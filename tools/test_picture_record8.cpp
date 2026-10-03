#include "../src/mac/PictureRecord8.h"
#include <vector>
#include <fstream>
#include <iterator>
#include <cassert>
#include <string>
static std::vector<uint8_t> read(const std::string& name) {
    std::ifstream f(name,std::ios::binary);assert(f);
    return {std::istreambuf_iterator<char>(f),{}};
}
int main(int argc,char** argv) {
    assert(argc==3);
    const std::string prefix=std::string(argv[1])+"/pictrecord-reference-";
    auto pm=read(prefix+"enter-src-pm.bin"),ct=read(prefix+"enter-src-clut.bin");
    auto pixels=read(prefix+"enter-src-pixels.bin"),from=read(prefix+"enter-from.bin");
    auto to=read(prefix+"enter-to.bin"),frame=read(prefix+"frame.bin");
    const uint16_t width=RectBounds::word(from.data()+6)-RectBounds::word(from.data()+2);
    const uint16_t height=RectBounds::word(from.data()+4)-RectBounds::word(from.data());
    std::vector<uint8_t> out(PictureRecord8::capacity(width,height));
    auto size=PictureRecord8::record(out.data(),out.size(),frame.data(),pm.data(),ct.data(),
        pixels.data(),pixels.size(),from.data(),to.data(),64);
    assert(size && size<=out.size());
    assert(!PictureRecord8::record(out.data(),1,frame.data(),pm.data(),ct.data(),
        pixels.data(),pixels.size(),from.data(),to.data(),64));
    assert(!PictureRecord8::record(out.data(),out.size(),frame.data(),pm.data(),ct.data(),
        pixels.data(),pixels.size(),from.data(),to.data(),1));
    std::ofstream f(argv[2],std::ios::binary);assert(f);
    f.write(reinterpret_cast<const char*>(out.data()),size);
}
