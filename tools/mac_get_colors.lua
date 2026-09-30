-- Original RGB getters and component fixtures, using InitGraf's actual global.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'RGB / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('RGB / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function save(name,a,n)
 local f=assert(io.open('tmp/getcolor-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local phase='entry';local n=0;local fixture=0
local thePort;local args;local ret;local port;local rgb;local trap;local scratch;local stack
local function log(which)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end
 print(string.format('GC_%s n=%d fixture=%d trap=%X sp=%X rgb=%X value=%s guard=%s port=%X fields=%s version=%X',which,n,fixture,trap,which=='ENTER' and args or cpu.state.A7.value,rgb,bytes(rgb,6),bytes(rgb-4,14),port,bytes(port+36,12),mem:read_u16(port+6))..tail)
 save(tostring(n)..'-'..tostring(fixture)..'-'..which:lower()..'-port',port,108)
end
local function arm()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','') end
 cpu.debug:bpset(0xdd60,cond..' && ((w@(d@(sp+2))==0xaa19 && (d@(sp+2)&0xffffff)=='..base(12)..'+0x623c) || (w@(d@(sp+2))==0xaa1a && (d@(sp+2)&0xffffff)=='..base(12)..'+0x6242))','')
 phase='entry';dbg.execution_state='run'
end
local function next_fixture()
 fixture=fixture+1
 if fixture>4 then done=true;print('PASS original colour getters calls=2 fixtures=4');dbg:command('quit');return end
 trap=fixture%2==1 and 0xaa19 or 0xaa1a
 local fields=fixture<=2 and {0x1234,0x5678,0x9abc,0xdef0,0x1357,0x2468} or {0xffff,0,0x8000,0,0xffff,0x8001}
 for i=1,6 do mem:write_u16(port+34+i*2,fields[i]) end
 rgb=scratch+32;for i=-4,9 do mem:write_u8(rgb+i,0xa5)end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,trap);mem:write_u16(scratch+4,0x4e71)
 mem:write_u32(stack,rgb);cpu.state.A7.value=stack;cpu.state.D0.value=0x12345678;cpu.state.D1.value=0x89abcdef;cpu.state.PC.value=scratch
 ret=scratch+4;phase='fixture';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'GETCOLOR / DISPATCHER BYTES');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' or phase=='fixture' then
   if phase=='entry' then
    if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
     thePort=ptr(cpu.state.A7.value+8);print(string.format('GC_INIT thePort=%X a5=%X',thePort,cpu.state.A5.value));dbg:command('bpclear');arm();return
    end
    n=n+1;args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;trap=mem:read_u16(ret-2);rgb=ptr(args)
    port=ptr(assert(thePort))
    print(string.format('GC_BYTES n=%d data=%s',n,bytes(ret-6,6)))
   else args=stack end
   log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'GETCOLOR / RETURN');log('RETURN');dbg:command('bpclear')
   if n<2 then arm() else
    if not scratch then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end
    next_fixture()
   end
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1);mac.wait(3600);error('GETCOLOR / NO COMPLETION')end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
