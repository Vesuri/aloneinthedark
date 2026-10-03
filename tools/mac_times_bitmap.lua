-- Capture Times/plain/14 bitmap artwork through isolated original DrawText calls.
-- The game instructions remain unchanged; fixture calls use scratch memory.
local dot,accent=false,false
local prefix='drawtext'
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRAWTEXT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('DRAWTEXT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local fixture=0;local scratch;local stack;local sampleText;local sampleCount;local startPoint
local function save(name,a,n)
 local f=assert(io.open('tmp/'..prefix..'-reference-'..(fixture==0 and '' or 'fixture'..fixture..'-')..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local phase='entry';local thePort;local args;local ret;local port;local pm;local pixels;local size
local metricOut;local metricRet
local function arm()
 if dot then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa88b && (d@(sp+2)&0xffffff)=='..base(12)..'+0x13c','')end
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa885 && (d@(sp+2)&0xffffff)=='..base(12)..'+0x346'..(accent and ' && w@(sp+0x8)==0x4 && w@(sp+0xa)==0x0 && d@(d@(sp+0xc))==0x5961896c' or '')..(dot and ' && w@(sp+0x8)==0x8 && w@(sp+0xa)==0x0 && w@(d@(sp+0xc))==0x49fa' or ''),'');dbg.execution_state='run'
end
local function log(label)
 if label~='RETURN' or fixture==0 then return end
 local f=assert(io.open('tmp/m3-menu/glyph-'..string.rep('0',3-#tostring(fixture+31))..tostring(fixture+31)..'.bin','wb'))
 for y=176,207 do for x=29,60 do f:write(string.char(mem:read_u8(pixels+y*652+x))) end end
 f:close()
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DRAWTEXT / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='metric-return' then
  assert(cpu.state.PC.value==metricRet);print('DOT_METRIC_RETURN data='..bytes(metricOut,12));dbg:command('bpclear');phase='entry';arm()
 elseif phase=='fixture' then
  log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 elseif phase=='entry' then
  if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
   thePort=ptr(cpu.state.A7.value+8);print(string.format('TEXT_INIT thePort=%X',thePort));dbg:command('bpclear');arm();return
  end
  if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa88b then
   metricOut=ptr(cpu.state.A7.value+8);metricRet=ptr(cpu.state.A7.value+2)+2;local p=ptr(thePort)
   print('DOT_METRIC_ENTER state='..bytes(p+68,12)..' data='..bytes(metricOut,12)..' bytes='..bytes(metricRet-6,6));phase='metric-return';cpu.debug:bpset(metricRet,'1','');dbg.execution_state='run';return
  end
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;local count=mem:read_u16(args);local first=mem:read_u16(args+2);local text=ptr(args+4);assert(count<4096 and first<32768,'DRAWTEXT / RANGE');print(string.format('TEXT_ARGUMENTS count=%u first=%u text=%X hex=%s',count,first,text,bytes(text+first,count)));save('arguments',args,8);save('string',text+first,count);sampleText=text+first;sampleCount=count;port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
  print(string.format('TEXT_LAYOUT port=%X pm=%X raw=%s',port,pm,bytes(pm,50)))
  local function signed(v)return v>=32768 and v-65536 or v end
  size=(mem:read_u16(pm+4)&0x3fff)*(signed(mem:read_u16(pm+10))-signed(mem:read_u16(pm+6)))
  assert(mem:read_u16(pm+32)==8 and size>0 and size<=1048576,'DRAWTEXT / PIXMAP')
  startPoint=mem:read_u32(port+48);print('TEXT_BYTES '..bytes(ret-6,6));log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');dbg:command('bpclear')
  if fixture==224 then done=true;print('PASS original Times14 glyphs=224');dbg:command('quit');return end
  fixture=fixture+1
  if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192;cpu.state.SR.value=cpu.state.SR.value|0x700 end
  -- Isolated service fixture: draw one character on the original owned world.
  for i=0,size-1 do mem:write_u8(pixels+i,0)end
  mem:write_u16(port+48,196);mem:write_u16(port+50,37);mem:write_u16(port+14,0x8000)
  mem:write_u8(scratch+32,fixture+31)
  mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa885);mem:write_u16(scratch+4,0x4e71)
  mem:write_u16(stack,1);mem:write_u16(stack+2,0);mem:write_u32(stack+4,scratch+32)
  cpu.state.A7.value=stack;cpu.state.PC.value=scratch;args=stack;ret=scratch+4;phase='fixture';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'

 end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('DRAWTEXT / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
