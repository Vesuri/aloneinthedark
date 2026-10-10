#!/usr/bin/env bash
# Run a bounded GDB observer. Timeout returns 124, even if interrupting GDB
# produces diagnostic output; only normal observer completion can return zero.
set -euo pipefail
cd "$(dirname "$0")"
# Keep the shared helper's PID record with this diagnostic's private disks/logs.
# Different diagnostic directories must not reclaim one another's live emulator.
RUN="${DIAG_RUN_DIR:-.run}"
[[ "$RUN" =~ ^\.run(-[a-z0-9][a-z0-9_-]*)?$ ]] || { echo 'DIAG / INVALID RUN DIRECTORY' >&2; exit 2; }
FSUAE_RUN="$RUN"
. ./fsuae.sh || exit 1
. ./stage_original_data.sh
# Functional diagnostics use the fastest existing 68030 setup. Baseline and
# performance callers must select their fixed-clock configuration explicitly.
AMIGA_CONFIG="${AMIGA_CONFIG:-a4000-030}"
. ./config.sh || exit 1
# The verified native ARM runtime (shared host tool, FSUAE_ARM) accelerates only
# unattended maximum-speed 030 checks. Fixed-clock acceptance and explicit FSUAE
# overrides retain their selected emulator; normal interactive launch does not
# use this branch.
if [[ -z "${FSUAE:-}" && "$AMIGA_CONFIG" == a4000-030 && "$(uname -m)" == arm64 && -x "$FSUAE_ARM" ]]; then
  FSUAE="$FSUAE_ARM"
  echo 'DIAG native ARM emulator (verified pilot)'
fi
GDB="${GDB:-m68k-amiga-elf-gdb}"
ROM="$KICKSTART"
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
# Unattended runs default to warp. Set EXTRA_ARGS=--warp_mode=0 for real-time
# measurements; diagnostic options precede pinned machine flags.
EXTRA_ARGS="${EXTRA_ARGS:---warp_mode=1}"
case "${DIAG_AUDIO:-0}" in
  0) SOUND=0 ;;
  1) SOUND=1 ;;
  *) echo 'DIAG / INVALID AUDIO OPTION (use 0 or 1)' >&2; exit 2 ;;
esac

DH0="$RUN/dh0"; DH1="$RUN/dh1"; GDBHOME="$RUN/gdbhome"
mkdir -p "$DH0/s" "$DH1" "$RUN/state" "$RUN/logs" "$GDBHOME"
launch_args=()
case "${DIAG_LAUNCH:-shell}" in
  shell)
    [[ "${DIAG_STACK:-4096}" =~ ^[1-9][0-9]*$ ]] || { echo 'DIAG / INVALID STACK SIZE' >&2; exit 2; }
    printf 'Stack %s\ncd dh1:\nAloneInTheDark\n' "${DIAG_STACK:-4096}" > "$DH0/s/startup-sequence"
    ;;
  workbench)
    [[ -f "$WORKBENCH_ADF" ]] || { echo 'DIAG / MISSING WORKBENCH_ADF' >&2; exit 1; }
    m68k-amiga-elf-gcc -g -m68020 -msoft-float -Os -nostdlib -ffunction-sections -fdata-sections \
      -Wl,--emit-relocs,--gc-sections,-Ttext=0 ../tools/quit_workbench.c \
      obj/gcc8_c_support.o obj/gcc8_a_support.o -o "$RUN/quit-workbench.elf"
    elf2hunk "$RUN/quit-workbench.elf" "$DH1/QuitWorkbench" -s
    rm -f "$DH1/QuitWorkbench.done"
    printf 'cd dh1:\nQuitWorkbench\n' > "$DH0/s/startup-sequence"
    launch_args+=(--floppy_drive_0="$WORKBENCH_ADF" --hard_drive_0_priority=10)
    ;;
  *) echo 'DIAG / UNKNOWN DIAG_LAUNCH' >&2; exit 1 ;;
esac
cp -f out/AloneInTheDark.exe "$DH1/AloneInTheDark"
stage_aitd_original_data "$DH1"
case "${GDBSCRIPT:-runtime_status.gdb}" in
  fresh_viewport.gdb|menu_lifecycle.gdb|pixbase.gdb|apple_events.gdb|font_metrics.gdb|choice_services.gdb|resource_read.gdb|font_lookup.gdb|driver_startup.gdb|menu_records.gdb|device_startup.gdb|setdepth.gdb|hidden_move.gdb|sane.gdb|main_device.gdb|hidden_dialog.gdb|getgworld.gdb|identity.gdb|original_startup.gdb|file_catalog.gdb)
    python3 ../tools/check_startup_prefs.py --folder "$DH1/prefs" --gdb "$RUN/startup-state.gdb"
    ;;
esac
rm -f "$RUN"/state/*.uss
: > "$RUN/gdb-out.log"

fsuae_claim_port || exit 1
# Default to silent host playback; DIAG_AUDIO=1 keeps the normal audio driver.
# Emulated Paula/DMA remains active in either mode.  The window opens behind the others.
# fsuae_options in $FSUAE_COMMON; $EXTRA_ARGS goes first, then these arguments, then its
# defaults (FS-UAE keeps the first value).
NTSC="$aitd_ntsc" DEBUG=1
fsuae_options
FSUAE_LOG="$RUN/fsuae-dbg.log" fsuae_launch \
  "${launch_args[@]}" "${AITD_MACHINE_ARGS[@]}" \
  --logs_dir="$PWD/$RUN/logs" --kickstart_file="$ROM" \
  --hard_drive_0="$DH0" --hard_drive_1="$DH1" \
  --joystick_port_0=mouse --joystick_port_1=nothing \
  --full_keyboard=1 \
  --keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down \
  --keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right \
  --automatic_input_grab=0 --fullscreen=0 --window_width=720 --window_height=568 \
  --remote_debugger_trigger=AloneInTheDark \
  --state_dir="$RUN/state"
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
  "$GDB" --batch -q -l 10 -x "$RUN/connect.gdb" -x trap_args.gdb -x "${GDBSCRIPT:-runtime_status.gdb}" out/AloneInTheDark.elf \
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
if [[ "$status" == 0 && "${DIAG_LAUNCH:-shell}" == workbench ]]; then
  for i in $(seq 1 10); do
    [[ -f "$DH1/QuitWorkbench.done" ]] && break
    kill -0 "$FSUAE_PID" 2>/dev/null || break
    sleep 1
  done
  if [[ ! -f "$DH1/QuitWorkbench.done" ]] || ! grep -qx 'PASS Workbench startup reply received after game cleanup' "$DH1/QuitWorkbench.done"; then
    echo 'DIAG / WORKBENCH REPLY MISSING' >&2; status=1
  else
    cat "$DH1/QuitWorkbench.done"
  fi
fi
cleanup
echo "=== gdb output (filtered) ==="
# Preserve the observer/timeout exit status even when the filtered log is empty.
grep -v "Internal error: pc" "$RUN/gdb-out.log" | grep -vE "^warning:" | tail -"${GDBTAIL:-40}" || true
exit "$status"
