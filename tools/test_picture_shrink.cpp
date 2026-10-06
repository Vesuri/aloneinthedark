#include "../src/mac/PictureShrink8.h"
#include "../src/mac/GWorld8.h"
#include <cstdio>
#include <vector>
int main() {
    uint8_t args[10];if(std::fread(args,1,10,stdin)!=10)return 1;
    const uint16_t stride=RectBounds::word(args),sw=RectBounds::word(args+2),sh=RectBounds::word(args+4);
    const uint16_t w=RectBounds::word(args+6),h=RectBounds::word(args+8);
    if(stride>1024 || sh>480 || w>640 || h>480)return 2;
    std::vector<uint8_t> input(uint32_t(stride)*sh+2056*2+4620);
    if(std::fread(input.data(),1,input.size(),stdin)!=input.size())return 3;
    const uint8_t* colors=input.data()+uint32_t(stride)*sh;
    std::vector<uint8_t> inverse(4620);std::vector<uint16_t> grid(5832),queue(5832);
    if(!GWorld8::inverse(colors+2056,4,inverse.data(),grid.data(),queue.data()))return 6;
    for(unsigned i=6;i<4102;++i)if(inverse[i]!=colors[4112+i])return 7;
    std::vector<uint8_t> out(uint32_t(w)*h),workspace(PictureShrink8::workspaceBytes(sw,w));
    if(!PictureShrink8::draw(input.data(),stride,sw,sh,colors,colors+2056,colors+4112,
                            out.data(),w,h,workspace.data()))return 4;
    return std::fwrite(out.data(),1,out.size(),stdout)==out.size() ? 0 : 5;
}
