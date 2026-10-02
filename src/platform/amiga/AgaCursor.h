#ifndef AITD_AGA_CURSOR_H
#define AITD_AGA_CURSOR_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

namespace AgaCursor {
// BPLCON4 XORs the playfield index, independently of sprite palette banks.
// Pairing XOR 1 with palette[i^1]=logicalPalette[i] preserves all game RGBs.
// Sprite 0/value 1 selects physical white 1; sprite 7/value 2 selects black
// 254 (odd bank 15, pair offset 12). No palette entry is replaced.
static const uint8_t playfieldXor=1;
static const uint16_t displayControl=0x010f;
static const uint16_t whiteChannel=0,blackChannel=7;
inline bool paletteSupported(const uint32_t* colors) {
    return colors && colors[0]==0xffffff && colors[255]==0;
}
inline bool shapeSupported(const uint16_t* image,const uint16_t* mask) {
    if(!image || !mask)return false;
    for(uint16_t row=0;row<16;++row)if(image[row]&~mask[row])return false;
    return true;
}
inline void row(uint16_t image,uint16_t mask,uint16_t* white,uint16_t* black) {
    white[0]=uint16_t(~image&mask);white[1]=0;
    black[0]=0;black[1]=uint16_t(image&mask);
}
}
#endif
