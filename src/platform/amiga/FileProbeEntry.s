    .section .text.aitdFileProbeTraps,"ax"
    .even
    .macro filetrap name,opcode
    .globl \name
\name:
    move.l 4(sp),a0
    .word \opcode
    move.w ccr,g_fileProbeCCR
    rts
    .endm
    filetrap aitdProbeOpen,0xa000
    filetrap aitdProbeHOpen,0xa200
    filetrap aitdProbeRead,0xa002
    filetrap aitdProbeClose,0xa001
    filetrap aitdProbeEOF,0xa011
    filetrap aitdProbeSeek,0xa044
    filetrap aitdProbePosition,0xa018
    filetrap aitdProbeGetVol,0xa014
    filetrap aitdProbeSetVol,0xa015
    .globl aitdProbeOpenWD
aitdProbeOpenWD:
    move.l 4(sp),a0
    moveq #1,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeFCB
aitdProbeFCB:
    move.l 4(sp),a0
    moveq #8,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    filetrap aitdProbeHGetVol,0xa214
    filetrap aitdProbeHSetVol,0xa215
    .globl aitdProbeGetWD
aitdProbeGetWD:
    move.l 4(sp),a0
    moveq #7,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeCloseWD
aitdProbeCloseWD:
    move.l 4(sp),a0
    moveq #2,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeWriteBackend
aitdProbeWriteBackend:
    .word 0xa0fb
    move.w ccr,g_fileProbeCCR
    rts

    filetrap aitdProbeWrite,0xa003
    filetrap aitdProbeSetEOF,0xa012
    filetrap aitdProbeFlush,0xa013

    filetrap aitdProbeCreate,0xa008
    filetrap aitdProbeHCreate,0xa208
    filetrap aitdProbeDelete,0xa009
    filetrap aitdProbeHDelete,0xa209
    filetrap aitdProbeInfo,0xa00c
    filetrap aitdProbeHInfo,0xa20c
    filetrap aitdProbeSetInfo,0xa00d
    filetrap aitdProbeHSetInfo,0xa20d

    filetrap aitdProbeOpenRF,0xa00a
    filetrap aitdProbeHOpenRF,0xa20a

    .globl aitdProbeVolParms
aitdProbeVolParms:
    move.l 4(sp),a0
    moveq #0x30,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts

    .globl aitdProbeOpenDF
aitdProbeOpenDF:
    move.l 4(sp),a0
    moveq #0x1a,d0
    .word 0xa060
    move.w ccr,g_fileProbeCCR
    rts
    .globl aitdProbeHOpenDF
aitdProbeHOpenDF:
    move.l 4(sp),a0
    moveq #0x1a,d0
    .word 0xa260
    move.w ccr,g_fileProbeCCR
    rts

    filetrap aitdProbeHGetVInfo,0xa207

    .section .text.aitdFileAsyncProbe,"ax"
    filetrap aitdProbeAsyncInfo,0xa40c
    filetrap aitdProbeAsyncHInfo,0xa60c
    filetrap aitdProbeAsyncCreate,0xa608
    filetrap aitdProbeAsyncSetInfo,0xa60d
    filetrap aitdProbeAsyncOpenRF,0xa60a
    filetrap aitdProbeAsyncGetVol,0xa614
    filetrap aitdProbeAsyncSetVol,0xa615
    .macro asyncdispatch name,selector
    .globl \name
\name:
    move.l 4(sp),a0
    moveq #\selector,d0
    .word 0xa660
    move.w ccr,g_fileProbeCCR
    rts
    .endm
    asyncdispatch aitdProbeAsyncOpenWD,1
    asyncdispatch aitdProbeAsyncCloseWD,2
    asyncdispatch aitdProbeAsyncGetWD,7
    asyncdispatch aitdProbeAsyncFCB,8
    .globl aitdFileAsyncCompletion
aitdFileAsyncCompletion:
    addq.l #1,g_fileAsyncCallbacks
    move.l a5,g_fileAsyncA5
    move.l a0,g_fileAsyncPB
    move.l d0,g_fileAsyncResult
    tst.l g_fileAsyncNested
    beq.s 1f
    movem.l d0/a0,-(sp)
    jsr aitdFileAsyncNestedCall
    movem.l (sp)+,d0/a0
1:  tst.l g_fileAsyncClobber
    beq.s 2f
    move.l #0xdeadbeef,d0
    move.l #0xaabbccdd,d1
    move.l #0xbbccddee,d2
    move.l #0xccddee00,a0
    move.l #0xddee0011,a1
2:  rts

    .globl aitdProbeAsyncRegisters
aitdProbeAsyncRegisters:
    movem.l d2/a5,-(sp)
    move.l 12(sp),a0
    move.l #0x11223344,d1
    move.l #0x22334455,d2
    move.l #0x33445566,a1
    move.l #0x12345678,a5
    .word 0xa614
    move.w ccr,g_fileProbeCCR
    cmpi.l #0x11223344,d1
    bne.s 3f
    cmpi.l #0x22334455,d2
    bne.s 3f
    cmpa.l #0x33445566,a1
    bne.s 3f
    cmpa.l #0x12345678,a5
    bne.s 3f
    cmpa.l 12(sp),a0
    beq.s 4f
3:  move.l #0xbad00001,d0
4:  movem.l (sp)+,d2/a5
    rts
