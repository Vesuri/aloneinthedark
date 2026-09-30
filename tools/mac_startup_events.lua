-- Capture the unchanged original startup event route, including Finder launch.
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
local armed=false;local done=false;local returning=false;local n=0;local args;local ret;local event
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function log(phase)
 local s='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6','A7'})do s=s..string.format(' %s=%08X',r,cpu.state[r].value)end
 print(string.format('WNE_%s n=%d args=%X stack=%s event=%X record=%s ticks=%X%s',phase,n,args,bytes(args,16),event,bytes(event,16),mem:read_u32(0x16a),s))
end
local function arm()cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa860 && (d@(sp+2)&ffffff)=='..base(7)..'+0x44f0','')end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02);arm();armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if not returning then
  n=n+1;args=cpu.state.A7.value+8;ret=(mem:read_u32(cpu.state.A7.value+2)&0xffffff)+2;event=mem:read_u32(args+8)&0xffffff
  if n==1 then print('WNE_BYTES '..bytes(ret-16,16))end
  print(string.format('WNE_GUARD phase=ENTER n=%d data=%s',n,bytes(event-4,24)))
  log('ENTER');returning=true;cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');print(string.format('WNE_GUARD phase=RETURN n=%d data=%s',n,bytes(event-4,24)));dbg:command('bpclear');returning=false
  if n>=8 then done=true;print('PASS WaitNextEvent original calls=8');dbg:command('quit')else arm();dbg.execution_state='run'end
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
