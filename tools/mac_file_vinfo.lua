-- CPU-only, read-only vinfo-file metadata probe. No game file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'VINFO / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x3cea)==0xa207661a and mem:read_u32(base+0x4424)==0xa2073e00,'VINFO / CALLER BYTES')
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'VINFO / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local function request(index,ref,text)
  local out='d@(a0+12)=0;w@(a0+16)='..(ref or 'temp2')..';w@(a0+1c)='..string.format('0x%x',index&0xffff)..';'
  for i=0,45 do out=out..string.format('w@(a0+0x%x)=cccc;',30+2*i) end
  if text then
   out=out..'d@(a0+12)=sp+200;'
   text=string.char(#text)..text
   for i=1,#text do out=out..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
  end
  return out
 end
 add('get-default',0xa014,'d@(a0+12)=0;','temp3=w@(a0+16);')
 add('explicit',0xa207,request(0),'temp4=w@(a0+42);temp5=d@(a0+5a);')
 add('default',0xa207,request(0,'0'))
 add('wd',0xa207,request(0,'temp3'))
 add('drive',0xa207,request(0,'1'))
 add('drive-valid',0xa207,request(0,'temp4'))
 add('badvol',0xa207,request(0,'1234'))
 add('index1',0xa207,request(1,'1234','ignored'))
 add('index2',0xa207,request(2,'temp2','ignored'))
 add('zero-name',0xa207,request(0,'temp2','ignored'))
 add('named',0xa207,request(-1,'1234','7.5.5 2GB (D)'))
 add('named-colon',0xa207,request(-1,'1234','7.5.5 2GB (D):'))
 add('missing',0xa207,request(-1,'temp2','AITD Absent Volume:'))
 add('negative-default',0xa207,request(-1,'0','ignored'))
 add('system-wd',0xa260,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp5;d@(a0+1c)=4552494b;','temp6=w@(a0+16);')
 add('system-query',0xa260,'w@(a0+16)=temp6;w@(a0+1a)=0;')
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n,s.label=='system-wd' and 1 or s.label=='system-query' and 7 or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);temp2=w@(a0+34);temp3=w@(a0+16);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',base+0x4146)
 local name='ignored';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "VINFO label=%s stage=%X state=%%X d0=%%08X result=%%04X volume=%%04X created=%%08X modified=%%08X attr=%%04X valence=%%04X bitmap=%%04X alloc=%%04X blocks=%%04X blocksize=%%08X clump=%%08X start=%%04X nextid=%%08X free=%%04X sig=%%04X drive=%%04X driver=%%04X fsid=%%04X backup=%%08X sequence=%%04X writes=%%08X files=%%08X dirs=%%08X finder0=%%08X finder1=%%08X finder2=%%08X finder3=%%08X finder4=%%08X finder5=%%08X finder6=%%08X finder7=%%08X name0=%%08X name1=%%08X name2=%%08X name3=%%08X\\n",temp0,d0,w@(a0+10),w@(a0+16),d@(a0+1e),d@(a0+22),w@(a0+26),w@(a0+28),w@(a0+2a),w@(a0+2c),w@(a0+2e),d@(a0+30),d@(a0+34),w@(a0+38),d@(a0+3a),w@(a0+3e),w@(a0+40),w@(a0+42),w@(a0+44),w@(a0+46),d@(a0+48),w@(a0+4c),d@(a0+4e),d@(a0+52),d@(a0+56),d@(a0+5a),d@(a0+5e),d@(a0+62),d@(a0+66),d@(a0+6a),d@(a0+6e),d@(a0+72),d@(a0+76),d@(sp+200),d@(sp+204),d@(sp+208),d@(sp+20c);',s.label,n)

  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS vinfo capture complete; read-only complete\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM vinfo Core+$4142 bytes=7008a2606004; read-only vinfo files; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'VINFO / LAUNCH FAILED');mac.wait(3600);error('VINFO / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
