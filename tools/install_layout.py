"""The one archive-to-installed path change verified with the original installer."""
import argparse
import hashlib
from pathlib import Path

BODY='ListBod2.PAK'
BODY_SHA='5c552161db462f80e82346494a304d133ca502c92ab299a77b82ca988fd1893e'
def installed_path(relative):
    relative=Path(relative)
    return Path('Alone Data')/BODY if relative==Path(BODY) else relative

def retire_legacy(root,data,info):
    """Remove only byte-verified leftovers from our earlier extraction/staging."""
    if hashlib.sha256(data).hexdigest()!=BODY_SHA:
        raise ValueError('INSTALL LAYOUT / ORIGINAL LISTBOD2 BYTES')
    root=Path(root)
    paths=[]
    for suffix,expected in (('',data),('.finfo',info)):
        p=root/(BODY+suffix)
        if p.exists() or p.is_symlink():
            if p.is_symlink() or not p.is_file() or p.read_bytes()!=expected:
                raise ValueError('INSTALL LAYOUT / CONFLICTING LEGACY FILE: '+str(p))
            paths.append(p)
    if (root/(BODY+'.rsrc')).exists() or (root/(BODY+'.rsrc')).is_symlink():
        raise ValueError('INSTALL LAYOUT / UNEXPECTED LEGACY RESOURCE FORK')
    for p in paths:p.unlink()

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('root',type=Path);p.add_argument('source',type=Path);a=p.parse_args()
    try:retire_legacy(a.root,a.source.read_bytes(),Path(str(a.source)+'.finfo').read_bytes())
    except (ValueError,OSError) as error:raise SystemExit(str(error))
