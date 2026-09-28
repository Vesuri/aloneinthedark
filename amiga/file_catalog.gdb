# Production observer; byte-check the original callers, then inspect real returns.
set pagination off
set confirm off
set $catalog_fcb=0
set $catalog_wd=0
break AitdScreen::showLoudStop
commands
 silent
 if $catalog_fcb != 1 || $catalog_wd != 1 || g_trapWord != 0xa015 || g_trapSegment != 3 || g_trapOffset != 0x4066 || g_macServiceEntered != 2 || g_macServiceCompleted != 2 || g_systemWindows != 0
  printf "FAIL file-catalog: FCB=%u WD=%u next=%s/%s\n",$catalog_fcb,$catalog_wd,g_trapManager,g_trapRoutine
  detach
  quit 1
 end
 if *(short*)((unsigned char*)g_trapRegisters[8]+22) != $catalog_ref
  echo FAIL file-catalog: original SetVol must use returned WD reference\n
  detach
  quit 1
 end
 printf "PASS file-catalog: entries=%u data-files=%u data-bytes=%u FCB=1 OpenWD=1 windows=%u next=SETVOL\n",g_catalogEntries,g_catalogDataFiles,g_catalogDataBytes,g_systemWindows
 detach
 quit 0
end
if g_catalogEntries != 39 || g_catalogDataFiles != 32 || g_catalogDataBytes != 5315994 || g_applicationFileRef <= 0
 echo FAIL file-catalog: original metadata totals\n
 detach
 quit 1
end
tbreak *(g_startupCode+0xaa)
continue
if *(unsigned long *)(g_code3Base+0x4142) != 0x7008a260 || *(unsigned long *)(g_code3Base+0x40dc) != 0x7001a260 || *(unsigned short *)(g_code3Base+0x4066) != 0xa015
 echo FAIL file-catalog: original trap bytes\n
 detach
 quit 1
end
break *(g_code3Base+0x4146)
commands
 silent
 set $pb=(unsigned char*)$a0
 if $d0 != 0 || *(short*)($pb+16) != 0 || *(short*)($pb+24) != g_applicationFileRef || *(short*)($pb+28) != 0 || *(unsigned long*)($pb+32) != 8 || *(unsigned short*)($pb+36) != 0x300 || *(unsigned long*)($pb+40) != 1424934 || *(short*)($pb+52) != -1 || *(unsigned long*)($pb+58) != 3 || *(short*)(g_macLowMemory+132) != g_applicationFileRef
  echo FAIL file-catalog: application FCB result\n
  detach
  quit 1
 end
 # Engine+$409A is the original CurResFile. Its result is stored at +$74.
 if *(unsigned short*)(s_segments[7].begin+0x409a) != 0xa994 || *(short*)(*(unsigned long*)$a4+0x72) != g_applicationFileRef || *(short*)(*(unsigned long*)$a4+0x74) != g_applicationFileRef
  echo FAIL file-catalog: original application/current resource identities\n
  detach
  quit 1
 end
 set $name=*(unsigned char**)($pb+18)
 if *$name != 17 || *(unsigned long*)($name+1) != 0x416c6f6e || *(unsigned long*)($name+5) != 0x6520496e || *(unsigned long*)($name+9) != 0x20546865 || *(unsigned long*)($name+13) != 0x20446172 || *($name+17) != 0x6b
  echo FAIL file-catalog: Pascal application name\n
  detach
  quit 1
 end
 set $catalog_fcb=$catalog_fcb+1
 dump binary memory ../tmp/amiga-fcb-result.bin $pb $pb+80
 continue
end
break *(g_code3Base+0x40de)
commands
 silent
 set $pb=(unsigned char*)$a0
 if *(unsigned long*)($pb+18) != 0 || *(short*)($pb+22) != 0 || *(unsigned long*)($pb+48) != 3
  echo FAIL file-catalog: original application OpenWD request\n
  detach
  quit 1
 end
 continue
end
break *(g_code3Base+0x40e0)
commands
 silent
 set $pb=(unsigned char*)$a0
 set $catalog_ref=*(short*)($pb+22)
 if $d0 != 0 || *(short*)($pb+16) != 0 || $catalog_ref != -32000 || *(short*)($pb+24) != 1 || *(unsigned long*)($pb+48) != 3
  echo FAIL file-catalog: OpenWD result\n
  detach
  quit 1
 end
 set $catalog_wd=$catalog_wd+1
 dump binary memory ../tmp/amiga-wd-result.bin $pb $pb+80
 continue
end
continue
echo FAIL file-catalog: unexpected stop\n
detach
quit 1
