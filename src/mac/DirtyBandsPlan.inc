// Shared coordinate-only planner body. Adapter supplies dimensions and policy macros.

    if(!DIRTY_BANDS_VIEWPORT_VALID(viewport) || dirtyCount>DIRTY_BANDS_CAPACITY || !capacity
       || (dirtyCount && !dirty) || !output)return false;
    Rect clipped[DIRTY_BANDS_CAPACITY],bounds={height,width,0,0};uint16_t n=0;
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
    if(n==1) {DIRTY_BANDS_ALIGN(clipped[0]);output[count++]=clipped[0];return true;}
    for(int16_t top=bounds.top;top<bounds.bottom;) {
        int16_t bottom=bounds.bottom;
        struct Span {int16_t left,right;} spans[DIRTY_BANDS_CAPACITY];uint16_t spanCount=0;
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
            DIRTY_BANDS_ALIGN(r);
            while(i<spanCount) {
                Rect next={top,spans[i].left,bottom,spans[i].right};
                DIRTY_BANDS_ALIGN(next);
                if(next.left>r.right)break;
                if(spans[i].right>r.right)r.right=spans[i].right;
                DIRTY_BANDS_ALIGN(r);++i;
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
                    DIRTY_BANDS_ALIGN(bounds);output[0]=bounds;count=1;return true;
                }
                output[count++]=r;
            }
        }
        top=bottom;
    }
    return true;
