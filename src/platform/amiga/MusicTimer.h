#ifndef AITD_MUSIC_TIMER_H
#define AITD_MUSIC_TIMER_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#ifdef AITD_CIA_MUSIC
extern "C" {
extern volatile uint32_t g_musicTicks;
extern volatile uint16_t g_musicTimerSource;
}
const char* aitdMusicTimerStart(uint32_t initialTick);
void aitdMusicTimerStop();
#endif
#endif
