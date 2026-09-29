#include "../src/mac/WindowGeometry.h"
#include <cassert>
#include <cstring>
#include <set>
#include <cstdio>
using WindowGeometry::Rect;
static int word(const unsigned char* p) {return int16_t(uint16_t(p[0])<<8|p[1]);}
static bool same(Rect a,Rect b) {return a.top==b.top && a.left==b.left && a.bottom==b.bottom && a.right==b.right;}
static bool contains(const unsigned char* data,int x,int y) {
    std::set<int> crossings;
    int at=10;
    while(word(data+at)!=32767 && word(data+at)<=y) {
        at+=2;
        while(word(data+at)!=32767) {
            int edge=word(data+at);at+=2;
            if(!crossings.erase(edge))crossings.insert(edge);
        }
        at+=2;assert(crossings.size()%2==0);
    }
    bool inside=false;
    for(int edge:crossings) {if(x<edge)break;inside=!inside;}
    return inside;
}
int main() {
    const Rect frames[]={{-8000,-8000,8000,8000},{168,82,368,402},{150,160,350,480}};
    const Rect ports[]={{0,0,16000,16000},{0,0,200,320},{0,0,200,320}};
    const Rect pixmaps[]={{8000,8000,8480,8640},{-168,-82,312,558},{-150,-160,330,480}};
    for(unsigned i=0;i<3;++i) {
        Rect p{},m{},f{};
        assert(WindowGeometry::layout(frames[i],p,m));
        assert(same(p,ports[i]) && same(m,pixmaps[i]));
        assert(WindowGeometry::frame(p,m,f) && same(f,frames[i]));
    }
    Rect p={1,2,3,4},m=p,keep=p;
    assert(!WindowGeometry::layout({0,0,0,1},p,m) && same(p,keep) && same(m,keep));
    assert(!WindowGeometry::layout({-32768,0,0,1},p,m));
    assert(!WindowGeometry::layout({-32500,0,-32400,1},p,m));
    assert(!WindowGeometry::frame({1,0,200,320},{0,0,480,640},p));
    assert(!WindowGeometry::frame({0,0,200,320},{0,0,479,640},p));
    for(Rect f: {Rect{150,160,350,480},Rect{-10,-5,2,7},Rect{0,0,1,1}}) {
        unsigned char region[44];assert(WindowGeometry::structure4(f,region));
        assert(word(region)==44);
        for(int y=f.top-20;y<=f.bottom+3;++y)for(int x=f.left-2;x<=f.right+3;++x) {
            bool border=x>=f.left-1 && x<f.right+1 && y>=f.top-19 && y<f.bottom+1;
            bool shadow=x>=f.left && x<f.right+2 && y>=f.top-18 && y<f.bottom+2;
            assert(contains(region,x,y)==(border || shadow));
        }
    }
    unsigned char bad[44];std::memset(bad,0xa5,sizeof bad);
    assert(!WindowGeometry::structure4({-32760,0,-32750,10},bad));
    for(auto b:bad)assert(b==0xa5);
    std::puts("PASS window geometry: original resource layouts, inverse coordinates, independent region decode, shadow union and overflow rejection");
}
