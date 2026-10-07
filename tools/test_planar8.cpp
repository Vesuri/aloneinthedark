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
    Planar8::Rect previous[32];uint16_t previousCount=0;
    Planar8::Rect viewport{150,160,350,480};
    uint32_t seed=7;
    auto random=[&]() {seed=seed*1664525u+1013904223u;return seed;};
    unsigned merged=0,skipped=0,copied=0;
    for(unsigned frame=0;frame<400;++frame) {
        // Up to 40 dirty rectangles exercises the bounding-box fallback.
        std::vector<Planar8::Rect> dirty;
        unsigned count=frame%41==40 ? 40 : frame%13;
        for(unsigned i=0;i<count;++i) {
            int16_t left=random()%320,top=random()%200;
            int16_t right=left+1+random()%(320-left),bottom=top+1+random()%(200-top);
            if(i&1) {right=left+1+random()%8;if(right>320)right=320;}
            dirty.push_back({int16_t(top+viewport.top),int16_t(left+viewport.left),
                             int16_t(bottom+viewport.top),int16_t(right+viewport.left)});
        }
        if(frame%17==0)dirty={viewport};
        // Only dirty pixels change; everything else must survive from earlier frames.
        for(const auto& r:dirty)for(int y=r.top;y<r.bottom;++y)for(int x=r.left;x<r.right;++x)
            source[y*640+x]=uint8_t(frame*37+x*13+y*71);
        Planar8::Rect converted[32];uint16_t convertedCount=0;
        for(const auto& r:dirty) {
            Planar8::Rect local;
            assert(Planar8::normalize(viewport,r,local));
            if(local.top<local.bottom && local.left<local.right)
                Planar8::append(converted,convertedCount,32,local);
        }
        assert(convertedCount<=32);
        merged+=dirty.size()-convertedCount;
        // Converted rectangles cover every dirty pixel.
        for(const auto& r:dirty)for(int y=r.top;y<r.bottom;++y)for(int x=r.left;x<r.right;++x) {
            bool covered=false;
            for(uint16_t i=0;i<convertedCount;++i) {
                const auto& c=converted[i];
                covered|=y-viewport.top>=c.top && y-viewport.top<c.bottom
                    && x-viewport.left>=c.left && x-viewport.left<c.right;
            }
            assert(covered);
        }
        for(uint16_t i=0;i<previousCount;++i) {
            const auto& r=previous[i];
            if(!Planar8::syncNeeded(r,converted,convertedCount)) {++skipped;continue;}
            ++copied;
            for(int y=r.top;y<r.bottom;++y)for(unsigned p=0;p<8;++p)
                for(int x=r.left/8;x<r.right/8;++x)back[y*320+p*40+x]=front[y*320+p*40+x];
        }
        for(uint16_t i=0;i<convertedCount;++i) {
            const auto& r=converted[i];
            assert(!(r.left&15) && !((r.right-r.left)&31));
            Planar8::Rect global{int16_t(r.top+viewport.top),int16_t(r.left+viewport.left),
                int16_t(r.bottom+viewport.top),int16_t(r.right+viewport.left)},out;
            assert(Planar8::convert(source.data(),back.data(),viewport,global,out));
        }
        Planar8::Mismatch mismatch{};
        assert(Planar8::verify(source.data(),back.data(),viewport,mismatch));
        front.swap(back);
        for(uint16_t i=0;i<convertedCount;++i)previous[i]=converted[i];
        previousCount=convertedCount;
    }
    assert(merged && skipped && copied);
    puts("PASS Planar8 dirty-rectangle synchronization: 400 alternating-buffer frames, merged/overlapping/full/empty/overflowing updates, exact frame verification");
}
int main() {
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
    // Every clipped span must cover its dirty input, stay within one row,
    // and obey the assembly width/word-start contract, including right edges.
    for(int left=0;left<320;++left)for(int right=left+1;right<=320;++right) {
        Planar8::Rect r;
        assert(Planar8::normalize(viewport,{150,int16_t(160+left),151,int16_t(160+right)},r));
        assert(r.left>=0 && r.left<=left && r.right>=right && r.right<=320);
        assert(!(r.left&15) && !((r.right-r.left)&31));
    }
    assert(Planar8::normalize(viewport,{150,338,286,360},partial));
    assert(same(partial,{0,176,136,208}));
    Planar8::Rect overlapping[2];uint16_t overlapCount=0;
    Planar8::append(overlapping,overlapCount,2,{0,16,1,48});
    Planar8::append(overlapping,overlapCount,2,{0,32,1,64});
    assert(overlapCount==2); // A 48-pixel union would violate Kalms' contract.
    Planar8::append(overlapping,overlapCount,1,{0,32,1,64});
    assert(overlapCount==1 && same(overlapping[0],{0,16,1,80}));
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
    puts("PASS Planar8: all pens/planes, full viewport, partial preservation, word-aligned 32-pixel spans, edge clipping and invalid-input atomicity");
}
