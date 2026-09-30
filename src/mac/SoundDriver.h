#ifndef AITD_SOUND_DRIVER_H
#define AITD_SOUND_DRIVER_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Native D8 interface state. MacLoader owns the Paula DMA buffers and must
// quiesce assigned channels before asking this model to stop logical voices.
class SoundDriver {
public:
    struct Voice { uint32_t sample; int16_t channel; uint16_t active; };
    uint16_t initialized=0,songLimit=0,normalizedLimit=0,effectLimit=0;
    uint16_t requestedRate=0,interpolation=0;
    uint32_t clockOrigin=0; // Native 60 Hz epoch for the original callback counter.
    uint16_t songControl=0; // Original state+$38, written by selector 13.
    Voice songs[6]={},effects[2]={};
    uint16_t effectIds[2]={};
    int16_t channels[4]={-1,-1,-1,-1};

    void reset() {
        initialized=0;songLimit=0;normalizedLimit=0;effectLimit=0;
        requestedRate=0;interpolation=0;songControl=0;clockOrigin=0;
        for(auto& voice:songs) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& voice:effects) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& id:effectIds)id=0;
        for(auto& channel:channels)channel=-1;
    }
    const char* initialize(uint16_t song,uint16_t normalized,uint16_t effect,uint32_t tick=0) {
        if(initialized)return "REINITIALIZE"; // not measured yet
        if(song!=6 || normalized!=2 || effect!=2)return "VOICE CONFIG";
        for(auto& voice:songs) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& voice:effects) { voice.sample=0;voice.channel=-1;voice.active=0; }
        for(auto& id:effectIds)id=0;
        for(auto& channel:channels)channel=-1;
        songLimit=song;normalizedLimit=normalized;effectLimit=effect;
        requestedRate=22;interpolation=0;songControl=0;clockOrigin=tick;initialized=1;
        return 0;
    }
    const char* stopEffects() {
        if(!initialized)return "NOT INITIALIZED";
        // The measured driver marks effect voices inactive without discarding
        // their sample state or altering song voices. Reject a caller that bypasses
        // the hardware owner: assigned channels must already be quiesced.
        for(const auto& voice:effects)if(voice.channel!=-1)return "EFFECT DMA STOP";
        for(auto& voice:effects)voice.active=0;
        return 0;
    }
    const char* effectStatus(uint16_t identifier,uint16_t& status) const {
        if(!initialized)return "NOT INITIALIZED";
        status=1;
        // Original +$36FA stops at the first matching ID, even if that slot
        // is inactive and a later slot has the same ID and remains active.
        for(uint16_t i=0;i<effectLimit;++i)if(effectIds[i]==identifier) {
            status=effects[i].active ? 0 : 1;
            break;
        }
        return 0;
    }
    static uint16_t clockCCR(uint32_t result) {
        // Original LSL.W of selector 15 clears X; MOVE.L supplies N/Z, clears V/C.
        return !result ? 4 : (result&0x80000000UL) ? 8 : 0;
    }
    const char* clock(uint32_t tick,uint32_t& result) const {
        if(!initialized)return "NOT INITIALIZED";
        result=tick-clockOrigin; // Unsigned 32-bit wrap, independent of song/effects.
        return 0;
    }
    const char* setSongControl(uint32_t value) {
        if(!initialized)return "NOT INITIALIZED";
        songControl=(uint16_t)value;
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
