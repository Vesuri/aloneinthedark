#ifndef AITD_MAC_INPUT_H
#define AITD_MAC_INPUT_H

bool aitdInputInitialize();
void aitdInputShutdown();
void aitdInputSuspend();
void aitdInputResume();
void aitdInputFlush();
bool aitdInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers);
bool aitdInputKeyDown(uint8_t rawKey);
uint16_t aitdInputModifiers();
void aitdInputInjectProbeKey(uint8_t rawKey, bool down);

#endif
