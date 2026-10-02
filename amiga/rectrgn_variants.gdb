# REGIONPROBE=1. Seven CPU-executed RectRgn cases paired with Macintosh.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL RectRgn fixture: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
set $case=1
while $case<=7
 tbreak aitdRectRegionEnter
 continue
 if $pc!=aitdRectRegionEnter || $d2!=$case || *(unsigned short*)$pc!=0xa8df
  echo FAIL RectRgn fixture entry\n
  detach
  quit 1
 end
 set $args=$sp
 set $rect=*(unsigned long*)$args
 set $handle=*(unsigned long*)($args+4)
 set $body=*(unsigned long*)$handle
 set $length=$d3
 printf "RECT_VARIANT_ENTER n=%u sp=%X handle=%X body=%X rect=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$case,$sp,$handle,*(unsigned long*)$handle,$rect,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/rectrgn-variants-native-case%u-enter-region.bin $body $body+$length",$case
 eval "dump binary memory ../tmp/rectrgn-variants-native-case%u-enter-rect.bin $rect-4 $rect-4+16",$case
 tbreak aitdRectRegionReturn
 continue
 if $pc!=aitdRectRegionReturn
  echo FAIL RectRgn fixture return\n
  detach
  quit 1
 end
 set $length=10
 printf "RECT_VARIANT_RETURN n=%u sp=%X handle=%X body=%X rect=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$case,$sp,$handle,*(unsigned long*)$handle,$rect,s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/rectrgn-variants-native-case%u-return-region.bin $body $body+$length",$case
 eval "dump binary memory ../tmp/rectrgn-variants-native-case%u-return-rect.bin $rect-4 $rect-4+16",$case
 tbreak aitdRectRegionSize
 continue
 printf "RECT_VARIANT_SIZE n=%u size=%X memerr=%X\n",$case,$d0,s_memoryError
 tbreak aitdRectRegionFlags
 continue
 printf "RECT_VARIANT_FLAGS n=%u flags=%X memerr=%X\n",$case,$d0&255,s_memoryError
 tbreak aitdRectRegionOwner
 continue
 printf "RECT_VARIANT_OWNER n=%u owner=%X zone=%X memerr=%X\n",$case,$a0,(unsigned long)s_applicationZone.arena_,s_memoryError
 set $case=$case+1
end
tbreak aitdRectRegionComplete
continue
if $pc!=aitdRectRegionComplete || s_memoryError!=0
 echo FAIL RectRgn fixture completion\n
 detach
 quit 1
end
echo PASS native RectRgn variants cases=7\n
detach
quit 0
