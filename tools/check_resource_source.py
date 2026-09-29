#!/usr/bin/env python3
"""Validate callback-backed resource maps and bounded payload reads."""
import os
from pathlib import Path
import subprocess
import tempfile
root=Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='aitd-resource-source-') as work:
    exe=str(Path(work)/'test')
    subprocess.run([os.environ.get('HOST_CXX','c++'),'-std=c++17','-Wall','-Wextra','-Werror','-include','cstdint','-fsanitize=address,undefined',str(root/'tools/test_resource_source.cpp'),str(root/'src/mac/ResourceMap.cpp'),str(root/'src/mac/ResourceForks.cpp'),'-o',exe],check=True)
    subprocess.run([exe],check=True,timeout=30)
