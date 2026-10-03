#ifndef AITD_SONG_TIMELINE_H
#define AITD_SONG_TIMELINE_H
#include "SongInputs.h"

// Original +$1686/$18C4/$1A40: 1/64 MIDI-tick countdowns, with tempo
// quantized by the SONG clock divisor. Native playback advances from VBI;
// resource ownership and prepared sample lifetime are managed in user mode.
class SongTimeline {
    SongInputs::Midi midi;
    SongInputs::Event pending;
    uint32_t phase=0,lastTick=0;
    uint16_t divisor=0;
    const char* tempo(uint32_t microseconds) {
        uint32_t quotient=microseconds/divisor;
        if(!quotient || quotient>65535)return "SONG TEMPO DIVISOR";
        uint32_t value=(uint32_t(midi.division)<<6)/quotient;
        if(!value || value>65535)return "SONG TEMPO STEP";
        step=value;return 0;
    }
public:
    uint32_t pulses=0,step=0;
    bool active=false;
    const char* start(const uint8_t* bytes,uint32_t size,const SongInputs::Song& song) {
        active=false;const char* error=midi.begin(bytes,size,song);if(error)return error;
        divisor=SongInputs::word(song.data+4);if(!divisor)divisor=0x411b;
        if((error=tempo(500000)))return error;
        if((error=midi.next(pending)))return error;
        phase=lastTick=pulses=0;active=true;return 0;
    }
    const char* advance() {
        if(!active)return "SONG CLOCK INACTIVE";
        // The first callback reads the first delta without subtracting a step.
        if(pulses) {
            if(step>0xffffffffUL-phase)return "SONG CLOCK RANGE";
            phase+=step;
        }
        ++pulses;return 0;
    }
    const char* next(SongInputs::Event& event,bool& ready) {
        ready=false;
        if(!active || !pulses)return 0;
        if(pending.tick>0x03ffffffUL)return "SONG CLOCK RANGE";
        // A nonzero countdown fires only on subtraction borrow. Coincident
        // zero-delta events are processed in the same callback.
        if(pending.tick!=lastTick && (pending.tick<<6)>=phase)return 0;
        event=pending;lastTick=event.tick;ready=true;
        if(event.kind==SongInputs::Event::End) {active=false;return 0;}
        const char* error=0;
        if(event.kind==SongInputs::Event::Tempo && (error=tempo(event.tempo)))return error;
        return midi.next(pending);
    }
};
#endif
