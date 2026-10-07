#ifndef AITD_EFFECT_STREAM_H
#define AITD_EFFECT_STREAM_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Sample-order planner for bounded DMA fragments. PCM is already converted;
// this performs no allocation, conversion, division or resource access.
// Counter bytes use the original guest's big-endian signed-word convention.
namespace EffectStream {
struct Cursor {
    const uint8_t* pcm=0;
    uint8_t* counter=0;
    uint32_t size=0,position=0,loopStart=0,loopEnd=0,boundaries=0;
    bool looping=false,finished=false,tailAgeHeld=false;
    bool initialize(const uint8_t* data,uint32_t bytes,uint32_t start,
                    uint32_t end,uint8_t* count) {
        *this=Cursor();
        if(!data || !bytes || ((start || end) && (!start || end<=start || end>bytes || !count)))return false;
        pcm=data;size=bytes;loopStart=start;loopEnd=end;counter=count;
        looping=end!=0;return true;
    }
    uint16_t fill(uint8_t* destination,uint16_t capacity) {
        uint16_t written=0;
        while(written<capacity && !finished) {
            if(looping && position==loopEnd) {
                int16_t count=(int16_t)((counter[0]<<8)|counter[1]);
                ++boundaries;
                if(count>0) {
                    --count;counter[0]=(uint16_t)count>>8;counter[1]=(uint8_t)count;
                }
                if(count)position=loopStart;
                else {looping=false;tailAgeHeld=true;}
            }
            if(position==size) {finished=true;break;}
            destination[written++]=pcm[position++];
        }
        return written;
    }
};
}
#endif
