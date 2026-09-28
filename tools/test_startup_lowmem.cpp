#include <cstdint>
#include "../src/mac/StartupLowMemory.h"
#include <cstdio>
#include <cstring>
using namespace StartupLowMemory;
int main(int argc, char** argv) {
    if (argc == 2 && !std::strcmp(argv[1], "--sites")) {
        for (const Site& s : sites) std::printf("%u %u %u\n", s.offset, s.length, base+s.shadow);
        return 0;
    }
    if (argc == 2 && !std::strcmp(argv[1], "--patch")) {
        uint8_t code[1234];
        if (std::fread(code, 1, sizeof(code), stdin) != sizeof(code)
            || std::fgetc(stdin) != EOF || !patch(code, sizeof(code))) return 1;
        return std::fwrite(code, 1, sizeof(code), stdout) == sizeof(code) ? 0 : 1;
    }
    uint8_t original[1234] = {}, code[1234], corrupt[1234];
    for (const Site& s : sites) std::memcpy(original+s.offset, s.original, s.length);
    unsigned rejected = 0;
    for (const Site& s : sites) for (unsigned j=0; j<s.length; ++j) {
        std::memcpy(code, original, sizeof(code));
        code[s.offset+j] ^= 1;
        std::memcpy(corrupt, code, sizeof(code));
        if (patch(code, sizeof(code)) || std::memcmp(code, corrupt, sizeof(code))) return 1;
        ++rejected;
    }
    std::memcpy(code, original, sizeof(code));
    if (patch(code, sizeof(code)-1) || !patch(code, sizeof(code)) || patch(code, sizeof(code))) return 1;
    std::printf("PASS startup-lowmem-host: sites=%u rejected-bytes=%u atomic=1 size=1 repeat=1\n",count,rejected);
}
