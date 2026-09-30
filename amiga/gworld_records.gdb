set $world=*(unsigned long*)$out
set $slot=0
while $slot<8 && s_gworlds[$slot].port!=(unsigned char*)$world
 set $slot=$slot+1
end
if $slot==8
 echo FAIL NewGWorld registry\n
 detach
 quit 1
end
set $pm=*(unsigned long*)*(unsigned long*)($world+2)
set $table=*(unsigned long*)*(unsigned long*)($pm+42)
set $zone=(unsigned long)s_gworlds[$slot].owner->arena_
printf "GW_RETURN sp=%X result=%X world=%X pmHandle=%X pm=%X clutHandle=%X clut=%X base=%X baseLong=%X zone=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$sp,*(unsigned short*)$sp,$world,*(unsigned long*)($world+2),$pm,*(unsigned long*)($pm+42),$table,*(unsigned long*)$pm,*(unsigned long*)*(unsigned long*)$pm,$zone,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
dump binary memory ../tmp/gworld-native-port.bin (char*)$world (char*)$world+108
dump binary memory ../tmp/gworld-native-pm.bin (char*)$pm (char*)$pm+50
dump binary memory ../tmp/gworld-native-clut.bin (char*)$table (char*)$table+2056
dump binary memory ../tmp/gworld-native-after-device.bin (char*)s_mainDevice (char*)s_mainDevice+62
dump binary memory ../tmp/gworld-native-after-pixels.bin (char*)s_colorScreen (char*)s_colorScreen+307200
dump binary memory ../tmp/gworld-native-heap.bin (char*)$zone (char*)$zone+s_gworlds[$slot].owner->bytes_
set $h=(unsigned long)s_gworlds[$slot].handles[0]
set $body=*(unsigned long*)$h
printf "GW_AUX label=pixmap handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-pixmap.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[1]
set $body=*(unsigned long*)$h
printf "GW_AUX label=pixels handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-pixels.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[2]
set $body=*(unsigned long*)$h
printf "GW_AUX label=ctable handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-ctable.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[3]
set $body=*(unsigned long*)$h
printf "GW_AUX label=visibility handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-visibility.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[4]
set $body=*(unsigned long*)$h
printf "GW_AUX label=clip handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-clip.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[5]
set $body=*(unsigned long*)$h
printf "GW_AUX label=grafvars handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-grafvars.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[6]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[7]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[8]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[9]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat-map handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat-map.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[10]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat-data handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat-data.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[11]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat-xdata handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat-xdata.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[12]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat-xmap handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat-xmap.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[13]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat-map handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat-map.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[14]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat-data handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat-data.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[15]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat-xdata handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat-xdata.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[16]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat-xmap handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat-xmap.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[17]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat-map handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat-map.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[18]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat-data handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat-data.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[19]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat-xdata handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat-xdata.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[20]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat-xmap handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat-xmap.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[21]
set $body=*(unsigned long*)$h
printf "GW_AUX label=grafvars-child handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-grafvars-child.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[22]
set $body=*(unsigned long*)$h
printf "GW_AUX label=backpat-table handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-backpat-table.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[23]
set $body=*(unsigned long*)$h
printf "GW_AUX label=penpat-table handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-penpat-table.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[24]
set $body=*(unsigned long*)$h
printf "GW_AUX label=fillpat-table handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-fillpat-table.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[25]
set $body=*(unsigned long*)$h
printf "GW_AUX label=device-map handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-device-map.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
set $h=(unsigned long)s_gworlds[$slot].handles[26]
set $body=*(unsigned long*)$h
printf "GW_AUX label=device-inverse handle=%X body=%X size=%X owner=%X kind=%X\n",$h,$body,*(unsigned long*)($body-20),*(unsigned long*)($body-16),*(unsigned long*)($body-12)
dump binary memory ../tmp/gworld-native-aux-device-inverse.bin (char*)$body (char*)$body+*(unsigned long*)($body-20)
