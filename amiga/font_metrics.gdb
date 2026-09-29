set pagination off
set confirm off
set width 0
source .run/startup-state.gdb
break AitdScreen::showLoudStop
tbreak getFontNumber
continue
set $core=s_segments[3].begin
tbreak *($core+0x53a)
continue
tbreak dispatchMacTrap if trap==0xa88b
continue
set $initial_args=userStack
set $initial_regs=regs
set $initial_pc=*(unsigned long*)(frame+2)
set $misc=s_segments[9].begin
if $misc==0 || $initial_pc!=(unsigned long)$misc+0x610 || *(unsigned short*)($misc+0x610)!=0xa88b || *(unsigned short*)($misc+0x618)!=0xa88d || *(unsigned short*)($misc+0x626)!=0xa88d
 echo FAIL metrics original call bytes\n
 detach
 quit 1
end
echo ARM native metrics original bytes\n
set $metric_seq=0
set $metric_group=0
define metric_bytes
 set $n=0
 while $n<$arg1
  printf "%08X",*(unsigned long*)($arg0+$n*4)
  set $n=$n+1
 end
 printf "\n"
end
while $metric_group<25
 if $metric_group>0
  tbreak *($misc+0x610)
  continue
 end
 if $metric_group>0 && $pc!=$misc+0x610
  echo FAIL metrics call not reached\n
  detach
  quit 1
 end
 set $metric_seq=$metric_seq+1
 set $port=*(unsigned long*)s_qdThePort
 if $metric_group==0
  set $args=(unsigned long)$initial_args
  set $r_d0=$initial_regs[0]
  set $r_d1=$initial_regs[1]
  set $r_d2=$initial_regs[2]
  set $r_d3=$initial_regs[3]
  set $r_d4=$initial_regs[4]
  set $r_d5=$initial_regs[5]
  set $r_d6=$initial_regs[6]
  set $r_d7=$initial_regs[7]
  set $r_a0=$initial_regs[8]
  set $r_a1=$initial_regs[9]
  set $r_a2=$initial_regs[10]
  set $r_a3=$initial_regs[11]
  set $r_a4=$initial_regs[12]
  set $r_a5=$initial_regs[13]
  set $r_a6=$initial_regs[14]
 else
  set $args=$sp
  set $r_d0=(unsigned long)$d0
  set $r_d1=(unsigned long)$d1
  set $r_d2=(unsigned long)$d2
  set $r_d3=(unsigned long)$d3
  set $r_d4=(unsigned long)$d4
  set $r_d5=(unsigned long)$d5
  set $r_d6=(unsigned long)$d6
  set $r_d7=(unsigned long)$d7
  set $r_a0=(unsigned long)$a0
  set $r_a1=(unsigned long)$a1
  set $r_a2=(unsigned long)$a2
  set $r_a3=(unsigned long)$a3
  set $r_a4=(unsigned long)$a4
  set $r_a5=(unsigned long)$a5
  set $r_a6=(unsigned long)$a6
 end
 printf "METRIC_ENTER label=INFO seq=%X sp=%X port=%X font=%X size=%X face=%X extra=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$args,$port,*(unsigned short*)($port+68),*(unsigned short*)($port+74),*(unsigned char*)($port+70),*(unsigned long*)($port+76),$r_d0,$r_d1,$r_d2,$r_d3,$r_d4,$r_d5,$r_d6,$r_d7,$r_a0,$r_a1,$r_a2,$r_a3,$r_a4,$r_a5,$r_a6
 printf "METRIC_ARGS seq=%X data=",$metric_seq
 metric_bytes $args 3
 set $out=*(unsigned long*)$args
 printf "METRIC_BEFORE seq=%X data=",$metric_seq
 metric_bytes $out 3
 printf "METRIC_FONTS seq=%X data=",$metric_seq
 set $dump_address=$r_a5-0xf10
 metric_bytes $dump_address 8
 printf "METRIC_STYLES seq=%X data=",$metric_seq
 set $dump_address=$r_a5-0xef2
 metric_bytes $dump_address 3
 printf "METRIC_SAVED seq=%X font=%X size=%X face=%X\n",$metric_seq,*(unsigned short*)($r_a6-6),*(unsigned short*)($r_a6-12),*(unsigned char*)($r_a6-7)
 tbreak *($misc+0x612)
 continue
 if $pc!=$misc+0x612
  echo FAIL metrics return not reached\n
  detach
  quit 1
 end
 printf "METRIC_RETURN label=INFO seq=%X sp=%X port=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$sp,*(unsigned long*)s_qdThePort,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 printf "METRIC_AFTER seq=%X data=",$metric_seq
 metric_bytes $out 3
 tbreak *($misc+0x618)
 continue
 if $pc!=$misc+0x618
  echo FAIL metrics call not reached\n
  detach
  quit 1
 end
 set $metric_seq=$metric_seq+1
 set $port=*(unsigned long*)s_qdThePort
 set $args=$sp
 printf "METRIC_ENTER label=ZERO seq=%X sp=%X port=%X font=%X size=%X face=%X extra=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$sp,$port,*(unsigned short*)($port+68),*(unsigned short*)($port+74),*(unsigned char*)($port+70),*(unsigned long*)($port+76),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 printf "METRIC_ARGS seq=%X data=",$metric_seq
 metric_bytes $args 3
 tbreak *($misc+0x61a)
 continue
 if $pc!=$misc+0x61a
  echo FAIL metrics return not reached\n
  detach
  quit 1
 end
 printf "METRIC_RETURN label=ZERO seq=%X sp=%X port=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$sp,*(unsigned long*)s_qdThePort,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 tbreak *($misc+0x626)
 continue
 if $pc!=$misc+0x626
  echo FAIL metrics call not reached\n
  detach
  quit 1
 end
 set $metric_seq=$metric_seq+1
 set $port=*(unsigned long*)s_qdThePort
 set $args=$sp
 printf "METRIC_ENTER label=SPACE seq=%X sp=%X port=%X font=%X size=%X face=%X extra=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$sp,$port,*(unsigned short*)($port+68),*(unsigned short*)($port+74),*(unsigned char*)($port+70),*(unsigned long*)($port+76),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 printf "METRIC_ARGS seq=%X data=",$metric_seq
 metric_bytes $args 3
 tbreak *($misc+0x628)
 continue
 if $pc!=$misc+0x628
  echo FAIL metrics return not reached\n
  detach
  quit 1
 end
 printf "METRIC_RETURN label=SPACE seq=%X sp=%X port=%X result=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$metric_seq,$sp,*(unsigned long*)s_qdThePort,*(unsigned short*)$sp,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 set $metric_group=$metric_group+1
end
tbreak *($misc+0x660)
continue
set $port=*(unsigned long*)s_qdThePort
printf "METRIC_DONE font=%X size=%X face=%X error=%X\n",*(unsigned short*)($port+68),*(unsigned short*)($port+74),*(unsigned char*)($port+70),*(unsigned short*)($a6-10)
set $ri=0
while $ri<g_resourceCount
 if s_resourceForks.m_items[$ri].item.type==0x4d445256 && s_resourceHandles[$ri]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 if s_resourceForks.m_items[$ri].item.fork==15 && (s_resourceForks.m_items[$ri].item.type==0x464f4e44 || s_resourceForks.m_items[$ri].item.type==0x4e464e54)
  if s_resourceHandles[$ri]==0 || *s_resourceHandles[$ri]==0
   echo FAIL installed font not resident\n
   detach
   quit 1
  end
  set $body=(unsigned long)*s_resourceHandles[$ri]
  set $size=s_resourceForks.m_items[$ri].item.size
  set $kind=s_resourceForks.m_items[$ri].item.type
  set $id=s_resourceForks.m_items[$ri].item.id
  printf "FONT_INSTALLED type=%X id=%u size=%u\n",$kind,$id,$size
  eval "dump binary memory ../tmp/metrics-font-%X-%u.bin %u %u",$kind,$id,$body,$body+$size
 end
 set $ri=$ri+1
end
continue
printf "METRIC_NEXT state=%u trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s windows=%u services=%u/%u app=%u/%u overlay=%u/%u prep=%u/%u resources=%u\n",g_stageBState,g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine,g_systemWindows,g_macServiceEntered,g_macServiceCompleted,g_resourceRuntimeReads,g_resourceRuntimeBytes,g_overlayRuntimeReads,g_overlayRuntimeBytes,g_overlaySourceReads,g_overlaySourceBytes,g_resourceCount
if g_stageBState!=3 || g_trapWord!=0xab1d || g_trapSelector!=6 || g_trapSegment!=7 || g_trapOffset!=0x1286 || *(unsigned long*)(g_trapRoutine+0)!=0x53455447 || *(unsigned long*)(g_trapRoutine+4)!=0x574f524c || g_trapRoutine[8]!=0x44 || g_trapRoutine[9]!=0 || g_macServiceActive!=0 || g_systemWindows!=$startup_windows || g_macServiceEntered!=$startup_entered || g_macServiceCompleted!=$startup_completed
 echo FAIL metrics next stop\n
 detach
 quit 1
end
echo PASS native font metrics calls=4B next=SETGWORLD\n
detach
quit 0
