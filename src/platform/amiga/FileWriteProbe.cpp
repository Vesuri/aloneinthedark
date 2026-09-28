#ifdef AITD_FILE_WRITE_PROBE
#include <proto/exec.h>
#include <exec/memory.h>
#include "FileAccess.h"
#include "mac/FileWriteBuffer.h"
extern "C" { volatile uint32_t g_fileWriteProbeStep=0; }
static uint8_t payload[131089],readback[200003];
static uint8_t pattern(uint32_t i) { return (i*37+(i>>8))&255; }
static uint8_t* allocate(uint32_t size) { return (uint8_t*)AllocMem(size,MEMF_FAST); }
static void release(uint8_t* p,uint32_t size) { FreeMem(p,size); }
int32_t aitdFileWriteBackendProbe() {
    FileAccess::ReadStream stream={0};FileWriteBuffer buffer;uint32_t actual=0;
    g_fileWriteProbeStep=1;
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
#endif
