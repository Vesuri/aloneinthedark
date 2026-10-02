#include "../src/mac/SongInputs.h"
#include "../src/mac/SongTimeline.h"
#include "../src/mac/SongVoice.h"
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
    unsigned long long random=0x83e473991035ef83ULL;
    for(unsigned i=0;i<2000;++i) {
        random=random*6364136223846793005ULL+1;auto numerator=random;
        random=random*6364136223846793005ULL+1;auto denominator=(i&1) ? random : random>>32;
        uint32_t result=0;bool okay=SongVoice::divide(numerator,denominator,result);
        assert(okay==(denominator && numerator/denominator<=0xffffffffULL));
        if(okay)assert(result==numerator/denominator);
    }
    uint32_t quotient=0;assert(!SongVoice::divide(1,0,quotient));
    assert(SongVoice::divide(0xffffffffffffffffULL,0xffffffffffffffffULL,quotient) && quotient==1);
    assert(!SongVoice::divide(0x100000000ULL,1,quotient));
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
    SongTimeline clock;bool ready=false;
    auto timed=midi({0,0x90,60,127,0x83,0x60,0x80,60,64,0,0xff,0x2f,0});
    assert(!clock.start(timed.data(),timed.size(),song) && clock.step==1059);
    assert(!clock.next(event,ready) && !ready);
    for(unsigned pulse=1;pulse<=31;++pulse) {
        assert(!clock.advance());
        assert(!clock.next(event,ready));
        assert(ready==(pulse==1 || pulse==31));
        if(ready)assert(event.kind==(pulse==1?Event::NoteOn:Event::NoteOff));
        if(pulse==31)assert(!clock.next(event,ready) && ready && event.kind==Event::End && !clock.active);
    }
    assert(clock.advance());
    // A tempo whose quotient is exactly 30 makes the countdown hit zero;
    // the original waits one further pulse for borrow before emitting the note.
    auto exact=midi({0,0xff,0x51,3,7,0xa1,0x2a,0,0x90,60,127,0x83,0x60,0x80,60,64,0,0xff,0x2f,0});
    assert(!clock.start(exact.data(),exact.size(),song));
    for(unsigned pulse=1;pulse<=32;++pulse) {
        assert(!clock.advance());assert(!clock.next(event,ready));
        if(pulse==1) {assert(ready && event.kind==Event::Tempo && clock.step==1024);assert(!clock.next(event,ready) && ready && event.kind==Event::NoteOn);}
        else assert(ready==(pulse==32));
    }
    std::puts("PASS song clock: first pulse, quantized tempo, exact-zero borrow boundary and same-pulse end");
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
    // Sample selection reproduces the original byte comparisons, including
    // open range ends and the signed upper-bound branch.
    uint8_t ranged[30]={0,1,0,72,255,0,0,0,0,0,0,0,0,1,20,80,0,2,0,0,0,0,0,0,128,0,0,0,0,0};
    assert(!instrument.parse(ranged,sizeof(ranged)));
    uint16_t selected=0;int16_t adjusted=0;bool found=false;
    assert(!SongVoice::select(instrument,52,selected,adjusted,found) && found && selected==2 && adjusted==40);
    assert(!SongVoice::select(instrument,20,selected,adjusted,found) && !found);
    assert(!SongVoice::select(instrument,0,selected,adjusted,found) && found && adjusted==-12);
    assert(SongVoice::select(instrument,128,selected,adjusted,found));
    uint32_t step=0;assert(!SongVoice::pitch(40,48,step) && step==0x1427e);
    assert(SongVoice::pitch(-61,60,step));assert(SongVoice::pitch(128,60,step));
    // Independent streaming oracle: advance one source byte at a time through
    // each wrap, and compare several hardware reloads plus guarded allocation.
    for(uint32_t clock: {3546895u,3579545u})
    for(unsigned size: {101u,200u,301u})for(unsigned start: {0u,1u,100u})for(unsigned pitchIndex: {48u,72u,84u}) {
        if(start>=size)continue;
        std::vector<uint8_t> pcm(size);for(unsigned i=0;i<size;++i)pcm[i]=(i*47+13)&255;
        Sample spec;spec.pcm=pcm.data();spec.size=size;spec.rate=11025u<<16;spec.baseNote=60;
        spec.loopStart=start;spec.loopEnd=start ? size : 0;
        SongVoice::Plan plan;assert(!SongVoice::describe(spec,pitchIndex,clock,plan));
        SongVoice::Dma dma;assert(!SongVoice::dma(spec,plan,clock,dma));
        assert(dma.period>=124 && dma.stride>=1);
        std::vector<uint8_t> bytes(dma.layout.allocated+2,0x5a);SongVoice::convert(dma,bytes.data()+1);
        assert(bytes.front()==0x5a && bytes.back()==0x5a);
        unsigned cursor=0;
        for(unsigned i=0;i<dma.layout.attackBytes+3*dma.layout.reloadBytes;++i) {
            unsigned offset=i<dma.layout.attackBytes ? i : dma.layout.reloadOffset+(i-dma.layout.attackBytes)%dma.layout.reloadBytes;
            uint8_t expected=cursor<size ? pcm[cursor]^0x80 : 0;
            assert(bytes[offset+1]==expected);
            for(unsigned k=0;k<dma.stride;++k) {
                ++cursor;if(plan.loopEnd && cursor==plan.loopEnd)cursor=plan.loopStart;
            }
        }
    }
    std::puts("PASS song voice plan: range selection, quantized pitch, bounded periods and 27 guarded looping/decimation streams");
    if(argc==3 || argc==4) {
        auto rawSong=load(argv[1]),rawMidi=load(argv[2]);
        assert(!song.parse(rawSong.data(),rawSong.size()));assert(!decoder.begin(rawMidi.data(),rawMidi.size(),song));
        for(unsigned index=0;index<128;++index) {
            uint32_t pitchStep=0;assert(!SongVoice::pitch(index,60,pitchStep));
            std::printf("SONG_PITCH index=%u step=%X\n",index,pitchStep);
        }
        unsigned count=0;bool used[128]={};
        while(!decoder.ended) {
            const char* error=decoder.next(event);if(error) {std::fprintf(stderr,"FAIL %s\n",error);return 1;}
            if(event.kind==Event::NoteOn || event.kind==Event::NoteOff) {
                assert(event.instrument<128);used[event.instrument]=true;
                std::printf("SONG_EVENT n=%u on=%u offset=%X instrument=%X note=%X velocity=%X channel=%X\n",++count,event.kind==Event::NoteOn,event.offset,event.instrument,event.note,event.velocity,event.channel);
            }
        }
        std::printf("PASS decoded song events=%u ticks=%u\n",count,event.tick);
        SongTimeline timeline;assert(!timeline.start(rawMidi.data(),rawMidi.size(),song));
        unsigned timedCount=0;
        while(timeline.active) {
            assert(timeline.pulses<100000);assert(!timeline.advance());
            for(;;) {
                bool available=false;const char* error=timeline.next(event,available);
                if(error) {std::fprintf(stderr,"FAIL %s\n",error);return 1;}
                if(!available)break;
                if(event.kind==Event::NoteOn || event.kind==Event::NoteOff)
                    std::printf("SONG_TIMED_EVENT n=%u offset=%X pulse=%X step=%X\n",++timedCount,event.offset,timeline.pulses,timeline.step);
            }
        }
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
            assert(!decoder.begin(rawMidi.data(),rawMidi.size(),song));unsigned noteNumber=0;
            while(!decoder.ended) {
                assert(!decoder.next(event));
                if(event.kind!=Event::NoteOn && event.kind!=Event::NoteOff)continue;
                ++noteNumber;if(event.kind!=Event::NoteOn)continue;
                char path[1024];std::snprintf(path,sizeof(path),"%s/INST_%u",argv[3],event.instrument);
                auto body=load(path);Instrument spec;assert(!spec.parse(body.data(),body.size()));
                uint16_t selected=0;int16_t adjusted=0;bool found=false;
                assert(!SongVoice::select(spec,event.note,selected,adjusted,found) && found);
                std::snprintf(path,sizeof(path),"%s/snd_%u",argv[3],selected);auto pcm=load(path);Sample format;
                assert(!format.parse(pcm.data(),pcm.size()));SongVoice::Plan plan;
                assert(!SongVoice::describe(format,adjusted,3546895,plan));
                SongVoice::Dma dma;assert(!SongVoice::dma(format,plan,3546895,dma));
                std::vector<uint8_t> chip(dma.layout.allocated+2,0x5a);SongVoice::convert(dma,chip.data()+1);
                assert(chip.front()==0x5a && chip.back()==0x5a);
                uint32_t cursor=0;
                for(uint32_t i=0;i<dma.layout.attackBytes+2*dma.layout.reloadBytes;++i) {
                    uint32_t offset=i<dma.layout.attackBytes ? i : dma.layout.reloadOffset+(i-dma.layout.attackBytes)%dma.layout.reloadBytes;
                    assert(chip[offset+1]==(cursor<format.size ? (format.pcm[cursor]^0x80) : 0));
                    for(uint16_t k=0;k<dma.stride;++k) {
                        ++cursor;if(plan.loopEnd && cursor==plan.loopEnd)cursor=plan.loopStart;
                    }
                }

                std::printf("SONG_PLAN n=%u sample=%u step=%X bytes=%u loop=%u/%u period=%u\n",noteNumber,selected,plan.step,format.size,plan.loopStart,plan.loopEnd,plan.period);
            }

        }
    }
}
