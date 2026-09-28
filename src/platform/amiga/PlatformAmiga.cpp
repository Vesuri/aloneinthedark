/* PlatformAmiga — the machine takeover.  See PlatformAmiga.h for the scope.
 *
 * The shape is inherited from the Revs port (same toolchain, same target, and its
 * ordering comments record failures that were paid for once already):
 *   LoadView(NULL) -> display DMA down -> VERTB vector taken over -> screen built ->
 *   publish to the ISR -> DMA up -> Forbid() -> frame pump -> restore in reverse.
 *
 * ⚠ INCLUDE ORDER IS LOAD-BEARING: every system header FIRST, AmigaHardware.h LAST
 * (its bare register macros collide with `struct Custom`'s members).
 */
#include <proto/exec.h>
#include <proto/graphics.h>
#include <proto/dos.h>
#include <exec/execbase.h>
#include <exec/interrupts.h>
#include <exec/nodes.h>
#include <exec/memory.h>
#include <graphics/gfxbase.h>
#include <graphics/view.h>
#include <dos/dos.h>
#include <hardware/dmabits.h>
#include <hardware/intbits.h>

#include "framework/AmigaHardware.h"
#include "framework/CopperList.h"
#include "PlatformAmiga.h"
#include "MacInput.h"
#include "AitdScreen.h"
#include "PerfProbe.h"
#include "mac/MacLoader.h"

extern struct GfxBase* GfxBase;         // opened below; the global lives in GCCRuntime.cpp

struct OriginalResourceFiles {
    uint8_t* application;
    uint32_t applicationSize;
    uint8_t* data;
    uint32_t dataSize;
};

static bool readOriginalResourceFork(const char* name, uint8_t*& bytes, uint32_t& size)
{
    bytes = 0;
    size = 0;
    BPTR file = Open((CONST_STRPTR)name, MODE_OLDFILE);
    if (!file) return false;
    bool ok = false;
    if (Seek(file, 0, OFFSET_END) >= 0) {
        LONG length = Seek(file, 0, OFFSET_CURRENT);
        if (length >= 16 && (uint32_t)length <= 4UL * 1024 * 1024
            && Seek(file, 0, OFFSET_BEGINNING) >= 0) {
            bytes = (uint8_t*)AllocMem((uint32_t)length, MEMF_ANY);
            if (bytes) {
                size = (uint32_t)length;
                LONG total = 0;
                while (total < length) {
                    LONG got = Read(file, bytes + total, length - total);
                    if (got <= 0) break;
                    total += got;
                }
                if (total == length) {
                    ok = true;
                }
            }
        }
    }
    Close(file);
    if (!ok && bytes) {
        FreeMem(bytes, size);
        bytes = 0;
        size = 0;
    }
    return ok;
}

static void releaseOriginalResourceFiles(OriginalResourceFiles& files)
{
    if (files.application)
        FreeMem(files.application, files.applicationSize);
    if (files.data)
        FreeMem(files.data, files.dataSize);
    files.application = files.data = 0;
    files.applicationSize = files.dataSize = 0;
}

// The development and installed layouts both keep the original application's
// raw resource fork as "Alone In The Dark", beside the executable or in data/.
// The "Alone Data" folder of .PAK/.ITD data-fork files is read later through
// the File Manager implementation, not preloaded here.
static bool loadOriginalResourceFiles(OriginalResourceFiles& files)
{
    files.application = files.data = 0;
    files.applicationSize = files.dataSize = 0;
    if (!readOriginalResourceFork("PROGDIR:data/Alone In The Dark",
                                  files.application, files.applicationSize) &&
        !readOriginalResourceFork("PROGDIR:Alone In The Dark",
                                  files.application, files.applicationSize)) {
        PutStr((CONST_STRPTR)
            "Alone: cannot read Alone In The Dark in PROGDIR:data/ or PROGDIR:\n");
        return false;
    }
    return true;
}

// ---------------------------------------------------------------------------
// ⚠⚠ EVERY GLOBAL A COMMITTED .gdb SCRIPT READS MUST BE IN amiga/Makefile's PROBE_SYMS.
// -Wl,--gc-sections drops an unreferenced counter, and gdb then resolves the name into
// .text and prints INSTRUCTION BYTES as a value -- a fake measurement, not an obvious
// zero.  `make probe-audit` enforces it on every link.  (CLAUDE.md)
//
// Bootstrap diagnostics: field count, allocation status and chip-RAM checksum.
extern "C" {
volatile uint16_t g_vbiCount      = 0;   // real PAL fields, the only honest timebase
volatile uint32_t g_planeChecksum = 0;   // of the blob IN CHIP RAM (AitdScreen)
volatile uint16_t g_screenReady   = 0;   // 0 = allocation failed, 1 = displaying
extern volatile uint32_t g_macTicks;
extern volatile uint32_t* g_macTicksAddress;
extern volatile uint32_t* g_macRndSeedAddress;
#ifdef AITD_PROBE
volatile uint16_t g_restoreSavedDmacon = 0;
volatile uint16_t g_restoreActualDmacon = 0;
volatile uint16_t g_restoreSavedIntena = 0;
volatile uint16_t g_restoreActualIntena = 0;
volatile uint16_t g_restoreViewMatches = 0;
#endif
}

#ifdef AITD_PROBE
// A stable post-WaitTOF breakpoint for quit_path.gdb. The values are sampled
// before entry, so its first instruction observes the completed handback.
extern "C" __attribute__((noinline)) void aitdRestoreComplete()
{
    __asm__ volatile ("" ::: "memory");
}
#endif

static AitdScreen* s_screen = 0;

static struct Interrupt s_vbiServer;
static struct IntVector s_savedVertb;
static bool     s_vertbTaken  = false;
static uint16_t s_savedDmacon = 0;
static uint16_t s_savedIntena = 0;
static uint16_t s_macTickRemainder = 0;

// exec puts IntVects[] at ExecBase+84, so VERTB (bit 5) is ExecBase+144 -- exactly the
// offset Kickstart's level-3 autovector stub dispatches through.  If this stops compiling,
// the vector takeover needs re-deriving before it is trusted.
static_assert(__builtin_offsetof(struct ExecBase, IntVects) == 84,
              "ExecBase::IntVects moved — re-check the VERTB vector takeover");

static uint32_t vbiHandler()
{
    // ⚠ Clearing the request is THIS handler's job now -- exec's server-chain walker used
    // to do it and we replaced it.  Miss it and level 3 re-triggers forever.
    *intreqPointer = (uint16_t)INTF_VERTB;

    // Advance the monotonic profiling epoch before opening the VBI bracket.  A
    // bracket around this increment appears one whole field long even when the
    // handler used only a few scanlines.
    g_vbiCount++;
#ifdef AITD_PROBE
    AitdProfileScope profileVBI(kProfileVBI);
#endif

    // ⭐⭐ THE COPPER BITPLANE POINTERS GO FIRST, before any other ISR work.  "In the VBI
    // ISR" is not "in the vblank": anything behind another 100+ scanlines of handler lands
    // inside the displayed picture, and a torn pointer garbages the whole field.
    // (docs/amiga-arch.md)
    if (s_screen) s_screen->vbiUpdate();

    // Macintosh Ticks advances at ~60 Hz; PAL VERTB is 50 Hz.  Four fields add
    // one tick and every fifth adds two, preserving real-time animation speed.
    uint16_t tickDelta = 1;
    if (++s_macTickRemainder == 5) { s_macTickRemainder = 0; tickDelta = 2; }
    g_macTicks += tickDelta;
    if (g_macTicksAddress) *g_macTicksAddress = g_macTicks;
    // System 6 keeps its low-memory random seed live independently of each
    // application's QuickDraw randSeed.  MAME shows it one tick behind Ticks;
    // Vette copies it into qd.randSeed once during startup.
    if (g_macRndSeedAddress) *g_macRndSeedAddress = g_macTicks - 1;

    aitdProfileOnVBI();
    return 0;
}

// ---------------------------------------------------------------------------
bool PlatformAmiga::run()
{
    // Everything this function touches, it opens here and closes at the end.  See the header
    // for why none of this is in a constructor.
    GfxBase = (struct GfxBase*)OpenLibrary((CONST_STRPTR)"graphics.library", 33);
    if (!GfxBase) return false;     // nothing has been changed yet, so there is nothing to undo
    // Use the OS chipset report: OCS has no reliable DENISEID register.
    AmigaHardware::hasAGAChipSet = GfxBase->LibNode.lib_Version >= 39
        && (GfxBase->ChipRevBits0 & GFXF_AA_LISA) != 0;
    DOSBase = (struct DosLibrary*)OpenLibrary((CONST_STRPTR)"dos.library", 33);
    if (!DOSBase) {
        CloseLibrary((struct Library*)GfxBase);
        GfxBase = 0;
        return false;
    }

    static AitdScreen screen;      // file-scope lifetime, off the stack — see src/main.cpp
    static MacLoader loader;
    OriginalResourceFiles resourceFiles = {};
    if (!loadOriginalResourceFiles(resourceFiles)) {
        CloseLibrary((struct Library*)GfxBase);
        GfxBase = 0;
        CloseLibrary((struct Library*)DOSBase);
        DOSBase = 0;
        return false;
    }
    if (!loader.prepareResourceForks(resourceFiles.application,
                                     resourceFiles.applicationSize,
                                     resourceFiles.data, resourceFiles.dataSize)) {
        PutStr((CONST_STRPTR)
            "Alone: the original application resource fork is invalid or unsupported.\n");
        releaseOriginalResourceFiles(resourceFiles);
        CloseLibrary((struct Library*)GfxBase);
        GfxBase = 0;
        CloseLibrary((struct Library*)DOSBase);
        DOSBase = 0;
        return false;
    }

    // --- takeover -----------------------------------------------------------
    struct View* savedView = GfxBase->ActiView;
    const CopperList osCopperList((uint32_t*)GfxBase->copinit); // non-owning
    // Rescue on Fractalus established that LoadView restores neither COP1LC
    // nor the DMA/interrupt masks. Capture all three before the first write.
    s_savedDmacon = AmigaHardware::enabledDMAChannels();
    s_savedIntena = AmigaHardware::enabledInterrupts();
#ifdef AITD_PROBE
    g_restoreSavedDmacon = s_savedDmacon;
    g_restoreSavedIntena = s_savedIntena;
#endif
    LoadView(NULL);
    WaitTOF();
    WaitTOF();

    // Raster + sprite + copper DMA off so no OS state leaks through.  Copper comes back
    // on below, once OUR list is installed.
    *dmaconPointer = (uint16_t)(DMAF_RASTER | DMAF_SPRITE | DMAF_COPPER);

    // Mask blit-done: nothing here consumes it and every armed one is a pointless level-3
    // dispatch into graphics.library's queue handler.  INTENA is restored verbatim.
    *intenaPointer = (uint16_t)INTF_BLIT;    // no SETCLR = disable
    *intreqPointer = (uint16_t)INTF_BLIT;

    // A KNOWN-BLANK display for the window before the screen exists: no bitplanes.
    // ⚠ The geometry is NOT set here.  It has exactly one owner, AitdScreen.
    *bplcon0Pointer = 0x0000;

    // --- take over the whole VERTB vector ------------------------------------
    // Not AddIntServer: exec's iv_Code IS the server-chain walker, so overwriting it drops
    // graphics.library / gameport.device / timer.device off the vblank entirely.  iv_Node
    // is cosmetic -- it is what OS debug tools report as the vector's owner.
    s_vbiServer.is_Node.ln_Type = NT_INTERRUPT;
    s_vbiServer.is_Node.ln_Pri  = 127;
    s_vbiServer.is_Node.ln_Name = (char*)"Alone VBI";
    s_vbiServer.is_Data = 0;
    s_vbiServer.is_Code = (void(*)())vbiHandler;
    {
        struct IntVector* iv = &SysBase->IntVects[INTB_VERTB];
        Disable();
        s_savedVertb = *iv;
        iv->iv_Data = 0;
        iv->iv_Code = (void(*)())vbiHandler;
        iv->iv_Node = &s_vbiServer.is_Node;
        Enable();
        s_vertbTaken = true;
    }

    // --- bring the screen up -------------------------------------------------
    // Start black.  No captured Macintosh framebuffer is embedded or displayed:
    // every non-black pixel seen from here on comes from the original Mac code
    // drawing into its emulated QuickDraw surface and our planar conversion of it.
    bool ok = screen.initialize(0, 0);
    g_screenReady   = ok ? 1 : 0;
    g_planeChecksum = ok ? screen.pictureChecksum() : 0;

    // ⭐⭐ PUBLISH TO THE ISR ONLY ONCE THE SCREEN IS BUILT.  The VERTB vector has been ours
    // for ~40 lines already, so the handler is firing at 50 Hz throughout initialize() --
    // which calls AllocMem twice and comfortably spans a vblank.  An ISR that saw the
    // half-built object would patch a copper list that has not been written yet.  (This is
    // the Revs black-screen bug, which every probe reported as healthy.)
    if (ok) s_screen = &screen;

    // Our list is installed and the mode registers are set — safe to start display DMA.
    // Sprite 0 is the mouse pointer and is rebuilt by AitdScreen at every VBI.
    if (ok)
        *dmaconPointer = (uint16_t)(DMAF_SETCLR | DMAF_MASTER | DMAF_COPPER
                                  | DMAF_RASTER | DMAF_SPRITE);

    // Install the keyboard edge queue while Exec calls are still legal.
    if (ok) ok = aitdInputInitialize();

    // --- run -----------------------------------------------------------------
    // Nothing here Wait()s, so multitasking can stay off for the duration.
    Forbid();

    // Stage B hands control to the original Macintosh instructions.  Its Line-A handler
    // services the one prerequisite (_BlockMove), then deliberately stops on the first
    // unimplemented trap and paints the full diagnostic into this screen.
    if (ok) ok = loader.run(&screen);

    // Keep multitasking forbidden through the Wait()-free hardware handback.
    // Permit belongs immediately before LoadView/WaitTOF, after exec's VERTB
    // vector and the saved interrupt mask are live again.
    aitdInputShutdown();

    // --- restore, in reverse --------------------------------------------------
    // Stop our VBI and display before changing or freeing anything they read.
    AmigaHardware::setInterrupts(INTF_VERTB, false);
    AmigaHardware::clearInterruptRequests(INTF_VERTB);
    AmigaHardware::setDMAChannels(DMAF_COPPER | DMAF_RASTER | DMAF_SPRITE, false);

    // LoadView publishes the View through COP2LC but does not restore COP1LC.
    // Put graphics.library's startup list back, run it, and undo ECS border
    // blanking before releasing our copper list and bitplanes.
    AmigaHardware::setCopperList(osCopperList, true);
    *bplcon3Pointer = 0x0c00;
    AmigaHardware::setDMAChannels(DMAF_COPPER, true);
    AmigaHardware::blitterDrain();
    s_screen = 0;
    screen.shutdown();

    // VERTB goes back before its saved enable bit and before WaitTOF: the wait
    // is signalled by graphics.library's server behind exec's original vector.
    if (s_vertbTaken) {
        Disable();
        SysBase->IntVects[INTB_VERTB] = s_savedVertb;
        Enable();
        s_vertbTaken = false;
    }

    // Clear every channel/enable the game may have changed, then reproduce
    // the exact writable masks captured at takeover. In particular this stops
    // Paula voices and restores the OS copper/raster/master bits rather than
    // assuming a fixed Workbench configuration.
    AmigaHardware::clearInterruptRequests(INTF_BLIT);
    const uint16_t dmaMask = DMAF_ALL | DMAF_MASTER | DMAF_BLITHOG;
    AmigaHardware::setDMAChannels(dmaMask, false);
    AmigaHardware::setInterrupts(0x7fffu, false);
    AmigaHardware::setDMAChannels((uint16_t)(s_savedDmacon & dmaMask), true);
    AmigaHardware::setInterrupts(
        (uint16_t)((s_savedIntena & (uint16_t)~INTF_SETCLR) | INTF_INTEN), true);

    Permit();
    LoadView(savedView);
    WaitTOF();
    WaitTOF();
#ifdef AITD_PROBE
    g_restoreActualDmacon = (uint16_t)(AmigaHardware::enabledDMAChannels() & dmaMask);
    g_restoreActualIntena = AmigaHardware::enabledInterrupts();
    g_restoreViewMatches = (uint16_t)(GfxBase->ActiView == savedView);
    aitdRestoreComplete();
#endif

    // Any deferred save-game or preference writes belong here, once the OS owns
    // interrupts, DMA, the View, and multitasking again (Vette's score file
    // established the rule): disk I/O during the takeover would resume
    // unrelated tasks against partially restored state.
    loader.releaseResourceForks();
    releaseOriginalResourceFiles(resourceFiles);

    // Closed here rather than in a destructor -- see the note in PlatformAmiga.h.  ⚠ AFTER
    // the LoadView restore, which needs GfxBase.
    CloseLibrary((struct Library*)GfxBase);
    GfxBase = 0;
    if (DOSBase) {
        CloseLibrary((struct Library*)DOSBase);
        DOSBase = 0;
    }
    return true;
}
