-- Original clut 129 request and isolated size/ownership fixtures.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'CTABLE129 / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('CTABLE129 / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function save(name,a,n)
 local f=assert(io.open('tmp/ctable129-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end

local armed=false;local done=false;local phase='entry';local args;local ret;local handle;local scratch;local stack;local fixture=0;local resource
local function state(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('CT129_%s fixture=%d sp=%X result=%X res=%X mem=%X',label,fixture,cpu.state.A7.value,mem:read_u32(cpu.state.A7.value),mem:read_u16(0xa60),mem:read_u16(0x220))..tail)
end
local function next_fixture()
 fixture=fixture+1
 if fixture>6 then done=true;print('PASS original clut129 and ownership fixtures=6');dbg:command('quit');return end
 if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end
 local trap=({0xa025,0xa069,0xa9a6,0xa9a0,0xa069,0xa025})[fixture]
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,trap);mem:write_u16(scratch+4,0x4e71)
 for i=0,15 do mem:write_u8(stack+i,0xcc)end
 cpu.state.A0.value=fixture<=3 and handle or resource or 0
 if fixture==3 then mem:write_u32(stack,handle)end
 if fixture==4 then mem:write_u16(stack,129);mem:write_u32(stack+2,0x636c7574)end
 cpu.state.A7.value=stack;cpu.state.PC.value=scratch;ret=scratch+4;phase='fixture-entry';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'CTABLE129 / DISPATCHER')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa18 && (d@(sp+2)&0xffffff)=='..base(5)..'+0x1fdc','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='entry' then
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2
  assert(mem:read_u16(args)==129,'CTABLE129 / ID');print('CT129_BYTES '..bytes(ret-8,8));state('ENTER')
  phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 elseif phase=='fixture-entry' then state('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret,'CTABLE129 / RETURN');state('RETURN');dbg:command('bpclear')
  if fixture==0 then
   handle=ptr(cpu.state.A7.value);assert(handle~=0);local body=ptr(handle)
   print(string.format('CT129_TABLE handle=%X master=%X body=%X header=%s',handle,mem:read_u32(handle),body,bytes(body,8)));save('returned',body,2064)
  elseif fixture==4 then
   resource=ptr(cpu.state.A7.value);assert(resource~=0 and resource~=handle,'CTABLE129 / DETACHED');save('resource',ptr(resource),2064)
  end
  next_fixture()
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('CTABLE129 / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
