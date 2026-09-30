-- Capture the original presentation picture draw, without modifying it.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PRESENTPICT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('PRESENTPICT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function save(name,a,n)
 local f=assert(io.open('tmp/presentpict-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local returning=false;local count=0
local thePort;local nextStop=false;local args;local ret;local picture;local rect;local port;local pm;local pixels;local size
local function arm()
 cpu.debug:bpset(0xdd60,cond..' && (w@(d@(sp+2))==0xa86e || (w@(d@(sp+2))==0xa8f6 && (d@(sp+2)&0xffffff)=='..base(5)..'+0x20f2))','')
 dbg.execution_state='run'
end
local function log(phase)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end
 print(string.format('PRESENTPICT_%s n=%d sp=%X picture=%X rect=%s port=%X pm=%X pixels=%X bytes=%X',phase,count,phase=='ENTER' and args or cpu.state.A7.value,picture,bytes(rect,8),port,pm,pixels,size)..tail)
 local name=tostring(count)..'-'..phase:lower()
 save(name..'-port',port,108);save(name..'-pm',pm,50);save(name..'-pixels',pixels,size)
 save(name..'-clut',ptr(ptr(pm+42)),2056)
 save(name..'-inverse',ptr(ptr(ptr(ptr(0x8a4))+6)),4620)
 save(name..'-picture',ptr(picture),mem:read_u16(ptr(picture)))
 for _,r in ipairs({{'vis',24},{'clip',28}}) do local body=ptr(ptr(port+r[2]));save(name..'-'..r[1],body,mem:read_u16(body)) end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'PRESENTPICT / DISPATCHER BYTES')
 armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if nextStop then
   log('NEXT');done=true;print('PASS original presentation picture calls=1');dbg:command('quit');return
  end
  if not returning then
   assert(cpu.state.PC.value==0xdd60,'PRESENTPICT / ENTRY')
   if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then thePort=ptr(cpu.state.A7.value+8);dbg:command('bpclear');arm();return end
   count=count+1
   args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;rect=ptr(args);picture=ptr(args+4)
   port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
   assert(mem:read_u16(pm+32)==8,'PRESENTPICT / LOCKED EIGHT BIT WORLD')
   size=(mem:read_u16(pm+4)&0x3fff)*((mem:read_u16(pm+10)-mem:read_u16(pm+6))&0xffff)
   if count==1 then
    print('PRESENTPICT_BYTES data='..bytes(ret-8,8));save('clut',ptr(ptr(pm+42)),2056)
    local gd=ptr(ptr(0x8a4));save('inverse',ptr(ptr(gd+6)),4620)
   end
   log('ENTER');returning=true;cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'PRESENTPICT / RETURN');log('RETURN');dbg:command('bpclear');returning=false
   nextStop=true;cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xaa95 && (d@(sp+2)&0xffffff)=='..base(5)..'+0x214c','');dbg.execution_state='run'
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'PRESENTPICT / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'PRESENTPICT / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('PRESENTPICT / NO COMPLETION')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
