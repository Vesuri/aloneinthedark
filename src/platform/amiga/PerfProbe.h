#ifndef AITD_PERF_PROBE_H
#define AITD_PERF_PROBE_H

// Diagnostic-only phase accounting.  All calls compile to nothing in ordinary
// builds: the profiler reads custom-chip registers and is intentionally never
// part of a quoted shipping-build frame rate.
enum AitdProfileCategory {
    kProfileDrawing = 0,
    kProfileResource,
    kProfileAudio,
    kProfileOtherTrap,
    kProfilePresent,
    kProfileSync,
    kProfileWait,
    kProfileControl,
    kProfileVBI,
    kProfileC2P,
    kProfilePalette,
    kProfileCopyBits,
    kProfilePaintRect,
    kProfileColorLookup,
    kProfileCopyMap,
    kProfileCodeViews,
    kProfileHeapPublish,
    kProfileRegionExpand,
    kProfileRegionResize,
    kProfileHeapLookup,
    kProfileTrapServices,
    kProfileMacVBL,
    kProfileSceneBoundary,
    kProfileBookBoundary,
    kProfileEffectService,
    kProfileVBLSchedule,
    kProfileMacVBLTrap,
    kProfileCategoryCount
};

#ifdef AITD_PROBE
uint32_t aitdProfileBeamEpoch();
void aitdProfileStart();
void aitdProfileStop();
void aitdProfileOnVBI();
AitdProfileCategory aitdProfileTrapCategory(uint16_t trap);
#ifdef AITD_PROFILE_FRAME
class AitdTrapProfileScope {
public:
    explicit AitdTrapProfileScope(uint16_t trap);
    ~AitdTrapProfileScope();
private:
    uint16_t m_trap;
    uint32_t m_start;
};
#endif

class AitdProfileScope {
public:
    explicit AitdProfileScope(AitdProfileCategory category, bool enabled = true);
    ~AitdProfileScope();
private:
    AitdProfileCategory m_category;
    uint32_t m_start;
    uint16_t m_generation;
};
#else
inline void aitdProfileStart() {}
inline void aitdProfileOnVBI() {}
class AitdProfileScope {
public:
    explicit AitdProfileScope(AitdProfileCategory, bool = true) {}
};
#endif

#endif
