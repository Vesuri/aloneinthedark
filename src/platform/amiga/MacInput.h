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
#ifdef AITD_ACTION_PROBE
void aitdInputActionProbe(uint16_t trap,uint32_t ticks);
#endif
#ifdef AITD_MENU_PROBE
void aitdInputMenuProbe(uint32_t ticks);
void aitdInputMenuProbeQuit();
void aitdInputMenuProbeFinished(bool ok);
#endif
#ifdef AITD_GAME_INPUT
void aitdInputGameplay(uint32_t ticks,bool ready,uint16_t animation);
void aitdInputGameplayEvent(uint16_t what,uint32_t message);
#endif
#ifdef AITD_DEATH_ROUTE
void aitdInputDeathRoute(bool menu,uint32_t ticks,bool initialActor,int16_t z,uint16_t animation);
#endif
#ifdef AITD_LAMP_ROUTE
void aitdInputLamp(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t track,bool taken,bool used,bool ready);
#endif
#ifdef AITD_EXPLORE_ROUTE
void aitdInputExplore(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t beta,uint16_t animation,uint16_t floor,uint16_t room,uint16_t track,bool ready);
#endif
#ifdef AITD_SAVE_LOAD
void aitdInputSaveLoad(uint32_t ticks,uint32_t scenes,int16_t x,int16_t z,uint16_t animation,bool ready);
void aitdInputSaveLoadClosed(uint32_t bytes);
void aitdInputSaveLoadRead(uint32_t bytes);
#endif
#ifdef AITD_INGAME
extern "C" { extern volatile uint16_t g_ingameStage; extern volatile uint32_t g_ingameTick; }
void aitdInputInGame(uint16_t trap, bool menu, bool portraits, bool story,
                    bool gameplay, uint32_t ticks);
#endif

#endif
