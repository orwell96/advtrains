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
advtrains.pos_add_dir = advtrains.dirCoordSet

function advtrains.dirToCoord(dir)
	return advtrains.dirCoordSet({x=0, y=0, z=0}, dir)
end
advtrains.dir_to_vector = advtrains.dirToCoord

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

function atround(number)
	return math.floor(number+0.5)
end
atfloor = math.floor


function advtrains.round_vector_floor_y(vec)
	return {x=math.floor(vec.x+0.5), y=math.floor(vec.y), z=math.floor(vec.z+0.5)}
end

function advtrains.yawToDirection(yaw, conn1, conn2)
	if not conn1 or not conn2 then
		error("given nil to yawToDirection: conn1="..(conn1 or "nil").." conn2="..(conn1 or "nil"))
	end
	local yaw1 = advtrains.dir_to_angle(conn1)
	local yaw2 = advtrains.dir_to_angle(conn2)
	local adiff1 = advtrains.minAngleDiffRad(yaw, yaw1)
	local adiff2 = advtrains.minAngleDiffRad(yaw, yaw2)
	
	if math.abs(adiff2)<math.abs(adiff1) then
		return conn2
	else
		return conn1
	end
end

function advtrains.yawToAnyDir(yaw)
	local min_conn, min_diff=0, 10
	for conn, vec in pairs(advtrains.dir_trans_tbl) do
		local yaw1 = advtrains.dir_to_angle(conn)
		local diff = advtrains.minAngleDiffRad(yaw, yaw1)
		if diff < min_diff then
			min_conn = conn
			min_diff = diff
		end
	end
	return min_conn
end
function advtrains.yawToClosestConn(yaw, conns)
	local min_connid, min_diff=1, 10
	for connid, conn in ipairs(conns) do
		local yaw1 = advtrains.dir_to_angle(conn.c)
		local diff = advtrains.minAngleDiffRad(yaw, yaw1)
		if diff < min_diff then
			min_connid = connid
			min_diff = diff
		end
	end
	return min_connid
end

function advtrains.dir_to_angle(dir)
	local uvec = vector.normalize(advtrains.dirToCoord())
	local yaw1 = math.atan2(uvec.z, -uvec.x)
end


function advtrains.minAngleDiffRad(r1, r2)
	local pi, pi2 = math.pi, 2*math.pi
	while r1>pi2 do
		r1=r1-pi2
	end
	while r1<0 do
		r1=r1+pi2
	end
	while r2>pi2 do
		r2=r2-pi2
	end
	while r1<0 do
		r2=r2+pi2
	end
	local try1=r2-r1
	local try2=r2+pi2-r1
	local try3=r2-pi2-r1
	
	local minabs = math.min(math.abs(try1), math.abs(try2), math.abs(try3))
	if minabs==math.abs(try1) then
		return try1
	end
	if minabs==math.abs(try2) then
		return try2
	end
	if minabs==math.abs(try3) then
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
function advtrains.save_keys(tbl, keys)
	local new={}
	for _,key in ipairs(keys) do
		new[key] = tbl[key]
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

function advtrains.ms_to_kmh(speed)
	return speed * 3.6
end

-- 4 possible inputs:
-- integer: just do that modulo calculation
-- table with c set: rotate c
-- table with tables: rotate each
-- table with integers: rotate each (probably no use case)
function advtrains.rotate_conn_by(conn, rotate)
	if tonumber(conn) then
		return (conn+rotate)%AT_CMAX
	elseif conn.c then
		return { c = (conn.c+rotate)%AT_CMAX, y = conn.y}
	end
	local tmp={}
	for connid, data in ipairs(conn) do
		tmp[connid]=advtrains.rotate_conn_by(data, rotate)
	end
	return tmp
end

--TODO use this
function advtrains.oppd(dir)
	return advtrains.rotate_conn_by(dir, AT_CMAX/2)
end
--conn_to_match like rotate_conn_by
--other_conns have to be a table of conn tables!
function advtrains.conn_matches_to(conn, other_conns)
	if tonumber(conn) then
		for connid, data in ipairs(other_conns) do
			if advtrains.oppd(conn) == data.c then return connid end
		end
		return false
	elseif conn.c then
		for connid, data in ipairs(other_conns) do
			local cmp = advtrains.oppd(conn)
			if cmp.c == data.c and (cmp.y or 0) == (data.y or 0) then return connid end
		end
		return false
	end
	local tmp={}
	for connid, data in ipairs(conn) do
		local backmatch = advtrains.conn_matches_to(data, other_conns)
		if backmatch then return backmatch, connid end --returns <connid of other rail> <connid of this rail>
	end
	return false
end


-- returns: <adjacent pos>, <conn index of adjacent>, <my conn index>, <railheight of adjacent>
function advtrains.get_adjacent_rail(this_posnr, this_conns_p, conn_idx, drives_on)
	local this_pos = advtrains.round_vector_floor_y(this_posnr)
	local this_conns = this_conns_p
	if not this_conns then
		_, this_conns = advtrains.get_rail_info_at(this_pos)
	end
	if not conn_idx then
		for coni, _ in ipairs(this_conns) do
			local adj_pos, adj_conn_idx, _, nry = advtrains.get_adjacent_rail(this_pos, this_conns, coni)
			if adj_pos then return adj_pos,adj_conn_idx,coni,nry end
		end
		return nil
	end
	
	local conn = this_conns[conn_idx]
	local conn_y = conn.y or 0
	local adj_pos = advtrains.dirCoordSet(this_pos, conn.c);
	
	while conn_y>=1 do
		conn_y = conn_y - 1
		adj_pos.y = adj_pos.y + 1
	end
	
	local nextnode_ok, nextconns, nextrail_y=advtrains.get_rail_info_at(adj_pos, drives_on)
	if not nextnode_ok then
		adj_pos.y = adj_pos.y - 1
		conn_y = conn_y + 1
		nextnode_ok, nextconns, nextrail_y=advtrains.get_rail_info_at(adj_pos, drives_on)
		if not nextnode_ok then
			return nil
		end
	end
	local adj_connid = advtrains.conn_matches_to({c=conn.c, y=conn_y}, nextconns)
	if adj_connid then
		return adj_pos, adj_connid, conn_idx, nextrail_y
	end
	return nil
end

local connlku={[2]={2,1}, [3]={2,1,1}, [4]={2,1,4,3}}
function advtrains.get_matching_conn(conn, nconns)
	return connlku[nconns][conn]
end

function advtrains.random_id()
	local idst=""
	for i=0,5 do
		idst=idst..(math.random(0,9))
	end
	return idst
end

