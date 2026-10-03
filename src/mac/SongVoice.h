#ifndef AITD_SONG_VOICE_H
#define AITD_SONG_VOICE_H
#include "SongInputs.h"
#include "PaulaSample.h"

// Measured note-to-sample contract for plain INST resources (flags zero).
// No original driver instructions or modifier callbacks execute here.
namespace SongVoice {
// Freestanding 68020 builds have no 64-bit division runtime. Return a bounded
// 32-bit quotient using shifts/subtractions; never silently truncate overflow.
inline bool divide(unsigned long long numerator,unsigned long long denominator,uint32_t& result) {
    if(!denominator)return false;
    unsigned long long remainder=0;result=0;
    for(int16_t bit=63;bit>=0;--bit) {
        bool carry=(remainder>>63)!=0;
        remainder=(remainder<<1)|(numerator>>63);numerator<<=1;
        if(carry || remainder>=denominator) {
            remainder-=denominator;
            if(bit>=32)return false;
            result|=1UL<<bit;
        }
    }
    return true;
}
inline const char* select(const SongInputs::Instrument& instrument,uint16_t note,
                           uint16_t& sample,int16_t& adjusted,bool& found) {
    found=false;
    if(!instrument.data || note>127)return "SONG NOTE RANGE";
    adjusted=int16_t(note);
    if(instrument.basePitch)adjusted=adjusted-instrument.basePitch+60;
    sample=instrument.baseSample;
    if(!instrument.ranges) {found=sample!=0;return 0;}
    // Original +$31AE: a zero lower bound and a 127 upper bound are open.
    // Plain instruments drop a note that matches no range; they do not wrap it.
    for(uint16_t i=0;i<instrument.ranges;++i) {
        const uint8_t* row=instrument.data+14+8*i;
        if((!row[0] || uint8_t(adjusted)>=row[0])
           && (row[1]>=127 || int8_t(adjusted)<=int8_t(row[1]))) {
            uint16_t alternate=SongInputs::word(row+2);
            if(alternate)sample=alternate;
            found=sample!=0;return 0;
        }
    }
    return 0;
}
inline const char* pitch(int16_t adjusted,uint8_t sampleNote,uint32_t& step) {
    int16_t index=adjusted+60-sampleNote;
    if(index<0 || index>=128)return "SONG PITCH RANGE";
    // Twelve measured fixed-point pitch ratios describe the original table;
    // lower octaves truncate by shifting. This preserves its quantization,
    // including slightly unequal semitones, without floating point.
    static const uint32_t octave[12]={
        0x400014,0x43ccca,0x47d64c,0x4c1c98,0x509fb0,0x555f92,
        0x5a7aa8,0x5fd286,0x32c2cc,0x35c9ed,0x38fea6,0x3c60f8
    };
    uint16_t degree=index%12,top=degree<8 ? degree+120 : degree+108;
    step=octave[degree]>>((top-index)/12);
    // Original +$3436 clears fractional residues below four units.
    if((step&0xffff)<4)step&=0xffff0000UL;
    return 0;
}
struct Plan {
    uint32_t step=0,loopStart=0,loopEnd=0;
    uint16_t period=0;
};
inline const char* describe(const SongInputs::Sample& sample,int16_t adjusted,
                            uint32_t paulaClock,Plan& plan) {
    if(!sample.pcm || sample.rate!=(11025UL<<16))return "SONG SAMPLE RATE";
    const char* error=pitch(adjusted,sample.baseNote,plan.step);if(error)return error;
    // The reached driver mixes 185 samples per callback, then interpolates
    // to 370 at fixed output rate $56EE8BA3. Match its actual pitch, not a
    // guessed 11025 Hz output clock. All arithmetic is integer.
    unsigned long long denominator=static_cast<unsigned long long>(plan.step)*0x56ee8ba3UL;
    if(!denominator || (paulaClock!=3546895 && paulaClock!=3579545))return "SONG PAULA CLOCK";
    uint32_t period=0;
    if(!divide((static_cast<unsigned long long>(paulaClock)<<33)+(denominator>>1),denominator,period))return "SONG PAULA PERIOD";
    if(!period || period>65535)return "SONG PAULA PERIOD";
    plan.period=uint16_t(period);plan.loopStart=plan.loopEnd=0;
    // Original +$34C8 requires a nonzero start and at least 100 bytes
    // (word-sized comparison) before enabling the sample loop.
    if(sample.loopStart && sample.loopEnd && sample.loopEnd!=0xffffffffUL
       && uint16_t(sample.loopEnd-sample.loopStart)>=100) {
        plan.loopStart=sample.loopStart;plan.loopEnd=sample.loopEnd;
    }
    return 0;
}
struct Dma {
    PaulaSample::Layout layout={};
    uint16_t stride=1,period=0;
};
inline const char* dma(const SongInputs::Sample& sample,const Plan& plan,
                       uint32_t paulaClock,Dma& out) {
    if(!sample.pcm || !sample.size || sample.size>131070 || !plan.step || (paulaClock!=3546895 && paulaClock!=3579545))
        return "SONG DMA SAMPLE";
    out={};
    unsigned long long denominator=static_cast<unsigned long long>(plan.step)*0x56ee8ba3UL;
    unsigned long long numerator=static_cast<unsigned long long>(paulaClock)<<33;
    uint32_t period=0;
    if(!divide(numerator+(denominator>>1),denominator,period))return "SONG DMA PERIOD";
    while(period<124 && out.stride<16) {
        out.stride<<=1;numerator<<=1;
        if(!divide(numerator+(denominator>>1),denominator,period))return "SONG DMA PERIOD";
    }
    if(period<124 || period>65535)return "SONG DMA PERIOD";
    out.period=uint16_t(period);
    auto& layout=out.layout;layout.pcm=sample.pcm;layout.size=sample.size;
    layout.loopStart=plan.loopStart;layout.loopEnd=plan.loopEnd;
    if(layout.loopEnd && (layout.loopEnd>layout.size || layout.loopStart>=layout.loopEnd))return "SONG DMA LOOP";
    uint32_t end=layout.loopEnd ? layout.loopEnd : layout.size;
    uint32_t attack=(end+out.stride-1)/out.stride;
    layout.attackBytes=(attack+1)&~1UL;layout.reloadOffset=layout.attackBytes;
    if(layout.loopEnd) {
        uint32_t loop=layout.loopEnd-layout.loopStart,divisor=out.stride;
        while(divisor>1 && loop%divisor)divisor>>=1;
        uint32_t cycle=loop/divisor;
        layout.reloadBytes=(cycle&1) ? cycle*2 : cycle;
    } else layout.reloadBytes=2;
    if(layout.attackBytes>131070 || layout.reloadBytes>131070)return "SONG DMA LENGTH";
    layout.allocated=layout.attackBytes+layout.reloadBytes;
    return 0;
}
inline uint8_t pcmAt(const Dma& dma,uint32_t position) {
    const auto& layout=dma.layout;
    if(layout.loopEnd && position>=layout.loopEnd)
        position=layout.loopStart+(position-layout.loopEnd)%(layout.loopEnd-layout.loopStart);
    return position<layout.size ? layout.pcm[position]^0x80 : 0;
}
inline void convertSpan(const Dma& dma,uint8_t* destination,uint32_t bytes,uint32_t& position) {
    const auto& layout=dma.layout;
    while(bytes) {
        if(layout.loopEnd && position>=layout.loopEnd)
            position=layout.loopStart+(position-layout.loopEnd)%(layout.loopEnd-layout.loopStart);
        if(position>=layout.size) {
            while(bytes--) *destination++=0;
            return;
        }
        // Copy an uninterrupted source span. Bounds and loop arithmetic belong
        // at its boundary, not in the per-byte unsigned-to-signed conversion.
        uint32_t end=layout.loopEnd ? layout.loopEnd : layout.size;
        uint32_t count=1+(end-1-position)/dma.stride;
        if(count>bytes)count=bytes;
        bytes-=count;
        // Ordinary PCM needs only a sign-bit flip. The 68020+ permits unaligned
        // longword transfers; use explicit instructions to avoid byte copies.
        if(dma.stride==1)while(count>=4) {
            uint32_t word;
#if defined(__m68k__)
            __asm__ volatile("move.l (%1),%0\n\t"
                             "eor.l #0x80808080,%0\n\t"
                             "move.l %0,(%2)"
                             : "=&d"(word)
                             : "a"(layout.pcm+position),"a"(destination)
                             : "cc","memory");
#else
            __builtin_memcpy(&word,layout.pcm+position,4);
            word^=0x80808080UL;
            __builtin_memcpy(destination,&word,4);
#endif
            position+=4;destination+=4;count-=4;
        }
        while(count--) {
            *destination++=layout.pcm[position]^0x80;
            position+=dma.stride;
        }
    }
}
inline void convert(const Dma& dma,uint8_t* destination) {
    const auto& layout=dma.layout;
    uint32_t position=0;
    convertSpan(dma,destination,layout.attackBytes,position);
    if(!layout.loopEnd) {
        destination[layout.reloadOffset]=destination[layout.reloadOffset+1]=0;return;
    }
    // Decimate the source stream, including its wrap. Odd loops retain their
    // complete phase cycle; pad/reload alignment never repeats or loses a byte.
    convertSpan(dma,destination+layout.reloadOffset,layout.reloadBytes,position);
}

}
#endif
