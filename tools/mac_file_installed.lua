-- CPU-only, read-only installed-file metadata probe. No game file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'INSTALLED / DEBUGGER REQUIRED')
local armed=false
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 local base
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==3 and mem:read_u16(e)==3 and mem:read_u16(e+2)==0x4ef9 then base=(mem:read_u32(e+4)&0xffffff)-j[2];break end
 end
 if not base then return end
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'INSTALLED / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local byname='d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'
 local hierarchical='d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;'
 local fatal='logerror "FAIL installed file-info query\\n";quit;'
 local function named(text)
  local out='d@(a0+12)=sp+200;w@(a0+16)=ffff;w@(a0+1c)=0;d@(a0+30)=temp1;'
  text=string.char(#text)..text
  for i=1,#text do out=out..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
  return out
 end
 add('application',0xa20c,named('Alone In The Dark'),nil,fatal)
 add('camera',0xa20c,named(':Alone Data:Camera00.PAK'),nil,fatal)
 add('ress',0xa20c,named(':Alone Data:ITD_Ress.PAK'),nil,fatal)
 add('present',0xa20c,named(':Alone Data:Present.PAK'),nil,fatal)
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=%x;w@(sp+400)=%x;pc=sp+400;g',n,s.trap==0xa260 and 8 or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=%x;',base+0x4146)
 local name='AITD Port Catalog Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "INSTALLED label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X ref=%%04X attr=%%02X finder0=%%08X finder1=%%08X finder2=%%08X finder3=%%08X id=%%08X data=%%08X resource=%%08X created=%%08X modified=%%08X\\n",temp0,d0,w@(a0+10),w@(a0+18),b@(a0+1e),d@(a0+20),d@(a0+24),d@(a0+28),d@(a0+2c),d@(a0+30),d@(a0+36),d@(a0+40),d@(a0+48),d@(a0+4c);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS installed capture complete; read-only complete\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM installed Core+$4142 bytes=7008a2606004; read-only installed files; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'INSTALLED / LAUNCH FAILED');mac.wait(3600);error('INSTALLED / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
