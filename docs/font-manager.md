# Font Manager

## GetFNum reference contract

The original Dan1 calls at +$0012 and +$0038 request the Pascal string `Times`
and write family ID 20. Both preserve D0, pop eight argument bytes and leave
ResErr/MemErr zero in this startup context. The second call follows the original
screen-size dialog; choosing 320×200 is required to reach it. No original code
or game state is patched by the original-call observer.

`tools/mac_font_lookup.lua` catches the verified System 7.5.5 Line-A dispatcher
and attributes calls through the live Dan1 jump-table entry. It records the
name bytes, instruction after each trap, output pointer, D0 and stack. The host
checker verifies the original Dan1 routine bytes independently. Frame callbacks
alone miss the early first call and are not sufficient evidence.

The separate `AITD_FONT_FIXTURE=1` diagnostic replays GetFNum in scratch stack
memory after the first original return. These calls measure the service contract;
they do not prove original startup progress. Every call starts with D0=$12345678,
ResErr=$8888, MemErr=$7777 and a $CCCC result surrounded by $ABCD/$DCBA guards.
All eight preserve D0 and both guards and pop exactly eight bytes.

| Name | Result | ResErr | MemErr |
| --- | --- | --- | --- |
| Times, times, TIMES, tImEs | 20 | 0 | $7777 unchanged |
| AITD Missing Font | 0 | -192 | 0 |
| empty string | 0 | -192 | $7777 unchanged |
| Times followed by space | 0 | -192 | 0 |
| space followed by Times | 0 | -192 | 0 |

These are measured names, not a complete international name-collation contract.
The error-global effects are observed System 7.5.5 behavior for these cases.
A matching ID alone is not a font implementation: the native trap still needs
a validated port-owned font definition in the overlay. Full text drawing and
rendered-font acceptance remain M2.9.

The independent M2.1c3a reference prerequisite passes both bounded captures
with process status zero and the full host suite. Native implementation is still
M2.1c3 at the top of the queue; production still stops at GetFNum. No runtime
code changed, so native regression results from the preceding checkpoint are
unchanged, not newly rerun.

## Reproduction

Run each mode sequentially, after sourcing `amiga/env.sh`:

```sh
AITD_FONT_FIXTURE=0 SDL_VIDEODRIVER=dummy timeout -k 5 90 mame maciix \
  -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M \
  -hard ref/mame/hd/aitd_755.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 180 \
  -snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
  -nvram_directory ref/mame/nvram -debug -debugger none -oslog \
  -autoboot_script tools/mac_font_lookup.lua >tmp/font-original.log 2>&1
font_status=$?
python3 tools/check_font_lookup.py tmp/font-original.log --status "$font_status"
```

Repeat with `AITD_FONT_FIXTURE=1`, a separate log and checker `--fixture`.
The checker requires normal process exit and exactly one positive completion,
rejects incomplete/duplicate/reordered calls, verifies stack/results and D0,
and checks original bytes. Its negative fixtures run in `make host-tests`.
Timeouts and diagnostic wait snapshots are failures. Internal MAME snapshots
are local diagnostics and do not satisfy deferred Amiga rendered-video checks.
