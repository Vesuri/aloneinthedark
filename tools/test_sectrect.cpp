#include "../src/mac/RectBounds.h"
#include <cassert>
#include <cstring>
#include <iostream>
#include <string>
static void decode(const std::string& s,uint8_t* p) {
    assert(s.size()==16);
    for(unsigned i=0;i<8;++i)p[i]=uint8_t(std::stoul(s.substr(i*2,2),nullptr,16));
}
int main() {
    std::string a,b,expected;unsigned alias,nonempty,count=0;
    while(std::cin>>a>>b>>expected>>alias>>nonempty) {
        uint8_t storage[48];std::memset(storage,0xa5,sizeof(storage));
        decode(a,storage+4);decode(b,storage+20);
        uint8_t want[48];std::memcpy(want,storage,sizeof(want));
        unsigned out=alias==1?4:alias==2?20:36;decode(expected,want+out);
        bool actual=false;
        assert(RectBounds::intersect(storage+out,storage+4,storage+20,actual));
        assert(actual==bool(nonempty));
        assert(std::memcmp(storage,want,sizeof(storage))==0);
        assert(!RectBounds::intersect(nullptr,storage+4,storage+20,actual));
        assert(!RectBounds::intersect(storage+out,nullptr,storage+20,actual));
        assert(!RectBounds::intersect(storage+out,storage+4,nullptr,actual));
        assert(std::memcmp(storage,want,sizeof(storage))==0);++count;
    }
    assert(count==16);std::cout<<"PASS rectangle bounds: 16 intersection pairs, aliasing, surrounding bytes and null rejection\n";
}
