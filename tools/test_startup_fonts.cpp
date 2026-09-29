#include "../src/mac/BitmapFont.h"
#include <cassert>
#include <fstream>
#include <iterator>
#include <vector>
#include <string>
#include <cstdio>
static std::vector<uint8_t> read(const std::string& path) {
    std::ifstream in(path,std::ios::binary);assert(in.good());return {std::istreambuf_iterator<char>(in),{}};
}
int main(int argc,char** argv) {
    assert(argc==2);std::string root=argv[1];auto expected=read(root+"/cases");assert(expected.size()==25*20);
    for(unsigned i=0;i<25;++i) {
        auto p=expected.data()+i*20;auto w=BitmapFont::word;
        auto fond=read(root+"/fond"+std::to_string(w(p)));
        auto nfnt=read(root+"/nfnt"+std::to_string(w(p+6)));
        BitmapFont::Family family={};BitmapFont font;
        assert(BitmapFont::family(fond.data(),fond.size(),w(p),family,w(p+2),w(p+4)));
        assert(family.bitmap==w(p+6) && !family.fixedWidth && family.size==w(p+2));
        assert(font.open(nfnt.data(),nfnt.size(),family));
        assert(font.ascent()==w(p+8) && font.descent()==w(p+10) && font.advance()==w(p+12) && font.leading()==w(p+14));
        assert(font.charWidth('0')==w(p+16) && font.charWidth(' ')==w(p+18));
        assert(font.height()==font.ascent()+font.descent());
        bool ink=false;
        for(unsigned y=0;y<font.height();++y)for(unsigned x=0;x<font.advance();++x) {
            ink|=font.pixel('A',x,y);assert(!font.pixel(' ',x,y));
        }
        assert(ink && !font.pixel('A',font.advance(),0) && !font.pixel('A',0,font.height()));
        assert(font.charWidth(0)==font.advance());
        for(unsigned n=0;n<fond.size();++n)assert(!BitmapFont::family(fond.data(),n,w(p),family,w(p+2),w(p+4)));
        for(unsigned n:{0,16,50,52,54,56,58}) {
            auto bad=fond;bad[n]^=n==0 ? 0x20 : 0x80;assert(!BitmapFont::family(bad.data(),bad.size(),w(p),family,w(p+2),w(p+4)));
        }
        assert(!BitmapFont::family(fond.data(),fond.size(),w(p),family,55,0));
        assert(!BitmapFont::family(fond.data(),fond.size(),w(p),family,w(p+2),4));
        assert(BitmapFont::family(fond.data(),fond.size(),w(p),family,w(p+2),w(p+4)));
        for(unsigned n=0;n<nfnt.size();++n)assert(!font.open(nfnt.data(),n,family));
        for(unsigned n:{0,2,4,6,8,10,12,14,16,18,20,22,24}) {
            auto bad=nfnt;bad[n]^=0x80;assert(!font.open(bad.data(),bad.size(),family));assert(font.charWidth('0')==0);
        }
        auto bad=nfnt;unsigned widths=16+w(nfnt.data()+16)*2;bad[widths]=1;
        assert(!font.open(bad.data(),bad.size(),family));
        bad=nfnt;bad[widths+1]=255;assert(!font.open(bad.data(),bad.size(),family));
        bad=nfnt;bad[widths-2]=255;assert(!font.open(bad.data(),bad.size(),family));
    }
    puts("PASS startup fonts: 25 associations, measured metrics/widths, bounded owned glyphs, missing selections and malformed/truncated definitions rejected");
}
