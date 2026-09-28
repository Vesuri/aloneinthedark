# At the current loader stop, all startup operands must resolve inside A5 shadows.
set pagination off
set confirm off
break AitdScreen::showLoudStop
continue
if g_startupLowMemoryPatches != 10 || g_macLowMemory == 0 || g_startupCode == 0
  echo startup-lowmem FAIL: missing patches or storage\n
  detach
  quit 1
end
set $aitd_a5=*(unsigned long *)(g_macLowMemory+32)
printf "startup-lowmem addresses A5=$%08x shadows=$%08x CurStackBase=$%08x\n",$aitd_a5,g_macLowMemory,*(unsigned long *)(g_macLowMemory+52)
if $aitd_a5+3776 != (unsigned long)g_macLowMemory || $aitd_a5-*(unsigned long *)(g_macLowMemory+52) != 75616
  echo startup-lowmem FAIL: shadow allocation/layout\n
  detach
  quit 1
end
define check_startup_site
  set $site=g_startupCode+$arg0
  if (*(unsigned short *)$site & 63) != 45 || *(unsigned short *)($site+$arg1-2) != 3776+$arg2
    printf "startup-lowmem FAIL: CODE 1+$%04x\n",$arg0
    detach
    quit 1
  end
end
check_startup_site 0x14 4 56
check_startup_site 0x48 4 32
check_startup_site 0x6a 4 60
check_startup_site 0xbe 4 59
check_startup_site 0xf4 4 60
check_startup_site 0x118 4 60
check_startup_site 0x13a 4 52
check_startup_site 0x246 6 58
check_startup_site 0x254 6 58
check_startup_site 0x29c 4 64
if g_macLowMemory[58] != 3 || g_macLowMemory[59] != 0 || *(unsigned long *)(g_macLowMemory+64) != 0xffffffff
  echo startup-lowmem FAIL: startup values\n
  detach
  quit 1
end
printf "startup-lowmem PASS: sites=10 A5=$%08x shadows=$%08x CPUFlag=3 LoadTrap=0\n",$aitd_a5,g_macLowMemory
detach
quit 0
