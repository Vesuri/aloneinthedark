#ifndef AMIGAXDEV_REGION_RESULT_CACHE_H
#define AMIGAXDEV_REGION_RESULT_CACHE_H
#include "RegionRows.h"
namespace RegionResultCache {
// Exact geometry records only, never pixels or handle addresses. Positive
// results are copied into bounded owned storage. Recycled/moved handles and
// mutations therefore cannot resurrect a previous shape. No heap allocation.
struct Cache {
    enum { capacity=32768, slots=32 };
    struct Entry { uint16_t offset,keySize,valueSize,kind; };
    Entry entries[slots]{};
    uint8_t storage[capacity];
    uint16_t cursor=0,next=0;
    bool get(uint16_t kind,const uint8_t* key,uint32_t bytes,uint8_t* out,
             uint16_t limit,uint16_t& size) const {
        if(!key || !out || bytes<10)return false;
        uint16_t extent=uint16_t(RegionRows::get(key));
        if(extent<10 || extent>bytes)return false;
        for(uint16_t i=0;i<slots;++i) {
            const Entry& entry=entries[i];
            if(entry.kind!=kind || entry.keySize!=extent || entry.valueSize>limit)continue;
            const uint8_t* stored=storage+entry.offset;
            if(!RegionRows::ValidationCache::same(stored,key,extent))continue;
            size=entry.valueSize;
            for(uint16_t j=0;j<size;++j)out[j]=stored[extent+j];
            return true;
        }
        return false;
    }
    void put(uint16_t kind,const uint8_t* key,const uint8_t* value,uint16_t size) {
        uint16_t extent=uint16_t(RegionRows::get(key));
        uint32_t bytes=uint32_t(extent)+size;
        if(bytes>capacity)return;
        if(cursor+bytes>capacity)cursor=0;
        for(uint16_t i=0;i<slots;++i) {
            Entry& entry=entries[i];
            if(entry.kind && cursor<uint32_t(entry.offset)+entry.keySize+entry.valueSize
               && entry.offset<cursor+bytes)entry.kind=0;
        }
        for(uint16_t i=0;i<extent;++i)storage[cursor+i]=key[i];
        for(uint16_t i=0;i<size;++i)storage[cursor+extent+i]=value[i];
        entries[next]={cursor,extent,size,kind};next=(next+1)%slots;
        cursor+=bytes;
    }
};
}
#endif
