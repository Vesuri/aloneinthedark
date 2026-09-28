| Real deferred OS/Toolbox traps, callbacks, nested ordinary traps and originals.
	.section .text.aitd_service_probe,"ax"
	.even
	.globl aitd_service_probe
aitd_service_probe:
	movem.l d2-d7/a2-a6,-(sp)
	move.l sp,g_serviceProbe+8
	move.l #.callback,g_macVBLCallbackEntry
	move.l a5,g_macVBLCallbackA5
	move.l #0x12340000,d0
	move.l #0x11223344,d1
	move.l #0xdeadbeef,a0
	movem.l d0-d7/a0-a6,g_serviceProbe+32
	move.w #0x1f,ccr
	.word 0xa1fc
	movem.l d0-d7/a0-a6,g_serviceProbe+92
	move.w ccr,d1
	andi.l #31,d1
	move.l d1,g_serviceProbe+12
	move.l #0xabcdef00,d0
	movem.l d0-d7/a0-a6,g_serviceProbe+152
	subq.l #2,sp
	move.w #0x5060,-(sp)
	move.l #0x10203040,-(sp)
	move.w #0x1f,ccr
	.word 0xabfb
	movem.l d0-d7/a0-a6,g_serviceProbe+212
	move.w ccr,d1
	andi.l #31,d1
	move.l d1,g_serviceProbe+16
	cmp.w #0x1357,(sp)+
	bne .failed
	move.l #0xa1fc,d0
	.word 0xa346
	move.l a0,a3
	move.l #0xa1fc,d1
	jsr (a3)
	cmp.l #0xffffff94,d0
	bne .failed
	cmp.l #0x2468ace0,a0
	bne .failed
	move.l #0xabfb,d0
	.word 0xa146
	move.l a0,a3
	subq.l #2,sp
	move.w #0x5060,-(sp)
	move.l #0x10203040,-(sp)
	jsr (a3)
	cmp.w #0x1357,(sp)+
	bne .failed
	move.l sp,d0
	cmp.l g_serviceProbe+8,d0
	bne .failed
	move.l #1,g_serviceProbe+24
.failed:
	movem.l (sp)+,d2-d7/a2-a6
	rts
.callback:
	addq.l #1,g_serviceProbe+20
	moveq #-1,d0
	moveq #-1,d1
	move.l #0x12345678,a5
	move.w #0,ccr
	rts

	.globl aitd_service_nested_probe
aitd_service_nested_probe:
	.word 0xa055
	rts
