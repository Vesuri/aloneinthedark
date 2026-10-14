#ifndef AITD_EFFECT_SAMPLE_CACHE_H
#define AITD_EFFECT_SAMPLE_CACHE_H

// One-shot raw PCM only. Caller supplies allocation policy; no IRQ accesses this
// cache. Exact source-byte validation also covers reused/moved game allocations.
template<class Memory> class EffectSampleCache {
public:
    struct Entry { uint8_t* original; uint8_t* chip; uint32_t size; uint16_t users; };
    static const uint32_t budget=131072;
    Entry entries[4]={};
    uint32_t retained=0;
    static uint32_t allocation(uint32_t size) {return ((size+1)&~1UL)+2;}
    void clearUnused() {
        for(auto& e:entries)if(e.chip && !e.users)discard(e);
    }
    void release(Entry* e) {if(e)--e->users;}
    Entry* acquire(const uint8_t* pcm,uint32_t size) {
        if(!size || size>131070)return 0;
        for(auto& e:entries)if(e.chip && e.size==size && equal(e.original,pcm,size)) {
            ++e.users;return &e;
        }
        const uint32_t bytes=allocation(size);
        if(bytes>budget)return 0;
        Entry* slot=0;
        for(auto& e:entries)if(!e.chip) {slot=&e;break;}
        if(!slot)for(auto& e:entries)if(!e.users) {slot=&e;break;}
        if(!slot)return 0;
        if(slot->chip)discard(*slot);
        if(retained+bytes>budget)clearUnused();
        if(retained+bytes>budget)return 0;
        uint8_t* original=Memory::fast(size);
        uint8_t* chip=original ? Memory::chip(bytes) : 0;
        if(!chip) {
            if(original)Memory::free(original,size);
            clearUnused();return 0; // Optional cache: caller retains uncached fallback.
        }
        uint32_t i=0;
        for(;i+4<=size;i+=4) {
            const uint32_t value=load(pcm+i);
            store(original+i,value);
            store(chip+i,value^0x80808080UL);
        }
        for(;i<size;++i) {original[i]=pcm[i];chip[i]=pcm[i]^0x80;}
        for(;i<bytes;++i)chip[i]=0;
        *slot={original,chip,size,1};retained+=bytes;return slot;
    }
private:
    struct __attribute__((packed,may_alias)) Long {uint32_t value;};
    static uint32_t load(const uint8_t* p) {
#ifdef AITD_PLATFORM_AMIGA
        uint32_t value;
        __asm__("move.l %1,%0" : "=d"(value) : "m"(*(const Long*)p));
        return value;
#else
        return ((const Long*)p)->value;
#endif
    }
    static void store(uint8_t* p,uint32_t value) {
#ifdef AITD_PLATFORM_AMIGA
        __asm__("move.l %1,%0" : "=m"(*(Long*)p) : "d"(value));
#else
        ((Long*)p)->value=value;
#endif
    }
    static bool equal(const uint8_t* a,const uint8_t* b,uint32_t size) {
        uint32_t i=0;
        for(;i+4<=size;i+=4)if(load(a+i)!=load(b+i))return false;
        for(;i<size;++i)if(a[i]!=b[i])return false;
        return true;
    }
    void discard(Entry& e) {
        const uint32_t bytes=allocation(e.size);
        Memory::free(e.original,e.size);Memory::free(e.chip,bytes);
        retained-=bytes;e={};
    }
};
#endif
