local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens) do screen=v end
local dbg=assert(manager.machine.debugger)
local codes={0xa860,0xa970,0xa976,0xa974,0xa973,0xa032,0xa9b3,0xa856}
local counts={0,0,0,0,0,0,0,0};local observing=false
local fightPC;local fightConsumed=false
emu.register_periodic(function()
 if not observing or dbg.execution_state~='stop' then return end
 if fightPC and (cpu.state.PC.value&0xffffff)==fightPC then
  fightConsumed=true;print('INPUT_FIGHT_EVENT tick='..mem:read_u32(0x16a)..' delivered=1')
  dbg.execution_state='run';return
 end
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
local appWorld
local function snap(n)
 local a5=assert(appWorld);local a=a5-0xb292+160
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
  appWorld=mem:read_u32(0x904)&0xffffff
  local actor=appWorld-0xb292+160
  assert(mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12 and mem:read_i16(actor+0x30)==0 and mem:read_i16(actor+0x32)==0,'Carnby attic identity')
  local meta=dofile('tmp/mac-trap-map.lua');local dark
  for i,j in ipairs(meta.jt)do if j[1]==4 then dark=(mem:read_u32(appWorld+36+(i-1)*8)&0xffffff)-j[2];break end end
  assert(dark and mem:read_u32(dark+0x58e8)==0x0c790066,'original Fight dispatch bytes')
  fightPC=dark+0x58e8
  for _,alias in ipairs({0,0x80000000})do
   cpu.debug:bpset(fightPC|alias,string.format('w@%x==0x66 || w@%x==0x46',appWorld-0xd84c,appWorld-0xd84c),'')
  end
  local function accept(n,minimum,animation,fight)
   waitticks(minimum)
   assert(mac.wait_for('gameplay command '..n,function()
    return (not animation or mem:read_i16(actor+0x3e)==animation)
       and (not fight or fightConsumed)
   end,1200))
   print(string.format('INPUT_ACCEPT stage=%d tick=%d anim=%d actions=%d room=%d floor=%d',n,mem:read_u32(0x16a),mem:read_i16(actor+0x3e),mem:read_u16(appWorld-0xd868),mem:read_i16(actor+0x30),mem:read_i16(actor+0x32)))
   snap(n)
  end
  observe();accept(1,300,4);mac.key_down('Up Arrow');accept(2,60,254);mac.key_up('Up Arrow')
  accept(3,30,4);mac.key_down('Shift');mac.key_down('Up Arrow');accept(4,60,255);mac.key_up('Up Arrow');mac.key_up('Shift')
  accept(5,30,4);mac.key_down('f');accept(6,20,nil,true);mac.key_up('f')
  accept(7,30,nil,true);mac.key_down('Space');mac.key_down('Up Arrow');accept(8,90,262);mac.key_up('Up Arrow');mac.key_up('Space');accept(9,60,4)
  observing=false;print('CONTROL_TRAPS '..table.concat(counts,','));print('PASS original gameplay controls');manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
