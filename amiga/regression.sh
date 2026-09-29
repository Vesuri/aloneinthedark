#!/usr/bin/env bash
# Vette's clean-build / bounded observer / explicit PASS pattern.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
deadline=60
case "${1:-boot}" in
  boot) flags=(); observer=boot.gdb ;;
  resource-read)
    flags=(); observer=resource_read.gdb
    python3 ../tools/check_resource_reads.py --prepare
    ;;
  file-read)
    flags=(FILEPROBE=1); observer=file_read.gdb
    python3 ../tools/check_file_read_probe.py --prepare
    ;;
  file-write)
    flags=(FILEPROBE=1 FILEWRITEPROBE=1); observer=file_write.gdb; deadline=120
    python3 ../tools/check_file_read_probe.py --prepare --write
    ;;
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
GDBTAIL=120 EXTRA_ARGS=--warp_mode=1 GDBSCRIPT="$observer" ./diag_run.sh "$deadline" || status=$?
if [[ "$observer" == resource_read.gdb ]]; then
  python3 ../tools/check_resource_reads.py --status "$status"
elif [[ "$observer" == file_read.gdb ]]; then
  python3 ../tools/check_file_read_probe.py --status "$status"
elif [[ "$observer" == file_write.gdb ]]; then
  python3 ../tools/check_file_read_probe.py --write --status "$status"
elif [[ "$observer" == window.gdb ]]; then
  python3 ../tools/check_window_capture.py --status "$status"
else
  python3 ../tools/regression_result.py .run/gdb-out.log --status "$status"
fi
