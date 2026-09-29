-- Original D4 selection reference. Optional controlled input changes only PREF size.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger)
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+%x)&ffffff)-%x)',36+(i-1)*8,j[2]) end end
 error('missing segment')
end
local app='Alone In The Dark';local cond=string.format('b@910==%x',#app)
for i=1,#app do cond=cond..string.format(' && b@%x==%x',0x910+i,app:byte(i)) end
local fixture=os.getenv('AITD_SIZE_INPUT')
assert(not fixture or fixture=='0' or fixture=='1','invalid size fixture')
local input=fixture and ('b@(temp1+b)='..fixture..';') or ''
local armed=false
emu.register_frame_done(function()
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a)
 local a='temp0='..base(3)..';bpset temp0+502,1,{temp1=d@(d@(a5-11b54));'..input..'logerror "CHOICE_PREF before=%08X%08X%04X\\n",d@(temp1+4),d@(temp1+8),w@(temp1+c);g};bpset temp0+514,1,{logerror "CHOICE_RESULT d0=%X pref=%X\\n",d0,b@(temp1+b);g};bpset temp0+53a,1,{logerror "CHOICE_PREF after=%08X%08X%04X\\n",d@(temp1+4),d@(temp1+8),w@(temp1+c);g};g'
 cpu.debug:bpset(0xdd60,cond..' && (d@(sp+2)&ffffff)=='..base(3)..'+500',a)
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==a97c','logerror "CHOICE_DIALOG id=%X\\n",w@(sp+10);g')
 cpu.debug:bpset(0xdd60,cond..' && (d@(sp+2)&ffffff)=='..base(13)..'+30fe','temp2=d@(sp+8);temp3='..base(13)..';bpset temp3+3100,1,{logerror "CHOICE_ITEM item=%X\\n",w@temp2;g};g')
 cpu.debug:bpset(0xdd60,cond..' && w@(d@(sp+2))==aa46 && (d@(sp+2)&ffffff)=='..base(9)..'+109a','logerror "CHOICE_WINDOW id=%X opcode=%X\\n",w@(sp+10),w@(d@(sp+2));logerror "PASS original screen choice\\n";quit')
 armed=true;print('SIZE_INPUT fixture='..(fixture or 'existing'))
end)
mac.run(function()
 assert(mac.launch());mac.wait(300);assert(mac.mouse_to(256,274));mac.click(1)
 mac.wait(3600);print('FAIL no choice completion');manager.machine:exit()
end)
dbg.execution_state='run'
