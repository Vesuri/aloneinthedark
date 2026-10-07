; C ABI adapter for Mikael Kalms' public-domain c2p1x1_8_c5_gen.
; void aitdKalmsC2PRect(const uint8_t *source, uint8_t *destination,
;                      uint32_t width, uint32_t rows);
; Source stride 640, output stride 320, planes separated by 40 bytes.
; Caller supplies a word-aligned destination, nonempty width divisible by 32
; (<=320) and rows <=200. Source may be unaligned on 68020+.
        section code,code
        xdef aitdKalmsC2PRect
aitdKalmsC2PRect:
        movem.l d2-d3/a2-a3,-(sp)
        move.l  20(sp),a2
        move.l  24(sp),a3
        move.l  28(sp),d0
        move.l  32(sp),d2
        moveq   #1,d1
        moveq   #0,d3
        bsr     c2p1x1_8_c5_gen_init
.row:
        move.l  a2,a0
        move.l  a3,a1
        bsr     c2p1x1_8_c5_gen
        adda.w  #640,a2
        adda.w  #320,a3
        subq.l  #1,d2
        bne.s   .row
        movem.l (sp)+,d2-d3/a2-a3
        rts
BPLX    equ 320
BPLY    equ 1
BPLSIZE equ 40
        include "../src/platform/amiga/kalms/c2p1x1_8_c5_gen.s"
