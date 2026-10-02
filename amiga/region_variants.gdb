# REGIONPROBE=1. Original-measured shapes executed through native Line-A.
set pagination off
set confirm off
set width 0
break AitdScreen::showLoudStop
commands
 silent
 printf "FAIL region fixture: %s / %s selector=%u\n",manager,routine,selector
 detach
 quit 1
end
set $case=1
while $case<=6
 tbreak aitdRegionEmptyEnter
 continue
 if $pc!=aitdRegionEmptyEnter || $d2!=$case || *(unsigned short*)$pc!=0xa8e2
  echo FAIL EmptyRgn fixture entry\n
  detach
  quit 1
 end
 set $args=$sp
 set $handle=*(unsigned long*)$args
 set $body=*(unsigned long*)$handle
 set $call=$pc
 printf "EMPTY_VARIANT_ENTER n=%u sp=%X handle=%X body=%X call=%X result=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$case,$sp,$handle,*(unsigned long*)$handle,$call,*(unsigned short*)($args+4),s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/emptyrgn-variants-native-case%u-enter.bin $body $body+64",$case
 tbreak aitdRegionEmptyReturn
 continue
 if $pc!=aitdRegionEmptyReturn
  echo FAIL EmptyRgn fixture return\n
  detach
  quit 1
 end
 printf "EMPTY_VARIANT_RETURN n=%u sp=%X handle=%X body=%X call=%X result=%X memerr=%X d0=%X d1=%X d2=%X d3=%X d4=%X d5=%X d6=%X d7=%X a0=%X a1=%X a2=%X a3=%X a4=%X a5=%X a6=%X\n",$case,$sp,$handle,*(unsigned long*)$handle,$call,*(unsigned short*)($args+4),s_memoryError,$d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7,$a0,$a1,$a2,$a3,$a4,$a5,$a6
 eval "dump binary memory ../tmp/emptyrgn-variants-native-case%u-return.bin $body $body+64",$case
 set $case=$case+1
end
tbreak aitdRegionProbeComplete
continue
if $pc!=aitdRegionProbeComplete || s_memoryError!=0
 echo FAIL region fixture disposal\n
 detach
 quit 1
end
echo PASS native EmptyRgn variants cases=6\n
detach
quit 0
