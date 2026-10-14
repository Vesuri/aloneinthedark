| Diagnostic: TickCount and the original (Dan2,$3364) absolute-deadline loop.
    .section .text.aitd_tick_probe,"ax"
    .even
    .globl aitd_tick_probe_read
aitd_tick_probe_read:
    clr.l -(sp)
    .word 0xa975
    move.l (sp)+,d0
    rts
    .globl aitd_tick_probe_wait
aitd_tick_probe_wait:
    move.l d5,-(sp)
    move.l 8(sp),d5
1:  clr.l -(sp)
    .word 0xa975
    cmp.l (sp)+,d5
    bhi.s 1b
    move.l -4(sp),d0
    move.l (sp)+,d5
    rts
