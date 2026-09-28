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
    kProfileCategoryCount
};

#ifdef AITD_PROBE
uint32_t aitdProfileBeamEpoch();
void aitdProfileStart();
void aitdProfileOnVBI();
AitdProfileCategory aitdProfileTrapCategory(uint16_t trap);

class AitdProfileScope {
public:
    explicit AitdProfileScope(AitdProfileCategory category);
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
    explicit AitdProfileScope(AitdProfileCategory) {}
};
#endif

#endif
