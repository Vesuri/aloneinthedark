-- Capture the original window rectangle fill, without modifying game code.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PAINTRECT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('PAINTRECT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local fixture=0;local scratch;local stack
local function save(name,a,n)
 local f=assert(io.open('tmp/paintrect-reference-'..(fixture==0 and '' or 'fixture'..fixture..'-')..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local phase='entry';local thePort;local args;local ret;local rect;local port;local pm;local pixels;local size
local function arm()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8a2 && (d@(sp+2)&0xffffff)=='..base(13)..'+0xd52','');dbg.execution_state='run'
end
local function log(label)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('PR_%s fixture=%d sp=%X rect=%s port=%X pm=%X pixels=%X bytes=%X pen=%s fore=%X back=%X',label,fixture,label=='ENTER' and args or cpu.state.A7.value,bytes(rect,8),port,pm,pixels,size,bytes(port+48,10),mem:read_u32(port+80),mem:read_u32(port+84))..tail)
 save(label:lower()..'-clut',ptr(ptr(pm+42)),2056);save(label:lower()..'-port',port,108);save(label:lower()..'-pm',pm,50);save(label:lower()..'-pixels',pixels,size);save(label:lower()..'-rect',rect-4,16)
 for _,r in ipairs({{'vis',24},{'clip',28}}) do local body=ptr(ptr(port+r[2]));save(label:lower()..'-'..r[1],body,mem:read_u16(body))end
 local pattern=ptr(ptr(port+58));save(label:lower()..'-pen',pattern,28)
 save(label:lower()..'-pen-map',ptr(ptr(pattern+2)),50);save(label:lower()..'-pen-data',ptr(ptr(pattern+6)),8)
end
local function next_fixture()
 fixture=fixture+1
 if fixture>2 then done=true;print('PASS original window PaintRect fixtures=2');dbg:command('quit');return end
 if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end
 -- Contrast the existing black client pixels; only this isolated CPU fixture writes VRAM.
 for y=150,349 do for x=160,479 do mem:write_u8(pixels+y*640+x,0)end end
 rect=scratch+32
 local r=fixture==1 and {5,7,11,19} or {-5,-7,210,330}
 for i=1,4 do mem:write_u16(rect+2*(i-1),r[i]&0xffff)end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa8a2);mem:write_u16(scratch+4,0x4e71)
 mem:write_u32(stack,rect);cpu.state.A7.value=stack;cpu.state.PC.value=scratch
 args=stack;ret=scratch+4;phase='fixture';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'PAINTRECT / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='fixture' then
  log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 elseif phase=='entry' then
  if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
   thePort=ptr(cpu.state.A7.value+8);print(string.format('PR_INIT thePort=%X',thePort));dbg:command('bpclear');arm();return
  end
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;rect=ptr(args);port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
  print(string.format('PR_LAYOUT port=%X pm=%X raw=%s',port,pm,bytes(pm,50)))
  local function signed(v)return v>=32768 and v-65536 or v end
  size=(mem:read_u16(pm+4)&0x3fff)*(signed(mem:read_u16(pm+10))-signed(mem:read_u16(pm+6)))
  assert(mem:read_u16(pm+32)==8 and size==307200,'PAINTRECT / PIXMAP')
  print('PR_BYTES '..bytes(ret-6,6));log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');dbg:command('bpclear');next_fixture()
 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('PAINTRECT / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
