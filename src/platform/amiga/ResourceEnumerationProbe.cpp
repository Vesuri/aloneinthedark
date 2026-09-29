#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_systemWindows;
volatile uint32_t g_resourceEnumerationStep=0,g_resourceEnumerationHash=0;
uint8_t** aitdProbe1IndResource(uint32_t,int32_t);
uint32_t aitdProbeCount1Resources(uint32_t),aitdProbeCountResources(uint32_t);
void aitdProbeResInfo(uint8_t**,uint16_t*,uint32_t*,uint8_t*),aitdProbeResLoad(uint32_t);
}
static void seedEnumeration() { ++g_resourceEnumerationStep;g_macLowMemory[140]=0x88;g_macLowMemory[141]=0x88; }
static bool enumerationResult(uint16_t error,uint32_t d0) {
    return ((uint16_t)g_macLowMemory[140]<<8|g_macLowMemory[141])==error && g_resourceLookupD0==d0;
}
extern "C" bool aitdResourceEnumerationProbe() {
    const uint32_t start=g_systemWindows,reads=g_resourceRuntimeReads,bytes=g_resourceRuntimeBytes;
    const uint32_t types[]={0x4352454c,0x4352454c,0x434f4445,0x53545253,0x51515151,0x51515151};
    const uint16_t counts[]={10,10,14,1,0,0};
    for(uint16_t i=0;i<6;++i) {
        seedEnumeration();uint32_t count=i==1 || i==5 ? aitdProbeCountResources(types[i]) : aitdProbeCount1Resources(types[i]);
        if(count!=counts[i] || !enumerationResult(0,0) || g_systemWindows!=start)return false;
    }
    seedEnumeration();aitdProbeResLoad(0);if(!enumerationResult(0x8888,0x12345678))return false;
    static const struct { uint32_t type;int16_t index,id;bool valid; } rows[]={
        {0x4352454c,0,0,false},{0x4352454c,-1,0,false},
        {0x4352454c,1,13,true},{0x4352454c,2,12,true},{0x4352454c,3,3,true},
        {0x4352454c,4,4,true},{0x4352454c,5,5,true},{0x4352454c,6,6,true},
        {0x4352454c,7,7,true},{0x4352454c,8,8,true},{0x4352454c,9,9,true},{0x4352454c,10,10,true},
        {0x4352454c,11,0,false},{0x4352454c,32767,0,false},{0x4352454c,-32768,0,false},{0x51515151,1,0,false},
        {0x434f4445,1,2,true},{0x434f4445,2,13,true},{0x434f4445,14,0,true},{0x53545253,1,0,true},
        {0x4352454c,1,13,true}
    };
    uint8_t** first=0;
    for(uint16_t i=0;i<21;++i) {
        const auto& q=rows[i];
        if(i==20) { seedEnumeration();aitdProbeResLoad(1);if(!enumerationResult(0x8888,0x12345678))return false; }
        seedEnumeration();auto handle=aitdProbe1IndResource(q.type,q.index);
        uint16_t error=q.valid ? 0 : 0xff40;
        if(bool(handle)!=q.valid || !enumerationResult(error,error))return false;
        if(i==2)first=handle;
        if(q.valid) {
            if(i<20 && q.type==0x4352454c && *handle)return false;
            if(i==20 && (handle!=first || !*handle))return false;
            uint16_t id=0xcccc;uint32_t type=0xcccccccc;uint8_t name[256];
            seedEnumeration();aitdProbeResInfo(handle,&id,&type,name);
            if(!enumerationResult(0,0) || id!=(uint16_t)q.id || type!=q.type)return false;
        }
        uint32_t loads=i==20 ? 1 : 0;
        if(g_systemWindows!=start+loads || g_resourceRuntimeReads!=reads+loads || g_resourceRuntimeBytes!=bytes+1288*loads)return false;
    }
    uint32_t hash=2166136261UL;
    for(uint16_t i=0;i<1288;++i)hash=(hash^(*first)[i])*16777619UL;
    g_resourceEnumerationHash=hash;
    if(g_resourceEnumerationStep!=44 || hash!=0x8d35d0be)return false;
    g_resourceEnumerationStep=45;return true;
}
#endif
