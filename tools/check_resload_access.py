#!/usr/bin/env python3
"""Exercise the actual portable resload adapter against a strict API fixture."""
import os
from pathlib import Path
import subprocess
import local_temp as tempfile
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="aitd-resload-") as work:
    exe=str(Path(work)/"test")
    subprocess.run([os.environ.get("HOST_CXX","c++"),"-std=c++17","-Wall","-Wextra","-Werror",
        "-include","cstdint","-fsanitize=address,undefined",
        str(root/"tools/test_resload_access.cpp"),str(root/"src/platform/amiga/ResloadAccess.cpp"),
        "-o",exe],check=True)
    subprocess.run([exe],check=True,timeout=30)
