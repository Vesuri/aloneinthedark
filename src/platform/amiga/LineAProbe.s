| Test-only entry points; garbage-collected unless LINEAPROBE=1 calls them.
	.section .text.aitd_line_a_probe,"ax"
	.even
	.globl aitd_line_a_probe
aitd_line_a_probe:
	move.l sp,g_lineAProbe
	move.l a5,g_lineAProbe+4
	move.l #0x12340000,d0
	move.w #0x1f,ccr
	.word 0xa055
	move.w ccr,d1
	move.l d1,g_lineAProbe+8
	move.l #0x12340001,d0
	move.w #0x1f,ccr
	.word 0xa055
	move.w ccr,d1
	move.l d1,g_lineAProbe+12
	move.l #0x12348000,d0
	move.w #0x1f,ccr
	.word 0xa055
	move.w ccr,d1
	move.l d1,g_lineAProbe+16
	move.w #0x1f,ccr
	.word 0xa850
	move.w ccr,d1
	move.l d1,g_lineAProbe+20
	| Nonzero high word must not change QDExtensions selector 1.
	subq.l #2,sp
	clr.l -(sp)
	move.l #0x56780001,d0
	.word 0xab1d
	addq.l #2,sp
	move.l #aitd_line_a_callback_probe,g_macVBLCallbackEntry
	move.l #0x87654320,g_macVBLCallbackA5
	move.l #0x12340000,d0
	move.w #0x1f,ccr
	.word 0xa055
	move.w ccr,d1
	move.l d1,g_lineAProbe+32
	move.l a5,g_lineAProbe+4
	jsr aitd_trap_patch_probe
	rts
aitd_line_a_callback_probe:
	addq.l #1,g_lineAProbe+36
	move.w #0,ccr
	rts

	.section .text.aitd_line_a_exit_probe,"ax"
	.even
	.globl aitd_line_a_exit_probe
aitd_line_a_exit_probe:
	.word 0xa9f4
	illegal
