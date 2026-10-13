#!/usr/bin/env bash
# Debugger-free emulator smoke test for a previously built MONSTERAUDIT=1 binary.
set -euo pipefail
cd "$(dirname "$0")"
RUN=.run-monster-audit
FSUAE_RUN=$RUN
. ./fsuae.sh
. ./stage_original_data.sh
AMIGA_CONFIG=${AMIGA_CONFIG:-a4000-030}
. ./config.sh
if [[ -z "${FSUAE:-}" && -x "$FSUAE_ARM" && "$AMIGA_CONFIG" == a4000-030 ]]; then FSUAE=$FSUAE_ARM; fi
deadline=${1:-600}
[[ "$deadline" =~ ^[1-9][0-9]*$ ]] || exit 2
trap 'fsuae_stop' EXIT
fsuae_stop_previous
mkdir -p "$RUN/dh0/s" "$RUN/dh1" "$RUN/state" "$RUN/logs"
cp out/AloneInTheDark.exe "$RUN/dh1/AloneInTheDark"
stage_aitd_original_data "$RUN/dh1"
# First-launch preference creation is a different startup path. Match PERF.2's
# existing default preferences; this directory belongs only to the fixture.
if [[ ! -e "$RUN/dh1/prefs" ]]; then
 python3 ../tools/check_startup_prefs.py --prepare --folder "$RUN/dh1/prefs"
fi
PYTHONPATH=../tools python3 -c 'import sys;from pathlib import Path;from check_startup_prefs import state;assert state(Path(sys.argv[1])), "missing preferences"' "$RUN/dh1/prefs"
rm -f "$RUN/dh1/monster-amigaos.bin" "$RUN/dh0/audit-returned"
printf 'Stack 4096\ncd dh1:\nAloneInTheDark >DH0:audit-result\nEcho returned >DH0:audit-returned\n' > "$RUN/dh0/s/startup-sequence"
SOUND=1 DEBUG=0 DETERMINISTIC=1 WARP=1 NTSC=$aitd_ntsc
EXTRA_ARGS=${EXTRA_ARGS:---warp_mode=1}
fsuae_options
FSUAE_LOG="$RUN/emulator.log" fsuae_launch "${AITD_MACHINE_ARGS[@]}" \
 --kickstart_file="$KICKSTART" --hard_drive_0="$RUN/dh0" --hard_drive_1="$RUN/dh1" \
 --joystick_port_0=mouse --joystick_port_1=nothing --automatic_input_grab=0 \
 --state_dir="$RUN/state" --logs_dir="$PWD/$RUN/logs"
for ((i=0;i<deadline;i++)); do
 if [[ -f "$RUN/dh0/audit-returned" ]]; then
  cat "$RUN/dh0/audit-result"
  grep -qx "Monster audit complete; report saved beside the executable." "$RUN/dh0/audit-result"
  python3 ../tools/check_monster_audit.py "$RUN/dh1/monster-amigaos.bin"
  exit
 fi
 kill -0 "$FSUAE_PID" 2>/dev/null || { echo 'FAIL emulator exited'; exit 1; }
 sleep 1
done
echo 'FAIL monster audit timeout' >&2
exit 124
