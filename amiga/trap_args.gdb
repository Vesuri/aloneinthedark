# Shared read-only argument view at either native dispatch boundary.
# The assembly entry has three C arguments but no call return address yet.
define mac-trap-args
 if $pc==(unsigned long)aitd_line_a_trap_entry
  set $mac_regs=*(unsigned long**)$sp
  set $mac_frame=*(unsigned char**)($sp+4)
  set $mac_stack=*(unsigned char**)($sp+8)
 else
  set $mac_regs=regs
  set $mac_frame=frame
  set $mac_stack=userStack
 end
end
