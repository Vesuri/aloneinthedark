#!/usr/bin/env python3
"""Exercise native driver state and the bounded effect-stream planner."""
import os
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='aitd-driver-') as work:
    exe=Path(work)/'check'
    for source in ('test_sound_driver.cpp','test_effect_stream.cpp'):
        subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(root/'tools'/source),'-o',str(exe)],check=True)
        subprocess.run([str(exe)],check=True,timeout=30)
