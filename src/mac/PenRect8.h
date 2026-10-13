#ifndef AMIGAXDEV_PEN_RECT8_H
#define AMIGAXDEV_PEN_RECT8_H
#include "BigEndianMemory.h"
#include "FillRect8.h"
namespace PenRect8 {
// Solid zero-displacement QuickDraw pen: half-open rectangle, signed local
// coordinates. Validate the complete map before writing; clip by coordinates.
inline bool solid(uint8_t* pixels,uint32_t capacity,uint16_t stride,
                  const uint8_t* map,const uint8_t* port,const uint8_t* vis,
                  const uint8_t* clip,int16_t x,int16_t y,uint16_t width,
                  uint16_t height,uint8_t color) {
    using namespace BigEndianMemory;
    if(!pixels || !map || !port || !vis || !clip || width>32767 || height>32767)
        return false;
    int32_t right=int32_t(x)+width,bottom=int32_t(y)+height;
    if(right>32767 || bottom>32767)return false;
    const int32_t mt=int16_t(read16(map)),ml=int16_t(read16(map+2));
    const int32_t mb=int16_t(read16(map+4)),mr=int16_t(read16(map+6));
    if(mb<=mt || mr<=ml || uint32_t(mr-ml)>stride
       || uint32_t(mb-mt)*stride>capacity)return false;
    int32_t top=y,left=x;
    if(top<mt)top=mt;if(left<ml)left=ml;
    if(bottom>mb)bottom=mb;if(right>mr)right=mr;
    const uint8_t* limits[3]={port,vis,clip};
    for(unsigned i=0;i<3;++i) {
        const uint8_t* r=limits[i];
        const int16_t t=read16(r),l=read16(r+2),b=read16(r+4),e=read16(r+6);
        if(top<t)top=t;if(left<l)left=l;if(bottom>b)bottom=b;if(right>e)right=e;
    }
    if(top>=bottom || left>=right)return true;
    uint8_t* row=pixels+uint32_t(top-mt)*stride+left-ml;
    const uint16_t columns=uint16_t(right-left),rows=uint16_t(bottom-top);
    // Particle pens are small; avoid wide-span setup for each two-byte row.
    if(columns<=4) {
        for(uint16_t n=0;n<rows;++n,row+=stride)
            for(uint16_t c=0;c<columns;++c)row[c]=color;
    } else FillRect8::fillRows(row,stride,columns,rows,color);
    return true;
}
}
#endif
