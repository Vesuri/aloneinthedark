#ifdef AITD_MONSTER_AUDIT
#include <proto/exec.h>
#include <proto/dos.h>
#include <exec/execbase.h>
#include <dos/dos.h>
#include "MonsterProfile.h"
#include "FileAccess.h"
extern "C" { extern volatile uint16_t g_videoPAL; }
// Big-endian wire header: magic, version, count, phase, PAL, resload,
// AttnFlags, CACR before/after, cleanup result, then five event row indices.
extern "C" { volatile uint32_t g_monsterAudit[16]={0x41495444,0x4d4f4e31,1}; }
static __attribute__((interrupt)) void readCACRSupervisor()
{
    // Like the framework's getVBR: return the control register in D0 via RTE.
    __asm__ volatile(".short 0x4e7a,0x0002");
}
void aitdMonsterAuditBegin()
{
    g_monsterAudit[5]=g_videoPAL;
    g_monsterAudit[6]=FileAccess::resloadActive();
    g_monsterAudit[7]=SysBase->AttnFlags;
    g_monsterAudit[8]=Supervisor((ULONG (*)())readCACRSupervisor);
}
bool aitdMonsterAuditSave(bool cleanupOK)
{
    // Caller has restored interrupts, DMA, the View and multitasking. No file
    // output or OS return is introduced into the measured sequence.
    g_monsterAudit[3]=g_monsterCount;
    g_monsterAudit[4]=g_monsterPhase;
    g_monsterAudit[9]=Supervisor((ULONG (*)())readCACRSupervisor);
    g_monsterAudit[10]=cleanupOK;
    const char* path=g_monsterAudit[6] ? "PROGDIR:monster-whd.bin" : "PROGDIR:monster-amigaos.bin";
    BPTR file=Open((CONST_STRPTR)path,MODE_NEWFILE);
    bool saved=false;
    if(file) {
        const uint32_t bytes=g_monsterCount*sizeof(MonsterProfileFrame);
        const bool header=Write(file,(APTR)g_monsterAudit,sizeof(g_monsterAudit))==sizeof(g_monsterAudit);
        const bool rows=header && Write(file,(APTR)g_monsterFrames,bytes)==(LONG)bytes;
        saved=Close(file)!=0 && rows;
    }
    PutStr((CONST_STRPTR)(saved && cleanupOK && g_monsterPhase==5
        ? "Monster audit complete; report saved beside the executable.\n"
        : "Monster audit FAILED or incomplete; check report and disk space.\n"));
    return saved && cleanupOK && g_monsterPhase==5;
}
#endif
