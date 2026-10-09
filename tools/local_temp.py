"""Temporary host artifacts stay in the ignored repository tmp directory."""
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def _directory(kwargs):
    if kwargs.get("dir") is None:
        scratch = ROOT / "tmp"
        scratch.mkdir(parents=True, exist_ok=True)
        kwargs["dir"] = scratch
    return kwargs

def TemporaryDirectory(*args, **kwargs):
    return tempfile.TemporaryDirectory(*args, **_directory(kwargs))

def mkdtemp(*args, **kwargs):
    return tempfile.mkdtemp(*args, **_directory(kwargs))
