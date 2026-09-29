#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileOpenDFProbeStep=0;
int32_t aitdProbeHSetVol(void*);
int32_t aitdProbeOpenDF(void*),aitdProbeHOpenDF(void*);
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
static int32_t openDF(bool hierarchical=false) {
    if(!hierarchical)w(22,0);
    return hierarchical ? aitdProbeHOpenDF(pb) : aitdProbeOpenDF(pb);
}
extern "C" bool aitdFileOpenDFProbe() {
    static uint8_t data[]={0x12,0x34,0x56,0x78};
    const char* scratch=".opendf-probe";
    g_fileOpenDFProbeStep=1;named(scratch);l(18,0);
    if(!result(aitdProbeHSetVol(pb)))return false;named(scratch);if(!result(aitdProbeHCreate(pb)))return false;
    named(scratch,6,3);if(!result(openDF()))return false;
    int16_t ref=get(24)>>16;uint32_t fileID=0;
    if(!transfer(ref,true,data,4) || !close(ref))return false;
    for(uint16_t alias=0;alias<2;++alias)for(uint8_t permission=0;permission<=4;++permission) {
        g_fileOpenDFProbeStep=2+alias*5+permission;
        named(scratch,6,permission);
        if(!result(openDF(alias)))return false;
        ref=get(24)>>16;
        if(!flags(ref,permission==1 ? 0 : permission==4 ? 0x1100 : 0x100,4,0))return false;
        if(!alias && !permission)fileID=get(32);
        if(permission==1) {
            if(!transfer(ref,false,bytes,4))return false;
            for(uint16_t i=0;i<4;++i)if(bytes[i]!=data[i])return false;
        }
        if(!close(ref))return false;
    }
    g_fileOpenDFProbeStep=12;named(scratch,6,3);
    if(!result(openDF()))return false;ref=get(24)>>16;
    named(scratch,6,3);w(24,0);
    if(!result(openDF(true),-49) || (get(24)>>16)!=(uint16_t)ref || !close(ref))return false;
    g_fileOpenDFProbeStep=13;named(scratch,6,4);
    if(!result(openDF()))return false;ref=get(24)>>16;
    named(scratch,6,4);if(!result(openDF(true)))return false;int16_t second=get(24)>>16;
    if(second==ref || !transfer(ref,false,bytes,4) || !flags(second,0x1100,4,0))return false;
    for(uint16_t i=0;i<4;++i)if(bytes[i]!=data[i])return false;
    if(!close(second) || !close(ref))return false;
    g_fileOpenDFProbeStep=14;named(scratch,0x9999,1);
    if(!result(openDF()) || !close(get(24)>>16))return false;
    named(scratch,0x9999,1);w(24,0x1234);
    if(!result(openDF(true),-43) || (get(24)>>16))return false;
    named(":.opendf-probe",0x9999,1);w(24,0x1234);
    if(!result(aitdProbeHOpen(pb),-43) || (get(24)>>16))return false;
    named(scratch,0x9999,1);w(24,0x1234);
    if(!result(aitdProbeHOpenRF(pb),-43) || (get(24)>>16))return false;
    named(scratch,fileID,1);w(24,0x1234);
    if(!result(openDF(true),-43) || (get(24)>>16))return false;
    named(":.opendf-probe:child",6,1);w(24,0x1234);
    if(!result(openDF(true),-43) || (get(24)>>16))return false;
    named(":Absent:child",6,1);w(24,0x1234);
    if(!result(openDF(true),-120) || (get(24)>>16))return false;
    named(scratch,6,1);w(22,0x1234);w(24,0x1234);if(!result(openDF(true),-35) || (get(24)>>16))return false;
    g_fileOpenDFProbeStep=15;
    for(uint8_t permission=0;permission<=4;++permission) {
        named("::Alone Data:locked-probe.bin",7,permission);w(24,0);
        if(!result(openDF(),permission<2 ? 0 : -54))return false;
        if(permission<2 && !close(get(24)>>16))return false;
    }
    g_fileOpenDFProbeStep=16;named(scratch);if(!result(aitdProbeHDelete(pb)))return false;
    named(scratch,6,1);w(24,0x1234);if(!result(openDF(),-43) || (get(24)>>16))return false;
    g_fileOpenDFProbeStep=17;return true;
}
#endif
