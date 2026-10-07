#include "platform/amiga/M5Audit.h"
#ifdef AITD_FILE_WRITE_PROBE
#include <proto/exec.h>
#include <proto/dos.h>
#include <dos/dos.h>
#include "SystemWindow.h"
#include <exec/memory.h>
#include "FileAccess.h"
#include "mac/FileWriteBuffer.h"
extern "C" { volatile uint32_t g_fileWriteProbeStep=0; }
static uint8_t payload[131089],readback[200003];
static uint8_t pattern(uint32_t i) { return (i*37+(i>>8))&255; }
static uint8_t* allocate(uint32_t size) { return (uint8_t*)M5_ALLOC_MEM(size,MEMF_FAST); }
static void release(uint8_t* p,uint32_t size) { M5_FREE_MEM(p,size); }
static int32_t protectFixture(void*) {
    return SetProtection((CONST_STRPTR)"PROGDIR:locked-probe.bin",FIBF_WRITE) ? 0 : -36;
}
int32_t aitdFileWriteBackendProbe() {
    FileAccess::ReadStream stream={0};FileWriteBuffer buffer;uint32_t actual=0;
    g_fileWriteProbeStep=1;
    if(aitdSystemWindow(protectFixture,0))return -1;
    if(FileAccess::openStream("PROGDIR:write-probe.bin",stream))return -1;
    int32_t result=-1;
    do {
        if(buffer.bind(sizeof(readback),FileAccess::readStream,&stream,allocate,release))break;
        for(uint32_t i=0;i<sizeof(payload);++i)payload[i]=pattern(i)^0x5a;
        g_fileWriteProbeStep=2;
        if(buffer.write(65530,payload,sizeof(payload),actual) || actual!=sizeof(payload) || !buffer.dirty())break;
        g_fileWriteProbeStep=3;
        if(FileAccess::flushStream(stream,buffer) || buffer.dirty())break;
        g_fileWriteProbeStep=4;
        if(FileAccess::readStream(&stream,0,readback,sizeof(readback),actual) || actual!=sizeof(readback))break;
        bool exact=true;
        for(uint32_t i=0;i<sizeof(readback);++i) {
            uint8_t expected=i>=65530 && i<65530+sizeof(payload) ? (pattern(i-65530)^0x5a) : pattern(i);
            if(readback[i]!=expected) { exact=false;break; }
        }
        if(!exact)break;
        g_fileWriteProbeStep=5;
        if(buffer.resize(17) || buffer.resize(sizeof(readback)) || FileAccess::flushStream(stream,buffer) || buffer.dirty())break;
        g_fileWriteProbeStep=6;
        if(FileAccess::readStream(&stream,0,readback,sizeof(readback),actual) || actual!=sizeof(readback))break;
        for(uint32_t i=0;i<sizeof(readback);++i)if(readback[i]!=(i<17 ? pattern(i) : 0)) { exact=false;break; }
        if(!exact)break;
        g_fileWriteProbeStep=7;
        if(buffer.resize(17) || FileAccess::flushStream(stream,buffer) || buffer.dirty())break;
        g_fileWriteProbeStep=8;
        if(FileAccess::readStream(&stream,0,readback,sizeof(readback),actual) || actual!=17)break;
        for(uint32_t i=0;i<17;++i)if(readback[i]!=pattern(i)) { exact=false;break; }
        if(!exact)break;
        result=0;
    } while(false);
    buffer.clear();
    if(FileAccess::closeStream(stream))result=-1;
    if(!result)g_fileWriteProbeStep=9;
    return result;
}

extern "C" {
extern volatile uint16_t g_fileProbeCCR;
int32_t aitdProbeHOpen(void*),aitdProbeWrite(void*),aitdProbeRead(void*),aitdProbeSetEOF(void*);
int32_t aitdProbeEOF(void*),aitdProbeFCB(void*),aitdProbeFlush(void*),aitdProbeClose(void*);
}
static uint8_t pb[80] __attribute__((aligned(4)));
static uint8_t name[]="\022mutation-probe.bin";
static void w(uint16_t off,uint16_t value) { pb[off]=value>>8;pb[off+1]=value; }
static void l(uint16_t off,uint32_t value) { w(off,value>>16);w(off+2,value); }
static uint32_t get(uint16_t off) { return (uint32_t)pb[off]<<24|(uint32_t)pb[off+1]<<16|(uint32_t)pb[off+2]<<8|pb[off+3]; }
static bool result(int32_t value,int32_t expected=0) {
    return value==expected && (int16_t)(get(16)>>16)==expected
        && (g_fileProbeCCR&15)==(expected<0 ? 8 : expected==0 ? 4 : 0);
}
static bool open(uint8_t permission) {
    l(18,(uint32_t)name);w(22,0xffff);l(48,7);pb[27]=permission;
    return result(aitdProbeHOpen(pb));
}
static bool transfer(bool writing,uint8_t* bytes,uint32_t count,uint16_t mode,uint32_t position) {
    l(32,(uint32_t)bytes);l(36,count);w(44,mode);l(46,position);
    return result(writing ? aitdProbeWrite(pb) : aitdProbeRead(pb)) && get(40)==count;
}
static bool fcb(uint32_t size,uint32_t mark) {
    l(18,0);w(28,0);
    return result(aitdProbeFCB(pb)) && get(40)==size && get(48)==mark;
}
extern "C" bool aitdFileMutationProbe() {
    g_fileWriteProbeStep=10;if(!open(3))return false;
    g_fileWriteProbeStep=11;l(28,0);if(!result(aitdProbeSetEOF(pb)))return false;
    payload[0]=0x12;payload[1]=0x34;payload[2]=0x56;payload[3]=0x78;
    g_fileWriteProbeStep=12;
    if(!transfer(true,payload,4,1,8) || get(46)!=12 || !result(aitdProbeEOF(pb)) || get(28)!=12)return false;
    g_fileWriteProbeStep=13;l(28,2);
    if(!result(aitdProbeSetEOF(pb)) || !fcb(2,2))return false;
    g_fileWriteProbeStep=14;
    if(!transfer(true,payload,0,1,32) || get(46)!=32 || !fcb(32,32))return false;
    g_fileWriteProbeStep=15;l(28,20);
    if(!result(aitdProbeSetEOF(pb)) || !fcb(20,20) || !transfer(false,readback,20,1,0))return false;
    for(uint32_t i=0;i<20;++i)if(readback[i])return false; // Unwritten bytes are deterministic zeros.
    g_fileWriteProbeStep=16;
    if(!transfer(true,payload,4,3,0xffffffffUL) || get(46)!=23)return false;
    g_fileWriteProbeStep=17;l(18,0);w(22,0xffff);
    if(!result(aitdProbeFlush(pb)) || !result(aitdProbeClose(pb)))return false;
    g_fileWriteProbeStep=18;
    if(!open(1) || !transfer(false,readback,23,1,0))return false;
    for(uint32_t i=0;i<23;++i)if(readback[i]!=(i<19 ? 0 : payload[i-19]))return false;
    g_fileWriteProbeStep=19;
    l(40,0xdeadbeef);l(28,0);
    if(!result(aitdProbeWrite(pb),-61) || get(40)!=0xdeadbeef || !result(aitdProbeSetEOF(pb),-61)
       || !fcb(23,23) || !result(aitdProbeClose(pb)))return false;
    g_fileWriteProbeStep=20;if(!open(3))return false;
    for(uint32_t i=0;i<70000;++i)payload[i]=pattern(i)^0xa5;
    if(!transfer(true,payload,70000,1,0) || !result(aitdProbeClose(pb)))return false;
    g_fileWriteProbeStep=21;
    if(!open(1) || !transfer(false,readback,70000,1,0))return false;
    for(uint32_t i=0;i<70000;++i)if(readback[i]!=payload[i])return false;
    if(!result(aitdProbeClose(pb)))return false;
    // Leave dirty data for the restored-OS shutdown path, then verify on host.
    g_fileWriteProbeStep=22;if(!open(3))return false;
    l(28,0);if(!result(aitdProbeSetEOF(pb)) || !transfer(true,payload,3,1,0))return false;
    g_fileWriteProbeStep=23;return true;
}
#endif
