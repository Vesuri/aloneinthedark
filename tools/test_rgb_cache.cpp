#include <cassert>
#include <cstring>
#include <vector>
#include "../src/mac/RGBColorCache.h"
int main() {
    RGBColorCache::Cache cache{};
    uint8_t ct[2056]={},ct2[2056],rgb[6];
    std::vector<uint8_t> it(32768+524),it2;
    std::vector<uint16_t> grid(34*34*34),queue(32768);
    GWorld8::word(ct+6,255);
    for(unsigned i=0;i<256;++i) {
        GWorld8::word(ct+8+8*i,i);
        GWorld8::word(ct+10+8*i,(i*257)^0x5555);
        GWorld8::word(ct+12+8*i,i*257);
        GWorld8::word(ct+14+8*i,(255-i)*257);
    }
    auto check=[&](const uint8_t* c,const uint8_t* t) {
        uint16_t a=0xaaaa,b=a;
        bool x=cache.lookup(c,t,rgb,a),y=GWorld8::colorIndex(c,t,rgb,b);
        assert(x==y && a==b);
    };
    for(unsigned resolution: {4U,5U}) {
        assert(GWorld8::inverse(ct,resolution,it.data(),grid.data(),queue.data()));
        cache.invalidate();
        uint32_t random=1;
        for(unsigned n=0;n<5000;++n) {
            for(auto& b:rgb) {random=random*1664525+1013904223;b=random>>24;}
            check(ct,it.data());check(ct,it.data());
        }
        for(unsigned i=0;i<256;++i) {
            memcpy(rgb,ct+10+8*i,6);check(ct,it.data());check(ct,it.data());
        }
        // Relocation/replacement of either contents address, independent seeds,
        // header/resolution changes, same-seed rebuilds, and port reuse.
        memcpy(ct2,ct,sizeof ct);it2=it;
        check(ct2,it.data());check(ct2,it2.data());
        ct2[3]++;check(ct2,it2.data());it2[3]++;check(ct2,it2.data());
        ct2[4]=0x40;check(ct2,it2.data());ct2[4]=0;check(ct2,it2.data());
        it2[5]=3;check(ct2,it2.data());it2=it;check(ct,it2.data());
        cache.invalidate();ct[10]^=0x10;
        assert(GWorld8::inverse(ct,resolution,it.data(),grid.data(),queue.data()));
        check(ct,it.data());cache.invalidate();check(ct,it.data());
        // Failure is never cached; null input must leave the result untouched.
        uint16_t out=1234;assert(!cache.lookup(nullptr,it.data(),rgb,out)&&out==1234);
        assert(!cache.lookup(ct,nullptr,rgb,out)&&out==1234);
        assert(!cache.lookup(ct,it.data(),nullptr,out)&&out==1234);
    }
}
