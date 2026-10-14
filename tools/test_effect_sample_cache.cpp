#include <cstdint>
#include <cstdlib>
#include <cassert>
#include <cstdio>
#include <map>
#include <vector>
#include "mac/EffectSampleCache.h"
struct Memory {
    static inline std::map<void*,uint32_t> live;
    static inline int fail=-1;
    static uint8_t* fast(uint32_t n) {
        if(fail==0)return nullptr;
        if(fail>0)--fail;
        auto p=(uint8_t*)malloc(n);live[p]=n;return p;
    }
    static uint8_t* chip(uint32_t n) {return fast(n);}
    static void free(uint8_t* p,uint32_t n) {assert(live.at(p)==n);live.erase(p);::free(p);}
};
int main() {
    EffectSampleCache<Memory> cache;
    assert(!cache.acquire(nullptr,0) && !cache.acquire(nullptr,131071));
    for(unsigned n: {1,2,3,4,127,128,129,4096,65535,131069,131070})for(unsigned offset=0;offset<4;++offset) {
        std::vector<uint8_t> src(n+offset),copy(n);
        for(unsigned i=0;i<n;++i)src[offset+i]=copy[i]=(i*17+n)&255;
        auto* e=cache.acquire(src.data()+offset,n);assert(e);
        for(unsigned i=0;i<n;++i)assert(e->chip[i]==(copy[i]^128));
        for(unsigned i=n;i<cache.allocation(n);++i)assert(!e->chip[i]);
        assert(cache.acquire(copy.data(),n)==e && e->users==2); // Relocated body.
        cache.release(e);cache.clearUnused();assert(e->users==1);
        cache.release(e);
        src[offset+n/2]^=1; // Same source address, new content must not hit.
        auto* changed=cache.acquire(src.data()+offset,n);assert(changed);
        assert(changed->chip[n/2]==(src[offset+n/2]^128));
        cache.release(changed);cache.clearUnused();assert(Memory::live.empty());
    }
    uint8_t a[7]={};
    for(int fail=0;fail<2;++fail) {
        Memory::fail=fail;assert(!cache.acquire(a,7));assert(Memory::live.empty());
    }
    Memory::fail=-1;
    std::vector<uint8_t> large(70000);
    auto* pinned=cache.acquire(large.data(),large.size());assert(pinned);
    large[5]=1;assert(!cache.acquire(large.data(),large.size())); // Budget cannot evict DMA.
    assert(pinned->chip[5]==128);cache.release(pinned);cache.clearUnused();
    EffectSampleCache<Memory>::Entry* entries[4];
    for(unsigned i=0;i<4;++i) {a[0]=i;entries[i]=cache.acquire(a,7);assert(entries[i]);}
    a[0]=4;assert(!cache.acquire(a,7));
    for(auto* e:entries)cache.release(e);
    assert(cache.acquire(a,7)); // Eviction after unpinning.
    for(auto& e:cache.entries)if(e.users)cache.release(&e);
    cache.clearUnused();assert(cache.retained==0 && Memory::live.empty());
    puts("PASS effect sample cache: alignment, odd tails, exact content, sharing, pinning, budget, eviction and allocation failure");
}
