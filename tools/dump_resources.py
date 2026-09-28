#!/usr/bin/env python3
"""Write each resource of a raw classic-Mac resource fork to its own file.

Files are named TYPE_ID[_name] (for example CODE_3_Core), the layout the
m68k_sweep.py / m68k_lowmem.py flow scans and the Ghidra import expect.
Output is derived from the original game: keep it under ignored tmp/.

    python3 tools/dump_resources.py "tmp/runtime-data/Alone In The Dark" tmp/segments CODE
"""
import argparse
import re
from pathlib import Path

from resource_fork import read_resource_fork


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("fork", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("types", nargs="*", help="four-character types to keep (default: all)")
    args = parser.parse_args()
    wanted = {t.encode("mac_roman").ljust(4) for t in args.types}
    args.destination.mkdir(parents=True, exist_ok=True)
    count = 0
    for resource in read_resource_fork(args.fork):
        if wanted and resource.kind not in wanted:
            continue
        kind = re.sub(r"[^A-Za-z0-9]", "_", resource.kind.decode("mac_roman"))
        name = re.sub(r"[^A-Za-z0-9.-]+", "_", resource.name).strip("_")
        filename = f"{kind}_{resource.rid}" + (f"_{name}" if name else "")
        (args.destination / filename).write_bytes(resource.body)
        count += 1
    print(f"{count} resources -> {args.destination}")


if __name__ == "__main__":
    main()
