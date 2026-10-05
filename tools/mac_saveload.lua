-- Ordinary save/write/close, movement, real load/read and restored actor proof.
-- Observe Dialog Manager/StandardFile while the original game supplies its UI.
-- Ordinary keyboard route only: no instruction, resource or game-state edits.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local active=false;local pending;local refs={};local savedClosed=0;local loadedRead=0;local saving=false;local loading=false
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function nameAt(a)
 if not a or a==0 then return '' end
 local n=mem:read_u8(a);local t={};for i=1,n do t[#t+1]=string.char(mem:read_u8(a+i))end;return table.concat(t)
end
local function armIO()
 dbg:command('bpclear')
 cpu.debug:bpset(0xdd60,'a0!=0 && b@910==0x11 && (w@(d@(sp+2))==0xa000 || w@(d@(sp+2))==0xa200 || w@(d@(sp+2))==0xa001 || w@(d@(sp+2))==0xa002 || w@(d@(sp+2))==0xa003 || ((w@(d@(sp+2))==0xa060 || w@(d@(sp+2))==0xa260) && (d0&0xffff)==0x1a))','')
 dbg.execution_state='run'
end
emu.register_periodic(function()
 if not active or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not pending then
   local sp=cpu.state.A7.value;local pc=mem:read_u32(sp+2);local trap=mem:read_u16(pc);local pb=cpu.state.A0.value&0xffffff
   pending={trap=trap,pb=pb,ref=mem:read_i16(pb+24),name=(trap==0xa000 or trap==0xa200 or trap==0xa060 or trap==0xa260) and nameAt(ptr(pb+18)) or ''}
   print(string.format('SAVELOAD_IO_ENTER trap=%04X pc=%X pb=%X ref=%d name=%s',trap,pc,pb,pending.ref,pending.name))
   dbg:command('bpclear')
   cpu.debug:bpset(pc+2,'1','')
   if pc<0x1000000 then cpu.debug:bpset((pc+2)|0x80000000,'1','')end
  else
   local p=pending;local error=mem:read_i16(p.pb+16)
   print(string.format('SAVELOAD_IO_RETURN trap=%04X result=%d ref=%d actual=%d',p.trap,error,mem:read_i16(p.pb+24),mem:read_u32(p.pb+40)))
   if error==0 then
    if p.trap==0xa000 or p.trap==0xa200 or p.trap==0xa060 or p.trap==0xa260 then
     if p.name:upper():find('SAVE0.ITD',1,true) then refs[mem:read_i16(p.pb+24)]={write=0} end
    elseif p.trap==0xa003 and saving and refs[p.ref] then
     refs[p.ref].write=refs[p.ref].write+mem:read_u32(p.pb+40)
    elseif p.trap==0xa001 and refs[p.ref] then
     if refs[p.ref].write>10000 then savedClosed=refs[p.ref].write;print('SAVELOAD_WRITE_CLOSED bytes='..savedClosed..' tick='..mem:read_u32(0x16a))end
     refs[p.ref]=nil
    elseif p.trap==0xa002 and loading and refs[p.ref] then
     loadedRead=loadedRead+mem:read_u32(p.pb+40)
    end
   end
   pending=nil;armIO()
  end
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL SAVELOAD IO '..tostring(err));manager.machine:exit()end
end)
local function key(name,command)
 if command then mac.key_down(mac.CMD)end
 mac.wait(2);mac.key_down(name);mac.wait(8);mac.key_up(name)
 if command then mac.key_up(mac.CMD)end
 mac.wait(10)
end
local function pixels(points)
 local raw,w,h=screen:pixels();assert(w==640 and h==480)
 for _,p in ipairs(points)do
  if(string.unpack('I4',raw,4*(p[2]*w+p[1])+1)&0xffffff)~=p[3]then return false end
 end
 return true
end
local function room()return pixels({{180,160,0x814530},{290,245,0x7d6154},{400,300,0x71584a}})end
local function slot()return pixels({{190,180,0x84653b},{400,210,0x81a1a1},{200,345,0}})end
local function capture(name)
 local raw,w,h=screen:pixels();assert(w==640 and h==480)
 local f=assert(io.open('tmp/m3-saveload/mac-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
 print('DIALOG_STATE '..name..' ticks='..mem:read_u32(0x16a))
end
local function state(name,fn)
 assert(mac.wait_for(name,fn,1800),'DIALOG STATE '..name);capture(name)
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
  if not window320()then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  mac.wait(3000);key('Space');mac.wait(120);capture('main-menu')
  key('Return');mac.wait(720);capture('new-game')
  key('Right Arrow');key('Return');mac.wait(240);capture('character-story')
  key('Return');mac.wait(180);key('Esc');state('attic',room)
  local world;local actor
  assert(mac.wait_for('application Carnby world',function()
   local w=ptr(0x904);local a=w-0xb292+160
   if a>0 and a<0x7fffff and mem:read_i16(a)==1 and mem:read_i16(a+2)==12 and mem:read_i16(a+0x30)==0 and mem:read_i16(a+0x2e)==0 then world=w;actor=a;return true end
   return false
  end,1200))
  local function snapshot(phase)
   print(string.format('SAVELOAD_STATE phase=%s tick=%d x=%d z=%d anim=%d room=%d floor=%d closed=%d read=%d',phase,mem:read_u32(0x16a),mem:read_i16(actor+0x1c),mem:read_i16(actor+0x20),mem:read_i16(actor+0x3e),mem:read_i16(actor+0x30),mem:read_i16(actor+0x2e),savedClosed,loadedRead))
   local f=assert(io.open('tmp/m3-saveload/mac-'..phase..'-actor.bin','wb'));for i=0,159 do f:write(string.char(mem:read_u8(actor+i)))end;f:close()
  end
  snapshot('before-save');local savedX=mem:read_i16(actor+0x1c);local savedZ=mem:read_i16(actor+0x20)
  active=true;saving=true;armIO()
  key('s',true);state('save-name',slot)
  local backspace
  for _,port in pairs(manager.machine.ioport.ports)do for name,_ in pairs(port.fields)do if name:find('Backspace')then backspace=name end end end
  assert(backspace);for _=1,31 do key(backspace)end
  mac.type('m3test');key('Return');state('saved',room)
  assert(savedClosed>10000,'actual save write/close');saving=false;snapshot('saved')
  mac.key_down('Up Arrow')
  assert(mac.wait_for('real walk after save',function()return math.abs(mem:read_i16(actor+0x20)-savedZ)>=300 and mem:read_i16(actor+0x3e)==254 end,1200))
  mac.key_up('Up Arrow');mac.wait(30)
  assert(mac.wait_for('walk released',function()return mem:read_i16(actor+0x3e)==4 end,1200));snapshot('moved')
  loading=true;key('o',true);state('load',slot);key('Return')
  assert(mac.wait_for('restored actor',function()return loadedRead>10000 and mem:read_i16(actor+0x1c)==savedX and mem:read_i16(actor+0x20)==savedZ and mem:read_i16(actor+0x3e)==4 end,1800))
  state('loaded',room);snapshot('loaded');active=false;dbg:command('bpclear')
  key('q',true);assert(mac.wait_for('Finder',function()return mac.frontmost()=='Finder'end,1800))
  print('PASS original save move load restored actor and quit');manager.machine:exit()
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
