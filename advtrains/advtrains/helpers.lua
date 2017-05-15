--advtrains by orwell96, see readme.txt

advtrains.dir_trans_tbl={
	[0]={x=0, z=1},
	[1]={x=1, z=2},
	[2]={x=1, z=1},
	[3]={x=2, z=1},
	[4]={x=1, z=0},
	[5]={x=2, z=-1},
	[6]={x=1, z=-1},
	[7]={x=1, z=-2},
	[8]={x=0, z=-1},
	[9]={x=-1, z=-2},
	[10]={x=-1, z=-1},
	[11]={x=-2, z=-1},
	[12]={x=-1, z=0},
	[13]={x=-2, z=1},
	[14]={x=-1, z=1},
	[15]={x=-1, z=2},
}

function advtrains.dirCoordSet(coord, dir)
	local x,z
	if advtrains.dir_trans_tbl[dir] then
		x,z=advtrains.dir_trans_tbl[dir].x, advtrains.dir_trans_tbl[dir].z
	else
		error("advtrains: in helpers.lua/dirCoordSet() given dir="..(dir or "nil"))
	end
	return {x=coord.x+x, y=coord.y, z=coord.z+z}
end
function advtrains.dirToCoord(dir)
	return advtrains.dirCoordSet({x=0, y=0, z=0}, dir)
end

function advtrains.maxN(list, expectstart)
	local n=expectstart or 0
	while list[n] do
		n=n+1
	end
	return n-1
end

function advtrains.minN(list, expectstart)
	local n=expectstart or 0
	while list[n] do
		n=n-1
	end
	return n+1
end

--vertical_transmit:
--[[
rely1, rely2 tell to which height the connections are pointed to. 1 means it will go up the next node

]]

function advtrains.conway(midreal, prev, drives_on)--in order prev,mid,return
	local mid=advtrains.round_vector_floor_y(midreal)
	
	local midnode_ok, middir1, middir2, midrely1, midrely2=advtrains.get_rail_info_at(mid, drives_on)
	if not midnode_ok then
		return nil 
	end
	
	local next, chkdir, chkrely, y_offset
	y_offset=0
	--atprint(" in order mid1,mid2",middir1,middir2)
	--try if it is dir1
	local cor1=advtrains.dirCoordSet(mid, middir2)--<<<<
	if cor1.x==prev.x and cor1.z==prev.z then--this was previous
		next=advtrains.dirCoordSet(mid, middir1)
		if midrely1>=1 then
			next.y=next.y+1
			--atprint("found midrely1 to be >=1: next is now "..(next and minetest.pos_to_string(next) or "nil"))
			y_offset=1
		end
		chkdir=middir1
		chkrely=midrely1
		--atprint("dir2 applied next pos:",minetest.pos_to_string(next),"(chkdir is ",chkdir,")")
	end
	--dir2???
	local cor2=advtrains.dirCoordSet(mid, middir1)--<<<<
	if math.floor(cor2.x+0.5)==math.floor(prev.x+0.5) and math.floor(cor2.z+0.5)==math.floor(prev.z+0.5) then
		next=advtrains.dirCoordSet(mid, middir2)--dir2 wird überprüft, alles gut.
		if midrely2>=1 then
			next.y=next.y+1
			--atprint("found midrely2 to be >=1: next is now "..(next and minetest.pos_to_string(next) or "nil"))
			y_offset=1
		end
		chkdir=middir2
		chkrely=midrely2
		--atprint(" dir2 applied next pos:",minetest.pos_to_string(next),"(chkdir is ",chkdir,")")
	end
	--atprint("dir applied next pos: "..(next and minetest.pos_to_string(next) or "nil").."(chkdir is "..(chkdir or "nil")..", y-offset "..y_offset..")")
	--is there a next
	if not next then
		--atprint("in conway: no next rail(nil), returning!")
		return nil
	end
	
	local nextnode_ok, nextdir1, nextdir2, nextrely1, nextrely2, nextrailheight=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(next), drives_on)
	
	--is it a rail?
	if(not nextnode_ok) then
		--atprint("in conway: next "..minetest.pos_to_string(next).." not a rail, trying one node below!")
		next.y=next.y-1
		y_offset=y_offset-1
		
		nextnode_ok, nextdir1, nextdir2, nextrely1, nextrely2, nextrailheight=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(next), drives_on)
		if(not nextnode_ok) then
			--atprint("in conway: one below "..minetest.pos_to_string(next).." is not a rail either, returning!")
			return nil
		end
	end
	
	--is this next rail connecting to the mid?
	if not ( (((nextdir1+8)%16)==chkdir and nextrely1==chkrely-y_offset) or (((nextdir2+8)%16)==chkdir and nextrely2==chkrely-y_offset) ) then
		--atprint("in conway: next "..minetest.pos_to_string(next).." not connecting, trying one node below!")
		next.y=next.y-1
		y_offset=y_offset-1
		
		nextnode_ok, nextdir1, nextdir2, nextrely1, nextrely2, nextrailheight=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(next), drives_on)
		if(not nextnode_ok) then
			--atprint("in conway: (at connecting if check again) one below "..minetest.pos_to_string(next).." is not a rail either, returning!")
			return nil
		end
		if not ( (((nextdir1+8)%16)==chkdir and nextrely1==chkrely) or (((nextdir2+8)%16)==chkdir and nextrely2==chkrely) ) then
			--atprint("in conway: one below "..minetest.pos_to_string(next).." rail not connecting, returning!")
			--atprint(" in order mid1,2,next1,2,chkdir "..middir1.." "..middir2.." "..nextdir1.." "..nextdir2.." "..chkdir)
			return nil
		end
	end
	
	--atprint("conway found rail.")
	return vector.add(advtrains.round_vector_floor_y(next), {x=0, y=nextrailheight, z=0}), chkdir
end
--TODO use this
function advtrains.oppd(dir)
	return ((dir+8)%16)
end

function advtrains.round_vector_floor_y(vec)
	return {x=math.floor(vec.x+0.5), y=math.floor(vec.y), z=math.floor(vec.z+0.5)}
end

function advtrains.yawToDirection(yaw, conn1, conn2)
	if not conn1 or not conn2 then
		error("given nil to yawToDirection: conn1="..(conn1 or "nil").." conn2="..(conn1 or "nil"))
	end
	local yaw1=math.pi*(conn1/4)
	local yaw2=math.pi*(conn2/4)
	if advtrains.minAngleDiffRad(yaw, yaw1)<advtrains.minAngleDiffRad(yaw, yaw2) then--change to > if weird behavior
		return conn2
	else
		return conn1
	end
end

function advtrains.minAngleDiffRad(r1, r2)
	local try1=r2-r1
	local try2=(r2+2*math.pi)-r1
	local try3=r2-(r1+2*math.pi)
	if math.min(math.abs(try1), math.abs(try2), math.abs(try3))==math.abs(try1) then
		return try1
	end
	if math.min(math.abs(try1), math.abs(try2), math.abs(try3))==math.abs(try2) then
		return try2
	end
	if math.min(math.abs(try1), math.abs(try2), math.abs(try3))==math.abs(try3) then
		return try3
	end
end

function advtrains.dumppath(path)
	atlog("Dumping a path:")
	if not path then atlog("dumppath: no path(nil)") return end
	local temp_path={}
	for ipt, iit in pairs(path) do 
		temp_path[#temp_path+1]={i=ipt, p=iit}
	end
	table.sort(temp_path, function (k1, k2) return k1.i < k2.i end)
	for _,pit in ipairs(temp_path) do
		atlog(pit.i.." > "..minetest.pos_to_string(pit.p))
	end
end

function advtrains.merge_tables(a, ...)
	local new={}
	for _,t in ipairs({a,...}) do
		for k,v in pairs(t) do new[k]=v end
	end
	return new
end
function advtrains.yaw_from_3_positions(prev, curr, next)
	local pts=minetest.pos_to_string
	--atprint("p3 "..pts(prev)..pts(curr)..pts(next))
	local prev2curr=math.atan2((curr.x-prev.x), (prev.z-curr.z))
	local curr2next=math.atan2((next.x-curr.x), (curr.z-next.z))
	--atprint("y3 "..(prev2curr*360/(2*math.pi)).." "..(curr2next*360/(2*math.pi)))
	return prev2curr+(advtrains.minAngleDiffRad(prev2curr, curr2next)/2)
end
function advtrains.get_wagon_yaw(front, first, second, back, pct)
	local pts=minetest.pos_to_string
	--atprint("p "..pts(front)..pts(first)..pts(second)..pts(back))
	local y2=advtrains.yaw_from_3_positions(second, first, front)
	local y1=advtrains.yaw_from_3_positions(back, second, first)
	--atprint("y "..(y1*360/(2*math.pi)).." "..(y2*360/(2*math.pi)))
	return y1+advtrains.minAngleDiffRad(y1, y2)*pct
end
function advtrains.get_real_index_position(path, index)
	if not path or not index then return end
	
	local first_pos=path[math.floor(index)]
	local second_pos=path[math.floor(index)+1]
	
	if not first_pos or not second_pos then return nil end
	
	local factor=index-math.floor(index)
	local actual_pos={x=first_pos.x-(first_pos.x-second_pos.x)*factor, y=first_pos.y-(first_pos.y-second_pos.y)*factor, z=first_pos.z-(first_pos.z-second_pos.z)*factor,}
	return actual_pos
end
function advtrains.pos_median(pos1, pos2)
	return {x=pos1.x-(pos1.x-pos2.x)*0.5, y=pos1.y-(pos1.y-pos2.y)*0.5, z=pos1.z-(pos1.z-pos2.z)*0.5}
end
function advtrains.abs_ceil(i)
	return math.ceil(math.abs(i))*math.sign(i)
end

function advtrains.serialize_inventory(inv)
	local ser={}
	local liszts=inv:get_lists()
	for lisztname, liszt in pairs(liszts) do
		ser[lisztname]={}
		for idx, item in ipairs(liszt) do
			local istring=item:to_string()
			if istring~="" then
				ser[lisztname][idx]=istring
			end
		end
	end
	return minetest.serialize(ser)
end
function advtrains.deserialize_inventory(sers, inv)
	local ser=minetest.deserialize(sers)
	if ser then
		inv:set_lists(ser)
		return true
	end
	return false
end

--is_protected wrapper that checks for protection_bypass privilege
function advtrains.is_protected(pos, name)
	if not name then
		error("advtrains.is_protected() called without name parameter!")
	end
	if minetest.check_player_privs(name, {protection_bypass=true}) then
		--player can bypass protection
		return false
	end
	return minetest.is_protected(pos, name)
end
