#ifdef AITD_FILE_WRITE_PROBE
extern "C" {
extern uint8_t* g_macLowMemory;
extern volatile uint32_t g_resourceLookupD0,g_resourceFileStackError,g_systemWindows,g_resourceStageFault;
volatile uint32_t g_resourceMutationStep=0,g_resourceMutationValue=0,g_resourceMutationError=0,g_resourceMutationMemory=0,g_resourceMutationWindows=0,g_resourceMutationFaultChecks=0,g_resourceMutationLifecycleChecks=0;
__attribute__((noinline)) void aitdResourceMutationRolledBack() { __asm__ volatile(""); }
__attribute__((noinline)) void aitdResourceMutationPersisted() { __asm__ volatile(""); }
uint32_t aitdRFileCall(void(*)(),const uint8_t*,uint32_t,uint32_t);
uint8_t** aitdRFileAllocate();
int32_t aitdProbeCreate(void*),aitdProbeDelete(void*);
void aitdProbeResState(uint8_t**,uint32_t);
void aitdRFileCur(),aitdRFileOpen(),aitdRFileCreate(),aitdRFileUpdate(),aitdRFileClose(),aitdRFileAdd();
void aitdRMutRelease(),aitdRMutDetach();
void aitdRMutChanged(),aitdRMutWrite(),aitdRMutRemove(),aitdRMutAttrs(),aitdRMutCount(),aitdRMutLookup(),aitdRMutIndex(),aitdRMutLoad(),aitdRMutEmpty();
}
static void w(uint8_t* p,uint16_t v) { p[0]=v>>8;p[1]=v; }
static void l(uint8_t* p,uint32_t v) { w(p,v>>16);w(p+2,v); }
static uint32_t lng(const uint8_t* p) { return (uint32_t)p[0]<<24|(uint32_t)p[1]<<16|(uint32_t)p[2]<<8|p[3]; }
static uint16_t word(const uint8_t* p) { return (uint16_t)p[0]<<8|p[1]; }
static uint32_t named(void(*trap)(),const uint8_t* name,uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)name);return aitdRFileCall(trap,a,4,result); }
static uint32_t refcall(void(*trap)(),uint16_t ref) { uint8_t a[2];w(a,ref);return aitdRFileCall(trap,a,2,0); }
static uint32_t hcall(void(*trap)(),uint8_t** h,uint32_t result=0) { uint8_t a[4];l(a,(uint32_t)h);return aitdRFileCall(trap,a,4,result); }
static uint32_t file(bool create,const uint8_t* name) { uint8_t pb[80]={};l(pb+18,(uint32_t)name);int32_t e=create?aitdProbeCreate(pb):aitdProbeDelete(pb);g_resourceLookupD0=e;return e; }
static uint32_t add(uint8_t** h,uint32_t type,uint16_t id) { static const uint8_t name[]="\007Scratch";uint8_t a[14];l(a,(uint32_t)name);w(a+4,id);l(a+6,type);l(a+10,(uint32_t)h);return aitdRFileCall(aitdRFileAdd,a,14,0); }
static uint8_t** lookup(uint32_t type,uint16_t id,bool indexed=false) { uint8_t a[6];w(a,id);l(a+2,type);return (uint8_t**)aitdRFileCall(indexed?aitdRMutIndex:aitdRMutLookup,a,6,4); }
static uint32_t count(uint32_t type) { uint8_t a[4];l(a,type);return aitdRFileCall(aitdRMutCount,a,4,2); }
struct Expected { uint16_t error,memory;uint32_t d0; };
static const Expected expected0[]={
 {0x8888,0x7777,0x12345678}, // application
 {0x8888,0x7777,0x0}, // create-file
 {0x0,0x7777,0x4}, // create-map
 {0x0,0x0,0x12345678}, // open
 {0x8888,0x0,0x0}, // allocate
 {0x0,0x0,0x0}, // add
 {0x0,0x7777,0x12345678}, // attrs-added
 {0x0,0x0,0x0}, // changed
 {0x0,0x7777,0x12345678}, // attrs-changed
 {0x0,0x0,0x0}, // write
 {0x0,0x7777,0x12345678}, // attrs-written
 {0x0,0x0,0x12345678}, // update
 {0x0,0x0,0x0}, // close
 {0x0,0x0,0x12345678}, // reopen
 {0x0,0x0,0x0}, // lookup-written
 {0x0,0x7777,0x12345678}, // attrs-reopened
 {0x0,0x0,0x0}, // write-without-changed
 {0x0,0x0,0x0}, // close-unchanged
 {0x0,0x0,0x12345678}, // reopen-unchanged
 {0x0,0x0,0x0}, // lookup-unchanged
 {0x8888,0x0,0x0}, // duplicate-allocate
 {0x0,0x0,0x0}, // duplicate-add
 {0x0,0x0,0x0}, // count-after-duplicate
 {0x0,0x0,0x12345678}, // update-duplicates
 {0x0,0x0,0x0}, // close-duplicates
 {0x0,0x0,0x12345678}, // reopen-duplicates
 {0x0,0x0,0x0}, // count-reopened-duplicates
 {0x0,0x0,0x0}, // duplicate-index-one
 {0x0,0x0,0x0}, // duplicate-index-two
 {0x0,0x7777,0x0}, // lookup-duplicate-selected
 {0xff3e,0x0,0xff3e}, // nil-add
 {0xff40,0x7777,0xff40}, // nil-changed
 {0xff40,0x7777,0xff40}, // nil-write
 {0xff3c,0x7777,0xff3c}, // nil-remove
 {0x0,0x0,0x0}, // remove
 {0xff40,0x7777,0x12345678}, // attrs-removed
 {0xff40,0x7777,0xff40}, // changed-removed
 {0xff40,0x7777,0xff40}, // write-removed
 {0xff3c,0x7777,0xff3c}, // remove-again
 {0x0,0x0,0x0}, // count-removed
 {0x0,0x0,0x0}, // readd
 {0xff3f,0x7777,0x12345678}, // invalid-update
 {0x0,0x0,0x12345678}, // update-readded
 {0x0,0x0,0x0}, // close-readded
 {0x0,0x0,0x12345678}, // reopen-readded
 {0x0,0x0,0x0}, // lookup-readded
 {0x0,0x0,0x0}, // lookup-removed
 {0x0,0x0,0x0}, // final-close
 {0x8888,0x7777,0x0}, // delete-file
 {0x8888,0x7777,0x12345678}, // current-final
};
static const Expected expected1[]={
 {0x8888,0x7777,0x12345678}, // application
 {0x8888,0x7777,0x0}, // create
 {0x0,0x7777,0x4}, // map
 {0x0,0x0,0x12345678}, // open
 {0x8888,0x0,0x0}, // allocate-a
 {0x0,0x0,0x0}, // add-a
 {0x8888,0x0,0x0}, // allocate-b
 {0x0,0x0,0x0}, // add-b
 {0x0,0x0,0x12345678}, // update-baseline
 {0x0,0x0,0x0}, // change-a
 {0x0,0x0,0x0}, // change-b
 {0x0,0x0,0x0}, // write-a
 {0x0,0x7777,0x12345678}, // attrs-written-a
 {0x0,0x7777,0x12345678}, // attrs-dirty-b
 {0x8888,0x0,0x0}, // empty-a
 {0x0,0x0,0x12345678}, // reload-a
 {0x8888,0x0,0x0}, // empty-b
 {0x0,0x7777,0x12345678}, // attrs-empty-b
 {0x0,0x0,0x12345678}, // reload-b
 {0x0,0x7777,0x12345678}, // attrs-reloaded-b
 {0x0,0x7777,0x12345678}, // update-discarded
 {0x0,0x0,0x0}, // close-first
 {0x0,0x0,0x12345678}, // reopen-first
 {0x0,0x0,0x0}, // lookup-first-a
 {0x0,0x0,0x0}, // lookup-first-b
 {0x0,0x0,0x0}, // change-again-a
 {0x0,0x0,0x0}, // change-again-b
 {0x0,0x0,0x0}, // write-b
 {0x0,0x7777,0x12345678}, // attrs-dirty-a
 {0x0,0x7777,0x12345678}, // attrs-written-b
 {0x8888,0x0,0x0}, // empty-written-b
 {0x0,0x0,0x12345678}, // reload-written-b
 {0x0,0x0,0x12345678}, // update-both
 {0x0,0x0,0x0}, // close-second
 {0x0,0x0,0x12345678}, // reopen-second
 {0x0,0x0,0x0}, // lookup-final-a
 {0x0,0x0,0x0}, // lookup-final-b
 {0x0,0x0,0x0}, // close-final
 {0x8888,0x7777,0x0}, // delete
 {0x8888,0x7777,0x12345678}, // current-final
};
extern "C" bool aitdResourceMutationProbe() {
 uint32_t start=g_systemWindows;
 for(uint16_t phase=0;phase<2;++phase) {
  static const uint8_t writeName[]="\044:Alone Saved Games:Resource Mutation";
  static const uint8_t isolateName[]="\045:Alone Saved Games:Resource Isolation";
  const uint8_t* name=phase?isolateName:writeName;uint32_t type=phase?0x49534f4c:0x5257524b;
  uint16_t app=0,ref=0;uint8_t** h=0,**other=0,**first=0,**ha=0,**hb=0;
  for(uint16_t n=1;n<=(phase?40:50);++n) {
   g_resourceMutationStep=phase*100+n;g_resourceFileStackError=0;
   if(!phase && n==10)for(uint16_t fault=1;fault<=2;++fault) {
    g_resourceMutationStep=900+fault;g_resourceStageFault=fault;
    uint32_t result=hcall(aitdRMutWrite,h);g_resourceStageFault=0;
    if(result || g_resourceFileStackError || word(g_macLowMemory+140)!=0xffdc || g_resourceLookupD0!=0xffdc)return false;
    if(hcall(aitdRMutAttrs,h,2)!=2 || word(g_macLowMemory+140) || !*h || lng(*h)!=0x42424242)return false;
    aitdResourceMutationRolledBack();++g_resourceMutationFaultChecks;
   }
   if(phase && n==12) {
    w(g_macLowMemory+100,0x7777);w(g_macLowMemory+140,0x8888);g_resourceMutationStep=801;
    if(hcall(aitdRMutRelease,ha)||word(g_macLowMemory+140)||word(g_macLowMemory+100)!=0x7777||g_resourceLookupD0!=0x12345678||g_resourceFileStackError||!*ha||lng(*ha)!=0x43434343)return false;
    ++g_resourceMutationLifecycleChecks;g_resourceMutationStep=802;
    if(hcall(aitdRMutDetach,ha)||word(g_macLowMemory+140)!=0xff3a||word(g_macLowMemory+100)!=0x7777||g_resourceLookupD0!=0xff3a||g_resourceFileStackError||!*ha||lng(*ha)!=0x43434343)return false;
    ++g_resourceMutationLifecycleChecks;g_resourceMutationStep=803;
    if(hcall(aitdRMutAttrs,ha,2)!=2||word(g_macLowMemory+140)||word(g_macLowMemory+100)!=0x7777||g_resourceLookupD0!=0x12345678||g_resourceFileStackError)return false;
    ++g_resourceMutationLifecycleChecks;
   }
   g_resourceMutationStep=phase*100+n;
   w(g_macLowMemory+140,0x8888);w(g_macLowMemory+100,0x7777);
   uint32_t result=0,wanted=0,body=0;bool scalar=true;int16_t flags=-1;
   if(!phase)switch(n) {
   case 1:app=result=aitdRFileCall(aitdRFileCur,0,0,2);scalar=false;break;
   case 2:result=file(true,name);break;
   case 3:result=named(aitdRFileCreate,name);break;
   case 4:case 14:case 19:case 26:case 45:ref=result=named(aitdRFileOpen,name,2);if(!ref||ref==0xffff||ref==app)return false;scalar=false;break;
   case 5:h=aitdRFileAllocate();if(!h||!*h)return false;l(*h,0x41414141);body=0x41414141;flags=0;break;
   case 6:case 22:case 31:case 41:result=add(n==22?other:n==31?0:h,type,n>=31?129:128);break;
   case 7:case 9:case 11:case 16:case 36:result=hcall(aitdRMutAttrs,h,2);wanted=n==7||n==9?2:0;break;
   case 8:l(*h,0x42424242);result=hcall(aitdRMutChanged,h);body=0x42424242;flags=0x20;break;
   case 10:case 17:case 33:case 38:if(n==17)l(*h,0x43434343);result=hcall(aitdRMutWrite,n==33?0:h);break;
   case 12:case 24:case 42:case 43:result=refcall(aitdRFileUpdate,n==42?0x1234:ref);break;
   case 13:case 18:case 25:case 44:case 48:result=refcall(aitdRFileClose,ref);break;
   case 15:case 20:case 30:case 46:case 47:h=lookup(type,n==46?129:128);body=n==47?0x44444444:0x42424242;flags=0x20;if(n==30&&h!=first)return false;break;
   case 21:other=aitdRFileAllocate();if(!other||!*other||other==h)return false;l(*other,0x44444444);break;
   case 23:case 27:case 40:result=count(type);wanted=n==40?1:2;break;
   case 28:case 29:h=lookup(type,n==28?1:2,true);if(n==28)first=h;else if(h==first)return false;body=n==28?0x42424242:0x44444444;flags=0x20;break;
   case 32:case 37:result=hcall(aitdRMutChanged,n==32?0:h);break;
   case 34:case 35:case 39:result=hcall(aitdRMutRemove,n==34?0:h);break;
   case 49:result=file(false,name);break;
   case 50:result=aitdRFileCall(aitdRFileCur,0,0,2);wanted=app;break;
   }
   else switch(n) {
   case 1:app=result=aitdRFileCall(aitdRFileCur,0,0,2);scalar=false;break;
   case 2:result=file(true,name);break;
   case 3:result=named(aitdRFileCreate,name);break;
   case 4:case 23:case 35:ref=result=named(aitdRFileOpen,name,2);if(!ref||ref==0xffff||ref==app)return false;scalar=false;break;
   case 5:case 7:h=aitdRFileAllocate();if(!h||!*h)return false;if(n==5)ha=h;else hb=h;l(*h,n==5?0x41414141:0x42424242);break;
   case 6:case 8:result=add(h,type,n==6?128:129);break;
   case 9:case 21:case 33:result=refcall(aitdRFileUpdate,ref);break;
   case 10:case 11:case 26:case 27:h=n==10||n==26?ha:hb;l(*h,n==10?0x43434343:n==11?0x44444444:n==26?0x45454545:0x46464646);result=hcall(aitdRMutChanged,h);break;
   case 12:case 28:h=n==12?ha:hb;result=hcall(aitdRMutWrite,h);break;
   case 13:case 14:case 18:case 20:case 29:case 30:h=n==13||n==29?ha:hb;result=hcall(aitdRMutAttrs,h,2);wanted=n==14||n==18||n==29?2:0;break;
   case 15:case 17:case 31:h=n==15?ha:hb;result=hcall(aitdRMutEmpty,h);if(*h)return false;break;
   case 16:case 19:case 32:h=n==16?ha:hb;result=hcall(aitdRMutLoad,h);body=n==16?0x43434343:n==19?0x42424242:0x46464646;flags=0x20;break;
   case 22:case 34:case 38:result=refcall(aitdRFileClose,ref);break;
   case 24:case 25:case 36:case 37:h=lookup(type,n==24||n==36?128:129);if(n==24)ha=h;if(n==25)hb=h;body=n==24?0x43434343:n==25?0x42424242:n==36?0x45454545:0x46464646;flags=0x20;break;
   case 39:result=file(false,name);break;
   case 40:result=aitdRFileCall(aitdRFileCur,0,0,2);wanted=app;break;
   }
   if(!phase) {
    if(n==6) { body=0x41414141;flags=0x20; }
    if(n==10) { body=0x42424242;flags=0x20; }
    if(n==17) { body=0x43434343;flags=0x20; }
    if(n>=35&&n<=39) { body=0x42424242;flags=0; }
    if(n==41) { body=0x42424242;flags=0x20; }
   }
   const auto& e=phase?expected1[n-1]:expected0[n-1];
   g_resourceMutationValue=result;g_resourceMutationError=word(g_macLowMemory+140);g_resourceMutationMemory=word(g_macLowMemory+100);
   if(g_resourceFileStackError||g_resourceMutationError!=e.error||g_resourceMutationMemory!=e.memory||g_resourceLookupD0!=e.d0||(scalar&&result!=wanted))return false;
   if(body&&(!h||!*h||lng(*h)!=body))return false;
   if(flags>=0) { aitdProbeResState(h,0x12345678);if(g_resourceLookupD0!=(uint32_t)flags)return false; }
   if((!phase&&n==48)||(phase&&n==38))aitdResourceMutationPersisted();
  }
 }
 g_resourceMutationWindows=g_systemWindows-start;g_resourceMutationStep=141;return true;
}
#endif
