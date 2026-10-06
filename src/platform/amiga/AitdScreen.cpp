/* AitdScreen — the Amiga display for Target 1 (the intro screen).  See AitdScreen.h
 * for why this file, and not the framework, owns the mode registers.
 *
 * ⚠ INCLUDE ORDER IS LOAD-BEARING.  framework/AmigaHardware.h #defines bare register
 * names (bplcon0, vposr, …) as offsets and they collide with the `struct Custom` MEMBERS
 * in <hardware/custom.h>.  Every system header FIRST, AmigaHardware.h LAST.
 */
#include <proto/exec.h>
#include <exec/memory.h>
#include <hardware/dmabits.h>

#include "framework/AmigaHardware.h"
#include "framework/CopperList.h"   /* copperMove() -- the list entries, nothing else */
#include "AitdScreen.h"
#include "Planar8.h"
#include "AgaPalette.h"
#include "AgaCursor.h"
#include "CursorInvert.h"
#include "VideoColor.h"
#include "VideoTiming.h"
#include "PerfProbe.h"
#include "mac/MacLoader.h"

extern "C" {
void aitdKalmsC2PRect(const uint8_t* source,uint8_t* destination,uint32_t width,uint32_t rows);
volatile uint16_t g_macFramesQueued = 0;
volatile uint16_t g_macFramesPresented = 0;
volatile uint16_t g_beamPresentLine = 0;
volatile uint16_t g_beamPresentMin = 0xffff;
volatile uint16_t g_beamPresentMax = 0;
volatile uint32_t g_beamPresents = 0;
volatile uint32_t g_beamPresentsLate = 0;
#ifdef AITD_C2P_VERIFY
volatile uint32_t g_c2pVerifiedFrames=0,g_c2pPartialFrames=0,g_c2pVerifyFailures=0;
Planar8::Mismatch g_c2pMismatch={};
__attribute__((noinline)) void aitdC2PVerifyFailed() { __asm__ volatile("nop" ::: "memory"); }
#endif
#ifdef AITD_PALETTE_READ_FRAME
volatile uint16_t g_paletteReadHigh[256] = {};
volatile uint16_t g_paletteReadLow[256] = {};
volatile uint16_t g_paletteReadBanks = 0, g_paletteReadStable = 0;
volatile uint16_t g_paletteReadFrame = 0, g_paletteReadDone = 0;
volatile uint16_t g_paletteReadBeamMax = 0;
volatile uint16_t g_paletteReadDMABefore = 0, g_paletteReadDMAAfter = 0;
__attribute__((noinline)) void aitdPaletteReadComplete() { __asm__ volatile("" ::: "memory"); }
#endif
#ifdef AITD_PROBE
volatile uint16_t g_probeSkipC2P = 0;
volatile uint32_t g_probeC2PFrames = 0;
volatile uint32_t g_probeC2PRects = 0;
volatile uint32_t g_probeC2PPixels = 0;
#endif
#ifdef AITD_FILLWATCH
volatile uint32_t g_fillWatchFrames = 0;
volatile uint32_t g_fillWatchRows = 0;
volatile uint32_t g_fillBadFrames = 0;
volatile uint32_t g_fillBadPixels = 0;
volatile uint16_t g_fillBadX = 0;
volatile uint16_t g_fillBadY = 0;
volatile uint16_t g_fillBadExpected = 0;
volatile uint16_t g_fillBadActual = 0;
#endif
}

static uint16_t beamLine()
{
    // Read VPOSR first: the pair is not atomic, and taking V8 after V0..V7
    // could straddle the line-256 transition.
    uint16_t high = *vposrPointer;
    uint16_t low = *vhposrPointer;
    return (uint16_t)(((high & 1u) << 8) | (low >> 8));
}

// Centre the 200-line client in the selected PAL/NTSC window. FMODE is 1x.
#define VS_BPLCON0 0x0211 // BPU3, COLOR, ECSENA; no HAM/dual playfield
#define VS_BPLCON2 0x0024
static_assert(AitdScreen::kPlanes==8 && AitdScreen::kWidth==320, "eight-plane lores");
static_assert(AitdScreen::kPictureBytes==Planar8::bytes, "planar layout");
static_assert(0xd0==0x38+8*(AitdScreen::kWidth/16-1), "fetch width");
#define VS_CL_PTRS 0
#define VS_CL_SPRITES (VS_CL_PTRS+16)
#define VS_CL_COLORS (VS_CL_SPRITES+16)
#define VS_CL_END (VS_CL_COLORS+AgaPalette::moves)
#define VS_CL_LONGS (VS_CL_END+1)

// Allocate all sixteen cursor rows.
// Include the control pair and a mandatory zero terminator.
static const uint16_t kMouseSpriteFieldRows = 16;
static const uint32_t kMouseSpriteBytes = (kMouseSpriteFieldRows + 2) * 4;
// Match Rescue on Fractalus's Sprite::allocate(0): control pair plus a zero
// terminator, both cleared, so DMA cannot walk beyond the null object.
static const uint32_t kEmptySpriteBytes = 8;

// Buffer diagnostics use rotate-then-xor rather than a plain sum:
// a sum is blind to byte ORDER, and a plane blob loaded with the wrong stride or with the
// two interleave halves swapped has exactly the right bytes in the wrong places.
static uint32_t rotXorChecksum(const uint8_t* p, uint32_t n)
{
    uint32_t c = 0;
    for (uint32_t i = 0; i < n; i++) {
        c = (c << 1) | (c >> 31);
        c ^= (uint32_t)p[i];
    }
    return c;
}

bool AitdScreen::initialize(const uint8_t* picture, const uint16_t* palette16)
{
    // ⚠ The picture MUST live in chip RAM: FS-UAE runs this port with --fast_memory=8192, so
    // a linked-in blob lands in fast RAM, which the display DMA cannot reach.  The failure is
    // not a crash -- the copper happily fetches whatever chip address the truncated pointer
    // lands on -- so allocate explicitly and copy.
    m_chip = (uint8_t*)AllocMem(kPictureBytes, MEMF_CHIP);
    if (!m_chip) return false;
    m_back = (uint8_t*)AllocMem(kPictureBytes, MEMF_CHIP);
    if (!m_back) { FreeMem(m_chip, kPictureBytes); m_chip = 0; return false; }

    m_mouseSprite = (uint16_t*)AllocMem(2*kMouseSpriteBytes, MEMF_CHIP | MEMF_CLEAR);
    if (!m_mouseSprite) {
        FreeMem(m_back, kPictureBytes); m_back = 0;
        FreeMem(m_chip, kPictureBytes); m_chip = 0;
        return false;
    }
    m_emptySprite = (uint16_t*)AllocMem(kEmptySpriteBytes, MEMF_CHIP | MEMF_CLEAR);
    if (!m_emptySprite) {
        FreeMem(m_mouseSprite, 2*kMouseSpriteBytes); m_mouseSprite = 0;
        FreeMem(m_back, kPictureBytes); m_back = 0;
        FreeMem(m_chip, kPictureBytes); m_chip = 0;
        return false;
    }

    m_copperAllocation = (uint32_t*)AllocMem(2 * VS_CL_LONGS * sizeof(uint32_t), MEMF_CHIP | MEMF_CLEAR);
    m_copper = m_copperAllocation;
    if (!m_copper) {
        FreeMem(m_emptySprite, kEmptySpriteBytes); m_emptySprite = 0;
        FreeMem(m_mouseSprite, 2*kMouseSpriteBytes); m_mouseSprite = 0;
        FreeMem(m_back, kPictureBytes); m_back = 0;
        FreeMem(m_chip, kPictureBytes); m_chip = 0;
        return false;
    }

    m_syncCount = 0;
    m_paletteValid = false;

    for (uint32_t i = 0; i < kPictureBytes; i++)
        m_chip[i] = m_back[i] = picture ? picture[i] : 0;

    // Checksum what is IN CHIP RAM, after the copy -- that is what the display reads, and it
    // is the only form of the data that proves the whole asset path end to end.
    m_checksum = rotXorChecksum(m_chip, kPictureBytes);

    m_ptrIndex = VS_CL_PTRS;
    for (uint16_t k = 0; k < kPlanes; k++) {
        m_copper[VS_CL_PTRS + k * 2 + 0] = copperMove(bpl1pth + k * 4, (uint32_t)(m_chip+k*kBytesPerRow)>>16);
        m_copper[VS_CL_PTRS + k * 2 + 1] = copperMove(bpl1ptl + k * 4, (uint32_t)(m_chip+k*kBytesPerRow)&65535);
    }
    for (uint16_t channel = 0; channel < 8; ++channel) {
        uint32_t sprite = (uint32_t)(channel==AgaCursor::whiteChannel ? m_mouseSprite :
            channel==AgaCursor::blackChannel ? m_mouseSprite+kMouseSpriteBytes/2 : m_emptySprite);
        m_copper[VS_CL_SPRITES + channel * 2]
            = copperMove(spr1pth + channel * 4, (uint16_t)(sprite >> 16));
        m_copper[VS_CL_SPRITES + channel * 2 + 1]
            = copperMove(spr1ptl + channel * 4, (uint16_t)sprite);
    }
    for(uint16_t i=0;i<256;++i)m_nextPalette[i]=0;
    if(palette16)for(uint16_t i=0;i<16;++i) {
        uint16_t c=palette16[i];
        m_nextPalette[i]=uint32_t((c>>8)&15)*17*65536
                       +uint32_t((c>>4)&15)*17*256+(c&15)*17;
    }
    AgaPalette::build(m_copper+VS_CL_COLORS,m_nextPalette);
    m_copper[VS_CL_END] = 0xfffffffe;
    // Both lists start complete; queueFrame then patches only changed parts.
    for(uint16_t i=0;i<VS_CL_LONGS;++i)m_copper[VS_CL_LONGS+i]=m_copper[i];
    m_paletteVersion=0;
    m_listPaletteVersion[0]=m_listPaletteVersion[1]=0;
    m_listMouseAllowed[0]=m_listMouseAllowed[1]=false;

    // Publish valid bitplane pointers before enabling display DMA.
    vbiUpdate(false);

    writeModeRegisters();

    // Install the list.  ⚠ Copper DMA is still OFF here (PlatformAmiga turns it on only
    // after this returns): writing COP1LC with the copper halted is what makes the bring-up
    // race-free -- the OS's LoadView(NULL) list can never run over the registers just set.
    *cop1lcPointer = m_copper;
    return true;
}

void AitdScreen::writeModeRegisters()
{
    *fmodePointer=0;
    *bplcon0Pointer=VS_BPLCON0;
    *bplcon1Pointer=0;
    *bplcon2Pointer=VS_BPLCON2;
    *bplcon3Pointer=AgaPalette::control;
    *bplcon4Pointer=m_mouseAllowed ? AgaCursor::displayControl : 0x0011;
    *diwstrtPointer=(VideoTiming::startLine(g_videoPAL!=0)<<8)|0x81;
    *diwstopPointer=((VideoTiming::stopLine(g_videoPAL!=0)&255)<<8)|0xc1;
    *diwhighPointer=VideoTiming::diwHigh(g_videoPAL!=0);
    *ddfstrtPointer=0x0038;
    *ddfstopPointer=0x00d0;
    *bpl1modPointer=kRowStride-kBytesPerRow;
    *bpl2modPointer=kRowStride-kBytesPerRow;
}

void AitdScreen::queueFrame(uint16_t left,uint16_t top,bool mouseAllowed)
{
    const uint16_t list=m_copper==m_copperAllocation ? 1 : 0;
    uint32_t* next=m_copperAllocation+list*VS_CL_LONGS;
    // Sprite pointers and the list end never change. The inactive list was
    // last published two frames ago: refresh its bitplane pointers, and its
    // 520 colour moves only when the palette or cursor mode differs.
    for(uint16_t plane=0;plane<kPlanes;++plane) {
        uint32_t p=(uint32_t)(m_back+plane*kBytesPerRow);
        next[VS_CL_PTRS+plane*2]=copperMove(bpl1pth+plane*4,p>>16);
        next[VS_CL_PTRS+plane*2+1]=copperMove(bpl1ptl+plane*4,p&65535);
    }
    if(m_listPaletteVersion[list]!=m_paletteVersion || m_listMouseAllowed[list]!=mouseAllowed) {
        AgaPalette::build(next+VS_CL_COLORS,m_nextPalette,mouseAllowed ? AgaCursor::playfieldXor : 0);
        m_listPaletteVersion[list]=m_paletteVersion;m_listMouseAllowed[list]=mouseAllowed;
    }
    m_nextCopper=next;m_nextCropLeft=left;m_nextCropTop=top;m_nextMouseAllowed=mouseAllowed;
    ++g_macFramesQueued;
    __asm__ volatile("" ::: "memory");
    m_framePending=true;
}

#ifdef AITD_PALETTE_READ_FRAME
// Diagnostic only: read Lisa's colour RAM, not the intended copper-list values.
// RDRAM/BANK/LOCT contract: FS-UAE custom.cpp, COLOR_READ(). Read one bank per
// VBI, before restarting the copper. Pause copper DMA so it cannot change BANK
// during the reads. This restores owned control values, not unknown OS values;
// it is a palette-content probe, not proof of unmodified display-mode state.
void AitdScreen::readPaletteProbe()
{
    if(g_paletteReadDone)return;
    if(m_framePending || g_macFramesPresented!=AITD_PALETTE_READ_FRAME) {
        g_paletteReadBanks=0;g_paletteReadStable=0;return;
    }
    // Allow the previous publication's copper to execute for a whole field.
    if(g_paletteReadStable<2) { ++g_paletteReadStable;return; }
    uint16_t bank=g_paletteReadBanks;
    uint16_t dma=*dmaconrPointer;
    g_paletteReadDMABefore=dma;
    *dmaconPointer=DMAF_COPPER;
    *bplcon2Pointer=VS_BPLCON2|0x0100; // RDRAM
    *bplcon3Pointer=AgaPalette::control|(bank<<13);
    for(uint16_t i=0;i<32;++i)g_paletteReadHigh[bank*32+i]=color00Pointer[i];
    *bplcon3Pointer=AgaPalette::control|(bank<<13)|0x0200; // LOCT
    for(uint16_t i=0;i<32;++i)g_paletteReadLow[bank*32+i]=color00Pointer[i];
    *bplcon3Pointer=AgaPalette::control;
    *bplcon2Pointer=VS_BPLCON2;
    if(dma&DMAF_COPPER)*dmaconPointer=DMAF_SETCLR|DMAF_COPPER;
    g_paletteReadDMAAfter=*dmaconrPointer;
    uint16_t line=beamLine();
    if(line>g_paletteReadBeamMax)g_paletteReadBeamMax=line;
    g_paletteReadFrame=g_macFramesPresented;
    g_paletteReadBanks=bank+1;
    if(g_paletteReadBanks==8) {
        g_paletteReadDone=1;
        aitdPaletteReadComplete();
    }
}
#endif

void AitdScreen::vbiUpdate(bool install)
{
    if(!m_copper || !m_chip)return;
    uint8_t* invertedPicture=m_chip;
#ifdef AITD_PALETTE_READ_FRAME
    if(install)readPaletteProbe();
#endif
    bool present=m_framePending;
    if(present) {
        uint8_t* previous=m_chip;m_chip=m_back;m_back=previous;
        m_copper=m_nextCopper;
        m_cropLeft=m_nextCropLeft;m_cropTop=m_nextCropTop;m_mouseAllowed=m_nextMouseAllowed;
    }
    // Publish the already-complete copper list before input/audio work.
    if(install) {
        *bplcon4Pointer=m_mouseAllowed ? AgaCursor::displayControl : 0x0011;
        uint16_t line=beamLine();g_beamPresentLine=line;
        if(line<g_beamPresentMin)g_beamPresentMin=line;
        if(line>g_beamPresentMax)g_beamPresentMax=line;
        ++g_beamPresents;if(line>=16)++g_beamPresentsLate;
        *cop1lcPointer=m_copper;*copjmp1Pointer=0;
    }
    // Pointer publication comes first. Undo the old XOR before input work and
    // before returning the inactive bitmap to user-mode frame preparation.
    if(m_invertActive) {xorCursorInversion(invertedPicture);m_invertActive=false;}
    if(present) {
        ++g_macFramesPresented;
        __asm__ volatile("" ::: "memory");
        m_framePending=false;
    }
#ifndef AITD_AGA_CURSOR_PROBE
    aitdMacMouseVBI();
#endif
    updateMouseSprite();
    if(install)applyCursorInversion();
#ifdef AITD_AGA_CURSOR_PROBE
    if(install) {
        uint16_t line=beamLine();
        if(line>m_cursorProbeEndLine)m_cursorProbeEndLine=line;
    }
#endif
}

void AitdScreen::setMouseCursor(const uint8_t* cursor, int16_t x, int16_t y,
                                 bool visible)
{
    // The VBI may fire at any instruction. Publish one coherent cursor state;
    // the critical section is only 36 word/coordinate stores.
    Disable();
    m_cursorX = x;
    m_cursorY = y;
    m_cursorVisible = visible && cursor;
    if (cursor) {
        for (uint16_t row = 0; row < 16; ++row) {
            m_cursorImage[row] = (uint16_t)(cursor[row * 2] << 8 | cursor[row * 2 + 1]);
            m_cursorMask[row] = (uint16_t)(cursor[32 + row * 2] << 8
                                         | cursor[33 + row * 2]);
        }
        m_cursorHotY = (int16_t)(cursor[64] << 8 | cursor[65]);
        m_cursorHotX = (int16_t)(cursor[66] << 8 | cursor[67]);
    }
    Enable();
}

void AitdScreen::xorCursorInversion(uint8_t* picture)
{
    for(int16_t row=0;row<16;++row) {
        int32_t y=int32_t(m_invertTop)+row;
        if(y<0 || y>=200 || !m_invertRows[row])continue;
        CursorInvert::planes(picture+y*kRowStride,m_invertLeft,m_invertRows[row]);
    }
}

void AitdScreen::applyCursorInversion()
{
    if(!m_mouseAllowed || !m_cursorVisible)return;
    m_invertLeft=m_cursorX-m_cursorHotX-m_cropLeft;
    m_invertTop=m_cursorY-m_cursorHotY-m_cropTop;
    for(uint16_t row=0;row<16;++row) {
        m_invertRows[row]=m_cursorImage[row]&~m_cursorMask[row];
        if(m_invertRows[row])m_invertActive=true;
    }
    if(m_invertActive)xorCursorInversion(m_chip);
}

void AitdScreen::updateMouseCoordinates(int16_t& x, int16_t& y, int16_t dx, int16_t dy)
{
    int16_t left = m_cropLeft;
    int16_t top = m_cropTop;
    if (m_mouseCoordinatesInitialized) {
        dx += left - m_mouseCropLeft;
        dy += top - m_mouseCropTop;
    }
    m_mouseCoordinatesInitialized = true;
    m_mouseCropLeft = left;
    m_mouseCropTop = top;
    int16_t right = left + kLoresWidth - 1;
    int16_t bottom = top + kLoresHeight - 1;
    x += dx;
    y += dy;
    if (x < left) x = left;
    if (x > right) x = right;
    if (y < top) y = top;
    if (y > bottom) y = bottom;
}

void AitdScreen::setMousePositionFromVBI(int16_t x, int16_t y, bool visible)
{
    m_cursorX = x;
    m_cursorY = y;
    m_cursorVisible = visible;
}

void AitdScreen::updateMouseSprite()
{
    uint16_t* sprite = m_mouseSprite;
    if (!sprite) return;
    uint16_t* blackSprite=sprite+kMouseSpriteBytes/2;

    int16_t left = (int16_t)(m_cursorX - m_cursorHotX - m_cropLeft);
    int16_t top = (int16_t)(m_cursorY - m_cursorHotY - (int16_t)m_cropTop);
    uint16_t firstSourceRow = 0;
    while (firstSourceRow < 16 && top + firstSourceRow < 0) ++firstSourceRow;
    uint16_t rows = 0;
    int16_t height = kLoresHeight;
    while (firstSourceRow + rows < 16
           && top + firstSourceRow + rows < height) ++rows;
    bool visible = m_mouseAllowed && m_cursorVisible
        && left < (int16_t)kLoresWidth
        && left + 16 > 0 && rows;
    uint16_t hstart = (uint16_t)(129 + (left > 0 ? left : 0));
    uint16_t vstart = (uint16_t)(VideoTiming::startLine(g_videoPAL!=0) + top + firstSourceRow);
    uint16_t vstop = (uint16_t)(vstart + rows);
    uint8_t* control = (uint8_t*)sprite;
    control[0] = visible ? (uint8_t)vstart : 0;
    control[1] = visible ? (uint8_t)(hstart >> 1) : 0;
    control[2] = visible ? (uint8_t)vstop : 0;
    control[3] = visible ? (uint8_t)(((vstart >> 8) & 1) << 2
                                   | ((vstop >> 8) & 1) << 1
                                   | (hstart & 1)) : 0;
    blackSprite[0]=sprite[0];blackSprite[1]=sprite[1];

    for (uint16_t fieldRow = 0; fieldRow < rows; ++fieldRow) {
        uint16_t sourceRow = (uint16_t)(firstSourceRow + fieldRow);
        uint16_t image = m_cursorImage[sourceRow];
        uint16_t mask = m_cursorMask[sourceRow];
        if (left < 0 && left > -16) { image <<= -left; mask <<= -left; }
        AgaCursor::row(image,mask,sprite+2+fieldRow*2,blackSprite+2+fieldRow*2);
    }

    sprite[2 + rows * 2] = sprite[3 + rows * 2] = 0;
    blackSprite[2 + rows * 2] = blackSprite[3 + rows * 2] = 0;


}

int16_t AitdScreen::presentMacFrame(const uint8_t* chunky,const uint8_t* colorTable,
                                  const DirtyRect* dirtyRects,uint16_t dirtyRectCount,
                                  uint16_t cropLeft,uint16_t cropTop,bool mouseAllowed)
{
    Planar8::Rect viewport{int16_t(cropTop),int16_t(cropLeft),int16_t(cropTop+200),int16_t(cropLeft+320)};
    if(!chunky || !colorTable || !m_back || !Planar8::viewportValid(viewport)
       || dirtyRectCount>kMaxDirtyRects || (dirtyRectCount && !dirtyRects)
       || colorTable[4]!=0x80 || colorTable[5]!=0 || colorTable[6]!=0 || colorTable[7]!=255)return -1;
    if(m_framePending)return 0;
    if(mouseAllowed) {
        for(uint16_t c=0;c<6;++c)
            if(colorTable[10+c]!=255 || colorTable[10+255*8+c]!=0)return -3;
    }
    Planar8::Rect normalized[kMaxDirtyRects];uint16_t count=0;
    if(!matchesViewport(cropLeft,cropTop)) {
        // A newly exposed viewport converts completely and supersedes any
        // rectangles pending from the old one.
        normalized[count++]={0,0,200,320};m_syncCount=0;
    } else for(uint16_t i=0;i<dirtyRectCount;++i) {
        const DirtyRect& d=dirtyRects[i];Planar8::Rect local;
        if(!Planar8::normalize(viewport,{d.top,d.left,d.bottom,d.right},local))return -1;
        if(local.top<local.bottom && local.left<local.right)
            Planar8::append(normalized,count,kMaxDirtyRects,local);
    }
    // Vette's explicit synchronization: bring the previous frame's converted
    // rectangles to the inactive bitmap unless this frame replaces them.
    { AitdProfileScope profile(kProfileSync);
    for(uint16_t i=0;i<m_syncCount;++i) {
        const Planar8::Rect& r=m_syncRects[i];
        if(!Planar8::syncNeeded(r,normalized,count))continue;
        const uint16_t firstLong=uint16_t(r.left)/32,longs=uint16_t(r.right-r.left)/32;
        for(int16_t y=r.top;y<r.bottom;++y) {
            const int16_t row=y-m_invertTop;
            for(uint16_t plane=0;plane<kPlanes;++plane) {
                // A VBI can move the cursor between spans. Copy and undo its
                // current XOR atomically for one plane span (at most 40 bytes),
                // preserving a clean inactive bitmap during conversion.
                uint32_t* out=(uint32_t*)(m_back+uint32_t(y)*kRowStride+plane*kBytesPerRow)+firstLong;
                Disable();
                __asm__ volatile("" ::: "memory");
                const uint32_t* in=(const uint32_t*)(m_chip+uint32_t(y)*kRowStride+plane*kBytesPerRow)+firstLong;
                for(uint16_t x=0;x<longs;++x)out[x]=in[x];
                if(m_invertActive && row>=0 && row<16)
                    CursorInvert::row(m_back+uint32_t(y)*kRowStride+plane*kBytesPerRow,
                        r.left,r.right,m_invertLeft,m_invertRows[row]);
                __asm__ volatile("" ::: "memory");
                Enable();
            }
        }
    }
    }
    { AitdProfileScope profile(kProfileC2P);
    for(uint16_t i=0;i<count;++i) {
        const Planar8::Rect& r=normalized[i];
        aitdKalmsC2PRect(chunky+uint32_t(r.top+cropTop)*640+cropLeft+r.left,
            m_back+uint32_t(r.top)*kRowStride+r.left/8,r.right-r.left,r.bottom-r.top);
        m_syncRects[i]=r;
    }
    m_syncCount=count;
    }
#ifdef AITD_C2P_VERIFY
    if(!Planar8::verify(chunky,m_back,viewport,g_c2pMismatch)) {
        ++g_c2pVerifyFailures;aitdC2PVerifyFailed();return -1;
    }
    ++g_c2pVerifiedFrames;
    bool full=false;
    for(uint16_t i=0;i<count;++i) {
        const Planar8::Rect& r=normalized[i];
        if(r.top==0 && r.left==0 && r.bottom==200 && r.right==320)full=true;
    }
    if(count && !full)++g_c2pPartialFrames;
#endif
    { AitdProfileScope profile(kProfilePalette);
    const uint32_t seed=uint32_t(colorTable[0])<<24|uint32_t(colorTable[1])<<16|uint32_t(colorTable[2])<<8|colorTable[3];
    if(!m_paletteValid || seed!=m_paletteSeed) {
        // Every Color Manager change installs a new table seed.
        for(uint16_t i=0;i<256;++i) {
            const uint8_t* c=colorTable+10+i*8;
            m_nextPalette[i]=VideoColor::rgb(uint16_t(c[0])<<8|c[1],uint16_t(c[2])<<8|c[3],uint16_t(c[4])<<8|c[5]);
        }
        m_paletteSeed=seed;m_paletteValid=true;++m_paletteVersion;
    }
    queueFrame(cropLeft,cropTop,mouseAllowed);
    }
    return 1;
}

void AitdScreen::shutdown()
{
    if (m_copperAllocation) {
        FreeMem(m_copperAllocation, 2 * VS_CL_LONGS * sizeof(uint32_t));
        m_copperAllocation = 0;
        m_copper = 0;
    }
    if (m_emptySprite) { FreeMem(m_emptySprite, kEmptySpriteBytes); m_emptySprite = 0; }
    if (m_mouseSprite) { FreeMem(m_mouseSprite, 2*kMouseSpriteBytes); m_mouseSprite = 0; }
    if (m_back)   { FreeMem(m_back, kPictureBytes); m_back = 0; }
    if (m_chip)   { FreeMem(m_chip, kPictureBytes); m_chip = 0; }
}

// Compact 5x7 capitals.  Rows are five low bits, left to right.  The Stage B stop uses
// only capitals deliberately: this is exception-path code, not a general text renderer.
static const uint8_t s_font[37][7] = {
    {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},
    {30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,16,30,1,1,30},
    {14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},
    {14,17,17,15,1,1,14},
    {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},
    {30,17,17,17,17,17,30},{31,16,16,30,16,16,31},{31,16,16,30,16,16,16},
    {14,17,16,23,17,17,14},{17,17,17,31,17,17,17},{14,4,4,4,4,4,14},
    {7,2,2,2,2,18,12},{17,18,20,24,20,18,17},{16,16,16,16,16,16,31},
    {17,27,21,21,17,17,17},{17,25,21,19,17,17,17},{14,17,17,17,17,17,14},
    {30,17,17,30,16,16,16},{14,17,17,17,21,18,13},{30,17,17,30,20,18,17},
    {15,16,16,14,1,1,30},{31,4,4,4,4,4,4},{17,17,17,17,17,17,14},
    {17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},
    {17,17,10,4,4,4,4},{31,1,2,4,8,16,31},
    {0,0,0,0,0,0,0}
};

static uint8_t glyphRow(char c, uint16_t row)
{
    if (c >= '0' && c <= '9') return s_font[c - '0'][row];
    if (c >= 'A' && c <= 'Z') return s_font[10 + c - 'A'][row];
    if (c == ':') return (row == 2 || row == 5) ? 4 : 0;
    if (c == '+') return row == 3 ? 31 : ((row >= 1 && row <= 5) ? 4 : 0);
    if (c == '/') return (uint8_t)(1u << (row < 5 ? 4 - row : 0));
    if (c == '-') return row == 3 ? 31 : 0;
    if (c == '$') return s_font[28][row]; // readable S-shaped dollar substitute
    return s_font[36][row];
}

static void setWhitePixel(uint8_t* chip, uint16_t x, uint16_t y)
{
    if (x >= AitdScreen::kWidth || y >= AitdScreen::kHeight) return;
    uint8_t mask = (uint8_t)(0x80u >> (x & 7));
    uint32_t row = (uint32_t)y * AitdScreen::kRowStride;
    uint16_t byte = x >> 3;
    for (uint16_t p = 0; p < AitdScreen::kPlanes; ++p)
        chip[row + (uint32_t)p * AitdScreen::kBytesPerRow + byte] |= mask;
}

static void drawLine(uint8_t* chip, uint16_t x, uint16_t y, const char* text)
{
    for (; *text; ++text, x += 6) {
        for (uint16_t row = 0; row < 7; ++row) {
            uint8_t bits = glyphRow(*text, row);
            for (uint16_t col = 0; col < 5; ++col) if (bits & (16u >> col)) {
                setWhitePixel(chip,x+col,y+row);
            }
        }
    }
}

static char hexDigit(uint8_t v) { return (char)(v < 10 ? '0' + v : 'A' + v - 10); }

static void append(char*& p, const char* s) { while (*s) *p++ = *s++; }
static void appendHex(char*& p, uint32_t value, uint16_t digits)
{
    while (digits--) *p++ = hexDigit((uint8_t)(value >> (digits * 4)) & 15);
}

void AitdScreen::showLoudStop(const char* manager, const char* routine, int32_t selector,
                               const char* segment, uint32_t offset, uint16_t trapWord)
{
    if(!m_chip || !m_back)return;
    // Let an already queued game frame complete before reusing its bitmap.
    while(m_framePending) { __asm__ volatile("nop"); }
    for(uint32_t i=0;i<kPictureBytes;++i)m_back[i]=0;

    char line[48]; char* p;
    drawLine(m_back, 24, 24, "STAGE B LOUD STOP");
    p = line; append(p, "TRAP: $"); appendHex(p, trapWord, 4); *p = 0;
    drawLine(m_back, 24, 58, line);
    p = line; append(p, "MANAGER: "); append(p, manager); *p = 0;
    drawLine(m_back, 24, 82, line);
    p = line; append(p, "ROUTINE: "); append(p, routine); *p = 0;
    drawLine(m_back, 24, 106, line);
    p = line; append(p, "SELECTOR: ");
    if (selector < 0) append(p, "N/A"); else appendHex(p, (uint32_t)selector, 8);
    *p = 0; drawLine(m_back, 24, 130, line);
    p = line; append(p, "CALLER: "); append(p, segment); *p++ = '+';
    appendHex(p, offset, 4); *p = 0;
    drawLine(m_back, 24, 154, line);
    for(uint16_t i=0;i<256;++i)m_nextPalette[i]=0;
    m_nextPalette[255]=0xffffff;
    m_syncCount=0;m_paletteValid=false;++m_paletteVersion;
    queueFrame(m_cropLeft,m_cropTop,false);
}


#ifdef AITD_AGA_PROBE
extern "C" {
volatile uint16_t g_agaProbeStage=0,g_agaProbeError=0,g_agaProbeDone=0;
AitdScreen* g_agaProbeScreen=0;
const uint8_t* g_agaProbeSource=0;
const uint8_t* g_agaProbeColors=0;
int16_t g_agaProbeViewport[4]={0,0,0,0};
extern volatile uint16_t g_vbiCount;
extern volatile uint32_t g_macTicks;
__attribute__((noinline,used)) void aitdAgaProbeCheckpoint() { __asm__ volatile("nop" ::: "memory"); }

bool aitdRunAgaProbe(AitdScreen* screen)
{
    static uint8_t source[640*480],colors[2056];
    g_agaProbeScreen=screen;g_agaProbeSource=source;g_agaProbeColors=colors;
    for(uint16_t y=0;y<480;++y)for(uint16_t x=0;x<640;++x)
        source[uint32_t(y)*640+x]=uint8_t(x*37+y*71+(x^y));
    colors[4]=0x80;colors[7]=255;
#ifdef AITD_AGA_VISUAL
    // All 256 indices in a readable ramp above the bitplane stress pattern.
    for(uint16_t y=150;y<230;++y)for(uint16_t x=160;x<480;++x)
        source[uint32_t(y)*640+x]=uint8_t(uint32_t(x-160)*256/320);
#endif
    for(uint16_t i=0;i<256;++i) {
        uint8_t* c=colors+8+i*8;c[0]=8;
        c[2]=c[3]=uint8_t(i);c[4]=c[5]=uint8_t(255-i);c[6]=c[7]=uint8_t(i*71);
    }
#ifdef AITD_AGA_CURSOR_PROBE
    // Exercise the same protected endpoints as the original game palettes.
    // Keep input independent of the uninitialized Mac cursor in this fixture.
    static uint8_t cursor[68];
    for(uint16_t c=0;c<6;++c) {colors[10+c]=255;colors[10+255*8+c]=0;}
    for(uint16_t row=0;row<16;++row) {
        uint16_t mask=uint16_t(0xffffu>>(row%5));
        uint16_t image=uint16_t(0xa55au^(row*0x1111u));
        cursor[row*2]=image>>8;cursor[row*2+1]=image;
        cursor[32+row*2]=mask>>8;cursor[33+row*2]=mask;
    }
    cursor[65]=2;cursor[67]=3;
#endif
    uint16_t left=160,top=150;
    for(uint16_t frame=0;frame<5;++frame) {
        AitdScreen::DirtyRect dirty={150,160,350,480};uint16_t count=1;
        if(frame==1 || frame==2) {
            dirty=frame==1 ? AitdScreen::DirtyRect{153,195,155,229} : AitdScreen::DirtyRect{180,400,183,404};
            for(int16_t y=dirty.top;y<dirty.bottom;++y)for(int16_t x=dirty.left;x<dirty.right;++x)
                source[uint32_t(y)*640+x]=frame==1 ? 0x69 : 0xc3;
        }
        if(frame==3) {count=0;colors[10+42*8]=colors[11+42*8]=17;}
        if(frame==4) {left=161;top=151;count=0;}
        g_agaProbeViewport[0]=top;g_agaProbeViewport[1]=left;
        g_agaProbeViewport[2]=top+200;g_agaProbeViewport[3]=left+320;
        bool mouseAllowed=false;
#ifdef AITD_AGA_CURSOR_PROBE
        // Centre, clipped upper-left, clipped bottom, hidden, then disabled.
        const int16_t x[5]={180,160,460,220,221};
        const int16_t y[5]={180,150,349,220,221};
        screen->setMouseCursor(cursor,frame ? x[frame] : 170,frame ? y[frame] : 170,frame!=3);
        mouseAllowed=frame!=4;
#endif
        if(screen->presentMacFrame(source,colors,&dirty,count,left,top,mouseAllowed)!=1) {
            g_agaProbeError=frame+1;return false;
        }
        while(g_macFramesPresented<frame+1) {__asm__ volatile("nop");}
        uint16_t start=g_vbiCount;
        while(uint16_t(g_vbiCount-start)<2) {__asm__ volatile("nop");}
#ifdef AITD_AGA_CURSOR_PROBE
        if(frame==0) {
            // Move after publication without queuing a frame. The full capture
            // must contain the new XOR only, with no trail at the old position.
            screen->setMouseCursor(cursor,x[frame],y[frame],true);
            start=g_vbiCount;
            while(uint16_t(g_vbiCount-start)<2) {__asm__ volatile("nop");}
        }
#endif
        g_agaProbeStage=frame+1;aitdAgaProbeCheckpoint();
#ifdef AITD_AGA_VISUAL
        // Let the owner capture real, running video rather than a debugger stop.
        uint32_t visibleStart=g_macTicks;
        while(uint32_t(g_macTicks-visibleStart)<30*60) {__asm__ volatile("nop");}
#endif
    }
    return true;
}
void aitdAgaProbeRestored(uint16_t success)
{
    g_agaProbeDone=success;g_agaProbeStage=99;aitdAgaProbeCheckpoint();
}
}
#endif
