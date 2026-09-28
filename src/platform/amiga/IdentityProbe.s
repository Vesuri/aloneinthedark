| Diagnostic-only identity errors through real native Line-A instructions.
	.section .text.aitd_identity_probe,"ax"
	.even
	.globl aitd_identity_probe
aitd_identity_probe:
	move.l #0x7174696d,d0
	.word 0xa1ad
	cmp.l #0xea51,d0
	bne .failed
	move.l a0,d1
	bne .failed
	move.l #1,g_identityProbeStage
	move.l #0x612f7578,d0
	.word 0xa1ad
	cmp.l #0xea52,d0
	bne .failed
	move.l a0,d1
	bne .failed
	move.l #2,g_identityProbeStage
	move.l #0x78787878,d0
	.word 0xa1ad
	move.l #3,g_identityProbeStage
.failed:
	rts
