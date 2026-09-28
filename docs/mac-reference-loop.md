# Macintosh reference

The unmodified original under MAME is the fidelity reference. ROMs, system
images, original files and captures stay local under ignored `ref/` and `tmp/`;
none is distributed.

## Local setup

`ref/mame/roms` holds the `mac2fdhd`, `nb_mdc48`, `nb_mdc824` and `adbmodem`
ROM sets, and `ref/mame/dl` the System 6.0.8 boot media, MacsBug and ResEdit
downloads, all carried over from the Vette! setup. Vette's prepared volume
(`~/Documents/Vette/ref/mame/hd/608_2GB_drive.hd`) is Vette-specific and was not
copied.

A reference volume for this game is still to be built in `ref/mame/hd/`. It needs
256 colors and at least 3 MB free for the application. Whether System 6.0.8 with
32-bit QuickDraw suffices or System 7 is required is not yet known. Install from
the HFS image inside the original archive, or copy the extracted files with
`hcopy -m`, which preserves both forks (see `tools/macbin.py`).

## Running without taking over the host screen

```sh
mkdir -p ref/mame/snap ref/mame/cfg ref/mame/nvram tmp
timeout -k 5 300 env SDL_VIDEODRIVER=dummy \
  mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
  -ramsize 8M -hard ref/mame/hd/<volume>.hd \
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
application to launch, and its Finder coordinates must be re-measured for the
new volume. `mac_launch.lua` launches and snapshots, `mame_snap.lua` takes
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
