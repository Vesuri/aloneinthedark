#include "../src/mac/FillRect8.h"
#include <cstdio>
#include <vector>
int main() {
    // Binary fixture: map bounds, port bounds, vis bounds, clip bounds, rect,
    // then the complete 640x480 screen. Output is the complete resulting screen.
    uint8_t bounds[40],drawn[8];
    std::vector<uint8_t> pixels(640*480);
    if(fread(bounds,1,40,stdin)!=40 || fread(pixels.data(),1,pixels.size(),stdin)!=pixels.size())return 1;
    if(!FillRect8::solid(pixels.data(),pixels.size(),640,bounds,bounds+8,bounds+16,bounds+24,bounds+32,255,drawn))return 2;
    return fwrite(pixels.data(),1,pixels.size(),stdout)==pixels.size()?0:3;
}
