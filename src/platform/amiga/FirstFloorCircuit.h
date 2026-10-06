#pragma once
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#ifdef AITD_FIRSTFLOOR_CIRCUIT
void aitdInputFirstFloorCircuit(uint32_t ticks,uint32_t scenes,const uint8_t* world);
extern "C" {
extern volatile uint16_t g_circuitStage,g_circuitCycle,g_circuitAttempts;
extern volatile uint32_t g_circuitTick;
void aitdInputCircuitCheckpoint();
}
#endif
