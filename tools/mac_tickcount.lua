-- Original TickCount ABI, followed by a scratch full-word fixture.
-- The fixture changes only scratch code/stack and restores the reference clock.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'TICKCOUNT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('TICKCOUNT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'TICKCOUNT / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(4)..';logerror "TICK_ENTER sp=%X result=%X ticks=%X bytes=%04X%04X%04X%04X%04X%04X'..regs..'\\n",temp0,d@temp0,d@0x16a,w@(temp6+0x41ec),w@(temp6+0x41ee),w@(temp6+0x41f0),w@(temp6+0x41f2),w@(temp6+0x41f4),w@(temp6+0x41f6)'..values..';'
 local returned='logerror "TICK_RETURN sp=%X result=%X ticks=%X'..regs..'\\n",sp,d@sp,d@0x16a'..values..';logerror "PASS original TickCount\\n";temp2=d@0x16a;sp=sp-0x400;temp4=sp+0x100;w@temp4=0x42a7;w@(temp4+2)=0xa975;w@(temp4+4)=0x4e71;d1=0xdeadbeef;d@0x16a=0xfedcba98;pc=temp4;bpset temp4+4,1,{logerror "TICK_FIXTURE sp=%X result=%X ticks=%X d1=%X a1=%X\\n",sp,d@sp,d@0x16a,d1,a1;d@0x16a=temp2;logerror "PASS TickCount full-word fixture\\n";quit};g'
 entered=entered..'bpset temp6+0x41f6,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa975 && (d@(sp+2)&0xffffff)=='..base(4)..'+0x41f4',entered)
 armed=true
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'TICKCOUNT / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'TICKCOUNT / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('TICKCOUNT / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
