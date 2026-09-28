#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileIndexProbeStep=0;
int32_t aitdProbeHCreate(void*),aitdProbeHDelete(void*),aitdProbeHInfo(void*),aitdProbeInfo(void*);
int32_t aitdProbeOpenWD(void*),aitdProbeCloseWD(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),name[256];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static bool result(int32_t value,int16_t wanted=0) {
    return value==wanted && (int16_t)(get(16)>>16)==wanted && (g_fileProbeCCR&15)==(wanted<0 ? 8 : wanted==0 ? 4 : 0);
}
static void named(const char* text,uint32_t directory=6) {
    uint16_t n=0;while(text[n]) { name[n+1]=text[n];++n; }name[0]=n;
    l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,directory);pb[27]=0;
}
static bool equals(const char* text) {
    uint16_t n=0;while(text[n]) { if(name[n+1]!=text[n])return false;++n; }
    return name[0]==n;
}
extern "C" bool aitdFileIndexProbe() {
    static const char* created[]={"iZx","i_x","iAx","i0x","i`x"};
    static const char* sorted[]={"fork-durable.bin","i0x","iAx","i`x","iZx","i_x","metadata-durable.bin"};
    g_fileIndexProbeStep=1;
    for(uint16_t i=0;i<5;++i) { named(created[i]);if(!result(aitdProbeHCreate(pb)))return false; }
    g_fileIndexProbeStep=2;
    for(uint16_t i=0;i<7;++i) {
        named("ignored");w(28,i+1);
        if(!result(aitdProbeHInfo(pb)) || !equals(sorted[i]) || pb[30])return false;
    }
    g_fileIndexProbeStep=3;named("ignored");w(28,8);
    if(!result(aitdProbeHInfo(pb),-43) || !equals("ignored"))return false;
    named("ignored");w(28,0x7fff);if(!result(aitdProbeHInfo(pb),-43))return false;
    g_fileIndexProbeStep=4;named("ignored");w(28,3);l(18,0);
    if(!result(aitdProbeHInfo(pb)) || !equals("ignored"))return false;
    uint32_t fileID=get(48);
    named("iAx");w(28,0xffff);
    if(!result(aitdProbeHInfo(pb)) || get(48)!=fileID || !equals("iAx"))return false;
    g_fileIndexProbeStep=5;named("ignored",0x9999);w(28,1);
    if(!result(aitdProbeHInfo(pb),-43))return false;
    named("ignored");w(28,1);w(22,0x1234);if(!result(aitdProbeHInfo(pb),-35))return false;
    g_fileIndexProbeStep=6;named("ignored",0x9999);w(28,2);w(22,0);
    if(!result(aitdProbeInfo(pb)) || !equals("i0x"))return false;
    g_fileIndexProbeStep=7;named("");l(18,0);l(28,0x41495444);
    if(!result(aitdProbeOpenWD(pb)))return false;int16_t wd=get(20)&65535;
    named("ignored",0x9999);w(22,wd);w(28,1);
    if(!result(aitdProbeHInfo(pb),-43) || !result(aitdProbeCloseWD(pb)))return false;
    g_fileIndexProbeStep=8;
    for(uint16_t i=0;i<5;++i) { named(created[i]);if(!result(aitdProbeHDelete(pb)))return false; }
    named("ignored");w(28,2);
    if(!result(aitdProbeHInfo(pb)) || !equals("metadata-durable.bin"))return false;
    g_fileIndexProbeStep=9;return true;
}
#endif
