-- Bounded, read-only File Manager reference fixture. Re-enter the original
-- byte-checked PBGetFCBInfo trap with diagnostic parameter blocks, then exit.
-- This measures API semantics; it is not original-game execution acceptance.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu']
local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'FILE QUERIES / DEBUGGER REQUIRED')
local armed=false
local function log(stage)
 return 'logerror "FCBQUERY stage='..stage..' d0=%08X result=%04X volume=%04X ref=%04X index=%04X id=%08X flags=%04X eof=%08X parent=%08X\\n",d0,w@(a0+10),w@(a0+16),w@(a0+18),w@(a0+1c),d@(a0+20),w@(a0+24),d@(a0+28),d@(a0+3a);'
end
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==3 and mem:read_u16(e)==3 and mem:read_u16(e+2)==0x4ef9 then
   local base=(mem:read_u32(e+4)&0xffffff)-j[2]
   assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'FILE QUERIES / ORIGINAL BYTES')
   local at=base+0x4146
   local again='d0=8;pc=pc-2;g'
   cpu.debug:bpset(at,'temp0==0',log(0)..'temp0=1;d@(a0+12)=0;w@(a0+16)=0;w@(a0+1c)=1;'..again)
   cpu.debug:bpset(at,'temp0==1',log(1)..'temp1=w@(a0+18);temp2=d@(a0+20);temp3=d@(a0+28);temp0=2;w@(a0+1c)=0;'..again)
   cpu.debug:bpset(at,'temp0==2',log(2)..'temp0=3;w@(a0+1c)=7fff;'..again)
   cpu.debug:bpset(at,'temp0==3',log(3)..'temp0=4;w@(a0+1c)=1;w@(a0+16)=1234;'..again)
   cpu.debug:bpset(at,'temp0==4',log(4)..'temp0=5;w@(a0+1c)=0;w@(a0+18)=0;'..again)
   cpu.debug:bpset(at,'temp0==5',log(5)..'logerror "PASS file-query capture complete\\n";quit')
   armed=true
   print(string.format('ARM file-queries Core+$4144=%08X bytes=7008a2606004',base+0x4144))
   break
  end
 end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'FILE QUERIES / LAUNCH FAILED')
  mac.wait(3600)
  error('FILE QUERIES / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
