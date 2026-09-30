-- Original Dan2 DetachResource, then CPU-only owned-handle/error fixtures.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DETACHED / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('DETACHED / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function save(path,a,n)
 local f=assert(io.open(path,'wb'));for i=0,n-1 do f:write(string.char(mem:read_u8(a+i))) end;f:close()
end
local steps={{'repeat',0xa992},{'lock',0xa029},{'locked',0xa992},{'unlock',0xa02a},{'empty',0xa02b},{'empty-detach',0xa992},{'nil',0xa992}}
local armed=false;local done=false;local phase='entry';local index=0;local args;local ret;local handle;local scratch;local stack
local function log(which)
 local tail='';for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end
 print(string.format('DET_%s label=%s sp=%X handle=%X master=%X res=%X mem=%X',which,index==0 and 'original' or steps[index][1],which=='ENTER' and args or cpu.state.A7.value,handle,mem:read_u32(handle),mem:read_u16(0xa60),mem:read_u16(0x220))..tail)
end
local function next_step()
 index=index+1
 if index>#steps then done=true;print('PASS original detached resource and seven fixtures');dbg:command('quit');return end
 local label,trap=table.unpack(steps[index])
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,trap);mem:write_u16(scratch+4,0x4e71)
 cpu.state.A7.value=stack;cpu.state.D0.value=0x12345678
 mem:write_u16(0xa60,0x8888);mem:write_u16(0x220,0x7777)
 if trap==0xa992 then mem:write_u32(stack,label=='nil' and 0 or handle) else cpu.state.A0.value=handle end
 cpu.state.PC.value=scratch;ret=scratch+4;phase='fixture-entry'
 cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DETACHED / DISPATCHER BYTES')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa992 && (d@(sp+2)&0xffffff)=='..base(13)..'+0x210','')
 armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' or phase=='fixture-entry' then
   if phase=='entry' then
    assert(cpu.state.PC.value==0xdd60,'DETACHED / ENTRY')
    args=cpu.state.A7.value+8;ret=(mem:read_u32(cpu.state.A7.value+2)&0xffffff)+2
    handle=mem:read_u32(args)&0xffffff
    print('DET_BYTES data='..bytes(ret-4,20))
    save('tmp/detached-reference-before.bin',mem:read_u32(handle)&0xffffff,2056)
   else args=stack end
   log('ENTER');phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'DETACHED / RETURN');log('RETURN');dbg:command('bpclear')
   if index==0 then
    save('tmp/detached-reference-after.bin',mem:read_u32(handle)&0xffffff,2056)
    scratch=(cpu.state.A7.value-1024)&0xfffffc;stack=scratch+128
   end
   next_step()
  end
 end)
 if not ok then done=true;print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DETACHED / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DETACHED / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DETACHED / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
