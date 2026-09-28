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
