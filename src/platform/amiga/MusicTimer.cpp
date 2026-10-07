#include "M5Audit.h"
#include "MusicTimer.h"
#ifdef AITD_CIA_MUSIC
#include <proto/exec.h>
#include <exec/interrupts.h>
#include <exec/nodes.h>
#include <resources/cia.h>
#include <proto/cia.h>
#include <hardware/cia.h>
#include "VideoTiming.h"

extern "C" {
volatile uint32_t g_musicTicks=0;
volatile uint16_t g_musicTimerSource=0;
void aitd_song_vbi(); // Existing private-stack wrapper, now called by CIA.
}
static struct Library* s_resource;
static struct Interrupt s_interrupt;
static volatile uint8_t *s_control,*s_low,*s_high;
static uint16_t s_bit,s_period,s_remainder,s_fraction;
static volatile bool s_running=false;

static uint16_t nextLatch()
{
    uint16_t period=s_period;
    s_fraction+=s_remainder;
    if(s_fraction>=60) {s_fraction-=60;++period;}
    return period-1; // Underflow includes the zero count.
}
static void writeLatch()
{
    uint16_t latch=nextLatch();
    *s_low=uint8_t(latch);*s_high=uint8_t(latch>>8);
}
static uint32_t musicInterrupt()
{
    if(s_running) {
        // Continuous counting reloads in hardware; ISR work does not move
        // the next deadline. Fractional reloads preserve the average 60 Hz.
#ifdef AITD_M5_AUDIT
        uint8_t hi,lo,again;
        do {hi=*s_high;lo=*s_low;again=*s_high;}while(hi!=again);
        aitdM5IRQBegin(uint16_t(hi)<<8|lo,s_period);
#endif
        writeLatch();++g_musicTicks;
        aitd_song_vbi();
#ifdef AITD_M5_AUDIT
        aitdM5IRQEnd();
#endif
    }
    return 0;
}

const char* aitdMusicTimerStart(uint32_t initialTick)
{
    if(s_resource)return "MUSIC TIMER ALREADY OWNED";
    struct Library* resource=(struct Library*)OpenResource((CONST_STRPTR)CIAANAME);
    if(!resource)return "MUSIC CIA RESOURCE";
    s_interrupt.is_Node.ln_Type=NT_INTERRUPT;
    s_interrupt.is_Node.ln_Pri=0;
    s_interrupt.is_Node.ln_Name=(char*)"Alone music";
    s_interrupt.is_Data=0;s_interrupt.is_Code=(void(*)())musicInterrupt;
    // Level 2 allows display VBI (level 3) to preempt a long note restart.
    // Only claim a free timer; never remove another owner's interrupt.
    for(uint16_t bit=CIAICRB_TA;bit<=CIAICRB_TB;++bit) {
        if(AddICRVector(resource,bit,&s_interrupt))continue;
        Disable();
        s_resource=resource;s_bit=bit;
        uint16_t mask=uint16_t(1u<<bit);
        AbleICR(resource,mask);
        s_control=(volatile uint8_t*)(bit==CIAICRB_TA ? 0xbfee01UL : 0xbfef01UL);
        s_low=(volatile uint8_t*)(bit==CIAICRB_TA ? 0xbfe401UL : 0xbfe601UL);
        s_high=(volatile uint8_t*)(bit==CIAICRB_TA ? 0xbfe501UL : 0xbfe701UL);
        // Preserve serial/TOD and port-output configuration. Select E-clock,
        // continuous counting, initially stopped (RKM CIA resource protocol).
        *s_control &= bit==CIAICRB_TA ? 0xc6 : 0x86;
        uint32_t eclock=g_paulaClock/5;
        s_period=uint16_t(eclock/60);s_remainder=uint16_t(eclock%60);s_fraction=0;
        g_musicTicks=initialTick;g_musicTimerSource=bit+1;
        writeLatch();
        SetICR(resource,mask);
#ifdef AITD_M5_AUDIT
        aitdM5TimerStart();
#endif
        s_running=true;
        AbleICR(resource,uint16_t(CIAICRF_SETCLR|mask));
        *s_control |= CIACRAF_START;
        Enable();
        return 0;
    }
    return "MUSIC CIA TIMERS BUSY";
}

void aitdMusicTimerStop()
{
    if(!s_resource)return;
    Disable();
    s_running=false;
    uint16_t mask=uint16_t(1u<<s_bit);
    AbleICR(s_resource,mask);
    *s_control &= uint8_t(~CIACRAF_START);
    SetICR(s_resource,mask);
    RemICRVector(s_resource,s_bit,&s_interrupt);
    s_resource=0;g_musicTimerSource=0;
    Enable();
}
#endif
