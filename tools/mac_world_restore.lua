-- Original SetGWorld binding of the later startup drawing window. No game patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'WORLD BIND / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('WORLD BIND / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function state(phase)
 local out='logerror "WB_STATE phase='..phase..' port=%X main=%X device=%X\\n",d@temp7&0xffffff,d@0x8a4&0xffffff,d@0xcc8&0xffffff;'
 for _,r in ipairs({{'window','temp2',156},{'pm','d@(d@(temp2+2)&0xffffff)&0xffffff',50},{'device','d@temp4&0xffffff',62}}) do
  out=out..string.format('save tmp/worldrestore-reference-%s-%s.bin,%s,0x%x;',phase,r[1],r[2],r[3])
 end
 return out
end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'WORLD BIND / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp1=d@temp0&0xffffff;temp2=d@(temp0+4)&0xffffff;temp4=d@0x8a4&0xffffff;temp6='..base(9)..';temp7=d@('..base(7)..'+0x3f94)&0xffffff;'
 entered=entered..'logerror "WB_ENTER sp=%X device=%X window=%X'..regs..'\\n",temp0,temp1,temp2'..values..';'..state('before')
 local fmt,args='',''
 for x=0xdfe,0xe0a,2 do fmt=fmt..'%04X';args=args..string.format(',w@(temp6+0x%x)',x) end
 entered=entered..'logerror "WB_BYTES data='..fmt..'\\n"'..args..';'
 local returned='logerror "WB_RETURN sp=%X'..regs..'\\n",sp'..values..';'..state('after')
 entered=entered..'bpset temp6+0xe0c,1,{'..returned..'}'
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xab1d && (d@(sp+2)&0xffffff)=='..base(9)..'+0xe0a',entered)
 armed=true
end)
local stage=0
emu.register_periodic(function()
 if not armed or dbg.execution_state~='stop' or stage>=2 then return end
 local phase=stage==0 and 'before' or 'after'
 local f=assert(io.open('tmp/worldrestore-reference-'..phase..'-pixels.bin','wb'))
 for y=0,479 do
  local row={};for x=0,639 do row[#row+1]=string.char(mem:read_u8(0xf9000a00+y*640+x)) end
  f:write(table.concat(row))
 end
 f:close();stage=stage+1
 if stage==2 then print('PASS original world binding');dbg:command('quit') else dbg.execution_state='run' end
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'WORLD BIND / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'WORLD BIND / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('WORLD BIND / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
