#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
__attribute__((noinline)) void aitdResourceFilesPersisted() { __asm__ volatile("" ::: "memory"); }
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_systemWindows;
volatile uint32_t g_resourceFileStep=0,g_resourceFileStackError=0,g_resourceFileWindows=0,g_resourceFileResult=0;
uint32_t aitdRFileCall(void(*)(),const uint8_t*,uint32_t,uint32_t);
void aitdRFileCur(),aitdRFileUse(),aitdRFileOpen(),aitdRFilePerm(),aitdRFileHOpen(),aitdRFileCreate(),aitdRFileHCreate(),aitdRFileUpdate(),aitdRFileClose(),aitdRFileAdd();
uint8_t** aitdRFileAllocate();
int32_t aitdProbeCreate(void*),aitdProbeDelete(void*);
uint32_t aitdProbeCountResources(uint32_t),aitdProbeCount1Resources(uint32_t);
uint8_t** aitdProbeResource(uint32_t,int32_t),**aitdProbe1Resource(uint32_t,int32_t),**aitdProbeNamed(uint32_t,const uint8_t*);
}
static void w(uint8_t* p,uint16_t v) { p[0]=v>>8;p[1]=v; }
static void l(uint8_t* p,uint32_t v) { w(p,v>>16);w(p+2,v); }
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static const uint8_t nameA[]="\043:Alone Saved Games:Resource Probe A",nameB[]="\043:Alone Saved Games:Resource Probe B",general[]="\007General";
static uint32_t named(void(*trap)(),const uint8_t* name,uint32_t size=4,uint32_t result=0) {
    uint8_t args[14]={};l(args,name ? (uint32_t)name : 0);return aitdRFileCall(trap,args,size,result);
}
static uint32_t refcall(void(*trap)(),int16_t ref) { uint8_t args[2];w(args,ref);return aitdRFileCall(trap,args,2,0); }
static uint32_t current() { return aitdRFileCall(aitdRFileCur,0,0,2); }
static uint32_t file(bool create,const uint8_t* name) {
    uint8_t pb[80]={};l(pb+18,(uint32_t)name);int32_t result=create ? aitdProbeCreate(pb) : aitdProbeDelete(pb);
    g_resourceLookupD0=result;return result;
}
static uint32_t add(uint8_t** handle,uint32_t type,int16_t id) {
    uint8_t args[14];l(args,(uint32_t)general);w(args+4,id);l(args+6,type);l(args+10,(uint32_t)handle);
    return aitdRFileCall(aitdRFileAdd,args,14,0);
}
extern "C" bool aitdResourceFileProbe() {
    uint32_t start=g_systemWindows,baseline=0,app=0,a=0,b=0,value=0;uint8_t** handles[6]={},**found=0;
    for(uint16_t n=1;n<=63;++n) {
        g_resourceFileStep=n;g_resourceFileStackError=0;g_macLowMemory[140]=g_macLowMemory[141]=0x88;
        value=0;found=0;uint32_t expected=0;bool compare=false;
        switch(n) {
        case 1:app=value=current();break;
        case 2:baseline=value=aitdProbeCountResources(0x53545223);break;
        case 3:value=aitdProbeCountResources(0x52505242);compare=true;break;
        case 4:case 17:value=file(true,n==4 ? nameA : nameB);compare=true;break;
        case 5:value=named(aitdRFileCreate,nameA);compare=true;break;
        case 6:a=value=named(aitdRFileOpen,nameA,4,2);if(a==0xffff || a==app)return false;break;
        case 7:case 38:case 51:case 54:value=current();expected=a;compare=true;break;
        case 8:value=aitdProbeCount1Resources(0x52505242);compare=true;break;
        case 9:case 11:case 13:case 21:case 23:case 25: {
            uint16_t i=n<15 ? (n-9)/2 : 3+(n-21)/2;handles[i]=aitdRFileAllocate();
            if(!handles[i] || !*handles[i])return false;
            for(uint16_t j=0;j<i;++j)if(handles[i]==handles[j])return false;
            const uint32_t bytes[]={0x41414141,0x37373737,0x31313131,0x42424242,0x32323232,0x77777777};l(*handles[i],bytes[i]);break;
        }
        case 10:case 12:case 14:case 22:case 24:case 26: {
            uint16_t i=n<15 ? (n-10)/2 : 3+(n-22)/2;const uint16_t ids[]={128,7,1,128,2,7};
            value=add(handles[i],i==0 || i==3 ? 0x53545223 : 0x52505242,ids[i]);compare=true;break;
        }
        case 15:case 27:value=refcall(aitdRFileUpdate,n==15 ? a : b);compare=true;break;
        case 16:value=named(aitdRFileOpen,nameA,4,2);expected=a;compare=true;break;
        case 18:value=named(aitdRFileHCreate,nameB,10);compare=true;break;
        case 19: { uint8_t args[8]={};args[0]=3;l(args+4,(uint32_t)nameB);b=value=aitdRFileCall(aitdRFilePerm,args,8,2);if(b==a || b==app || b==0xffff)return false;break; }
        case 20:value=current();expected=b;compare=true;break;
        case 28:value=aitdProbeCountResources(0x53545223);expected=baseline+2;compare=true;break;
        case 29:value=aitdProbeCount1Resources(0x53545223);expected=1;compare=true;break;
        case 30:case 39:case 45:value=aitdProbeCountResources(0x52505242);expected=4;compare=true;break;
        case 31:value=aitdProbeCount1Resources(0x52505242);expected=2;compare=true;break;
        case 32:case 40:case 46:case 52:found=aitdProbeResource(0x53545223,128);break;
        case 33:case 58:found=aitdProbe1Resource(0x53545223,128);break;
        case 34:found=aitdProbeResource(0x52505242,1);break;
        case 35:found=aitdProbe1Resource(0x52505242,1);compare=true;break;
        case 36:case 42:found=aitdProbeNamed(0x53545223,general);break;
        case 37:case 43:case 47:case 49:value=refcall(aitdRFileUse,n==37 ? a : n==43 ? app : n==47 ? 0x1234 : b);compare=true;break;
        case 41:found=aitdProbeResource(0x52505242,2);compare=true;break;
        case 44:case 48:case 56:case 63:value=current();expected=app;compare=true;break;
        case 50:case 53:case 55:case 59:value=refcall(aitdRFileClose,n<55 ? b : a);compare=true;break;
        case 57: { uint8_t args[12]={};args[0]=3;l(args+2,(uint32_t)nameA);a=value=aitdRFileCall(aitdRFileHOpen,args,12,2);if(a==0xffff)return false;break; }
        case 60:case 61:value=file(false,n==60 ? nameA : nameB);compare=true;break;
        case 62:value=named(aitdRFileOpen,nameA,4,2);expected=0xffff;compare=true;break;
        }
        if(n==59)aitdResourceFilesPersisted();
        g_resourceFileResult=value;
        const bool os=n==4 || n==17 || n==60 || n==61 || n==9 || n==11 || n==13 || n==21 || n==23 || n==25;
        const bool cur=n==1 || n==7 || n==20 || n==38 || n==44 || n==48 || n==51 || n==54 || n==56 || n==63;
        uint16_t error=os || cur ? 0x8888 : n==47 || n==53 ? 0xff3f : n==62 ? 0xffd5 : 0;
        uint32_t d0=cur || n==6 || n==15 || n==16 || n==27 || n==36 || n==42 || n==62 ? 0x12345678 : n==5 ? 4 : n==18 ? 10 : os ? 0 : error;
        if(g_resourceFileStackError || ((uint16_t)g_macLowMemory[140]<<8|g_macLowMemory[141])!=error || g_resourceLookupD0!=d0 || (compare && (value!=expected || found)))return false;
        uint32_t body=0;uint8_t** wanted=0;
        if(n==32 || n==33 || n==36) { body=0x42424242;wanted=handles[3]; }
        if(n==34) { body=0x31313131;wanted=handles[2]; }
        if(n==40 || n==42 || n==52) { body=0x41414141;wanted=handles[0]; }
        if(n==46)body=0x000e3d53; // Original General's first words; checked against original below.
        if(n==58)body=0x41414141;
        if(body && (!found || !*found || lng(*found)!=body || (wanted && found!=wanted)))return false;
    }
    g_resourceFileWindows=g_systemWindows-start;g_resourceFileStep=64;return true;
}
#endif
