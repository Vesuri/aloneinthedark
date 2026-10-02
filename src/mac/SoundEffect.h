#ifndef AITD_SOUND_EFFECT_H
#define AITD_SOUND_EFFECT_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#include "PaulaSample.h"

namespace SoundEffect {
// Selector 17 supplies raw unsigned PCM, not Vette's optional sample header.
// Only the measured one-shot path is enabled. Loop counters require the
// original loop-boundary semantics before they can be played successfully.
inline const char* describe(const uint8_t* pcm,uint32_t bytes,uint32_t rate,
                            uint32_t loopStart,uint32_t loopEnd,
                            PaulaSample::Layout& layout,uint16_t& period,
                            uint32_t& ticks,uint32_t paulaClock) {
    if(!pcm || !bytes || bytes>131070)return "EFFECT SAMPLE SIZE";
    if(loopStart || loopEnd)return "EFFECT LOOP";
    if(!rate || (rate&0xffff))return "EFFECT RATE";
    if(paulaClock!=3546895 && paulaClock!=3579545)return "EFFECT CLOCK";
    uint32_t hz=rate>>16;
    uint32_t clocks=(paulaClock+hz/2)/hz;
    if(clocks<124 || clocks>65535)return "EFFECT PERIOD";
    layout={};layout.pcm=pcm;layout.size=bytes;layout.rate=(uint16_t)hz;
    layout.attackBytes=(bytes+1)&~1UL;layout.reloadOffset=layout.attackBytes;
    layout.reloadBytes=2;layout.allocated=layout.attackBytes+2;
    period=(uint16_t)clocks;
    // Ceil the actual DMA duration; integer-only, including at very low rates.
    // Split at 65536 bytes so both products fit a native 32-bit MULU.L.
    // attackBytes <= 131070, so there is at most one high chunk.
    uint32_t low=(layout.attackBytes&65535)*clocks;
    uint32_t high=(layout.attackBytes>>16)*(65536UL*clocks);
    uint32_t seconds=low/paulaClock+high/paulaClock;
    uint32_t remainder=low%paulaClock+high%paulaClock;
    ticks=seconds*60+(remainder*60+paulaClock-1)/paulaClock;
    return 0;
}
}
#endif
