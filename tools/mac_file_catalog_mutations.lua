-- CPU-only scratch-file probe. No original code or existing file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'CATALOG / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'CATALOG / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local byname='d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'
 local hierarchical='d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;'
 local fatal='logerror "FAIL catalog scratch ownership/setup\\n";quit;'
 add('create',0xa208,hierarchical,nil,fatal)
 add('duplicate',0xa208,hierarchical)
 add('directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,fatal)
 add('initial_info',0xa00c,byname)
 add('set_info',0xa00d,byname..'d@(a0+20)=54455354;d@(a0+24)=41495444;w@(a0+28)=400;w@(a0+2a)=12;w@(a0+2c)=34;w@(a0+2e)=0;d@(a0+48)=abcd0102;d@(a0+4c)=abcd0304;')
 add('changed_info',0xa00c,byname)
 add('hierarchical_info',0xa20c,hierarchical..'w@(a0+1c)=0;')
 add('hierarchical_set_info',0xa20d,hierarchical..'d@(a0+48)=abcd0102;d@(a0+4c)=abcd0304;')
 add('after_hierarchical_set',0xa00c,byname)
 add('open',0xa000,byname..'b@(a0+1b)=3;','temp2=w@(a0+18);',fatal)
 add('open_info',0xa00c,byname)
 add('busy_delete',0xa009,byname)
 add('close',0xa001,'w@(a0+18)=temp2;')
 add('lock',0xa041,byname)
 add('locked_info',0xa00c,byname)
 add('locked_set_info',0xa00d,byname..'d@(a0+4c)=abcd0506;')
 add('after_locked_set',0xa00c,byname)
 add('locked_delete',0xa009,byname)
 add('unlock',0xa042,byname)
 add('delete',0xa009,byname,nil,fatal)
 add('missing_info',0xa00c,byname)
 add('missing_delete',0xa009,byname)
 add('recreate',0xa008,byname..'b@(a0+1b)=0;',nil,fatal)
 add('recreated_info',0xa20c,hierarchical..'w@(a0+1c)=0;')
 add('recreated_setinfo',0xa00d,byname..'d@(a0+48)=abcd0102;d@(a0+4c)=abcd0304;')
 add('write_open',0xa000,byname..'b@(a0+1b)=3;','temp2=w@(a0+18);',fatal)
 add('write',0xa003,'w@(a0+18)=temp2;d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('written_info',0xa00c,byname)
 add('write_flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;')
 add('flushed_info',0xa00c,byname)
 add('write_close',0xa001,'w@(a0+18)=temp2;')
 add('closed_info',0xa00c,byname)
 add('hierarchical_delete',0xa209,hierarchical,nil,fatal)
 add('bad_directory',0xa208,hierarchical..'d@(a0+30)=9999;')
 add('empty_name',0xa008,'d@(a0+12)=sp+280;b@(sp+280)=0;w@(a0+16)=0;')
 add('flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;',nil,fatal)
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n,s.trap==0xa260 and 8 or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',base+0x4146)
 local name='AITD Port Catalog Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "CATALOG label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X ref=%%04X attr=%%02X finder0=%%08X finder1=%%08X finder2=%%08X finder3=%%08X id=%%08X data=%%08X resource=%%08X created=%%08X modified=%%08X\\n",temp0,d0,w@(a0+10),w@(a0+18),b@(a0+1e),d@(a0+20),d@(a0+24),d@(a0+28),d@(a0+2c),d@(a0+30),d@(a0+36),d@(a0+40),d@(a0+48),d@(a0+4c);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS catalog capture complete; scratch deleted\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM catalog Core+$4142 bytes=7008a2606004; owned scratch; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'CATALOG / LAUNCH FAILED');mac.wait(3600);error('CATALOG / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
