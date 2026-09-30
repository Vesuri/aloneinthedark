set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x8e
continue
set $world=*(unsigned long*)(userStack+4)
set $code=(unsigned long)s_segments[10].begin
set $pmh=*(unsigned long*)($world+2)
set $pixelh=*(unsigned long*)*(unsigned long*)$pmh
dump binary memory ../tmp/gworld-init-native-original-code.bin (char*)$code+0x76 (char*)$code+0x116
dump binary memory ../tmp/gworld-init-native-screen-before.bin (char*)s_colorScreen (char*)s_colorScreen+307200
set $spx=(unsigned long)userStack
printf "GWINIT offset=8E phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-08e-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-08e-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-08e-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-08e-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-08e-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-08e-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-08e-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0x90)
continue
if $pc!=$code+0x90
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=8E phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-08e-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-08e-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-08e-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-08e-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-08e-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-08e-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-08e-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x98
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=98 phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-098-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-098-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-098-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-098-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-098-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-098-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-098-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0x9a)
continue
if $pc!=$code+0x9a
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=98 phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-098-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-098-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-098-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-098-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-098-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-098-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-098-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0xa8
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=A8 phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0a8-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0a8-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0a8-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0a8-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0a8-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0a8-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0a8-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0xaa)
continue
if $pc!=$code+0xaa
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=A8 phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0a8-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0a8-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0a8-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0a8-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0a8-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0a8-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0a8-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0xb0
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=B0 phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0b0-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0b0-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0b0-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0b0-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0b0-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0b0-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0b0-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0xb2)
continue
if $pc!=$code+0xb2
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=B0 phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0b0-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0b0-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0b0-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0b0-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0b0-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0b0-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0b0-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0xbe
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=BE phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0be-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0be-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0be-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0be-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0be-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0be-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0be-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0xc0)
continue
if $pc!=$code+0xc0
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=BE phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0be-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0be-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0be-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0be-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0be-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0be-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0be-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0xcc
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=CC phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0cc-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0cc-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0cc-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0cc-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0cc-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0cc-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0cc-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0xce)
continue
if $pc!=$code+0xce
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=CC phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0cc-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0cc-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0cc-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0cc-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0cc-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0cc-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0cc-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0xd4
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=D4 phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0d4-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0d4-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0d4-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0d4-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0d4-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0d4-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0d4-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0xd6)
continue
if $pc!=$code+0xd6
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=D4 phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-0d4-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-0d4-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-0d4-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-0d4-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-0d4-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-0d4-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-0d4-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
tbreak dispatchMacTrap if *(unsigned long*)(frame+2)==(unsigned long)s_segments[10].begin+0x114
continue
set $spx=(unsigned long)userStack
printf "GWINIT offset=114 phase=before sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,regs[0],regs[1],regs[2],regs[3],regs[4],regs[5],regs[6],regs[7],regs[8],regs[9],regs[10],regs[11],regs[12],regs[13],regs[14]
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-114-before-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-114-before-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-114-before-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-114-before-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-114-before-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-114-before-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-114-before-pixels.bin $dumpaddr $dumpaddr+261452
tbreak *($code+0x116)
continue
if $pc!=$code+0x116
 echo FAIL GWorld initialization return\n
 detach
 quit 1
end
set $spx=$sp
printf "GWINIT offset=114 phase=after sp=%X world=%X pmh=%X pixelh=%X currentPort=%X D0=%X D1=%X D2=%X D3=%X D4=%X D5=%X D6=%X D7=%X A0=%X A1=%X A2=%X A3=%X A4=%X A5=%X A6=%X\n",$spx,$world,$pmh,$pixelh,*(unsigned long*)s_qdThePort,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
set $pm=*(unsigned long*)$pmh
set $gd=*(unsigned long*)(*(unsigned long*)*(unsigned long*)($world+8)+26)
set $clip=*(unsigned long*)*(unsigned long*)($world+28)
set $dumpaddr=(unsigned long)($spx)
dump binary memory ../tmp/gworld-init-native-114-after-stack.bin $dumpaddr $dumpaddr+32
set $dumpaddr=(unsigned long)($world)
dump binary memory ../tmp/gworld-init-native-114-after-port.bin $dumpaddr $dumpaddr+108
set $dumpaddr=(unsigned long)($pm)
dump binary memory ../tmp/gworld-init-native-114-after-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)(*(unsigned long*)$gd)
dump binary memory ../tmp/gworld-init-native-114-after-device.bin $dumpaddr $dumpaddr+62
set $dumpaddr=(unsigned long)(*(unsigned long*)*(unsigned long*)(*(unsigned long*)$gd+22))
dump binary memory ../tmp/gworld-init-native-114-after-device-pm.bin $dumpaddr $dumpaddr+50
set $dumpaddr=(unsigned long)($clip)
dump binary memory ../tmp/gworld-init-native-114-after-clip.bin $dumpaddr $dumpaddr+10
set $dumpaddr=(unsigned long)(*(unsigned long*)$pixelh)
dump binary memory ../tmp/gworld-init-native-114-after-pixels.bin $dumpaddr $dumpaddr+261452
printf "GWLOCK state=%X\n",*(unsigned char*)((unsigned long)s_gworlds[0].owner->arena_+*(unsigned long*)(*(unsigned long*)$pixelh-8))
dump binary memory ../tmp/gworld-init-native-screen-after.bin (char*)s_colorScreen (char*)s_colorScreen+307200
echo PASS native offscreen initialization\n
continue
printf "GWINIT_NEXT trap=%X selector=%X segment=%u offset=%X manager=%s routine=%s\n",g_trapWord,g_trapSelector,g_trapSegment,g_trapOffset,g_trapManager,g_trapRoutine
if g_stageBState!=3 || g_trapWord!=0xab1d || g_trapSelector!=0 || g_trapSegment!=13 || g_trapOffset!=0x234 || g_macServiceActive!=0
 echo FAIL offscreen progression\n
 detach
 quit 1
end
set $i=0
while $i<g_resourceCount
 if s_resourceForks.m_items[$i].item.type==0x4d445256 && s_resourceHandles[$i]!=0
  echo FAIL original MDRV resident\n
  detach
  quit 1
 end
 set $i=$i+1
end
detach
quit 0
