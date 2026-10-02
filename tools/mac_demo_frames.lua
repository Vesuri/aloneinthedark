-- Original car endpoint and first pond camera; diagnostic entropy only.
-- The first post-transition Dark+$5658 has camera 3, not the prior camera 1.
-- Original Engine random/selection and scene code run unchanged.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'FIXED RANDOM / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function address(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then
  local entry=ptr(0x904)+32+(i-1)*8
  if mem:read_u16(entry+2)~=0x4ef9 then return nil end
  return ptr(entry+4)-j[2]
 end end
end
local function callerState(pc)
 for seg,info in pairs(meta.segments)do
  local base=address(seg)
  if base and pc>=base and pc<base+info.size then return seg,pc-base end
 end
 error('unknown original random caller')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local armed,done,skip=false,false,false
local thePort,ret,callerSegment,callerOffset
local seed,mixed,count=1,1,0
local point,roompc,last
local pondLoaded=false
local frames=0
local function block(a,n)
 local parts={};for i=0,n-1 do parts[#parts+1]=string.char(mem:read_u8(a+i))end
 return table.concat(parts)
end
local function capture(kind)
 local a5=cpu.state.A5.value
 local pm=ptr(ptr(ptr(ptr(0x8a4))+22));local clut=ptr(ptr(pm+42))
 assert(mem:read_u16(pm+32)==8 and (mem:read_u16(pm+4)&0x3fff)==640,'DEMO / DISPLAY')
 return {kind=kind,frame=frames,ticks=mem:read_u32(0x16a),random=count,room=mem:read_u16(a5-0xcd68),camera=mem:read_u16(a5-0xcd70),actor=bytes(a5-0xb292,160),
  screen=block(mem:read_u32(pm),307200),clut=block(clut,2056),a5=block(a5-75616,79392)}
end
local function save(c)
 for _,kind in ipairs({'screen','clut','a5'})do
  local f=assert(io.open('tmp/demo-reference-'..c.kind..'-'..kind..'.bin','wb'));f:write(c[kind]);f:close()
 end
 print(string.format('DEMO_STATE kind=%s segment=4 offset=5658 frame=%u ticks=%u random=%u room=%u camera=%u actor0=%s',c.kind,c.frame,c.ticks,c.random,c.room,c.camera,c.actor))
end
local function arm()
 local dark=address(4)
 if dark and count>0 then
  assert(bytes(dark+0x5658,4)=='4E56FFF8' and bytes(dark+0x5be8,2)=='4EB9','DEMO / ORIGINAL CHECKPOINT BYTES')
  point=dark+0x5658;cpu.debug:bpset(point,'1','')
  if not pondLoaded then roompc=dark+0x5be8;cpu.debug:bpset(roompc,'1','')end
 end
 local tests={'w@(d@(sp+2))==0xa861'}
 if not thePort then tests[#tests+1]='w@(d@(sp+2))==0xa86e' end
 if not skip then tests[#tests+1]='w@(d@(sp+2))==0xa891' end
 cpu.debug:bpset(0xdd60,cond..' && ('..table.concat(tests,' || ')..')','')
 dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(bytes(0xdd60,8)=='2F0A2F02246F000A','dispatcher bytes');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
  local pc=cpu.state.PC.value
  if roompc and pc==roompc then
   local a5=cpu.state.A5.value
   if mem:read_u16(a5-0xcd68)==0 and mem:read_u16(a5-0xcd70)==1 then
    assert(last,'DEMO / NO NEAR CAR BEFORE POND');pondLoaded=true
   end
   arm();return
  end
  if point and pc==point then
   frames=frames+1;assert(frames<2000,'DEMO / FRAME BOUND')
   local a5=cpu.state.A5.value
   local room,camera=mem:read_u16(a5-0xcd68),mem:read_u16(a5-0xcd70)
   if pondLoaded then
    assert(room==0 and camera==3,'DEMO / FIRST POND CAMERA')
    save(last);save(capture('pond'))
    assert(mem:read_u16(a5-0xd8f2)==0,'DEMO / CHARACTER')
    done=true;print('PASS original near car and first completed pond camera frame');dbg:command('quit');return
   end
   local l,t,r,b=mem:read_i16(a5-0xb27e),mem:read_i16(a5-0xb27c),mem:read_i16(a5-0xb27a),mem:read_i16(a5-0xb278)
   if room==0 and camera==0 and r-l>=80 and l<320 and r>0 and t<200 and b>0 then
    assert(mem:read_u16(a5-0xb292)==286,'DEMO / CAR IDENTITY')
    last=capture('car')
   end
   arm();return
  end
  if ret then
   assert(cpu.state.PC.value==ret,'original wrapper continuation')
   local result=cpu.state.D0.value&0xffff
   local nextSeed=mem:read_u32(thePort-126)
   local actualMixed=mem:read_u16(cpu.state.A5.value-0x1078)
   assert(actualMixed==((mixed~result)&0x7fff),'original accumulator result')
   print(string.format('FIXED_RANDOM row=%u seed=%X mixed=%X result=%X next=%X segment=%u offset=%X',count,seed,mixed,result,nextSeed,callerSegment,callerOffset))
   seed=nextSeed;mixed=actualMixed;count=count+1;ret=nil
   arm();return
  end
  local call=ptr(cpu.state.A7.value+2);local trap=mem:read_u16(call)
  if trap==0xa86e then thePort=ptr(cpu.state.A7.value+8);arm();return end
  if trap==0xa891 then skip=true;arm();return end
  local engine=address(7)
  if not engine or call~=engine+0x4a32 then arm();return end -- OS-internal Random
  assert(thePort and bytes(engine+0x4a30,8)=='4267A861301FB179','Random wrapper bytes')
  local accumulator=cpu.state.A5.value-0x1078
  assert(ptr(engine+0x4a38)==accumulator,'relocated accumulator')
  callerSegment,callerOffset=callerState(ptr(cpu.state.A6.value+4))
  if count==0 then assert(callerSegment==4 and callerOffset==0x5250,'first character choice')end
  -- Replace live clock addition with zero and isolate game entropy from OS calls.
  mem:write_u32(thePort-126,seed);mem:write_u16(accumulator,mixed)
  ret=engine+0x4a44;cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return');assert(mac.mouse_to(620,470),'DEMO / POINTER')
  mac.wait(42000);error('fixed random endpoint absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
