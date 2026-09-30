#ifndef AITD_TEXT8_H
#define AITD_TEXT8_H
#include "BitmapFont.h"
#include "RectBounds.h"
#include "Times14Metrics.h"
namespace Text8 {
// Placeholder ink, measured Times/plain/14 spacing. The fractional pen survives
// calls; MoveTo supplies the measured half-pixel initial fraction.
inline bool draw(uint8_t* pixels,uint32_t capacity,uint16_t stride,
                 const uint8_t* map,const uint8_t* port,const uint8_t* vis,
                 const uint8_t* clip,const BitmapFont& font,
                 const uint8_t* text,int16_t first,int16_t count,
                 int16_t baseline,int16_t& pen,uint16_t& fraction,uint8_t color) {
    if(!pixels || !map || !port || !vis || !clip || !font.height()
       || first<0 || count<0 || (!text && count))return false;
    int32_t mt=int16_t(RectBounds::word(map)),ml=int16_t(RectBounds::word(map+2));
    int32_t mb=int16_t(RectBounds::word(map+4)),mr=int16_t(RectBounds::word(map+6));
    if(mb<=mt || mr<=ml || uint32_t(mr-ml)>stride
       || uint32_t(mb-mt)*stride>capacity)return false;
    uint32_t advance=fraction;
    for(uint16_t i=0;i<uint16_t(count);++i) {
        uint8_t c=text[uint32_t(first)+i];
        // Only characters with owned artwork are enabled, never the missing box.
        if(!((c>=32 && c<=126) || c==0xa5 || c==0xa9))return false;
        uint32_t step=uint32_t(Times14Metrics::units(c))*299*256;
        if(advance>0x7fffffffUL-step)return false;
        advance+=step;
    }
    int32_t finalPen=int32_t(pen)+int32_t(advance>>16);
    if(finalPen>32767)return false;
    uint8_t bounds[8];bool visible;
    RectBounds::intersect(bounds,map,port,visible);
    if(visible)RectBounds::intersect(bounds,bounds,vis,visible);
    if(visible)RectBounds::intersect(bounds,bounds,clip,visible);
    int32_t top=int16_t(RectBounds::word(bounds)),left=int16_t(RectBounds::word(bounds+2));
    int32_t bottom=int16_t(RectBounds::word(bounds+4)),right=int16_t(RectBounds::word(bounds+6));
    uint32_t position=fraction;
    for(uint16_t i=0;visible && i<uint16_t(count);++i) {
        uint8_t c=text[uint32_t(first)+i];
        uint32_t next=position+uint32_t(Times14Metrics::units(c))*299*256;
        unsigned inkLeft=font.advance(),inkRight=0;
        for(unsigned y=0;y<font.height();++y)for(unsigned x=0;x<font.advance();++x)
            if(font.pixel(c,x,y)) { if(x<inkLeft)inkLeft=x;if(x+1>inkRight)inkRight=x+1; }
        unsigned cell=(next>>16)-(position>>16);
        if(inkRight>inkLeft && cell>1) {
            unsigned width=inkRight-inkLeft;
            if(width>=cell)width=cell-1;
            // Fit owned ink into its measured cell, retaining a separating column.
            for(unsigned y=0;y<font.height();++y)for(unsigned x=0;x<width;++x) {
                unsigned sourceX=inkLeft+x*(inkRight-inkLeft)/width;
                if(!font.pixel(c,sourceX,y))continue;
                int32_t px=int32_t(pen)+int32_t(position>>16)+int32_t(x);
                int32_t py=int32_t(baseline)-font.ascent()+int32_t(y);
                if(px>=left && px<right && py>=top && py<bottom)
                    pixels[uint32_t(py-mt)*stride+uint32_t(px-ml)]=color;
            }
        }
        position=next;
    }
    pen=int16_t(finalPen);fraction=uint16_t(advance);return true;
}
}
#endif
