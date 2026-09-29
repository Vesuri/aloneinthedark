-- Observe the original driver before native replacement; no game-state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DRIVER STARTUP / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('DRIVER STARTUP / NO JUMP ENTRY')
end
local names={'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}
local registerFormat,registerValues='',''
for _,name in ipairs(names) do registerFormat=registerFormat..' '..name..'=%08X';registerValues=registerValues..','..name end
local app='Alone In The Dark';local condition=string.format('b@910==0x%x',#app)
for i=1,#app do condition=condition..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
condition=condition..' && w@(d@(sp+2))==a900 && (d@(sp+2)&ffffff)=='..base(12)..'+12'
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DRIVER STARTUP / DISPATCHER BYTES')
 dbg:command('temp8=0')
 local returned='logerror "DRIVER_RETURN count=%X selector=%X sp=%X expected=%X voices=%04X/%04X/%04X quality=%02X rate=%04X/%04X error=%04X'..registerFormat..'\\n",temp8,temp2,sp,temp0,w@(temp7+53c0),w@(temp7+53c2),w@(temp7+53c4),b@(temp7+4230),w@(temp7+4260),w@(temp7+4268),w@(temp7+4208)'..registerValues..';g'
 local entered='temp0=sp;temp1=pc+2;temp2=d@sp;temp3=d@(sp+4);temp8=temp8+1;logerror "DRIVER_CALL count=%X caller=%X cleanup=%04X selector=%X arg=%X packet0=%08X packet1=%04X sp=%X'..registerFormat..'\\n",temp8,temp1-temp5,w@temp1,temp2,temp3,if(temp2==15,d@temp3,0),if(temp2==15,w@(temp3+4),0),sp'..registerValues..';bpset temp1,sp==temp0,{'..returned..'};g'
 local installed='temp7=d@((d@904&ffffff)-6ac)&ffffff;logerror "DRIVER_INSTALLED entry=%X raw=%08X bytes=%08X/%08X/%08X store=%08X\\n",temp7,d@((d@904&ffffff)-6ac),d@temp7,d@(temp7+4),d@(temp7+8),d@(temp5+1cf4);save tmp/m2-driver-original.bin,temp7,7248;bpset temp5+1d46,1,{'..entered..'};bpset temp5+1d60,1,{'..entered..'};g'
 local action='temp5='..base(3)..';temp6='..base(12)..';logerror "DRIVER_ARM init=%08X quality=%08X font=%08X\\n",d@(temp5+1d46),d@(temp5+1d60),d@(temp6+38);bpset temp5+1cf8,1,{'..installed..'};bpset temp6+3a,temp8!=2,{logerror "FAIL driver startup missing calls\\n";quit};bpset temp6+3a,temp8==2,{logerror "PASS driver startup reference: second Times=%X calls=%X\\n",w@((d@904&ffffff)-1261c),temp8;quit};g'
 cpu.debug:bpset(0xdd60,condition,action)
 armed=true;print('ARM driver startup dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DRIVER STARTUP / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DRIVER STARTUP / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DRIVER STARTUP / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
