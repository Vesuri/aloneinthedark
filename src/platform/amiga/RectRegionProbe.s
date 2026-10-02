| Paired RectRgn fixtures: native allocation/state/resize/ownership traps.
    .section .text.aitdRectRegionProbe,"ax"
    .even
    .globl aitdRectRegionProbe
aitdRectRegionProbe:
    movem.l d2-d7/a2-a6,-(sp)
    lea -16(sp),sp
    move.l sp,a4
    lea rectCases(pc),a3
    moveq #1,d2
1:  moveq #0,d0
    move.w (a3),d0
    move.l d0,d3
    .word 0xa122
    move.l a0,a2
    move.l (a2),a0
    move.l d3,d0
    subq.w #1,d0
2:  move.b #0xa5,(a0)+
    dbra d0,2b
    move.l (a2),a0
    cmp.w #10,d3
    bne 3f
    move.w #10,(a0)
    clr.l 2(a0)
    clr.l 6(a0)
    bra 5f
3:  lea complexRegion(pc),a1
    moveq #35,d0
4:  move.b (a1)+,(a0)+
    dbra d0,4b
5:  move.l #0xa5a5a5a5,(a4)
    move.l 4(a3),4(a4)
    move.l 8(a3),8(a4)
    move.l #0xa5a5a5a5,12(a4)
    move.l a2,a0
    moveq #0,d0
    move.w 2(a3),d0
    .word 0xa06a
    move.l a2,-(sp)
    pea 4(a4)
    move.l #0x13579bdf,d0
    move.l #0x89abcdef,d1
    .globl aitdRectRegionEnter
aitdRectRegionEnter:
    .word 0xa8df
    .globl aitdRectRegionReturn
aitdRectRegionReturn:
    nop
    move.l a2,a0
    .word 0xa025
    .globl aitdRectRegionSize
aitdRectRegionSize:
    nop
    move.l a2,a0
    .word 0xa069
    .globl aitdRectRegionFlags
aitdRectRegionFlags:
    nop
    move.l a2,a0
    .word 0xa126
    .globl aitdRectRegionOwner
aitdRectRegionOwner:
    nop
    move.l a2,a0
    .word 0xa023
    add.l #12,a3
    addq.w #1,d2
    cmp.w #8,d2
    bne 1b
    .globl aitdRectRegionComplete
aitdRectRegionComplete:
    nop
    lea 16(sp),sp
    movem.l (sp)+,d2-d7/a2-a6
    rts
rectCases:
    .word 10,0,-3,-2,4,7
    .word 64,0,-3,-2,4,7
    .word 64,0,4,-2,4,7
    .word 64,0,5,-2,4,7
    .word 64,0,-3,8,4,7
    .word 64,0x80,-3,-2,4,7
    .word 64,0x40,-3,-2,4,7
complexRegion:
    .word 36,1,2,4,8,1,2,4,6,8,0x7fff,4,2,4,6,8,0x7fff,0x7fff
