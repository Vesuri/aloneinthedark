| Shared no-due-service/unfinished-scene guard. Clobbers d0/d1/a0/a1/a6.
	lea g_rgbQuick,a6
	tst.w g_quickServiceValid
	bne.w .servicesReady
.checkServices:
	move.l 12(a6),a0
	tst.l (a0)
	bne.w .miss
	move.l g_macTicks,d0
	move.l d0,g_quickServiceTick
	clr.w g_quickServiceValid
	move.l 8(a6),a0
	cmp.l 8(a0),d0
	bne.w .miss
	tst.l 4(a0)
	bne.w .miss
	tst.b 16(a0)
	bne.w .miss
	| Preserve effect polling: only an active, unfinished ordinary sample
	| needs no service. Stream completion retains the ordinary implementation.
	tst.w g_soundDriver+72
	beq.s 1f
	tst.l g_effects
	bne.w .miss
	move.l d0,d1
	sub.l g_effects+24,d1
	bpl.w .miss
1:	tst.w g_soundDriver+80
	beq.s 2f
	tst.l g_effects+36
	bne.w .miss
	sub.l g_effects+60,d0
	bpl.w .miss
2:	move.w #1,g_quickServiceValid
	| Publish, then validate: an interrupt during the cold checks cannot
	| leave a newly valid certificate for an old tick or an audio failure.
	move.l g_quickServiceTick,d0
	cmp.l g_macTicks,d0
	bne.s .staleCertificate
	move.l 12(a6),a0
	tst.l (a0)
	beq.s .servicesReady
.staleCertificate:
	clr.w g_quickServiceValid
	bra.w .miss
.servicesReady:
	move.l g_macSceneFrameOwner,d0
	beq.w .miss
	move.l usp,a1
	cmp.l a1,d0
	bcs.w .miss
	move.l d0,a0
	move.l 16(a6),a1
	move.l (a1),d1
	cmp.l (a0),d1
	bne.w .miss
	move.l 20(a6),a1
	move.l (a1),d1
	cmp.l 4(a0),d1
	bne.w .miss
