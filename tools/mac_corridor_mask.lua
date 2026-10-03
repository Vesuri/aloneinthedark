-- Read-only natural Carnby foreground-mask stages and exact polygon/region captures.
-- Create tmp/corridor-mask first; capture stdout there as mac.log.
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
local call,actor,poly=0,-1,0
local inCall=false
local function dump(name,address,bytes)
 local f=assert(io.open("tmp/corridor-mask/mac-"..name..".bin","wb"))
 local parts={}
 for i=0,bytes-1 do parts[#parts+1]=string.char(mem:read_u8(address+i))end
 f:write(table.concat(parts));f:close()
end
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
     assert(step>=5 and not inCall,'incomplete mask steps');done=true;print('PASS natural corridor mask stages');dbg:command('quit');return
    end
    step=step+1
   elseif landing and room==1 and camera==2 then
    assert(mem:read_u16(a5-0xd8f2)==0,'Carnby comparison required');active=true
    local dark=assert(segmentbase(4))
    assert(mem:read_u16(dark+0x3fba)==0x4eba,'begin bytes');points[dark+0x3fba]='begin';cpu.debug:bpset(dark+0x3fba,'1','')
    assert(mem:read_u16(dark+0x319a)==0x4a39,'clip-done bytes');points[dark+0x319a]='clip-done';cpu.debug:bpset(dark+0x319a,'1','')
    assert(mem:read_u16(dark+0x3266)==0x6000,'setup-done bytes');points[dark+0x3266]='setup-done';cpu.debug:bpset(dark+0x3266,'1','')
    assert(mem:read_u16(dark+0x3354)==0x2850,'cache bytes');points[dark+0x3354]='cache';cpu.debug:bpset(dark+0x3354,'1','')
    assert(mem:read_u16(dark+0x3394)==0x42a7,'build bytes');points[dark+0x3394]='build';cpu.debug:bpset(dark+0x3394,'1','')
    assert(mem:read_u16(dark+0x33ec)==0xa8c6,'polygon bytes');points[dark+0x33ec]='polygon';cpu.debug:bpset(dark+0x33ec,'1','')
    assert(mem:read_u16(dark+0x33ee)==0x2f0a,'polygon-done bytes');points[dark+0x33ee]='polygon-done';cpu.debug:bpset(dark+0x33ee,'1','')
    assert(mem:read_u16(dark+0x33f2)==0x2f0a,'close-done bytes');points[dark+0x33f2]='close-done';cpu.debug:bpset(dark+0x33f2,'1','')
    assert(mem:read_u16(dark+0x33fa)==0x2046,'inset-done bytes');points[dark+0x33fa]='inset-done';cpu.debug:bpset(dark+0x33fa,'1','')
    assert(mem:read_u16(dark+0x346c)==0xa8ec,'copy bytes');points[dark+0x346c]='copy';cpu.debug:bpset(dark+0x346c,'1','')
    assert(mem:read_u16(dark+0x346e)==0x95ca,'copy-done bytes');points[dark+0x346e]='copy-done';cpu.debug:bpset(dark+0x346e,'1','')
    assert(mem:read_u16(dark+0x3fbe)==0x4eba,'end bytes');points[dark+0x3fbe]='end';cpu.debug:bpset(dark+0x3fbe,'1','')
   end
  elseif active then
   if label=='begin' then
    assert(not inCall,'nested mask');inCall=true;call=call+1;actor=mem:read_i16(cpu.state.A3.value)
   end
   if inCall then
    print(string.format('MASK_STAGE step=%u call=%u actor=%d stage=%s ticks=%u',step,call,actor,label,mem:read_u32(0x16a)))
    if label=='polygon' then
     poly=poly+1;local record=ptr(ptr(cpu.state.SP.value));local bytes=mem:read_u16(record)
     assert(bytes>=26 and bytes<=270,'polygon extent');dump(string.format('poly-%03u',poly),record,bytes)
    elseif label=='inset-done' then
     local record=ptr(cpu.state.A2.value);local bytes=mem:read_u16(record)
     assert(bytes>=10 and bytes<=4096,'region extent');dump(string.format('region-%03u',poly),record,bytes)
    elseif label=='end' then inCall=false end
   end
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
