# Production observer: check original SysEnvirons, Gestalt and derived flags.
set pagination off
set confirm off
set $id_calls=0
set $id_flags=0
break AitdScreen::showLoudStop
commands
 silent
 if g_stageBState != 3 || g_trapWord!=0xab1d || g_trapSegment!=10 || g_trapOffset!=0x74 || *(unsigned long*)(g_trapRoutine+0)!=0x4e455747 || *(unsigned long*)(g_trapRoutine+4)!=0x574f524c || g_trapRoutine[8]!=0x44 || g_trapRoutine[9]!=0 || g_trapSelector!=0 || $id_calls != 8 || $id_flags != 1
  printf "identity FAIL: calls=%u flags=%u %s / %s\n",$id_calls,$id_flags,g_trapManager,g_trapRoutine
  detach
  quit 1
 end
 printf "PASS identity: SysEnvRec=16 Gestalt=8 Engine-flags=11 next=NEWGWORLD\n"
 detach
 quit 0
end
tbreak *(g_startupCode+0xaa)
continue
if *(unsigned long *)(g_code3Base+0x3bce) != 0xa0903f40 || *(unsigned long *)(g_code3Base+0x3d36) != 0xa1ad226e
 echo identity FAIL: original trap bytes\n
 detach
 quit 1
end
tbreak *(g_code3Base+0x3bd0)
continue
if $d0 != 0 || *(unsigned long *)$a0 != 0x00010005 || *(unsigned long *)($a0+4) != 0x07550004 || *(unsigned long *)($a0+8) != 0x01010005 || *(unsigned long *)($a0+12) != 0x003a8053 || *(unsigned short *)(g_macLowMemory+84) != 0x755
 echo identity FAIL: SysEnvirons or SysVersion\n
 detach
 quit 1
end
if *(unsigned short *)(s_segments[7].begin+0x43e2) != 0x4a47
 echo identity FAIL: original Engine flags boundary\n
 detach
 quit 1
end
break *(s_segments[7].begin+0x43e2)
commands
 silent
 set $id_object=*(unsigned long *)$a4
 if ($d7 & 65535) != 0 || *(unsigned long *)($id_object+4) != 0x01010101 || *(unsigned long *)($id_object+8) != 0x01010100 || *(unsigned short *)($id_object+12) != 0x0101 || *(unsigned char *)($id_object+14) != 1
  echo identity FAIL: original derived capabilities\n
  x/16bx $id_object
  detach
  quit 1
 end
 set $id_flags=1
 continue
end
break *(g_code3Base+0x3d36)
commands
 silent
 set $id_expected=-1
 set $id_error=0
 if $id_calls == 0 && $d0 == 0x73797376
  set $id_expected=0x755
 end
 if $id_calls == 1 && $d0 == 0x70726f63
  set $id_expected=4
 end
 if $id_calls == 2 && $d0 == 0x71642020
  set $id_expected=0x230
 end
 if $id_calls == 7 && $d0 == 0x612f7578
  set $id_expected=0
  set $id_error=0xea52
 end
 if ($id_calls == 3 && $d0 == 0x68656c70) || ($id_calls == 4 && $d0 == 0x666f6c64) || ($id_calls == 5 && $d0 == 0x65766e74) || ($id_calls == 6 && $d0 == 0x666f6c64)
  set $id_expected=1
 end
 continue
end
break *(g_code3Base+0x3d38)
commands
 silent
 if $id_expected == -1 || $d0 != $id_error || (unsigned long)$a0 != $id_expected
  printf "identity FAIL: Gestalt call=%u D0=$%x A0=$%x expected=$%x\n",$id_calls,$d0,$a0,$id_expected
  detach
  quit 1
 end
 set $id_calls=$id_calls+1
 continue
end
continue
echo identity FAIL: unexpected debugger stop\n
detach
quit 1
