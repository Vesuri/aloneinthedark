#include "../src/mac/Text8.h"
#include <cassert>
#include <fstream>
#include <iterator>
#include <vector>
#include <cstdio>
static std::vector<uint8_t> read(const char* path) {
    std::ifstream in(path,std::ios::binary);assert(in.good());return {std::istreambuf_iterator<char>(in),{}};
}
int main(int argc,char** argv) {
    assert(argc==1 || argc==3);
    const uint8_t map[]={0,0,0,0,1,145,2,136}; // 648 x 401, padded stride 652
    const uint8_t clipped[]={0,188,0,40,0,192,0,80};
    const uint8_t text[]="\xa9" "1992 I\xa5Motion/Infogrames, 1994 Interplay";
    std::vector<uint8_t> pixels(652*401,83),untouched=pixels;
    int16_t pen=37;uint16_t fraction=0x8000;
    auto draw=[&](const uint8_t* value,int16_t first,int16_t count,const uint8_t* clip) {
        return Text8::draw(pixels.data(),pixels.size(),652,map,map,map,clip,value,first,count,196,pen,fraction,26);
    };
    assert(draw(text,0,41,map) && pen==285 && fraction==0x1c00);
    unsigned ink=0;
    for(unsigned y=0;y<401;++y)for(unsigned x=0;x<652;++x) {
        if(pixels[y*652+x]!=83) {assert(pixels[y*652+x]==26 && x>=37 && x<285 && y>=184 && y<199);++ink;}
    }
    assert(ink>300);
    assert(draw(text,0,41,map) && pen==532 && fraction==0xb800);
    pixels=untouched;pen=37;fraction=0x8000;
    assert(draw(text,0,41,clipped) && pen==285 && fraction==0x1c00);
    ink=0;
    for(unsigned y=0;y<401;++y)for(unsigned x=0;x<652;++x)
        if(pixels[y*652+x]!=83) {assert(x>=40 && x<80 && y>=188 && y<192);++ink;}
    assert(ink);
    auto saved=pixels;
    assert(draw(nullptr,0,0,map) && pixels==saved && pen==285 && fraction==0x1c00);
    assert(!draw(text,-1,1,map) && pixels==saved);
    assert(!draw(text,0,-1,map) && pixels==saved);
    const uint8_t missing[]={'A',0xff};assert(!draw(missing,0,2,map) && pixels==saved);
    pen=32760;assert(!draw(text,0,41,map) && pixels==saved && pen==32760);
    pen=37;fraction=0x8000;pixels=untouched;
    assert(draw(text,1,4,map));auto offset=pixels;int16_t end=pen;uint16_t frac=fraction;
    pen=37;fraction=0x8000;pixels=untouched;
    assert(draw(text+1,0,4,map) && pixels==offset && pen==end && fraction==frac);
    assert(!Text8::draw(pixels.data(),10,652,map,map,map,map,text,0,41,196,pen,fraction,26));
    const uint8_t dotText[]={'I',0xfa,'M','o','t','i','o','n'};
    pixels=untouched;pen=129;fraction=0x8000;
    assert(Text8::draw(pixels.data(),pixels.size(),652,map,map,map,map,
                      dotText,0,8,98,pen,fraction,26));
    assert(pen==179 && fraction==0xb900);
    for(unsigned y=0;y<401;++y)for(unsigned x=0;x<652;++x)
        if(pixels[y*652+x]!=83)assert(x>=129 && x<179 && y>=85 && y<98);
    assert(Text8::draw(pixels.data(),pixels.size(),652,map,map,map,map,
                      dotText,0,8,98,pen,fraction,26));
    assert(pen==229 && fraction==0xf200);
    const uint8_t accentText[]={'Y','a',0x89,'l'};
    pixels=untouched;pen=99;fraction=0x8000;
    assert(Text8::draw(pixels.data(),pixels.size(),652,map,map,map,map,
                      accentText,0,4,114,pen,fraction,26));
    assert(pen==125 && fraction==0x3200);
    assert(Text8::draw(pixels.data(),pixels.size(),652,map,map,map,map,
                      accentText,0,4,114,pen,fraction,26));
    assert(pen==150 && fraction==0xe400);
    // Original Dark+$3A14 uses a 16-row redraw band [180,196) for the
    // car caption at baseline 191. Owned ink must disappear with that band.
    const uint8_t carText[]="\xa9" "1992 I\xfaMotion/Infogrames, 1994 Interplay";
    pixels=untouched;pen=37;fraction=0x8000;
    assert(Text8::draw(pixels.data(),pixels.size(),652,map,map,map,map,
                      carText,0,41,191,pen,fraction,26));
    assert(pen==285 && fraction==0x1c00 && pixels!=untouched);
    for(unsigned y=180;y<196;++y)
        for(unsigned x=0;x<320;++x)pixels[y*652+x]=83;
    assert(pixels==untouched);
    if(argc==3) {
        auto actual=read(argv[1]);auto expected=read(argv[2]);
        const uint8_t referenceMap[]={0,0,0,0,1,145,2,136};
        pen=37;fraction=0x8000;
        assert(Text8::draw(actual.data(),actual.size(),652,referenceMap,referenceMap,
                          referenceMap,referenceMap,text,0,41,196,pen,fraction,26));
        assert(actual==expected);
        puts("PASS Times14: original Macintosh caption matches every pixel, including padding");
    }
    puts("PASS Text8: measured fractional endpoints, repeat, empty, clipping, padding, range and atomic rejection");
}
