#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
volatile uint32_t g_resourceLookupStep=0,g_resourceLookupD0=0,g_resourceLookupHash=0;
uint8_t** aitdProbeNamed(uint32_t,const uint8_t*),**aitdProbe1Named(uint32_t,const uint8_t*);
uint8_t** aitdProbeResource(uint32_t,int32_t),**aitdProbe1Resource(uint32_t,int32_t);
}
static const struct { const char* name;uint32_t type;int16_t id;uint8_t mode,kind; } cases[]={
    {"General",0x53545223,0,0,1},{"general",0x53545223,0,0,1},{"GENERAL",0x53545223,0,0,1},
    {"G\216neral",0x53545223,0,0,0},{"Absent AITD resource",0x53545223,0,0,0},
    {"General",0x73747223,0,0,0},{"",0x53545253,0,0,0},{"Error Messages",0x53545223,0,0,2},
    {"General",0x53545223,0,1,1},{"Absent AITD resource",0x53545223,0,1,0},
    {0,0x53545223,128,2,1},{0,0x53545223,32767,2,0},{0,0x53545223,128,2,1},
    {0,0x53545223,0,2,0},{0,0x53545223,-32768,2,0},{0,0x51515151,128,2,0},
    {0,0x53545223,32767,3,0},{0,0x51515151,128,3,0},{"",0x53545253,0,1,0},
    {0,0x53545223,128,2,1}
};
extern "C" bool aitdResourceLookupProbe() {
    uint8_t name[64];uint8_t** general=0;
    for(uint16_t i=0;i<sizeof(cases)/sizeof(cases[0]);++i) {
        g_resourceLookupStep=i+1;const auto& q=cases[i];uint16_t length=0;
        if(q.name)while(q.name[length]) { name[length+1]=q.name[length];++length; }name[0]=length;
        g_macLowMemory[140]=0x88;g_macLowMemory[141]=0x88;
        uint8_t** result=q.mode==0 ? aitdProbe1Named(q.type,name) : q.mode==1 ? aitdProbeNamed(q.type,name)
            : q.mode==2 ? aitdProbe1Resource(q.type,q.id) : aitdProbeResource(q.type,q.id);
        uint16_t wanted=q.mode<2 && !q.kind ? 0xff40 : 0;
        if(((uint16_t)g_macLowMemory[140]<<8|g_macLowMemory[141])!=wanted
            || g_resourceLookupD0!=(q.mode==1 ? 0x12345678UL : wanted))return false;
        if(!i)general=result;
        if(q.kind && (!result || !*result))return false;
        if((q.kind==1 && result!=general) || (q.kind==2 && result==general) || (!q.kind && result))return false;
    }
    uint32_t hash=2166136261UL;
    for(uint32_t i=0;i<612;++i)hash=(hash^(*general)[i])*16777619UL;
    g_resourceLookupHash=hash;g_resourceLookupStep=21;return true;
}
#endif
