#ifdef AITD_STACK_PROBE
#include <proto/exec.h>
#include <dos/dosextens.h>
#include "StackProbe.h"
extern "C" {
extern uint8_t aitd_song_stack[8192],aitd_song_deferred_stack[8192];
struct StackReport { uint32_t magic[2],processSize,processUsed,macSize,macUsed,songUsed,deferredUsed,done; };
volatile StackReport g_stackReport={{0x41495444,0x5354414b},0,0,0,0,0,0,0};
__attribute__((noinline)) void aitdStackProbeFinished() { __asm__ volatile("nop" ::: "memory"); }
}
static uint8_t* processLower;
static uint32_t used(uint8_t* base,uint32_t size,uint8_t pattern=0xa7) {
    uint32_t untouched=0;
    while(untouched<size && base[untouched]==pattern)++untouched;
    return size-untouched;
}
static void mark(uint8_t* base,uint32_t size,uint8_t pattern=0xa7) {
    volatile uint8_t* bytes=base;
    for(uint32_t i=0;i<size;i++)bytes[i]=pattern;
}
void aitdStackProbeBegin() {
    auto* process=(Process*)FindTask(0);uint8_t* sp;
    __asm__ volatile("move.l %%sp,%0" : "=a"(sp));
    processLower=(uint8_t*)process->pr_Task.tc_SPLower;
    auto* upper=(uint8_t*)process->pr_Task.tc_SPUpper;
    if(sp>processLower+128 && sp<upper) {
        g_stackReport.processSize=upper-processLower;
        mark(processLower,sp-processLower-128);
    }
    // M5Audit marks these same stacks with 0xa5 during audio initialization.
    mark(aitd_song_stack,8192,0xa5);mark(aitd_song_deferred_stack,8192,0xa5);
}
void aitdStackProbeMacBegin(uint8_t* stack,uint32_t size) { mark(stack,size);g_stackReport.macSize=size; }
void aitdStackProbeMacEnd(uint8_t* stack,uint32_t size) { if(stack)g_stackReport.macUsed=used(stack,size); }
void aitdStackProbeEnd() {
    if(g_stackReport.processSize)g_stackReport.processUsed=used(processLower,g_stackReport.processSize);
    g_stackReport.songUsed=used(aitd_song_stack,8192,0xa5);
    g_stackReport.deferredUsed=used(aitd_song_deferred_stack,8192,0xa5);
    g_stackReport.done=1;aitdStackProbeFinished();
}
#endif
