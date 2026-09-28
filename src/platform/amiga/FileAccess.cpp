#include <proto/dos.h>
#include <dos/dos.h>
#include "FileAccess.h"
#include "SystemWindow.h"
#ifdef AITD_WINDOW_PROBE
extern "C" void aitdWindowProbeInside();
#endif
namespace FileAccess {
struct Request {
    const char* path;
    uint8_t* buffer;
    uint32_t offset,bytes,actual;
};
static int32_t readOperation(void* context)
{
    Request& r=*(Request*)context;
    BPTR file=Open((CONST_STRPTR)r.path,MODE_OLDFILE);
    if(!file)return IoErr()==ERROR_OBJECT_NOT_FOUND ? notFound : ioError;
    int32_t error=ok;
    if(Seek(file,r.offset,OFFSET_BEGINNING)<0)error=ioError;
    else {
        LONG got=Read(file,r.buffer,r.bytes);
        if(got<0)error=ioError;else r.actual=got;
    }
#ifdef AITD_WINDOW_PROBE
    Delay(2); // Diagnostic only: positively exercise OS scheduling and VBI servers.
    aitdWindowProbeInside();
#endif
    Close(file);
    return error;
}
static int32_t readAt(const char* path,uint32_t offset,uint8_t* buffer,uint32_t bytes,uint32_t& actual)
{
    actual=0;
    if(!path || !buffer || bytes>chunkBytes || offset>0x7fffffffUL-bytes)return invalid;
    Request request={path,buffer,offset,bytes,0};
    int32_t error=aitdSystemWindow(readOperation,&request);
    actual=request.actual;return error;
}
// Whole-file replacement is bounded to one chunk here; larger durable writes
// need a persistent file session (M3.6), not a partial success.
static int32_t saveOperation(void* context)
{
    Request& r=*(Request*)context;
    BPTR file=Open((CONST_STRPTR)r.path,MODE_NEWFILE);
    if(!file)return ioError;
    LONG wrote=Write(file,r.buffer,r.bytes);
    LONG closed=Close(file);
    return wrote==(LONG)r.bytes && closed ? ok : ioError;
}
static int32_t save(const char* path,const uint8_t* buffer,uint32_t bytes)
{
    if(!path || !buffer || bytes>chunkBytes)return invalid;
    Request request={path,(uint8_t*)buffer,0,bytes,0};
    return aitdSystemWindow(saveOperation,&request);
}
const Backend dos={readAt,save};
}
