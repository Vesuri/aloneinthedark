# INTROSKIP=1 FIXEDRNG=1 MASKREJECTPROBE=1. The diagnostic warms the cache,
# then corrupts a real mask with guest instructions. No debugger memory writes.
set pagination off
set confirm off
set stack-cache off
set code-cache off
tbreak corruptMaskProbe
continue
set $body=(unsigned long)mask
set $size=size
set $pixels=(unsigned long)pixels
set $bytes=pixelBytes
if $size<=10 || *(unsigned short*)($body+$size-2)!=32767 || !$bytes
 echo FAIL mask rejection complex fixture\n
 detach
 quit 1
end
dump binary memory ../tmp/mask-rejection-before.bin $pixels $pixels+$bytes
break AitdScreen::showLoudStop
continue
if *(unsigned short*)($body+$size-2)!=0
 echo FAIL mask mutation did not take effect\n
 detach
 quit 1
end
if g_stageBState!=3 || g_trapWord!=0xa8ec || g_trapSegment!=4 || g_trapOffset!=0x346c
 echo FAIL malformed mask expected CopyBits loud stop\n
 detach
 quit 1
end
dump binary memory ../tmp/mask-rejection-after.bin $pixels $pixels+$bytes
printf "MASK_REJECTED trap=%X segment=%u offset=%X bytes=%u\n",g_trapWord,g_trapSegment,g_trapOffset,$bytes
echo PASS malformed mask named rejection\n
detach
quit 0
