-- Authorized isolated SysBeep contract fixture: guest RAM writes only.
-- Redirect one original indirect call to the unchanged Engine beep wrapper.
-- No original instructions/resources or CPU registers are patched.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 local a5=ptr(0x904)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(a5+36+(i-1)*8)-j[2] end end
 error('SYSBEEP / SEGMENT')
end
local function capture(label,sp)
 local line=''
 for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do line=line..string.format(' %s=%X',r:lower(),cpu.state[r].value)end
 print(string.format('SYSBEEP_%s sp=%X tick=%X%s',label,sp,mem:read_u32(0x16a),line))
end
local phase='arm';local armed=false;local done=false
local dispatch,oldDriver,callsp,oldArgument,trapReturn
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 local app='Alone In The Dark';local condition=string.format('b@910==0x%x',#app)
 for i=1,#app do condition=condition..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,condition..' && w@(d@(sp+2))==0xa86e','')
 armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='arm' then
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x1388,'1','');phase='redirect'
  elseif phase=='redirect' then
   assert(mem:read_u32(cpu.state.PC.value)==0x206df954,'SYSBEEP / ORIGINAL INDIRECT LOAD')
   local a5=cpu.state.A5.value;local wrapper
   for i,j in ipairs(meta.jt)do if j[1]==7 and j[2]==0x4f40 then wrapper=a5+34+(i-1)*8 end end
   assert(wrapper,'SYSBEEP / ORIGINAL ENGINE ENTRY')
   dispatch=a5-0x6ac;oldDriver=mem:read_u32(dispatch);callsp=cpu.state.A7.value;oldArgument=mem:read_u32(callsp)
   assert(oldArgument==0,'SYSBEEP / ORIGINAL SELECTOR ZERO')
   mem:write_u32(dispatch,wrapper);mem:write_u16(callsp,1)
   print(string.format('SYSBEEP_FIXTURE wrapper=%X duration=1 dispatch=%X saved=%X',wrapper,dispatch,oldDriver))
   dbg:command('bpclear');cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==0xa9c8','');phase='enter'
  elseif phase=='enter' then
   local pc=ptr(cpu.state.A7.value+2);local sp=cpu.state.A7.value+8
   assert(pc==base(7)+0x4f48 and mem:read_u16(sp)==1,'SYSBEEP / EXACT WRAPPER AND ARGUMENT')
   local bytes=''
   for a=pc-4,pc+5 do bytes=bytes..string.format('%02X',mem:read_u8(a)) end
   assert(bytes=='3F2E0008A9C84E5E4E75','SYSBEEP / LIVE WRAPPER BYTES')
   print('SYSBEEP_BYTES '..bytes)
   capture('ENTER',sp);trapReturn=pc+2
   dbg:command('bpclear');cpu.debug:bpset(trapReturn,'1','');phase='return'
  else
   assert(cpu.state.PC.value==trapReturn,'SYSBEEP / ORIGINAL RETURN')
   capture('RETURN',cpu.state.A7.value)
   mem:write_u32(dispatch,oldDriver);mem:write_u32(callsp,oldArgument)
   done=true;print('PASS original isolated SysBeep duration 1');dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  mac.wait(18000);error('SYSBEEP / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
