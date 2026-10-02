-- Four original instruction checkpoints; no intro skip or elapsed-frame pairing.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'INTRO / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function address(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then
  local entry=ptr(0x904)+32+(i-1)*8
  if mem:read_u16(entry+2)~=0x4ef9 then return nil end
  return ptr(entry+4)-j[2]
 end end
end
local states={{5,0x1c94,0x2d5f},{5,0x1f46,0x2f0b},{13,0x2ed4,0x42a7},{4,0x5220,0x6000}}
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local done=false;local state=1;local target
local function save(suffix,a,n)
 local f=assert(io.open('tmp/intro-reference-'..state..'-'..suffix..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end
 f:close()
end
local function armState()
 local s=states[state];local base=address(s[1])
 if not base then return end
 target=base+s[2]
 assert(mem:read_u16(target)==s[3],'INTRO / ORIGINAL CHECKPOINT BYTES')
 cpu.debug:bpset(target,'1','');dbg.execution_state='run'
end
local function nextState()
 state=state+1
 if state>#states then done=true;print('PASS original intro frames=4');dbg:command('quit');return end
 target=nil;dbg.execution_state='run'
end
emu.register_frame_done(function()
 if done or target or mac.frontmost()~=app then return end
 local a5=ptr(0x904)
 if a5<0x100000 or a5-ptr(0x908)~=75616 then return end
 local ok,err=pcall(armState)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
emu.register_periodic(function()
 if done or not target or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  dbg:command('bpclear')
  assert(cpu.state.PC.value==target,'INTRO / CHECKPOINT')
  if state==4 then assert(cpu.state.D0.value==0,'INTRO / SKIPPED')end
  local pm=ptr(ptr(ptr(ptr(0x8a4))+22));local ct=ptr(ptr(pm+42))
  assert(mem:read_u16(pm+32)==8 and (mem:read_u16(pm+4)&0x3fff)==640,'INTRO / DISPLAY LAYOUT')
  assert(mem:read_u16(ct+6)==255,'INTRO / PALETTE SIZE')
  save('screen',mem:read_u32(pm),307200);save('clut',ct,2056)
  print(string.format('INTRO_FRAME n=%u segment=%u offset=%X d0=%X',state,states[state][1],states[state][2],cpu.state.D0.value))
  nextState()
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function gameWindow()
   local w=ptr(0x9d6)
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=ptr(w+0x90)
   end
   return false
  end
  if not gameWindow() then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200 window',gameWindow,1800))
  assert(mac.mouse_to(620,470));mac.wait(42000);error('INTRO / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
