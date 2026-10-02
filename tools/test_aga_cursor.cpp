#include "../src/platform/amiga/AgaCursor.h"
#include "../src/platform/amiga/AgaPalette.h"
#include <cassert>
#include <cstdio>
#include <cstdint>

int main() {
    uint32_t colors[256],copper[AgaPalette::moves],physical[256]={};
    for(unsigned i=0;i<256;++i)colors[i]=(i*73%256)<<16|(i*131%256)<<8|(i*193%256);
    colors[0]=0xffffff;colors[255]=0;
    assert(AgaCursor::paletteSupported(colors));
    AgaPalette::build(copper,colors,AgaCursor::playfieldXor);
    unsigned bank=0;bool low=false;
    for(uint32_t move:copper) {
        unsigned reg=move>>16,value=move&65535;
        if(reg==0x106) {bank=value>>13;low=value&0x200;continue;}
        assert(reg>=0x180 && reg<=0x1be && !(reg&1));
        unsigned pen=bank*32+(reg-0x180)/2;
        physical[pen]|=((value>>8)&15)<<(low?16:20);
        physical[pen]|=((value>>4)&15)<<(low?8:12);
        physical[pen]|=(value&15)<<(low?0:4);
    }
    // Independent hardware address calculation, every game colour and both
    // pointer colours. The underlying logical bitplanes are never remapped.
    for(unsigned pen=0;pen<256;++pen)
        assert(physical[pen^(AgaCursor::displayControl>>8)]==colors[pen]);
    unsigned even=(AgaCursor::displayControl>>4)&15,odd=AgaCursor::displayControl&15;
    assert(physical[(even<<4)+((AgaCursor::whiteChannel&6)<<1)+1]==0xffffff);
    assert(physical[(odd<<4)+((AgaCursor::blackChannel&6)<<1)+2]==0);
    uint16_t image[16],mask[16];
    for(unsigned y=0;y<16;++y) {image[y]=uint16_t(0x8421u<<y);mask[y]=image[y]|uint16_t(0x1357u>>y);}
    assert(AgaCursor::shapeSupported(image,mask));
    for(unsigned y=0;y<16;++y) {
        uint16_t white[2],black[2];AgaCursor::row(image[y],mask[y],white,black);
        for(unsigned x=0;x<16;++x) {
            unsigned bit=0x8000>>x;
            unsigned w=bool(white[0]&bit)+2*bool(white[1]&bit);
            unsigned b=bool(black[0]&bit)+2*bool(black[1]&bit);
            assert(!(w&&b));
            assert(w==(!(image[y]&bit) && (mask[y]&bit) ? 1u : 0u));
            assert(b==((image[y]&mask[y]&bit) ? 2u : 0u));
        }
    }
    image[15]=1;mask[15]=0;assert(!AgaCursor::shapeSupported(image,mask));
    assert(!AgaCursor::shapeSupported(nullptr,mask));
    colors[0]=0xfffffe;assert(!AgaCursor::paletteSupported(colors));
    assert(!AgaCursor::paletteSupported(nullptr));
    puts("PASS pointer palette: all 256 game RGBs preserved, exact two-sprite black/white/transparent pixels, inverted shapes rejected");
}
