// Experimental diagnostic: full knockback/walking/exit route is not accepted.
// Ordinary-input replay of the original living room-4 recovery observer.
#include "FirstFloorRecovery.h"
#ifdef AITD_ROOM4_RECOVERY
#include "MacInput.h"
extern "C" {
void aitdInputCombatCheckpoint();
volatile uint16_t g_room4RecoveryStage=0;
volatile uint32_t g_room4RecoveryTick=0;
__attribute__((noinline)) void aitdInputRoom4RecoveryCheckpoint() {__asm__ volatile("nop" ::: "memory");}
}
static uint16_t word(const uint8_t* p) {return uint16_t(p[0])<<8|p[1];}
static uint32_t longword(const uint8_t* p) {return uint32_t(word(p))<<16|word(p+2);}
static int16_t signedword(const uint8_t* p) {return int16_t(word(p));}
static void key(uint8_t k,bool down) {aitdInputInjectProbeKey(k,down);}
static uint8_t phase=0,held=0;
static uint32_t phaseTick=0;
static void advance(uint16_t next,uint32_t ticks)
{
 g_room4RecoveryStage=next;g_room4RecoveryTick=ticks;phaseTick=ticks;phase=0;held=0;
 aitdInputRoom4RecoveryCheckpoint();
}
static void fail()
{
 for(uint8_t k=0x4c;k<=0x4f;++k)key(k,false);
 key(0x60,false);key(0x40,false);key(0x18,false);key(0x23,false);
 g_room4RecoveryStage=0xffff;g_combatRouteStage=0xffff;
 aitdInputRoom4RecoveryCheckpoint();
}
static bool face(uint16_t target,uint16_t beta,bool manual,uint32_t ticks)
{
 const uint16_t delta=(target-beta)&1023;
 if(!phase) {
  if(!manual)return false;
  if(delta<=16 || delta>=1008)return true;
  held=delta>512 ? 0x4f : 0x4e;key(held,true);phase=1;return false;
 }
 if(phase==1) {
  if(delta>16 && delta<1008)return false;
  key(held,false);phase=2;phaseTick=ticks;return false;
 }
 return manual && ticks-phaseTick>=30;
}
static bool action(uint16_t desired,uint16_t actual,bool manual,uint32_t ticks)
{
 const uint8_t k=desired==16 ? 0x23 : 0x18;
 if(!phase) {if(!manual)return false;key(k,true);phase=1;phaseTick=ticks;return false;}
 if(phase==1) {if(ticks-phaseTick<120)return false;key(k,false);phase=2;phaseTick=ticks;return false;}
 return manual && ticks-phaseTick>=30 && actual==desired;
}
static bool alignZ(int16_t z,int16_t low,int16_t high,bool positive,uint16_t animation,bool manual,uint32_t ticks)
{
 if(held) {
  // A hit can interrupt a queued walking step before it is observed.
  if(animation!=237 && animation!=(held==0x4d ? 256 : 254))return false;
  key(held,false);held=0;phase=2;phaseTick=ticks;return false;
 }
 if(!manual || (phase==2 && ticks-phaseTick<30))return false;
 if(z>=low && z<=high)return true;
 held=((z>high)==positive) ? 0x4d : 0x4c;key(held,true);phase=1;return false;
}
static bool walk(bool reached,bool manual,bool run,uint32_t ticks)
{
 if(!phase) {
  if(!manual)return false;
  if(reached)return true;
  if(run)key(0x60,true);
  key(0x4c,true);phase=1;return false;
 }
 if(phase==1) {
  if(!reached)return false;
  key(0x4c,false);if(run)key(0x60,false);phase=2;phaseTick=ticks;return false;
 }
 if(!manual || ticks-phaseTick<30)return false;
 if(!reached) {if(run)key(0x60,true);key(0x4c,true);phase=1;return false;}
 return true;
}
bool aitdInputRoom4Recovery(uint32_t ticks,uint32_t scenes,const uint8_t* world)
{
 static uint32_t entryScenes=0;
 if(g_room4RecoveryStage==0xffff)return false;
 uint16_t combat=g_combatRouteStage;
 if(combat!=17 && combat!=21 && combat!=25)return true;
 const uint8_t* actor=world-0xb292+160;
 const uint8_t* vars=(const uint8_t*)longword(world-0xcbcc);
 const uint16_t room=word(actor+0x30),animation=word(actor+0x3e),beta=word(actor+0x2a)&1023;
 if(!vars || word(actor)!=1 || word(actor+2)!=12 || word(actor+0x2e)!=1 ||
    signedword(vars+42)<=0 || (room!=4 && room!=5)) {fail();return false;}
 const bool manual=animation==4 && word(actor+0x52)==1 && word(world-0xd864)==1;
 const int16_t x=signedword(actor+0x1c),z=signedword(actor+0x20);
 const uint16_t actual=word(vars+180);
 if(combat==17) {
  if(!manual)return false;
  // Begin the measured retreat at the released approach, before the
  // optional northward contact step. Only diagnostic route state changes.
  combat=21;g_combatRouteStage=21;g_combatRouteTick=ticks;
  aitdInputCombatCheckpoint();
 }
 if(combat==21) {
  if(!g_room4RecoveryStage) {
   // Match the original retreat before engaging; do not rely on a random
   // sequence of kick/hit timings to reach the adjoining room.
   aitdInputCombatRecoveryBegin(ticks);
   if(room!=4) {advance(1,ticks);return false;}
   if(signedword(vars+114)<=0 || signedword(world-0x115f2+62*52)<0) {fail();return false;}
   // Stop the earlier pulse sequence at the actual live knockback transition.
   // Only diagnostic key/phase state changes; the original actor is read only.
   aitdInputCombatRecoveryBegin(ticks);entryScenes=scenes;advance(11,ticks);return false;
  }
  if(g_room4RecoveryStage<11) {
   if(room==4) {
    if(signedword(vars+114)<=0) {fail();return false;}
    aitdInputCombatRecoveryBegin(ticks);entryScenes=scenes;advance(11,ticks);return false;
   }
   if(ticks-g_room4RecoveryTick>(g_room4RecoveryStage==6 ? 12000UL : 3600UL)) {fail();return false;}
   bool done=false;
   switch(g_room4RecoveryStage) {
    case 1:done=face(512,beta,manual,ticks);break;
    case 2:done=alignZ(z,650,1050,true,animation,manual,ticks);break;
    case 3:done=action(64,actual,manual,ticks);break;
    case 4:done=face(256,beta,manual,ticks);break;
    case 5:
     // Replay the original eastward clearance attempt. A westward room
     // transition during this input must come from the original hit response.
     done=walk(x>=-1800,manual,false,ticks);break;
    case 6:break;
    default:fail();return false;
   }
   if(done)advance(g_room4RecoveryStage+1,ticks);
   return false;
  }
  if(g_room4RecoveryStage==12)return true;
  if(ticks-g_room4RecoveryTick>1800) {fail();return false;}
  if(!manual || scenes<=entryScenes)return false;
  if(room!=4 || signedword(vars+114)<=0) {fail();return false;}
  if(!action(16,actual,manual,ticks))return false;
  g_combatRouteTick=ticks;advance(12,ticks);return false;
 }
 if(g_room4RecoveryStage==30)return true;
 if(!g_room4RecoveryStage) {fail();return false;} // The required room4 path was never exercised.
 if(g_room4RecoveryStage==12) {
  if(room==5) {advance(30,ticks);return true;}
  if(!manual)return false;
  if(signedword(vars+114)>0 || signedword(world-0x115f2+62*52)>=0 || (actual!=16 && actual!=64)) {fail();return false;}
  // The original can retain Fight while the second room-4 enemy is active.
  advance(x < -1500 ? 40 : 20,ticks);return false;
 }
 if(ticks-g_room4RecoveryTick>3600) {fail();return false;}
 bool done=false;
 switch(g_room4RecoveryStage) {
  // The original room's furniture leaves only the eastward corridor open.
  // Defeat its second monster with ordinary Fight/forward-kick input.
  case 40:done=face(256,beta,manual,ticks);break;
  case 41: {
   const int16_t slot=signedword(world-0x115f2+57*52);
   const uint8_t* npc=slot>=0 && slot<50 ? world-0xb292+slot*160 : 0;
   done=walk(!npc || signedword(npc+0x1c)-x<=700,manual,false,ticks);
   break;
  }
  case 42:
   if(signedword(world-0x115f2+57*52)<0) {
    key(0x40,false);key(0x4c,false);
    if(manual)advance(20,ticks);
   } else if(!phase && manual) {
    key(0x40,true);key(0x4c,true);phase=1;
   }
   return false;
  case 20:done=(!phase && manual && z>=650 && z<=1200) || face(0,beta,manual,ticks);break;
  case 21:done=alignZ(z,650,1200,false,animation,manual,ticks);break;
  case 22:done=face(256,beta,manual,ticks);break;
  case 23:done=walk(room==5,manual,true,ticks);break;
  case 24:done=action(64,actual,manual,ticks);break;
  case 25:
   if(!manual || room!=5 || actual!=64)return false;
   g_combatRouteTick=ticks;advance(30,ticks);return true;
  default:fail();return false;
 }
 if(done)advance(g_room4RecoveryStage+1,ticks);
 return false;
}
#endif
