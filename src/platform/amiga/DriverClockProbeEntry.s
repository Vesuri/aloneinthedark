    .section .text.aitdProbeDriverClock,"ax"
    .even
    .globl aitdProbeDriverClock
aitdProbeDriverClock:
    move.l 4(sp),a0
    move.l 8(sp),-(sp)
    move.l #15,-(sp)
    move.w #31,ccr
    jsr (a0)
    move.w ccr,g_clockProbeCCR
    move.l d1,g_clockProbeD1
    lea 8(sp),sp
    rts

    .globl aitdProbeClockDriverResource
aitdProbeClockDriverResource:
    subq.l #4,sp
    move.l #0x4a6e7468,-(sp)
    move.w #11,-(sp)
    .word 0xa9a0
    move.l (sp)+,d0
    rts
