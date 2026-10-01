#include <cstdint>
#include "../src/mac/MacHeap.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#define CHECK(x) do { if(!(x)){std::fprintf(stderr,"heap FAIL line %d: %s\n",__LINE__,#x);std::exit(1);} }while(0)
static void pattern(uint8_t* p,unsigned n,uint8_t v) {std::memset(p,v,n);}
static bool patternIs(uint8_t* p,unsigned n,uint8_t v) {for(unsigned i=0;i<n;++i)if(p[i]!=v)return false;return true;}
int main() {
    alignas(8) uint8_t arena[65536];MacHeap h;
    CHECK(h.init(arena,sizeof(arena)));CHECK(h.check());
    auto original=h.freeBytes();
    auto a=h.newHandle(300,true);auto b=h.newHandle(500);auto pin=h.newPtr(200);
    CHECK(a&&b&&pin);CHECK(patternIs(*a,300,0));pattern(*a,300,0x23);pattern(*b,500,0x45);pattern(pin,200,0x67);
    CHECK(!h.isFreeHandleSlot(a));CHECK(!h.isFreeHandleSlot(nullptr));
    CHECK(!h.isFreeHandleSlot((MacHeap::Handle)pin));
    CHECK(!h.isFreeHandleSlot((MacHeap::Handle)((uint8_t*)a+1)));
    auto before=*b;CHECK(h.setState(b,0xa0)==0);CHECK(h.state(b)==0xa0);
    CHECK(h.disposeHandle(a)==0);CHECK(h.isFreeHandleSlot(a));CHECK(!h.isHandle(a));h.compact();CHECK(*b==before);CHECK(patternIs(*b,500,0x45));CHECK(patternIs(pin,200,0x67));
    CHECK(h.emptyHandle(b)==MacHeap::memPurErr);CHECK(h.moveHigh(b)==MacHeap::memLockedErr);
    CHECK(h.setState(b,0x20)==0);h.compact();CHECK(h.check());CHECK(h.recoverHandle(*b+100)==b);
    CHECK(h.moveHigh(b)==0);CHECK(h.check());CHECK(patternIs(*b,500,0x45));
    CHECK(h.setHandleSize(b,1500)==0);CHECK(h.handleSize(b)==1500);CHECK(patternIs(*b,500,0x45));
    CHECK(h.setHandleSize(b,24)==0);CHECK(patternIs(*b,24,0x45));CHECK(h.emptyHandle(b)==0);CHECK(*b==nullptr);
    CHECK(h.reallocateHandle(b,1000)==0);CHECK(h.state(b)==0);CHECK(h.handleSize(b)==1000);
    CHECK(h.disposeHandle(b)==0);CHECK(h.disposePtr(pin)==0);CHECK(h.freeBytes()==original);CHECK(h.check());
    // Failed reallocation retains the pointer, contents and state.
    a=h.newHandle(400,true);pattern(*a,400,0x37);before=*a;CHECK(h.setState(a,0x60)==0);
    CHECK(h.reallocateHandle(a,0xffffffff)==MacHeap::memFullErr);
    CHECK(*a==before);CHECK(patternIs(*a,400,0x37));CHECK(h.state(a)==0x60);
    CHECK(h.setState(a,0x80)==0);CHECK(h.reallocateHandle(a,1)==MacHeap::memPurErr);
    CHECK(h.disposeHandle(a)==0);
    // MoreMasters really allocates master blocks in the zone and reuses disposed slots.
    std::vector<MacHeap::Handle> handles;
    for(unsigned i=0;i<160;++i){auto x=h.newEmptyHandle();CHECK(x);CHECK(h.owns(x));handles.push_back(x);}
    CHECK(h.freeBytes()<original);for(auto x:handles)CHECK(h.disposeHandle(x)==0);CHECK(h.check());
    // Purging releases eligible data and preserves a stable empty master pointer.
    CHECK(h.init(arena,sizeof(arena)));
    a=h.newHandle(16000);b=h.newHandle(16000);CHECK(a&&b);pattern(*b,16000,0x91);
    CHECK(h.setState(a,0x40)==0);CHECK(h.setState(b,0xc0)==0);
    auto c=h.newHandle(40000);CHECK(!c);CHECK(*a==nullptr);CHECK(*b!=nullptr);CHECK(patternIs(*b,16000,0x91));CHECK(h.check());
    CHECK(h.setState(b,0)==0);c=h.newHandle(40000);CHECK(c);CHECK(patternIs(*b,16000,0x91));CHECK(h.check());
    CHECK(h.newHandle(0xffffffff)==nullptr);CHECK(h.error()==MacHeap::memFullErr);CHECK(h.check());
    // Pointer growth may move adjacent unlocked handles, never the pointer itself.
    CHECK(h.init(arena,sizeof(arena)));pin=h.newPtr(32);a=h.newHandle(512);pattern(*a,512,0x52);
    CHECK(h.setPtrSize(pin,8192)==0);CHECK(h.ptrSize(pin)==8192);CHECK(patternIs(*a,512,0x52));CHECK(h.check());
    CHECK(h.setState(a,0x80)==0);before=*a;CHECK(h.setHandleSize(a,128)==0);CHECK(*a==before);CHECK(patternIs(*a,128,0x52));
    CHECK(h.disposeHandle(a)==0);CHECK(h.disposePtr(pin)==0);
    CHECK(h.newHandle(0)!=nullptr);CHECK(h.newPtr(0)!=nullptr);CHECK(h.check());
    // Read-only success and failure retain every arena byte, including the
    // published zone header and free-master chain, while reporting MemError.
    CHECK(h.init(arena,sizeof(arena),2));
    a=h.newHandle(37);b=h.newEmptyHandle();pin=h.newPtr(19);
    auto freed=h.newHandle(8);CHECK(h.disposeHandle(freed)==0);
    CHECK(h.setState(a,0xa0)==0);
    std::vector<uint8_t> queryArena(arena,arena+sizeof(arena));
    CHECK(h.handleSize(a)==37 && h.error()==0);
    CHECK(h.handleSize(b)==0 && h.error()==MacHeap::nilHandleErr);
    CHECK(h.handleSize(nullptr)==0 && h.error()==MacHeap::nilHandleErr);
    CHECK(h.ptrSize(pin)==19 && h.error()==0);
    CHECK(h.ptrSize(*a)==0 && h.error()==MacHeap::memWZErr);
    CHECK(h.state(a)==0xa0 && h.error()==0);
    CHECK(h.state(freed)==0 && h.error()==MacHeap::nilHandleErr);
    CHECK(h.recoverHandle(*a+5)==a && h.error()==0);
    CHECK(h.recoverHandle(pin)==nullptr && h.error()==MacHeap::nilHandleErr);
    CHECK(std::memcmp(arena,queryArena.data(),sizeof(arena))==0);
    CHECK(h.check());
    // Deterministic fragmentation: validate every surviving payload after every operation.
    CHECK(h.init(arena,sizeof(arena)));handles.assign(48,nullptr);uint32_t rng=1;
    unsigned sizes[48]={};
    for(unsigned step=0;step<2500;++step) {
        rng=rng*1664525U+1013904223U;unsigned slot=(rng>>16)%48;
        if(handles[slot]) { CHECK(h.disposeHandle(handles[slot])==0);handles[slot]=nullptr; }
        else { unsigned n=(rng%700)+1;auto x=h.newHandle(n);if(x){handles[slot]=x;sizes[slot]=n;pattern(*x,n,slot+1);} }
        if(step%7==0)h.compact();
        if(step%11==0 && handles[slot])CHECK(h.moveHigh(handles[slot])==0);
        CHECK(h.check());
        for(unsigned i=0;i<48;++i)if(handles[i])CHECK(patternIs(*handles[i],sizes[i],i+1));
    }
    // Force many master blocks interleaved with data and holes.
    CHECK(h.init(arena,sizeof(arena),1));handles.clear();
    for(unsigned i=0;i<120;++i){auto x=h.newHandle(200);CHECK(x);pattern(*x,200,i+1);handles.push_back(x);}
    for(unsigned i=0;i<120;i+=3){CHECK(h.disposeHandle(handles[i])==0);handles[i]=nullptr;}
    h.compact();CHECK(h.check());
    for(unsigned i=0;i<120;++i)if(handles[i]){CHECK(h.moveHigh(handles[i])==0);CHECK(h.setHandleSize(handles[i],300)==0);CHECK(patternIs(*handles[i],200,i+1));}
    h.compact();CHECK(h.check());
    for(unsigned i=0;i<120;++i)if(handles[i])CHECK(patternIs(*handles[i],200,i+1));
    std::puts("PASS mac-heap: allocation master-blocks lock purge compact resize move-high fragmentation=2500");
}
