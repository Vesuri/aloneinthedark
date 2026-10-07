#ifndef AITD_EFFECT_DMA_STREAM_H
#define AITD_EFFECT_DMA_STREAM_H
namespace EffectDma {
struct Stream;
Stream* prepare(const unsigned char* pcm,unsigned long bytes,unsigned long start,
                unsigned long end,unsigned char* counter,const char*& error);
void start(Stream*,unsigned short channel,unsigned short period,unsigned short volume);
void suspend(Stream*);
void dispose(Stream*);
bool done(const Stream*);
unsigned short age(const Stream*,unsigned long tick);
unsigned char* chip(Stream*);
unsigned long fastBytes(const Stream*);
}
#endif
