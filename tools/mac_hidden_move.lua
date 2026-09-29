-- Observe original hidden DLOG 1000 MoveWindow. No instruction, argument or state patches.
local mac=dofile('tools/mame_mac_input.lua')
local meta=dofile('tmp/mac-trap-map.lua')
local cpu=manager.machine.devices[':maincpu'];local mem=cpu.spaces.program
local dbg=assert(manager.machine.debugger,'DIALOG / DEBUGGER REQUIRED')
local function base(seg)
 for i,j in ipairs(meta.jt) do if j[1]==seg then return string.format('((d@((d@904&ffffff)+0x%x)&ffffff)-0x%x)',36+(i-1)*8,j[2]) end end
 error('DIALOG / NO JUMP ENTRY')
end
local app='Alone In The Dark';local appcond=string.format('b@910==0x%x',#app)
for i=1,#app do appcond=appcond..string.format(' && b@0x%x==0x%x',0x910+i,app:byte(i)) end
local regs,values='',''
for _,r in ipairs({'d0','d1','d2','d3','d4','d5','d6','d7','a0','a1','a2','a3','a4','a5','a6'}) do regs=regs..' '..r..'=%08X';values=values..','..r end
local function dump(label,address,count)
 local format,args='',''
 for i=0,count-1 do format=format..'%08X';args=args..string.format(',d@((%s)+0x%x)',address,i*4) end
 return 'logerror "'..label..' seq=%X data='..format..'\\n",temp8'..args..';'
end
local armed=false
local consoleSeen=0
emu.register_frame_done(function()
 -- Retain console errors: malformed debugger actions otherwise look like hangs.
 for i=consoleSeen+1,#dbg.consolelog do
  local line=tostring(dbg.consolelog[i])
  if line:find('unknown command') or line:find('Error') then print('FAIL dialog debugger: '..line);manager.machine:exit() end
 end
 consoleSeen=#dbg.consolelog
 if armed or mem:read_u32(0x28)~=0xdd60 then return end
 assert(mem:read_u32(0xdd60)==0x2f0a2f02 and mem:read_u32(0xdd64)==0x246f000a,'DIALOG / DISPATCHER BYTES')
 dbg:command('temp8=0;temp9=0')
 local function state(prefix)
  local out=dump(prefix..'_RECORD','temp3',43)..dump(prefix..'_ITEMS','d@(d@(temp3+9c)&ffffff)&ffffff',29)
  for name,offset in pairs({VIS=0x18,CLIP=0x1c,STRUCT=0x72,CONTENT=0x76,UPDATE=0x7a}) do
   out=out..dump(prefix..'_'..name,string.format('d@(d@(temp3+0x%x)&ffffff)&ffffff',offset),3)
  end
  out=out..dump(prefix..'_CONTROL1','d@(d@((d@(d@(temp3+9c)&ffffff)&ffffff)+2)&ffffff)&ffffff',13)..dump(prefix..'_CONTROL2','d@(d@((d@(d@(temp3+9c)&ffffff)&ffffff)+1a)&ffffff)&ffffff',13)..dump(prefix..'_TEXT3','d@(d@((d@(d@(temp3+9c)&ffffff)&ffffff)+32)&ffffff)&ffffff',13)
  return out
 end
 local entered='temp8=1;temp0=sp+8;temp6='..base(7)..';temp7=d@(temp6+3f94)&ffffff;temp3=d@(sp+e)&ffffff;logerror "MOVE_ENTER sp=%X args=%04X%04X%04X%08X qdPort=%X windows=%X'..regs..'\\n",temp0,w@(sp+8),w@(sp+a),w@(sp+c),d@(sp+e),d@temp7,d@9d6'..values..';'..state('MOVE_BEFORE')
 local returned='logerror "MOVE_RETURN sp=%X qdPort=%X windows=%X'..regs..'\\n",sp,d@temp7,d@9d6'..values..';'..state('MOVE_AFTER')..'logerror "PASS original hidden MoveWindow\\n";quit'
 entered=entered..'bpset temp6+48a4,1,{'..returned..'};g'
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a91b && (d@(sp+2)&ffffff)=='..base(7)..'+48a2',entered)
 cpu.debug:bpset(0xdd60,appcond..' && w@(d@(sp+2))==a97c && (d@(sp+2)&ffffff)=='..base(13)..'+341c','bpset '..base(13)..'+341e,1,{temp9=d@sp&ffffff;logerror "MOVE_CONSTRUCTOR_EDIT dialog=%X fields=%08X\\n",temp9,d@(temp9+0xa4);wpset temp9+0xa4,4,w,1,{logerror "MOVE_EDIT_WRITE pc=%X fields=%08X\\n",pc,d@(temp9+0xa4);g};g};g')
 armed=true;print('ARM dialog dispatcher bytes=2f0a2f02246f000a')
end)
mac.run(function()
 local ok,err=pcall(function()
  assert(mac.launch(),'DIALOG / LAUNCH');mac.wait(300)
  assert(mac.mouse_to(256,274),'DIALOG / SIZE POINTER');mac.click(1)
  mac.wait(3600);error('DIALOG / NO COMPLETION')
 end)
 if not ok then print('FAIL '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
