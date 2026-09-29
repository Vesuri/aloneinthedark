| CPU-executed NewPalette/DisposePalette ownership fixture; GDB only observes.
    .section .text.aitdPaletteProbe,"ax"
    .even
    .globl aitdPaletteProbe
aitdPaletteProbe:
    movem.l d2-d7/a2-a6,-(sp)
    lea -512(sp),sp
    move.l sp,a4
    clr.l -(sp)
    move.w #128,-(sp)
    .word 0xaa18
    move.l (sp)+,256(a4)
    move.l 256(a4),a0
    move.l (a0),a0
    clr.w 4(a0)
    moveq #0,d0
1:  move.w d0,8(a0,d0.w*8)
    addq.w #1,d0
    cmp.w #256,d0
    blt 1b
    clr.l -(sp)
    move.w #256,-(sp)
    move.l 256(a4),-(sp)
    pea 10.w
    .globl aitdPaletteInitial
aitdPaletteInitial:
    .word 0xaa91
    .globl aitdPaletteInitialReturned
aitdPaletteInitialReturned:
    move.l (sp)+,260(a4)
    move.l 260(a4),a0
    move.l (a0),a0
    move.l 12(a0),264(a4)
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdPaletteCase1
aitdPaletteCase1:
    .word 0xa025
    .globl aitdPaletteCase1Returned
aitdPaletteCase1Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdPaletteCase2
aitdPaletteCase2:
    .word 0xa069
    .globl aitdPaletteCase2Returned
aitdPaletteCase2Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdPaletteCase3
aitdPaletteCase3:
    .word 0xa025
    .globl aitdPaletteCase3Returned
aitdPaletteCase3Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdPaletteCase4
aitdPaletteCase4:
    .word 0xa069
    .globl aitdPaletteCase4Returned
aitdPaletteCase4Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 264(a4),a0
    .globl aitdPaletteCase5
aitdPaletteCase5:
    .word 0xa025
    .globl aitdPaletteCase5Returned
aitdPaletteCase5Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.w #0xcccc,-(sp)
    move.l 260(a4),-(sp)
    .globl aitdPaletteCase6
aitdPaletteCase6:
    .word 0xa9a6
    .globl aitdPaletteCase6Returned
aitdPaletteCase6Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    move.l 256(a4),a1
    move.l (a1),a1
    move.w #0x1234,10(a1)
    .globl aitdPaletteCase7
aitdPaletteCase7:
    .word 0xa069
    .globl aitdPaletteCase7Returned
aitdPaletteCase7Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    move.l 260(a4),a1
    move.l (a1),a1
    move.w #0x5678,16(a1)
    .globl aitdPaletteCase8
aitdPaletteCase8:
    .word 0xa069
    .globl aitdPaletteCase8Returned
aitdPaletteCase8Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),-(sp)
    .globl aitdPaletteCase9
aitdPaletteCase9:
    .word 0xaa93
    .globl aitdPaletteCase9Returned
aitdPaletteCase9Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 256(a4),a0
    .globl aitdPaletteCase10
aitdPaletteCase10:
    .word 0xa025
    .globl aitdPaletteCase10Returned
aitdPaletteCase10Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 260(a4),a0
    .globl aitdPaletteCase11
aitdPaletteCase11:
    .word 0xa025
    .globl aitdPaletteCase11Returned
aitdPaletteCase11Returned:
    nop
    move.l a4,sp
    move.l g_macLowMemory,a1
    move.w #0x8888,140(a1)
    move.w #0x7777,100(a1)
    move.l #0x12345678,d0
    move.l 264(a4),a0
    .globl aitdPaletteCase12
aitdPaletteCase12:
    .word 0xa025
    .globl aitdPaletteCase12Returned
aitdPaletteCase12Returned:
    nop
    move.l a4,sp
    | Initialize the same eight-bit manager state as original startup.
    | QDGlobals uses bytes 38..243; ownership slots begin at 256.
    pea 240(a4)
    .word 0xa86e
    .word 0xa8fe
    .word 0xa912
    | Leave a newly constructed default palette alive for actual shutdown.
    clr.l -(sp)
    move.w #256,-(sp)
    move.l 256(a4),-(sp)
    pea 10.w
    .word 0xaa91
    move.l (sp)+,260(a4)
    pea -1.w
    move.l 260(a4),-(sp)
    move.w #0x0100,-(sp)
    .globl aitdPaletteBinding
aitdPaletteBinding:
    .word 0xaa95
    .globl aitdPaletteBindingReturned
aitdPaletteBindingReturned:
    nop
    lea 512(sp),sp
    movem.l (sp)+,d2-d7/a2-a6
    .globl aitdPaletteProbeDone
aitdPaletteProbeDone:
    rts
