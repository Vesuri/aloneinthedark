#ifndef AITD_SONG_INPUTS_H
#define AITD_SONG_INPUTS_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Bounded descriptions of the formats reached by SoundMusicSys selector 0.
// These helpers neither own resources nor start voices.
namespace SongInputs {
inline uint16_t word(const uint8_t* p) { return uint16_t(p[0])<<8|p[1]; }
inline uint32_t longword(const uint8_t* p) { return uint32_t(word(p))<<16|word(p+2); }
struct Song {
    const uint8_t* data=0;
    uint16_t midi=0,flags=0,maps=0,musicVoices=0,effectVoices=0,normalized=0;
    int16_t transpose=0;
    const char* parse(const uint8_t* p,uint32_t size) {
        if(!p || size<18)return "SONG HEADER";
        uint16_t count=word(p+16);
        if(count>128 || size!=18u+4u*count)return "SONG MAPPING SIZE";
        if(word(p+12)!=0x2205)return "SONG FLAGS";
        if(!p[9] || p[8]+p[9]>16 || word(p+10)>16)return "SONG VOICES";
        for(uint16_t i=0;i<count;++i)
            if(word(p+18+4*i)>127 || word(p+20+4*i)>127)return "SONG MAPPING RANGE";
        data=p;midi=word(p);flags=word(p+12);maps=count;transpose=(int16_t)word(p+6);
        musicVoices=p[9];effectVoices=p[8];normalized=word(p+10);
        return 0;
    }
    uint16_t instrument(uint8_t program) const {
        for(uint16_t i=0;i<maps;++i)
            if(word(data+18+4*i)==program)return word(data+20+4*i);
        return program;
    }
    uint16_t note(uint8_t pitch) const {
        uint16_t shifted=(uint16_t)(pitch+transpose);
        // Original adds a word, tests the low byte's sign, then undoes a
        // negative-byte result. Retain that behavior rather than clamping.
        return shifted&0x80 ? pitch : shifted;
    }
};
struct Instrument {
    const uint8_t* data=0;
    uint16_t baseSample=0,basePitch=0,ranges=0;
    const char* parse(const uint8_t* p,uint32_t size) {
        if(!p || size<22)return "INST HEADER";
        uint16_t count=word(p+12);
        if(count>128 || size!=22u+8u*count)return "INST RANGE SIZE";
        // These are the seven instruments reached by SONG 135. Random,
        // velocity, recursive instrument and modifier forms remain explicit.
        if(p[4]!=255 || p[5] || word(p+6) || word(p+8) || word(p+10))return "INST FLAGS";
        if(word(p+2)>127)return "INST BASE PITCH";
        for(uint16_t i=0;i<count;++i) {
            const uint8_t* row=p+14+8*i;
            if(row[0]>row[1] || row[1]>127 || longword(row+4))return "INST RANGE";
        }
        const uint8_t* end=p+14+8*count;
        if(word(end)!=0 || word(end+2)!=0x8000 || longword(end+4))return "INST TRAILER";
        data=p;baseSample=word(p);basePitch=word(p+2);ranges=count;
        return 0;
    }
    uint16_t rangeSample(uint16_t index) const {
        return index<ranges ? word(data+16+8*index) : 0;
    }
};
struct Sample {
    const uint8_t* pcm=0;
    uint32_t size=0,rate=0,loopStart=0,loopEnd=0,trailingBytes=0;
    uint8_t baseNote=0;
    const char* parse(const uint8_t* p,uint32_t bytes) {
        if(!p || bytes<36)return "SND HEADER";
        if(word(p)!=2 || word(p+2) || word(p+4)!=1 || word(p+6)!=0x8050
           || word(p+8) || longword(p+10)!=14)return "SND COMMAND";
        const uint8_t* h=p+14;
        if(longword(h) || h[20])return "SND ENCODING";
        uint32_t length=longword(h+4),start=longword(h+12),end=longword(h+16);
        if(!length || length>bytes-36 || !longword(h+8) || h[21]>127)return "SND SAMPLE";
        if(start>length || (end!=0xffffffffUL && end>length)
           || (end==0xffffffffUL && start) || (end && end!=0xffffffffUL && start>=end)
           || (!end && start))return "SND LOOP";
        // Original +$34BE uses the declared sample count, not resource size.
        trailingBytes=bytes-36-length;pcm=p+36;size=length;rate=longword(h+8);loopStart=start;loopEnd=end;baseNote=h[21];
        return 0;
    }
};
struct Event {
    enum Kind { NoteOn,NoteOff,Tempo,End } kind=End;
    uint32_t tick=0,offset=0,tempo=0;
    uint16_t instrument=0,note=0,velocity=0,channel=0;
};
class Midi {
    const uint8_t* data=0;uint32_t size=0,pos=0,tick=0;
    const Song* song=0;
    uint8_t running=0,program[16]={},volume[16]={};
    const char* variable(uint32_t& value) {
        value=0;
        for(uint16_t i=0;i<4;++i) {
            if(pos>=size)return "MIDI TRUNCATED VARIABLE";
            uint8_t byte=data[pos++];value=(value<<7)|(byte&127);
            if(!(byte&128))return 0;
        }
        return "MIDI VARIABLE OVERFLOW";
    }
public:
    uint16_t division=0;bool ended=false;
    const char* begin(const uint8_t* p,uint32_t bytes,const Song& config) {
        if(!p || bytes<22 || !config.data)return "MIDI HEADER";
        if(longword(p)!=0x4d546864 || longword(p+4)!=6 || word(p+8)!=0 || word(p+10)!=1
           || longword(p+14)!=0x4d54726b || longword(p+18)!=bytes-22)return "MIDI FORMAT";
        if(!word(p+12) || (word(p+12)&0x8000))return "MIDI DIVISION";
        data=p;size=bytes;pos=22;tick=0;song=&config;running=0;ended=false;division=word(p+12);
        for(uint16_t i=0;i<16;++i) {program[i]=(uint8_t)i;volume[i]=127;}
        return 0;
    }
    const char* next(Event& event) {
        if(!data || ended)return "MIDI END";
        while(pos<size) {
            uint32_t delta;const char* error=variable(delta);if(error)return error;
            if(delta>0xffffffffUL-tick)return "MIDI TICK OVERFLOW";
            tick+=delta;
            if(pos>=size)return "MIDI TRUNCATED EVENT";
            uint8_t status=data[pos];
            if(status&128)++pos;
            else {if(!running)return "MIDI RUNNING STATUS";status=running;}
            if(status==0xff) {
                if(pos>=size)return "MIDI TRUNCATED META";
                uint8_t type=data[pos++];uint32_t length;
                if((error=variable(length)))return error;
                if(length>size-pos)return "MIDI META SIZE";
                event={};event.tick=tick;
                if(type==0x2f) {
                    if(length || pos!=size)return "MIDI END SIZE";
                    ended=true;event.kind=Event::End;event.offset=pos;return 0;
                }
                if(type==0x51) {
                    if(length!=3)return "MIDI TEMPO SIZE";
                    event.tempo=uint32_t(data[pos])<<16|uint32_t(data[pos+1])<<8|data[pos+2];
                    if(!event.tempo)return "MIDI ZERO TEMPO";
                    pos+=3;event.kind=Event::Tempo;event.offset=pos;return 0;
                }
                pos+=length;continue;
            }
            if(status>=0xf0)return "MIDI SYSTEM EVENT";
            running=status;
            uint8_t type=status>>4,channel=status&15;
            uint16_t count=(type==12 || type==13)?1:2;
            if(count>size-pos)return "MIDI TRUNCATED CHANNEL";
            uint8_t first=data[pos++],second=count==2?data[pos++]:0;
            if((first|second)&128)return "MIDI CHANNEL DATA";
            // BTST #2,state+$11BA tests the high byte of the flags word.
            if(type==12) {if(song->flags&0x0400)program[channel]=first;continue;}
            if(type==11) {if(first==7)volume[channel]=second;continue;}
            if(type!=8 && type!=9)continue; // Original ignores pressure and bend.
            event={};event.tick=tick;event.offset=pos;event.channel=channel;
            event.instrument=song->instrument(program[channel]);event.note=song->note(first);
            event.velocity=type==9 ? uint16_t(volume[channel])*second/127 : second;
            event.kind=type==9 && event.velocity ? Event::NoteOn : Event::NoteOff;
            return 0;
        }
        return "MIDI MISSING END";
    }
};
}
#endif
