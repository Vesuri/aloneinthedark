-- Original GetKeys polling: no key, held A, released A, through real ADB input.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'GETKEYS / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('GETKEYS / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function regs()local t='';for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do t=t..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end;return t end
local armed=false;local done=false;local returning=false;local n=1;local args;local ret;local dest
local function arm()
 dbg:command('bpclear');cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa976 && (d@(sp+2)&ffffff)=='..base(12)..'+0x583a','');dbg.execution_state='run'
end
local function capture(phase)
 print(string.format('GETKEYS_%s n=%d sp=%X destination=%X guard=%s keymap=%s',phase,n,phase=='ENTER' and args or cpu.state.A7.value,dest,bytes(dest-4,24),bytes(0x174,16))..regs())
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETKEYS / DISPATCHER BYTES');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not returning then
   local held=mem:read_u8(0x174)&1~=0
   if (n==2 and not held) or (n==3 and held) then dbg.execution_state='run';return end
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;dest=ptr(args)
   assert(bytes(ret-6,6)=='486EFFF0A976','GETKEYS / ORIGINAL CALLER BYTES')
   print(string.format('GETKEYS_BYTES n=%d data=%s',n,bytes(ret-6,6)));capture('ENTER');returning=true;dbg:command('bpclear');cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'GETKEYS / RETURN');capture('RETURN');returning=false
   if n==3 then done=true;print('PASS original GetKeys calls=3 released/held/released');dbg:command('quit');return end
   if n==1 then mac.key_down('a') else mac.key_up('a') end
   n=n+1;arm()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('GETKEYS / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
