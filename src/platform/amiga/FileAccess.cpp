#include <proto/dos.h>
#include <dos/dos.h>
#include "FileAccess.h"
#include "SystemWindow.h"
#ifdef AITD_WINDOW_PROBE
extern "C" void aitdWindowProbeInside();
#endif
#ifdef AITD_FILE_PROBE
extern "C" { volatile uint32_t g_fileReadCalls=0,g_fileReadBytes=0,g_fileReadMax=0,g_fileOpenHandles=0,g_fileRestoredCloses=0,g_fileCloseErrors=0; }
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
struct StreamRequest {
    ReadStream* stream;const char* path;uint8_t* buffer;
    uint32_t offset,bytes,actual;
};
static int32_t openStreamOperation(void* context) {
    StreamRequest& r=*(StreamRequest*)context;
    r.stream->handle=Open((CONST_STRPTR)r.path,MODE_OLDFILE);
#ifdef AITD_FILE_PROBE
    if(r.stream->handle)++g_fileOpenHandles;
#endif
    return r.stream->handle ? ok : IoErr()==ERROR_OBJECT_NOT_FOUND ? notFound : ioError;
}
int32_t openStream(const char* path,ReadStream& stream) {
    if(!path || stream.handle)return invalid;
    StreamRequest r={&stream,path,0,0,0,0};
    return aitdSystemWindow(openStreamOperation,&r);
}
static int32_t readStreamOperation(void* context) {
    StreamRequest& r=*(StreamRequest*)context;
    if(Seek(r.stream->handle,r.offset,OFFSET_BEGINNING)<0)return ioError;
    while(r.actual<r.bytes) {
        uint32_t count=r.bytes-r.actual;
        if(count>chunkBytes)count=chunkBytes;
#ifdef AITD_FILE_PROBE
        ++g_fileReadCalls;if(count>g_fileReadMax)g_fileReadMax=count;
#endif
        LONG got=Read(r.stream->handle,r.buffer+r.actual,count);
#ifdef AITD_FILE_PROBE
        if(got>0)g_fileReadBytes+=got;
#endif
        if(got<0)return ioError;
        r.actual+=got;
        if((uint32_t)got<count)break;
    }
    return ok;
}
int32_t readStream(void* context,uint32_t offset,uint8_t* buffer,uint32_t bytes,uint32_t& actual) {
    actual=0;
    if(!context)return invalid;
    ReadStream& stream=*(ReadStream*)context;
    if(!stream.handle || (!buffer && bytes) || bytes>0x7fffffffUL || offset>0x7fffffffUL-bytes)return invalid;
    StreamRequest r={&stream,0,buffer,offset,bytes,0};
    int32_t error=aitdSystemWindow(readStreamOperation,&r);
    actual=r.actual;return error;
}
static int32_t closeStreamOperation(void* context) {
    ReadStream& stream=*(ReadStream*)context;
    LONG closed=Close(stream.handle);stream.handle=0;
#ifdef AITD_FILE_PROBE
    --g_fileOpenHandles;if(!closed)++g_fileCloseErrors;
#endif
    return closed ? ok : ioError;
}
int32_t closeStream(ReadStream& stream) {
    if(!stream.handle)return invalid;
    return aitdSystemWindow(closeStreamOperation,&stream);
}
int32_t closeRestoredStream(ReadStream& stream) {
    if(!stream.handle)return invalid;
#ifdef AITD_FILE_PROBE
    ++g_fileRestoredCloses;
#endif
    return closeStreamOperation(&stream);
}
const Backend dos={readAt,save};
}
