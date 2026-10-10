| LINEAPROBE-only Pascal ABI and patched quick-entry checks.
	.section .text.aitd_quick_trap_probe,"ax"
	.even
	.globl aitd_quick_trap_probe
aitd_quick_trap_probe:
	movem.l d2-d7/a2-a6,-(sp)
	pea g_quickTrapProbe+202
	.word 0xa86e
	move.l #g_quickTrapProbe+208,g_quickTrapProbe+202
	move.l sp,g_quickTrapProbe+320
	move.l #0x12345678,-(sp)
	movem.l seeds(pc),d0-d7/a0-a6
	move.w #31,ccr
	.word 0xa893
	move.w ccr,g_quickTrapProbe+388
	movem.l d0-d7/a0-a6,g_quickTrapProbe+328
	move.l sp,g_quickTrapProbe+324
	move.l #0x00030004,-(sp)
	movem.l seeds(pc),d0-d7/a0-a6
	move.w #31,ccr
	.word 0xa89b
	move.w ccr,g_quickTrapProbe+452
	movem.l d0-d7/a0-a6,g_quickTrapProbe+392
	move.w #7,-(sp)
	movem.l seeds(pc),d0-d7/a0-a6
	move.w #31,ccr
	.word 0xa89c
	move.w ccr,g_quickTrapProbe+516
	movem.l d0-d7/a0-a6,g_quickTrapProbe+456
	move.l #0xa89c,d0
	.word 0xa146
	move.l a0,g_quickTrapProbe+520
	lea pen_patch(pc),a0
	move.l #0xa89c,d0
	.word 0xa047
	move.w #9,-(sp)
	.word 0xa89c
	move.l g_quickTrapProbe+520,a0
	move.l #0xa89c,d0
	.word 0xa047
	move.w #11,-(sp)
	.word 0xa89c
	| OS aliases share a patch slot, but retain the caller's A0-return flag.
	move.l #0xa11a,d0
	.word 0xa346
	move.l a0,g_quickTrapProbe+532
	lea zone_patch(pc),a0
	move.l #0xa01a,d0
	.word 0xa047
	.word 0xa11a
	move.l a0,g_quickTrapProbe+540
	move.l g_quickTrapProbe+532,a0
	move.l #0xa01a,d0
	.word 0xa047
	.word 0xa11a
	move.l a0,g_quickTrapProbe+544
	move.l sp,g_quickTrapProbe+528
	| Ordinary game startup initializes its own QuickDraw globals.
	movem.l (sp)+,d2-d7/a2-a6
	.globl aitdQuickTrapProbeComplete
aitdQuickTrapProbeComplete:
	rts
pen_patch:
	addq.l #1,g_quickTrapProbe+524
	move.l g_quickTrapProbe+520,a0
	jmp (a0)
zone_patch:
	addq.l #1,g_quickTrapProbe+536
	move.l g_quickTrapProbe+532,a0
	jmp (a0)
seeds:
	.long 0x11110000,0x11110001,0x11110002,0x11110003
	.long 0x11110004,0x11110005,0x11110006,0x11110007
	.long 0x11110008,0x11110009,0x1111000a,0x1111000b
	.long 0x1111000c,0x1111000d,0x1111000e
	.section .bss.g_quickTrapProbe,"aw",@nobits
	.balign 4
	.globl g_quickTrapProbe
	.type g_quickTrapProbe,@object
g_quickTrapProbe:
	.space 548
	.size g_quickTrapProbe,.-g_quickTrapProbe
