#ifndef AITD_STARTUP_LOW_MEMORY_H
#define AITD_STARTUP_LOW_MEMORY_H
// Fixed-width types are supplied by the Amiga ABI header or host <cstdint>.

// CODE 0 above-A5 size is $EC0; the private shadows follow the jump table.
namespace StartupLowMemory {
static const uint16_t base = 3776;
static const uint16_t size = 80;
static const uint16_t currentA5 = 32, curStackBase = 52;
static const uint16_t fpState = 56, cpuFlag = 58, loadTrap = 59;
static const uint16_t resLoad = 60, lo3Bytes = 64;
struct Site {
    uint16_t offset, shadow;
    uint8_t length;
    uint8_t original[6];
};
static const Site sites[] = {
    {0x0014, fpState,     4, {0x42,0x78,0x0a,0x4a}},
    {0x0048, currentA5,   4, {0x2a,0x78,0x09,0x04}},
    {0x006a, resLoad,     4, {0x50,0xf8,0x0a,0x5e}},
    {0x00be, loadTrap,    4, {0x4a,0x38,0x01,0x2d}},
    {0x00f4, resLoad,     4, {0x50,0xf8,0x0a,0x5e}},
    {0x0118, resLoad,    4, {0x50,0xf8,0x0a,0x5e}},
    {0x013a, curStackBase,4, {0x22,0x78,0x09,0x08}},
    {0x0246, cpuFlag,    6, {0x0c,0x38,0x00,0x04,0x01,0x2f}},
    {0x0254, cpuFlag,    6, {0x0c,0x38,0x00,0x02,0x01,0x2f}},
    {0x029c, lo3Bytes,   4, {0x20,0x38,0x03,0x1a}},
};
static const uint16_t count = sizeof(sites) / sizeof(sites[0]);

// Validate the entire table before changing even one byte.
inline bool patch(uint8_t* code, uint32_t bytes)
{
    if (bytes != 1234) return false;
    for (uint16_t i = 0; i < count; ++i) {
        const Site& site = sites[i];
        if (site.offset + site.length > bytes) return false;
        for (uint16_t j = 0; j < site.length; ++j)
            if (code[site.offset + j] != site.original[j]) return false;
    }
    for (uint16_t i = 0; i < count; ++i) {
        const Site& site = sites[i];
        code[site.offset + 1] = (code[site.offset + 1] & 0xc0) | 0x2d;
        uint16_t disp = base + site.shadow;
        code[site.offset + site.length - 2] = disp >> 8;
        code[site.offset + site.length - 1] = disp & 255;
    }
    return true;
}
}
#endif
