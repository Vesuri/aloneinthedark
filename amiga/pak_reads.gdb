# INTROSKIP=1 PAKPROBE=1. FIXEDRNG=1 checks payloads; without it require natural idle exit too.
set pagination off
set confirm off
set width 0
if g_pakProbeFixed
 if g_fixedRandomCalls!=0 || g_fixedRandomSeed!=1
  echo FAIL PAK deterministic startup fixture\n
  detach
  quit 1
 end
end
set $unseeded_rooms=0
set $unseeded_exit=0
set $unseeded_armed=0
set $pak_n=0
set $pak_itd=0
set $pak_present=0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL PAK original route loud stop: %s / %s selector=%u segment=%s offset=%X\n",manager,routine,selector,segment,offset
 detach
 quit 1
end
set $pak_rebind_verified=0
tbreak aitdPaletteRebindProbe
break aitdPakReadProbe
set $pak_read_bp=$bpnum
continue
while $pak_itd==0 || $pak_present==0 || $pak_rebind_verified==0 || (!g_pakProbeFixed && !$unseeded_exit)
 if !g_pakProbeFixed && !$unseeded_armed
  set $unseeded_dark=(unsigned long)s_segments[4].begin
  if *(unsigned long*)($unseeded_dark+0x5528)!=0x4eba00ac || *(unsigned short*)($unseeded_dark+0x552c)!=0x4e71 || *(unsigned short*)($unseeded_dark+0x5be8)!=0x4eb9
   echo FAIL unseeded original route bytes\n
   detach
   quit 1
  end
  break *($unseeded_dark+0x5be8)
  break *($unseeded_dark+0x552c)
  set $unseeded_armed=1
 end
 if $unseeded_armed && ($pc==$unseeded_dark+0x5be8 || $pc==$unseeded_dark+0x552c)
  if g_pakProbeFixed || *(unsigned short*)($a5-0x11af4) || *(unsigned short*)($a5-0x11af8) || *(unsigned short*)($a5-0x11af0)
   echo FAIL unseeded route entropy/input\n
   detach
   quit 1
  end
  if $pc==$unseeded_dark+0x5be8
   set $unseeded_rooms=$unseeded_rooms+1
   printf "UNSEEDED_ROOM n=%u room=%u camera=%u ticks=%u frames=%u\n",$unseeded_rooms,*(unsigned short*)($a5-0xcd68),*(unsigned short*)($a5-0xcd70),g_macTicks,g_macFramesPresented
  else
   if $unseeded_rooms!=9 || $unseeded_exit || *(unsigned short*)($a5-0xd862)!=1
    echo FAIL unseeded natural idle completion\n
    detach
    quit 1
   end
   set $unseeded_exit=1
   printf "UNSEEDED_EXIT ticks=%u rooms=%u choice=%u flag=%u input=0/0/0\n",g_macTicks,$unseeded_rooms,*(unsigned short*)($a5-0xd8f2),*(unsigned short*)($a5-0xd862)
  end
 else
 if $pc==aitdPaletteRebindProbe
  set $rebind_regs=(unsigned long*)g_rebindProbeRegs
  set $rebind_frame=(unsigned char*)g_rebindProbeFrame
  set $rebind_args=(unsigned char*)g_rebindProbeArgs
  if *(unsigned long*)($rebind_frame+2)!=(unsigned long)s_segments[5].begin+0x20cc
   echo FAIL PAK original palette reactivation caller\n
   detach
   quit 1
  end
  source palette_rebind_call.gdb
  set $pak_rebind_verified=1
 else
  if g_stageBState==3 || $pc!=aitdPakReadProbe
   printf "FAIL PAK original read not reached: %s / %s pc=%X ticks=%u songTick=%u playing=%u\n",g_trapManager,g_trapRoutine,$pc,g_macTicks,g_song.lastTick,g_song.playing
   bt 8
   detach
   quit 1
  end
  set $pak_pb=g_pakProbePB
  set $pak_ref=*(short*)($pak_pb+24)
  set $pak_call=g_pakProbeCall
  set $pak_out=*(unsigned long*)($pak_pb+32)
  set $pak_requested=*(unsigned long*)($pak_pb+36)
  set $pak_id=g_pakProbeFileID
  set $pak_entry=-1
  set $i=0
  while $i<s_files.count_
   if s_files.entries_[$i].id==$pak_id
    set $pak_entry=$i
   end
   set $i=$i+1
  end
  set $pak_seg=0
  set $i=1
  while $i<s_segmentCount
   if $pak_call>=(unsigned long)s_segments[$i].begin && $pak_call<(unsigned long)s_segments[$i].end
    set $pak_seg=$i
   end
   set $i=$i+1
  end
  if $pak_entry<0 || !$pak_seg || !$pak_out || $pak_requested>1048576 || *(unsigned short*)$pak_call!=0xa002
   echo FAIL PAK original caller/catalog/buffer\n
   detach
   quit 1
  end
  set $pak_offset=$pak_call-(unsigned long)s_segments[$pak_seg].begin
  eval "dump binary memory ../tmp/pak-native-%u-enter-pb.bin $pak_pb $pak_pb+80",$pak_n
  disable $pak_read_bp
  tbreak *($pak_call+2)
  continue
  if $pc!=$pak_call+2 || g_stageBState==3
   echo FAIL original PBRead return\n
   detach
   quit 1
  end
  set $pak_actual=*(unsigned long*)($pak_pb+40)
  set $pak_end=*(unsigned long*)($pak_pb+46)
  if $pak_actual>$pak_requested || $pak_actual>$pak_end || (*(short*)($pak_pb+16)!=0 && *(short*)($pak_pb+16)!=-39) || ($d0&65535)!=*(unsigned short*)($pak_pb+16)
   echo FAIL PAK read result\n
   detach
   quit 1
  end
  printf "PAK_READ n=%u name=%s segment=%u offset=%X position=%u requested=%u actual=%u windows=%u\n",$pak_n,s_files.entries_[$pak_entry].name,$pak_seg,$pak_offset,$pak_end-$pak_actual,$pak_requested,$pak_actual,g_systemWindows
  eval "dump binary memory ../tmp/pak-native-%u-return-pb.bin $pak_pb $pak_pb+80",$pak_n
  if $pak_actual>0
   eval "dump binary memory ../tmp/pak-native-%u-bytes.bin $pak_out $pak_out+$pak_actual",$pak_n
  end
  # Require actual payload, not just a directory/header word.
  if $pak_actual>=1024
   if *(unsigned long*)s_files.entries_[$pak_entry].name==0x4954445f
    set $pak_itd=$pak_itd+1
   end
   if *(unsigned long*)s_files.entries_[$pak_entry].name==0x50726573
    set $pak_present=$pak_present+1
   end
  end
  set $pak_n=$pak_n+1
  if $pak_n>2
   echo FAIL PAK read bound\n
   detach
   quit 1
  end
 end
 end
 if $pak_itd==0 || $pak_present==0 || $pak_rebind_verified==0 || (!g_pakProbeFixed && !$unseeded_exit)
  enable $pak_read_bp
  continue
 end
end
if g_pakProbeMask!=3 || $pak_rebind_verified!=1
 echo FAIL PAK filtered probe coverage\n
 detach
 quit 1
end
if g_pakProbeFixed
 printf "PAK_RANDOM calls=%u seed=%X\n",g_fixedRandomCalls,g_fixedRandomSeed
else
 echo PAK_RANDOM mode=ordinary\n
end
printf "PASS original native PAK reads calls=%u itd_payloads=%u present_payloads=%u windows=%u resources=%u services=%u/%u\n",$pak_n,$pak_itd,$pak_present,g_systemWindows,g_resourceRuntimeReads,g_macServiceEntered,g_macServiceCompleted
detach
quit 0
