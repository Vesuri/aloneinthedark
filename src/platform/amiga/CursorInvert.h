#ifndef AITD_CURSOR_INVERT_H
#define AITD_CURSOR_INVERT_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
namespace CursorInvert {
// Original eight-bit QuickDraw cursor inversion XORs the pixel index with 255.
// Apply the same row mask to all eight planes; applying it twice restores data.
// row points to a complete 320-pixel plane row. Bounds limit a copied span.
inline void row(uint8_t* bytes,int16_t left,int16_t right,
                int16_t cursorLeft,uint16_t mask) {
    if(!mask || cursorLeft<=-16 || cursorLeft>=320)return;
    if(cursorLeft<0) {mask=uint16_t(mask<<-cursorLeft);cursorLeft=0;}
    uint32_t bits=uint32_t(mask)<<(8-(cursorLeft&7));
    int16_t byte=cursorLeft/8;
    // Synchronization rectangles are byte-aligned, as are the viewport edges.
    for(uint16_t i=0;i<3;++i,++byte) {
        if(byte>=left/8 && byte<right/8 && byte<40)
            bytes[byte]^=uint8_t(bits>>(16-i*8));
    }
}
// VBI path: decode a cursor row once, then XOR its bytes in all eight planes.
inline void planes(uint8_t* firstPlane,int16_t cursorLeft,uint16_t mask) {
    if(!mask || cursorLeft<=-16 || cursorLeft>=320)return;
    if(cursorLeft<0) {mask=uint16_t(mask<<-cursorLeft);cursorLeft=0;}
    uint32_t bits=uint32_t(mask)<<(8-(cursorLeft&7));
    uint16_t byte=cursorLeft/8;
    for(uint16_t i=0;i<3;++i,++byte) {
        uint8_t value=uint8_t(bits>>(16-i*8));
        if(byte<40 && value)for(uint16_t plane=0;plane<8;++plane)
            firstPlane[plane*40+byte]^=value;
    }
}
}
#endif
