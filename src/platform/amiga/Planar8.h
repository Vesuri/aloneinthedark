#ifndef AITD_PLANAR8_H
#define AITD_PLANAR8_H
#ifndef AITD_PLATFORM_AMIGA
#include <stdint.h>
#endif

// Integer reference converter for the fixed 320x200 view of a 640x480 Mac
// device. Plane zero is the least significant pixel bit. Rows interleave eight
// 40-byte planes. The assembly converter must agree with this representation.
namespace Planar8 {
static const uint16_t width=320, height=200, planes=8, planeRow=40, rowBytes=320;
static const uint32_t bytes=uint32_t(rowBytes)*height;
struct Rect { int16_t top,left,bottom,right; };

inline bool contains(const Rect& outer,const Rect& inner) {
    return outer.top<=inner.top && outer.left<=inner.left
        && outer.bottom>=inner.bottom && outer.right>=inner.right;
}

// Kalms needs a width divisible by 32, but its output may start on any word.
// Anchoring the block at a 16-pixel boundary avoids expanding a narrow actor
// across two fixed 32-pixel columns. Keep the final block inside the viewport.
inline void alignSpan(Rect& r) {
    r.left=int16_t(r.left&~15);
    r.right=int16_t(r.left+((r.right-r.left+31)&~31));
    if(r.right>width) {r.left-=r.right-width;r.right=width;}
}

// The inactive buffer holds the frame from two publications ago. A rectangle
// converted for the previous frame must be copied forward unless one rectangle
// converted this frame replaces it completely; conversion follows the copy.
inline bool syncNeeded(const Rect& previous,const Rect* converted,uint16_t count) {
    for(uint16_t i=0;i<count;++i)if(contains(converted[i],previous))return false;
    return true;
}

inline bool viewportValid(const Rect& viewport) {
    return viewport.top>=0 && viewport.left>=0 && viewport.bottom<=480
        && viewport.right<=640 && viewport.bottom-viewport.top==height
        && viewport.right-viewport.left==width;
}

struct Mismatch { uint16_t x,y;uint8_t expected,actual; };
// Independent bitplane decoder for diagnostic builds. Check the entire frame,
// including pixels preserved outside the current dirty rectangles.
inline bool verify(const uint8_t* chunky,const uint8_t* planar,
                   const Rect& viewport,Mismatch& mismatch) {
    if(!chunky || !planar || !viewportValid(viewport))return false;
    for(uint16_t y=0;y<height;++y)for(uint16_t x=0;x<width;++x) {
        uint8_t actual=0;
        for(uint16_t bit=0;bit<planes;++bit)
            if(planar[uint32_t(y)*rowBytes+bit*planeRow+x/8]&(128u>>(x&7)))
                actual|=1u<<bit;
        uint8_t expected=chunky[uint32_t(y+viewport.top)*640+x+viewport.left];
        if(actual!=expected) {mismatch={x,y,expected,actual};return false;}
    }
    return true;
}

// Output coordinates are local to the viewport. Empty intersections are valid
// and produce an empty rectangle. Align relative to the destination, then clip.
inline bool normalize(const Rect& viewport,const Rect& dirty,Rect& local) {
    if(!viewportValid(viewport) || dirty.bottom<dirty.top || dirty.right<dirty.left)return false;
    local={0,0,0,0};
    int32_t top=dirty.top>viewport.top ? dirty.top : viewport.top;
    int32_t left=dirty.left>viewport.left ? dirty.left : viewport.left;
    int32_t bottom=dirty.bottom<viewport.bottom ? dirty.bottom : viewport.bottom;
    int32_t right=dirty.right<viewport.right ? dirty.right : viewport.right;
    if(top>=bottom || left>=right)return true;
    local.top=int16_t(top-viewport.top);local.bottom=int16_t(bottom-viewport.top);
    local.left=int16_t(left-viewport.left);
    local.right=int16_t(right-viewport.left);
    alignSpan(local);
    return true;
}

// Plan disjoint conversion bands from clipped draw coordinates, before alignment.
// No pixels are read. Each band has a constant set of dirty horizontal intervals;
// aligned overlaps become one span, then identical adjacent bands coalesce.
inline bool plan(const Rect& viewport,const Rect* dirty,uint16_t dirtyCount,
                 Rect* output,uint16_t capacity,uint16_t& count) {
    if(!viewportValid(viewport) || dirtyCount>32 || !capacity
       || (dirtyCount && !dirty) || !output)return false;
    Rect clipped[32],bounds={height,width,0,0};uint16_t n=0;
    for(uint16_t i=0;i<dirtyCount;++i) {
        const Rect& d=dirty[i];
        if(d.top>d.bottom || d.left>d.right)return false;
        const int32_t top=d.top>viewport.top ? d.top : viewport.top;
        const int32_t left=d.left>viewport.left ? d.left : viewport.left;
        const int32_t bottom=d.bottom<viewport.bottom ? d.bottom : viewport.bottom;
        const int32_t right=d.right<viewport.right ? d.right : viewport.right;
        if(top>=bottom || left>=right)continue;
        Rect r={int16_t(top-viewport.top),int16_t(left-viewport.left),
                int16_t(bottom-viewport.top),int16_t(right-viewport.left)};
        clipped[n++]=r;
        if(r.top<bounds.top)bounds.top=r.top;
        if(r.left<bounds.left)bounds.left=r.left;
        if(r.bottom>bounds.bottom)bounds.bottom=r.bottom;
        if(r.right>bounds.right)bounds.right=r.right;
    }
    count=0;
    if(!n)return true;
    // Common one-rectangle publication needs no sweep.
    if(n==1) {alignSpan(clipped[0]);output[count++]=clipped[0];return true;}
    for(int16_t top=bounds.top;top<bounds.bottom;) {
        int16_t bottom=bounds.bottom;
        struct Span {int16_t left,right;} spans[32];uint16_t spanCount=0;
        for(uint16_t i=0;i<n;++i) {
            const Rect& r=clipped[i];
            if(r.top>top && r.top<bottom)bottom=r.top;
            if(r.bottom>top && r.bottom<bottom)bottom=r.bottom;
            if(r.top>top || r.bottom<=top)continue;
            uint16_t at=spanCount++;
            while(at && spans[at-1].left>r.left) {spans[at]=spans[at-1];--at;}
            spans[at]={r.left,r.right};
        }
        for(uint16_t i=0;i<spanCount;) {
            Rect r={top,spans[i].left,bottom,spans[i].right};++i;
            // Union actual touching/overlapping coordinates before alignment.
            while(i<spanCount && spans[i].left<=r.right) {
                if(spans[i].right>r.right)r.right=spans[i].right;
                ++i;
            }
            alignSpan(r);
            while(i<spanCount) {
                Rect next={top,spans[i].left,bottom,spans[i].right};
                alignSpan(next);
                if(next.left>r.right)break;
                if(spans[i].right>r.right)r.right=spans[i].right;
                alignSpan(r);++i;
            }
            bool extended=false;
            for(uint16_t j=0;j<count;++j) {
                Rect& prior=output[j];
                if(prior.bottom==top && prior.left==r.left && prior.right==r.right) {
                    prior.bottom=bottom;extended=true;break;
                }
            }
            if(!extended) {
                if(count==capacity) {
                    // Bounded storage fallback covers all inputs, including later bands.
                    alignSpan(bounds);output[0]=bounds;count=1;return true;
                }
                output[count++]=r;
            }
        }
        top=bottom;
    }
    return true;
}

#ifndef AITD_PLATFORM_AMIGA
// Host oracle only. The game always calls Kalms assembly.
inline bool convert(const uint8_t* chunky,uint8_t* planar,const Rect& viewport,
                    const Rect& dirty,Rect& converted) {
    Rect local;
    if(!chunky || !planar || !normalize(viewport,dirty,local))return false;
    for(int16_t y=local.top;y<local.bottom;++y) {
        const uint8_t* source=chunky+uint32_t(y+viewport.top)*640+viewport.left;
        uint8_t* destination=planar+uint32_t(y)*rowBytes;
        for(int16_t x=local.left;x<local.right;x+=8) {
            for(uint16_t plane=0;plane<planes;++plane) {
                uint8_t bits=0;
                for(uint16_t pixel=0;pixel<8;++pixel)
                    bits=uint8_t((bits<<1)|((source[x+pixel]>>plane)&1));
                destination[plane*planeRow+x/8]=bits;
            }
        }
    }
    converted=local;
    return true;
}
#endif
}
#endif
