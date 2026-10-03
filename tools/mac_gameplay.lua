local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens) do screen=v end
local dbg=assert(manager.machine.debugger)
local codes={0xa860,0xa970,0xa976,0xa974,0xa973,0xa032,0xa9b3,0xa856}
local counts={0,0,0,0,0,0,0,0};local observing=false
emu.register_periodic(function()
 if not observing or dbg.execution_state~='stop' then return end
 local pc=mem:read_u32(cpu.state.A7.value+2)&0xffffff;local trap=mem:read_u16(pc)
 for i,v in ipairs(codes) do if trap==v then
  counts[i]=counts[i]+1
  if counts[i]==1 then print(string.format('CONTROL_TRAP trap=%X pc=%X d0=%X',trap,pc,cpu.state.D0.value)) end
 end end
 dbg.execution_state='run'
end)
local function observe()
 local cond={};for _,v in ipairs(codes) do cond[#cond+1]=string.format('w@(d@(sp+2))==0x%x',v) end
 cpu.debug:bpset(0xdd60,table.concat(cond,' || '),'');observing=true;dbg.execution_state='run'
end
local function key(name) mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10) end
local function waitticks(n) local t=mem:read_u32(0x16a);assert(mac.wait_for('tick interval',function()return mem:read_u32(0x16a)-t>=n end,1800)) end
local function snap(n)
 local a5=mem:read_u32(0x904)&0xffffff;local a=a5-0xb292+160
 local f=assert(io.open('tmp/m3-input/mac-input-'..n..'-actor.bin','wb'));for i=0,159 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
 print(string.format('CONTROL stage=%d tick=%d actor=%d body=%d x=%d z=%d anim=%d frame=%d key=%d direction=%d action=%d',n,mem:read_u32(0x16a),mem:read_i16(a),mem:read_i16(a+2),mem:read_i16(a+0x1c),mem:read_i16(a+0x20),mem:read_i16(a+0x3e),mem:read_i16(a+0x4a),mem:read_i16(a5-0x11af4),mem:read_i16(a5-0x11af8),mem:read_i16(a5-0x11af0)))
 screen:snapshot('m3-input-'..n..'.png')
end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function window320()
   local w=mem:read_u32(0x9d6)&0xffffff
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=mem:read_u32(w+0x90)&0xffffff
   end
   return false
  end
  if not window320() then assert(mac.mouse_to(256,274));mac.click(1) end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
  key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180)
  key('Esc')
  assert(mac.wait_for('attic',function()
   local raw,w,h=screen:pixels();if w~=640 or h~=480 then return false end
   return (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
  end,1800))
  observe();snap(1);mac.key_down('Up Arrow');waitticks(60);snap(2);mac.key_up('Up Arrow');waitticks(30)
  snap(3);mac.key_down('Shift');mac.key_down('Up Arrow');waitticks(60);snap(4);mac.key_up('Up Arrow');mac.key_up('Shift');waitticks(30)
  snap(5);mac.key_down('f');waitticks(20);snap(6);mac.key_up('f');waitticks(30)
  snap(7);mac.key_down('Space');mac.key_down('Up Arrow');waitticks(90);snap(8);mac.key_up('Up Arrow');mac.key_up('Space');waitticks(60);snap(9)
  observing=false;print('CONTROL_TRAPS '..table.concat(counts,','));print('PASS original gameplay controls');manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
