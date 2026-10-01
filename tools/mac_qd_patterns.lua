-- Capture the original InitGraf default patterns before later game drawing.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PATTERNS / DEBUGGER REQUIRED')
local armed,done=false,false
local ret,port,stack
local function ptr(a)return mem:read_u32(a)&0xffffff end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'dispatcher bytes')
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not ret then
   stack=cpu.state.A7.value+8;port=ptr(stack);ret=ptr(cpu.state.A7.value+2)+2
   assert(port>202 and port<0x800000,'QDGlobals pointer')
   dbg:command('bpclear');cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret and cpu.state.A7.value==stack+4,'InitGraf return')
   local f=assert(io.open('tmp/qd-patterns-reference.bin','wb'))
   for i=-40,-1 do f:write(string.char(mem:read_u8(port+i)))end;f:close()
   print('PASS original InitGraf five patterns bytes=40');done=true;dbg:command('quit')
  end
 end)
 if not ok then print('FAIL '..tostring(err));done=true;manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(3600);error('InitGraf not captured')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
