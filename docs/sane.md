# Integer-only SANE positioning

The original Engine routine uses five FP68K operations at ten sites between +$47C2 and
+$4852. These are software service calls, not FPU instructions. `Sane.h` implements them
with integer arithmetic on the sole 68020 target:

| Selector | Operation | Argument cleanup |
| --- | --- | --- |
| $200E | signed word to extended | 10 bytes |
| $1004 | extended destination × IEEE single source | 10 bytes |
| $2000 | extended destination + signed word | 10 bytes |
| $0016 | truncate extended toward zero | 6 bytes |
| $2010 | extended to signed word, nearest-even | 10 bytes |

The supported state is FPState=0: default extended precision and nearest-even. Finite
normal/subnormal operands and signed zero are handled with exact wide integer
intermediates and explicit rounding. Unknown selectors, other FPState, nonfinite/invalid
encodings, overflow and out-of-range word conversion retain `SANE / FP68K`; rejected
operations leave the destination unchanged. This is not a claim of complete SANE
exception/environment support. The build keeps `-msoft-float` and its no-float link
audit; no floating-point runtime helpers link.

The unchanged original positioning computes horizontal 355 × 0.5 = 177.5, then truncates
to 177. Vertical positioning computes (480−20−90) × 0.5 + 20 = 205. Native originally
produced 195 because its MBarHeight shadow was zero. Paired probes at Engine+$479E
measured reference $0BAA=20, native zero, the same 640×480 device rectangle and
selected/main-device identity. The shadow is now initialized to 20; the existing
byte-checked patch changes `30380BAA` to `302D0F5C`. This is logical Mac geometry only:
no menu bar is drawn (D7), and DLOG 1000 stays hidden (D4). D5 prohibits all Mac dialog
presentation.

All fifteen data/address registers, FPState and destination guard bytes are preserved in
the paired ten calls. Original SANE clobbers CCR; each continuation overwrites it before
any conditional use. Native Toolbox returns retain their saved CCR. The FS-UAE debugger
reports stale SR at some original breakpoints, so the observer checks the actual
exception-frame word before and after each service instead. An initial debugger-SR
assertion was rejected and instrumented.

## Evidence and reproduction

`check_sane.py` compares 2,455 cases against an independent exact rational oracle under
host address/undefined-behavior sanitizers. The 41 deterministic fixtures also run
through the original Mac SANE service, with exact input readback as well as result
checks, including rounding, cancellation, signed zeros and subnormals.
`mac_sane_fixtures.lua` uses a bounded private scratch handle and controlled call
arguments; it changes no instructions. `mac_sane_position.lua` observes all ten original
calls without changing inputs. Both use the documented headless MAME command and require
normal exit.

```sh
python3 tools/check_sane.py
python3 tools/check_sane.py --write-fixtures tmp/sane-fixtures.lua
# MAME: -autoboot_script tools/mac_sane_fixtures.lua
python3 tools/check_sane.py --reference FIXTURE_LOG --status 0
# MAME: -autoboot_script tools/mac_sane_position.lua
# Native: GDBSCRIPT=sane.gdb ./diag_run.sh 60 (from amiga/, after build)
python3 tools/check_sane_position.py REFERENCE_LOG --status 0 --native NATIVE_LOG --native-status 0
```

The positioning checker guards original Engine+$477A–+$48AB bytes, all ten
operand/results, stack/registers, FPState, destination extents and the paired 177/205
position. Missing/duplicate completion, altered operands/results and nonzero/timeout
status fail. Maintained host checks include checker rejections. Local captures:
`tmp/m2-sane-height-reference.log`, `tmp/m2-literals-sane-fixtures.log` and
`tmp/m2-sane-verified-sane.log`.

### Live return-frame verification

The native observer checks flags immediately before Line-A's guarded `RTE`. If that
return routes through the VBL trampoline, it also checks the live saved CCR and resume
PC immediately before the guarded `move.w (sp)+,ccr; rts`. The caller's stack, registers
and arithmetic results remain checked afterward. It never treats the former
exception-frame stack address as live after return.

Palette-startup regression instrumentation demonstrated why: a due callback preserved
CCR=0 at both restoration points but reused the old frame storage, which read as 4 by
the original caller's breakpoint. That rejected old-observer run was not a SANE
arithmetic failure. `tmp/m2-palette-sane-live-frames.log` records both live points and
the reused storage; no runtime/SANE code changed.
