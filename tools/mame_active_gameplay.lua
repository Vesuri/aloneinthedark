-- Conservative read-only first-floor activity timing; no game state is written.
return function(mac,mem,label)
 local world,actor
 local result={}
 local held={};local oldDown,oldUp=mac.key_down,mac.key_up
 function mac.key_down(name)held[name]=true;oldDown(name)end
 function mac.key_up(name)held[name]=nil;oldUp(name)end
 local ticks,moving,turning,attacking,samples=0,0,0,0,0
 local previousTick,previousKind,previousRoom;local rooms={}
 local nextReport=600
 emu.register_frame_done(function()
  if not world then return end
  local now=mem:read_u32(0x16a)
  local room=mem:read_i16(actor+0x30)
  local animation=mem:read_i16(actor+0x3e)
  local manual=mem:read_i16(actor)==1 and mem:read_i16(actor+2)==12 and
   mem:read_i16(actor+0x2e)==1 and mem:read_i16(actor+0x52)==1 and
   mem:read_i16(world-0xd864)==1
  local kind
  if manual then
   if (animation==254 or animation==256) and (held['Up Arrow'] or held['Down Arrow']) then kind='move'
   elseif (animation==257 or animation==258) and (held['Left Arrow'] or held['Right Arrow']) then kind='turn'
   elseif animation==262 and held['Space'] and held['Up Arrow'] then kind='kick' end
  end
  if kind and previousKind==kind and previousRoom==room and previousTick then
   local delta=now-previousTick
   -- Drop gaps, state changes, idle animation and all key-release waits.
   if delta>0 and delta<=2 then
    ticks=ticks+delta;samples=samples+1;rooms[room]=true
    if kind=='move' then moving=moving+delta elseif kind=='turn' then turning=turning+delta else attacking=attacking+delta end
    if ticks>=nextReport then
     print(string.format('ACTIVE_GAMEPLAY route=%s ticks=%d move=%d turn=%d kick=%d samples=%d',label,ticks,moving,turning,attacking,samples))
     nextReport=nextReport+600
    end
   end
  end
  previousTick,previousKind,previousRoom=now,kind,room
 end)
 function result.start(w,a)world,actor=w,a end
 function result.active_ticks()return ticks end
 function result.finish()
  local visited={};for room in pairs(rooms)do visited[#visited+1]=room end;table.sort(visited)
  print(string.format('ACTIVE_GAMEPLAY_FINAL route=%s ticks=%d move=%d turn=%d kick=%d samples=%d rooms=%s',label,ticks,moving,turning,attacking,samples,table.concat(visited,',')))
  return ticks
 end
 return result
end
