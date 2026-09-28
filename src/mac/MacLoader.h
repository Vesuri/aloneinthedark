#ifndef AITD_MAC_LOADER_H
#define AITD_MAC_LOADER_H

class AitdScreen;

class MacLoader {
public:
    // Validate and index the original raw Macintosh resource fork(s) while
    // AmigaDOS and normal process memory are still available. The application
    // CODE 1 is copied to aligned storage; later CODE handles are created on demand.
    // The supplied file images remain untouched.  `data` may be
    // null: Alone in the Dark keeps its game data in data-fork .PAK files.
    bool prepareResourceForks(uint8_t* application, uint32_t applicationSize,
                              uint8_t* data, uint32_t dataSize);
    void releaseResourceForks();
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

#endif
