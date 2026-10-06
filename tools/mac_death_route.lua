-- Ordinary control sequence, natural death, menu and a fresh Carnby game.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens) do screen=v end
local dbg=assert(manager.machine.debugger)
local codes={0xa860,0xa970,0xa976,0xa974,0xa973,0xa032,0xa9b3,0xa856}
local counts={0,0,0,0,0,0,0,0};local observing=false
local fightPC;local fightConsumed=false
local deathPC;local deathReturn;local deathState;local deathWorld;local deathReturned=false
emu.register_periodic(function()
 if dbg.execution_state~='stop' then return end
 if deathPC then
  local pc=cpu.state.PC.value&0xffffff
  if pc==deathPC and not deathState then
   local sp=cpu.state.A7.value;assert(mem:read_u32(sp+4)==131,'death song argument')
   deathState={sp=sp,tick=mem:read_u32(0x16a)}
   for _,r in ipairs({'D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do deathState[r]=cpu.state[r].value end
   print(string.format('DEATH_ENTER tick=%d mode=%d room=%d anim=%d',deathState.tick,mem:read_u8(deathWorld-0x11b4c),mem:read_i16(deathWorld-0xcd68),mem:read_i16(deathWorld-0xb292+160+0x3e)))
   dbg:command('bpclear')
   for _,alias in ipairs({0,0x80000000})do cpu.debug:bpset(deathReturn|alias,'1','')end
   deathPC=deathReturn;dbg.execution_state='run';return
  elseif deathState and pc==deathReturn then
   assert(cpu.state.A7.value==deathState.sp and cpu.state.D0.value==0 and cpu.state.D1.value==12,'death song return ABI')
   for _,r in ipairs({'D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do assert(cpu.state[r].value==deathState[r],'death song preserved '..r)end
   print(string.format('DEATH_RETURN tick=%d preserved=13 result=0/12',mem:read_u32(0x16a)))
   deathReturned=true;deathPC=nil;dbg:command('bpclear');dbg.execution_state='run';return
  end
 end
 if not observing then return end
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
  assert(mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12 and mem:read_i16(actor+0x30)==0 and mem:read_i16(actor+0x2e)==0,'Carnby attic identity')
  local meta=dofile('tmp/mac-trap-map.lua');local dark
  for i,j in ipairs(meta.jt)do if j[1]==4 then dark=(mem:read_u32(appWorld+36+(i-1)*8)&0xffffff)-j[2];break end end
  assert(dark and mem:read_u32(dark+0x58e8)==0x0c790066,'original Fight dispatch bytes')
  fightPC=dark+0x58e8
  for _,alias in ipairs({0,0x80000000})do
   cpu.debug:bpset(fightPC|alias,string.format('w@0x%x==0x66 || w@0x%x==0x46',appWorld-0xd84c,appWorld-0xd84c),'')
  end
  local function accept(n,minimum,animation,fight)
   waitticks(minimum)
   assert(mac.wait_for('gameplay command '..n,function()
    return (not animation or mem:read_i16(actor+0x3e)==animation)
       and (not fight or fightConsumed)
   end,1200))
   print(string.format('INPUT_ACCEPT stage=%d tick=%d anim=%d actions=%d room=%d floor=%d',n,mem:read_u32(0x16a),mem:read_i16(actor+0x3e),mem:read_u16(appWorld-0xd868),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e)))
   snap(n)
  end
  observe();accept(1,300,4);mac.key_down('Up Arrow');accept(2,60,254);mac.key_up('Up Arrow')
  accept(3,30,4);mac.key_down('Shift');mac.key_down('Up Arrow');accept(4,60,255);mac.key_up('Up Arrow');mac.key_up('Shift')
  accept(5,30,4);mac.key_down('f');accept(6,20,nil,true);mac.key_up('f')
  accept(7,30,nil,true);mac.key_down('Space');mac.key_down('Up Arrow');accept(8,90,262);mac.key_up('Up Arrow');mac.key_up('Space');accept(9,60,4)
  observing=false;print('CONTROL_TRAPS '..table.concat(counts,','));print('PASS original gameplay controls')
  mac.key_down('Down Arrow')
  assert(mac.wait_for('return to starting area',function()return mem:read_i16(actor+0x20)>=-1548 end,1200))
  mac.key_up('Down Arrow');waitticks(30)
  assert(mac.wait_for('backward key released',function()return mem:read_i16(actor+0x3e)==4 end,1200))
  print(string.format('DEATH_BACK tick=%d x=%d z=%d anim=%d',mem:read_u32(0x16a),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x3e)))
  dbg:command('bpclear');local core
  for i,j in ipairs(meta.jt)do if j[1]==3 then core=(mem:read_u32(appWorld+36+(i-1)*8)&0xffffff)-j[2];break end end
  assert(core and mem:read_u16(core+0x138c)==0x4e90 and mem:read_u16(core+0x138e)==0x508f,'death song caller bytes')
  deathPC=core+0x138c;deathReturn=core+0x138e;deathWorld=appWorld
  for _,alias in ipairs({0,0x80000000})do cpu.debug:bpset(deathPC|alias,'d@(sp+4)==0x83','')end
  local previous=-1
  for i=1,600 do
   mac.wait(60)
   if deathReturned then break end
   local mode=mem:read_u8(appWorld-0x11b4c)
   if mode~=previous or i%10==0 then
    print(string.format('DEATH_STATE tick=%d mode=%d room=%d floor=%d anim=%d x=%d z=%d word88=%d',mem:read_u32(0x16a),mode,mem:read_i16(appWorld-0xcd68),mem:read_i16(actor+0x2e),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+88)));previous=mode
   end
  end
  assert(deathReturned,'natural death call deadline')
  assert(mac.wait_for('death menu',function()return mem:read_u8(appWorld-0x11b4c)==2 end,12000))
  print('DEATH_MENU tick='..mem:read_u32(0x16a))
  mac.wait(60);key('Return');mac.wait(720)
  key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
  assert(mac.wait_for('restarted Carnby attic',function()
   return mem:read_u8(appWorld-0x11b4c)==1 and mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12
     and mem:read_i16(actor+0x1c)==3231 and mem:read_i16(actor+0x20)==-1548
     and mem:read_i16(actor+0x30)==0 and mem:read_i16(actor+0x2e)==0 and mem:read_i16(actor+0x3e)==4
  end,1800))
  assert(mac.wait_for('restarted attic publication',function()
   local raw,w,h=screen:pixels();if w~=640 or h~=480 then return false end
   return (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
  end,1800))
  dofile('tools/mame_mac_frame.lua').rgb('tmp/m3-death/death-restart-mac-rgb.bin')
  local f=assert(io.open('tmp/m3-death/death-restart-mac-actor.bin','wb'));for i=0,159 do f:write(string.char(mem:read_u8(actor+i)))end;f:close()
  print(string.format('DEATH_RESTART tick=%d actor=%d body=%d x=%d z=%d anim=%d room=%d floor=%d',mem:read_u32(0x16a),mem:read_i16(actor),mem:read_i16(actor+2),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e)))
  print('PASS original natural death music ABI and new-game restart');manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
