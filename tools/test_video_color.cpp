#include "../src/platform/amiga/VideoColor.h"
#include <cassert>
#include <cstdio>
int main() {
    for(unsigned i=0;i<65536;++i) {
        unsigned r=i,g=65535-i,b=(i*71)&65535;
        uint32_t rgb=VideoColor::rgb(r,g,b);
        assert((rgb>>16)==VideoColor::component(r));
        assert(((rgb>>8)&255)==VideoColor::component(g));
        assert((rgb&255)==VideoColor::component(b));
        assert(std::putchar(VideoColor::component(i))!=EOF);
    }
}
