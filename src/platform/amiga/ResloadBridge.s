| C ABI to WHDLoad D0/D1/A0/A1; preserve all C callee-saved registers.
| Entry table offsets are four-byte branch slots, not library negative vectors.
    .section .text.aitdResloadCall,"ax"
    .even
    .globl aitdResloadCall
aitdResloadCall:
    movem.l d2-d7/a2-a6,-(sp)
    move.l 48(sp),a2
    adda.l 52(sp),a2
    move.l 56(sp),d0
    move.l 60(sp),d1
    move.l 64(sp),a0
    move.l 68(sp),a1
    jsr (a2)
    move.l 72(sp),a0
    move.l d1,(a0)
    movem.l (sp)+,d2-d7/a2-a6
    rts
