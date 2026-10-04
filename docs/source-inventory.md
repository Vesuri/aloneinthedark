# Source inventory

The application is `Alone In The Dark`, type/creator `APPL`/`AITD`, `vers` 1.0:
"Alone In The Dark 1.0 ©1992 I•Motion/Infogrames, ©1994 Interplay
Productions." Its resource fork was last modified on 9 November 1994. `SIZE`
asks for 3,145,728 bytes preferred and minimum (flags `$58C0`). The credits
(`TEXT` 1234) name Robert Barris as lead Macintosh programmer.

## Application resources

| Type | Count | Notes |
| --- | --- | --- |
| `CODE` | 14 | CODE 0 jump table plus 13 segments; see [static-map.md](static-map.md) |
| `CREL` | 10 | Per-segment relocation lists for CODE 3–10, 12, 13 |
| `DATA` / `ZERO` / `DREL` | 1 each | Initial A5 data, zero-fill description and data relocations (ID 0) |
| `PICT` | 25 | Intro frames, MacPlay logo, pause and book arrows |
| `clut` | 3 | 256-entry "Game CLUT", its older version and the MacPlay logo CLUT |
| `WIND` / `wctb` | 6 / 7 | Main window, 2× window, hidden-background variants, about |
| `DLOG` / `DITL` / `ALRT` | 7 / 10 / 2 | Screen-size/monitor/error dialogs plus unobserved new-game, save-warning and castle-design templates; reached new-game/save/load UI is engine-drawn ([verification](game-interfaces.md)) |
| `MENU` | 4 | Apple, File, Edit, Options |
| `snd ` | 51 | 897,891 bytes of sampled sound and instruments |
| `MIDI` / `SONG` / `INST` / `MDRV` / `SMOD` | 8 / 8 / 20 / 1 / 4 | Halestorm SoundMusicSys: songs, instruments, the driver and sound modifiers (below) |
| `slab` / `stab` | 1 / 1 | 8-bit image data (28,672 bytes) and its bounds table, copied into a GWorld by Misc2+$055C |
| `CURS`, `STR `, `STR#`, `STRS`, icons, `TMPL`, `mctb` | — | UI support |

The game world (rooms, cameras, bodies, animations, scripts, samples and music
tracks) is in the Infogrames `.PAK` files in `Alone Data`, read through the
File Manager rather than the Resource Manager. Their container format is not
documented here yet.

## Music driver

`MDRV` 11 "MIDI Synth 3.32 9/10/93" is Halestorm SoundMusicSys ("Copyright
1989-1993 by HALESTORM Incorporated" in the unpacked image). It is stored
encrypted (from byte 7: `out = c ^ (s >> 8)`, `s = ((s + c) * $CE6D + $58BF)`
mod 2^16, seed $DCE5) and LZSS-compressed (first long = unpacked size 29,256;
4 KB window). Core+$10CC loads, decrypts and unpacks it; the entry pointer is
kept at A5−$6AC and called as `D0 = entry(selector, arg)`. With Sound Manager
3 it mixes 8-bit mono at 22,254.5 Hz into two 370-byte `SndPlayDoubleBuffer`
buffers; without it, it drives the Mac sound hardware directly. `SMOD` 0–3 are
plain 68k code it calls.

## Build toolchain

THINK C, far model: CODE 1 is its runtime (`DATA`/`ZERO`/`DREL` expansion,
`CREL`-applying `_LoadSeg` patch, 32-bit multiply/divide helpers) and Misc3
holds its ANSI/unix I/O library (`open`/`read`/`lseek`/`close` at jump-table
entries 95–99). See [static-map.md](static-map.md).
