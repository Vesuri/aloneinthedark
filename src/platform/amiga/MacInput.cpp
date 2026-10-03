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

void aitdInputSuspend()
{
    if(!s_ciaaBase)return;
    RemICRVector(s_ciaaBase,CIAICRB_SP,&s_keyboardInterrupt);
    if(s_savedVector)AddICRVector(s_ciaaBase,CIAICRB_SP,s_savedVector);
}
// Only call while the OS owns the keyboard vector: no port ISR can race
// these stores, so display/audio interrupts need not be masked for the loop.
void aitdInputFlush()
{
    for(uint16_t i=0;i<128;++i)s_keyDown[i]=0;
    aitdMacReleaseKeys();
    s_head=s_tail=0;
}
void aitdInputResume()
{
    if(!s_ciaaBase)return;
    if(s_savedVector)RemICRVector(s_ciaaBase,CIAICRB_SP,s_savedVector);
    AddICRVector(s_ciaaBase,CIAICRB_SP,&s_keyboardInterrupt);
}
