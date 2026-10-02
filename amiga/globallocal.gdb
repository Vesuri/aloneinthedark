# INTROSKIP=1 MOUSEPROBE=1. Guest mouse input through the normal VBI sampler.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL GlobalToLocal loud stop: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
tbreak *recordKey
continue
if g_mouseProbeStage || g_mouseProbeSamples
 echo FAIL mouse fixture initial state\n
 detach
 quit 1
end
set $target=(unsigned long)s_segments[7].begin+0x16e8
tbreak *$target
continue
if !g_mouseProbeSamples || g_mouseProbeStage<2
 echo FAIL native VBI mouse input\n
 detach
 quit 1
end
printf "GL_INPUT point=00FD0141 button=1 samples=%u site=native-vbi-mouse\n",g_mouseProbeSamples
set $args=$sp
set $point=*(unsigned long*)$args
set $port=*(unsigned long*)s_qdThePort
set $pm=*(unsigned long*)*(unsigned long*)($port+2)
if $pc!=$target || *(unsigned long*)($target-8)!=0x27530004 || *(unsigned long*)($target-4)!=0x486b0004 || *(unsigned short*)$target!=0xa871
 echo FAIL original inverse caller\n
 detach
 quit 1
end
dump binary memory ../tmp/globallocal-native-before.bin (char*)$point-4 (char*)$point+8
dump binary memory ../tmp/globallocal-native-port.bin (char*)$port (char*)$port+108
dump binary memory ../tmp/globallocal-native-pm.bin (char*)$pm (char*)$pm+50
printf "GL_NATIVE_ENTRY args=%X point=%X value=%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$args,$point,*(unsigned long*)$point,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak *($target+2)
continue
if $pc!=$target+2 || $sp!=$args+4
 echo FAIL inverse return\n
 detach
 quit 1
end
printf "GL_NATIVE_RETURN sp=%X value=%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)$point,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/globallocal-native-after.bin (char*)$point-4 (char*)$point+8
echo PASS native original GlobalToLocal call\n
detach
quit 0
