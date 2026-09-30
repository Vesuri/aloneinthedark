-- Original foreground/background calls and CPU-only indexed-colour fixtures.
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
 local f=assert(io.open('tmp/window-rgb-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local armed=false;local done=false;local phase='entry';local original=0;local fixture=0
local thePort;local args;local ret;local port;local rgb;local trap;local colors={};local scratch;local stack
local function log(which)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end
 print(string.format('RGB_%s original=%d fixture=%d trap=%X sp=%X rgb=%s fore=%X back=%X port=%X fields=%s',which,original,fixture,trap,which=='ENTER' and args or cpu.state.A7.value,bytes(rgb,6),mem:read_u32(port+80),mem:read_u32(port+84),port,bytes(port+36,12))..tail)
 do
  local label=(fixture==0 and tostring(original) or 'fixture'..tostring(fixture))..'-'..which:lower()
  save(label..'-port',port,108)
  for _,pat in ipairs({{'back',32},{'pen',58},{'fill',62}}) do save(label..'-'..pat[1],ptr(ptr(port+pat[2])),28) end
 end
end
local function original_break()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 cpu.debug:bpset(0xdd60,cond..' && ((w@(d@(sp+2))==0xaa14 && (d@(sp+2)&0xffffff)=='..base(12)..'+0x624a) || (w@(d@(sp+2))==0xaa15 && (d@(sp+2)&0xffffff)=='..base(12)..'+0x6252))','')
 phase='entry';dbg.execution_state='run'
end
local function next_fixture()
 fixture=fixture+1
 if fixture>#colors*2 then done=true;print('PASS original RGB colours and '..tostring(#colors*2)..' fixtures');dbg:command('quit');return end
 trap=fixture%2==1 and 0xaa14 or 0xaa15
 local color=colors[(fixture+1)//2]
 rgb=scratch+32;for i=1,3 do mem:write_u16(rgb+(i-1)*2,color[i]) end
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,trap);mem:write_u16(scratch+4,0x4e71)
 mem:write_u32(stack,rgb);cpu.state.A7.value=stack;cpu.state.D0.value=0x12345678;cpu.state.PC.value=scratch
 ret=scratch+4;phase='fixture-entry';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'RGB / DISPATCHER BYTES')
 original_break();armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' or phase=='fixture-entry' then
   if phase=='entry' then
    assert(cpu.state.PC.value==0xdd60,'RGB / ENTRY')
    if mem:read_u16(ptr(cpu.state.A7.value+2))==0xa86e then
     thePort=ptr(cpu.state.A7.value+8);print(string.format('RGB_INIT thePort=%X',thePort));dbg:command('bpclear');original_break();return
    end
    original=original+1
    args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2;trap=mem:read_u16(ret-2);rgb=ptr(args)
    port=ptr(assert(thePort))
    print(string.format('RGB_BYTES original=%d data=%s',original,bytes(ret-8,8)))
    if original==1 then
     local pm=ptr(ptr(port+2));local table=ptr(ptr(pm+42))
     local gd=ptr(ptr(0xcc8));local inverse=ptr(ptr(gd+6));print(string.format('RGB_DEVICE handle=%X body=%X inverse=%X resolution=%u seed=%X tableSeed=%X',ptr(0xcc8),gd,inverse,mem:read_u16(inverse+4),mem:read_u32(inverse),mem:read_u32(table)))
     save('clut',table,2056);save('inverse-before',inverse,524+(1<<(3*mem:read_u16(inverse+4))))
     for _,i in ipairs({0,1,2,15,16,32,64,127,128,191,192,254,255}) do
      colors[#colors+1]={mem:read_u16(table+10+i*8),mem:read_u16(table+12+i*8),mem:read_u16(table+14+i*8)}
     end
     for _,v in ipairs({1,0x0800,0x1234,0x3333,0x7fff,0x8000,0xabcd,0xfffe}) do
      colors[#colors+1]={v,v,v};colors[#colors+1]={v,(v*3)&0xffff,(v*7)&0xffff}
     end
     colors[#colors+1]={65535,0,0};colors[#colors+1]={0,65535,0};colors[#colors+1]={0,0,65535}
    end
   else args=stack end
   log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'RGB / RETURN');log('RETURN');
   if original==1 and fixture==0 then local gd=ptr(ptr(0xcc8));local inverse=ptr(ptr(gd+6));save('inverse',inverse,524+(1<<(3*mem:read_u16(inverse+4)))) end
   dbg:command('bpclear')
   if original<2 then original_break() else
    if fixture==0 then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end
    next_fixture()
   end
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'RGB / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'RGB / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('RGB / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
