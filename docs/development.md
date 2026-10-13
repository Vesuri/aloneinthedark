# Development

The Amiga executable is the product; there is no host game renderer. Use
[testing.md](testing.md) for regression procedures and [open-work.md](open-work.md) for
unresolved work. Implementation history and old measurements are in Git.

## Build dependencies

- GNU make, Bash, Python 3 and a host C/C++ compiler for helper checks.
- `m68k-amiga-elf-gcc` (with its C++ frontend), `elf2hunk`, cross-GDB and vasm.
- Amiga NDK headers and WHDLoad SDK includes for the slave.
- LHa for UNIX with LH5 encoding, plus Lhasa's `lha` for independent decoding.
- FS-UAE for Amiga tests; MAME for original Macintosh comparisons.
- For the optional cycle profiler: Git, curl, autotools, pkg-config, glib, gettext, SDL2,
   FreeType and libpng. AmigaXDev's `make setup` installs its space-free build.
- `unar` and `hfsutils` for the independent Python data extractor; the standalone
  C installer helper does not need them.

AmigaXDev (`make setup`) installs the toolchain under `~/.local` and the common Amiga
files under `~/.local/share/amiga`. `amiga/env.sh` sources its shared `env.sh`, which puts
the toolchain on PATH and sets the variables below; `amiga/env.sh` keeps WHDLoad 19.2 for
the slave and its tests. `VASM`, `NDK` and `WHDLOAD` override slave dependencies. All
launchers source the shared `fsuae_common.sh` for PID-scoped process and port management,
and launch through its `fsuae_options`/`fsuae_launch`: the pinned machine arguments come
first, debug and diagnostic runs are silent with the window behind the others (`WINDOW=front`
or `none` to change it), and `run.sh` plays with sound in front. These tools are developer
dependencies, not release contents.

## Shared files and environment overrides

Common Amiga files live under `~/.local/share/amiga`; AmigaXDev installs them from the ROM
and OS sources you supply. None are tracked or packaged. Every common input has an override:

| Variable | Default | Purpose |
| --- | --- | --- |
| `KICKSTART` | `~/.local/share/amiga/Kickstarts/kick40063.A600` | KS 3.1 A600 ROM: native launchers, installer tests and WHDLoad guest |
| `KICKSTART_RTB` | `KICKSTART` filename plus `.RTB` | Matching relocation table for installer/WHDLoad tests |
| `WHDLOAD_HOST_KICKSTART` | `~/.local/share/amiga/Kickstarts/kick40068.A1200` | Outer emulator ROM for the WHDLoad test; distinct from its guest ROM |
| `WORKBENCH_ADF` | `~/.local/share/amiga/Workbenchv2.04rev37.67Workbench.adf` | Workbench and Installer/WHDLoad tests |
| `INSTALLER43` | `~/.local/share/amiga/Installer43/Installer` | Real Installer binary used by its test |
| `WHDLOAD` | `~/.local/share/amiga/WHDLoad` | SDK directory; tests use its `C/WHDLoad` binary |
| `FSUAE_COMMON` | `~/.local/share/amiga/fsuae_common.sh` | Shared launcher helper |
| `FSUAE` | `fs-uae` on PATH, with the ARM selection below | Emulator executable |
| `FSUAE_ARM` | `~/.local/share/amiga/fs-uae-arm/fs-uae` | Native ARM emulator for fast 68030 diagnostics |
| `FSUAE_MMU` | `~/.local/share/amiga/fs-uae-mmu-fixed/fs-uae` | Corrected 040/060 MMU/cache emulator for WHDLoad `--data-cache` checks |
| `FSUAE_APROF` | `~/.local/share/amiga/fs-uae-aprof/fs-uae` | Cycle-profiling emulator that AmigaXDev builds ([performance](performance.md#cycle-profiler)) |
| `MAME` | `mame` on PATH | Original Mac audio regression emulator |
| `GDB` | `m68k-amiga-elf-gdb` | Native diagnostic debugger |
| `VASM` | `~/.local/vasmm68k_mot` | Slave assembler |
| `NDK` | `~/.local/opt/m68k-amiga-elf/sys-include` | NDK includes |
| `LHA` | `lha-compress` on PATH, then the shared `lha-compressor/src/lha` | LH5 encoder |
| `FSEMU_SCREENSHOTS_DIR` | repository `tmp/screenshots` | F12+S screenshots |

The WHDLoad test also accepts `--rom`, `--rtb`, `--host-rom`, `--workbench` and
`--whdload`; explicit options take precedence over environment defaults. Keep the guest
ROM's supported WHDLoad filename and matching RTB. The A600 default has SHA-256
`8c8a0cf04f91b88eaf0c4f1126041987067e2286a8ee590bdbae447a8000c5ee`; the outer A1200 ROM
has SHA-256 `0bc8cf92d9e21d071118abd77f76b13dc77bfa4f2df2c50a8ed51a50b24741d7`. Changing
a default location must preserve the input bytes, verified by hash.

Use repo-relative paths for project inputs and outputs. Do not put personal home paths
or paths into other checkouts in tracked files. Cite another project by name only (for
example, Vette's architecture document); generic lessons are cited from AmigaXDev's docs.
Template credits name the template, not its installation location.

## Build and original data

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4
make installer slave
make release
```

Outputs are `amiga/out/AloneInTheDark.exe`, `build/install-data/AitdInstallData.exe`,
`build/whdload/AloneInTheDark.slave` and `dist/AloneInTheDark-0.91.lha`. Production
builds need no original game input. Always clean when changing build flags or widely
included headers: make does not track those changes. Every link checks for unwanted
floating-point helpers and missing debugger probe symbols. The executable targets 68020
with `-msoft-float`, without an FPU.

Put the supported StuffIt archive under ignored `tmp/`, then run:

```sh
make extract-original-data ARCHIVE=tmp/AloneInTheDark.img_.sit
make segments
```

The first writes the application resource fork and installed data into
`tmp/runtime-data/`; the second writes CODE resources to `tmp/segments/`. See [the
extraction contract](install-original-data.md). The native staging helper accepts
`AITD_APP_RSRC` and `AITD_DATA_DIR` (paths relative to `amiga/` when used by the
launchers). Root extras and Finder companions must be beside the application resource
fork. It stages game inputs under the executable's `data/` directory. The port-owned overlay
is embedded in the executable. Saved games and preferences use separate `Saved
Games/` and `prefs/` drawers.

## Running and debugging

```sh
. amiga/env.sh
amiga/run.sh
```

Normal launch shows every boot scene and uses audio, fixed-clock 68030 and PAL. For
direct gameplay testing, clean-build with `INGAME=1`; it skips publisher, book, menu,
story and intro but still performs normal initialization/loading. `INTROSKIP=1` only
sends the normal Enter skip during the boot sequence. Clean-build without either flag to
restore production startup.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4 INGAME=1
amiga/run.sh
```

| `AMIGA_CONFIG` | CPU and timing |
| --- | --- |
| `a1200-020` | 68EC020, fixed PAL 14.18758 MHz / NTSC 14.31818 MHz |
| `a4000-030-reference` | 68030, fixed 15.6672 MHz, comparable to the Mac IIx |
| `a4000-020`, `a1200-030`, `a4000-030` | Maximum-speed 020/030 functional diagnostics |
| `a4000-040`, `a1200-060`, `a4000-060` | Maximum-speed 040/060 functional diagnostics |
| `a4000-040-jit` | Unlimited 68040-NOMMU with JIT; stair-bug reproduction, not an accepted configuration |

All use AGA, 2 MB Chip and 8 MB Fast RAM, no MMU/FPU. JIT is disabled
except in the explicitly named reproduction configuration. Set `AMIGA_VIDEO=PAL|NTSC`;
`AMIGA_FAST_KB=2048|4096|8192` selects memory rejection or acceptance cases.
`AMIGA_CONFIG` takes precedence over `AMIGA_MODEL`. Do not override pinned machine
settings through `EXTRA_ARGS`.

`diag_run.sh` defaults to maximum-speed `a4000-030` and warp. On ARM it prefers
`FSUAE_ARM` when executable, unless `FSUAE` was explicitly set. Fixed-clock and
interactive runs retain the selected emulator. Installer/WHDLoad tests also prefer the
shared native ARM emulator when available. Matching clock rates are not proof of
identical emulator memory-system timing.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4 PROBES=1
GDBSCRIPT=runtime_status.gdb amiga/diag_run.sh 60
```

The seconds argument is a safety ceiling, never proof of success. `debug.sh` provides an
interactive debugger. `DIAG_RUN_DIR=.run-example` isolates native diagnostic disks,
saves, state and logs; `DEBUG_PORT` defaults to 24377 and must be unique for concurrent
runs. These directories under `amiga/` are ignored emulator working volumes. General
captures and host temporary artifacts belong in ignored `tmp/`; `tools/local_temp.py`
supplies that default to host tools. Do not delete local data or saves as part of source
cleanup.

Debug launchers mute host audio by default while Paula emulation continues. Use
`DIAG_AUDIO=1` and `EXTRA_ARGS=--warp_mode=0` for audible real-time diagnostics. For
timing comparisons, explicitly select `a1200-020` or `a4000-030-reference` and measure
guest ticks/fields, not host elapsed time. `runtime_status.gdb` reports named
loader/trap stops with segment and offset. A stopped emulator does not count as
successful gameplay.

## Static and Macintosh analysis

```sh
make host-tests
make trap-census
make m68k-sweep
make lowmem-scan
make entrypoints-check
make mac-trap-map
```

Original-byte analyses require the extracted resource fork and segments. Trap names are
generated from cxmon by `make tmp/trap_names.lua` (AmigaXDev's
`python3 -m amigaxdev.mac.gen_trap_names`, which accepts a local `mon_atraps.h` for offline
use). `disasm/symbols.csv` and `ghidra_scripts/entrypoints.csv` are curated; generated
disassembly stays local. Ghidra scripts use the shared installation through ignored
`tools/ghidra`. The Mac scripts are AmigaXDev's (`MacMarkEntries`, which reads this repo's
`ghidra_scripts/entrypoints.csv`, `MacApplyNames`, `MacDumpTraps`, `DumpCallGraph`,
`ExportListing`): start the headless analyzer from the repository root with
`-scriptPath "ghidra_scripts;$AMIGA_GHIDRA_SCRIPTS"`.

Use [mac-reference-loop.md](mac-reference-loop.md) for MAME setup, deterministic input
and frame/trap capture. Always pass headless video/window options and explicit local
cfg/nvram directories. Compare matching game state, not matching frame numbers. Do not
run Macintosh.js for the stair investigation.

## WHDLoad exception vectors

WHDLoad owns the real VBR table, which its MMU protects. The runtime installs
and restores Line-A at guest address `$28` when the resload binding is active;
the slave's `WHDLF_EmulLineA` forwards exceptions there. Native execution uses
the current OS VBR. Never write into WHDLoad's real VBR table.

## WHDLoad input ownership

The slave/runtime binding is a 16-byte `AITDWHDR` block, ABI version 2:
magic, version word, OS-return epoch word, and resload pointer. The slave
chains kickemu's switch callback, increments the epoch without using the
stack, and restores the original callback before unloading the executable.
The resload bridge preserves its results while reconciling input after a
changed epoch. Since physical releases during host OS ownership cannot reach
the game's CIA handler, it clears held keys, the Mac KeyMap, and stale queued
edges. Calls satisfied without an OS switch preserve input. Update both the
slave and executable together; mismatched ABI versions are rejected.

## Shared Macintosh helpers

Geometry, region, indexed copy/fill, GWorld and bitmap-font helpers come from
AmigaXDev’s canonical `mac-runtime` sources. Vendored copies are hash-pinned in
`manifest/shared-runtime.sha256` and checked before host tests and native builds.
Update the canonical source and install through AmigaXDev before updating consumers.

The loader’s big-endian word/longword accesses also use the canonical
`BigEndianMemory.h`; their 68020 instructions and unaligned-access contract are unchanged.

### RGB colour lookup

Each owned GWorld and window retains up to 256 RGB-to-index results in 2,070 bytes
of native storage (33,120 bytes for all sixteen slots). The key includes all six
RGB bytes, both table contents addresses and seeds, colour-table flags/size and
inverse-table resolution. Moved bodies or changed table versions discard entries;
port disposal and same-seed main-device inverse rebuilds invalidate explicitly.
As with QuickDraw and the CopyBits colour-map cache, an edit to table contents must
publish a new seed. No framebuffer is retained or compared.

Misses use the unchanged `GWorld8::colorIndex` collision-ring matcher. Port checks,
RGB/index field writes, overlap semantics, scratch registers and trap service
boundaries remain unchanged. `RGBCACHEVERIFY=1` independently computes every index
again, including assembly hits, and stops on any disagreement; use it for correctness,
never timings.

The RGB assembly entry uses MacEntry’s already-saved register image. It only handles
an unchanged, live 8-bit GWorld with a solid pattern and an exact cache hit, inside
an unfinished scene. Due VBL callbacks, pending work, song errors, streaming or
completed effects, partial RGB overlap and unsupported state return to the ordinary
quick handler before any mutation. The existing scene-owner stack stamps and
`(Dan2, $B46)` exception retain the publication boundary. `SCENEFRAMEVERIFY=1`
checks that claim with the independent frame walker on assembly hits too. Original
callbacks still run only at the usual safe return points, never from an interrupt.

### Solid particle pens

Zero-displacement solid Line/LineTo pens draw their clipped half-open rectangles
through `PenRect8`, without rebuilding rectangle records or looking up the pixel
handle size per dot. GWorld pixel capacity is refreshed alongside its heap-derived
addresses after memory changes and pixel locking, including in-place resizes.
The adapter retains its depth, pattern, visibility, signed-overflow and rectangular
region checks; unsupported thick strokes still stop explicitly.

`LineQuick.s` handles owned locked GWorld points inside an unfinished scene when no
services are due. It shares `QuickSceneGuard.inc` with the RGB entry, checks live
port/region/pattern data and bounds before writing, and changes only the saved D0
result. Misses tail-call the ordinary Line/LineTo handler. `SCENEFRAMEVERIFY=1`
also runs the independent frame-end check on this entry. Pixel dirtiness remains
coordinate-based and publication stays at the existing complete-frame boundary.

### Camera mask results

FramePoly and InsetRgn retain up to 32 successful geometry results in a shared
32 KiB FIFO byte arena (plus 260 bytes of metadata). Keys include the operation
and every byte of the input record, including its length and bounds; handle
addresses are never keys. Storage relocation, edits and arena reuse therefore
cannot return a stale shape. Oversized/truncated inputs cannot hit. Misses use
the unchanged polygon/region validators, including their named loud stops.
Only successful results enter the cache; region ownership, resizing and trap
register effects still execute on hits. This retains derived geometry only,
not game assets or framebuffer pixels; no shadow comparison computes dirty areas.

The shared `HeapResize.inc` merges only a newly split free tail with its next
free neighbour. It requires the existing no-adjacent-free-block heap invariant,
and preserves the previous layout, free-byte count and recovery paths. This
removes whole-zone scans from polygon growth, CloseRgn and InsetRgn resizing.

### Unattended hardware frame audit

For the debugger-free monster encounter diagnostic, clean-build with
`MONSTERAUDIT=1`; it enables `FRAMEAUDIT=1`, `INGAME=1` and `FIXEDRNG=1`.
The [performance workflow](performance.md#debugger-free-hardware-audit) covers
isolated preferences, emulator checks, hardware launch and report decoding.
Real-Amiga benchmarks are deferred; use emulator runs only to validate collection.

## WHDLoad code and DMA cache policy

The slave requests kickemu `CACHE`: Chip memory noncacheable, Fast/slave memory
copyback, both CPU caches enabled. User WHDLoad cache overrides remain effective.
Code publication uses Exec `CacheClearU`; kickemu routes its cache-control path
to `resload_FlushCache`. The initial CODE/A5/trap stubs are published before entry.
The original segment loader flushes after relocation and jump-table updates through
`FlushInstructionCache` (`$A0BD`); supported `HWPriv` flush selectors use the same
service. The executable Jnth resource is also flushed after MoveHHi.

CODE 1 installs three trap addresses at `(CODE 1, $43e–$4a8)` before writing the
LoadSeg, UnloadSeg and ExitToShell trampolines. The dispatcher therefore publishes
a newly installed entry once, immediately before its first call, after those writes.
Flushing only at SetTrapAddress is too early. Original instructions and registers
remain unchanged; repeated calls do not add a flush.

All Paula sample/stream buffers, bitplanes, copper lists and sprite buffers use
`MEMF_CHIP`, so their CPU writes are visible to DMA under this policy. Planar
synchronization drains the blitter before C2P or CPU reads reuse its destination.
Fast-memory chunky pixels and software blitter-queue entries are CPU-only. No
per-frame cache flush is needed. See [cache validation](testing.md#whdload-cache-validation)
for the emulator gate; hardware performance and corruption checks remain deferred.

## Plain-AmigaOS cache ownership

Direct launch requires the accelerator's matching 68040/68060 support library,
initialized by SetPatch, with instruction and data caches enabled. The executable
and its launch scripts do not write CACR or call CacheControl to select cache
policy. Modified code is published through Exec CacheClearU; the CPU library owns
the flush implementation and any transient cache-control operations it needs.
This is preservation of cache policy, not a claim that flushing never touches CACR.

The original CODE 1 loader can select a direct CACR fallback when the Macintosh
cache-flush service is absent. Our GetOSTrapAddress exposes `$A0BD`, distinct from
the unimplemented-trap entry, so the loader selects `(CODE 1, $26e)` and uses our
Exec-backed flush service instead. Native audit code only reads CACR through
Supervisor; hardware takeover/restoration does not change the cache policy.

The disposable emulator launchers boot a minimal Kickstart environment without
SetPatch or CPU libraries. They are functional fixtures, not the installed-system
cache/performance reference. In particular, a plain 030 run with CACR `$2001`
has its data cache disabled. Do not interpret it as a both-caches-enabled 040 run.
The [hardware audit](performance.md#debugger-free-hardware-audit) records raw CACR
before gameplay and after OS restoration; PERF.3 retains the physical-machine gate.
