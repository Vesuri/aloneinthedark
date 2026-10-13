#ifndef AMIGAXDEV_RGB_COLOR_CACHE_H
#define AMIGAXDEV_RGB_COLOR_CACHE_H
#ifndef __mc68000__
#include <stdint.h>
#endif
#include "GWorld8.h"
#include "BigEndianMemory.h"

namespace RGBColorCache {
// One instance per port. The caller owns table lifetimes and must invalidate
// on writes that do not change the QuickDraw seed (e.g. rebuilding an ITable).
// Both dereferenced contents addresses, seeds and table headers form the key.
// Mac table edits publish a new seed; master pointers alone are not identities.
struct Cache {
    const uint8_t* colors;
    const uint8_t* inverse;
    uint32_t colorSeed,inverseSeed,header;
    uint16_t resolution;
    struct Entry { uint32_t rg; uint16_t b,indexPlusOne; } entries[256];
    void invalidate() { colors=0; }
    bool same(const uint8_t* ct,const uint8_t* it) const {
        using namespace BigEndianMemory;
        return ct==colors && it==inverse && read32(ct)==colorSeed
            && read32(it)==inverseSeed && read32(ct+4)==header
            && read16(it+4)==resolution;
    }
    static unsigned slot(uint32_t rg,uint16_t b) {
        return ((rg>>24)^(rg>>12)^(b>>8))&255;
    }
    // Keep validation/refill's live values and stack off the common hit path.
    __attribute__((noinline)) bool miss(const uint8_t* ct,const uint8_t* it,
                                       const uint8_t* rgb,uint16_t& result) {
        using namespace BigEndianMemory;
        if(!ct || !it || !rgb)return false;
        if(!same(ct,it)) {
            for(unsigned i=0;i<256;++i)entries[i].indexPlusOne=0;
            colors=ct;inverse=it;colorSeed=read32(ct);inverseSeed=read32(it);
            header=read32(ct+4);resolution=read16(it+4);
        }
        if(!GWorld8::colorIndex(ct,it,rgb,result))return false;
        uint32_t rg=read32(rgb);uint16_t b=read16(rgb+4);
        Entry& e=entries[slot(rg,b)];
        e.rg=rg;e.b=b;e.indexPlusOne=result+1;
        return true;
    }
    bool lookup(const uint8_t* ct,const uint8_t* it,const uint8_t* rgb,
                uint16_t& result) {
        using namespace BigEndianMemory;
        if(ct && it && rgb && same(ct,it)) {
            uint32_t rg=read32(rgb);uint16_t b=read16(rgb+4);
            const Entry& e=entries[slot(rg,b)];
            if(e.indexPlusOne && e.rg==rg && e.b==b) {
                result=e.indexPlusOne-1;return true;
            }
        }
        return miss(ct,it,rgb,result);
    }
};
}
#endif
