# BLOCKMOVEPROBE=1; executes the host cases through the real native copy helper.
set pagination off
set confirm off
break aitdBlockMoveProbeComplete
continue
if g_blockMoveChecks!=28388
 printf "FAIL BlockMove checks=%u\n",g_blockMoveChecks
 detach
 quit 1
end
printf "PASS BlockMove checks=%u: overlap, alignment, lengths and canaries\n",g_blockMoveChecks
detach
quit 0
