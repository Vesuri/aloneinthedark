| Native saved-image ABI: full image at SP, exception frame at SP+60.
	.section .text.aitdStateQuick,"ax"
	.even
	.globl aitdStateQuick
	.type aitdStateQuick,@function
aitdStateQuick:
	.include "../src/platform/amiga/QuickSceneGuard.inc"
	cmpi.w #0xab1d,d7
	beq.w .body
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
	.globl aitdStateQuickPen
aitdStateQuickPen:
	move.l (a6),a0
	move.l (a0),a0
	cmpa.l #0,a0
	beq.w .body
	move.l (a0),a0
	move.l usp,a1
	cmpi.w #0xa89b,d7
	beq.s .size
	cmpi.w #0xa89c,d7
	beq.s .mode
	cmpi.w #0xa893,d7
	bne.w .body
	cmpa.l #0,a0
	beq.s 1f
	move.w (a1),48(a0)
	move.w 2(a1),50(a0)
	move.w 6(a0),d0
	andi.w #0xc000,d0
	beq.s 1f
	move.w #0x8000,14(a0)
1:	cmpi.w #97,g_stageCDepth
	bcc.s .four
	move.w #97,g_stageCDepth
	bra.s .four
.size:
	cmpa.l #0,a0
	beq.s 2f
	move.w (a1),52(a0)
	move.w 2(a1),54(a0)
2:	cmpi.w #58,g_stageCDepth
	bcc.s .four
	move.w #58,g_stageCDepth
.four:
	moveq #5,d0
	jmp aitdQuickNativeDone
.mode:
	cmpa.l #0,a0
	beq.s 3f
	move.w (a1),56(a0)
3:	cmpi.w #59,g_stageCDepth
	bcc.s 4f
	move.w #59,g_stageCDepth
4:	moveq #3,d0
	jmp aitdQuickNativeDone
.body:
	.globl aitdStateQuickFallback
aitdStateQuickFallback:
	lea aitdStateQuickDraw,a4
	jmp aitdQuickCBridge
.miss:
	lea aitdStateQuickMiss,a4
	jmp aitdQuickCBridge
	.size aitdStateQuick,.-aitdStateQuick
