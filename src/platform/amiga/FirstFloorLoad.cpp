// Optional diagnostic ordinary game Load; never restores emulator state.
#include "FirstFloorLoad.h"
#ifdef AITD_FIRSTFLOOR_LOAD
#include "MacInput.h"
static uint16_t word(const uint8_t* p) {return uint16_t(p[0])<<8|p[1];}
static uint32_t longword(const uint8_t* p) {return uint32_t(word(p))<<16|word(p+2);}
static int16_t signedword(const uint8_t* p) {return int16_t(word(p));}
static void key(uint8_t k,bool down) {aitdInputInjectProbeKey(k,down);}

extern "C" {
#ifdef AITD_STAIRS_SAVE
volatile uint32_t g_walkingReport[4+32*14]={0x41495444,0x57414c4b};
#endif
volatile uint16_t g_firstFloorLoadStage=0;
volatile uint32_t g_firstFloorLoadTick=0,g_firstFloorLoadReadBytes=0;
__attribute__((noinline)) void aitdInputFirstFloorLoadCheckpoint() {__asm__ volatile("nop" ::: "memory");}
}
extern "C" void aitdInputFirstFloorLoadRead(uint32_t bytes)
{
#ifdef AITD_STAIRS_SAVE
 if(g_firstFloorLoadStage>=2 && g_firstFloorLoadStage<=4) {
  g_firstFloorLoadReadBytes+=bytes;
 }
#else
 if(g_firstFloorLoadStage==3 || g_firstFloorLoadStage==4)g_firstFloorLoadReadBytes+=bytes;
#endif
}
#ifdef AITD_STAIRS_SAVE
static void walkingSample(uint32_t ticks,uint32_t scenes,const uint8_t* world)
{
 uint32_t n=g_walkingReport[2];if(n>=32)return;
 const uint8_t* a=world-0xb292+160;
 volatile uint32_t* r=g_walkingReport+4+n*14;
 r[0]=ticks;r[1]=scenes;r[2]=word(world-0xd8f2);
 const uint8_t offsets[]={28,30,32,42,62,46,48,82,88,92};
 for(unsigned i=0;i<10;++i)r[3+i]=int32_t(signedword(a+offsets[i]));
 r[13]=0;for(unsigned i=0;i<4;++i)if(aitdInputKeyDown(0x4c+i))r[13]|=1<<i;
 g_walkingReport[2]=n+1;
}
#endif
static uint32_t loadScenes=0;
static bool loadPixel(const uint8_t* screen,const uint8_t* colors,uint16_t x,uint16_t y,uint32_t rgb)
{
 const uint8_t* c=colors+8+screen[y*640UL+x]*8;
 return ((uint32_t(c[2])<<16)|(uint32_t(c[4])<<8)|c[6])==rgb;
}
void aitdInputFirstFloorLoad(uint32_t ticks,uint32_t scenes,const uint8_t* world,const uint8_t* screen,const uint8_t* colors)
{
#ifdef AITD_STAIRS_SAVE
 if(g_firstFloorLoadStage>=5) {
  if(g_firstFloorLoadStage==5 && ticks-g_firstFloorLoadTick>=60) {
   walkingSample(ticks,scenes,world);
   g_firstFloorLoadTick=ticks;aitdInputFirstFloorLoadCheckpoint();
  }
  return;
 }
#else
 if(g_firstFloorLoadStage==5 || g_firstFloorLoadStage==0xffff)return;
#endif
 const uint8_t* a=world-0xb292+160;
 const uint8_t* vars=(const uint8_t*)longword(world-0xcbcc);
 const uint16_t stage=g_firstFloorLoadStage;
 const uint32_t elapsed=ticks-g_firstFloorLoadTick;
 if(!stage) {
  if(g_ingameStage!=5 || !scenes || word(a)!=1 || word(a+2)!=12 || word(a+0x2e) || word(a+0x30) ||
     word(a+0x3e)!=4 || word(a+0x52)!=1 || word(world-0xd864)!=1)return;
#ifdef AITD_STAIRS_SAVE
  // Discard only the diagnostic boot skipper's pending input before Load.
  // The saved game then receives no directional input at any point.
  aitdInputAfterOSSwitch();
#endif
  key(0x67,true);key(0x18,true);loadScenes=scenes;
 } else if(elapsed>3600) {
  key(0x67,false);key(0x18,false);key(0x44,false);
  g_firstFloorLoadStage=0xffff;aitdInputFirstFloorLoadCheckpoint();return;
 } else if(stage==1) {
#ifdef AITD_STAIRS_SAVE
  if(elapsed<90)return;
#else
  if(elapsed<8)return;
#endif
  key(0x18,false);key(0x67,false);
 } else if(stage==2) {
  // Native chooser pixels measured after the original preview has drawn.
  if(!loadPixel(screen,colors,190,180,0x63431f) ||
     !loadPixel(screen,colors,400,210,0x5f8383) || !loadPixel(screen,colors,200,345,0))return;
  key(0x44,true);loadScenes=scenes;
 } else if(stage==3) {
  if(elapsed<8)return;
  // Preview/resource disk windows can clear an injected edge. Retry ordinary
  // press/release pairs until Load reads data, without an assumed draw time.
  if(!g_firstFloorLoadReadBytes) {key(0x44,(elapsed%60)>=30);return;}
  key(0x44,false);
 } else {
#ifdef AITD_STAIRS_SAVE
  if(g_firstFloorLoadReadBytes<10000 || scenes<=loadScenes || word(a+0x2e)!=1)return;
#else
  // Only actual game Load can produce this checkpoint. No game RAM is written.
  if(!vars || g_firstFloorLoadReadBytes<10000 || scenes<=loadScenes || word(a)!=1 || word(a+2)!=12 || word(a+0x2e)!=1 || word(a+0x30)!=3 ||
     word(a+0x3e)!=4 || word(a+0x52)!=1 || word(world-0xd864)!=1 || signedword(vars+42)<=0)return;
  if(signedword(a+0x1c)!=929 || signedword(a+0x20)!=2266 || word(a+0x2a)!=0 ||
     word(world-0xd8a6)!=2 || word(world-0xd8a4)!=2 || word(world-0xd8a2)!=13 || word(world-0xd8a8)!=2 ||
     signedword(vars+114)>0 || signedword(world-0x115f2+62*52)>=0 || word(vars+40) ||
     signedword(vars+80)!=10 || signedword(world-0x115f2+35*52)>=0 || word(vars+180)!=64) {
   g_firstFloorLoadStage=0xffff;aitdInputFirstFloorLoadCheckpoint();return;
  }
#endif
 }
 g_firstFloorLoadStage=stage+1;g_firstFloorLoadTick=ticks;
#ifdef AITD_STAIRS_SAVE
 if(g_firstFloorLoadStage==5)walkingSample(ticks,scenes,world);
#endif
 aitdInputFirstFloorLoadCheckpoint();
}
#endif
