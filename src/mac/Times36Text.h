#ifndef AITD_TIMES36_TEXT_H
#define AITD_TIMES36_TEXT_H
#include "RectBounds.h"
#include "Times36Bitmap.h"
namespace Times36Text {
inline bool width(const uint8_t* text,int16_t first,int16_t count,uint16_t& result) {
    if(first<0 || count<0 || (!text && count))return false;
    uint32_t total=0;
    for(uint16_t i=0;i<uint16_t(count);++i) {
        uint8_t c=text[uint32_t(first)+i];if(c<32)return false;
        total+=Times36Bitmap::glyphs[c-32].advance;
    }
    if(total>32767)return false;
    result=uint16_t(total);return true;
}
// Reached srcOr text with foreground index zero: write the original glyph coverage.
// Fractional pen state is unchanged by the measured integer advances.
inline bool draw(uint8_t* pixels,uint32_t capacity,uint16_t stride,
                 const uint8_t* map,const uint8_t* port,const uint8_t* vis,
                 const uint8_t* clip,const uint8_t* text,int16_t first,int16_t count,
                 int16_t baseline,int16_t& pen,uint8_t* dirty) {
    uint16_t advance;
    if(!pixels || !map || !port || !vis || !clip || !dirty
       || !width(text,first,count,advance) || int32_t(pen)+advance>32767)return false;
    int32_t mt=int16_t(RectBounds::word(map)),ml=int16_t(RectBounds::word(map+2));
    int32_t mb=int16_t(RectBounds::word(map+4)),mr=int16_t(RectBounds::word(map+6));
    if(mb<=mt || mr<=ml || uint32_t(mr-ml)>stride || uint32_t(mb-mt)*stride>capacity)return false;
    uint8_t bounds[8];bool visible;
    RectBounds::intersect(bounds,map,port,visible);
    if(visible)RectBounds::intersect(bounds,bounds,vis,visible);
    if(visible)RectBounds::intersect(bounds,bounds,clip,visible);
    int32_t top=int16_t(RectBounds::word(bounds)),left=int16_t(RectBounds::word(bounds+2));
    int32_t bottom=int16_t(RectBounds::word(bounds+4)),right=int16_t(RectBounds::word(bounds+6));
    int32_t dt=32767,dl=32767,db=-32768,dr=-32768,xpen=pen;
    for(uint16_t i=0;visible && i<uint16_t(count);++i) {
        const Times36Bitmap::Glyph& g=Times36Bitmap::glyphs[text[uint32_t(first)+i]-32];
        uint16_t rowBytes=(g.width+7)/8;
        for(uint16_t y=0;y<g.height;++y)for(uint16_t x=0;x<g.width;++x) {
            if(!(Times36Bitmap::bits[g.offset+y*rowBytes+x/8]&(128>>(x&7))))continue;
            int32_t px=xpen+g.left+x,py=int32_t(baseline)+g.top+y;
            if(px<left || px>=right || py<top || py>=bottom)continue;
            pixels[uint32_t(py-mt)*stride+uint32_t(px-ml)]=0;
            if(py<dt)dt=py;
            if(px<dl)dl=px;
            if(py+1>db)db=py+1;
            if(px+1>dr)dr=px+1;
        }
        xpen+=g.advance;
    }
    if(db<=dt || dr<=dl)dt=dl=db=dr=0;
    const uint16_t rectangle[]={uint16_t(dt),uint16_t(dl),uint16_t(db),uint16_t(dr)};
    for(unsigned i=0;i<4;++i) {dirty[2*i]=uint8_t(rectangle[i]>>8);dirty[2*i+1]=uint8_t(rectangle[i]);}
    pen=int16_t(int32_t(pen)+advance);return true;
}
}
#endif
