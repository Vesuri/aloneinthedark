#include "../src/platform/amiga/AgaPalette.h"
#include <array>
#include <cassert>
#include <cstdio>
int main() {
    std::array<uint32_t,256> rgb{},decoded{};
    std::array<uint32_t,AgaPalette::moves+2> list{};
    for(unsigned i=0;i<256;++i)rgb[i]=((i^0x39)<<16)|((255-i)<<8)|((i*71)&255);
    list.front()=list.back()=0xdeadbeef;
    AgaPalette::build(list.data()+1,rgb.data());
    unsigned bank=0;bool low=false;
    std::array<unsigned,256> highCount{},lowCount{};
    for(unsigned i=1;i<=AgaPalette::moves;++i) {
        unsigned reg=list[i]>>16, value=list[i]&65535;
        if(reg==0x106) {
            assert((value&0x1dff)==AgaPalette::control);
            bank=value>>13;low=(value&0x200)!=0;
        } else {
            assert(reg>=0x180 && reg<=0x1be && !(reg&1) && value<4096);
            unsigned index=bank*32+(reg-0x180)/2;
            unsigned channels=((value>>8)<<16)|(((value>>4)&15)<<8)|(value&15);
            if(low) {decoded[index]=(decoded[index]&0xf0f0f0)|channels;lowCount[index]++;}
            else {decoded[index]=(decoded[index]&0x0f0f0f)|(channels<<4);highCount[index]++;}
        }
    }
    assert(decoded==rgb && bank==0 && !low);
    for(unsigned i=0;i<256;++i)assert(highCount[i]==1 && lowCount[i]==1);
    assert(list.front()==0xdeadbeef && list.back()==0xdeadbeef);
    puts("PASS AGA palette: all 256 RGB24 values reconstructed, every high/low bank write, restored bank/LOCT and output bounds");
}
