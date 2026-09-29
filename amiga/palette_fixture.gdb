set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
echo ARM native palette CPU fixture\n
tbreak aitdPaletteInitial
continue
if $pc!=aitdPaletteInitial
 echo FAIL aitdPaletteInitial\n
 detach
 quit 1
end
set $source=*(unsigned long*)($sp+4)
set $sourcebody=*(unsigned long*)$source
printf "PALETTE_ENTER sp=%X args=%08X/%08X/%08X/%04X source=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),*(unsigned long*)($sp+8),*(unsigned short*)($sp+12),$source,$sourcebody,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "PALETTE_FIX_CODE data=%04X%04X%04X%04X%04X%04X%04X%04X\n",*(unsigned short*)($pc-14),*(unsigned short*)($pc-12),*(unsigned short*)($pc-10),*(unsigned short*)($pc-8),*(unsigned short*)($pc-6),*(unsigned short*)($pc-4),*(unsigned short*)($pc-2),*(unsigned short*)($pc+0)
set $dumpbody=*(unsigned long*)$source
dump binary memory ../tmp/palette-native-source.bin $dumpbody $dumpbody+2056
tbreak aitdPaletteInitialReturned
continue
if $pc!=aitdPaletteInitialReturned
 echo FAIL aitdPaletteInitialReturned\n
 detach
 quit 1
end
set $handle=*(unsigned long*)$sp
set $body=*(unsigned long*)$handle
set $private=*(unsigned long*)($body+12)
printf "PALETTE_RETURN sp=%X handle=%X body=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,$handle,$body,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
printf "PALETTE_PRIVATE handle=%X body=%X\n",$private,*(unsigned long*)$private
set $dumpbody=*(unsigned long*)$source
dump binary memory ../tmp/palette-native-source-after.bin $dumpbody $dumpbody+2056
tbreak aitdPaletteCase1
continue
if $pc!=aitdPaletteCase1
 echo FAIL aitdPaletteCase1\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",1,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase1Returned
continue
if $pc!=aitdPaletteCase1Returned
 echo FAIL aitdPaletteCase1Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=palette-size seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",1,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$handle
dump binary memory ../tmp/palette-native-body.bin $dumpbody $dumpbody+4112
tbreak aitdPaletteCase2
continue
if $pc!=aitdPaletteCase2
 echo FAIL aitdPaletteCase2\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",2,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase2Returned
continue
if $pc!=aitdPaletteCase2Returned
 echo FAIL aitdPaletteCase2Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=palette-state seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",2,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase3
continue
if $pc!=aitdPaletteCase3
 echo FAIL aitdPaletteCase3\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",3,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase3Returned
continue
if $pc!=aitdPaletteCase3Returned
 echo FAIL aitdPaletteCase3Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=source-size seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",3,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase4
continue
if $pc!=aitdPaletteCase4
 echo FAIL aitdPaletteCase4\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",4,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase4Returned
continue
if $pc!=aitdPaletteCase4Returned
 echo FAIL aitdPaletteCase4Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=source-state seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",4,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase5
continue
if $pc!=aitdPaletteCase5
 echo FAIL aitdPaletteCase5\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",5,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase5Returned
continue
if $pc!=aitdPaletteCase5Returned
 echo FAIL aitdPaletteCase5Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=private-size seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",5,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$private
dump binary memory ../tmp/palette-native-private.bin $dumpbody $dumpbody+4
tbreak aitdPaletteCase6
continue
if $pc!=aitdPaletteCase6
 echo FAIL aitdPaletteCase6\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",6,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase6Returned
continue
if $pc!=aitdPaletteCase6Returned
 echo FAIL aitdPaletteCase6Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=palette-attrs seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",6,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase7
continue
if $pc!=aitdPaletteCase7
 echo FAIL aitdPaletteCase7\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",7,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase7Returned
continue
if $pc!=aitdPaletteCase7Returned
 echo FAIL aitdPaletteCase7Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=mutate-source seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",7,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$source
dump binary memory ../tmp/palette-native-source-mutated.bin $dumpbody $dumpbody+2056
set $dumpbody=*(unsigned long*)$handle
dump binary memory ../tmp/palette-native-after-source.bin $dumpbody $dumpbody+4112
tbreak aitdPaletteCase8
continue
if $pc!=aitdPaletteCase8
 echo FAIL aitdPaletteCase8\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",8,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase8Returned
continue
if $pc!=aitdPaletteCase8Returned
 echo FAIL aitdPaletteCase8Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=mutate-palette seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",8,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$handle
dump binary memory ../tmp/palette-native-mutated.bin $dumpbody $dumpbody+4112
set $dumpbody=*(unsigned long*)$source
dump binary memory ../tmp/palette-native-source-after-palette.bin $dumpbody $dumpbody+2056
tbreak aitdPaletteCase9
continue
if $pc!=aitdPaletteCase9
 echo FAIL aitdPaletteCase9\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",9,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase9Returned
continue
if $pc!=aitdPaletteCase9Returned
 echo FAIL aitdPaletteCase9Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=dispose-palette seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",9,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase10
continue
if $pc!=aitdPaletteCase10
 echo FAIL aitdPaletteCase10\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",10,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase10Returned
continue
if $pc!=aitdPaletteCase10Returned
 echo FAIL aitdPaletteCase10Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=source-survives seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",10,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $dumpbody=*(unsigned long*)$source
dump binary memory ../tmp/palette-native-source-survives.bin $dumpbody $dumpbody+2056
tbreak aitdPaletteCase11
continue
if $pc!=aitdPaletteCase11
 echo FAIL aitdPaletteCase11\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",11,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase11Returned
continue
if $pc!=aitdPaletteCase11Returned
 echo FAIL aitdPaletteCase11Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=disposed-palette-size seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",11,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase12
continue
if $pc!=aitdPaletteCase12
 echo FAIL aitdPaletteCase12\n
 detach
 quit 1
end
printf "PALETTE_FIX_ENTER seq=%X trap=%X sp=%X args=%08X/%08X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",12,*(unsigned short*)$pc,$sp,*(unsigned long*)$sp,*(unsigned long*)($sp+4),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteCase12Returned
continue
if $pc!=aitdPaletteCase12Returned
 echo FAIL aitdPaletteCase12Returned\n
 detach
 quit 1
end
printf "PALETTE_FIX_RETURN label=disposed-private-size seq=%X sp=%X result=%X res=%X mem=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",12,$sp,*(unsigned long*)$sp,*(unsigned short*)(g_macLowMemory+140),*(unsigned short*)(g_macLowMemory+100),$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
tbreak aitdPaletteProbeDone
continue
if $pc!=aitdPaletteProbeDone
 echo FAIL aitdPaletteProbeDone\n
 detach
 quit 1
end
if *(unsigned short *)((unsigned long)_start+0x58)!=0x4eb9 || *(unsigned long *)((unsigned long)_start+0x5a)!=(unsigned long)main
 echo FAIL palette fixture CRT guard\n
 detach
 quit 1
end
tbreak *((unsigned long)_start+0x5e)
continue
if $pc!=(unsigned long)_start+0x5e || $d0!=0 || g_macLineAInstalled!=0 || g_resourceSourceOpen!=0 || g_overlaySourceOpen!=0 || g_applicationZoneBase!=0 || g_systemZoneBase!=0
 echo FAIL palette fixture shutdown\n
 detach
 quit 1
end
echo PASS NewPalette ownership fixture calls=C\n
echo PASS native palette CPU fixture shutdown zones=0 sources=0/0 lineA=0 result=0\n
detach
quit 0
