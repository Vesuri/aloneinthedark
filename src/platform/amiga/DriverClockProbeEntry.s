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

    .section .text.aitdProbeClockDriverResource,"ax"
    .even
    .globl aitdProbeClockDriverResource
aitdProbeClockDriverResource:
    subq.l #4,sp
    move.l #0x4a6e7468,-(sp)
    move.w #11,-(sp)
    .word 0xa9a0
    move.l (sp)+,d0
    rts

    .section .text.aitdProbeDriverGain,"ax"
    .even
    .globl aitdProbeDriverGain
aitdProbeDriverGain:
    move.l 4(sp),a0
    move.l 8(sp),-(sp)
    move.l #19,-(sp)
    move.w #31,ccr
    .globl aitdGainProbeCall
aitdGainProbeCall:
    jsr (a0)
    .globl aitdGainProbeReturn
aitdGainProbeReturn:
    move.w ccr,g_gainProbeCCR
    move.l d1,g_gainProbeD1
    lea 8(sp),sp
    rts

    .section .text.aitdProbeGainSong,"ax"
    .even
    .globl aitdProbeGainSong
aitdProbeGainSong:
    move.l 4(sp),a0
    move.l 12(sp),-(sp)
    move.l 12(sp),-(sp)
    jsr (a0)
    lea 8(sp),sp
    rts
