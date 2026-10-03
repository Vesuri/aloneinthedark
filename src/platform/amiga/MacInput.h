#ifndef AITD_MAC_INPUT_H
#define AITD_MAC_INPUT_H

bool aitdInputInitialize();
void aitdInputShutdown();
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
#ifdef AITD_STORY_READ
void aitdInputStoryRead(bool atStory, uint16_t page, bool lastPage, uint32_t ticks);
#endif
void aitdInputInjectProbeKey(uint8_t rawKey, bool down);
#ifdef AITD_GAME_INPUT
void aitdInputGameplay(uint32_t ticks);
#endif
#ifdef AITD_INGAME
extern "C" { extern volatile uint16_t g_ingameStage; extern volatile uint32_t g_ingameTick; }
void aitdInputInGame(uint16_t trap, bool menu, bool portraits, bool story,
                    bool gameplay, uint32_t ticks);
#endif

#endif
