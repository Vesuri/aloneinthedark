#ifndef AITD_MAC_LOADER_H
#define AITD_MAC_LOADER_H

#include "ResourceForks.h"
class AitdScreen;
class MacFiles;

class MacLoader {
public:
    MacFiles& files();
    // Retain maps only; validate original CODE through temporary source reads.
    // The source context remains live until releaseResourceForks returns.
    bool prepareResourceForks(const ResourceForks::Source& application);
    bool releaseResourceForks();
    const char* preparationError() const;

    // Zeroes the CODE 0 A5 world, loads JT 0-9 and enters CODE 1+$14. Original
    // startup expands globals and relocates later CODE through its trap patches.
    // Unsupported layouts and services are named loud stops.
    bool run(AitdScreen* screen);
};

// Classic Mac OS updates the low-memory KeyMap asynchronously from its
// keyboard interrupt.  The Amiga CIA edge path calls this bridge so original
// code that waits without making a Toolbox call still sees transitions.
extern "C" void aitdMacRawKeyChanged(uint8_t rawKey, bool down);

// The Macintosh mouse globals were maintained by a vertical-retrace task, not
// by GetNextEvent.  The Amiga VBI calls this after the time-critical bitplane
// pointer update and before sprite 0 is built for the upcoming field.
extern "C" void aitdMacMouseVBI();
bool aitdMacSuspendLineA();
void aitdMacResumeLineA();

#endif
