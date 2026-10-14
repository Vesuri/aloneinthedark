| Native saved-image ABI, as for RGBQuick. No game register is changed
| until all guards pass. Ordinary dispatch retains due services; both entries
| share the validated raster. C fallback retains partially clipped strokes.
	.section .text.aitdLineQuick,"ax"
	.even
	.globl aitdLineQuick
	.type aitdLineQuick,@function
aitdLineQuick:
	.globl aitdTrapGuardLine
aitdTrapGuardLine:
	.include "../src/platform/amiga/QuickSceneGuard.inc"
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
	.globl aitdLineQuickBody
aitdLineQuickBody:
	move.l usp,a4
	lea .nativeReturn,a5
	move.l (a6),a0
	move.l (a0),a0
	cmpa.l #0,a0
	beq.w .drawMiss
	move.l (a0),a0
	move.l 4(a6),a6
	cmpa.l #0,a6
	beq.w .drawMiss
.validate:
	.globl aitdLineValidation
aitdLineValidation:
	tst.b 2202(a6)
	beq.w .drawMiss
	tst.b 2203(a6)
	beq.w .drawMiss
	cmpa.l 2070(a6),a0
	bne.w .drawMiss
	cmpi.w #8,56(a0)
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

	cmpi.l #0x00010001,52(a0)
	beq.w .thin
	move.l (a4),d0
	cmpi.w #0xa892,d7
	beq.s 1f
	cmp.l 48(a0),d0
	bne.w .drawMiss
	bra.s 2f
1:	tst.l d0
	bne.w .drawMiss
2:
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
.done:	moveq #1,d0
	jmp (a5)
| Fully contained 1x1 strokes. All validation precedes port/pixel writes.
| Rejected/clipped strokes retain Line8::solid, including its exact dirty bounds.
.thin:
	.globl aitdLineClipThin
aitdLineClipThin:
	move.w (a4),d2
	move.w 2(a4),d3
	move.w 48(a0),d0
	move.w 50(a0),d1
	cmpi.w #0xa892,d7
	bne.s 1f
	add.w d0,d2
	add.w d1,d3
1:	movem.w d0-d3,-(sp)
	cmp.w d0,d2
	bge.s 2f
	exg d0,d2
2:	cmp.w d1,d3
	bge.s 3f
	exg d1,d3
3:	moveq #0,d5
	lea 6(a2),a1
	bsr.w .inside
	lea 16(a0),a1
	bsr.w .inside
	move.l 2098(a6),a1
	move.l (a1),a1
	cmpi.w #10,(a1)+
	bne.w .thinMiss
	bsr.w .inside
	move.l 2102(a6),a1
	move.l (a1),a1
	cmpi.w #10,(a1)+
	bne.w .thinMiss
	bsr.w .inside
	btst #1,d5
	bne.w .thinEmpty
	tst.w d5
	bne.w .thinMiss
	| Limit distances so the 16.16 shallow accumulator cannot wrap.
	move.w d3,d5
	sub.w d1,d5
	bmi.w .thinMiss
	move.w d2,d5
	sub.w d0,d5
	bmi.w .thinMiss
	movem.w (sp)+,d0-d3
	.globl aitdLineQuickThin
aitdLineQuickThin:
	move.w d2,48(a0)
	move.w d3,50(a0)
	cmp.w d0,d2
	bge.s 4f
	exg d0,d2
	exg d1,d3
4:	sub.w d0,d2
	sub.w d1,d3
	sub.w 6(a2),d0
	sub.w 8(a2),d1
	mulu.w d4,d0
	andi.l #65535,d1
	add.l d1,d0
	adda.l d0,a3
	moveq #1,d7
	tst.w d3
	bpl.s 5f
	neg.w d3
	moveq #-1,d7
5:	andi.l #65535,d3
	andi.l #65535,d2
	tst.w d2
	beq.w .horizontal
	cmp.w d2,d3
	beq.w .diagonal
	move.l d3,d1
	swap d1
	divu.l d2,d1
	move.l d1,d0
	lsr.l #1,d0
	addi.l #32768,d0
	cmp.w d2,d3
	bhi.s .shallow
	| Steep lines: the fractional carry advances one column.
.steep:
	move.b d6,(a3)
	adda.l d4,a3
	add.w d1,d0
	bcc.s 6f
	adda.l d7,a3
6:	dbra d2,.steep
	bra.w .done
.diagonal:
	add.l d7,d4
7:	move.b d6,(a3)
	adda.l d4,a3
	dbra d2,7b
	bra.w .done
.horizontal:
	move.b d6,(a3)
	adda.l d7,a3
	dbra d3,.horizontal
	bra.w .done
.shallow:
	| A descending exact half-open boundary belongs to the next row.
	tst.l d7
	bpl.s 8f
	subq.l #1,d0
8:	addq.l #1,d3
.shallowRow:
	move.l d0,d5
	swap d5
	andi.l #65535,d5
	cmp.l d3,d5
	bls.s 9f
	move.l d3,d5
9:	sub.l d5,d3
	move.l a3,a1
	subq.w #1,d5
	bmi.s 11f
10:	move.b d6,(a1)
	adda.l d7,a1
	dbra d5,10b
11:	move.l a1,a3
	adda.l d4,a3
	andi.l #65535,d0
	add.l d1,d0
	dbra d2,.shallowRow
	bra.w .done
.thinEmpty:
	movem.w (sp)+,d0-d3
	.globl aitdLineQuickEmpty
aitdLineQuickEmpty:
	move.w d2,48(a0)
	move.w d3,50(a0)
	bra.w .done
.inside:
	.globl aitdLineClipTest
aitdLineClipTest:
	cmp.w (a1),d0
	blt.s .outside
	cmp.w 2(a1),d1
	blt.s .outside
	cmp.w 4(a1),d2
	bge.s .outside
	cmp.w 6(a1),d3
	bge.s .outside
	rts
.outside:
	or.w #1,d5
	cmp.w (a1),d2
	blt.s 12f
	cmp.w 2(a1),d3
	blt.s 12f
	cmp.w 4(a1),d0
	bge.s 12f
	cmp.w 6(a1),d1
	blt.s 13f
12:	or.w #2,d5
13:	rts
.thinMiss:
	addq.l #8,sp
	bra.w .drawMiss
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
	.globl aitdLineDrawReturn
aitdLineDrawReturn:
	moveq #0,d0
	jmp (a5)
.nativeReturn:
	.globl aitdLineNativeReturn
aitdLineNativeReturn:
	tst.l d0
	beq.s .fallback
	clr.l (sp)
	moveq #5,d0
	jmp aitdQuickNativeDone
.fallback:
	.globl aitdLineQuickFallback
aitdLineQuickFallback:
	lea aitdStateQuickDraw,a4
	jmp aitdQuickCBridge
.miss:
	lea aitdLineQuickMiss,a4
	jmp aitdQuickCBridge
	.size aitdLineQuick,.-aitdLineQuick

| bool aitdSolidLine(GWorldSlot*, uint32_t packedEndpoint). Ordinary C ABI.
| Shares drawing only; the caller retains all service/frame boundary checks.
	.even
	.globl aitdSolidLine
	.type aitdSolidLine,@function
aitdSolidLine:
	movem.l d2-d7/a2-a6,-(sp)
	move.l 48(sp),a6
	move.l 2070(a6),a0
	lea 52(sp),a4
	lea .cReturn,a5
	move.w #0xa891,d7
	bra.w .validate
.cReturn:
	movem.l (sp)+,d2-d7/a2-a6
	rts
	.size aitdSolidLine,.-aitdSolidLine
