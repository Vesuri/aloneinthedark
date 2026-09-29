#ifdef AITD_FILE_WRITE_PROBE
#include <proto/dos.h>
#include <dos/dos.h>
#include "SystemWindow.h"
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceFileStackError,g_systemWindows;
volatile uint32_t g_resourcePermissionStep=0,g_resourcePermissionValue=0,g_resourcePermissionError=0,g_resourcePermissionMemory=0,g_resourcePermissionWindows=0;
__attribute__((noinline)) void aitdResourcePermissionsPersisted() { __asm__ volatile("" ::: "memory"); }
uint32_t aitdRFileCall(void(*)(),const uint8_t*,uint32_t,uint32_t);
uint8_t** aitdRFileAllocate();
int32_t aitdProbeCreate(void*),aitdProbeDelete(void*),aitdProbeOpenRF(void*),aitdProbeWrite(void*),aitdProbeClose(void*),aitdRPermissionProtect(uint32_t);
void aitdRFileCur(),aitdRFilePerm(),aitdRFileCreate(),aitdRFileUpdate(),aitdRFileClose(),aitdRFileAdd();
void aitdRMutChanged(),aitdRMutWrite(),aitdRMutRemove(),aitdRMutAttrs(),aitdRMutCount(),aitdRMutLookup(),aitdRMutDispose();
void aitdProbeResState(uint8_t**,uint32_t);
}
static int32_t protection(void* locked) {
 return SetProtection((CONST_STRPTR)"PROGDIR:Saved Games/Resource Permissions",locked?FIBF_WRITE:0)?0:-36;
}
// Diagnostic setup only: the game's census does not call SetFLock/RstFLock.
int32_t aitdResourcePermissionProtection(uint32_t locked) { return aitdSystemWindow(protection,(void*)locked); }
static void w(uint8_t* p,uint16_t v) { p[0]=v>>8;p[1]=v; }
static void l(uint8_t* p,uint32_t v) { w(p,v>>16);w(p+2,v); }
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static uint16_t word(const uint8_t* p) { return (uint16_t)p[0]<<8|p[1]; }
static const uint8_t name[]="\047:Alone Saved Games:Resource Permissions",resourceName[]="\007Scratch";
static uint32_t named(void(*trap)()) { uint8_t a[4];l(a,(uint32_t)name);return aitdRFileCall(trap,a,4,0); }
static uint32_t refcall(void(*trap)(),uint16_t ref) { uint8_t a[2];w(a,ref);return aitdRFileCall(trap,a,2,0); }
static uint32_t hcall(void(*trap)(),uint8_t** h,uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)h);return aitdRFileCall(trap,a,4,result); }
static uint32_t open(uint8_t permission) { uint8_t a[8]={};a[0]=permission;l(a+4,(uint32_t)name);return aitdRFileCall(aitdRFilePerm,a,8,2); }
static uint32_t add(uint8_t** h,uint16_t id) { uint8_t a[14];l(a,(uint32_t)resourceName);w(a+4,id);l(a+6,0x5250524d);l(a+10,(uint32_t)h);return aitdRFileCall(aitdRFileAdd,a,14,0); }
static uint8_t** lookup(uint16_t id) { uint8_t a[6];w(a,id);l(a+2,0x5250524d);return (uint8_t**)aitdRFileCall(aitdRMutLookup,a,6,4); }
static uint32_t count() { uint8_t a[4];l(a,0x5250524d);return aitdRFileCall(aitdRMutCount,a,4,2); }
struct Expected { uint16_t error,memory;uint32_t d0; };
static const Expected expected[]={
 {0x8888,0x7777,0x12345678}, // application
 {0x8888,0x7777,0x00000000}, // exclusive-create
 {0xFFD9,0x0000,0x0000FFD9}, // open-empty-map
 {0x8888,0x7777,0x00000000}, // raw-open
 {0x8888,0x7777,0x00000000}, // raw-write-bad-map
 {0x8888,0x7777,0x00000000}, // raw-close
 {0xFFD9,0x0000,0x0000FFD9}, // open-malformed-map
 {0x8888,0x7777,0x00000000}, // delete-empty
 {0x0000,0x7777,0x00000004}, // create-absent
 {0x0000,0x0000,0x00000000}, // open-initial
 {0x8888,0x0000,0x00000000}, // allocate
 {0x0000,0x0000,0x00000000}, // add
 {0x0000,0x0000,0x12345678}, // update
 {0x0000,0x0000,0x00000000}, // close-initial
 {0xFFD0,0x7777,0x00000004}, // create-existing
 {0x0000,0x0000,0x00000000}, // open-0
 {0x0000,0x0000,0x00000000}, // lookup-0
 {0x0000,0x0000,0x00000000}, // close-0
 {0x0000,0x0000,0x00000000}, // open-1
 {0x0000,0x0000,0x00000000}, // lookup-1
 {0x0000,0x0000,0x00000000}, // close-1
 {0x0000,0x0000,0x00000000}, // open-2
 {0x0000,0x0000,0x00000000}, // lookup-2
 {0x0000,0x0000,0x00000000}, // close-2
 {0x0000,0x0000,0x00000000}, // open-3
 {0x0000,0x0000,0x00000000}, // lookup-3
 {0x0000,0x0000,0x00000000}, // close-3
 {0x0000,0x0000,0x00000000}, // open-4
 {0x0000,0x0000,0x00000000}, // lookup-4
 {0x0000,0x0000,0x00000000}, // close-4
 {0x0000,0x0000,0x00000000}, // open-readonly
 {0x0000,0x0000,0x00000000}, // lookup-readonly
 {0xFFC3,0x0000,0x0000FFC3}, // changed-readonly
 {0x0000,0x7777,0x12345678}, // attrs-readonly
 {0x0000,0x0000,0x00000000}, // write-readonly
 {0x8888,0x0000,0x00000000}, // readonly-allocate
 {0xFFC3,0x0000,0x0000FFC3}, // add-readonly
 {0x0000,0x0000,0x00000000}, // count-readonly-added
 {0x0000,0x0000,0x00000000}, // remove-readonly
 {0xFFC3,0x7777,0x12345678}, // update-readonly
 {0xFFC3,0x0000,0x0000FFC3}, // close-readonly
 {0x8888,0x7777,0x12345678}, // current-after-readonly
 {0x0000,0x0000,0x00000000}, // open-after-readonly
 {0x0000,0x0000,0x00000000}, // lookup-after-readonly
 {0x0000,0x7777,0x00000000}, // lookup-readonly-added
 {0x0000,0x0000,0x00000000}, // close-after-readonly
 {0x8888,0x7777,0x00000000}, // lock
 {0x0000,0x0000,0x00000000}, // open-locked-default
 {0x0000,0x0000,0x00000000}, // lookup-locked-default
 {0x0000,0x0000,0x00000000}, // close-locked-default
 {0x0000,0x0000,0x00000000}, // open-locked-read
 {0x0000,0x0000,0x00000000}, // lookup-locked-read
 {0x0000,0x0000,0x00000000}, // close-locked-read
 {0xFFCA,0x0000,0x0000FFCA}, // open-locked-2
 {0xFFCA,0x0000,0x0000FFCA}, // open-locked-3
 {0xFFCA,0x0000,0x0000FFCA}, // open-locked-4
 {0x8888,0x7777,0x00000000}, // unlock
 {0x8888,0x7777,0x00000000}, // delete-file
 {0x8888,0x7777,0x12345678}, // current-final
};
extern "C" bool aitdResourcePermissionProbe() {
 uint32_t start=g_systemWindows;uint16_t app=0,ref=0;uint8_t** h=0,**other=0,**removed=0;
 uint8_t pb[80]={},zero[16]={};
 for(uint16_t n=1;n<=59;++n) {
  g_resourcePermissionStep=n;g_resourceFileStackError=0;
  w(g_macLowMemory+140,0x8888);w(g_macLowMemory+100,0x7777);
  uint32_t result=0,wanted=0,body=0;int16_t flags=-1;bool scalar=true,opened=false;
  switch(n) {
  case 1:case 42:case 59:result=aitdRFileCall(aitdRFileCur,0,0,2);if(n==1){app=result;scalar=false;}else wanted=app;break;
  case 2:case 8:case 58:l(pb+18,(uint32_t)name);result=n==2?aitdProbeCreate(pb):aitdProbeDelete(pb);g_resourceLookupD0=result;break;
  case 3:case 7:case 54:case 55:case 56:result=open(n<54?3:n-52);wanted=0xffff;break;
  case 4:l(pb+18,(uint32_t)name);pb[27]=3;g_resourceLookupD0=aitdProbeOpenRF(pb);ref=result=word(pb+24);if(!ref)return false;scalar=false;break;
  case 5:w(pb+24,ref);l(pb+32,(uint32_t)zero);l(pb+36,16);w(pb+44,1);l(pb+46,0);g_resourceLookupD0=aitdProbeWrite(pb);result=lng(pb+40);wanted=16;break;
  case 6:w(pb+24,ref);result=aitdProbeClose(pb);g_resourceLookupD0=result;pb[27]=0;break;
  case 9:case 15:result=named(aitdRFileCreate);break;
  case 10:case 16:case 19:case 22:case 25:case 28:case 31:case 43:case 48:case 51:
   result=open(n==10||n==43?3:n==31||n==51?1:n==48?0:(n-16)/3);opened=true;break;
  case 11:h=aitdRFileAllocate();if(!h||!*h)return false;l(*h,0x41424344);body=0x41424344;flags=0;break;
  case 12:result=add(h,128);body=0x41424344;flags=0x20;break;
  case 13:case 40:result=refcall(aitdRFileUpdate,ref);break;
  case 14:case 18:case 21:case 24:case 27:case 30:case 41:case 46:case 50:case 53:result=refcall(aitdRFileClose,ref);if(n==41){body=0x45464748;flags=0;}break;
  case 17:case 20:case 23:case 26:case 29:case 32:case 44:case 49:case 52:h=lookup(128);body=0x41424344;flags=0x20;if(n==32)removed=h;break;
  case 33:l(*h,0x45464748);result=hcall(aitdRMutChanged,h);body=0x45464748;flags=0x20;break;
  case 34:result=hcall(aitdRMutAttrs,h,2);body=0x45464748;flags=0x20;break;
  case 35:result=hcall(aitdRMutWrite,h);body=0x45464748;flags=0x20;break;
  case 36:other=aitdRFileAllocate();if(!other||!*other||other==h)return false;l(*other,0x49494949);break;
  case 37:result=add(other,129);if(!*other||lng(*other)!=0x49494949)return false;break;
  case 38:result=count();wanted=1;break;
  case 39:result=hcall(aitdRMutRemove,h);body=0x45464748;flags=0;break;
  case 45:result=(uint32_t)lookup(129);break;
  case 47:case 57:result=aitdRPermissionProtect(n==47);break;
  }
  if(opened){if(!result||result==0xffff||result==app)return false;ref=result;scalar=false;}
  const auto& e=expected[n-1];
  g_resourcePermissionValue=result;g_resourcePermissionError=word(g_macLowMemory+140);g_resourcePermissionMemory=word(g_macLowMemory+100);
  if(g_resourceFileStackError||g_resourcePermissionError!=e.error||g_resourcePermissionMemory!=e.memory||g_resourceLookupD0!=e.d0||(scalar&&result!=wanted))return false;
  if(body&&(!h||!*h||lng(*h)!=body))return false;
  if(flags>=0){aitdProbeResState(h,0x12345678);if(g_resourceLookupD0!=(uint32_t)flags)return false;}
  if(n==15||n==41||n==57)aitdResourcePermissionsPersisted();
 }
 // RmveResource and rejected AddResource leave their caller-owned handles live.
 uint8_t** detached[]={removed,other};for(auto h:detached)if(hcall(aitdRMutDispose,h)||g_resourceFileStackError||g_resourceLookupD0||word(g_macLowMemory+100))return false;
 g_resourcePermissionWindows=g_systemWindows-start;g_resourcePermissionStep=60;return true;
}
#endif
