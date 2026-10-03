#ifndef AITD_PICTURE_RECORD8_H
#define AITD_PICTURE_RECORD8_H
#include "RectBounds.h"
namespace PictureRecord8 {
inline void word(uint8_t* p,uint16_t v) {p[0]=uint8_t(v>>8);p[1]=uint8_t(v);}
inline void bytes(uint8_t* out,const uint8_t* in,uint32_t n) {while(n--)*out++=*in++;}
// One measured indexed CopyBits operation in a v2 picture. The complete
// source raster is retained, just as QuickDraw does for the save thumbnail.
inline uint32_t capacity(uint16_t stride,uint16_t height) {
    return 2180+uint32_t(height)*(stride+(stride+127)/128+2);
}
inline uint32_t record(uint8_t* out,uint32_t room,const uint8_t* frame,
                      const uint8_t* pm,const uint8_t* colors,const uint8_t* pixels,
                      uint32_t pixelBytes,const uint8_t* from,const uint8_t* to,uint16_t mode) {
    if(!out || !frame || !pm || !colors || !pixels || !from || !to)return 0;
    const uint16_t sourceStride=RectBounds::word(pm+4)&0x3fff;
    const int32_t sourceHeight=int16_t(RectBounds::word(pm+10))-int16_t(RectBounds::word(pm+6));
    const int32_t sourceWidth=int16_t(RectBounds::word(pm+12))-int16_t(RectBounds::word(pm+8));
    const int32_t height=int16_t(RectBounds::word(from+4))-int16_t(RectBounds::word(from));
    const int32_t width=int16_t(RectBounds::word(from+6))-int16_t(RectBounds::word(from+2));
    const uint16_t stride=uint16_t(width);
    if(height<=0 || height>480 || width<=0 || width>640 || sourceHeight<=0
       || sourceWidth<=0 || sourceStride<sourceWidth || uint32_t(sourceHeight)*sourceStride>pixelBytes
       || RectBounds::word(pm+32)!=8 || RectBounds::word(colors+6)!=255
       || (mode!=0 && mode!=64) || room<capacity(stride,uint16_t(height)))return 0;
    for(unsigned i=0;i<4;++i) {
        const int32_t value=int16_t(RectBounds::word(from+2*i));
        const int32_t bound=int16_t(RectBounds::word(pm+6+2*i));
        if((i<2 ? value<bound : value>bound) || RectBounds::word(to+2*i)!=RectBounds::word(frame+2*i))return 0;
    }
    if(int16_t(RectBounds::word(from+4))<=int16_t(RectBounds::word(from))
       || int16_t(RectBounds::word(from+6))<=int16_t(RectBounds::word(from+2)))return 0;
    for(uint32_t i=0;i<52;++i)out[i]=0;
    bytes(out+2,frame,8);word(out+10,0x11);word(out+12,0x2ff);word(out+14,0xc00);
    for(unsigned i=16;i<20;++i)out[i]=0xff;
    // Fixed-point header bounds, in left/top/right/bottom order.
    bytes(out+20,frame+2,2);bytes(out+24,frame,2);
    bytes(out+28,frame+6,2);bytes(out+32,frame+4,2);
    word(out+40,1);word(out+42,10);bytes(out+44,frame,8);
    word(out+52,0x98);bytes(out+54,pm+4,46);
    word(out+54,0x8000|stride);bytes(out+56,from,8);word(out+64,0);
    bytes(out+100,colors,2056);
    word(out+104,0x8000); // sequential colour indices, no live table pointer
    for(unsigned i=92;i<100;++i)out[i]=0;
    bytes(out+2156,from,8);bytes(out+2164,to,8);word(out+2172,mode);
    uint32_t at=2174;
    for(int32_t y=0;y<height;++y) {
        const uint32_t sy=uint32_t(int16_t(RectBounds::word(from))-int16_t(RectBounds::word(pm+6)))+uint32_t(y);
        const uint32_t sx=uint32_t(int16_t(RectBounds::word(from+2))-int16_t(RectBounds::word(pm+8)));
        const uint8_t* row=pixels+sy*sourceStride+sx;
        const uint32_t prefix=at;at+=stride>250?2:1;
        const uint32_t start=at;
        uint16_t x=0;
        while(x<stride) {
            uint16_t run=1;
            while(x+run<stride && run<128 && row[x+run]==row[x])++run;
            if(run>=3) {out[at++]=uint8_t(1-int16_t(run));out[at++]=row[x];x+=run;}
            else {
                const uint16_t first=x;x+=run;
                while(x<stride && x-first<128) {
                    run=1;while(x+run<stride && run<3 && row[x+run]==row[x])++run;
                    if(run>=3)break;
                    ++x;
                }
                out[at++]=uint8_t(x-first-1);bytes(out+at,row+first,x-first);at+=x-first;
            }
        }
        if(stride>250)word(out+prefix,uint16_t(at-start));else out[prefix]=uint8_t(at-start);
    }
    if(at&1)out[at++]=0;
    word(out+at,0xff);at+=2;word(out,at<=65535?uint16_t(at):0);
    return at;
}
}
#endif
