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
    static const char* paths[]={"Alone In The Dark",":Alone Data:Camera00.PAK",":Alone Data:ITD_Ress.PAK",":Alone Data:Present.PAK",":Alone Data:ListBod2.PAK","Quick Reference","Register Triple A Pack"};
    static const uint32_t created[]={0xaae67ed8,0xa701add8,0xa7c501ba,0xa7393b8c,0xa7c516c2,0xaae3108a,0xaaf6b2bb};
    static const uint32_t modified[]={0xaae68edd,0xa701add8,0xaa77d6fb,0xa7393b8c,0xaa77ec13,0xac99c8dc,0xac99c817};
    static const uint32_t sizes[]={0,142907,362108,267190,268430,4973,0};
    static const uint32_t resources[]={1424934,0,0,0,0,712,87427};
    static const uint32_t types[]={0x4150504c,0x44415441,0x44415441,0x44415441,0x44415441,0x7474726f,0x4150504c};
    static const uint32_t creators[]={0x41495444,0x41495444,0x41495444,0x41495444,0x41495444,0x74747874,0x65726352};
    static const uint32_t flags[]={0x25000000,0x01000000,0x01000000,0x01000000,0x01000000,0x01000000,0x21000000};
    for(uint16_t i=0;i<7;++i) {
        g_fileInstalledProbeStep=i+1;
        uint16_t n=0;while(paths[i][n]) { name[n+1]=paths[i][n];++n; }name[0]=n;
        l(18,(uint32_t)name);w(22,0xffff);w(28,0);l(48,3);
        if(aitdProbeHInfo(pb) || (get(16)>>16) || (g_fileProbeCCR&15)!=4
            || get(32)!=types[i] || get(36)!=creators[i]
            || get(40)!=flags[i] || get(44)
            || get(72)!=created[i] || get(76)!=modified[i] || get(54)!=sizes[i]
            || get(64)!=resources[i] || pb[30]!=(i ? 0 : 0x84))return false;
    }
    g_fileInstalledProbeStep=8;
    static const uint16_t order[]={0,5,6};
    for(uint16_t i=0;i<3;++i) {
        l(48,3);w(28,i+1);
        if(aitdProbeHInfo(pb) || (get(16)>>16) || (g_fileProbeCCR&15)!=4
            || get(54)!=sizes[order[i]] || get(64)!=resources[order[i]])return false;
        const char* expected=paths[order[i]];uint16_t n=0;
        while(expected[n]) { if(name[n+1]!=expected[n])return false;++n; }
        if(name[0]!=n)return false;
    }
    g_fileInstalledProbeStep=9;l(48,3);w(28,4);
    if(aitdProbeHInfo(pb)!=-43 || (int16_t)(get(16)>>16)!=-43 || (g_fileProbeCCR&15)!=8)return false;
    const char* missing="AITD Absent Namespace Probe";uint16_t n=0;
    while(missing[n]) { name[n+1]=missing[n];++n; }name[0]=n;
    l(48,3);w(28,0);
    if(aitdProbeHInfo(pb)!=-43 || (int16_t)(get(16)>>16)!=-43 || (g_fileProbeCCR&15)!=8)return false;
    g_fileInstalledProbeStep=10;return true;
}
#endif
