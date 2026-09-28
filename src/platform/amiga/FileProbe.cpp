#ifdef AITD_FILE_PROBE
extern "C" {
extern volatile uint32_t g_systemWindows;
volatile uint32_t g_fileProbeStage=0,g_fileProbeError=0,g_fileProbeDone=0,g_fileProbeWindows=0;
volatile uint16_t g_fileProbeCCR=0;
int32_t aitdProbeGetWD(void*),aitdProbeCloseWD(void*);
int32_t aitdProbeFCB(void*),aitdProbeHGetVol(void*),aitdProbeHSetVol(void*);
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
    g_fileProbeStage=19;l(18,(uint32_t)volume);w(22,0);w(24,0);w(28,1);
    if(!result(aitdProbeFCB(pb),0) || ((get(24)>>16)&65535)!=128
       || get(40)!=1424934 || (get(36)>>16)!=0x300 || volume[0]!=17)return false;
    g_fileProbeStage=20;w(28,2);w(22,wd);
    if(!result(aitdProbeFCB(pb),0) || ((get(24)>>16)&65535)!=129
       || get(40)!=200003 || (get(36)>>16)!=0 || volume[0]!=14)return false;
    uint32_t fileID=get(32),parent=get(58);
    g_fileProbeStage=21;w(28,0);w(22,0x1234);l(18,0);
    if(!result(aitdProbeFCB(pb),0) || get(32)!=fileID || get(58)!=parent || get(40)!=200003)return false;
    g_fileProbeStage=22;w(28,0x7fff);w(22,0);
    if(!result(aitdProbeFCB(pb),-38) || get(32)!=fileID)return false;
    w(28,1);w(22,0x1234);
    if(!result(aitdProbeFCB(pb),-35))return false;
    w(28,0);w(24,0);
    if(!result(aitdProbeFCB(pb),-51) || g_systemWindows!=start+10)return false;
    g_fileProbeStage=23;l(18,0);w(22,0xffff);l(48,7);
    if(!result(aitdProbeHSetVol(pb),0) || !result(aitdProbeGetVol(pb),0) || (get(20)&65535)!=0xffff)return false;
    g_fileProbeStage=24;l(18,(uint32_t)volume);l(28,0xdeadbeef);l(48,0);
    if(!result(aitdProbeHGetVol(pb),0) || get(48)!=7 || (get(20)&65535)!=0xffff
       || (get(32)>>16)!=0xffff || get(28)!=0xdeadbeef || volume[0]!=5)return false;
    g_fileProbeStage=25;l(18,0);w(22,wd);
    if(!result(aitdProbeSetVol(pb),0) || !result(aitdProbeHGetVol(pb),0)
       || (get(20)&65535)!=wd || get(48)!=7 || get(28)!=0xdeadbeef)return false;
    g_fileProbeStage=26;l(48,0);
    if(!result(aitdProbeHSetVol(pb),0) || !result(aitdProbeHGetVol(pb),0)
       || (get(20)&65535)!=0xffff || get(48)!=7 || get(28)!=0xdeadbeef)return false;
    g_fileProbeStage=27;w(22,wd);l(48,0x9999);
    if(!result(aitdProbeHSetVol(pb),-43) || !result(aitdProbeHGetVol(pb),0)
       || (get(20)&65535)!=0xffff || get(48)!=7)return false;
    g_fileProbeStage=28;
    static uint8_t directoryName[]="\014:Alone Data:";
    w(22,0xffff);l(48,3);l(18,(uint32_t)directoryName);
    if(!result(aitdProbeHSetVol(pb),0))return false;
    l(18,0);
    if(!result(aitdProbeHGetVol(pb),0) || get(48)!=7 || g_systemWindows!=start+10)return false;
    g_fileProbeStage=29;w(22,0x8053);w(26,0);
    if(!result(aitdProbeGetWD(pb),0) || get(48)!=4 || get(28)!=0x4552494b || (get(32)>>16)!=0xffff)return false;
    g_fileProbeStage=30;
    if(!result(aitdProbeCloseWD(pb),0) || !result(aitdProbeGetWD(pb),-35) || !result(aitdProbeCloseWD(pb),-51))return false;
    g_fileProbeStage=31;w(22,0xffff);l(48,7);l(28,0x41495445);
    if(!result(aitdProbeOpenWD(pb),0) || (get(20)&65535)!=wd || (get(24)>>16)!=0)return false;
    g_fileProbeStage=32;l(18,(uint32_t)volume);w(26,0);
    if(!result(aitdProbeGetWD(pb),0) || get(48)!=7 || get(28)!=0x41495444 || volume[0]!=5)return false;
    g_fileProbeStage=33;l(18,0);w(22,0);w(26,1);l(28,0x41495444);
    if(!result(aitdProbeGetWD(pb),0) || (get(20)&65535)!=wd || get(48)!=7)return false;
    w(22,0);l(28,0x41495445);
    if(!result(aitdProbeGetWD(pb),-35) || (get(20)&65535)!=0 || get(28)!=0x41495445)return false;
    g_fileProbeStage=34;w(26,0);
    if(!result(aitdProbeGetWD(pb),0) || (get(20)&65535)!=0xffff || get(48)!=2 || get(28)!=0)return false;
    g_fileProbeStage=35;w(22,wd);
    if(!result(aitdProbeSetVol(pb),0) || !result(aitdProbeCloseWD(pb),0))return false;
    l(28,0xdeadbeef);
    if(!result(aitdProbeHGetVol(pb),0) || (get(20)&65535)!=wd || get(48)!=7 || get(28)!=0xdeadbeef
       || !result(aitdProbeGetWD(pb),-35) || !result(aitdProbeCloseWD(pb),-51))return false;
    g_fileProbeStage=36;w(22,0xffff);
    if(!result(aitdProbeCloseWD(pb),0))return false;
    w(22,0);if(!result(aitdProbeCloseWD(pb),-51))return false;
    w(22,0x1234);if(!result(aitdProbeCloseWD(pb),-51))return false;
    g_fileProbeStage=37;w(22,0xffff);l(48,3);l(28,0);
    if(!result(aitdProbeOpenWD(pb),0) || (get(20)&65535)!=(uint16_t)-32000 || (get(24)>>16)!=0
       || !result(aitdProbeCloseWD(pb),0) || !result(aitdProbeGetWD(pb),0) || get(48)!=3)return false;
    g_fileProbeStage=38;w(22,0);w(26,1);l(28,0);
    if(!result(aitdProbeGetWD(pb),0) || (get(20)&65535)!=(uint16_t)-32000 || get(48)!=3)return false;
    g_fileProbeStage=39;w(22,0);w(26,0xffff);
    if(!result(aitdProbeGetWD(pb),0) || (get(20)&65535)!=0xffff || get(48)!=2)return false;
    w(22,0);w(26,0x7fff);if(!result(aitdProbeGetWD(pb),-35))return false;
    w(22,0x1234);w(26,1);
    if(!result(aitdProbeGetWD(pb),-35) || g_systemWindows!=start+10)return false;
    g_fileProbeWindows=g_systemWindows-start;return true;
}
extern "C" void aitdFileProbe() {
    if(!run())g_fileProbeError=g_fileProbeStage;
    g_fileProbeDone=1;aitdFileProbeFinished();
}
#endif
