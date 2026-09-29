#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern volatile uint16_t g_fileProbeCCR;
volatile uint32_t g_fileVolumeProbeStep=0;
int32_t aitdProbeVolParms(void*);
}
static uint8_t pb[80] __attribute__((aligned(4))),buffer[32],name[64];
static void w(uint16_t o,uint16_t v) { pb[o]=v>>8;pb[o+1]=v; }
static void l(uint16_t o,uint32_t v) { w(o,v>>16);w(o+2,v); }
static uint32_t get(uint16_t o) { return (uint32_t)pb[o]<<24|(uint32_t)pb[o+1]<<16|(uint32_t)pb[o+2]<<8|pb[o+3]; }
static bool query(uint32_t count,int16_t volume,const char* text,int16_t wanted=0,bool nullBuffer=false) {
    for(uint16_t i=0;i<32;++i)buffer[i]=0xcc;
    uint16_t length=0;
    if(text) { while(text[length]) { name[length+1]=text[length];++length; }name[0]=length; }
    l(18,text ? (uint32_t)name : 0);w(22,volume);l(32,nullBuffer ? 0 : (uint32_t)buffer);
    l(36,count);l(40,0xdeadbeef);
    if(aitdProbeVolParms(pb)!=wanted || (int16_t)(get(16)>>16)!=wanted
        || (g_fileProbeCCR&15)!=(wanted<0 ? 8 : 4))return false;
    uint32_t actual=wanted ? 0 : count<20 ? count : 20;
    if(get(40)!=(wanted ? 0xdeadbeefUL : actual))return false;
    for(uint16_t i=0;i<32;++i) {
        uint8_t expected=i>=actual ? 0xcc : i==1 ? 2 : i==4 ? 0x10 : i==5 ? 0xe0 : 0;
        if(buffer[i]!=expected)return false;
    }
    return true;
}
extern "C" bool aitdFileVolumeProbe() {
    for(uint16_t count=0;count<=32;++count) {
        g_fileVolumeProbeStep=count+1;if(!query(count,-1,0))return false;
    }
    g_fileVolumeProbeStep=34;
    if(!query(6,0,0) || !query(6,-32000,0) || !query(6,0x1234,0,-35)
        || !query(6,0x1234,"Alone",-35) || !query(6,0x1234,"Alone:")
        || !query(6,-1,"AITD Absent Volume") || !query(6,-1,"AITD Absent Volume:",-35)
        || !query(6,-1,"") || !query(6,-1,":ignored:") || !query(0,-1,0,0,true))return false;
    g_fileVolumeProbeStep=35;return true;
}
#endif
