	.text
	.even
| Native music must not consume the interrupted graphics service's small
| supervisor stack. This is a C ABI call within VBI, not a Mac callback.
	.globl aitd_song_vbi
aitd_song_vbi:
	move.l sp,a0
	lea aitd_song_stack_end,sp
	move.l a0,-(sp)
	jsr aitdSongInterrupt
	move.l (sp)+,sp
	rts
| Ownership release can run in user or supervisor mode. Keep its stack
| separate from both the caller's small stack and the VBI music stack.
	.globl aitd_song_deferred
aitd_song_deferred:
	move.l sp,a0
	lea aitd_song_deferred_stack_end,sp
	move.l a0,-(sp)
	jsr aitdSongDeferred
	move.l (sp)+,sp
	rts
	.bss
	.balign 4
aitd_song_stack:
	.space 8192
aitd_song_stack_end:
	.balign 4
aitd_song_deferred_stack:
	.space 8192
aitd_song_deferred_stack_end:
	.text
	.even
	.globl aitd_call_mac_code
aitd_call_mac_code:
	move.l 4(sp),a0
	move.l 8(sp),a1
	move.l 12(sp),d0
	movem.l d2-d7/a2-a6,-(sp)
	move.l sp,g_macHostReturnSP
	move.l a1,a5
	move.l d0,sp
	jsr (a0)
	move.l g_macHostReturnSP,sp
	clr.l g_macHostReturnSP
	movem.l (sp)+,d2-d7/a2-a6
	rts

| Enter the Macintosh ExitToShell trap from a normal user-mode trap return.
| The game's installed patch runs first, restores the old trap address, then
| invokes this trap again to reach aitd_user_exit_trampoline below.
	.globl aitd_user_exit_request
aitd_user_exit_request:
	.word 0xa9f4
1:	bra.s 1b

| ExitToShell never returns to its Macintosh caller.  Restore the user stack
| saved immediately before the application entry JSR, then execute the matching
| aitd_call_mac_code epilogue so C++ regains control with its callee-saved
| registers intact.
	.globl aitd_user_exit_trampoline
aitd_user_exit_trampoline:
	move.l g_macHostReturnSP,sp
	clr.l g_macHostReturnSP
	movem.l (sp)+,d2-d7/a2-a6
	rts

	.globl aitd_line_a_handler
aitd_line_a_handler:
	| Vette kept one high-frequency private trap ($AFFD) out of the C++
	| dispatcher here.  Add such a fast path only for a measured hot hook.
	movem.l d0-d7/a0-a6,-(sp)
	move.l sp,a0
	lea 60(sp),a1
	move.l 2(a1),a3
	move.w (a3),d7	| Original trap word; C ABI preserves D7.
	cmpi.w #0xaffe,d7
	bne.s 5f
	move.w 2(a3),d7	| Private callable-original stub's trap class.
5:
	move.l usp,a2
	move.l a2,-(sp)
	move.l a1,-(sp)
	move.l a0,-(sp)
	jsr aitdLineADispatch
	lea 12(sp),sp
	cmpi.l #-1,d0
	beq.w .defer_service
	tst.l d0
	beq.s 1f
	subq.l #1,d0
	move.l usp,a0
	adda.w d0,a0
	move.l a0,usp
	btst #11,d7
	bne.s 3f
	| Direct sound queries publish their measured selector-specific CCR.
	cmpi.w #0xa0f8,d7
	beq.s 3f
	| OS return: TST.W D0 semantics, retaining X and all saved SR high bits.
	andi.w #0xfff0,60(sp)
	tst.w 2(sp)	| Low word of saved D0, not the dispatcher cleanup result.
	bmi.s 4f
	bne.s 3f
	ori.w #4,60(sp)
	bra.s 3f
4:	ori.w #8,60(sp)
3:
	movem.l (sp)+,d0-d7/a0-a6
	addq.l #2,2(sp)
	tst.w g_macServiceActive
	bne.s 2f
	tst.w g_macFileCompletionDepth
	bne.s 2f
	tst.l g_macVBLCallbackEntry
	beq.s 2f
	move.l 2(sp),g_macVBLCallbackReturn
	move.l #aitd_user_vbl_trampoline,2(sp)
2:
	rte
1:
	bra.s 1b

.defer_service:
	movem.l (sp)+,d0-d7/a0-a6
	move.l #aitd_user_service_trampoline,2(sp)
	rte

| Save every application register before calling the C++ service in user mode.
	.globl aitd_user_service_trampoline
aitd_user_service_trampoline:
	lea -4(sp),sp
	move.w ccr,-(sp)
	movem.l d0-d7/a0-a6,-(sp)
	move.l sp,-(sp)
	jsr aitdUserServiceDispatch
	move.l d0,sp
	movem.l (sp)+,d0-d7/a0-a6
	move.w (sp)+,ccr
	rts

| Entered by RTE in user mode, with the original application's registers and
| USP restored.  Keep those registers parked while draining all Macintosh
| VBLTasks already due at this safe scheduling point, then resume after the
| trap.  Reload the parked image before each callback so one VBLTask cannot
| leak scratch registers into the next.
	.globl aitd_user_vbl_trampoline
aitd_user_vbl_trampoline:
	lea -4(sp),sp	| Reserve resume PC without changing CCR.
	move.w ccr,-(sp)
	movem.l d0-d7/a0-a6,-(sp)
1:
 .ifdef AITD_PROBE
	move.w ccr,-(sp)
	jsr aitdProfileMacVBLBegin
	move.w (sp)+,ccr
 .endif
	movem.l (sp),d0-d7/a0-a6
	move.l g_macVBLCallbackEntry,a1
	clr.l g_macVBLCallbackEntry
	move.l g_macVBLCallbackTask,a0
	move.l g_macVBLCallbackA5,a5
	move.w #1,g_macVBLCallbackActive
	jsr (a1)
 .ifdef AITD_PROBE
	jsr aitdProfileMacVBLEnd
 .endif
	clr.w g_macVBLCallbackActive
	jsr aitdVBLCallbackComplete
	tst.l g_macVBLCallbackEntry
	bne.s 1b
	movem.l (sp)+,d0-d7/a0-a6
	move.l g_macVBLCallbackReturn,2(sp)
	move.w (sp)+,ccr
	rts

| RTS from an installed OS patch. Layout follows routePatchedTrap's saved USP
| record; restore the dispatcher-saved registers and TST.W D0 after all moves.
	.globl aitd_os_patch_return
aitd_os_patch_return:
	btst #0,26(sp)	| Trap bit 8: allow an A0 result when set.
	bne.s 1f
	move.l (sp),a0
1:	move.l 4(sp),a1
	move.l 8(sp),d1
	move.l 12(sp),d2
	move.l 16(sp),a2
	move.l 20(sp),24(sp)
	lea 24(sp),sp
	tst.w d0
	rts

| File completions run on the active user stack, outside the service boundary.
| Preserve the native C ABI and the Mac A5 context. D0 is deliberately returned:
| the local-HFS reference lets the completion's D0 survive the File Manager call.
    .globl aitd_call_file_completion
aitd_call_file_completion:
    movem.l d2-d7/a2-a6,-(sp)
    move.l 48(sp),a1
    move.l 52(sp),a0
    move.l 56(sp),d0
    move.l 60(sp),a5
    jsr (a1)
    movem.l (sp)+,d2-d7/a2-a6
    rts
