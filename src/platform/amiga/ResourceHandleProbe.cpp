#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_systemWindows;
volatile uint32_t g_resourceHandleStep=0,g_resourceHandleHash=0;
uint8_t** aitdProbe1Resource(uint32_t,int32_t),**aitdProbeNamed(uint32_t,const uint8_t*);
void aitdProbeResInfo(uint8_t**,uint16_t*,uint32_t*,uint8_t*),aitdProbeResLoad(uint32_t);
void aitdProbeLoadResource(uint8_t**),aitdProbeEmptyResource(uint8_t**),aitdProbeDetachResource(uint8_t**),aitdProbeReleaseResource(uint8_t**);
}
extern "C" bool aitdResourceHandleProbe() {
    const uint32_t start=g_systemWindows,reads=g_resourceRuntimeReads,bytes=g_resourceRuntimeBytes;
    uint8_t** general=aitdProbe1Resource(0x53545223,128),**other=0;
    if(!general || !*general)return false;
    const uint8_t label[]={14,'E','r','r','o','r',' ','M','e','s','s','a','g','e','s'};
    const uint8_t generalName[]={7,'G','e','n','e','r','a','l'};
    uint32_t loaded=1;uint8_t* detached=0;
    for(uint16_t n=1;n<=18;++n) {
        g_resourceHandleStep=n;
        uint16_t id=0xcccc;uint32_t type=0xcccccccc;uint8_t name[20];
        for(uint16_t i=0;i<20;++i)name[i]=0xcc;
        g_macLowMemory[140]=0x88;g_macLowMemory[141]=0x88;
        switch(n) {
        case 1:aitdProbeResInfo(general,&id,&type,name);break;
        case 2:aitdProbeResInfo(0,&id,&type,name);break;
        case 3:aitdProbeResLoad(0);break;
        case 4:other=aitdProbe1Resource(0x53545223,2001);if(!other || other==general)return false;break;
        case 5:if(aitdProbeNamed(0x53545223,label)!=other)return false;break;
        case 6:case 8:case 10:case 16:aitdProbeResInfo(other,&id,&type,name);break;
        case 7:case 11:aitdProbeLoadResource(other);++loaded;break;
        case 9:case 13:aitdProbeEmptyResource(other);break;
        case 12:aitdProbeResLoad(1);break;
        case 14:if(aitdProbe1Resource(0x53545223,2001)!=other)return false;++loaded;break;
        case 15:detached=*other;aitdProbeDetachResource(other);break;
        case 17:aitdProbeLoadResource(other);break;
        case 18:aitdProbeReleaseResource(0);break;
        }
        const uint16_t err=n==2 || n==16 || n==18 ? 0xff40 : n==3 || n==9 || n==12 || n==13 ? 0x8888 : 0;
        const uint32_t d0=n==3 || n==5 || n==7 || n==11 || n==12 || n==17 || n==18 ? 0x12345678 : n==2 || n==16 ? 0xff40 : 0;
        if(((uint16_t)g_macLowMemory[140]<<8|g_macLowMemory[141])!=err || g_resourceLookupD0!=d0
            || g_macLowMemory[60]!=(n<=2 ? 0xff : n<12 ? 0 : 1))return false;
        if(g_systemWindows!=start+loaded || g_resourceRuntimeReads!=reads+loaded
            || g_resourceRuntimeBytes!=bytes+612+251*(loaded-1))return false;
        bool empty=n==4 || n==5 || n==6 || n==9 || n==10 || n==13;
        if(other && ((!*other)!=empty || (detached && *other!=detached)))return false;
        const uint8_t* expected=0;uint16_t wantedID=0xcccc;uint32_t wantedType=0xcccccccc;
        static const uint8_t emptyName[]={0};
        if(n==1) { expected=generalName;wantedID=128;wantedType=0x53545223; }
        if(n==6 || n==8 || n==10) { expected=label;wantedID=2001;wantedType=0x53545223; }
        if(n==2 || n==16) { expected=emptyName;wantedID=0xffff;wantedType=0; }
        if(id!=wantedID || type!=wantedType)return false;
        for(uint16_t i=0;i<20;++i)if(name[i]!=(expected && i<=expected[0] ? expected[i] : 0xcc))return false;
        if(n==11 || n==14 || n==18) {
            uint32_t hash=2166136261UL;
            for(uint16_t i=0;i<251;++i)hash=(hash^(*other)[i])*16777619UL;
            g_resourceHandleHash=hash;if(hash!=0x20ac017e)return false;
        }
    }
    g_resourceHandleStep=19;return true;
}
#endif
