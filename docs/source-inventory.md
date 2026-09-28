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
| `DLOG` / `DITL` / `ALRT` | 7 / 10 / 2 | New game, load/save, screen-size dialog, "No good monitors" |
| `MENU` | 4 | Apple, File, Edit, Options |
| `snd ` | 51 | 897,891 bytes of sampled sound and instruments |
| `MIDI` / `SONG` / `INST` / `MDRV` / `SMOD` | 8 / 8 / 20 / 1 / 4 | "MIDI Synth 3.32" music driver data and Halestorm-style songs |
| `slab` / `stab` | 1 / 1 | 28,672 / 48 bytes; purpose not yet decoded |
| `CURS`, `STR `, `STR#`, `STRS`, icons, `TMPL`, `mctb` | — | UI support |

The game world (rooms, cameras, bodies, animations, scripts, samples and music
tracks) is in the Infogrames `.PAK` files in `Alone Data`, read through the
File Manager rather than the Resource Manager. Their container format is not
documented here yet.

## Build toolchain [inference]

`DATA`/`ZERO`/`DREL` plus per-segment `CREL`, and segment headers whose bit 15
marks exactly the CREL segments, match the THINK C / Symantec C++ far-model
application layout. Core begins with `CMPA.L CurrentA5,A5`. Confirm the
toolchain from the startup code in CODE 1 before relying on it.
