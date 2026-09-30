#ifndef AITD_FILL_RECT8_H
#define AITD_FILL_RECT8_H
#include "RectBounds.h"
namespace FillRect8 {
// All bounds use the selected port's signed local coordinates. The returned
// rectangle is the actual write area, for conversion to display coordinates.
inline bool solid(uint8_t* pixels,uint32_t capacity,uint16_t stride,
                  const uint8_t* map,const uint8_t* port,const uint8_t* vis,
                  const uint8_t* clip,const uint8_t* rect,uint8_t color,uint8_t* drawn) {
    if(!pixels || !map || !port || !vis || !clip || !rect || !drawn)return false;
    int32_t mt=int16_t(RectBounds::word(map)),ml=int16_t(RectBounds::word(map+2));
    int32_t mb=int16_t(RectBounds::word(map+4)),mr=int16_t(RectBounds::word(map+6));
    if(mb<=mt || mr<=ml || uint32_t(mr-ml)>stride
       || uint32_t(mb-mt)*stride>capacity)return false;
    bool nonempty;
    RectBounds::intersect(drawn,rect,map,nonempty);
    const uint8_t* limits[3]={port,vis,clip};
    for(unsigned i=0;i<3 && nonempty;++i)RectBounds::intersect(drawn,drawn,limits[i],nonempty);
    if(!nonempty)return true;
    int32_t top=int16_t(RectBounds::word(drawn)),left=int16_t(RectBounds::word(drawn+2));
    int32_t bottom=int16_t(RectBounds::word(drawn+4)),right=int16_t(RectBounds::word(drawn+6));
    for(int32_t y=top;y<bottom;++y) {
        uint8_t* row=pixels+uint32_t(y-mt)*stride;
        for(int32_t x=left;x<right;++x)row[x-ml]=color;
    }
    return true;
}
}
#endif
