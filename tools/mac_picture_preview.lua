-- Original saved-preview DrawPicture, filtering, lookup cube and visible choice.
-- Ordinary input and read-only observations; no game or system memory edits.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local screen;for _,v in pairs(manager.machine.screens)do screen=v end
local folder=os.getenv('AITD_PICTURE_PREVIEW_DIR') or 'tmp/picture-preview'
local function ptr(a)return mem:read_u32(a)&0xffffff end
local thePortAddr
local previewPending=false
local lineNo=0
local previewArmed=false
local previewDone=false
local previewArgs,previewReturn,previewHandle,previewBody,previewRect,previewPort,previewMap,previewPixels,previewBytes
local function dump(name,a,n)
 local f=assert(io.open(folder..'/source-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function armPreview()
 previewArmed=true;dbg:command('bpclear')
 cpu.debug:bpset(0xdd60,'b@910==0x11 && (w@(d@(sp+2))==0xa86e || w@(d@(sp+2))==0xa8f6)','')
 dbg.execution_state='run'
end
emu.register_frame_done(function()
 if previewArmed or mem:read_u32(0x28)~=0xdd60 then return end
 armPreview()
end)
emu.register_periodic(function()
 if not previewArmed or previewDone or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not previewPending then
   local sp=cpu.state.A7.value
   if mem:read_u16(ptr(sp+2))==0xa86e then thePortAddr=ptr(sp+8);armPreview();return end
   previewArgs=sp+8;previewReturn=ptr(sp+2)+2
   previewRect=ptr(previewArgs);previewHandle=ptr(previewArgs+4);previewBody=ptr(previewHandle)
   if mem:read_u16(previewBody)~=55492 then armPreview();return end
   previewPort=ptr(assert(thePortAddr,'actual InitGraf pointer'))
   previewMap=ptr(ptr(previewPort+2));previewPixels=mem:read_u32(previewMap)
   assert(mem:read_u16(previewMap+32)==8,'eight-bit window')
   previewBytes=(mem:read_u16(previewMap+4)&0x3fff)*(mem:read_i16(previewMap+10)-mem:read_i16(previewMap+6))
   print(string.format('PREVIEW_ENTER return=%X rect=%d,%d,%d,%d size=%d stride=%d pixels=%X',previewReturn,mem:read_i16(previewRect),mem:read_i16(previewRect+2),mem:read_i16(previewRect+4),mem:read_i16(previewRect+6),mem:read_u16(previewBody),mem:read_u16(previewMap+4)&0x3fff,previewPixels))
   dump('picture',previewBody,mem:read_u16(previewBody));dump('rect',previewRect,8)
   dump('port',previewPort,108);dump('pm',previewMap,50);dump('before',previewPixels,previewBytes)
   for _,r in ipairs({{'vis',24},{'clip',28}})do local q=ptr(ptr(previewPort+r[2]));dump(r[1],q,mem:read_u16(q))end
   dump('colors',ptr(ptr(previewMap+42)),2056)
   local gd=ptr(ptr(0x8a4));local dp=ptr(ptr(gd+22));dump('device',gd,64);dump('device-colors',ptr(ptr(dp+42)),2056);dump('device-inverse',ptr(ptr(gd+6)),4620)
   dbg:command('bpclear');cpu.debug:bpset(previewReturn,'1','');cpu.debug:bpset(previewReturn|0x80000000,'1','')
   assert(mem:read_u16(0x240a4)==0x302e and mem:read_u16(0x26328)==0x48e7,'measured QuickDraw loop bytes');cpu.debug:bpset(0x240a4,'1','');cpu.debug:bpset(0x24524,'1','');cpu.debug:bpset(0x26150,'1','');cpu.debug:bpset(0x26328,'1','');previewPending=true;dbg.execution_state='run'
  else
   local pc=cpu.state.PC.value&0xffffff
   local a6=cpu.state.A6.value&0xffffff
   if pc==0x24524 then
    print(string.format('SHRINK_VERTICAL line=%d count=%d width=%d src=%X stride=%d err=%d height=%d destHeight=%d',lineNo,cpu.state.D7.value&0xffff,cpu.state.D4.value&0xffff,cpu.state.A3.value,mem:read_u32(a6-0x1bc),mem:read_i16(a6-0x23e),mem:read_i16(a6-0x20c),mem:read_i16(a6-0x208)))
   elseif pc==0x26150 then
    print(string.format('SHRINK_HORIZONTAL line=%d ratio=%d depth=%d source=%X dest=%X end=%X',lineNo,cpu.state.D4.value&0xffff,cpu.state.D5.value&0xffff,cpu.state.A0.value,cpu.state.A1.value,cpu.state.A2.value))
   elseif pc==0x240a4 then
    lineNo=lineNo+1;dump('filtered-'..lineNo,ptr(a6-0x1d8),352)
   elseif pc==0x26328 then
    print(string.format('DITHER_LINE line=%d src=%X dst=%X end=%X inverse=%X colors=%X resolution=%d errors=%X flag=%d',lineNo,cpu.state.A0.value,cpu.state.A1.value,cpu.state.A2.value,ptr(a6-0x28c),ptr(a6-0x29c),mem:read_i16(a6-0x29e),ptr(a6-0x2a4),mem:read_u8(a6-0x2a9)))
    if lineNo==1 then dump('dither-inverse',ptr(a6-0x28c),4096);dump('dither-colors',ptr(a6-0x29c),2056);dump('dither-errors',ptr(a6-0x2a4),528)end
   end
   if pc~=previewReturn then dbg.execution_state='run';return end
   previewDone=true
   print(string.format('PREVIEW_RETURN pc=%X',cpu.state.PC.value))
   dump('after',previewPixels,previewBytes)
   dump('return-pm',previewMap,50);dump('return-port',previewPort,108)
   dbg:command('bpclear');dbg.execution_state='run'
  end
 end)
 if not ok then print('FAIL preview '..tostring(err));dbg:command('quit')end
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
 local f=assert(io.open(folder..'/ordinary-'..name..'-rgb.bin','wb'));f:write(raw);f:close()
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
  local actor
  assert(mac.wait_for('application Carnby world',function()
   local w=ptr(0x904);local a=w-0xb292+160
   if a>0 and a<0x7fffff and mem:read_i16(a)==1 and mem:read_i16(a+2)==12 and mem:read_i16(a+0x30)==0 and mem:read_i16(a+0x2e)==0 then actor=a;return true end
   return false
  end,1200))
  armPreview();key('o',true);state('firstfloor-load-choice',slot)
  assert(previewDone and lineNo==54,'complete actual preview draw')
  print('PASS original saved-preview DrawPicture return');dbg:command('quit')
 end)
 if not ok then print('FAIL '..tostring(err));dbg:command('quit')end
end)
dbg.execution_state='run'
