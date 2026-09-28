#ifndef AITD_MAC_LOADER_H
#define AITD_MAC_LOADER_H

class AitdScreen;

class MacLoader {
public:
    // Validate and index the original raw Macintosh resource fork(s) while
    // AmigaDOS and normal process memory are still available. The application
    // CODE resources are copied to aligned resident storage for patching and
    // execution; the supplied file images remain untouched.  `data` may be
    // null: Alone in the Dark keeps its game data in data-fork .PAK files.
    bool prepareResourceForks(uint8_t* application, uint32_t applicationSize,
                              uint8_t* data, uint32_t dataSize);
    void releaseResourceForks();

    // Builds the A5 world described by CODE 0, resolves the jump table into
    // the resident CODE copies, then enters the first jump-table entry.  A
    // segment layout the loader cannot execute is a named loud stop.
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
