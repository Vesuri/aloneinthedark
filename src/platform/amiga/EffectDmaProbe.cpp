// Diagnostic only: locate Paula interrupts relative to a real effect segment.
#ifdef AITD_EFFECT_DMA_PROBE
#include <proto/exec.h>
#include <exec/execbase.h>
#include <hardware/custom.h>
#include <hardware/intbits.h>
#include "M5Audit.h"
extern "C" {
volatile unsigned long g_effectDmaProbeStarted=0,g_effectDmaProbeIRQ[4]={};
volatile unsigned short g_effectDmaProbeCount=0,g_effectDmaProbeRestored=0;
}
static volatile Custom* const custom=(volatile Custom*)0xdff000;
static IntVector saved;
static unsigned short source,mask,savedEnable;
static bool installed;
static unsigned long audioInterrupt()
{
    custom->intreq=mask;
    unsigned short index=g_effectDmaProbeCount;
    if(index<4) {
        g_effectDmaProbeIRQ[index]=aitdM5Clock();
        g_effectDmaProbeCount=index+1;
    }
    if(g_effectDmaProbeCount>=4)custom->intena=mask;
    return 0;
}
void aitdEffectDmaProbeBegin(unsigned short channel)
{
    Disable();
    source=INTB_AUD0+channel;mask=INTF_AUD0<<channel;
    saved=SysBase->IntVects[source];savedEnable=custom->intenar&mask;
    SysBase->IntVects[source].iv_Data=0;
    SysBase->IntVects[source].iv_Code=(void(*)())audioInterrupt;
    g_effectDmaProbeStarted=aitdM5Clock();g_effectDmaProbeCount=0;
    custom->intreq=mask;custom->intena=INTF_SETCLR|mask;
    installed=true;
    Enable();
}
void aitdEffectDmaProbeEnd()
{
    if(!installed)return;
    Disable();
    custom->intena=mask;custom->intreq=mask;
    SysBase->IntVects[source]=saved;
    if(savedEnable)custom->intena=INTF_SETCLR|savedEnable;
    g_effectDmaProbeRestored=SysBase->IntVects[source].iv_Data==saved.iv_Data
        && SysBase->IntVects[source].iv_Code==saved.iv_Code
        && SysBase->IntVects[source].iv_Node==saved.iv_Node
        && (custom->intenar&mask)==savedEnable;
    installed=false;
    Enable();
}
#endif
