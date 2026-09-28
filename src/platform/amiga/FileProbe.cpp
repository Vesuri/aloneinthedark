#ifdef AITD_FILE_PROBE
extern "C" {
extern volatile uint32_t g_systemWindows;
volatile uint32_t g_fileProbeStage=0,g_fileProbeError=0,g_fileProbeDone=0,g_fileProbeWindows=0;
volatile uint16_t g_fileProbeCCR=0;
int32_t aitdProbeGetVol(void*),aitdProbeSetVol(void*),aitdProbeOpenWD(void*);
int32_t aitdProbeHOpen(void*),aitdProbeOpen(void*),aitdProbeRead(void*),aitdProbeClose(void*),aitdProbeEOF(void*),aitdProbeSeek(void*),aitdProbePosition(void*);
__attribute__((noinline)) void aitdFileCleanupFinished() { __asm__ volatile("" ::: "memory"); }
__attribute__((noinline)) void aitdFileProbeFinished() { __asm__ volatile("" ::: "memory"); }
}
static uint8_t pb[80] __attribute__((aligned(4))),out[131089];
static uint8_t name[]={26,':','A','l','o','n','e',' ','D','a','t','a',':','r','e','a','d','-','p','r','o','b','e','.','b','i','n'};
static void w(uint16_t off,uint16_t v) { pb[off]=v>>8;pb[off+1]=v; }
static void l(uint16_t off,uint32_t v) { w(off,v>>16);w(off+2,v); }
static uint32_t get(uint16_t off) { return (uint32_t)pb[off]<<24 | (uint32_t)pb[off+1]<<16 | (uint32_t)pb[off+2]<<8 | pb[off+3]; }
static bool result(int32_t value,int32_t expected) {
    return value==expected && (int16_t)((pb[16]<<8)|pb[17])==expected
        && (g_fileProbeCCR&15)==(expected<0 ? 8 : expected==0 ? 4 : 0);
}
static bool bytes(uint32_t offset,uint32_t count) {
    for(uint32_t i=0;i<count;++i)if(out[i]!=(uint8_t)((offset+i)*37+((offset+i)>>8)))return false;
    return true;
}
static bool seek(uint32_t offset) { w(44,1);l(46,offset);return result(aitdProbeSeek(pb),0); }
static bool read(uint32_t count,int32_t error,uint32_t actual,uint32_t offset) {
    l(32,(uint32_t)out);l(36,count);w(44,0);
    return result(aitdProbeRead(pb),error) && get(40)==actual && get(46)==offset+actual && bytes(offset,actual);
}
static bool run() {
    uint32_t start=g_systemWindows;
    g_fileProbeStage=1;l(18,(uint32_t)name);pb[27]=1;
    if(!result(aitdProbeOpen(pb),0) || g_systemWindows!=start+1)return false;
    g_fileProbeStage=2;
    if(!result(aitdProbeEOF(pb),0) || get(28)!=200003)return false;
    g_fileProbeStage=3;
    if(!read(16,0,16,0) || g_systemWindows!=start+2)return false;
    g_fileProbeStage=4;
    if(!read(16,0,16,16) || g_systemWindows!=start+2)return false;
    g_fileProbeStage=5;
    if(!seek(65530) || !read(20,0,20,65530) || g_systemWindows!=start+3)return false;
    g_fileProbeStage=6;
    if(!seek(1000) || !read(sizeof(out),0,sizeof(out),1000) || g_systemWindows!=start+4)return false;
    g_fileProbeStage=7;
    if(!seek(199996) || !read(20,-39,7,199996) || g_systemWindows!=start+5)return false;
    g_fileProbeStage=8;
    if(!read(1,-39,0,200003) || g_systemWindows!=start+5)return false;
    g_fileProbeStage=9;w(44,1);l(46,0xffffffff);
    if(!result(aitdProbeSeek(pb),-40) || get(46)!=200003)return false;
    g_fileProbeStage=10;
    if(!result(aitdProbePosition(pb),0) || get(46)!=200003 || get(36)!=0)return false;
    g_fileProbeStage=11;
    if(!result(aitdProbeClose(pb),0) || g_systemWindows!=start+6)return false;
    g_fileProbeStage=12;
    if(!result(aitdProbeClose(pb),-51))return false;
    g_fileProbeStage=13;
    static uint8_t missing[]="\034:Alone Data:absent-probe.bin";
    l(18,(uint32_t)missing);pb[27]=1;
    if(!result(aitdProbeOpen(pb),-43) || g_systemWindows!=start+7)return false;
    g_fileProbeStage=14;
    static uint8_t relative[]="\016read-probe.bin";
    l(18,(uint32_t)relative);w(22,0xffff);l(48,7);
    if(!result(aitdProbeHOpen(pb),0) || !result(aitdProbeClose(pb),0) || g_systemWindows!=start+9)return false;
    // Leave one read-only session for shutdown after the OS has been restored.
    g_fileProbeStage=15;
    if(!result(aitdProbeHOpen(pb),0) || g_systemWindows!=start+10)return false;
    // Metadata calls must return the selected WD, not silently its volume root.
    g_fileProbeStage=16;l(18,0);w(22,0xffff);
    if(!result(aitdProbeSetVol(pb),0))return false;
    uint8_t volume[32]={};l(18,(uint32_t)volume);w(22,0x1234);
    if(!result(aitdProbeGetVol(pb),0) || (get(20)&65535)!=0xffff
       || volume[0]!=5 || volume[1]!='A' || volume[2]!='l' || volume[3]!='o'
       || volume[4]!='n' || volume[5]!='e')return false;
    g_fileProbeStage=17;l(18,0);w(22,0xffff);l(48,7);l(28,0x41495444);
    if(!result(aitdProbeOpenWD(pb),0))return false;
    uint16_t wd=get(20)&65535;
    if(wd==0xffff || !result(aitdProbeSetVol(pb),0))return false;
    l(18,(uint32_t)volume);w(22,0);
    if(!result(aitdProbeGetVol(pb),0) || (get(20)&65535)!=wd || volume[0]!=5)return false;
    g_fileProbeStage=18;l(18,0);w(22,42);
    if(!result(aitdProbeSetVol(pb),-35) || !result(aitdProbeGetVol(pb),0)
       || (get(20)&65535)!=wd)return false;
    w(22,0xffff);
    if(!result(aitdProbeSetVol(pb),0) || g_systemWindows!=start+10)return false;
    g_fileProbeWindows=g_systemWindows-start;return true;
}
extern "C" void aitdFileProbe() {
    if(!run())g_fileProbeError=g_fileProbeStage;
    g_fileProbeDone=1;aitdFileProbeFinished();
}
#endif
