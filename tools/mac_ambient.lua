-- Isolated ambient selection: only QuickDraw seed and game accumulator RAM change.
-- Original random wrapper, life interpreter, archive loading and MDRV execute.
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local folder=assert(os.getenv('AITD_CIRCUIT_DIR'))
local choice=assert(tonumber(os.getenv('AITD_AMBIENT_CASE')))
assert(choice>=0 and choice<=2 and choice%1==0,'AMBIENT / CASE')
local lengths={27115,21157,10806}
local function ptr(a)return mem:read_u32(a)&0xffffff end
local function bytes(a,n)local t={};for i=0,n-1 do t[#t+1]=string.format('%02X',mem:read_u8(a+i))end;return table.concat(t)end
local function save(name,a,n)local f=assert(io.open(folder..'/'..name..'.bin','wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i)))end;f:close()end
local function base(seg)
 for i,j in ipairs(meta.jt)do if j[1]==seg then local at=ptr(0x904)+32+(i-1)*8;if mem:read_u16(at+2)==0x4ef9 then return ptr(at+4)-j[2]end end end
end
local world,entry,state,thePort,armed,selected,rngReturn,callSP,callReturn,slot,startTick,done
local phase='wait'
local function capture(label)
 local tail='';for _,r in ipairs({'SR','D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'})do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value)end
 print(string.format('AMBIENT_%s tick=%u sp=%X selector=%u argument=%X',label,mem:read_u32(0x16a),cpu.state.A7.value,mem:read_u32(callSP+4),mem:read_u32(callSP+8))..tail)
 save(label:lower()..'-state',state,0x3048)
end
emu.register_frame_done(function()
 if not armed and mem:read_u32(0x28)==0xdd60 then
  assert(bytes(0xdd60,8)=='2F0A2F02246F000A','AMBIENT / TRAP DISPATCHER')
  cpu.debug:bpset(0xdd60,'w@(d@(sp+2))==0xa861 || w@(d@(sp+2))==0xa86e','');armed=true
 end
 if entry then return end
 local w=ptr(0x904);if w<0x100000 or w>=0x800000 then return end
 local p=ptr(w-0x6ac)
 if p<0x100000 or p>0x7f0000 or bytes(p,12)~='202F0004222F000848E73FFE' then return end
 world=w;entry=p;state=entry+0x4200
 cpu.debug:bpset(entry,'d@(sp+4)==0x11','');cpu.debug:bpset(entry|0x80000000,'d@(sp+4)==0x11','')
 save('driver',entry,0x7248)
end)
emu.register_periodic(function()
 if done then return end
 local ok,err=pcall(function()
  if phase=='playing' and mem:read_u16(state+0x24d2+slot*4)==0xffff then
   save('complete-state',state,0x3048)
   print(string.format('AMBIENT_COMPLETE case=%u slot=%u elapsed=%u',choice,slot,mem:read_u32(0x16a)-startTick))
   done=true;print('PASS original isolated ambient playback');dbg:command('quit');return
  end
  if dbg.execution_state~='stop' then return end
  local pc=cpu.state.PC.value&0xffffff
  if pc==0xdd60 then
   local sp=cpu.state.A7.value;local call=ptr(sp+2);local trap=mem:read_u16(call)
   if trap==0xa86e and base(7) then thePort=ptr(sp+8)end
   local engine,dark=base(7),base(5)
   if trap==0xa861 and engine and dark and call==engine+0x4a32 and ptr(cpu.state.A6.value+4)==dark+0x25f6 and world and mem:read_u16(ptr(world-0xb29c))==300 then
    assert(thePort and bytes(engine+0x4a30,8)=='4267A861301FB179','AMBIENT / RANDOM WRAPPER')
    assert(ptr(engine+0x4a38)==world-0x1078,'AMBIENT / ACCUMULATOR')
    assert(mem:read_i16(world-0xb292+160)==1,'AMBIENT / HERO')
    local target=selected and 299 or choice
    mem:write_u32(thePort-126,1);mem:write_u16(world-0x1078,16807~target)
    if not selected then
     selected=true;rngReturn=engine+0x4a44;cpu.debug:bpset(rngReturn,'1','')
     print(string.format('AMBIENT_SEED case=%u caller=%X bound=300 seed=1 mixed=%u',choice,dark+0x25f6,16807~target))
    end
   end
  elseif rngReturn and pc==rngReturn then
   assert(mem:read_u16(world-0x1078)==choice,'AMBIENT / ORIGINAL RANDOM RESULT')
   print(string.format('AMBIENT_SELECTED result=%u nextSeed=%u',mem:read_u16(world-0x1078),mem:read_u32(thePort-126)));rngReturn=nil
  elseif entry and pc==entry and phase=='wait' and selected then
   local sp=cpu.state.A7.value;local packet=ptr(sp+8)
   if mem:read_u32(packet+4)==lengths[choice+1] then
    callSP=sp;callReturn=ptr(sp);startTick=mem:read_u32(0x16a)
    save('packet',packet,26);save('source',ptr(packet),mem:read_u32(packet+4));save('actors',world-0xb292,8000)
    capture('ENTER');cpu.debug:bpset(callReturn,'1','');phase='return'
   end
  elseif callReturn and pc==callReturn and phase=='return' then
   assert(cpu.state.A7.value==callSP+4,'AMBIENT / RETURN STACK');capture('RETURN')
   slot=mem:read_u16(state+0x24d2+6*4)~=0xffff and 6 or 7
   assert(mem:read_u16(state+0x24d2+slot*4)~=0xffff,'AMBIENT / ACTIVE EFFECT')
   print(string.format('AMBIENT_PLAYING slot=%u cursor=%X age=%u',slot,mem:read_u32(state+0x22d2+slot*4),mem:read_u16(state+0x24d2+slot*4)))
   phase='playing'
  end
  dbg.execution_state='run'
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit()end
end)
dofile('tools/mac_firstfloor_circuit.lua')
