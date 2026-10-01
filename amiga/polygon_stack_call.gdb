# At the encoder's first instruction. Decode its checked compiled prologue,
# including saved registers, rather than trusting a source-level array size.
if *(unsigned short*)$pc!=0x4fef || *(unsigned short*)($pc+4)!=0x48e7
 echo FAIL polygon stack prologue changed\n
 detach
 quit 1
end
set $poly_frame=-(short)*(unsigned short*)($pc+2)
set $poly_mask=*(unsigned short*)($pc+6)
set $poly_saved=0
while $poly_mask
 set $poly_saved=$poly_saved+4*($poly_mask&1)
 set $poly_mask=$poly_mask>>1
end
set $poly_headroom=$sp-(unsigned long)SysBase->SysStkLower-$poly_frame-$poly_saved
printf "POLYGON_STACK frame=%u saved=%u entry=%X lower=%X upper=%X headroom=%u\n",$poly_frame,$poly_saved,$sp,SysBase->SysStkLower,SysBase->SysStkUpper,$poly_headroom
if $poly_frame<=0 || $sp<(unsigned long)SysBase->SysStkLower+$poly_frame+$poly_saved+4096 || $sp>(unsigned long)SysBase->SysStkUpper
 echo FAIL polygon interrupt stack headroom\n
 detach
 quit 1
end
