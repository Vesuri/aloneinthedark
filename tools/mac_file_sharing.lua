-- CPU-only scratch-file probe. No original code or existing file is changed.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SHARING / DEBUGGER REQUIRED')
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
 assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'SHARING / ORIGINAL BYTES')
 local steps={}
 local function add(label,trap,setup,success,failure)
  steps[#steps+1]={label=label,trap=trap,setup=setup or '',success=success or '',failure=failure or ''}
 end
 local function open(label,permission,register)
  add(label,0xa000,string.format('d@(a0+12)=sp+200;w@(a0+16)=0;w@(a0+18)=0;b@(a0+1b)=%x;',permission),register..'=w@(a0+18);',register..'=0;')
 end
 local function fcb(label,register) add(label,0xa260,'d@(a0+12)=0;w@(a0+1c)=0;w@(a0+18)='..register..';') end
 local function close(label,register) add(label,0xa001,'w@(a0+18)='..register..';') end
 add('create',0xa208,'d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,'logerror "FAIL sharing create; existing file preserved\\n";quit;')
 add('directory',0xa215,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;',nil,'logerror "FAIL sharing directory\\n";quit;')
 for first=0,4 do for second=0,4 do
  local tag=string.format('matrix_%d_%d',first,second)
  open(tag..'_first',first,'temp2');fcb(tag..'_firstflags','temp2')
  open(tag..'_second',second,'temp3');fcb(tag..'_secondflags','temp3')
  close(tag..'_close_second','temp3');close(tag..'_close_first','temp2')
 end end
 for _,pair in ipairs({{3,1},{4,4}}) do
  local tag=string.format('coherent_%d_%d',pair[1],pair[2])
  open(tag..'_first',pair[1],'temp2');open(tag..'_second',pair[2],'temp3')
  add(tag..'_truncate',0xa012,'w@(a0+18)=temp2;d@(a0+1c)=0;')
  add(tag..'_write',0xa003,'d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
  fcb(tag..'_second_before_read','temp3')
  add(tag..'_read',0xa002,'w@(a0+18)=temp3;d@(sp+300)=0;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
  add(tag..'_shrink',0xa012,'w@(a0+18)=temp2;d@(a0+1c)=2;')
  fcb(tag..'_second_after_shrink','temp3');fcb(tag..'_first_after_shrink','temp2')
  add(tag..'_flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;');fcb(tag..'_first_after_flush','temp2')
  close(tag..'_close_first','temp2');fcb(tag..'_second_after_close','temp3')
  add(tag..'_read_after_close',0xa002,'w@(a0+18)=temp3;d@(sp+300)=0;d@(a0+20)=sp+300;d@(a0+24)=2;w@(a0+2c)=1;d@(a0+2e)=0;')
  if pair[2]==4 then
   add(tag..'_write_after_close',0xa003,'w@(a0+18)=temp3;d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=2;d@(a0+2e)=0;')
   fcb(tag..'_after_late_write','temp3')
  end
  close(tag..'_close_second','temp3')
 end
 open('reader_close_writer',3,'temp2');open('reader_close_reader',1,'temp3')
 add('reader_close_write',0xa003,'w@(a0+18)=temp2;d@(sp+300)=12345678;d@(a0+20)=sp+300;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=0;')
 close('reader_close_first','temp3');fcb('reader_close_writer_flags','temp2');close('reader_close_last','temp2')
 add('lock',0xa041,'d@(a0+12)=sp+200;w@(a0+16)=0;',nil,'logerror "FAIL sharing lock\\n";quit;')
 for permission=0,4 do
  open('locked_'..permission,permission,'temp2');fcb('locked_'..permission..'_flags','temp2');close('locked_'..permission..'_close','temp2')
 end
 add('unlock',0xa042,'d@(a0+12)=sp+200;w@(a0+16)=0;',nil,'logerror "FAIL sharing unlock\\n";quit;')
 add('volume_name',0xa014,'d@(a0+12)=sp+250;')
 add('flush_name',0xa013,'d@(a0+12)=sp+250;w@(a0+16)=1234;')
 add('flush_plain_default',0xa013,'w@(a0+16)=0;')
 add('flush_colon',0xa013,'b@(sp+251+b@(sp+250))=3a;b@(sp+250)=b@(sp+250)+1;w@(a0+16)=1234;')
 add('flush_full_path',0xa013,'b@(sp+251+b@(sp+250))=58;b@(sp+250)=b@(sp+250)+1;')
 add('flush_partial',0xa013,'d@(a0+12)=sp+280;b@(sp+280)=2;b@(sp+281)=3a;b@(sp+282)=58;w@(a0+16)=ffff;')
 add('flush_partial_bad_ref',0xa013,'w@(a0+16)=1234;')
 add('restore_name',0xa013,'d@(a0+12)=sp+250;w@(a0+16)=ffff;')
 add('flush_bad_name',0xa013,'b@(sp+251)=58;w@(a0+16)=ffff;')
 add('volume_info',0xa207,'d@(a0+12)=0;w@(a0+16)=ffff;w@(a0+1c)=0;','temp4=w@(a0+42);')
 add('flush_drive',0xa013,'w@(a0+16)=temp4;')
 add('flush_bad_ref',0xa013,'d@(a0+12)=0;w@(a0+16)=1234;')
 add('flush_default',0xa013,'w@(a0+16)=0;')
 add('delete',0xa009,'d@(a0+12)=sp+200;w@(a0+16)=0;',nil,'logerror "FAIL sharing scratch delete\\n";quit;')
 add('flush',0xa013,'d@(a0+12)=0;w@(a0+16)=ffff;',nil,'logerror "FAIL sharing scratch flush\\n";quit;')
 local function enter(n)
  local s=steps[n]
  return s.setup..string.format('temp0=0x%x;d0=%x;w@(sp+400)=%x;pc=sp+400;g',n,s.trap==0xa260 and 8 or 0,s.trap)
 end
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=%x;',base+0x4146)
 local name='AITD Port Sharing Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+%x)=%x;',0x200+i-1,text:byte(i)) end
 cpu.debug:bpset(base+0x4146,'temp0==0',setup..enter(1))
 for n,s in ipairs(steps) do
  local report=string.format('logerror "SHARING label=%s stage=%X state=%%X trap=%04X d0=%%08X result=%%04X ref=%%04X volume=%%04X drive=%%04X flags=%%04X eof=%%08X mark=%%08X actual=%%08X position=%%08X data=%%08X\\n",temp0,d0,w@(a0+10),w@(a0+18),w@(a0+16),w@(a0+42),w@(a0+24),d@(a0+28),d@(a0+30),d@(a0+28),d@(a0+2e),d@(sp+300);',s.label,n,s.trap)
  local nextaction=n<#steps and enter(n+1) or 'logerror "PASS sharing capture complete; scratch deleted\\n";quit'
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)==0',n),report..s.success..nextaction)
  cpu.debug:bpset(base+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0',n),report..s.failure..(s.failure:find('quit',1,true) and '' or nextaction))
 end
 armed=true;print('ARM sharing Core+$4142 bytes=7008a2606004; owned scratch; no mode input')
end)
mac.run(function()
 local ok,err=pcall(function() assert(mac.launch(),'SHARING / LAUNCH FAILED');mac.wait(3600);error('SHARING / NO COMPLETION') end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
