set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
tbreak dispatchMacTrap if trap==0xaa46 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x1272
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
printf "GEOM_ENTER id=%X site=%X opcode=%X sp=%X behind=%X storage=%X result=%X\n",*(unsigned short*)($args+8),0x1272,*(unsigned short*)($misc+0x1272),$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+10)
tbreak *($misc+0x1274)
continue
if $pc!=$misc+0x1274
 echo FAIL constructor return\n
 detach
 quit 1
end
set $window=*(unsigned long*)$sp
set $pm=*(unsigned long*)*(unsigned long*)($window+2)
printf "GEOM_RETURN id=83 sp=%X expected=%X window=%X pm=%X kind=%X visible=%X next=%X\n",$sp,$args+10,$window,$pm,*(unsigned short*)($window+108),*(unsigned char*)($window+110),*(unsigned long*)($window+144)
dump binary memory ../tmp/window-geometry-native-131-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/window-geometry-native-131-pm.bin (char*)$pm (char*)$pm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/window-geometry-native-131-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/window-geometry-native-131-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/window-geometry-native-131-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/window-geometry-native-131-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/window-geometry-native-131-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
tbreak dispatchMacTrap if trap==0xaa46 && *(unsigned long*)(frame+2)==(unsigned long)s_segments[9].begin+0x109a
continue
set $misc=s_segments[9].begin
set $args=(unsigned long)userStack
printf "GEOM_ENTER id=%X site=%X opcode=%X sp=%X behind=%X storage=%X result=%X\n",*(unsigned short*)($args+8),0x109a,*(unsigned short*)($misc+0x109a),$args,*(unsigned long*)$args,*(unsigned long*)($args+4),*(unsigned long*)($args+10)
tbreak *($misc+0x109c)
continue
if $pc!=$misc+0x109c
 echo FAIL constructor return\n
 detach
 quit 1
end
set $window=*(unsigned long*)$sp
set $pm=*(unsigned long*)*(unsigned long*)($window+2)
printf "GEOM_RETURN id=80 sp=%X expected=%X window=%X pm=%X kind=%X visible=%X next=%X\n",$sp,$args+10,$window,$pm,*(unsigned short*)($window+108),*(unsigned char*)($window+110),*(unsigned long*)($window+144)
dump binary memory ../tmp/window-geometry-native-128-window.bin (char*)$window (char*)$window+156
dump binary memory ../tmp/window-geometry-native-128-pm.bin (char*)$pm (char*)$pm+50
set $region=*(unsigned long*)*(unsigned long*)($window+24)
dump binary memory ../tmp/window-geometry-native-128-visibility.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+28)
dump binary memory ../tmp/window-geometry-native-128-clip.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+114)
dump binary memory ../tmp/window-geometry-native-128-structure.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+118)
dump binary memory ../tmp/window-geometry-native-128-content.bin (char*)$region (char*)$region+*(unsigned short*)$region
set $region=*(unsigned long*)*(unsigned long*)($window+122)
dump binary memory ../tmp/window-geometry-native-128-update.bin (char*)$region (char*)$region+*(unsigned short*)$region
echo PASS native colour-window geometry capture calls=2\n
detach
quit 0
