#pragma once
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#ifdef AITD_FULL_PLAY
bool aitdInputFullPlayNeedsService(const uint8_t* hero);
void aitdInputFullPlay(uint32_t ticks,const uint8_t* hero);
void aitdInputFullPlayVBI(uint32_t ticks);
extern "C" {
extern volatile uint32_t g_fullPlaySequence,g_fullPlayMask,g_fullPlayDuration,g_fullPlayTick;
extern volatile uint16_t g_fullPlayStatus;
void aitdInputFullPlayCheckpoint();
}
#endif
