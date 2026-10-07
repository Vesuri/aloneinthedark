#include <proto/exec.h>
#include <exec/execbase.h>
#include <exec/memory.h>
#include <hardware/custom.h>
#include <hardware/intbits.h>
#include <hardware/dmabits.h>
#include "M5Audit.h"
#include "EffectDmaStream.h"
#include "mac/EffectStream.h"
extern "C" volatile uint32_t g_macTicks;
#ifdef AITD_EFFECT_LOOP_PROBE
extern "C" {
volatile uint32_t g_effectStreamRecords=0,g_effectStreamBytes=0,g_effectStreamOverflow=0;
uint32_t g_effectStreamTrace[2048][7]={};
uint8_t g_effectStreamPCM[262144]={};
}
#endif
namespace EffectDma {
static volatile Custom* const custom=(volatile Custom*)0xdff000;
static const uint16_t fragment=128;
struct Stream {
    EffectStream::Cursor cursor;
    uint8_t* converted;
    uint8_t* buffers;
    uint32_t bytes;
    volatile uint32_t boundaryTick;
    volatile bool complete;
    uint16_t channel,bank,mask,source,savedEnable;
    bool installed,silenceQueued,draining;
    IntVector saved;
};
static Stream* channels[4]={};
static void record(Stream* s,uint8_t* pcm,uint16_t bytes)
{
#ifdef AITD_EFFECT_LOOP_PROBE
    uint32_t n=g_effectStreamRecords;
    if(n>=2048 || g_effectStreamBytes+bytes>sizeof(g_effectStreamPCM)) {++g_effectStreamOverflow;return;}
    uint32_t* row=g_effectStreamTrace[n];
    row[0]=g_macTicks;row[1]=s->cursor.position;row[2]=s->cursor.boundaries;
    row[3]=s->cursor.counter ? (s->cursor.counter[0]<<8)|s->cursor.counter[1] : 0;
    row[4]=bytes;row[5]=s->channel;row[6]=aitdM5Clock();
    for(uint16_t i=0;i<bytes;++i)g_effectStreamPCM[g_effectStreamBytes+i]=pcm[i];
    g_effectStreamBytes+=bytes;g_effectStreamRecords=n+1;
#else
    (void)s;(void)pcm;(void)bytes;
#endif
}
static uint16_t fill(Stream* s,uint16_t bank)
{
    uint8_t* out=s->buffers+bank*fragment;
    uint32_t before=s->cursor.boundaries;
    uint16_t bytes=s->cursor.fill(out,fragment);
    if(before!=s->cursor.boundaries)s->boundaryTick=g_macTicks;
    record(s,out,bytes);
    if(bytes&1)out[bytes]=0;
    return (bytes+1)&~1U;
}
static uint32_t interrupt(uint16_t channel)
{
    Stream* s=channels[channel];const uint16_t mask=INTF_AUD0<<channel;
    custom->intreq=mask;
    if(!s) {custom->intena=mask;return 0;}
    if(s->draining) {
        // One complete silent word has followed the last PCM word. No IRQ
        // releases memory or logical voice ownership; the next user service does.
        custom->dmacon=DMAF_AUD0<<channel;custom->aud[channel].ac_vol=0;
        custom->intena=mask;s->complete=true;return 0;
    }
    uint16_t bank=s->bank^1,bytes;
    if(s->silenceQueued) {bytes=0;s->draining=true;}
    else bytes=fill(s,bank);
    if(!bytes) {
        s->buffers[bank*fragment]=s->buffers[bank*fragment+1]=0;
        bytes=2;s->silenceQueued=true;
    }
    custom->aud[channel].ac_ptr=(UWORD*)(s->buffers+bank*fragment);
    custom->aud[channel].ac_len=bytes>>1;
    s->bank=bank;
    return 0;
}
static uint32_t irq0(){return interrupt(0);} static uint32_t irq1(){return interrupt(1);}
static uint32_t irq2(){return interrupt(2);} static uint32_t irq3(){return interrupt(3);}
Stream* prepare(const uint8_t* pcm,uint32_t bytes,uint32_t begin,uint32_t end,uint8_t* counter,const char*& error)
{
    error=0;
    Stream* s=(Stream*)M5_ALLOC_MEM(sizeof(Stream),MEMF_FAST|MEMF_CLEAR);
    if(!s) {error="EFFECT STREAM STATE";return 0;}
    s->bytes=bytes;
    s->converted=(uint8_t*)M5_ALLOC_MEM(bytes,MEMF_FAST);
    s->buffers=(uint8_t*)M5_ALLOC_MEM(fragment*2,MEMF_CHIP|MEMF_CLEAR);
    if(!s->converted || !s->buffers) {error="EFFECT STREAM MEMORY";dispose(s);return 0;}
    // Conversion is performed once in user mode. The IRQ only copies bounded
    // spans of these signed bytes into the alternating DMA buffers.
    uint32_t i=0;
    if(!((uint32_t)pcm&1))for(;i+4<=bytes;i+=4)
        *(uint32_t*)(s->converted+i)=*(const uint32_t*)(pcm+i)^0x80808080UL;
    for(;i<bytes;++i)s->converted[i]=pcm[i]^0x80;
    if(!s->cursor.initialize(s->converted,bytes,begin,end,counter)) {
        error="EFFECT LOOP BOUNDS";dispose(s);return 0;
    }
    return s;
}
void start(Stream* s,uint16_t channel,uint16_t period,uint16_t volume)
{
    s->channel=channel;s->bank=0;s->boundaryTick=g_macTicks;
    uint16_t bytes=fill(s,0);
    Disable();
    s->source=INTB_AUD0+channel;s->mask=INTF_AUD0<<channel;
    s->saved=SysBase->IntVects[s->source];s->savedEnable=custom->intenar&s->mask;
    static uint32_t(*const handlers[4])()={irq0,irq1,irq2,irq3};
    channels[channel]=s;s->installed=true;
    SysBase->IntVects[s->source].iv_Data=0;
    SysBase->IntVects[s->source].iv_Code=(void(*)())handlers[channel];
    custom->aud[channel].ac_ptr=(UWORD*)s->buffers;
    custom->aud[channel].ac_len=bytes>>1;
    custom->aud[channel].ac_per=period;custom->aud[channel].ac_vol=volume;
    custom->intreq=s->mask;custom->intena=INTF_SETCLR|s->mask;
    custom->dmacon=DMAF_SETCLR|DMAF_MASTER|(DMAF_AUD0<<channel);
    Enable();
}
void suspend(Stream* s)
{
    if(!s || !s->installed)return;
    Disable();custom->intena=s->mask;custom->dmacon=DMAF_AUD0<<s->channel;
    custom->intreq=s->mask;Enable();
}
void dispose(Stream* s)
{
    if(!s)return;
    if(s->installed) {
        suspend(s);Disable();
        channels[s->channel]=0;
        SysBase->IntVects[s->source]=s->saved;
        if(s->savedEnable)custom->intena=INTF_SETCLR|s->savedEnable;
        s->installed=false;Enable();
    }
    if(s->buffers)M5_FREE_MEM(s->buffers,fragment*2);
    if(s->converted)M5_FREE_MEM(s->converted,s->bytes);
    M5_FREE_MEM(s,sizeof(Stream));
}
bool done(const Stream* s){return s->complete;}
uint16_t age(const Stream* s,uint32_t tick)
{
    (void)tick;Disable();
    uint32_t elapsed=g_macTicks-s->boundaryTick;
    uint16_t origin=s->cursor.boundaries ? 0x7fff : 0x7ffe;
    uint16_t result=s->cursor.tailAgeHeld ? 0x7fff : elapsed>origin ? 0xffff : uint16_t(origin-elapsed);
    Enable();return result;
}
uint8_t* chip(Stream* s){return s->buffers;}
uint32_t fastBytes(const Stream* s){return ((sizeof(Stream)+7)&~7UL)+((s->bytes+7)&~7UL);}
}
