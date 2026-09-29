-- Capture original SetPt arguments, point bytes and register/stack effects.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SETPT / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SETPT / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SETPT / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(4)..';temp9=d@(temp0+4)&0xffffff;logerror "POINT_ENTER sp=%X point=%X args=%08X%08X value=%08X'..regs..'\\n",temp0,temp9,d@temp0,d@(temp0+4),d@temp9'..values..';save tmp/point-reference-before.bin,temp9-4,0xc;'
 local fmt,ops='',''
 for off=0x4f7a,0x4f88,2 do fmt=fmt..'%04X';ops=ops..string.format(',w@(temp6+0x%x)',off) end
 entered=entered..'logerror "POINT_BYTES data='..fmt..'\\n"'..ops..';'
 local returned='logerror "POINT_RETURN sp=%X value=%08X'..regs..'\\n",sp,d@temp9'..values..';save tmp/point-reference-after.bin,temp9-4,0xc;logerror "PASS original SetPt\\n";quit'
 entered=entered..'bpset temp6+0x4f8a,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa880 && (d@(sp+2)&0xffffff)=='..base(4)..'+0x4f88',entered)
 armed=true
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SETPT / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SETPT / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SETPT / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
