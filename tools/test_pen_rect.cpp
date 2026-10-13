#include "../src/mac/PenRect8.h"
#include <vector>
#include <cassert>
#include <cstdio>
#include <algorithm>
static void rect(uint8_t* p,int t,int l,int b,int r) {
    int a[]={t,l,b,r};for(unsigned i=0;i<4;++i) {p[2*i]=uint16_t(a[i])>>8;p[2*i+1]=uint8_t(a[i]);}
}
static uint32_t rng=17;
static unsigned random(unsigned n) {rng=rng*1664525u+1013904223u;return (rng>>8)%n;}
int main() {
    for(unsigned n=0;n<12000;++n) {
        int mt=int(random(600))-300,ml=int(random(600))-300;
        unsigned stride=32+random(9),height=24,capacity=stride*height;
        uint8_t bounds[32];rect(bounds,mt,ml,mt+height,ml+32);
        for(unsigned j=1;j<4;++j) {
            int y=mt+int(random(35))-5,x=ml+int(random(43))-5;
            rect(bounds+8*j,y,x,y+int(random(28))-2,x+int(random(36))-2);
        }
        int16_t x=ml+int(random(64))-16,y=mt+int(random(56))-16;
        const uint16_t sizes[]={0,1,2,3,4,8,16,31,32767,65535};
        uint16_t w=sizes[random(10)],h=sizes[random(10)];
        if(n%19==0)x=32766;if(n%23==0)y=-32768;
        uint32_t cap=n%13 ? capacity : capacity-1;
        std::vector<uint8_t> pixels(capacity+32),expected;
        for(auto& v:pixels)v=random(256);
        expected=pixels;uint8_t ink=random(256);
        bool valid=w<=32767 && h<=32767 && int(x)+w<=32767 && int(y)+h<=32767 && cap>=capacity;
        if(valid)for(unsigned row=0;row<height;++row)for(unsigned col=0;col<32;++col) {
            int yy=mt+row,xx=ml+col;bool paint=xx>=x && xx<int(x)+w && yy>=y && yy<int(y)+h;
            for(unsigned j=1;j<4;++j) {
                auto r=bounds+8*j;
                paint=paint && yy>=int16_t(BigEndianMemory::read16(r)) && xx>=int16_t(BigEndianMemory::read16(r+2))
                    && yy<int16_t(BigEndianMemory::read16(r+4)) && xx<int16_t(BigEndianMemory::read16(r+6));
            }
            if(paint)expected[16+row*stride+col]=ink;
        }
        assert(PenRect8::solid(pixels.data()+16,cap,stride,bounds,bounds+8,bounds+16,bounds+24,x,y,w,h,ink)==valid);
        assert(pixels==expected);
    }
    uint8_t b[8]={0,0,0,0,0,1,0,1},p[4]={1,2,3,4};
    assert(!PenRect8::solid(nullptr,4,1,b,b,b,b,0,0,1,1,2));
    assert(!PenRect8::solid(p,4,0,b,b,b,b,0,0,1,1,2));
    b[4]=255;assert(!PenRect8::solid(p,4,1,b,b,b,b,0,0,1,1,2));
    assert(p[0]==1 && p[3]==4);
    puts("PASS pen rectangles: 12000 complete guarded-buffer cases, clipping, sizes, signed bounds, padding and atomic rejection");
}
