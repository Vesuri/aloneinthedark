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
local armed=false;local done=false;local phase='entry';local n=0;local args;local ret;local point;local port;local pm
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,count)local t={};for i=0,count-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(t) end
local function regs()local t='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do t=t..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end;return t end
local function save(name,a,count)local f=assert(io.open('tmp/localglobal-reference-'..n..'-'..phase..'-'..name..'.bin','wb'));for i=0,count-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close() end
local function arm()
 phase='entry';cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa870 && ((d@(sp+2)&ffffff)=='..base(9)..'+0xe20 || (d@(sp+2)&ffffff)=='..base(9)..'+0xe26)','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'LOCALGLOBAL / DISPATCHER BYTES');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' then
   assert(cpu.state.PC.value==0xdd60,'LOCALGLOBAL / ENTRY');n=n+1;args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;point=ptr(args)
   port=ptr(cpu.state.A4.value+8);pm=ptr(ptr(port+2))
   print(string.format('LG_BYTES n=%d data=%s',n,bytes(ret-6,6)))
  else assert(cpu.state.PC.value==ret,'LOCALGLOBAL / RETURN') end
  print(string.format('LG_%s n=%d sp=%X point=%X value=%08X port=%X bounds=%s',phase:upper(),n,phase=='entry' and args or cpu.state.A7.value,point,mem:read_u32(point),port,bytes(pm+6,8))..regs())
  save('point',point-4,12);save('port',port,108);save('pm',pm,50)
  if phase=='entry' then phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else dbg:command('bpclear');if n==2 then done=true;print('PASS original LocalToGlobal calls=2');dbg:command('quit') else arm() end end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'LOCALGLOBAL / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'LOCALGLOBAL / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('LOCALGLOBAL / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
