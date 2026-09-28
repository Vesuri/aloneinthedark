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
