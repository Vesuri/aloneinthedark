-- Bounded writable File Manager API fixture in a newly created, named scratch
-- file on the local reference volume. Existing files are never overwritten.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'MUTATION PROBE / DEBUGGER REQUIRED')
local bases={};local armed=false
local function emit(stage)
 return string.format('logerror "MUTATION stage=%X d0=%%08X result=%%04X ref=%%04X misc=%%08X actual=%%08X position=%%08X fcbmark=%%08X data0=%%08X data1=%%08X data2=%%08X data3=%%08X data4=%%08X\\n",d0,w@(a0+10),w@(a0+18),d@(a0+1c),d@(a0+28),d@(a0+2e),d@(a0+30),d@(sp+300),d@(sp+304),d@(sp+308),d@(sp+30c),d@(sp+310);',stage)
end
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if (j[1]==3 or j[1]==11) and mem:read_u16(e)==j[1] and mem:read_u16(e+2)==0x4ef9 then
   bases[j[1]]=(mem:read_u32(e+4)&0xffffff)-j[2]
  end
 end
 if not bases[3] then return end
 assert(mem:read_u32(bases[3]+0x4142)==0x7008a260 and mem:read_u16(bases[3]+0x4146)==0x6004,'MUTATION / ORIGINAL FCB BYTES')
 -- Segment/offset columns identify original census sites; the fixture runs
 -- these APIs in its own stub, without modifying those original instructions.
 local steps={
  {3,0x416a,0xa208,'d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;'},
  {3,0x4108,0xa215,'d@(a0+12)=sp+200;w@(a0+16)=0;b@(a0+1b)=3;'},
  {11,0x0fbe,0xa000,'temp2=w@(a0+18);d@(a0+1c)=0;'},
  {11,0x0fec,0xa012,'d@(a0+20)=sp+300;d@(sp+300)=12345678;d@(a0+24)=4;w@(a0+2c)=1;d@(a0+2e)=8;'},
  {11,0x11ce,0xa003,''}, {11,0x0ffa,0xa011,'d@(a0+1c)=2;'},
  {11,0x0fec,0xa012,'d@(a0+12)=0;w@(a0+1c)=0;'},
  {3,0x4144,0xa260,'w@(a0+18)=temp2;d@(a0+20)=sp+300;d@(a0+24)=0;w@(a0+2c)=1;d@(a0+2e)=20;'},
  {11,0x11ce,0xa003,'w@(a0+1c)=0;'},
  {3,0x4144,0xa260,'w@(a0+18)=temp2;d@(a0+1c)=14;'},
  {11,0x0fec,0xa012,'d@(a0+20)=sp+300;d@(a0+24)=14;w@(a0+2c)=1;d@(a0+2e)=0;'},
  {11,0x111e,0xa002,'d@(sp+300)=abcdef01;d@(a0+24)=4;w@(a0+2c)=3;d@(a0+2e)=ffffffff;'},
  {11,0x11ce,0xa003,'d@(a0+12)=0;w@(a0+16)=ffff;'},
  {11,0x12ea,0xa013,''}, {3,0x3fa6,0xa001,'d@(a0+12)=sp+200;w@(a0+16)=0;b@(a0+1b)=1;'},
  {11,0x0fbe,0xa000,'d@(a0+20)=sp+300;d@(a0+24)=4;d@(a0+28)=deadbeef;w@(a0+2c)=1;d@(a0+2e)=0;'},
  {11,0x11ce,0xa003,'d@(a0+1c)=0;'}, {11,0x0fec,0xa012,''},
  {3,0x3fa6,0xa001,'d@(a0+12)=sp+200;w@(a0+16)=0;'}, {11,0x0fd6,0xa009,'d@(a0+12)=0;w@(a0+16)=ffff;'},
  {11,0x12ea,0xa013,''},
 }
 -- The fixture owns scratch stack memory; it changes no original instructions.
 -- Each trap returns through a generated JMP to the verified startup observer.
 local setup='temp1=d@(a0+3a);sp=sp-600;a0=sp+100;'
 for i=0,19 do setup=setup..string.format('d@(a0+0x%x)=0;',4*i) end
 setup=setup..string.format('w@(sp+402)=4ef9;d@(sp+404)=0x%x;',bases[3]+0x4146)
 local name='AITD Port Write Probe';local text=string.char(#name)..name
 for i=1,#text do setup=setup..string.format('b@(sp+0x%x)=0x%x;',0x200+i-1,text:byte(i)) end
 setup=setup..'temp0=1;d@(a0+12)=sp+200;w@(a0+16)=ffff;d@(a0+30)=temp1;w@(sp+400)=a208;pc=sp+400;g'
 cpu.debug:bpset(bases[3]+0x4146,'temp0==0',setup)
 for n,s in ipairs(steps) do
  local nextstep=steps[n+1];local action
  if nextstep then
   action=s[4]..string.format('temp0=0x%x;d0=0x%x;w@(sp+400)=0x%x;pc=sp+400;g',n+1,nextstep[3]==0xa260 and 8 or 0,nextstep[3])
  else action='logerror "PASS mutation capture complete; scratch file deleted\\n";quit' end
  local expected=(n==17 or n==18) and 0xffc3 or 0
  local condition=string.format('temp0==0x%x && (d0&ffff)==0x%x',n,expected)
  cpu.debug:bpset(bases[3]+0x4146,condition,'logerror "MUTATION RETURN pc=%08X sp=%08X a0=%08X stage=%X stub=%04X\\n",pc,sp,a0,temp0,w@(sp+400);'..emit(n)..action)
  cpu.debug:bpset(bases[3]+0x4146,string.format('temp0==0x%x && (d0&ffff)!=0x%x',n,expected),emit(n)..'logerror "FAIL mutation unexpected result; scratch retained for recovery\\n";quit')
 end
 armed=true;print('ARM mutation Core+$4142 bytes=7008a2606004; stack-owned API fixture; new scratch file only')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'MUTATION / LAUNCH FAILED');mac.wait(3600);error('MUTATION / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
