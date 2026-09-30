#ifndef AITD_COPY_BITS8_H
#define AITD_COPY_BITS8_H
#include "RectBounds.h"
namespace CopyBits8 {
inline int32_t coord(const uint8_t* r,unsigned i) { return int16_t(RectBounds::word(r+2*i)); }
// Vette's unscaled clipping equations, applied to byte pixels. The caller
// supplies a measured colour map when the colour environments differ, and
// establishes distinct owned buffers.
inline bool copy(const uint8_t* src,uint32_t srcBytes,uint16_t srcStride,const uint8_t* srcMap,
                 uint8_t* dst,uint32_t dstBytes,uint16_t dstStride,const uint8_t* dstMap,
                 const uint8_t* from,const uint8_t* to,const uint8_t* port,
                 const uint8_t* vis,const uint8_t* clip,uint8_t* drawn,const uint8_t* colors=0) {
    if(!src || !dst || src==dst || !srcMap || !dstMap || !from || !to
       || !port || !vis || !clip || !drawn)return false;
    const uint8_t* maps[2]={srcMap,dstMap};uint32_t sizes[2]={srcBytes,dstBytes};
    uint16_t strides[2]={srcStride,dstStride};
    for(unsigned i=0;i<2;++i) {
        int32_t h=coord(maps[i],2)-coord(maps[i],0),w=coord(maps[i],3)-coord(maps[i],1);
        if(h<=0 || w<=0 || uint32_t(w)>strides[i] || uint32_t(h)*strides[i]>sizes[i])return false;
    }
    int32_t h=coord(from,2)-coord(from,0),w=coord(from,3)-coord(from,1);
    if(h<=0 || w<=0 || h!=coord(to,2)-coord(to,0) || w!=coord(to,3)-coord(to,1))return false;
    int32_t limits[4];
    for(unsigned i=0;i<4;++i) {
        int32_t bound=coord(to,i),source=coord(to,i<2?i:i-2)+coord(srcMap,i)-coord(from,i<2?i:i-2);
        bound=i<2 ? (bound>source?bound:source) : (bound<source?bound:source);
        const uint8_t* boxes[4]={dstMap,port,vis,clip};
        for(unsigned j=0;j<4;++j) {
            int32_t v=coord(boxes[j],i);bound=i<2 ? (bound>v?bound:v) : (bound<v?bound:v);
        }
        limits[i]=bound;
    }
    bool nonempty=limits[0]<limits[2] && limits[1]<limits[3];
    for(unsigned i=0;i<4;++i) {
        uint16_t v=nonempty?uint16_t(limits[i]):0;drawn[2*i]=uint8_t(v>>8);drawn[2*i+1]=uint8_t(v);
    }
    if(!nonempty)return true;
    for(int32_t y=limits[0];y<limits[2];++y) {
        const uint8_t* source=src+uint32_t(coord(from,0)+y-coord(to,0)-coord(srcMap,0))*srcStride;
        uint8_t* target=dst+uint32_t(y-coord(dstMap,0))*dstStride;
        for(int32_t x=limits[1];x<limits[3];++x) {
            uint8_t pixel=source[coord(from,1)+x-coord(to,1)-coord(srcMap,1)];
            target[x-coord(dstMap,1)]=colors ? colors[pixel] : pixel;
        }
    }
    return true;
}
}
#endif
