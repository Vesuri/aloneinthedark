-- Capture original NewRgn bytes, allocation and owning-zone contract.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'NEWRGN / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('NEWRGN / NO JUMP ENTRY')
end
local app='Alone In The Dark';local cond=string.format('b@910==0x%x',#app)
for i=1,#app do cond=cond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'NEWRGN / DISPATCHER BYTES')
 local entered='temp0=sp+8;temp6='..base(10)..';logerror "RGN_ENTER sp=%X result=%X zone=%X memerr=%X'..regs..'\\n",temp0,d@temp0,d@0x118,w@0x220'..values..';'
 local fmt,ops='',''
 for off=0x1d9c,0x1da8,2 do fmt=fmt..'%04X';ops=ops..string.format(',w@(temp6+0x%x)',off) end
 entered=entered..'logerror "RGN_BYTES data='..fmt..'\\n"'..ops..';'
 local returned='temp9=d@sp&0xffffff;temp8=d@temp9&0xffffff;logerror "RGN_RETURN sp=%X handle=%X body=%X zone=%X memerr=%X'..regs..'\\n",sp,temp9,temp8,d@0x118,w@0x220'..values..';save tmp/newrgn-reference.bin,temp8,0xa;logerror "PASS original NewRgn\\n";'
 -- Query the returned handle with CPU-executed Memory Manager calls.
 returned=returned..'sp=sp-0x400;temp4=sp+0x100;w@temp4=0xa025;w@(temp4+2)=0xa069;w@(temp4+4)=0xa126;w@(temp4+6)=0x4e71;a0=temp9;pc=temp4;'
 returned=returned..'bpset temp4+2,1,{logerror "RGN_SIZE size=%X memerr=%X\\n",d0,w@0x220;g};'
 returned=returned..'bpset temp4+4,1,{logerror "RGN_FLAGS flags=%X memerr=%X\\n",d0&ff,w@0x220;g};'
 returned=returned..'bpset temp4+6,1,{logerror "RGN_OWNER owner=%X zone=%X memerr=%X\\n",a0,d@0x118,w@0x220;logerror "PASS NewRgn ownership queries\\n";quit};g'
 entered=entered..'bpset temp6+0x1da8,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==0xa8d8 && (d@(sp+2)&0xffffff)=='..base(10)..'+0x1da6',entered)
 armed=true
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'NEWRGN / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'NEWRGN / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('NEWRGN / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
