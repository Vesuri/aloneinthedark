#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
extern volatile uint32_t g_fileWriteProbeStep;
int32_t aitdProbeHOpen(void*),aitdProbeWrite(void*),aitdProbeRead(void*),aitdProbeSetEOF(void*);
int32_t aitdProbeFCB(void*),aitdProbeFlush(void*),aitdProbeClose(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),data[4];
static uint8_t name[]="\021sharing-probe.bin",lockedName[]="\020locked-probe.bin";
static void w(uint16_t off,uint16_t v) { pb[off]=v>>8;pb[off+1]=v; }
static void l(uint16_t off,uint32_t v) { w(off,v>>16);w(off+2,v); }
static uint32_t get(uint16_t off) { return (uint32_t)pb[off]<<24|(uint32_t)pb[off+1]<<16|(uint32_t)pb[off+2]<<8|pb[off+3]; }
static bool result(int32_t value,int32_t expected=0) {
    return value==expected && (int16_t)(get(16)>>16)==expected
        && (g_fileProbeCCR&15)==(expected<0 ? 8 : expected==0 ? 4 : 0);
}
static bool open(uint8_t permission,int32_t expected=0,bool locked=false) {
    l(18,(uint32_t)(locked ? lockedName : name));w(22,0xffff);l(48,7);w(24,0);pb[27]=permission;
    return result(aitdProbeHOpen(pb),expected);
}
static uint16_t ref() { return get(24)>>16; }
static bool close(uint16_t ref) { w(24,ref);return result(aitdProbeClose(pb)); }
static bool fcb(uint16_t ref,uint16_t flags,uint32_t size,uint32_t mark) {
    l(18,0);w(24,ref);w(28,0);
    return result(aitdProbeFCB(pb)) && get(36)>>16==flags && get(40)==size && get(48)==mark;
}
static bool transfer(uint16_t ref,bool write,uint32_t count,uint16_t mode=1,uint32_t offset=0) {
    w(24,ref);l(32,(uint32_t)data);l(36,count);w(44,mode);l(46,offset);
    return result(write ? aitdProbeWrite(pb) : aitdProbeRead(pb)) && get(40)==count;
}
static bool flush() { l(18,0);w(22,0xffff);return result(aitdProbeFlush(pb)); }
extern "C" bool aitdFileSharingProbe() {
    for(uint8_t first=0;first<5;++first)for(uint8_t second=0;second<5;++second) {
        g_fileWriteProbeStep=100+first*5+second;
        if(!open(first))return false;
        uint16_t a=ref();
        uint16_t fa=first==1 ? 0 : first==4 ? 0x1100 : 0x100;
        if(!fcb(a,fa,0,0))return false;
        bool conflict=first!=1 && second!=1 && !(first==4 && second==4);
        if(!open(second,conflict ? -49 : 0))return false;
        uint16_t b=ref();
        if(conflict) { if(b!=a)return false; }
        else {
            uint16_t fb=second==1 ? 0 : second==4 ? 0x1100 : 0x100;
            if(a==b || !fcb(b,fb,0,0) || !close(b))return false;
        }
        if(!close(a))return false;
    }
    for(uint8_t shared=0;shared<2;++shared) {
        g_fileWriteProbeStep=130+shared;
        if(!open(shared ? 4 : 3))return false;
        uint16_t a=ref();
        if(!open(shared ? 4 : 1))return false;
        uint16_t b=ref();
        w(24,a);l(28,0);if(!result(aitdProbeSetEOF(pb)))return false;
        data[0]=0x12;data[1]=0x34;data[2]=0x56;data[3]=0x78;
        if(!transfer(a,true,4) || !fcb(b,shared ? 0x1100 : 0,4,0))return false;
        for(uint16_t i=0;i<4;++i)data[i]=0;
        if(!transfer(b,false,4) || data[0]!=0x12 || data[1]!=0x34 || data[2]!=0x56 || data[3]!=0x78)return false;
        w(24,a);l(28,2);if(!result(aitdProbeSetEOF(pb)))return false;
        if(!fcb(b,shared ? 0x1100 : 0,2,4) || !fcb(a,shared ? 0x9100 : 0x8100,2,2))return false;
        if(!flush() || !fcb(a,shared ? 0x1100 : 0x100,2,2) || !close(a))return false;
        if(!fcb(b,shared ? 0x1100 : 0,2,4) || !transfer(b,false,2) || data[0]!=0x12 || data[1]!=0x34)return false;
        // The remaining shared writer must still own valid backing storage.
        if(shared && !transfer(b,true,4,2))return false;
        if(!close(b))return false;
    }
    g_fileWriteProbeStep=140;
    // Populate a read cache before a writer opens; it must not serve stale data.
    if(!open(1))return false;
    uint16_t reader=ref();
    if(!transfer(reader,false,2) || !open(3))return false;
    uint16_t writer=ref();
    data[0]=0xab;data[1]=0xcd;data[2]=0xef;data[3]=1;
    if(!transfer(writer,true,4) || !transfer(reader,false,4) || data[0]!=0xab || data[3]!=1 || !close(writer))return false;
    data[0]=0;if(!transfer(reader,false,4) || data[0]!=0xab || !close(reader))return false;
    g_fileWriteProbeStep=145;
    if(!open(3))return false;writer=ref();
    if(!open(1))return false;reader=ref();
    if(!transfer(writer,true,4) || !close(reader) || !fcb(writer,0x8100,6,4) || !close(writer))return false;
    for(uint8_t permission=0;permission<5;++permission) {
        g_fileWriteProbeStep=150+permission;
        if(!open(permission,permission<2 ? 0 : -54,true))return false;
        if(permission<2 && (!fcb(ref(),0x2000,0,0) || !close(ref())))return false;
    }
    g_fileWriteProbeStep=160;
    static uint8_t plain[]="\005Alone",full[]="\006Alone:",bad[]="\006Other:",partial[]="\002:X",path[]="\007Alone:X";
    l(18,(uint32_t)plain);w(22,0x1234);if(!result(aitdProbeFlush(pb),-35))return false;
    w(22,0);if(!result(aitdProbeFlush(pb)))return false;
    l(18,(uint32_t)full);w(22,0x1234);if(!result(aitdProbeFlush(pb)))return false;
    l(18,(uint32_t)path);if(!result(aitdProbeFlush(pb)))return false;
    l(18,(uint32_t)partial);w(22,0xffff);if(!result(aitdProbeFlush(pb)))return false;
    w(22,0x1234);if(!result(aitdProbeFlush(pb),-35))return false;
    l(18,(uint32_t)bad);w(22,0xffff);if(!result(aitdProbeFlush(pb),-35))return false;
    l(18,0);w(22,1);if(!result(aitdProbeFlush(pb)))return false;
    w(22,0x1234);if(!result(aitdProbeFlush(pb),-35))return false;
    return true;
}
#endif
