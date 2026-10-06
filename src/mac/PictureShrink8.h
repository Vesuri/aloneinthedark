#ifndef AITD_PICTURE_SHRINK8_H
#define AITD_PICTURE_SHRINK8_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
#include "RectBounds.h"

namespace PictureShrink8 {
// The measured System 7 indexed ditherCopy path: vertical RGB8 averaging,
// horizontal fixed-point groups, then serpentine half-error diffusion.
// Caller-owned workspace keeps scanlines and error storage off the trap stack.
inline uint32_t workspaceBytes(uint16_t sourceWidth,uint16_t width) {
    return ((1024UL+3UL*sourceWidth+3UL*width+1UL)&~1UL)+6UL*width;
}
inline bool draw(const uint8_t* source,uint16_t stride,uint16_t sourceWidth,
                 uint16_t sourceHeight,const uint8_t* sourceColors,
                 const uint8_t* destinationColors,const uint8_t* inverse,
                 uint8_t* out,uint16_t width,uint16_t height,uint8_t* workspace) {
    if(!source || !sourceColors || !destinationColors || !inverse || !out || !workspace
       || !width || !height || sourceWidth>640 || sourceHeight>480
       || sourceWidth<2UL*width || sourceHeight<2UL*height || stride<sourceWidth
       || sourceHeight%height==0 || RectBounds::word(sourceColors+6)!=255
       || RectBounds::word(destinationColors+6)!=255 || RectBounds::word(inverse+4)!=4
       || (RectBounds::word(sourceColors+4)!=0 && RectBounds::word(sourceColors+4)!=0x8000))return false;
    // Integral vertical shrink and the overlapping horizontal branch have
    // not been observed; leave those layouts unsupported rather than guessing.
    uint8_t* palette=workspace;uint8_t* seen=palette+768;
    for(uint16_t i=0;i<256;++i)seen[i]=0;
    for(uint16_t i=0;i<256;++i) {
        const uint8_t* color=sourceColors+8+uint32_t(i)*8;
        const uint16_t index=RectBounds::word(sourceColors+4)&0x8000 ? i : RectBounds::word(color);
        if(index>255 || seen[index])return false;
        seen[index]=1;
        for(uint16_t c=0;c<3;++c)palette[uint32_t(index)*3+c]=color[2+c*2];
    }
    uint8_t* vertical=workspace+1024;
    uint8_t* filtered=vertical+3UL*sourceWidth;
    int16_t* errors=(int16_t*)(workspace+((1024UL+3UL*sourceWidth+3UL*width+1UL)&~1UL));
    for(uint16_t x=0;x<width*3;++x)errors[x]=0;
    int32_t verticalError=-int32_t(sourceHeight/2);
    uint16_t sourceY=0;
    const uint32_t ratio=(uint32_t(width)<<16)/sourceWidth;
    for(uint16_t y=0;y<height;++y) {
        uint16_t count=0;
        do {++count;verticalError+=height;}while(verticalError<=0);
        verticalError-=sourceHeight;
        if(sourceY+count>sourceHeight)return false;
        for(uint16_t x=0;x<sourceWidth;++x) {
            for(uint16_t c=0;c<3;++c) {
                uint16_t sum=0;
                for(uint16_t row=0;row<count;++row)
                    sum+=palette[uint32_t(source[uint32_t(sourceY+row)*stride+x])*3+c];
                vertical[uint32_t(x)*3+c]=uint8_t(sum/count);
            }
        }
        sourceY+=count;
        uint32_t horizontalError=ratio/2;
        uint16_t sourceX=0;
        for(uint16_t x=0;x<width;++x) {
            horizontalError+=ratio;
            if(horizontalError>=65536)return false;
            uint16_t columns=1;
            do {++columns;horizontalError+=ratio;}while(horizontalError<65536);
            horizontalError-=65536;
            if(sourceX+columns>sourceWidth)return false;
            for(uint16_t c=0;c<3;++c) {
                uint32_t sum=0;
                for(uint16_t column=0;column<columns;++column)
                    sum+=vertical[uint32_t(sourceX+column)*3+c];
                filtered[uint32_t(x)*3+c]=uint8_t(sum/columns);
            }
            sourceX+=columns;
        }
        int16_t carry[3]={0,0,0};
        for(uint16_t column=0;column<width;++column) {
            const uint16_t x=y&1 ? width-1-column : column;
            uint16_t cell=0;int16_t value[3];
            for(uint16_t c=0;c<3;++c) {
                int16_t v=int16_t(filtered[uint32_t(x)*3+c])+errors[uint32_t(x)*3+c]+carry[c];
                if(v<0)v=0;
                if(v>255)v=255;
                value[c]=v;cell=uint16_t((cell<<4)|(v>>4));
            }
            const uint8_t pen=inverse[6+cell];out[uint32_t(y)*width+x]=pen;
            for(uint16_t c=0;c<3;++c) {
                const int16_t error=value[c]-destinationColors[10+uint32_t(pen)*8+c*2];
                // ASR followed by ADDX: floor half goes below, ceil half sideways.
                const int16_t below=error<0 ? -int16_t((1-error)/2) : error/2;
                errors[uint32_t(x)*3+c]=below;carry[c]=error-below;
            }
        }
    }
    return true;
}
}
#endif
