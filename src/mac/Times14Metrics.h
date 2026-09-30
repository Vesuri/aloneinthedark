#ifndef AITD_TIMES14_METRICS_H
#define AITD_TIMES14_METRICS_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
// Measured Times/plain/14 advances. These are spacing metrics, not font artwork.
// The Mac accumulates these units with scale 299/256, then truncates once.
namespace Times14Metrics {
inline bool width(const uint8_t* text,int16_t first,int16_t count,uint16_t& result) {
    if(first<0 || count<0 || (!text && count))return false;
    static const uint8_t advances[256]={
        0,4,4,4,4,4,4,4,4,3,4,4,4,0,4,4,
        4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
        3,4,5,6,6,10,10,2,4,4,6,7,3,4,3,3,
        6,6,6,6,6,6,6,6,6,6,3,3,7,7,7,5,
        11,9,8,8,9,8,7,9,9,4,5,9,7,11,9,9,
        7,9,8,7,7,9,9,12,9,9,8,4,3,4,6,6,
        4,5,6,5,6,5,4,6,6,3,3,6,3,10,6,6,
        6,6,4,5,3,6,6,9,6,6,5,6,2,6,7,4,
        9,9,8,8,9,9,9,6,5,5,5,5,5,5,5,5,
        5,5,3,3,3,3,6,6,6,6,6,6,6,6,6,6,
        6,5,6,6,6,4,6,6,9,9,12,4,4,7,11,9,
        9,7,7,7,6,6,6,9,10,7,4,4,4,10,8,6,
        5,4,7,7,6,7,8,6,6,12,3,9,9,9,11,9,
        6,12,6,6,4,4,7,6,6,9,2,6,4,4,7,7,
        6,3,4,6,12,9,8,9,8,8,4,4,4,4,9,9,
        10,9,9,9,9,3,4,4,4,4,4,4,4,4,4,4,
    };
    uint32_t total=0;
    for(uint16_t i=0;i<(uint16_t)count;++i)total+=advances[text[(uint32_t)first+i]];
    total=(total*299)>>8;
    if(total>32767)return false; // Unmeasured signed-result overflow.
    result=(uint16_t)total;return true;
}
}
#endif
