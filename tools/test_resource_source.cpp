#include <cassert>
#include <cstdio>
#include <vector>
#include <algorithm>
#include "../src/mac/ResourceForks.h"
static void w(std::vector<uint8_t>& b,uint32_t o,uint32_t v) { b[o]=v>>8;b[o+1]=v; }
static void l(std::vector<uint8_t>& b,uint32_t o,uint32_t v) { w(b,o,v>>16);w(b,o+2,v); }
struct Disk {
    std::vector<uint8_t> bytes;
    uint32_t calls=0,total=0,max=0,fail=0;bool payload=false,shortRead=false;
    Disk():bytes(100574) {
        l(bytes,0,256);l(bytes,4,100512);l(bytes,8,100011);l(bytes,12,62);
        std::copy_n(bytes.begin(),16,bytes.begin()+100512);
        const uint32_t m=100512;w(bytes,m+24,28);w(bytes,m+26,62);w(bytes,m+28,0);
        l(bytes,m+30,0x54455354);w(bytes,m+34,1);w(bytes,m+36,10);
        w(bytes,m+38,128);w(bytes,m+40,65535);
        w(bytes,m+50,65533);w(bytes,m+52,65535);l(bytes,m+54,100007);
        l(bytes,256,100003);for(uint32_t i=0;i<100003;++i)bytes[260+i]=(i*37+(i>>8))&255;
        l(bytes,100263,0);
    }
    static int32_t read(void* opaque,uint32_t at,uint8_t* out,uint32_t size,uint32_t& actual) {
        Disk& d=*(Disk*)opaque;++d.calls;d.total+=size;d.max=std::max(size,d.max);
        assert(size<=65536 && at<=d.bytes.size() && size<=d.bytes.size()-at);
        assert(d.payload || (at==0 && size==16) || (at==100512 && size==62) || ((at==256 || at==100263) && size==4));
        if(d.fail==d.calls) { actual=0;return -36; }
        actual=d.shortRead ? size-1 : size;std::copy_n(d.bytes.begin()+at,actual,out);return 0;
    }
    ResourceForks::Source source() { return {this,(uint32_t)bytes.size(),read}; }
};
int main() {
    Disk disk;ResourceForks forks;auto source=disk.source();
    assert(forks.open(source) && forks.resourceCount()==2 && forks.forkCount()==1);
    assert(disk.calls==4 && disk.total==86 && disk.max==62); // No body read on open.
    ResourceForks::Item item;uint32_t index;
    assert(forks.item(0,item) && item.id==128 && item.fork==0);
    assert(forks.item(1,item) && item.id==-3 && item.fork==0);
    assert(!forks.item(2,item));
    assert(forks.find(0,0x54455354,128,item,&index) && item.size==100003 && !item.data);
    std::vector<uint8_t> out(100005,0xcc);disk.payload=true;auto calls=disk.calls;
    assert(forks.read(index,out.data()+1,100002)==-50 && disk.calls==calls);
    assert(!forks.read(index,out.data()+1,100003) && disk.calls==calls+2 && disk.max==65536);
    assert(out.front()==0xcc && out.back()==0xcc);
    for(uint32_t i=0;i<100003;++i)assert(out[i+1]==disk.bytes[i+260]);
    disk.fail=disk.calls+2;assert(forks.read(index,out.data()+1,100003)==-36);
    disk.fail=0;disk.shortRead=true;assert(forks.read(index,out.data()+1,100003)==-39);disk.shortRead=false;
    assert(forks.find(0,0x54455354,-3,item,&index) && item.size==0);calls=disk.calls;
    assert(!forks.read(index,nullptr,0) && disk.calls==calls);
    assert(forks.open(source,&source) && forks.resourceCount()==4 && forks.forkCount()==2);
    for(uint32_t i=0;i<4;++i) {
        assert(forks.item(i,item) && item.fork==i/2 && item.id==(i%2 ? -3 : 128));
        uint32_t foundIndex;
        assert(forks.find(item.fork,item.type,item.id,item,&foundIndex) && foundIndex==i);
    }
    assert(forks.find(1,0x54455354,128,item,&index) && !forks.read(index,out.data(),out.size()));
    disk.fail=disk.calls+2;assert(!forks.open(source) && !forks.resourceCount() && !forks.forkCount());
    assert(forks.read(0,out.data(),out.size())==-50);disk.fail=0;
    assert(forks.open(disk.bytes.data(),disk.bytes.size(),nullptr,0));
    assert(forks.find(0,0x54455354,128,item,&index) && item.data==disk.bytes.data()+260);
    assert(!forks.read(index,out.data(),out.size()));
    forks.close();assert(!forks.item(0,item));
    puts("PASS resource-source: metadata-only open, 64KiB reads, exact bytes, errors/short reads, two forks, zero resource, cleanup");
}
