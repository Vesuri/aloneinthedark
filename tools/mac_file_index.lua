-- CPU-only scratch-file probe. No original code or existing file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'INDEX / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'INDEX / ORIGINAL BYTES')
 assert(mem:read_u16(base+0x417c)==0xa20c,'INDEX / HGETFINFO ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local fatal='logerror "FAIL index scratch setup/cleanup\\n";quit;'
 local function named(text,dir)
  local out='d@(a0+12)=sp+200;w@(a0+16)=ffff;w@(a0+1c)=0;b@(a0+1b)=0;d@(a0+30)='..dir..';'
  text=string.char(#text)..text
  for i=1,#text do out=out..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
  return out
 end
 add('make_directory',0xa260,named('AITD Port Index Probe','temp1'),'temp2=d@(a0+30);',fatal);steps[#steps].selector=6
 local names={}
 for c=126,32,-1 do if not (c>=97 and c<=122) and c~=47 and c~=58 then names[#names+1]='i'..string.char(c)..'x' end end
 for i,name in ipairs(names) do add('create_'..i,0xa208,named(name,'temp2'),nil,fatal) end
 add('make_subdirectory',0xa260,named('iBdir','temp2'),'temp3=d@(a0+30);',fatal);steps[#steps].selector=6
 for i=1,#names+2 do add('index_'..i,0xa20c,named('ignored','temp2')..string.format('w@(a0+1c)=0x%x;',i)) end
 add('null_name',0xa20c,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp2;w@(a0+1c)=1;')
 add('negative_name',0xa20c,named('iAx','temp2')..'w@(a0+1c)=ffff;')
 add('bad_directory',0xa20c,named('ignored','9999')..'w@(a0+1c)=1;')
 add('bad_volume',0xa20c,named('ignored','temp2')..'w@(a0+1c)=1;w@(a0+16)=1234;')
 add('default_directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp2;',nil,fatal)
 add('classic_index',0xa00c,named('ignored','9999')..'w@(a0+16)=0;w@(a0+1c)=1;')
 add('open_wd',0xa260,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp2;d@(a0+1c)=41495444;','temp4=w@(a0+16);',fatal);steps[#steps].selector=1
 add('wd_bad_directory',0xa20c,named('ignored','9999')..'w@(a0+16)=temp4;w@(a0+1c)=1;')
 add('close_wd',0xa260,'w@(a0+16)=temp4;',nil,fatal);steps[#steps].selector=2
 add('restore_directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,fatal)
 for i,name in ipairs(names) do add('delete_'..i,0xa209,named(name,'temp2'),nil,fatal) end
 add('delete_subdirectory',0xa209,named('iBdir','temp2'),nil,fatal)
 add('delete_directory',0xa209,named('AITD Port Index Probe','temp1'),nil,fatal)
 add('flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;',nil,fatal)
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n,s.selector or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',base+0x4146)
 local name='AITD Port Catalog Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "INDEX label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X index=%%04X attr=%%02X name0=%%08X name1=%%08X id=%%08X\\n",temp0,d0,w@(a0+10),w@(a0+1c),b@(a0+1e),d@(sp+200),d@(sp+204),d@(a0+30);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS index capture complete; scratch deleted\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM index Core+$4142 bytes=7008a2606004; owned scratch; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'INDEX / LAUNCH FAILED');mac.wait(3600);error('INDEX / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
