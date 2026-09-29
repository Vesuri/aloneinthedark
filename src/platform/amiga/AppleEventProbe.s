    .section .text.aitdAppleEventProbe,"ax"
    .even
    .globl aitdAppleEventProbe
aitdAppleEventProbe:
    movem.l d2-d7/a2-a6,-(sp)
    lea -512(sp),sp
    move.l sp,a4
    tst.l g_aeProbeForm
    bne aitdAEUnsupportedSetup
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x6f617070,-(sp)
    pea 0xac2(a5)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAESeed0
aitdAESeed0:
    .word 0xa816
    .globl aitdAESeed0Returned
aitdAESeed0Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x70646f63,-(sp)
    pea 0xac2(a5)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAESeed1
aitdAESeed1:
    .word 0xa816
    .globl aitdAESeed1Returned
aitdAESeed1Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x6f646f63,-(sp)
    pea 0xad2(a5)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAESeed2
aitdAESeed2:
    .word 0xa816
    .globl aitdAESeed2Returned
aitdAESeed2Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x71756974,-(sp)
    pea 0xaca(a5)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAESeed3
aitdAESeed3:
    .word 0xa816
    .globl aitdAESeed3Returned
aitdAESeed3Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x6f617070,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase1
aitdAECase1:
    .word 0xa816
    .globl aitdAECase1Returned
aitdAECase1Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x70646f63,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase2
aitdAECase2:
    .word 0xa816
    .globl aitdAECase2Returned
aitdAECase2Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x6f646f63,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase3
aitdAECase3:
    .word 0xa816
    .globl aitdAECase3Returned
aitdAECase3Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x71756974,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase4
aitdAECase4:
    .word 0xa816
    .globl aitdAECase4Returned
aitdAECase4Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase5
aitdAECase5:
    .word 0xa816
    .globl aitdAECase5Returned
aitdAECase5Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0xac2(a5)
    move.l #0x12345678,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAECase6
aitdAECase6:
    .word 0xa816
    .globl aitdAECase6Returned
aitdAECase6Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase7
aitdAECase7:
    .word 0xa816
    .globl aitdAECase7Returned
aitdAECase7Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0xac2(a5)
    move.l #0xcafebabe,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAECase8
aitdAECase8:
    .word 0xa816
    .globl aitdAECase8Returned
aitdAECase8Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase9
aitdAECase9:
    .word 0xa816
    .globl aitdAECase9Returned
aitdAECase9Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0xaca(a5)
    move.l #0xaabbccdd,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAECase10
aitdAECase10:
    .word 0xa816
    .globl aitdAECase10Returned
aitdAECase10Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase11
aitdAECase11:
    .word 0xa816
    .globl aitdAECase11Returned
aitdAECase11Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697465,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase12
aitdAECase12:
    .word 0xa816
    .globl aitdAECase12Returned
aitdAECase12Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x100,-(sp)
    move.l #0x921,d0
    .globl aitdAECase13
aitdAECase13:
    .word 0xa816
    .globl aitdAECase13Returned
aitdAECase13Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    clr.l -(sp)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAECase14
aitdAECase14:
    .word 0xa816
    .globl aitdAECase14Returned
aitdAECase14Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase15
aitdAECase15:
    .word 0xa816
    .globl aitdAECase15Returned
aitdAECase15Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0xac3(a5)
    move.l #0x0,-(sp)
    move.w #0x0,-(sp)
    move.l #0x91f,d0
    .globl aitdAECase16
aitdAECase16:
    .word 0xa816
    .globl aitdAECase16Returned
aitdAECase16Returned:
    nop
    move.l a4,sp
    move.l #0xdeadbeef,256(a4)
    move.l #0xcccccccc,260(a4)
    move.l #0xdddddddd,264(a4)
    move.l #0xfacefeed,268(a4)
    move.w #0xeeee,-(sp)
    move.l #0x61697464,-(sp)
    move.l #0x70726231,-(sp)
    pea 0x104(a4)
    pea 0x108(a4)
    move.w #0x0,-(sp)
    move.l #0x921,d0
    .globl aitdAECase17
aitdAECase17:
    .word 0xa816
    .globl aitdAECase17Returned
aitdAECase17Returned:
    nop
    move.l a4,sp
    lea 512(sp),sp
    movem.l (sp)+,d2-d7/a2-a6
    .globl aitdAEProbeDone
aitdAEProbeDone:
    rts

| Unsupported inputs are constructed by the CPU; GDB only observes them.
aitdAEUnsupportedSetup:
    move.w #0xeeee,-(sp)
    move.l #0x61657674,-(sp)
    move.l #0x6f617070,-(sp)
    pea 0xac2(a5)
    clr.l -(sp)
    clr.w -(sp)
    move.l #0x91f,d0
    move.l g_aeProbeForm,d1
    cmp.l #1,d1
    bne 1f
    move.b #1,(sp)
1:  cmp.l #2,d1
    bne 2f
    move.l #0x2a2a2a2a,14(sp)
2:  cmp.l #3,d1
    bne 3f
    move.l #0x2a2a2a2a,10(sp)
3:  cmp.l #4,d1
    bne 4f
    move.l #0x21b,d0
4:  cmp.l #5,d1
    bne 5f
    move.l #0x921,d0
    clr.l 6(sp)
5:  cmp.l #6,d1
    bne 6f
    move.l #0x921,d0
    move.l #1,6(sp)
6:
    .globl aitdAEUnsupportedCall
aitdAEUnsupportedCall:
    .word 0xa816
    .globl aitdAEUnsupportedReturned
aitdAEUnsupportedReturned:
    bra aitdAEUnsupportedReturned
