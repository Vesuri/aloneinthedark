#include "platform/amiga/M5Audit.h"
#ifdef AITD_WINDOW_PROBE
#include <proto/dos.h>
#include <proto/exec.h>
#include <exec/execbase.h>
#include <exec/memory.h>
#include <exec/interrupts.h>
#include <hardware/custom.h>
#include <hardware/intbits.h>
#include <hardware/dmabits.h>
#include "FileAccess.h"
#include "MacInput.h"
#include "mac/MacLoader.h"
extern "C" int aitdResloadBridgeProbe();
extern "C" void aitdResloadSwitchProbe();
extern "C" bool aitdMacKeyReleaseProbe();
extern "C" bool aitdMacKeyEventProbe();
extern "C" {
extern volatile uint32_t g_macTicks,g_windowFields,g_systemWindows;
extern volatile uint32_t* g_macTicksAddress;
volatile uint32_t g_windowProbeAudio=0,g_windowProbeAudioInside=0,g_windowProbeAudioWindows=0;
extern volatile uint16_t g_vbiCount,g_systemWindowActive;
volatile uint32_t g_windowProbeIOChecks=0,g_windowProbeKeyChecks=0;
volatile uint32_t g_windowProbeChunk=0,g_windowProbeDone=0,g_windowProbeError=0;
volatile uint32_t g_windowProbeHash=2166136261UL,g_windowProbeTicks=0,g_windowProbeFields=0;
uint8_t* g_windowProbePicture=0;
__attribute__((noinline)) void aitdWindowProbeBefore() { __asm__ volatile("" ::: "memory"); }
__attribute__((noinline)) void aitdWindowProbeInside()
{
    static uint32_t previous=0;
    if(g_windowProbeAudioInside>previous)++g_windowProbeAudioWindows;
    previous=g_windowProbeAudioInside;
    if(g_windowProbeChunk && g_systemWindows<16) {
        if(aitdInputKeyDown(0x20)!=(g_windowProbeChunk<=8))g_windowProbeError=17;
        ++g_windowProbeKeyChecks;
        if(g_windowProbeChunk==8)aitdInputInjectProbeKey(0x20,false);
    }
}
__attribute__((noinline)) void aitdWindowProbeAfter() { __asm__ volatile("" ::: "memory"); }
}
static uint8_t buffer[65536];
static volatile Custom* const custom=(volatile Custom*)0xdff000;
static uint32_t audioInterrupt()
{
    custom->intreq=INTF_AUD0;
    ++g_windowProbeAudio;
    if(g_systemWindowActive)++g_windowProbeAudioInside;
    return 0;
}
// Diagnostic-only silent DMA; no game sound driver is installed at this stage.
struct AudioProbe {
    void* sample;
    IntVector saved;
    AudioProbe(): sample(M5_ALLOC_MEM(1024,MEMF_CHIP|MEMF_CLEAR)) {
        if(!sample)return;
        Disable();
        saved=SysBase->IntVects[INTB_AUD0];
        SysBase->IntVects[INTB_AUD0].iv_Data=0;
        SysBase->IntVects[INTB_AUD0].iv_Code=(void(*)())audioInterrupt;
        custom->aud[0].ac_ptr=(UWORD*)sample;
        custom->aud[0].ac_len=512;
        custom->aud[0].ac_per=124;
        custom->aud[0].ac_vol=0;
        custom->intreq=INTF_AUD0;
        custom->intena=INTF_SETCLR|INTF_AUD0;
        custom->dmacon=DMAF_SETCLR|DMAF_AUD0;
        Enable();
    }
    ~AudioProbe() {
        if(!sample)return;
        Disable();
        custom->dmacon=DMAF_AUD0;
        custom->intena=INTF_AUD0;
        custom->intreq=INTF_AUD0;
        SysBase->IntVects[INTB_AUD0]=saved;
        Enable();
        M5_FREE_MEM(sample,1024);
    }
};
static bool probeKeyMap()
{
    struct Step { uint8_t raw,down,byte,value; };
    const Step steps[]={
        {0x20,1,0,1}, {0x40,1,6,2}, {0x20,0,0,0}, {0x40,0,6,0},
        {0x60,1,7,1}, {0x61,1,7,1}, {0x60,0,7,1}, {0x61,0,7,0},
        {0x4f,1,15,8}, {0x4f,0,15,0}
    };
    uint8_t expected[16]={0},guarded[24];
    if(aitdMacGetKeys(0))return false;
    for(uint16_t n=0;n<=sizeof(steps)/sizeof(steps[0]);++n) {
        if(n) {
            const Step& step=steps[n-1];
            aitdInputInjectProbeKey(step.raw,step.down!=0);
            expected[step.byte]=step.value;
        }
        for(uint16_t i=0;i<24;++i)guarded[i]=0xcc;
        if(!aitdMacGetKeys(guarded+4))return false;
        for(uint16_t i=0;i<24;++i)
            if(guarded[i]!=(i>=4 && i<20 ? expected[i-4] : 0xcc))return false;
        ++g_windowProbeKeyChecks;
    }
    // Polling must leave the event queue available to GetNextEvent.
    uint8_t raw;bool down;uint16_t modifiers;
    for(uint16_t i=0;i<sizeof(steps)/sizeof(steps[0]);++i)
        if(!aitdInputPopKey(raw,down,modifiers) || raw!=steps[i].raw
           || down!=(steps[i].down!=0))return false;
    if(aitdInputPopKey(raw,down,modifiers))return false;
    return true;
}
extern "C" bool aitdWindowProbe()
{
    if(!aitdResloadBridgeProbe()) { g_windowProbeError=8;return false; }
    if(!probeKeyMap() || !aitdMacKeyReleaseProbe() || !aitdMacKeyEventProbe()) { g_windowProbeError=16;return false; }
    // A Return released while WHDLoad owns the host OS has no guest key-up.
    aitdInputInjectProbeKey(0x44,true);
    aitdResloadSwitchProbe();
    if(!aitdResloadBridgeProbe()) { g_windowProbeError=17;return false; }
    uint8_t staleRaw;bool staleDown;uint16_t staleModifiers;
    uint8_t liveKeys[16];aitdMacGetKeys(liveKeys);
    if(aitdInputKeyDown(0x44) || (liveKeys[4]&0x10)
        || aitdInputPopKey(staleRaw,staleDown,staleModifiers)) {
        g_windowProbeError=17;return false;
    }
    aitdInputInjectProbeKey(0x44,true);
    if(!aitdInputPopKey(staleRaw,staleDown,staleModifiers) || staleRaw!=0x44 || !staleDown) {
        g_windowProbeError=17;return false;
    }
    aitdInputInjectProbeKey(0x44,false);
    aitdInputPopKey(staleRaw,staleDown,staleModifiers);
    AudioProbe audio;
    if(!audio.sample) { g_windowProbeError=5;return false; }
    aitdWindowProbeBefore();
    Disable();
    uint32_t startTicks=g_macTicks;
    uint16_t startFields=g_vbiCount;
    Enable();
    aitdInputInjectProbeKey(0x20,true);
    for(uint32_t chunk=0;chunk<16;++chunk) {
        g_windowProbeChunk=chunk+1;
        uint32_t actual=0;
        int32_t error=FileAccess::dos.readAt("PROGDIR:WindowProbe.bin",chunk*65536,buffer,65536,actual);
        if(error || actual!=65536) { g_windowProbeError=1;return false; }
        for(uint32_t i=0;i<65536;++i) {
            uint32_t offset=chunk*65536+i;
            uint8_t expected=(offset*17+(offset>>8)*29+(offset>>16)*71)&255;
            if(buffer[i]!=expected) { g_windowProbeError=2;return false; }
            g_windowProbeHash=(g_windowProbeHash^buffer[i])*16777619UL;
        }
    }
    Disable();
    g_windowProbeTicks=g_macTicks-startTicks;
    g_windowProbeFields=(uint16_t)(g_vbiCount-startFields);
    bool clockMatches=g_macTicksAddress && *g_macTicksAddress==g_macTicks;
    Enable();
    uint32_t expectedTicks=g_windowProbeFields*6/5;
    if(!clockMatches || g_windowProbeTicks<expectedTicks || g_windowProbeTicks>expectedTicks+1) {
        g_windowProbeError=6;return false;
    }
    if(g_windowProbeAudioWindows!=16 || !g_windowProbeAudioInside
        || g_windowProbeAudio<=g_windowProbeAudioInside) { g_windowProbeError=7;return false; }
    uint8_t key;bool down;uint16_t mods;
    if(g_windowProbeError)return false;
    if(aitdInputKeyDown(0x20)
       || !aitdInputPopKey(key,down,mods) || key!=0x20 || !down
       || !aitdInputPopKey(key,down,mods) || key!=0x20 || down
       || aitdInputPopKey(key,down,mods)) { g_windowProbeError=3;return false; }
    if(g_systemWindowActive || g_systemWindows!=16 || g_windowFields<16) { g_windowProbeError=4;return false; }
    // The primary 16-window clock/audio checks precede these five DOS operations.
    uint32_t actual=123;
    if(FileAccess::dos.readAt("PROGDIR:WindowProbe.missing",0,buffer,1,actual)!=FileAccess::notFound
        || actual) { g_windowProbeError=9;return false; }
    ++g_windowProbeIOChecks;
    if(FileAccess::dos.readAt("PROGDIR:WindowProbe.bin",1048576-7,buffer,32,actual)
        || actual!=7) { g_windowProbeError=10;return false; }
    ++g_windowProbeIOChecks;
    if(FileAccess::dos.readAt("PROGDIR:WindowProbe.bin",1048576,buffer,32,actual)
        || actual) { g_windowProbeError=11;return false; }
    ++g_windowProbeIOChecks;
    for(uint32_t i=0;i<32;++i)buffer[i]=(uint8_t)(i^0xa5);
    if(FileAccess::dos.save("PROGDIR:WindowProbe.saved",buffer,32)) { g_windowProbeError=12;return false; }
    ++g_windowProbeIOChecks;
    for(uint32_t i=0;i<32;++i)buffer[i]=0;
    if(FileAccess::dos.readAt("PROGDIR:WindowProbe.saved",0,buffer,32,actual)
        || actual!=32) { g_windowProbeError=13;return false; }
    for(uint32_t i=0;i<32;++i)
        if(buffer[i]!=(uint8_t)(i^0xa5)) { g_windowProbeError=14;return false; }
    ++g_windowProbeIOChecks;
    if(FileAccess::dos.save("PROGDIR:WindowProbe.saved",buffer,65537)!=FileAccess::invalid
        || FileAccess::dos.readAt("PROGDIR:WindowProbe.bin",0,buffer,65537,actual)!=FileAccess::invalid
        || actual || g_systemWindows!=21) { g_windowProbeError=15;return false; }
    g_windowProbeDone=1;
    aitdWindowProbeAfter();
    return true;
}
#endif
