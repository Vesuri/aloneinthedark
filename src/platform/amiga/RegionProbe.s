| CPU-executed paired EmptyRgn fixtures. No debugger target writes.
    .section .text.aitdRegionProbe,"ax"
    .even
    .globl aitdRegionProbe
aitdRegionProbe:
    movem.l d2-d7/a2-a6,-(sp)
    moveq #64,d0
    .word 0xa122
    move.l a0,a2
    lea regionShapes(pc),a3
    moveq #1,d2
1:  move.l (a2),a0
    moveq #15,d0
2:  move.l #0xa5a5a5a5,(a0)+
    dbra d0,2b
    move.l (a2),a0
    moveq #0,d0
    move.w (a3),d0
    subq.w #1,d0
3:  move.b (a3)+,(a0)+
    dbra d0,3b
    move.w #0xa57e,-(sp)
    move.l a2,-(sp)
    move.l #0x13579bdf,d0
    move.l #0x89abcdef,d1
    .globl aitdRegionEmptyEnter
aitdRegionEmptyEnter:
    .word 0xa8e2
    .globl aitdRegionEmptyReturn
aitdRegionEmptyReturn:
    nop
    addq.l #2,sp
    addq.w #1,d2
    cmp.w #7,d2
    bne 1b
    move.l a2,a0
    .word 0xa023
    .globl aitdRegionProbeComplete
aitdRegionProbeComplete:
    nop
    movem.l (sp)+,d2-d7/a2-a6
    rts
regionShapes:
    .word 10,0,0,0,0
    .word 10,-3,-2,4,7
    .word 10,4,-2,4,7
    .word 10,5,-2,4,7
    .word 10,-3,8,4,7
    .word 36,1,2,4,8,1,2,4,6,8,0x7fff,4,2,4,6,8,0x7fff,0x7fff
