-- Original Misc1 SectRect call, followed by isolated rectangle/alias fixtures.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SECTRECT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SECTRECT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs={'D0','D1','D2','D3','D4','D5','D6','D7','A0','A1','A2','A3','A4','A5','A6'}
local function bytes(a,n)
 local out={};for i=0,n-1 do out[#out+1]=string.format('%02X',mem:read_u8(a+i)) end;return table.concat(out)
end
local function ptr(a) return mem:read_u32(a)&0xffffff end
local count=0;local phase='entry';local args;local inputs;local ret;local armed=false
local fixtures={
 {{1,2,10,20},{3,4,30,40},0},
 {{-10,-20,0,0},{-30,-40,-15,-5},0},
 {{0,0,0,0},{2,3,4,5},0},
 {{2,3,4,5},{0,0,0,0},0},
 {{20,30,20,30},{2,3,4,5},0},
 {{20,30,10,15},{2,3,4,5},0},
 {{20,30,10,15},{40,50,30,45},0},
 {{-32768,-32768,32767,32767},{0,0,1,1},0},
 {{1,2,10,20},{3,4,30,40},1},
 {{1,2,10,20},{3,4,30,40},2},
 {{7,8,7,9},{4,3,4,3},0},
 {{0,0,10,10},{10,0,20,10},0},
 {{0,0,10,10},{0,10,10,20},0},
 {{0,0,10,10},{0,0,10,10},0},
}
local fixture=0;local scratch;local stack;local done=false
local function log(which)
 local tail=''
 if which=='RETURN' then tail=' returnsp='..string.format('%X',cpu.state.A7.value) end
 for _,r in ipairs(regs) do tail=tail..string.format(' %s=%08X',r:lower(),cpu.state[r].value) end
 print(string.format('SR_%s n=%d fixture=%d sp=%X dst=%X r1=%X r2=%X data1=%s data2=%s dest=%s result=%04X',which,count,fixture,args,inputs[1],inputs[3],inputs[2],bytes(inputs[3],8),bytes(inputs[2],8),bytes(inputs[1],8),mem:read_u16(args+12))..tail)
end

local function next_fixture()
 fixture=fixture+1
 if fixture>#fixtures then done=true;print('PASS original SectRect calls=2 fixtures=14');dbg:command('quit');return end
 local f=fixtures[fixture]
 mem:write_u16(scratch,0x4e71);mem:write_u16(scratch+2,0xa8aa);mem:write_u16(scratch+4,0x4e71)
 local r1=scratch+32;local r2=scratch+48;local dest=scratch+64
 for i=1,4 do mem:write_u16(r1+(i-1)*2,f[1][i]&0xffff);mem:write_u16(r2+(i-1)*2,f[2][i]&0xffff) end
 if f[3]==1 then dest=r1 elseif f[3]==2 then dest=r2 end
 if f[3]==0 then for i=0,7 do mem:write_u8(dest+i,0xcc) end end
 mem:write_u32(stack,dest);mem:write_u32(stack+4,r2);mem:write_u32(stack+8,r1);mem:write_u16(stack+12,0xccdd)
 cpu.state.A7.value=stack;cpu.state.D0.value=0x12345678;cpu.state.D1.value=0x89abcdef;cpu.state.PC.value=scratch
 ret=scratch+4;phase='fixture-entry';cpu.debug:bpset(scratch+2,'1','');dbg.execution_state='run'
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SECTRECT / DISPATCHER BYTES')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8aa && (d@(sp+2)&0xffffff)=='..base(9)..'+0xe90','')
 armed=true
end)
emu.register_periodic(function()
 if done or not armed or dbg.execution_state~='stop' then return end
 local ok,err=pcall(function()
  if phase=='entry' or phase=='fixture-entry' then
   if phase=='entry' then
    assert(cpu.state.PC.value==0xdd60,'SECTRECT / DISPATCH ENTRY')
    count=count+1;args=cpu.state.A7.value+8;ret=ptr(cpu.state.A7.value+2)+2
    assert(mem:read_u16(ret-2)==0xa8aa,'SECTRECT / ORIGINAL TRAP')
    if count==1 then print('SR_BYTES data='..bytes(ret-0x12,0x12)) end
   else args=stack end
   inputs={ptr(args),ptr(args+4),ptr(args+8)};log('ENTER')
   phase='return';cpu.debug:bpset(ret,'1','');dbg.execution_state='run'
  else
   assert(cpu.state.PC.value==ret,'SECTRECT / RETURN')
   log('RETURN');dbg:command('bpclear')
   if count<2 then
    phase='entry';cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8aa && (d@(sp+2)&0xffffff)=='..base(9)..'+0xe90','');dbg.execution_state='run'
   else
    if fixture==0 then scratch=(cpu.state.A7.value-16384)&0xfffffc;stack=scratch+8192 end
    next_fixture()
   end
  end
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SECTRECT / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SECTRECT / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SECTRECT / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
