#!/usr/bin/env python3
"""Import Finder records from the user's extracted classic StuffIt payload.

lsar locates entries; raw headers retain Mac timestamp integers without the
host-timezone conversion applied by lsar/unar's displayed filesystem dates.
Full Finder bytes come from unar's AppleDouble/FinderInfo output, never defaults.
"""
import json
from pathlib import Path
import struct
import subprocess

def archive_entries(path):
    listing=json.loads(subprocess.check_output(['lsar','-j',str(path)]))
    if listing.get('lsarFormatName')!='StuffIt':raise ValueError('METADATA / EXPECTED CLASSIC STUFFIT')
    return listing['lsarContents'],Path(path).read_bytes()

def finder_info(source):
    companion=Path(str(source)+'.rsrc')
    if companion.exists():
        raw=companion.read_bytes()
        if len(raw)<26 or raw[:8]!=bytes.fromhex('0005160700020000'):raise ValueError('METADATA / APPLEDOUBLE HEADER')
        count=struct.unpack_from('>H',raw,24)[0]
        if 26+count*12>len(raw):raise ValueError('METADATA / APPLEDOUBLE TABLE')
        found=[]
        for i in range(count):
            kind,offset,length=struct.unpack_from('>III',raw,26+i*12)
            if offset<26+count*12 or offset+length>len(raw):raise ValueError('METADATA / APPLEDOUBLE ENTRY')
            if kind==9:found.append(raw[offset:offset+length])
        if len(found)!=1 or len(found[0])!=32:raise ValueError('METADATA / FINDER RECORD')
        return found[0][:16]
    result=subprocess.run(['xattr','-px','com.apple.FinderInfo',str(source)],capture_output=True,text=True,check=True)
    raw=bytes.fromhex(result.stdout)
    if len(raw)!=32:raise ValueError('METADATA / FINDER ATTRIBUTE')
    return raw[:16]

def encode(finder,created,modified):
    if len(finder)!=16:raise ValueError('METADATA / FINDER SIZE')
    body=b'AFI1'+finder+struct.pack('>II',created,modified)
    checksum=2166136261
    for byte in body:checksum=((checksum^byte)*16777619)&0xffffffff
    return body+struct.pack('>I',checksum)

def from_entry(archive,entry,finder):
    offset=entry['XADDataOffset'];name=entry['XADFileName'].split('/')[-1]
    if offset<134 or offset>len(archive) or entry.get('XADIsDirectory'):raise ValueError('METADATA / ENTRY OFFSET')
    header=archive[offset-112:offset]
    if not 0<header[2]<=63 or header[3:3+header[2]].decode('mac_roman')!=name:raise ValueError('METADATA / HEADER NAME OR FORK LAYOUT')
    resource=bool(entry.get('XADIsResourceFork'))
    size,other=struct.unpack_from('>II',header,84)
    packed,other_packed=struct.unpack_from('>II',header,92)
    method=header[0]
    if not resource:size,other,packed,other_packed,method=other,size,other_packed,packed,header[1]
    if other or other_packed or size!=entry['XADFileSize'] or packed!=entry['XADDataLength'] or method!=entry['StuffItCompressionMethod'] or offset+packed>len(archive):raise ValueError('METADATA / FORK LAYOUT')
    declared=struct.pack('>IIH',entry['XADFileType'],entry['XADFileCreator'],entry['XADFinderFlags'])
    if len(finder)!=16 or header[66:76]!=declared or finder[:10]!=declared:raise ValueError('METADATA / FINDER SOURCE DISAGREEMENT')
    created,modified=struct.unpack_from('>II',header,76)
    return encode(finder,created,modified)

def metadata_for(archive,entries,relative,source):
    selected=[e for e in entries if e['XADFileName']==relative and not e.get('XADIsDirectory')]
    if len(selected)!=1:raise ValueError('METADATA / AMBIGUOUS OR MISSING ENTRY: '+relative)
    return from_entry(archive,selected[0],finder_info(source))
