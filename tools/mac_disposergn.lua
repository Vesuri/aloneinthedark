-- Original DisposeRgn after the pond masked copy; normal Return skips the book.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DISPOSERGN / DEBUGGER REQUIRED')
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)
 assert(n>=0 and n<=1048576,'capture extent')
 local f=assert(io.open('tmp/disposergn-reference-'..name..'.bin','wb'))
 for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()
end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2])end end
 error('segment absent')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local armed,done,skip,masked=false,false,false,false
local thePort,port,args,ret,region,body,size,zone,pm,pixels,pixelBytes
local function arm()
 local target=masked and '+0x3058' or '+0x346c'
 local tests={'(d@(sp+2)&ffffff)=='..base(4)..target}
 if not thePort then tests[#tests+1]='w@(d@(sp+2))==0xa86e'end
 if not skip then tests[#tests+1]='w@(d@(sp+2))==0xa891'end
 cpu.debug:bpset(0xdd60,cond..' && ('..table.concat(tests,' || ')..')','')
 dbg.execution_state='run'
end
local function capture(phase)
 local tail='';for _,r in ipairs(regs)do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('DRGN_%s sp=%X region=%X body=%X size=%X master=%X memerr=%X zone=%X free=%X',phase,phase=='ENTER' and args or cpu.state.A7.value,region,body,size,mem:read_u32(region),mem:read_u16(0x220),zone,mem:read_u32(zone+12))..tail)
 save(phase..'-zone',zone,64);save(phase..'-port',port,108)
 save(phase..'-pm',pm,50);save(phase..'-pixels',pixels,pixelBytes)
 local ct=ptr(ptr(pm+42));save(phase..'-clut',ct,8+8*(mem:read_u16(ct+6)+1))
 for _,v in ipairs({{'vis',24},{'clip',28}})do
  local h=ptr(port+v[2]);assert(h~=region,'disposed active clipping region')
  local b=ptr(h);save(phase..'-'..v[1],b,mem:read_u16(b))
 end
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(bytes(0xdd60,8)=='2F0A2F02246F000A','dispatcher bytes');armed=true;arm()
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if ret then
   assert(cpu.state.PC.value==ret,'return PC');capture('RETURN')
   done=true;print('COMPLETE original pond region disposal');dbg:command('quit');return
  end
  local call=ptr(cpu.state.A7.value+2);local trap=mem:read_u16(call);local sp=cpu.state.A7.value+8
  dbg:command('bpclear')
  if trap==0xa86e then thePort=ptr(sp);arm();return end
  if trap==0xa891 then skip=true;print('DRGN_SKIP first LineTo');arm();return end
  if not masked then
   assert(trap==0xa8ec and bytes(call-4,6)=='42672F0AA8EC','masked copy caller')
   masked=true;print('DRGN_MASKED_COPY reached');arm();return
  end
  assert(trap==0xa8d9 and bytes(call-2,4)=='2F14A8D9','DisposeRgn caller')
  print('DRGN_BYTES data='..bytes(call-2,12))
  args=sp;ret=call+2;region=ptr(sp);body=ptr(region);size=mem:read_u16(body);zone=ptr(0x118)
  assert(size>=10 and size<=32766,'region extent');save('ENTER-region',body,size);save('ENTER-block',body-16,size+16)
  port=ptr(assert(thePort));pm=ptr(ptr(port+2));pixels=mem:read_u32(pm)
  pixelBytes=(mem:read_u16(pm+4)&0x3fff)*(mem:read_i16(pm+10)-mem:read_i16(pm+6))
  assert(mem:read_u16(pm+32)==8,'pixel depth');capture('ENTER')
  cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
  assert(mac.wait_for('first LineTo',function()return skip end,3600));mac.press('Return');print('DRGN_SKIP Return released')
  mac.wait(42000);error('region disposal absent')
 end)
 if not ok and not done then print('FAIL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'
