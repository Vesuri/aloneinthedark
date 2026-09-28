-- AitD 1.0 / System 7.5.5 trap logger. Requires -debug -debugger none -oslog.
-- The reference replaces the ROM Line-A dispatcher with RAM at $DD60.
-- Read taps miss that execution; use a byte-checked execution breakpoint.
-- Actions log through MAME's debugger without stopping or changing game state.
local mac = dofile('tools/mame_mac_input.lua')
local meta = dofile('tmp/mac-trap-map.lua')
local cpu = manager.machine.devices[':maincpu']
local mem = cpu.spaces.program
local dbg = assert(manager.machine.debugger, 'TRAP LOG / DEBUGGER REQUIRED')
local appname='Alone In The Dark'
local guard={string.format('b@910==%x',#appname)}
for i=1,#appname do guard[#guard+1]=string.format('b@%x==%x',0x910+i,appname:byte(i)) end
local appcond=table.concat(guard,' && ')
local function u32(a) return mem:read_u32(a & 0xffffff) end
local function ptr(a) return u32(a) & 0xffffff end
local known, return_bps, armed = {}, {}, false
local function is_file_trap(trap)
 local code=trap & 0x08ff
 return code<=0x18 or code==0x44 or code==0x60
end
local function file_fields(args)
 -- Preserve the raw 80-byte parameter block: selectors reuse field offsets.
 for i=0,19 do args[#args+1]={'pb'..i,string.format('d@((a0&ffffff)+%x)',4*i)} end
 return args
end
local function action(label, expressions)
 local fmt, args = label, ''
 for _, pair in ipairs(expressions) do
  fmt=fmt..' '..pair[1]..'=%08X'; args=args..','..pair[2]
 end
 return 'logerror "'..fmt..'\\n"'..args..';g'
end
local function breakpoint(addr,label,expressions,condition)
 return cpu.debug:bpset(addr,condition or appcond,action(label,expressions))
end
local function map_segments()
 local a5=ptr(0x904)
 if a5<0x100000 or a5-ptr(0x908)~=75616 then return end
 -- CurApName changes before Finder relinquishes its A5 world. Verify JT0's
 -- CODE 1 startup bytes as well, rather than assigning Finder code to the game.
 if mem:read_u16(a5+32)~=1 or mem:read_u16(a5+34)~=0x4ef9
  or u32(ptr(a5+36))~=0x42780a4a then return end
 local found={}
 for index,j in ipairs(meta.jt) do
  local e=a5+32+(index-1)*8
  if mem:read_u16(e+2)==0x4ef9 and mem:read_u16(e)==j[1] then
   local target=ptr(e+4)
   local base=target-j[2]
   if base>0x100000 and mem:read_u16(target)==j[3] then
    found[base]=j[1]
   end
  end
 end
 for base,seg in pairs(found) do
  local key=string.format('%x:%d',base,seg)
  if not known[key] then
   known[key]=true
   local info=meta.segments[seg]
   print(string.format('MAP frame=%d a5=%08X seg=%d name=%s base=%08X size=%d',mac.frames(),a5,seg,info.name,base,info.size))
   for _,offset in ipairs(info.driver_calls) do
    local pc=base+offset
    assert(u32(pc-4)==0x206df954 and mem:read_u16(pc)==0x4e90,'MDRV / CALL BYTES')
    local args={{'ticks','d@16a'},{'caller','pc'},{'cleanup','w@(pc+2)'},{'selector','d@sp'},{'arg','d@(sp+4)'},
     {'arg0','d@(d@(sp+4)&ffffff)'},{'arg1','d@((d@(sp+4)&ffffff)+4)'},{'arg2','d@((d@(sp+4)&ffffff)+8)'}}
    for i=0,7 do args[#args+1]={'sample'..i,string.format('if(d@sp==11,d@((d@(d@(sp+4)&ffffff)&ffffff)+%x),0)',4*i)} end
    breakpoint(pc,string.format('MDRV seg=%X offset=%X',seg,offset),args)
   end
   for _,site in ipairs(info.input_writes) do
    assert(mem:read_u16(base+site[1])==site[3],'INPUT PROBE / ORIGINAL WRITE BYTES')
    cpu.debug:bpset(base+site[2],appcond..string.format(' && temp3==%x && w@((d@904&ffffff)-temp3)==temp1',site[4]),'temp0=temp0+1;g')
   end
   for _,t in ipairs(info.traps) do
    local pc=base+t[1]
    -- Byte-check every original site; loaded relocation never changes trap words.
    if mem:read_u16(pc)==t[2] and (t[2]&0x0c00)~=0x0c00 and not return_bps[pc+2] then
     local result={{'pc','pc'},{'sp','sp'},{'d0','d0'},{'a0','a0'},{'r0','d@sp'},{'r1','d@(sp+4)'},{'r2','d@(sp+8)'},{'env0','if(w@(pc-2)==a090,d@a0,0)'},{'env1','if(w@(pc-2)==a090,d@(a0+4),0)'},{'env2','if(w@(pc-2)==a090,d@(a0+8),0)'},{'env3','if(w@(pc-2)==a090,d@(a0+c),0)'}}
     if is_file_trap(t[2]) then file_fields(result) end
     return_bps[pc+2]=breakpoint(pc+2,string.format('RESULT seg=%d offset=%04X trap=%04X',seg,t[1],t[2]),result)
    end
   end
  end
 end

end
emu.register_frame_done(function()
 if not armed and u32(0x28)==0xdd60 then
  assert(u32(0xdd60)==0x2f0a2f02 and u32(0xdd64)==0x246f000a,'TRAP LOG / DISPATCHER BYTES')
  local expr={{'ticks','d@16a'},{'pc','d@(sp+2)'},{'sp','sp'},{'d0','d0'},{'d1','d1'},{'a0','a0'},{'a1','a1'},{'a5','a5'},{'trap','w@(d@(sp+2))'}}
  -- Zone+12 is zcbFree, the FreeMem value. Include it in the existing
  -- dispatcher action: MAME runs only the first matching breakpoint there.
  for _,field in ipairs({{'zone','d@118'},{'appzone','d@2aa'},
   {'applimit','d@130'},{'free','d@((d@118&ffffff)+c)'},
   {'limit','d@(d@118&ffffff)'},{'masters','w@((d@118&ffffff)+14)'},
   {'memerr','w@220'},{'master','if(a0>100000 && a0<800000,d@a0,0)'}}) do
   expr[#expr+1]=field
  end
  local first={}
  for index,j in ipairs(meta.jt) do
   if not first[j[1]] then
    first[j[1]]=true
    local e=32+(index-1)*8
    expr[#expr+1]={'j'..j[1],string.format('if(w@((d@904&ffffff)+%x)==4ef9,d@((d@904&ffffff)+%x),0)',e+2,e+4)}
   end
  end
  for i=0,7 do expr[#expr+1]={'p'..i,string.format('d@(sp+%x)',8+4*i)} end
  local trapword='w@(d@(sp+2))'
  local base=appcond..' && (d@(sp+2)&ffffff)>100000 && (d@(sp+2)&ffffff)<800000'
  local excluded=' && '..trapword..'!=a884 && '..trapword..'!=a885 && '..trapword..'!=a900 && ('..trapword..'&8ff)>18 && ('..trapword..'&8ff)!=44 && ('..trapword..'&8ff)!=60'
  breakpoint(0xdd60,'TRAP',expr,base..excluded)
  local function detail(label,args,condition)
   local both=action('TRAP',expr):gsub(';g$',';')..action(label,args)
   cpu.debug:bpset(0xdd60,appcond..' && '..condition,both)
  end
  -- DrawText's Pascal stack: count:w, first:w, buffer:l.
  local text={{'font','w@((d@(d@(d@904)&ffffff)&ffffff)+44)'},{'size','w@((d@(d@(d@904)&ffffff)&ffffff)+4a)'},{'pc','d@(sp+2)'},{'count','w@(sp+8)'},{'first','w@(sp+a)'}}
  for i=0,15 do text[#text+1]={'text'..i,string.format('d@((d@(sp+c)&ffffff)+w@(sp+a)+%x)',4*i)} end
  detail('TEXT',text,trapword..'==a885')
  local stringtext={{'font','w@((d@(d@(d@904)&ffffff)&ffffff)+44)'},
   {'size','w@((d@(d@(d@904)&ffffff)&ffffff)+4a)'},
   {'pc','d@(sp+2)'},{'count','b@(d@(sp+8)&ffffff)'}}
  for i=0,15 do stringtext[#stringtext+1]={'text'..i,string.format('d@((d@(sp+8)&ffffff)+%x)',1+4*i)} end
  detail('TEXT',stringtext,trapword..'==a884')
  local font={{'pc','d@(sp+2)'},{'resultptr','d@(sp+8)'}}
  for i=0,7 do font[#font+1]={'name'..i,string.format('d@((d@(sp+c)&ffffff)+%x)',4*i)} end
  detail('FONT',font,trapword..'==a900')
  local file={{'pc','d@(sp+2)'},{'trap','w@(d@(sp+2))'},{'selector','d0'},{'pb','a0'},
   {'ref','w@(a0+18)'},{'buffer','d@(a0+20)'},{'requested','d@(a0+24)'},
   {'actual','d@(a0+28)'},{'position','d@(a0+2e)'}}
  for i=0,11 do file[#file+1]={'name'..i,string.format('d@((d@(a0+12)&ffffff)+%x)',4*i)} end
  detail('FILE',file_fields(file),'(('..trapword..'&8ff)<=18 || ('..trapword..'&8ff)==44 || ('..trapword..'&8ff)==60)')
  armed=true
  print('ARM dispatcher=0000DD60 bytes=2f0a2f02246f000a')
 end
 if mac.frontmost()=='Alone In The Dark' then map_segments() end
end)

mac.run(function()
 local ok,err=pcall(function()
 assert(mac.launch(),'TRAP LOG / LAUNCH FAILED')
 assert(armed and next(known),'TRAP LOG / NO VERIFIED GAME MAP')
 local scenario=os.getenv('AITD_MAC_SCENARIO') or 'tools/mac_trap_session.lua'
 assert(loadfile(scenario))()(mac,mem)
 end)
 if not ok then print('FAIL mac-trap-session '..tostring(err));manager.machine:exit() end
end)
dbg.execution_state='run'
