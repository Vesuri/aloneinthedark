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
verifies the live framebuffer and CLUT. Both were written for Vette's 4-bit
display and need an 8-bit path.

## Address and timing cautions

- Code identity is (live segment, offset), not a raw address saved after shutdown.
- Mask handles to 24 bits when the reference system runs in 24-bit addressing mode.
- Macintosh ticks advance at 60 Hz. MAME `-nothrottle` changes host execution
  speed, not emulated-time quantities.
- The original's storeroom-stairs bug is timing-dependent (see
  [install-original-data.md](install-original-data.md)); compare by game state.
