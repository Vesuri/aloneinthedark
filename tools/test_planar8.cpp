#include "../src/platform/amiga/Planar8.h"
#include <cassert>
#include <vector>
#include <cstdio>
#include <algorithm>

static unsigned decode(const uint8_t* plane,unsigned x,unsigned y) {
    unsigned pixel=0;
    for(unsigned bit=0;bit<8;++bit)
        if(plane[y*320+bit*40+x/8] & (128u>>(x%8)))pixel|=1u<<bit;
    return pixel;
}
static bool same(const Planar8::Rect& a,const Planar8::Rect& b) {
    return a.top==b.top && a.left==b.left && a.bottom==b.bottom && a.right==b.right;
}
int main() {
    std::vector<uint8_t> source(640*480),storage(Planar8::bytes+64,0xa5);
    uint8_t* output=storage.data()+32;
    for(unsigned y=0;y<480;++y)for(unsigned x=0;x<640;++x)
        source[y*640+x]=uint8_t(x*37+y*71+(x^y));
    // Every bit position, all 256 pens, and an asymmetric spatial pattern.
    for(unsigned x=0;x<320;++x)source[150*640+160+x]=uint8_t(x);
    const auto original=source;
    Planar8::Rect viewport{150,160,350,480},full{},partial{};
    assert(Planar8::convert(source.data(),output,viewport,viewport,full));
    assert(same(full,{0,0,200,320}));
    for(unsigned y=0;y<200;++y)for(unsigned x=0;x<320;++x)
        assert(decode(output,x,y)==source[(y+150)*640+x+160]);
    auto previous=storage;
    std::fill(source.begin(),source.end(),0x69);
    assert(Planar8::convert(source.data(),output,viewport,{153,195,155,229},partial));
    assert(same(partial,{3,32,5,96}));
    for(unsigned y=0;y<200;++y)for(unsigned x=0;x<320;++x)
        assert(decode(output,x,y)==(y>=3 && y<5 && x>=32 && x<96 ? 0x69 : decode(previous.data()+32,x,y)));
    for(unsigned i=0;i<32;++i)assert(storage[i]==0xa5 && storage[storage.size()-32+i]==0xa5);
    // Clipping at all viewport edges, including an unaligned source origin.
    assert(Planar8::normalize(viewport,{-32768,-32768,32767,32767},partial));
    assert(same(partial,full));
    assert(Planar8::normalize({151,161,351,481},{150,160,153,162},partial));
    assert(same(partial,{0,0,2,32}));
    assert(Planar8::normalize(viewport,{349,479,480,640},partial));
    assert(same(partial,{199,288,200,320}));
    previous=storage;
    assert(Planar8::convert(source.data(),output,viewport,{0,0,150,160},partial));
    assert(same(partial,{0,0,0,0}) && storage==previous);
    for(auto bad: {Planar8::Rect{-1,160,199,480},Planar8::Rect{150,321,350,641},
                   Planar8::Rect{150,160,351,480},Planar8::Rect{281,160,481,480}}) {
        partial={1,2,3,4};
        assert(!Planar8::convert(source.data(),output,bad,viewport,partial));
        assert(storage==previous && same(partial,{1,2,3,4}));
    }
    assert(!Planar8::convert(nullptr,output,viewport,viewport,partial));
    assert(!Planar8::convert(source.data(),nullptr,viewport,viewport,partial));
    assert(!Planar8::convert(source.data(),output,viewport,{10,10,0,0},partial));
    assert(storage==previous);
    // Initial source is read-only; verify the full converter on a fresh buffer.
    auto immutable=original;
    assert(Planar8::convert(immutable.data(),output,viewport,viewport,full));
    assert(immutable==original);
    Planar8::Rect shifted{151,161,351,481};
    assert(Planar8::convert(immutable.data(),output,shifted,shifted,full));
    for(unsigned y=0;y<200;++y)for(unsigned x=0;x<320;++x)
        assert(decode(output,x,y)==immutable[(y+151)*640+x+161]);
    puts("PASS Planar8: all pens/planes, full viewport, partial preservation, 32-pixel alignment, edge clipping and invalid-input atomicity");
}
