#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_systemWindows;
volatile uint32_t g_resourceLifecycleStep=0,g_resourceLifecycleHash=0;
uint8_t** aitdProbe1Resource(uint32_t,int32_t);
void aitdProbeLoadResource(uint8_t**),aitdProbeEmptyResource(uint8_t**),aitdProbeDetachResource(uint8_t**),aitdProbeReleaseResource(uint8_t**);
void aitdProbeResState(uint8_t**,uint32_t),aitdProbeResLock(uint8_t**,uint32_t),aitdProbeResUnlock(uint8_t**,uint32_t),aitdProbeResHPurge(uint8_t**,uint32_t),aitdProbeResSetState(uint8_t**,uint32_t),aitdProbeResPurge(uint8_t**,uint32_t);
}
// Ordered System 7.5.5 results: ResErr, MemErr, D0, disk loads, residency.
// Residency 2 marks a disposed handle; do not dereference that slot.
static const struct { uint16_t error,memory;uint32_t d0;uint8_t loads,resident; } expected[]={
 {0,0,0,1,1},{0x8888,0,0x60,1,1},{0x8888,0xff94,0xffffff94,1,0},
 {0x8888,0xff93,0xffffff93,1,0},{0,0,0x12345678,2,1},{0x8888,0,0x60,2,1},
 {0x8888,0,0,2,1},{0x8888,0xff94,0xffffff94,2,1},{0x8888,0,0xe0,2,1},
 {0,0,0x12345678,2,2},{0,0,0,3,1},{0x8888,0,0,3,1},
 {0,0,0x12345678,3,2},{0,0,0,4,1},{0x8888,0,0,4,0},
 {0x8888,0xff93,0xffffff93,4,0},{0x8888,0xff93,0xffffff93,4,0},
 {0x8888,0xff93,0xffffff93,4,0},{0x8888,0xff93,0xffffff93,4,0},
 {0x8888,0xff93,0xffffff93,4,0},{0,0,0x12345678,4,2},{0,0,0,5,1},
 {0x8888,0,0,5,0},{0,0xff93,0,5,0},{0xff40,0x7777,0x12345678,5,0},
 {0xff40,0x7777,0x12345678,5,0},{0,0x7777,0x12345678,5,0},
 {0xff40,0x7777,0xff40,5,0}
};
extern "C" bool aitdResourceLifecycleProbe() {
    const uint32_t start=g_systemWindows,reads=g_resourceRuntimeReads,bytes=g_resourceRuntimeBytes;
    uint8_t** handle=0;
    for(uint16_t n=1;n<=28;++n) {
        g_resourceLifecycleStep=n;
        g_macLowMemory[140]=0x88;g_macLowMemory[141]=0x88;
        g_macLowMemory[100]=0x77;g_macLowMemory[101]=0x77;
        switch(n) {
        case 1:case 11:case 14:case 22:handle=aitdProbe1Resource(0x4352454c,13);if(!handle)return false;break;
        case 2:case 4:case 6:case 9:case 16:aitdProbeResState(handle,0x12345678);break;
        case 3:case 8:aitdProbeResPurge(handle,0xffffff);break;
        case 5:case 25:aitdProbeLoadResource(handle);break;
        case 7:case 17:aitdProbeResLock(handle,0x12345678);break;
        case 10:case 13:case 21:case 26:aitdProbeReleaseResource(handle);break;
        case 12:case 19:aitdProbeResUnlock(handle,0x12345678);break;
        case 15:case 23:aitdProbeEmptyResource(handle);break;
        case 18:aitdProbeResHPurge(handle,0x12345678);break;
        case 20:aitdProbeResSetState(handle,0xe0);break;
        case 24:aitdProbeDetachResource(handle);break;
        case 27:aitdProbeLoadResource(0);break;
        case 28:aitdProbeDetachResource(0);break;
        }
        const auto& q=expected[n-1];
        if(((uint16_t)g_macLowMemory[140]<<8|g_macLowMemory[141])!=q.error
            || ((uint16_t)g_macLowMemory[100]<<8|g_macLowMemory[101])!=q.memory
            || g_resourceLookupD0!=q.d0 || g_systemWindows!=start+q.loads
            || g_resourceRuntimeReads!=reads+q.loads || g_resourceRuntimeBytes!=bytes+1288*q.loads)return false;
        if(q.resident!=2 && bool(*handle)!=bool(q.resident))return false;
        if(q.resident==1) {
            uint32_t hash=2166136261UL;
            for(uint16_t i=0;i<1288;++i)hash=(hash^(*handle)[i])*16777619UL;
            g_resourceLifecycleHash=hash;if(hash!=0x8d35d0be)return false;
        }
    }
    g_resourceLifecycleStep=29;return true;
}
#endif
