#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
extern volatile uint32_t g_volumeBackingProbe[6];
volatile uint32_t g_fileVInfoProbeStep=0;
int32_t aitdProbeHGetVInfo(void*),aitdProbeHSetVol(void*),aitdProbeOpenWD(void*),aitdProbeGetWD(void*);
}
static uint8_t pb[128] __attribute__((aligned(4))),name[64];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static bool result(int32_t value,int16_t wanted=0) {
    return value==wanted && (int16_t)(get(16)>>16)==wanted && (g_fileProbeCCR&15)==(wanted<0 ? 8 : 4);
}
static bool query(int16_t index,int16_t ref,const char* text,uint16_t valence,int16_t wanted=0) {
    for(uint16_t i=0;i<128;++i)pb[i]=0xcc;
    for(uint16_t i=0;i<64;++i)name[i]=0xcc;
    if(text) { uint16_t n=0;while(text[n]) { name[n+1]=text[n];++n; }name[0]=n; }
    l(12,0);l(18,text ? (uint32_t)name : 0);w(22,ref);w(28,index);
    if(!result(aitdProbeHGetVInfo(pb),wanted))return false;
    if(wanted) {
        if((int16_t)(get(22)>>16)!=(index>0 ? 0 : ref))return false;
        for(uint16_t i=30;i<128;++i)if(pb[i]!=0xcc)return false;
        if(text) { uint16_t n=0;while(text[n]) { if(name[n+1]!=text[n])return false;++n; }if(name[0]!=n)return false; }
        return true;
    }
    uint32_t total=g_volumeBackingProbe[0],used=g_volumeBackingProbe[1],size=g_volumeBackingProbe[2],group=1;
    while(total/group>65535) { group*=2;size*=2; }
    if((get(22)>>16)!=65535 || get(30)!=g_volumeBackingProbe[3] || get(34)!=g_volumeBackingProbe[4]
        || (get(38)>>16)!=(g_volumeBackingProbe[5] ? 0x80 : 0) || (get(40)>>16)!=valence
        || get(42) || (get(46)>>16)!=total/group || get(48)!=size || get(52)!=size || (get(56)>>16)
        || get(58)<=49 || (get(62)>>16)!=(total-used)/group || (get(64)>>16)!=0x4244
        || (get(66)>>16)!=1 || (get(68)>>16)!=65535 || (get(70)>>16) || get(72) || (get(76)>>16)
        || get(78) || get(82)!=43 || get(86)!=5 || get(90)!=4 || get(94) || get(98)!=3)return false;
    for(uint16_t i=102;i<122;++i)if(pb[i])return false;
    for(uint16_t i=122;i<128;++i)if(pb[i]!=0xcc)return false;
    if(text && (name[0]!=5 || name[1]!='A' || name[2]!='l' || name[3]!='o' || name[4]!='n' || name[5]!='e'))return false;
    return true;
}
extern "C" bool aitdFileVInfoProbe() {
    g_fileVInfoProbeStep=1;l(18,0);w(22,0xffff);l(48,3);
    if(!result(aitdProbeHSetVol(pb)))return false;
    g_fileVInfoProbeStep=2;if(!query(0,-1,0,0))return false;
    g_fileVInfoProbeStep=3;if(!query(0,0,0,5))return false;
    g_fileVInfoProbeStep=4;if(!query(0,-32000,0,5))return false;
    g_fileVInfoProbeStep=5;if(!query(0,1,0,0) || !query(0,2,0,0,-35))return false;
    g_fileVInfoProbeStep=6;if(!query(0,0x1234,0,0,-35))return false;
    g_fileVInfoProbeStep=7;if(!query(1,0x1234,"ignored",0) || !query(2,-1,"ignored",0,-35))return false;
    g_fileVInfoProbeStep=8;if(!query(0,-1,"ignored",0))return false;
    g_fileVInfoProbeStep=9;if(!query(-1,0x1234,"Alone",0,-35) || !query(-1,0x1234,"Alone:",0))return false;
    g_fileVInfoProbeStep=10;if(!query(-1,-1,"Absent:",0,-35) || !query(-1,0,"ignored",5))return false;
    // Both original callers consume ioVFndrInfo[0] as a real System directory ID.
    g_fileVInfoProbeStep=11;l(48,get(90));l(18,0);w(22,0xffff);l(28,0x4552494b);
    if(!result(aitdProbeOpenWD(pb)) || (int16_t)(get(22)>>16)>=-1)return false;
    w(26,0);if(!result(aitdProbeGetWD(pb)) || get(48)!=4 || get(28)!=0x4552494b)return false;
    g_fileVInfoProbeStep=12;return true;
}
#endif
