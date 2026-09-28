#!/usr/bin/env python3
"""Exercise the portable sparse write buffer."""
import os
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="aitd-files-") as work:
    exe=str(Path(work)/"test")
    subprocess.run([os.environ.get("HOST_CXX","c++"),"-std=c++17","-Wall","-Wextra","-Werror",
        "-include","cstdint","-fsanitize=address,undefined",
        str(root/"tools/test_file_write_buffer.cpp"),str(root/"src/mac/FileWriteBuffer.cpp"),
        "-o",exe],check=True)
    subprocess.run([exe],check=True,timeout=30)
