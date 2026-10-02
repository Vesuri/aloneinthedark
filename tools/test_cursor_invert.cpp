#include "../src/platform/amiga/CursorInvert.h"
#include <array>
#include <cassert>
#include <cstdio>

int main() {
    for(int x=-20;x<325;++x)for(int left=0;left<320;left+=8)
        for(uint16_t mask:{uint16_t(0),uint16_t(1),uint16_t(0x8000),uint16_t(0xffff),uint16_t(0xa55a)}) {
            const int right=left+8;
            std::array<uint8_t,42> actual,expected,original;
            for(unsigned i=0;i<actual.size();++i)actual[i]=uint8_t(i*71);
            expected=original=actual;
            for(int bit=0;bit<16;++bit) {
                int px=x+bit;
                if((mask&(0x8000>>bit)) && px>=left && px<right)
                    expected[1+px/8]^=0x80>>(px&7);
            }
            CursorInvert::row(actual.data()+1,left,right,x,mask);
            assert(actual==expected);
            CursorInvert::row(actual.data()+1,left,right,x,mask);
            assert(actual==original);
        }
    // A copied span must lose the visible front buffer's XOR before becoming
    // the next frame. Untouched bytes, including the two canaries, stay exact.
    std::array<uint8_t,40> clean{},front{},back{};
    for(unsigned i=0;i<40;++i)clean[i]=uint8_t(i*37);
    front=back=clean;
    CursorInvert::row(front.data(),0,320,13,0xa55a);
    for(unsigned i=1;i<4;++i)back[i]=front[i];
    CursorInvert::row(back.data(),8,32,13,0xa55a);
    assert(back==clean);
    for(int x=-20;x<325;++x)for(uint16_t mask:{uint16_t(0xffff),uint16_t(0xa55a)}) {
        std::array<uint8_t,322> actual{},expected{};
        for(unsigned i=0;i<actual.size();++i)actual[i]=uint8_t(i*37);
        expected=actual;
        for(unsigned plane=0;plane<8;++plane)for(int bit=0;bit<16;++bit) {
            int px=x+bit;
            if(px>=0 && px<320 && (mask&(0x8000>>bit)))
                expected[1+plane*40+px/8]^=0x80>>(px&7);
        }
        CursorInvert::planes(actual.data()+1,x,mask);assert(actual==expected);
    }
    puts("PASS cursor XOR: clipped spans, all bit alignments, reversibility and clean frame synchronization");
}
