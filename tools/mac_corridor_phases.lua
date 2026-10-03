-- Read-only natural Carnby corridor drawing stages; no state replay.
-- Create tmp/corridor-phases/mac before the standard Mac IIx reference run.
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
local sample=0
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local function save(name,address,size)
 local f=assert(io.open('tmp/corridor-phases/mac/'..name..'.bin','wb'))
 local parts={};for i=0,size-1 do parts[#parts+1]=string.char(mem:read_u8(address+i))end
 f:write(table.concat(parts));f:close()
end
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
    print(string.format('CORRIDOR_PHASE sample=%u phase=next-loop ticks=%u room=%u camera=%u',sample,mem:read_u32(0x16a),room,camera))
    local pm=ptr(ptr(ptr(ptr(0x8a4))+22));assert(mem:read_u16(pm+32)==8,'display depth')
    save(string.format('%03d-screen',sample),mem:read_u32(pm),307200)
    if room~=1 or camera~=2 then
     assert(sample>=5,'too few renders');done=true;print('PASS original natural corridor phases');dbg:command('quit');return
    end
   elseif landing and room==1 and camera==2 then
    assert(mem:read_u16(a5-0xd8f2)==0,'Carnby comparison required');active=true
    local dark=assert(segmentbase(4));assert(mem:read_u16(dark+0x3ed4)==0x4eb9,'draw bytes')
    points[dark+0x3ed4]='draw';cpu.debug:bpset(dark+0x3ed4,'w@(a3)==0x120','')
    local at=assert(segmentbase(6))+0x1da0;assert(mem:read_u16(at)==0x48e7,'model-setup bytes');points[at]='model-setup';cpu.debug:bpset(at,'1','')
    local at=assert(segmentbase(6))+0x1e3c;assert(mem:read_u16(at)==0x8040,'vertices-done bytes');points[at]='vertices-done';cpu.debug:bpset(at,'1','')
    local at=assert(segmentbase(6))+0x1e66;assert(mem:read_u16(at)==0x3439,'surfaces-prepared bytes');points[at]='surfaces-prepared';cpu.debug:bpset(at,'1','')
    local at=assert(segmentbase(6))+0x1efe;assert(mem:read_u16(at)==0x41f9,'sort-done bytes');points[at]='sort-done';cpu.debug:bpset(at,'1','')
    local at=assert(segmentbase(6))+0x1f2e;assert(mem:read_u16(at)==0x4280,'draw-list-done bytes');points[at]='draw-list-done';cpu.debug:bpset(at,'1','')
    local at=assert(segmentbase(4))+0x3eda;assert(mem:read_u16(at)==0x4fef,'draw-return bytes');points[at]='draw-return';cpu.debug:bpset(at,'1','')
   end
  elseif active then
   if label=='draw' then
    sample=sample+1;local sp=cpu.state.A7.value;local actor=cpu.state.A3.value;local body=ptr(sp+12)
    assert(mem:read_u16(actor+2)==265 and mem:read_u16(body)==3,'person model')
    save(string.format('%03d-body',sample),body,3438)
    save(string.format('%03d-args',sample),sp,16)
    save(string.format('%03d-actor',sample),actor,160)
   end
   if sample>0 then print(string.format('CORRIDOR_PHASE sample=%u phase=%s ticks=%u room=%u camera=%u',sample,label,mem:read_u32(0x16a),room,camera))end
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
