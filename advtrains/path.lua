-- path.lua
-- Functions for pathpredicting, put in a separate file. 

function advtrains.conway(midreal, prev, drives_on)--in order prev,mid,return
	local mid=advtrains.round_vector_floor_y(midreal)
	
	local midnode_ok, midconns=advtrains.get_rail_info_at(mid, drives_on)
	if not midnode_ok then
		return nil 
	end
	local pconnid
	for connid, conn in ipairs(midconns) do
		local tps = advtrains.dirCoordSet(mid, conn.c)
		if tps.x==prev.x and tps.z==prev.z then
			pconnid=connid
		end
	end
	local nconnid = advtrains.get_matching_conn(pconnid, #midconns)
	
	local next, next_connid, _, nextrailheight = advtrains.get_adjacent_rail(mid, midconns, nconnid, drives_on)
	if not next then
		return nil
	end
	return vector.add(advtrains.round_vector_floor_y(next), {x=0, y=nextrailheight, z=0}), midconns[nconnid].c
end

function advtrains.pathpredict(id, train, gen_front, gen_back)
	
	local maxn=train.path_extent_max or 0
	while maxn < gen_front do--pregenerate
		local conway
		if train.max_index_on_track == maxn then
			--atprint("maxn conway for ",maxn,train.path[maxn],maxn-1,train.path[maxn-1])
			conway=advtrains.conway(train.path[maxn], train.path[maxn-1], train.drives_on)
		end
		if conway then
			train.path[maxn+1]=conway
			train.max_index_on_track=maxn+1
		else
			--do as if nothing has happened and preceed with path
			--but do not update max_index_on_track
			atprint("over-generating path max to index ",(maxn+1)," (position ",train.path[maxn]," )")
			train.path[maxn+1]=vector.add(train.path[maxn], vector.subtract(train.path[maxn], train.path[maxn-1]))
		end
		train.path_dist[maxn]=vector.distance(train.path[maxn+1], train.path[maxn])
		maxn=maxn+1
	end
	train.path_extent_max=maxn
	
	local minn=train.path_extent_min or -1
	while minn > gen_back do
		local conway
		if train.min_index_on_track == minn then
			--atprint("minn conway for ",minn,train.path[minn],minn+1,train.path[minn+1])
			conway=advtrains.conway(train.path[minn], train.path[minn+1], train.drives_on)
		end
		if conway then
			train.path[minn-1]=conway
			train.min_index_on_track=minn-1
		else
			--do as if nothing has happened and preceed with path
			--but do not update min_index_on_track
			atprint("over-generating path min to index ",(minn-1)," (position ",train.path[minn]," )")
			train.path[minn-1]=vector.add(train.path[minn], vector.subtract(train.path[minn], train.path[minn+1]))
		end
		train.path_dist[minn-1]=vector.distance(train.path[minn], train.path[minn-1])
		minn=minn-1
	end
	train.path_extent_min=minn
	if not train.min_index_on_track then train.min_index_on_track=-1 end
	if not train.max_index_on_track then train.max_index_on_track=0 end
end

-- Naming conventions:
-- 'index' - An index of the train.path table.
-- 'offset' - A value in meters that determines how far on the path to walk relative to a certain index
-- 'n' - Referring or pointing towards the 'next' path item, the one with index+1
-- 'p' - Referring or pointing towards the 'prev' path item, the one with index-1
-- 'f' - Referring to the positive end of the path (the end with the higher index)
-- 'b' - Referring to the negative end of the path (the end with the lower index)

-- New path structure of trains:
--Tables:
-- path      - path positions. 'indices' are relative to this. At the moment, at.round_vector_floor_y(path[i])
--              is the node this item corresponds to, however, this will change in the future.
-- path_node - (reserved)
-- path_cn   - Connid of the current node that points towards path[i+1]
-- path_cp   - Connid of the current node that points towards path[i-1]
--     When the day comes on that path!=node, these will only be set if this index represents a transition between rail nodes
-- path_dist - The distance (in meters) between this (path[i]) and the next (path[i+1]) item of the path
-- path_dir  - The direction of this path item's transition to the next path item, which is the angle of conns[path_cn[i]].c
--Variables:
-- path_ext_f/b - how far path[i] is set
-- path_trk_f/b - how far the path extends along a track. beyond those values, paths are generated in a straight line.
-- path_req_f/b - how far path items were requested in the last step

-- creates the path data structure, reconstructing the train from a position and a connid
-- Important! train.drives_on must exist while calling this method
-- returns: true - successful
--           nil - node not yet available/unloaded, please wait
--         false - node definitely gone, remove train
function advtrains.path_create(train, pos, connid, rel_index)
	local posr = advtrains.round_vector_floor_y(pos)
	local node_ok, conns, rhe = advtrains.get_rail_info_at(pos, train.drives_on)
	if not node_ok then
		return node_ok
	end
	local mconnid = advtrains.get_matching_conn(connid, #conns)
	train.index = rel_index
	train.path = { [0] = { x=posr.x, y=posr.y+rhe, z=posr.z } }
	train.path_cn = { [0] = connid }
	train.path_cp = { [0] = mconnid }
	train.path_dist = {}
	
	train.path_dir = {
		[0] = advtrains.conn_angle_median(conns[mconnid].c, conns[connid].c)
	}
	
	train.path_ext_f=0
	train.path_ext_b=0
	train.path_trk_f=0
	train.path_trk_b=0
	train.path_req_f=0
	train.path_req_b=0
	
	advtrains.occ.set_item(train.id, posr, 0)
	
end

-- Sets position and connid to properly restore after a crash, e.g. in order
-- to save the train or to invalidate its path
-- Assumes that the train is in clean state
-- if invert ist true, setrestore will use the end index
function advtrains.path_setrestore(train, invert)
	local idx = train.index
	if invert then
		idx = train.end_index
	end
	
	local pos, connid, frac = advtrains.path_getrestore(train, idx, invert)
	
	train.last_pos = pos
	train.last_connid = connid
	train.last_frac = frac
end
-- Get restore position, connid and frac (in this order) for a train that will originate at the passed index
-- If invert is set, it will return path_cp and multiply frac by -1, in order to reverse the train there.
function advtrains.path_getrestore(train, index, invert)
	local idx = train.index
	local cns = train.path_cn
	
	if invert then
		idx = train.end_index
		cns = train.path_cp
	end
	
	fli = atfloor(train.index)
	if fli > train.path_trk_f then
		fli = train.path_trk_f
	end
	if fli < train.path_trk_b then
		fli = train.path_trk_b
	end
	
	return advtrains.path_get(train, fli),
			cns[fli],
			(idx - fli) * (invert and -1 or 1)
end

-- Invalidates a path
-- this is supposed to clear stuff from the occupation tables
function advtrains.path_invalidate(train)
	if train.path then
		for i,p in pairs(train.path) do
			advtrains.occ.clear_item(train.id, advtrains.round_vector_floor_y(p))
		end
	end
	train.path = nil
	train.path_dist = nil
	train.path_cp = nil
	train.path_cn = nil
	train.path_dir = nil
	train.path_ext_f=0
	train.path_ext_b=0
	train.path_trk_f=0
	train.path_trk_b=0
	train.path_req_f=0
	train.path_req_b=0
end

-- Prints a path using the passed print function
-- This function should be 'atprint', 'atlog', 'atwarn' or 'atdebug', because it needs to use print_concat_table
function advtrains.path_print(train, printf)
	printf("i:	CP	Position	Dir	CN		->Dist->")
	for i = train.path_ext_b, train.path_ext_f do
		printf(i,":	",train.path_cp[i],"	",train.path[i],"	",train.path_dir[i],"	",train.path_cn[i],"		->",train.path_dist[i],"->")
	end
end

-- Function to get path entry at a position. This function will automatically calculate more of the path when required.
-- returns: pos, on_track
function advtrains.path_get(train, index)
	if not train.path then
		error("For train "..train.id..": path_get called but there's no path set yet!")
	end
	if index ~= atfloor(index) then
		error("For train "..train.id..": Called path_get() but index="..index.." is not a round number")
	end
	local pef = train.path_ext_f
	while index > pef do
		local pos = train.path[pef]
		local connid = train.path_cn[pef]
		local node_ok, this_conns, adj_pos, adj_connid, conn_idx, nextrail_y, next_conns
		if pef == train.path_trk_f then
			node_ok, this_conns = advtrains.get_rail_info_at(pos)
			if not node_ok then error("For train "..train.id..": Path item "..pef.." on-track but not a valid node!") end
			adj_pos, adj_connid, conn_idx, nextrail_y, next_conns = advtrains.get_adjacent_rail(pos, this_conns, connid, train.drives_on)
		end
		pef = pef + 1
		if adj_pos then
			advtrains.occ.set_item(train.id, adj_pos, pef)
		
			adj_pos.y = adj_pos.y + nextrail_y
			train.path_cp[pef] = adj_connid
			local mconnid = advtrains.get_matching_conn(adj_connid, #next_conns)
			train.path_cn[pef] = mconnid
			train.path_dir[pef] = advtrains.conn_angle_median(next_conns[adj_connid].c, next_conns[mconnid].c)
			train.path_trk_f = pef
		else
			-- off-track fallback behavior
			adj_pos = advtrains.pos_add_angle(pos, train.path_dir[pef-1])
			train.path_dir[pef] = train.path_dir[pef-1]
		end
		train.path[pef] = adj_pos
		train.path_dist[pef - 1] = vector.distance(pos, adj_pos)
	end
	train.path_ext_f = pef
	local peb = train.path_ext_b
	while index < peb do
		local pos = train.path[peb]
		local connid = train.path_cp[peb]
		local node_ok, this_conns, adj_pos, adj_connid, conn_idx, nextrail_y, next_conns
		if peb == train.path_trk_b then
			node_ok, this_conns = advtrains.get_rail_info_at(pos)
			if not node_ok then error("For train "..train.id..": Path item "..peb.." on-track but not a valid node!") end
			adj_pos, adj_connid, conn_idx, nextrail_y, next_conns = advtrains.get_adjacent_rail(pos, this_conns, connid, train.drives_on)
		end
		peb = peb - 1
		if adj_pos then
			advtrains.occ.set_item(train.id, adj_pos, peb)
			
			adj_pos.y = adj_pos.y + nextrail_y
			train.path_cn[peb] = adj_connid
			local mconnid = advtrains.get_matching_conn(adj_connid, #next_conns)
			train.path_cp[peb] = mconnid
			train.path_dir[peb] = advtrains.conn_angle_median(next_conns[mconnid].c, next_conns[adj_connid].c)
			train.path_trk_b = peb
		else
			-- off-track fallback behavior
			adj_pos = advtrains.pos_add_angle(pos, train.path_dir[peb+1] + math.pi)
			train.path_dir[peb] = train.path_dir[peb+1]
		end
		train.path[peb] = adj_pos
		train.path_dist[peb] = vector.distance(pos, adj_pos)
	end
	train.path_ext_b = peb
	
	if index < train.path_req_b then
		train.path_req_b = index
	end
	if index > train.path_req_f then
		train.path_req_f = index
	end
	
	return train.path[index], (index<=train.path_trk_f and index>=train.path_trk_b)
	
end

-- interpolated position to fractional index given, and angle based on path_dir
-- returns: pos, angle(yaw), p_floor, p_ceil
function advtrains.path_get_interpolated(train, index)
	local i_floor = atfloor(index)
	local i_ceil = i_floor + 1
	local frac = index - i_floor
	local p_floor = advtrains.path_get(train, i_floor)
	local p_ceil = advtrains.path_get(train, i_ceil)
	-- Note: minimal code duplication to path_get_adjacent, for performance
	
	local a_floor = train.path_dir[i_floor]
	local a_ceil = train.path_dir[i_ceil]
	
	local ang = advtrains.minAngleDiffRad(a_floor, a_ceil)
	
	return vector.add(p_floor, vector.multiply(vector.subtract(p_ceil, p_floor), frac)), (a_floor + frac * ang)%(2*math.pi), p_floor, p_ceil
end
-- returns the 2 path positions directly adjacent to index and the fraction on how to interpolate between them
-- returns: pos_floor, pos_ceil, fraction
function advtrains.path_get_adjacent(train, index)
	local i_floor = atfloor(index)
	local i_ceil = i_floor + 1
	local frac = index - i_floor
	local p_floor = advtrains.path_get(train, i_floor)
	local p_ceil = advtrains.path_get(train, i_ceil)
	return p_floor, p_ceil, frac
end

function advtrains.path_get_index_by_offset(train, index, offset)
	local off = offset
	local idx = atfloor(index)
	-- go down to floor. Calculate required path_dist
	advtrains.path_get_adjacent(train, idx)
	off = off + ((index-idx) * train.path_dist[idx])
	--atdebug("pibo: 1 off=",off,"idx=",idx,"  index=",index)
	
	-- then walk the path back until we overshoot (off becomes >=0)
	while off<0 do
		idx = idx - 1
		advtrains.path_get_adjacent(train, idx)
		off = off + train.path_dist[idx]
	end
	--atdebug("pibo: 2 off=",off,"idx=",idx)
	-- then walk the path forward until we would overshoot
	while off - train.path_dist[idx] >= 0 do
		idx = idx - 1
		advtrains.path_get_adjacent(train, idx)
		if not train.path_dist[idx] then
			atdebug("second while",idx)
			for i=-5,5 do
				atdebug(idx+i,train.path_dist[idx+i])
			end
		end
		off = off - train.path_dist[idx]
	end
	--atdebug("pibo: 3 off=",off,"idx=",idx," returns:",idx + (off / train.path_dist[idx]))
	-- we should now be on the floor of the index we actually want.
	-- give them the rest!
	
	return idx + (off / train.path_dist[idx])
end

local PATH_CLEAR_KEEP = 4

function advtrains.path_clear_unused(train)
	local i
	for i = train.path_ext_b, train.path_req_b - PATH_CLEAR_KEEP do
		advtrains.occ.clear_item(train.id, advtrains.round_vector_floor_y(train.path[i]))
		train.path[i] = nil
		train.path_dist[i-1] = nil
		train.path_cp[i] = nil
		train.path_cn[i] = nil
		train.path_dir[i] = nil
		train.path_ext_b = i + 1
	end
	
	for i = train.path_ext_f,train.path_req_f + PATH_CLEAR_KEEP,-1 do
		advtrains.occ.clear_item(train.id, advtrains.round_vector_floor_y(train.path[i]))
		train.path[i] = nil
		train.path_dist[i] = nil
		train.path_cp[i] = nil
		train.path_cn[i] = nil
		train.path_dir[i+1] = nil
		train.path_ext_b = i - 1
	end
	
	train.path_req_f = math.ceil(train.index)
	train.path_req_b = math.floor(train.end_index or train.index)
end

function advtrains.path_lookup(train, pos)
	local cp = advtrains.round_vector_floor_y(pos)
	for i = train.path_ext_b, train.path_ext_f do
		if vector.equals(advtrains.round_vector_floor_y(train.path[i]), cp) then
			return i
		end
	end
	return nil
end
