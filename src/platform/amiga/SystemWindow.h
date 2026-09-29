#ifndef AITD_SYSTEM_WINDOW_H
#define AITD_SYSTEM_WINDOW_H
// Requires the Mac-code task inside the active user-service bridge. Never call from an interrupt.
int32_t aitdSystemWindow(int32_t (*operation)(void*), void* context);
#endif
