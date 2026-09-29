#ifndef AITD_BITMAP_FONT_H
#define AITD_BITMAP_FONT_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif
// Restricted classic FOND/NFNT reader for the port-owned placeholder overlay.
// Unsupported tables, styles and depths are rejected, never guessed.
class BitmapFont {
public:
    struct Family { uint16_t first,last,size;int16_t bitmap; };
    static uint16_t word(const uint8_t* p) { return uint16_t(p[0])<<8|p[1]; }
    static bool family(const uint8_t* p,uint32_t bytes,int16_t id,Family& out) {
        if(!p || bytes!=60 || word(p)!=0xc000 || int16_t(word(p+2))!=id || word(p+50)!=2 || word(p+52)!=0 || word(p+56)!=0)return false;
        for(uint16_t n=16;n<50;++n)if(p[n])return false;
        uint16_t first=word(p+4),last=word(p+6),size=word(p+54);
        if(first>last || last>255 || !size || size>255 || !word(p+8) || !word(p+14))return false;
        out.first=first;out.last=last;out.size=size;out.bitmap=int16_t(word(p+58));return true;
    }
    bool open(const uint8_t* p,uint32_t bytes,const Family& family) {
        data_=0;
        if(!p || bytes<26 || word(p)!=0x3000 || word(p+2)!=family.first || word(p+4)!=family.last || word(p+8)!=0 || word(p+22)!=0)return false;
        uint16_t count=family.last-family.first+2; // includes missing glyph
        uint16_t height=word(p+14),rowWords=word(p+24),ascent=word(p+18),descent=word(p+20),width=word(p+6);
        if(!height || height>255 || !rowWords || rowWords>4096 || !width || width>255 || word(p+12)>width || ascent+descent!=height || height!=family.size || int16_t(word(p+10))!=-int32_t(descent))return false;
        uint32_t locations=26+uint32_t(rowWords)*2*height;
        uint32_t widths=locations+uint32_t(count+1)*2;
        if(widths+uint32_t(count+1)*2!=bytes || 16+uint32_t(word(p+16))*2!=widths || word(p+locations)!=0 || word(p+widths+count*2)!=0xffff)return false;
        for(uint16_t n=0;n<count;++n) {
            uint16_t left=word(p+locations+n*2),right=word(p+locations+(n+1)*2);
            if(left>right || right>uint32_t(rowWords)*16 || right-left>word(p+12) || word(p+widths+n*2)!=width)return false;
        }
        data_=p;first_=family.first;last_=family.last;locations_=locations;rowBytes_=rowWords*2;height_=height;advance_=width;return true;
    }
    uint16_t advance() const { return advance_; }
    uint16_t height() const { return height_; }
    bool pixel(uint16_t character,uint16_t x,uint16_t y) const {
        if(!data_ || y>=height_)return false;
        uint16_t index=character>=first_ && character<=last_ ? character-first_ : last_-first_+1;
        uint16_t left=word(data_+locations_+index*2),right=word(data_+locations_+(index+1)*2);
        if(x>=right-left)return false;
        uint16_t bit=left+x;
        return (data_[26+uint32_t(y)*rowBytes_+bit/8]&(128>>(bit&7)))!=0;
    }
    static bool nameEquals(const uint8_t* pascal,const uint8_t* name,uint16_t length) {
        if(!pascal || !name || !length || pascal[0]!=length)return false;
        for(uint16_t n=0;n<length;++n) {
            uint8_t a=pascal[n+1],b=name[n];
            if(a>='a' && a<='z')a-='a'-'A';
            if(b>='a' && b<='z')b-='a'-'A';
            if(a!=b)return false;
        }
        return true;
    }
private:
    const uint8_t* data_=0;
    uint32_t locations_=0;
    uint16_t first_=0,last_=0,rowBytes_=0,height_=0,advance_=0;
};
#endif
