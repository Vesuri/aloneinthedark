/* AitdScreen — THE SINGLE OWNER of the Amiga display mode registers.
 *
 * ⭐⭐ ONE OWNER, ON PURPOSE.  DIWSTRT/DIWSTOP, DDFSTRT/DDFSTOP, BPLCON0-3, FMODE
 * and BPL1MOD/BPL2MOD are write-only and mutually constrained: the display window,
 * the fetch window and the row modulo have to agree by CONSTRUCTION, not because
 * two files happen to hold matching literals.  Every one of them is derived here
 * from the constants below and written in one place.  (See docs/amiga-arch.md.)
 *
 * The single display mode is 320x200 with eight planes. This class owns all mode
 * register writes and publishes complete copper lists during blanking.
 */
#ifndef AITD_SCREEN_H
#define AITD_SCREEN_H

// ⚠ NO <stdint.h> -- SASCCompat.h is force-included and already typedefs these.  See
// PlatformAmiga.h for the conflicting-declaration error the two together produce.

class AitdScreen {
public:
    struct DirtyRect {
        int16_t top, left, bottom, right;
    };
    static const uint16_t kMaxDirtyRects = 32;

    // Fixed physical display; the logical Mac source remains 640x480.
    static const uint16_t kWidth  = 320;
    static const uint16_t kHeight = 200;
    static const uint16_t kMacHeight = 480;
    static const uint16_t kMacTop = 0;
    static const uint16_t kLoresLeft = 0;
    static const uint16_t kLoresWidth = 320;
    static const uint16_t kLoresRight = kLoresLeft + kLoresWidth;
    static const uint16_t kLoresHeight = 200;
    static const uint16_t kPlanes = 8;
    static const uint16_t kBytesPerRow = kWidth / 8;                 // 40
    static const uint16_t kRowStride   = kBytesPerRow * kPlanes;     // 320, interleaved
    static const uint32_t kPictureBytes = (uint32_t)kRowStride * kHeight;

    // Copies `picture` (kPictureBytes of interleaved bitplanes) into chip RAM and
    // builds the copper list.  A null picture and palette produce a black screen;
    // production startup uses that so no captured emulator frame is displayed.
    // ⚠ Returns false if chip RAM could not be had -- the caller must not display.
    bool initialize(const uint8_t* picture, const uint16_t* palette16);
    void shutdown();

    // Called first in VERTB: publish the complete inactive copper list before
    // input/audio work, then restart the Copper during blanking.
    void vbiUpdate(bool install = true);

    // Convert a Macintosh 8-bpp 640x480 surface and device ColorTable into the Amiga's
    // interleaved planes.  The completed frame is swapped in by vbiUpdate(), so
    // the copper never scans a half-converted picture.
    // Returns 1 when queued, 0 while a previous frame is pending, -1 for unsupported input.
    int16_t presentMacFrame(const uint8_t* chunky, const uint8_t* colorTable,
                         const DirtyRect* dirtyRects, uint16_t dirtyRectCount,
                         uint16_t cropLeft = kLoresLeft, uint16_t cropTop = 0,
                         bool mouseAllowed = false);

    bool matchesViewport(uint16_t left, uint16_t top) const {
        return m_cropLeft == left && m_cropTop == top;
    }

    bool matchesMouseVisibility(bool allowed) const { return m_mouseAllowed == allowed; }

    // VBI-only: preserve physical pointer position across viewport changes,
    // apply hardware movement, and clamp the hotspot to the displayed area.
    void updateMouseCoordinates(int16_t& x, int16_t& y, int16_t dx, int16_t dy);

    // Publish the Macintosh cursor shape/state to Amiga sprite 0. Physical
    // position is sampled by the VBI independently of game/Toolbox polling.
    void setMouseCursor(const uint8_t* cursor, int16_t x, int16_t y, bool visible);

    // VBI-only position publication. A 68000 word store is atomic, and the VBI
    // immediately consumes these coordinates when it builds the next sprite.
    void setMousePositionFromVBI(int16_t x, int16_t y, bool visible);

    // Stage B's fail-loud surface.  It replaces the captured frame with a diagnostic
    // generated on the Amiga, so an unknown Mac trap cannot masquerade as a freeze.
    void showLoudStop(const char* manager, const char* routine, int32_t selector,
                      const char* segment, uint32_t offset, uint16_t trapWord);

    uint32_t* copperList() const { return m_copper; }
    uint8_t*  picture() const    { return m_chip; }

    // Display diagnostics. The checksum is computed from
    // the bytes IN CHIP RAM after the copy, so it proves the initialized display
    // surface rather than merely proving that host data exists.
    uint32_t pictureChecksum() const { return m_checksum; }

private:
    uint16_t m_cropLeft = kLoresLeft, m_cropTop = 0;
    uint16_t m_nextCropLeft = kLoresLeft, m_nextCropTop = 0;
    uint16_t m_mouseCropLeft = kLoresLeft, m_mouseCropTop = 0;
    bool m_mouseCoordinatesInitialized = false;
    bool m_mouseAllowed = false, m_nextMouseAllowed = false;
    void writeModeRegisters();
#ifdef AITD_PALETTE_READ_FRAME
    void readPaletteProbe();
#endif
    void queueFrame(uint16_t left,uint16_t top,bool mouseAllowed);
    void updateMouseSprite();

    uint32_t* m_copper = 0;
    uint32_t* m_copperAllocation = 0;
    uint32_t* m_nextCopper = 0;
    uint8_t*  m_chip = 0;
    uint8_t*  m_back = 0;
    uint32_t  m_checksum = 0;
    uint16_t  m_ptrIndex = 0;      // copper-list index of the first BPLxPT move
    uint32_t  m_nextPalette[256] = {0};
    volatile bool m_framePending = false;
    uint16_t* m_mouseSprite = 0;
    uint16_t* m_emptySprite = 0;
    uint16_t  m_cursorImage[16] = {0};
    uint16_t  m_cursorMask[16] = {0};
    int16_t   m_cursorX = 256;
    int16_t   m_cursorY = 160;
    int16_t   m_cursorHotX = 0;
    int16_t   m_cursorHotY = 0;
    bool      m_cursorVisible = false;
    DirtyRect m_syncRects[kMaxDirtyRects] = {};
    uint16_t m_syncRectCount = 0;
};

#endif
