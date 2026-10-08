#ifndef AITD_INVERT_REGION8_H
#define AITD_INVERT_REGION8_H
#include "RegionRows.h"
namespace InvertRegion8 {
// Indexed Color QuickDraw inversion complements pixel indexes. The caller
// supplies the intersection of the shape and the complete clipping region.
inline bool draw(uint8_t* pixels,uint32_t bytes,uint16_t stride,const uint8_t* map,
                 const uint8_t* port,const uint8_t* visible,const uint8_t* region,
                 uint16_t regionBytes,uint8_t* drawn) {
    if(!pixels || !map || !port || !visible || !drawn)return false;
    int32_t mapTop=RegionRows::get(map),mapLeft=RegionRows::get(map+2);
    int32_t h=RegionRows::get(map+4)-mapTop,w=RegionRows::get(map+6)-mapLeft;
    if(h<=0 || w<=0 || w>stride || uint32_t(h)*stride>bytes)return false;
    RegionRows::Cursor rows;if(!rows.begin(region,regionBytes))return false;
    int16_t bounds[4];
    for(uint16_t i=0;i<4;++i) {
        int16_t value=RegionRows::get(map+i*2);
        const uint8_t* boxes[3]={port,visible,region+2};
        for(uint16_t j=0;j<3;++j) {
            int16_t v=RegionRows::get(boxes[j]+i*2);
            if(i<2 ? v>value : v<value)value=v;
        }
        bounds[i]=value;
    }
    bool nonempty=bounds[0]<bounds[2] && bounds[1]<bounds[3];
    for(uint16_t i=0;i<4;++i)WindowGeometry::word(drawn+i*2,nonempty?uint16_t(bounds[i]):0);
    if(!nonempty)return true;
    for(int32_t y=bounds[0];y<bounds[2];++y) {
        if(!rows.advance(int16_t(y)))return false;
        for(uint16_t i=0;i<rows.edges.count;i+=2) {
            int32_t left=rows.edges.x[i],right=rows.edges.x[i+1];
            if(left<bounds[1])left=bounds[1];if(right>bounds[3])right=bounds[3];
            if(left>=right)continue;
            uint8_t* p=pixels+uint32_t(y-mapTop)*stride+uint32_t(left-mapLeft);
            for(int32_t x=left;x<right;++x)*p++^=0xff;
        }
    }
    return true;
}
}
#endif
