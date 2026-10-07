#pragma once
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#ifdef AITD_ROOM4_RECOVERY
bool aitdInputRoom4Recovery(uint32_t ticks,uint32_t scenes,const uint8_t* world);
extern "C" {
extern volatile uint16_t g_room4RecoveryStage;
extern volatile uint32_t g_room4RecoveryTick;
void aitdInputRoom4RecoveryCheckpoint();
}
#endif
