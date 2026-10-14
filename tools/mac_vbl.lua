-- Original System 7.5.5 fixture at AitD InitGraf; adapted from the PoP2 fixture.
-- Callback counters and task records are evidence, never original game bytes.
local M={}
local mac=dofile('tools/mame_mac_input.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=manager.machine.debugger
local ending,probe,base,startTick,removing
local counts={1,2,0,0xffff}
local links={}
local function put(address,bytes)
 for i=1,#bytes do mem:writev_u8(address+i-1,bytes:byte(i))end
 for i=1,#bytes do assert(mem:readv_u8(address+i-1)==bytes:byte(i),'TIMING FIXTURE BYTES')end
end
function M.start()
 base=(cpu.state.SP.value&0xffffff)-16384
 assert(base>0x100000 and base+4096<0x800000,'TIMING FIXTURE EXTENT')
 local program=''
 for i,count in ipairs(counts)do
  local task=base+2048+32*i;local data=base+3072+32*i;local callback=base+512+64*i
  put(data,string.rep('\0',32))
  put(task,string.pack('>I4I2I4I2I2',0,1,callback,count,0))
  -- Increment counter, capture Ticks, rearm for one tick until three callbacks.
  put(callback,string.pack('>I2I4I2I4I4I2I2I4I2I2I2I4I2',
   0x5279,data,0x23f9,0x16a,data+4,0x0c79,3,data,0x6408,0x33fc,1,task+10,0x4e75))
  program=program..string.pack('>I2I4I2I2I4',0x207c,task,0xa033,0x33c0,data+2)
 end
 -- Wait thirty guest ticks, without executing a game frame or changing its timers.
 program=program..string.pack('>I2I4I2I4I2I2I4I2',0x2c39,0x16a,0x2039,0x16a,0x9086,0x0c80,30,0x65f0)
 ending=base+#program;program=program..string.pack('>I2',0x4e71)
 put(base,program)
 startTick=mem:readv_u32(0x16a)
 probe=cpu.debug:bpset(ending,'1','logerror "TIMING_VBL_STOP\\n"')
 cpu.state.PC.value=base;dbg.execution_state='run'
end
function M.poll()
 if not ending or dbg.execution_state~='stop' or cpu.state.PC.value~=ending then return false end
 if removing then
  for i,count in ipairs(counts)do
   print(string.format('TIMING_VREMOVE initial=%04X error=%04X link=%08X',count,mem:readv_u16(base+3072+32*i+8),mem:readv_u32(base+2048+32*i)))
  end
  for i in ipairs(counts)do
   assert(mem:readv_u16(base+3072+32*i+8)==(i<=2 and 0xffff or 0),'VRemove result')
   assert(mem:readv_u32(base+2048+32*i)==links[i],'removed qLink changed')
  end
  print('TIMING_VBL_COMPLETE removal=1')
  cpu.debug:bpclear(probe);ending=nil;manager.machine:exit();dbg.execution_state='run';return true
 end
 local elapsed=(mem:readv_u32(0x16a)-startTick)&0xffffffff
 assert(elapsed>=30 and elapsed<120,'TIMING FIXTURE DURATION')
 for i,count in ipairs(counts)do
  local task=base+2048+32*i;local data=base+3072+32*i
  print(string.format('TIMING_VBL initial=%04X calls=%d error=%04X count=%04X link=%08X last=%08X',count,
   mem:readv_u16(data),mem:readv_u16(data+2),mem:readv_u16(task+10),mem:readv_u32(task),mem:readv_u32(data+4)))
  links[i]=mem:readv_u32(task)
  assert(links[i]==(i<4 and base+2048+32*(i+1) or 0),'automatic removal qLink')
  assert(mem:readv_u16(data+2)==0,'VInstall result')
  assert(mem:readv_u16(data)==(i<=2 and 3 or 0),'callback count')
  assert(mem:readv_u16(task+10)==(i<=2 and 0 or ((count-elapsed)&0xffff)),'countdown')
 end
 print('TIMING_VBL_OBSERVED elapsed='..elapsed)
 cpu.debug:bpclear(probe)
 local program=''
 for i in ipairs(counts)do
  program=program..string.pack('>I2I4I2I2I4',0x207c,base+2048+32*i,0xa034,0x33c0,base+3072+32*i+8)
 end
 local entry=base+128;ending=entry+#program
 put(entry,program..string.pack('>I2',0x4e71));removing=true
 probe=cpu.debug:bpset(ending,'1','logerror "TIMING_REMOVE_STOP\\n"')
 cpu.state.PC.value=entry;dbg.execution_state='run';return true
end
local armed=false
local ready=false
emu.register_frame_done(function()
 if armed or mem:readv_u32(0x28)~=0xdd60 then return end
 assert(mem:readv_u32(0xdd60)==0x2f0a2f02,'dispatcher bytes')
 local app='Alone In The Dark';local condition=string.format('b@910==0x%x',#app)
 for i=1,#app do condition=condition..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i))end
 cpu.debug:bpset(0xdd60,condition..' && w@(d@(sp+2))==0xa86e','')
 armed=true;dbg.execution_state='run'
end)
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if ending then M.poll();return end
  if not ready then
   local ret=(mem:readv_u32(cpu.state.SP.value+2)&0xffffff)+2
   dbg:command('bpclear');cpu.debug:bpset(ret,'1','');ready=true;dbg.execution_state='run'
  else dbg:command('bpclear');M.start() end
 end)
 if not ok then print('FAIL VBL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()assert(mac.launch());mac.wait(18000);error('no fixture completion')end)
 if not ok then print('FAIL VBL '..tostring(err));manager.machine:exit()end
end)
dbg.execution_state='run'

