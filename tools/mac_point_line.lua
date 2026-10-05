-- Original Dan2 particle point; AITD_POINT_PAIRED=1 replays native pixel inputs.
local paired=os.getenv('AITD_POINT_PAIRED')=='1'
local prefix=paired and 'm3-death/point-paired' or 'm3-death/point-reference'
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'LINETO / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('LINETO / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local fixture=0
local function save(name,a,n)
 local f=assert(io.open('tmp/'..prefix..'-reference-'..(fixture==0 and '' or 'fixture'..fixture..'-')..name..'.bin','wb'));if fixture>0 and name:find('pixels',1,true) then for y=0,63 do for x=0,63 do f:write(string.char(mem:read_u8(a+y*652+x)))end end else for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end end;f:close()
end
local armed=false;local done=false;local phase='entry';local thePort;local args;local ret;local rect;local port;local pm;local pixels;local size
local active=false
local function arm()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 if active then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa892 && (d@(sp+2)&ffffff)=='..base(13)..'+3fec','')end
 dbg.execution_state='run'
end
local function log(label)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('LINE_%s fixture=%d sp=%X target=%s port=%X pm=%X pixels=%X bytes=%X pen=%s fore=%X back=%X',label,fixture,label=='ENTER' and args or cpu.state.A7.value,bytes(args,4),port,pm,pixels,size,bytes(port+48,10),mem:read_u32(port+80),mem:read_u32(port+84))..tail)
 save(label:lower()..'-clut',ptr(ptr(pm+42)),2056);save(label:lower()..'-port',port,108);save(label:lower()..'-pm',pm,50);save(label:lower()..'-pixels',pixels,size);save(label:lower()..'-args',args-4,12)
 for _,r in ipairs({{'vis',24},{'clip',28}}) do local body=ptr(ptr(port+r[2]));save(label:lower()..'-'..r[1],body,mem:read_u16(body))end
 local pattern=ptr(ptr(port+58));save(label:lower()..'-pen',pattern,28)
 save(label:lower()..'-pen-map',ptr(ptr(pattern+2)),50);save(label:lower()..'-pen-data',ptr(ptr(pattern+6)),8)
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'LINETO / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='entry' then
  if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
   thePort=ptr(cpu.state.A7.value+8);print(string.format('LINE_INIT thePort=%X',thePort));dbg:command('bpclear');arm();return
  end
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;rect=ptr(args);port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
  print(string.format('LINE_LAYOUT port=%X pm=%X raw=%s',port,pm,bytes(pm,50)))
  local function signed(v)return v>=32768 and v-65536 or v end
  size=(mem:read_u16(pm+4)&0x3fff)*(signed(mem:read_u16(pm+10))-signed(mem:read_u16(pm+6)))
  assert(mem:read_u16(pm+32)==8 and size>0 and size<=1048576,'LINETO / PIXMAP')
  assert(mem:read_u16(port+52)==2 and mem:read_u16(port+54)==2 and bytes(args,4)=='00000000','POINT / natural caller variant')
  if paired then
  local f=assert(io.open('tmp/m3-death/point-native-enter-pixels.bin','rb'));local native=f:read('*a');f:close()
  assert(#native==size and size==261452,'POINT / matching buffer extent')
  for i=1,#native do mem:write_u8(pixels+i-1,native:byte(i))end
  local p=assert(io.open('tmp/m3-death/point-native-enter-port.bin','rb'));local portdata=p:read('*a');p:close()
  assert(#portdata==108,'POINT / native port extent')
  for i=48,57 do mem:write_u8(port+i,portdata:byte(i+1))end
  assert(bytes(port+80,4)==portdata:sub(81,84):gsub('.',function(c)return string.format('%02X',c:byte())end),'POINT / same indexed foreground')
  print('POINT_NATIVE_INPUT bytes='..#native..' pen='..bytes(port+48,10)..' fore='..bytes(port+80,4))
  end
  assert(bytes(ret-10,10)=='3F2EFFECA89342A7A892','POINT / caller bytes');print('LINE_BYTES '..bytes(ret-10,10));log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');done=true;print('PASS original point line');dbg:command('quit')
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
local function key(name) mac.wait(2);mac.key_down(name);mac.wait(4);mac.key_up(name);mac.wait(10) end
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
  active=true;dbg:command('bpclear');arm();mac.wait(36000)
  error('COMBAT LINE / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
