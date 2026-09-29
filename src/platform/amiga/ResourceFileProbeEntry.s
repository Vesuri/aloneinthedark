    .section .text.aitdResourceFileProbe,"ax"
    .even
    .globl aitdRFileCall
aitdRFileCall:
    movem.l d2-d3/a2-a3,-(sp)
    move.l 20(sp),a0
    move.l 24(sp),a2
    move.l 28(sp),d3
    move.l 32(sp),d2
    move.l sp,a3
    suba.l d2,sp
    suba.l d3,sp
    move.l sp,a1
    tst.l d3
    beq.s 2f
1:  move.b (a2)+,(a1)+
    subq.l #1,d3
    bne.s 1b
2:  move.l #0x12345678,d0
    jmp (a0)
    .macro rfile name,opcode
    .globl \name
\name:
    .word \opcode
    bra.w rfileAfter
    .endm
    rfile aitdRFileCur,0xa994
    rfile aitdRFileUse,0xa998
    rfile aitdRFileOpen,0xa997
    rfile aitdRFilePerm,0xa9c4
    rfile aitdRFileHOpen,0xa81a
    rfile aitdRFileCreate,0xa9b1
    rfile aitdRFileHCreate,0xa81b
    rfile aitdRFileUpdate,0xa999
    rfile aitdRFileClose,0xa99a
    rfile aitdRFileAdd,0xa9ab
    rfile aitdRMutRelease,0xa9a3
    rfile aitdRMutDetach,0xa992
    rfile aitdRMutChanged,0xa9aa
    rfile aitdRMutWrite,0xa9b0
    rfile aitdRMutRemove,0xa9ad
    rfile aitdRMutAttrs,0xa9a6
    rfile aitdRMutCount,0xa80d
    rfile aitdRMutLookup,0xa81f
    rfile aitdRMutIndex,0xa80e
    rfile aitdRMutLoad,0xa9a2
    .globl aitdRMutEmpty
aitdRMutEmpty:
    move.l (sp)+,a0
    .word 0xa02b
    bra.w rfileAfter
    .globl aitdRMutDispose
aitdRMutDispose:
    move.l (sp)+,a0
    .word 0xa023
    bra.w rfileAfter
rfileAfter:
    move.l d0,g_resourceLookupD0
    move.l sp,d0
    sub.l a3,d0
    add.l d2,d0
    move.l d0,g_resourceFileStackError
    moveq #0,d0
    cmpi.l #2,d2
    bne.s 3f
    move.w (sp),d0
3:  cmpi.l #4,d2
    bne.s 4f
    move.l (sp),d0
4:  move.l a3,sp
    movem.l (sp)+,d2-d3/a2-a3
    rts
    .globl aitdRFileAllocate
aitdRFileAllocate:
    moveq #4,d0
    .word 0xa122
    move.l d0,g_resourceLookupD0
    move.l a0,d0
    rts
