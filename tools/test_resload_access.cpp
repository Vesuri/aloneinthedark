#include <cstdint>
#include <cassert>
#include <cstring>
#include <cstdio>
#include "../src/platform/amiga/FileAccess.h"
static uint32_t size=100,error=0,success=1,calls=0,lastBytes=0,lastOffset=0,lastFunction=0;
extern "C" uint32_t aitdResloadCall(void* base,uint32_t function,uint32_t bytes,uint32_t offset,
    const void* name,void* buffer,uint32_t* resultError)
{
    assert(base==(void*)1);++calls;lastFunction=function;*resultError=error;
    if(function==0x24)return size;
    if(function==0x34) {
        auto* tags=(uint32_t*)name;
        assert(tags[0]==0x8800000e && tags[2]==0);tags[1]=error;return success;
    }
    assert(std::strcmp((const char*)name,"probe")==0);
    lastBytes=bytes;lastOffset=offset;
    if(function==0x4c) { if(success)std::memset(buffer,0x5a,bytes); }
    else assert(function==0x0c);
    return success;
}
int main()
{
    using namespace FileAccess;
    uint8_t buffer[128]={};uint32_t actual=99;
    assert(whdload.readAt("probe",0,buffer,20,actual)==unavailable && actual==0);
    assert(whdload.save("probe",buffer,20)==unavailable);
    bindResload((void*)1);
    assert(whdload.readAt("probe",0,buffer,20,actual)==ok && actual==20 && buffer[19]==0x5a);
    assert(lastBytes==20 && lastOffset==0);
    assert(whdload.readAt("probe",90,buffer,20,actual)==ok && actual==10);
    assert(lastBytes==10 && lastOffset==90);
    assert(whdload.readAt("probe",100,buffer,20,actual)==ok && actual==0);
    assert(whdload.readAt("probe",200,buffer,20,actual)==ok && actual==0);
    size=0;
    assert(whdload.readAt("probe",0,buffer,20,actual)==ok && actual==0);
    error=205;
    assert(whdload.readAt("probe",0,buffer,20,actual)==notFound && actual==0);
    error=212;
    assert(whdload.readAt("probe",0,buffer,20,actual)==ioError && actual==0);
    size=100;success=0;
    assert(whdload.readAt("probe",0,buffer,20,actual)==ioError && actual==0);
    assert(whdload.save("probe",buffer,20)==ioError);
    success=1;
    assert(whdload.save("probe",buffer,20)==ok && lastFunction==0xc && lastBytes==20);
    unsigned before=calls;
    assert(whdload.readAt("probe",0,buffer,65537,actual)==invalid && actual==0);
    assert(whdload.readAt("probe",0x7fffffff,buffer,2,actual)==invalid);
    assert(whdload.readAt(nullptr,0,buffer,2,actual)==invalid);
    assert(whdload.save("probe",buffer,65537)==invalid);
    assert(calls==before);
    bindResload(nullptr);
    puts("PASS resload-adapter: ranges, EOF, empty, missing, errors, save, unbound");
}
