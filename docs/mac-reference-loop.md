# Macintosh reference

The unmodified original under MAME is the fidelity reference. ROMs, system
images, original files and captures stay local under ignored `ref/` and `tmp/`;
none is distributed.

## Local setup

`ref/mame/roms` holds the `mac2fdhd`, `nb_mdc48`, `nb_mdc824` and `adbmodem`
ROM sets, carried over from the Vette! setup; `maciix` uses the same ROM.
`ref/mame/dl` holds Steve Taylor's prepared System images from
<https://www.savagetaylor.com/downloads/downloads-macintosh/>, plus MacsBug and
ResEdit.

The game needs **System 7**, despite the manual's "System 6.0.7 or higher". It
calls `GetGWorldPixMap`, which does not exist in 32-Bit QuickDraw 1.2 under
System 6: there the call returns garbage (handle 7), and the game's slab loader
(Misc2+$0680) then `BlockMove`s graphics over its own loaded code and dies with
"illegal instruction", whichever screen size is chosen. Build the reference
volume from the System 7.5.5 drive image:

```sh
unzip -p ref/mame/dl/755_2GB_drive.zip > ref/mame/hd/aitd_755.hd
python3 tools/install_reference_volume.py tmp/AloneInTheDark.img_.sit \
  ref/mame/hd/aitd_755.hd
```

The tool installs the release's folder, with both forks of every file, on the
volume's desktop. Use `maciix` (68030) with 8 MB. The screen must be set to 256
colours (Control Panels > Monitors). That setting lives in PRAM, which MAME
keeps per machine in `ref/mame/nvram/`, so it is set once. `ref/mame/cfg/maciix.cfg`
enables the full emulated keyboard; Scroll Lock (Fn+Delete on a Mac keyboard)
toggles MAME's UI keys.

## Playing interactively

```sh
mame maciix -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -window -skip_gameinfo \
  -cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
  -snapshot_directory ref/mame/snap
```

Open "Alone in the Dark" on the desktop, double-click "Alone In The Dark" and
choose 320×200, the mode the port reproduces.

## Running without taking over the host screen

```sh
mkdir -p ref/mame/snap ref/mame/cfg ref/mame/nvram tmp
timeout -k 5 300 env SDL_VIDEODRIVER=dummy \
  mame maciix -rompath ref/mame/roms -nb9 mdc48 \
  -ramsize 8M -hard ref/mame/hd/aitd_755.hd \
  -video none -sound none -window -skip_gameinfo -nothrottle \
  -seconds_to_run 120 -snapshot_directory ref/mame/snap \
  -cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
  -autoboot_script tools/mac_launch.lua
```

`-video none` alone is insufficient to prevent a fullscreen window. Explicit
cfg/nvram directories also prevent state leaking into the repository. Terminate
only the process belonging to the current run.

## Automation

`mame_mac_input.lua` is the shared launch/input library; `AITD_MAC_APP` names the
application to launch. On the 7.5.5 volume the desktop folder opens at
(598,98) and the application icon is at (166,90); Finder menus do not yet
respond to its press-drag, but double-clicks do. `mac_launch.lua` launches and snapshots, `mame_snap.lua` takes
frame-numbered snapshots, and `mac_probe_fb.lua` with `fb_to_png.py` dumps and
verifies the live 8-bit framebuffer, logical CLUT and video palette.

## Address and timing cautions

- Code identity is (live segment, offset), not a raw address saved after shutdown.
- Mask handles to 24 bits when the reference system runs in 24-bit addressing mode.
- Macintosh ticks advance at 60 Hz. MAME `-nothrottle` changes host execution
  speed, not emulated-time quantities.
- The original's storeroom-stairs bug is timing-dependent (see
  [install-original-data.md](install-original-data.md)); compare by game state.

## Runtime trap evidence

Generate the original-byte metadata and use the debugger-enabled reference run:

```sh
make mac-trap-map
timeout -k 5 600 env SDL_VIDEODRIVER=dummy \
  mame maciix -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 360 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_traps.lua > tmp/mac-traps.log 2>&1
python3 tools/mac_trap_report.py tmp/mac-traps.log
```

All metadata, logs, screenshots and saves stay local. The script uses the first
save slot on the disposable reference volume. `AITD_MAC_SCENARIO` can select a
local diagnostic scenario; it is not a replacement for the acceptance route.
A normal emulator exit is insufficient: require the report's PASS, every state
proof, and visual inspection of the named `m0.2-*.png` captures. A timeout or
`FAIL mac-trap-session` is a failure.

System 7.5.5 replaces the ROM Line-A entry with RAM code at `$DD60`. The logger
checks `2F0A2F02246F000A` before installing a debugger execution breakpoint;
ROM read taps miss application execution on this volume. It records only while
`CurApName` is exactly `Alone In The Dark`. Every trap record contains the live
jump-table targets. The report masks tagged pointers to 24 bits and verifies the
original opcode at the resolved segment offset; unattributed OS/driver calls
remain separate. Trap return probes check original trap bytes before installing.
MDRV probes check the original `movea.l -$6AC(a5),a0; jsr (a0)` and stack cleanup,
so initialization cannot be missed by frame polling of the driver pointer.
These are debugger probes, not modifications of the original game.

The route checks rendered states from `screen:pixels()` against native captures.
On MAME 0.289, `screen:pixel(x,y)` did not agree with the packed bitmap or PNG;
the packed bitmap did agree byte for byte at the probe locations. Gameplay input
probes confirm writes to the original key globals, but modal menus also need
rendered-state checks. In particular, a consumed ESC event does not prove the
menu remained open. The script fails with a named state and screenshot when
it cannot verify a transition.

### M0.2 acceptance (MAME 0.289, System 7.5.5)

The completed local `tmp/m0.2-save-proof.log` run reached 320×200, intro,
Carnby's first room, ESC save, Command-S, Command-O/load, and Finder after quit.
The `m0log` slot and loaded attic were visually verified. The report found
273,416 direct CODE calls at 632 sites, **174 distinct words, all within the
243-word live census**, 292,604 return records, 4,458 MDRV calls and 292 text
records. The session ended normally at 182 emulated seconds; no timeout passed.
Host fixtures, census and low-memory scans pass. No Amiga runtime changed.

- **Pack3:** zero direct CODE `$A9EA` calls on this route. This does not prove
  unreachable error paths cannot call it.
- **Menus/keys:** ESC opens the engine's Return/Save/Load/Music/Sound/Details/Quit
  screen. Command-S and Command-O open its save/load screens too. P displays
  "The game is paused!" and resumes; S and M produce sound/music feedback and
  change the engine menu's settings. These observations do not remove D5's
  requirement to handle any other oversized dialogs that are actually reached.
- **Fonts:** Times ID 20, size 14 for credits, menus, narrative, save/load labels
  and S/M feedback; Times 36 for pause. The size chooser uses system font 0,
  size 12 for controls, with default-size (0) prompt/menu/title records.
  Separate inventory exploration also observed Times 14 for action labels.
- **LISTSAMP:** yes. Core+$17FC calls selector 17 with a packet containing the
  sample pointer, length and `$1F400000` (8000 Hz plus flags). The first packet
  has length 30,783. Its first 32 sample bytes exactly match decoded LISTSAMP
  entry 6 at offset 44. The archive entry is at 64,226, implode-compressed
  24,434 → 30,834 bytes. Comparison used the local FITD `PAK_explode` reference;
  neither its output nor the original sample is committed. Another packet has
  length 10,199. Core+$17C8 passes the same packet to selector 20.

Observed MDRV selectors (decimal); offsets include the CODE header. Pointer
addresses vary by load, so the raw log additionally retains their first words.
The table describes arguments and timing without guessing undocumented semantics.

| Selector | Core call offset(s) | Argument | Observed timing |
| --- | --- | --- | --- |
| 21 | `$1D46` | Init packet, first words `$00060002,$00020001,$00050755` | Startup, before chooser/intro |
| 24 | `$1D60` | `$10B` | Startup |
| 17 / 20 | `$17FC` / `$17C8` | Effect packet above | Logo/intro effects; 20 repeatedly between 17 calls |
| 22 | `$1A74` | No second argument | Startup, scene transitions, toggles and quit |
| 15 | `$0FC8` | 0 | Narrative/gameplay music transitions and reload |
| 13 | `$137E` | 0 | Same transitions |
| 0 | `$138C` | `$87` or `$89` | Narrative/attic music, toggle-on and reload |
| 4 | `$145C,$1FC8` | No second argument | Repeated during gameplay, menus, save/load and pause |
| 5 / 7 | `$1400` / `$140C` | No second argument | Transitions, toggle-off, reload and quit |
| 8 | `$1DCC` | No second argument | Quit |

The caller's checked `ADDQ #8,SP` versus `ADDQ #4,SP` distinguishes two arguments
from one; an incidental stack word is never reported as a second argument.
The local report keeps per-phase counts and selector arguments; the raw log
also retains trap arguments and return values.

## 8-bit framebuffer proof (M0.5)

Run the same headless MAME command without debugger logging, with
`-autoboot_script tools/mac_probe_fb.lua`, `-seconds_to_run 120` and a 180-second
host bound. The default output prefix is `ref/mame/snap/fb`; `AITD_FB_OUT` can
change it. The script waits for game palette activation, then captures after
900 fields (the measured Infogrames logo). `AITD_FB_DELAY` and `AITD_FB_COUNT`
select diagnostic capture intervals/counts; frame timing is not itself a pass.
Require `FRAMEBUFFER_CAPTURE` with no `FAIL framebuffer` or timeout in the run
log, inspect the new PNG, and require the converter's comparison result:

```sh
python3 tools/fb_to_png.py --bpp 8 \
  --resource 'tmp/runtime-data/Alone In The Dark' \
  --hardware-clut ref/mame/snap/fb-hardware.clut \
  ref/mame/snap/fb.raw ref/mame/snap/fb.clut 640 480 640 \
  ref/mame/snap/fb-rendered.png ref/mame/snap/fb-reference.png
```

The default remains 4 bpp for older captures; `--bpp 8` uses one byte per pixel.
Stride, padding, palette size and data size are checked; any pixel mismatch
exits nonzero. `make host-tests` covers both depths and invalid geometry.

The accepted original Infogrames capture (`m05-final`, frame 3778, MAME 0.289)
has screen base `$F9000A00`, 640×480×8, rowBytes 640, and a 256-entry logical
CLUT. Handle/master pointers are masked to 24 bits; the NuBus framebuffer base
must retain its high byte. The rendered PNG matches the MAME snapshot exactly:
**0 differing pixels of 307,200**. The window content in this live capture is
(160,150)–(480,350), after original window positioning; the WIND resource's
initial bounds alone are not the final viewport.

Two palette layers must remain distinct. The logical GDevice CLUT contains the
Mac RGB16 requests. The mdc48 device palette contains the colours actually sent
to the screen (including the reference's colour transfer). Using the logical
CLUT's high bytes directly is visibly darker and fails the exact comparison;
using `pen_color` from the read-only video palette gives the exact match.
No guessed gamma exponent is used.

253 logical RGB16 entries equal original `clut` 128 at their original indices.
Three duplicate black/white slots retain values from the preceding MacPlay
logo: index 1 `$F7F7/$F7F7/$F7F7`, index 15 `$6363/$6363/$6363`, index 191
`$0808/$1818/$2121`. The original has black at 1/191 and white at 15, duplicated
at the endpoints. The converter reports these three differences explicitly,
checks their original resource values, and rejects differences at all other
indices. Palette Manager allocation details and the display colour transfer
are carried into M2.7/M2.7a; the capture does not justify replacing those slots
with guessed colours.


File Manager parameter-block evidence is checked separately with
`python3 tools/check_file_reference.py <log>`; see [file-manager.md](file-manager.md).
The logger includes HFSDispatch selectors and SetFPos as well as the basic
file calls, and records 80 parameter-block bytes on original-code returns.


## Debugger literal discipline

MAME expressions resolve bare `a0`–`a7` and `d0`–`d7` as registers. Generated
hexadecimal operands must use `0x` prefixes, including byte strings supplied
through `%s`. Diagnostic printf formats are separate from operand formatting.
`tools/check_mame_literals.py`, run by `make host-tests`, scans all 41 maintained
Mac/MAME Lua scripts and rejects unprefixed generated numeric/byte operands.
Its rejection tests include a reverted dialog-dump offset, uppercase formats
and decimal formatting after a hex prefix. The two explicit non-operand `%x`
uses are a host map key and the Lua input-count pattern.

The M2.1c3c2c5b2r audit changed 36 emitters. The impact inventory is:

| Emitter group | Previous exposure and accepted evidence |
| --- | --- |
| Hidden constructor/movement, 172-byte rounded record dump | Offsets $A0/$A4 read registers. Corrected captures supersede the old tail bytes; editField=-1 is now implemented and paired. |
| Menu/text, 256-byte dump | $A0/$A4/$D0/$D4 changed only padding. Across all 33 original calls, menu bodies are at most 97 bytes and text at most 30; every semantic byte is unchanged in the fresh capture and still pairs with native records. |
| SANE fixture byte writer | Hex byte strings could collide with registers. Every one of 41 fixture source/destination inputs is now read back exactly before execution, then results, guards, stack and FPState are checked. Historical captures without input readback no longer satisfy this checker. |
| Main device, device selection, depth, world and SANE-position dumps | Maximum rounded record is 108 bytes, below the first ambiguous offset $A0. CLUT payloads use direct `save`, not generated per-word offsets. |
| Segment bases and general trap logger | Only the first jump entry per segment is emitted. All 12 actual base/entry operands avoid register aliases; parameter/text/name dumps use offsets below $A0. The logger never emits all 468 jump slots. |
| File/resource fixtures and input probes | Parameter-block loops stay below $A0; larger scratch offsets start at $100. Text is length-prefixed ASCII. Fixture stages/IDs/selectors, full addresses and payload words do not collide with register names on the accepted routes; large resource-stage sequences already used prefixes. Remaining concatenated scratch slots are $300/$304 and payload words are eight hex digits. Prefixes now protect future values as well. |

Fresh logs `tmp/m2-literals-hidden_dialog-reference.log`,
`tmp/m2-literals-hidden_move-reference.log`, `tmp/m2-literals-menu-reference.log`
and `tmp/m2-literals-sane-fixtures.log` all completed normally and pass their
checkers. Constructor/movement/menu records pair with the existing accepted
native build; the exact-rational host oracle includes all 41 SANE fixtures.
The menu log also has `PASS MAME script syntax files=41`, from compiling every
maintained Lua source with MAME's `loadfile` before starting the observer.
Generate that wrapper with:

```sh
python3 tools/check_mame_literals.py --syntax-wrapper tmp/mame-literals-syntax.lua
# Use the standard headless command with -autoboot_script tmp/mame-literals-syntax.lua.
```

The full host suite passes. This is a reference-tool correction; native code,
original instructions, resource inputs and rendering behavior are unchanged.
