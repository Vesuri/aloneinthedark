#ifndef AITD_VIDEO_TIMING_H
#define AITD_VIDEO_TIMING_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

namespace VideoTiming {
inline uint32_t paulaClock(bool pal) { return pal ? 3546895UL : 3579545UL; }
inline uint16_t startLine(bool pal) { return pal ? 72 : 44; }
inline uint16_t stopLine(bool pal) { return startLine(pal)+200; }
inline uint16_t diwHigh(bool pal) { return 0x2000 | (stopLine(pal)&0x100); }
inline uint16_t tickDelta(bool pal,uint16_t& remainder) {
    if(pal && ++remainder==5) { remainder=0;return 2; }
    return 1;
}
}
#ifdef AITD_PLATFORM_AMIGA
extern "C" {
extern uint16_t g_videoPAL;
extern uint32_t g_paulaClock;
}
#endif
#endif
