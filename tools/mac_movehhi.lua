-- Isolated original Memory Manager fixture. Original game/OS bytes are unchanged.
-- A debugger trampoline in spare guest stack RAM calls traps on a private zone.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local armed=false;local phase='entry';local worker;local code;local zone
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function call(trap,d0,a0)
 mem:write_u16(code,trap);mem:write_u16(code+2,0x4e71)
 assert(mem:read_u16(code)==trap,'trampoline readback')
 dbg:command(string.format('pc=0x%x;d0=0x%x;a0=0x%x',code,d0 or 0,a0 or 0))
 cpu.debug:bpset(code+2,'1','');dbg.execution_state='run';coroutine.yield()
 assert(cpu.state.PC.value==code+2,'trap return')
 dbg:command('bpclear')
 return cpu.state.D0.value, cpu.state.A0.value&0xffffff, mem:read_u16(0x220)
end
local function handle(size)
 local d,h,e=call(0xa322,size);assert(e==0 and h~=0 and ptr(h)~=0,'NewHandle')
 return h
end
local function init()
 mem:write_u32(code+16,zone);mem:write_u32(code+20,zone+65536)
 mem:write_u16(code+24,64);mem:write_u32(code+26,0)
 local _,_,e=call(0xa019,0,code+16);assert(e==0 and ptr(0x118)==zone,'InitZone')
end
local function pattern(h,n,seed)
 for i=0,n-1 do mem:write_u8(ptr(h)+i,(i+seed)&255)end
end
local function check(h,n,seed)
 assert(ptr(h)~=0,'unexpected purge')
 for i=0,n-1 do assert(mem:read_u8(ptr(h)+i)==((i+seed)&255),'payload mismatch')end
end
local function test(name,h,others)
 local before=ptr(h);local addresses={}
 for i,v in ipairs(others)do addresses[i]=ptr(v)end
 local free=mem:read_u32(zone+12)
 local d,_,e=call(0xa064,0,h)
 local line=string.format('MOVEHHI %s error=%d result=%X target=%X->%X free=%d->%d',name,e>=32768 and e-65536 or e,d,before-zone,ptr(h)-zone,free,mem:read_u32(zone+12))
 for i,v in ipairs(others)do line=line..string.format(' other%d=%X->%X',i,addresses[i]-zone,ptr(v)==0 and 0 or ptr(v)-zone)end
 print(line)
 assert(e==0 and free==mem:read_u32(zone+12),'result/free space')
 if name=='free-above' or name=='purgeable' then
  assert(ptr(h)>before and ptr(others[1])==addresses[1],'free-tail placement')
 elseif name=='locked-barrier' then
  assert(ptr(h)==before and ptr(others[1])==addresses[1],'locked barrier')
 else assert(ptr(h)>before and ptr(others[1])==before,'compacted neighbour')end
 check(h,1024,17)
 for _,v in ipairs(others)do if ptr(v)~=0 then check(v,512,31)end end
end
local function run()
 local _,p,e=call(0xa31e,65536);assert(e==0 and p~=0,'private arena');zone=p
 print(string.format('MOVEHHI zone=%X bytes=65536 system=%X',zone,mem:read_u16(0x15a)))
 for _,name in ipairs({'free-above','locked-barrier','no-room','purgeable','fragmented','interior-hole','small-gap','small-tail','purgeable-no-room'})do
  init();local h=handle(1024);local hole
  if name=='interior-hole' or name=='small-tail' then hole=handle(2048)
  elseif name=='small-gap' then hole=handle(8)end
  local b=handle(512);pattern(h,1024,17);pattern(b,512,31)
  if hole then
   local tail;if name=='small-tail' then tail=handle(512)end
   local barrier=handle(512);call(0xa029,0,barrier);call(0xa023,0,hole)
   if tail then call(0xa023,0,tail)end
  end
  if name=='locked-barrier' then call(0xa029,0,b)
  elseif name=='purgeable' then call(0xa049,0,b)
  elseif name=='no-room' or name=='purgeable-no-room' then
   if name=='purgeable-no-room' then call(0xa049,0,b)end
   local free=mem:read_u32(zone+12);local rest=handle(free-8);call(0xa029,0,rest)
  elseif name=='fragmented' then
   local holes={};for i=1,12 do holes[i]=handle(512)end
   local free=mem:read_u32(zone+12);local rest=handle(free-8);call(0xa029,0,rest)
   for i=1,12,2 do call(0xa023,0,holes[i])end
  end
  test(name,h,{b})
 end
 print('PASS original MoveHHi cases=9 payloads intact');phase='done';dbg:command('quit')
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02,'dispatcher bytes')
 local app='Alone In The Dark';local condition=string.format('b@910==0x%x',#app)
 for i=1,#app do condition=condition..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,condition..' && w@(d@(sp+2))==0xa86e','');armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if phase=='done' or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' then
   local ret=ptr(cpu.state.A7.value+2)+2;dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='ready';dbg.execution_state='run';return
  elseif phase=='ready' then
   dbg:command('bpclear');code=cpu.state.A7.value-256
   dbg:command(string.format('sp=0x%x',code-4096));worker=coroutine.create(run);phase='running'
  end
  local success,error=coroutine.resume(worker);assert(success,error)
 end)
 if not ok then print('FAIL MoveHHi '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(18000);error('no fixture completion')end)
 if not ok then print('FAIL MoveHHi '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
