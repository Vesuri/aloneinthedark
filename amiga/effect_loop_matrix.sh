#!/usr/bin/env bash
# Native isolated loop fixtures paired with retained original Mac captures.
set -euo pipefail
cd "$(dirname "$0")/.."
source amiga/env.sh
export AMIGA_CONFIG="${AMIGA_CONFIG:-a4000-030-reference}"
export FSUAE="${FSUAE:-$HOME/.local/share/amiga/fs-uae-arm/fs-uae}"
export DEBUG_PORT="${DEBUG_PORT:-24391}"
export DIAG_RUN_DIR="${DIAG_RUN_DIR:-.run-m4-fraction}"
export GDBSCRIPT=effect_loop.gdb
for fixture_case in "${@:-loop3 loop0 loop1 loopnegative action18 action17 long}"; do
 # Default expansion is split explicitly below; positional cases stay intact.
 for mode in $fixture_case; do
  action=0
  long=0
  export GDBSCRIPT=effect_loop.gdb
  case "$mode" in loop3) count=3;; loop0) count=0;; loop1) count=1;; loopnegative) count=-1;; long) count=0; long=1;; action17|action18) count=-1; action=${mode#action}; export GDBSCRIPT=effect_loop_action.gdb;; *) echo "Unknown loop fixture: $mode" >&2; exit 2;; esac
  original="tmp/m4/effects/$mode"
  capture="$original/native"
  mkdir -p "$capture" tmp/m4/effects/stream
  original_status=$(cat "$original/exit-status")
  if [[ "$action" == 0 ]]; then
   python3 tools/check_effect_packet.py "$original" --status "$original_status"
  else
   python3 tools/check_effect_loop_action.py "$original" --status "$original_status"
  fi
  make -C amiga clean >"$capture/build.log" 2>&1
  make -C amiga -j8 EFFECTLONGPROBE="$long" EFFECTLOOPPROBE=1 EFFECTLOOPCOUNT="$count" EFFECTLOOPACTION="$action" PROBES= >>"$capture/build.log" 2>&1
  if amiga/diag_run.sh 180 >"$capture/run.log" 2>&1; then result=0; else result=$?; fi
  printf '%s\n' "$result" >"$capture/exit-status"
  cp "amiga/$DIAG_RUN_DIR/gdb-out.log" "$capture/native-capture.log"
  if [[ "$result" != 0 ]]; then tail -30 "$capture/native-capture.log"; exit "$result"; fi
  if [[ "$action" != 0 ]]; then
   if [[ "$action" == 17 ]]; then cp tmp/m4/effects/stream/replacement-pcm.bin "$original/native-pcm.bin"; fi
   python3 tools/check_effect_loop_action.py "$original" --status "$original_status" --native "$capture/native-capture.log" --native-status "$result"
   continue
  fi
  cp tmp/m4/effects/stream/native-{trace,pcm}.bin "$capture/"
  cp tmp/driver17-native-packet.bin "$capture/native-packet.bin"
  cp tmp/driver17-native-sample.bin "$capture/native-sample.bin"
  python3 tools/check_effect_stream.py "$original" "$capture" --status "$original_status" --native-status "$result"
 done
done
