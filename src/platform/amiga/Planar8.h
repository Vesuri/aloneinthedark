#ifndef AITD_PLANAR8_H
#define AITD_PLANAR8_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Integer reference converter for the fixed 320x200 view of a 640x480 Mac
// device. Plane zero is the least significant pixel bit. Rows interleave eight
// 40-byte planes. The assembly converter must agree with this representation.
namespace Planar8 {
static const uint16_t width=320, height=200, planes=8, planeRow=40, rowBytes=320;
static const uint32_t bytes=uint32_t(rowBytes)*height;
struct Rect { int16_t top,left,bottom,right; };

// All rectangles here have already been normalized to 32-pixel boundaries.
// Each bit selects one four-byte span of a plane row. Pixels converted from
// chunky this frame need no copy from the previous front buffer.
inline uint16_t syncRowMask(const Rect& previous,int16_t y,
                            const Rect* converted,uint16_t count) {
    if(y<previous.top || y>=previous.bottom)return 0;
    uint16_t mask=uint16_t((1u<<(previous.right/32))-(1u<<(previous.left/32)));
    for(uint16_t i=0;i<count && mask;++i) {
        const Rect& r=converted[i];
        if(y>=r.top && y<r.bottom)
            mask&=uint16_t(~((1u<<(r.right/32))-(1u<<(r.left/32))));
    }
    return mask;
}

inline bool viewportValid(const Rect& viewport) {
    return viewport.top>=0 && viewport.left>=0 && viewport.bottom<=480
        && viewport.right<=640 && viewport.bottom-viewport.top==height
        && viewport.right-viewport.left==width;
}

struct Mismatch { uint16_t x,y;uint8_t expected,actual; };
// Independent bitplane decoder for diagnostic builds. Check the entire frame,
// including pixels preserved outside the current dirty rectangles.
inline bool verify(const uint8_t* chunky,const uint8_t* planar,
                   const Rect& viewport,Mismatch& mismatch) {
    if(!chunky || !planar || !viewportValid(viewport))return false;
    for(uint16_t y=0;y<height;++y)for(uint16_t x=0;x<width;++x) {
        uint8_t actual=0;
        for(uint16_t bit=0;bit<planes;++bit)
            if(planar[uint32_t(y)*rowBytes+bit*planeRow+x/8]&(128u>>(x&7)))
                actual|=1u<<bit;
        uint8_t expected=chunky[uint32_t(y+viewport.top)*640+x+viewport.left];
        if(actual!=expected) {mismatch={x,y,expected,actual};return false;}
    }
    return true;
}

// Output coordinates are local to the viewport. Empty intersections are valid
// and produce an empty rectangle. Align relative to the destination, then clip.
inline bool normalize(const Rect& viewport,const Rect& dirty,Rect& local) {
    if(!viewportValid(viewport) || dirty.bottom<dirty.top || dirty.right<dirty.left)return false;
    local={0,0,0,0};
    int32_t top=dirty.top>viewport.top ? dirty.top : viewport.top;
    int32_t left=dirty.left>viewport.left ? dirty.left : viewport.left;
    int32_t bottom=dirty.bottom<viewport.bottom ? dirty.bottom : viewport.bottom;
    int32_t right=dirty.right<viewport.right ? dirty.right : viewport.right;
    if(top>=bottom || left>=right)return true;
    local.top=int16_t(top-viewport.top);local.bottom=int16_t(bottom-viewport.top);
    local.left=int16_t((left-viewport.left)&~31);
    local.right=int16_t((right-viewport.left+31)&~31);
    return true;
}

#ifndef AITD_PLATFORM_AMIGA
// Host oracle only. The game always calls Kalms assembly.
inline bool convert(const uint8_t* chunky,uint8_t* planar,const Rect& viewport,
                    const Rect& dirty,Rect& converted) {
    Rect local;
    if(!chunky || !planar || !normalize(viewport,dirty,local))return false;
    for(int16_t y=local.top;y<local.bottom;++y) {
        const uint8_t* source=chunky+uint32_t(y+viewport.top)*640+viewport.left;
        uint8_t* destination=planar+uint32_t(y)*rowBytes;
        for(int16_t x=local.left;x<local.right;x+=8) {
            for(uint16_t plane=0;plane<planes;++plane) {
                uint8_t bits=0;
                for(uint16_t pixel=0;pixel<8;++pixel)
                    bits=uint8_t((bits<<1)|((source[x+pixel]>>plane)&1));
                destination[plane*planeRow+x/8]=bits;
            }
        }
    }
    converted=local;
    return true;
}
#endif
}
#endif
