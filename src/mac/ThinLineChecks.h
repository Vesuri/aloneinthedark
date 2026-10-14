// Diagnostic only: run the emitted native raster against the original-paired
// Line8 implementation. Owned scratch keeps the supervisor stack bounded.
extern "C" {
volatile uint32_t g_thinLineChecks=0,g_thinLineFast=0,g_thinLineRejected=0;
__attribute__((noinline)) void aitdThinLineChecksComplete() { __asm__ volatile("" ::: "memory"); }
}
static void thinLineChecks()
{
    struct Scratch {
        GWorldSlot world;
        uint8_t port[108],map[50],vis[10],clip[10],pattern[8],pen[2];
        uint8_t* roots[22];
        uint8_t actual[68*64],expected[68*64];
    };
    Scratch* s=(Scratch*)AllocMem(sizeof(Scratch),MEMF_FAST|MEMF_CLEAR);
    if(!s) {loaderStop("THIN LINE TEST ALLOC",0);showLoaderStop();}
    GWorldSlot& w=s->world;
    w.port=s->port;w.pixMap=s->map;w.pixels=s->actual;
    w.used=w.locked=true;w.pixelCapacity=sizeof(s->actual);
    for(unsigned i=0;i<22;++i)w.handles[i]=&s->roots[i];
    s->roots[3]=s->vis;s->roots[4]=s->clip;s->roots[7]=s->pen;s->roots[14]=s->pattern;
    for(unsigned i=0;i<8;++i)s->pattern[i]=255;
    write16(s->map+4,68);write16(s->map+32,8);
    write16(s->port+52,1);write16(s->port+54,1);write16(s->port+56,8);
    write32(s->port+80,93);write16(s->vis,10);write16(s->clip,10);
    // Every slope -31..31 in both directions, shifted origins and clip edges.
    for(unsigned mode=0;mode<4;++mode)for(int dy=-31;dy<=31;++dy)for(int dx=-31;dx<=31;++dx) {
        const int origin=mode&1 ? -160 : 0;
        uint8_t* rects[]={s->map+6,s->port+16,s->vis+2,s->clip+2};
        for(unsigned r=0;r<4;++r) {
            const int inset=(mode&2) && r==3 ? 12 : 0;
            write16(rects[r],origin+inset);write16(rects[r]+2,origin+inset);
            write16(rects[r]+4,origin+64-inset);write16(rects[r]+6,origin+64-inset);
        }
        int16_t x0=origin+31,y0=origin+31,x1=x0+dx,y1=y0+dy;
        write16(s->port+48,y0);write16(s->port+50,x0);
        for(unsigned i=0;i<sizeof(s->actual);++i)s->actual[i]=s->expected[i]=uint8_t(i*37+19);
        bool accepted=aitdSolidLine(&w,(uint32_t(uint16_t(y1))<<16)|uint16_t(x1));
        if(accepted) {
            if(!Line8::solid(s->expected,sizeof(s->expected),68,s->map+6,s->port+16,s->vis+2,s->clip+2,x0,y0,x1,y1,93))
                {loaderStop("THIN LINE TEST ORACLE",0);showLoaderStop();}
            if(read16(s->port+48)!=uint16_t(y1) || read16(s->port+50)!=uint16_t(x1))
                {loaderStop("THIN LINE TEST PEN",0);showLoaderStop();}
            ++g_thinLineFast;
        } else {
            if(read16(s->port+48)!=uint16_t(y0) || read16(s->port+50)!=uint16_t(x0))
                {loaderStop("THIN LINE REJECT PEN",0);showLoaderStop();}
            ++g_thinLineRejected;
        }
        for(unsigned i=0;i<sizeof(s->actual);++i)if(s->actual[i]!=s->expected[i])
            {loaderStop("THIN LINE TEST PIXELS",0);showLoaderStop();}
        ++g_thinLineChecks;
    }
    // Whole-line rejection, signed endpoint extremes and validation failures.
    for(unsigned n=0;n<10;++n) {
        write16(s->port+48,0x8000);write16(s->port+50,0x8000);
        write16(s->port+56,n==1 ? 0 : 8);
        write16(s->port+66,n==2 ? 1 : 0);
        write16(s->vis,n==3 ? 12 : 10);
        s->pattern[7]=n==4 ? 0 : 255;
        w.locked=n!=5;w.pixelCapacity=n==6 ? 1 : sizeof(s->actual);
        write16(s->pen,n==7 ? 1 : 0);
        write32(s->port+80,n==8 ? 256 : 93);
        for(unsigned i=0;i<sizeof(s->actual);++i)s->actual[i]=uint8_t(i*37+19);
        uint32_t target=n==9 ? 0x7fff7fffUL : 0x80018001UL;
        bool accepted=aitdSolidLine(&w,target);
        if(accepted!=(n==0) || read32(s->port+48)!=(accepted ? target : 0x80008000UL))
            {loaderStop("THIN LINE TEST REJECT",0);showLoaderStop();}
        for(unsigned i=0;i<sizeof(s->actual);++i)if(s->actual[i]!=uint8_t(i*37+19))
            {loaderStop("THIN LINE REJECT WRITE",0);showLoaderStop();}
        ++g_thinLineChecks;
    }
    FreeMem(s,sizeof(Scratch));
    aitdThinLineChecksComplete();
}
