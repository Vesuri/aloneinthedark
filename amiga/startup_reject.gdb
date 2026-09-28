# Use GDB_ENTRY=MacLoader::prepareResourceForks and a deliberately corrupted copy.
set pagination off
set confirm off
finish
if $d0 != 0 || g_screenReady != 0 || g_startupLowMemoryPatches != 0 || g_startupCode != 0
  echo startup-reject FAIL: input accepted or takeover occurred\n
  detach
  quit 1
end
echo startup-reject PASS: invalid original rejected before takeover\n
detach
quit 0
