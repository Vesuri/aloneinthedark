#include "../src/mac/SongInputs.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>
using namespace SongInputs;
static std::vector<uint8_t> midi(std::initializer_list<uint8_t> track) {
    std::vector<uint8_t> v={0x4d,0x54,0x68,0x64,0,0,0,6,0,0,0,1,1,0xe0,0x4d,0x54,0x72,0x6b,0,0,0,(uint8_t)track.size()};
    v.insert(v.end(),track);return v;
}
static std::vector<uint8_t> load(const char* name) {
    std::ifstream file(name,std::ios::binary);assert(file);
    return std::vector<uint8_t>(std::istreambuf_iterator<char>(file),{});
}
int main(int argc,char** argv) {
    uint8_t config[]={0,1,0,4,0,0,0,0,1,6,0,3,0x22,5,0,0,0,0};
    Song song;assert(!song.parse(config,sizeof(config)));
    Midi decoder;Event event;
    auto good=midi({0,0xc0,11,0,0xb0,7,64,0,0x90,60,127,1,61,64,2,0x80,60,23,0,0xff,0x2f,0});
    assert(!decoder.begin(good.data(),good.size(),song));
    assert(!decoder.next(event) && event.kind==Event::NoteOn && event.instrument==0 && event.note==60 && event.velocity==64 && event.tick==0);
    assert(!decoder.next(event) && event.kind==Event::NoteOn && event.note==61 && event.velocity==32 && event.tick==1);
    assert(!decoder.next(event) && event.kind==Event::NoteOff && event.velocity==23 && event.tick==3);
    assert(!decoder.next(event) && event.kind==Event::End && decoder.ended);
    assert(decoder.next(event));
    auto tempo=midi({0,0xff,0x51,3,7,0xa1,0x20,0,0xff,0x2f,0});
    assert(!decoder.begin(tempo.data(),tempo.size(),song));
    assert(!decoder.next(event) && event.kind==Event::Tempo && event.tempo==500000);
    // Every truncation of a complete real-sized event stream fails its container check.
    for(unsigned n=0;n<good.size();++n)assert(decoder.begin(good.data(),n,song));
    for(unsigned n=0;n<sizeof(config);++n) {Song bad;assert(bad.parse(config,n));}
    auto badSong=std::vector<uint8_t>(config,config+sizeof(config));badSong[13]=0;assert(song.parse(badSong.data(),badSong.size()));
    assert(!song.parse(config,sizeof(config)));
    const std::vector<std::vector<uint8_t>> badTracks={
        midi({0,60,1}),midi({0x81,0x80,0x80,0x80,0}),midi({0,0x90,60}),
        midi({0,0x90,128,1}),midi({0,0xff}),midi({0,0xff,1,4,1}),
        midi({0,0xff,0x51,2,1,1}),midi({0,0xff,0x51,3,0,0,0}),
        midi({0,0xff,0x2f,1,0}),midi({0,0xf0,0}),midi({0,0x90,1,2})
    };
    for(const auto& bad:badTracks) {
        assert(!decoder.begin(bad.data(),bad.size(),song));
        const char* error=0;
        for(unsigned i=0;i<4 && !error && !decoder.ended;++i)error=decoder.next(event);
        assert(error);
    }
    std::puts("PASS SONG/MIDI fixtures: volume, running status, ignored program changes, note order, tempo, end and bounded malformed-input rejection");
    uint8_t inst[22]={0,1,0,60,255,0,0,0,0,0,0,0,0,0,0,0,128,0,0,0,0,0};
    Instrument instrument;assert(!instrument.parse(inst,sizeof(inst)) && instrument.baseSample==1);
    for(unsigned n=0;n<sizeof(inst);++n)assert(instrument.parse(inst,n));
    inst[7]=1;assert(instrument.parse(inst,sizeof(inst)));inst[7]=0;
    inst[15]=127;assert(instrument.parse(inst,sizeof(inst)));inst[15]=0;
    uint8_t sound[40]={0,2,0,0,0,1,0x80,0x50,0,0,0,0,0,14,0,0,0,0,0,0,0,4,
                       0x2b,0x11,0,0,0,0,0,0,0,0,0,0,0,60,0,127,128,255};
    Sample sample;assert(!sample.parse(sound,sizeof(sound)) && sample.size==4 && sample.pcm==sound+36);
    for(unsigned n=0;n<sizeof(sound);++n)assert(sample.parse(sound,n));
    sound[34]=1;assert(sample.parse(sound,sizeof(sound)));sound[34]=0;
    sound[33]=5;assert(sample.parse(sound,sizeof(sound)));sound[33]=4;
    assert(!sample.parse(sound,sizeof(sound)) && sample.loopEnd==4);
    sound[29]=4;assert(sample.parse(sound,sizeof(sound)));sound[29]=0;
    auto padded=std::vector<uint8_t>(sound,sound+sizeof(sound));padded.resize(76,0xa5);
    assert(!sample.parse(padded.data(),padded.size()) && sample.size==4 && sample.trailingBytes==36);
    std::puts("PASS INST/SND fixtures: exact sizes, range trailer, encoding, sample bounds and loop bounds");
    if(argc==3 || argc==4) {
        auto rawSong=load(argv[1]),rawMidi=load(argv[2]);
        assert(!song.parse(rawSong.data(),rawSong.size()));assert(!decoder.begin(rawMidi.data(),rawMidi.size(),song));
        unsigned count=0;bool used[128]={};
        while(!decoder.ended) {
            const char* error=decoder.next(event);if(error) {std::fprintf(stderr,"FAIL %s\n",error);return 1;}
            if(event.kind==Event::NoteOn || event.kind==Event::NoteOff) {
                assert(event.instrument<128);used[event.instrument]=true;
                std::printf("SONG_EVENT n=%u on=%u offset=%X instrument=%X note=%X velocity=%X channel=%X\n",++count,event.kind==Event::NoteOn,event.offset,event.instrument,event.note,event.velocity,event.channel);
            }
        }
        std::printf("PASS decoded song events=%u ticks=%u\n",count,event.tick);
        if(argc==4) {
            bool samples[32768]={};unsigned instruments=0,pcmCount=0;
            for(unsigned id=0;id<128;++id)if(used[id]) {
                char path[1024];std::snprintf(path,sizeof(path),"%s/INST_%u",argv[3],id);
                auto body=load(path);Instrument spec;const char* error=spec.parse(body.data(),body.size());
                if(error) {std::fprintf(stderr,"FAIL INST %u %s\n",id,error);return 1;}
                ++instruments;std::printf("SONG_INSTRUMENT id=%u ranges=%u pitch=%u\n",id,spec.ranges,spec.basePitch);
                for(unsigned r=0;r<=spec.ranges;++r) {
                    uint16_t sid=r ? spec.rangeSample(r-1) : spec.baseSample;
                    if(!sid)continue;assert(sid<32768);
                    if(samples[sid])continue;samples[sid]=true;++pcmCount;
                    std::snprintf(path,sizeof(path),"%s/snd_%u",argv[3],sid);auto pcm=load(path);Sample format;
                    if((error=format.parse(pcm.data(),pcm.size()))) {std::fprintf(stderr,"FAIL SND %u %s\n",sid,error);return 1;}
                    std::printf("SONG_SAMPLE id=%u bytes=%u rate=%u loop=%u/%u note=%u\n",sid,format.size,format.rate,format.loopStart,format.loopEnd,format.baseNote);
                }
            }
            std::printf("PASS song resource graph instruments=%u samples=%u\n",instruments,pcmCount);
        }
    }
}
