#include "../src/mac/Line8.h"
#include <cstdio>
#include <vector>
int main() {
    uint8_t b[40];std::vector<uint8_t> pixels(652*401);
    if(fread(b,1,sizeof b,stdin)!=sizeof b || fread(pixels.data(),1,pixels.size(),stdin)!=pixels.size())return 1;
    if(!Line8::solid(pixels.data(),pixels.size(),652,b,b+8,b+16,b+24,
        int16_t(RectBounds::word(b+32)),int16_t(RectBounds::word(b+34)),
        int16_t(RectBounds::word(b+36)),int16_t(RectBounds::word(b+38)),26))return 2;
    return fwrite(pixels.data(),1,pixels.size(),stdout)==pixels.size()?0:3;
}
