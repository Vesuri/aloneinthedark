-- CPU-only scratch-file probe. No original code or existing file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'OPENDF / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'OPENDF / ORIGINAL BYTES')
 assert(mem:read_u32(base+0x3f78)==0x701aa060,'OPENDF / ORIGINAL CALLER BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local byname='d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'
 local hierarchical='d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;'
 local fatal='logerror "FAIL opendf scratch ownership/setup\\n";quit;'
 local function setname(text)
  text=string.char(#text)..text;local out=''
  for i=1,#text do out=out..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
  return out
 end
 add('create',0xa208,hierarchical,nil,fatal)
 add('created_info',0xa20c,hierarchical,'temp4=d@(a0+30);',fatal)
 add('directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,fatal)
 add('seed_open',0xa260,hierarchical..'b@(a0+1b)=3;',nil,fatal)
 add('seed_write',0xa003,'d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('seed_close',0xa001)
 for _,trap in ipairs({0xa060,0xa260}) do
  local prefix=trap==0xa060 and 'fs_' or 'hfs_'
  for p=0,4 do
   add(prefix..'open_'..p,trap,hierarchical..'b@(a0+1b)='..p..';',nil,fatal)
   add(prefix..'fcb_'..p,0xa260,'w@(a0+1c)=0;')
   if p==1 then add(prefix..'read',0xa002,'d@(sp+300)=0;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;') end
   add(prefix..'close_'..p,0xa001)
  end
 end
 add('exclusive',0xa060,hierarchical..'b@(a0+1b)=3;','temp2=w@(a0+18);',fatal)
 add('conflict',0xa260,hierarchical..'b@(a0+1b)=3;w@(a0+18)=0;')
 add('exclusive_close',0xa001,'w@(a0+18)=temp2;')
 add('shared_first',0xa060,hierarchical..'b@(a0+1b)=4;','temp2=w@(a0+18);',fatal)
 add('shared_second',0xa260,hierarchical..'b@(a0+1b)=4;','temp3=w@(a0+18);',fatal)
 add('shared_read',0xa002,'w@(a0+18)=temp2;d@(sp+300)=0;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('shared_position',0xa018,'w@(a0+18)=temp3;')
 add('shared_close_second',0xa001,'w@(a0+18)=temp3;')
 add('shared_close_first',0xa001,'w@(a0+18)=temp2;')
 add('ignored_directory',0xa060,hierarchical..'b@(a0+1b)=1;d@(a0+30)=9999;')
 add('ignored_close',0xa001)
 add('bad_directory',0xa260,hierarchical..'b@(a0+1b)=1;d@(a0+30)=9999;w@(a0+18)=1234;')
 add('hopen_bad_directory',0xa200,hierarchical..setname(':.AITD Port DF Probe')..'b@(a0+1b)=1;d@(a0+30)=9999;w@(a0+18)=1234;')
 add('hopenrf_bad_directory',0xa20a,hierarchical..setname('.AITD Port DF Probe')..'b@(a0+1b)=1;d@(a0+30)=9999;w@(a0+18)=1234;')
 add('bad_volume',0xa260,hierarchical..'b@(a0+1b)=1;w@(a0+16)=1234;w@(a0+18)=1234;')
 add('file_directory',0xa260,hierarchical..'b@(a0+1b)=1;d@(a0+30)=temp4;w@(a0+18)=1234;')
 add('file_parent',0xa260,hierarchical..setname(':.AITD Port DF Probe:child')..'b@(a0+1b)=1;w@(a0+18)=1234;')
 add('missing_parent',0xa260,hierarchical..setname(':AITD Absent Parent:child')..'b@(a0+1b)=1;w@(a0+18)=1234;')
 add('restore_name',0xa20c,hierarchical..setname('.AITD Port DF Probe'))
 add('lock',0xa041,byname)
 for p=0,4 do
  add('locked_'..p,0xa060,hierarchical..'b@(a0+1b)='..p..';w@(a0+18)=0;')
  if p<2 then add('locked_close_'..p,0xa001) end
 end
 add('unlock',0xa042,byname)
 add('delete',0xa009,byname,nil,fatal)
 add('missing',0xa060,hierarchical..'b@(a0+1b)=1;w@(a0+18)=1234;')
 add('flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;',nil,fatal)
 local function enter(n)
  local s=steps[n]
  return s.setup..(s.trap==0xa060 and 'w@(a0+16)=0;' or '')..string.format('temp0=0x%x;d0=%x;w@(sp+400)=%x;pc=sp+400;g',n,s.label:find('fcb_',1,true) and 8 or 0x1a,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=%x;',base+0x4146)
 local name='.AITD Port DF Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "OPENDF label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X ref=%%04X attr=%%02X data=%%08X resource=%%08X eof=%%08X flags=%%04X length=%%08X mark=%%08X actual=%%08X name0=%%08X name1=%%08X position=%%08X bytes=%%08X tail=%%04X\\n",temp0,d0,w@(a0+10),w@(a0+18),b@(a0+1e),d@(a0+36),d@(a0+40),d@(a0+1c),w@(a0+24),d@(a0+28),d@(a0+30),d@(a0+28),d@(sp+200),d@(sp+204),d@(a0+2e),d@(sp+300),w@(sp+304);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS opendf capture complete; scratch deleted\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM opendf Core+$4142 bytes=7008a2606004 OpenDF=701AA060; owned scratch; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'OPENDF / LAUNCH FAILED');mac.wait(3600);error('OPENDF / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
