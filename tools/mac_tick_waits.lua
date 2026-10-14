-- Isolated short-wait clock contract, using (Dan2,$3364)'s eight-byte loop.
-- Five ticks is a resolution stress control; seven is the original dialog delay.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'TICK WAIT / DEBUGGER REQUIRED')
local armed,ending,base,done
local function put(a,bytes)
 for i=1,#bytes do mem:writev_u8(a+i-1,bytes:byte(i)) end
 for i=1,#bytes do assert(mem:readv_u8(a+i-1)==bytes:byte(i),'TICK WAIT / WRITE') end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02,'TICK WAIT / DISPATCHER')
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','');armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not ending then
   dbg:command('bpclear')
   base=(cpu.state.SP.value&0xffffff)-16384
   assert(base>0x100000 and base+4096<0x800000,'TICK WAIT / EXTENT')
   local program=string.pack('>I2I4',0x267c,base+2048) -- movea.l results,a3
   for n=0,41 do
    local delay=n<20 and 5 or n<40 and 7 or 300
    program=program..string.pack('>I2I2I2I2I2I4',0x42a7,0xa975,0x2a1f,0x26c5,0x0685,delay)
    program=program..string.pack('>I2I2I2I2I2I2',0x42a7,0xa975,0xba9f,0x62f8,0x26ef,0xfffc)
   end
   ending=base+#program;program=program..string.pack('>I2',0x4e71)
   assert(#program<2048);put(base,program)
   cpu.debug:bpset(ending,'1','');cpu.state.PC.value=base
  else
   assert(cpu.state.PC.value==ending,'TICK WAIT / END PC')
   for n=0,41 do
    local delay=n<20 and 5 or n<40 and 7 or 300
    print(string.format('TICK_WAIT n=%d delay=%d start=%d end=%d',n,delay,mem:readv_u32(base+2048+n*8),mem:readv_u32(base+2052+n*8)))
   end
   done=true;print('PASS original tick waits');dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL '..tostring(err));dbg:command('quit') end
end)
mac.run(function() assert(mac.launch());mac.wait(6000);print('FAIL tick wait timeout');manager.machine:exit() end)
dbg.execution_state='run'
