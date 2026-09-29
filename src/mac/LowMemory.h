#ifndef AITD_LOW_MEMORY_H
#define AITD_LOW_MEMORY_H
// Fixed-width types come from the Amiga ABI header or host <cstdint>.
// Same-length effective-address redirection, following Vette's A5 shadows.
namespace MacLowMemory {
static const uint16_t base = 3776;
static const uint16_t size = 160;
static const uint16_t currentA5 = 32, curStackBase = 52;
static const uint16_t fpState = 56, cpuFlag = 58, loadTrap = 59;
static const uint16_t resLoad = 60, lo3Bytes = 64, menuBarHeight = 156;
struct Shadow { uint16_t address, offset, width; };
static const Shadow shadows[] = {
    {0x012d, 59, 1},
    {0x012f, 58, 1},
    {0x0130, 80, 4},
    {0x015a, 84, 2},
    {0x016a, 0, 4},
    {0x016c, 2, 2},
    {0x01fb, 88, 1},
    {0x0210, 92, 2},
    {0x021e, 96, 1},
    {0x0220, 100, 2},
    {0x027e, 104, 1},
    {0x028e, 108, 2},
    {0x0291, 112, 1},
    {0x02ae, 116, 4},
    {0x02dc, 120, 4},
    {0x031a, 64, 4},
    {0x034e, 124, 4},
    {0x03f6, 128, 2},
    {0x0900, 132, 2},
    {0x0904, 32, 4},
    {0x0908, 52, 4},
    {0x0a4a, 56, 2},
    {0x0a58, 136, 2},
    {0x0a5e, 60, 1},
    {0x0a60, 140, 2},
    {0x0ab0, 144, 2},
    {0x0ab4, 148, 4},
    {0x0b22, 152, 2},
    {0x0baa, 156, 2},
};
struct Segment { uint16_t id; uint32_t bytes, fingerprint; };
// Size + FNV-1a of every original CODE, checked before takeover. A changed
// instruction outside the known sites must not introduce an unchecked access.
static const Segment segments[] = {
    {1, 1234, 0x236a81fcUL},
    {2, 4, 0x93573ef1UL},
    {3, 20590, 0x13de0618UL},
    {4, 27692, 0x82aa794dUL},
    {5, 26108, 0xe4337feaUL},
    {6, 18502, 0x8c731debUL},
    {7, 20428, 0x05c76577UL},
    {8, 2538, 0xcf8b325bUL},
    {9, 4796, 0xebb31842UL},
    {10, 15226, 0x0250ba4aUL},
    {11, 11704, 0x5afacd62UL},
    {12, 25322, 0xba6d6721UL},
    {13, 17292, 0xb75b212eUL},
};
struct Site {
    uint16_t segment, offset, shadow;
    uint8_t length, extension, destination;
    uint8_t original[8];
};
static const Site sites[] = {
    {1, 0x0014, 56, 4, 2, 0, {0x42,0x78,0x0a,0x4a}}, // $0A4A
    {1, 0x0048, 32, 4, 2, 0, {0x2a,0x78,0x09,0x04}}, // $0904
    {1, 0x006a, 60, 4, 2, 0, {0x50,0xf8,0x0a,0x5e}}, // $0A5E
    {1, 0x00be, 59, 4, 2, 0, {0x4a,0x38,0x01,0x2d}}, // $012D
    {1, 0x00f4, 60, 4, 2, 0, {0x50,0xf8,0x0a,0x5e}}, // $0A5E
    {1, 0x0118, 60, 4, 2, 0, {0x50,0xf8,0x0a,0x5e}}, // $0A5E
    {1, 0x013a, 52, 4, 2, 0, {0x22,0x78,0x09,0x08}}, // $0908
    {1, 0x0246, 58, 6, 4, 0, {0x0c,0x38,0x00,0x04,0x01,0x2f}}, // $012F
    {1, 0x0254, 58, 6, 4, 0, {0x0c,0x38,0x00,0x02,0x01,0x2f}}, // $012F
    {1, 0x029c, 64, 4, 2, 0, {0x20,0x38,0x03,0x1a}}, // $031A
    {3, 0x1bfc, 104, 4, 2, 0, {0x4a,0x38,0x02,0x7e}}, // $027E
    {3, 0x2ac6, 100, 4, 2, 0, {0x4a,0x78,0x02,0x20}}, // $0220
    {3, 0x2de6, 58, 6, 4, 0, {0x0c,0x38,0x00,0x02,0x01,0x2f}}, // $012F
    {3, 0x3bae, 108, 4, 2, 0, {0x4a,0x78,0x02,0x8e}}, // $028E
    {3, 0x3bfa, 116, 4, 2, 0, {0x20,0x78,0x02,0xae}}, // $02AE
    {3, 0x3c18, 108, 4, 2, 0, {0x4a,0x78,0x02,0x8e}}, // $028E
    {3, 0x3c24, 152, 4, 2, 0, {0x4a,0x78,0x0b,0x22}}, // $0B22
    {3, 0x3c52, 58, 6, 4, 0, {0x0c,0x38,0x00,0x02,0x01,0x2f}}, // $012F
    {3, 0x3c5a, 58, 4, 2, 0, {0x10,0x38,0x01,0x2f}}, // $012F
    {3, 0x3c64, 108, 4, 2, 0, {0x4a,0x78,0x02,0x8e}}, // $028E
    {3, 0x3c6a, 152, 6, 4, 0, {0x08,0x38,0x00,0x04,0x0b,0x22}}, // $0B22
    {3, 0x3c78, 108, 6, 4, 0, {0x0c,0x78,0x3f,0xff,0x02,0x8e}}, // $028E
    {3, 0x3c86, 96, 4, 2, 0, {0x10,0x38,0x02,0x1e}}, // $021E
    {3, 0x3c9e, 112, 4, 2, 0, {0x4a,0x38,0x02,0x91}}, // $0291
    {3, 0x3ca4, 88, 4, 2, 0, {0x12,0x38,0x01,0xfb}}, // $01FB
    {3, 0x3cb2, 120, 4, 2, 0, {0x20,0x78,0x02,0xdc}}, // $02DC
    {3, 0x3cbc, 92, 6, 2, 0, {0x33,0x78,0x02,0x10,0x00,0x0e}}, // $0210
    {3, 0x3cc2, 128, 4, 2, 0, {0x4a,0x78,0x03,0xf6}}, // $03F6
    {3, 0x3cd8, 136, 6, 2, 0, {0x31,0x78,0x0a,0x58,0x00,0x18}}, // $0A58
    {3, 0x41e2, 108, 6, 4, 0, {0x08,0x38,0x00,0x06,0x02,0x8e}}, // $028E
    {3, 0x41f0, 64, 4, 2, 0, {0xc0,0xb8,0x03,0x1a}}, // $031A
    {3, 0x4270, 148, 4, 2, 0, {0x2f,0x38,0x0a,0xb4}}, // $0AB4
    {3, 0x4286, 144, 4, 2, 0, {0x42,0x78,0x0a,0xb0}}, // $0AB0
    {3, 0x4290, 144, 4, 2, 1, {0x31,0xc0,0x0a,0xb0}}, // $0AB0
    {3, 0x429c, 148, 4, 2, 0, {0x20,0x78,0x0a,0xb4}}, // $0AB4
    {3, 0x42a4, 144, 4, 2, 0, {0x3f,0x38,0x0a,0xb0}}, // $0AB0
    {3, 0x42ba, 148, 4, 2, 0, {0x20,0x78,0x0a,0xb4}}, // $0AB4
    {3, 0x43b6, 136, 6, 2, 0, {0x3d,0x78,0x0a,0x58,0xff,0x98}}, // $0A58
    {3, 0x46c0, 84, 6, 4, 0, {0x0c,0x78,0x06,0x00,0x01,0x5a}}, // $015A
    {3, 0x47c0, 140, 4, 2, 1, {0x31,0xc7,0x0a,0x60}}, // $0A60
    {3, 0x4802, 84, 6, 4, 0, {0x0c,0x78,0x06,0x00,0x01,0x5a}}, // $015A
    {3, 0x48fa, 140, 4, 2, 1, {0x31,0xc7,0x0a,0x60}}, // $0A60
    {3, 0x4a2e, 52, 6, 2, 0, {0x2d,0x78,0x09,0x08,0xff,0xf8}}, // $0908
    {4, 0x4200, 0, 4, 2, 0, {0x20,0x38,0x01,0x6a}}, // $016A
    {4, 0x4222, 0, 8, 2, 0, {0x23,0xf8,0x01,0x6a,0xff,0xff,0x4c,0x6a}}, // $016A
    {4, 0x4248, 0, 4, 2, 0, {0x20,0x38,0x01,0x6a}}, // $016A
    {7, 0x2502, 100, 4, 2, 0, {0x3e,0x38,0x02,0x20}}, // $0220
    {7, 0x27bc, 100, 4, 2, 0, {0x3c,0x38,0x02,0x20}}, // $0220
    {7, 0x2a92, 100, 4, 2, 0, {0x3e,0x38,0x02,0x20}}, // $0220
    {7, 0x3f86, 80, 4, 2, 0, {0x20,0x78,0x01,0x30}}, // $0130
    {7, 0x4092, 132, 6, 2, 0, {0x31,0x78,0x09,0x00,0x00,0x72}}, // $0900
    {7, 0x479e, 156, 4, 2, 0, {0x30,0x38,0x0b,0xaa}}, // $0BAA
    {7, 0x4a22, 2, 4, 2, 0, {0x30,0x38,0x01,0x6c}}, // $016C
    {9, 0x0136, 100, 4, 2, 0, {0x30,0x38,0x02,0x20}}, // $0220
    {9, 0x02ea, 100, 4, 2, 0, {0x30,0x38,0x02,0x20}}, // $0220
    {11, 0x0892, 108, 4, 2, 0, {0x4a,0x78,0x02,0x8e}}, // $028E
    {11, 0x1236, 124, 4, 2, 0, {0xd7,0xf8,0x03,0x4e}}, // $034E
    {12, 0x2314, 0, 4, 2, 0, {0x2e,0x38,0x01,0x6a}}, // $016A
};
static const uint16_t count = sizeof(sites) / sizeof(sites[0]);
static const uint16_t segmentCount = sizeof(segments) / sizeof(segments[0]);
inline uint16_t siteCount(uint16_t segment)
{
    uint16_t result = 0;
    for (uint16_t i = 0; i < count; ++i) if (sites[i].segment == segment) ++result;
    return result;
}
inline bool validate(uint16_t segment, const uint8_t* code, uint32_t bytes)
{
    const Segment* expected = 0;
    for (uint16_t i = 0; i < segmentCount; ++i)
        if (segments[i].id == segment) expected = &segments[i];
    if (!expected || !code || bytes != expected->bytes) return false;
    uint32_t fingerprint = 2166136261UL;
    for (uint32_t i = 0; i < bytes; ++i) fingerprint = (fingerprint ^ code[i]) * 16777619UL;
    if (fingerprint != expected->fingerprint) return false;
    for (uint16_t i = 0; i < count; ++i) {
        const Site& site = sites[i];
        if (site.segment != segment) continue;
        if (site.offset + site.length > bytes) return false;
        for (uint16_t j = 0; j < site.length; ++j)
            if (code[site.offset + j] != site.original[j]) return false;
    }
    return true;
}
// Caller validates every original CODE before takeover and again at creation.
// The separate apply function also validates all affected bytes atomically;
// host fixtures can exercise it without embedding original game data.
inline bool apply(uint16_t segment, uint8_t* code, uint32_t bytes)
{
    const Segment* expected = 0;
    for (uint16_t i = 0; i < segmentCount; ++i)
        if (segments[i].id == segment) expected = &segments[i];
    if (!expected || !code || bytes != expected->bytes) return false;
    for (uint16_t i = 0; i < count; ++i) {
        const Site& site = sites[i];
        if (site.segment != segment) continue;
        if (site.offset + site.length > bytes) return false;
        for (uint16_t j = 0; j < site.length; ++j)
            if (code[site.offset + j] != site.original[j]) return false;
    }
    for (uint16_t i = 0; i < count; ++i) {
        const Site& site = sites[i];
        if (site.segment != segment) continue;
        uint8_t* at = code + site.offset;
        uint16_t opcode = ((uint16_t)at[0] << 8) | at[1];
        // MOVE destination EA has reversed register/mode fields.
        opcode = site.destination ? ((opcode & 0xf03f) | 0x0b40)
                                  : ((opcode & 0xffc0) | 0x002d);
        at[0] = opcode >> 8; at[1] = opcode & 255;
        uint16_t displacement = base + site.shadow;
        at[site.extension] = displacement >> 8;
        at[site.extension + 1] = displacement & 255;
    }
    return true;
}
inline bool patch(uint16_t segment, uint8_t* code, uint32_t bytes)
{
    return validate(segment, code, bytes) && apply(segment, code, bytes);
}
}
#endif
