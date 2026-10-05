# Game interfaces (D5)

New game, character choice, save-name entry and load selection use the
original engine's interfaces inside 320×200. They do not call the Macintosh
Dialog Manager. Preserve these existing interfaces rather than replacing them
with new controls. Right-Amiga+S/O reaches the same engine screens as the
original Command-S/O; Escape cancels through the game's own input path.

The observed Mac route includes new game, Save cancellation, typed save,
overwrite of that slot, Load cancellation, actual reload and Quit. Its only
application Dialog Manager calls are startup InitDialogs, GetNewDialog(1000),
two ModalDialog calls, two GetDItem calls and disposal. The Mac's internal
NewDialog/CloseDialog calls belong to that same chooser. D4 suppresses it on
the Amiga and returns item 2 automatically. No alert or StandardFile call
occurs on this route, including save overwrite.

Resource labels previously suggested different behavior. DITL 129 contains
"New Game", and DLOG/DITL 131 contains Save/Cancel/Don't Save buttons, but
neither is called by this route. DITL 200/201/212 even contains castle-design
instructions. These are resource inventory, not evidence of reached UI.
Do not add an overwrite warning the original does not show.

The native 68030 fixture uses ordinary input through startup and character
selection, enters `m3test` in Save, opens/cancels Load and quits. It keeps
audio on and warp off. Its observer rejects any non-size dialog construction
or DrawDialog call, and requires the hidden chooser and every startup stage
as positive controls. New-game and character-story captures match all 64,000
Mac viewport pixels exactly, including original Times/14 text. Save/Load
captures identify the same engine artwork; names and thumbnails can differ
after independent saves. All captured interfaces leave pixels outside the
viewport unchanged, and no menu bar is drawn.
The fixture implies `INGAME=1`: boot visuals are drawn internally and their
framebuffer captures are compared, while boot presentation is suppressed for
testing. Save/Load captures are published gameplay frames. Full visible startup
acceptance remains the separately verified M2 route.

This establishes M3.3 for the reached gameplay interfaces. Paired native/reference save→move→load and native abrupt-restart durability
now pass M3.5/M3.6; see [current acceptance](development.md). Error alerts, monitor-selection
failures, About and other unreached paths are not accepted by this check;
unsupported service calls retain named stops. Any newly reached dialog must
be measured and given an in-game replacement under D5 before accepting that
path in the broader gameplay work.

## Reproduce

Create `tmp/m3-dialog` and `tmp/m3-menu`. Run `tools/mac_dialog_route.lua` with
the [documented headless Mac IIx setup](mac-reference-loop.md), debugger enabled,
logging to `tmp/m3-dialog/mac-route.log`. The reference changes its test save
slot, including an overwrite, through ordinary game input.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4 MENUPROBE=1 PROBES=1
DIAG_AUDIO=1 EXTRA_ARGS=--warp_mode=0 GDBSCRIPT=dialog_route.gdb \
  amiga/diag_run.sh 300 >tmp/m3-dialog/native-route.log 2>&1
```

Preserve `amiga/.run/gdb-out.log` as `tmp/m3-dialog/native-gdb.log` and run
`tools/check_dialog_route.py` with the reference/native logs and their actual
exit statuses. The wrapper also runs the [M3.2 menu observer](menu-manager.md)
and writes its captures to `tmp/m3-menu`. Accepted local logs are `mac-route.log`,
`native-gdb.log` and `checked.log` under `tmp/m3-dialog`, with both runner
statuses zero. A timeout, missing chooser, extra application dialog call,
wrong startup order or changed frame fails acceptance. Clean-build normally
after the diagnostic run so automated test input is absent from production.

## Oil-lamp inventory actions

The paired attic route takes the oil lamp, selects it through the engine
inventory and executes Use. The original menu offers Use, Reload, Throw and
Drop/Put. The measured Use result is “The lamp has no oil”; body 11/animation
287 remains under manual control, and ordinary movement afterward passes.
Published feedback matches the original glyphs, colour and horizontal placement.
Other lamp actions remain unverified. See the [reproducible Use route](development.md#autonomous-empty-lamp-use--2026-10-05).
