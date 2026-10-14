| Native saved-image ABI, as for RGBQuick. No game register is changed
| until all guards pass. C fallback retains unknown shapes and due services.
	.section .text.aitdLineQuick,"ax"
	.even
	.globl aitdLineQuick
	.type aitdLineQuick,@function
aitdLineQuick:
	.globl aitdTrapGuardLine
aitdTrapGuardLine:
	.include "../src/platform/amiga/QuickSceneGuard.inc"
	.globl aitdLineQuickBody
aitdLineQuickBody:
	move.l (a6),a0
	move.l (a0),a0
	cmpa.l #0,a0
	beq.w .drawMiss
	move.l (a0),a0
	move.l 4(a6),a6
	cmpa.l #0,a6
	beq.w .drawMiss
	tst.b 2202(a6)
	beq.w .drawMiss
	tst.b 2203(a6)
	beq.w .drawMiss
	cmpa.l 2070(a6),a0
	bne.w .drawMiss
	move.l usp,a1
	move.l (a1),d0
	cmpi.w #0xa892,d7
	beq.s 1f
	| Pascal stack and pnLoc both store v then h.
	cmp.l 48(a0),d0
	bne.w .drawMiss
	bra.s 2f
1:	tst.l d0
	bne.w .drawMiss
2:	cmpi.w #8,56(a0)
	bne.w .drawMiss
	tst.w 66(a0)
	bne.w .drawMiss
	move.l 80(a0),d6
	cmpi.l #255,d6
	bhi.w .drawMiss
	move.l 2114(a6),a1
	move.l (a1),a1
	tst.w (a1)
	bne.w .drawMiss
	move.l 2142(a6),a1
	move.l (a1),a1
	cmpi.l #-1,(a1)
	bne.w .drawMiss
	cmpi.l #-1,4(a1)
	bne.w .drawMiss
	move.l 2074(a6),a2
	cmpi.w #8,32(a2)
	bne.w .drawMiss
	move.l 2082(a6),a3
	cmpa.l #0,a3
	beq.w .drawMiss
	move.w 4(a2),d4
	andi.l #0x3fff,d4
	move.w 10(a2),d0
	sub.w 6(a2),d0
	ble.w .drawMiss
	move.w 12(a2),d1
	sub.w 8(a2),d1
	ble.w .drawMiss
	cmp.w d4,d1
	bhi.w .drawMiss
	mulu.w d4,d0
	cmp.l 2206(a6),d0
	bhi.w .drawMiss
.ifdef AITD_RGB_SCENE_VERIFY
	movem.l d0-d6/a0-a6,-(sp)
	move.l usp,a1
	move.l a1,-(sp)
	pea 120(sp)
	pea 64(sp)
	jsr aitdRGBSceneGuard
	lea 12(sp),sp
	movem.l (sp)+,d0-d6/a0-a6
.endif
	.globl aitdLineQuickPoint
aitdLineQuickPoint:
	move.w 48(a0),d0
	move.w 50(a0),d1
	move.w 52(a0),d2
	bmi.w .drawMiss
	move.w 54(a0),d3
	bmi.w .drawMiss
	add.w d0,d2
	bvs.w .drawMiss
	add.w d1,d3
	bvs.w .drawMiss
	| d0/d1/d2/d3 = top/left/bottom/right. Clip signed coordinates.
	lea 6(a2),a1
	bsr.w .clip
	lea 16(a0),a1
	bsr.w .clip
	move.l 2098(a6),a1
	move.l (a1),a1
	cmpi.w #10,(a1)+
	bne.w .drawMiss
	bsr.w .clip
	move.l 2102(a6),a1
	move.l (a1),a1
	cmpi.w #10,(a1)+
	bne.w .drawMiss
	bsr.w .clip
	cmp.w d2,d0
	bge.s .done
	cmp.w d3,d1
	bge.s .done
	sub.w d0,d2
	sub.w d1,d3
	sub.w 6(a2),d0
	sub.w 8(a2),d1
	mulu.w d4,d0
	andi.l #65535,d1
	add.l d1,d0
	adda.l d0,a3
	subq.w #1,d2
	subq.w #1,d3
.row:	move.l a3,a1
	move.w d3,d5
.pixel:	move.b d6,(a1)+
	dbra d5,.pixel
	adda.l d4,a3
	dbra d2,.row
.done:	move.l sp,a0
	clr.l (a0)
	moveq #5,d0
	jmp aitdQuickNativeDone
.clip:	cmp.w (a1),d0
	bge.s 3f
	move.w (a1),d0
3:	cmp.w 2(a1),d1
	bge.s 4f
	move.w 2(a1),d1
4:	cmp.w 4(a1),d2
	ble.s 5f
	move.w 4(a1),d2
5:	cmp.w 6(a1),d3
	ble.s 6f
	move.w 6(a1),d3
6:	rts
.drawMiss:
	.globl aitdLineQuickFallback
aitdLineQuickFallback:
	lea aitdStateQuickDraw,a4
	jmp aitdQuickCBridge
.miss:
	lea aitdLineQuickMiss,a4
	jmp aitdQuickCBridge
	.size aitdLineQuick,.-aitdLineQuick
