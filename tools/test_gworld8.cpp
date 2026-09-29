#include <cassert>
#include <cstring>
#include <vector>
#include <fstream>
#include "../src/mac/GWorld8.h"
int main(int argc,char** argv) {
    GWorld8::Layout l{};
    assert(GWorld8::layout({0,0,401,648},l)&&l.rowBytes==652&&l.pixelBytes==261452);
    for(int width=1;width<=16376;++width) {
        assert(GWorld8::layout({-10,-100,17,int16_t(width-100)},l));
        assert(l.rowBytes==4*((width+3)/4)+4&&l.pixelBytes==unsigned(l.rowBytes)*27);
    }
    assert(!GWorld8::layout({0,0,1,16377},l));
    assert(!GWorld8::layout({0,0,0,5},l));assert(!GWorld8::layout({2,3,1,9},l));
    assert(!GWorld8::layout({0,5,10,5},l));
    assert(GWorld8::layout({-32768,0,32767,1},l)&&l.pixelBytes==8U*65535);
    uint8_t guarded[54];memset(guarded,0xa5,sizeof guarded);
    assert(GWorld8::layout({0,0,401,648},l));
    GWorld8::pixmap(guarded+2,0x12345678,0x23456789,{0,0,401,648},l);
    const uint8_t expected[50]={0x12,0x34,0x56,0x78,0x82,0x8c,0,0,0,0,1,0x91,2,0x88,0,2,0,0,0,0,0,0,0,0x48,0,0,0,0x48,0,0,0,0,0,8,0,1,0,8,0,0,0,0,0x23,0x45,0x67,0x89,0,0,0,0};
    assert(!memcmp(guarded+2,expected,50));
    assert(guarded[0]==0xa5&&guarded[1]==0xa5&&guarded[52]==0xa5&&guarded[53]==0xa5);
    std::vector<uint16_t> grid(34*34*34),queue(32*32*32);
    uint8_t colors[2056]={};GWorld8::word(colors+6,255);
    for(unsigned i=0;i<256;++i) {GWorld8::word(colors+8+i*8,i);GWorld8::word(colors+10+i*8,0xffff);}
    std::vector<uint8_t> inverse(32768+524);
    for(unsigned resolution: {4U,5U}) {
        assert(GWorld8::inverse(colors,resolution,inverse.data(),grid.data(),queue.data()));
        unsigned cube=1U<<(3*resolution);
        for(unsigned i=0;i<cube;++i)assert(inverse[6+i]==0);
        assert(GWorld8::readword(inverse.data()+6+cube)==255);
    }
    if(argc==3) {
        std::ifstream source(argv[1],std::ios::binary);source.read((char*)colors,sizeof colors);assert(source.gcount()==sizeof colors);
        assert(GWorld8::inverse(colors,4,inverse.data(),grid.data(),queue.data()));
        std::ofstream result(argv[2],std::ios::binary);result.write((char*)inverse.data(),4620);
    }

}
