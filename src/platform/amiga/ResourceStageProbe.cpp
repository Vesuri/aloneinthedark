#ifdef AITD_FILE_WRITE_PROBE
#include <proto/dos.h>
#include <dos/dos.h>
#include "ResourceStage.h"
#include "SystemWindow.h"
#include "mac/ResourceMap.h"
extern "C" {
extern volatile uint32_t g_systemWindows,g_resourceStageFault;
volatile int32_t g_resourceStageError=0;
volatile uint32_t g_resourceStageStep=0,g_resourceStageWindows=0,g_resourceStageHash=0;
}
static const uint32_t payloadBytes=70003,fileBytes=70314;
static uint8_t output[fileBytes];
struct Generator { uint8_t mask;bool fail; };
static uint8_t pattern(uint32_t i) { return (i*37+(i>>8))&255; }
static int32_t generate(void* context,uint32_t offset,uint8_t* bytes,uint32_t size,uint32_t& actual) {
    actual=0;auto& g=*(Generator*)context;if(g.fail)return -36;
    if(size>65536 || offset>payloadBytes || size>payloadBytes-offset)return -50;
    for(uint32_t i=0;i<size;++i)bytes[i]=pattern(offset+i)^g.mask;actual=size;return 0;
}
struct Verify { const char* path;bool serialized; };
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static int32_t verifyInside(void* context) {
    auto& r=*(Verify*)context;BPTR f=Open((CONST_STRPTR)r.path,MODE_OLDFILE);if(!f)return -36;
    uint32_t expected=r.serialized ? fileBytes : 4;int32_t error=0;
    for(uint32_t at=0;at<expected && !error;) {
        uint32_t n=expected-at>65536 ? 65536 : expected-at;
        if(Read(f,output+at,n)!=(LONG)n)error=-36;at+=n;
    }
    uint8_t extra;if(!error && Read(f,&extra,1)!=0)error=-36;if(!Close(f))error=-36;if(error)return error;
    if(!r.serialized)return lng(output)==0x4b454550 ? 0 : -36;
    ResourceMap map;ResourceMap::Entry entry;uint32_t offset;
    if(!map.open(output,fileBytes,output+lng(output+4),lng(output+12)) || map.count()!=1 || !map.entry(0,entry)
        || entry.type!=0x52535243 || entry.id!=128 || !map.payload(0,payloadBytes,offset) || lng(output+entry.lengthOffset)!=payloadBytes)return -36;
    uint32_t hash=2166136261UL;
    for(uint32_t i=0;i<payloadBytes;++i) { if(output[offset+i]!=pattern(i))return -36;hash=(hash^output[offset+i])*16777619UL; }
    g_resourceStageHash=hash;return 0;
}
static bool verify(const char* path,bool serialized=true) { Verify r={path,serialized};return aitdSystemWindow(verifyInside,&r)==0; }
bool aitdResourceStageProbe() {
    uint32_t start=g_systemWindows;ResourceStage stage;Generator generator={0,false};
    ResourceWriter::Entry entry={0x52535243,128,0,0,0,{&generator,payloadBytes,generate},0,payloadBytes};
    const char* path="PROGDIR:stage-probe.rsrc";
    g_resourceStageStep=1;if(!stage.bind(path)) { g_resourceStageError=-1;return false; }
    g_resourceStageError=ResourceWriter::serialize(&entry,1,stage.sink());
    if(g_resourceStageError || stage.active() || !verify(path))return false;
    auto sink=stage.sink();uint32_t actual;const uint8_t alternate[]={1,2,3,4};
    g_resourceStageStep=2;
    if(sink.begin(sink.context,4) || sink.write(sink.context,0,alternate,4,actual) || actual!=4 || sink.finish(sink.context,false) || stage.active() || !verify(path))return false;
    g_resourceStageStep=3;
    if(sink.begin(sink.context,4) || sink.write(sink.context,0,alternate,2,actual) || actual!=2 || sink.finish(sink.context,true)!=-36
        || sink.finish(sink.context,false) || stage.active() || !verify(path))return false;
    generator.mask=0x5a;
    for(uint16_t fault=1;fault<=2;++fault) {
        g_resourceStageStep=3+fault;g_resourceStageFault=fault;
        int32_t error=ResourceWriter::serialize(&entry,1,stage.sink());g_resourceStageFault=0;
        if(error!=-36 || stage.active() || !verify(path))return false;
    }
    g_resourceStageStep=6;ResourceStage stale;
    if(!stale.bind("PROGDIR:stage-stale.rsrc") || stale.sink().begin(&stale,4)!=ResourceStage::recoveryRequired
        || stale.active() || !verify("PROGDIR:stage-stale.rsrc.aitd-new",false))return false;
    g_resourceStageStep=7;
    if(!stale.bind("PROGDIR:stage-backup.rsrc") || stale.sink().begin(&stale,4)!=ResourceStage::recoveryRequired
        || stale.active() || !verify("PROGDIR:stage-backup.rsrc.aitd-old",false))return false;
    g_resourceStageStep=8;generator.mask=0;
    if(!stage.bind("PROGDIR:stage-created.rsrc") || ResourceWriter::serialize(&entry,1,stage.sink()) || stage.active() || !verify("PROGDIR:stage-created.rsrc"))return false;
    g_resourceStageStep=9;generator.fail=true;
    if(ResourceWriter::serialize(&entry,1,stage.sink())!=-36 || stage.active() || !verify("PROGDIR:stage-created.rsrc"))return false;
    g_resourceStageWindows=g_systemWindows-start;
    if(g_resourceStageWindows!=56)return false;
    g_resourceStageStep=10;return true;
}
#endif
