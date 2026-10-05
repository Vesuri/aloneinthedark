#include <proto/exec.h>
#include <exec/interrupts.h>
#include <exec/nodes.h>
#include <resources/cia.h>
#include <proto/cia.h>
#include <hardware/cia.h>

#include "MacInput.h"
#include "framework/AmigaHardware.h"
#include "mac/MacLoader.h"

static struct Library* s_ciaaBase;
static struct Interrupt s_keyboardInterrupt;
static struct Interrupt* s_savedVector;
struct KeyEvent {
    uint8_t rawAndUp;
    uint16_t modifiers;
};
static volatile KeyEvent s_events[32];
static volatile uint8_t s_head, s_tail;
static volatile uint8_t s_keyDown[128];

static uint16_t currentModifiers()
{
    uint16_t modifiers = 0;
    if (s_keyDown[0x60] || s_keyDown[0x61]) modifiers |= 0x0200; // shiftKey
    if (s_keyDown[0x63]) modifiers |= 0x1000;                    // controlKey
    if (s_keyDown[0x64] || s_keyDown[0x65]) modifiers |= 0x0800; // optionKey
    if (s_keyDown[0x66] || s_keyDown[0x67]) modifiers |= 0x0100; // cmdKey
    return modifiers;
}

static void recordKey(uint8_t raw, bool down)
{
    s_keyDown[raw] = down ? 1 : 0;
    aitdMacRawKeyChanged(raw, down);
    uint8_t next = (uint8_t)((s_head + 1) & 31);
    if (next != s_tail) {
        s_events[s_head].rawAndUp = (uint8_t)(raw | (down ? 0 : 0x80));
        s_events[s_head].modifiers = currentModifiers();
        s_head = next;
    }
}

static uint32_t keyboardHandler()
{
    uint8_t code = (uint8_t)~*ciaasdrPointer;
    *ciaacraPointer |= CIACRAF_SPMODE;
    for (volatile uint16_t delay = 0; delay < 200; ++delay) { }
    *ciaacraPointer &= (uint8_t)~CIACRAF_SPMODE;
    code = (uint8_t)((code >> 1) | (code << 7));
    uint8_t raw = (uint8_t)(code & 0x7f);
    bool down = (code & 0x80) == 0;
    recordKey(raw, down);
    return 0;
}

bool aitdInputInitialize()
{
    for (uint16_t i = 0; i < 128; ++i) s_keyDown[i] = 0;
    s_head = s_tail = 0;
    s_ciaaBase = (struct Library*)OpenResource((CONST_STRPTR)CIAANAME);
    if (!s_ciaaBase) return false;
    s_keyboardInterrupt.is_Node.ln_Type = NT_INTERRUPT;
    s_keyboardInterrupt.is_Node.ln_Pri = 0;
    s_keyboardInterrupt.is_Node.ln_Name = (char*)"Alone keyboard";
    s_keyboardInterrupt.is_Data = 0;
    s_keyboardInterrupt.is_Code = (void(*)())keyboardHandler;
    s_savedVector = AddICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    if (s_savedVector) {
        RemICRVector(s_ciaaBase, CIAICRB_SP, s_savedVector);
        AddICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    }
    return true;
}

void aitdInputShutdown()
{
    if (!s_ciaaBase) return;
    RemICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    if (s_savedVector) AddICRVector(s_ciaaBase, CIAICRB_SP, s_savedVector);
    s_savedVector = 0;
    s_ciaaBase = 0;
}

bool aitdInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers)
{
    if (s_tail == s_head) return false;
    uint8_t event = s_events[s_tail].rawAndUp;
    modifiers = s_events[s_tail].modifiers;
    s_tail = (uint8_t)((s_tail + 1) & 31);
    rawKey = (uint8_t)(event & 0x7f);
    down = (event & 0x80) == 0;
    return true;
}

bool aitdInputKeyDown(uint8_t rawKey)
{
    if (rawKey >= 128) return false;
    return s_keyDown[rawKey] != 0;
}

uint16_t aitdInputModifiers()
{
    return currentModifiers();
}

void aitdInputInjectProbeKey(uint8_t rawKey, bool down)
{
    if (rawKey >= 128) return;
    Disable();
    recordKey(rawKey, down);
    Enable();
}


#ifdef AITD_INGAME
extern "C" { volatile uint16_t g_ingameStage=0; volatile uint32_t g_ingameTick=0; }
extern "C" __attribute__((noinline)) void aitdInputInGameCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
void aitdInputInGame(uint16_t trap,bool menu,bool portraits,bool story,
                    bool gameplay,uint32_t ticks)
{
    static uint8_t held=0xff;
    static uint32_t pressed=0;
    static bool announced=false;
    const uint16_t previous=g_ingameStage;
    uint8_t key=0xff;
    if(g_ingameStage==5)return;
    if(menu && g_ingameStage==0) {g_ingameStage=1;g_ingameTick=ticks;}
    if(portraits && g_ingameStage==1) {g_ingameStage=2;g_ingameTick=ticks;}
    if(story && g_ingameStage==2) {g_ingameStage=3;g_ingameTick=ticks;}
    if(g_ingameStage==3 && !story && ticks-g_ingameTick>=4) {
        g_ingameStage=4;g_ingameTick=ticks;
    }
    if(g_ingameStage==4 && gameplay && trap==0xa976) {
        g_ingameStage=5;g_ingameTick=ticks;
    }
    // Publisher screens poll events before the book polls GetKeys. Send
    // bounded presses: some normal skip paths explicitly wait for release.
    if(g_ingameStage==0 && (announced || trap==0xa860 || trap==0xa970
       || trap==0xa976 || trap==0xa974 || trap==0xa891)
       && ticks%30<4)key=0x40;
    if((g_ingameStage==1 && menu)
       || (g_ingameStage==3 && story)) {
        // Leave a released interval between successive Return selections.
        if(ticks-g_ingameTick>=2)key=0x44;
    }
    if(g_ingameStage==2 && portraits) {
        if(ticks-g_ingameTick>=2 && ticks-g_ingameTick<6)key=0x4e;
        if(ticks-g_ingameTick>=8)key=0x44;
    }
    if(g_ingameStage==4 && !gameplay && trap==0xa976)key=0x45;
    if((held==0x44 || held==0x4e) && ticks-pressed<2 && g_ingameStage>=1 && g_ingameStage<=3)
        key=held;
    if(held!=key) {
        if(held!=0xff)aitdInputInjectProbeKey(held,false);
        held=key;
    }
    // Do not enqueue duplicate presses while the requested key is held.
    if(key!=0xff && !aitdInputKeyDown(key)) {
        aitdInputInjectProbeKey(key,true);pressed=ticks;
    }
    if(previous!=g_ingameStage || (!announced && key!=0xff)) {
        announced=true;aitdInputInGameCheckpoint();
    }
}
#endif

#ifdef AITD_GAME_INPUT
extern "C" { volatile uint16_t g_gameInputStage=0; volatile uint32_t g_gameInputTick=0; volatile uint16_t g_gameInputFightEvent=0; }
extern "C" __attribute__((noinline)) void aitdInputGameplayCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
extern "C" __attribute__((noinline)) void aitdInputGameplayFightCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
void aitdInputGameplayEvent(uint16_t what,uint32_t message)
{
    if(g_gameInputStage==5 && what==3 && (message&255)=='f' && !g_gameInputFightEvent) {
        g_gameInputFightEvent=1;aitdInputGameplayFightCheckpoint();
    }
}
void aitdInputGameplay(uint32_t ticks,bool ready,uint16_t animation)
{
    if(g_ingameStage!=5 || g_gameInputStage>=9 || !ready)return;
    static const uint16_t duration[]={300,60,30,60,30,20,30,90,60};
    if(!g_gameInputTick) {g_gameInputTick=ticks;return;}
    const uint32_t elapsed=ticks-g_gameInputTick;
    // Fail explicitly instead of turning a missed command into idle coverage.
    if(elapsed>1200) {
        g_gameInputStage=0xffff;aitdInputGameplayCheckpoint();return;
    }
    if(elapsed<duration[g_gameInputStage])return;
    // Fight is a queued character, unlike level-polled movement. Wait until
    // the game has selected it; slow frames must not outrun the event queue.
    const uint16_t stageBefore=g_gameInputStage;
    if((stageBefore==0 || stageBefore==2 || stageBefore==4 || stageBefore==8) && animation!=4)return;
    if(stageBefore==1 && animation!=254)return;
    if(stageBefore==3 && animation!=255)return;
    if((stageBefore==5 || stageBefore==6) && !g_gameInputFightEvent)return;
    if(stageBefore==7 && animation!=262)return;
    // Ordinary keyboard levels only: walk, release, Shift-run, release,
    // F for Fight, release, Space+Up action, release. Never write game state.
    ++g_gameInputStage;g_gameInputTick=ticks;
    const uint16_t stage=g_gameInputStage;
    aitdInputInjectProbeKey(0x4c,stage==1 || stage==3 || stage==7);
    aitdInputInjectProbeKey(0x60,stage==3);
    aitdInputInjectProbeKey(0x23,stage==5);
    aitdInputInjectProbeKey(0x40,stage==7);
    aitdInputGameplayCheckpoint();
}
#endif

#ifdef AITD_DEATH_ROUTE
extern "C" { volatile uint16_t g_deathRouteStage=0; volatile uint32_t g_deathRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputDeathRouteCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
void aitdInputDeathRoute(bool menu,uint32_t ticks,bool initialActor,int16_t z,uint16_t animation)
{
    static uint32_t sampled=0;
    if(g_deathRouteStage>=5)return;
    if(!g_deathRouteStage) {
        if(g_gameInputStage!=9)return;
        // Return from the control test's far wall to the starting area using
        // the ordinary backward key. Do not change actor/game state.
        aitdInputInjectProbeKey(0x4d,true);
        g_deathRouteStage=1;g_deathRouteTick=ticks;sampled=ticks;
    } else if(ticks-g_deathRouteTick>(g_deathRouteStage<=2 ? 1200U : 36000U)) {
        aitdInputInjectProbeKey(0x4d,false);g_deathRouteStage=0xffff;
    } else if(g_deathRouteStage==1) {
        if(z<-1548)return;
        aitdInputInjectProbeKey(0x4d,false);
        g_deathRouteStage=2;g_deathRouteTick=ticks;
    } else if(g_deathRouteStage==2) {
        if(animation!=4 || ticks-g_deathRouteTick<30)return;
        g_deathRouteStage=3;g_deathRouteTick=ticks;sampled=ticks;
    } else if(g_deathRouteStage==3) {
        if(!menu) {
            if(ticks-sampled>=600) {sampled=ticks;aitdInputDeathRouteCheckpoint();}
            return;
        }
        // Re-arm only diagnostic startup bookkeeping. The original menu,
        // portrait and story loops receive the same ordinary input as boot.
        g_deathRouteStage=4;g_deathRouteTick=ticks;
        g_ingameStage=0;g_ingameTick=0;
    } else {
        if(g_ingameStage!=5 || !initialActor)return;
        g_deathRouteStage=5;g_deathRouteTick=ticks;
    }
    aitdInputDeathRouteCheckpoint();
}
#endif

#ifdef AITD_MENU_PROBE
extern "C" { volatile uint16_t g_menuProbeStage=0,g_menuProbeExitOK=0; volatile uint32_t g_menuProbeTick=0; }
extern "C" { extern volatile uint16_t g_menuFeedbackStage; }
extern "C" __attribute__((noinline)) void aitdMenuProbeCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static const uint8_t s_menuProbeKeys[]={0,0x21,0x21,0x37,0x37,0x21,0x37,0x18,
#ifdef AITD_SAVE_LOAD
0x44,
#else
0x45,
#endif
0x10};
#ifdef AITD_SAVE_LOAD
extern "C" { volatile uint16_t g_saveLoadStage=0; volatile uint32_t g_saveLoadTick=0,g_saveLoadClosedBytes=0,g_saveLoadReadBytes=0; volatile int16_t g_saveLoadSavedX=0,g_saveLoadSavedZ=0; }
#endif
static const uint8_t s_menuProbeText[]={0x37,0x03,0x14,0x12,0x21,0x14,0x44}; // m3test, Return
static uint16_t s_menuProbeTextIndex=0;
static bool s_menuProbeHeld=false;
static void menuProbeKey(bool down)
{
    const uint16_t stage=g_menuProbeStage;
    const bool command=stage==5 || stage==7 || stage==9;
    if(command && down)aitdInputInjectProbeKey(0x67,true);
    aitdInputInjectProbeKey(stage==6 ? s_menuProbeText[s_menuProbeTextIndex] : s_menuProbeKeys[stage],down);
    if(command && !down)aitdInputInjectProbeKey(0x67,false);
    s_menuProbeHeld=down;
}
void aitdInputMenuProbe(uint32_t ticks)
{
    if(g_ingameStage!=5 || g_menuProbeStage>=9)return;
    if(!g_menuProbeTick) {g_menuProbeTick=ticks;return;}
    const uint32_t elapsed=ticks-g_menuProbeTick;
    if(!g_menuProbeStage) {
        if(elapsed<300)return;
    } else if(s_menuProbeHeld) {
        // S/M are polled as key levels by the game. Hold them across a
        // complete slow scene frame; menu equivalents use queued key events.
        if(elapsed>=(g_menuProbeStage<=4 ? 60 : 8)) {menuProbeKey(false);g_menuProbeTick=ticks;}
        return;
    } else if(g_menuProbeStage==6 && s_menuProbeTextIndex<6) {
        if(elapsed<8)return;
        ++s_menuProbeTextIndex;g_menuProbeTick=ticks;menuProbeKey(true);return;
    } else if(elapsed<90)return;
    else if(g_menuProbeStage<=4 && g_menuFeedbackStage!=g_menuProbeStage) {
        // Initial room setup can consume a key before its control loop is
        // ready. Retry ordinary input until the game's own feedback confirms
        // this action, instead of advancing into an unfinished previous call.
        g_menuProbeTick=ticks;menuProbeKey(true);return;
    }
#ifdef AITD_SAVE_LOAD
    if((g_menuProbeStage==6 && g_saveLoadStage<4) || (g_menuProbeStage==8 && g_saveLoadStage<6))return;
#endif
    ++g_menuProbeStage;g_menuProbeTick=ticks;
    aitdMenuProbeCheckpoint();
    menuProbeKey(true);
}
void aitdInputMenuProbeQuit()
{
    if(s_menuProbeHeld)menuProbeKey(false);
    g_menuProbeStage=10;aitdMenuProbeCheckpoint();
}
void aitdInputMenuProbeFinished(bool ok)
{
    g_menuProbeExitOK=ok;g_menuProbeStage=11;aitdMenuProbeCheckpoint();
}
#endif

#ifdef AITD_EXPLORE_ROUTE
extern "C" { volatile uint16_t g_exploreRouteStage=0; volatile uint32_t g_exploreRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputExploreCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint32_t s_exploreFrames=0;
void aitdInputExplore(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t floor,uint16_t track,bool ready)
{
    if(!ready || g_exploreRouteStage>=19)return;
    beta&=1023;
    uint16_t stage=g_exploreRouteStage;
    if(stage && ticks-g_exploreRouteTick>3600) {
        for(uint8_t key=0x4c;key<=0x4f;++key)aitdInputInjectProbeKey(key,false);
        g_exploreRouteStage=0xffff;aitdInputExploreCheckpoint();return;
    }
    if(stage==18) {
        if(floor!=1 || track!=1 || animation!=4 || ticks-g_exploreRouteTick<30 || scenes<=s_exploreFrames)return;
        g_exploreRouteStage=19;aitdInputExploreCheckpoint();return;
    }
    if(!stage)aitdInputInjectProbeKey(0x4d,true);
    else if(stage==1) {if(z<1000)return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==3) {if(beta<240 || beta>=512)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==5) {if(x<4100)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==7) {if(beta<496 || beta>=768)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==9) {if(z<3600)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==11) {if(beta<240 || beta>280)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==13) {if(x<6650)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==15) {if(beta>32 && beta<992)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==17) {if(floor!=1)return;aitdInputInjectProbeKey(0x4c,false);}
    else {
        if(animation!=4 || ticks-g_exploreRouteTick<30)return;
        const uint8_t key=stage==2 || stage==6 ? 0x4f : stage==10 || stage==14 ? 0x4e : 0x4c;
        aitdInputInjectProbeKey(key,true);
    }
    g_exploreRouteStage=stage+1;g_exploreRouteTick=ticks;
    if(g_exploreRouteStage==18)s_exploreFrames=scenes;
    aitdInputExploreCheckpoint();
}
#endif

#ifdef AITD_SAVE_LOAD
extern "C" __attribute__((noinline)) void aitdInputSaveLoadCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint32_t s_saveLoadFrames=0;
void aitdInputSaveLoadClosed(uint32_t bytes)
{
    if(g_saveLoadStage==1)g_saveLoadClosedBytes=bytes;
}
void aitdInputSaveLoadRead(uint32_t bytes)
{
    if(g_saveLoadStage==5)g_saveLoadReadBytes+=bytes;
}
void aitdInputSaveLoad(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t animation,bool ready)
{
    if(g_saveLoadStage>=6 || !ready)return;
    if(!g_saveLoadStage) {
#ifdef AITD_LOAD_ONLY
        // Fresh boot: move away before loading the preceding run's save.
        // Only diagnostic controller state is initialized; the game sees keys.
        g_menuProbeStage=6;g_menuProbeTick=ticks;s_menuProbeTextIndex=6;
        g_saveLoadSavedX=x;g_saveLoadSavedZ=z;s_saveLoadFrames=scenes;
        aitdInputInjectProbeKey(0x4c,true);g_saveLoadStage=2;g_saveLoadTick=ticks;
#else
        if(g_menuProbeStage!=6 || s_menuProbeTextIndex!=6)return;
        g_saveLoadSavedX=x;g_saveLoadSavedZ=z;s_saveLoadFrames=scenes;
        g_saveLoadStage=1;g_saveLoadTick=ticks;
#endif
    } else if(ticks-g_saveLoadTick>2400) {
        aitdInputInjectProbeKey(0x4c,false);g_saveLoadStage=0xffff;
    } else if(g_saveLoadStage==1) {
        if(g_saveLoadClosedBytes<10000 || s_menuProbeHeld || scenes<=s_saveLoadFrames)return;
        if(x!=g_saveLoadSavedX || z!=g_saveLoadSavedZ)return;
        aitdInputInjectProbeKey(0x4c,true);g_saveLoadStage=2;g_saveLoadTick=ticks;
    } else if(g_saveLoadStage==2) {
        int32_t distance=int32_t(z)-g_saveLoadSavedZ;if(distance<0)distance=-distance;
        if(distance<300 || animation!=254)return;
        aitdInputInjectProbeKey(0x4c,false);g_saveLoadStage=3;g_saveLoadTick=ticks;
    } else if(g_saveLoadStage==3) {
        if(animation!=4 || ticks-g_saveLoadTick<30)return;
        g_saveLoadStage=4;g_saveLoadTick=ticks;
    } else if(g_saveLoadStage==4) {
        if(g_menuProbeStage!=8)return;
        s_saveLoadFrames=scenes;g_saveLoadStage=5;g_saveLoadTick=ticks;
    } else {
        if(x!=g_saveLoadSavedX || z!=g_saveLoadSavedZ || animation!=4
           || g_saveLoadReadBytes<10000 || scenes<=s_saveLoadFrames)return;
        g_saveLoadStage=6;g_saveLoadTick=ticks;
    }
    aitdInputSaveLoadCheckpoint();
}
#endif

#ifdef AITD_INTRO_SKIP
extern "C" { volatile uint16_t g_introSkipState = 0; volatile uint32_t g_introSkipTick = 0; }
void aitdInputIntroSkip(uint16_t trap, uint32_t ticks)
{
    // Diagnostic input only, following Slicks' target-side key queue.
    if (!g_introSkipState && trap == 0xa891) {
        aitdInputInjectProbeKey(0x44, true);
        g_introSkipTick = ticks;
        g_introSkipState = 1;
    } else if (g_introSkipState == 1 && (trap == 0xa976 || ticks - g_introSkipTick >= 120)) {
        aitdInputInjectProbeKey(0x44, false);
        g_introSkipState = 2;
    }
}
#endif


#ifdef AITD_MENU_ENTER
extern "C" {
volatile uint16_t g_menuEnterState=0;
volatile uint32_t g_menuEnterTick=0,g_menuEnterReleased=0;
}
void aitdInputMenuEnter(bool atMenu,uint32_t ticks)
{
    if(!g_menuEnterState && atMenu) {
        g_menuEnterTick=ticks;g_menuEnterState=1;
    } else if(g_menuEnterState==1 && atMenu && ticks-g_menuEnterTick>=30) {
        aitdInputInjectProbeKey(0x44,true);
        g_menuEnterTick=ticks;g_menuEnterState=2;
    } else if(g_menuEnterState==2 && ticks-g_menuEnterTick>=2) {
        aitdInputInjectProbeKey(0x44,false);
        g_menuEnterReleased=ticks;g_menuEnterState=3;
    }
}
#endif

#ifdef AITD_STORY_ENTER
extern "C" {
volatile uint16_t g_storyEnterState=0;
volatile uint32_t g_storyEnterTick=0,g_storyEnterReleased=0;
}
void aitdInputStoryEnter(bool atPortraits,uint32_t ticks)
{
    if(!g_storyEnterState && atPortraits) {
        g_storyEnterTick=ticks;g_storyEnterState=1;
    } else if(g_storyEnterState==1 && atPortraits && ticks-g_storyEnterTick>=30) {
        aitdInputInjectProbeKey(0x44,true);
        g_storyEnterTick=ticks;g_storyEnterState=2;
    } else if(g_storyEnterState==2 && ticks-g_storyEnterTick>=2) {
        aitdInputInjectProbeKey(0x44,false);
        g_storyEnterReleased=ticks;g_storyEnterState=3;
    }
}
#endif

#ifdef AITD_STORY_READ
extern "C" {
volatile uint16_t g_storyReadState=0,g_storyReadPage=0xffff,g_storyReadCount=0;
volatile uint32_t g_storyReadTick=0,g_storyReadReleased=0;
}
void aitdInputStoryRead(bool atStory,uint16_t page,bool lastPage,uint32_t ticks)
{
    static uint8_t key;
    if(atStory && (!g_storyReadState || (g_storyReadState==3 && page!=g_storyReadPage))) {
        g_storyReadPage=page;g_storyReadTick=ticks;g_storyReadState=1;
        key=lastPage ? 0x44 : 0x4e;
    } else if(atStory && g_storyReadState==1 && ticks-g_storyReadTick>=30) {
        aitdInputInjectProbeKey(key,true);
        g_storyReadTick=ticks;g_storyReadState=2;++g_storyReadCount;
    } else if(g_storyReadState==2 && ticks-g_storyReadTick>=2) {
        aitdInputInjectProbeKey(key,false);
        g_storyReadReleased=ticks;g_storyReadState=3;
    }
}
#endif

#ifdef AITD_ACTION_PROBE
#include "PerfProbe.h"
extern "C" {
volatile uint16_t g_actionProbeStage=0;
volatile uint32_t g_actionProbeTick=0;
}
#ifdef AITD_ACTION_NAV
extern "C" {
volatile uint16_t g_actionNavStage=0;
volatile uint32_t g_actionNavTick=0;
extern volatile uint16_t g_mouseProbeEnabled,g_mouseProbeDown;
extern volatile int16_t g_mouseProbeX,g_mouseProbeY;
}
static void actionNavigation(uint32_t ticks)
{
    if(!g_actionNavStage) {
        g_mouseProbeX=620;g_mouseProbeY=470;g_mouseProbeDown=0;g_mouseProbeEnabled=1;
        if(g_actionProbeStage!=3 || ticks-g_actionProbeTick<600)return;
        g_actionNavStage=1;g_actionNavTick=ticks;
        aitdInputInjectProbeKey(0x4e,true);return;
    }
    const uint32_t elapsed=ticks-g_actionNavTick;
    const uint16_t stage=g_actionNavStage;
#ifdef AITD_ACTION_CLICK
    if(elapsed<(stage==13 ? 8U : (stage>=7 && stage<=10) || stage==12 ? 120U : 60U))return;
    if(stage==1)aitdInputInjectProbeKey(0x4e,false);
    else if(stage==2)aitdInputInjectProbeKey(0x4d,true);
    else if(stage==3)aitdInputInjectProbeKey(0x4d,false);
    else if(stage==4)aitdInputInjectProbeKey(0x4c,true);
    else if(stage==5)aitdInputInjectProbeKey(0x4c,false);
    else if(stage==6) {g_mouseProbeX=410;g_mouseProbeY=285;}
    else if(stage==7)g_mouseProbeDown=1;
    else if(stage==8)g_mouseProbeDown=0;
    else if(stage==9) {g_mouseProbeX=620;g_mouseProbeY=470;}
    else if(stage==10)aitdInputInjectProbeKey(0x45,true);
    else if(stage==11)aitdInputInjectProbeKey(0x45,false);
    else if(stage==12) {aitdInputInjectProbeKey(0x67,true);aitdInputInjectProbeKey(0x10,true);}
    else if(stage==13) {aitdInputInjectProbeKey(0x10,false);aitdInputInjectProbeKey(0x67,false);}
    else return;
#else
    if(elapsed<(stage==11 ? 8U : stage==7 || stage==8 || stage==10 ? 120U : 60U))return;
    if(stage==1)aitdInputInjectProbeKey(0x4e,false);
    else if(stage==2)aitdInputInjectProbeKey(0x4d,true);
    else if(stage==3)aitdInputInjectProbeKey(0x4d,false);
    else if(stage==4)aitdInputInjectProbeKey(0x4c,true);
    else if(stage==5)aitdInputInjectProbeKey(0x4c,false);
    else if(stage==6) {g_mouseProbeX=410;g_mouseProbeY=285;}
    else if(stage==7) {g_mouseProbeX=620;g_mouseProbeY=470;}
    else if(stage==8)aitdInputInjectProbeKey(0x45,true);
    else if(stage==9)aitdInputInjectProbeKey(0x45,false);
    else if(stage==10) {aitdInputInjectProbeKey(0x67,true);aitdInputInjectProbeKey(0x10,true);}
    else if(stage==11) {aitdInputInjectProbeKey(0x10,false);aitdInputInjectProbeKey(0x67,false);}
    else return;
#endif
    ++g_actionNavStage;g_actionNavTick=ticks;
}
#endif
void aitdInputActionProbe(uint16_t trap,uint32_t ticks)
{
    if(g_ingameStage!=5)return;
#ifdef AITD_ACTION_NAV
    actionNavigation(ticks);
#endif
    if(!g_actionProbeStage) {g_actionProbeStage=1;g_actionProbeTick=ticks;}
    // Press at GetKeys so a short press cannot disappear during a slow render.
    // Release at any subsequent trap, including the menu's release-wait loop.
    if(g_actionProbeStage==1 && trap==0xa976 && ticks-g_actionProbeTick>=30) {
        aitdProfileStart();aitdInputInjectProbeKey(0x44,true);
        g_actionProbeStage=2;g_actionProbeTick=ticks;
    } else if(g_actionProbeStage==2 && ticks-g_actionProbeTick>=4) {
        aitdInputInjectProbeKey(0x44,false);g_actionProbeStage=3;
    }
}
#endif
