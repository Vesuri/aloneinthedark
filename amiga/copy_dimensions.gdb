# Untimed geometry observer: clean-build MONSTERPROFILE=1 FIXEDRNG=1.
# Run with the profile emulator and prepared monster preferences; never time it.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 echo FAIL copy dimensions loud stop\n
 detach
 quit 1
end
break aitdMonsterCheckpoint if g_monsterPhase==4
continue
delete $bpnum
set $copies=0
set $rows=0
set $current=0
break *aitdCopyBitsQuick
commands
 silent
 if $copies>=128
  if $rows==0
   echo FAIL no direct rows\n
   detach
   quit 1
  end
  printf "PASS unmasked copy dimensions calls=%u rows=%u (untimed)\n",$copies,$rows
  detach
  quit 0
 end
 set $frame=*(unsigned long*)($sp+8)
 set $args=*(unsigned long*)($sp+12)
 set $pcopy=*(unsigned long*)($frame+2)
 set $current=0
 if *(unsigned long*)$args==0
  set $seg=0
  set $offset=0
  if $pcopy>=(unsigned long)s_segments[4].begin && $pcopy<(unsigned long)s_segments[4].end
   set $seg=4
   set $offset=$pcopy-(unsigned long)s_segments[4].begin
  end
  if $pcopy>=(unsigned long)s_segments[10].begin && $pcopy<(unsigned long)s_segments[10].end
   set $seg=10
   set $offset=$pcopy-(unsigned long)s_segments[10].begin
  end
  if $seg
   set $from=*(unsigned long*)($args+10)
   set $to=*(unsigned long*)($args+6)
   printf "COPY_DIM seg=%u offset=%x mode=%u from=%d,%d,%d,%d to=%d,%d,%d,%d\n",$seg,$offset,*(unsigned short*)($args+4),*(short*)$from,*(short*)($from+2),*(short*)($from+4),*(short*)($from+6),*(short*)$to,*(short*)($to+2),*(short*)($to+4),*(short*)($to+6)
   set $copies=$copies+1
   set $current=1
  end
 end
 continue
end
break CopyBits8::directRows
commands
 silent
 if $current
  printf "COPY_ROWS seg=%u offset=%x width=%u height=%u src_stride=%u dst_stride=%u\n",$seg,$offset,width,height,srcStride,dstStride
  set $rows=$rows+1
 end
 continue
end
continue
