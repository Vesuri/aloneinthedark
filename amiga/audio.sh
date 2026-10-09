#!/usr/bin/env bash
# Complete headless audio contracts; this is not listening/gameplay-route acceptance.
set -euo pipefail
cd "$(dirname "$0")/.."
source amiga/env.sh
export AMIGA_CONFIG="${AMIGA_CONFIG:-a4000-030-reference}"
export FSUAE="${FSUAE:-$HOME/.local/share/amiga/fs-uae-arm/fs-uae}"
export DEBUG_PORT="${DEBUG_PORT:-24391}"
export DIAG_RUN_DIR="${DIAG_RUN_DIR:-.run}"
MAME="${MAME:-mame}"
mac_disk="${AITD_AUDIO_MAC_DISK:-tmp/m4/sysbeep/mac.hd}"
[[ -f "$mac_disk" ]] || { echo 'AUDIO / set AITD_AUDIO_MAC_DISK to a private writable reference disk' >&2; exit 2; }
mkdir -p tmp/m4
capture=$(mktemp -d tmp/m4/audio-XXXXXX)
exec > >(tee "$capture/summary.log") 2>&1
printf 'AUDIO capture=%s config=%s\n' "$capture" "$AMIGA_CONFIG"
git rev-parse HEAD >"$capture/revision"
git diff --binary >"$capture/working.patch"
mkdir -p "$capture/mac-cfg" "$capture/mac-nvram" "$capture/mac-snap" tmp/m4/native-song
# Each invocation gets fresh native logs. Checkers require positive completion
# and consume the actual emulator exit code, never a previous PASS record.
run_native() {
 local label=$1 observer=$2 deadline=$3; shift 3
 current="$capture/$label"; mkdir -p "$current"
 printf 'AUDIO native %s\n' "$label"
 make -C amiga clean >"$current/build.log" 2>&1
 make -C amiga -j8 "$@" PROBES= >>"$current/build.log" 2>&1
 if GDBSCRIPT="$observer" amiga/diag_run.sh "$deadline" >"$current/run.log" 2>&1; then native_status=0; else native_status=$?; fi
 printf '%s\n' "$native_status" >"$current/exit-status"
 cp "amiga/$DIAG_RUN_DIR/gdb-out.log" "$current/capture.log"
 if [[ "$native_status" != 0 ]]; then tail -35 "$current/capture.log"; return "$native_status"; fi
}
run_mac() {
 local label=$1 script=$2; shift 2
 reference="$capture/$label"; mkdir -p "$reference"
 printf 'AUDIO original %s\n' "$label"
 if timeout -k 5 600 env SDL_VIDEODRIVER=dummy "$@" "$MAME" maciix \
   -rompath ref/mame/roms -nb9 mdc48 -ramsize 8M -hard "$mac_disk" \
   -video none -sound none -window -skip_gameinfo -nothrottle -debug -debugger none \
   -seconds_to_run 3600 -snapshot_directory "$capture/mac-snap" \
   -cfg_directory "$capture/mac-cfg" -nvram_directory "$capture/mac-nvram" \
   -autoboot_script "$script" >"$reference/run.log" 2>&1; then original_status=0; else original_status=$?; fi
 printf '%s\n' "$original_status" >"$reference/exit-status"
 if [[ "$original_status" != 0 ]]; then tail -25 "$reference/run.log"; return "$original_status"; fi
}
python3 tools/audio_reference_inputs.py "$capture/references"
python3 tools/survey_song_resources.py --output "$capture/decoded"
for song in 130 131 132 133 134 135 136 137; do
 if [[ -n "${AITD_AUDIO_SONG_REFERENCES:-}" ]]; then
  reference="$capture/song$song/mac"; mkdir -p "$reference"
  cp "$AITD_AUDIO_SONG_REFERENCES/song$song/mac/"{run.log,exit-status,song-live-initial-state.bin,song-live-final-state.bin} "$reference/"
  original_status=$(cat "$reference/exit-status")
  printf 'AUDIO retained original song%s from %s; revalidating all events
' "$song" "$AITD_AUDIO_SONG_REFERENCES"
 else
  run_mac "song$song/mac" tools/mac_audio_song.lua AITD_LIVE_SONG="$song" AITD_LIVE_FOLDER="$capture/song$song/mac"
 fi
 python3 tools/check_song_live.py "$song" "$reference/run.log" "$capture/decoded/song$song.log" --state "$reference/song-live-initial-state.bin" --status "$original_status"
 run_native "song$song/native" song_live.gdb 600 SONGPROBE=1 SONGPROBEID="$song" SONGHARDWARE=1
 cp tmp/m4/native-song/native-*.bin "$current/"
 python3 tools/check_song_live.py "$song" "$reference/run.log" "$capture/decoded/song$song.log" --state "$reference/song-live-initial-state.bin" --status "$original_status" --native "$current/capture.log" --native-folder "$current" --native-status "$native_status"
done
# These RAM-only reference fixtures retain their own recorded process statuses.
amiga/effect_loop_matrix.sh
for mode in loop0 loop1 loop3 loopnegative action17 action18 long; do
 mkdir -p "$capture/$mode"
 cp -R "tmp/m4/effects/$mode/native" "$capture/$mode/"
done
run_native slots effect_slots.gdb 180 EFFECTSLOTSPROBE=1 M5AUDIT=1
cp tmp/m4/effects/slots/native-chip-*.bin "$current/"
python3 tools/check_effect_slots.py tmp/m4/effects/slots --status "$(cat tmp/m4/effects/slots/exit-status)" --native "$current/capture.log" --native-status "$native_status"
run_native fraction effect_dma.gdb 180 EFFECTDMAPROBE=1
cp tmp/driver17-native-packet.bin tmp/m4/effects/fraction/native-packet.bin
cp tmp/driver17-native-sample.bin tmp/m4/effects/fraction/native-sample.bin
cp tmp/driver17-native-chip.bin tmp/m4/effects/fraction/native-chip.bin
cp tmp/m4/effects/fraction/native-*.bin "$current/"
python3 tools/check_effect_packet.py tmp/m4/effects/fraction --status "$(cat tmp/m4/effects/fraction/exit-status)" --native "$current/capture.log" --native-status "$native_status"
run_native sysbeep sysbeep.gdb 240 BEEPPROBE=1 M5AUDIT=1 SONGPROBEID=135
cp tmp/m4/sysbeep/native-*.bin "$current/"
python3 tools/check_sysbeep.py tmp/m4/sysbeep/mac.log "$current/capture.log" "$current" --original-status "$(cat tmp/m4/sysbeep/mac-exit-status)" --native-status "$native_status"
run_mac active-stop/mac tools/mac_driver22_active.lua AITD_DRIVER22_ACTIVE_DIR="$capture/active-stop/mac"
python3 tools/check_driver22_active.py "$reference/run.log" --folder "$reference" --status "$original_status"
run_native active-stop/native driver22_active.gdb 240 AUDIOSTOPPROBE=1 INTROSKIP=1
cp tmp/m4/driver22/native/*.bin "$current/"
python3 tools/check_driver22_active.py "$reference/run.log" --folder "$reference" --status "$original_status" --native "$current/capture.log" --native-folder "$current" --native-status "$native_status"
# Leave an ordinary build, not the last RAM/input fixture.
make -C amiga clean >"$capture/production-build.log" 2>&1
make -C amiga -j8 PROBES= >>"$capture/production-build.log" 2>&1
printf 'PASS audio regression: eight songs, interrupt timing/allocation, loop/long/fractional effects, replacement, SysBeep and active sound-off; headless contracts only\n'
