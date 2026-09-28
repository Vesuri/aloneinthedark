#!/usr/bin/env python3
"""Exercise the persistent Finder metadata format."""
import os
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="aitd-metadata-") as work:
    exe=str(Path(work)/"test")
    subprocess.run([os.environ.get("HOST_CXX","c++"),"-std=c++17","-Wall","-Wextra","-Werror",
        "-include","cstdint","-fsanitize=address,undefined",
        str(root/"tools/test_file_metadata.cpp"),str(root/"src/mac/FileMetadata.cpp"),
        "-o",exe],check=True)
    subprocess.run([exe],check=True,timeout=30)
