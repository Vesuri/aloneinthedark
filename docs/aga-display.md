# Eight-bit display bring-up

The integrated display publishes the first client clear and reaches
`QUICKDRAW / SETGWORLD` at Engine+$1286 after palette binding/activation and
background ShowHide. ShowHide changes no displayed pixel and queues no extra frame. Independent startup and
five-frame fixture capture decoders pass, as do the 21 startup observers and
paired checks, fresh/existing preferences, host tests, system-window checks,
clean boot and streamed-resource regressions. This is M2.5a prerequisite
acceptance; rendered video and intro acceptance remain pending.

`Planar8.h` defines a 320×200 destination with eight interleaved 40-byte plane
rows (64,000 bytes total), sampled from the live viewport of the 640×480 Mac
screen. It clips and aligns dirty rectangles to 32 destination pixels. Host
sanitizer checks decode every plane independently, cover every palette index,
check partial-write preservation, edge clipping, an unaligned source origin,
and invalid-input atomicity. This integer converter is also the future assembly
verification reference; it is not an optimization or M2.6 completion.

`AgaPalette.h` emits all 256 RGB24 colours through eight banks, writing high
and low nibbles separately and restoring bank zero/LOCT-clear state. Its input
is already display RGB24. It deliberately does not apply Vette's four-bit gamma
thresholds or guess the Mac video transfer. Host tests independently decode the
copper writes and verify every colour, bank/write count and output boundary.
The bank and nibble encoding follows the original
[HowToCode AGA programming notes](https://jvaltane.kapsi.fi/amiga/howtocode/aga.html).

`VideoColor.h` now supplies the measured integer transfer. The maintained
`mac_video_transfer.lua` runs 257 CPU SetEntries calls after the byte-checked
startup boundary. It exercises all 65,536 RGB16 grayscale values plus 256 mixed
colours, and captures actual arguments, input arrays, stack cleanup and mdc48
outputs. The low byte has no effect for any tested input; a 256-byte table is
therefore exact for this reference. The expanded map's SHA-256 is
`bf0a6433c155a61989e5dc0571bae1357066ab476a24d0afaf2e2aa7094fe2aa`.
The checker also matches all 512 before/after startup palette colours. No
floating-point arithmetic or fitted gamma is used. The service signature is
specified in Apple's [Color Manager reference](https://dev.os9.ca/techpubs/mac/ACI/ACI-108.html).

The maintained reference run exited zero with its positive completion marker:
`tmp/m2-video-transfer-maintained.log`; checker evidence is
`tmp/m2-video-transfer-checked.log`. Reproduce using the headless command in
[mac-reference-loop.md](mac-reference-loop.md) with the maintained Lua script,
then run `python3 tools/check_video_transfer.py --reference LOG --status 0`,
supplying the actual runner exit code. Captures stay local in `tmp/`.

The runtime uses one 320×200 eight-plane mode and Vette's explicit dirty
synchronization. Main-thread conversion prepares the back bitmap and inactive
copper list; VBI publishes both together before input work. The clean startup
run (`tmp/m2-aga-startup-final.log`, exit zero) published at line zero.
`check_aga_capture.py startup LOG --status 0` independently decodes every
pixel, all eight plane pointers and all 256 RGB24 colours and checks that the
queued and active buffers match. Supply the actual observer exit status.
The five-frame `AGAPROBE=1` fixture additionally exercises partial changes,
a palette-only update, viewport movement and display cleanup. The bounded run
`tmp/m2-aga-fixture-entry.log` exited zero and its independent decoder passed
all five frames, with every publication at line zero. Launch it with `GDB_ENTRY=aitdRunAgaProbe GDBSCRIPT=aga_probe.gdb`. No rendered output is accepted
by the helper tests alone. Sprite palette ownership still needs validation
before enabling the game pointer; the 256 game colours must not be overwritten
by inherited 16-colour cursor setup.

Regression evidence is local: `tmp/m2-aga-startup-suite.log`,
`tmp/m2-aga-windowstate.log`, `tmp/m2-aga-final-variants-{fresh,low}.log`,
`tmp/m2-aga-host-tests.log`, `tmp/m2-aga-window-core.log`, `tmp/m2-aga-boot.log`
and `tmp/m2-aga-resource-read.log`. The M2.5a checkpoint production SHA-256 is
`df261784efb9b279b0a26fe89e24ba75823ba7481e0fd816dd30f9c3701441c6`.
The no-float and 78-symbol link audits pass. Capture-checker rejection checks
cover nonzero/timeout status, debugger errors, missing completion and corrupted
partial-update pixels. The system-window check records zero late publications
and preserves all 64,000 bitmap bytes across OS ownership; this is not video.
