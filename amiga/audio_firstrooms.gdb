# Observe genuine effect requests without modifying guest RAM or CPU registers.
set pagination off
set confirm off
set $audio_event=0
break playNativeEffect
commands
 silent
 set $audio_event=$audio_event+1
 set $audio_sample=*(unsigned long*)packet
 set $audio_size=*(unsigned long*)(packet+4)
 set $audio_world=(unsigned long)s_a5WorldStorage+75616
 printf "AUDIO_NATIVE_EFFECT event=%u tick=%u id=%X bytes=%u rate=%X loop=%u/%u room=%d camera=%d\n",$audio_event,g_macTicks,*(unsigned short*)(packet+24),$audio_size,*(unsigned long*)(packet+8),*(unsigned long*)(packet+12),*(unsigned long*)(packet+16),*(short*)($audio_world-0xcd68),*(short*)($audio_world-0xcd70)
 if $audio_sample && $audio_size
  eval "dump binary memory ../tmp/m4/gameplay/native/effect-%u.bin %u %u",$audio_event,$audio_sample,$audio_sample+$audio_size
 end
 continue
end
source south_rooms.gdb
