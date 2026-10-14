-- Read-only original book-hold deadline capture (Dan1,$4970).
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'TICK WAIT / DEBUGGER REQUIRED')
local meta=dofile('tmp/mac-trap-map.lua')
local function base(seg)
 local a5=mem:read_u32(0x904)&0xffffff
 for i,j in ipairs(meta.jt) do if j[1]==seg then return (mem:read_u32(a5+36+(i-1)*8)&0xffffff)-j[2] end end
end
local armed,count,done=false,0,false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02)
 local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
 for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
 local expression
 for i,j in ipairs(meta.jt) do if j[1]==12 then expression=string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]);break end end
 cpu.debug:bpset(0xdd60,cond..' && (d@(sp+2)&ffffff)=='..expression..'+0x4970 && d@0x16a-d@(a6-0x1b6)>=0x12c','');armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local pc=mem:read_u32(cpu.state.SP.value+2)&0xffffff
 if pc==base(12)+0x4970 then
  assert(mem:read_u32(pc-2)==0x42a7a975 and mem:read_u32(pc+2)==0x201f90ae
    and mem:read_u32(pc+6)==0xfe4a0c80 and mem:read_u32(pc+10)==300,'TICK ROUTE / ORIGINAL BYTES')
  local start=mem:read_u32((cpu.state.A6.value&0xffffff)-438)
  local tick=mem:read_u32(0x16a)
  if tick-start>=300 then
   print(string.format('TICK_ROUTE n=%d delay=300 start=%d end=%d d7=%d',count,start,tick,cpu.state.D7.value))
   count=count+1
   if count==2 then done=true;print('PASS original tick route');dbg:command('quit');return end
  end
 end
 dbg.execution_state='run'
end)
mac.run(function()
 assert(mac.launch());mac.wait(300);mac.mouse_to(256,274);mac.click(1)
 mac.wait(18000);print('FAIL tick route timeout');manager.machine:exit()
end)
dbg.execution_state='run'
