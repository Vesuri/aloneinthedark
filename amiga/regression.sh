#!/usr/bin/env bash
# Vette's clean-build / bounded observer / explicit PASS pattern.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
case "${1:-boot}" in
  boot) flags=(); observer=boot.gdb ;;
  window-core)
    flags=(WINDOWPROBE=1 PROBES=1); observer=window.gdb
    python3 ../tools/check_window_capture.py --prepare
    ;;
  *) echo "REGRESSION / UNKNOWN CASE: $1" >&2; exit 2 ;;
esac
mkdir -p .run
# A failed launch must never inherit a PASS record from an older run.
: > .run/gdb-out.log
make clean > .run/regression-build.log 2>&1
if ! make -j4 "${flags[@]}" >> .run/regression-build.log 2>&1; then
  cat .run/regression-build.log >&2
  exit 1
fi
status=0
GDBTAIL=120 EXTRA_ARGS=--warp_mode=1 GDBSCRIPT="$observer" ./diag_run.sh 60 || status=$?
if [[ "$observer" == window.gdb ]]; then
  python3 ../tools/check_window_capture.py --status "$status"
else
  python3 ../tools/regression_result.py .run/gdb-out.log --status "$status"
fi
