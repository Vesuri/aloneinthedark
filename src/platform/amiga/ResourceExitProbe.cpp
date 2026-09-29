#ifdef AITD_RESOURCE_EXIT_PROBE
#include <proto/exec.h>
#ifndef AITD_RESOURCE_EXIT_PHASE
#define AITD_RESOURCE_EXIT_PHASE 1
#endif
#ifndef AITD_RESOURCE_EXIT_PREFS
#define AITD_RESOURCE_EXIT_PREFS 0
#endif
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceStageFault;
volatile uint32_t g_resourceExitPhase=AITD_RESOURCE_EXIT_PHASE,g_resourceExitStep=0,g_resourceExitError=0,g_resourceExitPrepared=0,g_resourceExitCleanupOK=0,g_resourceExitHandle=0;
volatile uint32_t g_resourceExitPrefs=AITD_RESOURCE_EXIT_PREFS,g_resourceExitOverlayChecks=0;
volatile uint32_t g_resourceLookupD0=0,g_resourceFileStackError=0;
volatile uint16_t g_fileProbeCCR=0;
__attribute__((noinline)) void aitdResourceExitFixtureFinished() { __asm__ volatile("" ::: "memory"); }
__attribute__((noinline)) void aitdResourceExitCleanupFinished() { __asm__ volatile("" ::: "memory"); }
uint32_t aitdRFileCall(void(*)(),const uint8_t*,uint32_t,uint32_t);
uint8_t** aitdRFileAllocate();
int32_t aitdProbeCreate(void*),aitdProbeDelete(void*);
void aitdRFileUpdate(),aitdRFileUse(),aitdRMutCount(),aitdRFileCur(),aitdRFileOpen(),aitdRFileCreate(),aitdRFileClose(),aitdRFileAdd(),aitdRMutAttrs(),aitdRMutLookup();
void aitdProbeResState(uint8_t**,uint32_t);
}
static void w(uint8_t* p,uint16_t v) { p[0]=v>>8;p[1]=v; }
static void l(uint8_t* p,uint32_t v) { w(p,v>>16);w(p+2,v); }
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static uint16_t word(const uint8_t* p) { return (uint16_t)p[0]<<8|p[1]; }
#if AITD_RESOURCE_EXIT_PREFS
static const uint8_t name[]="\055Alone:System Folder:Preferences:Resource Exit";
#else
static const uint8_t name[]="\040:Alone Saved Games:Resource Exit";
#endif
static const uint8_t resourceName[]="\007Scratch";
static uint32_t named(void(*trap)(),uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)name);return aitdRFileCall(trap,a,4,result); }
struct Expected { uint16_t error,memory;uint32_t d0; };
static const Expected expected[]={
 {0x8888,0x7777,0x12345678},{0x8888,0x7777,0},{0,0x7777,4},{0,0,0x12345678},
 {0x8888,0,0},{0,0,0},{0,0x7777,0x12345678},
 {0x8888,0x7777,0x12345678},{0,0,0x12345678},{0,0,0},{0,0,0},{0x8888,0x7777,0},{0x8888,0x7777,0x12345678}
};
static bool checkOverlay() {
 uint16_t app=aitdRFileCall(aitdRFileCur,0,0,2);if(!app)return false;
 uint8_t a[4]={};aitdRFileCall(aitdRFileUse,a,2,0);
 if(word(g_macLowMemory+140) || aitdRFileCall(aitdRFileCur,0,0,2))return false;
 l(a,0x434f4445);if(aitdRFileCall(aitdRMutCount,a,4,2)!=0 || word(g_macLowMemory+140))return false;
 w(a,app);aitdRFileCall(aitdRFileUse,a,2,0);
 if(word(g_macLowMemory+140) || aitdRFileCall(aitdRFileCur,0,0,2)!=app || g_resourceFileStackError)return false;
 g_resourceExitOverlayChecks=6;return true;
}
static bool run() {
 bool write=g_resourceExitPhase!=2;if(g_resourceExitPhase<1 || g_resourceExitPhase>3)return false;
 uint16_t app=0,ref=0;uint8_t** h=0;
 for(uint16_t n=1;n<=(write?7:6);++n) {
  g_resourceExitStep=write?n:0x1000+n;g_resourceFileStackError=0;
  w(g_macLowMemory+140,0x8888);w(g_macLowMemory+100,0x7777);
  uint32_t result=0,wanted=0;bool scalar=true;int16_t flags=-1;
  if(n==1 || (!write&&n==6)){result=aitdRFileCall(aitdRFileCur,0,0,2);if(n==1){app=result;scalar=false;}else wanted=app;}
  else if((write&&n==2)||(!write&&n==5)) { uint8_t pb[80]={};l(pb+18,(uint32_t)name);result=write?aitdProbeCreate(pb):aitdProbeDelete(pb);g_resourceLookupD0=result; }
  else if(write&&n==3)result=named(aitdRFileCreate);
  else if((write&&n==4)||(!write&&n==2)){ref=result=named(aitdRFileOpen,2);if(!ref||ref==0xffff||ref==app)return false;scalar=false;}
  else if(write&&n==5){h=aitdRFileAllocate();if(!h||!*h)return false;l(*h,0x45584954);flags=0;}
  else if(write&&n==6){uint8_t a[14];l(a,(uint32_t)resourceName);w(a+4,128);l(a+6,0x4c494645);l(a+10,(uint32_t)h);result=aitdRFileCall(aitdRFileAdd,a,14,0);flags=0x20;}
  else if(write&&n==7){uint8_t a[4];l(a,(uint32_t)h);result=aitdRFileCall(aitdRMutAttrs,a,4,2);wanted=2;flags=0x20;}
  else if(!write&&n==3){uint8_t a[6];w(a,128);l(a+2,0x4c494645);h=(uint8_t**)aitdRFileCall(aitdRMutLookup,a,6,4);flags=0x20;}
  else if(!write&&n==4){uint8_t a[2];w(a,ref);result=aitdRFileCall(aitdRFileClose,a,2,0);}
  const auto& e=expected[(write?0:7)+n-1];
  if(g_resourceFileStackError||word(g_macLowMemory+140)!=e.error||word(g_macLowMemory+100)!=e.memory||g_resourceLookupD0!=e.d0||(scalar&&result!=wanted))return false;
  if(flags>=0){if(!h||!*h||lng(*h)!=0x45584954)return false;aitdProbeResState(h,0x12345678);if(g_resourceLookupD0!=(uint32_t)flags)return false;}
 }
 g_resourceExitHandle=write?(uint32_t)h:0;return true;
}
// Diagnostic build only. FS-UAE's remote stub ignores register/memory writes;
// install this byte-guarded entry while CODE 3 is loaded. The fixture immediately
// restores it and returns to the original CODE 1+$48 caller/unpatch/ExitToShell.
static uint8_t* originalMain=0;
extern "C" void aitdResourceExitFixture();
void aitdInstallResourceExitProbe(uint8_t* core) {
    uint8_t* entry=core+0x3e4;
    if(lng(entry)!=0x4e56ff00 || lng(entry+4)!=0x4ebafd7c) { g_resourceExitError=0xfffe;return; }
    originalMain=entry;w(entry,0x4ef9);l(entry+2,(uint32_t)aitdResourceExitFixture);CacheClearU();
}
extern "C" void aitdResourceExitFixture() {
 if(!originalMain) { g_resourceExitError=0xfffd;aitdResourceExitFixtureFinished();return; }
 l(originalMain,0x4e56ff00);l(originalMain+4,0x4ebafd7c);CacheClearU();
 if(!checkOverlay()) { g_resourceExitError=0xfffc;aitdResourceExitFixtureFinished();return; }
 if(g_resourceExitPhase==4 || g_resourceExitPhase==5) {
  g_resourceExitPrepared=1;g_resourceExitStep=0x2000+g_resourceExitPhase;
  uint8_t ref[2]={};aitdRFileCall(g_resourceExitPhase==4?aitdRFileUpdate:aitdRFileClose,ref,2,0);
  g_resourceExitError=0xfffb;aitdResourceExitFixtureFinished();return;
 }
 if(run())g_resourceExitPrepared=1;else g_resourceExitError=g_resourceExitStep?g_resourceExitStep:0xffff;
 if(g_resourceExitPhase==3 && g_resourceExitPrepared)g_resourceStageFault=1;
 aitdResourceExitFixtureFinished();
}
#endif
