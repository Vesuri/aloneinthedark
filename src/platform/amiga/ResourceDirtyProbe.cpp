#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceFileStackError,g_systemWindows;
volatile uint32_t g_resourceDirtyStep=0,g_resourceDirtyValue=0,g_resourceDirtyError=0,g_resourceDirtyMemory=0,g_resourceDirtyWindows=0;
__attribute__((noinline)) void aitdResourceDirtyPersisted() { __asm__ volatile("" ::: "memory"); }
uint32_t aitdRFileCall(void(*)(),const uint8_t*,uint32_t,uint32_t);
uint8_t** aitdRFileAllocate();
int32_t aitdProbeCreate(void*),aitdProbeDelete(void*);
void aitdRFileCur(),aitdRFileUse(),aitdRFileOpen(),aitdRFileCreate(),aitdRFileUpdate(),aitdRFileClose(),aitdRFileAdd();
void aitdRMutChanged(),aitdRMutWrite(),aitdRMutRelease(),aitdRMutDetach(),aitdRMutAttrs(),aitdRMutLookup(),aitdRMutDispose(),aitdRMutEmpty(),aitdRMutLoad();
void aitdProbeResState(uint8_t**,uint32_t);
}
static void w(uint8_t* p,uint16_t v) { p[0]=v>>8;p[1]=v; }
static void l(uint8_t* p,uint32_t v) { w(p,v>>16);w(p+2,v); }
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static uint16_t word(const uint8_t* p) { return (uint16_t)p[0]<<8|p[1]; }
static const uint8_t nameA[]="\043:Alone Saved Games:Resource Dirty A",nameB[]="\043:Alone Saved Games:Resource Dirty B",resourceName[]="\007Scratch";
static uint32_t named(void(*trap)(),const uint8_t* name,uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)name);return aitdRFileCall(trap,a,4,result); }
static uint32_t refcall(void(*trap)(),uint16_t ref) { uint8_t a[2];w(a,ref);return aitdRFileCall(trap,a,2,0); }
static uint32_t hcall(void(*trap)(),uint8_t** h,uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)h);return aitdRFileCall(trap,a,4,result); }
static uint32_t file(bool create,const uint8_t* name) { uint8_t pb[80]={};l(pb+18,(uint32_t)name);int32_t e=create?aitdProbeCreate(pb):aitdProbeDelete(pb);g_resourceLookupD0=e;return e; }
static uint32_t add(uint8_t** h) { uint8_t a[14];l(a,(uint32_t)resourceName);w(a+4,128);l(a+6,0x4c494645);l(a+10,(uint32_t)h);return aitdRFileCall(aitdRFileAdd,a,14,0); }
static uint8_t** lookup() { uint8_t a[6];w(a,128);l(a+2,0x4c494645);return (uint8_t**)aitdRFileCall(aitdRMutLookup,a,6,4); }
struct Expected { uint16_t error,memory;uint32_t d0; };
static const Expected expected[]={
 {0x8888,0x7777,0x12345678}, // application
 {0x8888,0x7777,0x00000000}, // create-a
 {0x0000,0x7777,0x00000004}, // map-a
 {0x0000,0x0000,0x12345678}, // open-a
 {0x8888,0x0000,0x00000000}, // allocate-a
 {0x0000,0x0000,0x00000000}, // add-a
 {0x0000,0x0000,0x12345678}, // update-a
 {0x0000,0x0000,0x00000000}, // change-release
 {0x0000,0x7777,0x12345678}, // release-dirty
 {0x0000,0x7777,0x00000000}, // lookup-released
 {0x0000,0x7777,0x12345678}, // attrs-released
 {0x0000,0x0000,0x00000000}, // change-detach
 {0xFF3A,0x7777,0x0000FF3A}, // detach-dirty
 {0x0000,0x7777,0x12345678}, // attrs-still-dirty
 {0x0000,0x0000,0x00000000}, // write-before-detach
 {0x0000,0x0000,0x00000000}, // detach-written
 {0xFF40,0x7777,0x12345678}, // attrs-detached
 {0x0000,0x0000,0x00000000}, // lookup-detached
 {0x8888,0x0000,0x00000000}, // dispose-detached
 {0x0000,0x0000,0x00000000}, // change-empty
 {0x8888,0x0000,0x00000000}, // empty-dirty
 {0x0000,0x7777,0x12345678}, // attrs-empty
 {0x0000,0x0000,0x12345678}, // load-empty
 {0x0000,0x7777,0x12345678}, // attrs-loaded
 {0x0000,0x7777,0x12345678}, // update-loaded
 {0x0000,0x0000,0x00000000}, // change-close
 {0x0000,0x0000,0x00000000}, // close-dirty
 {0x0000,0x0000,0x12345678}, // reopen-a
 {0x0000,0x0000,0x00000000}, // lookup-closed
 {0x8888,0x7777,0x00000000}, // create-b
 {0x0000,0x7777,0x00000004}, // map-b
 {0x0000,0x0000,0x12345678}, // open-b
 {0x8888,0x0000,0x00000000}, // allocate-b
 {0x0000,0x0000,0x00000000}, // add-b
 {0x0000,0x7777,0x00000000}, // use-app
 {0x0000,0x0000,0x00000000}, // close-noncurrent-a
 {0x8888,0x7777,0x12345678}, // current-after-a
 {0x0000,0x0000,0x00000000}, // close-noncurrent-dirty-b
 {0x8888,0x7777,0x12345678}, // current-after-b
 {0x0000,0x0000,0x12345678}, // reopen-b
 {0x0000,0x0000,0x00000000}, // lookup-noncurrent-closed
 {0x0000,0x0000,0x00000000}, // close-b
 {0x8888,0x7777,0x00000000}, // delete-a
 {0x8888,0x7777,0x00000000}, // delete-b
 {0x8888,0x7777,0x12345678}, // current-final
};
extern "C" bool aitdResourceDirtyProbe() {
 uint32_t start=g_systemWindows;uint16_t app=0,a=0,b=0;uint8_t** h=0,**released=0,**detached=0;
 for(uint16_t n=1;n<=45;++n) {
  g_resourceDirtyStep=n;g_resourceFileStackError=0;
  w(g_macLowMemory+140,0x8888);w(g_macLowMemory+100,0x7777);
  uint32_t result=0,wanted=0,body=0;int16_t flags=-1;bool scalar=true;
  switch(n) {
  case 1:case 37:case 39:case 45:result=aitdRFileCall(aitdRFileCur,0,0,2);if(n==1){app=result;scalar=false;}else wanted=app;break;
  case 2:case 30:case 43:case 44:result=file(n==2||n==30,n==2||n==43?nameA:nameB);break;
  case 3:case 31:result=named(aitdRFileCreate,n==3?nameA:nameB);break;
  case 4:case 28:case 32:case 40:result=named(aitdRFileOpen,n<30?nameA:nameB,2);if(!result||result==0xffff||result==app)return false;if(n<30)a=result;else b=result;scalar=false;break;
  case 5:case 33:h=aitdRFileAllocate();if(!h||!*h)return false;body=n==5?0x41414141:0x46464646;l(*h,body);flags=0;break;
  case 6:case 34:result=add(h);body=n==6?0x41414141:0x46464646;flags=0x20;break;
  case 7:case 25:result=refcall(aitdRFileUpdate,a);break;
  case 8:case 12:case 20:case 26:body=n==8?0x42424242:n==12?0x43434343:n==20?0x44444444:0x45454545;l(*h,body);result=hcall(aitdRMutChanged,h);flags=0x20;break;
  case 9:released=h;result=hcall(aitdRMutRelease,h);body=0x42424242;flags=0x20;break;
  case 10:case 18:case 29:case 41:h=lookup();if((n==10&&h!=released)||(n==18&&h==detached))return false;body=n==10?0x42424242:n==18?0x43434343:n==29?0x45454545:0x46464646;flags=0x20;break;
  case 11:case 14:case 17:case 22:case 24:result=hcall(aitdRMutAttrs,h,2);wanted=n==11||n==14||n==22?2:0;if(n==22&&*h)return false;break;
  case 13:case 16:result=hcall(aitdRMutDetach,h);if(n==16)detached=h;body=0x43434343;flags=n==13?0x20:0;break;
  case 15:result=hcall(aitdRMutWrite,h);body=0x43434343;flags=0x20;break;
  case 19:result=hcall(aitdRMutDispose,detached);break;
  case 21:result=hcall(aitdRMutEmpty,h);if(*h)return false;break;
  case 23:result=hcall(aitdRMutLoad,h);body=0x43434343;flags=0x20;break;
  case 27:case 36:case 38:case 42:result=refcall(aitdRFileClose,n<38?a:b);break;
  case 35:result=refcall(aitdRFileUse,app);body=0x46464646;flags=0x20;break;
  }
  const auto& e=expected[n-1];
  g_resourceDirtyValue=result;g_resourceDirtyError=word(g_macLowMemory+140);g_resourceDirtyMemory=word(g_macLowMemory+100);
  if(g_resourceFileStackError||g_resourceDirtyError!=e.error||g_resourceDirtyMemory!=e.memory||g_resourceLookupD0!=e.d0||(scalar&&result!=wanted))return false;
  if(body&&(!h||!*h||lng(*h)!=body))return false;
  if(flags>=0){aitdProbeResState(h,0x12345678);if(g_resourceLookupD0!=(uint32_t)flags)return false;}
  if(n==42)aitdResourceDirtyPersisted();
 }
 g_resourceDirtyWindows=g_systemWindows-start;g_resourceDirtyStep=46;return true;
}
#endif
