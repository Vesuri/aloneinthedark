-- Bounded, read-only File Manager reference fixture. Re-enter the original
-- byte-checked original traps with diagnostic parameter blocks, then exit.
-- AITD_FILE_QUERIES=directories selects defaults; =wd selects WD lifetime/filtering.
-- This measures API semantics; it is not original-game execution acceptance.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu']
local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'FILE QUERIES / DEBUGGER REQUIRED')
local armed=false
local function log(stage)
 return 'logerror "FCBQUERY stage='..stage..' d0=%08X result=%04X volume=%04X ref=%04X index=%04X id=%08X flags=%04X eof=%08X parent=%08X\\n",d0,w@(a0+10),w@(a0+16),w@(a0+18),w@(a0+1c),d@(a0+20),w@(a0+24),d@(a0+28),d@(a0+3a);'
end
emu.register_frame_done(function()
 if armed or mac.frontmost()~='Alone In The Dark' then return end
 local a5=mem:read_u32(0x904)&0xffffff
 if a5<0x100000 or a5-(mem:read_u32(0x908)&0xffffff)~=75616 then return end
 for i,j in ipairs(meta.jt) do
  local e=a5+32+(i-1)*8
  if j[1]==3 and mem:read_u16(e)==3 and mem:read_u16(e+2)==0x4ef9 then
   local base=(mem:read_u32(e+4)&0xffffff)-j[2]
   assert(mem:read_u32(base+0x4142)==0x7008a260 and mem:read_u16(base+0x4146)==0x6004,'FILE QUERIES / ORIGINAL BYTES')
   if os.getenv('AITD_FILE_QUERIES')=='directories' or os.getenv('AITD_FILE_QUERIES')=='wd' then
    local steps={
     {0x4144,0xa260,'temp1=d@(a0+3a);temp4=d@(a0+12);d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;'},
     {0x4108,0xa215,'d@(a0+1c)=deadbeef;'}, {0x411a,0xa214,''}, {0x403e,0xa014,'w@(a0+16)=ffff;d@(a0+30)=temp1;d@(a0+1c)=41495444;d@(a0+12)=temp4;d@(temp4)=0c3a416c;d@(temp4+4)=6f6e6520;d@(temp4+8)=44617461;b@(temp4+c)=3a;'},
     {0x40de,0xa260,'temp2=w@(a0+16);d@(a0+12)=0;'}, {0x4066,0xa015,'d@(a0+1c)=deadbeef;'},
     {0x411a,0xa214,''}, {0x403e,0xa014,'w@(a0+1a)=0;'},
     {0x412e,0xa260,'w@(a0+16)=temp2;d@(a0+30)=0;'},
     {0x4108,0xa215,'d@(a0+1c)=deadbeef;'}, {0x411a,0xa214,''}, {0x403e,0xa014,'w@(a0+16)=temp2;'},
     {0x40f4,0xa260,''}, {0x411a,0xa214,''}, {0x403e,0xa014,'w@(a0+16)=temp2;w@(a0+1a)=0;'},
     {0x412e,0xa260,'w@(a0+16)=temp2;'}, {0x40f4,0xa260,'w@(a0+16)=ffff;'},
     {0x40f4,0xa260,''}, {0x412e,0xa260,'w@(a0+16)=0;'},
     {0x412e,0xa260,'w@(a0+16)=ffff;d@(a0+30)=9999;'}, {0x4108,0xa215,''},
    }
    local wdmode=os.getenv('AITD_FILE_QUERIES')=='wd'
    if wdmode then
     local data='d@(a0+12)=temp4;d@(temp4)=0c3a416c;d@(temp4+4)=6f6e6520;d@(temp4+8)=44617461;b@(temp4+c)=3a;w@(a0+16)=ffff;d@(a0+30)=temp1;'
     steps={
      {0x4144,0xa260,'temp1=d@(a0+3a);temp4=d@(a0+12);d@(a0+12)=0;w@(a0+16)=ffff;d@(a0+30)=temp1;d@(a0+1c)=0;'},
      {0x40de,0xa260,'temp5=w@(a0+16);w@(a0+16)=8053;w@(a0+1a)=0;'},
      {0x412e,0xa260,''}, {0x40f4,0xa260,''},
      {0x412e,0xa260,data..'d@(a0+1c)=41495444;'},
      {0x40de,0xa260,'temp2=w@(a0+16);'..data..'d@(a0+1c)=41495445;'},
      {0x40de,0xa260,'temp3=w@(a0+16);d@(a0+12)=0;w@(a0+1a)=0;'},
      {0x412e,0xa260,'w@(a0+16)=temp2;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=1;d@(a0+1c)=41495444;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=1;d@(a0+1c)=41495445;'},
      {0x412e,0xa260,'w@(a0+16)=temp2;w@(a0+1a)=0;'},
      {0x4066,0xa015,''}, {0x40f4,0xa260,'d@(a0+1c)=deadbeef;'},
      {0x411a,0xa214,'w@(a0+16)=temp2;w@(a0+1a)=0;'},
      {0x412e,0xa260,''}, {0x40f4,0xa260,'w@(a0+16)=0;w@(a0+1a)=1;d@(a0+1c)=0;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=1;d@(a0+1c)=41495444;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=1;d@(a0+1c)=41495445;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=2;d@(a0+1c)=41495445;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=7fff;d@(a0+1c)=0;'},
      {0x412e,0xa260,'w@(a0+16)=0;w@(a0+1a)=ffff;d@(a0+1c)=0;'},
      {0x412e,0xa260,'w@(a0+16)=1234;w@(a0+1a)=1;d@(a0+1c)=0;'},
      {0x412e,0xa260,'w@(a0+16)=0;'}, {0x40f4,0xa260,'w@(a0+16)=1234;'},
      {0x40f4,0xa260,'w@(a0+16)=temp5;'}, {0x40f4,0xa260,'w@(a0+1a)=0;'},
      {0x412e,0xa260,''},
     }
    end
    for n,step in ipairs(steps) do
     assert(mem:read_u16(base+step[1])==step[2],'DIRECTORY QUERIES / ORIGINAL TRAP BYTES')
     local report=string.format('logerror "DIRQUERY stage=%%X trap=%%04X d0=%%08X result=%%04X volume=%%04X created=%%04X index=%%04X process=%%08X wdvolume=%%04X directory=%%08X\\n",temp0,0x%x,d0,w@(a0+10),w@(a0+16),w@(a0+18),w@(a0+1a),d@(a0+1c),w@(a0+20),d@(a0+30);',step[2])
     if wdmode then report=report:gsub('DIRQUERY','WDQUERY') end
     local nextstep=steps[n+1]
     local action
     if nextstep then
      local selector=nextstep[1]==0x40de and 1 or nextstep[1]==0x40f4 and 2 or nextstep[1]==0x412e and 7 or 0
      action=step[3]..string.format('temp0=0x%x;d0=0x%x;pc=0x%x;g',n,selector,base+nextstep[1])
     else action='logerror "PASS directory-query capture complete\\n";quit' end
     if wdmode then action=action:gsub('directory%-query capture','wd-query capture') end
     cpu.debug:bpset(base+step[1]+2,string.format('temp0==0x%x',n-1),report..action)
    end
   else
   local at=base+0x4146
   local again='d0=8;pc=pc-2;g'
   cpu.debug:bpset(at,'temp0==0',log(0)..'temp0=1;d@(a0+12)=0;w@(a0+16)=0;w@(a0+1c)=1;'..again)
   cpu.debug:bpset(at,'temp0==1',log(1)..'temp1=w@(a0+18);temp2=d@(a0+20);temp3=d@(a0+28);temp0=2;w@(a0+1c)=0;'..again)
   cpu.debug:bpset(at,'temp0==2',log(2)..'temp0=3;w@(a0+1c)=7fff;'..again)
   cpu.debug:bpset(at,'temp0==3',log(3)..'temp0=4;w@(a0+1c)=1;w@(a0+16)=1234;'..again)
   cpu.debug:bpset(at,'temp0==4',log(4)..'temp0=5;w@(a0+1c)=0;w@(a0+18)=0;'..again)
   cpu.debug:bpset(at,'temp0==5',log(5)..'logerror "PASS file-query capture complete\\n";quit')
   end
   armed=true
   print(string.format('ARM file-queries Core+$4144=%08X bytes=7008a2606004',base+0x4144))
   break
  end
 end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'FILE QUERIES / LAUNCH FAILED')
  mac.wait(3600)
  error('FILE QUERIES / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
