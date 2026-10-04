-- Original keyboard menu and natural driver shutdown capture. No instruction/state patches.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local dbg=assert(manager.machine.debugger);local active=false;local returning=false;local keychar;local ret;local enteredSP;local commands=0
local meta=dofile('tmp/mac-trap-map.lua')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return ptr(ptr(0x904)+36+(i-1)*8)-j[2]end end
 error('MENUS / SEGMENT')
end
local function bytes(a,n)local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(out)end
local function save(name,a,n)
 local f=assert(io.open('tmp/m3-menu/'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local driverPhase=false;local driverDone=false;local driverEntry;local driverSP;local driverCall
local function arm()
 cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==0xa93e','')
 if not driverDone then cpu.debug:bpset(driverCall,'1','')end
end
local function driverState(phase)
 local tail='';for _,r in ipairs({'SR','D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER8_%s sp=%X selector=%X argument=%X entry=%X',phase,cpu.state.A7.value,mem:read_u32(driverSP),mem:read_u32(driverSP+4),driverEntry)..tail)
 save('driver8-'..phase:lower()..'-state',driverEntry+0x4200,0x3048)
end
emu.register_periodic(function()
 if not active or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if driverPhase then
   assert(cpu.state.PC.value==driverCall+2 and cpu.state.A7.value==driverSP,'MENUS / DRIVER RETURN')
   driverState('RETURN');driverDone=true;driverPhase=false;dbg:command('bpclear');arm()
  elseif cpu.state.PC.value==driverCall then
   assert(bytes(driverCall-8,12)=='48780008206DF9544E90588F','MENUS / QUIT BYTES')
   print('DRIVER8_BYTES '..bytes(driverCall-8,12));driverEntry=ptr(cpu.state.A5.value-0x6ac);driverSP=cpu.state.A7.value
   save('driver8-driver',driverEntry,0x7248);driverState('ENTER');driverPhase=true
   dbg:command('bpclear');cpu.debug:bpset(driverCall+2,'1','')
  elseif not returning then
   enteredSP=cpu.state.A7.value;local pc=ptr(enteredSP+2)
   assert(mem:read_u16(pc)==0xa93e);keychar=mem:read_u16(enteredSP+8)
   ret=mem:read_u32(enteredSP+2)+2;print(string.format('MENUKEY_ENTER key=%X pc=%X sp=%X',keychar,pc,enteredSP))
   dbg:command('bpclear');cpu.debug:bpset(ret,'1','');returning=true
  else
   commands=commands+1
   print(string.format('MENUKEY_RETURN key=%X result=%X delta=%d',keychar,mem:read_u32(cpu.state.A7.value),cpu.state.A7.value-enteredSP))
   returning=false;dbg:command('bpclear');arm()
  end
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
local function key(name,cmd)
 if cmd then mac.key_down(mac.CMD) end
 mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name)
 if cmd then mac.key_up(mac.CMD) end
 mac.wait(10)
end
local function pixels(points)
 local raw,w,h=screen:pixels();if w~=640 or h~=480 then return false end
 for _,p in ipairs(points)do if(string.unpack('I4',raw,4*(p[2]*w+p[1])+1)&0xffffff)~=p[3]then return false end end
 return true
end
local function room()return pixels({{180,160,0x814530},{290,245,0x7d6154},{400,300,0x71584a}})end
local function slot()return pixels({{190,180,0x84653b},{400,210,0x81a1a1},{200,345,0}})end
local function shot(name)
 print('MENU_STATE '..name..' ticks='..mem:read_u32(0x16a))
 local raw,w,h=screen:pixels();assert(w==640 and h==480)
 local f=assert(io.open('tmp/m3-menu/mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
end
local function state(name,fn)if not mac.wait_for(name,fn,1800)then shot('FAIL-'..name);error('MENU STATE '..name)end;shot(name)end
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
  active=true;driverCall=base(3)+0x1dcc;arm();dbg.execution_state='run'
  shot('attic')
  key('s');mac.wait(60);shot('sound-off');key('s');mac.wait(60);shot('sound-on')
  key('m');mac.wait(60);shot('music-off');key('m');mac.wait(120);shot('music-on')
  key('s',true);state('save',slot);key('Esc');state('save-cancel',room)
  key('o',true);state('load',slot);key('Esc');state('load-cancel',room)
  key('q',true);state('quit',function()return mac.frontmost()=='Finder'end)
  assert(commands==3 and driverDone,'MENU COMMAND/QUIT COUNT');print('PASS original keyboard menus commands='..commands);manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
