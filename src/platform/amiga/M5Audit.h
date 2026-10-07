#ifndef AITD_M5_AUDIT_H
#define AITD_M5_AUDIT_H
#ifdef AITD_M5_AUDIT
void* aitdM5Alloc(unsigned long bytes,unsigned long flags);
void aitdM5Free(void* ptr,unsigned long bytes);
void aitdM5Init();
void aitdM5Stop();
struct M5AuditSession { M5AuditSession(){aitdM5Init();} ~M5AuditSession(){aitdM5Stop();} };
void aitdM5Trap(unsigned long pc,unsigned short trap,unsigned short song);
void aitdM5Note(unsigned short song,unsigned short note,unsigned long due,unsigned long actual,unsigned long effects);
void aitdM5Zone(const void* base,unsigned long used);
unsigned long aitdM5Clock();
void aitdM5IRQBegin(unsigned short remaining,unsigned short period);
void aitdM5IRQEnd();
void aitdM5TimerStart();
#define M5_ALLOC_MEM aitdM5Alloc
#define M5_FREE_MEM aitdM5Free
#else
#define M5_ALLOC_MEM AllocMem
#define M5_FREE_MEM FreeMem
#endif
#endif
