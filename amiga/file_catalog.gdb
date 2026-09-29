# Production observer; byte-check the original callers, then inspect real returns.
set pagination off
set confirm off
source .run/startup-state.gdb
set $catalog_fcb=0
set $catalog_wd=0
set $catalog_setvol=0
set $catalog_getvol=0
set $catalog_restore_name=0
set $catalog_folder=0
break AitdScreen::showLoudStop
commands
 silent
 if $catalog_fcb != 1 || $catalog_wd != 4 || $catalog_setvol != 4 || $catalog_getvol != 1 || $catalog_folder != 1 || g_stageBState != 3 || g_trapWord!=0xa880 || g_trapSegment!=4 || g_trapOffset!=0x4f88 || *(unsigned long*)(g_trapRoutine+0)!=0x53455450 || g_trapRoutine[4]!=0x54 || g_trapRoutine[5]!=0 || g_trapSelector!=-1 || g_macServiceEntered != $startup_entered || g_macServiceCompleted != $startup_completed || g_systemWindows != $startup_windows || g_resourceRuntimeReads != 39 || g_resourceRuntimeBytes != 177820
  printf "FAIL file-catalog: FCB=%u WD=%u next=%s/%s\n",$catalog_fcb,$catalog_wd,g_trapManager,g_trapRoutine
  detach
  quit 1
 end
 printf "PASS file-catalog: entries=%u data-files=%u data-bytes=%u FCB=1 OpenWD=3 missing-movies=1 SetVol=4 GetVol=1 FindFolder=1 windows=%u next=SETPT\n",g_catalogEntries,g_catalogDataFiles,g_catalogDataBytes,g_systemWindows
 detach
 quit 0
end
printf "CATALOG measured entries=%u data-files=%u data-bytes=%u application-ref=%d expected-entries=%u\n",g_catalogEntries,g_catalogDataFiles,g_catalogDataBytes,g_applicationFileRef,$startup_catalog
if g_catalogEntries != $startup_catalog || g_catalogDataFiles != 33 || g_catalogDataBytes != 5584424 || g_applicationFileRef <= 0
 echo FAIL file-catalog: original metadata totals\n
 detach
 quit 1
end
tbreak *(g_startupCode+0xaa)
continue
if *(unsigned long *)(g_code3Base+0x403e)!=0xa0143d40 || *(unsigned long *)(g_code3Base+0x4142) != 0x7008a260 || *(unsigned long *)(g_code3Base+0x40dc) != 0x7001a260 || *(unsigned short *)(g_code3Base+0x4066) != 0xa015 || *(unsigned long*)(g_code3Base+0x4354) != 0x7000a823
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
 set $path=*(unsigned char**)($pb+18)
 set $expected_dir=3
 set $expected_volume=0
 set $path_ok=0
 if $catalog_wd == 0 && $path == 0
  set $path_ok=1
 end
 if $catalog_wd == 1 && $path != 0
  if *$path == 12 && *(unsigned long*)($path+1) == 0x3a416c6f && *(unsigned long*)($path+5) == 0x6e652044 && *(unsigned long*)($path+9) == 0x6174613a
   set $path_ok=1
  end
 end
 if $catalog_wd == 2 && $path == 0
  set $path_ok=1
  set $expected_dir=5
  set $expected_volume=-1
 end
 if $catalog_wd == 3 && $path != 0
  if *$path == 14 && *(unsigned long*)($path+1) == 0x3a416c6f && *(unsigned long*)($path+5) == 0x6e65204d && *(unsigned long*)($path+9) == 0x6f766965 && *(unsigned short*)($path+13) == 0x733a
   set $path_ok=1
  end
 end
 if $path_ok != 1 || *(short*)($pb+22) != $expected_volume || *(unsigned long*)($pb+48) != $expected_dir
  echo FAIL file-catalog: original OpenWD request\n
  detach
  quit 1
 end
 continue
end
break *(g_code3Base+0x40e0)
commands
 silent
 set $pb=(unsigned char*)$a0
 set $expected_ref=-31999+$catalog_wd
 if $catalog_wd == 0
  set $expected_ref=-32000
 end
 set $expected_error=0
 if $catalog_wd == 3
  set $expected_ref=0
  set $expected_error=-43
 end
 if (short)$d0 != $expected_error || *(short*)($pb+16) != $expected_error || *(short*)($pb+22) != $expected_ref || *(unsigned long*)($pb+48) != $expected_dir
  echo FAIL file-catalog: OpenWD result\n
  detach
  quit 1
 end
 if $catalog_wd < 3 && *(short*)($pb+24) != ($catalog_wd != 0)
  echo FAIL file-catalog: new WD flag\n
  detach
  quit 1
 end
 set $catalog_wd=$catalog_wd+1
 continue
end
# Original preferences setup saves and restores the default directory by name/WD.
break *(g_code3Base+0x4040)
commands
 silent
 set $pb=(unsigned char*)$a0
 set $catalog_restore_name=*(unsigned char**)($pb+18)
 if $d0!=0 || *(short*)($pb+16)!=0 || *(short*)($pb+22)!=-32000 || $catalog_restore_name==0
  echo FAIL file-catalog: original GetVol result\n
  detach
  quit 1
 end
 if *(unsigned long*)$catalog_restore_name!=0x05416c6f || *(unsigned short*)($catalog_restore_name+4)!=0x6e65
  echo FAIL file-catalog: original GetVol volume name\n
  detach
  quit 1
 end
 set $catalog_getvol=$catalog_getvol+1
 continue
end
break *(g_code3Base+0x4066)
commands
 silent
 set $pb=(unsigned char*)$a0
 set $setvol_ref=-32000
 set $setvol_name=0
 if $catalog_setvol==2
  set $setvol_ref=-31997
 end
 if $catalog_setvol==3
  set $setvol_name=$catalog_restore_name
 end
 if $catalog_setvol>3 || *(unsigned long*)($pb+18)!=$setvol_name || *(short*)($pb+22)!=$setvol_ref || ($catalog_setvol==3 && $catalog_getvol!=1)
  printf "FAIL file-catalog: original SetVol call=%u ref=%d name=%x\n",$catalog_setvol,*(short*)($pb+22),*(unsigned long*)($pb+18)
  detach
  quit 1
 end

 continue
end
break *(g_code3Base+0x4068)
commands
 silent
 if $d0 != 0 || *(short*)((unsigned char*)$a0+16) != 0
  echo FAIL file-catalog: SetVol result\n
  detach
  quit 1
 end
 set $catalog_setvol=$catalog_setvol+1
 continue
end
break *(g_code3Base+0x4356)
commands
 silent
 if $d0 != 0 || *(unsigned long*)($sp+10) != 0x70726566 || *(unsigned short*)($sp+14) != 0x8000 || *(unsigned char*)($sp+8) != 1
  echo FAIL file-catalog: original FindFolder request\n
  detach
  quit 1
 end
 set $folder_sp=$sp
 set $folder_dir=*(unsigned long*)$sp
 set $folder_vol=*(unsigned long*)($sp+4)
 continue
end
break *(g_code3Base+0x4358)
commands
 silent
 if $sp != $folder_sp+16 || *(short*)$sp != 0 || *(short*)$folder_vol != -1 || *(unsigned long*)$folder_dir != 5
  echo FAIL file-catalog: FindFolder result or stack cleanup\n
  detach
  quit 1
 end
 set $catalog_folder=$catalog_folder+1
 continue
end
continue
echo FAIL file-catalog: unexpected stop\n
detach
quit 1
