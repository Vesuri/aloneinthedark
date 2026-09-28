#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileForkProbeStep=0;
int32_t aitdProbeHCreate(void*),aitdProbeHDelete(void*),aitdProbeHInfo(void*),aitdProbeHOpen(void*);
int32_t aitdProbeOpenRF(void*),aitdProbeHOpenRF(void*),aitdProbeRead(void*),aitdProbeWrite(void*);
int32_t aitdProbeEOF(void*),aitdProbeFCB(void*),aitdProbeClose(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),name[32],bytes[16];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static bool result(int32_t value,int16_t wanted=0) {
    return value==wanted && (int16_t)(get(16)>>16)==wanted
        && (g_fileProbeCCR&15)==(wanted<0 ? 8 : wanted==0 ? 4 : 0);
}
static void named(const char* text,uint32_t directory=6,uint8_t permission=0) {
    uint16_t n=0;while(text[n]) { name[n+1]=text[n];++n; }name[0]=n;
    l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,directory);pb[27]=permission;
}
static bool transfer(int16_t ref,bool writing,uint8_t* data,uint32_t count) {
    w(24,ref);l(32,(uint32_t)data);l(36,count);w(44,1);l(46,0);
    return result(writing ? aitdProbeWrite(pb) : aitdProbeRead(pb)) && get(40)==count && get(46)==count;
}
static bool flags(int16_t ref,uint16_t bits,uint32_t length,uint32_t mark) {
    w(24,ref);l(18,0);w(28,0);
    return result(aitdProbeFCB(pb)) && (get(36)>>16)==bits && get(40)==length && get(48)==mark;
}
static bool close(int16_t ref) { w(24,ref);return result(aitdProbeClose(pb)); }
extern "C" bool aitdFileForkProbe() {
    static uint8_t data[]={0x12,0x34,0x56,0x78},resource[]={0xab,0xcd,0xef,1,0x23,0x45};
    g_fileForkProbeStep=1;named("fork-probe.bin");if(!result(aitdProbeHCreate(pb)))return false;
    named("fork-probe.bin",6,3);if(!result(aitdProbeHOpen(pb)))return false;
    int16_t df=get(24)>>16;
    g_fileForkProbeStep=2;named("fork-probe.bin",6,3);if(!result(aitdProbeHOpenRF(pb)))return false;
    int16_t rf=get(24)>>16;if(rf==df || !result(aitdProbeEOF(pb)) || get(28))return false;
    g_fileForkProbeStep=3;
    if(!transfer(df,true,data,4) || !transfer(rf,true,resource,6))return false;
    named("fork-probe.bin");
    if(!result(aitdProbeHInfo(pb)) || get(54)!=4 || get(64)!=6 || pb[30]!=0x8c)return false;
    if(!flags(df,0x8100,4,4) || !flags(rf,0x8300,6,6))return false;
    g_fileForkProbeStep=4;named("fork-probe.bin",6,1);w(22,0);
    if(!result(aitdProbeOpenRF(pb)))return false;int16_t reader=get(24)>>16;
    if(!transfer(reader,false,bytes,6))return false;
    for(uint16_t i=0;i<6;++i)if(bytes[i]!=resource[i])return false;
    if(!close(reader))return false;
    g_fileForkProbeStep=5;
    if(!close(df) || !flags(rf,0x8300,6,6) || !close(rf))return false;
    g_fileForkProbeStep=6;named("fork-probe.bin",6,1);
    if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
    if(!result(aitdProbeEOF(pb)) || get(28)!=6 || !transfer(rf,false,bytes,6))return false;
    for(uint16_t i=0;i<6;++i)if(bytes[i]!=resource[i])return false;
    if(!close(rf))return false;
    named("fork-probe.bin");if(!result(aitdProbeHInfo(pb)) || get(54)!=4 || get(64)!=6 || pb[30])return false;
    named("fork-probe.bin");if(!result(aitdProbeHDelete(pb)))return false;
    named("fork-probe.bin",6,1);if(!result(aitdProbeHOpenRF(pb),-43))return false;
    // Seeded physical resource bytes were enumerated, not preloaded, at startup.
    g_fileForkProbeStep=7;named("fork-seed.bin",6,1);
    if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
    if(!result(aitdProbeEOF(pb)) || get(28)!=6 || !transfer(rf,false,bytes,6))return false;
    for(uint16_t i=0;i<6;++i)if(bytes[i]!=resource[i])return false;
    if(!close(rf))return false;
    named("fork-seed.bin");if(!result(aitdProbeHDelete(pb)))return false;
    // The legacy application resource path must never become its data stream.
    g_fileForkProbeStep=8;named("Alone In The Dark",3,3);
    if(!result(aitdProbeHOpen(pb)))return false;df=get(24)>>16;
    if(!result(aitdProbeEOF(pb)) || get(28) || !transfer(df,true,data,4) || !close(df))return false;
    g_fileForkProbeStep=9;named("Alone In The Dark",3,1);
    if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
    if(!result(aitdProbeEOF(pb)) || get(28)!=1424934 || !transfer(rf,false,bytes,16))return false;
    // Original resource header bytes verified from the local release before this probe.
    static const uint8_t header[]={0,0,1,0,0,0x15,0xaa,0xa0,0,0x15,0xa9,0xa0,0,0,0x13,0x86};
    for(uint16_t i=0;i<16;++i)if(bytes[i]!=header[i])return false;
    if(!close(rf))return false;
    // Leave both complete fork files for independent host byte/durability checks.
    g_fileForkProbeStep=10;named("fork-durable.bin");if(!result(aitdProbeHCreate(pb)))return false;
    named("fork-durable.bin",6,3);if(!result(aitdProbeHOpen(pb)))return false;df=get(24)>>16;
    named("fork-durable.bin",6,3);if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
    if(!transfer(df,true,data,4) || !transfer(rf,true,resource,6) || !close(df) || !close(rf))return false;
    g_fileForkProbeStep=11;
    for(uint8_t permission=0;permission<=4;++permission) {
        named("fork-durable.bin",6,permission);
        if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
        if(!flags(rf,permission==1 ? 0x200 : permission==4 ? 0x1300 : 0x300,6,0) || !close(rf))return false;
    }
    g_fileForkProbeStep=12;named("fork-durable.bin",6,4);
    if(!result(aitdProbeHOpenRF(pb)))return false;rf=get(24)>>16;
    named("fork-durable.bin",6,4);if(!result(aitdProbeHOpenRF(pb)))return false;reader=get(24)>>16;
    if(reader==rf || !close(reader) || !close(rf))return false;
    g_fileForkProbeStep=13;
    for(uint8_t permission=0;permission<=4;++permission) {
        named("locked-probe.bin",7,permission);w(24,0);
        if(!result(aitdProbeHOpenRF(pb),permission<2 ? 0 : -54))return false;
        if(permission<2) { rf=get(24)>>16;if(!flags(rf,0x2200,0,0) || !close(rf))return false; }
    }
    g_fileForkProbeStep=14;return true;
}
#endif
