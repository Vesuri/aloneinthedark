#ifndef AITD_REGION_OPS_H
#define AITD_REGION_OPS_H
#include "RegionRows.h"
namespace RegionOps {
// Callers own staging storage, kept off the native supervisor stack. Failed
// encoding may change staging bytes, but must never publish a destination.
struct Writer {
    uint8_t* out;uint16_t capacity,used=10;
    RegionRows::Edges previous{};
    int16_t top=32767,left=32767,bottom=0,right=-32768;
    Writer(uint8_t* p,uint16_t n):out(p),capacity(n) {}
    bool row(int16_t y,const RegionRows::Edges& next) {
        if(previous.count)bottom=y;
        if(next.count) {
            if(top==32767)top=y;
            if(next.x[0]<left)left=next.x[0];
            if(next.x[next.count-1]>right)right=next.x[next.count-1];
        }
        RegionRows::Edges changes=previous;
        for(uint16_t i=0;i<next.count;++i)
            if(!RegionRows::toggle(changes,next.x[i]))return false;
        if(changes.count) {
            if(y==32767 || used+changes.count*2+6>capacity)return false;
            WindowGeometry::word(out+used,uint16_t(y));used+=2;
            for(uint16_t i=0;i<changes.count;++i) {
                if(changes.x[i]==32767)return false;
                WindowGeometry::word(out+used,uint16_t(changes.x[i]));used+=2;
            }
            WindowGeometry::word(out+used,32767);used+=2;
        }
        previous=next;return true;
    }
    bool finish(uint16_t& size) {
        size=0;if(!out || capacity<10 || previous.count)return false;
        if(top==32767) {used=10;top=left=bottom=right=0;}
        else {if(used+2>capacity)return false;WindowGeometry::word(out+used,32767);used+=2;if(used==28)used=10;}
        WindowGeometry::word(out,used);WindowGeometry::word(out+2,uint16_t(top));
        WindowGeometry::word(out+4,uint16_t(left));WindowGeometry::word(out+6,uint16_t(bottom));
        WindowGeometry::word(out+8,uint16_t(right));size=used;return true;
    }
};
enum Operation { Xor, Difference, Intersection };
inline bool spans(const RegionRows::Edges& a,const RegionRows::Edges& b,
                  Operation op,RegionRows::Edges& out) {
    out.count=0;uint16_t i=0,j=0;bool inA=false,inB=false,previous=false;
    while(i<a.count || j<b.count) {
        int16_t x=j==b.count || (i<a.count && a.x[i]<b.x[j]) ? a.x[i] : b.x[j];
        if(i<a.count && a.x[i]==x) {inA=!inA;++i;}
        if(j<b.count && b.x[j]==x) {inB=!inB;++j;}
        bool next=op==Xor ? inA!=inB : op==Difference ? inA && !inB : inA && inB;
        if(next!=previous) {
            if(out.count==16)return false;
            out.x[out.count++]=x;previous=next;
        }
    }
    return !previous;
}
inline int32_t nextLine(const RegionRows::Cursor& c,int32_t y) {
    if(c.size==10) {
        int16_t top=RegionRows::get(c.region+2),bottom=RegionRows::get(c.region+6);
        return y<top ? top : y<bottom ? bottom : 32767;
    }
    return RegionRows::get(c.region+c.at);
}
inline bool combine(const uint8_t* a,uint16_t aBytes,const uint8_t* b,uint16_t bBytes,
                    Operation op,uint8_t* scratch,uint16_t capacity,uint16_t& size) {
    size=0;if(!scratch || capacity<10)return false;
    RegionRows::Cursor ca,cb;
    if(!ca.begin(a,aBytes) || !cb.begin(b,bBytes))return false;
    Writer writer(scratch,capacity);
    int32_t y=-32769;
    for(;;) {
        int32_t ay=nextLine(ca,y),by=nextLine(cb,y);y=ay<by?ay:by;
        if(y==32767)break;
        if(!ca.advance(int16_t(y)) || !cb.advance(int16_t(y)))return false;
        RegionRows::Edges next{};
        if(!spans(ca.edges,cb.edges,op,next) || !writer.row(int16_t(y),next))return false;
    }
    return writer.finish(size);
}
// Reached FrameOval recording uses circular bounds. Pixel centres are tested
// with integer arithmetic. Non-circular ellipses remain unsupported pending
// exact QuickDraw rounding coverage, rather than silently approximated.
inline bool circle(const uint8_t* rect,uint8_t* scratch,uint16_t capacity,uint16_t& size) {
    size=0;if(!rect || !scratch || capacity<10)return false;
    int32_t top=RegionRows::get(rect),left=RegionRows::get(rect+2);
    int32_t bottom=RegionRows::get(rect+4),right=RegionRows::get(rect+6);
    Writer writer(scratch,capacity);
    if(top>=bottom || left>=right)return writer.finish(size);
    int32_t diameter=right-left;
    if(diameter!=bottom-top || diameter>32766 || bottom>=32767 || right>=32767)return false;
    const int32_t square=diameter*diameter;
    for(int32_t y=top;y<=bottom;++y) {
        RegionRows::Edges next{};
        if(y<bottom) {
            int32_t dy=2*(y-top)+1-diameter;
            int32_t lo=0,hi=diameter/2;
            while(lo<hi) {
                int32_t x=(lo+hi)/2,dx=2*x+1-diameter;
                if(dx*dx+dy*dy<=square)hi=x;else lo=x+1;
            }
            int32_t dx=2*lo+1-diameter;
            if(dx*dx+dy*dy<=square) {
                next.count=2;next.x[0]=int16_t(left+lo);next.x[1]=int16_t(right-lo);
            }
        }
        if(!writer.row(int16_t(y),next))return false;
    }
    return writer.finish(size);
}
}
#endif
