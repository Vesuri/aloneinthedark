#!/usr/bin/env bash
# Run a bounded GDB observer. Timeout returns 124, even if interrupting GDB
# produces diagnostic output; only normal observer completion can return zero.
set -euo pipefail
cd "$(dirname "$0")"
. "${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}"
. ./stage_original_data.sh
. ./config.sh || exit 1
FSUAE="${FSUAE:-fs-uae}"
GDB="${GDB:-m68k-amiga-elf-gdb}"
ROM="${KICKSTART:-$HOME/Documents/RetroPie/BIOS/kick31.rom}"
DELAY="${1:-14}"
[[ "$DELAY" =~ ^[1-9][0-9]*$ ]] || { echo 'DIAG / INVALID DEADLINE' >&2; exit 2; }
GDB_PID=
cleanup() {
  if [[ -n "$GDB_PID" ]]; then
    kill -9 "$GDB_PID" 2>/dev/null || true
    wait "$GDB_PID" 2>/dev/null || true
  fi
  fsuae_stop
  if [[ -n "${FSUAE_PID:-}" ]]; then wait "$FSUAE_PID" 2>/dev/null || true; fi
  FSUAE_PID=
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Extra diagnostic options, such as --warp_mode=1, precede pinned machine flags.
EXTRA_ARGS="${EXTRA_ARGS:-}"

RUN=.run; DH0="$RUN/dh0"; DH1="$RUN/dh1"; GDBHOME="$RUN/gdbhome"
mkdir -p "$DH0/s" "$DH1" "$RUN/state" "$RUN/logs" "$GDBHOME"
printf 'cd dh1:\nAlone\n' > "$DH0/s/startup-sequence"
cp -f out/Alone.exe "$DH1/Alone"
stage_aitd_original_data "$DH1"
case "${GDBSCRIPT:-runtime_status.gdb}" in
  apple_events.gdb|font_metrics.gdb|choice_services.gdb|resource_read.gdb|font_lookup.gdb|driver_startup.gdb|menu_records.gdb|device_startup.gdb|setdepth.gdb|hidden_move.gdb|sane.gdb|main_device.gdb|hidden_dialog.gdb|getgworld.gdb|identity.gdb|original_startup.gdb|file_catalog.gdb)
    python3 ../tools/check_startup_prefs.py --folder "$DH1/prefs" --gdb "$RUN/startup-state.gdb"
    ;;
esac
rm -f "$RUN"/state/*.uss
: > "$RUN/gdb-out.log"

fsuae_claim_port
"$FSUAE" \
  $EXTRA_ARGS "${AITD_MACHINE_ARGS[@]}" \
  --logs_dir="$PWD/$RUN/logs" --kickstart_file="$ROM" \
  --hard_drive_0="$DH0" --hard_drive_1="$DH1" \
  --joystick_port_0=mouse --joystick_port_1=nothing \
  --full_keyboard=1 \
  --keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down \
  --keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right \
  --automatic_input_grab=0 --fullscreen=0 --window_width=720 --window_height=568 \
  --remote_debugger=20 --remote_debugger_port="$DEBUG_PORT" --remote_debugger_trigger=Alone \
  --ntsc_mode=0 --state_dir="$RUN/state" > "$RUN/fsuae-dbg.log" 2>&1 &
FSUAE_PID=$!
fsuae_track "$FSUAE_PID"
echo "FS-UAE pid=$FSUAE_PID; waiting for stub..."
for i in $(seq 1 60); do
  kill -0 "$FSUAE_PID" 2>/dev/null || { echo "FS-UAE exited early; see $RUN/fsuae-dbg.log"; exit 1; }
  lsof -nP -iTCP:"$DEBUG_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  sleep 1
done

lsof -nP -iTCP:"$DEBUG_PORT" -sTCP:LISTEN >/dev/null 2>&1 || {
  echo 'DIAG / DEBUG STUB TIMEOUT' >&2; exit 124
}

cat > "$RUN/connect.gdb" <<EOF
set pagination off
set confirm off
set remotetimeout 90
target remote 127.0.0.1:$DEBUG_PORT
# CODE segments are disk-loaded during PlatformAmiga startup.  Pause once at
# MacLoader::run, after prepareResourceForks has populated s_segments, before
# sourcing observers whose breakpoint expressions use those resident bases.
tbreak ${GDB_ENTRY:-MacLoader::run}
commands
  silent
end
continue
EOF

env HOME="$GDBHOME" XDG_CACHE_HOME="$GDBHOME" \
  "$GDB" -q -l 10 -x "$RUN/connect.gdb" -x "${GDBSCRIPT:-runtime_status.gdb}" out/Alone.elf \
  > "$RUN/gdb-out.log" 2>&1 &
GDB_PID=$!
echo "gdb pid=$GDB_PID; running for ${DELAY}s..."
# Finish immediately when an event-driven gdb script (such as gameplay_smoke.gdb)
# prints its result and exits; snapshot/profiling scripts still run until the
# wall-time ceiling and receive SIGINT below.
for i in $(seq 1 "$DELAY"); do
  kill -0 "$GDB_PID" 2>/dev/null || break
  sleep 1
done
status=0
if kill -0 "$GDB_PID" 2>/dev/null; then
  echo 'DIAG / GDB TIMEOUT' >&2
  status=124
  kill -INT "$GDB_PID" 2>/dev/null || true
  # Allow a short diagnostic flush; a record after this point cannot pass.
  for i in $(seq 1 5); do kill -0 "$GDB_PID" 2>/dev/null || break; sleep 1; done
  kill -9 "$GDB_PID" 2>/dev/null || true
  wait "$GDB_PID" 2>/dev/null || true
else
  wait "$GDB_PID" || status=$?
fi
GDB_PID=
cleanup
echo "=== gdb output (filtered) ==="
# Preserve the observer/timeout exit status even when the filtered log is empty.
grep -v "Internal error: pc" "$RUN/gdb-out.log" | grep -vE "^warning:" | tail -"${GDBTAIL:-40}" || true
exit "$status"
