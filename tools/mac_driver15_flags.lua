-- Isolated original selector-15 condition-code fixtures, after driver initialization.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER15 / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('DRIVER15 / NO JUMP ENTRY')
end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local armed=false;local done=false;local phase='arm';local entry;local scratch;local stack
local values={0,1,0x8000,0x10000,0x80000000,0x89abcdef,0xffffffff};local index=0
local function nextcase()
 index=index+1
 if index>#values then done=true;print('PASS original driver15 full-width condition codes cases=7');dbg:command('quit');return end
 local value=values[index]
 cpu.state.SR.value=(cpu.state.SR.value&0xffe0)|0x071f
 mem:write_u32(entry+0x5a80,value)
 mem:write_u32(stack,15);mem:write_u32(stack+4,0x12345678)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='arm' then
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x1d62,'1','');phase='setup';dbg.execution_state='run'
  elseif phase=='setup' then
   entry=ptr(cpu.state.A5.value-0x6ac)
   assert(bytes(entry,12)=='202F0004222F000848E73FFE' and bytes(entry+0x19c,8)=='202C18806000FF0E')
   scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0x4eb9);mem:write_u32(scratch+4,entry);mem:write_u16(scratch+8,0x4e71)
   dbg:command('bpclear');cpu.debug:bpset(scratch+8,'1','');phase='case';nextcase()
  else
   assert(cpu.state.PC.value==scratch+8 and cpu.state.A7.value==stack)
   print(string.format('DRIVER15_FLAGS n=%d input=%08X result=%08X d1=%08X ccr=%02X',index,values[index],cpu.state.D0.value,cpu.state.D1.value,cpu.state.SR.value&31))
   nextcase()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('DRIVER15 FLAGS / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
