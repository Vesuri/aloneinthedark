#ifndef AITD_FILE_ACCESS_H
#define AITD_FILE_ACCESS_H
// All backends use bounded byte ranges. A short successful read is EOF.
class FileWriteBuffer;
namespace FileAccess {
enum { ok=0, invalid=-50, unavailable=-1, notFound=-43, ioError=-36 };
const uint32_t chunkBytes=65536;
struct Backend {
    int32_t (*readAt)(const char*,uint32_t,uint8_t*,uint32_t,uint32_t&);
    int32_t (*save)(const char*,const uint8_t*,uint32_t);
};
// Persistent DOS fork. Runtime operations enter a bounded system window;
// the File Manager enforces caller permissions before using write callbacks.
struct ReadStream { uint32_t handle; };
int32_t openStream(const char* path,ReadStream& stream);
int32_t readStream(void* stream,uint32_t offset,uint8_t* buffer,uint32_t bytes,uint32_t& actual);
int32_t closeStream(ReadStream& stream);
int32_t flushStream(ReadStream& stream,FileWriteBuffer& buffer);
// Shutdown only: caller has fully restored OS ownership and scheduling.
int32_t flushRestoredStream(ReadStream& stream,FileWriteBuffer& buffer);
int32_t closeRestoredStream(ReadStream& stream);
extern const Backend dos;
extern const Backend whdload;
// Slave supplies the resident resload entry table before starting the runtime.
void bindResload(void* entryTable);
}
#endif
