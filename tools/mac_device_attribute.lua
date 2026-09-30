-- Capture original SetPt arguments, point bytes and register/stack effects.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SETPT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SETPT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local armed=false;local done=false;local phase='entry';local fixture=-1;local args;local ret;local device;local scratch;local stack
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,count)local t={};for i=0,count-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(t) end
local function regs()local t='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do t=t..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end;return t end
local function next_fixture()
 fixture=fixture+1
 if fixture==16 then done=true;print('PASS original TestDeviceAttribute plus 16 flag fixtures');dbg:command('quit');return end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xaa2c);mem:write_u16(scratch+4,0x4e71)
 mem:write_u16(stack,fixture);mem:write_u32(stack+2,device);mem:write_u16(stack+6,0xccdd)
 cpu.state.D0.value=0x12345678;cpu.state.D1.value=0x89abcdef;cpu.state.A7.value=stack;cpu.state.PC.value=scratch;args=stack;ret=scratch+4;phase='fixture-entry';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DEVICE FLAG / DISPATCHER BYTES');armed=true
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa2c && (d@(sp+2)&ffffff)=='..base(9)..'+0xe3a','');dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' then
   assert(cpu.state.PC.value==0xdd60,'DEVICE FLAG / ENTRY');args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;device=ptr(args+2)
   print('DA_BYTES data='..bytes(ret-10,10))
  elseif phase=='return' then assert(cpu.state.PC.value==ret,'DEVICE FLAG / RETURN') end
  print(string.format('DA_%s fixture=%d sp=%X attribute=%X device=%X result=%04X body=%s',phase=='return' and 'RETURN' or 'ENTRY',fixture,phase=='return' and cpu.state.A7.value or args,mem:read_u16(args),device,mem:read_u16(args+6),bytes(ptr(device),62))..regs())
  if phase~='return' then phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else dbg:command('bpclear');if fixture==-1 then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end;next_fixture() end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DEVICE FLAG / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DEVICE FLAG / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DEVICE FLAG / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
