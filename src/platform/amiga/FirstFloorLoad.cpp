// Optional diagnostic ordinary game Load; never restores emulator state.
#include "FirstFloorLoad.h"
#ifdef AITD_FIRSTFLOOR_LOAD
#include "MacInput.h"
static uint16_t word(const uint8_t* p) {return uint16_t(p[0])<<8|p[1];}
static uint32_t longword(const uint8_t* p) {return uint32_t(word(p))<<16|word(p+2);}
static int16_t signedword(const uint8_t* p) {return int16_t(word(p));}
static void key(uint8_t k,bool down) {aitdInputInjectProbeKey(k,down);}

extern "C" {
volatile uint16_t g_firstFloorLoadStage=0;
volatile uint32_t g_firstFloorLoadTick=0,g_firstFloorLoadReadBytes=0;
__attribute__((noinline)) void aitdInputFirstFloorLoadCheckpoint() {__asm__ volatile("nop" ::: "memory");}
}
extern "C" void aitdInputFirstFloorLoadRead(uint32_t bytes)
{
 if(g_firstFloorLoadStage==3 || g_firstFloorLoadStage==4)g_firstFloorLoadReadBytes+=bytes;
}
static uint32_t loadScenes=0;
static bool loadPixel(const uint8_t* screen,const uint8_t* colors,uint16_t x,uint16_t y,uint32_t rgb)
{
 const uint8_t* c=colors+8+screen[y*640UL+x]*8;
 return ((uint32_t(c[2])<<16)|(uint32_t(c[4])<<8)|c[6])==rgb;
}
void aitdInputFirstFloorLoad(uint32_t ticks,uint32_t scenes,const uint8_t* world,const uint8_t* screen,const uint8_t* colors)
{
 if(g_firstFloorLoadStage==5 || g_firstFloorLoadStage==0xffff)return;
 const uint8_t* a=world-0xb292+160;
 const uint8_t* vars=(const uint8_t*)longword(world-0xcbcc);
 const uint16_t stage=g_firstFloorLoadStage;
 const uint32_t elapsed=ticks-g_firstFloorLoadTick;
 if(!stage) {
  if(g_ingameStage!=5 || !scenes || word(a)!=1 || word(a+2)!=12 || word(a+0x2e) || word(a+0x30) ||
     word(a+0x3e)!=4 || word(a+0x52)!=1 || word(world-0xd864)!=1)return;
  key(0x67,true);key(0x18,true);loadScenes=scenes;
 } else if(elapsed>3600) {
  key(0x67,false);key(0x18,false);key(0x44,false);
  g_firstFloorLoadStage=0xffff;aitdInputFirstFloorLoadCheckpoint();return;
 } else if(stage==1) {
  if(elapsed<8)return;key(0x18,false);key(0x67,false);
 } else if(stage==2) {
  // Native chooser pixels measured after the original preview has drawn.
  if(!loadPixel(screen,colors,190,180,0x63431f) ||
     !loadPixel(screen,colors,400,210,0x5f8383) || !loadPixel(screen,colors,200,345,0))return;
  key(0x44,true);loadScenes=scenes;
 } else if(stage==3) {
  if(elapsed<8)return;key(0x44,false);
 } else {
  // Only actual game Load can produce this checkpoint. No game RAM is written.
  if(!vars || g_firstFloorLoadReadBytes<10000 || scenes<=loadScenes || word(a)!=1 || word(a+2)!=12 || word(a+0x2e)!=1 || word(a+0x30)!=3 ||
     word(a+0x3e)!=4 || word(a+0x52)!=1 || word(world-0xd864)!=1 || signedword(vars+42)<=0)return;
  if(signedword(a+0x1c)!=929 || signedword(a+0x20)!=2266 || word(a+0x2a)!=0 ||
     word(world-0xd8a6)!=2 || word(world-0xd8a4)!=2 || word(world-0xd8a2)!=13 || word(world-0xd8a8)!=2 ||
     signedword(vars+114)>0 || signedword(world-0x115f2+62*52)>=0 || word(vars+40) ||
     signedword(vars+80)!=10 || signedword(world-0x115f2+35*52)>=0 || word(vars+180)!=64) {
   g_firstFloorLoadStage=0xffff;aitdInputFirstFloorLoadCheckpoint();return;
  }
 }
 g_firstFloorLoadStage=stage+1;g_firstFloorLoadTick=ticks;aitdInputFirstFloorLoadCheckpoint();
}
#endif
