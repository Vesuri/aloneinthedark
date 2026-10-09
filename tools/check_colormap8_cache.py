#!/usr/bin/env python3
import os, subprocess
import local_temp as tempfile
from pathlib import Path
root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="aitd-colormap8-") as directory:
    executable = Path(directory)/"test"
    subprocess.run([os.environ.get("HOST_CXX", "c++"), "-std=c++17", "-Wall", "-Wextra", "-Werror", "-fsanitize=address,undefined", str(root/"tools/test_colormap8_cache.cpp"), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True, timeout=30)
