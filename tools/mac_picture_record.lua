-- Capture the original save-slot thumbnail CopyBits through normal keyboard input.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'COPY8 / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('COPY8 / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(out)end
local function save(name,a,n)
 assert(n>=0 and n<=1048576,'COPY8 / CAPTURE SIZE')
 local f=assert(io.open('tmp/pictrecord-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function map(bitmap)if mem:read_u16(bitmap+4)&0xc000==0xc000 then return ptr(ptr(bitmap))else return bitmap end end
local armed=false;local done=false;local returning=false;local thePort;local args;local ret;local src;local dst;local port
local picture;local operation;local recording=false
local function arm()
 local condition=cond..' && (w@(d@(sp+2))==0xa86e || w@(d@(sp+2))==0xa8f3 || w@(d@(sp+2))==0xa8f4'
 if recording then condition=condition..' || w@(d@(sp+2))==0xa8ec' end
 cpu.debug:bpset(0xdd60,condition..')','');dbg.execution_state='run'
end
local function capture(phase)
 print(string.format('RECORD_%s trap=%X sp=%X pc=%X port=%X',phase,operation,cpu.state.A7.value,cpu.state.PC.value,port))
 save('record-'..phase:lower()..'-port',port,108)
 if operation==0xa8f3 and phase=='ENTER' then save('frame',ptr(args),8) end
 if operation==0xa8ec then
  save(phase:lower()..'-from',ptr(args+10),8);save(phase:lower()..'-to',ptr(args+6),8)
  for _,v in ipairs({{'src',src},{'dst',dst}})do
   local pm=v[2];local row=mem:read_u16(pm+4)&0x3fff;local height=(mem:read_u16(pm+10)-mem:read_u16(pm+6))&0xffff
   save(phase:lower()..'-'..v[1]..'-pm',pm,50);save(phase:lower()..'-'..v[1]..'-pixels',mem:read_u32(pm),row*height)
   local ct=ptr(ptr(pm+42));save(phase:lower()..'-'..v[1]..'-clut',ct,8+8*(mem:read_u16(ct+6)+1))
  end
  save(phase:lower()..'-port',port,108)
  for _,v in ipairs({{'vis',24},{'clip',28}})do local r=ptr(ptr(port+v[2]));save(phase:lower()..'-'..v[1],r,mem:read_u16(r))end
 end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'RECORD / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not returning then
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;operation=mem:read_u16(ret-2)
   if operation==0xa86e then thePort=ptr(args);dbg:command('bpclear');arm();return end
   port=ptr(assert(thePort))
   if operation==0xa8ec then src=map(ptr(args+18));dst=map(ptr(args+14)) end
   capture('ENTER');returning=true;dbg:command('bpclear');cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret);capture('RETURN');dbg:command('bpclear');returning=false
   if operation==0xa8f3 then picture=ptr(cpu.state.A7.value);recording=true;print(string.format('RECORD_HANDLE handle=%X body=%X',picture,ptr(picture))) end
   if operation==0xa8f4 then
    local body=ptr(picture);local size=mem:read_u16(body);assert(size>10 and size<65535)
    save('picture',body,size);print('PASS original recorded save thumbnail bytes='..size);done=true;dbg:command('quit')
   else arm() end
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
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
  local function key(name)
   mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10)
  end
  mac.wait(3000);key('Space');mac.wait(120);key('Return');mac.wait(720)
  key('Right Arrow');key('Return');mac.wait(240);key('Return');mac.wait(180);key('Esc')
  assert(mac.wait_for('attic',function()
   for _,screen in pairs(manager.machine.screens)do
    local raw,w,h=screen:pixels()
    return w==640 and h==480 and (string.unpack('I4',raw,4*(160*w+180)+1)&0xffffff)==0x814530
   end
  end,1800))
  mac.key_down(mac.CMD);key('s');mac.key_up(mac.CMD)
  assert(mac.wait_for('save slots',function()
   for _,screen in pairs(manager.machine.screens)do
    local raw,w,h=screen:pixels()
    return w==640 and h==480 and (string.unpack('I4',raw,4*(210*w+400)+1)&0xffffff)==0x81a1a1
   end
  end,1800))
  mac.wait(180);mac.type('m3test');mac.wait(30);key('Return')
  mac.wait(1800);error('COPY8 / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
