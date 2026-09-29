-- CPU-only scratch-file probe. No original code or existing file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'FORKS / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'FORKS / ORIGINAL BYTES')
 assert(mem:read_u16(base+0x4158)==0xa20a,'FORKS / HOPENRF ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local byname='d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+1c)=0;'
 local hierarchical='d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;'
 local fatal='logerror "FAIL forks scratch ownership/setup\\n";quit;'
 add('create',0xa208,hierarchical,nil,fatal)
 add('directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,fatal)
 add('data_open',0xa200,hierarchical..'b@(a0+1b)=3;','temp2=w@(a0+18);',fatal)
 add('resource_open',0xa20a,hierarchical..'b@(a0+1b)=3;','temp3=w@(a0+18);',fatal)
 add('resource_empty',0xa011,'w@(a0+18)=temp3;')
 add('data_write',0xa003,'w@(a0+18)=temp2;d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('resource_write',0xa003,'w@(a0+18)=temp3;d@(sp+300)=abcdef01;w@(sp+304)=2345;d@(a0+20)=sp+300;d@(a0+24)=6;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('both_info',0xa00c,byname)
 add('data_fcb',0xa260,'w@(a0+18)=temp2;w@(a0+1c)=0;')
 add('resource_fcb',0xa260,'w@(a0+18)=temp3;w@(a0+1c)=0;')
 add('resource_reader',0xa00a,byname..'b@(a0+1b)=1;','temp4=w@(a0+18);',fatal)
 add('resource_read',0xa002,'w@(a0+18)=temp4;d@(sp+300)=0;w@(sp+304)=0;d@(a0+20)=sp+300;d@(a0+24)=6;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('reader_close',0xa001,'w@(a0+18)=temp4;')
 add('data_close',0xa001,'w@(a0+18)=temp2;')
 add('resource_after_data_close',0xa260,'w@(a0+18)=temp3;w@(a0+1c)=0;')
 add('resource_close',0xa001,'w@(a0+18)=temp3;')
 add('reopen_resource',0xa20a,hierarchical..'b@(a0+1b)=1;','temp3=w@(a0+18);',fatal)
 add('resource_eof',0xa011,'w@(a0+18)=temp3;')
 add('resource_readback',0xa002,'d@(sp+300)=0;w@(sp+304)=0;d@(a0+20)=sp+300;d@(a0+24)=6;w@(a0+2c)=1;d@(a0+2e)=0;')
 add('reopened_close',0xa001,'w@(a0+18)=temp3;')
 for p=0,4 do
  add('permission_'..p,0xa20a,hierarchical..'b@(a0+1b)='..p..';w@(a0+18)=0;')
  add('permission_flags_'..p,0xa260,'w@(a0+1c)=0;')
  add('permission_close_'..p,0xa001)
 end
 add('shared_first',0xa20a,hierarchical..'b@(a0+1b)=4;','temp2=w@(a0+18);',fatal)
 add('shared_second',0xa20a,hierarchical..'b@(a0+1b)=4;',nil,fatal)
 add('shared_close_second',0xa001)
 add('shared_close_first',0xa001,'w@(a0+18)=temp2;')
 add('lock',0xa041,byname)
 for p=0,4 do
  add('locked_'..p,0xa20a,hierarchical..'b@(a0+1b)='..p..';w@(a0+18)=0;')
  add('locked_flags_'..p,0xa260,'w@(a0+1c)=0;')
  add('locked_close_'..p,0xa001)
 end
 add('unlock',0xa042,byname)
 add('closed_info',0xa00c,byname)
 add('delete',0xa009,byname,nil,fatal)
 add('missing_resource',0xa20a,hierarchical..'b@(a0+1b)=1;')
 add('flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;',nil,fatal)
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n,s.trap==0xa260 and 8 or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',base+0x4146)
 local name='AITD Port Fork Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "FORKS label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X ref=%%04X attr=%%02X data=%%08X resource=%%08X eof=%%08X flags=%%04X length=%%08X mark=%%08X actual=%%08X position=%%08X bytes=%%08X tail=%%04X\\n",temp0,d0,w@(a0+10),w@(a0+18),b@(a0+1e),d@(a0+36),d@(a0+40),d@(a0+1c),w@(a0+24),d@(a0+28),d@(a0+30),d@(a0+28),d@(a0+2e),d@(sp+300),w@(sp+304);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS forks capture complete; scratch deleted\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM forks Core+$4142 bytes=7008a2606004 HOpenRF=A20A; owned scratch; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'FORKS / LAUNCH FAILED');mac.wait(3600);error('FORKS / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
