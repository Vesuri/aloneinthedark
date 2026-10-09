#!/usr/bin/env bash
# Run the Amiga Alone in the Dark build in FS-UAE with the shared test configuration.
#   ./run.sh [path-to-kickstart-rom]
# Use KS 3.1 (auto-boots directory HDs). Right-Amiga+Q quits normally.
# Override ROM via $1 or $KICKSTART.
#
# Run a DIFFERENT binary than out/AloneInTheDark.exe with $AITD_EXE — handy for A/B-ing two builds by
# eye or ear without rebuilding between each look, e.g.
#   AITD_EXE=Alone-a.exe ./run.sh      vs      AITD_EXE=Alone-b.exe ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
. ./fsuae.sh || exit 1
. ./stage_original_data.sh
. ./config.sh || exit 1

FSUAE="${FSUAE:-fs-uae}"
ROM="${1:-${KICKSTART:-$HOME/.local/share/amiga/Kickstarts/kick40063.A600}}"
[ -f "$ROM" ] || { echo "Kickstart ROM not found: $ROM  (pass as \$1 or set \$KICKSTART)"; exit 1; }
EXE="${AITD_EXE:-out/AloneInTheDark.exe}"
[ -f "$EXE" ] || { echo "not found: $EXE  (build first: make, or set \$AITD_EXE)"; exit 1; }

RUN=.run; DH0="$RUN/dh0"; DH1="$RUN/dh1"
mkdir -p "$DH0/s" "$DH1" "$RUN/state" "$RUN/logs"
printf 'cd dh1:\nAloneInTheDark\n' > "$DH0/s/startup-sequence"
cp -f "$EXE" "$DH1/AloneInTheDark"
stage_aitd_original_data "$DH1"
echo "running $EXE"

# ⚠ ALWAYS start from a clean FS-UAE state.  diag_run.sh / the gdb-stub harnesses share this
# --state_dir, and they leave a .uss saved while the CPU was halted on the grey first frame —
# resuming that makes ANY build look frozen and grey, which has cost hours of false bisecting.
# There is no reason to resume state here (the game needs none), so just wipe it every run.
rm -f "$RUN"/state/*.uss

# Screenshots: this fsemu-core FS-UAE takes them with HOST-KEY + S = hold F12, press S.
# The screenshot code reads the FSEMU_SCREENSHOTS_DIR env var (the --screenshots_output_dir
# config key is parsed but ignored by the fsemu core), so set it here.  Dir must exist.
SHOTS="${FSEMU_SCREENSHOTS_DIR:-$PWD/../tmp/screenshots}"
mkdir -p "$SHOTS"
export FSEMU_SCREENSHOTS_DIR="$SHOTS"

fsuae_stop_previous
# After the exec this shell IS fs-uae, so record $$ as the emulator pid.
fsuae_track_self
# Port 0 remains the real Amiga mouse.  Port 1 must be "nothing" (FS-UAE's
# documented spelling), otherwise its keyboard-joystick fallback consumes the
# host cursor keys before they can become Amiga keyboard events.
exec "$FSUAE" \
  "${AITD_MACHINE_ARGS[@]}" \
  --logs_dir="$PWD/$RUN/logs" --kickstart_file="$ROM" \
  --hard_drive_0="$DH0" --hard_drive_1="$DH1" \
  --joystick_port_0=mouse --joystick_port_1=nothing \
  --full_keyboard=1 \
  --keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down \
  --keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right \
  --automatic_input_grab=1 --fullscreen=0 --window_width=720 --window_height=568 \
  --state_dir="$RUN/state" \
  --screenshots_output_dir="$SHOTS"
