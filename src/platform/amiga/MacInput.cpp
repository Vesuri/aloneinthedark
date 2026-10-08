#ifdef AITD_ROOM4_RECOVERY
#include "FirstFloorRecovery.h"
#endif
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
#ifdef AITD_ROOM5_RETURN
extern "C" { volatile uint32_t g_returnDroppedKeys=0,g_returnOpenEvents=0; }
#endif

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
#ifdef AITD_ROOM5_RETURN
    } else {
        ++g_returnDroppedKeys;
#endif
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
    // Probe controllers describe held levels. Repeated requests to release a
    // key are not additional keyboard transitions and must not fill the queue.
    if ((s_keyDown[rawKey] != 0) == down) { Enable(); return; }
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
    static bool approached=false,approaching=false;
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
        // The idle starting position can leave the attacker just out of reach.
        // Once, use ordinary Back to close that gap; never edit combat state.
        if(!approached && !approaching && !menu && animation==4
           && ticks-g_deathRouteTick>=6000) {
            approached=true;
            if(z<-500) {approaching=true;aitdInputInjectProbeKey(0x4d,true);}
        }
        if(approaching && (z>=-500 || animation==261 || menu)) {
            aitdInputInjectProbeKey(0x4d,false);approaching=false;
        }
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

#ifdef AITD_LAMP_ROUTE
extern "C" { volatile uint16_t g_lampRouteStage=0; volatile uint32_t g_lampRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputLampCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint32_t s_lampFrames=0;
void aitdInputLamp(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t track,bool found,bool taken,bool used,bool ready)
{
#ifdef AITD_LAMP_USE
#ifdef AITD_HALLWAY
    const uint16_t terminal=30;
#else
    const uint16_t terminal=27;
#endif
#else
    const uint16_t terminal=15;
    (void)used;
#endif
#ifndef AITD_COMBAT_ROUTE
    (void)found;
#endif
    if(!ready || g_lampRouteStage>=terminal)return;
    beta&=1023;const uint16_t stage=g_lampRouteStage;
    const uint32_t elapsed=ticks-g_lampRouteTick;
    if(stage && elapsed>2400) {
        for(uint8_t key=0x4c;key<=0x4f;++key)aitdInputInjectProbeKey(key,false);
        aitdInputInjectProbeKey(0x18,false);aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x44,false);
        g_lampRouteStage=0xffff;aitdInputLampCheckpoint();return;
    }
    if(!stage)aitdInputInjectProbeKey(0x4f,true);
    else if(stage==1) {if(beta<240 || beta>=512)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==2 || stage==4 || stage==6) {
        if(animation!=4 || elapsed<30)return;
        aitdInputInjectProbeKey(stage==4 ? 0x4e : 0x4c,true);
    }
    else if(stage==3) {
#if defined(AITD_COMBAT_ROUTE) && !defined(AITD_ROOM5_COMBAT)
        if(x<3800)return;
#else
        if(x<3600)return;
#endif
        aitdInputInjectProbeKey(0x4c,false);
    }
    else if(stage==5) {
#ifdef AITD_ROOM5_COMBAT
        // Match the southern-room Mac route. Releasing at beta 26 leaves all
        // subsequent quarter-turns off-axis and outside the stairs tolerance.
        if(beta>8 && beta<1016)return;
#else
        if(beta>32 && beta<992)return;
#endif
        aitdInputInjectProbeKey(0x4e,false);
    }
    else if(stage==7) {if(z>-3800)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==8) {if(elapsed<30)return;aitdInputInjectProbeKey(0x18,true);}
    else if(stage==9) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
    else if(stage==10) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
    else if(stage==11) {if(elapsed<120
#ifdef AITD_COMBAT_ROUTE
        || !found
#endif
        )return;aitdInputInjectProbeKey(0x40,false);}
    else if(stage==12) {if(elapsed<30)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==13) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);s_lampFrames=scenes;}
    else if(stage==14) {if(!taken || animation!=4 || track!=1 || scenes<=s_lampFrames)return;}
#ifdef AITD_LAMP_USE
    else if(stage==15)aitdInputInjectProbeKey(0x44,true);
    else if(stage==16 || stage==20 || stage==22) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);}
    else if(stage==17) {if(elapsed<180)return;aitdInputInjectProbeKey(0x4d,true);}
    else if(stage==18) {if(elapsed<8)return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==19 || stage==21) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==23) {if(!used || animation!=287)return;s_lampFrames=scenes;}
    else if(stage==24) {if(!used || animation!=287 || track!=1 || scenes<=s_lampFrames)return;aitdInputInjectProbeKey(0x4d,true);}
    else if(stage==25) {if(z<-3500)return;aitdInputInjectProbeKey(0x4d,false);s_lampFrames=scenes;}
    else if(stage==26) {if(!used || animation!=287 || track!=1 || elapsed<30 || scenes<=s_lampFrames)return;}
#ifdef AITD_HALLWAY
    else if(stage==27)aitdInputInjectProbeKey(0x18,true);
    else if(stage==28) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);s_lampFrames=scenes;}
    else if(stage==29) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_lampFrames)return;}
#endif
#endif
    g_lampRouteStage=stage+1;g_lampRouteTick=ticks;aitdInputLampCheckpoint();
}
#endif

#ifdef AITD_BOOK_PAGES
extern "C" { volatile uint16_t g_bookPageStage=0,g_bookPageIndex=0xffff,g_bookPageLast=0;
volatile uint32_t g_bookPageTick=0; }
extern "C" __attribute__((noinline)) void aitdInputBookPageCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
void aitdInputBookPages(bool reading,uint16_t page,bool last,uint32_t ticks,bool completed)
{
    if(g_bookRouteStage!=36 || g_bookPageStage>=19)return;
    const uint16_t stage=g_bookPageStage;
    const uint32_t elapsed=ticks-g_bookPageTick;
    if(stage && elapsed>2400) {
        aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);aitdInputInjectProbeKey(0x44,false);
        g_bookPageStage=0xffff;aitdInputBookPageCheckpoint();return;
    }
    if(!stage) {if(!reading || page!=0 || last)return;}
    else if(stage==18) {if(!completed)return;}
    else if(stage%3==1) {
        if(!reading)return;
        if(stage==16 && (page!=3 || !last))return;
        aitdInputInjectProbeKey(stage==16 ? 0x44 : stage==4 ? 0x4f : 0x4e,true);
    }
    else if(stage%3==2) {
        if(elapsed<8)return;
        aitdInputInjectProbeKey(stage==17 ? 0x44 : stage==5 ? 0x4f : 0x4e,false);
    }
    else {
        const uint16_t expected[]={1,0,1,2,3};
        if(!reading || page!=expected[stage/3-1] || last!=(page==3) || elapsed<300)return;
    }
    if(reading) {g_bookPageIndex=page;g_bookPageLast=last;}
    g_bookPageStage=stage+1;g_bookPageTick=ticks;aitdInputBookPageCheckpoint();
}
#endif

#ifdef AITD_BOOK_ROUTE
extern "C" { volatile uint16_t g_bookRouteStage=0; volatile uint32_t g_bookRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputBookCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint32_t s_bookFrames=0;
void aitdInputBook(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t track,uint16_t objects,bool ready)
{
    // Independent continuation of lamp Take, before its optional Use route.
    if(g_lampRouteStage!=15 || !ready || g_bookRouteStage>=39)return;
    const uint16_t stage=g_bookRouteStage;
    const uint32_t elapsed=ticks-g_bookRouteTick;
    beta&=1023;
    uint32_t deadline=2400;
#ifdef AITD_BOOK_PAGES
    if(stage==36)deadline=24000; // Individual page waits remain bounded below.
#endif
    if(stage && elapsed>deadline) {
        for(uint8_t k=0x4c;k<=0x4f;++k)aitdInputInjectProbeKey(k,false);
        aitdInputInjectProbeKey(0x18,false);aitdInputInjectProbeKey(0x40,false);
        aitdInputInjectProbeKey(0x44,false);aitdInputInjectProbeKey(0x45,false);
        g_bookRouteStage=0xffff;aitdInputBookCheckpoint();return;
    }
    if(!stage)aitdInputInjectProbeKey(0x4d,true);
    else if(stage==1) {if(z<-1800)return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage>=2 && stage<=20 && stage%3==2) {
        if(animation!=4 || track!=1 || elapsed<30)return;
        const uint8_t keys[]={0x4e,0x4c,0x4f,0x4c,0x4f,0x4c,0x18};
        aitdInputInjectProbeKey(keys[(stage-2)/3],true);
    }
    // A slow frame can step across the narrower west-facing window.
    else if(stage==3) {if(beta<736 || beta>800)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==6) {if(x>-1600)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==9) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==12) {if(z>-3100)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==15) {if(beta<240 || beta>272)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==18) {if(x<-1650)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage>=4 && stage<=19 && stage%3==1) {if(animation!=4 || track!=1 || elapsed<30)return;}
    else if(stage==21) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
    else if(stage==22) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
    else if(stage==23) {if(!(objects&1))return;aitdInputInjectProbeKey(0x40,false);}
    else if(stage==24) {if(elapsed<300 || !(objects&1))return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==25) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);s_bookFrames=scenes;}
    else if(stage==26) {if(!(objects&2) || (objects&1) || animation!=4 || track!=1 || scenes<=s_bookFrames || elapsed<60)return;}
    else if(stage==27)aitdInputInjectProbeKey(0x44,true);
    else if(stage==28) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);}
    else if(stage==29) {if(elapsed<180)return;aitdInputInjectProbeKey(0x4d,true);}
    else if(stage==30) {if(!(objects&4))return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==31 || stage==33) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==32 || stage==34) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);}
    else if(stage==35) {if(!(objects&8) || elapsed<300)return;}
    else if(stage==36) {
#ifdef AITD_BOOK_PAGES
        if(g_bookPageStage!=19)return;
#else
        aitdInputInjectProbeKey(0x45,true);
#endif
    }
    else if(stage==37) {if(elapsed<8)return;aitdInputInjectProbeKey(0x45,false);s_bookFrames=scenes;}
    else if(stage==38) {if(!(objects&16) || animation!=4 || track!=1 || elapsed<180 || scenes<=s_bookFrames)return;}
    g_bookRouteStage=stage+1;g_bookRouteTick=ticks;aitdInputBookCheckpoint();
}
#endif

#ifdef AITD_EXPLORE_ROUTE
extern "C" { volatile uint16_t g_exploreRouteStage=0; volatile uint32_t g_exploreRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputExploreCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint32_t s_exploreFrames=0;
#ifdef AITD_SABER_ROUTE
extern "C" { volatile uint16_t g_saberOpenAttempts=0; }
extern "C" __attribute__((noinline)) void aitdInputSaberActionCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
#ifdef AITD_SABER_BREAK
extern "C" { volatile uint16_t g_saberBreakAttempts=3; }
extern "C" __attribute__((noinline)) void aitdInputSaberBreakCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint8_t s_saberBreakState=0;
static uint32_t s_saberBreakTick=0;
static bool saberBrokenReady(uint32_t ticks,uint16_t objects,uint16_t animation,uint16_t track)
{
    if((objects&32) && (s_saberBreakState==1 || s_saberBreakState==2)) {
        aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x40,false);
        s_saberBreakState=3;s_saberBreakTick=ticks;return false;
    }
    if(s_saberBreakState==1) {
        if(animation!=41)return false;
        s_saberBreakState=2;s_saberBreakTick=ticks;return false;
    }
    if(s_saberBreakState==2) {
        if(ticks-s_saberBreakTick<120)return false;
        aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x40,false);
        s_saberBreakState=3;s_saberBreakTick=ticks;return false;
    }
    if(animation!=4 || track!=1 || (s_saberBreakState==3 && ticks-s_saberBreakTick<30))return false;
    if(objects&32)return true;
    if(g_saberBreakAttempts>=16)return false;
    aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4c,true);
    s_saberBreakState=1;++g_saberBreakAttempts;aitdInputSaberBreakCheckpoint();return false;
}
#endif
static uint8_t s_saberActionState=0;
static uint32_t s_saberActionTick=0,s_saberFindTick=0;
static bool saberFindReady(uint32_t ticks,uint16_t objects,uint16_t animation,uint16_t track)
{
    if(s_saberActionState==1) {
        if(ticks-s_saberActionTick<120)return false;
        aitdInputInjectProbeKey(0x40,false);s_saberActionState=2;s_saberActionTick=ticks;return false;
    }
    if(objects&16) {
        if(!s_saberFindTick)s_saberFindTick=ticks;
        return ticks-s_saberFindTick>=300;
    }
    if(animation!=4 || track!=1 || ticks-s_saberActionTick<300)return false;
    aitdInputInjectProbeKey(0x40,true);s_saberActionState=1;s_saberActionTick=ticks;
    ++g_saberOpenAttempts;aitdInputSaberActionCheckpoint();return false;
}
#endif
extern "C" { volatile uint16_t g_exploreAlignment=0; }
extern "C" __attribute__((noinline)) void aitdInputExploreAlignCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static bool exploreAligned(int16_t position,int16_t low,int16_t high,bool backForHigh,uint16_t animation)
{
    if(g_exploreAlignment==1 || g_exploreAlignment==3) {
        if(animation!=(g_exploreAlignment==1 ? 256 : 254))return false;
        aitdInputInjectProbeKey(g_exploreAlignment==1 ? 0x4d : 0x4c,false);
        ++g_exploreAlignment;aitdInputExploreAlignCheckpoint();return false;
    }
    if(g_exploreAlignment==2 || g_exploreAlignment==4) {
        if(animation!=4)return false;
        g_exploreAlignment=0;aitdInputExploreAlignCheckpoint();return false;
    }
    if(animation!=4)return false;
    if(position<low || position>high) {
        const bool back=(position>high)==backForHigh;
        g_exploreAlignment=back ? 1 : 3;
        aitdInputInjectProbeKey(back ? 0x4d : 0x4c,true);
        aitdInputExploreAlignCheckpoint();return false;
    }
    return true;
}
#ifdef AITD_HALLWAY
static uint8_t s_stairExitState=0;
static uint32_t s_stairExitTick=0;
static bool exploreStairExit(uint32_t ticks,int16_t x,uint16_t beta,uint16_t animation)
{
    if(!s_stairExitState) {
        if(x>=-350 && x<=32)s_stairExitState=2;
        else {aitdInputInjectProbeKey(0x4f,true);s_stairExitState=1;return false;}
    }
    if(s_stairExitState==1) {
        if(beta<240 || beta>272)return false;
        aitdInputInjectProbeKey(0x4f,false);s_stairExitState=2;return false;
    }
    if(s_stairExitState==2) {
        if(animation!=4 || !exploreAligned(x,-350,32,true,animation))return false;
        if(beta>16 && beta<1008) {aitdInputInjectProbeKey(0x4e,true);s_stairExitState=3;return false;}
        s_stairExitState=4;s_stairExitTick=ticks;return false;
    }
    if(s_stairExitState==3) {
        if(beta>16 && beta<1008)return false;
        aitdInputInjectProbeKey(0x4e,false);s_stairExitState=4;s_stairExitTick=ticks;return false;
    }
    return animation==4 && ticks-s_stairExitTick>=30;
}

#endif
void aitdInputExplore(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t floor,uint16_t room,uint16_t track,uint16_t objects,bool ready)
{
#ifdef AITD_LAMP_STAIRS
#ifdef AITD_HALLWAY
    if(g_lampRouteStage!=30)return;
#else
    if(g_lampRouteStage!=27)return;
#endif
    // The measured equipped-lamp standing animation satisfies release waits.
    if(animation==287)animation=4;
#endif
#ifdef AITD_SOUTH_ROOMS
    const uint16_t terminal=52;
#elif defined(AITD_SABER_BREAK)
    static uint32_t s_exploreAttackTick=0;
    const uint16_t terminal=115;
#elif defined(AITD_SABER_ROUTE)
    const uint16_t terminal=98;
#elif defined(AITD_BEDROOM_KEY)
    const uint16_t terminal=64;
#elif defined(AITD_HALLWAY)
    const uint16_t terminal=39;
#elif defined(AITD_FIRSTFLOOR)
    const uint16_t terminal=26;
#else
    const uint16_t terminal=19;
    (void)room;
#endif
#ifndef AITD_BEDROOM_KEY
    (void)objects;
#endif
    if(!ready || g_exploreRouteStage>=terminal)return;
    beta&=1023;
    uint16_t stage=g_exploreRouteStage;
    if(stage && ticks-g_exploreRouteTick>3600) {
        for(uint8_t key=0x4c;key<=0x4f;++key)aitdInputInjectProbeKey(key,false);
        g_exploreRouteStage=0xffff;aitdInputExploreCheckpoint();return;
    }
    if(stage==18) {
        if(floor!=1 || track!=1 || animation!=4 || ticks-g_exploreRouteTick<30 || scenes<=s_exploreFrames)return;
        g_exploreRouteStage=19;g_exploreRouteTick=ticks;aitdInputExploreCheckpoint();return;
    }
#ifdef AITD_SOUTH_ROOMS
    if(stage>=39) {
        const uint32_t elapsed=ticks-g_exploreRouteTick;
        if(stage==39) {if(animation!=4 || track!=1 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==40) {if(x>3400)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==41) {
#ifdef AITD_ROOM5_RETURN
            // Start inside the measured doorway range far enough east to
            // retain alignment after the south-facing walking animation.
            const int16_t approachLow=2860;
#else
            const int16_t approachLow=2720;
#endif
            if(elapsed<30 || !exploreAligned(x,approachLow,2900,false,animation))return;
            aitdInputInjectProbeKey(0x4e,true);
        }
        else if(stage==42) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==43) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==44) {if(z<200)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==45) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==46) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==47) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==48) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==49) {if(animation!=4 || track!=1 || elapsed<120)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==50) {if(floor!=1 || room!=5)return;aitdInputInjectProbeKey(0x4c,false);s_exploreFrames=scenes;}
        else if(stage==51) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;}
        g_exploreRouteStage=stage+1;g_exploreRouteTick=ticks;aitdInputExploreCheckpoint();return;
    }
#endif
#ifdef AITD_FIRSTFLOOR
    if(stage>=19) {
        const uint32_t elapsed=ticks-g_exploreRouteTick;
        if(stage==19) {if(elapsed<30
#ifdef AITD_HALLWAY
            || !exploreStairExit(ticks,x,beta,animation)
#endif
            )return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==20) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==21) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==22) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==23) {if(elapsed<120)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==24) {if(floor!=1 || room!=0)return;aitdInputInjectProbeKey(0x4c,false);s_exploreFrames=scenes;}
        else if(stage==25) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;}
#ifdef AITD_HALLWAY
        else if(stage==26) {if(elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==27) {if(z>3200)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==28) {if(elapsed<30 || !exploreAligned(z,2720,2900,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==29) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==30) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==31) {if(x>0)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==32) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==33) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==34) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==35) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==36) {if(elapsed<120 || track!=1 || animation!=4)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==37) {if(floor!=1 || room!=1)return;aitdInputInjectProbeKey(0x4c,false);s_exploreFrames=scenes;}
        else if(stage==38) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;}
#endif
#ifdef AITD_BEDROOM_KEY
        else if(stage==39) {if(elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==40) {if(x>3400)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==41) {if(elapsed<30 || !exploreAligned(x,2720,2900,false,animation))return;aitdInputInjectProbeKey(0x4f,true);}
        else if(stage==42) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4f,false);}
        else if(stage==43) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==44) {if(z>-850)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==45) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==46) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==47) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==48) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==49) {if(elapsed<120 || track!=1 || animation!=4)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==50) {if(floor!=1 || room!=2)return;aitdInputInjectProbeKey(0x4c,false);s_exploreFrames=scenes;}
        else if(stage==51) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==52) {if(z>-1000)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==53) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==54) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==55) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==56) {if(x>-500)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==57) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==58) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==59) {if(elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==60) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==61) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==62) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);s_exploreFrames=scenes;}
        else if(stage==63) {if(!(objects&1) || animation!=4 || track!=1 || scenes<=s_exploreFrames)return;}
#endif
#ifdef AITD_SABER_ROUTE
        else if(stage==64) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==65) {if(beta<240 || beta>272)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==66) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==67) {if(x<600)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==68) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4f,true);}
        else if(stage==69) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4f,false);}
        else if(stage==70) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==71) {if(z<900)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==72) {if(elapsed<30 || !exploreAligned(z,1200,1380,true,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==73) {if(beta<240 || beta>272)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==74) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==75) {if(x<1300)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==76) {if(elapsed<30 || !exploreAligned(x,1640,1680,true,animation))return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==77 || stage==81 || stage==83 || stage==90 || stage==94 || stage==96) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);if(stage==96)s_exploreFrames=scenes;}
        else if(stage==78 || stage==91) {if(elapsed<180)return;aitdInputInjectProbeKey(0x4d,true);}
        else if(stage==79 || stage==92) {if(elapsed<8)return;aitdInputInjectProbeKey(0x4d,false);}
        else if(stage==80 || stage==82 || stage==93 || stage==95) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==84) {if(elapsed<180 || !(objects&2))return;aitdInputInjectProbeKey(0x40,true);g_saberOpenAttempts=1;}
        else if(stage==85) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);s_saberActionTick=ticks;}
        else if(stage==86) {if(elapsed<300 || !saberFindReady(ticks,objects,animation,track))return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==87) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,false);s_exploreFrames=scenes;}
        else if(stage==88) {if(!(objects&4) || animation!=4 || track!=1 || scenes<=s_exploreFrames)return;}
        else if(stage==89) {if(elapsed<60)return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==97) {if(!(objects&8) || animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;}
#endif
#ifdef AITD_SABER_BREAK
        else if(stage==98) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==99) {if(!s_exploreAttackTick && animation==41)s_exploreAttackTick=ticks;if(!s_exploreAttackTick || ticks-s_exploreAttackTick<120)return;s_exploreAttackTick=0;aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x40,false);}
        else if(stage==100) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4f,true);}
        else if(stage==101) {if(!s_exploreAttackTick && animation==37)s_exploreAttackTick=ticks;if(!s_exploreAttackTick || ticks-s_exploreAttackTick<120)return;s_exploreAttackTick=0;aitdInputInjectProbeKey(0x4f,false);aitdInputInjectProbeKey(0x40,false);}
        else if(stage==102) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==103) {if(!s_exploreAttackTick && animation==39)s_exploreAttackTick=ticks;if(!s_exploreAttackTick || ticks-s_exploreAttackTick<120)return;s_exploreAttackTick=0;aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x40,false);}
        else if(stage==104) {if(elapsed<30 || !saberBrokenReady(ticks,objects,animation,track))return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==105) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==106) {if(animation!=4 || track!=1 || elapsed<30 || !(objects&256))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==107) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==108) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==109) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==110) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==111) {if(!(objects&64))return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==112) {if(elapsed<300 || !(objects&64))return;aitdInputInjectProbeKey(0x44,true);}
        else if(stage==113) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);s_exploreFrames=scenes;}
        else if(stage==114) {if(!(objects&128) || animation!=4 || track!=1 || elapsed<30 || scenes<=s_exploreFrames)return;}
#endif
        g_exploreRouteStage=stage+1;g_exploreRouteTick=ticks;aitdInputExploreCheckpoint();return;
    }
#endif
#ifndef AITD_LAMP_STAIRS
    // This fixture starts at heading zero. Let each original quarter-turn
    // reach its cardinal endpoint instead of cutting it short: early release
    // compounds angular error and can steer the approach into the partition.
    if(stage==3 || stage==7 || stage==11 || stage==15) {
        const uint16_t target=stage==7 ? 512 : stage==15 ? 0 : 256;
        if(beta!=target)return;
        aitdInputInjectProbeKey(stage==3 || stage==7 ? 0x4f : 0x4e,false);
        g_exploreRouteStage=stage+1;g_exploreRouteTick=ticks;
        aitdInputExploreCheckpoint();return;
    }
#endif
    if(!stage)aitdInputInjectProbeKey(0x4d,true);
    else if(stage==1) {if(z<1000)return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==3) {if(beta<240 || beta>=512)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==5) {if(x<4100)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==7) {if(beta<496 || beta>=768)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==9) {if(z<3600)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==11) {
#ifdef AITD_HALLWAY
        if(beta<240 || beta>272)return;
#else
        if(beta<240 || beta>280)return;
#endif
        aitdInputInjectProbeKey(0x4e,false);
    }
    else if(stage==13) {if(x<6650)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==15) {
#ifdef AITD_COMBAT_ROUTE
        if(beta>16 && beta<1008)return;
#else
        if(beta>32 && beta<992)return;
#endif
        aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==17) {if(floor!=1)return;aitdInputInjectProbeKey(0x4c,false);}
    else {
        // Reach the doorway before turning east. Coasting after release differs
        // with frame rate; the standalone stairs fixture needs this too.
        if(stage==10) {
            if(ticks-g_exploreRouteTick<30 || !exploreAligned(z,3920,4070,true,animation))return;
        }
        if(animation!=4 || ticks-g_exploreRouteTick<30)return;
        const uint8_t key=stage==2 || stage==6 ? 0x4f : stage==10 || stage==14 ? 0x4e : 0x4c;
        aitdInputInjectProbeKey(key,true);
    }
    g_exploreRouteStage=stage+1;g_exploreRouteTick=ticks;
    if(g_exploreRouteStage==18)s_exploreFrames=scenes;
    aitdInputExploreCheckpoint();
}
#endif

#ifdef AITD_ROOM5_RETURN
extern "C" { volatile uint32_t g_activeGameplayTicks=0,g_activeMoveTicks=0,g_activeTurnTicks=0,g_activeKickTicks=0,g_activeGameplaySamples=0; }
void aitdInputMeasureActivity(uint32_t ticks,uint16_t animation,uint16_t room,bool ready)
{
    static uint32_t previousTick=0;
    static uint16_t previousRoom=0;
    static uint8_t previousKind=0;
    uint8_t kind=0;
    if(ready) {
        if((animation==254 || animation==256) && (s_keyDown[0x4c] || s_keyDown[0x4d]))kind=1;
        else if((animation==257 || animation==258) && (s_keyDown[0x4e] || s_keyDown[0x4f]))kind=2;
        else if(animation==262 && s_keyDown[0x40] && s_keyDown[0x4c])kind=3;
    }
    const uint32_t delta=ticks-previousTick;
    // Conservative tick coverage: no idle, key-release waits or unsampled gaps.
    if(kind && kind==previousKind && room==previousRoom && delta && delta<=2) {
        g_activeGameplayTicks+=delta;++g_activeGameplaySamples;
        if(kind==1)g_activeMoveTicks+=delta;
        else if(kind==2)g_activeTurnTicks+=delta;
        else g_activeKickTicks+=delta;
    }
    previousTick=ticks;previousRoom=room;previousKind=kind;
}
#endif

#ifdef AITD_COMBAT_ROUTE
extern "C" { volatile uint16_t g_combatRouteStage=0,g_combatFightEvent=0,g_combatSawEnemy=0,g_combatAttempts=1,g_combatAimHeading=0,g_combatKicks=0;
volatile uint32_t g_combatRouteTick=0; }
extern "C" __attribute__((noinline)) void aitdInputCombatCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
extern "C" __attribute__((noinline)) void aitdInputCombatAttackCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
void aitdInputCombatEvent(uint16_t what,uint32_t message)
{
#ifdef AITD_ROOM5_COMBAT
    const uint16_t stage=1;
#else
    const uint16_t stage=25;
#endif
    if(g_combatRouteStage==stage && what==3 && (message&255)=='f')g_combatFightEvent=1;
#ifdef AITD_ROOM5_RETURN
    if(g_combatRouteStage>=23 && what==3 && (message&255)=='o')++g_returnOpenEvents;
#endif
}
extern "C" __attribute__((noinline)) void aitdInputCombatAimCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
extern "C" __attribute__((noinline)) void aitdInputCombatKickCheckpoint()
{ __asm__ volatile("nop" ::: "memory"); }
static uint8_t s_combatAimKey=0;
#ifdef AITD_ROOM5_COMBAT
static bool s_combatTurnTest=true;
#else
static bool s_combatTurnTest=false;
#endif
#ifdef AITD_ROOM5_RETURN
static uint8_t s_returnRecoveryPhase=0,s_returnRecoveryTurnKey=0;
static uint32_t s_returnRecoveryTick=0;
#ifdef AITD_ROOM3_ROUTE
static uint8_t s_bathroomRetryPhase=0,s_bathroomHallPhase=0;
static uint32_t s_bathroomRetryTick=0,s_bathroomHallTick=0;
#endif
#endif
static uint32_t s_combatFrames=0,s_combatAttackTick=0;
static uint8_t s_combatAttackState=0;
#ifdef AITD_ROOM4_RECOVERY
void aitdInputCombatRecoveryBegin(uint32_t ticks)
{
    for(uint8_t k=0x4c;k<=0x4f;++k)aitdInputInjectProbeKey(k,false);
    aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x18,false);aitdInputInjectProbeKey(0x23,false);
    s_combatAttackState=0;s_combatAttackTick=ticks;
}
#endif
void aitdInputCombat(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t track,uint16_t objects,int16_t enemyX,int16_t enemyZ,bool ready)
{
#ifdef AITD_ROOM5_COMBAT
    const uint16_t prefix=52,attackStage=21,
#ifdef AITD_ROOM3_ROUTE
        terminal=66;
#elif defined(AITD_ROOM4_ROUTE)
        terminal=53;
#elif defined(AITD_ROOM5_RETURN)
        terminal=48;
#else
        terminal=23;
#endif
#else
    const uint16_t prefix=64,attackStage=34,terminal=36;
#endif
#ifdef AITD_ROOM5_RETURN
    if(g_combatRouteStage && g_combatRouteStage<terminal && !ready) {
        for(uint8_t key=0x4c;key<=0x4f;++key)aitdInputInjectProbeKey(key,false);
        aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x18,false);
        g_combatRouteStage=0xffff;aitdInputCombatCheckpoint();return;
    }
#endif
    if(g_exploreRouteStage!=prefix || !ready || g_combatRouteStage>=terminal)return;
    const uint16_t stage=g_combatRouteStage;
    const uint32_t elapsed=ticks-g_combatRouteTick;
    beta&=1023;
    if((stage && elapsed>(stage==attackStage ? 36000UL : 2400UL)) || !(objects&16)) {
        aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x4d,false);aitdInputInjectProbeKey(0x40,false);
        aitdInputInjectProbeKey(0x44,false);aitdInputInjectProbeKey(0x18,false);aitdInputInjectProbeKey(0x23,false);
        g_combatRouteStage=0xffff;aitdInputCombatCheckpoint();return;
    }
#ifdef AITD_ROOM5_RETURN
    if(stage>=23) {
        if(stage==23) {if(animation!=4 || track!=1)return;aitdInputInjectProbeKey(0x18,true);}
        else if(stage==24) {if(elapsed<120)return;aitdInputInjectProbeKey(0x18,false);}
        else if(stage==25) {
            if(!(objects&16384)) {
                // A command can arrive while the original frame is still busy.
                // Retry ordinary O presses, bounded by the phase deadline; only
                // the real Open/Search state permits movement to continue.
                if(elapsed>=300) {
                    const bool down=elapsed%300<120;
                    if(aitdInputKeyDown(0x18)!=down)aitdInputInjectProbeKey(0x18,down);
                }
                return;
            }
            if(aitdInputKeyDown(0x18))aitdInputInjectProbeKey(0x18,false);
            // Combat can leave Carnby in the connecting-door pocket. Clear
            // east into the measured corridor before the northward Search leg.
            if(!s_returnRecoveryPhase) {
                if(animation!=4 || track!=1 || elapsed<30)return;
                const uint16_t delta=(256-beta)&1023;
                if(delta>16 && delta<1008) {
                    s_returnRecoveryTurnKey=delta>512 ? 0x4f : 0x4e;
                    aitdInputInjectProbeKey(s_returnRecoveryTurnKey,true);
                    s_returnRecoveryPhase=1;
                } else s_returnRecoveryPhase=2;
                s_returnRecoveryTick=ticks;return;
            }
            if(s_returnRecoveryPhase==1) {
                const uint16_t delta=(256-beta)&1023;
                if(delta>16 && delta<1008)return;
                aitdInputInjectProbeKey(s_returnRecoveryTurnKey,false);
                s_returnRecoveryPhase=2;s_returnRecoveryTick=ticks;return;
            }
            if(s_returnRecoveryPhase==2) {
                if(animation!=4 || track!=1 || ticks-s_returnRecoveryTick<30)return;
                if(x<-1800) {
                    aitdInputInjectProbeKey(0x4c,true);s_returnRecoveryPhase=3;
                } else s_returnRecoveryPhase=4;
                s_returnRecoveryTick=ticks;return;
            }
            if(s_returnRecoveryPhase==3) {
                if(x<-1800)return;
                aitdInputInjectProbeKey(0x4c,false);
                s_returnRecoveryPhase=4;s_returnRecoveryTick=ticks;return;
            }
            if(s_returnRecoveryPhase==4) {
                if(ticks-s_returnRecoveryTick<30 || !exploreAligned(x,-1700,-1550,true,animation))return;
                s_returnRecoveryPhase=5;
            }
            if(animation!=4 || elapsed<30)return;
            if(beta>16 && beta<1008)aitdInputInjectProbeKey(0x4e,true);
        }
        else if(stage==26) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==27) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==28) {if(z>0)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==29) {if(elapsed<30 || !exploreAligned(z,-280,-100,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==30) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==31) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==32) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
#ifdef AITD_ROOM4_ROUTE
        // The original crossing can complete during key release. Observe the
        // actual destination before consulting coordinates in the new room.
        else if(stage==33) {if(animation!=4 || elapsed<120)return;aitdInputInjectProbeKey(0x4f,true);}
        else if(stage==34) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4f,false);}
        else if(stage==35) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==36) {if(z<600)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==37) {if(elapsed<30 || !exploreAligned(z,650,850,true,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==38) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==39) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==40) {if(!(objects&32768))return;aitdInputInjectProbeKey(0x4c,false);s_combatFrames=scenes;}
        else if(stage==41) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_combatFrames)return;}
        else if(stage==42) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==43) {if(x>100)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==44) {if(elapsed<30 || !exploreAligned(x,-200,100,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==45) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==46) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==47) {if(!(objects&8192) && z>-1600)return;aitdInputInjectProbeKey(0x4c,false);s_combatFrames=scenes;}
        else if(stage==48) {
            if(animation!=4 || track!=1 || elapsed<30)return;
            if(objects&8192) {
                if(scenes<=s_combatFrames)return;
                g_combatRouteStage=53;g_combatRouteTick=ticks;aitdInputCombatCheckpoint();return;
            }
            aitdInputInjectProbeKey(0x40,true);
        }
        else if(stage==49) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==50) {if(animation!=4 || elapsed<120)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==51) {if(!(objects&8192))return;aitdInputInjectProbeKey(0x4c,false);s_combatFrames=scenes;}
        else if(stage==52) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_combatFrames)return;}
#ifdef AITD_ROOM3_ROUTE
        else if(stage==53) {
            // Clear the room-4 doorway before going west to the bathroom,
            // as in the verified original continuous first-floor circuit.
            if(!s_bathroomHallPhase) {
                if(animation!=4 || elapsed<30 || !(objects&8192))return;
                s_bathroomHallPhase=z>0 ? 1 : 2;s_bathroomHallTick=ticks;
                if(s_bathroomHallPhase==1)aitdInputInjectProbeKey(0x4c,true);
                return;
            }
            if(s_bathroomHallPhase==1) {
                // Room flags can cross back during the doorway's release step.
                // Keep walking; inspect hallway coordinates only in room 1.
                if(!(objects&8192) || z>0)return;
                aitdInputInjectProbeKey(0x4c,false);s_bathroomHallPhase=2;s_bathroomHallTick=ticks;return;
            }
            if(s_bathroomHallPhase==3) {
                if(animation!=4 || ticks-s_bathroomHallTick<30)return;
                aitdInputInjectProbeKey(0x4c,true);s_bathroomHallPhase=1;return;
            }
            if(!(objects&8192)) {
                // Cancel a held alignment step before recovering forward.
                // Opposed held arrows otherwise keep moving back into room 4.
                aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x4d,false);
                g_exploreAlignment=0;s_bathroomHallPhase=3;s_bathroomHallTick=ticks;return;
            }
            if(ticks-s_bathroomHallTick<30)return;
            // The alignment helper must see the moving animation to release
            // its held key; waiting for idle here prevents that release.
            if(!exploreAligned(z,-150,0,false,animation))return;
            aitdInputInjectProbeKey(0x4f,true);
        }
        else if(stage==54) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4f,false);}
        else if(stage==55) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==56) {if(x>-650)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==57) {if(elapsed<30 || !exploreAligned(x,-900,-700,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==58) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==59) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==60) {if(!(objects&128) && z>-850)return;aitdInputInjectProbeKey(0x4c,false);s_combatFrames=scenes;}
        else if(stage==61) {
            if(animation!=4 || track!=1 || elapsed<30)return;
            if(objects&128) {
                if(scenes<=s_combatFrames)return;
                g_combatRouteStage=66;g_combatRouteTick=ticks;aitdInputCombatCheckpoint();return;
            }
            aitdInputInjectProbeKey(0x40,true);
        }
        else if(stage==62) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==63) {if(animation!=4 || elapsed<120)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==64) {
            if(!(objects&128)) {
                // An early Open/Search can move closer without crossing. Retry
                // only after releasing the blocked walk and returning to idle.
                const uint32_t retryElapsed=ticks-s_bathroomRetryTick;
                if(!s_bathroomRetryPhase) {
                    if(elapsed<300)return;
                    aitdInputInjectProbeKey(0x4c,false);s_bathroomRetryPhase=1;s_bathroomRetryTick=ticks;
                } else if(s_bathroomRetryPhase==1) {
                    if(animation!=4 || retryElapsed<30)return;
                    aitdInputInjectProbeKey(0x40,true);s_bathroomRetryPhase=2;s_bathroomRetryTick=ticks;
                } else if(s_bathroomRetryPhase==2) {
                    if(retryElapsed<120)return;
                    aitdInputInjectProbeKey(0x40,false);s_bathroomRetryPhase=3;s_bathroomRetryTick=ticks;
                } else if(s_bathroomRetryPhase==3) {
                    if(animation!=4 || retryElapsed<120)return;
                    aitdInputInjectProbeKey(0x4c,true);s_bathroomRetryPhase=4;s_bathroomRetryTick=ticks;
                } else {
                    if(retryElapsed<300)return;
                    aitdInputInjectProbeKey(0x4c,false);s_bathroomRetryPhase=1;s_bathroomRetryTick=ticks;
                }
                return;
            }
            aitdInputInjectProbeKey(0x4c,false);aitdInputInjectProbeKey(0x40,false);s_combatFrames=scenes;
        }
        else if(stage==65) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_combatFrames)return;}
#endif


#else
        else if(stage==33) {if(animation!=4 || elapsed<120)return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==34) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==35) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==36) {if(z>-1500)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==37) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==38) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==39) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==40) {if(x>-2240)return;aitdInputInjectProbeKey(0x4c,false);}
        else if(stage==41) {if(elapsed<30 || !exploreAligned(x,-2400,-2200,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
        else if(stage==42) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
        else if(stage==43) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);}
        else if(stage==44) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);}
        else if(stage==45) {if(animation!=4 || elapsed<120)return;aitdInputInjectProbeKey(0x4c,true);}
        else if(stage==46) {
            // MacLoader readiness covers room 5 and the hallway; object bit 8192
            // records the real room 1 transition, not an x/z threshold.
            if(!(objects&8192))return;aitdInputInjectProbeKey(0x4c,false);s_combatFrames=scenes;
        }
        else if(stage==47) {if(animation!=4 || track!=1 || elapsed<30 || scenes<=s_combatFrames)return;}
#endif
        g_combatRouteStage=stage+1;g_combatRouteTick=ticks;aitdInputCombatCheckpoint();return;
    }
#endif
#ifdef AITD_ROOM5_COMBAT
    if(!stage) {
        if(!(objects&1) || !(objects&256) || animation!=4 || track!=1)return;
        g_combatSawEnemy=1;aitdInputInjectProbeKey(0x23,true);
    }
    else if(stage==1) {if(elapsed<120 || !g_combatFightEvent || !(objects&512))return;aitdInputInjectProbeKey(0x23,false);}
    else if(stage==2) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==3) {if(z<-1200)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==4) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4f,true);}
    else if(stage==5) {if(beta<240 || beta>272)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==6) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==7) {if(x<-1600)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==8) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
    else if(stage==9) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==10) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==11) {if(z<-200)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==12) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
    else if(stage==13) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==14) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==15) {if(!(objects&2) && x>-1650)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==16) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4e,true);}
    else if(stage==17) {if(beta>16 && beta<1008)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==18) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==19) {if(z>-650 && !(objects&4096))return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==20) {if(animation!=4 || elapsed<30)return;}
#else
    if(!stage) {if(!(objects&1))return;g_combatSawEnemy=1;aitdInputInjectProbeKey(0x4e,true);}
    else if(stage==1) {if(beta<240 || beta>272)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==2) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==3) {if(x<600)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==4) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4f,true);}
    else if(stage==5) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==6) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==7) {if(z<900)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==8) {if(elapsed<30 || !exploreAligned(z,1200,1380,true,animation))return;aitdInputInjectProbeKey(0x4f,true);}
    else if(stage==9) {if(beta<752 || beta>784)return;aitdInputInjectProbeKey(0x4f,false);}
    else if(stage==10) {if(animation!=4 || elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==11) {if(x>850)return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==12) {if(elapsed<30 || !exploreAligned(x,600,800,false,animation))return;aitdInputInjectProbeKey(0x4e,true);}
    else if(stage==13) {if(beta<496 || beta>528)return;aitdInputInjectProbeKey(0x4e,false);}
    else if(stage==14) {if(animation!=4 || track!=1 || elapsed<30)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==15 || stage==17 || stage==23) {if(elapsed<8)return;aitdInputInjectProbeKey(0x44,false);}
    else if(stage==16) {if(elapsed<180)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==18) {if(elapsed<180)return;aitdInputInjectProbeKey(0x4d,true);}
    else if(stage==19) {if(!(objects&32))return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==20) {if(elapsed<120)return;aitdInputInjectProbeKey(0x4d,true);}
    else if(stage==21) {if(!(objects&128))return;aitdInputInjectProbeKey(0x4d,false);}
    else if(stage==22) {if(elapsed<120)return;aitdInputInjectProbeKey(0x44,true);}
    else if(stage==24) {if(!(objects&64) || !(objects&256) || animation!=4 || track!=1 || elapsed<120)return;aitdInputInjectProbeKey(0x23,true);}
    else if(stage==25) {if(elapsed<120 || !g_combatFightEvent || !(objects&512))return;aitdInputInjectProbeKey(0x23,false);}
    else if(stage==26) {if(elapsed<30)return;aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==27) {if(!(objects&2))return;aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==28) {if(animation!=4 || track!=1 || elapsed<30)return;}
    else if(stage==29) {if(elapsed<30)return;}
    else if(stage==30) {if(animation!=4 || track!=1 || elapsed<30)return;aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4c,true);}
    else if(stage==31) {if(animation!=262)return;}
    else if(stage==32) {if(elapsed<120)return;aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x4c,false);}
    else if(stage==33) {if(animation!=4 || track!=1 || elapsed<30)return;}
#endif
    else if(stage==attackStage) {
        if((objects&8) && g_combatSawEnemy) {
            aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x4c,false);
            aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);s_combatFrames=scenes;
        } else {
#ifdef AITD_ROOM5_RETURN
#ifdef AITD_ROOM4_RECOVERY
            if(g_room4RecoveryStage>=12) {
#endif
            // The measured recovery walks once to the enemy, then keeps the
            // kick held until actual death. Releasing and walking repeatedly
            // let the original enemy knock Carnby too far away to survive.
            if(objects&2048) {
                aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x4c,false);
                aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);return;
            }
            if(s_combatAttackState && ticks-s_combatAttackTick>12000) {
                aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x4c,false);
                aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);
                g_combatRouteStage=0xffff;aitdInputCombatCheckpoint();return;
            }
            const int32_t dx=enemyX,dz=enemyZ;
            const uint32_t ax=dx<0 ? -dx : dx,az=dz<0 ? -dz : dz;
            if(s_combatAttackState==4) {
                const uint16_t delta=(g_combatAimHeading-beta)&1023;
                if(delta>16 && delta<1008)return;
                aitdInputInjectProbeKey(s_combatAimKey,false);
                s_combatAttackState=5;s_combatAttackTick=ticks;aitdInputCombatAimCheckpoint();return;
            }
            if(s_combatAttackState==7) {
                if(!(objects&1024) || (ax>800 || az>800))return;
                aitdInputInjectProbeKey(0x4c,false);s_combatAttackState=8;s_combatAttackTick=ticks;
                aitdInputCombatAimCheckpoint();return;
            }
            if(s_combatAttackState==1) {
                if(animation==262) {
                    ++g_combatKicks;aitdInputCombatKickCheckpoint();s_combatAttackState=2;
                }
                return;
            }
            if(s_combatAttackState==2)return;
            if(animation!=4 || track!=1 || !(objects&256) || !(objects&512) ||
                (s_combatAttackState && ticks-s_combatAttackTick<30) || !(objects&1024))return;
            if(!s_combatAttackState) {
                // The measured cardinal aiming also works when low frame
                // rates skip the intermediate angles of an original turn.
                g_combatAimHeading=ax>az ? (dx>0 ? 256 : 768) : (dz>0 ? 512 : 0);
                const uint16_t delta=(g_combatAimHeading-beta)&1023;
                if(delta>16 && delta<1008) {
                    s_combatAimKey=delta>512 ? 0x4f : 0x4e;
                    aitdInputInjectProbeKey(s_combatAimKey,true);s_combatAttackState=4;s_combatAttackTick=ticks;
                    aitdInputCombatAimCheckpoint();return;
                }
                s_combatAttackState=5;
            }
            if(s_combatAttackState==5 && (ax>800 || az>800)) {
                aitdInputInjectProbeKey(0x4c,true);s_combatAttackState=7;s_combatAttackTick=ticks;
                aitdInputCombatAimCheckpoint();return;
            }
            ++g_combatAttempts;aitdInputCombatAttackCheckpoint();
            aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4c,true);
            s_combatAttackState=1;s_combatAttackTick=ticks;return;
#ifdef AITD_ROOM4_RECOVERY
            }
#endif
#endif
            if(s_combatAttackState && ticks-s_combatAttackTick>1800) {g_combatRouteStage=0xffff;aitdInputCombatCheckpoint();return;}
            if(s_combatAttackState==1) {
                if(animation==262) {++g_combatKicks;aitdInputCombatKickCheckpoint();s_combatAttackState=2;}
                else if(ticks-s_combatAttackTick<180)return;
                // A hit can interrupt the queued kick. Release the input even
                // when no kick began, so the original release wait can finish.
                else s_combatAttackState=2;
            }
            if(s_combatAttackState==2) {
                if(ticks-s_combatAttackTick<180)return;
                aitdInputInjectProbeKey(0x40,false);aitdInputInjectProbeKey(0x4c,false);s_combatAttackState=3;s_combatAttackTick=ticks;return;
            }
            if(objects&2048) { // Let the original death animation remove its actor.
                aitdInputInjectProbeKey(0x4c,false);
                aitdInputInjectProbeKey(0x4e,false);aitdInputInjectProbeKey(0x4f,false);return;
            }
            if(s_combatAttackState==4 || s_combatAttackState==6) {
                const uint16_t delta=(g_combatAimHeading-beta)&1023;
                if(delta>16 && delta<1008)return;
                aitdInputInjectProbeKey(s_combatAimKey,false);s_combatAttackState=s_combatAttackState==6 ? 3 : 5;s_combatAttackTick=ticks;
                aitdInputCombatAimCheckpoint();return;
            }
            if(animation!=4 || track!=1 || (s_combatAttackState>=3 && ticks-s_combatAttackTick<30))return;
            // Exercise a deliberate turn before re-aiming, on both references.
            if(!s_combatTurnTest && (objects&1024)) {
                s_combatTurnTest=true;g_combatAimHeading=768;
                const uint16_t delta=(768-beta)&1023;
                if(delta>16 && delta<1008) {
                    s_combatAimKey=delta>512 ? 0x4f : 0x4e;
                    aitdInputInjectProbeKey(s_combatAimKey,true);s_combatAttackState=6;s_combatAttackTick=ticks;
                    aitdInputCombatAimCheckpoint();return;
                }
            }
            if(s_combatAttackState!=5 && (objects&1024)) {
#ifdef AITD_ROOM5_RETURN
                const int32_t dx=enemyX,dz=enemyZ;
#else
                const int32_t dx=int32_t(enemyX)-x,dz=int32_t(enemyZ)-z;
#endif
                const uint32_t ax=dx<0 ? -dx : dx,az=dz<0 ? -dz : dz;
                g_combatAimHeading=ax>az ? (dx>0 ? 256 : 768) : (dz>0 ? 512 : 0);
                const uint16_t delta=(g_combatAimHeading-beta)&1023;
                if(delta>16 && delta<1008) {
                    s_combatAimKey=delta>512 ? 0x4f : 0x4e;
                    aitdInputInjectProbeKey(s_combatAimKey,true);s_combatAttackState=4;s_combatAttackTick=ticks;
                    aitdInputCombatAimCheckpoint();return;
                }
            }
#ifdef AITD_ROOM5_RETURN
            const uint16_t attemptLimit=64;
#else
            const uint16_t attemptLimit=32;
#endif
            if(g_combatAttempts>=attemptLimit) {g_combatRouteStage=0xffff;aitdInputCombatCheckpoint();return;}
            ++g_combatAttempts;aitdInputCombatAttackCheckpoint();
            aitdInputInjectProbeKey(0x40,true);aitdInputInjectProbeKey(0x4c,true);s_combatAttackState=1;s_combatAttackTick=ticks;return;
        }
    }
    else if(stage==attackStage+1) {if(!(objects&8) || animation!=4 || track!=1 || elapsed<30 || scenes<=s_combatFrames)return;}
    g_combatRouteStage=stage+1;g_combatRouteTick=ticks;aitdInputCombatCheckpoint();
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
