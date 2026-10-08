#include <cstdint>
#include <cassert>
#include <cstring>
#include <cstdio>
#include "../src/platform/amiga/FileAccess.h"
static uint32_t protection=0;
static int32_t entryType=-3;
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
    else if(function==0x78) {
        auto* info=(uint8_t*)buffer;
        std::memset(info,0,260);
        auto put=[info](unsigned at,uint32_t value) { for(unsigned i=0;i<4;i++)info[at+i]=value>>(24-i*8); };
        put(4,entryType);put(116,protection);put(124,size);
    }
    else assert(function==0x0c || function==0x58);
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
    error=0;
    assert(whdload.readAt("PROGDIR:probe",0,buffer,20,actual)==ok && actual==20);
    uint32_t measured=0;bool found=false,locked=false,deleteLocked=false;
    assert(resloadStat("PROGDIR:probe",measured,found,locked,&deleteLocked)==ok && found && measured==100 && !locked && !deleteLocked);
    protection=5;
    assert(resloadStat("probe",measured,found,locked,&deleteLocked)==ok && locked && deleteLocked);
    protection=0;entryType=2;
    assert(resloadStat("probe",measured,found,locked)==invalid);
    entryType=-3;success=0;error=205;
    assert(resloadStat("probe",measured,found,locked)==ok && !found);
    error=214;
    assert(resloadReplace("probe",buffer,20)==-44);
    error=222;assert(resloadDelete("probe")==-45);
    success=1;error=0;
    assert(resloadReplace("probe",nullptr,0)==ok && lastBytes==0);
    assert(resloadDelete("PROGDIR:probe")==ok && lastFunction==0x58);
    unsigned before=calls;
    assert(whdload.readAt("probe",0,buffer,65537,actual)==invalid && actual==0);
    assert(whdload.readAt("probe",0x7fffffff,buffer,2,actual)==invalid);
    assert(whdload.readAt(nullptr,0,buffer,2,actual)==invalid);
    assert(whdload.save("probe",buffer,65537)==invalid);
    assert(calls==before);
    bindResload(nullptr);
    puts("PASS resload-adapter: ranges, EOF, empty, missing, errors, save/delete/stat, protection, path normalization, unbound");
}
