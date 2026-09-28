#include <proto/exec.h>
#include <exec/memory.h>
#include <hardware/dmabits.h>

#include "MacLoader.h"
#include "LowMemory.h"
#include "MacHeap.h"
#include "MacFiles.h"
#include "FileReadCache.h"
#include "FileWriteBuffer.h"
#include "platform/amiga/FileAccess.h"
#include "platform/amiga/FileMetadataIO.h"
#include "ResourceForks.h"
#include "platform/amiga/AitdScreen.h"
#include "platform/amiga/MacInput.h"
#include "platform/amiga/PerfProbe.h"
#include "platform/amiga/framework/AmigaHardware.h"
#include "PaulaSample.h"

extern "C" {
void aitd_line_a_handler();
void aitd_call_mac_code(void* entry, void* a5, void* stackTop);
void aitd_user_exit_request();
void aitd_user_exit_trampoline();
void aitd_os_patch_return();
void aitd_user_vbl_trampoline();
extern volatile uint16_t g_macFramesPresented;
extern volatile uint16_t g_vbiCount;
#ifdef AITD_MAPPED_COPY_ASM
void aitdMappedCopyRowsAsm(const uint8_t* source, uint8_t* destination,
                            const uint8_t* map, uint32_t rowBytes, uint32_t height,
                            uint32_t sourceModulo, uint32_t destinationModulo);
#endif

volatile uint16_t g_stageBState = 0;
volatile uint16_t g_trapWord = 0;
volatile int32_t  g_trapSelector = -1;
volatile uint16_t g_trapSegment = 0xffff;
volatile uint32_t g_trapOffset = 0xffffffffUL;
volatile uint32_t g_trapPC = 0;
volatile uint32_t g_trapRegisters[15] = {0};
volatile uint32_t g_trapUserStack = 0;
volatile uint32_t g_resourceCount = 0;
volatile uint16_t g_jumpEntryCount = 0;
volatile uint16_t g_blockMoveCount = 0;
volatile uint16_t g_stageCDepth = 1;       // _BlockMove is row 1
volatile uint32_t g_macTicks = 0;
volatile uint32_t g_mouseVBISamples = 0;
volatile uint32_t g_mouseVBIMoves = 0;
#ifdef AITD_PROBE
volatile uint32_t g_probeCopyMapIdentity = 0;
volatile uint32_t g_probeCopyMapHits = 0;
volatile uint32_t g_probeCopyMapMisses = 0;
volatile uint32_t g_probeCopyBitsTicks = 0;
volatile uint32_t g_probeCopyBitsCalls = 0;
volatile uint32_t g_probeDelayCalls = 0;
volatile uint32_t g_probeDelayRequested = 0;
volatile uint32_t g_probeBlockMoveTicks = 0;
volatile uint32_t g_probeBlockMoveCalls = 0;
volatile uint32_t g_probeDrawPictureTicks = 0;
volatile uint32_t g_probeDrawPictureCalls = 0;
volatile int16_t g_probeDrawPictureTrace[64][5] = {};
volatile uint32_t g_probeDrawPictureTraceTicks[64] = {};
volatile uint16_t g_probePaulaZeroedMask = 0x000f;
volatile uint16_t g_probeCopyTraceEnabled = 0;
volatile uint16_t g_probeCopyTraceCount = 0;
volatile int16_t g_probeCopyTrace[32][12] = {};
volatile uint32_t g_probeCopyModeTicks[7] = {};
volatile uint32_t g_probeCopyModeCalls[7] = {};
#endif
volatile uint32_t* g_macTicksAddress = 0;
volatile uint32_t* g_macRndSeedAddress = 0;
volatile uint32_t g_macVBLCallbackEntry = 0;
volatile uint32_t g_macVBLCallbackTask = 0;
volatile uint32_t g_macVBLCallbackA5 = 0;
volatile uint32_t g_macVBLCallbackReturn = 0;
volatile uint16_t g_macVBLCallbackActive = 0;
volatile uint32_t g_macHostReturnSP = 0;
uint8_t* g_macStackBase = 0;
uint8_t* g_macLowMemory = 0;
uint8_t* g_startupCode = 0;
volatile uint16_t g_startupLowMemoryPatches = 0;
volatile uint16_t g_lowMemoryValidatedSites = 0;
volatile uint16_t g_lowMemoryAppliedSites = 0;
volatile uint32_t g_loadedCodeMask = 0;
uint8_t* g_code3Base = 0;
uint8_t* g_applicationZoneBase=0;
uint8_t* g_systemZoneBase=0;
volatile uint32_t g_heapFree=0, g_heapLargest=0, g_heapSystemFree=0;
volatile int16_t g_heapError=0;
volatile uint32_t g_macLineAVectorAddress = 0;
volatile uint32_t g_macSavedLineAVector = 0;
volatile uint16_t g_macLineAInstalled = 0;
#ifdef AITD_LINE_A_PROBE
volatile uint32_t g_lineAProbe[42] = {};
void aitd_line_a_probe();
void aitd_line_a_exit_probe();
__attribute__((noinline)) void aitdLineAProbeComplete() { __asm__ volatile("" ::: "memory"); }
#endif
#ifdef AITD_HEAP_PROBE
volatile uint32_t g_heapProbeStage=0, g_heapProbeDone=0;
void aitd_heap_probe();
__attribute__((noinline)) void aitdHeapProbeComplete() { __asm__ volatile("" ::: "memory"); }
#endif
#ifdef AITD_IDENTITY_PROBE
volatile uint32_t g_identityProbeStage=0;
void aitd_identity_probe();
__attribute__((noinline)) void aitdIdentityProbeReturned() { __asm__ volatile("" ::: "memory"); }
#endif
#ifdef AITD_FILE_PROBE
void aitdFileProbe();
#endif
#ifdef AITD_WINDOW_PROBE
bool aitdWindowProbe();
void aitd_window_probe();
#endif
volatile uint16_t g_macServiceActive=0;
volatile uint32_t g_macServiceEntered=0, g_macServiceCompleted=0;
#ifdef AITD_SERVICE_PROBE
volatile uint32_t g_serviceProbe[68]={};
void aitd_service_probe();
void aitd_service_nested_probe();
__attribute__((noinline)) void aitdServiceProbeComplete() { __asm__ volatile("" ::: "memory"); }
#endif
volatile uint16_t g_macExitState = 0;
#ifdef AITD_PROBE
#endif
#ifdef AITD_MAPPED_COPY_VERIFY
volatile uint32_t g_mappedCopyAsmTicks = 0;
volatile uint32_t g_mappedCopyCTicks = 0;
volatile uint32_t g_mappedCopyVerifyCalls = 0;
volatile uint32_t g_mappedCopyVerifyBytes = 0;
volatile uint32_t g_mappedCopyVerifyFailures = 0;
#endif
char g_trapManager[24] = "";
char g_trapRoutine[24] = "";
}

// Private shadows for the classic-Mac Page-0 globals the original code reads
// or writes directly.  Page 0 holds exception vectors and Exec state on the
// Amiga, so byte-verified absolute-address accesses are redirected here
// instead. The shadows follow the jump table within d16(A5) reach; M1.4
// extends the currently implemented CODE 1 startup patch set.
static const uint16_t kLowTicks = 0;         // $016A
static const uint16_t kLowRndSeed = 4;       // $0156
static const uint16_t kLowWMgrPort = 8;      // $09DE
static const uint16_t kLowGrayRgn = 12;      // $09EE
static const uint16_t kLowKeyMap = 16;       // $0174, 16 bytes
static const uint16_t kLowCurrentA5 = MacLowMemory::currentA5;    // $0904
static const uint16_t kLowMBState = 36;      // $0172
static const uint16_t kLowMTempV = 38;       // $0828
static const uint16_t kLowMTempH = 40;       // $082A
static const uint16_t kLowRawMouseV = 42;    // $082C
static const uint16_t kLowRawMouseH = 44;    // $082E
static const uint16_t kLowMouseV = 46;       // $0830
static const uint16_t kLowCurStackBase = MacLowMemory::curStackBase; // $0908: lowest A5 global, not execution stack
static const uint16_t kLowMouseH = 48;       // $0832
static uint8_t s_initialLowMemory[MacLowMemory::size] __attribute__((aligned(4)));
static uint8_t* s_portLowMemory = s_initialLowMemory;
static const char* s_preparationError = "RESOURCE FORK / INVALID OR UNSUPPORTED";
// The A5 world is sized by CODE 0, not by a compile-time constant: this
// application's 75616 bytes below A5 would not fit Vette's static layout.
static uint8_t* s_a5WorldStorage;
static uint32_t s_a5WorldBytes;
static uint32_t s_jumpTableOffset;
static AitdScreen* s_loudStopScreen;
static ResourceForks s_resourceForks;
static MacFiles s_files;
struct DataSource {
    uint32_t id=0;bool resource=false;
    FileAccess::ReadStream* backing=0;
    FileWriteBuffer writes;
};
static DataSource s_dataSources[MacFiles::maxOpen];
static int32_t readDataSource(void* context,uint32_t offset,uint8_t* bytes,uint32_t count,uint32_t& actual) {
    DataSource* source=(DataSource*)context;
    return FileAccess::readStream(source->backing,offset,bytes,count,actual);
}
struct DataFork {
    int16_t ref=0;
    FileAccess::ReadStream stream={0};
    uint8_t* buffer=0;
    FileReadCache cache;
    DataSource* source=0;
};
static DataFork s_dataForks[MacFiles::maxOpen];
static int16_t s_resourceFileRefs[ResourceForks::kForkCount];
MacFiles& MacLoader::files() { return s_files; }
extern "C" { volatile int16_t g_applicationFileRef=0; }
static MacHeap::Handle s_resourceHandles[ResourceForks::kMaximumResources];
static int16_t s_resourceError;
static uint8_t s_quickDrawScreen[(512 / 8) * 320];
static uint8_t s_colorScreen[(512 / 2) * 320];
// The first driving frame expands its roadside panorama as 512x24 8-bit
// strips.  Keep one strip's decode storage resident so all 38 calls share the
// same small working set instead of entering Exec's allocator for every PICT.
// Larger pictures retain the existing allocation path.
static uint8_t s_indexedPictureScratch[512 * 24];
#ifdef AITD_MAPPED_COPY_VERIFY
static uint8_t s_mappedCopyVerify[512 * 342 / 2];
#endif
static uint8_t s_windowManagerPort[108];
static uint8_t s_windowManagerPixMap[50];
static uint8_t* s_windowManagerPixMapMaster;
static uint8_t s_mainDevice[62];
static uint8_t* s_mainDeviceMaster;
static uint8_t s_mainDeviceITable[6 + 4096];
static uint8_t* s_mainDeviceITableMaster;
static uint8_t s_windowManagerColors[8 + 16 * 8];
static uint8_t* s_windowManagerColorsMaster;
static uint8_t s_windowManagerVisRgn[10];
static uint8_t* s_windowManagerVisRgnMaster;
static uint8_t s_windowManagerClipRgn[10];
static uint8_t* s_windowManagerClipRgnMaster;
static uint8_t s_grayRgn[10];
static uint8_t* s_grayRgnMaster;
static uint8_t s_textEditScrap[1];
static uint8_t* s_textEditScrapMaster;
static uint8_t s_trapBuiltins[4096][6] __attribute__((aligned(4)));
static uint8_t* s_trapAddresses[4096];
static uint8_t* s_qdThePort;
#ifdef AITD_PROBE
static volatile uint32_t s_randomTrapPC;
#endif
static uint8_t* s_currentA5;
static uint16_t s_currentResourceFork = 0;  // application resource file at process launch
static volatile bool s_mouseInitialized;
static uint8_t s_mouseCounterX, s_mouseCounterY;
static volatile int16_t s_mouseX = 256, s_mouseY = 160;
static volatile bool s_mouseHardwareButtonDown;
static bool s_mouseButtonDown;
static uint8_t* s_mouseGlobalsA5;

struct WindowSlot {
    uint8_t record[170];                    // WindowRecord plus DialogRecord tail
    uint8_t* window;
    bool used;
    uint8_t structureRegion[10];
    uint8_t* structureRegionMaster;
    uint8_t contentRegion[10];
    uint8_t* contentRegionMaster;
    uint8_t clipRegion[10];
    uint8_t* clipRegionMaster;
    uint8_t updateRegion[10];
    uint8_t* updateRegionMaster;
    uint8_t title[256];
    uint8_t* titleMaster;
    int16_t procID;
    int16_t resourceID; // Original WIND/DLOG identity, retained for presentation.
    uint8_t** palette;
    bool paletteUpdates;
    bool updating;
    bool dialog;
    uint16_t dialogItemCount;
    bool dialogDrawn;
};
static WindowSlot s_windows[8];
static uint8_t* s_windowList;
static uint32_t s_colorSeed = 1;
static uint8_t** s_activePalette;
static bool s_screenDirty = true;
static bool s_pixelsDirty = false;
static int16_t s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight;
static AitdScreen::DirtyRect s_dirtyRects[AitdScreen::kMaxDirtyRects];
static uint16_t s_dirtyRectCount;
static bool s_suppressDirectScreenDirty;
static volatile uint8_t s_unsupportedPictureOpcode;
static volatile uint32_t s_unsupportedPictureOffset;
static uint16_t read16(const uint8_t* p);

static bool dirtyRectContains(const AitdScreen::DirtyRect& outer,
                              const AitdScreen::DirtyRect& inner)
{
    return outer.top <= inner.top && outer.left <= inner.left
        && outer.bottom >= inner.bottom && outer.right >= inner.right;
}

static bool dirtyRectsMergeLosslessly(const AitdScreen::DirtyRect& a,
                                      const AitdScreen::DirtyRect& b)
{
    if (dirtyRectContains(a, b) || dirtyRectContains(b, a)) return true;
    bool sameColumns = a.left == b.left && a.right == b.right
        && a.top <= b.bottom && a.bottom >= b.top;
    bool sameRows = a.top == b.top && a.bottom == b.bottom
        && a.left <= b.right && a.right >= b.left;
    return sameColumns || sameRows;
}

static void appendDirtyBounds(AitdScreen::DirtyRect* rectangles, uint16_t& count,
                              int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    AitdScreen::DirtyRect rectangle = { top, left, bottom, right };
    bool merged;
    do {
        merged = false;
        for (uint16_t i = 0; i < count; ++i) {
            AitdScreen::DirtyRect& existing = rectangles[i];
            if (!dirtyRectsMergeLosslessly(rectangle, existing)) continue;
            if (existing.top < rectangle.top) rectangle.top = existing.top;
            if (existing.left < rectangle.left) rectangle.left = existing.left;
            if (existing.bottom > rectangle.bottom) rectangle.bottom = existing.bottom;
            if (existing.right > rectangle.right) rectangle.right = existing.right;
            existing = rectangles[--count];
            merged = true;
            break;
        }
    } while (merged);
    if (count < AitdScreen::kMaxDirtyRects) rectangles[count++] = rectangle;
    else {
        // Correctness fallback: retain every touched pixel when a scene is
        // more fragmented than the fixed list can represent.
        for (uint16_t i = 0; i < count; ++i) {
            if (rectangles[i].top < rectangle.top) rectangle.top = rectangles[i].top;
            if (rectangles[i].left < rectangle.left) rectangle.left = rectangles[i].left;
            if (rectangles[i].bottom > rectangle.bottom) rectangle.bottom = rectangles[i].bottom;
            if (rectangles[i].right > rectangle.right) rectangle.right = rectangles[i].right;
        }
        rectangles[0] = rectangle;
        count = 1;
    }
}

static void markDirtyBounds(int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    if (top >= bottom || left >= right) return;
    if (!s_pixelsDirty) {
        s_dirtyTop = top; s_dirtyLeft = left;
        s_dirtyBottom = bottom; s_dirtyRight = right;
        s_pixelsDirty = true;
    } else {
        if (top < s_dirtyTop) s_dirtyTop = top;
        if (left < s_dirtyLeft) s_dirtyLeft = left;
        if (bottom > s_dirtyBottom) s_dirtyBottom = bottom;
        if (right > s_dirtyRight) s_dirtyRight = right;
    }
    appendDirtyBounds(s_dirtyRects, s_dirtyRectCount, top, left, bottom, right);
    s_screenDirty = true;
}

static void markDirty(const uint8_t* rectangle)
{
    if (!rectangle) return;
    markDirtyBounds((int16_t)read16(rectangle), (int16_t)read16(rectangle + 2),
                    (int16_t)read16(rectangle + 4), (int16_t)read16(rectangle + 6));
}

// VBLTask is a 14-byte 68k record: qLink, qType, vblAddr, vblCount,
// vblPhase.  Keep the caller-owned records linked exactly as the classic
// Vertical Retrace Manager does.  Execution is deliberately a separate
// concern: calling application code from Amiga's supervisor-mode VERTB ISR
// would give Line-A traps the wrong exception/USP context.
static uint8_t* s_vblTasks[8];
static uint16_t s_vblTaskCount;
static uint16_t s_vblPassIndex;
static uint16_t s_vblPassLimit;
static uint32_t s_vblPendingTicks;
static bool s_vblPassActive;
static uint32_t s_vblLastTick;
static uint32_t s_vblDispatchTick;

#ifdef AITD_PROBE
static uint32_t probeNonzeroBytes(const uint8_t* data, uint16_t bytes)
{
    uint32_t count = 0;
    while (bytes--) if (*data++) ++count;
    return count;
}
#endif

struct GWorldSlot {
    uint8_t port[108];
    uint8_t pixMap[50];
    uint8_t* pixMapMaster;
    uint8_t colorTable[8 + 16 * 8];
    uint8_t* colorTableMaster;
    uint8_t** palette;
    uint8_t visRegion[10];
    uint8_t* visRegionMaster;
    uint8_t clipRegion[10];
    uint8_t* clipRegionMaster;
    uint8_t* pixels;
    bool used;
    bool locked;
    bool purgeable;
};
// Initialize can keep six offscreen worlds alive at once.  This is capacity,
// not emulated heap exhaustion: a full slot table must never masquerade as a
// Macintosh memFullErr while Exec still has memory available.
static GWorldSlot s_gworlds[8];
static uint32_t s_gworldAllocationBytes[8];

struct FontManagerState {
    bool initialized;
    int16_t systemFont;
    int16_t systemSize;
};
static FontManagerState s_fontManager;

struct WindowManagerState {
    bool initialized;
    bool palettesInitialized;
    uint8_t* port;
};
static WindowManagerState s_windowManager;

struct MenuManagerState {
    bool initialized;
    uint8_t** colorTable;
    int16_t highlightedID;
    struct Entry {
        uint8_t** handle;
        bool inMenuBar;
    } entries[16];
    uint16_t count;
};
static MenuManagerState s_menuManager;

struct TextEditState {
    bool initialized;
    uint8_t** scrap;
};
static TextEditState s_textEdit;

struct DialogManagerState {
    bool initialized;
    uint8_t* resumeProcedure;
};
static DialogManagerState s_dialogManager;

struct CursorState {
    bool initialized;
    bool visible;
    const uint8_t* image;
};
static CursorState s_cursor;

static MacHeap s_applicationZone, s_systemZone;
static MacHeap* s_currentZone = &s_applicationZone;
static const uint32_t kApplicationZoneBytes = 3145728, kSystemZoneBytes = 131072;
static uint8_t* s_applicationArena;
static uint8_t* s_systemArena;
static uint8_t* s_applicationLimit;
static int16_t s_memoryError;

static void releaseZones()
{
    s_applicationZone.reset();s_systemZone.reset();
    if(s_applicationArena)FreeMem(s_applicationArena,kApplicationZoneBytes);
    if(s_systemArena)FreeMem(s_systemArena,kSystemZoneBytes);
    s_applicationArena=s_systemArena=s_applicationLimit=0;
    g_applicationZoneBase=g_systemZoneBase=0;
}
static bool prepareZones()
{
    releaseZones();
    s_applicationArena=(uint8_t*)AllocMem(kApplicationZoneBytes,MEMF_FAST|MEMF_CLEAR);
    s_systemArena=(uint8_t*)AllocMem(kSystemZoneBytes,MEMF_FAST|MEMF_CLEAR);
    if(!s_applicationArena || !s_systemArena
        || !s_applicationZone.init(s_applicationArena,kApplicationZoneBytes)
        || !s_systemZone.init(s_systemArena,kSystemZoneBytes,32)) {
        releaseZones();return false;
    }
    s_currentZone=&s_applicationZone;
    s_applicationLimit=s_applicationArena+kApplicationZoneBytes;
    s_memoryError=0;
    g_applicationZoneBase=s_applicationArena;g_systemZoneBase=s_systemArena;
    return true;
}
static MacHeap* handleZone(MacHeap::Handle h)
{
    if(s_applicationZone.isHandle(h))return &s_applicationZone;
    if(s_systemZone.isHandle(h))return &s_systemZone;
    return 0;
}
static MacHeap* pointerZone(uint8_t* p)
{
    if(s_applicationZone.owns(p))return &s_applicationZone;
    if(s_systemZone.owns(p))return &s_systemZone;
    return 0;
}
#ifdef AITD_PROBE
volatile uint16_t g_probeReleasedGWorlds;
volatile uint16_t g_probeReleasedPointers;
volatile uint16_t g_probeReleasedHandles;
#endif

// CODE resource IDs index this table directly.  Names are the CODE resource
// names, so attribution reads (Dark, $0123) rather than a bare number.
static const uint16_t kMaximumSegments = 32;
struct Segment { uint8_t* begin; uint8_t* end; char name[24]; uint32_t size; MacHeap::Handle handle; };
static Segment s_segments[kMaximumSegments];
static uint16_t s_segmentCount;             // highest loaded CODE ID + 1

static uint16_t read16(const uint8_t* p) { return (uint16_t)((p[0] << 8) | p[1]); }
static uint32_t read32(const uint8_t* p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}
static void write16(uint8_t* p, uint16_t v) { p[0] = (uint8_t)(v >> 8); p[1] = (uint8_t)v; }
static int16_t resourceResult(int16_t error)
{
    s_resourceError=error;write16(s_portLowMemory+140,(uint16_t)error);return error;
}
static int16_t memoryResult(int16_t error);
static void writeBoolean(uint8_t* p, bool value) { p[0] = value ? 1 : 0; p[1] = 0; }
static void write32(uint8_t* p, uint32_t v)
{
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}
static void copyString(char* out, const char* in)
{
    uint16_t i = 0;
    while (i != 23 && in[i]) { out[i] = in[i]; ++i; }
    out[i] = 0;
}

static void clearResidentSegments()
{
    for (uint16_t i = 0; i < kMaximumSegments; ++i) {
        if(i==0)delete[] s_segments[i].begin;
        else if(MacHeap* zone=handleZone(s_segments[i].handle))zone->disposeHandle(s_segments[i].handle);
        s_segments[i].handle=0;
        s_segments[i].begin = s_segments[i].end = 0;
        s_segments[i].name[0] = 0;
        s_segments[i].size = 0;
    }
    s_segmentCount = 0;
    g_startupCode = 0;
    g_code3Base = 0;
    g_loadedCodeMask = 0;
    g_startupLowMemoryPatches = 0;
    g_lowMemoryValidatedSites = g_lowMemoryAppliedSites = 0;
}

static bool loadStartupSegments()
{
    clearResidentSegments();
    uint16_t checkedSegments = 0, checkedSites = 0;
    for (uint32_t index = 0; index < s_resourceForks.resourceCount(); ++index) {
        ResourceForks::Item item;
        if (!s_resourceForks.item(index, item)) {
            clearResidentSegments();
            return false;
        }
        if (item.fork != 0 || item.type != 0x434f4445UL) continue;   // 'CODE'
        if (item.id < 0 || item.id >= (int16_t)kMaximumSegments || item.size < 4
            || s_segments[item.id].size) {
            clearResidentSegments();
            return false;
        }
        if (item.id > 0) {
            if (!MacLowMemory::validate(item.id, item.data, item.size)) {
                s_preparationError = "LOW MEMORY / ORIGINAL CODE MISMATCH";
                clearResidentSegments();
                return false;
            }
            ++checkedSegments;
            checkedSites += MacLowMemory::siteCount(item.id);
        }
        Segment& segment = s_segments[item.id];
        segment.size = item.size;
        // CODE 0 is metadata; CODE 1 is the only executable loaded at launch.
        if (item.id <= 1) {
            if(item.id==0)segment.begin = new uint8_t[item.size];
            else {
                segment.handle=s_applicationZone.newHandle(item.size);
                if(segment.handle) {
                    segment.begin=*segment.handle;
                    s_applicationZone.setState(segment.handle,0x20|((item.attrs&0x10)?0x80:0)|((item.attrs&0x20)?0x40:0));
                    s_resourceHandles[index]=segment.handle;
                }
            }
            if (!segment.begin) { clearResidentSegments(); return false; }
            for (uint32_t byte = 0; byte < item.size; ++byte)
                segment.begin[byte] = item.data[byte];
            segment.end = segment.begin + item.size;
            g_loadedCodeMask |= 1UL << item.id;
        }
        uint16_t length = item.nameLength < sizeof(segment.name) - 1
            ? item.nameLength : (uint16_t)(sizeof(segment.name) - 1);
        for (uint16_t c = 0; c < length; ++c) segment.name[c] = (char)item.name[c];
        segment.name[length] = 0;
        if (!length) copyString(segment.name, item.id ? "CODE" : "CODE0");
        if ((uint16_t)item.id + 1 > s_segmentCount) s_segmentCount = (uint16_t)(item.id + 1);
    }
    if (checkedSegments != MacLowMemory::segmentCount || checkedSites != MacLowMemory::count) {
        s_preparationError = "LOW MEMORY / SITE COUNT";
        clearResidentSegments();
        return false;
    }
    if (!s_segments[0].begin || !s_segments[1].begin) {
        clearResidentSegments();
        return false;
    }
    const uint8_t* header = s_segments[0].begin;
    if (s_segments[0].end - header != 3760 || read32(header) != 3776
        || read32(header + 4) != 75616 || read32(header + 8) != 3744
        || read32(header + 12) != 32) {
        s_preparationError = "STARTUP LOW MEMORY / CODE 0 LAYOUT";
        clearResidentSegments();
        return false;
    }
    if (!MacLowMemory::patch(1, s_segments[1].begin,
                                  s_segments[1].end - s_segments[1].begin)) {
        s_preparationError = "STARTUP LOW MEMORY / ORIGINAL BYTE MISMATCH";
        clearResidentSegments();
        return false;
    }
    g_startupCode = s_segments[1].begin;
    g_startupLowMemoryPatches = MacLowMemory::siteCount(1);
    g_lowMemoryAppliedSites = g_startupLowMemoryPatches;
    g_lowMemoryValidatedSites = checkedSites;
    return true;
}

struct TrapName { uint16_t word; const char* manager; const char* routine; };
static const TrapName s_trapNames[] = {
#ifdef AITD_SERVICE_PROBE
    {0xabfb,"USER SERVICE","TOOLBOX PROBE"},
#endif
    {0xa11a,"MEMORY MANAGER","GETZONE"},
    {0xa01b,"MEMORY MANAGER","SETZONE"},
    {0xa11d,"MEMORY MANAGER","MAXMEM"},
    {0xa020,"MEMORY MANAGER","SETPTRSIZE"},
    {0xa021,"MEMORY MANAGER","GETPTRSIZE"},
    {0xa023,"MEMORY MANAGER","DISPOSEHANDLE"},
    {0xa126,"MEMORY MANAGER","HANDLEZONE"},
    {0xa027,"MEMORY MANAGER","REALLOCHANDLE"},
    {0xa02b,"MEMORY MANAGER","EMPTYHANDLE"},
    {0xa02d,"MEMORY MANAGER","SETAPPLLIMIT"},
    {0xa036,"MEMORY MANAGER","MOREMASTERS"},
    {0xa148,"MEMORY MANAGER","PTRZONE"},
    {0xa04c,"MEMORY MANAGER","COMPACTMEM"},
    {0xa166,"MEMORY MANAGER","NEWEMPTYHANDLE"},
    {0xa06a,"MEMORY MANAGER","HSETSTATE"},
    {0xa067,"MEMORY MANAGER","HSETRBIT"},
    {0xa068,"MEMORY MANAGER","HCLRRBIT"},
    {0xa71e,"MEMORY MANAGER","NEWPTRSYSCLEAR"},
    {0xa9e3,"MEMORY MANAGER","PTRTOHAND"},
    {0xa1ad,"OS","GESTALT"},
    {0xa860,"EVENT MANAGER","WAITNEXTEVENT"},
    {0xa260,"FILE MANAGER","HFSDISPATCH"},
    {0xa9af,"RESOURCE MANAGER","RESERROR"}, {0xa992,"RESOURCE MANAGER","DETACHRESOURCE"},
    {0xa055,"OS","STRIPADDRESS"}, {0xa0bd,"OS","VCACHEFLUSH"},
    {0xa198,"OS","HWPRIV"}, {0xa9c9,"OS","SYSERROR"},
    {0xa069,"MEMORY MANAGER","HGETSTATE"},
    {0xa322,"MEMORY MANAGER","NEWHANDLECLEAR"},
    {0xa001,"FILE MANAGER","CLOSE"}, {0xa015,"FILE MANAGER","SETVOL"},
    {0xa000,"FILE MANAGER","OPEN"}, {0xa200,"FILE MANAGER","HOPEN"},
    {0xa002,"FILE MANAGER","READ"}, {0xa011,"FILE MANAGER","GETEOF"},
    {0xa018,"FILE MANAGER","GETFPOS"}, {0xa044,"FILE MANAGER","SETFPOS"},
    {0xa214,"FILE MANAGER","HGETVOL"}, {0xa215,"FILE MANAGER","HSETVOL"},
    {0xa014,"FILE MANAGER","GETVOL"}, {0xa823,"FOLDER MANAGER","FINDFOLDER"},
    {0xa81a,"RESOURCE MANAGER","HOPENRESFILE"},
    {0xa820,"RESOURCE MANAGER","GET1NAMEDRESOURCE"},
    {0xa007,"FILE MANAGER","GETVOLINFO"}, {0xa861,"QUICKDRAW","RANDOM"},
    {0xa02e,"MEMORY MANAGER","BLOCKMOVE"}, {0xa9f1,"SEGMENT MANAGER","UNLOADSEG"},
    {0xa86e,"QUICKDRAW","INITGRAF"},
    {0xa8fe,"FONT MANAGER","INITFONTS"}, {0xa912,"WINDOW MANAGER","INITWINDOWS"},
    {0xa930,"MENU MANAGER","INITMENUS"}, {0xa9cc,"TEXTEDIT","TEINIT"},
    {0xa97b,"DIALOG MANAGER","INITDIALOGS"},
    {0xa997,"RESOURCE MANAGER","OPENRESFILE"},
    {0xa9a1,"RESOURCE MANAGER","GETNAMEDRESOURCE"}, {0xa9a3,"RESOURCE MANAGER","RELEASERESOURCE"},
    {0xa063,"MEMORY MANAGER","MAXAPPLZONE"}, {0xa01c,"MEMORY MANAGER","FREEMEM"},
    {0xa01f,"MEMORY MANAGER","DISPOSEPTR"},
    {0xa090,"TOOLBOX UTILITIES","SYSENVIRONS"},
    {0xa746,"TRAP MANAGER","GETTOOLTRAPADDRESS"},
    {0xa31e,"MEMORY MANAGER","NEWPTRCLEAR"}, {0xaa32,"QUICKDRAW","GETGDEVICE"},
    {0xa9a0,"RESOURCE MANAGER","GETRESOURCE"},
    {0xa9aa,"RESOURCE MANAGER","CHANGEDRESOURCE"},
    {0xa9b0,"RESOURCE MANAGER","WRITERESOURCE"},
    {0xa064,"MEMORY MANAGER","MOVEHHI"},
    {0xa029,"MEMORY MANAGER","HLOCK"}, {0xa11e,"MEMORY MANAGER","NEWPTR"},
    {0xa51e,"MEMORY MANAGER","NEWPTRSYS"},
    {0xa122,"MEMORY MANAGER","NEWHANDLE"},
    {0xa128,"MEMORY MANAGER","RECOVERHANDLE"},
    {0xa025,"MEMORY MANAGER","GETHANDLESIZE"},
    {0xa024,"MEMORY MANAGER","SETHANDLESIZE"},
    {0xa9ef,"MEMORY MANAGER","PTRANDHAND"},
    {0xa02a,"MEMORY MANAGER","HUNLOCK"}, {0xa049,"MEMORY MANAGER","HPURGE"},
    {0xa04a,"MEMORY MANAGER","HNOPURGE"},
    {0xa032,"EVENT MANAGER","FLUSHEVENTS"},
    {0xa03b,"TIME MANAGER","DELAY"},
    {0xa03c,"TEXT UTILITIES","CMPSTRING"}, {0xa23c,"TEXT UTILITIES","CMPSTRING"},
    {0xa43c,"TEXT UTILITIES","CMPSTRING"}, {0xa63c,"TEXT UTILITIES","CMPSTRING"},
    {0xa033,"VERTICAL RETRACE","VINSTALL"}, {0xa034,"VERTICAL RETRACE","VREMOVE"},
    {0xa998,"RESOURCE MANAGER","USERESFILE"}, {0xa994,"RESOURCE MANAGER","CURRESFILE"},
    {0xaa46,"WINDOW MANAGER","GETNEWCWINDOW"}, {0xa91b,"WINDOW MANAGER","MOVEWINDOW"},
    {0xa915,"WINDOW MANAGER","SHOWWINDOW"}, {0xa916,"WINDOW MANAGER","HIDEWINDOW"},
    {0xa924,"WINDOW MANAGER","FRONTWINDOW"}, {0xa925,"WINDOW MANAGER","DRAGWINDOW"},
    {0xa92c,"WINDOW MANAGER","FINDWINDOW"},
    {0xaa92,"PALETTE MANAGER","GETNEWPALETTE"}, {0xaa93,"PALETTE MANAGER","DISPOSEPALETTE"},
    {0xa873,"QUICKDRAW","SETPORT"},
    {0xaa28,"COLOR MANAGER","GETCTSEED"}, {0xaa39,"COLOR MANAGER","MAKEITABLE"},
    {0xa91f,"WINDOW MANAGER","SELECTWINDOW"},
    {0xa922,"WINDOW MANAGER","BEGINUPDATE"}, {0xa923,"WINDOW MANAGER","ENDUPDATE"},
    {0xa883,"QUICKDRAW","DRAWCHAR"}, {0xa884,"QUICKDRAW","DRAWSTRING"},
    {0xa885,"QUICKDRAW","DRAWTEXT"},
    {0xa887,"QUICKDRAW","TEXTFONT"}, {0xa888,"QUICKDRAW","TEXTFACE"},
    {0xa889,"QUICKDRAW","TEXTMODE"}, {0xa88a,"QUICKDRAW","TEXTSIZE"},
    {0xa88e,"QUICKDRAW","SPACEEXTRA"}, {0xa893,"QUICKDRAW","MOVETO"},
    {0xa9b9,"QUICKDRAW","GETCURSOR"},
    {0xa851,"QUICKDRAW","SETCURSOR"}, {0xa852,"QUICKDRAW","HIDECURSOR"},
    {0xa853,"QUICKDRAW","SHOWCURSOR"},
    {0xa97c,"DIALOG MANAGER","GETNEWDIALOG"}, {0xa981,"DIALOG MANAGER","DRAWDIALOG"},
    {0xa988,"DIALOG MANAGER","CAUTIONALERT"},
    {0xa990,"DIALOG MANAGER","GETITEXT"}, {0xa991,"DIALOG MANAGER","MODALDIALOG"},
    {0xab1d,"QUICKDRAW","QDEXTENSIONS"},
    {0xaa95,"PALETTE MANAGER","SETPALETTE"}, {0xa146,"TRAP MANAGER","GETTRAPADDRESS"},
    {0xaa2e,"GRAPHICS DEVICE MANAGER","INITGDEVICE"},
    {0xa047,"TRAP MANAGER","SETTRAPADDRESS"}, {0xa983,"DIALOG MANAGER","DISPOSEDIALOG"},
    {0xa850,"QUICKDRAW","INITCURSOR"}, {0xa9bc,"QUICKDRAW","GETPICTURE"},
    {0xa8f6,"QUICKDRAW","DRAWPICTURE"}, {0xa89b,"QUICKDRAW","PENSIZE"},
    {0xa89c,"QUICKDRAW","PENMODE"}, {0xa8a1,"QUICKDRAW","FRAMERECT"},
    {0xa8a7,"QUICKDRAW","SETRECT"},
    {0xa8a2,"QUICKDRAW","PAINTRECT"},
    {0xa8a4,"QUICKDRAW","INVERTRECT"},
    {0xa8a9,"QUICKDRAW","INSETRECT"}, {0xa8b0,"QUICKDRAW","FRAMEROUNDRECT"},
    {0xa8ad,"QUICKDRAW","PTINRECT"},
    {0xa8ec,"QUICKDRAW","COPYBITS"}, {0xa8a3,"QUICKDRAW","ERASERECT"},
    {0xa87b,"QUICKDRAW","CLIPRECT"}, {0xa974,"EVENT MANAGER","BUTTON"},
    {0xa98d,"DIALOG MANAGER","GETDITEM"}, {0xa98f,"DIALOG MANAGER","SETITEXT"},
    {0xa914,"WINDOW MANAGER","DISPOSEWINDOW"}, {0xa90d,"WINDOW MANAGER","PAINTBEHIND"},
    {0xa04d,"MEMORY MANAGER","PURGEMEM"}, {0xa04c,"MEMORY MANAGER","COMPACTMEM"},
    {0xa939,"MENU MANAGER","ENABLEITEM"}, {0xa93a,"MENU MANAGER","DISABLEITEM"},
    {0xa945,"MENU MANAGER","CHECKITEM"}, {0xa93e,"MENU MANAGER","MENUKEY"},
    {0xa938,"MENU MANAGER","HILITEMENU"},
    {0xa931,"MENU MANAGER","NEWMENU"},
    {0xa933,"MENU MANAGER","APPENDMENU"}, {0xa94d,"MENU MANAGER","ADDRESMENU"},
    {0xa935,"MENU MANAGER","INSERTMENU"},
    {0xa9bf,"MENU MANAGER","GETMENU"},
    {0xa937,"MENU MANAGER","DRAWMENUBAR"}, {0xa970,"EVENT MANAGER","GETNEXTEVENT"},
    {0xa972,"EVENT MANAGER","GETMOUSE"}, {0xa973,"EVENT MANAGER","STILLDOWN"},
    {0xa9b4,"EVENT MANAGER","SYSTEMTASK"}, {0xaa94,"PALETTE MANAGER","ACTIVATEPALETTE"},
    {0xa874,"QUICKDRAW","GETPORT"}, {0xa871,"QUICKDRAW","GLOBALTOLOCAL"}
};

static void showLoaderStop();
static const char* s_loaderStopReason;
static uint16_t s_loaderStopSegment;

static bool loaderStop(const char* reason, uint16_t segment)
{
    s_loaderStopReason = reason;
    s_loaderStopSegment = segment;
    return false;
}

static void releaseA5World()
{
    if (s_a5WorldStorage) FreeMem(s_a5WorldStorage, s_a5WorldBytes);
    s_a5WorldStorage = 0;
    s_a5WorldBytes = 0;
    s_portLowMemory = s_initialLowMemory;
    g_macLowMemory = 0;
}

static bool buildA5World(uint8_t*& a5)
{
    // CODE 0: above-A5 size, below-A5 size, jump-table size and offset, then
    // the jump table itself (Inside Macintosh II-60 / Processes 7-38).
    const uint8_t* code0 = s_segments[0].begin;
    uint32_t code0Bytes = (uint32_t)(s_segments[0].end - code0);
    if (code0Bytes < 16) return loaderStop("CODE 0 HEADER", 0);
    uint32_t above = read32(code0), below = read32(code0 + 4);
    uint32_t jumpBytes = read32(code0 + 8), jumpOffset = read32(code0 + 12);
    if (code0Bytes != 16 + jumpBytes || (jumpBytes & 7) || jumpOffset + jumpBytes > above
        || above > 0x100000UL || below > 0x100000UL)
        return loaderStop("CODE 0 HEADER", 0);

    releaseA5World();
    s_a5WorldBytes = below + above + MacLowMemory::size;
    s_a5WorldStorage = (uint8_t*)AllocMem(s_a5WorldBytes, MEMF_ANY | MEMF_CLEAR);
    if (!s_a5WorldStorage) {
        s_a5WorldBytes = 0;
        return loaderStop("A5 WORLD MEMORY", 0);
    }
    a5 = s_a5WorldStorage + below;
    s_portLowMemory = a5 + MacLowMemory::base;
    g_macLowMemory = s_portLowMemory;
    s_portLowMemory[MacLowMemory::cpuFlag] = 3; // Mac IIx identity (D2/section 4.2)
    s_portLowMemory[MacLowMemory::loadTrap] = 0;
    write32(s_portLowMemory + MacLowMemory::lo3Bytes, 0xffffffffUL);
    write32(s_portLowMemory + kLowCurrentA5, (uint32_t)a5);
    write32(s_portLowMemory + kLowCurStackBase, (uint32_t)s_a5WorldStorage);
    write32(s_portLowMemory+80,(uint32_t)s_applicationLimit);
    write16(s_portLowMemory+100,(uint16_t)s_memoryError);
    write16(s_portLowMemory+132,g_applicationFileRef); // CurApRefNum ($0900), Engine+$4092
    write16(s_portLowMemory+84,0x0755); // M1.6 System 7.5.5 reference
    s_jumpTableOffset = jumpOffset;

    // Preserve the original unloaded entries. CODE 1's installed LoadSeg
    // handler, not the port, will relocate later CODE and resolve their jumps.
    const uint8_t* source = code0 + 16;
    uint8_t* jump = a5 + jumpOffset;
    g_jumpEntryCount = 0;
    for (uint32_t i = 0; i < jumpBytes / 8; ++i, source += 8, jump += 8) {
        uint16_t offset = read16(source);
        uint16_t segment = read16(source + 4);
        if (read16(source + 2) != 0x3f3c || read16(source + 6) != 0xa9f0)
            return loaderStop("JUMP TABLE ENTRY", 0);
        if (segment == 0 || segment >= s_segmentCount || !s_segments[segment].size
            || offset >= s_segments[segment].size - 4)
            return loaderStop("JUMP TABLE SEGMENT", segment);
        for (uint16_t byte = 0; byte < 8; ++byte) jump[byte] = source[byte];
        if (i < 10) {
            if (segment != 1) return loaderStop("STARTUP JUMP TABLE", segment);
            write16(jump, segment);
            write16(jump + 2, 0x4ef9);
            write32(jump + 4, (uint32_t)(s_segments[1].begin + 4 + offset));
            ++g_jumpEntryCount;
        }
    }
    return true;
}

static void blockMove(const uint8_t* source, uint8_t* destination, uint32_t count)
{
    // The driving renderer uses _BlockMove as a direct packed-pixel primitive,
    // bypassing QuickDraw's rectangle calls.  Convert the touched byte span to
    // a conservative screen-space dirty rectangle before the pointers move.
    uint8_t* screenEnd = s_colorScreen + sizeof(s_colorScreen);
    uint8_t* moveEnd = destination + count;
    if (!s_suppressDirectScreenDirty
        && destination < screenEnd && moveEnd > s_colorScreen) {
        uint8_t* first = destination > s_colorScreen ? destination : s_colorScreen;
        uint8_t* final = moveEnd < screenEnd ? moveEnd : screenEnd;
        uint32_t firstOffset = (uint32_t)(first - s_colorScreen);
        uint32_t finalOffset = (uint32_t)(final - s_colorScreen);
        int16_t top = (int16_t)(firstOffset / 256);
        int16_t bottom = (int16_t)((finalOffset + 255) / 256);
        int16_t left = 0, right = 512;
        if (top + 1 == bottom) {
            left = (int16_t)((firstOffset & 255) * 2);
            right = (int16_t)(((finalOffset - 1) & 255) * 2 + 2);
        }
        markDirtyBounds(top, left, bottom, right);
    }
    if (destination > source && destination < source + count) {
        source += count;
        destination += count;
        if (((uint32_t)source ^ (uint32_t)destination) & 1) {
            while (count) { --source; --destination; *destination = *source; --count; }
            return;
        }
        if ((uint32_t)source & 1) {
            --source; --destination; *destination = *source; --count;
        }
        while (count >= 4) {
            source -= 4; destination -= 4;
            *(uint32_t*)destination = *(const uint32_t*)source;
            count -= 4;
        }
        while (count >= 2) {
            source -= 2; destination -= 2;
            *(uint16_t*)destination = *(const uint16_t*)source;
            count -= 2;
        }
        if (count) { --source; --destination; *destination = *source; }
    } else {
        if (((uint32_t)source ^ (uint32_t)destination) & 1) {
            while (count--) *destination++ = *source++;
            return;
        }
        if ((uint32_t)source & 1) {
            *destination++ = *source++; --count;
        }
        while (count >= 4) {
            *(uint32_t*)destination = *(const uint32_t*)source;
            source += 4; destination += 4; count -= 4;
        }
        while (count >= 2) {
            *(uint16_t*)destination = *(const uint16_t*)source;
            source += 2; destination += 2; count -= 2;
        }
        if (count) *destination = *source;
    }
}

static __attribute__((noinline)) void mappedCopyRowsC(const uint8_t* source,
                                                       uint8_t* destination,
                                                       const uint8_t* map,
                                                       uint32_t rowBytes,
                                                       uint32_t height,
                                                       uint32_t sourceModulo,
                                                       uint32_t destinationModulo)
{
    while (height--) {
        uint32_t count = rowBytes;
        while (count--) *destination++ = map[*source++];
        source += sourceModulo;
        destination += destinationModulo;
    }
}

static void mappedCopyRows(const uint8_t* source, uint8_t* destination,
                           const uint8_t* map, uint32_t rowBytes, uint32_t height,
                           uint32_t sourceModulo, uint32_t destinationModulo)
{
#ifdef AITD_MAPPED_COPY_VERIFY
    // This helper is reached only for non-overlapping palette-mapped srcCopy.
    // Run the C oracle and asm twin on identical source bytes and the same real
    // destination in one process.  Preserve the oracle output only for the
    // comparison; the 68000 has no data cache for that intervening copy to bias.
    uint32_t count = 0;
    for (uint32_t y = 0; y < height; ++y) count += rowBytes;
    if (count > sizeof(s_mappedCopyVerify)) {
        ++g_mappedCopyVerifyFailures;
        mappedCopyRowsC(source, destination, map, rowBytes, height,
                        sourceModulo, destinationModulo);
        return;
    }
    uint32_t before = g_macTicks;
    mappedCopyRowsC(source, destination, map, rowBytes, height,
                    sourceModulo, destinationModulo);
    g_mappedCopyCTicks += g_macTicks - before;
    const uint8_t* preservedSource = destination;
    uint8_t* preservedDestination = s_mappedCopyVerify;
    for (uint32_t y = 0; y < height; ++y) {
        blockMove(preservedSource, preservedDestination, rowBytes);
        preservedSource += rowBytes + destinationModulo;
        preservedDestination += rowBytes;
    }
    before = g_macTicks;
    aitdMappedCopyRowsAsm(source, destination, map, rowBytes, height,
                           sourceModulo, destinationModulo);
    g_mappedCopyAsmTicks += g_macTicks - before;
    ++g_mappedCopyVerifyCalls;
    g_mappedCopyVerifyBytes += count;
    const uint8_t* compared = destination;
    const uint8_t* expected = s_mappedCopyVerify;
    for (uint32_t y = 0; y < height; ++y) {
        for (uint32_t x = 0; x < rowBytes; ++x)
            if (compared[x] != *expected++) {
                ++g_mappedCopyVerifyFailures;
                return;
            }
        compared += rowBytes + destinationModulo;
    }
#elif defined(AITD_MAPPED_COPY_ASM)
    aitdMappedCopyRowsAsm(source, destination, map, rowBytes, height,
                           sourceModulo, destinationModulo);
#else
    mappedCopyRowsC(source, destination, map, rowBytes, height,
                    sourceModulo, destinationModulo);
#endif
}

static void blockClear(uint8_t* destination, uint32_t count)
{
    if ((uint32_t)destination & 1) {
        *destination++ = 0;
        if (!--count) return;
    }
    while (count >= 2) {
        *(uint16_t*)destination = 0;
        destination += 2;
        count -= 2;
    }
    if (count) *destination = 0;
}

static void blockFill(uint8_t* destination, uint32_t count, uint8_t value)
{
    if (!count) return;
    if ((uint32_t)destination & 1) {
        *destination++ = value;
        if (!--count) return;
    }
    uint16_t pair = (uint16_t)((value << 8) | value);
    while (count >= 2) {
        *(uint16_t*)destination = pair;
        destination += 2;
        count -= 2;
    }
    if (count) *destination = value;
}

static void refreshCodeViews()
{
    g_loadedCodeMask=s_segments[0].begin ? 1 : 0;
    for(uint16_t n=1;n<s_segmentCount;++n) {
        Segment& segment=s_segments[n];
        segment.begin=segment.handle && handleZone(segment.handle) ? *segment.handle : 0;
        segment.end=segment.begin ? segment.begin+segment.size : 0;
        if(segment.begin)g_loadedCodeMask|=1UL<<n;
    }
    g_startupCode=s_segments[1].begin;g_code3Base=s_segments[3].begin;
    g_heapFree=s_applicationZone.freeBytes();g_heapLargest=s_applicationZone.largestBlock();
    g_heapSystemFree=s_systemZone.freeBytes();
}
static uint8_t** loadResource(uint32_t index,const ResourceForks::Item& item)
{
    MacHeap::Handle& handle=s_resourceHandles[index];
    MacHeap* zone=(item.attrs&0x40) ? &s_systemZone : &s_applicationZone;
    if(!handle) { handle=zone->newEmptyHandle();memoryResult(zone->error()); }
    if(!handle) { resourceResult(zone->error());return 0; }
    if(!*handle) {
        if(zone->reallocateHandle(handle,item.size)!=0) { memoryResult(zone->error());resourceResult(zone->error());return 0; }
        memoryResult(zone->error());
        for(uint32_t byte=0;byte<item.size;++byte)(*handle)[byte]=item.data[byte];
        zone->setState(handle,0x20|((item.attrs&0x10)?0x80:0)|((item.attrs&0x20)?0x40:0));
        if(item.fork==0 && item.type==0x434f4445UL && item.id>0) {
            if(item.id>=kMaximumSegments || !MacLowMemory::patch(item.id,*handle,item.size)) {
                loaderStop("LOW MEMORY ORIGINAL BYTE MISMATCH",item.id<kMaximumSegments ? item.id : 0);
                showLoaderStop();
            }
            s_segments[item.id].handle=handle;
            g_lowMemoryAppliedSites+=MacLowMemory::siteCount(item.id);
        }
        refreshCodeViews();
    }
    resourceResult(0);return handle;
}
static uint8_t** getResource(uint32_t type,int16_t id)
{
    for(uint16_t pass=0;pass<s_resourceForks.forkCount();++pass) {
        uint16_t fork=(s_currentResourceFork+pass)%s_resourceForks.forkCount();
        ResourceForks::Item item;uint32_t index;
        if(s_resourceForks.find(fork,type,id,item,&index))return loadResource(index,item);
    }
    resourceResult(-192);return 0;
}

static uint16_t paulaBeamLine()
{
    // V8 lives in VPOSR while V0..V7 live in VHPOSR. Re-read VPOSR so a
    // raster wrap between the two register reads cannot manufacture a line.
    uint16_t before, after, horizontal;
    do {
        before = *vposrPointer;
        horizontal = *vhposrPointer;
        after = *vposrPointer;
    } while ((before & 1) != (after & 1));
    return (uint16_t)(((after & 1) << 8) | (horizontal >> 8));
}

static void waitPaulaDmaLines(uint16_t lines)
{
    uint16_t previous = paulaBeamLine();
    while (lines) {
        uint16_t current = paulaBeamLine();
        if (current == previous) continue;
        previous = current;
        --lines;
    }
}

// AUDxPER is write-only and its current countdown can still use an older
// value after a pitch change. Keep a conservative ceiling until DMA stops.
static uint16_t s_paulaPeriodCeiling[4] = {65535, 65535, 65535, 65535};

static void setPaulaPeriod(uint16_t channel, uint16_t period)
{
    if (period > s_paulaPeriodCeiling[channel]) s_paulaPeriodCeiling[channel] = period;
    *(volatile uint16_t*)(0xdff0a6UL + channel * 16) = period;
}

static void disablePaulaChannel(uint16_t channel)
{
    *dmaconPointer = (uint16_t)(DMAF_AUD0 << channel);
    // RKM 5-2-7: DMA must remain off for at least two SAMPLE periods.
    // PAL lines contain at least 227 colour clocks. Add a full line because
    // the first observed raster transition can occur immediately.
    uint16_t lines = (uint16_t)((((uint32_t)s_paulaPeriodCeiling[channel] << 1) / 227U) + 2);
    waitPaulaDmaLines(lines);
    s_paulaPeriodCeiling[channel] = 0;
}

static void quiescePaulaChannel(uint16_t channel)
{
    if (channel > 3) return;
    volatile uint8_t* audio = (volatile uint8_t*)(0xdff0a0UL + channel * 16);

    // DMA-off and volume zero merely mute a Paula channel: they do not clear
    // the two sample bytes held in AUDxDAT.  Let Agnus observe the disable,
    // then explicitly load signed PCM zero so emulator/hardware hand-off does
    // not expose the previous nonzero DAC value as a shutdown click.
    *(volatile uint16_t*)(audio + 8) = 0;
    disablePaulaChannel(channel);
    // Direct (non-DMA) output advances the two bytes in AUDxDAT at AUDxPER.
    // Use the documented minimum period, then allow both zero bytes to reach
    // and settle in the DAC rather than merely leaving zero in its holding
    // register. This also gives never-used channels a valid period.
    setPaulaPeriod(channel, 124);
    // Direct output only leaves idle when its previous interrupt is cleared.
    *intreqPointer = (uint16_t)(0x0080U << channel);
    *(volatile uint16_t*)(audio + 10) = 0;
    waitPaulaDmaLines(3);
#ifdef AITD_PROBE
    g_probePaulaZeroedMask |= (uint16_t)(1U << channel);
#endif
}

// Shared restart protocol for intro and gameplay. The reload contains only
// the defined loop, or a silent word for one-shot samples.
static void startPaulaSample(uint8_t* data, const PaulaSample::Layout& layout,
                             uint16_t channel, uint16_t period, uint16_t volume)
{
    uint16_t dma = (uint16_t)(DMAF_AUD0 << channel);
    volatile uint8_t* audio = (volatile uint8_t*)(0xdff0a0UL + channel * 16);
    disablePaulaChannel(channel);
    *(volatile uint32_t*)(audio + 0) = (uint32_t)data;
    *(volatile uint16_t*)(audio + 4) = (uint16_t)(layout.attackBytes >> 1);
    setPaulaPeriod(channel, period);
    *(volatile uint16_t*)(audio + 8) = volume;
#ifdef AITD_PROBE
    g_probePaulaZeroedMask &= (uint16_t)~(1U << channel);
#endif
    *dmaconPointer = (uint16_t)(DMAF_SETCLR | DMAF_MASTER | dma);
    // Let DMA latch the attack before publishing the next segment (RKM 5-3-1).
    waitPaulaDmaLines(2);
    *(volatile uint32_t*)(audio + 0) = (uint32_t)(data + layout.reloadOffset);
    *(volatile uint16_t*)(audio + 4) = (uint16_t)(layout.reloadBytes >> 1);
}

static uint8_t asciiUpper(uint8_t c)
{
    return c >= 'a' && c <= 'z' ? (uint8_t)(c - ('a' - 'A')) : c;
}

// EqualString's register trap compares MacRoman bytes.  Bit 10 of the trap
// word makes case count; bit 9 makes diacritical marks count.  These tables
// are the complete MacRoman lowercase and mark-stripping maps, rather than an
// ASCII approximation that would quietly mis-handle resource names.
static const uint8_t kMacRomanLower[256] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
    0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,
    0x40,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x5b,0x5c,0x5d,0x5e,0x5f,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f,
    0x8a,0x8c,0x8d,0x8e,0x96,0x9a,0x9f,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f,
    0x90,0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9d,0x9e,0x9f,
    0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0xad,0xbe,0xbf,
    0xb0,0xb1,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbe,0xbf,
    0xc0,0xc1,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0x88,0x8b,0x9b,0xcf,0xcf,
    0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd8,0xda,0xdb,0xdc,0xdd,0xde,0xdf,
    0xe0,0xe1,0xe2,0xe3,0xe4,0x89,0x90,0x87,0x91,0x8f,0x92,0x94,0x95,0x93,0x97,0x99,
    0xf0,0x98,0x9c,0x9e,0x9d,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
};

static const uint8_t kMacRomanWithoutMarks[256] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
    0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,
    0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,
    0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x5b,0x5c,0x5d,0x5e,0x5f,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f,
    0x41,0x41,0x43,0x45,0x4e,0x4f,0x55,0x61,0x61,0x61,0x61,0x61,0x61,0x63,0x65,0x65,
    0x65,0x65,0x69,0x69,0x69,0x69,0x6e,0x6f,0x6f,0x6f,0x6f,0x6f,0x75,0x75,0x75,0x75,
    0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0x3d,0xae,0xaf,
    0xb0,0xb1,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbe,0xbf,
    0xc0,0xc1,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0x41,0x41,0x4f,0xce,0xcf,
    0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0x79,0x59,0xda,0xdb,0xdc,0xdd,0xde,0xdf,
    0xe0,0xe1,0xe2,0xe3,0xe4,0x41,0x45,0x41,0x45,0x45,0x49,0x49,0x49,0x49,0x4f,0x4f,
    0xf0,0x4f,0x55,0x55,0x55,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
};

static uint8_t normalizedMacRoman(uint8_t value, bool caseSensitive, bool marksSensitive)
{
    if (!marksSensitive) value = kMacRomanWithoutMarks[value];
    if (!caseSensitive) value = kMacRomanLower[value];
    return value;
}

static bool equalMacRomanStrings(const uint8_t* first, uint16_t firstLength,
                                 const uint8_t* second, uint16_t secondLength,
                                 bool caseSensitive, bool marksSensitive)
{
    if (!first || !second || firstLength != secondLength) return false;
    for (uint16_t i = 0; i < firstLength; ++i)
        if (normalizedMacRoman(first[i], caseSensitive, marksSensitive)
            != normalizedMacRoman(second[i], caseSensitive, marksSensitive)) return false;
    return true;
}

static bool resourceNameEquals(const ResourceForks::Item& item, const uint8_t* name)
{
    if (!name || name[0] != item.nameLength) return false;
    for (uint16_t i = 0; i < item.nameLength; ++i)
        if (asciiUpper(name[i + 1]) != asciiUpper(item.name[i])) return false;
    return true;
}

static uint8_t** getNamedResource(uint32_t type, const uint8_t* name)
{
    for (uint16_t pass = 0; pass < s_resourceForks.forkCount(); ++pass) {
        uint16_t fork = (uint16_t)(s_currentResourceFork + pass);
        if (fork >= s_resourceForks.forkCount()) fork -= s_resourceForks.forkCount();
        for (uint32_t i = 0; i < s_resourceForks.resourceCount(); ++i) {
            ResourceForks::Item item;
            if (!s_resourceForks.item(i, item)) return 0;
            if (item.fork == fork && item.type == type && resourceNameEquals(item, name)) {
                return loadResource(i,item);
            }
        }
    }
    return 0;
}

static bool pascalEquals(const uint8_t* value, const char* expected)
{
    uint16_t length = 0;
    while (expected[length]) ++length;
    if (!value || value[0] != length) return false;
    for (uint16_t i = 0; i < length; ++i)
        if (asciiUpper(value[i + 1]) != asciiUpper((uint8_t)expected[i])) return false;
    return true;
}

static int16_t openResourceFile(const uint8_t* name)
{
    // Vette opened its second resource fork by name here. Alone in the Dark
    // keeps its data in data-fork .PAK files; no second fork is known yet.
    (void)name;
    return -1;
}

static void initGraf(uint8_t* thePort)
{
    // QDGlobals is a 206-byte decrementing record whose last field is thePort.
    // InitGraf receives &thePort; all other public globals have negative offsets.
    s_qdThePort = thePort;
    for (int16_t offset = -202; offset < 4; ++offset) thePort[offset] = 0;

    // The five standard QuickDraw patterns, from light to dark in memory order.
    static const uint8_t patterns[40] = {
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // white   (-8)
        0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff, // black   (-16)
        0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55, // gray    (-24)
        0x88,0x22,0x88,0x22,0x88,0x22,0x88,0x22, // ltGray  (-32)
        0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd  // dkGray  (-40)
    };
    for (uint16_t pattern = 0; pattern < 5; ++pattern)
        for (uint16_t byte = 0; byte < 8; ++byte)
            thePort[-8 * (int16_t)(pattern + 1) + byte] = patterns[pattern * 8 + byte];

    // The standard 16x16 arrow Cursor: image, mask, then hot spot (0,0).
    static const uint16_t arrowImage[16] = {
        0x0000,0x4000,0x6000,0x7000,0x7800,0x7c00,0x7e00,0x7f00,
        0x7f80,0x7c00,0x6c00,0x4600,0x0600,0x0300,0x0300,0x0000
    };
    static const uint16_t arrowMask[16] = {
        0xc000,0xe000,0xf000,0xf800,0xfc00,0xfe00,0xff00,0xff80,
        0xffc0,0xffe0,0xfe00,0xef00,0xcf00,0x0780,0x0780,0x0380
    };
    uint8_t* arrow = thePort - 108;
    for (uint16_t i = 0; i < 16; ++i) {
        write16(arrow + i * 2, arrowImage[i]);
        write16(arrow + 32 + i * 2, arrowMask[i]);
    }

    // screenBits is a one-bit BitMap describing the whole logical screen.
    uint8_t* screenBits = thePort - 122;
    write32(screenBits, (uint32_t)s_quickDrawScreen);
    write16(screenBits + 4, 512 / 8);
    write16(screenBits + 6, 0);             // bounds.top
    write16(screenBits + 8, 0);             // bounds.left
    write16(screenBits + 10, 320);          // bounds.bottom
    write16(screenBits + 12, 512);          // bounds.right
    write32(thePort - 126, 1);               // randSeed
    write32(thePort, 0);                     // no current GrafPort until InitWindows/SetPort
}

static void initFonts()
{
    // Classic InitFonts selects the system font.  Keep the selection as manager state;
    // GrafPort text attributes are established when a port is opened, not here.
    s_fontManager.initialized = true;
    s_fontManager.systemFont = 0;             // system font
    s_fontManager.systemSize = 12;
}

static void writeRect(uint8_t* p, int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    write16(p, (uint16_t)top); write16(p + 2, (uint16_t)left);
    write16(p + 4, (uint16_t)bottom); write16(p + 6, (uint16_t)right);
}

static void initRegion(uint8_t* region, uint8_t*& master,
                       int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    master = region;
    write16(region, 10);                    // rectangular region: header only
    writeRect(region + 2, top, left, bottom, right);
}

static void initWindowManagerPort()
{
    for (uint16_t i = 0; i < sizeof(s_windowManagerPort); ++i) s_windowManagerPort[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_windowManagerPixMap); ++i) s_windowManagerPixMap[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_mainDevice); ++i) s_mainDevice[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_windowManagerColors); ++i) s_windowManagerColors[i] = 0;

    s_windowManagerColorsMaster = s_windowManagerColors;
    write32(s_windowManagerColors, 1);      // ctSeed
    write16(s_windowManagerColors + 4, 0);  // ctFlags
    write16(s_windowManagerColors + 6, 15); // ctSize is the final array index
    for (uint16_t i = 0; i < 16; ++i) {
        uint8_t* spec = s_windowManagerColors + 8 + i * 8;
        write16(spec, i);
        uint16_t level = (uint16_t)((15 - i) * 0x1111U);
        write16(spec + 2, level); write16(spec + 4, level); write16(spec + 6, level);
    }

    s_windowManagerPixMapMaster = s_windowManagerPixMap;
    write32(s_windowManagerPixMap, (uint32_t)s_colorScreen);
    write16(s_windowManagerPixMap + 4, 0x8000 | (512 / 2));
    writeRect(s_windowManagerPixMap + 6, 0, 0, 320, 512);
    write32(s_windowManagerPixMap + 22, 72UL << 16); // hRes
    write32(s_windowManagerPixMap + 26, 72UL << 16); // vRes
    write16(s_windowManagerPixMap + 30, 0);          // indexed pixelType
    write16(s_windowManagerPixMap + 32, 4);          // pixelSize
    write16(s_windowManagerPixMap + 34, 1);          // cmpCount
    write16(s_windowManagerPixMap + 36, 4);          // cmpSize
    write32(s_windowManagerPixMap + 42, (uint32_t)&s_windowManagerColorsMaster);

    // One active screen GDevice is sufficient for the shipped single-monitor game.
    // gdPMap is at +22 in a classic GDevice record and is itself a Handle.
    s_mainDeviceMaster = s_mainDevice;
    s_mainDeviceITableMaster = s_mainDeviceITable;
    write32(s_mainDeviceITable, read32(s_windowManagerColors));
    write16(s_mainDeviceITable + 4, 4);
    write16(s_mainDevice + 4, 0);           // clutType
    write32(s_mainDevice + 6, (uint32_t)&s_mainDeviceITableMaster); // gdITable
    write16(s_mainDevice + 10, 4);          // gdResPref
    write16(s_mainDevice + 20, 1);          // screenDevice
    write32(s_mainDevice + 22, (uint32_t)&s_windowManagerPixMapMaster);
    writeRect(s_mainDevice + 34, 0, 0, 320, 512);

    initRegion(s_windowManagerVisRgn, s_windowManagerVisRgnMaster, 0, 0, 320, 512);
    initRegion(s_windowManagerClipRgn, s_windowManagerClipRgnMaster,
               -32767, -32767, 32767, 32767);
    initRegion(s_grayRgn, s_grayRgnMaster, 20, 0, 320, 512);

    // WMgrPort remains an old-style GrafPort on this system.  Vette reads its
    // embedded BitMap directly to obtain the screen bounds before centering windows.
    write32(s_windowManagerPort + 2, (uint32_t)s_colorScreen);
    write16(s_windowManagerPort + 6, 512 / 2);
    writeRect(s_windowManagerPort + 8, 0, 0, 320, 512);
    writeRect(s_windowManagerPort + 16, 0, 0, 320, 512);
    write32(s_windowManagerPort + 24, (uint32_t)&s_windowManagerVisRgnMaster);
    write32(s_windowManagerPort + 28, (uint32_t)&s_windowManagerClipRgnMaster);
    for (uint16_t i = 0; i < 8; ++i) {
        s_windowManagerPort[32 + i] = 0;              // bkPat = white
        s_windowManagerPort[40 + i] = 0xff;           // fillPat = black
        s_windowManagerPort[58 + i] = 0xff;           // pnPat = black
    }
    write16(s_windowManagerPort + 52, 1);             // pnSize.v
    write16(s_windowManagerPort + 54, 1);             // pnSize.h
    write16(s_windowManagerPort + 56, 8);             // patCopy
    write16(s_windowManagerPort + 68, s_fontManager.systemFont);
    write16(s_windowManagerPort + 72, 1);             // srcOr
    write16(s_windowManagerPort + 74, s_fontManager.systemSize);
    write32(s_windowManagerPort + 80, 33);            // blackColor
    write32(s_windowManagerPort + 84, 30);            // whiteColor

    s_windowManager.initialized = true;
    s_windowManager.palettesInitialized = true;       // InitWindows calls InitPalettes
    s_windowManager.port = s_windowManagerPort;
    write32(s_qdThePort, (uint32_t)s_windowManagerPort);
    write32(s_portLowMemory + kLowWMgrPort, (uint32_t)s_windowManagerPort);
    write32(s_portLowMemory + kLowGrayRgn, (uint32_t)&s_grayRgnMaster);
}

static bool makeITable(uint8_t** colorTableHandle, uint8_t** inverseTableHandle,
                       uint16_t resolution)
{
    if (!colorTableHandle) colorTableHandle = &s_windowManagerColorsMaster;
    if (!inverseTableHandle) inverseTableHandle = &s_mainDeviceITableMaster;
    if (!resolution) resolution = read16(s_mainDevice + 10);
    if (colorTableHandle != &s_windowManagerColorsMaster
        || inverseTableHandle != &s_mainDeviceITableMaster
        || !*colorTableHandle || !*inverseTableHandle || resolution != 4)
        return false;

    const uint8_t* colorTable = *colorTableHandle;
    uint8_t* inverseTable = *inverseTableHandle;
    uint16_t finalIndex = read16(colorTable + 6);
    if (finalIndex > 15) return false;
    bool deviceTable = (read16(colorTable + 4) & 0x8000) != 0;
    write32(inverseTable, read32(colorTable));
    write16(inverseTable + 4, resolution);
    uint8_t red[16], green[16], blue[16], value[16];
    for (uint16_t i = 0; i <= finalIndex; ++i) {
        const uint8_t* color = colorTable + 8 + i * 8;
        // For a device table, the ColorSpec array position is the physical
        // pixel value.  Color Manager owns cs.value and stores allocation
        // flags there (for example $0800 protected and $2000 tolerant).
        value[i] = deviceTable ? (uint8_t)i : (uint8_t)read16(color);
        red[i] = (uint8_t)(read16(color + 2) >> 12);
        green[i] = (uint8_t)(read16(color + 4) >> 12);
        blue[i] = (uint8_t)(read16(color + 6) >> 12);
    }
    for (uint16_t key = 0; key < 4096; ++key) {
        uint8_t r = (uint8_t)((key >> 8) & 15);
        uint8_t g = (uint8_t)((key >> 4) & 15);
        uint8_t b = (uint8_t)(key & 15);
        uint16_t bestDistance = 0xffff;
        uint8_t bestValue = 0;
        for (uint16_t i = 0; i <= finalIndex; ++i) {
            uint16_t distance = (uint16_t)((r > red[i] ? r - red[i] : red[i] - r)
                              + (g > green[i] ? g - green[i] : green[i] - g)
                              + (b > blue[i] ? b - blue[i] : blue[i] - b));
            if (distance < bestDistance) {
                bestDistance = distance;
                bestValue = value[i];
            }
        }
        inverseTable[6 + key] = bestValue;
    }
    return true;
}

static uint16_t colorDistance4(uint16_t sr, uint16_t sg, uint16_t sb,
                               uint16_t dr, uint16_t dg, uint16_t db)
{
    uint8_t sourceRed = (uint8_t)(sr >> 12), sourceGreen = (uint8_t)(sg >> 12);
    uint8_t sourceBlue = (uint8_t)(sb >> 12), destinationRed = (uint8_t)(dr >> 12);
    uint8_t destinationGreen = (uint8_t)(dg >> 12), destinationBlue = (uint8_t)(db >> 12);
    return (uint16_t)((sourceRed > destinationRed ? sourceRed - destinationRed
                                                   : destinationRed - sourceRed)
        + (sourceGreen > destinationGreen ? sourceGreen - destinationGreen
                                           : destinationGreen - sourceGreen)
        + (sourceBlue > destinationBlue ? sourceBlue - destinationBlue
                                         : destinationBlue - sourceBlue));
}

static void initColorPort(uint8_t* port, uint8_t** visRgn, uint8_t** clipRgn,
                          int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    write32(port + 2, (uint32_t)&s_windowManagerPixMapMaster);
    write16(port + 6, 0xc000);                        // CGrafPort version
    writeRect(port + 16, top, left, bottom, right);
    write32(port + 24, (uint32_t)visRgn);
    write32(port + 28, (uint32_t)clipRgn);
    write16(port + 42, 0xffff);
    write16(port + 44, 0xffff);
    write16(port + 46, 0xffff);                       // rgbBkColor = white
    write16(port + 52, 1);
    write16(port + 54, 1);
    write16(port + 56, 8);                            // patCopy
    write16(port + 68, s_fontManager.systemFont);
    write16(port + 72, 1);                            // srcOr
    write16(port + 74, s_fontManager.systemSize);
    write32(port + 80, 33);                           // blackColor
    write32(port + 84, 30);                           // whiteColor
}

static uint8_t* newColorWindow(int16_t id, uint8_t* storage, uint8_t* behind)
{
    uint8_t** resource = getResource(0x57494e44UL, id); // 'WIND'
    if (!resource || !*resource) return 0;
    const uint8_t* wind = *resource;

    WindowSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (!s_windows[i].used) { slot = &s_windows[i]; break; }
    if (!slot) return 0;
    slot->used = true;
    slot->dialog = false;
    slot->resourceID = id;
    slot->palette = 0;
    slot->paletteUpdates = false;
    slot->updating = false;
    slot->dialogItemCount = 0;
    slot->dialogDrawn = false;
    for (uint16_t i = 0; i < sizeof(slot->record); ++i) slot->record[i] = 0;

    int16_t top = (int16_t)read16(wind);
    int16_t left = (int16_t)read16(wind + 2);
    int16_t bottom = (int16_t)read16(wind + 4);
    int16_t right = (int16_t)read16(wind + 6);
    uint8_t* window = storage ? storage : slot->record;
    slot->window = window;
    if (storage)
        for (uint16_t i = 0; i < 156; ++i) storage[i] = 0;

    initRegion(slot->structureRegion, slot->structureRegionMaster,
               top, left, bottom, right);
    initRegion(slot->contentRegion, slot->contentRegionMaster,
               top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster,
               top, left, bottom, right);
    initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
    initColorPort(window, &slot->contentRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);

    write16(window + 108, 0);                         // windowKind
    window[110] = wind[10];                           // visible
    window[112] = wind[11];                           // goAwayFlag
    write32(window + 114, (uint32_t)&slot->structureRegionMaster);
    write32(window + 118, (uint32_t)&slot->contentRegionMaster);
    write32(window + 122, (uint32_t)&slot->updateRegionMaster);
    slot->procID = (int16_t)read16(wind + 8);         // WDEF selection for later operations
    uint8_t titleLength = wind[16];
    slot->title[0] = titleLength;
    for (uint16_t i = 0; i < titleLength; ++i) slot->title[i + 1] = wind[17 + i];
    slot->titleMaster = slot->title;
    write32(window + 134, (uint32_t)&slot->titleMaster);
    write32(window + 144, (uint32_t)s_windowList);
    write32(window + 152, read32(wind + 12));         // refCon
    s_windowList = window;                            // front of our window chain
    (void)behind;                                     // both shipped calls use behindWindow=-1
    return window;
}

static uint8_t* newDialog(int16_t id, uint8_t* storage, uint8_t* behind)
{
    uint8_t** resource = getResource(0x444c4f47UL, id); // 'DLOG'
    if (!resource || !*resource) return 0;
    const uint8_t* dlog = *resource;
    WindowSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (!s_windows[i].used) { slot = &s_windows[i]; break; }
    if (!slot) return 0;
    slot->used = true;
    slot->dialog = true;
    slot->resourceID = id;
    slot->palette = 0;
    slot->paletteUpdates = false;
    slot->updating = false;
    slot->dialogItemCount = 0;
    slot->dialogDrawn = false;
    uint8_t* dialog = storage ? storage : slot->record;
    slot->window = dialog;
    for (uint16_t i = 0; i < sizeof(slot->record); ++i) dialog[i] = 0;

    int16_t top = (int16_t)read16(dlog);
    int16_t left = (int16_t)read16(dlog + 2);
    int16_t bottom = (int16_t)read16(dlog + 4);
    int16_t right = (int16_t)read16(dlog + 6);
    initRegion(slot->structureRegion, slot->structureRegionMaster, top, left, bottom, right);
    initRegion(slot->contentRegion, slot->contentRegionMaster, top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster, top, left, bottom, right);
    initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
    initColorPort(dialog, &slot->contentRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);

    dialog[110] = dlog[10];
    dialog[112] = dlog[12];
    write32(dialog + 114, (uint32_t)&slot->structureRegionMaster);
    write32(dialog + 118, (uint32_t)&slot->contentRegionMaster);
    write32(dialog + 122, (uint32_t)&slot->updateRegionMaster);
    slot->procID = (int16_t)read16(dlog + 8);
    uint8_t titleLength = dlog[20];
    slot->title[0] = titleLength;
    for (uint16_t i = 0; i < titleLength; ++i) slot->title[i + 1] = dlog[21 + i];
    slot->titleMaster = slot->title;
    write32(dialog + 134, (uint32_t)&slot->titleMaster);
    write32(dialog + 144, (uint32_t)s_windowList);
    write32(dialog + 152, read32(dlog + 14));
    write32(dialog + 156,
            (uint32_t)getResource(0x4449544cUL, (int16_t)read16(dlog + 18))); // 'DITL'
    write16(dialog + 164, 0xffff);           // no editable-text item selected
    write16(dialog + 168, 1);                // default item
    s_windowList = dialog;
    (void)behind;
    return dialog;
}

static void moveWindow(uint8_t* window, int16_t h, int16_t v, bool front)
{
    int16_t height = (int16_t)(read16(window + 20) - read16(window + 16));
    int16_t width = (int16_t)(read16(window + 22) - read16(window + 18));
    writeRect(window + 16, v, h, (int16_t)(v + height), (int16_t)(h + width));
    uint8_t** structure = (uint8_t**)read32(window + 114);
    uint8_t** content = (uint8_t**)read32(window + 118);
    if (structure && *structure) writeRect(*structure + 2, v, h, v + height, h + width);
    if (content && *content) writeRect(*content + 2, v, h, v + height, h + width);
    if (front) s_windowList = window;
}

static WindowSlot* windowSlot(uint8_t* window)
{
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (s_windows[i].used && s_windows[i].window == window) return &s_windows[i];
    return 0;
}

static int16_t findWindow(int16_t vertical, int16_t horizontal, uint8_t*& found)
{
    found = 0;

    // The menu bar owns this strip regardless of the window list.
    if (vertical >= 0 && vertical < 20) return 1; // inMenuBar

    // FindWindow receives a global Point.  Vette's shipped windows all use
    // WDEF 2 (plainDBoxProc), so their structure and content regions coincide:
    // a point in a visible window is inContent.  Walk the Window Manager chain
    // front-to-back just as FrontWindow does instead of recognizing a screen
    // or a control by coordinates.
    uint8_t* window = s_windowList;
    for (uint16_t visited = 0;
         window && visited < sizeof(s_windows) / sizeof(s_windows[0]);
         ++visited, window = (uint8_t*)read32(window + 144)) {
        WindowSlot* slot = windowSlot(window);
        if (!slot || !window[110]) continue;
        uint8_t** structureHandle = (uint8_t**)read32(window + 114);
        const uint8_t* region = structureHandle ? *structureHandle : 0;
        if (!region || read16(region) < 10) continue;
        const uint8_t* bounds = region + 2;
        if (vertical >= (int16_t)read16(bounds)
            && horizontal >= (int16_t)read16(bounds + 2)
            && vertical < (int16_t)read16(bounds + 4)
            && horizontal < (int16_t)read16(bounds + 6)) {
            found = window;
            return 3;                       // inContent
        }
    }

    return 0;                                      // inDesk
}

static bool disposeWindow(uint8_t* window)
{
    WindowSlot* slot = windowSlot(window);
    if (!slot) return false;
    uint8_t* next = (uint8_t*)read32(window + 144);
    if (s_windowList == window) s_windowList = next;
    else {
        for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i) {
            uint8_t* candidate = s_windows[i].used ? s_windows[i].window : 0;
            if (candidate && (uint8_t*)read32(candidate + 144) == window) {
                write32(candidate + 144, (uint32_t)next);
                break;
            }
        }
    }
    if ((uint8_t*)read32(s_qdThePort) == window)
        write32(s_qdThePort, (uint32_t)s_windowManagerPort);
    window[110] = 0;
    write32(window + 144, 0);
    slot->used = false;
    slot->window = 0;
    slot->dialog = false;
    slot->dialogItemCount = 0;
    slot->dialogDrawn = false;
    return true;
}

static bool paintBehind(uint8_t* startWindow, uint8_t** clobberedRegion)
{
    WindowSlot* slot = windowSlot(startWindow);
    uint8_t* region = clobberedRegion ? *clobberedRegion : 0;
    if (!slot || !region || read16(region) != 10) return false;

    // The measured transition calls start at a newly allocated, still hidden
    // game window.  There are no visible windows behind it, so PaintBehind
    // exposes only the background inside GrayRgn.  Retain the loud stop if a
    // later call actually needs WDEF drawing for a window farther down the chain.
    for (uint8_t* behind = (uint8_t*)read32(startWindow + 144); behind;
         behind = (uint8_t*)read32(behind + 144))
        if (behind[110]) return false;

    int16_t top = (int16_t)read16(region + 2);
    int16_t left = (int16_t)read16(region + 4);
    int16_t bottom = (int16_t)read16(region + 6);
    int16_t right = (int16_t)read16(region + 8);
    if (top < 0) top = 0;
    if (left < 0) left = 0;
    if (bottom > 320) bottom = 320;
    if (right > 512) right = 512;
    if (top >= bottom || left >= right) return true;

    // There is no Macintosh desktop in the standalone Amiga game.  When the
    // complete GrayRgn is exposed, include the former menu-bar rows so pixels
    // from the retiring full-screen window cannot remain above the next one.
    if (top == 20 && left == 0 && bottom == 320 && right == 512) top = 0;

    // Clear exposed space to reserved black.  Work in packed 4-bpp bytes and
    // preserve boundary nibbles for any future partial background exposure.
    for (int16_t y = top; y < bottom; ++y) {
        uint8_t* row = s_colorScreen + (uint32_t)y * (512 / 2);
        int16_t x = left;
        if (x & 1) {
            row[x >> 1] &= 0xf0;
            ++x;
        }
        uint16_t firstByte = (uint16_t)(x >> 1);
        uint16_t fullBytes = (uint16_t)((right - x) >> 1);
        blockFill(row + firstByte, fullBytes, 0);
        x = (int16_t)(x + fullBytes * 2);
        if (x < right)
            row[x >> 1] &= 0x0f;
    }
    markDirtyBounds(top, left, bottom, right);
    return true;
}

static bool disposeDialog(uint8_t* dialog)
{
    WindowSlot* slot = windowSlot(dialog);
    return slot && slot->dialog && disposeWindow(dialog);
}

static int32_t resourceHandleIndex(uint8_t** handle);
static uint8_t** newHandle(uint32_t size, bool clear);
static uint32_t handleSize(uint8_t** handle);
static int16_t setHandleSize(uint8_t** handle, uint32_t newSize);

static uint32_t resourceHandleSize(uint8_t** handle)
{
    int32_t index = resourceHandleIndex(handle);
    ResourceForks::Item item;
    return index >= 0 && s_resourceForks.item((uint32_t)index, item) ? item.size : 0;
}

static bool drawDialog(uint8_t* dialog)
{
    WindowSlot* slot = windowSlot(dialog);
    if (!slot || !slot->dialog) return false;
    uint8_t** itemsHandle = (uint8_t**)read32(dialog + 156);
    uint32_t size = resourceHandleSize(itemsHandle);
    if (!itemsHandle || !*itemsHandle || size < 2) return false;
    const uint8_t* items = *itemsHandle;
    uint16_t count = (uint16_t)(read16(items) + 1);
    uint32_t offset = 2;
    for (uint16_t i = 0; i < count; ++i) {
        if (offset + 14 > size) return false;
        uint8_t dataLength = items[offset + 13];
        offset += 14 + dataLength;
        if (offset & 1) ++offset;
        if (offset > size) return false;
    }
    slot->dialogItemCount = count;
    slot->dialogDrawn = true;
    dialog[110] = 1;
    write32(s_qdThePort, (uint32_t)dialog);
    // DrawDialog draws items, not the window background. The recovery and
    // model-preview DITLs contain only a null userItem, so they draw nothing;
    // the original code supplies their picture separately with DrawPicture.
    // Clearing here used global window bounds while the picture uses local
    // coordinates, corrupting background exposed by word-aligned C2P.
    // Text/control rendering remains outside this compatibility subset.
    return true;
}

static bool unpackPackBitsRow(const uint8_t* packed, uint32_t packedSize,
                              uint8_t* unpacked, uint16_t rowBytes,
                              const uint8_t* byteMap = 0)
{
    uint32_t source = 0;
    uint16_t destination = 0;
    while (source < packedSize && destination < rowBytes) {
        int8_t header = (int8_t)packed[source++];
        if (header >= 0) {
            uint16_t count = (uint16_t)header + 1;
            if (source + count > packedSize || destination + count > rowBytes) return false;
            const uint8_t* literal = packed + source;
            uint8_t* output = unpacked + destination;
            uint16_t left = count;
            if (byteMap) {
                for (uint16_t i = 0; i < left; ++i) *output++ = byteMap[*literal++];
                left = 0;
            } else if ((((uint32_t)literal ^ (uint32_t)output) & 1) == 0) {
                if ((uint32_t)literal & 1) {
                    *output++ = *literal++;
                    --left;
                }
                while (left >= 2) {
                    *(uint16_t*)output = *(const uint16_t*)literal;
                    output += 2;
                    literal += 2;
                    left -= 2;
                }
            }
            while (left--) *output++ = *literal++;
            source += count;
            destination = (uint16_t)(destination + count);
        } else if (header != -128) {
            uint16_t count = (uint16_t)(1 - header);
            if (source >= packedSize || destination + count > rowBytes) return false;
            uint8_t value = packed[source++];
            if (byteMap) value = byteMap[value];
            uint8_t* output = unpacked + destination;
            uint16_t left = count;
            if ((uint32_t)output & 1) {
                *output++ = value;
                --left;
            }
            uint16_t pair = (uint16_t)((value << 8) | value);
            while (left >= 2) {
                *(uint16_t*)output = pair;
                output += 2;
                left -= 2;
            }
            if (left) *output = value;
            destination = (uint16_t)(destination + count);
        }
    }
    return destination == rowBytes && source == packedSize;
}

static uint32_t multiplyUnsigned16(uint16_t first, uint16_t second)
{
    uint32_t product = first;
    __asm__ volatile ("mulu.w %1,%0" : "+d" (product) : "d" (second));
    return product;
}

static void setPackedPixel(uint8_t* pixels, uint16_t rowBytes,
                           int16_t boundsTop, int16_t boundsLeft,
                           int16_t x, int16_t y, uint8_t value)
{
    uint8_t* byte = pixels + multiplyUnsigned16((uint16_t)(y - boundsTop), rowBytes)
                    + (uint16_t)(x - boundsLeft) / 2;
    if ((x - boundsLeft) & 1) *byte = (uint8_t)((*byte & 0xf0) | (value & 0x0f));
    else *byte = (uint8_t)((*byte & 0x0f) | ((value & 0x0f) << 4));
}

static void publishMouseCursor()
{
    if (s_loudStopScreen)
        s_loudStopScreen->setMouseCursor(s_cursor.image, s_mouseX, s_mouseY,
                                         s_cursor.initialized && s_cursor.visible);
}

static uint32_t multiplyDivide(uint16_t value, uint16_t multiplier, uint16_t divisor)
{
    if (!divisor) return 0;
    if (multiplier == divisor) return value;
    uint32_t quotient = value;
    __asm__ volatile ("mulu.w %1,%0" : "+d" (quotient) : "d" (multiplier));
    // Every caller maps one 16-bit coordinate between rectangles, so the
    // quotient is itself a 16-bit coordinate.  DIVU.W leaves that quotient in
    // the low word and the remainder in the high word.
    __asm__ volatile ("divu.w %1,%0" : "+d" (quotient) : "d" (divisor));
    return quotient & 0xffff;
}

static uint32_t multiplyDivideCentered(uint16_t value, uint16_t multiplier,
                                       uint16_t divisor)
{
    if (!divisor) return 0;
    if (multiplier == divisor) return value;
    // QuickDraw samples a scaled destination pixel at its centre.  Adding half
    // a source pixel before division places a duplicated row in the interior
    // of a 77->78 stretch instead of duplicating row zero at the top edge.
    uint32_t numerator = multiplyUnsigned16(value, multiplier) + (multiplier >> 1);
    __asm__ volatile ("divu.w %1,%0" : "+d" (numerator) : "d" (divisor));
    return numerator & 0xffff;
}

static bool drawIndexedPictureBits(const uint8_t* picture, uint32_t size, uint32_t& offset,
                                   const uint8_t* pictureFrame, const uint8_t* targetRect,
                                   bool packed)
{
    if (offset + 46 > size) return false;
    const uint8_t* pixMap = picture + offset;
    uint16_t rowBytes = (uint16_t)(read16(pixMap) & 0x3fff);
    uint16_t pixelSize = read16(pixMap + 28);
    if (!(read16(pixMap) & 0x8000) || (pixelSize != 4 && pixelSize != 8) || !rowBytes)
        return false;
    int16_t sourceTop = (int16_t)read16(pixMap + 2);
    int16_t sourceLeft = (int16_t)read16(pixMap + 4);
    int16_t sourceBottom = (int16_t)read16(pixMap + 6);
    int16_t sourceRight = (int16_t)read16(pixMap + 8);
    if (sourceBottom <= sourceTop || sourceRight <= sourceLeft) return false;
    offset += 46;

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    // Color QuickDraw realizes an RGB color through the current GDevice's
    // inverse table.  That device environment is distinct from the retained
    // ColorTable attached to an offscreen PixMap.  Vette relies on the
    // distinction while drawing palette-131 PICTs into a palette-130 GWorld:
    // System 6 stores the current device's physical pen, then later preserves
    // that pen when copying the completed world to the screen.
    const uint8_t* destinationColors = s_windowManagerColors;

    if (offset + 8 > size) return false;
    const uint8_t* colorTable = picture + offset;
    uint16_t colorFlags = read16(colorTable + 4);
    uint16_t finalColor = read16(colorTable + 6);
    if ((pixelSize == 4 && finalColor > 15) || (pixelSize == 8 && finalColor > 255))
        return false;
    uint32_t colorBytes = 8UL + ((uint32_t)finalColor + 1) * 8;
    if (offset + colorBytes > size) return false;
    uint8_t colorMap[256];
    for (uint16_t i = 0; i < 256; ++i) colorMap[i] = 0;
    for (uint16_t i = 0; i <= finalColor; ++i) {
        const uint8_t* sourceColor = colorTable + 8 + (uint32_t)i * 8;
        uint16_t sourceIndex = colorFlags & 0x8000 ? i : read16(sourceColor);
        uint32_t bestDistance = 0xffffffffUL;
        uint8_t bestIndex = 0;
        for (uint8_t destinationIndex = 0; destinationIndex < 16; ++destinationIndex) {
            const uint8_t* destinationColor
                = destinationColors + 8 + (uint16_t)destinationIndex * 8;
            uint16_t sr = read16(sourceColor + 2), sg = read16(sourceColor + 4);
            uint16_t sb = read16(sourceColor + 6);
            uint16_t dr = read16(destinationColor + 2), dg = read16(destinationColor + 4);
            uint16_t db = read16(destinationColor + 6);
            uint16_t distance = colorDistance4(sr, sg, sb, dr, dg, db);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = destinationIndex;
            }
        }
        if (sourceIndex < 256) colorMap[sourceIndex] = bestIndex;
    }
    uint8_t packedColorMap[256];
    if (pixelSize == 4)
        for (uint16_t i = 0; i < 256; ++i)
            packedColorMap[i] = (uint8_t)((colorMap[i >> 4] << 4) | colorMap[i & 0x0f]);
    offset += colorBytes;
    if (offset + 18 > size) return false;
    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0) return false;              // srcCopy is the measured title path
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(rowBytes, height);
    bool allocatedPixels = pixelBytes > sizeof(s_indexedPictureScratch);
    uint8_t* pixels = allocatedPixels
        ? (uint8_t*)AllocMem(pixelBytes, 0) : s_indexedPictureScratch;
    if (!pixels) return false;
    bool valid = true;
    bool pixelsMapped = packed && pixelSize == 4;
    if (!packed) {
        if (offset + pixelBytes > size) valid = false;
        else {
            blockMove(picture + offset, pixels, pixelBytes);
            offset += pixelBytes;
        }
    } else {
        for (uint16_t row = 0; row < height && valid; ++row) {
            if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
            uint16_t packedSize;
            if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
            else packedSize = picture[offset++];
            if (offset + packedSize > size
                || !unpackPackBitsRow(picture + offset, packedSize,
                                      pixels + multiplyUnsigned16(row, rowBytes), rowBytes,
                                      pixelsMapped ? packedColorMap : 0)) {
                valid = false; break;
            }
            offset += packedSize;
        }
    }
    if (offset & 1) ++offset;

    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    bool usedPackedRows = false;
    bool unscaledPacked = valid
        && frameBottom - frameTop == targetBottom - targetTop
        && frameRight - frameLeft == targetRight - targetLeft
        && rasterBottom - rasterTop == copyBottom - copyTop
        && rasterRight - rasterLeft == copyRight - copyLeft;
    if (unscaledPacked) {
        int16_t translatedRasterTop = (int16_t)(targetTop + rasterTop - frameTop);
        int16_t translatedRasterLeft = (int16_t)(targetLeft + rasterLeft - frameLeft);
        int16_t translatedRasterBottom = (int16_t)(targetTop + rasterBottom - frameTop);
        int16_t translatedRasterRight = (int16_t)(targetLeft + rasterRight - frameLeft);
        int16_t packedTop = translatedRasterTop, packedLeft = translatedRasterLeft;
        int16_t packedBottom = translatedRasterBottom, packedRight = translatedRasterRight;
        if (packedTop < targetTop) packedTop = targetTop;
        if (packedTop < mapTop) packedTop = mapTop;
        if (packedTop < translatedRasterTop + sourceTop - copyTop)
            packedTop = (int16_t)(translatedRasterTop + sourceTop - copyTop);
        if (packedLeft < targetLeft) packedLeft = targetLeft;
        if (packedLeft < mapLeft) packedLeft = mapLeft;
        if (packedLeft < translatedRasterLeft + sourceLeft - copyLeft)
            packedLeft = (int16_t)(translatedRasterLeft + sourceLeft - copyLeft);
        if (packedBottom > targetBottom) packedBottom = targetBottom;
        if (packedBottom > mapBottom) packedBottom = mapBottom;
        if (packedBottom > translatedRasterTop + sourceBottom - copyTop)
            packedBottom = (int16_t)(translatedRasterTop + sourceBottom - copyTop);
        if (packedRight > targetRight) packedRight = targetRight;
        if (packedRight > mapRight) packedRight = mapRight;
        if (packedRight > translatedRasterLeft + sourceRight - copyLeft)
            packedRight = (int16_t)(translatedRasterLeft + sourceRight - copyLeft);
        int16_t packedSourceLeft
            = (int16_t)(copyLeft + packedLeft - translatedRasterLeft);
        if (packedTop >= packedBottom || packedLeft >= packedRight) {
            usedPackedRows = true;
        } else if (pixelSize == 4 && ((packedSourceLeft - sourceLeft) & 1) == 0
                   && ((packedLeft - mapLeft) & 1) == 0
                   && ((packedRight - packedLeft) & 1) == 0) {
            uint16_t copyBytes = (uint16_t)(packedRight - packedLeft) >> 1;
            for (int16_t y = packedTop; y < packedBottom; ++y) {
                int16_t sourceY = (int16_t)(copyTop + y - translatedRasterTop);
                uint8_t* source = pixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes)
                    + (uint16_t)(packedSourceLeft - sourceLeft) / 2;
                uint8_t* destination = destinationPixels
                    + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes)
                    + (uint16_t)(packedLeft - mapLeft) / 2;
                if (pixelsMapped) {
                    for (uint16_t x = 0; x < copyBytes; ++x) destination[x] = source[x];
                } else {
                    for (uint16_t x = 0; x < copyBytes; ++x)
                        destination[x] = packedColorMap[source[x]];
                }
            }
            usedPackedRows = true;
        } else if (pixelSize == 8) {
            for (int16_t y = packedTop; y < packedBottom; ++y) {
                int16_t sourceY = (int16_t)(copyTop + y - translatedRasterTop);
                const uint8_t* source = pixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes)
                    + (uint16_t)(packedSourceLeft - sourceLeft);
                uint8_t* destination = destinationPixels
                    + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes)
                    + (uint16_t)(packedLeft - mapLeft) / 2;
                uint16_t pixelsLeft = (uint16_t)(packedRight - packedLeft);
                if ((packedLeft - mapLeft) & 1) {
                    *destination = (uint8_t)((*destination & 0xf0) | colorMap[*source++]);
                    ++destination;
                    --pixelsLeft;
                }
                while (pixelsLeft >= 2) {
                    uint8_t high = colorMap[*source++];
                    uint8_t low = colorMap[*source++];
                    *destination++ = (uint8_t)((high << 4) | low);
                    pixelsLeft -= 2;
                }
                if (pixelsLeft) {
                    *destination = (uint8_t)((*destination & 0x0f)
                                           | (colorMap[*source] << 4));
                }
            }
            usedPackedRows = true;
        }
    }

    // A vertically scaled PICT can still be copied as packed rows when both
    // horizontal mappings are 1:1.  The driving view uses 512-pixel-wide
    // 4-bit strips in a 157->156 vertical mapping; falling through to the
    // generic pixel loop performed two coordinate divisions for every pixel
    // even though sourceX is only a translation of x.
    bool horizontallyUnscaled = valid && pixelSize == 4
        && frameRight - frameLeft == targetRight - targetLeft
        && rasterRight - rasterLeft == copyRight - copyLeft;
    if (!usedPackedRows && horizontallyUnscaled) {
        int16_t translatedRasterLeft = (int16_t)(targetLeft + rasterLeft - frameLeft);
        int16_t packedLeft = translatedRasterLeft;
        int16_t packedRight = (int16_t)(targetLeft + rasterRight - frameLeft);
        if (packedLeft < targetLeft) packedLeft = targetLeft;
        if (packedLeft < mapLeft) packedLeft = mapLeft;
        if (packedLeft < translatedRasterLeft + sourceLeft - copyLeft)
            packedLeft = (int16_t)(translatedRasterLeft + sourceLeft - copyLeft);
        if (packedRight > targetRight) packedRight = targetRight;
        if (packedRight > mapRight) packedRight = mapRight;
        if (packedRight > translatedRasterLeft + sourceRight - copyLeft)
            packedRight = (int16_t)(translatedRasterLeft + sourceRight - copyLeft);
        int16_t packedSourceLeft = (int16_t)(copyLeft + packedLeft - translatedRasterLeft);
        if (packedLeft >= packedRight) {
            usedPackedRows = true;
        } else if (((packedSourceLeft - sourceLeft) & 1) == 0
                   && ((packedLeft - mapLeft) & 1) == 0
                   && ((packedRight - packedLeft) & 1) == 0) {
            uint16_t copyBytes = (uint16_t)(packedRight - packedLeft) >> 1;
            for (int16_t y = targetTop; y < targetBottom; ++y) {
                if (y < mapTop || y >= mapBottom) continue;
                int16_t pictureY = (int16_t)(frameTop + multiplyDivideCentered(
                    (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                    (uint16_t)(targetBottom - targetTop)));
                if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
                int16_t sourceY = (int16_t)(copyTop + multiplyDivideCentered(
                    (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                    (uint16_t)(rasterBottom - rasterTop)));
                if (sourceY < sourceTop || sourceY >= sourceBottom) continue;
                uint8_t* source = pixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes)
                    + (uint16_t)(packedSourceLeft - sourceLeft) / 2;
                uint8_t* destination = destinationPixels
                    + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes)
                    + (uint16_t)(packedLeft - mapLeft) / 2;
                if (pixelsMapped) {
                    for (uint16_t x = 0; x < copyBytes; ++x) destination[x] = source[x];
                } else {
                    for (uint16_t x = 0; x < copyBytes; ++x)
                        destination[x] = packedColorMap[source[x]];
                }
            }
            usedPackedRows = true;
        }
    }

    if (valid && !usedPackedRows) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivideCentered(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivideCentered(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivideCentered(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivideCentered(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t value;
                    if (pixelSize == 4) {
                        uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                        uint8_t sourceValue = sourceColumn & 1
                            ? (uint8_t)(sourceByte & 0x0f) : (uint8_t)(sourceByte >> 4);
                        value = pixelsMapped ? sourceValue : colorMap[sourceValue];
                    } else value = colorMap[sourceRow[sourceColumn]];
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    if (allocatedPixels) FreeMem(pixels, pixelBytes);
    return valid;
}

static bool drawPackedMonochromePictureBits(const uint8_t* picture, uint32_t size,
                                            uint32_t& offset,
                                            const uint8_t* pictureFrame,
                                            const uint8_t* targetRect)
{
    if (offset + 28 > size) return false;
    uint16_t rowBytesWord = read16(picture + offset);
    uint16_t rowBytes = (uint16_t)(rowBytesWord & 0x3fff);
    if ((rowBytesWord & 0x8000) || !rowBytes) return false; // BitMap, not PixMap
    int16_t sourceTop = (int16_t)read16(picture + offset + 2);
    int16_t sourceLeft = (int16_t)read16(picture + offset + 4);
    int16_t sourceBottom = (int16_t)read16(picture + offset + 6);
    int16_t sourceRight = (int16_t)read16(picture + offset + 8);
    if (sourceBottom <= sourceTop || sourceRight <= sourceLeft
        || rowBytes < ((uint16_t)(sourceRight - sourceLeft) + 7) / 8) return false;
    offset += 10;

    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0 && mode != 1) return false; // srcCopy or srcOr
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(rowBytes, height);
    uint8_t* pixels = (uint8_t*)AllocMem(pixelBytes, 0);
    if (!pixels) return false;
    bool valid = true;
    for (uint16_t row = 0; row < height && valid; ++row) {
        if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
        uint16_t packedSize;
        if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
        else packedSize = picture[offset++];
        if (offset + packedSize > size
            || !unpackPackBitsRow(picture + offset, packedSize,
                                  pixels + multiplyUnsigned16(row, rowBytes), rowBytes)) {
            valid = false; break;
        }
        offset += packedSize;
    }

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap
        ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    bool usedUnscaledRows = false;
    if (valid
        && frameBottom - frameTop == targetBottom - targetTop
        && frameRight - frameLeft == targetRight - targetLeft
        && rasterBottom - rasterTop == copyBottom - copyTop
        && rasterRight - rasterLeft == copyRight - copyLeft) {
        int16_t translatedRasterTop = (int16_t)(targetTop + rasterTop - frameTop);
        int16_t translatedRasterLeft = (int16_t)(targetLeft + rasterLeft - frameLeft);
        int16_t translatedRasterBottom = (int16_t)(targetTop + rasterBottom - frameTop);
        int16_t translatedRasterRight = (int16_t)(targetLeft + rasterRight - frameLeft);
        int16_t packedTop = translatedRasterTop;
        int16_t packedLeft = translatedRasterLeft;
        int16_t packedBottom = translatedRasterBottom;
        int16_t packedRight = translatedRasterRight;
        if (packedTop < targetTop) packedTop = targetTop;
        if (packedTop < mapTop) packedTop = mapTop;
        if (packedTop < translatedRasterTop + sourceTop - copyTop)
            packedTop = (int16_t)(translatedRasterTop + sourceTop - copyTop);
        if (packedLeft < targetLeft) packedLeft = targetLeft;
        if (packedLeft < mapLeft) packedLeft = mapLeft;
        if (packedLeft < translatedRasterLeft + sourceLeft - copyLeft)
            packedLeft = (int16_t)(translatedRasterLeft + sourceLeft - copyLeft);
        if (packedBottom > targetBottom) packedBottom = targetBottom;
        if (packedBottom > mapBottom) packedBottom = mapBottom;
        if (packedBottom > translatedRasterTop + sourceBottom - copyTop)
            packedBottom = (int16_t)(translatedRasterTop + sourceBottom - copyTop);
        if (packedRight > targetRight) packedRight = targetRight;
        if (packedRight > mapRight) packedRight = mapRight;
        if (packedRight > translatedRasterLeft + sourceRight - copyLeft)
            packedRight = (int16_t)(translatedRasterLeft + sourceRight - copyLeft);

        for (int16_t y = packedTop; y < packedBottom; ++y) {
            int16_t sourceY = (int16_t)(copyTop + y - translatedRasterTop);
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            int16_t sourceX = (int16_t)(copyLeft + packedLeft - translatedRasterLeft);
            for (int16_t x = packedLeft; x < packedRight; ++x, ++sourceX) {
                uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                bool set = (sourceRow[sourceColumn >> 3]
                    & (uint8_t)(0x80 >> (sourceColumn & 7))) != 0;
                uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                uint8_t mask = destinationColumn & 1 ? 0x0f : 0xf0;
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (set) destinationByte |= mask;
                else if (mode == 0) destinationByte &= (uint8_t)~mask;
            }
        }
        usedUnscaledRows = true;
    }

    if (valid && !usedUnscaledRows) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivide(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivide(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivide(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivide(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t value = sourceRow[sourceColumn >> 3]
                        & (uint8_t)(0x80 >> (sourceColumn & 7)) ? 15 : 0;
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (mode == 1) {
                        uint8_t destinationValue = destinationColumn & 1
                            ? (uint8_t)(destinationByte & 0x0f)
                            : (uint8_t)(destinationByte >> 4);
                        value = (uint8_t)(destinationValue | value);
                    }
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    FreeMem(pixels, pixelBytes);
    return valid;
}

static bool drawDirectPictureBits(const uint8_t* picture, uint32_t size, uint32_t& offset,
                                  const uint8_t* pictureFrame, const uint8_t* targetRect)
{
    if (offset + 68 > size) return false;
    offset += 4;                            // baseAddr is not stored in a PICT PixMap
    const uint8_t* pixMap = picture + offset;
    uint16_t rowBytes = (uint16_t)(read16(pixMap) & 0x3fff);
    int16_t sourceTop = (int16_t)read16(pixMap + 2);
    int16_t sourceLeft = (int16_t)read16(pixMap + 4);
    int16_t sourceBottom = (int16_t)read16(pixMap + 6);
    int16_t sourceRight = (int16_t)read16(pixMap + 8);
    if (!(read16(pixMap) & 0x8000) || read16(pixMap + 12) != 4
        || read16(pixMap + 26) != 16 || read16(pixMap + 28) != 32
        || read16(pixMap + 30) != 3 || read16(pixMap + 32) != 8
        || sourceBottom <= sourceTop || sourceRight <= sourceLeft || !rowBytes) return false;
    uint16_t width = (uint16_t)(sourceRight - sourceLeft);
    uint16_t componentRowBytes = (uint16_t)(width + width + width);
    if (rowBytes < (uint16_t)(width << 2)) return false;
    offset += 46;

    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0 && mode != 0x0040) return false; // srcCopy or ditherCopy
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(componentRowBytes, height);
    uint8_t* pixels = (uint8_t*)AllocMem(pixelBytes, 0);
    if (!pixels) return false;
    bool valid = true;
    for (uint16_t row = 0; row < height && valid; ++row) {
        if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
        uint16_t packedSize;
        if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
        else packedSize = picture[offset++];
        if (offset + packedSize > size
            || !unpackPackBitsRow(picture + offset, packedSize,
                                  pixels + multiplyUnsigned16(row, componentRowBytes),
                                  componentRowBytes)) {
            valid = false; break;
        }
        offset += packedSize;
    }
    if (offset & 1) ++offset;

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    // Direct PICT colors use the same current-device inverse-color lookup as
    // indexed PICT colors; the destination PixMap's retained table is not the
    // active GDevice CLUT.
    const uint8_t* destinationColors = s_windowManagerColors;

    uint8_t colorMap[256];
    static const uint16_t levels3[8] = {
        0x0000,0x2492,0x4924,0x6db6,0x9249,0xb6db,0xdb6d,0xffff
    };
    static const uint16_t levels2[4] = { 0x0000,0x5555,0xaaaa,0xffff };
    for (uint16_t key = 0; key < 256; ++key) {
        uint16_t sr = levels3[key >> 5];
        uint16_t sg = levels3[(key >> 2) & 7];
        uint16_t sb = levels2[key & 3];
        uint32_t bestDistance = 0xffffffffUL;
        uint8_t bestIndex = 0;
        for (uint8_t destinationIndex = 0; destinationIndex < 16; ++destinationIndex) {
            const uint8_t* destinationColor
                = destinationColors + 8 + (uint16_t)destinationIndex * 8;
            uint16_t dr = read16(destinationColor + 2), dg = read16(destinationColor + 4);
            uint16_t db = read16(destinationColor + 6);
            uint16_t distance = colorDistance4(sr, sg, sb, dr, dg, db);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = destinationIndex;
            }
        }
        colorMap[key] = bestIndex;
    }

    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap
        ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    if (valid) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivide(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivide(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), componentRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivide(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivide(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t red = sourceRow[column];
                    uint8_t green = sourceRow[width + column];
                    uint8_t blue = sourceRow[width + width + column];
                    uint8_t value = colorMap[(red & 0xe0) | ((green >> 3) & 0x1c)
                                             | (blue >> 6)];
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    FreeMem(pixels, pixelBytes);
    return valid;
}

static const uint8_t kPictureFont[36][7] = {
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
    {17,17,10,4,4,4,4},{31,1,2,4,8,16,31}
};

static uint8_t pictureGlyphRow(uint8_t character, uint16_t row)
{
    if (character >= 'a' && character <= 'z') character -= (uint8_t)('a' - 'A');
    if (character >= '0' && character <= '9') return kPictureFont[character - '0'][row];
    if (character >= 'A' && character <= 'Z') return kPictureFont[10 + character - 'A'][row];
    if (character == ':') return (row == 2 || row == 5) ? 4 : 0;
    return 0;
}

static bool pictureRoundPixel(int16_t y, int16_t x, int16_t top, int16_t left,
                              int16_t bottom, int16_t right, uint16_t diameter)
{
    if (y < top || y >= bottom || x < left || x >= right) return false;
    uint16_t radius = (uint16_t)(diameter >> 1);
    uint16_t halfHeight = (uint16_t)(bottom - top) >> 1;
    uint16_t halfWidth = (uint16_t)(right - left) >> 1;
    if (radius > halfHeight) radius = halfHeight;
    if (radius > halfWidth) radius = halfWidth;
    if (!radius || (y >= top + radius && y < bottom - radius)
        || (x >= left + radius && x < right - radius)) return true;
    int16_t centerY = y < top + radius ? (int16_t)(top + radius - 1)
                                           : (int16_t)(bottom - radius);
    int16_t centerX = x < left + radius ? (int16_t)(left + radius - 1)
                                            : (int16_t)(right - radius);
    int16_t dy = (int16_t)(y - centerY), dx = (int16_t)(x - centerX);
    return (uint16_t)(dy * dy + dx * dx) < (uint16_t)(radius * radius);
}

static bool drawVersionOnePicture(const uint8_t* picture, uint32_t size,
                                  const uint8_t* frame, const uint8_t* targetRect)
{
    uint32_t offset = 12;                    // version opcode $11, version byte $01
    bool drewPixels = false;
    uint8_t pattern[8] = { 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff };
    int16_t penHeight = 1, penWidth = 1, ovalHeight = 0, ovalWidth = 0;
    int16_t textV = 0, textH = 0;
    int16_t lastTop = 0, lastLeft = 0, lastBottom = 0, lastRight = 0;
    int16_t frameTop = (int16_t)read16(frame), frameLeft = (int16_t)read16(frame + 2);
    int16_t frameBottom = (int16_t)read16(frame + 4), frameRight = (int16_t)read16(frame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    if (frameBottom - frameTop != targetBottom - targetTop
        || frameRight - frameLeft != targetRight - targetLeft) return false;
    int16_t translateV = (int16_t)(targetTop - frameTop);
    int16_t translateH = (int16_t)(targetLeft - frameLeft);
    textV = translateV;
    textH = translateH;
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** mapHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* map = mapHandle ? *mapHandle : 0;
    uint8_t* pixels = map ? (uint8_t*)read32(map) : 0;
    uint16_t rowBytes = map ? (uint16_t)(read16(map + 4) & 0x3fff) : 0;
    int16_t mapTop = map ? (int16_t)read16(map + 6) : 0;
    int16_t mapLeft = map ? (int16_t)read16(map + 8) : 0;
    int16_t mapBottom = map ? (int16_t)read16(map + 10) : 0;
    int16_t mapRight = map ? (int16_t)read16(map + 12) : 0;
    if (!pixels || !rowBytes || read16(map + 32) != 4) return false;
    while (offset < size) {
        uint8_t opcode = picture[offset++];
        if (opcode == 0xff) return drewPixels;
        if (opcode == 0x00) continue;
        if (opcode == 0xa0) { if (offset + 2 > size) return false; offset += 2; continue; }
        if (opcode == 0xa1) {
            if (offset + 4 > size) return false;
            uint16_t bytes = read16(picture + offset + 2);
            if (offset + 4UL + bytes > size) return false;
            offset += 4UL + bytes;
            continue;
        }
        if (opcode == 0x01) {
            if (offset + 2 > size) return false;
            uint16_t bytes = read16(picture + offset);
            if (bytes < 2 || offset + bytes > size) return false;
            offset += bytes; continue;
        }
        if (opcode == 0x03 || opcode == 0x0d) {
            if (offset + 2 > size) return false;
            offset += 2; continue;            // font ID / point size
        }
        if (opcode == 0x04) {
            if (offset >= size) return false;
            ++offset; continue;               // text face; compact fallback is unstyled
        }
        if (opcode == 0x07) {
            if (offset + 4 > size) return false;
            penHeight = (int16_t)read16(picture + offset);
            penWidth = (int16_t)read16(picture + offset + 2);
            offset += 4; continue;
        }
        if (opcode == 0x09) {
            if (offset + 8 > size) return false;
            for (uint16_t i = 0; i < 8; ++i) pattern[i] = picture[offset + i];
            offset += 8; continue;
        }
        if (opcode == 0x0a) { if (offset + 8 > size) return false; offset += 8; continue; }
        if (opcode == 0x0b) {
            if (offset + 4 > size) return false;
            ovalHeight = (int16_t)read16(picture + offset);
            ovalWidth = (int16_t)read16(picture + offset + 2);
            offset += 4; continue;
        }
        if (opcode == 0x2c) {                // FontName: byte count + old ID + Pascal name
            if (offset + 2 > size) return false;
            uint16_t bytes = read16(picture + offset);
            if (bytes < 3 || offset + 2UL + bytes > size
                || picture[offset + 4] > bytes - 3) return false;
            offset += 2UL + bytes;
            continue;                        // compact text fallback is font-independent
        }
        if (opcode == 0x22) {
            if (offset + 6 > size) return false;
            int16_t startV = (int16_t)(read16(picture + offset) + translateV);
            int16_t startH = (int16_t)(read16(picture + offset + 2) + translateH);
            int16_t endH = (int16_t)(startH + (int8_t)picture[offset + 4]);
            int16_t endV = (int16_t)(startV + (int8_t)picture[offset + 5]);
            int16_t x = startH, y = startV;
            int16_t dx = endH >= x ? (int16_t)(endH - x) : (int16_t)(x - endH);
            int16_t sx = x < endH ? 1 : -1;
            int16_t dy = endV >= y ? (int16_t)(y - endV) : (int16_t)(endV - y);
            int16_t sy = y < endV ? 1 : -1;
            int16_t error = (int16_t)(dx + dy);
            for (;;) {
                for (int16_t py = 0; py < penHeight; ++py)
                    for (int16_t px = 0; px < penWidth; ++px) {
                        int16_t plotY = (int16_t)(y + py), plotX = (int16_t)(x + px);
                        if (plotY >= mapTop && plotY < mapBottom
                            && plotX >= mapLeft && plotX < mapRight) {
                            uint8_t color = pattern[plotY & 7] & (0x80u >> (plotX & 7)) ? 15 : 0;
                            setPackedPixel(pixels, rowBytes, mapTop, mapLeft, plotX, plotY, color);
                        }
                    }
                if (x == endH && y == endV) break;
                int16_t twice = (int16_t)(error << 1);
                if (twice >= dy) { error = (int16_t)(error + dy); x = (int16_t)(x + sx); }
                if (twice <= dx) { error = (int16_t)(error + dx); y = (int16_t)(y + sy); }
            }
            offset += 6; drewPixels = true; continue;
        }
        if (opcode == 0x41 || opcode == 0x48) {
            if (opcode == 0x41) {
                if (offset + 8 > size) return false;
                lastTop = (int16_t)(read16(picture + offset) + translateV);
                lastLeft = (int16_t)(read16(picture + offset + 2) + translateH);
                lastBottom = (int16_t)(read16(picture + offset + 4) + translateV);
                lastRight = (int16_t)(read16(picture + offset + 6) + translateH);
                offset += 8;
            }
            for (int16_t y = lastTop; y < lastBottom; ++y)
                for (int16_t x = lastLeft; x < lastRight; ++x) {
                    if (y < mapTop || y >= mapBottom || x < mapLeft || x >= mapRight
                        || !pictureRoundPixel(y, x, lastTop, lastLeft, lastBottom, lastRight,
                                              (uint16_t)(ovalWidth < ovalHeight
                                                  ? ovalWidth : ovalHeight))) continue;
                    bool paint = opcode == 0x41;
                    if (!paint) {
                        int16_t innerTop = (int16_t)(lastTop + penHeight);
                        int16_t innerLeft = (int16_t)(lastLeft + penWidth);
                        int16_t innerBottom = (int16_t)(lastBottom - penHeight);
                        int16_t innerRight = (int16_t)(lastRight - penWidth);
                        paint = !pictureRoundPixel(y, x, innerTop, innerLeft, innerBottom,
                                                   innerRight,
                                                   (uint16_t)((ovalWidth < ovalHeight
                                                       ? ovalWidth : ovalHeight) - 2 * penWidth));
                    }
                    if (paint) {
                        uint8_t color = pattern[y & 7] & (0x80u >> (x & 7)) ? 15 : 0;
                        setPackedPixel(pixels, rowBytes, mapTop, mapLeft, x, y, color);
                    }
                }
            drewPixels = true; continue;
        }
        if (opcode >= 0x28 && opcode <= 0x2b) {
            uint16_t prefix = opcode == 0x28 ? 4 : opcode == 0x2b ? 2 : 1;
            if (offset + prefix + 1 > size) return false;
            if (opcode == 0x28) {
                textV = (int16_t)(read16(picture + offset) + translateV);
                textH = (int16_t)(read16(picture + offset + 2) + translateH);
            } else if (opcode == 0x29) {     // DHText
                textH = (int16_t)(textH + picture[offset]);
            } else if (opcode == 0x2a) {     // DVText
                textV = (int16_t)(textV + picture[offset]);
            } else {                         // DHDVText
                textH = (int16_t)(textH + picture[offset]);
                textV = (int16_t)(textV + picture[offset + 1]);
            }
            uint8_t length = picture[offset + prefix];
            if (offset + prefix + 1UL + length > size) return false;
            const uint8_t* text = picture + offset + prefix + 1;
            for (uint16_t i = 0; i < length; ++i) {
                for (uint16_t row = 0; row < 7; ++row) {
                    uint8_t bits = pictureGlyphRow(text[i], row);
                    for (uint16_t column = 0; column < 5; ++column)
                        if (bits & (16u >> column)) {
                            int16_t x = (int16_t)(textH + i * 6 + column);
                            int16_t y = (int16_t)(textV - 7 + row);
                            if (y >= mapTop && y < mapBottom && x >= mapLeft && x < mapRight)
                                setPackedPixel(pixels, rowBytes, mapTop, mapLeft, x, y, 15);
                        }
                }
            }
            // PICT compresses each relative text position against the origin
            // of the preceding text operation, not the post-DrawText pen.
            // Keep textH/textV at that origin for DHText/DVText/DHDVText.
            offset += prefix + 1UL + length;
            drewPixels = true; continue;
        }
        if (opcode == 0x98) {
            if (!drawPackedMonochromePictureBits(picture, size, offset, frame, targetRect))
                return false;
            drewPixels = true; continue;
        }
        s_unsupportedPictureOpcode = opcode;
        s_unsupportedPictureOffset = offset - 1;
        return false;
    }
    return false;
}

static bool drawPictureContents(uint8_t** pictureHandle, const uint8_t* targetRect)
{
    uint32_t size = resourceHandleSize(pictureHandle);
    if (!pictureHandle || !*pictureHandle || !targetRect || size < 12) return false;
    const uint8_t* picture = *pictureHandle;
    const uint8_t* frame = picture + 2;
    if (picture[10] == 0x11 && picture[11] == 0x01)
        return drawVersionOnePicture(picture, size, frame, targetRect);
    uint32_t offset = 10;
    bool drewPixels = false;
    while (offset + 2 <= size) {
        uint16_t opcode = read16(picture + offset); offset += 2;
        if (opcode == 0x00ff) return drewPixels;
        if (opcode == 0x0000 || opcode == 0x001e) continue;
        if (opcode == 0x0011) { if (offset + 2 > size) return false; offset += 2; continue; }
        if (opcode == 0x0c00) { if (offset + 24 > size) return false; offset += 24; continue; }
        if (opcode == 0x0001) {
            if (offset + 2 > size) return false;
            uint16_t bytes = read16(picture + offset);
            if (bytes < 2 || offset + bytes > size) return false;
            offset += bytes; continue;
        }
        if (opcode == 0x000a) { if (offset + 8 > size) return false; offset += 8; continue; }
        if (opcode == 0x00a1) {
            if (offset + 4 > size) return false;
            uint16_t bytes = read16(picture + offset + 2);
            if (offset + 4UL + bytes > size) return false;
            offset += 4UL + bytes; if (offset & 1) ++offset; continue;
        }
        if (opcode == 0x0090 || opcode == 0x0098) {
            if (!drawIndexedPictureBits(picture, size, offset, frame, targetRect,
                                        opcode == 0x0098)) return false;
            drewPixels = true; continue;
        }
        if (opcode == 0x009a) {
            if (!drawDirectPictureBits(picture, size, offset, frame, targetRect)) return false;
            drewPixels = true; continue;
        }
        s_unsupportedPictureOpcode = opcode;
        s_unsupportedPictureOffset = offset - 2;
        return false;                        // retain the loud stop for every unseen opcode
    }
    return false;
}

static bool currentPortPixels(uint8_t*& pixels, uint16_t& rowBytes,
                              int16_t& top, int16_t& left, int16_t& bottom, int16_t& right)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** mapHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* map = mapHandle ? *mapHandle : 0;
    if (!map || read16(map + 32) != 4) return false;
    pixels = (uint8_t*)read32(map);
    rowBytes = (uint16_t)(read16(map + 4) & 0x3fff);
    top = (int16_t)read16(map + 6); left = (int16_t)read16(map + 8);
    bottom = (int16_t)read16(map + 10); right = (int16_t)read16(map + 12);
    return pixels && rowBytes;
}

static bool drawPicture(uint8_t** pictureHandle, const uint8_t* targetRect)
{
    if (!drawPictureContents(pictureHandle, targetRect)) return false;
    return true;
}

static bool frameRect(const uint8_t* rectangle)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!port || !rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    int16_t penHeight = (int16_t)read16(port + 52);
    int16_t penWidth = (int16_t)read16(port + 54);
    if (top >= bottom || left >= right || penHeight <= 0 || penWidth <= 0
        || read16(port + 56) != 0) return false;
    for (int16_t y = top; y < bottom; ++y) {
        if (y < mapTop || y >= mapBottom) continue;
        uint8_t* row = pixels + multiplyUnsigned16((uint16_t)(y - mapTop), rowBytes);
        for (int16_t x = left; x < right; ++x) {
            if (x < mapLeft || x >= mapRight) continue;
            if (y >= top + penHeight && y < bottom - penHeight
                && x >= left + penWidth && x < right - penWidth) continue;
            uint16_t column = (uint16_t)(x - mapLeft);
            uint8_t& byte = row[column >> 1];
            if (column & 1) byte = (uint8_t)(byte | 0x0f);
            else byte = (uint8_t)(byte | 0xf0);
        }
    }
    return true;
}

static bool eraseRect(const uint8_t* rectangle)
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    if (top >= bottom || left >= right) return false;
    if (top < mapTop) top = mapTop;
    if (left < mapLeft) left = mapLeft;
    if (bottom > mapBottom) bottom = mapBottom;
    if (right > mapRight) right = mapRight;
    if (top >= bottom || left >= right) return true;
    uint16_t firstColumn = (uint16_t)(left - mapLeft);
    uint16_t lastColumn = (uint16_t)(right - mapLeft);
    for (int16_t y = top; y < bottom; ++y) {
        uint8_t* row = pixels + multiplyUnsigned16((uint16_t)(y - mapTop), rowBytes);
        uint16_t firstByte = (uint16_t)(firstColumn >> 1);
        uint16_t lastByte = (uint16_t)((lastColumn + 1) >> 1);
        if (firstColumn & 1) {
            row[firstByte] &= 0xf0;
            ++firstByte;
        }
        bool keepLowNibble = lastColumn & 1;
        if (keepLowNibble && lastByte > firstByte) --lastByte;
        if (lastByte > firstByte) blockClear(row + firstByte, lastByte - firstByte);
        if (keepLowNibble) row[lastByte] &= 0x0f;
    }
    return true;
}

static bool paintRect(const uint8_t* rectangle)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!port || !rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    if (top >= bottom || left >= right) return false;
    uint8_t** clipHandle = (uint8_t**)read32(port + 28);
    uint8_t* clip = clipHandle ? *clipHandle : 0;
    if (top < mapTop) top = mapTop;
    if (left < mapLeft) left = mapLeft;
    if (bottom > mapBottom) bottom = mapBottom;
    if (right > mapRight) right = mapRight;
    if (clip && read16(clip) >= 10) {
        if (top < (int16_t)read16(clip + 2)) top = (int16_t)read16(clip + 2);
        if (left < (int16_t)read16(clip + 4)) left = (int16_t)read16(clip + 4);
        if (bottom > (int16_t)read16(clip + 6)) bottom = (int16_t)read16(clip + 6);
        if (right > (int16_t)read16(clip + 8)) right = (int16_t)read16(clip + 8);
    }
    // VETTE passes its adjacent PICT-ID table (6398, 5383, ...) to PaintRect
    // once after drawing the course description.  The resulting rectangle is
    // wholly outside the port; QuickDraw clips it to an empty operation before
    // the pen transfer mode matters.  Keep that behavior without silently
    // accepting an unimplemented on-screen mode.
    return top >= bottom || left >= right;
}

static bool getVolumeInfo(uint8_t* parameterBlock)
{
    // Vette answered its one caller with the creation date of its own shipped
    // HFS volume.  That value is specific to Vette's media; until this game's
    // callers and the fields they read are known, PBGetVInfo is a loud stop.
    (void)parameterBlock;
    return false;
}

static int16_t quickDrawRandom()
{
    if (!s_qdThePort) return 0;
    uint8_t* randSeed = s_qdThePort - 126;
    uint32_t seed = read32(randSeed);
    uint16_t low = (uint16_t)seed;
    uint16_t high = (uint16_t)(seed >> 16);
    uint32_t lowProduct = multiplyUnsigned16(16807, low);
    uint32_t folded = multiplyUnsigned16(16807, high) + (lowProduct >> 16);
    seed = ((folded & 0x7fffUL) << 16)
         + ((folded >> 15) & 0xffffUL)
         + (lowProduct & 0xffffUL);
    write32(randSeed, seed);
    uint16_t result = (uint16_t)seed;
    return result == 0x8000 ? 0 : (int16_t)result;
}

static bool invertRect(const uint8_t* rectangle)
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    if (top >= bottom || left >= right) return false;
    if (top < mapTop) top = mapTop;
    if (left < mapLeft) left = mapLeft;
    if (bottom > mapBottom) bottom = mapBottom;
    if (right > mapRight) right = mapRight;
    if (top >= bottom || left >= right) return true;

    uint16_t firstColumn = (uint16_t)(left - mapLeft);
    uint16_t lastColumn = (uint16_t)(right - mapLeft);
    for (int16_t y = top; y < bottom; ++y) {
        uint8_t* row = pixels + multiplyUnsigned16((uint16_t)(y - mapTop), rowBytes);
        uint16_t column = firstColumn;
        if (column & 1) {
            row[column >> 1] ^= 0x0f;
            ++column;
        }
        while (column + 1 < lastColumn) {
            row[column >> 1] ^= 0xff;
            column = (uint16_t)(column + 2);
        }
        if (column < lastColumn) row[column >> 1] ^= 0xf0;
    }
    return true;
}

static bool bitmapPixels(const uint8_t* bitmap, uint8_t*& pixels, uint16_t& rowBytes,
                         int16_t& top, int16_t& left, int16_t& bottom, int16_t& right)
{
    if (!bitmap) return false;
    uint8_t* map = 0;
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && bitmap == s_gworlds[i].port + 2) map = s_gworlds[i].pixMap;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (s_windows[i].used && bitmap == s_windows[i].window + 2)
            map = s_windowManagerPixMap;
    if (bitmap == s_windowManagerPort + 2) map = s_windowManagerPixMap;
    if (!map || read16(map + 32) != 4) return false;
    pixels = (uint8_t*)read32(map);
    rowBytes = (uint16_t)(read16(map + 4) & 0x3fff);
    top = (int16_t)read16(map + 6); left = (int16_t)read16(map + 8);
    bottom = (int16_t)read16(map + 10); right = (int16_t)read16(map + 12);
    return pixels && rowBytes;
}

static bool bitmapIsScreen(const uint8_t* bitmap)
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t top, left, bottom, right;
    return bitmapPixels(bitmap, pixels, rowBytes, top, left, bottom, right)
        && pixels == s_colorScreen;
}

static const uint8_t* bitmapColorTable(const uint8_t* bitmap)
{
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && bitmap == s_gworlds[i].port + 2)
            return s_gworlds[i].colorTable;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (s_windows[i].used && bitmap == s_windows[i].window + 2)
            return s_windowManagerColors;
    if (bitmap == s_windowManagerPort + 2) return s_windowManagerColors;
    return 0;
}

static bool currentPortIsScreen()
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t top, left, bottom, right;
    return currentPortPixels(pixels, rowBytes, top, left, bottom, right)
        && pixels == s_colorScreen;
}

static bool drawQuickDrawText(const uint8_t* text, uint16_t length,
                              int16_t& top, int16_t& left,
                              int16_t& bottom, int16_t& right)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!port || (!text && length)
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    uint16_t mode = read16(port + 72);
    if (mode != 0 && mode != 1) return false; // srcCopy and srcOr are sufficient here

    int16_t penV = (int16_t)read16(port + 48);
    int16_t penH = (int16_t)read16(port + 50);
    top = (int16_t)(penV - 7);
    left = penH;
    bottom = penV;
    right = (int16_t)(penH + length * 6);

    uint8_t** clipHandle = (uint8_t**)read32(port + 28);
    uint8_t* clip = clipHandle ? *clipHandle : 0;
    int16_t clipTop = mapTop, clipLeft = mapLeft, clipBottom = mapBottom, clipRight = mapRight;
    if (clip && read16(clip) >= 10) {
        clipTop = (int16_t)read16(clip + 2);
        clipLeft = (int16_t)read16(clip + 4);
        clipBottom = (int16_t)read16(clip + 6);
        clipRight = (int16_t)read16(clip + 8);
    }
    for (uint16_t i = 0; i < length; ++i) {
        for (uint16_t row = 0; row < 7; ++row) {
            uint8_t bits = pictureGlyphRow(text[i], row);
            for (uint16_t column = 0; column < 5; ++column) {
                if (!(bits & (16u >> column))) continue;
                int16_t x = (int16_t)(penH + i * 6 + column);
                int16_t y = (int16_t)(penV - 7 + row);
                if (y < mapTop || y >= mapBottom || x < mapLeft || x >= mapRight
                    || y < clipTop || y >= clipBottom || x < clipLeft || x >= clipRight) continue;
                setPackedPixel(pixels, rowBytes, mapTop, mapLeft, x, y, 15);
            }
        }
    }
    write16(port + 50, (uint16_t)right);      // QuickDraw advances the pen location
    return true;
}

static __attribute__((noinline)) void shiftPackedCopyRowsC(
    const uint8_t* source, uint8_t* destination,
    uint16_t bytesPerRow, uint16_t height,
    uint16_t sourceModulo, uint16_t destinationModulo)
{
    while (height--) {
        uint16_t bytes = bytesPerRow;
        while (bytes--) {
            *destination++ = (uint8_t)((source[0] << 4) | (source[1] >> 4));
            ++source;
        }
        source += sourceModulo;
        destination += destinationModulo;
    }
}

static __attribute__((noinline)) void packedLogicRowsC(
    const uint8_t* source, uint8_t* destination,
    uint16_t bytesPerRow, uint16_t height,
    uint16_t sourceModulo, uint16_t destinationModulo,
    bool shifted, bool sourceBic)
{
    while (height--) {
        uint16_t bytes = bytesPerRow;
        if (shifted) {
            uint16_t longs = (uint16_t)(bytes >> 2);
            uint16_t tail = (uint16_t)(bytes & 3);
            if (sourceBic) {
                while (longs--) {
                    uint32_t value = (*(const uint32_t*)source << 4)
                        | (uint32_t)(source[4] >> 4);
                    *(uint32_t*)destination &= ~value;
                    source += 4;
                    destination += 4;
                }
                while (tail--) {
                    uint8_t value = (uint8_t)((source[0] << 4) | (source[1] >> 4));
                    *destination++ &= (uint8_t)~value;
                    ++source;
                }
            } else {
                while (longs--) {
                    uint32_t value = (*(const uint32_t*)source << 4)
                        | (uint32_t)(source[4] >> 4);
                    *(uint32_t*)destination |= value;
                    source += 4;
                    destination += 4;
                }
                while (tail--) {
                    *destination++ |= (uint8_t)((source[0] << 4) | (source[1] >> 4));
                    ++source;
                }
            }
        } else if (sourceBic) {
            while (bytes--) *destination++ &= (uint8_t)~*source++;
        } else {
            while (bytes--) *destination++ |= *source++;
        }
        source += sourceModulo;
        destination += destinationModulo;
    }
}

static bool copyBits(const uint8_t* sourceBitmap, const uint8_t* destinationBitmap,
                     const uint8_t* sourceRect, const uint8_t* destinationRect,
                     uint16_t mode, const uint8_t* maskRegion)
{
    if (!sourceRect || !destinationRect
        || (mode != 0 && mode != 1 && mode != 3 && mode != 6)
        || maskRegion) return false;
    uint8_t *sourcePixels, *destinationPixels;
    uint16_t sourceRowBytes, destinationRowBytes;
    int16_t sourceTop, sourceLeft, sourceBottom, sourceRight;
    int16_t destinationTop, destinationLeft, destinationBottom, destinationRight;
    if (!bitmapPixels(sourceBitmap, sourcePixels, sourceRowBytes,
                      sourceTop, sourceLeft, sourceBottom, sourceRight)
        || !bitmapPixels(destinationBitmap, destinationPixels, destinationRowBytes,
                         destinationTop, destinationLeft, destinationBottom, destinationRight))
        return false;
    int16_t fromTop = (int16_t)read16(sourceRect);
    int16_t fromLeft = (int16_t)read16(sourceRect + 2);
    int16_t fromBottom = (int16_t)read16(sourceRect + 4);
    int16_t fromRight = (int16_t)read16(sourceRect + 6);
    int16_t toTop = (int16_t)read16(destinationRect);
    int16_t toLeft = (int16_t)read16(destinationRect + 2);
    int16_t toBottom = (int16_t)read16(destinationRect + 4);
    int16_t toRight = (int16_t)read16(destinationRect + 6);
    if (fromBottom <= fromTop || fromRight <= fromLeft
        || toBottom <= toTop || toRight <= toLeft) return false;
    struct ColorMapCache {
        const uint8_t* source;
        const uint8_t* destination;
        uint32_t sourceSeed;
        uint32_t destinationSeed;
        uint8_t color[16];
        uint8_t packed[256];
        bool mapped;
    };
    static ColorMapCache colorCaches[4] = {};
    static uint16_t nextColorCache = 0;
    static uint8_t identityColorMap[16];
    static uint8_t identityPackedColorMap[256];
    static bool identityReady = false;
    if (!identityReady) {
        for (uint16_t i = 0; i < 16; ++i) identityColorMap[i] = (uint8_t)i;
        for (uint16_t i = 0; i < 256; ++i) identityPackedColorMap[i] = (uint8_t)i;
        identityReady = true;
    }
    const uint8_t* colorMap = identityColorMap;
    const uint8_t* packedColorMap = identityPackedColorMap;
    bool colorsMapped = false;
    const uint8_t* sourceColors = bitmapColorTable(sourceBitmap);
    const uint8_t* destinationColors = bitmapColorTable(destinationBitmap);
    // Color QuickDraw treats matching ctSeed values as the same color
    // environment even when the PixMaps own distinct table copies.  The
    // selector's initial screen copy depends on that identity; its later car
    // update sees a changed device seed and therefore needs translation.
    if (mode == 0 && sourceColors && destinationColors
        && read32(sourceColors) != read32(destinationColors)) {
        uint32_t sourceSeed = read32(sourceColors);
        uint32_t destinationSeed = read32(destinationColors);
        ColorMapCache* cache = 0;
        for (uint16_t i = 0; i < sizeof(colorCaches) / sizeof(colorCaches[0]); ++i) {
            if (colorCaches[i].source == sourceColors
                && colorCaches[i].destination == destinationColors
                && colorCaches[i].sourceSeed == sourceSeed
                && colorCaches[i].destinationSeed == destinationSeed) {
                cache = &colorCaches[i];
                break;
            }
        }
        if (!cache) {
            cache = &colorCaches[nextColorCache++];
            if (nextColorCache == sizeof(colorCaches) / sizeof(colorCaches[0]))
                nextColorCache = 0;
            cache->source = sourceColors;
            cache->destination = destinationColors;
            cache->sourceSeed = sourceSeed;
            cache->destinationSeed = destinationSeed;
            cache->mapped = false;
            for (uint8_t sourceIndex = 0; sourceIndex < 16; ++sourceIndex) {
                const uint8_t* sourceColor
                    = sourceColors + 8 + (uint16_t)sourceIndex * 8;
                uint16_t sr = read16(sourceColor + 2), sg = read16(sourceColor + 4);
                uint16_t sb = read16(sourceColor + 6);
                uint32_t bestDistance = 0xffffffffUL;
                uint8_t bestIndex = 0;
                for (uint8_t destinationIndex = 0; destinationIndex < 16;
                     ++destinationIndex) {
                    const uint8_t* destinationColor
                        = destinationColors + 8 + (uint16_t)destinationIndex * 8;
                    uint16_t dr = read16(destinationColor + 2);
                    uint16_t dg = read16(destinationColor + 4);
                    uint16_t db = read16(destinationColor + 6);
                    uint16_t distance = colorDistance4(sr, sg, sb, dr, dg, db);
                    if (distance < bestDistance) {
                        bestDistance = distance;
                        bestIndex = destinationIndex;
                    }
                }
                cache->color[sourceIndex] = bestIndex;
                if (bestIndex != sourceIndex) cache->mapped = true;
            }
            for (uint16_t i = 0; i < 256; ++i)
                cache->packed[i] = (uint8_t)((cache->color[i >> 4] << 4)
                                            | cache->color[i & 0x0f]);
#ifdef AITD_PROBE
            ++g_probeCopyMapMisses;
#endif
        } else {
#ifdef AITD_PROBE
            ++g_probeCopyMapHits;
#endif
        }
        colorMap = cache->color;
        packedColorMap = cache->packed;
        colorsMapped = cache->mapped;
#ifdef AITD_PROBE
    } else {
        ++g_probeCopyMapIdentity;
#endif
    }
    uint16_t width = (uint16_t)(toRight - toLeft);
    uint16_t height = (uint16_t)(toBottom - toTop);
    int16_t clipTop = destinationTop, clipLeft = destinationLeft;
    int16_t clipBottom = destinationBottom, clipRight = destinationRight;
    uint8_t* currentPort = (uint8_t*)read32(s_qdThePort);
    if (currentPort && destinationBitmap == currentPort + 2) {
        uint8_t** clipHandle = (uint8_t**)read32(currentPort + 28);
        uint8_t* clip = clipHandle ? *clipHandle : 0;
        if (clip && read16(clip) >= 10) {
            clipTop = (int16_t)read16(clip + 2); clipLeft = (int16_t)read16(clip + 4);
            clipBottom = (int16_t)read16(clip + 6); clipRight = (int16_t)read16(clip + 8);
        }
    }
    bool unscaled = fromRight - fromLeft == toRight - toLeft
                 && fromBottom - fromTop == toBottom - toTop;
    // All intro masks and sprites remain nibble-aligned even when their
    // destination rectangles cross a GWorld or clip boundary.  Clip first,
    // then operate on packed bytes.  The old fast paths required the *whole*
    // rectangle to be in bounds, so the tram's srcOr/srcBic pair fell back to
    // a pixel-at-a-time loop as soon as it touched the bottom or left edge.
    // That made the other concurrently scheduled actors lose real time.
    int16_t packedTop = toTop;
    int16_t packedLeft = toLeft;
    int16_t packedBottom = toBottom;
    int16_t packedRight = toRight;
    if (packedTop < destinationTop) packedTop = destinationTop;
    if (packedTop < clipTop) packedTop = clipTop;
    if (packedTop < toTop + sourceTop - fromTop)
        packedTop = (int16_t)(toTop + sourceTop - fromTop);
    if (packedLeft < destinationLeft) packedLeft = destinationLeft;
    if (packedLeft < clipLeft) packedLeft = clipLeft;
    if (packedLeft < toLeft + sourceLeft - fromLeft)
        packedLeft = (int16_t)(toLeft + sourceLeft - fromLeft);
    if (packedBottom > destinationBottom) packedBottom = destinationBottom;
    if (packedBottom > clipBottom) packedBottom = clipBottom;
    if (packedBottom > toTop + sourceBottom - fromTop)
        packedBottom = (int16_t)(toTop + sourceBottom - fromTop);
    if (packedRight > destinationRight) packedRight = destinationRight;
    if (packedRight > clipRight) packedRight = clipRight;
    if (packedRight > toLeft + sourceRight - fromLeft)
        packedRight = (int16_t)(toLeft + sourceRight - fromLeft);
    int16_t packedSourceTop = (int16_t)(fromTop + packedTop - toTop);
    int16_t packedSourceLeft = (int16_t)(fromLeft + packedLeft - toLeft);
    bool packedClippedPath = unscaled && packedTop < packedBottom
        && packedLeft < packedRight
        && ((packedSourceLeft - sourceLeft) & 1) == 0
        && ((packedLeft - destinationLeft) & 1) == 0
        && ((packedRight - packedLeft) & 1) == 0;
    if (packedClippedPath) {
        uint16_t copyBytes = (uint16_t)(packedRight - packedLeft) >> 1;
        uint16_t copyHeight = (uint16_t)(packedBottom - packedTop);
        if (mode == 0
            && copyBytes == sourceRowBytes && copyBytes == destinationRowBytes
            && packedSourceLeft == sourceLeft && packedLeft == destinationLeft) {
            const uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(packedSourceTop - sourceTop), sourceRowBytes);
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(packedTop - destinationTop),
                                     destinationRowBytes);
            uint32_t contiguousBytes = multiplyUnsigned16(copyBytes, copyHeight);
            if (!colorsMapped) blockMove(source, destination, contiguousBytes);
            else mappedCopyRows(source, destination, packedColorMap,
                                contiguousBytes, 1, 0, 0);
            return true;
        }
        if (mode == 0 && colorsMapped && sourcePixels != destinationPixels) {
            const uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(packedSourceTop - sourceTop), sourceRowBytes)
                + (uint16_t)(packedSourceLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(packedTop - destinationTop),
                                     destinationRowBytes)
                + (uint16_t)(packedLeft - destinationLeft) / 2;
            mappedCopyRows(source, destination, packedColorMap, copyBytes, copyHeight,
                           sourceRowBytes - copyBytes, destinationRowBytes - copyBytes);
            return true;
        }
        int16_t firstY = 0, lastY = (int16_t)copyHeight, stepY = 1;
        if (sourcePixels == destinationPixels && packedTop > packedSourceTop) {
            firstY = (int16_t)(copyHeight - 1); lastY = -1; stepY = -1;
        }
        for (int16_t y = firstY; y != lastY; y = (int16_t)(y + stepY)) {
            uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(packedSourceTop + y - sourceTop),
                                     sourceRowBytes)
                + (uint16_t)(packedSourceLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(packedTop + y - destinationTop),
                                     destinationRowBytes)
                + (uint16_t)(packedLeft - destinationLeft) / 2;
            if (mode == 0) {
                if (!colorsMapped) blockMove(source, destination, copyBytes);
                else for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = packedColorMap[source[x]];
            } else if (sourcePixels == destinationPixels && destination > source
                       && destination < source + copyBytes) {
                for (uint16_t x = copyBytes; x; --x) {
                    uint16_t i = (uint16_t)(x - 1);
                    if (mode == 1)
                        destination[i] = (uint8_t)(destination[i] | source[i]);
                    else if (mode == 3)
                        destination[i] = (uint8_t)(destination[i]
                            & (uint8_t)~source[i]);
                    else
                        destination[i] = (uint8_t)(destination[i] ^ source[i] ^ 0xff);
                }
            } else if (mode == 1) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] | source[x]);
            } else if (mode == 3) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] & (uint8_t)~source[x]);
            } else {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] ^ source[x] ^ 0xff);
            }
        }
        return true;
    }
    if (unscaled && sourcePixels == destinationPixels && (mode == 1 || mode == 3)
        && packedTop < packedBottom && packedLeft < packedRight) {
        // The garage plate transition composites a 290x84 source at an odd
        // horizontal destination inside the same PixMap.  Its one-nibble
        // shift used to miss the aligned path and perform bounds checks plus
        // read/modify/write for every pixel.  Assemble each destination byte
        // directly, retaining memmove order when the moving image overlaps
        // its source later in the animation.
        uint16_t pixelCount = (uint16_t)(packedRight - packedLeft);
        uint16_t sourceFirstColumn = (uint16_t)(packedSourceLeft - sourceLeft);
        uint16_t destinationFirstColumn = (uint16_t)(packedLeft - destinationLeft);
        bool rowsOverlap = packedTop < packedSourceTop + (packedBottom - packedTop)
            && packedBottom > packedSourceTop;
        if (!rowsOverlap) {
            uint16_t leadingPixel = (uint16_t)(destinationFirstColumn & 1);
            uint16_t interiorPixels = (uint16_t)(pixelCount - leadingPixel);
            uint16_t interiorBytes = (uint16_t)(interiorPixels >> 1);
            uint16_t trailingPixel = (uint16_t)(interiorPixels & 1);
            uint16_t interiorSourceColumn = (uint16_t)(sourceFirstColumn + leadingPixel);
            uint16_t interiorDestinationColumn
                = (uint16_t)(destinationFirstColumn + leadingPixel);

            for (int16_t y = packedTop; y < packedBottom; ++y) {
                int16_t sourceY = (int16_t)(packedSourceTop + y - packedTop);
                const uint8_t* sourceRow = sourcePixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes);
                uint8_t* destinationRow = destinationPixels
                    + multiplyUnsigned16((uint16_t)(y - destinationTop),
                                         destinationRowBytes);
                if (leadingPixel) {
                    uint8_t sourceByte = sourceRow[sourceFirstColumn >> 1];
                    uint8_t value = sourceFirstColumn & 1
                        ? (uint8_t)(sourceByte & 0x0f) : (uint8_t)(sourceByte >> 4);
                    uint8_t& destinationByte
                        = destinationRow[destinationFirstColumn >> 1];
                    if (mode == 1) destinationByte |= value;
                    else destinationByte &= (uint8_t)~value;
                }
                if (trailingPixel) {
                    uint16_t sourceColumn
                        = (uint16_t)(sourceFirstColumn + pixelCount - 1);
                    uint16_t destinationColumn
                        = (uint16_t)(destinationFirstColumn + pixelCount - 1);
                    uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                    uint8_t value = sourceColumn & 1
                        ? (uint8_t)(sourceByte & 0x0f) : (uint8_t)(sourceByte >> 4);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    value <<= 4;
                    if (mode == 1) destinationByte |= value;
                    else destinationByte &= (uint8_t)~value;
                }
            }
            if (interiorBytes) {
                const uint8_t* source = sourcePixels
                    + multiplyUnsigned16((uint16_t)(packedSourceTop - sourceTop),
                                         sourceRowBytes)
                    + (interiorSourceColumn >> 1);
                uint8_t* destination = destinationPixels
                    + multiplyUnsigned16((uint16_t)(packedTop - destinationTop),
                                         destinationRowBytes)
                    + (interiorDestinationColumn >> 1);
                packedLogicRowsC(source, destination, interiorBytes,
                    (uint16_t)(packedBottom - packedTop),
                    (uint16_t)(sourceRowBytes - interiorBytes),
                    (uint16_t)(destinationRowBytes - interiorBytes),
                    (interiorSourceColumn & 1) != 0, mode == 3);
            }
            return true;
        }
        int16_t firstY = packedTop, lastY = packedBottom, stepY = 1;
        if (packedTop > packedSourceTop) {
            firstY = (int16_t)(packedBottom - 1);
            lastY = (int16_t)(packedTop - 1);
            stepY = -1;
        }
        for (int16_t destinationY = firstY; destinationY != lastY;
             destinationY = (int16_t)(destinationY + stepY)) {
            int16_t sourceY = (int16_t)(packedSourceTop + destinationY - packedTop);
            uint8_t* sourceRow = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(destinationY - destinationTop),
                                     destinationRowBytes);
            int16_t firstByte = (int16_t)(destinationFirstColumn >> 1);
            int16_t lastByte = (int16_t)((destinationFirstColumn + pixelCount - 1) >> 1);
            int16_t stepByte = 1;
            uint16_t sourceLastColumn = (uint16_t)(sourceFirstColumn + pixelCount);
            uint16_t destinationLastColumn = (uint16_t)(destinationFirstColumn + pixelCount);
            if (sourceRow == destinationRow
                && destinationFirstColumn < sourceLastColumn
                && destinationLastColumn > sourceFirstColumn
                && destinationFirstColumn > sourceFirstColumn) {
                int16_t swap = firstByte; firstByte = lastByte; lastByte = swap;
                stepByte = -1;
            }
            int16_t finalByte = (int16_t)(lastByte + stepByte);
            for (int16_t destinationByteIndex = firstByte;
                 destinationByteIndex != finalByte;
                 destinationByteIndex = (int16_t)(destinationByteIndex + stepByte)) {
                uint16_t destinationColumn = (uint16_t)(destinationByteIndex << 1);
                uint8_t sourceValue = 0;
                if (destinationColumn >= destinationFirstColumn
                    && destinationColumn < destinationLastColumn) {
                    uint16_t sourceColumn = (uint16_t)(sourceFirstColumn
                        + destinationColumn - destinationFirstColumn);
                    uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                    sourceValue = sourceColumn & 1
                        ? (uint8_t)((sourceByte & 0x0f) << 4)
                        : (uint8_t)(sourceByte & 0xf0);
                }
                ++destinationColumn;
                if (destinationColumn >= destinationFirstColumn
                    && destinationColumn < destinationLastColumn) {
                    uint16_t sourceColumn = (uint16_t)(sourceFirstColumn
                        + destinationColumn - destinationFirstColumn);
                    uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                    sourceValue |= sourceColumn & 1
                        ? (uint8_t)(sourceByte & 0x0f)
                        : (uint8_t)(sourceByte >> 4);
                }
                uint8_t& destinationByte = destinationRow[destinationByteIndex];
                if (mode == 1) destinationByte = (uint8_t)(destinationByte | sourceValue);
                else destinationByte = (uint8_t)(destinationByte & (uint8_t)~sourceValue);
            }
        }
        return true;
    }
    if (unscaled && mode == 0 && !colorsMapped && sourcePixels != destinationPixels
        && packedTop < packedBottom && packedLeft < packedRight) {
        // Identity-colour srcCopy with opposite nibble alignment is the garage
        // animation hot path (for example 44x44 pixels from x=50 to x=311).
        // It has no scaling, palette operation or overlap, so retain only the
        // two edge read/modify/writes and assemble the packed interior bytes
        // directly. The general cross-GWorld loop below re-tested mode,
        // mapping and nibble parity for every pair of pixels.
        uint16_t pixelCount = (uint16_t)(packedRight - packedLeft);
        uint16_t sourceFirstColumn = (uint16_t)(packedSourceLeft - sourceLeft);
        uint16_t destinationFirstColumn = (uint16_t)(packedLeft - destinationLeft);
        uint16_t leadingPixel = (uint16_t)(destinationFirstColumn & 1);
        uint16_t interiorPixels = (uint16_t)(pixelCount - leadingPixel);
        uint16_t interiorBytes = (uint16_t)(interiorPixels >> 1);
        uint16_t trailingPixel = (uint16_t)(interiorPixels & 1);
        uint16_t interiorSourceColumn = (uint16_t)(sourceFirstColumn + leadingPixel);
        uint16_t interiorDestinationColumn
            = (uint16_t)(destinationFirstColumn + leadingPixel);

        // Preserve only the destination nibbles outside the rectangle. Do
        // both edges in one row walk, then process the packed interior as one
        // rectangular byte operation instead of redoing row-address multiplies
        // and mode/parity decisions for every byte.
        for (int16_t y = packedTop; y < packedBottom; ++y) {
            int16_t sourceY = (int16_t)(fromTop + y - toTop);
            const uint8_t* sourceRow = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - destinationTop), destinationRowBytes);
            if (leadingPixel) {
                uint8_t sourceByte = sourceRow[sourceFirstColumn >> 1];
                uint8_t value = sourceFirstColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                      : (uint8_t)(sourceByte >> 4);
                uint8_t& destinationByte
                    = destinationRow[destinationFirstColumn >> 1];
                destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
            }
            if (trailingPixel) {
                uint16_t sourceColumn = (uint16_t)(sourceFirstColumn + pixelCount - 1);
                uint16_t destinationColumn
                    = (uint16_t)(destinationFirstColumn + pixelCount - 1);
                uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                uint8_t value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                uint8_t& destinationByte
                    = destinationRow[destinationColumn >> 1];
                destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
            }
        }
        if (interiorBytes) {
            const uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(packedSourceTop - sourceTop), sourceRowBytes)
                + (interiorSourceColumn >> 1);
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(packedTop - destinationTop),
                                     destinationRowBytes)
                + (interiorDestinationColumn >> 1);
            uint16_t height = (uint16_t)(packedBottom - packedTop);
            if (interiorSourceColumn & 1) {
                shiftPackedCopyRowsC(source, destination, interiorBytes, height,
                    (uint16_t)(sourceRowBytes - interiorBytes),
                    (uint16_t)(destinationRowBytes - interiorBytes));
            } else {
                for (uint16_t row = 0; row < height; ++row) {
                    blockMove(source, destination, interiorBytes);
                    source += sourceRowBytes;
                    destination += destinationRowBytes;
                }
            }
        }
        return true;
    }
    if (unscaled && sourcePixels != destinationPixels
        && packedTop < packedBottom && packedLeft < packedRight) {
        // Cross-GWorld sprite/logo transfers frequently have an odd source or
        // destination nibble.  They are still one-to-one copies: assemble two
        // source pixels per destination byte instead of redoing clipping,
        // bounds tests, multiplies and read/modify/write for every pixel.
        for (int16_t y = packedTop; y < packedBottom; ++y) {
            int16_t sourceY = (int16_t)(fromTop + y - toTop);
            const uint8_t* sourceRow = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - destinationTop), destinationRowBytes);
            int16_t x = packedLeft;
            uint16_t destinationColumn = (uint16_t)(x - destinationLeft);
            uint16_t sourceColumn = (uint16_t)(fromLeft + x - toLeft - sourceLeft);
            if (destinationColumn & 1) {
                uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                uint8_t value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                if (mode == 0) value = colorMap[value];
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 1) value = (uint8_t)((destinationByte & 0x0f) | value);
                else if (mode == 3)
                    value = (uint8_t)((destinationByte & 0x0f) & (uint8_t)~value);
                else if (mode == 6)
                    value = (uint8_t)((destinationByte & 0x0f) ^ value ^ 0x0f);
                destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                ++x; ++sourceColumn; ++destinationColumn;
            }
            for (; x + 1 < packedRight; x += 2, sourceColumn += 2,
                                              destinationColumn += 2) {
                uint8_t value;
                if ((sourceColumn & 1) == 0) value = sourceRow[sourceColumn >> 1];
                else value = (uint8_t)((sourceRow[sourceColumn >> 1] << 4)
                    | (sourceRow[(sourceColumn >> 1) + 1] >> 4));
                if (mode == 0) value = packedColorMap[value];
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 0) destinationByte = value;
                else if (mode == 1) destinationByte = (uint8_t)(destinationByte | value);
                else if (mode == 3)
                    destinationByte = (uint8_t)(destinationByte & (uint8_t)~value);
                else destinationByte = (uint8_t)(destinationByte ^ value ^ 0xff);
            }
            if (x < packedRight) {
                uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                uint8_t value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                if (mode == 0) value = colorMap[value];
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 1) value = (uint8_t)((destinationByte >> 4) | value);
                else if (mode == 3)
                    value = (uint8_t)((destinationByte >> 4) & (uint8_t)~value);
                else if (mode == 6)
                    value = (uint8_t)((destinationByte >> 4) ^ value ^ 0x0f);
                destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
            }
        }
        return true;
    }
    bool packedFastPath = unscaled && mode == 0 && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toTop >= clipTop && toBottom <= clipBottom
        && toLeft >= clipLeft && toRight <= clipRight;
    bool packedVerticalClipPath = unscaled && mode == 0
        && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toLeft >= clipLeft && toRight <= clipRight
        && toTop < clipBottom && toBottom > clipTop;
    bool rectanglesOverlap = sourcePixels == destinationPixels
        && fromLeft < toRight && fromRight > toLeft
        && fromTop < toBottom && fromBottom > toTop;
    bool packedBooleanPath = unscaled && (mode == 1 || mode == 3 || mode == 6)
        && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toTop >= clipTop && toBottom <= clipBottom
        && toLeft >= clipLeft && toRight <= clipRight
        && !rectanglesOverlap;

    // The intro scrolls large, aligned rectangles inside a GWorld.  For srcCopy
    // that is a memmove, not a scale operation: retain overlap correctness while
    // moving packed 4-bpp rows directly.  This is the normal fast QuickDraw path
    // and keeps the original animation from losing time inside the compatibility
    // layer.
    if (packedFastPath || packedVerticalClipPath) {
        uint16_t copyBytes = width >> 1;
        int16_t copyTop = toTop < clipTop ? clipTop : toTop;
        int16_t copyBottom = toBottom > clipBottom ? clipBottom : toBottom;
        uint16_t copyHeight = (uint16_t)(copyBottom - copyTop);
        int16_t sourceCopyTop = (int16_t)(fromTop + copyTop - toTop);
        int16_t first = 0, last = (int16_t)copyHeight, step = 1;
        if (sourcePixels == destinationPixels && copyTop > sourceCopyTop) {
            first = (int16_t)(copyHeight - 1); last = -1; step = -1;
        }
        for (int16_t y = first; y != last; y = (int16_t)(y + step)) {
            uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceCopyTop + y - sourceTop), sourceRowBytes)
                + (uint16_t)(fromLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(copyTop + y - destinationTop), destinationRowBytes)
                + (uint16_t)(toLeft - destinationLeft) / 2;
            if (!colorsMapped) blockMove(source, destination, copyBytes);
            else for (uint16_t x = 0; x < copyBytes; ++x)
                destination[x] = packedColorMap[source[x]];
        }
        return true;
    }
    if (packedBooleanPath) {
        uint16_t copyBytes = width >> 1;
        for (uint16_t y = 0; y < height; ++y) {
            const uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(fromTop + y - sourceTop), sourceRowBytes)
                + (uint16_t)(fromLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(toTop + y - destinationTop), destinationRowBytes)
                + (uint16_t)(toLeft - destinationLeft) / 2;
            if (mode == 1) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] | source[x]);
            } else if (mode == 3) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] & (uint8_t)~source[x]);
            } else {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] ^ source[x] ^ 0xff);
            }
        }
        return true;
    }

    // An unscaled transfer has a one-to-one source/destination mapping and
    // does not need the byte-per-pixel expansion buffer below.  Walk in the
    // memmove direction when both BitMaps share storage so odd-aligned and
    // clipped self-copies retain the original source pixels.
    if (unscaled) {
        int16_t visibleTop = toTop;
        int16_t visibleLeft = toLeft;
        int16_t visibleBottom = toBottom;
        int16_t visibleRight = toRight;
        if (visibleTop < destinationTop) visibleTop = destinationTop;
        if (visibleTop < clipTop) visibleTop = clipTop;
        if (visibleLeft < destinationLeft) visibleLeft = destinationLeft;
        if (visibleLeft < clipLeft) visibleLeft = clipLeft;
        if (visibleBottom > destinationBottom) visibleBottom = destinationBottom;
        if (visibleBottom > clipBottom) visibleBottom = clipBottom;
        if (visibleRight > destinationRight) visibleRight = destinationRight;
        if (visibleRight > clipRight) visibleRight = clipRight;
        if (visibleTop >= visibleBottom || visibleLeft >= visibleRight) return true;

        int16_t firstY = visibleTop, lastY = visibleBottom, stepY = 1;
        int16_t firstX = visibleLeft, lastX = visibleRight, stepX = 1;
        if (sourcePixels == destinationPixels
            && toTop - destinationTop > fromTop - sourceTop) {
            firstY = (int16_t)(visibleBottom - 1);
            lastY = (int16_t)(visibleTop - 1);
            stepY = -1;
        }
        if (sourcePixels == destinationPixels
            && toLeft - destinationLeft > fromLeft - sourceLeft) {
            firstX = (int16_t)(visibleRight - 1);
            lastX = (int16_t)(visibleLeft - 1);
            stepX = -1;
        }
        for (int16_t destinationY = firstY; destinationY != lastY;
             destinationY = (int16_t)(destinationY + stepY)) {
            int16_t sourceY = (int16_t)(fromTop + destinationY - toTop);
            const uint8_t* sourceRow = sourceY >= sourceTop && sourceY < sourceBottom
                ? sourcePixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes)
                : 0;
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(destinationY - destinationTop),
                                     destinationRowBytes);
            for (int16_t destinationX = firstX; destinationX != lastX;
                 destinationX = (int16_t)(destinationX + stepX)) {
                int16_t sourceX = (int16_t)(fromLeft + destinationX - toLeft);
                uint8_t value = 0;
                if (sourceRow && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                    value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                             : (uint8_t)(sourceByte >> 4);
                }
                if (mode == 0) value = colorMap[value];
                uint16_t destinationColumn = (uint16_t)(destinationX - destinationLeft);
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode != 0) {
                    uint8_t destinationValue = destinationColumn & 1
                        ? (uint8_t)(destinationByte & 0x0f)
                        : (uint8_t)(destinationByte >> 4);
                    if (mode == 1) value = (uint8_t)(destinationValue | value);
                    else if (mode == 3)
                        value = (uint8_t)(destinationValue & (uint8_t)(~value & 0x0f));
                    else value = (uint8_t)(destinationValue ^ value ^ 0x0f);
                }
                if (destinationColumn & 1)
                    destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
            }
        }
        return true;
    }

    uint32_t temporaryBytes = multiplyUnsigned16(width, height);
    uint8_t* temporary = (uint8_t*)AllocMem(temporaryBytes, 0);
    if (!temporary) return false;
    for (uint16_t y = 0; y < height; ++y) {
        uint8_t* temporaryRow = temporary + multiplyUnsigned16(y, width);
        int16_t sourceY = unscaled ? (int16_t)(fromTop + y)
            : (int16_t)(fromTop + multiplyDivide(
                y, (uint16_t)(fromBottom - fromTop), height));
        const uint8_t* row = sourceY >= sourceTop && sourceY < sourceBottom
            ? sourcePixels + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes)
            : 0;
        if (unscaled) {
            for (uint16_t x = 0; x < width; ++x) {
                int16_t sourceX = (int16_t)(fromLeft + x);
                uint8_t value = 0;
                if (row && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t byte = row[column >> 1];
                    value = column & 1 ? (uint8_t)(byte & 0x0f) : (uint8_t)(byte >> 4);
                }
                temporaryRow[x] = value;
            }
        } else {
            for (uint16_t x = 0; x < width; ++x) {
                int16_t sourceX = (int16_t)(fromLeft + multiplyDivide(
                    x, (uint16_t)(fromRight - fromLeft), width));
                uint8_t value = 0;
                if (row && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t byte = row[column >> 1];
                    value = column & 1 ? (uint8_t)(byte & 0x0f) : (uint8_t)(byte >> 4);
                }
                temporaryRow[x] = value;
            }
        }
    }
    for (uint16_t y = 0; y < height; ++y) {
        const uint8_t* temporaryRow = temporary + multiplyUnsigned16(y, width);
        int16_t destinationY = (int16_t)(toTop + y);
        if (destinationY < destinationTop || destinationY >= destinationBottom
            || destinationY < clipTop || destinationY >= clipBottom) continue;
        uint8_t* row = destinationPixels
            + multiplyUnsigned16((uint16_t)(destinationY - destinationTop), destinationRowBytes);
        for (uint16_t x = 0; x < width; ++x) {
            int16_t destinationX = (int16_t)(toLeft + x);
            if (destinationX < destinationLeft || destinationX >= destinationRight
                || destinationX < clipLeft || destinationX >= clipRight) continue;
            uint8_t value = temporaryRow[x];
            if (mode == 0) value = colorMap[value];
            uint16_t column = (uint16_t)(destinationX - destinationLeft);
            uint8_t& byte = row[column >> 1];
            if (mode != 0) {
                uint8_t destinationValue = column & 1 ? (uint8_t)(byte & 0x0f)
                                                       : (uint8_t)(byte >> 4);
                if (mode == 1)               // srcOr: destination OR source
                    value = (uint8_t)(destinationValue | value);
                else if (mode == 3)          // srcBic: destination AND NOT source
                    value = (uint8_t)(destinationValue & (uint8_t)(~value & 0x0f));
                else                         // notSrcXor: destination XOR NOT source
                    value = (uint8_t)(destinationValue ^ value ^ 0x0f);
            }
            if (column & 1) byte = (uint8_t)((byte & 0xf0) | value);
            else byte = (uint8_t)((byte & 0x0f) | (value << 4));
        }
    }
    FreeMem(temporary, temporaryBytes);
    return true;
}

static bool clipRect(const uint8_t* rectangle)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** clipHandle = port ? (uint8_t**)read32(port + 28) : 0;
    uint8_t* clip = clipHandle ? *clipHandle : 0;
    if (!rectangle || !clip) return false;
    write16(clip, 10);
    writeRect(clip + 2, (int16_t)read16(rectangle), (int16_t)read16(rectangle + 2),
              (int16_t)read16(rectangle + 4), (int16_t)read16(rectangle + 6));
    return true;
}

static void paletteToColorTable(uint8_t** paletteHandle, uint8_t* colorTable)
{
    if (!paletteHandle || !*paletteHandle || !colorTable) return;
    const uint8_t* palette = *paletteHandle;
    uint16_t count = read16(palette);
    if (count > 16) count = 16;
    int16_t resourceID = -32768;
    for (uint32_t i = 0; i < s_resourceForks.resourceCount(); ++i) {
        ResourceForks::Item item;
        if (s_resourceHandles[i] == paletteHandle && s_resourceForks.item(i, item)
            && item.type == 0x706c7474UL) {
            resourceID = item.id;
            break;
        }
    }

    // Inside Macintosh specifies protected white/black and priority-ordered
    // tolerant allocation, but deliberately keeps device ColorSpec values and
    // the exact arbitration private.  These physical-slot layouts were
    // captured from Vette's unmodified pltt resources on System 6.0.8.  They
    // reproduce Color Manager state centrally; they are not scene or car
    // recognition and all RGB values still come from the shipped resources.
    static const uint8_t map130[16] = {
        0, 2, 15, 3, 14, 13, 7, 8, 9, 10, 11, 12, 6, 5, 4, 1
    };
    static const uint8_t map140[16] = {
        0, 2, 4, 5, 15, 14, 7, 8, 13, 10, 11, 12, 3, 9, 6, 1
    };
    static const uint8_t map150[16] = {
        0, 2, 15, 4, 14, 13, 6, 8, 9, 10, 11, 12, 7, 5, 3, 1
    };
    static const uint8_t map131[16] = {
        0, 9, 3, 2, 15, 14, 13, 12, 4, 11, 6, 10, 7, 8, 5, 1
    };
    const uint8_t* allocation = resourceID == 130 ? map130
        : resourceID == 140 ? map140 : resourceID == 150 ? map150
        : resourceID == 131 ? map131 : 0;

    if (allocation && count == 16) {
        for (uint16_t physical = 0; physical < 16; ++physical) {
            const uint8_t* color = palette + 16 + allocation[physical] * 16;
            uint8_t* spec = colorTable + 8 + physical * 8;
            write16(spec, physical == 0 || physical == 15 ? 0x0800 : 0x2000);
            write16(spec + 2, read16(color));
            write16(spec + 4, read16(color + 2));
            write16(spec + 6, read16(color + 4));
        }
    } else {
        uint16_t nextAvailable = 1;
        for (uint16_t i = 0; i < count; ++i) {
            const uint8_t* color = palette + 16 + i * 16;
            uint16_t red = read16(color), green = read16(color + 2), blue = read16(color + 4);
            uint16_t physical;
            if (red == 0xffff && green == 0xffff && blue == 0xffff) physical = 0;
            else if (!red && !green && !blue) physical = 15;
            else if (nextAvailable < 15) physical = nextAvailable++;
            else continue;
            uint8_t* spec = colorTable + 8 + physical * 8;
            write16(spec, physical == 0 || physical == 15 ? 0x0800 : 0x2000);
            write16(spec + 2, red);
            write16(spec + 4, green);
            write16(spec + 6, blue);
        }
    }
    write16(colorTable + 4, 0x8000);       // device table: array index is pixel value
    write32(colorTable, s_colorSeed++);
}

static GWorldSlot* gWorldForPort(uint8_t* port)
{
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && s_gworlds[i].port == port) return &s_gworlds[i];
    return 0;
}

static void activatePalette(uint8_t* window)
{
    WindowSlot* slot = windowSlot(window);
    if (slot && slot->palette && *slot->palette) {
        s_activePalette = slot->palette;
        paletteToColorTable(slot->palette, s_windowManagerColors);
        return;
    }
    GWorldSlot* world = gWorldForPort(window);
    if (world && world->palette && *world->palette) {
        // Palette Manager treats tolerant colors on an offscreen GWorld as
        // courteous.  It does not replace the GWorld's RGB table.  Instead it
        // synchronizes the table seed with the active device environment so
        // CopyBits preserves the renderer's already-realized pixel indexes.
        // This is measured System 6 behavior; rematching the stale RGB table
        // was what forced the former Porsche/F40 and grid-pen workarounds.
        write32(world->colorTable, read32(s_windowManagerColors));
    }
}

static void initGWorldColorTable(uint8_t* table)
{
    // With a null CTable and GDevice, NewGWorld copies the current device
    // color table.  It must remain a snapshot: Vette changes the window palette
    // after creating the rotating-car world, then CopyBits maps between them.
    blockMove(s_windowManagerColors, table, sizeof(s_windowManagerColors));
}

static uint8_t* newGWorld(const uint8_t* bounds, uint16_t depth)
{
    GWorldSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (!s_gworlds[i].used) { slot = &s_gworlds[i]; break; }
    if (!slot || !bounds) return 0;
    for (uint16_t i = 0; i < sizeof(slot->port); ++i) slot->port[i] = 0;
    for (uint16_t i = 0; i < sizeof(slot->pixMap); ++i) slot->pixMap[i] = 0;
    int16_t top = (int16_t)read16(bounds);
    int16_t left = (int16_t)read16(bounds + 2);
    int16_t bottom = (int16_t)read16(bounds + 4);
    int16_t right = (int16_t)read16(bounds + 6);
    uint16_t pixelDepth = depth ? depth : 4;
    uint16_t width = (uint16_t)(right - left);
    uint16_t height = (uint16_t)(bottom - top);
    // Color VETTE! predates System 7.1 and directly relies on the original
    // NewGWorld stride: round to a 32-bit boundary, then reserve one more
    // 32-bit slop word.  Omitting that word makes its 3D renderer advance 260
    // bytes through a PixMap advertised as 256 bytes wide, producing the
    // characteristic repeating/cyclic corruption seen on newer Mac systems.
    uint16_t rowBytes = (uint16_t)((((uint32_t)width * pixelDepth + 31) >> 5 << 2) + 4);
    uint32_t pixelBytes = (uint32_t)rowBytes * height;
    slot->pixels = (uint8_t*)AllocMem(pixelBytes, MEMF_CLEAR);
    if (!slot->pixels) return 0;
    s_gworldAllocationBytes[slot - s_gworlds] = pixelBytes;
    slot->used = true;
    slot->locked = false;
    slot->purgeable = true;
    slot->palette = 0;
    slot->pixMapMaster = slot->pixMap;
    slot->colorTableMaster = slot->colorTable;
    initGWorldColorTable(slot->colorTable);
    write32(slot->pixMap, (uint32_t)slot->pixels);
    write16(slot->pixMap + 4, (uint16_t)(0x8000 | rowBytes));
    writeRect(slot->pixMap + 6, top, left, bottom, right);
    write32(slot->pixMap + 22, 72UL << 16);
    write32(slot->pixMap + 26, 72UL << 16);
    write16(slot->pixMap + 30, 0);
    write16(slot->pixMap + 32, pixelDepth);
    write16(slot->pixMap + 34, 1);
    write16(slot->pixMap + 36, pixelDepth);
    write32(slot->pixMap + 42, (uint32_t)&slot->colorTableMaster);
    initRegion(slot->visRegion, slot->visRegionMaster, top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster, top, left, bottom, right);
    initColorPort(slot->port, &slot->visRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);
    write32(slot->port + 2, (uint32_t)&slot->pixMapMaster);
    return slot->port;
}

static GWorldSlot* gWorldForPixMap(uint8_t** pixMap)
{
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && &s_gworlds[i].pixMapMaster == pixMap) return &s_gworlds[i];
    return 0;
}

static void initMenus()
{
    s_menuManager.initialized = true;
    s_menuManager.colorTable = 0;
    s_menuManager.highlightedID = 0;
    s_menuManager.count = 0;

    // InitMenus optionally adopts the menu-color table resource.  Its ID is not
    // prescribed, so mirror the Resource Manager search and take the first 'mctb'.
    for (uint32_t i = 0; i < s_resourceForks.resourceCount(); ++i) {
        ResourceForks::Item item;
        if (!s_resourceForks.item(i, item)) break;
        if (item.type == 0x6d637462UL) {      // 'mctb'
            s_menuManager.colorTable = loadResource(i,item);
            break;
        }
    }

    // The initialized menu list is empty, so the menu bar is its white background.
    for (uint32_t i = 0; i < (512 / 2) * 20; ++i) s_colorScreen[i] = 0;
}

static bool disableMenuItem(uint8_t** menu, uint16_t item)
{
    // Intro updates the future game-menu state before Load has obtained MENU
    // 222, so the first three calls intentionally carry a nil MenuHandle.
    if (!menu) return true;
    if (!*menu || item >= 32 || handleSize(menu) < 14) return false;
    uint32_t enabled = read32(*menu + 10);
    enabled &= ~(1UL << item);
    write32(*menu + 10, enabled);
    return true;
}

static bool enableMenuItem(uint8_t** menu, uint16_t item)
{
    if (!menu) return true;
    if (!*menu || item >= 32 || handleSize(menu) < 14) return false;
    write32(*menu + 10, read32(*menu + 10) | (1UL << item));
    return true;
}

static bool checkMenuItem(uint8_t** handle, uint16_t requestedItem, bool checked)
{
    if (!handle || !*handle) return false;
    uint8_t* menu = *handle;
    uint32_t size = handleSize(handle);
    if (size < 16 || size < (uint32_t)16 + menu[14]) return false;
    // Vette uses item zero while Tour Mode has no previous destination to
    // uncheck.  Like the classic manager, accept it without touching a mark.
    if (!requestedItem) return true;
    uint32_t offset = 15 + menu[14];
    uint16_t item = 1;
    while (offset < size && menu[offset]) {
        uint8_t length = menu[offset];
        if (offset + 5UL + length > size) return false;
        if (item == requestedItem) {
            menu[offset + 3 + length] = checked ? 0x12 : 0; // classic checkMark
            return true;
        }
        offset += 5UL + length;
        ++item;
    }
    return false;
}

static uint32_t menuKey(uint8_t requestedKey)
{
    if (!s_menuManager.initialized) return 0;
    requestedKey = asciiUpper(requestedKey);
    for (uint16_t i = 0; i < s_menuManager.count; ++i) {
        const MenuManagerState::Entry& entry = s_menuManager.entries[i];
        // Inside Macintosh requires MenuKey to scan the complete current menu
        // list, including hierarchical submenus inserted with beforeID -1.
        // inMenuBar is a drawing/ordering property, not a key-equivalent gate.
        if (!entry.handle || !*entry.handle) continue;
        uint8_t* menu = *entry.handle;
        uint32_t size = handleSize(entry.handle);
        if (size < 16 || size < (uint32_t)16 + menu[14]) continue;
        uint32_t enabled = read32(menu + 10);
        if (!(enabled & 1)) continue;          // disabled menu title
        uint32_t offset = 15UL + menu[14];
        uint16_t item = 1;
        while (offset < size && menu[offset]) {
            uint8_t length = menu[offset];
            if (offset + 5UL + length > size) break;
            uint8_t key = menu[offset + 2 + length];
            if (item < 32 && (enabled & (1UL << item))
                && key && asciiUpper(key) == requestedKey)
                return ((uint32_t)read16(menu) << 16) | item;
            offset += 5UL + length;
            ++item;
        }
    }
    return 0;
}

static uint8_t** newMenu(int16_t id, const uint8_t* title)
{
    if (!title) return 0;
    uint16_t titleLength = title[0];
    uint8_t** handle = newHandle((uint32_t)16 + titleLength, true);
    if (!handle || !*handle) return 0;
    uint8_t* menu = *handle;
    write16(menu, (uint16_t)id);
    write32(menu + 10, 0xffffffffUL);         // title and future items enabled
    menu[14] = (uint8_t)titleLength;
    for (uint16_t i = 0; i < titleLength; ++i) menu[15 + i] = title[i + 1];
    menu[15 + titleLength] = 0;              // end of item list
    return handle;
}

static bool appendMenu(uint8_t** handle, const uint8_t* specification)
{
    if (!handle || !*handle || !specification) return false;
    uint32_t size = handleSize(handle);
    uint8_t* menu = *handle;
    if (size < 16 || size < (uint32_t)16 + menu[14]) return false;
    uint32_t end = 15 + menu[14];
    uint16_t itemNumber = 0;
    while (end < size && menu[end]) {
        uint8_t length = menu[end];
        if (end + 5UL + length >= size) return false;
        end += 5UL + length;
        ++itemNumber;
    }
    if (end >= size) return false;

    uint16_t source = 1;
    while (source <= specification[0]) {
        uint16_t start = source;
        while (source <= specification[0] && specification[source] != ';') ++source;
        uint16_t finish = source++;
        bool enabled = true;
        if (start < finish && specification[start] == '(') { enabled = false; ++start; }
        uint8_t label[255]; uint16_t labelLength = 0;
        uint8_t icon = 0, key = 0, mark = 0, style = 0;
        for (uint16_t i = start; i < finish && labelLength < 255; ++i) {
            uint8_t c = specification[i];
            if ((c == '^' || c == '/' || c == '!' || c == '<') && i + 1 < finish) {
                uint8_t value = specification[++i];
                if (c == '^') icon = value;
                else if (c == '/') key = value;
                else if (c == '!') mark = value;
                else style = value;
            } else label[labelLength++] = c;
        }
        uint32_t oldEnd = end;
        if (setHandleSize(handle, size + 5UL + labelLength) != 0) return false;
        size += 5UL + labelLength;
        menu = *handle;
        menu[oldEnd] = (uint8_t)labelLength;
        for (uint16_t i = 0; i < labelLength; ++i) menu[oldEnd + 1 + i] = label[i];
        menu[oldEnd + 1 + labelLength] = icon;
        menu[oldEnd + 2 + labelLength] = key;
        menu[oldEnd + 3 + labelLength] = mark;
        menu[oldEnd + 4 + labelLength] = style;
        end = oldEnd + 5UL + labelLength;
        menu[end] = 0;
        ++itemNumber;
        if (!enabled && itemNumber < 32) {
            uint32_t flags = read32(menu + 10);
            write32(menu + 10, flags & ~(1UL << itemNumber));
        }
    }
    return true;
}

static bool addResourceMenu(uint8_t** menu, uint32_t type)
{
    if (!menu || !*menu || handleSize(menu) < 16) return false;

    // AddResMenu appends the names of resources of the requested type.  The
    // shipped application and data forks contain no DRVR resources, so the
    // measured desk-accessory-menu call is an empty append.  Keep a loud stop
    // if a different archive does contain a named match: encoding those names
    // as menu items is observable state and must not be silently omitted.
    for (uint32_t i = 0; i < s_resourceForks.resourceCount(); ++i) {
        ResourceForks::Item item;
        if (!s_resourceForks.item(i, item)) return false;
        if (item.type == type && item.nameLength) return false;
    }
    return true;
}

static bool insertMenu(uint8_t** handle, int16_t beforeID)
{
    if (!s_menuManager.initialized || !handle || !*handle || handleSize(handle) < 16
        || s_menuManager.count >= sizeof(s_menuManager.entries) / sizeof(s_menuManager.entries[0]))
        return false;

    int16_t id = (int16_t)read16(*handle);
    for (uint16_t i = 0; i < s_menuManager.count; ++i)
        if (s_menuManager.entries[i].handle == handle
            || (s_menuManager.entries[i].handle && *s_menuManager.entries[i].handle
                && (int16_t)read16(*s_menuManager.entries[i].handle) == id)) return false;

    bool inMenuBar = beforeID != -1;
    uint16_t position = s_menuManager.count;
    if (inMenuBar && beforeID != 0) {
        for (uint16_t i = 0; i < s_menuManager.count; ++i) {
            uint8_t** existing = s_menuManager.entries[i].handle;
            if (s_menuManager.entries[i].inMenuBar && existing && *existing
                && (int16_t)read16(*existing) == beforeID) {
                position = i;
                break;
            }
        }
        if (position == s_menuManager.count) return false;
    }
    for (uint16_t i = s_menuManager.count; i > position; --i)
        s_menuManager.entries[i] = s_menuManager.entries[i - 1];
    s_menuManager.entries[position].handle = handle;
    s_menuManager.entries[position].inMenuBar = inMenuBar;
    ++s_menuManager.count;
    return true;
}

static uint8_t** getMenu(int16_t id)
{
    uint8_t** resource = getResource(0x4d454e55UL, id); // 'MENU'
    uint32_t size = resourceHandleSize(resource);
    if (!resource || !*resource || size < 16 || (int16_t)read16(*resource) != id) return 0;

    // Validate the packed MenuInfo title and item records before exposing them
    // as mutable manager state.  Each item is a Pascal string followed by its
    // icon, key equivalent, mark, and style bytes; a zero length terminates it.
    const uint8_t* source = *resource;
    uint32_t offset = 15UL + source[14];
    if (offset >= size) return 0;
    while (source[offset]) {
        uint32_t next = offset + 5UL + source[offset];
        if (next >= size) return 0;
        offset = next;
    }

    uint8_t** menu = newHandle(size, false);
    if (!menu || !*menu) return 0;
    for (uint32_t i = 0; i < size; ++i) (*menu)[i] = source[i];
    return menu;
}

static void initTextEdit()
{
    // TEInit creates an empty private scrap handle and resets its manager globals.
    s_textEditScrapMaster = s_textEditScrap;
    s_textEdit.initialized = true;
    s_textEdit.scrap = &s_textEditScrapMaster;
}

static void initDialogs(uint8_t* resumeProcedure)
{
    s_dialogManager.initialized = true;
    s_dialogManager.resumeProcedure = resumeProcedure;
}

static void initCursor()
{
    s_cursor.initialized = true;
    s_cursor.visible = true;
    s_cursor.image = s_qdThePort - 108;       // qd.arrow
    publishMouseCursor();
}

static bool isKnownToolTrap(uint16_t trap)
{
    // Entry availability and service implementation are separate: a known
    // reference entry can still stop loudly when its service is first called.
    if (trap == 0xab03) return true;           // Jackson: Color QuickDraw is present
    for (uint16_t i = 0; i < sizeof(s_trapNames) / sizeof(s_trapNames[0]); ++i)
        if (s_trapNames[i].word == trap) return true;
    return false;
}

static uint16_t trapIndex(uint16_t trap)
{
    return (trap & 0x0800) ? (0x0800 | (trap & 0x03ff)) : (trap & 0x00ff);
}

static uint8_t* getTrapAddress(uint16_t trap)
{
    uint16_t index = trapIndex(trap);
    return s_trapAddresses[index] ? s_trapAddresses[index] : s_trapBuiltins[index];
}

static uint8_t* getToolTrapAddress(uint16_t trap)
{
    trap = 0xa800 | (trap & 0x03ff);
    if (!isKnownToolTrap(trap)) trap = 0xa89f;
    return getTrapAddress(trap);
}

static void setTrapAddress(uint16_t trap, uint8_t* address)
{
    s_trapAddresses[trapIndex(trap)] = address;
}

static uint32_t routePatchedTrap(uint16_t trap, uint32_t* regs,
                                 uint8_t* frame, uint8_t* userStack)
{
    uint16_t index = trapIndex(trap);
    uint8_t* address = s_trapAddresses[index];
    if (!address || address == s_trapBuiltins[index]) return 0;
    uint32_t returnPC = read32(frame + 2) + 2;
    write32(frame + 2, (uint32_t)address - 2);
    if (trap & 0x0800) {
        if (trap == 0xa9f4) g_macExitState = 2;
        if (trap & 0x0400) return 1; // auto-pop: caller's return is already on USP
        write32(userStack - 4, returnPC);
        return (uint32_t)-3; // signed USP adjustment -4, plus dispatch sentinel
    }
    // System 7.5.5 dispatcher $DDA0-$DDE2: preserve D1/D2/A1/A2,
    // and A0 unless trap bit 8 requests its result. D1.W carries the trap;
    // D2.W its low nine bits; A2 points just beyond the original opcode.
    uint8_t* saved = userStack - 32;
    write32(saved, (uint32_t)aitd_os_patch_return);
    write32(saved + 4, regs[8]); write32(saved + 8, regs[9]);
    write32(saved + 12, regs[1]); write32(saved + 16, regs[2]);
    write32(saved + 20, regs[10]); write32(saved + 24, returnPC);
    write32(saved + 28, trap);
    regs[1] = (regs[1] & 0xffff0000UL) | trap;
    regs[2] = (regs[2] & 0xffff0000UL) | (trap & 0x01ff);
    regs[10] = returnPC;
    return (uint32_t)-31;
}

static void requestExitAfterTrap(uint8_t* frame)
{
    write32(frame + 2, (uint32_t)aitd_user_exit_request - 2);
    g_macVBLCallbackEntry = 0;
    g_macVBLCallbackTask = 0;
    g_macVBLCallbackA5 = 0;
    g_macExitState = 1;
}

static bool exitChordPressed()
{
    return AmigaHardware::isLeftMouseButtonPressed()
        && (aitdInputModifiers() & 0x1000) != 0;
}

static int16_t memoryResult(int16_t error)
{
    s_memoryError=error;g_heapError=error;
    write16(s_portLowMemory+100,(uint16_t)error);
    g_heapFree=s_applicationZone.freeBytes();g_heapLargest=s_applicationZone.largestBlock();
    g_heapSystemFree=s_systemZone.freeBytes();
    refreshCodeViews();
    return error;
}
static uint8_t** newHandle(uint32_t size,bool clear)
{
    MacHeap::Handle handle=s_currentZone->newHandle(size,clear);
    memoryResult(s_currentZone->error());return handle;
}
static uint32_t handleSize(uint8_t** handle)
{
    MacHeap* zone=handleZone(handle);
    if(!zone) { memoryResult(MacHeap::nilHandleErr);return 0; }
    uint32_t bytes=zone->handleSize(handle);memoryResult(zone->error());return bytes;
}
static int16_t setHandleSize(uint8_t** handle,uint32_t bytes)
{
    MacHeap* zone=handleZone(handle);
    return memoryResult(zone ? zone->setHandleSize(handle,bytes) : MacHeap::nilHandleErr);
}
static int16_t pointerAndHandle(const uint8_t* source,uint8_t** handle,uint32_t size)
{
    MacHeap* zone=handleZone(handle);
    if(!zone || (!source && size))return memoryResult(MacHeap::nilHandleErr);
    uint32_t old=zone->handleSize(handle);
    if(zone->error())return memoryResult(zone->error());
    if(size>0x7fffffffUL-old)return memoryResult(MacHeap::memFullErr);
    bool ownSource=(uint32_t)source>=(uint32_t)*handle
        && (uint32_t)source-(uint32_t)*handle<old;
    uint32_t offset=ownSource ? source-*handle : 0;
    if(zone->setHandleSize(handle,old+size))return memoryResult(zone->error());
    if(ownSource)source=*handle+offset;
    for(uint32_t i=0;i<size;++i)(*handle)[old+i]=source[i];
    return memoryResult(0);
}
static int16_t installVBLTask(uint8_t* task)
{
    if (!task) return -50;                   // paramErr
    for (uint16_t i = 0; i < s_vblTaskCount; ++i)
        if (s_vblTasks[i] == task) return -94; // vTypErr: already installed
    if (s_vblTaskCount == sizeof(s_vblTasks) / sizeof(s_vblTasks[0]))
        return -94;

    bool firstTask = s_vblTaskCount == 0;
    write16(task + 4, 1);                    // vType
    write32(task, 0);
    if (s_vblTaskCount) write32(s_vblTasks[s_vblTaskCount - 1], (uint32_t)task);
    s_vblTasks[s_vblTaskCount++] = task;
    if (firstTask) {
        s_vblPassIndex = 0;
        s_vblPassLimit = 0;
        s_vblPendingTicks = 0;
        s_vblPassActive = false;
        s_vblLastTick = g_macTicks;
        s_vblDispatchTick = g_macTicks;
    }
    return 0;
}

static int16_t removeVBLTask(uint8_t* task)
{
    if (!task) return -50;                   // paramErr
    if (read16(task + 4) != 1) return -2;   // vTypErr

    uint16_t index = 0;
    while (index < s_vblTaskCount && s_vblTasks[index] != task) ++index;
    if (index == s_vblTaskCount) return -1; // qErr: not in the queue

    if (g_macVBLCallbackTask == (uint32_t)task && g_macVBLCallbackEntry) {
        g_macVBLCallbackEntry = 0;
        g_macVBLCallbackTask = 0;
        g_macVBLCallbackA5 = 0;
    }
    for (uint16_t i = index + 1; i < s_vblTaskCount; ++i)
        s_vblTasks[i - 1] = s_vblTasks[i];
    --s_vblTaskCount;
    s_vblTasks[s_vblTaskCount] = 0;
    for (uint16_t i = 0; i < s_vblTaskCount; ++i)
        write32(s_vblTasks[i], i + 1 < s_vblTaskCount ? (uint32_t)s_vblTasks[i + 1] : 0);
    write32(task, 0);

    if (s_vblPassActive) {
        if (s_vblPassIndex > index) --s_vblPassIndex;
        if (s_vblPassLimit > index) --s_vblPassLimit;
        if (s_vblPassIndex >= s_vblPassLimit) s_vblPassActive = false;
    }
    if (!s_vblTaskCount) {
        s_vblPassIndex = 0;
        s_vblPassLimit = 0;
        s_vblPendingTicks = 0;
        s_vblPassActive = false;
        s_vblLastTick = g_macTicks;
        s_vblDispatchTick = g_macTicks;
    }
    return 0;
}

static void scheduleVBLTask()
{
    uint32_t now = g_macTicks;
    uint32_t elapsed = now - s_vblLastTick;
    if (elapsed) {
        s_vblLastTick = now;
        uint32_t room = 0xffffffffu - s_vblPendingTicks;
        s_vblPendingTicks += elapsed < room ? elapsed : room;
    }

    if (!s_vblTaskCount) {
        s_vblPendingTicks = 0;
        s_vblPassActive = false;
        if (g_macTicksAddress) write32((uint8_t*)g_macTicksAddress, g_macTicks);
        return;
    }
    if (g_macVBLCallbackEntry || g_macVBLCallbackActive) return;

    for (;;) {
        if (!s_vblPassActive) {
            if (!s_vblPendingTicks) return;
            --s_vblPendingTicks;
            ++s_vblDispatchTick;

            // A real Macintosh ages every queue entry once per vertical-retrace
            // pass, then calls each entry which became due in queue order.  PAL
            // fields sometimes advance g_macTicks by two, so preserve those as
            // two distinct passes: a one-tick task may rearm and run in both.
            s_vblPassIndex = 0;
            s_vblPassLimit = s_vblTaskCount;
            for (uint16_t i = 0; i < s_vblPassLimit; ++i) {
                uint8_t* task = s_vblTasks[i];
                int16_t count = (int16_t)read16(task + 10);
                if (count > 0) write16(task + 10, (uint16_t)(count - 1));
            }
            s_vblPassActive = true;
        }

        while (s_vblPassIndex < s_vblPassLimit) {
            uint8_t* task = s_vblTasks[s_vblPassIndex++];
            if ((int16_t)read16(task + 10) > 0) continue;

            // MacEntry.s substitutes a user-mode trampoline for the normal
            // trap return PC.  Only one callback is dispatched at this safe
            // point; the next trap resumes this same virtual VBL pass.
            write16(task + 10, 0);
            g_macVBLCallbackTask = (uint32_t)task;
            g_macVBLCallbackA5 = (uint32_t)s_currentA5;
            g_macVBLCallbackEntry = read32(task + 6);
            // Direct Ticks reads were redirected to this A5 shadow.  A queued
            // callback must observe the tick of its virtual VBL pass, not the
            // later wall-clock tick at which a safe point finally drains it.
            if (g_macTicksAddress)
                write32((uint8_t*)g_macTicksAddress, s_vblDispatchTick);
            return;
        }

        s_vblPassActive = false;
    }
}

// Called in user mode after a Macintosh VBL callback returns.  A renderer can
// spend several virtual ticks between safe trap boundaries, so one boundary
// may have multiple queue passes waiting.  Keep selecting the next due task;
// MacEntry.s preserves the interrupted application registers until the queue
// is caught up, just as the Macintosh VBL interrupt dispatcher does.
extern "C" void aitdVBLCallbackComplete()
{
    scheduleVBLTask();
    if (!g_macVBLCallbackEntry && g_macTicksAddress)
        write32((uint8_t*)g_macTicksAddress, g_macTicks);
}

static void presentMacRuntime()
{
    if (!s_loudStopScreen) return;
    // Vette chose a crop and pointer visibility per original WIND identity.
    // Alone in the Dark has not been mapped yet: present the default viewport.
    uint16_t cropLeft = 80, cropTop = 0;
    bool mouseAllowed = false;
    if (!s_screenDirty && s_loudStopScreen->matchesViewport(cropLeft, cropTop)
        && s_loudStopScreen->matchesMouseVisibility(mouseAllowed)) return;
    bool presented = s_loudStopScreen->presentMacFrame(
        s_colorScreen, s_windowManagerColors, s_dirtyRects, s_dirtyRectCount,
        cropLeft, cropTop, mouseAllowed);
    if (presented) {
        s_screenDirty = false;
        s_pixelsDirty = false;
        s_dirtyRectCount = 0;
    }
}

static void serviceMacRuntime()
{
    scheduleVBLTask();
    presentMacRuntime();
}

struct KeyTranslation {
    uint8_t virtualKey;
    uint8_t character;
    uint8_t shiftedCharacter;
};

static void setKeyMapState(uint8_t virtualKey, bool down)
{
    if (virtualKey > 0x7f) return;
    uint8_t byteOffset = (uint8_t)(virtualKey >> 3);
    // GetKeys numbers the low bit of each byte first (Vette's key scanner
    // confirmed it by shifting each byte right and treating carry as the next
    // ascending virtual-key code).
    uint8_t mask = (uint8_t)(1u << (virtualKey & 7));
    uint8_t* keyMap = s_portLowMemory + kLowKeyMap;
    if (down) keyMap[byteOffset] |= mask;
    else keyMap[byteOffset] &= (uint8_t)~mask;
}

static bool translateAmigaKey(uint8_t raw, KeyTranslation& key)
{
    // Amiga raw keys are physical positions, just like Macintosh ADB virtual
    // keys, but the two matrices use different numbers.  Keep the translation
    // explicit: passing raw values through happened to work for a few letters
    // and silently reported the wrong key for everything else.
    static const uint8_t alphaRaw[] = {
        0x20, 0x35, 0x33, 0x22, 0x12, 0x23, 0x24, 0x25, 0x17, 0x26, 0x27, 0x28,
        0x37, 0x36, 0x18, 0x19, 0x10, 0x13, 0x21, 0x14, 0x16, 0x34, 0x11, 0x32,
        0x15, 0x31
    };
    static const uint8_t alphaMac[] = {
        0x00, 0x0b, 0x08, 0x02, 0x0e, 0x03, 0x05, 0x04, 0x22, 0x26, 0x28, 0x25,
        0x2e, 0x2d, 0x1f, 0x23, 0x0c, 0x0f, 0x01, 0x11, 0x20, 0x09, 0x0d, 0x07,
        0x10, 0x06
    };
    for (uint16_t i = 0; i < 26; ++i) {
        if (raw == alphaRaw[i]) {
            key.virtualKey = alphaMac[i];
            key.character = (uint8_t)('a' + i);
            key.shiftedCharacter = (uint8_t)('A' + i);
            return true;
        }
    }

    static const uint8_t digitMac[] = {
        0x1d, 0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1a, 0x1c, 0x19
    };
    static const uint8_t digitShift[] = {
        ')', '!', '@', '#', '$', '%', '^', '&', '*', '('
    };
    if (raw >= 0x01 && raw <= 0x0a) {
        uint8_t digit = (uint8_t)(raw == 0x0a ? 0 : raw);
        key.virtualKey = digitMac[digit];
        key.character = (uint8_t)('0' + digit);
        key.shiftedCharacter = digitShift[digit];
        return true;
    }

    static const uint8_t keypadRaw[] = {
        0x0f, 0x1d, 0x1e, 0x1f, 0x2d, 0x2e, 0x2f, 0x3d, 0x3e, 0x3f
    };
    static const uint8_t keypadMac[] = {
        0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5b, 0x5c
    };
    for (uint16_t i = 0; i < 10; ++i) {
        if (raw == keypadRaw[i]) {
            key.virtualKey = keypadMac[i];
            key.character = (uint8_t)('0' + i);
            key.shiftedCharacter = key.character;
            return true;
        }
    }

    switch (raw) {
    case 0x00: key = {0x32, '`', '~'}; return true;
    case 0x0b: key = {0x1b, '-', '_'}; return true;
    case 0x0c: key = {0x18, '=', '+'}; return true;
    case 0x0d: key = {0x2a, '\\', '|'}; return true;
    case 0x1a: key = {0x21, '[', '{'}; return true;
    case 0x1b: key = {0x1e, ']', '}'}; return true;
    case 0x29: key = {0x29, ';', ':'}; return true;
    case 0x2a: key = {0x27, '\'', '"'}; return true;
    case 0x38: key = {0x2b, ',', '<'}; return true;
    case 0x39: key = {0x2f, '.', '>'}; return true;
    case 0x3a: key = {0x2c, '/', '?'}; return true;
    case 0x40: key = {0x31, ' ', ' '}; return true;
    case 0x41: key = {0x33, 0x08, 0x08}; return true;
    case 0x42: key = {0x30, 0x09, 0x09}; return true;
    case 0x44: key = {0x24, 0x0d, 0x0d}; return true;
    case 0x45: key = {0x35, 0x1b, 0x1b}; return true;
    case 0x46: key = {0x75, 0x7f, 0x7f}; return true;
    case 0x4c: key = {0x7e, 0, 0}; return true;
    case 0x4d: key = {0x7d, 0, 0}; return true;
    case 0x4e: key = {0x7c, 0, 0}; return true;
    case 0x4f: key = {0x7b, 0, 0}; return true;
    case 0x50: key = {0x7a, 0, 0}; return true;
    case 0x51: key = {0x78, 0, 0}; return true;
    case 0x52: key = {0x63, 0, 0}; return true;
    case 0x53: key = {0x76, 0, 0}; return true;
    case 0x54: key = {0x60, 0, 0}; return true;
    case 0x55: key = {0x61, 0, 0}; return true;
    case 0x56: key = {0x62, 0, 0}; return true;
    case 0x57: key = {0x64, 0, 0}; return true;
    case 0x58: key = {0x65, 0, 0}; return true;
    case 0x59: key = {0x6d, 0, 0}; return true;
    case 0x5f: key = {0x72, 0, 0}; return true;
    case 0x60: case 0x61: key = {0x38, 0, 0}; return true;
    case 0x62: key = {0x39, 0, 0}; return true;
    case 0x63: key = {0x3b, 0, 0}; return true;
    case 0x64: case 0x65: key = {0x3a, 0, 0}; return true;
    case 0x66: case 0x67: key = {0x37, 0, 0}; return true;
    default: return false;
    }
}

extern "C" void aitdMacRawKeyChanged(uint8_t rawKey, bool down)
{
    KeyTranslation key;
    if (!translateAmigaKey(rawKey, key)) return;
    setKeyMapState(key.virtualKey, down);
}

static int16_t addClampedMouseDelta(int16_t value, int16_t delta, int16_t maximum)
{
    int16_t changed = (int16_t)(value + delta);
    if (changed < 0) return 0;
    if (changed > maximum) return maximum;
    return changed;
}

extern "C" void aitdMacMouseVBI()
{
    uint16_t counters = *joy0datPointer;
    uint8_t counterX = (uint8_t)counters;
    uint8_t counterY = (uint8_t)(counters >> 8);
    bool buttonDown = AmigaHardware::isLeftMouseButtonPressed();
    int16_t deltaX = 0, deltaY = 0;
    if (s_mouseInitialized) {
        deltaX = (int8_t)(counterX - s_mouseCounterX);
        deltaY = (int8_t)(counterY - s_mouseCounterY);
    }
    s_mouseInitialized = true;
    s_mouseCounterX = counterX;
    s_mouseCounterY = counterY;
    int16_t oldX = s_mouseX, oldY = s_mouseY;
    int16_t x = oldX, y = oldY;
    if (s_loudStopScreen)
        s_loudStopScreen->updateMouseCoordinates(x, y, deltaX, deltaY);
    else {
        x = addClampedMouseDelta(x, deltaX, 511);
        y = addClampedMouseDelta(y, deltaY, 319);
    }
    s_mouseX = x;
    s_mouseY = y;
    // Include viewport motion and edge clamping in all redirected Mac mouse
    // globals, keeping GetMouse/EventRecord and the hardware sprite aligned.
    deltaX = x - oldX;
    deltaY = y - oldY;
    if (s_currentA5 && (deltaX || deltaY)) {
        const uint16_t verticals[] = { kLowMTempV, kLowRawMouseV, kLowMouseV };
        const uint16_t horizontals[] = { kLowMTempH, kLowRawMouseH, kLowMouseH };
        for (uint16_t i = 0; i < 3; ++i) {
            volatile uint16_t* v = (volatile uint16_t*)(s_portLowMemory + verticals[i]);
            volatile uint16_t* h = (volatile uint16_t*)(s_portLowMemory + horizontals[i]);
            *v = (uint16_t)addClampedMouseDelta((int16_t)*v, deltaY, 479);
            *h = (uint16_t)addClampedMouseDelta((int16_t)*h, deltaX, 639);
        }
    }
    if (deltaX || deltaY) ++g_mouseVBIMoves;
    if (s_currentA5 && s_mouseGlobalsA5 != s_currentA5) {
        // Mouse sampling begins as soon as the Amiga screen is live, before
        // the Macintosh A5 world exists. Initialize its redirected globals on
        // the first VBI after that world is published.
        int16_t globalV = (int16_t)(s_mouseY + 91);
        int16_t globalH = (int16_t)(s_mouseX + 64);
        *(volatile uint16_t*)(s_portLowMemory + kLowMTempV) = (uint16_t)globalV;
        *(volatile uint16_t*)(s_portLowMemory + kLowMTempH) = (uint16_t)globalH;
        *(volatile uint16_t*)(s_portLowMemory + kLowRawMouseV) = (uint16_t)globalV;
        *(volatile uint16_t*)(s_portLowMemory + kLowRawMouseH) = (uint16_t)globalH;
        *(volatile uint16_t*)(s_portLowMemory + kLowMouseV) = (uint16_t)globalV;
        *(volatile uint16_t*)(s_portLowMemory + kLowMouseH) = (uint16_t)globalH;
        s_mouseGlobalsA5 = s_currentA5;
    }
    s_mouseHardwareButtonDown = buttonDown;
    s_portLowMemory[kLowMBState] = buttonDown ? 0x00 : 0x80;
    if (s_loudStopScreen)
        s_loudStopScreen->setMousePositionFromVBI(s_mouseX, s_mouseY);
    ++g_mouseVBISamples;
}

static bool pollMacMouse()
{
    // Position, button and redirected low-memory globals are maintained by
    // aitdMacMouseVBI(). Event polling only consumes that asynchronous state.
    return s_mouseHardwareButtonDown;
}

static bool nextEvent(uint16_t mask, uint8_t* event)
{
    if (!event) return false;
    bool buttonDown = pollMacMouse();
    bool transition = false;
    uint16_t what = 0;
    if (buttonDown != s_mouseButtonDown) {
        what = buttonDown ? 1 : 2;
        transition = (mask & (1u << what)) != 0;
        s_mouseButtonDown = buttonDown;
    }

    uint32_t message = 0;
    uint16_t modifiers = (uint16_t)(aitdInputModifiers() | (buttonDown ? 0 : 0x0080));
    uint8_t rawKey;
    bool keyDown;
    uint16_t keyModifiers;
    while (!transition && aitdInputPopKey(rawKey, keyDown, keyModifiers)) {
        KeyTranslation key;
        uint16_t keyWhat = keyDown ? 3 : 4;
        if (!translateAmigaKey(rawKey, key)) continue;
        setKeyMapState(key.virtualKey, keyDown);
        if (!(mask & (1u << keyWhat))) continue;
        what = keyWhat;
        modifiers = (uint16_t)(keyModifiers | (buttonDown ? 0 : 0x0080));
        uint8_t character = (keyModifiers & 0x0200) ? key.shiftedCharacter : key.character;
        message = ((uint32_t)key.virtualKey << 8) | character;
        transition = true;
    }
    write16(event + 0, transition ? what : 0);
    write32(event + 2, message);
    write32(event + 6, g_macTicks);
    // EventRecord.where is in Macintosh global coordinates, not coordinates
    // relative to the cropped game surface shown by the Amiga display.
    write16(event + 10, (uint16_t)(s_mouseY + 91));
    write16(event + 12, (uint16_t)(s_mouseX + 64));
    write16(event + 14, modifiers);
    return transition;
}

static int32_t resourceHandleIndex(uint8_t** handle)
{
    if(!handle)return -1;
    for(uint32_t i=0;i<s_resourceForks.resourceCount();++i)
        if(s_resourceHandles[i]==handle)return i;
    return -1;
}
static void forgetHandle(uint8_t** handle)
{
    for(uint32_t i=0;i<s_resourceForks.resourceCount();++i)
        if(s_resourceHandles[i]==handle)s_resourceHandles[i]=0;
    for(uint16_t i=1;i<s_segmentCount;++i)
        if(s_segments[i].handle==handle)s_segments[i].handle=0;
}
static bool releaseResource(uint8_t** handle)
{
    int32_t index=resourceHandleIndex(handle);MacHeap* zone=handleZone(handle);
    if(index<0 || !zone) { resourceResult(-192);return false; }
    memoryResult(zone->disposeHandle(handle));forgetHandle(handle);refreshCodeViews();
    resourceResult(0);return true;
}
static bool permanentHandle(uint8_t** handle)
{
    return gWorldForPixMap(handle) || handle==&s_mainDeviceMaster
        || handle==&s_windowManagerPixMapMaster || handle==&s_mainDeviceITableMaster;
}
static bool dispatchMemoryTrap(uint16_t trap,uint32_t* regs)
{
    uint16_t op=trap&0xf8ff;
    MacHeap* zone=(trap&0x400) ? &s_systemZone : s_currentZone;
    uint8_t* ptr=(uint8_t*)regs[8];MacHeap::Handle handle=(MacHeap::Handle)ptr;
    MacHeap* owner=0;int16_t error=0;bool resultInD0=true;
    switch(op) {
    case 0xa01a: regs[8]=(uint32_t)s_currentZone->base();break;
    case 0xa01b:
        if(ptr==s_applicationZone.base())s_currentZone=&s_applicationZone;
        else if(ptr==s_systemZone.base())s_currentZone=&s_systemZone;
        else return false;
        break;
    case 0xa01c: regs[0]=zone->freeBytes();resultInD0=false;break;
    case 0xa01d:
        zone->purge(zone->capacity());regs[0]=zone->compact();regs[8]=0;
        resultInD0=false;break;
    case 0xa01e:
        regs[8]=(uint32_t)zone->newPtr(regs[0],(trap&0x200)!=0);error=zone->error();break;
    case 0xa01f:
        owner=pointerZone(ptr);if(!owner)return false;
        error=owner->disposePtr(ptr);break;
    case 0xa020:
        owner=pointerZone(ptr);if(!owner)return false;
        error=owner->setPtrSize(ptr,regs[0]);break;
    case 0xa021:
        owner=pointerZone(ptr);if(!owner)return false;
        regs[0]=owner->ptrSize(ptr);error=owner->error();resultInD0=false;break;
    case 0xa022:
        regs[8]=(uint32_t)zone->newHandle(regs[0],(trap&0x200)!=0);error=zone->error();break;
    case 0xa023:
        owner=handleZone(handle);if(!owner)return false;
        error=owner->disposeHandle(handle);if(!error)forgetHandle(handle);break;
    case 0xa024:
        owner=handleZone(handle);if(!owner)return false;
        error=owner->setHandleSize(handle,regs[0]);break;
    case 0xa025:
        owner=handleZone(handle);if(!owner)return false;
        regs[0]=owner->handleSize(handle);error=owner->error();resultInD0=false;break;
    case 0xa026:
        owner=handleZone(handle);if(!owner)return false;
        regs[8]=(uint32_t)owner->base();break;
    case 0xa027:
        owner=handleZone(handle);if(!owner)return false;
        error=owner->reallocateHandle(handle,regs[0]);break;
    case 0xa028:
        regs[8]=(uint32_t)zone->recoverHandle(ptr);error=zone->error();resultInD0=false;break;
    case 0xa029: case 0xa02a: case 0xa049: case 0xa04a: case 0xa067: case 0xa068: case 0xa069: case 0xa06a:
        owner=handleZone(handle);
        if(!owner) {
            // Permanent manager-owned handles cannot relocate. Other operations
            // need their manager's implementation and remain named stops.
            if(permanentHandle(handle) && (op==0xa029 || op==0xa02a))break;
            return false;
        }
        {
            uint8_t state=owner->state(handle);
            if(op==0xa069) { regs[0]=state;resultInD0=false;break; }
            if(op==0xa029)state|=0x80;
            if(op==0xa02a)state&=~0x80;
            if(op==0xa049)state|=0x40;
            if(op==0xa04a)state&=~0x40;
            if(op==0xa067)state|=0x20;
            if(op==0xa068)state&=~0x20;
            if(op==0xa06a)state=regs[0];
            error=owner->setState(handle,state);
        }
        break;
    case 0xa02b:
        owner=handleZone(handle);if(!owner)return false;
        error=owner->emptyHandle(handle);break;
    case 0xa02d:
        if(ptr<s_applicationArena || ptr>s_applicationArena+kApplicationZoneBytes)return false;
        // The zone is already fully reserved. As on the Mac, lowering ApplLimit
        // does not cut back an existing heap; it only prohibits future growth.
        s_applicationLimit=ptr;write32(s_portLowMemory+80,(uint32_t)ptr);break;
    case 0xa036: error=zone->moreMasters();break;
    case 0xa048:
        owner=pointerZone(ptr);if(!owner)return false;
        regs[8]=(uint32_t)owner->base();break;
    case 0xa04c: regs[0]=zone->compact();resultInD0=false;break;
    case 0xa04d: error=zone->purge(regs[0]);break;
    case 0xa063: break; // The full SIZE arena was reserved before takeover.
    case 0xa064:
        owner=handleZone(handle);if(!owner)return false;
        error=owner->moveHigh(handle);break;
    case 0xa066: regs[8]=(uint32_t)zone->newEmptyHandle();error=zone->error();break;
    default: return false;
    }
    memoryResult(error);
    if(resultInD0)regs[0]=(uint32_t)(int32_t)error;
    return true;
}

// Deferred services retain only exception metadata; registers are parked on
// the Mac user stack by MacEntry.s. The single active service cannot recurse.
struct UserService {
    uint8_t frame[8];
    uint8_t* arguments;
    uint16_t trap;
    bool builtin;
    uint32_t toolboxReturn;
};
static UserService s_userService;
static uint8_t* allocateFilePage(uint32_t size) { return (uint8_t*)AllocMem(size,MEMF_FAST); }
static void releaseFilePage(uint8_t* bytes,uint32_t size) { FreeMem(bytes,size); }
static int16_t flushDataSource(DataSource& source,FileAccess::ReadStream& stream,bool restored=false) {
    bool changed=source.writes.dirty();
    int16_t error=restored ? FileAccess::flushRestoredStream(stream,source.writes) : FileAccess::flushStream(stream,source.writes);
    if(!error && changed)s_files.touchMetadata(source.id,FileAccess::metadataTime());
    const MacFiles::Entry* entry=s_files.entry(source.id);
    if(!error && entry->metadataDirty) {
        error=FileAccess::storeMetadata(entry->path,entry->metadata,restored);
        if(!error)s_files.metadataFlushed(entry->id);
    }
    return error;
}
static bool isFileCatalogService(uint16_t trap) {
    return trap==0xa008 || trap==0xa208 || trap==0xa009 || trap==0xa209
        || trap==0xa00c || trap==0xa20c || trap==0xa00d || trap==0xa20d;
}
static bool dispatchFileCatalog(uint16_t trap,uint32_t* regs) {
    if(!isFileCatalogService(trap))return false;
    uint8_t* pb=(uint8_t*)regs[8];if(!pb)return false;
    uint16_t operation=trap&0xff;
    bool indexed=operation==12 && (int16_t)read16(pb+28)>0;
    uint8_t* name=(uint8_t*)read32(pb+18);if(!name && !indexed)return false;
    char path[256];uint16_t length=name && !indexed ? name[0] : 0;
    for(uint16_t i=0;i<length;++i)path[i]=name[i+1];path[length]=0;
    uint32_t directory=(trap&0x200) ? read32(pb+48) : 0,id=0;
    int16_t error=0;
    if(operation==8) {
        if(pb[27])return false; // Unmeasured legacy version-number form.
        MacFiles::Entry plan;
        error=s_files.planCreate((int16_t)read16(pb+22),directory,path,plan);
        if(!error) {
            FileMetadata::Record metadata;
            error=FileAccess::createFile(plan.path,s_files.entry(plan.parent)->path,
                plan.parent==s_files.preferences || plan.parent==s_files.saves,metadata);
            if(!error) {
                int32_t created=s_files.add(plan.parent,plan.name,plan.path,false);
                if(created<0)return false; // Preflight made this impossible without reentry.
                error=s_files.setMetadata(created,metadata);
            }
        }
    } else {
        error=indexed ? s_files.indexedFile((int16_t)read16(pb+22),directory,(int16_t)read16(pb+28),id)
                      : s_files.resolve((int16_t)read16(pb+22),directory,path,id);
        const MacFiles::Entry* entry=error ? 0 : s_files.entry(id);
        if(!error && operation==9) {
            error=s_files.canRemove(id);
            if(!error)error=FileAccess::deleteFile(entry->path,entry->resourceIsBase);
            if(!error)error=s_files.remove(id);
        } else if(!error) {
            if(entry->directory || (operation==12 && !entry->metadataKnown))return false;
            bool locked=false;error=FileAccess::fileProtection(entry->path,locked);
            if(!error && operation==13) {
                {
                    FileMetadata::Record metadata;
                    for(uint16_t i=0;i<16;++i)metadata.finder[i]=pb[32+i];
                    metadata.created=read32(pb+72);metadata.modified=read32(pb+76);
                    error=FileAccess::storeMetadata(entry->path,metadata);
                    if(!error)error=s_files.setMetadata(id,metadata);
                }
            } else if(!error) {
                const MacFiles::Fork* first=0;uint8_t attributes=locked ? 1 : 0;
                for(int16_t i=1;i<=MacFiles::maxOpen;++i) {
                    const MacFiles::Fork* fork=0;
                    if(s_files.queryFork(0,i,0,fork))break;
                    if(fork->id==id) { if(!first)first=fork;attributes|=0x80|(fork->resource ? 4 : 8); }
                }
                write16(pb+24,first ? first->ref : 0);pb[30]=attributes;pb[31]=0;
                // GCC 15.1 m68k combines the byte loop into MOVE.B (a0)+,(a0,d0),
                // shifting its destination by one. Explicit fixed words avoid that form.
                write32(pb+32,read32(entry->metadata.finder));
                write32(pb+36,read32(entry->metadata.finder+4));
                write32(pb+40,read32(entry->metadata.finder+8));
                write32(pb+44,read32(entry->metadata.finder+12));
                write32(pb+48,id);write16(pb+52,0);write32(pb+54,entry->dataSize);write32(pb+58,entry->dataSize);
                write16(pb+62,0);write32(pb+64,entry->resourceSize);write32(pb+68,entry->resourceSize);
                write32(pb+72,entry->metadata.created);write32(pb+76,entry->metadata.modified);
                if(name) { uint16_t n=0;while(entry->name[n]) { name[n+1]=entry->name[n];++n; }name[0]=n; }
            }
        }
    }
    if(error==MacFiles::unsupported)return false;
    write16(pb+16,error);regs[0]=(uint32_t)(int32_t)error;return true;
}
static bool isFileDataService(uint16_t trap) {
    return trap==0xa000 || trap==0xa200 || trap==0xa00a || trap==0xa20a || trap==0xa001 || trap==0xa002
        || trap==0xa011 || trap==0xa018 || trap==0xa044
        || trap==0xa003 || trap==0xa012 || trap==0xa013;
}
static bool dispatchFileData(uint16_t trap,uint32_t* regs) {
    if(!isFileDataService(trap))return false;
    uint8_t* pb=(uint8_t*)regs[8];if(!pb)return false;
    int16_t error=0;
    if(trap==0xa013) {
        uint8_t* name=(uint8_t*)read32(pb+18);char volume[256];
        uint16_t length=name ? name[0] : 0;
        for(uint16_t i=0;i<length;++i)volume[i]=name[i+1];volume[length]=0;
        error=s_files.volume((int16_t)read16(pb+22),volume);
        if(!error)for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(s_dataSources[i].id) {
            DataSource& source=s_dataSources[i];
            int16_t flushed=flushDataSource(source,*source.backing);
            if(!flushed)s_files.flushed(source.id,source.resource);else if(!error)error=flushed;
        }
    } else if(trap==0xa000 || trap==0xa200 || trap==0xa00a || trap==0xa20a) {
        bool resource=(trap&0xff)==0x0a;
        if(pb[27]>4)return false;
        uint8_t* name=(uint8_t*)read32(pb+18);if(!name)return false;
        char path[256];for(uint16_t i=0;i<name[0];++i)path[i]=name[i+1];path[name[0]]=0;
        uint32_t id=0;
        error=s_files.resolve((int16_t)read16(pb+22),(trap&0x200) ? read32(pb+48) : 0,path,id);
        if(!error) {
            const MacFiles::Entry* entry=s_files.entry(id);
            if(entry->directory)error=MacFiles::fnfErr;
            else {
                DataFork* slot=0;DataSource* source=0;
                for(uint16_t i=0;i<MacFiles::maxOpen;++i) {
                    if(!s_dataForks[i].ref && !slot)slot=&s_dataForks[i];
                    if(s_dataSources[i].id==id && s_dataSources[i].resource==resource)source=&s_dataSources[i];
                }
                if(!slot)error=-42;
                else {
                    // Open/Examine happens in one window, before deciding default
                    // permission. No payload is read, even for a protected file.
                    uint32_t length=resource ? entry->resourceSize : entry->dataSize;
                    char nativePath[192];error=s_files.forkPath(id,resource,nativePath,sizeof(nativePath));
                    bool companion=resource!=entry->resourceIsBase;
                    if(!error)error=FileAccess::openStream(nativePath,slot->stream,companion && !length,companion ? entry->path : 0);
                    int16_t ref=0;
                    if(!error)error=s_files.openFork(id,resource,pb[27],slot->stream.locked,ref);
                    if(error==-49)write16(pb+24,ref);
                    bool writable=!error && s_files.fork(ref)->writable;
                    bool newSource=false;
                    if(!error && writable && !source) {
                        for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(!s_dataSources[i].id) { source=&s_dataSources[i];break; }
                        if(!source)error=MacFiles::unsupported;
                        else {
                            source->backing=&slot->stream;
                            error=source->writes.bind(length,readDataSource,source,allocateFilePage,releaseFilePage);
                            if(!error) { source->id=id;source->resource=resource;newSource=true; }
                        }
                    }
                    if(!error && !source) {
                        slot->buffer=allocateFilePage(FileReadCache::capacity);
                        if(!slot->buffer)error=-108;
                    }
                    if(error) {
                        if(slot->stream.handle)FileAccess::closeStream(slot->stream);
                        if(error!=-49 && ref)s_files.close(ref);
                    } else {
                        slot->ref=ref;slot->source=source;
                        if(!source)slot->cache.bind(slot->buffer,length,FileAccess::readStream,&slot->stream);
                        if(newSource)for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(s_dataForks[i].ref) {
                            DataFork& other=s_dataForks[i];
                            if(s_files.fork(other.ref)->id==id && s_files.fork(other.ref)->resource==resource) {
                                other.source=source;
                                if(other.buffer)FreeMem(other.buffer,FileReadCache::capacity);other.buffer=0;
                            }
                        }
                        write16(pb+24,ref);
                    }
                }
            }
        }
    } else {
        int16_t ref=(int16_t)read16(pb+24);
        const MacFiles::Fork* fork=s_files.fork(ref);
        DataFork* slot=0;
        for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(s_dataForks[i].ref==ref && ref) { slot=&s_dataForks[i];break; }
        if(!fork)error=MacFiles::rfNumErr;
        else if(!slot)return false; // Buffered application/resource fork is not a data stream.
        else if(trap==0xa001) {
            error=slot->source && fork->writable && fork->modified ? flushDataSource(*slot->source,slot->stream) : 0;
            if(!error) {
                DataSource* source=slot->source;
                if(source) {
                    source->backing=0;
                    for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(&s_dataForks[i]!=slot && s_dataForks[i].ref && s_dataForks[i].source==source) {
                        source->backing=&s_dataForks[i].stream;break;
                    }
                    if(!source->backing) { source->writes.clear();source->id=0; }
                }
                error=FileAccess::closeStream(slot->stream);
                if(slot->buffer)FreeMem(slot->buffer,FileReadCache::capacity);
                slot->source=0;slot->buffer=0;slot->ref=0;s_files.close(ref);
            }
        } else if(trap==0xa012) {
            if(!fork->writable)error=-61;
            else {
                error=slot->source->writes.resize(read32(pb+28));
                if(!error) {
                    error=s_files.setSize(ref,slot->source->writes.size(),true);
                }
            }
        } else if(trap==0xa003 && !fork->writable)error=-61;
        else if(trap==0xa011)write32(pb+28,fork->resource ? s_files.entry(fork->id)->resourceSize : s_files.entry(fork->id)->dataSize);
        else if(trap==0xa018) {
            write32(pb+36,0);write32(pb+40,0);write16(pb+44,0);write32(pb+46,fork->position);
        } else {
            if(read16(pb+44)>3)return false; // Newline and other positioning flags pending.
            bool transfer=trap==0xa002 || trap==0xa003;
            uint32_t count=transfer ? read32(pb+36) : 0;
            uint8_t* buffer=(uint8_t*)read32(pb+32);
            if(transfer && (count>0x7fffffffUL || (!buffer && count)))error=MacFiles::paramErr;
            else error=s_files.seek(ref,read16(pb+44),(int32_t)read32(pb+46),trap==0xa003);
            uint32_t actual=0;
            if(!error && trap==0xa002) {
                error=slot->source ? slot->source->writes.read(fork->position,buffer,count,actual)
                                     : slot->cache.read(fork->position,buffer,count,actual);
                s_files.advance(ref,actual);
            }
            if(!error && trap==0xa003) {
                error=slot->source->writes.write(fork->position,buffer,count,actual);
                // Mac PBWrite with a zero count still extends EOF to its mark.
                if(!error && !count && fork->position>slot->source->writes.size())error=slot->source->writes.resize(fork->position);
                s_files.advance(ref,actual);
                if(actual)s_files.modified(ref);
                int16_t resized=s_files.setSize(ref,slot->source->writes.size(),false);
                if(!error)error=resized;
            }
            if(transfer)write32(pb+40,actual);
            write32(pb+46,fork->position);
        }
    }
    if(error==MacFiles::unsupported)return false;
    write16(pb+16,error);regs[0]=(uint32_t)(int32_t)error;return true;
}
static bool isUserService(uint16_t trap)
{
#ifdef AITD_FILE_WRITE_PROBE
    if(trap==0xa0fb)return true;
#endif
#ifdef AITD_WINDOW_PROBE
    if(trap==0xa1fc)return true;
#endif
#ifdef AITD_SERVICE_PROBE
    if((trap&0xfeff)==0xa0fc || trap==0xabfb)return true;
#endif
    return (trap&0xf8ff)==0xa060 || trap==0xa014 || trap==0xa015 || trap==0xa214 || trap==0xa215 || isFileDataService(trap) || isFileCatalogService(trap);
}
// Metadata-only File Manager selectors. Unsupported layouts fall through to
// the named trap stop; no OS call is made inside this helper.
static bool dispatchFileMetadata(uint16_t trap,uint32_t* regs)
{
    if(trap==0xa014 || trap==0xa214) { // Synchronous volume/default-directory queries.
        uint8_t* pb=(uint8_t*)regs[8];
        if(!pb)return false;
        uint32_t directory=0;
        int16_t error=s_files.directoryFor(0,directory);
        if(!error) {
            uint8_t* name=(uint8_t*)read32(pb+18);
            const char* volume=s_files.entry(2)->name;
            if(name) {
                uint8_t n=0;while(volume[n]) { name[n+1]=volume[n];++n; }name[0]=n;
            }
            write16(pb+22,s_files.defaultRef() ? s_files.defaultRef() : MacFiles::volumeRef);
            if(trap==0xa214) { write16(pb+32,MacFiles::volumeRef);write32(pb+48,directory); }
        }
        write16(pb+16,error);regs[0]=(uint32_t)(int32_t)error;return true;
    }
    if(trap==0xa015 || trap==0xa215) { // Synchronous volume/default-directory setters.
        uint8_t* pb=(uint8_t*)regs[8];
        if(!pb)return false;
        uint8_t* name=(uint8_t*)read32(pb+18);
        char volume[256];
        if(name) {
            for(uint16_t i=0;i<name[0];++i)volume[i]=name[i+1];
            volume[name[0]]=0;
        }
        int16_t error=trap==0xa215
            ? s_files.setHierarchicalDefault((int16_t)read16(pb+22),read32(pb+48),name ? volume : 0)
            : s_files.setDefault((int16_t)read16(pb+22),name ? volume : 0);
        if(error==MacFiles::unsupported)return false;
        write16(pb+16,error);regs[0]=(uint32_t)(int32_t)error;return true;
    }
    if((trap&0xf8ff)!=0xa060 || (trap&0x0400))return false;
    uint8_t* pb=(uint8_t*)regs[8];
    if(!pb)return false;
    uint16_t selector=(uint16_t)regs[0];
    int16_t error=MacFiles::unsupported;
    if(selector==8) { // PBGetFCBInfo: exact reference or one-based live-fork index.
        const MacFiles::Fork* fork=0;
        error=s_files.queryFork((int16_t)read16(pb+22),(int16_t)read16(pb+28),
                               (int16_t)read16(pb+24),fork);
        if(!error) {
            write16(pb+24,fork->ref);
            const MacFiles::Entry* file=s_files.entry(fork->id);
            uint8_t* name=(uint8_t*)read32(pb+18);
            if(name) {
                uint8_t n=0;while(file->name[n]) { name[n+1]=file->name[n];++n; }name[0]=n;
            }
            uint32_t length=fork->resource ? file->resourceSize : file->dataSize;
            write32(pb+32,file->id);
            write16(pb+36,(fork->resource ? 0x0200 : 0)|(fork->writable ? 0x0100 : 0)|(fork->shared ? 0x1000 : 0)
                    |(fork->locked ? 0x2000 : 0)|(fork->modified ? 0x8000 : 0));
            write16(pb+38,0); // Virtual files have no HFS allocation blocks.
            write32(pb+40,length);write32(pb+44,length);
            write32(pb+48,fork->position);write16(pb+52,MacFiles::volumeRef);
            write32(pb+54,0);write32(pb+58,file->parent);
            error=0;
        }
    } else if(selector==2) { // PBCloseWD
        error=s_files.closeWD((int16_t)read16(pb+22));
    } else if(selector==7) { // PBGetWDInfo: exact (including negative index) or filtered enumeration.
        int16_t ref=(int16_t)read16(pb+22);
        uint32_t process=read32(pb+28),directory=0;
        error=s_files.queryWD(ref,(int16_t)read16(pb+26),process,directory);
        if(!error) {
            uint8_t* name=(uint8_t*)read32(pb+18);
            const char* volume=s_files.entry(2)->name;
            if(name) { uint8_t n=0;while(volume[n]) { name[n+1]=volume[n];++n; }name[0]=n; }
            write16(pb+22,ref);write32(pb+28,process);write16(pb+32,MacFiles::volumeRef);write32(pb+48,directory);
        }
    } else if(selector==1) { // PBOpenWD
        char path[256];uint8_t* name=(uint8_t*)read32(pb+18);
        uint16_t length=name ? name[0] : 0;
        for(uint16_t i=0;i<length;++i)path[i]=name[i+1];path[length]=0;
        uint32_t directory=0;
        error=s_files.resolve((int16_t)read16(pb+22),read32(pb+48),path,directory);
        if(!error) {
            bool created=false;
            int16_t ref=s_files.openWD(directory,read32(pb+28),&created);
            uint32_t check=0;
            if(ref==-121 || ref==MacFiles::fnfErr)error=ref;
            else {
                if(s_files.directoryFor(ref,check) || check!=directory)return false;
                write16(pb+22,ref);write16(pb+24,created ? 1 : 0);error=0;
            }
        }
    }
    if(error==MacFiles::unsupported)return false;
    write16(pb+16,(uint16_t)error);regs[0]=(uint32_t)(int32_t)error;return true;
}

static uint32_t deferUserService(uint16_t trap,bool builtin,uint8_t* frame,uint8_t* arguments)
{
    if(g_macServiceActive) {
        loaderStop("USER SERVICE REENTRY",0);showLoaderStop();
    }
    if((read16(frame)&0x2000) || (read16(frame+6)&0xf000)) {
        loaderStop("USER SERVICE FRAME",0);showLoaderStop();
    }
    for(uint16_t i=0;i<8;++i)s_userService.frame[i]=frame[i];
    s_userService.arguments=arguments;s_userService.trap=trap;
    s_userService.builtin=builtin;s_userService.toolboxReturn=0;
    g_macServiceActive=1;
    return 0xffffffffUL; // Handler RTEs to the service without popping arguments.
}

// AmigaDOS runs the application in user mode: parameters are on USP, while Line-A creates
// an eight-byte format-0 frame on the 68020 supervisor stack. The Mac II runs
// its application in supervisor mode; our Macintosh arguments remain on USP.
static uint32_t dispatchMacTrap(uint16_t trap, bool builtin, uint32_t* regs,
                               uint8_t* frame, uint8_t* userStack, bool inUserService=false)
{
    uint32_t pc = read32(frame + 2);
#ifdef AITD_PROBE
    // Empty same-rate bracket: its total bounds the profiler's per-dispatch
    // observer cost and catches a timer whose apparent resolution is fiction.
    { AitdProfileScope profileControl(kProfileControl); }
    AitdProfileScope profileTrap(aitdProfileTrapCategory(trap));
#endif
    // Mouse position and button live in redirected low-memory shadows that
    // original code may read directly, so refresh them at every safe Line-A
    // boundary while keyboard polling remains independent.
    pollMacMouse();
    // Every handled trap return is a user-mode-safe opportunity to deliver
    // due VBL work, then to present the pixels drawn since the last boundary.
    scheduleVBLTask();
    presentMacRuntime();
    if (!builtin) {
        uint32_t routed = routePatchedTrap(trap, regs, frame, userStack);
        if (routed) return routed;
    }
#ifdef AITD_WINDOW_PROBE
    if(inUserService && trap==0xa1fc) {
        if(!aitdWindowProbe()) { loaderStop("SYSTEM WINDOW PROBE",0);showLoaderStop(); }
        regs[0]=0;return 1;
    }
#endif
#ifdef AITD_FILE_WRITE_PROBE
    if(inUserService && trap==0xa0fb) {
        extern int32_t aitdFileWriteBackendProbe();
        regs[0]=(uint32_t)aitdFileWriteBackendProbe();return 1;
    }
#endif
    if(isUserService(trap) && !inUserService)
        return deferUserService(trap,builtin,frame,userStack);
#ifdef AITD_SERVICE_PROBE
    if(inUserService && ((trap&0xfeff)==0xa0fc || trap==0xabfb)) {
        aitd_service_nested_probe(); // Its saved exception SR proves user mode.
        if(trap==0xabfb) {
            if(read32(userStack)!=0x10203040 || read16(userStack+4)!=0x5060) {
                loaderStop("USER SERVICE PROBE ARGUMENTS",0);showLoaderStop();
            }
            write16(userStack+6,0x1357);return 7;
        }
        regs[0]=0xffffff94;regs[8]=0x2468ace0;return 1;
    }
#endif
    if(!(trap&0x0800) && dispatchMemoryTrap(trap,regs))return 1;
    if(inUserService && dispatchFileMetadata(trap,regs))return 1;
    if(inUserService && dispatchFileData(trap,regs))return 1;
    if(inUserService && dispatchFileCatalog(trap,regs))return 1;
    if(trap==0xa823 && (uint16_t)regs[0]==0) { // FindFolder, catalogued Preferences.
        const uint16_t volume=read16(userStack+14);
        const uint32_t type=read32(userStack+10);
        if(type==0x70726566 && (volume==0x8000 || volume==0xffff)
            && s_files.entry(s_files.preferences) && read32(userStack) && read32(userStack+4)) {
            // The virtual Preferences directory exists from catalog construction.
            write32((uint8_t*)read32(userStack),s_files.preferences);
            write16((uint8_t*)read32(userStack+4),MacFiles::volumeRef);
            write16(userStack+16,0);
            return 17;
        }
    }
    if(trap==0xa9af) { write16(userStack,read16(s_portLowMemory+140));return 1; }
    if(trap==0xa992) {
        MacHeap::Handle handle=(MacHeap::Handle)read32(userStack);
        int32_t index=resourceHandleIndex(handle);MacHeap* zone=handleZone(handle);
        if(index>=0 && zone) {
            s_resourceHandles[index]=0;zone->setState(handle,zone->state(handle)&~0x20);
            resourceResult(0);return 5;
        }
    }
    if(trap==0xa9e3) {
        const uint8_t* source=(const uint8_t*)regs[8];uint32_t bytes=regs[0];
        MacHeap::Handle handle=newHandle(bytes,false);
        if(handle)for(uint32_t i=0;i<bytes;++i)(*handle)[i]=source[i];
        regs[8]=(uint32_t)handle;regs[0]=(uint32_t)(int32_t)s_memoryError;return 1;
    }
    if(trap==0xa9ef) {
        regs[0]=(uint32_t)(int32_t)pointerAndHandle((uint8_t*)regs[8],(uint8_t**)regs[9],regs[0]);return 1;
    }
    if ((trap & 0xfeff) == 0xa055) return 1; // StripAddress identity: native 32-bit pointers
    if (trap == 0xa0bd || (trap == 0xa198 && (regs[0] == 1 || regs[0] == 3))) {
        CacheClearU();
        regs[0] = 0;
        return 1;
    }

    if (trap == 0xa9f4) {                    // original ExitToShell after patch cleanup
        g_macVBLCallbackEntry = 0;
        g_macVBLCallbackTask = 0;
        g_macVBLCallbackA5 = 0;
        g_macExitState = 3;
        write32(frame + 2, (uint32_t)aitd_user_exit_trampoline - 2);
        return 1;
    }
    if (trap == 0xa02e) {                    // _BlockMove: A0, A1, D0; registers preserved
#ifdef AITD_PROBE
        uint32_t blockMoveStart = aitdProfileBeamEpoch();
#endif
        blockMove((uint8_t*)regs[8], (uint8_t*)regs[9], regs[0]);
#ifdef AITD_PROBE
        g_probeBlockMoveTicks += aitdProfileBeamEpoch() - blockMoveStart;
        ++g_probeBlockMoveCalls;
#endif
        ++g_blockMoveCount;
        return 1;
    }
    if (trap == 0xa001) {                    // _Close: IOParam in A0, result in D0
        uint8_t* parameterBlock = (uint8_t*)regs[8];
        if (parameterBlock) {
            int16_t reference = (int16_t)read16(parameterBlock + 24);
            // Communication shutdown closes the Macintosh built-in serial
            // input/output drivers (-6 and -7).  The standalone port owns no
            // corresponding Mac driver instances, so both are already idle.
            if (reference == -6 || reference == -7) {
                regs[0] = 0;                 // noErr
                return 1;
            }
        }
    }
    if (trap == 0xa007) {                    // PBGetVInfoSync(parameter block in A0)
        if (getVolumeInfo((uint8_t*)regs[8])) {
            regs[0] = 0;                    // noErr
            if (g_stageCDepth < 89) g_stageCDepth = 89;
            return 1;
        }
    }
    if (trap == 0xa861) {                    // Random() -> signed Integer
#ifdef AITD_PROBE
        s_randomTrapPC = pc;
#endif
        write16(userStack, (uint16_t)quickDrawRandom());
        if (g_stageCDepth < 90) g_stageCDepth = 90;
        return 1;
    }
    if (trap == 0xa9f1) {                    // _UnLoadSeg(Ptr), deliberately kept resident
        if (g_stageCDepth < 2) g_stageCDepth = 2;
        return 5;                             // handled + four parameter bytes consumed
    }
    if (trap == 0xa032) {                    // FlushEvents(whichMask, stopMask) in D0
        // No Macintosh events have been enqueued before the main loop.  The
        // combined masks in D0 are still accepted exactly as a register trap;
        // live mouse/key state is not an event-queue entry and is untouched.
        if (g_stageCDepth < 79) g_stageCDepth = 79;
        return 1;
    }
    if (trap == 0xa9b4) {                    // SystemTask()
        // There are no desk accessories or System processes in the standalone
        // port.  This cooperative-loop call is the natural point to run the
        // Mac compatibility callbacks and present accumulated dirty pixels.
        serviceMacRuntime();
        if (exitChordPressed()) requestExitAfterTrap(frame);
        if (g_stageCDepth < 80) g_stageCDepth = 80;
        return 1;
    }
    if (trap == 0xa970) {                    // GetNextEvent(mask, event) -> Boolean
        uint8_t* event = (uint8_t*)read32(userStack);
        if (event) {
            writeBoolean(userStack + 6, nextEvent(read16(userStack + 4), event));
            if (exitChordPressed()) requestExitAfterTrap(frame);
            if (g_stageCDepth < 81) g_stageCDepth = 81;
            return 7;
        }
    }
    if (trap == 0xa9a0) {                    // GetResource(type:4, id:2) -> Handle result:4
        int16_t id = (int16_t)read16(userStack);
        uint32_t type = read32(userStack + 2);
        uint8_t** handle = getResource(type, id);
        write32(userStack + 6, (uint32_t)handle);
        if (handle) {
            // D0 is scratch for this Pascal Toolbox call.  System 6.0.8 leaves
            // it zero on a successful GetResource, and Vette proved original
            // code can depend on that side effect.
            regs[0] = 0;
        }
        if (g_stageCDepth < 3) g_stageCDepth = 3;
        return 7;
    }
    if (trap == 0xa9a1) {                    // GetNamedResource(type:4, name:4) -> Handle result:4
        uint8_t** handle = getNamedResource(read32(userStack + 4),
                                             (const uint8_t*)read32(userStack));
        write32(userStack + 8, (uint32_t)handle);
        if (g_stageCDepth < 51) g_stageCDepth = 51;
        return 9;
    }
    if (trap == 0xa9a3) {                    // ReleaseResource(resource)
        if (releaseResource((uint8_t**)read32(userStack))) {
            if (g_stageCDepth < 78) g_stageCDepth = 78;
            return 5;
        }
    }
    if (trap == 0xa86e) {                    // InitGraf(&qd.thePort)
        initGraf((uint8_t*)read32(userStack));
        if (g_stageCDepth < 4) g_stageCDepth = 4;
        return 5;
    }
    if (trap == 0xa8fe) {                    // InitFonts()
        initFonts();
        if (g_stageCDepth < 5) g_stageCDepth = 5;
        return 1;
    }
    if (trap == 0xa912) {                    // InitWindows()
        if (!s_qdThePort || !s_fontManager.initialized) return 0;
        initWindowManagerPort();
        if (g_stageCDepth < 6) g_stageCDepth = 6;
        return 1;
    }
    if (trap == 0xa930) {                    // InitMenus()
        if (!s_windowManager.initialized) return 0;
        initMenus();
        if (g_stageCDepth < 7) g_stageCDepth = 7;
        return 1;
    }
    if (trap == 0xa93a) {                    // DisableItem(menu, item)
        if (disableMenuItem((uint8_t**)read32(userStack + 2), read16(userStack))) {
            if (g_stageCDepth < 71) g_stageCDepth = 71;
            return 7;
        }
    }
    if (trap == 0xa939) {                    // EnableItem(menu, item)
        if (enableMenuItem((uint8_t**)read32(userStack + 2), read16(userStack)))
            return 7;
    }
    if (trap == 0xa945) {                    // CheckItem(menu, item, checked)
        if (checkMenuItem((uint8_t**)read32(userStack + 4), read16(userStack + 2),
                          read16(userStack) != 0)) {
            if (g_stageCDepth < 92) g_stageCDepth = 92;
            return 9;
        }
    }
    if (trap == 0xa93e) {                    // MenuKey(key) -> menuID/item
        write32(userStack + 2, menuKey((uint8_t)read16(userStack)));
        return 3;
    }
    if (trap == 0xa938) {                    // HiliteMenu(menuID)
        // Keyboard equivalents conventionally finish with HiliteMenu(0).
        // Retain that manager state even though this port deliberately has no
        // pull-down-menu UI to invert on screen.
        s_menuManager.highlightedID = (int16_t)read16(userStack);
        return 3;
    }
    if (trap == 0xa931) {                    // NewMenu(id, title) -> MenuHandle
        uint8_t** menu = newMenu((int16_t)read16(userStack + 4),
                                 (const uint8_t*)read32(userStack));
        write32(userStack + 6, (uint32_t)menu);
        if (menu) {
            if (g_stageCDepth < 72) g_stageCDepth = 72;
            return 7;
        }
    }
    if (trap == 0xa933) {                    // AppendMenu(menu, itemList)
        if (appendMenu((uint8_t**)read32(userStack + 4),
                       (const uint8_t*)read32(userStack))) {
            if (g_stageCDepth < 73) g_stageCDepth = 73;
            return 9;
        }
    }
    if (trap == 0xa94d) {                    // AddResMenu(menu, type)
        if (addResourceMenu((uint8_t**)read32(userStack + 4), read32(userStack))) {
            if (g_stageCDepth < 74) g_stageCDepth = 74;
            return 9;
        }
    }
    if (trap == 0xa935) {                    // InsertMenu(menu, beforeID)
        if (insertMenu((uint8_t**)read32(userStack + 2), (int16_t)read16(userStack))) {
            if (g_stageCDepth < 75) g_stageCDepth = 75;
            return 7;
        }
    }
    if (trap == 0xa9bf) {                    // GetMenu(resourceID) -> MenuHandle
        uint8_t** menu = getMenu((int16_t)read16(userStack));
        write32(userStack + 2, (uint32_t)menu);
        if (menu) {
            if (g_stageCDepth < 76) g_stageCDepth = 76;
            return 3;
        }
    }
    if (trap == 0xa937) {                    // DrawMenuBar()
        // Keep the installed MENU records and MenuKey dispatcher, but do not
        // reproduce the Macintosh desktop chrome on the Amiga display.
        if (s_menuManager.initialized) {
            if (g_stageCDepth < 77) g_stageCDepth = 77;
            return 1;
        }
    }
    if (trap == 0xa9cc) {                    // TEInit()
        initTextEdit();
        if (g_stageCDepth < 8) g_stageCDepth = 8;
        return 1;
    }
    if (trap == 0xa97b) {                    // InitDialogs(resumeProc)
        initDialogs((uint8_t*)read32(userStack));
        if (g_stageCDepth < 9) g_stageCDepth = 9;
        return 5;
    }
    if (trap == 0xa850) {                    // InitCursor()
        initCursor();
        if (g_stageCDepth < 10) g_stageCDepth = 10;
        return 1;
    }
    if (trap == 0xa852) {                    // HideCursor()
        s_cursor.visible = false;
        publishMouseCursor();
        if (g_stageCDepth < 93) g_stageCDepth = 93;
        return 1;
    }
    if (trap == 0xa853) {                    // ShowCursor()
        s_cursor.visible = true;
        publishMouseCursor();
        if (g_stageCDepth < 94) g_stageCDepth = 94;
        return 1;
    }
    if (trap == 0xa746) {                    // GetToolTrapAddress(D0) -> A0
        regs[8] = (uint32_t)getToolTrapAddress((uint16_t)regs[0]);
        regs[0] = 0;
        if (g_stageCDepth < 11) g_stageCDepth = 11;
        return 1;
    }
    if (trap == 0xa346) {                    // GetOSTrapAddress
        uint16_t target = 0xa000 | (regs[0] & 0xff);
        regs[8] = (uint32_t)getTrapAddress(target);
        regs[0] = 0;
        return 1;
    }
    if (trap == 0xa146) {                    // GetTrapAddress(D0) -> A0
        regs[8] = (uint32_t)getTrapAddress((uint16_t)regs[0]);
        regs[0] = 0;
        if (g_stageCDepth < 47) g_stageCDepth = 47;
        return 1;
    }
    if (trap == 0xa047) {                    // SetTrapAddress(A0, D0)
        setTrapAddress((uint16_t)regs[0], (uint8_t*)regs[8]);
        regs[0] = 0;
        if (g_stageCDepth < 48) g_stageCDepth = 48;
        return 1;
    }

    if (trap == 0xa997) {                    // OpenResFile(name: Str255) -> refNum
        write16(userStack + 4, (uint16_t)openResourceFile((uint8_t*)read32(userStack)));
        if (g_stageCDepth < 13) g_stageCDepth = 13;
        return 5;
    }

    if (trap == 0xa874) {                    // GetPort(VAR port)
        write32((uint8_t*)read32(userStack), read32(s_qdThePort));
        if (g_stageCDepth < 16) g_stageCDepth = 16;
        return 5;
    }
    if (trap == 0xa1ad) {                    // Gestalt: D0 selector -> D0.W error, A0 response
        // Measured Mac IIx/System 7.5.5 answers; unknown selectors remain stops.
        uint32_t answer=0,error=0;
        bool known=true;
        switch(regs[0]) {
        case 0x73797376: answer=0x0755;break; // sysv
        case 0x70726f63: answer=4;break;      // proc: reference 68030
        case 0x71642020: answer=0x0230;break; // qd  : 32-bit QuickDraw
        case 0x68656c70:                     // help
        case 0x666f6c64:                     // fold
        case 0x65766e74: answer=1;break;      // evnt
        case 0x7174696d: error=0xea51;break;  // qtim: undefined selector (-5551)
        case 0x612f7578: error=0xea52;break;  // a/ux: unknown answer (-5550)
        default: known=false;break;
        }
        if(known) { regs[0]=error;regs[8]=answer;return 1; }
    }
    if (trap == 0xa090 && (uint16_t)regs[0] == 1 && regs[8]) {
        // Complete captured SysEnvRec, Core+$3BCE. Volume reference is mapped
        // by the File Manager catalog (M2.1); it is not an AmigaDOS handle.
        static const uint8_t environment[16]={
            0x00,0x01,0x00,0x05,0x07,0x55,0x00,0x04,
            0x01,0x01,0x00,0x05,0x00,0x3a,0x80,0x53
        };
        for(uint16_t i=0;i<16;++i)((uint8_t*)regs[8])[i]=environment[i];
        regs[0]=0;
        if (g_stageCDepth < 17) g_stageCDepth = 17;
        return 1;
    }
    if (trap == 0xaa32) {                    // GetGDevice() -> GDHandle
        write32(userStack, (uint32_t)&s_mainDeviceMaster);
        if (g_stageCDepth < 18) g_stageCDepth = 18;
        return 1;
    }
    if (trap == 0xaa2e) {                    // InitGDevice(refNum, mode, device)
        uint8_t** deviceHandle = (uint8_t**)read32(userStack);
        int16_t refNum = (int16_t)read16(userStack + 8);
        if (deviceHandle == &s_mainDeviceMaster && *deviceHandle == s_mainDevice
            && refNum == (int16_t)read16(s_mainDevice)) {
            write32(s_mainDevice + 42, read32(userStack + 4)); // gdMode
            if (g_stageCDepth < 67) g_stageCDepth = 67;
            return 11;
        }
    }

    if (trap == 0xa994) {                    // CurResFile() -> refNum
        write16(userStack, s_resourceFileRefs[s_currentResourceFork]);
        if (g_stageCDepth < 21) g_stageCDepth = 21;
        return 1;
    }
    if (trap == 0xa998) {                    // UseResFile(refNum)
        int16_t ref=(int16_t)read16(userStack);
        uint16_t fork=0;
        while(fork<s_resourceForks.forkCount() && s_resourceFileRefs[fork]!=ref)++fork;
        if (fork < s_resourceForks.forkCount()) {
            s_currentResourceFork = fork;
            resourceResult(0);
        } else {
            resourceResult(-193);    // resFNotFound
        }
        if (g_stageCDepth < 22) g_stageCDepth = 22;
        return 3;
    }

    if (trap == 0xa03b) {                    // Delay(ticks in A0) -> final ticks in D0
#ifdef AITD_PROBE
        ++g_probeDelayCalls;
        g_probeDelayRequested += regs[8];
#endif
        uint32_t target = g_macTicks + regs[8];
        while ((int32_t)(g_macTicks - target) < 0) { }
        regs[0] = g_macTicks;
        if (g_stageCDepth < 42) g_stageCDepth = 42;
        return 1;
    }
    if ((trap & 0xf9ff) == 0xa03c) {          // CmpString / EqualString register trap
        uint16_t firstLength = (uint16_t)(regs[0] >> 16);
        uint16_t secondLength = (uint16_t)regs[0];
        bool equal = equalMacRomanStrings((const uint8_t*)regs[8], firstLength,
                                           (const uint8_t*)regs[9], secondLength,
                                           (trap & 0x0400) != 0, (trap & 0x0200) != 0);
        regs[0] = equal ? 0 : 1;              // ROM result; glue flips it for EqualString
        if (g_stageCDepth < 53) g_stageCDepth = 53;
        return 1;
    }
    if (trap == 0xa033) {                    // VInstall(VBLTaskPtr in A0) -> OSErr in D0
        regs[0] = (uint32_t)(int32_t)installVBLTask((uint8_t*)regs[8]);
        if (g_stageCDepth < 44) g_stageCDepth = 44;
        return 1;
    }
    if (trap == 0xa034) {                    // VRemove(VBLTaskPtr in A0) -> OSErr in D0
        regs[0] = (uint32_t)(int32_t)removeVBLTask((uint8_t*)regs[8]);
        if (g_stageCDepth < 95) g_stageCDepth = 95;
        return 1;
    }
    if (trap == 0xaa46) {                    // GetNewCWindow(id, storage, behind) -> WindowPtr
        uint8_t* window = newColorWindow((int16_t)read16(userStack + 8),
                                         (uint8_t*)read32(userStack + 4),
                                         (uint8_t*)read32(userStack));
        write32(userStack + 10, (uint32_t)window);
        if (g_stageCDepth < 24) g_stageCDepth = 24;
        return 11;
    }
    if (trap == 0xa91b) {                    // MoveWindow(window, h, v, front)
        moveWindow((uint8_t*)read32(userStack + 6),
                   (int16_t)read16(userStack + 4), (int16_t)read16(userStack + 2),
                   userStack[0] != 0);
        if (g_stageCDepth < 25) g_stageCDepth = 25;
        return 11;
    }
    if (trap == 0xa914) {                    // DisposeWindow(window)
        if (disposeWindow((uint8_t*)read32(userStack))) {
            if (g_stageCDepth < 66) g_stageCDepth = 66;
            return 5;
        }
    }
    if (trap == 0xa90d) {                    // PaintBehind(startWindow, clobberedRgn)
        uint8_t* first = (uint8_t*)read32(userStack);
        uint8_t* second = (uint8_t*)read32(userStack + 4);
        // MPW's glue leaves the WindowPtr nearest the return slot for this
        // Toolbox procedure.  Resolve by record identity as a guard against
        // repeating the Pascal declaration order at the raw stack boundary.
        uint8_t* window = windowSlot(first) ? first : second;
        uint8_t** region = (uint8_t**)(window == first ? second : first);
        if (paintBehind(window, region)) {
            if (g_stageCDepth < 68) g_stageCDepth = 68;
            return 9;
        }
    }
    if (trap == 0xa873) {                    // SetPort(GrafPtr)
        write32(s_qdThePort, read32(userStack));
        if (g_stageCDepth < 26) g_stageCDepth = 26;
        return 5;
    }
    if (trap == 0xa871) {                    // GlobalToLocal(Point*)
        uint8_t* point = (uint8_t*)read32(userStack);
        if (point) {
            write16(point, (uint16_t)((int16_t)read16(point) - 91));
            write16(point + 2, (uint16_t)((int16_t)read16(point + 2) - 64));
        }
        if (g_stageCDepth < 83) g_stageCDepth = 83;
        return 5;
    }
    if (trap == 0xa8a7) {                    // SetRect(Rect*, left, top, right, bottom)
        uint8_t* rectangle = (uint8_t*)read32(userStack + 8);
        int16_t bottom = (int16_t)read16(userStack);
        int16_t right = (int16_t)read16(userStack + 2);
        int16_t top = (int16_t)read16(userStack + 4);
        int16_t left = (int16_t)read16(userStack + 6);
        if (rectangle) {
            writeRect(rectangle, top, left, bottom, right);
        }
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 13;
    }
    if (trap == 0xa8ad) {                    // PtInRect(Point, Rect*) -> Boolean
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        int16_t vertical = (int16_t)read16(userStack + 4);
        int16_t horizontal = (int16_t)read16(userStack + 6);
        bool inside = rectangle
            && vertical >= (int16_t)read16(rectangle)
            && horizontal >= (int16_t)read16(rectangle + 2)
            && vertical < (int16_t)read16(rectangle + 4)
            && horizontal < (int16_t)read16(rectangle + 6);
        userStack[8] = inside ? 1 : 0;
        if (g_stageCDepth < 84) g_stageCDepth = 84;
        return 9;
    }
    if (trap == 0xa972) {                    // GetMouse(Point*)
        uint8_t* point = (uint8_t*)read32(userStack);
        if (point) {
            write16(point, (uint16_t)s_mouseY);
            write16(point + 2, (uint16_t)s_mouseX);
        }
        if (g_stageCDepth < 86) g_stageCDepth = 86;
        return 5;
    }
    if (trap == 0xa973) {                    // StillDown() -> Boolean
        // Macintosh Boolean is an 8-bit type in a word-aligned result slot.
        // Some Vette callers test the byte and others test the whole word, so
        // place the value in the first (big-endian) byte and clear the pad.
        writeBoolean(userStack, AmigaHardware::isLeftMouseButtonPressed());
        if (exitChordPressed()) requestExitAfterTrap(frame);
        if (g_stageCDepth < 87) g_stageCDepth = 87;
        return 1;
    }
    if (trap == 0xa8a4) {                    // InvertRect(Rect*)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (invertRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 85) g_stageCDepth = 85;
            return 5;
        }
    }
    if (trap == 0xaa92) {                    // GetNewPalette(id) -> PaletteHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x706c7474UL, (int16_t)read16(userStack))); // 'pltt'
        if (g_stageCDepth < 27) g_stageCDepth = 27;
        return 3;
    }
    if (trap == 0xaa93) {                    // DisposePalette(palette)
        uint8_t** palette = (uint8_t**)read32(userStack);
        for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i) {
            if (!s_windows[i].used || s_windows[i].palette != palette) continue;
            s_windows[i].palette = 0;
            s_windows[i].paletteUpdates = false;
        }
        for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
            if (s_gworlds[i].used && s_gworlds[i].palette == palette)
                s_gworlds[i].palette = 0;
        if (s_activePalette == palette) s_activePalette = 0;
        // GetNewPalette is represented by the corresponding 'pltt' resource
        // master. Releasing it provides the Palette Manager ownership boundary;
        // a later request can materialize the same resource again.
        releaseResource(palette);
        if (g_stageCDepth < 96) g_stageCDepth = 96;
        return 5;
    }
    if (trap == 0xaa28) {                    // GetCTSeed() -> unique long seed
        write32(userStack, s_colorSeed++);
        if (g_stageCDepth < 28) g_stageCDepth = 28;
        return 1;
    }
    if (trap == 0xaa39) {                    // MakeITable(cTab, iTab, resolution)
        if (makeITable((uint8_t**)read32(userStack + 6),
                       (uint8_t**)read32(userStack + 2), read16(userStack))) {
            if (g_stageCDepth < 88) g_stageCDepth = 88;
            return 11;
        }
    }
    if (trap == 0xaa95) {                    // SetPalette(window, palette, update)
        uint8_t* window = (uint8_t*)read32(userStack + 6);
        WindowSlot* slot = windowSlot(window);
        if (slot) {
            slot->palette = (uint8_t**)read32(userStack + 2);
            slot->paletteUpdates = userStack[0] != 0;
            // Palette Manager immediately activates a palette attached to the
            // frontmost window; waiting for an explicit ActivatePalette leaves
            // drawing mapped through the preceding scene's colors.
            if (s_windowList == window) activatePalette(window);
        } else if (GWorldSlot* world = gWorldForPort(window)) {
            world->palette = (uint8_t**)read32(userStack + 2);
            // System 6 realizes a courteous offscreen palette association
            // immediately enough to put the GWorld in the current device
            // environment. Vette's final road setup does not follow this
            // SetPalette with ActivatePalette. The GWorld deliberately keeps
            // its old RGB snapshot while sharing the screen seed, so the next
            // full-surface CopyBits preserves renderer-authored pixel indices.
            write32(world->colorTable, read32(s_windowManagerColors));
        }
        if (g_stageCDepth < 29) g_stageCDepth = 29;
        return 11;
    }
    if (trap == 0xaa94) {                    // ActivatePalette(window)
        activatePalette((uint8_t*)read32(userStack));
        s_screenDirty = true;
        if (g_stageCDepth < 30) g_stageCDepth = 30;
        return 5;
    }
    if (trap == 0xa915) {                    // ShowWindow(window)
        uint8_t* window = (uint8_t*)read32(userStack);
        if (windowSlot(window)) window[110] = 1;
        if (g_stageCDepth < 31) g_stageCDepth = 31;
        return 5;
    }
    if (trap == 0xa916) {                    // HideWindow(window)
        uint8_t* window = (uint8_t*)read32(userStack);
        if (windowSlot(window)) {
            window[110] = 0;
            if (g_stageCDepth < 91) g_stageCDepth = 91;
            return 5;
        }
    }
    if (trap == 0xa924) {                    // FrontWindow() -> WindowPtr
        uint8_t* front = s_windowList;
        while (front && !front[110]) front = (uint8_t*)read32(front + 144);
        write32(userStack, (uint32_t)front);
        if (g_stageCDepth < 82) g_stageCDepth = 82;
        return 1;
    }
    if (trap == 0xa925) {                    // DragWindow(window, start, limits)
        // The standalone Amiga port owns one fixed game surface, not a desktop
        // windowing system.  Classic Vette routes harmless unclaimed content
        // clicks here; consume the parameters and leave the surface in place.
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 13;
    }
    if (trap == 0xa92c) {                    // FindWindow(Point, WindowPtr*) -> part code
        uint8_t** resultWindow = (uint8_t**)read32(userStack);
        int16_t vertical = (int16_t)read16(userStack + 4);
        int16_t horizontal = (int16_t)read16(userStack + 6);
        uint8_t* found;
        int16_t part = findWindow(vertical, horizontal, found);
        if (resultWindow) write32((uint8_t*)resultWindow, (uint32_t)found);
        write16(userStack + 8, (uint16_t)part);
        if (g_stageCDepth < 96) g_stageCDepth = 96;
        return 9;
    }
    if (trap == 0xa91f) {                    // SelectWindow(window)
        uint8_t* window = (uint8_t*)read32(userStack);
        for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
            if (s_windows[i].used)
                s_windows[i].window[111] = s_windows[i].window == window;
        s_windowList = window;
        activatePalette(window);             // front windows activate their palette automatically
        if (g_stageCDepth < 32) g_stageCDepth = 32;
        return 5;
    }
    if (trap == 0xa922) {                    // BeginUpdate(window)
        WindowSlot* slot = windowSlot((uint8_t*)read32(userStack));
        if (slot) slot->updating = true;
        if (g_stageCDepth < 33) g_stageCDepth = 33;
        return 5;
    }
    if (trap == 0xa923) {                    // EndUpdate(window)
        WindowSlot* slot = windowSlot((uint8_t*)read32(userStack));
        if (slot) {
            slot->updating = false;
            initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
        }
        if (g_stageCDepth < 34) g_stageCDepth = 34;
        return 5;
    }
    if (trap == 0xa889) {                    // TextMode(mode)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 72, read16(userStack));
        if (g_stageCDepth < 35) g_stageCDepth = 35;
        return 3;
    }
    if (trap == 0xa887) {                    // TextFont(font)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 68, read16(userStack));
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 3;
    }
    if (trap == 0xa888) {                    // TextFace(face)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) port[70] = userStack[1];
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 3;
    }
    if (trap == 0xa88a) {                    // TextSize(size)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 74, read16(userStack));
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 3;
    }
    if (trap == 0xa88e) {                    // SpaceExtra(extra: Fixed)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write32(port + 76, read32(userStack));
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 5;
    }
    if (trap == 0xa893) {                    // MoveTo(horizontal, vertical)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) {
            write16(port + 48, read16(userStack));
            write16(port + 50, read16(userStack + 2));
        }
        if (g_stageCDepth < 97) g_stageCDepth = 97;
        return 5;
    }
    if (trap == 0xa884) {                    // DrawString(Pascal string)
        const uint8_t* string = (const uint8_t*)read32(userStack);
        int16_t top, left, bottom, right;
        if (string && drawQuickDrawText(string + 1, string[0], top, left, bottom, right)) {
            if (currentPortIsScreen()) markDirtyBounds(top, left, bottom, right);
            if (g_stageCDepth < 97) g_stageCDepth = 97;
            return 5;
        }
    }
    if (trap == 0xa883) {                    // DrawChar(character)
        uint8_t character = userStack[1];
        int16_t top, left, bottom, right;
        if (drawQuickDrawText(&character, 1, top, left, bottom, right)) {
            if (currentPortIsScreen()) markDirtyBounds(top, left, bottom, right);
            if (g_stageCDepth < 97) g_stageCDepth = 97;
            return 3;
        }
    }
    if (trap == 0xa885) {                    // DrawText(text, firstByte, byteCount)
        const uint8_t* text = (const uint8_t*)read32(userStack + 4);
        uint16_t firstByte = read16(userStack + 2);
        uint16_t byteCount = read16(userStack);
        int16_t top, left, bottom, right;
        if (text && drawQuickDrawText(text + firstByte, byteCount,
                                      top, left, bottom, right)) {
            if (currentPortIsScreen()) markDirtyBounds(top, left, bottom, right);
            if (g_stageCDepth < 97) g_stageCDepth = 97;
            return 9;
        }
    }
    if (trap == 0xa89b) {                    // PenSize(horizontal, vertical)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) {
            write16(port + 52, read16(userStack));
            write16(port + 54, read16(userStack + 2));
        }
        if (g_stageCDepth < 58) g_stageCDepth = 58;
        return 5;
    }
    if (trap == 0xa89c) {                    // PenMode(mode)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 56, read16(userStack));
        if (g_stageCDepth < 59) g_stageCDepth = 59;
        return 3;
    }
    if (trap == 0xa87b) {                    // ClipRect(Rect*)
        if (clipRect((const uint8_t*)read32(userStack))) {
            if (g_stageCDepth < 63) g_stageCDepth = 63;
            return 5;
        }
    }
    if (trap == 0xa974) {                    // Button() -> Boolean
        serviceMacRuntime();
        bool pressed = AmigaHardware::isLeftMouseButtonPressed();
        writeBoolean(userStack, pressed);
        if (exitChordPressed()) requestExitAfterTrap(frame);
        if (g_stageCDepth < 64) g_stageCDepth = 64;
        return 1;
    }
    if (trap == 0xa8a1) {                    // FrameRect(rectangle)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (frameRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 60) g_stageCDepth = 60;
            return 5;
        }
    }
    if (trap == 0xa8a2) {                    // PaintRect(rectangle)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (paintRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            return 5;
        }
    }
    if (trap == 0xa8a3) {                    // EraseRect(rectangle)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (eraseRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 62) g_stageCDepth = 62;
            return 5;
        }
    }
    if (trap == 0xa9b9) {                    // GetCursor(id) -> CursHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x43555253UL, (int16_t)read16(userStack))); // 'CURS'
        if (g_stageCDepth < 36) g_stageCDepth = 36;
        return 3;
    }
    if (trap == 0xa9bc) {                    // GetPicture(id) -> PicHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x50494354UL, (int16_t)read16(userStack))); // 'PICT'
        if (g_stageCDepth < 56) g_stageCDepth = 56;
        return 3;
    }
    if (trap == 0xa8f6) {                    // DrawPicture(PicHandle, destination Rect)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
#ifdef AITD_PROBE
        uint32_t drawPictureStart = aitdProfileBeamEpoch();
        uint16_t drawPictureTraceIndex = (uint16_t)(g_probeDrawPictureCalls & 63);
        int32_t drawPictureResourceIndex
            = resourceHandleIndex((uint8_t**)read32(userStack + 4));
        ResourceForks::Item drawPictureItem;
        g_probeDrawPictureTrace[drawPictureTraceIndex][0]
            = drawPictureResourceIndex >= 0
                && s_resourceForks.item((uint32_t)drawPictureResourceIndex, drawPictureItem)
              ? drawPictureItem.id : -1;
        for (uint16_t i = 0; i < 4; ++i)
            g_probeDrawPictureTrace[drawPictureTraceIndex][1 + i]
                = rectangle ? (int16_t)read16(rectangle + i * 2) : 0;
#endif
        bool pictureDrawn = drawPicture((uint8_t**)read32(userStack + 4), rectangle);
#ifdef AITD_PROBE
        uint32_t drawPictureTicks = aitdProfileBeamEpoch() - drawPictureStart;
        g_probeDrawPictureTraceTicks[drawPictureTraceIndex] = drawPictureTicks;
        g_probeDrawPictureTicks += drawPictureTicks;
        ++g_probeDrawPictureCalls;
#endif
        if (pictureDrawn) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 57) g_stageCDepth = 57;
            return 9;
        }
    }
    if (trap == 0xa8ec) {                    // CopyBits(src, dst, srcRect, dstRect, mode, mask)
        const uint8_t* destinationRect = (const uint8_t*)read32(userStack + 6);
        const uint8_t* destinationBitmap = (const uint8_t*)read32(userStack + 14);
        const uint8_t* sourceBitmap = (const uint8_t*)read32(userStack + 18);
        const uint8_t* sourceRect = (const uint8_t*)read32(userStack + 10);
        uint16_t mode = read16(userStack + 4);
        const uint8_t* maskRegion = (const uint8_t*)read32(userStack);
#ifdef AITD_PROBE
        bool traceCopy = g_probeCopyTraceEnabled;
        if (traceCopy && g_probeCopyTraceCount < 32) {
            uint16_t trace = g_probeCopyTraceCount++;
            g_probeCopyTrace[trace][0] = (int16_t)mode;
            if (sourceRect)
                for (uint16_t i = 0; i < 4; ++i)
                    g_probeCopyTrace[trace][1 + i]
                        = (int16_t)read16(sourceRect + i * 2);
            if (destinationRect)
                for (uint16_t i = 0; i < 4; ++i)
                    g_probeCopyTrace[trace][5 + i]
                        = (int16_t)read16(destinationRect + i * 2);
            g_probeCopyTrace[trace][9] = sourceBitmap == destinationBitmap;
            g_probeCopyTrace[trace][10] = bitmapIsScreen(destinationBitmap);
            g_probeCopyTrace[trace][11] = bitmapIsScreen(sourceBitmap);
        }
#endif
        // CopyBits owns an exact destination rectangle and publishes it once
        // below. Its packed fast paths use BlockMove row by row; letting that
        // generic hook mark the screen would rebuild and merge the same dirty
        // rectangle once per scanline.
        // Direct BlockMove calls outside CopyBits retain their conservative
        // dirty tracking.
        s_suppressDirectScreenDirty = true;
        bool copied;
        {
#ifdef AITD_PROBE
            AitdProfileScope profileCopyBits(kProfileCopyBits);
            uint32_t copyBitsStart = aitdProfileBeamEpoch();
#endif
            copied = false;
            if (!copied)
                copied = copyBits(sourceBitmap, destinationBitmap, sourceRect,
                                  destinationRect, mode, maskRegion);
#ifdef AITD_PROBE
            uint32_t copyBitsTicks = aitdProfileBeamEpoch() - copyBitsStart;
            g_probeCopyBitsTicks += copyBitsTicks;
            ++g_probeCopyBitsCalls;
            if (mode < 7) {
                g_probeCopyModeTicks[mode] += copyBitsTicks;
                ++g_probeCopyModeCalls[mode];
            }
#endif
        }
        s_suppressDirectScreenDirty = false;
        if (copied) {
            if (bitmapIsScreen(destinationBitmap)) markDirty(destinationRect);
            if (g_stageCDepth < 61) g_stageCDepth = 61;
            return 23;
        }
    }
    if (trap == 0xa851) {                    // SetCursor(Cursor*)
        s_cursor.image = (const uint8_t*)read32(userStack);
        s_cursor.visible = true;
        publishMouseCursor();
        if (g_stageCDepth < 37) g_stageCDepth = 37;
        return 5;
    }
    if (trap == 0xa97c) {                    // GetNewDialog(id, storage, behind) -> DialogPtr
        uint8_t* dialog = newDialog((int16_t)read16(userStack + 8),
                                    (uint8_t*)read32(userStack + 4),
                                    (uint8_t*)read32(userStack));
        write32(userStack + 10, (uint32_t)dialog);
        if (g_stageCDepth < 38) g_stageCDepth = 38;
        return 11;
    }
    if (trap == 0xa981) {                    // DrawDialog(dialog)
        drawDialog((uint8_t*)read32(userStack));
        if (g_stageCDepth < 39) g_stageCDepth = 39;
        return 5;
    }
    if (trap == 0xa983) {                    // DisposeDialog(dialog)
        disposeDialog((uint8_t*)read32(userStack));
        if (g_stageCDepth < 55) g_stageCDepth = 55;
        return 5;
    }
    if (trap == 0xab1d && (uint16_t)regs[0] == 0) {    // QDExtensions: NewGWorld
        const uint8_t* bounds = (const uint8_t*)read32(userStack + 12);
        uint8_t* world = newGWorld(bounds, read16(userStack + 16));
        write32((uint8_t*)read32(userStack + 18), (uint32_t)world);
        write16(userStack + 22, world ? 0 : (uint16_t)-108);
        if (g_stageCDepth < 40) g_stageCDepth = 40;
        return 23;
    }
    if (trap == 0xab1d && (uint16_t)regs[0] == 1) {    // QDExtensions: LockPixels
        GWorldSlot* world = gWorldForPixMap((uint8_t**)read32(userStack));
        if (world) world->locked = true;
        userStack[4] = world ? 1 : 0;
        if (g_stageCDepth < 40) g_stageCDepth = 40;
        return 5;
    }
    if (trap == 0xab1d && (uint16_t)regs[0] == 12) {   // QDExtensions: NoPurgePixels
        GWorldSlot* world = gWorldForPixMap((uint8_t**)read32(userStack));
        if (world) world->purgeable = false;
        return 5;
    }

    g_stageBState = 3;
    g_trapWord = trap;
    g_trapPC = pc;
    for (uint16_t i = 0; i < 15; ++i) g_trapRegisters[i] = regs[i];
    g_trapUserStack = (uint32_t)userStack;
    g_trapSelector = -1;
    g_trapSegment = 0xffff;
    g_trapOffset = 0xffffffffUL;
    const char* segmentName = "UNKNOWN";
    for (uint16_t i = 1; i < s_segmentCount; ++i) {
        uint32_t lo = (uint32_t)s_segments[i].begin;
        uint32_t hi = (uint32_t)s_segments[i].end;
        if (pc >= lo && pc < hi) {
            g_trapSegment = i; g_trapOffset = pc - lo; segmentName = s_segments[i].name;
            break;
        }
    }
    const char* manager = "UNKNOWN MANAGER";
    const char* routine = "UNKNOWN TRAP";
    for (uint16_t i = 0; i < sizeof(s_trapNames) / sizeof(s_trapNames[0]); ++i)
        if (s_trapNames[i].word == trap) {
            manager = s_trapNames[i].manager; routine = s_trapNames[i].routine; break;
        }
    if (trap == 0xa9c9 || trap == 0xa198) g_trapSelector = (uint16_t)regs[0];
    if (trap == 0xab1d) g_trapSelector = (uint16_t)regs[0];
    if (trap == 0xa823) g_trapSelector=(uint16_t)regs[0];
    if (trap == 0xa1ad) g_trapSelector = (int32_t)regs[0];
    if (trap == 0xa260) {
        g_trapSelector=(uint16_t)regs[0];
        if(g_trapSelector==1)routine="OPENWD";
        if(g_trapSelector==2)routine="CLOSEWD";
        if(g_trapSelector==7)routine="GETWDINFO";
        if(g_trapSelector==8)routine="GETFCBINFO";
    }
    copyString(g_trapManager, manager);
    copyString(g_trapRoutine, routine);
    if (s_loudStopScreen)
        s_loudStopScreen->showLoudStop(manager, routine, g_trapSelector,
                                       segmentName, g_trapOffset, trap);
    for (;;) { }                             // VBI remains enabled, so the report stays live
}

// Called by RTE in user mode. Shift the parked register/CCR/PC image over
// consumed Pascal arguments, then let assembly restore it and RTS normally.
extern "C" uint8_t* aitdUserServiceDispatch(uint8_t* parked)
{
    ++g_macServiceEntered;
    uint32_t result=dispatchMacTrap(s_userService.trap,s_userService.builtin,
        (uint32_t*)parked,s_userService.frame,s_userService.arguments,true);
    if(!result || result>0x7fff) {
        loaderStop("USER SERVICE RETURN ABI",0);showLoaderStop();
    }
    uint32_t cleanup=result-1;
    if(s_userService.builtin && (s_userService.trap&0x0800))
        write32(s_userService.arguments-4+cleanup,s_userService.toolboxReturn);
    uint16_t ccr=read16(s_userService.frame);
    if(!(s_userService.trap&0x0800)) {
        ccr&=0xfff0;
        int16_t d0=(int16_t)read16(parked+2);
        if(d0<0)ccr|=8;else if(!d0)ccr|=4;
    }
    write16(parked+60,ccr);
    uint32_t returnPC=read32(s_userService.frame+2)+2;
    g_macServiceActive=0;
    ++g_macServiceCompleted;
    if(g_macVBLCallbackEntry) {
        g_macVBLCallbackReturn=returnPC;
        returnPC=(uint32_t)aitd_user_vbl_trampoline;
    }
    write32(parked+62,returnPC);
    // The destination may overlap the source when a short parameter list is popped.
    for(uint16_t i=66;i;--i)parked[cleanup+i-1]=parked[i-1];
    return parked+cleanup;
}

// Private callable originals are AFFE, trap word, RTS. Validate their exact
// range/alignment so original game bytes cannot masquerade as a port stub.
extern "C" uint32_t aitdLineADispatch(uint32_t* regs, uint8_t* frame, uint8_t* userStack)
{
    uint32_t pc = read32(frame + 2);
    uint16_t trap = read16((const uint8_t*)pc);
#ifdef AITD_SERVICE_PROBE
    if(g_macServiceActive && trap==0xa055) {
        ++g_serviceProbe[0];g_serviceProbe[1]|=read16(frame)&0x2000;
    }
#endif
    uint32_t base = (uint32_t)s_trapBuiltins;
    bool builtin = trap == 0xaffe && pc >= base && pc < base + sizeof(s_trapBuiltins)
        && (pc - base) % 6 == 0;
    uint32_t returnPC = 0;
    if (builtin) {
        trap = read16((const uint8_t*)pc + 2);
        if (!(trap & 0x0800) && (regs[1] & 0xf800) == 0xa000
            && (regs[1] & 0xff) == (trap & 0xff))
            trap = (uint16_t)regs[1]; // retain OS flags passed through a patch
        write32(frame + 2, pc + 2); // normal handler increment skips the operand
        if (trap & 0x0800) {
            returnPC = read32(userStack);
            userStack += 4; // Pascal parameters lie beyond the native return PC
        }
    }
    uint32_t result = dispatchMacTrap(trap, builtin, regs, frame, userStack);
    if (builtin && (trap & 0x0800)) {
        if(result==0xffffffffUL)s_userService.toolboxReturn=returnPC;
        else write32(userStack - 4 + result - 1, returnPC);
    }
    return result;
}

const char* MacLoader::preparationError() const { return s_preparationError; }

bool MacLoader::prepareResourceForks(uint8_t* application, uint32_t applicationSize,
                                     uint8_t* data, uint32_t dataSize)
{
    s_preparationError = "RESOURCE FORK / INVALID OR UNSUPPORTED";
    for (uint16_t i = 0; i < 4096; ++i) {
        write16(s_trapBuiltins[i], 0xaffe);
        write16(s_trapBuiltins[i] + 2, 0xa000 | i);
        write16(s_trapBuiltins[i] + 4, 0x4e75);
        s_trapAddresses[i] = 0;
    }
    s_resourceForks.close();
    clearResidentSegments();
    g_resourceCount = 0;
    for(uint16_t i=0;i<ResourceForks::kMaximumResources;++i)s_resourceHandles[i]=0;
    resourceResult(0);
    if(!prepareZones()) { s_preparationError="MEMORY MANAGER / FAST RAM ZONES";return false; }
    if (!s_resourceForks.open(application, applicationSize, data, dataSize)
        || !loadStartupSegments()) {
        s_resourceForks.close();clearResidentSegments();releaseZones();return false;
    }
    s_currentResourceFork = 0;
    const MacFiles::Entry* app=s_files.child(s_files.application,"Alone In The Dark");
    if(!app || s_resourceForks.forkCount()!=1) {
        s_preparationError="CATALOG / APPLICATION FORK";
        s_resourceForks.close();clearResidentSegments();releaseZones();return false;
    }
    s_resourceFileRefs[0]=s_files.open(app->id,true,true);
    if(s_resourceFileRefs[0]<0) {
        s_preparationError="FILE TABLE / APPLICATION FORK";
        s_resourceForks.close();clearResidentSegments();releaseZones();return false;
    }
    g_applicationFileRef=s_resourceFileRefs[0];
    g_resourceCount = s_resourceForks.resourceCount();
    return true;
}

static void releaseRuntimeAllocations()
{
#ifdef AITD_PROBE
    g_probeReleasedGWorlds = 0;
    g_probeReleasedPointers = 0;
    g_probeReleasedHandles = 0;
#endif
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i) {
        GWorldSlot& world = s_gworlds[i];
        if (world.pixels) {
            FreeMem(world.pixels, s_gworldAllocationBytes[i]);
#ifdef AITD_PROBE
            ++g_probeReleasedGWorlds;
#endif
        }
        world.pixels = 0;
        s_gworldAllocationBytes[i] = 0;
        world.used = false;
        world.locked = false;
        world.purgeable = false;
        world.palette = 0;
    }

}

#ifdef AITD_PROBE
extern "C" __attribute__((noinline)) void aitdRuntimeAllocationsReleased()
{
    __asm__ volatile("" : : : "memory");
}
#endif

bool MacLoader::releaseResourceForks()
{
    bool closed=true;
    // Platform has restored OS scheduling, vectors and display before this call.
    for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(s_dataSources[i].id) {
        DataSource& source=s_dataSources[i];
        if(flushDataSource(source,*source.backing,true))closed=false;
        source.writes.clear();source.id=0;source.backing=0;
    }
    for(uint16_t i=0;i<MacFiles::maxOpen;++i)if(s_dataForks[i].ref) {
        DataFork& f=s_dataForks[i];
        if(FileAccess::closeRestoredStream(f.stream))closed=false;
        f.source=0;
        if(f.buffer)FreeMem(f.buffer,FileReadCache::capacity);f.buffer=0;f.ref=0;
    }
    s_files.reset();g_applicationFileRef=0;
    releaseRuntimeAllocations();
#ifdef AITD_PROBE
    aitdRuntimeAllocationsReleased();
#endif
    s_resourceForks.close();
    clearResidentSegments();
    releaseZones();
    releaseA5World();
    if (g_macStackBase) FreeMem(g_macStackBase, 65536);
    g_macStackBase = 0;
    g_macTicksAddress = 0;
    g_macRndSeedAddress = 0;
    g_resourceCount = 0;
    return closed;
}

// A loader failure is reported like an unimplemented trap: named on screen
// and held there, rather than returning quietly to the Workbench.
static void showLoaderStop()
{
    g_stageBState = 2;
    g_trapSegment = s_loaderStopSegment;
    copyString(g_trapManager, "SEGMENT LOADER");
    copyString(g_trapRoutine, s_loaderStopReason ? s_loaderStopReason : "UNKNOWN");
    const char* segmentName = s_segments[s_loaderStopSegment].name;
    if (s_loudStopScreen)
        s_loudStopScreen->showLoudStop(g_trapManager, g_trapRoutine, -1,
                                       segmentName[0] ? segmentName : "UNKNOWN", 0, 0);
    for (;;) { }                             // VBI remains enabled, so the report stays live
}

static void installLineAVector()
{
    g_macLineAVectorAddress = (uint32_t)AmigaHardware::getVBR() + 0x28;
    Disable();
    volatile uint32_t* vector = (volatile uint32_t*)g_macLineAVectorAddress;
    g_macSavedLineAVector = *vector;
    *vector = (uint32_t)aitd_line_a_handler;
    g_macLineAInstalled = 1;
    Enable();
}

static void restoreLineAVector()
{
    Disable();
    *(volatile uint32_t*)g_macLineAVectorAddress = g_macSavedLineAVector;
    g_macLineAInstalled = 0;
    Enable();
}

bool aitdMacSuspendLineA()
{
    if(!g_macLineAInstalled || !g_macServiceActive)return false;
    restoreLineAVector();return true;
}
void aitdMacResumeLineA() { installLineAVector(); }

bool MacLoader::run(AitdScreen* screen)
{
    s_loudStopScreen = screen;
    if (!s_resourceForks.resourceCount()) return false;

    if (!g_macStackBase) g_macStackBase = (uint8_t*)AllocMem(65536, MEMF_ANY);
    if (!g_macStackBase) {
        loaderStop("MAC STACK MEMORY", 0);
        showLoaderStop();
    }
#ifdef AITD_LINE_A_PROBE
    // Native unit-style trap calls: no original code or game decisions replaced.
    installLineAVector();
    aitd_call_mac_code((void*)aitd_line_a_probe, (void*)0x12345678,
                      g_macStackBase + 65536);
    restoreLineAVector();
    g_lineAProbe[6] = g_macLineAInstalled == 0
        && *(volatile uint32_t*)g_macLineAVectorAddress == g_macSavedLineAVector;
    installLineAVector();
    aitd_call_mac_code((void*)aitd_line_a_exit_probe, (void*)0x12345678,
                      g_macStackBase + 65536);
    restoreLineAVector();
    g_lineAProbe[7] = g_macLineAInstalled == 0 && g_macHostReturnSP == 0
        && *(volatile uint32_t*)g_macLineAVectorAddress == g_macSavedLineAVector;
    aitdLineAProbeComplete();
#endif
    for (uint16_t i = 0; i < MacLowMemory::size; ++i) s_portLowMemory[i] = 0;
    uint8_t* a5 = 0;
    bool a5Ready = buildA5World(a5);
#ifdef AITD_LINE_A_PROBE
    g_lineAProbe[10] = read32(s_portLowMemory + kLowCurrentA5);
    g_lineAProbe[11] = read32(s_portLowMemory + kLowCurStackBase);
#endif
    if (!a5Ready) showLoaderStop();
#ifdef AITD_SERVICE_PROBE
    installLineAVector();
    aitd_call_mac_code((void*)aitd_service_probe,a5,g_macStackBase+65536);
    restoreLineAVector();
    aitdServiceProbeComplete();
#endif
#ifdef AITD_IDENTITY_PROBE
    installLineAVector();
    aitd_call_mac_code((void*)aitd_identity_probe, a5, g_macStackBase + 65536);
    restoreLineAVector();
    aitdIdentityProbeReturned();
#endif
#ifdef AITD_HEAP_PROBE
    installLineAVector();
    aitd_call_mac_code((void*)aitd_heap_probe, (void*)0x12345678,
                      g_macStackBase + 65536);
    restoreLineAVector();
    aitdHeapProbeComplete();
#endif
    write32(s_portLowMemory + kLowTicks, g_macTicks);
    write32(s_portLowMemory + kLowRndSeed, g_macTicks ? g_macTicks - 1 : 0);
    // The VBI consumes these 32-bit pointers. Publish them atomically with
    // respect to the level-3 handler; a torn 68000 longword would point the
    // ISR at arbitrary memory.
    Disable();
    g_macTicksAddress = (volatile uint32_t*)(s_portLowMemory + kLowTicks);
    g_macRndSeedAddress = (volatile uint32_t*)(s_portLowMemory + kLowRndSeed);
    s_currentA5 = a5;
    Enable();
#ifdef AITD_WINDOW_PROBE
    installLineAVector();
    aitd_call_mac_code((void*)aitd_window_probe,a5,g_macStackBase+65536);
    restoreLineAVector();
#endif

#ifdef AITD_FILE_PROBE
    installLineAVector();
    aitd_call_mac_code((void*)aitdFileProbe,a5,g_macStackBase+65536);
    restoreLineAVector();
    return true; // Diagnostic exits through normal OS restoration and file cleanup.
#endif
    g_stageBState = 1;
    uint8_t* firstJump = a5 + s_jumpTableOffset;
    if (read16(firstJump + 2) != 0x4ef9) return false;
    // These segments were loaded as data, then patched together with the A5
    // JMP table. Publish dirty data and discard stale instruction-cache lines
    // before executing any of them (Exec V37+, our OS 2.04 baseline).
    // Do not disable caches: let Exec use the installed CPU support routines.
    CacheClearU();
    // Enter the original runtime, which expands DATA/DREL and installs LoadSeg.
    installLineAVector();
    aitd_call_mac_code(s_segments[1].begin + 0x14, a5, g_macStackBase + 65536);
    restoreLineAVector();
    // Leave all four Paula DACs holding signed zero before PlatformAmiga
    // restores the operating system, whichever exit route was taken.
    for (uint16_t channel = 0; channel < 4; ++channel) quiescePaulaChannel(channel);
    g_macExitState = 4;
    return true;
}
