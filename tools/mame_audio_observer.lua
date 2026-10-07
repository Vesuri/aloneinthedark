-- Read-only original MDRV entry observer. Does not redirect calls or alter RAM/registers.
-- The owning ordinary-input route supplies its own success/failure endpoint.
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local entry,world;local sequence=0;local effects=0;local counts={}
local function ptr(a)return mem:read_u32(a)&0xffffff end
emu.register_frame_done(function()
 if entry then return end
 local app='Alone In The Dark'
 if mem:read_u8(0x910)~=#app then return end
 for i=1,#app do if mem:read_u8(0x910+i)~=app:byte(i)then return end end
 local a5=ptr(0x904);if a5<0x100000 or a5>=0x800000 then return end
 local candidate=ptr(a5-0x6ac)
 if candidate<0x100000 or candidate>0x7f0000 then return end
 if mem:read_u32(candidate)~=0x202f0004 or mem:read_u32(candidate+4)~=0x222f0008 then return end
 entry=candidate;world=a5
 cpu.debug:bpset(entry,'1','');cpu.debug:bpset(entry|0x80000000,'1','')
 print(string.format('AUDIO_OBSERVER entry=%X a5=%X entryBytes=202F0004222F0008',entry,world))
end)
emu.register_periodic(function()
 if not entry or dbg.execution_state~='stop' or (cpu.state.PC.value&0xffffff)~=entry then return end
 local ok,err=pcall(function()
  local sp=cpu.state.A7.value;local selector=mem:read_u32(sp+4);local argument=mem:read_u32(sp+8)
  assert(selector<=25,'AUDIO / DRIVER SELECTOR')
  sequence=sequence+1;counts[selector]=(counts[selector]or 0)+1
  print(string.format('AUDIO_CALL seq=%u tick=%u selector=%u argument=%X return=%X room=%d camera=%d',sequence,mem:read_u32(0x16a),selector,argument,mem:read_u32(sp),mem:read_i16(world-0xcd68),mem:read_i16(world-0xcd70)))
  if selector==17 then
   local packet=argument&0xffffff;assert(packet>0 and packet<=0x800000-26,'AUDIO / PACKET')
   local sample=ptr(packet);local size=mem:read_u32(packet+4);local hash=2166136261
   assert(sample==0 or (size>0 and size<0x800000 and sample+size<=0x800000),'AUDIO / PCM EXTENT')
   if sample~=0 then for i=0,size-1 do hash=((hash~mem:read_u8(sample+i))*16777619)&0xffffffff end end
   effects=effects+1
   local folder=os.getenv('AITD_CIRCUIT_DIR')
   if folder then
    local f=assert(io.open(folder..'/audio-effect-'..effects..'-actors.bin','wb'))
    for i=0,50*160-1 do f:write(string.char(mem:read_u8(world-0xb292+i)))end
    f:close()
   end
   print(string.format('AUDIO_EFFECT seq=%u event=%u id=%X bytes=%u rate=%X loop=%u/%u pcm=%08X',sequence,effects,mem:read_u16(packet+24),size,mem:read_u32(packet+8),mem:read_u32(packet+12),mem:read_u32(packet+16),hash))
  end
  dbg.execution_state='run'
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit()end
end)
