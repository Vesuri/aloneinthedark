#ifdef AITD_M5_AUDIT
#include <proto/exec.h>
#include <proto/timer.h>
#include <devices/timer.h>
#include <exec/execbase.h>
#include <exec/memory.h>
#include "framework/AmigaHardware.h"
#include "M5Audit.h"
extern "C" {
extern volatile uint16_t g_vbiCount,g_videoPAL;
extern volatile uint32_t g_musicTicks;
extern uint8_t *g_applicationZoneBase,*g_systemZoneBase;
extern uint8_t aitd_song_stack[],aitd_song_deferred_stack[];
struct M5Audit {
    uint32_t clockHz,cpuFlags,totalChip,totalFast,initialChip,initialFast;
    uint32_t liveChip,liveFast,peakChip,peakFast,minFreeChip,minFreeFast;
    uint32_t allocations,failures,accountingErrors,zonePeak[2];
    uint32_t traps,maxGap,gapFrom,gapTo,gapTrap,gapMusicTicks;
    uint32_t irqCalls,irqClocks,irqMaxClocks,irqMinInterval,irqMaxInterval,irqMaxLateEClocks;
    uint32_t noteCount,noteLateCount,noteMaxLate;
    uint32_t activeGap,activeGapTicks,activeGapSong;
} g_m5Audit={};
uint32_t g_m5NoteLog[1024][5]={};
}
static uint32_t s_lastTrap,s_lastPC,s_lastMusic,s_irqBegan,s_lastIRQ;
static bool s_initialized;
static uint16_t s_lastSong;
struct Device* TimerBase=0;
static struct timerequest s_request;
static struct MsgPort* s_port;
// OS-maintained E-clock is monotonic across display wrap and DOS windows.
// Low-word subtraction is valid for bounded sessions shorter than one wrap.
unsigned long aitdM5Clock() {
    struct EClockVal now;
    if(!TimerBase)return 0;
    ReadEClock(&now);return now.ev_lo;
}
void aitdM5Stop() {
    if(TimerBase) {CloseDevice(&s_request.tr_node);TimerBase=0;}
    if(s_port) {DeleteMsgPort(s_port);s_port=0;}
}
void aitdM5Init() {
    if(s_initialized)return;
    s_port=CreateMsgPort();
    if(!s_port) {++g_m5Audit.accountingErrors;return;}
    s_request.tr_node.io_Message.mn_ReplyPort=s_port;
    s_request.tr_node.io_Message.mn_Length=sizeof(s_request);
    if(OpenDevice((CONST_STRPTR)TIMERNAME,UNIT_ECLOCK,&s_request.tr_node,0)) {
        ++g_m5Audit.accountingErrors;aitdM5Stop();return;
    }
    TimerBase=s_request.tr_node.io_Device;
    struct EClockVal now;g_m5Audit.clockHz=ReadEClock(&now);
    g_m5Audit.cpuFlags=SysBase->AttnFlags;
    g_m5Audit.totalChip=AvailMem(MEMF_CHIP|MEMF_TOTAL);
    g_m5Audit.totalFast=AvailMem(MEMF_FAST|MEMF_TOTAL);
    g_m5Audit.initialChip=g_m5Audit.minFreeChip=AvailMem(MEMF_CHIP);
    g_m5Audit.initialFast=g_m5Audit.minFreeFast=AvailMem(MEMF_FAST);
    g_m5Audit.irqMinInterval=0xffffffffUL;
    for(uint32_t i=0;i<8192;++i)aitd_song_stack[i]=aitd_song_deferred_stack[i]=0xa5;
    s_initialized=true;
}
static void memorySample() {
    uint32_t chip=AvailMem(MEMF_CHIP),fast=AvailMem(MEMF_FAST);
    if(chip<g_m5Audit.minFreeChip)g_m5Audit.minFreeChip=chip;
    if(fast<g_m5Audit.minFreeFast)g_m5Audit.minFreeFast=fast;
}
void* aitdM5Alloc(unsigned long bytes,unsigned long flags) {
    void* p=AllocMem(bytes,flags);++g_m5Audit.allocations;
    if(!p) {++g_m5Audit.failures;return p;}
    uint32_t actual=(bytes+7)&~7UL;
    if(TypeOfMem(p)&MEMF_CHIP) {
        g_m5Audit.liveChip+=actual;
        if(g_m5Audit.liveChip>g_m5Audit.peakChip)g_m5Audit.peakChip=g_m5Audit.liveChip;
    } else {
        g_m5Audit.liveFast+=actual;
        if(g_m5Audit.liveFast>g_m5Audit.peakFast)g_m5Audit.peakFast=g_m5Audit.liveFast;
    }
    if(s_initialized)memorySample();
    return p;
}
void aitdM5Free(void* p,unsigned long bytes) {
    uint32_t actual=(bytes+7)&~7UL;
    uint32_t& live=(TypeOfMem(p)&MEMF_CHIP) ? g_m5Audit.liveChip : g_m5Audit.liveFast;
    if(live<actual)++g_m5Audit.accountingErrors;else live-=actual;
    FreeMem(p,bytes);
}
void aitdM5Zone(const void* base,unsigned long used) {
    if(base==g_applicationZoneBase && used>g_m5Audit.zonePeak[0])g_m5Audit.zonePeak[0]=used;
    if(base==g_systemZoneBase && used>g_m5Audit.zonePeak[1])g_m5Audit.zonePeak[1]=used;
}
void aitdM5Trap(unsigned long pc,unsigned short trap,unsigned short song) {
    uint32_t now=aitdM5Clock();
    if(s_lastTrap && now-s_lastTrap>g_m5Audit.maxGap) {
        g_m5Audit.maxGap=now-s_lastTrap;g_m5Audit.gapFrom=s_lastPC;
        g_m5Audit.gapTo=pc;g_m5Audit.gapTrap=trap;
        g_m5Audit.gapMusicTicks=g_musicTicks-s_lastMusic;
    }
    if(s_lastTrap && song && song==s_lastSong && now-s_lastTrap>g_m5Audit.activeGap) {
        g_m5Audit.activeGap=now-s_lastTrap;g_m5Audit.activeGapTicks=g_musicTicks-s_lastMusic;
        g_m5Audit.activeGapSong=song;
    }
    s_lastSong=song;
    s_lastTrap=now;s_lastPC=pc;s_lastMusic=g_musicTicks;++g_m5Audit.traps;
}
// Called after actual note delivery. Aggregate every song; retain the last
// 1024 events as a ring, so a long session cannot overflow the diagnostic.
void aitdM5Note(unsigned short song,unsigned short note,unsigned long due,unsigned long actual,unsigned long effects) {
    uint32_t* row=g_m5NoteLog[g_m5Audit.noteCount&1023];
    row[0]=song;row[1]=note;row[2]=due;row[3]=actual;row[4]=effects;
    ++g_m5Audit.noteCount;
    uint32_t late=actual-due;
    if(late)++g_m5Audit.noteLateCount;
    if(late>g_m5Audit.noteMaxLate)g_m5Audit.noteMaxLate=late;
}
void aitdM5TimerStart() {s_lastIRQ=0;}
void aitdM5IRQBegin(unsigned short remaining,unsigned short period) {
    s_irqBegan=aitdM5Clock();
    if(s_lastIRQ) {
        uint32_t interval=s_irqBegan-s_lastIRQ;
        if(interval<g_m5Audit.irqMinInterval)g_m5Audit.irqMinInterval=interval;
        if(interval>g_m5Audit.irqMaxInterval)g_m5Audit.irqMaxInterval=interval;
    }
    s_lastIRQ=s_irqBegan;
    uint32_t late=remaining<=period ? period-remaining : 0;
    if(late>g_m5Audit.irqMaxLateEClocks)g_m5Audit.irqMaxLateEClocks=late;
}
void aitdM5IRQEnd() {
    uint32_t elapsed=aitdM5Clock()-s_irqBegan;
    ++g_m5Audit.irqCalls;g_m5Audit.irqClocks+=elapsed;
    if(elapsed>g_m5Audit.irqMaxClocks)g_m5Audit.irqMaxClocks=elapsed;
}
#endif
