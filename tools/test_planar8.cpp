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
static void checkBufferSync() {
    std::vector<uint8_t> source(640*480),front(Planar8::bytes),back(Planar8::bytes);
    std::vector<Planar8::Rect> previous;
    const Planar8::Rect viewport{0,0,200,320};
    uint32_t seed=7;
    auto random=[&]() {seed=seed*1664525u+1013904223u;return seed;};
    for(unsigned frame=0;frame<160;++frame) {
        std::vector<Planar8::Rect> dirty,converted;
        unsigned count=frame%13;
        for(unsigned i=0;i<count;++i) {
            int16_t left=random()%320,top=random()%200;
            int16_t right=left+1+random()%(320-left),bottom=top+1+random()%(200-top);
            dirty.push_back({top,left,bottom,right});
        }
        if(frame%17==0)dirty={viewport};
        for(const auto& r:dirty) {
            for(int y=r.top;y<r.bottom;++y)for(int x=r.left;x<r.right;++x)
                source[y*640+x]=uint8_t(frame*37+x*13+y*71);
            Planar8::Rect local;
            assert(Planar8::normalize(viewport,r,local));converted.push_back(local);
        }
        for(const auto& r:previous)for(int16_t y=r.top;y<r.bottom;++y) {
            uint16_t mask=Planar8::syncRowMask(r,y,converted.data(),converted.size());
            // Compare selected bytes against geometric coverage, independently
            // of the helper's bit arithmetic, then synchronize the old buffer.
            for(int x=0;x<320;x+=8) {
                bool needed=x>=r.left && x<r.right;
                for(const auto& c:converted)
                    if(y>=c.top && y<c.bottom && x>=c.left && x<c.right)needed=false;
                assert(bool(mask&(1u<<(x/32)))==needed);
                if(needed)for(unsigned p=0;p<8;++p)back[y*320+p*40+x/8]=front[y*320+p*40+x/8];
            }
        }
        for(const auto& r:dirty) {
            Planar8::Rect local;
            assert(Planar8::convert(source.data(),back.data(),viewport,r,local));
        }
        Planar8::Mismatch mismatch{};
        assert(Planar8::verify(source.data(),back.data(),viewport,mismatch));
        front.swap(back);previous=converted;
    }
    const Planar8::Rect full{0,0,200,320},split[]={{0,0,200,160},{0,160,200,320}};
    for(int16_t y=0;y<200;++y)assert(Planar8::syncRowMask(full,y,split,2)==0);
    puts("PASS Planar8 synchronization: 160 alternating-buffer frames, overlapping/disjoint/full/empty updates and exact copied-byte coverage");
}
static void checkChangedBlocks() {
    std::vector<uint8_t> source(640*480),cache(64000,0xa5),front(64000),back(64000);
    uint16_t previous[200]={},changed[200];
    Planar8::Rect viewport{150,160,350,480},full{0,0,200,320};
    for(unsigned frame=0;frame<240;++frame) {
        bool force=frame==0 || frame%47==0;
        if(force && frame) {
            viewport.left^=1;viewport.right=viewport.left+320;
            viewport.top^=1;viewport.bottom=viewport.top+200;
        }
        // Broad dirty rectangles with sparse actual changes, including frames
        // with no changes and pixels reverting to their earlier values.
        if(frame%5)for(unsigned n=0;n<79;++n) {
            unsigned x=(n*37+frame*13)%320,y=(n*19+frame*7)%200;
            source[(y+viewport.top)*640+x+viewport.left]^=uint8_t(1u<<(n%8));
        }
        auto oldCache=cache;
        Planar8::changedRows(source.data(),cache.data(),viewport,&full,1,force,changed);
        for(unsigned y=0;y<200;++y)for(unsigned b=0;b<10;++b) {
            bool differs=force;
            for(unsigned x=b*32;x<b*32+32;++x)
                differs|=oldCache[y*320+x]!=source[(y+viewport.top)*640+x+viewport.left];
            assert(bool(changed[y]&(1u<<b))==differs);
            if((previous[y]&(1u<<b)) && !differs)
                for(unsigned p=0;p<8;++p)for(unsigned byte=b*4;byte<b*4+4;++byte)
                    back[y*320+p*40+byte]=front[y*320+p*40+byte];
            if(differs) {
                Planar8::Rect r{int16_t(y+viewport.top),int16_t(b*32+viewport.left),
                    int16_t(y+viewport.top+1),int16_t(b*32+viewport.left+32)},converted;
                assert(Planar8::convert(source.data(),back.data(),viewport,r,converted));
            }
        }
        Planar8::Mismatch mismatch{};
        assert(Planar8::verify(source.data(),back.data(),viewport,mismatch));
        front.swap(back);std::copy(changed,changed+200,previous);
    }
    puts("PASS changed blocks: 240 alternating buffers, sparse/reverted/unchanged pixels and odd viewport moves");
}
int main() {
    checkChangedBlocks();
    checkBufferSync();
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
    Planar8::Mismatch mismatch{};
    assert(Planar8::verify(source.data(),output,viewport,mismatch));
    // Each hardware plane must be checked, including a pixel outside a later
    // partial update and the final pixel of the viewport.
    for(unsigned bit=0;bit<8;++bit) {
        const unsigned at=199*320+bit*40+39;
        output[at]^=1;
        assert(!Planar8::verify(source.data(),output,viewport,mismatch));
        assert(mismatch.x==319 && mismatch.y==199);
        assert((mismatch.expected^mismatch.actual)==(1u<<bit));
        output[at]^=1;
    }
    for(unsigned y=0;y<200;++y)for(unsigned x=0;x<320;++x)
        assert(decode(output,x,y)==source[(y+150)*640+x+160]);
    auto previous=storage;
    std::fill(source.begin(),source.end(),0x69);
    assert(Planar8::convert(source.data(),output,viewport,{153,195,155,229},partial));
    assert(same(partial,{3,32,5,96}));
    // A partial conversion cannot claim the unrelated source changes match.
    assert(!Planar8::verify(source.data(),output,viewport,mismatch));
    auto partialSource=original;
    for(unsigned y=153;y<155;++y)
        std::fill(partialSource.begin()+y*640+192,partialSource.begin()+y*640+256,0x69);
    assert(Planar8::verify(partialSource.data(),output,viewport,mismatch));
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
    assert(Planar8::verify(immutable.data(),output,viewport,mismatch));
    Planar8::Rect shifted{151,161,351,481};
    assert(Planar8::convert(immutable.data(),output,shifted,shifted,full));
    assert(Planar8::verify(immutable.data(),output,shifted,mismatch));
    assert(!Planar8::verify(nullptr,output,shifted,mismatch));
    assert(!Planar8::verify(immutable.data(),nullptr,shifted,mismatch));
    assert(!Planar8::verify(immutable.data(),output,{0,0,1,1},mismatch));
    for(unsigned y=0;y<200;++y)for(unsigned x=0;x<320;++x)
        assert(decode(output,x,y)==immutable[(y+151)*640+x+161]);
    puts("PASS Planar8: all pens/planes, full viewport, partial preservation, 32-pixel alignment, edge clipping and invalid-input atomicity");
}
