#include <cstdint>
#include "../src/mac/LowMemory.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <vector>
using namespace MacLowMemory;
int main(int argc, char** argv) {
    if (argc == 2 && !std::strcmp(argv[1], "--sites")) {
        for (const Site& s : sites)
            std::printf("%u %u %u %u %u\n",s.segment,s.offset,s.length,base+s.shadow,s.destination);
        return 0;
    }
    if (argc == 3 && !std::strcmp(argv[1], "--patch")) {
        uint16_t segment = std::atoi(argv[2]);
        std::vector<uint8_t> code;
        int c;
        while ((c = std::getchar()) != EOF) code.push_back(c);
        if (!patch(segment, code.data(), code.size())) return 1;
        return std::fwrite(code.data(),1,code.size(),stdout) == code.size() ? 0 : 1;
    }
    unsigned rejected = 0;
    for (const Segment& segment : segments) {
        std::vector<uint8_t> original(segment.bytes,0), code, corrupt;
        for (const Site& s : sites) if (s.segment == segment.id)
            std::memcpy(original.data()+s.offset,s.original,s.length);
        for (const Site& s : sites) if (s.segment == segment.id)
            for (unsigned j=0; j<s.length; ++j) {
                code=original; code[s.offset+j]^=1; corrupt=code;
                if (apply(segment.id,code.data(),code.size()) || code!=corrupt) return 1;
                ++rejected;
            }
        code=original;
        if (apply(segment.id,code.data(),code.size()-1)
            || !apply(segment.id,code.data(),code.size())) return 1;
        if (siteCount(segment.id) && apply(segment.id,code.data(),code.size())) return 1;
    }
    if (apply(99,nullptr,0) || validate(99,nullptr,0)) return 1;
    for (const Shadow& s : shadows) {
        if (s.offset+s.width > size || base+s.offset+s.width > 32768) return 1;
        // Overlap is allowed only for the low word of Ticks ($16C).
        for (const Shadow& t : shadows)
            if (s.address!=t.address && s.offset<t.offset+t.width && t.offset<s.offset+s.width
                && !(s.address==0x16a && t.address==0x16c)
                && !(s.address==0x16c && t.address==0x16a)) return 1;
    }
    std::printf("PASS lowmem-host: sites=%u rejected-bytes=%u atomic=1 size=1 repeat=1 shadows=29\n",count,rejected);
}
