#pragma once
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

#ifdef AITD_FIRSTFLOOR_LOAD
void aitdInputFirstFloorLoad(uint32_t ticks,uint32_t scenes,const uint8_t* world,const uint8_t* screen,const uint8_t* colors);
extern "C" {
extern volatile uint16_t g_firstFloorLoadStage;
extern volatile uint32_t g_firstFloorLoadTick,g_firstFloorLoadReadBytes;
void aitdInputFirstFloorLoadCheckpoint();
void aitdInputFirstFloorLoadRead(uint32_t bytes);
}
#endif
