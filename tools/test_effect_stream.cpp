#include "../src/mac/EffectStream.h"
#include <cassert>
#include <cstdio>
#include <vector>

static std::vector<uint8_t> drain(EffectStream::Cursor& cursor,unsigned fragment) {
    std::vector<uint8_t> result;uint8_t block[128];
    while(!cursor.finished) {
        unsigned count=cursor.fill(block,fragment);
        result.insert(result.end(),block,block+count);
        assert(result.size()<20000);
    }
    return result;
}
int main() {
    std::vector<uint8_t> pcm(4096);
    for(unsigned i=0;i<pcm.size();++i)pcm[i]=(i*37+i/7)&255;
    for(unsigned fragment: {1u,2u,7u,64u,127u,128u}) {
        for(unsigned count: {0u,1u,3u}) {
            uint8_t word[]={0,(uint8_t)count};EffectStream::Cursor cursor;
            assert(cursor.initialize(pcm.data(),pcm.size(),512,1024,word));
            std::vector<uint8_t> expected(pcm.begin(),pcm.begin()+1024);
            // Original count 3 has two repeats; zero and one have none.
            if(count==3)for(unsigned repeat=0;repeat<2;++repeat)
                expected.insert(expected.end(),pcm.begin()+512,pcm.begin()+1024);
            expected.insert(expected.end(),pcm.begin()+1024,pcm.end());
            assert(drain(cursor,fragment)==expected);
            assert(!word[0] && !word[1] && cursor.tailAgeHeld);
            assert(cursor.boundaries==(count==3 ? 3u : 1u));
        }
        // A negative counter never decrements; clearing the shared word takes
        // the next loop boundary through the complete original sample tail.
        uint8_t word[]={255,255},block[128];EffectStream::Cursor cursor;
        assert(cursor.initialize(pcm.data(),pcm.size(),512,1024,word));
        std::vector<uint8_t> actual;
        while(actual.size()<4096) {
            unsigned n=cursor.fill(block,fragment);actual.insert(actual.end(),block,block+n);
            assert(word[0]==255 && word[1]==255 && !cursor.finished);
        }
        for(unsigned i=0;i<actual.size();++i)
            assert(actual[i]==pcm[i<1024 ? i : 512+(i-1024)%512]);
        unsigned position=cursor.position;word[0]=word[1]=0;
        std::vector<uint8_t> expected(pcm.begin()+position,pcm.end());
        assert(drain(cursor,fragment)==expected && cursor.tailAgeHeld);
    }
    // Odd boundaries must not duplicate, drop or pad a byte inside the stream;
    // word-alignment padding belongs only to the DMA publisher's final block.
    for(unsigned start: {1u,2u,511u})for(unsigned end: {513u,514u,1023u}) {
        uint8_t word[]={0,3};EffectStream::Cursor cursor;
        assert(cursor.initialize(pcm.data(),4095,start,end,word));
        std::vector<uint8_t> expected(pcm.begin(),pcm.begin()+end);
        for(unsigned n=0;n<2;++n)expected.insert(expected.end(),pcm.begin()+start,pcm.begin()+end);
        expected.insert(expected.end(),pcm.begin()+end,pcm.begin()+4095);
        assert(drain(cursor,128)==expected);
    }
    EffectStream::Cursor invalid;uint8_t word[]={0,1};
    assert(!invalid.initialize(pcm.data(),4096,512,1024,0));
    assert(!invalid.initialize(pcm.data(),4096,512,512,word));
    assert(!invalid.initialize(pcm.data(),4096,512,4097,word));
    assert(!invalid.initialize(pcm.data(),4096,0,1024,word));
    std::puts("PASS effect stream planner: original zero/one/three/negative counts, live release, exact tails, odd boundaries and bounded fragments");
}
