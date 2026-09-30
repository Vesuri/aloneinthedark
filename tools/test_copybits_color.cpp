#include "../src/mac/GWorld8.h"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iterator>
#include <vector>
static std::vector<uint8_t> read(const char* path) {
    std::ifstream in(path,std::ios::binary);assert(in.good());return {std::istreambuf_iterator<char>(in),{}};
}
int main(int argc,char** argv) {
    assert(argc==4);auto source=read(argv[1]),destination=read(argv[2]),original=read(argv[3]);
    assert(source.size()==2056 && destination.size()==2056 && original.size()==4620);
    uint8_t inverse[4620]={};uint16_t workspace[5832+4096]={};
    assert(GWorld8::inverse(destination.data(),4,inverse,workspace,workspace+5832));
    assert(!memcmp(inverse,original.data(),4364)); // Defined header/cube/collision record.
    for(unsigned i=0;i<256;++i) {
        uint16_t index;assert(GWorld8::colorIndex(destination.data(),inverse,source.data()+10+i*8,index));
        printf("%u\n",index);
    }
}
