-- Original polygon disposal after normal Enter and pond region expansion.
local mac=dofile('tools/mame_mac_input.lua');local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program;local dbg=manager.machine.debugger
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open('tmp/killpoly-reference-'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function base(seg)for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end;error('segment')end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app);for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed,done,skip=false,false,false;local thePort,port,poly,sp,ret,trap;local phase='entry';local n=0;local scratch;local region
local function arm()
 if not thePort then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa86e','')end
 if not skip then cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa891','')end
 cpu.debug:bpset(0xdd60,cond..' && (d@(sp+2)&ffffff)=='..base(4)..'+0x3396','')
end
local function log(label)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 local disposed=trap==0xa8cd and label=='RETURN'
 local size=poly and not disposed and mem:read_u16(ptr(poly)) or 0
 assert(size<4096,'polygon extent')
 print(string.format('KILL_%s n=%d trap=%X sp=%X args=%s port=%X poly=%X body=%X size=%X memerr=%X',label,n,trap,label=='ENTER' and sp or cpu.state.A7.value,bytes(sp,4),port,poly or 0,poly and ptr(poly) or 0,size,mem:read_u16(0x220))..tail)
 save(n..'-'..label..'-port',port,108)
 if trap==0xa8cd then
  local pm=ptr(ptr(port+2));local pixels=mem:read_u32(pm);local size=(mem:read_u16(pm+4)&0x3fff)*(mem:read_i16(pm+10)-mem:read_i16(pm+6))
  assert(mem:read_u16(pm+32)==8 and size>0 and size<=1048576,'recording PixMap')
  save(label..'-pixels',pixels,size);save(label..'-pm',pm,50)
 end
 if poly and not disposed then save(n..'-'..label..'-poly',ptr(poly),size)end
 if trap==0xa8cd then print(string.format('KILL_HEAP phase=%s zone=%X free=%X master=%X',label,ptr(0x118),mem:read_u32(ptr(0x118)+12),mem:read_u32(poly)));save(n..'-'..label..'-zone',ptr(0x118),64)end
 if region then
  local body=ptr(region);local count=mem:read_u16(body)
  assert(count>=10 and count<=32766,'region extent')
  print(string.format('KILL_REGION n=%u phase=%s handle=%X body=%X size=%X recording=%X',n,label,region,body,count,mem:read_u32(port+96)))
  save(n..'-'..label..'-region',body,count)
 end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'dispatcher bytes');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='size' then
   print(string.format('KILL_SIZE size=%X memerr=%X',cpu.state.D0.value,mem:read_u16(0x220)));dbg:command('bpclear');cpu.debug:bpset(scratch+4,'1','');phase='flags';dbg.execution_state='run'
  elseif phase=='flags' then
   print(string.format('KILL_FLAGS flags=%X memerr=%X',cpu.state.D0.value&0xff,mem:read_u16(0x220)));dbg:command('bpclear');cpu.debug:bpset(scratch+6,'1','');phase='owner';dbg.execution_state='run'
  elseif phase=='owner' then
   print(string.format('KILL_OWNER owner=%X zone=%X memerr=%X',cpu.state.A0.value,ptr(0x118),mem:read_u16(0x220)));done=true;print('COMPLETE original pond polygon disposal');dbg:command('quit')
  elseif phase=='entry' then
   local call=ptr(cpu.state.A7.value+2);trap=mem:read_u16(call);sp=cpu.state.A7.value+8
   if trap==0xa86e then thePort=ptr(sp);dbg:command('bpclear');arm();dbg.execution_state='run';return end
   if trap==0xa891 and not skip then skip=true;print('KILL_SKIP first LineTo; normal Return next frame');dbg:command('bpclear');arm();dbg.execution_state='run';return end
   port=ptr(assert(thePort));n=n+1;ret=call+2
   print(string.format('KILL_BYTES n=%d data=%s',n,bytes(call-2,4)))
   if trap==0xa8cd then assert(bytes(call-2,4)=='2F0CA8CD','KillPoly caller bytes');print('KILL_ARGUMENTS '..bytes(sp,4))end
   log('ENTER');dbg:command('bpclear');cpu.debug:bpset(ret,'1','');phase='return';dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'return PC')
   if trap==0xa8cb then poly=ptr(sp);assert(poly~=0,'OpenPoly failed')end
   if trap==0xa8d8 then region=ptr(sp);assert(region~=0,'NewRgn failed')end
   log('RETURN');dbg:command('bpclear')
   if trap==0xa8cd then
    scratch=(cpu.state.A7.value-16384)&0xfffffc
    mem:write_u16(scratch,0xa025);mem:write_u16(scratch+2,0xa069);mem:write_u16(scratch+4,0xa126);mem:write_u16(scratch+6,0x4e71)
    cpu.state.A0.value=region;cpu.state.A7.value=scratch+8192;cpu.state.PC.value=scratch
    cpu.debug:bpset(scratch+2,'1','');phase='size';dbg.execution_state='run';return
   end
   cpu.debug:bpset(0xdd60,cond..' && ((d@(sp+2)&ffffff)=='..base(4)..'+0x33b8 || (d@(sp+2)&ffffff)=='..base(4)..'+0x33ce || (d@(sp+2)&ffffff)=='..base(4)..'+0x33dc || (d@(sp+2)&ffffff)=='..base(4)..'+0x33e0 || (d@(sp+2)&ffffff)=='..base(4)..'+0x33e8 || (d@(sp+2)&ffffff)=='..base(4)..'+0x33ec || (d@(sp+2)&ffffff)=='..base(4)..'+0x33f0 || (d@(sp+2)&ffffff)=='..base(4)..'+0x33f8 || (d@(sp+2)&ffffff)=='..base(4)..'+0x3410)','');phase='entry';dbg.execution_state='run'
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return');print('KILL_SKIP Return released')
  mac.wait(42000);error('polygon completion absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
