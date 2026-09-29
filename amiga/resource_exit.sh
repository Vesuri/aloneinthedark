#!/usr/bin/env bash
# Three fresh processes per location: failure, original exit, reload/delete.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
. ./stage_original_data.sh
mkdir -p .run/dh1
stage_aitd_original_data .run/dh1
for location in saves prefs; do
  python3 ../tools/check_native_resource_exit.py --phase 0 --location "$location"
done
mkdir -p .run
for location in saves prefs; do
 prefs=0
 if [[ "$location" == prefs ]]; then prefs=1; fi
 phases=(3 1 2)
 if [[ "$location" == saves ]]; then phases=(4 5 3 1 2); fi
 for phase in "${phases[@]}"; do
  make clean > .run/resource-exit-build.log 2>&1
  if ! make -j4 RESOURCEEXITPROBE=1 RESOURCEEXITPHASE="$phase" RESOURCEEXITPREFS="$prefs" PROBES=1 >> .run/resource-exit-build.log 2>&1; then
    cat .run/resource-exit-build.log >&2
    exit 1
  fi
  status=0
  GDBTAIL=100 EXTRA_ARGS=--warp_mode=1 GDBSCRIPT=resource_exit.gdb ./diag_run.sh 60 || status=$?
  cp .run/gdb-out.log ".run/resource-exit-$location-$phase.log"
  cleanup=()
  if [[ "$phase" == 3 ]]; then cleanup=(--cleanup-fault); fi
  python3 ../tools/check_native_resource_exit.py --phase "$phase" --location "$location" --status "$status" --log ".run/resource-exit-$location-$phase.log" "${cleanup[@]}"
done
done
