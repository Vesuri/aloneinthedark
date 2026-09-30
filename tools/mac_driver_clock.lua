-- Count original callback-clock advances from quality setup through the first query.
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
local armed=false;local done=false;local phase='arm';local entry
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
   dbg:command('bpclear');cpu.debug:bpset(base(3)+0x1d62,'1','');phase='quality'
  elseif phase=='quality' then
   entry=ptr(cpu.state.A5.value-0x6ac)
   print(string.format('DRIVER_CLOCK_BEGIN tick=%X clock=%X entry=%X',mem:read_u32(0x16a),mem:read_u32(entry+0x5a80),entry))
   assert(bytes(entry+0x6fe,4)=='52AC1880' and bytes(entry+0x824,4)=='52AC1880' and bytes(entry+0x3b16,4)=='52AC1880')
   dbg:command('bpclear');dbg:command('temp0=0');dbg:command('temp1=0');dbg:command('temp2=0')
   for index,offset in ipairs({0x6fe,0x824,0x3b16})do
    local action=string.format('temp%d=temp%d+1;g',index-1,index-1)
    cpu.debug:bpset(entry+offset,'1',action);cpu.debug:bpset((entry+offset)|0x80000000,'1',action)
   end
   cpu.debug:bpset(base(3)+0xfc8,'1','');phase='query'
  else
   assert(bytes(cpu.state.PC.value-10,14)=='42A74878000F206DF9544E90508F')
   print(string.format('DRIVER_CLOCK_END tick=%X clock=%X',mem:read_u32(0x16a),mem:read_u32(entry+0x5a80)))
   dbg:command('logerror "DRIVER_CLOCK_COUNTS doublebuffer=%X legacy=%X device=%X\\n",temp0,temp1,temp2')
   done=true;print('PASS original driver clock observation');dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('DRIVER CLOCK / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
