-- Read-only natural Carnby corridor drawing stages; no state replay.
-- Capture stdout under tmp/corridor-scene/mac.log with the standard Mac IIx run.
-- Read-only timing of original demo checkpoints; normal Return skips the book.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=manager.machine.debugger
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function segmentbase(segment)
 for i,j in ipairs(meta.jt)do if j[1]==segment then
  local entry=ptr(0x904)+32+(i-1)*8
  if mem:read_u16(entry+2)==0x4ef9 then return ptr(entry+4)-j[2] end
 end end
end
local armed,skip,done,routeArmed,landing,active=false,false,false,false,false,false
local points={}
local step=1
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local function armRoute()
 if routeArmed or not skip or mac.frontmost()~='Alone In The Dark' then return end
 local dark=segmentbase(4);if not dark then return end
 assert(mem:read_u16(dark+0x5658)==0x4e56,'loop bytes')
 points[dark+0x5658]='loop';cpu.debug:bpset(dark+0x5658,'1','');routeArmed=true
end
emu.register_frame_done(function()
 armRoute()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02,'dispatcher bytes')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa891','');armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not skip then
   assert(cpu.state.PC.value==0xdd60,'skip checkpoint');dbg:command('bpclear')
   skip=true;dbg.execution_state='run';return
  end
  local label=assert(points[cpu.state.PC.value],'unexpected checkpoint')
  local a5=cpu.state.A5.value;local room=mem:read_u16(a5-0xcd68);local camera=mem:read_u16(a5-0xcd70)
  if label=='loop' then
   if room==7 and camera==1 then landing=true end
   if active then
    print(string.format('SCENE_STAGE step=%u stage=next-loop ticks=%u room=%u camera=%u actor=-1 body=-1',step,mem:read_u32(0x16a),room,camera))
    if room~=1 or camera~=2 then
     assert(step>=5,'too few steps');done=true;print('PASS original natural corridor scene stages');dbg:command('quit');return
    end
    step=step+1
   elseif landing and room==1 and camera==2 then
    assert(mem:read_u16(a5-0xd8f2)==0,'Carnby comparison required');active=true
    local dark=assert(segmentbase(4))
    assert(mem:read_u16(dark+0x3cce)==0x4e56,'scene-enter bytes');points[dark+0x3cce]='scene-enter';cpu.debug:bpset(dark+0x3cce,'1','')
    assert(mem:read_u16(dark+0x3d90)==0x2f3c,'background-done bytes');points[dark+0x3d90]='background-done';cpu.debug:bpset(dark+0x3d90,'1','')
    assert(mem:read_u16(dark+0x3dec)==0x7a00,'actors-begin bytes');points[dark+0x3dec]='actors-begin';cpu.debug:bpset(dark+0x3dec,'1','')
    assert(mem:read_u16(dark+0x3e28)==0x7025,'actor-ready bytes');points[dark+0x3e28]='actor-ready';cpu.debug:bpset(dark+0x3e28,'1','')
    assert(mem:read_u16(dark+0x3e8c)==0x4eb9,'animate bytes');points[dark+0x3e8c]='animate';cpu.debug:bpset(dark+0x3e8c,'1','')
    assert(mem:read_u16(dark+0x3e92)==0x4fef,'animate-return bytes');points[dark+0x3e92]='animate-return';cpu.debug:bpset(dark+0x3e92,'1','')
    assert(mem:read_u16(dark+0x3ed4)==0x4eb9,'model bytes');points[dark+0x3ed4]='model';cpu.debug:bpset(dark+0x3ed4,'1','')
    assert(mem:read_u16(dark+0x3eda)==0x4fef,'model-return bytes');points[dark+0x3eda]='model-return';cpu.debug:bpset(dark+0x3eda,'1','')
    assert(mem:read_u16(dark+0x3fba)==0x4eba,'mask bytes');points[dark+0x3fba]='mask';cpu.debug:bpset(dark+0x3fba,'1','')
    assert(mem:read_u16(dark+0x3fbe)==0x4eba,'mask-return bytes');points[dark+0x3fbe]='mask-return';cpu.debug:bpset(dark+0x3fbe,'1','')
    assert(mem:read_u16(dark+0x3fc2)==0x588f,'actor-copy-return bytes');points[dark+0x3fc2]='actor-copy-return';cpu.debug:bpset(dark+0x3fc2,'1','')
    assert(mem:read_u16(dark+0x3fe6)==0x3039,'actors-done bytes');points[dark+0x3fe6]='actors-done';cpu.debug:bpset(dark+0x3fe6,'1','')
    assert(mem:read_u16(dark+0x4190)==0x3f39,'overlay bytes');points[dark+0x4190]='overlay';cpu.debug:bpset(dark+0x4190,'1','')
    assert(mem:read_u16(dark+0x419a)==0x4a46,'overlay-return bytes');points[dark+0x419a]='overlay-return';cpu.debug:bpset(dark+0x419a,'1','')
    assert(mem:read_u16(dark+0x41e6)==0x4cdf,'scene-exit bytes');points[dark+0x41e6]='scene-exit';cpu.debug:bpset(dark+0x41e6,'1','')
   end
  elseif active then
   local actor,body=-1,-1
   if label=='actor-ready' or label=='animate' or label=='animate-return' or label=='model' or label=='model-return' or label=='mask' or label=='mask-return' or label=='actor-copy-return' then
    actor=mem:read_i16(cpu.state.A3.value);body=mem:read_i16(cpu.state.A3.value+2)
   end
   print(string.format('SCENE_STAGE step=%u stage=%s ticks=%u room=%u camera=%u actor=%d body=%d',step,label,mem:read_u32(0x16a),room,camera,actor,body))
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return')
  mac.wait(48000);error('corridor completion absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
