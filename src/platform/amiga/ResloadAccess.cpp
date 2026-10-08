#include "FileAccess.h"
// Offsets and tag value from WHDLoad Include/whdload.i (v18 API).
// This adapter deliberately makes no Exec/DOS calls.
extern "C" uint32_t aitdResloadCall(void*,uint32_t,uint32_t,uint32_t,const void*,void*,uint32_t*);
extern "C" {
struct ResloadConfig { uint32_t magic[2];uint16_t version,reserved;void* table; };
volatile ResloadConfig g_resloadConfig __attribute__((aligned(4)))={{0x41495444,0x57484452},1,0,0};
}
namespace FileAccess {
static void* resload=0;
void bindResload(void* entryTable) { resload=entryTable; }
bool resloadActive() { return resload!=0; }
void initializeResload() { bindResload(g_resloadConfig.table); }
static const char* relative(const char* path) {
    if(!path)return 0;
    const char* prefix="PROGDIR:";unsigned i=0;
    while(prefix[i] && path[i]==prefix[i])++i;
    return prefix[i] ? path : path+i;
}
static int32_t errorCode(uint32_t error) {
    switch(error) {
    case 205:return notFound;
    case 203:return -48;
    case 202:case 216:return -47;
    case 222:case 223:return -45;
    case 214:return -44;
    case 221:return -34;
    case 103:return -108;
    default:return ioError;
    }
}
int32_t resloadStat(const char* path,uint32_t& size,bool& found,bool& locked,bool* deleteLocked) {
    // AmigaDOS FileInfoBlock wire layout, independent of host LONG width.
    static uint8_t info[260] __attribute__((aligned(4)));
    auto field=[](unsigned n)->uint32_t { return (uint32_t(info[n])<<24)|(uint32_t(info[n+1])<<16)|(uint32_t(info[n+2])<<8)|info[n+3]; };
    size=0;found=locked=false;if(deleteLocked)*deleteLocked=false;
    if(!path)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;
    if(!aitdResloadCall(resload,0x78,0,0,relative(path),info,&error))return error==205 ? ok : errorCode(error);
    if(int32_t(field(4))>=0 || int32_t(field(124))<0)return invalid;
    size=field(124);found=true;locked=(field(116)&4)!=0;
    if(deleteLocked)*deleteLocked=(field(116)&1)!=0;
    return ok;
}
int32_t resloadReplace(const char* path,const uint8_t* buffer,uint32_t bytes) {
    if(!path || (!buffer && bytes) || bytes>0x7fffffffUL)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;static const uint8_t empty=0;
    return aitdResloadCall(resload,0x0c,bytes,0,relative(path),(void*)(buffer?buffer:&empty),&error) ? ok : errorCode(error);
}
int32_t resloadDelete(const char* path) {
    if(!path)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;
    return aitdResloadCall(resload,0x58,0,0,relative(path),0,&error) ? ok : errorCode(error);
}
static int32_t readAt(const char* path,uint32_t offset,uint8_t* buffer,uint32_t bytes,uint32_t& actual)
{
    actual=0;
    if(!path || !buffer || bytes>chunkBytes || offset>0x7fffffffUL-bytes)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;
    uint32_t size=aitdResloadCall(resload,0x24,0,0,relative(path),0,&error);
    if(!size) {
        uint32_t tags[]={0x8800000eUL,0,0}; // WHDLTAG_IOERR_GET, result, TAG_DONE
        if(!aitdResloadCall(resload,0x34,0,0,tags,0,&error))return ioError;
        if(tags[1])return errorCode(tags[1]);
    }
    if(offset>=size || !bytes)return ok;
    if(bytes>size-offset)bytes=size-offset;
    if(!aitdResloadCall(resload,0x4c,bytes,offset,relative(path),buffer,&error))return errorCode(error);
    actual=bytes;return ok;
}
static int32_t save(const char* path,const uint8_t* buffer,uint32_t bytes)
{
    if(!path || !buffer || bytes>chunkBytes)return invalid;
    return resloadReplace(path,buffer,bytes);
}
const Backend whdload={readAt,save};
}
