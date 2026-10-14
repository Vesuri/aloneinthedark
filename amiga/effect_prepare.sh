#!/usr/bin/env bash
# Six bounded stream preparations; playback contracts use effect_loop_matrix.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
source amiga/env.sh
name=${1:?usage: effect_prepare.sh NAME}
[[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || exit 2
out="tmp/aprof/$name"
[[ ! -e "$out.log" ]] || { echo 'Output already exists' >&2; exit 2; }
mkdir -p tmp/aprof
restore() {
 make -C amiga clean >"$out.restore.log" 2>&1
 make -C amiga -j4 >>"$out.restore.log" 2>&1
}
trap restore EXIT
make -C amiga clean >"$out.build.log" 2>&1
make -C amiga -j4 EFFECTPREPPROBE=1 INTROSKIP=1 >>"$out.build.log" 2>&1
python3 - "$out" <<'PY'
from pathlib import Path
import sys
out=sys.argv[1]
s=Path('amiga/effect_prepare.gdb').read_text().replace('@OUT@','../'+out)
Path(out+'.gdb').write_text(s)
PY
cp amiga/out/AloneInTheDark.elf "$out.elf"
GDBTAIL=2000 GDBSCRIPT="../$out.gdb" DIAG_RUN_DIR=.run-effect-prep \
 FSUAE="${FSUAE_APROF:-$AMIGA_SHARE/fs-uae-aprof/fs-uae}" \
 AMIGA_CONFIG=a4000-030-reference AMIGA_VIDEO=PAL \
 EXTRA_ARGS='--warp_mode=1' amiga/diag_run.sh 180 >"$out.log" 2>&1
grep -qx 'PASS repeated streamed preparation six cases' "$out.log"
for n in 0 1 2 3 4 5; do
 ln "$out.elf" "$out-$n.elf"
 python3 - "$out" "$n" <<'PYLOG'
from pathlib import Path
import re,sys
out,n=sys.argv[1:]
s=Path(out+'.log').read_text()
fields=re.findall(r'^PREPARATION case='+n+r' bytes=\d+ fast=\d+ chip=\d+ fields=(\d+)$',s,re.M)
if len(fields)!=1:raise SystemExit('missing or duplicate preparation result')
s=s.replace('DELTA fields=0 frames=0 steps=1','DELTA fields='+fields[0]+' frames=0 steps=1')
Path(out+'-'+n+'.log').write_text(s)
PYLOG
 python3 tools/aprof_report.py report "$name-$n" >"$out-$n.report"
done
grep '^PREPARATION\|^PASS' "$out.log"
