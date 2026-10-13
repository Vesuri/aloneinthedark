#!/bin/bash
# Exact emulated-cycle profile of a book-fold, gameplay or monster interval; see
# docs/performance.md. Clean-builds the matching executable first.
#   aprof.sh book START COUNT NAME [deadline]      START/COUNT in book steps
#   aprof.sh gameplay START COUNT NAME [deadline]  START/COUNT in completed scenes
#   aprof.sh monster NAME [deadline]             fresh game, event-delimited phases
# APROF_FRAME_STOPS=1 is an observer-bias control, not an acceptance measurement.
# Writes ../tmp/aprof/NAME.{prof,log,elf,jt.bin}; summarize with
# python3 ../tools/aprof_report.py report NAME.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
usage() { echo 'usage: aprof.sh book|gameplay START COUNT NAME [deadline] OR monster NAME [deadline]' >&2; exit 2; }
[[ $# -ge 1 ]] || usage
if [[ "$1" == monster ]]; then
  [[ $# -ge 2 && $# -le 3 ]] || usage
  scene=monster start=200 count=1 name=$2 deadline=${3:-3600}
else
  [[ $# -ge 4 && $# -le 5 ]] || usage
  scene=$1 start=$2 count=$3 name=$4 deadline=${5:-1500}
fi
[[ "$start" =~ ^[0-9]+$ && "$count" =~ ^[1-9][0-9]*$ ]] || usage
[[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo 'APROF / INVALID NAME' >&2; exit 2; }
case "$scene" in
   monster) flags="MONSTERPROFILE=1 FIXEDRNG=1"; counter=g_macSceneFramesCompleted; condition="unused" ;;
   book) flags=""; counter=g_macBookFramesCompleted; condition="$counter>=$start" ;;
   # INGAME only scripts the menu Enter presses into the first room.
   gameplay) flags="INGAME=1"; counter=g_macSceneFramesCompleted; condition="g_ingameStage==5 \&\& $counter>=$start" ;;
  *) usage ;;
esac
if [[ "$scene" == monster && ( "${AMIGA_CONFIG:-a4000-030-reference}" != a4000-030-reference || "${AMIGA_VIDEO:-PAL}" != PAL ) ]]; then
  echo 'APROF / monster requires a4000-030-reference PAL' >&2; exit 2
fi
FSUAE_APROF="${FSUAE_APROF:-$AMIGA_SHARE/fs-uae-aprof/fs-uae}"
[[ -x "$FSUAE_APROF" ]] || { echo 'APROF / MISSING EMULATOR: run make setup in AmigaXDev or set FSUAE_APROF' >&2; exit 1; }
frame_stops=${APROF_FRAME_STOPS:-0}
[[ "$frame_stops" == 0 || ( "$scene" == monster && "$frame_stops" == 1 ) ]] || usage
out=../tmp/aprof
mkdir -p "$out"
# Do not silently destroy a previous measurement.
[[ ! -e "$out/$name.log" ]] || { echo "APROF / NAME EXISTS: $name" >&2; exit 1; }
make clean >/dev/null
make -j4 $flags >"$out/$name.build.log" 2>&1 || { echo "APROF / BUILD FAILED: $out/$name.build.log" >&2; exit 1; }
[[ "$scene" != monster ]] || template=aprof_monster.gdb
sed -e "s/@START@/$condition/; s/@COUNTER@/$counter/g; s/@COUNT@/$count/; s#@OUT@#$out/$name#g; s/@FRAME_STOPS@/$frame_stops/g" "${template:-aprof.gdb}" > "$out/$name.gdb"
# Fixed-clock reference timing by default; warp does not change emulated cycles.
status=0
extra_args=${EXTRA_ARGS:---warp_mode=1}
# Host filesystem worker scheduling changes the game clock and combat route.
# FS-UAE deterministic mode services DOS packets at emulated hsync boundaries.
[[ "$scene" != monster ]] || extra_args="--deterministic=1 $extra_args"
EXTRA_ARGS="$extra_args" FSUAE="$FSUAE_APROF" AMIGA_CONFIG="${AMIGA_CONFIG:-a4000-030-reference}" DIAG_RUN_DIR=.run-aprof \
  GDBTAIL=2000 GDBSCRIPT="$out/$name.gdb" ./diag_run.sh "$deadline" > "$out/$name.log" 2>&1 || status=$?
cp -f out/AloneInTheDark.elf "$out/$name.elf"
grep -E '^(CONFIG|START|DELTA|ROOM|LOUDSTOP)' "$out/$name.log" || true
if [[ "$status" != 0 ]] || ! grep -qx COMPLETE "$out/$name.log"; then
  echo "APROF / INCOMPLETE (status $status): $out/$name.log" >&2
  exit 1
fi
if [[ "$scene" == monster ]]; then
  python3 ../tools/aprof_report.py monster "$name"
fi
echo "APROF COMPLETE $out/$name"
