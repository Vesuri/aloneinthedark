#include "../src/mac/BitmapFont.h"
#include <cassert>
#include <fstream>
#include <iterator>
#include <vector>
#include <cstdio>
static std::vector<uint8_t> read(const char* path) {
    std::ifstream in(path,std::ios::binary);assert(in.good());return {std::istreambuf_iterator<char>(in),{}};
}
int main(int argc,char** argv) {
    assert(argc==3);auto fond=read(argv[1]),nfnt=read(argv[2]);BitmapFont::Family family={};
    assert(BitmapFont::family(fond.data(),fond.size(),20,family));
    assert(family.first==32 && family.last==250 && family.size==14 && family.bitmap==128);
    BitmapFont font;assert(font.open(nfnt.data(),nfnt.size(),family));assert(font.height()==14 && font.advance()==6);
    // Independent inherited A bitmap, scaled from seven rows to twelve.
    const uint8_t a[7]={14,17,17,31,17,17,17};
    for(unsigned y=0;y<14;++y)for(unsigned x=0;x<6;++x) {
        bool expected=y<12 && x<5 && (a[y*7/12]&(16>>x));
        assert(font.pixel('A',x,y)==expected && font.pixel('a',x,y)==expected);
        assert(!font.pixel(' ',x,y));
        assert(font.pixel(0xfa,x,y)==bool(y<2 && x==2));
    }
    assert(font.pixel(0,0,0) && font.pixel(255,4,11));assert(!font.pixel(255,5,11));assert(!font.pixel('A',0,14));
    const uint8_t copyright[7]={14,17,23,21,23,17,14},bullet[7]={0,0,4,14,4,0,0};
    for(unsigned y=0;y<14;++y)for(unsigned x=0;x<5;++x) {
        assert(font.pixel(0xa9,x,y)==bool(y<12 && (copyright[y*7/12]&(16>>x))));
        assert(font.pixel(0xa5,x,y)==bool(y<12 && (bullet[y*7/12]&(16>>x))));
    }
    const uint8_t name[]={'T','i','m','e','s'};
    for(const char* s:{"\005Times","\005times","\005TIMES","\005tImEs"})assert(BitmapFont::nameEquals(reinterpret_cast<const uint8_t*>(s),name,5));
    for(const char* s:{"\000","\006Times ","\006 Times","\004Time","\005Other"})assert(!BitmapFont::nameEquals(reinterpret_cast<const uint8_t*>(s),name,5));
    assert(!BitmapFont::nameEquals(nullptr,name,5));assert(!BitmapFont::family(fond.data(),fond.size(),21,family));
    for(unsigned n=0;n<fond.size();++n)assert(!BitmapFont::family(fond.data(),n,20,family));
    for(unsigned n:{0,2,4,6,16,28,50,52,54,56}) {
        auto bad=fond;bad[n]^=n==0 ? 0x20 : 0x80;assert(!BitmapFont::family(bad.data(),bad.size(),20,family));
    }
    assert(BitmapFont::family(fond.data(),fond.size(),20,family));
    for(unsigned n=0;n<nfnt.size();++n)assert(!font.open(nfnt.data(),n,family));
    for(unsigned n:{0,2,4,6,8,10,12,14,16,18,20,22,24}) {
        auto bad=nfnt;bad[n]^=0x80;assert(!font.open(bad.data(),bad.size(),family));assert(!font.pixel('A',0,0));
    }
    for(unsigned n:{26u+unsigned(BitmapFont::word(nfnt.data()+24))*28u,
                    16u+unsigned(BitmapFont::word(nfnt.data()+16))*2u,unsigned(nfnt.size())-2u}) {
        auto bad=nfnt;bad[n]^=0x80;assert(!font.open(bad.data(),bad.size(),family));
    }
    puts("PASS bitmap font: family association, metrics, location/width bounds, exact A/space/missing pixels, ASCII name lookup, truncated and malformed resources rejected");
}
