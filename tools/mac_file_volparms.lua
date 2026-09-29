-- CPU-only, read-only volparms-file metadata probe. No game file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'VOLPARMS / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x43f4)==0x7030a260,'VOLPARMS / CALLER BYTES')
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'VOLPARMS / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local function request(count,ref,text)
  local out='d@(a0+12)=0;w@(a0+16)='..(ref or 'temp2')..';d@(a0+20)=sp+300;d@(a0+24)='..string.format('0x%x',count)..';d@(a0+28)=deadbeef;'
  for i=0,7 do out=out..string.format('d@(sp+0x%x)=cccccccc;',0x300+4*i) end
  if text then
   out=out..'d@(a0+12)=sp+200;'
   text=string.char(#text)..text
   for i=1,#text do out=out..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
  end
  return out
 end
 add('get-default',0xa014,'d@(a0+12)=0;','temp3=w@(a0+16);')
 for _,count in ipairs({0,1,2,4,6,10,14,18,20,24,32}) do add('size'..count,0xa260,request(count)) end
 add('default',0xa260,request(6,'0'))
 add('wd',0xa260,request(6,'temp3'))
 add('badvol',0xa260,request(6,'1234'))
 add('named',0xa260,request(6,'1234','7.5.5 2GB (D)'))
 add('named-colon',0xa260,request(6,'1234','7.5.5 2GB (D):'))
 add('missing',0xa260,request(6,'temp2','AITD Absent Volume'))
 add('missing-colon',0xa260,request(6,'temp2','AITD Absent Volume:'))
 add('empty',0xa260,request(6,'temp2',''))
 add('relative',0xa260,request(6,'temp2',':ignored:'))
 add('null-zero',0xa260,request(0)..'d@(a0+20)=0;')
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n,0x30,s.trap)
 end
 local setup='temp1=d@(a0+3a);temp2=w@(a0+34);temp3=w@(a0+16);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',base+0x4146)
 local name='AITD Port Catalog Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "VOLPARMS label=%s stage=%X state=%%X d0=%%08X result=%%04X actual=%%08X volume=%%04X b0=%%08X b1=%%08X b2=%%08X b3=%%08X b4=%%08X b5=%%08X b6=%%08X b7=%%08X\\n",temp0,d0,w@(a0+10),d@(a0+28),w@(a0+16),d@(sp+300),d@(sp+304),d@(sp+308),d@(sp+30c),d@(sp+310),d@(sp+314),d@(sp+318),d@(sp+31c);',s.label,n)

  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS volparms capture complete; read-only complete\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM volparms Core+$4142 bytes=7008a2606004; read-only volparms files; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'VOLPARMS / LAUNCH FAILED');mac.wait(3600);error('VOLPARMS / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
