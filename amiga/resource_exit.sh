#!/usr/bin/env bash
# Three fresh processes: failed publication, successful original exit, reload/delete.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
. ./stage_original_data.sh
mkdir -p .run/dh1
stage_aitd_original_data .run/dh1
python3 ../tools/check_native_resource_exit.py --phase 0
mkdir -p .run
for phase in 3 1 2; do
  make clean > .run/resource-exit-build.log 2>&1
  if ! make -j4 RESOURCEEXITPROBE=1 RESOURCEEXITPHASE="$phase" PROBES=1 >> .run/resource-exit-build.log 2>&1; then
    cat .run/resource-exit-build.log >&2
    exit 1
  fi
  status=0
  GDBTAIL=100 EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=resource_exit.gdb ./diag_run.sh 60 || status=$?
  cp .run/gdb-out.log ".run/resource-exit-$phase.log"
  cleanup=()
  if [[ "$phase" == 3 ]]; then cleanup=(--cleanup-fault); fi
  python3 ../tools/check_native_resource_exit.py --phase "$phase" --status "$status" --log ".run/resource-exit-$phase.log" "${cleanup[@]}"
done
