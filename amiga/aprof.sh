#!/bin/bash
# Exact emulated-cycle profile of a book-fold or gameplay interval; see
# docs/performance.md. Clean-builds the matching executable first.
#   aprof.sh book START COUNT NAME [deadline]      START/COUNT in book steps
#   aprof.sh gameplay START COUNT NAME [deadline]  START/COUNT in completed scenes
# Writes ../tmp/aprof/NAME.{prof,log,elf,jt.bin}; summarize with
# python3 ../tools/aprof_report.py report NAME.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
usage() { echo 'usage: aprof.sh book|gameplay START COUNT NAME [deadline]' >&2; exit 2; }
[[ $# -ge 4 ]] || usage
scene=$1 start=$2 count=$3 name=$4 deadline=${5:-1500}
[[ "$start" =~ ^[0-9]+$ && "$count" =~ ^[1-9][0-9]*$ ]] || usage
[[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo 'APROF / INVALID NAME' >&2; exit 2; }
case "$scene" in
   book) flags=""; counter=g_macBookFramesCompleted; condition="$counter>=$start" ;;
   # INGAME only scripts the menu Enter presses into the first room.
   gameplay) flags="INGAME=1"; counter=g_macSceneFramesCompleted; condition="g_ingameStage==5 \&\& $counter>=$start" ;;
  *) usage ;;
esac
FSUAE_APROF="${FSUAE_APROF:-$AMIGA_SHARE/fs-uae-aprof/fs-uae}"
[[ -x "$FSUAE_APROF" ]] || { echo 'APROF / MISSING EMULATOR: run make setup in AmigaXDev or set FSUAE_APROF' >&2; exit 1; }
out=../tmp/aprof
mkdir -p "$out"
rm -f "$out/$name".*
make clean >/dev/null
make -j4 $flags >"$out/$name.build.log" 2>&1 || { echo "APROF / BUILD FAILED: $out/$name.build.log" >&2; exit 1; }
sed -e "s/@START@/$condition/; s/@COUNTER@/$counter/g; s/@COUNT@/$count/; s#@OUT@#$out/$name#g" aprof.gdb > "$out/$name.gdb"
# Fixed-clock reference timing by default; warp does not change emulated cycles.
status=0
FSUAE="$FSUAE_APROF" AMIGA_CONFIG="${AMIGA_CONFIG:-a4000-030-reference}" DIAG_RUN_DIR=.run-aprof \
  GDBTAIL=400 GDBSCRIPT="$out/$name.gdb" ./diag_run.sh "$deadline" > "$out/$name.log" 2>&1 || status=$?
cp -f out/AloneInTheDark.elf "$out/$name.elf"
grep -E '^(CONFIG|START|DELTA|ROOM|LOUDSTOP)' "$out/$name.log" || true
if [[ "$status" != 0 ]] || ! grep -qx COMPLETE "$out/$name.log"; then
  echo "APROF / INCOMPLETE (status $status): $out/$name.log" >&2
  exit 1
fi
echo "APROF COMPLETE $out/$name.prof"
