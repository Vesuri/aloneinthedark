#!/usr/bin/env python3
"""Audit the exact minimal LHA release and its header and payload checksums."""
import argparse
import hashlib
import struct
import subprocess
from pathlib import Path
from package_release import ORIGINAL_HASHES, PREFIX, crc16
from installer_icon import installer_icon, readme_icon, drawer_icon

REQUIRED = {"AloneInTheDark", "AloneInTheDark.slave", "AloneInTheDark.inf", "AitdInstallData", "Install", "Install.info", "ReadMe", "ReadMe.info", "LICENSE.LGPL.txt"}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    raw = args.archive.read_bytes()
    pos = 0
    payloads = {}
    while pos < len(raw) and raw[pos]:
        size = raw[pos]
        header = raw[pos + 2:pos + 2 + size]
        assert len(header) == size and sum(header) & 255 == raw[pos + 1], "bad header checksum"
        assert header[:5] == b"-lh5-" and header[18] == 0, "expected level-zero LH5"
        packed, unpacked = struct.unpack_from("<II", header, 5)
        assert struct.unpack_from('<I',header,13)[0] == ((((2026-1980)<<9)|(10<<5)|9)<<16), 'noncanonical timestamp'
        n = header[19]
        assert size == 22 + n
        name = header[20:20 + n].decode("ascii").replace("\\", "/")
        archive_name = name
        if name == PREFIX + '.info':
            name = '@drawer'
        else:
            assert name.startswith(PREFIX + "/"), "wrong installation drawer"
            name = name[len(PREFIX) + 1:]
        assert name in REQUIRED | {'@drawer'} and name not in payloads, "unexpected or duplicate file"
        pos += size + 2
        assert len(raw[pos:pos + packed]) == packed, "truncated payload"
        # Decode independently with Lhasa, without extracting paths to disk.
        data = subprocess.run(["lha", "pq", str(args.archive.resolve()), archive_name],
                              check=True, capture_output=True).stdout
        assert len(data) == unpacked and crc16(data) == struct.unpack_from("<H", header, 20 + n)[0], "bad payload CRC"
        assert hashlib.sha256(data).hexdigest() not in ORIGINAL_HASHES
        payloads[name] = data
        pos += packed
    assert raw[pos:] == b"\0" and set(payloads) == REQUIRED | {'@drawer'}, "wrong archive contents"
    assert payloads['@drawer'] == drawer_icon(), 'wrong drawer icon'
    for name in ("AloneInTheDark", "AitdInstallData", "AloneInTheDark.slave"):
        assert payloads[name][:4] == b"\0\0\3\xf3", "not an Amiga HUNK executable"
    assert b'WHDLOADS' in payloads['AloneInTheDark.slave'], 'missing WHDLoad slave header'
    for name, kind in (("AloneInTheDark.inf", 4), ("ReadMe.info", 4), ("Install.info", 4), ('@drawer', 2)):
        assert payloads[name][:4] == b"\xe3\x10\0\1" and payloads[name][48] == kind
    assert b"$VER: Install 0.90 (09.10.2026)" in payloads["Install"]
    assert b'APPNAME=Alone in the Dark\0' in payloads['Install.info']
    assert b'Rescue on Fractalus' not in payloads['Install.info']
    assert payloads['AloneInTheDark.inf'] == installer_icon(game=True)
    assert payloads['ReadMe.info'] == readme_icon() and b'MultiView\0' in payloads['ReadMe.info']
    assert b'(settooltype "Slave" "AloneInTheDark.slave")' in payloads['Install']
    assert b'(settooltype "PreLoad" "")' in payloads['Install']
    assert b'(set #dest (tackon #parent "Alone in the Dark"))' in payloads['Install']
    assert b' Requirements:\n -------------' in payloads['ReadMe']
    root = Path(__file__).resolve().parent.parent
    version = (root / 'VERSION').read_text().strip().encode('ascii')
    for name, tag in (('AloneInTheDark', 'Alone in the Dark'), ('AloneInTheDark.slave', 'AloneInTheDark.slave'), ('AitdInstallData', 'AitdInstallData')):
        assert b'$VER: '+tag.encode('ascii')+b' '+version+b' (09.10.2026)' in payloads[name], 'wrong version/date: '+name
    assert payloads['AloneInTheDark'].count((root/'resources/overlay.rsrc').read_bytes()) == 1, 'missing or duplicate embedded overlay'
    assert payloads['ReadMe'] == (root / 'release/ReadMe').read_bytes()
    assert payloads['LICENSE.LGPL.txt'] == (root / 'tools/install-data/COPYING.LIB').read_bytes()
    assert b'independent AitdInstallData helper' in payloads['ReadMe']
    assert b'LICENSE.LGPL.txt' not in payloads['Install']
    assert b'https://github.com/Vesuri/aloneinthedark' in payloads['ReadMe']
    expected = {
        'AloneInTheDark': root/'amiga/out/AloneInTheDark.exe',
        'AloneInTheDark.slave': root/'build/whdload/AloneInTheDark.slave',
        'AitdInstallData': root/'build/install-data/AitdInstallData.exe',
        'Install': root/'release/Install',
    }
    for name, source in expected.items():
        assert payloads[name] == source.read_bytes(), 'archive differs from verified build: '+name
    print("PASS: WHDLoad release, nine files plus drawer icon, valid LHA CRCs, reference icons and separate helper license")

if __name__ == "__main__":
    main()
