#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
volatile uint32_t g_fileAsyncStep=0,g_fileAsyncCallbacks=0,g_fileAsyncPB=0,g_fileAsyncResult=0,g_fileAsyncA5=0;
volatile uint32_t g_fileAsyncClobber=0,g_fileAsyncNested=0,g_fileAsyncNestedOK=0;
extern volatile uint16_t g_fileProbeCCR,g_macServiceActive,g_macFileCompletionDepth;
int32_t aitdProbeAsyncInfo(void*),aitdProbeAsyncHInfo(void*),aitdProbeAsyncCreate(void*),aitdProbeAsyncSetInfo(void*),aitdProbeAsyncOpenRF(void*);
int32_t aitdProbeAsyncGetVol(void*),aitdProbeAsyncSetVol(void*),aitdProbeAsyncOpenWD(void*),aitdProbeAsyncCloseWD(void*),aitdProbeAsyncGetWD(void*),aitdProbeAsyncFCB(void*);
int32_t aitdProbeCloseWD(void*),aitdProbeInfo(void*),aitdProbeAsyncRegisters(void*),aitdProbeHGetVol(void*),aitdProbeHInfo(void*),aitdProbeClose(void*),aitdProbeHDelete(void*),aitdProbeFlush(void*);
void aitdFileAsyncCompletion();
}
static uint8_t pb[128] __attribute__((aligned(4))),name[64],nestedPB[128] __attribute__((aligned(4)));
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static void named(const char* text) {
    uint16_t n=0;while(text[n]) { name[n+1]=text[n];++n; }name[0]=n;
    l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,3);
}
static bool call(int32_t (*fn)(void*),int16_t error=0,bool callback=true,bool pointer=true) {
    ++g_fileAsyncStep;uint32_t count=g_fileAsyncCallbacks;
    l(12,pointer ? (uint32_t)aitdFileAsyncCompletion : 0);w(16,0x7777);
    int32_t value=fn(pb);int32_t wanted=callback && g_fileAsyncClobber ? (int32_t)0xdeadbeef : error;
    if(value!=wanted || (int16_t)(get(16)>>16)!=error || (g_fileProbeCCR&15)!=(wanted<0 ? 8 : wanted ? 0 : 4)
        || g_fileAsyncCallbacks!=count+(callback ? 1 : 0))return false;
    if(callback && (g_fileAsyncPB!=(uint32_t)pb || (int16_t)g_fileAsyncResult!=error))return false;
    return true;
}
extern "C" void aitdFileAsyncNestedCall() {
    // A completion can issue a synchronous service without overwriting the outer
    // return PC or parked register image. No file-system payload is needed here.
    if(g_macServiceActive || g_macFileCompletionDepth!=1)return;
    for(uint16_t i=0;i<128;++i)nestedPB[i]=0;
    if(aitdProbeHGetVol(nestedPB)==0 && !nestedPB[16] && !nestedPB[17])g_fileAsyncNestedOK=1;
}
extern "C" bool aitdFileAsyncProbe() {
    for(uint16_t i=0;i<128;++i)pb[i]=0;
    for(uint16_t mode=0;mode<2;++mode) {
        g_fileAsyncClobber=mode;
        l(18,0);if(!call(aitdProbeAsyncGetVol))return false;
        if(!call(aitdProbeAsyncGetVol,0,false,false))return false;
        if(!call(aitdProbeHGetVol,0,false) || get(12))return false;
        l(18,0);w(22,0xffff);l(48,3);if(!call(aitdProbeAsyncSetVol))return false;
        w(22,0x1234);if(!call(aitdProbeAsyncSetVol,-35))return false;
        named("Alone In The Dark");w(22,0);if(!call(aitdProbeAsyncInfo))return false;
        if(!call(aitdProbeInfo,0,false) || get(12))return false;
        named("Alone In The Dark");if(!call(aitdProbeAsyncHInfo))return false;
        w(22,0x1234);if(!call(aitdProbeAsyncHInfo,-35))return false;
        l(18,0);w(22,0);w(26,0);if(!call(aitdProbeAsyncGetWD))return false;
        w(22,0x1234);if(!call(aitdProbeAsyncGetWD,-35))return false;
        l(18,0);w(22,0);w(24,0);w(28,1);if(!call(aitdProbeAsyncFCB))return false;
        w(24,0);w(28,0);if(!call(aitdProbeAsyncFCB,-51))return false;
        l(18,0);w(22,0xffff);l(48,3);l(28,0x41495444);if(!call(aitdProbeAsyncOpenWD))return false;
        if(!call(aitdProbeAsyncCloseWD,0,false) || !get(12))return false;
        if(!call(aitdProbeCloseWD,0,false) || !get(12))return false;
        l(18,0);w(22,0xffff);l(48,2);if(!call(aitdProbeAsyncOpenWD))return false;
        if(!call(aitdProbeAsyncCloseWD))return false;
        named(":Alone Data:");l(28,0x41495444);if(!call(aitdProbeAsyncOpenWD))return false;
        if(!call(aitdProbeAsyncCloseWD))return false;
        if(!call(aitdProbeAsyncCloseWD,-51))return false;
        l(18,0);w(22,0x1234);l(48,3);if(!call(aitdProbeAsyncOpenWD,-35))return false;
        named(":Alone Saved Games:.async-probe");
        // OpenWD left its process ID in bytes 28..31. Async PBHCreate has
        // the same version byte at 31 as its synchronous counterpart.
        pb[31]=0;if(!call(aitdProbeAsyncCreate))return false;
        named(":Alone Saved Games:.async-probe");if(!call(aitdProbeAsyncCreate,-48))return false;
        named(":Alone Saved Games:.async-probe");if(!call(aitdProbeAsyncHInfo))return false;
        named(":Alone Saved Games:.async-probe");l(32,0x54455354);l(36,0x41495444);if(!call(aitdProbeAsyncSetInfo))return false;
        named(":Alone Saved Games:.async-probe");if(!call(aitdProbeAsyncHInfo) || get(32)!=0x54455354 || get(36)!=0x41495444)return false;
        named(":Alone Saved Games:.async-probe");w(22,0x1234);if(!call(aitdProbeAsyncSetInfo,-35))return false;
        named(":Alone Saved Games:.async-probe");pb[27]=1;if(!call(aitdProbeAsyncOpenRF))return false;
        if(!call(aitdProbeClose,0,false) || get(12))return false;
        named(":Alone Saved Games:.async-probe");w(22,0x1234);pb[27]=1;if(!call(aitdProbeAsyncOpenRF,-35))return false;
        named(":Alone Saved Games:.async-probe");if(!call(aitdProbeHDelete,0,false) || get(12))return false;
        l(18,0);w(22,0xffff);if(!call(aitdProbeFlush,0,false) || get(12))return false;
    }
    g_fileAsyncNested=1;l(18,0);if(!call(aitdProbeAsyncRegisters) || !g_fileAsyncNestedOK || g_fileAsyncA5!=0x12345678)return false;
    g_fileAsyncNested=0;return true;
}
#endif
