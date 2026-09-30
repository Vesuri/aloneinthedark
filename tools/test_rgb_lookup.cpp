#include "../src/mac/GWorld8.h"
#include <cassert>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
int main(int argc,char** argv) {
    assert(argc==3);std::ifstream c(argv[1],std::ios::binary),i(argv[2],std::ios::binary);
    std::vector<uint8_t> colors((std::istreambuf_iterator<char>(c)),{}),inverse((std::istreambuf_iterator<char>(i)),{});
    assert(colors.size()==2056 && inverse.size()==4620);
    unsigned r,g,b,index,count=0;
    while(std::cin>>std::hex>>r>>g>>b>>index) {
        uint8_t rgb[6];GWorld8::word(rgb,r);GWorld8::word(rgb+2,g);GWorld8::word(rgb+4,b);
        uint16_t result=0xaaaa;assert(GWorld8::colorIndex(colors.data(),inverse.data(),rgb,result));assert(result==index);
        ++count;
    }
    assert(count==66);
    uint8_t rgb[6]={};uint16_t result=0xaaaa;
    assert(!GWorld8::colorIndex(nullptr,inverse.data(),rgb,result) && result==0xaaaa);
    inverse[0]^=1;assert(!GWorld8::colorIndex(colors.data(),inverse.data(),rgb,result) && result==0xaaaa);inverse[0]^=1;
    inverse[5]=3;assert(!GWorld8::colorIndex(colors.data(),inverse.data(),rgb,result));inverse[5]=4;
    colors[5]=1;assert(!GWorld8::colorIndex(colors.data(),inverse.data(),rgb,result));colors[5]=0;
    inverse[6]=1;inverse[4108+1]=2;inverse[4108+2]=2;
    assert(!GWorld8::colorIndex(colors.data(),inverse.data(),rgb,result) && result==0xaaaa);
    std::cout<<"PASS RGB inverse-ring lookup: 66 Mac results; null, seed, resolution, flags and malformed-cycle rejection\n";
}
