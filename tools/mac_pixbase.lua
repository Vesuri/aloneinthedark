-- Original GetPixBaseAddr, row-copy use and CPU-executed unlocked fixture.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'PIXBASE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('PIXBASE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local armed=false;local stage=0;local handle,pm,pixels,bytes,returnpc,scratch,segment
local function ptr(a) return mem:read_u32(a)&0xffffff end
local function dump(label,a,n)
 local f=assert(io.open('tmp/pixbase-reference-'..label..'.bin','wb'))
 local bytes={};for i=0,n-1 do bytes[#bytes+1]=string.char(mem:read_u8(a+i)) end
 f:write(table.concat(bytes));f:close()
end
local function capture(label,sp)
 local registers=''
 for _,r in ipairs({'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}) do registers=registers..string.format(' %s=%08X',r,cpu.state[r].value) end
 print(string.format('PBASE phase=%s sp=%X pc=%X handle=%X pm=%X pixels=%X bytes=%X result=%X',label,sp,cpu.state.PC.value,handle,pm,pixels,bytes,mem:read_u32(sp))..registers)
 dump(label..'-pm',pm,50);dump(label..'-pixels',pixels,bytes);dump(label..'-stack',sp,16)
end
emu.register_frame_done(function()
 if armed or stage<0 or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'PIXBASE / DISPATCHER BYTES')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xab1d && (d@(sp+2)&0xffffff)=='..base(10)..'+0x2da','')
 armed=true
end)
emu.register_periodic(function()
 if not armed or stage<0 or dbg.execution_state~='stop' then return end
 local sp=cpu.state.SP.value&0xffffff
 if stage==0 then
  local pc=ptr(sp+2);sp=sp+8;handle=ptr(sp);pm=ptr(handle);pixels=ptr(pm)
  assert(mem:read_u16(pm+14)==1,'PIXBASE / ORIGINAL PIXELS NOT LOCKED')
  bytes=(mem:read_u16(pm+4)&0x3fff)*(mem:read_u16(pm+10)-mem:read_u16(pm+6))
  segment=pc-0x2da;returnpc=pc+2;dump('original-code',pc-0x2da+0x2ac,0x30);capture('locked-before',sp)
  dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',returnpc));stage=1
 elseif stage==1 then
  capture('locked-after',sp)
  dbg:command('bpclear');dbg:command(string.format('bpset 0xdd60,(d@(sp+2)&0xffffff)==0x%x',segment+0x686));stage=2
 elseif stage==2 then
  assert(cpu.state.D0.value==512 and (cpu.state.A1.value&0xffffff)==pixels,'PIXBASE / FIRST ROW DESTINATION')
  dump('copy-source',cpu.state.A0.value&0xffffff,512*56);dump('copy-before',pixels,bytes)
  dump('copy-code',segment+0x668,0x22)
  dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',segment+0x342));stage=3
 elseif stage==3 then
  dump('copy-after',pixels,bytes);dump('copy-after-pm',pm,50)
  assert(mem:read_u16(pm+14)==2,'PIXBASE / ORIGINAL COPY UNLOCK')
  print('PASS original pixel-address row copy')
  scratch=sp-0x400
  local code={0x598f,0x2f3c,(handle>>16)&0xffff,handle&0xffff,0x203c,0x0004,0x000f,0xab1d,0x4e71}
  for i,v in ipairs(code) do mem:write_u16(scratch+(i-1)*2,v) end
  dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',scratch+14))
  dbg:command(string.format('sp=0x%x;pc=0x%x',scratch-0x100,scratch));stage=4
 elseif stage==4 then
  capture('unlocked-before',sp);dbg:command('bpclear');dbg:command(string.format('bpset 0x%x',scratch+16));stage=5
 else
  capture('unlocked-after',sp);stage=-1;print('PASS original GetPixBaseAddr locked and unlocked');dbg:command('quit');return
 end
 dbg.execution_state='run'
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'PIXBASE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'PIXBASE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('PIXBASE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
