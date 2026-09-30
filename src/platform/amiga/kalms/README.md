# Kalms eight-plane converter

`c2p1x1_8_c5_gen.s` is unchanged from Mikael Kalms' collection:
https://github.com/Kalmalyzer/kalms-c2p
commit `d8ecf79a3325615305dd800ae7704b518e0d9dda`,
`normal/c2p1x1_8_c5_gen.s` (1999-01-08).

The upstream `readme.txt` places all files outside `others/` in the public
domain, permitting modification and commercial/noncommercial redistribution.

The port's `framework/KalmsC2P.s` supplies `BPLSIZE=40` and converts each dirty
row separately. Eight 40-byte planes occupy each 320-byte interleaved output
row; source rows are 640 bytes apart. Widths are normalized to multiples of
32 pixels before entry. The CPU-only integer routine uses no blitter, FPU,
self-modifying code or original game callbacks. Initialization and conversion
run together in the main task, never from an interrupt.

Verification uses the existing `AGAPROBE=1` five-frame native fixture and
`tools/check_aga_capture.py fixture LOG --status 0`. The decoder checks every
output pixel, including preserved pixels outside dirty rectangles, all eight
plane pointers, all palette entries and publication timing. The fifth frame
uses source origin (161,151), exercising unaligned 68020 source reads.
