#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileInstalledProbeStep=0;
int32_t aitdProbeHInfo(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),name[256];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
extern "C" bool aitdFileInstalledProbe() {
    // Measured original StuffIt headers; timestamps retain their raw Mac values.
    static const char* paths[]={"Alone In The Dark",":Alone Data:Camera00.PAK",":Alone Data:ITD_Ress.PAK",":Alone Data:Present.PAK"};
    static const uint32_t created[]={0xaae67ed8,0xa701add8,0xa7c501ba,0xa7393b8c};
    static const uint32_t modified[]={0xaae68edd,0xa701add8,0xaa77d6fb,0xa7393b8c};
    static const uint32_t sizes[]={0,142907,362108,267190};
    for(uint16_t i=0;i<4;++i) {
        g_fileInstalledProbeStep=i+1;
        uint16_t n=0;while(paths[i][n]) { name[n+1]=paths[i][n];++n; }name[0]=n;
        l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,3);
        if(aitdProbeHInfo(pb) || (get(16)>>16) || (g_fileProbeCCR&15)!=4
            || get(32)!=(i ? 0x44415441UL : 0x4150504cUL) || get(36)!=0x41495444
            || get(40)!=(i ? 0x01000000UL : 0x25000000UL) || get(44)
            || get(72)!=created[i] || get(76)!=modified[i] || get(54)!=sizes[i]
            || get(64)!=(i ? 0UL : 1424934UL) || pb[30]!=(i ? 0 : 0x84))return false;
    }
    g_fileInstalledProbeStep=5;return true;
}
#endif
