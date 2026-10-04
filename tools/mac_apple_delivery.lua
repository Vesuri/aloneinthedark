-- Observe the original Finder launch event and its registered application handler.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local armed=false;local phase=0;local callSP;local returnPC;local handlerReturn
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local result={};for i=0,n-1 do result[#result+1]=string.format('%02X',mem:read_u8(a+i))end
 return table.concat(result)
end
local function registers()
 local result='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do
  result=result..string.format(' %s=%08X',r:lower(),cpu.state[r].value)
 end;return result
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a)
 cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==a816 && (d0&ffff)==21b','')
 armed=true;print('AE_DELIVERY_ARM bytes=2f0a2f02246f000a')
end)
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  local sp=cpu.state.A7.value
  if phase==0 then
   callSP=sp+8;returnPC=ptr(sp+2)+2
   local event=ptr(callSP);local a5=ptr(0x904)
   print(string.format('AE_PROCESS_ENTER sp=%X selector=%X event=%s',callSP,cpu.state.D0.value&0xffff,bytes(event,16))..registers())
   dbg:command('bpclear');cpu.debug:bpset(a5+0xac2,'1','');cpu.debug:bpset(returnPC,'1','');phase=1
  elseif phase==1 and cpu.state.PC.value~=returnPC then
   handlerReturn=mem:read_u32(sp) -- System callback return can be in 32-bit ROM space.
   print(string.format('AE_HANDLER_ENTER sp=%X args=%s',sp,bytes(sp+4,14))..registers())
   for _,entry in ipairs({{'reply',ptr(sp+8)},{'event',ptr(sp+12)}})do
    local descriptor=entry[2];print('AE_DESCRIPTOR '..entry[1]..' '..bytes(descriptor,8))
    local handle=ptr(descriptor+4)
    if handle~=0 and ptr(handle)~=0 then print('AE_DESCRIPTOR_DATA '..entry[1]..' '..bytes(ptr(handle),128))end
   end
   dbg:command('bpclear');cpu.debug:bpset(handlerReturn,'1','');cpu.debug:bpset(returnPC,'1','');phase=2
  elseif phase==2 and cpu.state.PC.value==handlerReturn then
   print(string.format('AE_HANDLER_RETURN sp=%X result=%X',sp,mem:read_u16(sp))..registers())
   dbg:command('bpclear');cpu.debug:bpset(returnPC,'1','');phase=3
  else
   assert(cpu.state.PC.value==returnPC and phase==3,'AE handler positive control')
   print(string.format('AE_PROCESS_RETURN sp=%X result=%X delta=%d',sp,mem:read_u16(sp),sp-callSP)..registers())
   print('PASS original launch Apple Event delivery');manager.machine:exit()
  end
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600)
  error('AE delivery not reached')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
