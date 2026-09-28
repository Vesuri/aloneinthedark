#include "FileAccess.h"
// Offsets and tag value from WHDLoad Include/whdload.i (v18 API).
// This adapter deliberately makes no Exec/DOS calls.
extern "C" uint32_t aitdResloadCall(void*,uint32_t,uint32_t,uint32_t,const void*,void*,uint32_t*);
namespace FileAccess {
static void* resload=0;
void bindResload(void* entryTable) { resload=entryTable; }
static int32_t errorCode(uint32_t error) { return error==205 ? notFound : ioError; }
static int32_t readAt(const char* path,uint32_t offset,uint8_t* buffer,uint32_t bytes,uint32_t& actual)
{
    actual=0;
    if(!path || !buffer || bytes>chunkBytes || offset>0x7fffffffUL-bytes)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;
    uint32_t size=aitdResloadCall(resload,0x24,0,0,path,0,&error);
    if(!size) {
        uint32_t tags[]={0x8800000eUL,0,0}; // WHDLTAG_IOERR_GET, result, TAG_DONE
        if(!aitdResloadCall(resload,0x34,0,0,tags,0,&error))return ioError;
        if(tags[1])return errorCode(tags[1]);
    }
    if(offset>=size || !bytes)return ok;
    if(bytes>size-offset)bytes=size-offset;
    if(!aitdResloadCall(resload,0x4c,bytes,offset,path,buffer,&error))return errorCode(error);
    actual=bytes;return ok;
}
static int32_t save(const char* path,const uint8_t* buffer,uint32_t bytes)
{
    if(!path || !buffer || bytes>chunkBytes)return invalid;
    if(!resload)return unavailable;
    uint32_t error=0;
    return aitdResloadCall(resload,0x0c,bytes,0,path,(void*)buffer,&error) ? ok : errorCode(error);
}
const Backend whdload={readAt,save};
}
