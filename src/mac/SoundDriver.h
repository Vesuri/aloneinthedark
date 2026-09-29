#ifndef AITD_SOUND_DRIVER_H
#define AITD_SOUND_DRIVER_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Native D8 interface state. Playback/selectors beyond measured startup stop.
// Logical voices do not allocate Mac software-mixer buffers or Paula DMA yet.
class SoundDriver {
public:
    struct Voice { uint32_t sample; int16_t channel; uint16_t active; };
    uint16_t initialized=0,songLimit=0,normalizedLimit=0,effectLimit=0;
    uint16_t requestedRate=0,interpolation=0;
    Voice songs[6]={},effects[2]={};
    int16_t channels[4]={-1,-1,-1,-1};

    void reset() {
        initialized=0;songLimit=0;normalizedLimit=0;effectLimit=0;
        requestedRate=0;interpolation=0;
        for(auto& voice:songs) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& voice:effects) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& channel:channels)channel=-1;
    }
    const char* initialize(uint16_t song,uint16_t normalized,uint16_t effect) {
        if(initialized)return "REINITIALIZE"; // not measured yet
        if(song!=6 || normalized!=2 || effect!=2)return "VOICE CONFIG";
        for(auto& voice:songs) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& voice:effects) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& channel:channels)channel=-1;
        songLimit=song;normalizedLimit=normalized;effectLimit=effect;
        requestedRate=22;interpolation=0;initialized=1;
        return 0;
    }
    const char* quality(uint32_t value) {
        if(!initialized)return "NOT INITIALIZED";
        if(value!=0x10b)return "QUALITY CONFIG";
        requestedRate=11;interpolation=1;
        return 0;
    }
};
#endif
