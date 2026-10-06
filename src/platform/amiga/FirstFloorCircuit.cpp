// Diagnostic ordinary-input replay of the measured original first-floor circuit.
#include "FirstFloorCircuit.h"
#ifdef AITD_FIRSTFLOOR_CIRCUIT
#include "MacInput.h"
#include "FirstFloorLoad.h"

extern "C" {
volatile uint16_t g_circuitStage=0,g_circuitCycle=0,g_circuitAttempts=0;
volatile uint32_t g_circuitTick=0;
__attribute__((noinline)) void aitdInputCircuitCheckpoint() {__asm__ volatile("nop" ::: "memory");}
}
static uint16_t word(const uint8_t* p) {return uint16_t(p[0])<<8|p[1];}
static uint32_t longword(const uint8_t* p) {return uint32_t(word(p))<<16|word(p+2);}
static int16_t signedword(const uint8_t* p) {return int16_t(word(p));}
static void key(uint8_t k,bool down) {aitdInputInjectProbeKey(k,down);}
static void release() {for(uint8_t k=0x4c;k<=0x4f;++k)key(k,false);key(0x40,false);key(0x18,false);key(0x23,false);}

enum Kind {Face,GreaterX,LessX,GreaterZ,LessZ,AlignX,AlignZ,Room,RoomOrZ,RoomAndZ,SpaceUnlessRoom,Action,Door,Battle,SkipDead,WesternHall,Bathroom,Finish};
struct Step {uint8_t kind;int16_t arg,low,high;};
// Static storage keeps the route off the Macintosh trap dispatcher's small stack.
static const Step steps[]={
 {Face,512,0,0},{Room,1,0,0},{GreaterZ,0,0,0},{Face,256,0,0},{GreaterX,200,0,0},{AlignX,1,100,500},
 {Face,512,0,0},{Room,4,0,0},{GreaterZ,650,0,0},{AlignZ,1,900,1050},{Face,256,0,0},{Room,5,0,0},
 {GreaterX,-1800,0,0},{AlignX,1,-1700,-1550},{Face,0,0,0},{LessZ,-1500,0,0},{Face,256,0,0},
 {AlignX,1,-2400,-2200},{Face,0,0,0},{SpaceUnlessRoom,1,0,0},{Room,1,0,0},
 {RoomOrZ,2,-850,0},{SpaceUnlessRoom,2,0,0},{Room,2,0,0},{LessZ,800,0,0},
 {SkipDead,9,0,0},{Action,16,0,0},{Face,512,0,0},{GreaterZ,900,0,0},{AlignZ,1,1200,1380},
 {Face,768,0,0},{AlignX,0,600,800},{Face,512,0,0},{Action,16,0,0},{Door,0,0,0},{Battle,0,0,0},
 {Action,64,0,0},{Face,512,0,0},{RoomOrZ,1,1600,1},{SpaceUnlessRoom,1,0,0},{Room,1,0,0},
 {Face,256,0,0},{AlignX,1,2800,2900},{Face,512,0,0},{Room,5,0,0},{GreaterZ,-1200,0,0},{Face,256,0,0},{GreaterX,-1800,0,0},{AlignX,1,-1700,-1550},
 {Face,512,0,0},{GreaterZ,650,0,0},{AlignZ,1,650,850},{Face,768,0,0},{Room,4,0,0},
 {LessX,100,0,0},{AlignX,0,-200,100},{Face,0,0,0},{RoomOrZ,1,-1600,0},{SpaceUnlessRoom,1,0,0},
 {Room,1,0,0},{WesternHall,0,0,0},{Face,0,0,0},{RoomAndZ,1,0,0},{AlignZ,0,-150,0},
 {Face,768,0,0},{LessX,-650,0,0},{AlignX,0,-900,-700},{Face,0,0,0},{RoomOrZ,3,-850,0},
 {SpaceUnlessRoom,3,0,0},{Room,3,0,0},{Bathroom,0,0,0},{Finish,0,0,0}
};
static uint8_t phase=0,turnKey=0,alignKey=0;
static uint32_t phaseTick=0,phaseScenes=0;
static bool aligned(uint32_t ticks,uint16_t animation,int16_t position,const Step& s)
{
 if(alignKey) {
  const uint16_t expected=alignKey==0x4d ? 256 : 254;
  if(animation!=expected)return false;
  key(alignKey,false);alignKey=0;phaseTick=ticks;phase=2;return false;
 }
 if(animation!=4 || (phase==2 && ticks-phaseTick<30))return false;
 if(position>=s.low && position<=s.high)return true;
 const bool back=(position>s.high)==bool(s.arg);
 alignKey=back ? 0x4d : 0x4c;key(alignKey,true);phase=1;return false;
}
static void advance(uint32_t ticks,uint32_t scenes,uint16_t count=1)
{
 g_circuitStage+=count;g_circuitTick=ticks;phaseTick=ticks;phaseScenes=scenes;phase=0;alignKey=0;
 aitdInputCircuitCheckpoint();
}
static void fail() {release();g_circuitStage=0xffff;aitdInputCircuitCheckpoint();}

void aitdInputFirstFloorCircuit(uint32_t ticks,uint32_t scenes,const uint8_t* world)
{
#ifdef AITD_FIRSTFLOOR_LOAD
 if(g_firstFloorLoadStage!=5 || g_circuitStage==0xffff || g_circuitStage==0xfffe)return;
#else
 if(g_combatRouteStage!=66 || g_circuitStage==0xffff || g_circuitStage==0xfffe)return;
#endif
 const uint8_t* a=world-0xb292+160;
 const uint8_t* vars=(const uint8_t*)longword(world-0xcbcc);
 if(!vars || word(a)!=1 || word(a+2)!=12 || word(a+0x2e)!=1 || signedword(vars+42)<=0) {fail();return;}
 const uint16_t animation=word(a+0x3e),track=word(a+0x52),room=word(a+0x30),beta=word(a+0x2a)&1023;
 const int16_t x=signedword(a+0x1c),z=signedword(a+0x20);
 const bool manual=animation==4 && track==1 && word(world-0xd864)==1;
 const int16_t enemySlot=signedword(world-0x115f2+35*52),enemyHp=signedword(vars+80);
 if(!g_circuitCycle) {
  if(!manual || room!=3)return;
  g_circuitCycle=1;g_circuitTick=ticks;phaseTick=ticks;phaseScenes=scenes;aitdInputCircuitCheckpoint();
 }
 if(g_circuitStage>=sizeof(steps)/sizeof(steps[0])) {fail();return;}
 const Step& s=steps[g_circuitStage];
 if(ticks-g_circuitTick>(s.kind==Battle ? 36000UL : 3600UL)) {fail();return;}
 if(s.kind==SkipDead) {
  if(enemyHp<=0 && enemySlot<0 && !word(vars+40)) {advance(ticks,scenes,s.arg+1);return;}
  if(enemySlot<0)return;
  advance(ticks,scenes);return;
 }
 if(s.kind==Finish) {
  if(!manual || room!=3)return;
  if(g_activeGameplayTicks>=36000) {release();g_circuitStage=0xfffe;aitdInputCircuitCheckpoint();return;}
  ++g_circuitCycle;if(g_circuitCycle>30) {fail();return;}
  g_circuitStage=0;g_circuitTick=ticks;phaseTick=ticks;phaseScenes=scenes;phase=0;aitdInputCircuitCheckpoint();return;
 }
 if(s.kind==WesternHall || s.kind==Bathroom) {
  if(!manual)return;
  if((s.kind==WesternHall && (room!=1 || x>=1300)) || (s.kind==Bathroom && room!=3) ||
     enemyHp>0 || enemySlot>=0 || word(vars+40) || signedword(vars+114)>0 || signedword(world-0x115f2+62*52)>=0) {fail();return;}
  advance(ticks,scenes);return;
 }
 if(s.kind==Action) {
  const uint8_t actionKey=s.arg==16 ? 0x23 : 0x18;
  if(!phase) {if(!manual)return;key(actionKey,true);phase=1;phaseTick=ticks;return;}
  if(phase==1) {if(ticks-phaseTick<120)return;key(actionKey,false);phase=2;phaseTick=ticks;return;}
  if(!manual || word(vars+180)!=s.arg || ticks-phaseTick<30)return;
  advance(ticks,scenes);return;
 }
 if(s.kind==Face) {
  const uint16_t delta=(s.arg-beta)&1023;
  if(!phase) {
   if(!manual)return;
   if(delta<=16 || delta>=1008) {advance(ticks,scenes);return;}
   turnKey=delta>512 ? 0x4f : 0x4e;key(turnKey,true);phase=1;return;
  }
  if(phase==1) {if(delta>16 && delta<1008)return;key(turnKey,false);phase=2;phaseTick=ticks;return;}
  if(!manual || ticks-phaseTick<30)return;
  advance(ticks,scenes);return;
 }
 if(s.kind==AlignX || s.kind==AlignZ) {
  if(aligned(ticks,animation,s.kind==AlignX ? x : z,s))advance(ticks,scenes);
  return;
 }
 if(s.kind==SpaceUnlessRoom || s.kind==Door) {
  if(!phase) {
   if(!manual)return;
   if(s.kind==SpaceUnlessRoom && room==s.arg) {advance(ticks,scenes);return;}
   if(s.kind==Door && word(vars+60)==1) {advance(ticks,scenes);return;}
   key(s.kind==Door ? 0x4c : 0x40,true);phase=1;phaseTick=ticks;return;
  }
  if(phase==1) {
   // Walk toward the door in Fight, as in the paired bedroom encounter.
   // Only the original connecting-door state permits this step to finish.
   if(s.kind==Door ? word(vars+60)!=1 : ticks-phaseTick<120)return;
   key(s.kind==Door ? 0x4c : 0x40,false);phase=2;phaseTick=ticks;return;
  }
  if(!manual || ticks-phaseTick<(s.kind==Door ? 30U : 120U) || (s.kind==Door && word(vars+60)!=1))return;
  advance(ticks,scenes);return;
 }
 if(s.kind==Battle) {
  if(enemyHp<=0) {
   release();if(enemySlot<0 && !word(vars+40) && manual) {g_circuitAttempts=0;advance(ticks,scenes);}return;
  }
  if(room!=1 && room!=2) {fail();return;}
  if(!phase) {if(!manual)return;key(0x23,true);phase=1;phaseTick=ticks;return;}
  if(phase==1) {if(word(vars+180)!=16 || ticks-phaseTick<2)return;key(0x23,false);phase=2;phaseTick=ticks;return;}
  if(phase==2) {
   if(!manual || word(vars+180)!=16 || ticks-phaseTick<30 || enemySlot<0 || enemySlot>=50)return;
   const uint8_t* npc=world-0xb292+enemySlot*160;
   // Compare positions only while both actors occupy the same actual room.
   if(word(npc+0x30)!=room) {phase=4;phaseTick=ticks;return;}
   {
    const int32_t dx=int32_t(signedword(npc+0x1c))-x,dz=int32_t(signedword(npc+0x20))-z;
    const uint32_t ax=dx<0 ? -dx : dx,az=dz<0 ? -dz : dz;
    const uint16_t target=ax>az ? (dx>0 ? 256 : 768) : (dz>0 ? 512 : 0);
    const uint16_t delta=(target-beta)&1023;
    if(delta>16 && delta<1008) {turnKey=delta>512 ? 0x4f : 0x4e;key(turnKey,true);phase=3;phaseScenes=target;return;}
   }
   phase=4;phaseTick=ticks;return;
  }
  if(phase==3) {
   const uint16_t delta=(phaseScenes-beta)&1023;
   if(delta>16 && delta<1008)return;
   key(turnKey,false);phase=4;phaseTick=ticks;return;
  }
  if(phase==4) {
   if(!manual || ticks-phaseTick<30 || enemySlot<0 || enemySlot>=50)return;
   if(++g_circuitAttempts>32) {fail();return;}
   key(0x40,true);key(0x4c,true);phase=5;phaseTick=ticks;return;
  }
  if(phase==5) {if(ticks-phaseTick<180)return;key(0x4c,false);key(0x40,false);phase=6;phaseTick=ticks;return;}
  if(!manual || ticks-phaseTick<30)return;
  phase=2;phaseTick=ticks-30;return;
 }
 bool reached=false;
 if(s.kind==GreaterX)reached=x>=s.arg;
 else if(s.kind==LessX)reached=x<=s.arg;
 else if(s.kind==GreaterZ)reached=z>=s.arg;
 else if(s.kind==LessZ)reached=z<=s.arg;
 else if(s.kind==Room)reached=room==s.arg;
 else if(s.kind==RoomOrZ)reached=room==s.arg || (s.high ? z>=s.low : z<=s.low);
 else if(s.kind==RoomAndZ)reached=room==s.arg && (s.high ? z>=s.low : z<=s.low);
 else {fail();return;}
 if(!phase) {if(!manual)return;if(reached) {advance(ticks,scenes);return;}key(0x4c,true);phase=1;return;}
 if(phase==1) {if(!reached)return;key(0x4c,false);phase=2;phaseTick=ticks;phaseScenes=scenes;return;}
 if(!manual || ticks-phaseTick<30 || scenes<=phaseScenes)return;
 // Require the destination after release/coasting, not only on its first frame.
 if(!reached) {key(0x4c,true);phase=1;return;}
 advance(ticks,scenes);
}
#endif
