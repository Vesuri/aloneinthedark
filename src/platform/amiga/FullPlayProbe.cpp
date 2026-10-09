// File-controlled ordinary input. No original game memory is modified.
#include "FullPlayProbe.h"
#ifdef AITD_FULL_PLAY
#include <proto/dos.h>
#include <dos/dos.h>
#include "MacInput.h"
#include "SystemWindow.h"
extern volatile uint32_t g_macTicks;
extern "C" {
volatile uint32_t g_fullPlaySequence=0,g_fullPlayMask=0,g_fullPlayDuration=0,g_fullPlayTick=0;
volatile uint16_t g_fullPlayStatus=0;
#ifdef AITD_ESCAPE_PROBE
extern volatile uint32_t g_macSceneFramesCompleted;
// Core-dump report: magic, last phase, reserved, then ten tick/frame pairs.
volatile uint32_t g_escapeReport[24]={0x41495444,0x45534350};
#endif
__attribute__((noinline)) void aitdInputFullPlayCheckpoint() {
#ifdef AITD_ESCAPE_PROBE
 if(g_fullPlaySequence<=9) {
  g_escapeReport[2]=g_fullPlaySequence;
  g_escapeReport[4+2*g_fullPlaySequence]=g_macTicks;
  g_escapeReport[5+2*g_fullPlaySequence]=g_macSceneFramesCompleted;
 }
#endif
 __asm__ volatile("nop" ::: "memory");
}
}
// Up, Down, Left, Right, Space, Return, Escape, F, O, Shift, P, Right-Amiga, S.
static const uint8_t keys[]={0x4c,0x4d,0x4f,0x4e,0x40,0x44,0x45,0x23,0x18,0x60,0x19,0x67,0x21};
static volatile uint32_t held=0,started=0;
static uint32_t sequence=0,conditionField=0,conditionMode=0;
static int32_t conditionTarget=0;
static bool initialized=false;
static volatile bool active=false;
static void apply(uint32_t mask)
{
 // Event modifiers are sampled when a non-modifier key goes down.
 // Release ordinary keys first, then modifiers; press in the opposite order.
 const uint32_t modifiers=(1UL<<9)|(1UL<<11);
 const uint32_t released=held&~mask,pressed=mask&~held;
 const uint32_t groups[]={released&~modifiers,released&modifiers,
                          pressed&modifiers,pressed&~modifiers};
 for(unsigned group=0;group<4;++group)
  for(unsigned i=0;i<sizeof(keys);++i)
   if(groups[group]&(1UL<<i))aitdInputInjectProbeKey(keys[i],group>=2);
 held=mask;
}
static int32_t readCommand(void*)
{
#ifdef AITD_ESCAPE_PROBE
 // Ordinary Escape levels: open/close with 100 ms and one-second holds.
 static const uint16_t durations[]={180,6,30,6,30,60,30,60,30};
 g_fullPlaySequence=sequence+1;
 g_fullPlayMask=sequence<9 && (sequence&1) ? 1UL<<6 : 0;
 g_fullPlayDuration=sequence<9 ? durations[sequence] : 3600;
 return 0;
#else
 uint8_t bytes[25];
 BPTR file=Open("PROGDIR:M6Control",MODE_OLDFILE);
 if(!file)return -1;
 LONG count=Read(file,bytes,sizeof(bytes));Close(file);
 if(count!=24)return -1;
 uint32_t words[6]={0,0,0,0,0,0};
 for(unsigned i=0;i<24;++i)words[i/4]=(words[i/4]<<8)|bytes[i];
 if(words[0]!=sequence+1 || (words[1]>>sizeof(keys)) ||
    !words[2] || words[2]>3600 || words[3]>6 || words[5]>3 ||
    ((words[3]==0)!=(words[5]==0)) || (words[5]==3 && words[3]!=3))return -1;
 g_fullPlaySequence=words[0];g_fullPlayMask=words[1];g_fullPlayDuration=words[2];
 conditionField=words[3];conditionTarget=(int32_t)words[4];conditionMode=words[5];
 return 0;
#endif
}
void aitdInputFullPlayVBI(uint32_t ticks)
{
 // Original menu loops can inspect KeyMap without making a Toolbox call.
 // Like a physical keyboard release, expiry must not depend on that loop.
 if(active && ticks-started>=g_fullPlayDuration) {apply(0);active=false;}
}
bool aitdInputFullPlayNeedsService(const uint8_t* hero)
{
 // Holding keys needs no DOS access. Inspect waypoints before requesting the
 // user-service OS window; VBI already expires the duration independently.
 if(!active)return true;
 if(!conditionField)return false;
 static const uint8_t offsets[]={0,28,32,42,46,48,62};
 const uint8_t* p=hero+offsets[conditionField];
 const int32_t value=(int16_t)((uint16_t)p[0]<<8|p[1]);
 const uint32_t delta=(value-conditionTarget)&1023;
 return conditionMode==1 ? value>=conditionTarget :
     conditionMode==2 ? value<=conditionTarget : delta<=8 || delta>=1016;
}
void aitdInputFullPlay(uint32_t ticks,const uint8_t* hero)
{
 if(active && aitdInputFullPlayNeedsService(hero)) {apply(0);active=false;}
 if(initialized && active)return;
 initialized=true;active=false;g_fullPlayStatus=sequence ? 2 : 0;
 g_fullPlayTick=ticks;aitdInputFullPlayCheckpoint();
 // The host writes a complete command while stopped. DOS runs only through
 // the user-service OS window, never from the supervisor trap or an interrupt.
 if(aitdSystemWindow(readCommand,0)!=0) {
  apply(0);g_fullPlayStatus=0xffff;aitdInputFullPlayCheckpoint();return;
 }
 sequence=g_fullPlaySequence;apply(g_fullPlayMask);
 started=g_macTicks;active=true;g_fullPlayStatus=1;
}
#endif
