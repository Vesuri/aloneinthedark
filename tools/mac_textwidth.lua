-- Capture the original twenty-picture preparation loop, without modifying it.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PICT8 / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('PICT8 / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local original_count=tonumber(os.getenv('AITD_TEXTWIDTH_CALLS') or '0');local original=0
local armed=false;local done=false;local phase='entry';local ret;local args;local port;local scratch;local stack;local character=-1
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(t) end
local function registers()
 local t='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do t=t..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end;return t
end
local repeat_code=-1
local function next_repeat()
 repeat_code=repeat_code+1
 if repeat_code==273 then done=true;print('PASS original TextWidth and 256 character widths plus repeats/prefixes');dbg:command('quit');return end
 local count=192
 if repeat_code<256 then
  for i=0,count-1 do mem:write_u8(scratch+12288+i,repeat_code) end
 else
  local title='Alone in the Dark';count=repeat_code-255
  for i=1,#title do mem:write_u8(scratch+12287+i,title:byte(i)) end
 end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa886);mem:write_u16(scratch+4,0x4e71)
 mem:write_u16(stack,count);mem:write_u16(stack+2,0);mem:write_u32(stack+4,scratch+12288);mem:write_u16(stack+8,0xabcd)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch;phase='repeat'
 cpu.debug:bpset(scratch+4,'1','');dbg.execution_state='run'
end
local function next_character()
 character=character+1
 if character==256 then next_repeat();return end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa88d);mem:write_u16(scratch+4,0x4e71)
 mem:write_u16(stack,character);mem:write_u16(stack+2,0xabcd)
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 phase='character';cpu.debug:bpset(scratch+4,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'TEXTWIDTH / DISPATCHER BYTES')
 armed=true;cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa886 && (d@(sp+2)&ffffff)=='..base(12)..'+0x216','');dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' then
   original=original+1
   print(string.format('TW_INDEX n=%d',original))
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;port=cpu.state.A4.value&0xffffff
   local count=mem:read_u16(args);local first=mem:read_u16(args+2);local text=ptr(args+4)
   print('TW_BYTES data='..bytes(ret-6,6))
   print(string.format('TW_ENTER sp=%X count=%X first=%X text=%s font=%X size=%X face=%X extra=%X port=%s',args,count,first,bytes(text+first,count),mem:read_u16(port+68),mem:read_u16(port+74),mem:read_u8(port+70),mem:read_u32(port+76),bytes(port,108))..registers())
   phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  elseif phase=='return' then
   assert(cpu.state.PC.value==ret,'TEXTWIDTH / RETURN')
   print(string.format('TW_RETURN sp=%X width=%X port=%s',cpu.state.A7.value,mem:read_u16(cpu.state.A7.value),bytes(port,108))..registers())
   dbg:command('bpclear')
   if original_count>0 then
    if original==original_count then done=true;print(string.format('PASS original TextWidth calls=%d',original));dbg:command('quit')
    else phase='entry';cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa886 && (d@(sp+2)&ffffff)=='..base(12)..'+0x216','');dbg.execution_state='run' end
   else scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192;next_character() end
  elseif phase=='repeat' then
   if cpu.state.PC.value~=scratch+4 or cpu.state.A7.value~=stack+8 then print(string.format('TW_BAD_RETURN pc=%X expected=%X sp=%X expectedSP=%X code=%s',cpu.state.PC.value,scratch+4,cpu.state.A7.value,stack+8,bytes(scratch,6))) end
   assert(cpu.state.PC.value==scratch+4 and cpu.state.A7.value==stack+8,'TEXTWIDTH / REPEAT RETURN')
   print(string.format('TW_REPEAT code=%X width=%X',repeat_code,mem:read_u16(stack+8)));dbg:command('bpclear');next_repeat()
  else
   assert(cpu.state.PC.value==scratch+4 and cpu.state.A7.value==stack+2,'TEXTWIDTH / CHARACTER RETURN')
   print(string.format('TW_CHAR code=%X width=%X',character,mem:read_u16(stack+2)));dbg:command('bpclear');next_character()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'TEXTWIDTH / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'TEXTWIDTH / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('TEXTWIDTH / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
