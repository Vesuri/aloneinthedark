-- Observe the original hidden background-window title update.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'SETWTITLE / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('SETWTITLE / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end

local widths='a3=temp4+0x1000;'
for c=32,126 do
 local off=0x500+(c-32)*10
 for i,w in ipairs({0x558f,0x3f3c,c,0xa88d,0x36df}) do
  widths=widths..string.format('w@(temp4+0x%x)=0x%x;',off+(i-1)*2,w)
 end
end
widths=widths..'save tmp/title-reference-width-program.bin,temp4+0x500,0x3b6;logerror "TITLE_WIDTH_INPUT sp=%X output=%X font=%X face=%X size=%X\\n",sp,a3,w@(d@temp7+0x44),b@(d@temp7+0x46),w@(d@temp7+0x4a);pc=temp4+0x500;bpset temp4+0x8b6,1,{logerror "TITLE_WIDTH_DONE sp=%X output=%X\\n",sp,a3;save tmp/title-reference-ascii-widths.bin,temp4+0x1000,0xbe;logerror "PASS title system-font widths\\n";quit};g'

local armed=false
local function state(phase)
 local out='temp5=d@(temp1+0x86)&0xffffff;logerror "TITLE_STATE phase='..phase..' window=%X titleHandle=%X titleBody=%X length=%X visible=%X width=%X\\n",temp1,temp5,d@temp5&0xffffff,b@(d@temp5&0xffffff),b@(temp1+0x6e),w@(temp1+0x8a);'
 out=out..'save tmp/title-reference-'..phase..'-window.bin,temp1,0x9c;save tmp/title-reference-'..phase..'-title.bin,d@temp5&0xffffff,b@(d@temp5&0xffffff)+1;'
 for name,offset in pairs({vis=0x18,clip=0x1c,structure=0x72,content=0x76,update=0x7a}) do
  out=out..string.format('save tmp/title-reference-%s-%s.bin,d@(d@(temp1+0x%x)&0xffffff)&0xffffff,0xa;',phase,name,offset)
 end
 out=out..'save tmp/title-reference-'..phase..'-wmgr.bin,d@0x9de&0xffffff,0x6c;logerror "TITLE_PORT phase='..phase..' current=%X wmgr=%X\\n",d@temp7,d@0x9de;'
 return out
end
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'SETWTITLE / DISPATCHER BYTES')
 dbg:command('temp8=0')
 cpu.debug:bpset(0xdd60,'temp8==1 && (w@(d@(sp+2))==0xa88c || w@(d@(sp+2))==0xa886)','logerror "TITLE_WIDTH_CALL trap=%X font=%X face=%X size=%X string=%X\\n",w@(d@(sp+2)),w@(d@temp7+0x44),b@(d@temp7+0x46),w@(d@temp7+0x4a),d@(sp+8);g')
 local entered='temp8=1;temp7=d@('..base(7)..'+0x3f94)&0xffffff;temp0=sp+8;temp1=d@(temp0+4)&0xffffff;temp2=d@temp0&0xffffff;temp6='..base(9)..';logerror "TITLE_ENTER sp=%X string=%X window=%X'..regs..'\\n",temp0,temp2,temp1'..values..';save tmp/title-reference-input.bin,temp2,b@temp2+1;'
 entered=entered..'logerror "TITLE_BYTES data=%04X%04X%04X%04X%04X%04X\\n",w@(temp6+0x128c),w@(temp6+0x128e),w@(temp6+0x1290),w@(temp6+0x1292),w@(temp6+0x1294),w@(temp6+0x1296);'..state('before')
 local returned='logerror "TITLE_RETURN sp=%X'..regs..'\\n",sp'..values..';'..state('after')..'save tmp/title-reference-input-after.bin,temp2,b@temp2+1;temp8=0;sp=sp-0x2000;temp4=sp;w@(temp4+0x400)=0xa025;w@(temp4+0x402)=0x60fe;a0=temp5;pc=temp4+0x400;bpset temp4+0x402,1,{logerror "TITLE_SIZE size=%X mem=%X\\n",d0,w@0x220;logerror "PASS original SetWTitle capture\\n";'..widths..'};g'
 entered=entered..'bpset temp6+0x1298,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==0xa91a && (d@(sp+2)&0xffffff)=='..base(9)..'+0x1296',entered)
 armed=true;print('ARM title dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'SETWTITLE / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'SETWTITLE / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('SETWTITLE / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
