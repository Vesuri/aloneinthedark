#ifndef AITD_LINE8_H
#define AITD_LINE8_H
#include "RectBounds.h"
namespace Line8 {
// Integer and fraction stay separate: signed endpoints can span 65535 pixels
// without overflowing a signed 16.16 accumulator or requiring 64-bit division.
struct Edge {
    int32_t pixel;
    uint32_t fraction;
    void advance(uint32_t slope) {
        fraction+=slope&65535;
        pixel+=int32_t(slope>>16)+int32_t(fraction>>16);
        fraction&=65535;
    }
};
// System 7 colour QuickDraw, solid 1x1 patCopy pen. The original rasterizer
// normalizes top-to-bottom and truncates dx/dy to 16.16. Shallow lines fill
// half-open spans; 45-degree lines take the single-pixel branch.
inline bool solid(uint8_t* pixels,uint32_t capacity,uint16_t stride,
                  const uint8_t* map,const uint8_t* port,const uint8_t* vis,
                  const uint8_t* clip,int16_t x0,int16_t y0,int16_t x1,int16_t y1,
                  uint8_t color,uint8_t* drawn=0) {
    if(drawn)for(unsigned i=0;i<8;++i)drawn[i]=0;
    if(!pixels || !map || !port || !vis || !clip)return false;
    int32_t mt=int16_t(RectBounds::word(map)),ml=int16_t(RectBounds::word(map+2));
    int32_t mb=int16_t(RectBounds::word(map+4)),mr=int16_t(RectBounds::word(map+6));
    if(mb<=mt || mr<=ml || uint32_t(mr-ml)>stride
       || uint32_t(mb-mt)*stride>capacity)return false;
    uint8_t bounds[8];bool nonempty;
    RectBounds::intersect(bounds,map,port,nonempty);
    if(nonempty)RectBounds::intersect(bounds,bounds,vis,nonempty);
    if(nonempty)RectBounds::intersect(bounds,bounds,clip,nonempty);
    if(!nonempty)return true;
    int32_t top=int16_t(RectBounds::word(bounds)),left=int16_t(RectBounds::word(bounds+2));
    int32_t bottom=int16_t(RectBounds::word(bounds+4)),right=int16_t(RectBounds::word(bounds+6));
    int32_t inkTop=bottom,inkLeft=right,inkBottom=top,inkRight=left;
    if(y1<y0) { int16_t t=x0;x0=x1;x1=t;t=y0;y0=y1;y1=t; }
    int32_t delta=int32_t(x1)-x0;
    uint32_t dx=uint32_t(delta<0?-delta:delta),dy=uint32_t(int32_t(y1)-y0);
    uint32_t slope=dy ? (dx*65536u)/dy : 0;
    uint32_t start=32768u+slope/2;
    Edge last={int32_t(start>>16),start&65535};
    Edge first=last;
    if(dx>dy && dy) {
        first.pixel-=int32_t(slope>>16);
        if(first.fraction<(slope&65535))--first.pixel;
        first.fraction=(first.fraction-(slope&65535))&65535;
    }
    if(dx==dy)first=Edge{0,0};
    for(uint32_t row=0;row<=dy;++row) {
        int32_t y=int32_t(y0)+int32_t(row);
        int32_t begin=first.pixel,end=last.pixel;
        if(!dy) { begin=0;end=int32_t(dx)+1; }
        else if(dx<=dy)end=begin+1;
        if(begin<0)begin=0;
        if(end>int32_t(dx)+1)end=int32_t(dx)+1;
        if(y>=top && y<bottom) {
            uint8_t* out=pixels+uint32_t(y-mt)*stride;
            for(int32_t d=begin;d<end;++d) {
                int32_t x=int32_t(x0)+(delta<0?-d:d);
                if(x>=left && x<right) {
                    out[x-ml]=color;
                    if(drawn) {
                        if(y<inkTop)inkTop=y;if(y+1>inkBottom)inkBottom=y+1;
                        if(x<inkLeft)inkLeft=x;if(x+1>inkRight)inkRight=x+1;
                    }
                }
            }
        }
        first.advance(slope);last.advance(slope);
    }
    if(drawn && inkTop<inkBottom && inkLeft<inkRight) {
        int32_t bounds[4]={inkTop,inkLeft,inkBottom,inkRight};
        for(unsigned i=0;i<4;++i) {
            drawn[i*2]=uint8_t(uint16_t(bounds[i])>>8);
            drawn[i*2+1]=uint8_t(bounds[i]);
        }
    }
    return true;
}
}
#endif
