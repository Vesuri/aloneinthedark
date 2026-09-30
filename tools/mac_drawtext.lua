-- Original intro text plus isolated repeat, MoveTo and empty-text fixtures.
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
 local f=assert(io.open('tmp/drawtext-reference-'..(fixture==0 and '' or 'fixture'..fixture..'-')..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local phase='entry';local thePort;local args;local ret;local port;local pm;local pixels;local size
local function arm()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa885 && (d@(sp+2)&0xffffff)=='..base(12)..'+0x346','');dbg.execution_state='run'
end
local function log(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('TEXT_%s fixture=%u sp=%X port=%X pm=%X pixels=%X bytes=%X pen=%s font=%u size=%u face=%u mode=%u fore=%X back=%X',label,fixture,label=='ENTER' and args or cpu.state.A7.value,port,pm,pixels,size,bytes(port+48,4),mem:read_u16(port+68),mem:read_u16(port+74),mem:read_u8(port+70),mem:read_u16(port+72),mem:read_u32(port+80),mem:read_u32(port+84))..tail)
 save(label:lower()..'-port',port,108);save(label:lower()..'-pm',pm,50);save(label:lower()..'-pixels',pixels,size);save(label:lower()..'-clut',ptr(ptr(pm+42)),2056)
 for _,r in ipairs({{'vis',24},{'clip',28}})do local body=ptr(ptr(port+r[2]));save(label:lower()..'-'..r[1],body,mem:read_u16(body))end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DRAWTEXT / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
 if phase=='fixture' then
  log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 elseif phase=='entry' then
  if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
   thePort=ptr(cpu.state.A7.value+8);print(string.format('TEXT_INIT thePort=%X',thePort));dbg:command('bpclear');arm();return
  end
  args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;local count=mem:read_u16(args);local first=mem:read_u16(args+2);local text=ptr(args+4);assert(count<4096 and first<32768,'DRAWTEXT / RANGE');print(string.format('TEXT_ARGUMENTS count=%u first=%u text=%X hex=%s',count,first,text,bytes(text+first,count)));save('arguments',args,8);save('string',text+first,count);sampleText=text+first;sampleCount=count;port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
  print(string.format('TEXT_LAYOUT port=%X pm=%X raw=%s',port,pm,bytes(pm,50)))
  local function signed(v)return v>=32768 and v-65536 or v end
  size=(mem:read_u16(pm+4)&0x3fff)*(signed(mem:read_u16(pm+10))-signed(mem:read_u16(pm+6)))
  assert(mem:read_u16(pm+32)==8 and size>0 and size<=1048576,'DRAWTEXT / PIXMAP')
  startPoint=mem:read_u32(port+48);print('TEXT_BYTES '..bytes(ret-6,6));log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 else
  assert(cpu.state.PC.value==ret);log('RETURN');dbg:command('bpclear')
  if fixture==3 then done=true;print('PASS original intro DrawText fixtures=3');dbg:command('quit');return end
  fixture=fixture+1
  if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192;cpu.state.SR.value=cpu.state.SR.value|0x700 end
  mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,fixture==2 and 0xa893 or 0xa885);mem:write_u16(scratch+4,0x4e71)
  if fixture==2 then mem:write_u32(stack,startPoint)
  else mem:write_u16(stack,fixture==3 and 0 or sampleCount);mem:write_u16(stack+2,0);mem:write_u32(stack+4,sampleText)end
  print(string.format('TEXT_FIXTURE n=%u op=%s',fixture,fixture==2 and 'MOVETO' or 'DRAWTEXT'))
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
