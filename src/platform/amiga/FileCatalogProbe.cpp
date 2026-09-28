#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileCatalogProbeStep=0;
int32_t aitdProbeCreate(void*),aitdProbeHCreate(void*),aitdProbeDelete(void*),aitdProbeHDelete(void*);
int32_t aitdProbeInfo(void*),aitdProbeHInfo(void*),aitdProbeSetInfo(void*),aitdProbeHSetInfo(void*);
int32_t aitdProbeHSetVol(void*),aitdProbeOpen(void*),aitdProbeClose(void*),aitdProbeWrite(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),name[32];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static bool result(int32_t value,int16_t wanted=0) {
    return value==wanted && (int16_t)(get(16)>>16)==wanted
        && (g_fileProbeCCR&15)==(wanted<0 ? 8 : wanted==0 ? 4 : 0);
}
static void named(const char* text,uint32_t directory=6) {
    uint16_t n=0;while(text[n]) { name[n+1]=text[n];++n; }name[0]=n;
    l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,directory);pb[27]=0;
}
static void metadata(uint32_t modified=0xabcd0304) {
    l(32,0x54455354);l(36,0x41495444);l(40,0x04000012);l(44,0x00340000);
    l(72,0xabcd0102);l(76,modified);
}
static bool exact(uint8_t attributes,uint32_t modified=0xabcd0304) {
    return pb[30]==attributes && get(32)==0x54455354 && get(36)==0x41495444
        && get(40)==0x04000012 && get(44)==0x00340000 && get(72)==0xabcd0102
        && get(76)==modified && get(54)==0 && get(64)==0;
}
extern "C" bool aitdFileCatalogProbe() {
    g_fileCatalogProbeStep=1;named("catalog-probe.bin");
    if(!result(aitdProbeHCreate(pb)))return false;
    g_fileCatalogProbeStep=2;
    if(!result(aitdProbeHCreate(pb),-48))return false;
    g_fileCatalogProbeStep=3;
    if(!result(aitdProbeHInfo(pb)) || get(32) || get(36) || get(40) || get(44)
        || get(54) || get(64) || !get(72) || get(72)!=get(76))return false;
    uint32_t id=get(48);
    g_fileCatalogProbeStep=4;named("catalog-probe.bin");metadata();
    if(!result(aitdProbeHSetInfo(pb)))return false;
    named("catalog-probe.bin");if(!result(aitdProbeHInfo(pb)) || !exact(0) || get(48)!=id)return false;
    g_fileCatalogProbeStep=5;l(18,0);l(48,6);
    if(!result(aitdProbeHSetVol(pb)))return false;
    named("catalog-probe.bin");w(22,0);pb[27]=3;
    if(!result(aitdProbeOpen(pb)))return false;
    uint16_t ref=get(24)>>16;
    g_fileCatalogProbeStep=6;
    if(!result(aitdProbeInfo(pb)) || !exact(0x88) || (get(24)>>16)!=ref)return false;
    if(!result(aitdProbeDelete(pb),-47) || !result(aitdProbeClose(pb)))return false;
    g_fileCatalogProbeStep=7;
    if(!result(aitdProbeDelete(pb)) || !result(aitdProbeInfo(pb),-43) || !result(aitdProbeDelete(pb),-43))return false;
    g_fileCatalogProbeStep=8;pb[27]=0;
    if(!result(aitdProbeCreate(pb)) || !result(aitdProbeInfo(pb)) || get(48)==id
        || get(32) || get(36) || get(40) || get(44) || get(72)!=get(76))return false;
    named("catalog-probe.bin");if(!result(aitdProbeHDelete(pb)))return false;
    g_fileCatalogProbeStep=9;named("catalog-probe.bin",0x9999);
    if(!result(aitdProbeHCreate(pb),-120))return false;
    named("");w(22,0);if(!result(aitdProbeCreate(pb),-48))return false;
    // SetFInfo can change a locked file; Delete must still fail with fLckdErr.
    g_fileCatalogProbeStep=10;named("locked-probe.bin",7);metadata(0xabcd0506);
    if(!result(aitdProbeHSetInfo(pb)))return false;
    named("locked-probe.bin",7);
    if(!result(aitdProbeHInfo(pb)) || !exact(1,0xabcd0506))return false;
    named("locked-probe.bin",7);if(!result(aitdProbeHDelete(pb),-45))return false;
    // A host-seeded sidecar must have been decoded by normal startup enumeration.
    g_fileCatalogProbeStep=11;named("metadata-seed.bin");
    if(!result(aitdProbeHInfo(pb)) || !exact(0))return false;
    named("metadata-seed.bin");if(!result(aitdProbeHDelete(pb)))return false;
    // Leave one complete file for independent host-side durability verification.
    g_fileCatalogProbeStep=12;named("metadata-durable.bin");
    if(!result(aitdProbeHCreate(pb)))return false;
    metadata();if(!result(aitdProbeHSetInfo(pb)))return false;
    named("metadata-durable.bin");if(!result(aitdProbeHInfo(pb)) || !exact(0))return false;
    g_fileCatalogProbeStep=13;named("metadata-durable.bin");w(22,0);pb[27]=3;
    if(!result(aitdProbeOpen(pb)))return false;
    static uint8_t payload[]={0x12,0x34,0x56,0x78};
    ref=get(24)>>16;l(32,(uint32_t)payload);l(36,4);w(44,1);l(46,0);
    if(!result(aitdProbeWrite(pb)) || get(40)!=4)return false;
    named("metadata-durable.bin");
    if(!result(aitdProbeHInfo(pb)) || get(54)!=4 || get(76)!=0xabcd0304)return false;
    w(24,ref);if(!result(aitdProbeClose(pb)))return false;
    named("metadata-durable.bin");
    if(!result(aitdProbeHInfo(pb)) || get(54)!=4 || get(64) || get(72)!=0xabcd0102
        || get(76)==0xabcd0304 || !get(76) || get(32)!=0x54455354)return false;
    g_fileCatalogProbeStep=14;named("metadata-pref.bin",5);
    if(!result(aitdProbeHCreate(pb)))return false;
    named("metadata-pref.bin",5);
    if(!result(aitdProbeHInfo(pb)) || get(54) || get(64) || !get(72) || get(72)!=get(76))return false;
    named("metadata-pref.bin",5);if(!result(aitdProbeHDelete(pb)))return false;
    g_fileCatalogProbeStep=15;return true;
}
#endif
