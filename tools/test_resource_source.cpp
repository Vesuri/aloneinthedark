#include <cassert>
#include <cstdio>
#include <vector>
#include <algorithm>
#include <fstream>
#include <iterator>
#include "../src/mac/ResourceForks.h"
#include "../src/mac/ResourceDirectory.h"
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
struct FontOverlay {
    std::vector<uint8_t> bytes;uint32_t calls=0,total=0;bool payload=false;
    std::vector<uint32_t> prefixes;
    static uint32_t read32(const uint8_t* p) { return uint32_t(p[0])<<24|uint32_t(p[1])<<16|uint32_t(p[2])<<8|p[3]; }
    void indexPrefixes() {
        uint32_t at=read32(bytes.data()),end=at+read32(bytes.data()+8);
        while(at<end) { prefixes.push_back(at);assert(at+4<=end);at+=4+read32(bytes.data()+at); }
        assert(at==end && prefixes.size()==31);
    }
    static int32_t read(void* p,uint32_t at,uint8_t* out,uint32_t size,uint32_t& actual) {
        auto& disk=*(FontOverlay*)p;++disk.calls;disk.total+=size;
        assert(disk.payload || (at==0 && size==16) || (at==read32(disk.bytes.data()+4) && size==read32(disk.bytes.data()+12)) || (size==4 && std::find(disk.prefixes.begin(),disk.prefixes.end(),at)!=disk.prefixes.end()));
        assert(at+size<=disk.bytes.size());std::copy_n(disk.bytes.data()+at,size,out);actual=size;return 0;
    }
    ResourceForks::Source source() { return {this,(uint32_t)bytes.size(),read}; }
};
int main(int argc,char** argv) {
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
    // Dynamic maps may reuse directory slots; cached handles follow identity,
    // never a reused slot or a duplicate type/ID in a different fork.
    assert(forks.open(source));
    const uint32_t appIdentity=forks.identity(0);int16_t remap[ResourceForks::kMaximumResources];
    auto* directory=forks.directory();
    assert(!directory->open(7,source,true) && forks.refresh(remap));
    assert(forks.resourceCount()==4 && forks.forkCount()==2 && remap[0]==0 && remap[1]==1);
    assert(forks.find(7,0x54455354,128,item,&index) && index==2);
    const uint32_t otherIdentity=forks.identity(index);assert(otherIdentity!=appIdentity);
    auto body=ResourceWriter::Entry{0x54455354,9,0,0,0,source,260,3};uint32_t added;
    assert(!directory->add(7,body,added) && forks.refresh(remap));
    assert(forks.find(7,body.type,9,item,&index) && index==4 && forks.identity(index)==added);
    body.size=2;body.id=10;
    assert(!directory->replace(added,body) && forks.refresh(remap));
    assert(remap[4]==4 && forks.identity(4)==added);
    assert(forks.find(7,body.type,10,item,&index) && item.size==2 && !forks.find(7,body.type,9,item));
    assert(!forks.read(4,out.data(),out.size()) && out[0]==disk.bytes[260] && out[1]==disk.bytes[261]);
    assert(!directory->remove(otherIdentity) && forks.refresh(remap));
    assert(remap[0]==0 && remap[1]==1 && remap[2]==-1 && remap[3]==2 && remap[4]==3);
    assert(forks.identity(0)==appIdentity && !forks.find(7,body.type,128,item));
    assert(!directory->close(7) && forks.refresh(remap) && forks.resourceCount()==2 && remap[2]==-1 && remap[3]==-1);
    assert(!directory->open(7,source,true) && forks.refresh(remap));
    assert(forks.find(7,body.type,128,item,&index) && forks.identity(index)!=otherIdentity);
    // Opening older numeric keys must still enumerate in actual open order.
    assert(!directory->open(3,source,false) && forks.refresh(remap));
    assert(forks.item(4,item) && item.fork==3 && remap[2]==2);
    for(uint16_t f=0;f<ResourceForks::kForkCount;++f)if(!directory->active(f))assert(!directory->create(f));
    assert(forks.refresh(remap) && forks.forkCount()==16);
    assert(directory->create(16)==-108);
    directory->clear();assert(forks.refresh(remap) && !forks.resourceCount() && !forks.forkCount());
    for(auto slot:remap)assert(slot==-1);
    assert(!directory->open(0,source,false) && forks.refresh(remap));
    assert(forks.identity(0)!=appIdentity && !forks.item(2,item) && !forks.identity(2));
    // Duplicate keys in one native view follow insertion identities after reuse.
    directory->clear();assert(!directory->create(7) && forks.refresh(remap));
    body.id=128;body.offset=260;body.size=1;uint32_t first,second,third;
    auto before=disk.calls;
    assert(!directory->add(7,body,first));body.offset=261;assert(!directory->add(7,body,second));
    assert(forks.refresh(remap) && forks.find(7,body.type,128,item,&index) && index==0 && forks.identity(index)==first);
    assert(!directory->remove(first));body.offset=262;assert(!directory->add(7,body,third));
    assert(forks.refresh(remap) && remap[0]==-1 && remap[1]==0);
    assert(forks.find(7,body.type,128,item,&index) && index==0 && forks.identity(index)==second && !item.data);
    assert(forks.item(1,item) && forks.identity(1)==third && !item.data && disk.calls==before);
    assert(!forks.read(0,out.data(),out.size()) && out[0]==disk.bytes[261]);
    assert(!forks.read(1,out.data(),out.size()) && out[0]==disk.bytes[262]);
    assert(!directory->remove(second) && forks.refresh(remap) && remap[0]==-1 && remap[1]==0);
    assert(forks.find(7,body.type,128,item,&index) && forks.identity(index)==third);
    forks.close();assert(!forks.item(0,item));
    // System overlay is oldest, independent of its numeric key. No body is
    // fetched during map construction, search-order traversal or handle remap.
    Disk app,overlay;assert(forks.openWithOverlay(app.source(),overlay.source()));
    directory=forks.directory();int16_t key;
    assert(forks.forkCount()==2 && forks.resourceCount()==4);
    assert(app.calls==4 && overlay.calls==4 && app.total==86 && overlay.total==86);
    assert(directory->newest(key) && key==0 && directory->older(0,key) && key==ResourceForks::kOverlayFork);
    assert(!directory->older(key,key));
    assert(!directory->open(1,source,true) && forks.refresh(remap));
    assert(directory->newest(key) && key==1 && directory->older(1,key) && key==0);
    assert(directory->older(0,key) && key==ResourceForks::kOverlayFork);
    uint16_t keys[ResourceForks::kForkCount];
    auto reads=app.calls+overlay.calls+disk.calls;
    assert(forks.searchOrder(1,body.type,false,keys)==3 && keys[0]==1 && keys[1]==0 && keys[2]==ResourceForks::kOverlayFork);
    assert(forks.searchOrder(0,body.type,false,keys)==2 && keys[0]==0 && keys[1]==ResourceForks::kOverlayFork);
    for(auto type:{0x444c4f47UL,0x4449544cUL,0x414c5254UL}) {
        assert(forks.searchOrder(1,type,false,keys)==3 && keys[0]==ResourceForks::kOverlayFork && keys[1]==1 && keys[2]==0);
        assert(forks.searchOrder(1,type,true,keys)==1 && keys[0]==1);
        assert(forks.searchOrder(0,type,true,keys)==1 && keys[0]==0);
        assert(forks.searchOrder(ResourceForks::kOverlayFork,type,false,keys)==1 && keys[0]==ResourceForks::kOverlayFork);
    }
    assert(!forks.searchOrder(14,body.type,false,keys));
    assert(app.calls+overlay.calls+disk.calls==reads);
    assert(forks.find(ResourceForks::kOverlayFork,body.type,128,item,&index) && !item.data);
    overlay.payload=true;assert(!forks.read(index,out.data(),out.size()));
    assert(overlay.calls==6 && app.calls==4);
    assert(std::equal(out.begin(),out.begin()+100003,overlay.bytes.begin()+260));
    assert(directory->add(ResourceForks::kOverlayFork,body,added)==-54);
    assert(!directory->close(1) && forks.refresh(remap));
    assert(directory->newest(key) && key==0);
    // Either source failing leaves neither partial map nor stale dense items.
    overlay.fail=overlay.calls+1;auto appCalls=app.calls;
    assert(!forks.openWithOverlay(app.source(),overlay.source()) && !forks.forkCount() && !forks.resourceCount());
    assert(app.calls==appCalls);overlay.fail=0;app.fail=app.calls+1;
    assert(!forks.openWithOverlay(app.source(),overlay.source()) && !forks.directory());
    app.fail=0;
    // Read the committed generated font/driver fork through the same bounded API.
    assert(argc==2);std::ifstream file(argv[1],std::ios::binary);assert(file.good());
    FontOverlay empty;empty.bytes.assign(std::istreambuf_iterator<char>(file),{});empty.indexPrefixes();
    appCalls=app.calls;
    assert(forks.openWithOverlay(app.source(),empty.source()));
    assert(empty.bytes.size()==82026 && empty.calls==33 && empty.total==572);
    assert(forks.forkCount()==2 && forks.resourceCount()==33 && app.calls==appCalls+4);
    assert(forks.item(0,item) && item.fork==ResourceForks::kOverlayFork && !item.data);
    assert(forks.item(31,item) && item.fork==0 && !item.data);
    assert(forks.directory()->older(0,key) && key==ResourceForks::kOverlayFork);
    assert(!forks.find(ResourceForks::kOverlayFork,body.type,128,item));
    assert(forks.find(ResourceForks::kOverlayFork,0x464f4e44,20,item,&index) && item.size==60 && item.nameLength==5);
    empty.payload=true;assert(!forks.read(index,out.data(),out.size()));
    assert(std::equal(out.begin(),out.begin()+60,empty.bytes.begin()+260));
    assert(forks.find(ResourceForks::kOverlayFork,0x4e464e54,128,item,&index) && item.size==1818);
    assert(!forks.read(index,out.data(),out.size()));
    assert(std::equal(out.begin(),out.begin()+1818,empty.bytes.begin()+648));
    assert(empty.calls==35 && empty.total==2450);
    assert(forks.find(ResourceForks::kOverlayFork,0x4a6e7468,11,item,&index) && item.size==4);
    assert(!forks.read(index,out.data(),out.size()));
    assert(out[0]==0xa0 && out[1]==0xf8 && out[2]==0x4e && out[3]==0x75);
    assert(empty.calls==36 && empty.total==2454);
    forks.close();assert(!forks.directory() && !forks.forkCount());
    puts("PASS overlay-source: application/overlay/dynamic order, read-only map, lazy exact bodies, failed-open rollback, generated font/driver fork");
    puts("PASS resource-source: metadata-only open, 64KiB reads, exact bytes, errors/short reads, dynamic 16-fork identity/remap, zero resource, cleanup");
}
