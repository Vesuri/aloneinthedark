#ifdef AITD_DRIVER_CLOCK_PROBE
#include <exec/types.h>
#include <proto/exec.h>
#include "../../mac/SoundDriver.h"
extern "C" {
extern SoundDriver g_soundDriver;
extern uint8_t** g_soundDriverHandle;
extern volatile uint32_t g_macTicks;
volatile uint16_t g_clockProbeCCR=0,g_clockProbeCount=0;
volatile uint32_t g_clockProbeD1=0,g_clockProbeRows[7][4]={};
uint32_t aitdProbeClockDriverResource();
uint32_t aitdProbeDriverClock(uint32_t entry,uint32_t argument);
__attribute__((noinline)) void aitdDriverClockProbeComplete() {__asm__ volatile("" ::: "memory");}
void aitdDriverClockProbe() {
    // Runtime resource reads must enter the measured user-mode service bridge.
    uint32_t handle=aitdProbeClockDriverResource();
    if(!handle || handle!=(uint32_t)g_soundDriverHandle) {aitdDriverClockProbeComplete();return;}
    CacheClearU();
    const uint32_t values[]={0,1,0x8000,0x10000,0x80000000UL,0x89abcdefUL,0xffffffffUL};
    const uint32_t origin=g_soundDriver.clockOrigin;
    for(uint16_t i=0;i<7;++i) {
        // Freeze only this allocation-free query, so boundary values are exact.
        Disable();
        g_soundDriver.clockOrigin=g_macTicks-values[i];
        uint32_t result=aitdProbeDriverClock((uint32_t)*g_soundDriverHandle,0x12345678);
        g_clockProbeRows[i][0]=values[i];g_clockProbeRows[i][1]=result;
        g_clockProbeRows[i][2]=g_clockProbeD1;g_clockProbeRows[i][3]=g_clockProbeCCR&31;
        Enable();
        ++g_clockProbeCount;
    }
    g_soundDriver.clockOrigin=origin;
    aitdDriverClockProbeComplete();
}
}
#endif
