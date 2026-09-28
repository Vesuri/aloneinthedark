# Check live CODE patches and VBI publication after the bounded startup stop.
set pagination off
set confirm off
break AitdScreen::showLoudStop
continue
if g_lowMemoryValidatedSites != 58 || g_lowMemoryAppliedSites != 50 || g_loadedCodeMask != 0x8b
 echo lowmem FAIL: missing validation or loaded CODE patches\n
 detach
 quit 1
end
set $lm_a5=*(unsigned long *)(g_macLowMemory+32)
if (unsigned long)g_macLowMemory != $lm_a5+3776 || (unsigned long)g_macTicksAddress != (unsigned long)g_macLowMemory
 echo lowmem FAIL: shadow/Ticks pointers\n
 detach
 quit 1
end
# Source EA, immediate+EA, reversed MOVE destination EA, and trailing operand.
if *(unsigned long *)(g_code3Base+0x4290) != 0x3b400f50 || *(unsigned long *)(g_code3Base+0x3cbc) != 0x336d0f1c || *(unsigned short *)(g_code3Base+0x3cbc+4) != 14 || *(unsigned long *)(g_code3Base+0x2de6+2) != 0x00020efa
 echo lowmem FAIL: live Core instruction encoding\n
 detach
 quit 1
end
# Engine's $16C word must alias the low half of the $16A long.
if *(unsigned long *)(s_segments[7].begin+0x4a22) != 0x302d0ec2
 echo lowmem FAIL: Ticks word alias\n
 detach
 quit 1
end
tbreak vbiHandler
continue
finish
set $lm_fields=g_vbiCount
set $lm_ticks=g_macTicks
break vbiHandler
ignore $bpnum 9
continue
finish
if (unsigned short)(g_vbiCount-$lm_fields) != 10 || g_macTicks-$lm_ticks != 12 || *g_macTicksAddress != g_macTicks
 echo lowmem FAIL: VBI Ticks publication\n
 detach
 quit 1
end
printf "lowmem PASS: validated=58 applied=50 fields=10 ticks=12 shadow=$%08x\n",g_macLowMemory
detach
quit 0
