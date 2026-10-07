/* macOS arm64/x86-64 SDL2 callback capture for the installed FS-UAE.
 * Build (use the emulator architecture): clang -arch arm64 -O2 -dynamiclib -undefined dynamic_lookup
 *        tools/capture_fsuae_audio.c -o tmp/capture-fsuae-audio.dylib
 * Set DYLD_INSERT_LIBRARIES to that absolute library path only for FS-UAE,
 * and AITD_AUDIO_CAPTURE to a new absolute output path. Existing files are
 * never overwritten. Playback remains enabled and its bytes are unchanged.
 * A shared mapping retains committed callbacks even when the diagnostic
 * launcher terminates the emulator with SIGKILL. No callback does file I/O.
 * This records PCM supplied to SDL, not microphone/system audio or physical
 * speaker output. The SDL2 ABI and host architecture are deliberate limits.
 */
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>
// SDL2's documented ABI. No game state or sound samples are modified.
typedef struct {int freq;uint16_t format;uint8_t channels,silence;uint16_t samples,padding;uint32_t size;void (*callback)(void*,uint8_t*,int);void* userdata;} Spec;
extern unsigned SDL_OpenAudioDevice(const char*,int,const Spec*,Spec*,int);
#define ROWS 65536u
#define DATA_OFFSET (4096u+ROWS*24u)
#define CAPACITY (192u*1024u*1024u)
typedef struct {char magic[8];uint32_t version,frequency,format,channels,samples,device;uint64_t bytes,callbacks,overflow,dataOffset,capacity;} Header;
typedef struct {uint64_t ns,offset;uint32_t length,reserved;} Row;
_Static_assert(sizeof(Spec)==32,"SDL2 audio ABI");
_Static_assert(sizeof(Row)==24,"capture row ABI");
static Header* header;
static void (*original)(void*,uint8_t*,int);
static void* original_data;
static void callback(void* unused,uint8_t* stream,int length) {
    (void)unused;
    original(original_data,stream,length);
    struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);
    uint64_t offset=header->bytes,index=header->callbacks;
    if(length<0 || offset+(uint64_t)length>CAPACITY || index>=ROWS) {header->overflow++;return;}
    memcpy((uint8_t*)header+DATA_OFFSET+offset,stream,(size_t)length);
    Row* rows=(Row*)((uint8_t*)header+4096);
    rows[index]=(Row){(uint64_t)t.tv_sec*1000000000u+t.tv_nsec,offset,(uint32_t)length,0};
    __atomic_store_n(&header->bytes,offset+length,__ATOMIC_RELEASE);
    __atomic_store_n(&header->callbacks,index+1,__ATOMIC_RELEASE);
}
static unsigned capture_open(const char* name,int recording,const Spec* want,Spec* have,int changes) {
    const char* path=getenv("AITD_AUDIO_CAPTURE");
    if(!path || recording || header || !want || !want->callback)
        return SDL_OpenAudioDevice(name,recording,want,have,changes);
    int fd=open(path,O_CREAT|O_EXCL|O_RDWR,0600);
    if(fd<0) return SDL_OpenAudioDevice(name,recording,want,have,changes);
    size_t size=DATA_OFFSET+(size_t)CAPACITY;
    if(ftruncate(fd,size)) {close(fd);return SDL_OpenAudioDevice(name,recording,want,have,changes);}
    void* memory=mmap(0,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);close(fd);
    if(memory==MAP_FAILED)return SDL_OpenAudioDevice(name,recording,want,have,changes);
    header=memory;memcpy(header->magic,"AITDPCM1",8);header->version=1;
    header->dataOffset=DATA_OFFSET;header->capacity=CAPACITY;
    original=want->callback;original_data=want->userdata;
    Spec wrapped=*want;wrapped.callback=callback;wrapped.userdata=0;
    unsigned device=SDL_OpenAudioDevice(name,recording,&wrapped,have,changes);
    const Spec* actual=have ? have : want;
    header->frequency=actual->freq;header->format=actual->format;
    header->channels=actual->channels;header->samples=actual->samples;header->device=device;
    if(have) {have->callback=want->callback;have->userdata=want->userdata;}
    return device;
}
__attribute__((used)) static struct {const void* replacement;const void* original;} interpose
__attribute__((section("__DATA,__interpose")))={(const void*)capture_open,(const void*)SDL_OpenAudioDevice};
