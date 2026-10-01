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
#ifdef AITD_INTRO_SKIP
void aitdInputIntroSkip(uint16_t trap, uint32_t ticks);
#endif
#ifdef AITD_MENU_ENTER
void aitdInputMenuEnter(bool atMenu, uint32_t ticks);
#endif
#ifdef AITD_STORY_ENTER
void aitdInputStoryEnter(bool atPortraits, uint32_t ticks);
#endif
void aitdInputInjectProbeKey(uint8_t rawKey, bool down);

#endif
