-- Original Dan2+$07FA post-intro copy between owned offscreen worlds.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'POSTCOPY / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('POSTCOPY / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(out)end
local function save(name,a,n)
 assert(n>=0 and n<=1048576,'POSTCOPY / CAPTURE SIZE')
 local f=assert(io.open('tmp/postcopy-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function map(bitmap)if mem:read_u16(bitmap+4)&0xc000==0xc000 then return ptr(ptr(bitmap))else return bitmap end end
local armed=false;local done=false;local returning=false;local thePort;local args;local ret;local src;local dst;local port
local function arm()
 cpu.debug:bpset(0xdd60,cond..' && (w@(d@(sp+2))==0xa86e || (w@(d@(sp+2))==0xa8ec && (d@(sp+2)&0xffffff)=='..base(13)..'+0x7fa))','');dbg.execution_state='run'
end
local function capture(phase)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('POSTCOPY_%s sp=%X args=%s source=%s target=%s port=%X',phase,phase=='ENTER' and args or cpu.state.A7.value,bytes(args,22),bytes(ptr(args+10),8),bytes(ptr(args+6),8),port)..tail)
 for _,v in ipairs({{'src',src},{'dst',dst}})do
  local pm=v[2];local row=mem:read_u16(pm+4)&0x3fff;local height=(mem:read_u16(pm+10)-mem:read_u16(pm+6))&0xffff
  save(phase:lower()..'-'..v[1]..'-pm',pm,50);save(phase:lower()..'-'..v[1]..'-pixels',mem:read_u32(pm),row*height)
  local ct=ptr(ptr(pm+42));save(phase:lower()..'-'..v[1]..'-clut',ct,8+8*(mem:read_u16(ct+6)+1))
 end
 save(phase:lower()..'-port',port,108)
 for _,v in ipairs({{'vis',24},{'clip',28}})do local r=ptr(ptr(port+v[2]));save(phase:lower()..'-'..v[1],r,mem:read_u16(r))end
 local gd=ptr(ptr(0x8a4));save(phase:lower()..'-inverse',ptr(ptr(gd+6)),4620)
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'POSTCOPY / DISPATCHER');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if not returning then
   if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then thePort=ptr(cpu.state.A7.value+8);dbg:command('bpclear');arm();return end
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;port=ptr(assert(thePort));src=map(ptr(args+18));dst=map(ptr(args+14))
   assert(bytes(ret-20,20)=='486800022F0C2F2E0008486EFFF8426742A7A8EC','POSTCOPY / ORIGINAL CALLER BYTES');print('POSTCOPY_BYTES '..bytes(ret-20,20));capture('ENTER');returning=true;dbg:command('bpclear');cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'POSTCOPY / RETURN');capture('RETURN');done=true;print('PASS original post-intro CopyBits');dbg:command('quit')
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(36000);error('POSTCOPY / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
