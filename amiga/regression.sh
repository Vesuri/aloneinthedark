#!/usr/bin/env bash
# Vette's clean-build / bounded observer / explicit PASS pattern.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
if [[ "${AITD_REGRESSION_PREFS_ISOLATED:-}" != 1 ]]; then
  exec python3 ../tools/regression_preferences.py "$@"
fi
deadline=60
case "${1:-boot}" in
  resource-exit) exec bash ./resource_exit.sh ;;
  audio) exec bash ./audio.sh ;;
  boot) flags=(); observer=boot.gdb ;;
  startup)
    [[ "${DIAG_RUN_DIR:-.run}" == .run ]] || { echo "STARTUP / observer requires DIAG_RUN_DIR=.run" >&2; exit 2; }
    flags=(PROBES=1); observer=driver_startup.gdb; deadline=600
    python3 ../tools/check_startup_prefs.py --folder .run/dh1/prefs --prepare
    ;;
  stack)
    flags=(QUITPROBE=1 STACKPROBE=1 INTROSKIP=1); observer=stack.gdb; deadline=300
    export DIAG_STACK=4096
    ;;
  quit)
    flags=(QUITPROBE=1 INTROSKIP=1); observer=quit.gdb; deadline=300
    ;;
  stairs)
    flags=(EXPLOREROUTE=1 INTROSKIP=1 PROBES=); observer=stairs.gdb; deadline=900
    mkdir -p ../tmp/stairs-regression
    rm -f ../tmp/stairs-regression/native-*-actor.bin ../tmp/stairs-regression/stairs-native-*.bin
    ;;
  intro)
    flags=(C2PVERIFY=1 FIXEDRNG=1); observer=intro.gdb; deadline=1800
    export AMIGA_CONFIG="${AMIGA_CONFIG:-a1200-020}"
    ;;
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
GDBTAIL=120 EXTRA_ARGS="${EXTRA_ARGS:---warp_mode=1}" GDBSCRIPT="$observer" ./diag_run.sh "$deadline" || status=$?
if [[ "$observer" == driver_startup.gdb ]]; then
  python3 ../tools/check_native_driver.py .run/gdb-out.log --status "$status" --captures
elif [[ "$observer" == quit.gdb || "$observer" == stack.gdb ]]; then
  python3 ../tools/check_quit_regression.py .run/gdb-out.log --status "$status" --launch "${DIAG_LAUNCH:-shell}" --reply .run/dh1/QuitWorkbench.done
elif [[ "$observer" == stairs.gdb ]]; then
  python3 ../tools/check_stairs_regression.py .run/gdb-out.log --status "$status"
elif [[ "$observer" == intro.gdb ]]; then
  python3 ../tools/check_intro.py .run/gdb-out.log --status "$status"
elif [[ "$observer" == resource_read.gdb ]]; then
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
