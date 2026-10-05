#!/usr/bin/env bash
# Abrupt emulator power cycle after published Save success, then fresh Load.
# diag_run.sh's PID-scoped cleanup ends the first emulator without game Quit.
set -euo pipefail
cd "$(dirname "$0")/.."
. amiga/env.sh
mkdir -p tmp/m3-saveload tmp/m3-menu
make -C amiga clean >tmp/m3-saveload/durable-save-build.log
make -C amiga -j4 SAVELOAD=1 >>tmp/m3-saveload/durable-save-build.log 2>&1
DIAG_RUN_DIR=.run-saveload AMIGA_CONFIG=a1200-020 GDBSCRIPT=durable_save.gdb \
 EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 360 >tmp/m3-saveload/durable-save-run.log 2>&1
cp amiga/.run-saveload/gdb-out.log tmp/m3-saveload/durable-save-gdb.log
cp 'amiga/.run-saveload/dh1/Saved Games/SAVE0.ITD' tmp/m3-saveload/durable-save-before.itd
make -C amiga clean >tmp/m3-saveload/durable-load-build.log
make -C amiga -j4 LOADONLY=1 >>tmp/m3-saveload/durable-load-build.log 2>&1
DIAG_RUN_DIR=.run-saveload AMIGA_CONFIG=a1200-020 GDBSCRIPT=durable_load.gdb \
 EXTRA_ARGS=--warp_mode=1 amiga/diag_run.sh 360 >tmp/m3-saveload/durable-load-run.log 2>&1
cp amiga/.run-saveload/gdb-out.log tmp/m3-saveload/durable-load-gdb.log
cp 'amiga/.run-saveload/dh1/Saved Games/SAVE0.ITD' tmp/m3-saveload/durable-save-after.itd
python3 tools/check_durable_save.py tmp/m3-saveload/durable-save-gdb.log \
 tmp/m3-saveload/durable-load-gdb.log --save-status 0 --load-status 0 \
 >tmp/m3-saveload/durable-checked.log
cat tmp/m3-saveload/durable-checked.log
