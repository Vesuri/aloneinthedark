#include <proto/dos.h>
#include <dos/dos.h>
#include "FileMetadataIO.h"
#include "SystemWindow.h"
extern "C" { extern volatile uint32_t g_macTicks; }
namespace FileAccess {
static const int32_t unsupported=-32760;
static uint32_t epoch=0,epochTicks=0;
static uint32_t dosTime() {
    struct DateStamp stamp;DateStamp(&stamp);
    return 2335305600UL+(uint32_t)stamp.ds_Days*86400UL+(uint32_t)stamp.ds_Minute*60UL+(uint32_t)stamp.ds_Tick/TICKS_PER_SECOND;
}
void initializeMetadataClock() { epoch=dosTime();epochTicks=g_macTicks; }
uint32_t metadataTime() { return epoch+(g_macTicks-epochTicks)/60; }
static int32_t error(LONG code) {
    switch(code) {
    case ERROR_OBJECT_NOT_FOUND:return -43;
    case ERROR_OBJECT_EXISTS:return -48;
    case ERROR_OBJECT_IN_USE:case ERROR_DIRECTORY_NOT_EMPTY:return -47;
    case ERROR_DELETE_PROTECTED:case ERROR_WRITE_PROTECTED:return -45;
    case ERROR_DISK_WRITE_PROTECTED:return -44;
    case ERROR_DISK_FULL:return -34;
    case ERROR_NO_FREE_STORE:return -108;
    default:return -36;
    }
}
static bool companion(char* out,const char* path,const char* suffix) {
    if(!path)return false;
    uint16_t n=0;
    while(*path) { if(n==191)return false;out[n++]=*path++; }
    while(*suffix) { if(n==191)return false;out[n++]=*suffix++; }
    out[n]=0;return true;
}
static int32_t exists(const char* path,bool& found) {
    BPTR lock=Lock((CONST_STRPTR)path,ACCESS_READ);
    found=lock!=0;if(lock) { UnLock(lock);return 0; }
    LONG why=IoErr();return why==ERROR_OBJECT_NOT_FOUND ? 0 : error(why);
}
static int32_t writeNewMetadata(const char* path,const FileMetadata::Record& record) {
    bool present=false;int32_t result=exists(path,present);
    if(result || present)return result ? result : unsupported;
    BPTR file=Open((CONST_STRPTR)path,MODE_NEWFILE);if(!file)return error(IoErr());
    uint8_t bytes[FileMetadata::bytes];FileMetadata::encode(record,bytes);
    if(Write(file,bytes,sizeof(bytes))!=(LONG)sizeof(bytes) || !Flush(file))result=-36;
    if(!Close(file))result=-36;
    if(result && !DeleteFile((CONST_STRPTR)path))return unsupported;
    return result;
}
int32_t forkSizeRestored(const char* path,uint32_t& size,bool& found) {
    size=0;BPTR lock=Lock((CONST_STRPTR)path,ACCESS_READ);found=lock!=0;
    if(!lock)return IoErr()==ERROR_OBJECT_NOT_FOUND ? 0 : error(IoErr());
    FileInfoBlock* info=(FileInfoBlock*)AllocDosObject(DOS_FIB,0);
    int32_t result=!info ? -108 : !Examine(lock,info) ? -36
        : info->fib_DirEntryType>=0 || info->fib_Size<0 ? unsupported : 0;
    if(!result)size=info->fib_Size;
    if(info)FreeDosObject(DOS_FIB,info);UnLock(lock);return result;
}
int32_t loadMetadataRestored(const char* path,FileMetadata::Record& record,bool& found) {
    char name[192];found=false;
    if(!companion(name,path,".finfo"))return unsupported;
    BPTR file=Open((CONST_STRPTR)name,MODE_OLDFILE);
    if(!file) { LONG why=IoErr();return why==ERROR_OBJECT_NOT_FOUND ? 0 : error(why); }
    uint8_t bytes[FileMetadata::bytes+1];LONG actual=Read(file,bytes,sizeof(bytes));
    int32_t result=actual<0 ? -36 : FileMetadata::decode(bytes,actual,record) ? 0 : unsupported;
    if(!Close(file))result=-36;
    found=!result;return result;
}
struct CreateRequest { const char* path;const char* parent;bool materialize;FileMetadata::Record* record; };
static int32_t createOperation(void* context) {
    CreateRequest& request=*(CreateRequest*)context;
    bool present=false;int32_t result=exists(request.path,present);
    if(result || present)return result ? result : -48;
    char metadata[192];if(!companion(metadata,request.path,".finfo"))return unsupported;
    result=exists(metadata,present);if(result || present)return result ? result : unsupported;
    char resource[192];if(!companion(resource,request.path,".rsrc"))return unsupported;
    result=exists(resource,present);if(result || present)return result ? result : unsupported;
    result=exists(request.parent,present);if(result)return result;
    if(!present) {
        if(!request.materialize)return -120;
        BPTR directory=CreateDir((CONST_STRPTR)request.parent);
        if(!directory)return error(IoErr());
        UnLock(directory);
    }
    BPTR file=Open((CONST_STRPTR)request.path,MODE_NEWFILE);if(!file)return error(IoErr());
    if(!Close(file)) { if(!DeleteFile((CONST_STRPTR)request.path))return unsupported;return -36; }
    FileMetadata::Record fresh={};fresh.created=fresh.modified=metadataTime();
    result=writeNewMetadata(metadata,fresh);
    if(result) { if(!DeleteFile((CONST_STRPTR)request.path))return unsupported;return result; }
    *request.record=fresh;return 0;
}
int32_t createFile(const char* path,const char* parent,bool materializeParent,FileMetadata::Record& record) {
    if(!path || !parent)return -50;
    CreateRequest request={path,parent,materializeParent,&record};return aitdSystemWindow(createOperation,&request);
}
struct ProtectionRequest { const char* path;bool locked; };
static int32_t protectionOperation(void* context) {
    ProtectionRequest& request=*(ProtectionRequest*)context;
    BPTR lock=Lock((CONST_STRPTR)request.path,ACCESS_READ);if(!lock)return error(IoErr());
    FileInfoBlock* info=(FileInfoBlock*)AllocDosObject(DOS_FIB,0);
    int32_t result=!info ? -108 : !Examine(lock,info) ? -36 : 0;
    if(!result)request.locked=(info->fib_Protection&FIBF_WRITE)!=0;
    if(info)FreeDosObject(DOS_FIB,info);UnLock(lock);return result;
}
int32_t fileProtection(const char* path,bool& locked) {
    ProtectionRequest request={path,false};int32_t result=aitdSystemWindow(protectionOperation,&request);
    if(!result)locked=request.locked;return result;
}
struct DeleteRequest { const char* path;bool resourceIsBase; };
static int32_t deleteOperation(void* context) {
    DeleteRequest& request=*(DeleteRequest*)context;const char* path=request.path;
    BPTR lock=Lock((CONST_STRPTR)path,ACCESS_READ);if(!lock)return error(IoErr());
    FileInfoBlock* info=(FileInfoBlock*)AllocDosObject(DOS_FIB,0);
    int32_t result=!info ? -108 : !Examine(lock,info) ? -36
        : info->fib_DirEntryType>=0 ? unsupported
        : (info->fib_Protection&(FIBF_WRITE|FIBF_DELETE)) ? -45 : 0;
    if(info)FreeDosObject(DOS_FIB,info);
    UnLock(lock);if(result)return result;
    char metadata[192];if(!companion(metadata,path,".finfo"))return unsupported;
    bool present=false;result=exists(metadata,present);if(result)return result;
    char resource[192];if(!companion(resource,path,request.resourceIsBase ? ".data" : ".rsrc"))return unsupported;
    bool resourcePresent=false;result=exists(resource,resourcePresent);if(result)return result;
    if(!DeleteFile((CONST_STRPTR)path))return error(IoErr());
    if(resourcePresent && !DeleteFile((CONST_STRPTR)resource))return unsupported;
    // A partial deletion is a loud stop, never a claimed complete removal.
    if(present && !DeleteFile((CONST_STRPTR)metadata))return unsupported;
    return 0;
}
int32_t deleteFile(const char* path,bool resourceIsBase) {
    DeleteRequest request={path,resourceIsBase};return path ? aitdSystemWindow(deleteOperation,&request) : -50;
}
struct MetadataRequest { const char* path;const FileMetadata::Record* record; };
static int32_t storeOperation(void* context) {
    MetadataRequest& request=*(MetadataRequest*)context;
    char current[192],temporary[192],backup[192];
    if(!companion(current,request.path,".finfo") || !companion(temporary,request.path,".finfo.new")
        || !companion(backup,request.path,".finfo.old"))return unsupported;
    bool previous=false,orphan=false;int32_t result=exists(backup,orphan);
    if(result || orphan)return result ? result : unsupported;
    result=exists(current,previous);if(result)return result;
    result=writeNewMetadata(temporary,*request.record);if(result)return result;
    if(previous && !Rename((CONST_STRPTR)current,(CONST_STRPTR)backup)) {
        if(!DeleteFile((CONST_STRPTR)temporary))return unsupported;
        return -36;
    }
    if(!Rename((CONST_STRPTR)temporary,(CONST_STRPTR)current)) {
        if(previous && !Rename((CONST_STRPTR)backup,(CONST_STRPTR)current))return unsupported;
        if(!DeleteFile((CONST_STRPTR)temporary))return unsupported;
        return -36;
    }
    if(previous && !DeleteFile((CONST_STRPTR)backup))return unsupported;
    return 0;
}
int32_t storeMetadata(const char* path,const FileMetadata::Record& record,bool restored) {
    if(!path)return -50;
    MetadataRequest request={path,&record};
    return restored ? storeOperation(&request) : aitdSystemWindow(storeOperation,&request);
}
}
