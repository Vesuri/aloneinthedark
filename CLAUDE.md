# Repository guidance

This repository is an Amiga port of the Macintosh **Alone In The
Dark 1.0** (Interplay, 1994). It reuses the runtime of the completed Vette!
port, which is the reference for conventions and for
solutions already paid for. Read [README.md](README.md),
[docs/design.md](docs/design.md) (architecture, owner decisions, workflow),
[docs/development.md](docs/development.md) and
[docs/open-work.md](docs/open-work.md), the ordered work queue.

## Scope and correctness

- Keep the original 68k game instructions. Implement the documented services
  they call; do not replace game decisions with screen-specific guesses.
- Attribute code addresses as **(segment, offset)**; offsets include the
  four-byte CODE header. Segment names are the CODE resource names (Core, Dark…).
- Original Macintosh execution is the fidelity reference. State-pair captures;
  different CPU speeds need not display identical intermediate frames.
- Preserve every live register and condition code at binary hooks. Check original
  bytes before patching. Never map Mac Page 0 over Amiga vectors/Exec state.
- Unknown calls and unsupported loader layouts remain named loud stops. Do not
  add optional dialogs or guessed successes to hide a missing subsystem.
- The game is 68020 code (see [static map](docs/static-map.md)); do not plan
  around a 68000 target.
- Native presentation/input and global VBlank frame pacing are intentional port
  behavior (design.md D3). Pace completed frames, never individual drawing calls. See
  [architecture](docs/amiga-arch.md).

## Build and hardware

- Source `amiga/env.sh` in the same shell as builds/runs. Clean before changing
  build flags or widely included headers; the makefile does not track those.
- Build C/C++ with `-m68020 -mtune=68020 -msoft-float`; GNU assembly targets
  the 68020 ISA. Preserve the no-float and probe-symbol link audits.
  Use native integer arithmetic; the 68000-only math helpers are retired.
- `AitdScreen` owns display registers. Publish complete copper lists and
  bitplane/sprite pointers first in VBI, before input or audio work.
- Keep large temporary buffers off the trap dispatcher's stack. The measured
  FS-UAE system stack is only 6 KiB; inspect combined compiled frames for new
  trap helpers and leave room for the full interrupt call chain. Polygon
  encoding's 32-byte margin corrupted Exec during VBI despite correct output.
  Use owned temporary handles when staging large results.
- Keep explicit dirty rectangles; no shadow framebuffer or tile-diff machinery.
- Do not dispatch original game callbacks from an Amiga interrupt. The VBI updates
  time/input/Paula; Mac callbacks run at safe user-mode return points.
- Every debugger-read global must be in `PROBE_SYMS`; garbage-collected symbols
  can otherwise resolve into instruction bytes.
- Use `INTROSKIP=1` for routine service diagnostics (normal Enter input). Do not
  replay the full book unless the check specifically needs that animation.
- Unattended functional diagnostics default to maximum-speed `a4000-030`.
  Warp is enabled by default. Select `a1200-020` or `a4000-030-reference`
  explicitly for acceptance and performance measurements, with
  `EXTRA_ARGS=--warp_mode=0` for real-time runs. Optional `a4000-060` is a
  development speed pilot, not full CPU acceptance. Keep owner live runs at
  the requested settings.
- Check timing in emulated fields/ticks, not host wall time or screenshots.
  Warp is useful for bounded regression runs, not a real-time speed measurement.

## Local inputs and tools

- Keep personal filesystem paths and unrelated work references out of tracked
  files. Name other projects with project-relative paths only. Shared tools under
  `~/.local` and environment-overridable assets under `~/.local/share/amiga`
  are the convention; see [development.md](docs/development.md).
- Put screenshots and scratch output in ignored `tmp/`. Preserve original inputs
  and saves when cleaning local files. History belongs in Git, not progress logs.

- Never commit original game files, resource forks, .PAK/.ITD data, generated
  disassembly, screenshots, audio captures, ROMs or emulator state. `tmp/` and
  `ref/` are local-only. Build outputs and release archives are ignored.
- Never kill all FS-UAE or GDB processes. Use the scripts' PID-scoped cleanup.
  The shared helper is selected by `FSUAE_COMMON`; projects share the host.
- MAME must use the documented headless command, including
  `SDL_VIDEODRIVER=dummy`, `-window`, `-cfg_directory` and `-nvram_directory`.
- `tools/ghidra` is a symlink to the shared install in `~/.local/share/ghidra`.
- Keep maintained regression scripts, reusable format tools and concise current
  docs. One-off captures and diagnostics belong in `tmp/`, not the tracked tree.
- Source/resource names and decoded fields live in `disasm/symbols.csv`,
  `ghidra_scripts/entrypoints.csv` and the format documentation. Mark inference
  explicitly rather than treating a plausible name as a measured fact.

## Changes

- Keep `docs/open-work.md` strictly about unresolved work and its acceptance
  criteria. Do not add completion summaries, current-state inventories or
  historical progress logs. The overall plan belongs in `docs/design.md`;
  completed work belongs in Git history.
- Work [docs/open-work.md](docs/open-work.md) top down, one item at a time
  (design.md §8). Delete the item in the commit that completes it and add
  newly found work, with an ID and acceptance check, at its place in the queue.
- Owner decisions (design.md §5) and anything that changes game behaviour go
  to the owner; everything else proceeds on the documented defaults.
- Commit directly to `main`, one verified cohesive change per commit.
- Preserve unrelated worktree edits. Do not add hooks, signing or coauthor lines.
  Use the existing Vesuri identity and repository-local Git configuration.
  Keep remote/authentication overrides local to this repository or one command;
  never change global Git settings for this project.
- Validate in proportion to the change: host checks for pure helpers; original
  byte checks and bounded Amiga runs for runtime changes.
- Keep documentation current and concise. Historical experiments and removed
  development stages can be recovered from Git history.
