// Bounded isolated clock fixture; not a gameplay throughput benchmark.
#if defined(AITD_TICK_PROBE) || defined(AITD_TICK_ROUTE)
#include <proto/exec.h>
#include <hardware/intbits.h>
#include "framework/AmigaHardware.h"
extern struct ExecBase* SysBase;
extern "C" {
extern volatile uint32_t g_macTicks;
extern volatile uint32_t* g_macTicksAddress;
extern volatile uint16_t g_vbiCount;
uint32_t aitd_tick_probe_read();
uint32_t aitd_tick_probe_wait(uint32_t deadline);
volatile uint32_t g_tickControls=0;
volatile uint32_t g_tickCount=0, g_tickRows[42][5];
__attribute__((noinline)) void aitdTickProbeComplete() { __asm__ volatile ("" ::: "memory"); }
}
#ifdef AITD_TICK_PROBE
void tickContractProbe()
{
    for(unsigned n=0;n<42;++n) {
        uint32_t delay=n<20 ? 5 : n<40 ? 7 : 300;
        uint32_t start=aitd_tick_probe_read();
        uint16_t fields=g_vbiCount;
        uint32_t end=aitd_tick_probe_wait(start+delay);
        g_tickRows[n][0]=delay;g_tickRows[n][1]=start;g_tickRows[n][2]=end;
        g_tickRows[n][3]=fields;g_tickRows[n][4]=g_vbiCount;
        ++g_tickCount;
    }

}
// Called on the ordinary native stack, outside original-code execution.
void tickPendingControl()
{
    Disable();
    uint32_t tick=g_macTicks,shadow=*g_macTicksAddress;
    while(!(*intreqrPointer & INTF_VERTB)) {}
    if(g_macTicks==tick && *g_macTicksAddress==shadow)g_tickControls|=1;
    Enable();
    while(g_macTicks==tick) {}
    if(uint32_t(g_macTicks-tick)<=2)g_tickControls|=2;
}
void tickRolloverProbe()
{
    uint32_t previous=aitd_tick_probe_read();
    bool wrapped=false;
    while(uint32_t(aitd_tick_probe_read()-0xfffffff8UL)<20) {
        uint32_t next=aitd_tick_probe_read();
        if(uint32_t(next-previous)>2)return;
        if(next<previous)wrapped=true;
        previous=next;
    }
    if(wrapped)g_tickControls|=4;
}

#endif
#endif
