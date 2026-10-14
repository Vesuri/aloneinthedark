| Diagnostic-only real OS traps and callback, collected away in production.
    .section .text.aitd_vbl_probe,"ax"
    .even
    .globl aitd_vbl_probe_install
aitd_vbl_probe_install:
    move.l 4(sp),a0
    .word 0xa033
    rts
    .globl aitd_vbl_probe_remove
aitd_vbl_probe_remove:
    move.l 4(sp),a0
    .word 0xa034
    rts
    .globl aitd_vbl_probe_poll
aitd_vbl_probe_poll:
    .word 0xa11a
    rts
    .globl aitd_vbl_probe_callback
aitd_vbl_probe_callback:
    moveq #0,d0
    move.w 16(a0),d0
    addq.w #1,16(a0)
    cmp.w #3,d0
    bhs.s 2f
    move.l g_macTicksAddress,a1
    move.l (a1),24(a0,d0.w*4)
2:  cmp.w #3,16(a0)
    bhs.s 1f
    move.w #1,10(a0)
1:  moveq #-1,d0
    moveq #-1,d1
    move.l #0x12345678,a5
    move.w #0,ccr
    rts
