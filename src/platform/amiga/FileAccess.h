#ifndef AITD_FILE_ACCESS_H
#define AITD_FILE_ACCESS_H
// All backends use bounded byte ranges. A short successful read is EOF.
namespace FileAccess {
enum { ok=0, invalid=-50, unavailable=-1, notFound=-43, ioError=-36 };
const uint32_t chunkBytes=65536;
struct Backend {
    int32_t (*readAt)(const char*,uint32_t,uint8_t*,uint32_t,uint32_t&);
    int32_t (*save)(const char*,const uint8_t*,uint32_t);
};
extern const Backend dos;
extern const Backend whdload;
// Slave supplies the resident resload entry table before starting the runtime.
void bindResload(void* entryTable);
}
#endif
