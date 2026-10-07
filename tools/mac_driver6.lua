-- Original music-voice stop. Optional isolated mode changes only a real call's
-- selector word in guest RAM; no instructions or CPU registers are modified.
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local folder=assert(os.getenv('AITD_DRIVER6_DIR'),'DRIVER6 / OUTPUT DIRECTORY')
local mode=os.getenv('AITD_DRIVER6_MODE') or 'natural'
assert(mode=='natural' or mode=='active' or mode=='empty','DRIVER6 / MODE')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8((a+i)&0xffffff))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open(folder..'/'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8((a+i)&0xffffff)))end;f:close()end
local entry,state,world,sp,ret;local phase='entry';local done=false
local function active(first,last)
 local n=0;for i=first,last do local age=mem:read_u16(state+0x24d2+i*4);if age>0 and age<0x8000 then n=n+1 end end;return n
end
local function capture(label)
 local tail='';for _,r in ipairs({'SR','D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRIVER6_%s sp=%X tick=%X selector=%X argument=%X music=%u effects=%u',label,cpu.state.A7.value,mem:read_u32(0x16a),mem:read_u32(sp+4),mem:read_u32(sp+8),active(0,5),active(6,7))..tail)
 save(label:lower()..'-state',state,0x3048)
end
emu.register_frame_done(function()
 if entry or mac.frontmost()~='Alone In The Dark' then return end
 local a5=ptr(0x904);if a5<0x100000 or a5>=0x800000 then return end
 local candidate=ptr(a5-0x6ac)
 if candidate<0x100000 or candidate>0x7f0000 or bytes(candidate,12)~='202F0004222F000848E73FFE' then return end
 entry=candidate;state=entry+0x4200;world=a5
 for _,alias in ipairs({0,0x80000000})do cpu.debug:bpset(entry|alias,'d@(sp+4)==0x6'..(mode~='natural' and ' || d@(sp+4)==0x4' or ''),'')end
 print(string.format('DRIVER6_OBSERVER mode=%s entry=%X a5=%X',mode,entry,world))
end)
emu.register_periodic(function()
 if done or not entry or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  local pc=cpu.state.PC.value&0xffffff
  if phase=='entry' then
   assert(pc==entry,'DRIVER6 / ENTRY PC')
   local at=cpu.state.A7.value;local selector=mem:read_u32(at+4)
   local configured=mem:read_u16(state+0x11c0)==6
   local eligible=mode=='natural' and selector==6 or selector==4 and configured and
    (mode=='active' and active(0,5)>0 and active(6,7)>0 or mode=='empty' and active(0,5)==0)
   if eligible then
    sp=at;ret=mem:read_u32(sp)&0xffffff
    print(string.format('DRIVER6_FIXTURE mode=%s originalSelector=%u sp=%X return=%X',mode,selector,sp,ret))
    if mode~='natural' then mem:write_u32(sp+4,6)end
    print('DRIVER6_ENTRY_BYTES '..bytes(entry,12));save('driver',entry,0x7248)
    save('caller',ret-12,16);capture('ENTER')
    dbg:command('bpclear');for _,alias in ipairs({0,0x80000000})do cpu.debug:bpset(ret|alias,'1','')end
    phase='return'
   end
  else
   assert(pc==ret and cpu.state.A7.value==sp+4,'DRIVER6 / RETURN STACK')
   capture('RETURN');done=true;print('PASS original driver6 '..mode..' contract');dbg:command('quit');return
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
local function key(name)mac.wait(2);mac.key_down(name);mac.wait(8);mac.key_up(name);mac.wait(10)end
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300)
  local function window320()
   local w=ptr(0x9d6)
   for _=1,32 do
    if w==0 or w>0x7fffff then return false end
    if mem:read_i16(w+22)-mem:read_i16(w+18)==320 and mem:read_i16(w+20)-mem:read_i16(w+16)==200 then return true end
    w=ptr(w+0x90)
   end
   return false
  end
  if not window320()then assert(mac.mouse_to(256,274));mac.click(1)end
  assert(mac.wait_for('320x200',window320,1800));mac.mouse_to(620,470)
  if mode=='natural' then
   mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
   key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
  end
  mac.wait(24000);error('DRIVER6 / NO CONTRACT CAPTURE')
 end)
 if not ok and not done then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
