-- Observe original ObscureCursor, repeated/hide/show fixtures and ADB restoration.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local meta=dofile('tmp/mac-trap-map.lua')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('EVENT / SEGMENT')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local armed=false;local done=false;local phase='entry';local args;local ret;local scratch;local n=0
local fixtures={0xa850,0xa856,0xa856,0xa853,0xa852,0xa856,0xa853,0xa850,0xa856}
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function log(label)
 local s='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6','A7'})do s=s..string.format(' %s=%08X',r,cpu.state[r].value)end
 print(string.format('CUR_%s n=%d low=%s mouse=%08X%s',label,n,bytes(0x8cc,8),mem:read_u32(0x830),s))
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02)
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa856 && (d@(sp+2)&ffffff)=='..base(7)..'+0xff6','');armed=true
end)
emu.register_periodic(function()
 if done or not armed then return end
 if phase=='movement' then return end
 if dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='entry' or phase=='fixture' then
  if phase=='entry' then args=cpu.state.A7.value+8;ret=(mem:read_u32(cpu.state.A7.value+2)&0xffffff)+2;print('CUR_BYTES '..bytes(ret-14,14))
  else ret=scratch+4 end
  log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');dbg:command('bpclear')
  if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc end
  n=n+1
  if n>#fixtures then
   mem:write_u16(scratch,0x60fe);cpu.state.PC.value=scratch;phase='movement';dbg.execution_state='run'
  else
   mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,fixtures[n]);mem:write_u16(scratch+4,0x4e71)
   cpu.state.D0.value=0x12345678;cpu.state.D1.value=0x89abcdef;cpu.state.PC.value=scratch;phase='fixture';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
  end
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  for i=1,3600 do if phase=='movement' then break end;mac.wait(1)end
  assert(phase=='movement','CURSOR / NO CALL COMPLETION');log('BEFORE_MOVE')
  assert(mac.mouse_to(300,300),'CURSOR / MOVEMENT');mac.wait(4);log('AFTER_MOVE')
  done=true;print('PASS original ObscureCursor and nine fixtures plus mouse restoration');dbg:command('quit')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
