| CPU-executed ownership fixture; debugger observations never write target state.
    .section .text.aitdCTableProbe,"ax"
    .even
    .globl aitdCTableProbe
aitdCTableProbe:
    movem.l d2-d7/a2-a6,-(sp)
    lea -512(sp),sp
    move.l sp,a4
    clr.l 256(a4)
    clr.l 260(a4)
    clr.l 264(a4)
    clr.l 268(a4)
    clr.l -(sp)
    move.w #128,-(sp)
    .globl aitdCTableInitial
aitdCTableInitial:
    .word 0xaa18
    .globl aitdCTableInitialReturned
aitdCTableInitialReturned:
    move.l (sp)+,256(a4)
    move.l 256(a4),a0
    move.l (a0),a0
    clr.w 4(a0)
    moveq #0,d0
1:  move.w d0,8(a0,d0.w*8)
    addq.w #1,d0
    cmp.w #256,d0
    blt 1b
    .globl aitdCTableMutated
aitdCTableMutated:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdCTableCase1
aitdCTableCase1:
    .word 0xa025
    .globl aitdCTableCase1Returned
aitdCTableCase1Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdCTableCase2
aitdCTableCase2:
    .word 0xa069
    .globl aitdCTableCase2Returned
aitdCTableCase2Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.w #0xcccc,-(sp)
    move.l 256(a4),-(sp)
    .globl aitdCTableCase3
aitdCTableCase3:
    .word 0xa9a6
    .globl aitdCTableCase3Returned
aitdCTableCase3Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    move.l #0x636c7574,-(sp)
    move.w #128,-(sp)
    .globl aitdCTableCase4
aitdCTableCase4:
    .word 0xa9a0
    .globl aitdCTableCase4Returned
aitdCTableCase4Returned:
    nop
    move.l (sp),260(a4)
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdCTableCase5
aitdCTableCase5:
    .word 0xa025
    .globl aitdCTableCase5Returned
aitdCTableCase5Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdCTableCase6
aitdCTableCase6:
    .word 0xa069
    .globl aitdCTableCase6Returned
aitdCTableCase6Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    .globl aitdCTableCase7
aitdCTableCase7:
    .word 0xaa28
    .globl aitdCTableCase7Returned
aitdCTableCase7Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    move.w #128,-(sp)
    .globl aitdCTableCase8
aitdCTableCase8:
    .word 0xaa18
    .globl aitdCTableCase8Returned
aitdCTableCase8Returned:
    nop
    move.l (sp),264(a4)
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    .globl aitdCTableCase9
aitdCTableCase9:
    .word 0xaa28
    .globl aitdCTableCase9Returned
aitdCTableCase9Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 264(a4),a0
    .globl aitdCTableCase10
aitdCTableCase10:
    .word 0xa069
    .globl aitdCTableCase10Returned
aitdCTableCase10Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.w #0xcccc,-(sp)
    move.l 264(a4),-(sp)
    .globl aitdCTableCase11
aitdCTableCase11:
    .word 0xa9a6
    .globl aitdCTableCase11Returned
aitdCTableCase11Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 264(a4),a0
    move.l (a0),a1
    move.w #0x1234,10(a1)
    .globl aitdCTableCase12
aitdCTableCase12:
    .word 0xa069
    .globl aitdCTableCase12Returned
aitdCTableCase12Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    move.w #128,-(sp)
    .globl aitdCTableCase13
aitdCTableCase13:
    .word 0xaa18
    .globl aitdCTableCase13Returned
aitdCTableCase13Returned:
    nop
    move.l (sp),268(a4)
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    move.l #0x636c7574,-(sp)
    move.w #128,-(sp)
    .globl aitdCTableCase14
aitdCTableCase14:
    .word 0xa9a0
    .globl aitdCTableCase14Returned
aitdCTableCase14Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdCTableCase15
aitdCTableCase15:
    .word 0xa069
    .globl aitdCTableCase15Returned
aitdCTableCase15Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 264(a4),a0
    .globl aitdCTableCase16
aitdCTableCase16:
    .word 0xa023
    .globl aitdCTableCase16Returned
aitdCTableCase16Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdCTableCase17
aitdCTableCase17:
    .word 0xa025
    .globl aitdCTableCase17Returned
aitdCTableCase17Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdCTableCase18
aitdCTableCase18:
    .word 0xa025
    .globl aitdCTableCase18Returned
aitdCTableCase18Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 268(a4),a0
    .globl aitdCTableCase19
aitdCTableCase19:
    .word 0xa025
    .globl aitdCTableCase19Returned
aitdCTableCase19Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    move.w #32766,-(sp)
    .globl aitdCTableCase20
aitdCTableCase20:
    .word 0xaa18
    .globl aitdCTableCase20Returned
aitdCTableCase20Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l #0xcccccccc,-(sp)
    .globl aitdCTableCase21
aitdCTableCase21:
    .word 0xaa28
    .globl aitdCTableCase21Returned
aitdCTableCase21Returned:
    nop
    move.l a4,sp
    lea 512(sp),sp
    movem.l (sp)+,d2-d7/a2-a6
    .globl aitdCTableProbeDone
aitdCTableProbeDone:
    rts
