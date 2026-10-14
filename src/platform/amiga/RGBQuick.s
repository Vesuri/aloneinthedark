| RGB cache hit within an unfinished scene, with no due services.
| Called ONLY by MacEntry.s after saving the full game register/CCR image.
| Unlike C entries this may clobber native D2-D6/A2-A6; D7 retains the trap.
| SP holds the full saved image; SP+60 holds the exception frame.
| The C bridge handles misses; successful Pascal returns use the common epilogue.
| Native layout offsets are asserted in MacLoader.cpp. No game code is patched.
	.section .text.aitdRGBQuick,"ax"
	.even
	.globl aitdRGBQuick
	.type aitdRGBQuick,@function
aitdRGBQuick:
	.globl aitdTrapGuardRGB
aitdTrapGuardRGB:
	.include "../src/platform/amiga/QuickSceneGuard.inc"
	| The measured early foreground caller requires the general handler.
	cmpi.w #0xaa14,d7
	bne.s 3f
	move.l 24(a6),a0
	move.l (a0),d0
	beq.s 3f
	addi.l #0xb46,d0
	lea 60(sp),a0
	cmp.l 2(a0),d0
	beq.w .miss
3:
	.globl aitdRGBQuickBody
aitdRGBQuickBody:
	move.l (a6),a0
	move.l (a0),a0
	cmpa.l #0,a0
	beq.w .miss
	move.l (a0),a0
	move.l 4(a6),a6
	cmpa.l #0,a6
	beq.w .miss
	tst.b 2202(a6)
	beq.w .miss
	cmpa.l 2070(a6),a0
	bne.w .miss
	move.l 2086(a6),a1
	move.l (a1),a1
	cmpi.w #8,32(a1)
	bne.w .miss
	moveq #36,d6
	move.l 2114(a6),a1
	cmpi.w #0xaa14,d7
	beq.s 4f
	moveq #42,d6
	move.l 2110(a6),a1
4:	move.l (a1),a1
	tst.w (a1)
	bne.w .miss
	move.l usp,a2
	move.l (a2),a2
	cmpa.l #0,a2
	beq.w .miss
	| Partial overlap keeps the original ordered byte-copy fallback.
	lea (a0,d6.l),a1
	cmpa.l a1,a2
	beq.s 5f
	lea 6(a1),a3
	cmpa.l a3,a2
	bcc.s 5f
	lea 6(a2),a3
	cmpa.l a1,a3
	bhi.w .miss
5:	move.l 2094(a6),a1
	move.l (a1),a1
	cmpa.l (a6),a1
	bne.w .miss
	move.l 2190(a6),a3
	move.l (a3),a3
	cmpa.l 4(a6),a3
	bne.w .miss
	move.l (a1),d0
	cmp.l 8(a6),d0
	bne.w .miss
	move.l (a3),d0
	cmp.l 12(a6),d0
	bne.w .miss
	move.l 4(a1),d0
	cmp.l 16(a6),d0
	bne.w .miss
	move.w 4(a3),d2
	cmp.w 20(a6),d2
	bne.w .miss
	move.l (a2),d3
	move.w 4(a2),d4
	move.l d3,d0
	moveq #24,d1
	lsr.l d1,d0
	move.l d3,d1
	lsr.l #8,d1
	lsr.l #4,d1
	eor.l d1,d0
	move.w d4,d1
	lsr.w #8,d1
	eor.w d1,d0
	andi.l #255,d0
	lea 22(a6,d0.l*8),a4
	moveq #0,d5
	move.w 6(a4),d5
	beq.s .miss
	cmp.l (a4),d3
	bne.s .miss
	cmp.w 4(a4),d4
	bne.s .miss
	subq.w #1,d5
	move.l sp,a5
.ifdef AITD_RGB_CACHE_VERIFY
.ifdef AITD_RGB_CACHE_SABOTAGE
	eori.l #1,d5
.endif
	move.l a0,-(sp)
	move.l a2,-(sp)
	move.l a3,-(sp)
	move.l a1,-(sp)
	move.l d5,-(sp)
	jsr aitdVerifyRGBHit
	lea 16(sp),sp
	move.l (sp)+,a0
.endif
.ifdef AITD_RGB_SCENE_VERIFY
	move.l a0,-(sp)
	move.l usp,a1
	move.l a1,-(sp)
	pea 60(a5)
	move.l a5,-(sp)
	jsr aitdRGBSceneGuard
	lea 12(sp),sp
	move.l (sp)+,a0
.endif
	move.l d3,(a0,d6.l)
	move.w d4,4(a0,d6.l)
	lea 80(a0),a1
	cmpi.w #0xaa14,d7
	beq.s 6f
	addq.l #4,a1
6:	move.l d5,(a1)
	move.l d5,(a5)
	move.l d5,4(a5)
	move.l a1,32(a5)
	moveq #12,d0
	cmpi.w #4,d2
	beq.s 7f
	moveq #15,d0
7:	moveq #1,d1
	lsl.l d0,d1
	lea 6(a3,d1.l),a1
	move.l a1,36(a5)
	moveq #5,d0
	jmp aitdQuickNativeDone
.miss:
	.globl aitdRGBQuickFallback
aitdRGBQuickFallback:
	lea aitdRGBQuickMiss,a4
	jmp aitdQuickCBridge
	.size aitdRGBQuick,.-aitdRGBQuick
