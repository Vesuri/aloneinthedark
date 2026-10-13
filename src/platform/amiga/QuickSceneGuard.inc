| Shared no-due-service/unfinished-scene guard. Clobbers d0/d1/a0/a1/a6.
	lea g_rgbQuick,a6
	move.l 8(a6),a0
	move.l g_macTicks,d0
	cmp.l 8(a0),d0
	bne.w .miss
	tst.l 4(a0)
	bne.w .miss
	tst.b 16(a0)
	bne.w .miss
	move.l 12(a6),a0
	tst.l (a0)
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
2:	move.l g_macSceneFrameOwner,d0
	beq.w .miss
	cmp.l 12(sp),d0
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
