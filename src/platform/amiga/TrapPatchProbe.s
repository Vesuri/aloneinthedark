| Native tests of installed patches and callable originals. LINEAPROBE only.
	.section .text.aitd_trap_patch_probe,"ax"
	.even
	.globl aitd_trap_patch_probe
aitd_trap_patch_probe:
	move.l sp,g_lineAProbe+152
	moveq #-1,d0
	.word 0xa0bd
	move.l d0,g_lineAProbe+156
	moveq #1,d0
	.word 0xa198
	move.l d0,g_lineAProbe+160
	moveq #3,d0
	.word 0xa198
	move.l d0,g_lineAProbe+164
	move.l #0xa055,d0
	.word 0xa346
	move.l a0,g_lineAProbe+48
	lea os_patch(pc),a0
	move.l #0xa055,d0
	.word 0xa047
	bsr.w os_inputs
	.word 0xa055
	move.w ccr,g_lineAProbe+100
	movem.l d0-d2/a0-a2,g_lineAProbe+76
	move.l sp,g_lineAProbe+104
	bsr.w os_inputs
	.word 0xa155
	.globl aitd_patch_second_return
aitd_patch_second_return:
	move.w ccr,g_lineAProbe+132
	movem.l d0-d2/a0-a2,g_lineAProbe+108
	move.l sp,g_lineAProbe+136
	move.l g_lineAProbe+48,a0
	move.l #0xa055,d0
	.word 0xa047
	move.l #0xa9a0,d0
	.word 0xa146
	move.l a0,g_lineAProbe+52
	lea tool_patch(pc),a0
	move.l #0xa9a0,d0
	.word 0xa047
	subq.l #4,sp
	move.l #0x434f4445,-(sp)
	move.w #1,-(sp)
	.word 0xa9a0
	move.l (sp)+,g_lineAProbe+140
	move.l sp,g_lineAProbe+144
	move.l g_lineAProbe+52,a0
	move.l #0xa9a0,d0
	.word 0xa047
	rts
os_inputs:
	move.l #0xabcdef00,d0
	move.l #0x89abcdef,d1
	move.l #0x01234567,d2
	move.l #0x11223344,a0
	move.l #0x55667788,a1
	move.l #0x33445566,a2
	move.w #0x1f,ccr
	rts
os_patch:
	move.l d1,g_lineAProbe+56
	move.l d2,g_lineAProbe+60
	move.l a2,g_lineAProbe+64
	move.l g_lineAProbe+48,a2
	jsr (a2)
	move.l d0,g_lineAProbe+68
	addq.l #1,g_lineAProbe+72
	move.l #0x2468ace0,a0
	moveq #0,d1
	moveq #0,d2
	suba.l a1,a1
	suba.l a2,a2
	move.w #0x1f,ccr
	moveq #-108,d0
	rts
tool_patch:
	addq.l #1,g_lineAProbe+148
	move.l g_lineAProbe+52,a0
	jmp (a0)
