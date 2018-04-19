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
		[ 0] = conns[connid],
		[-1] = conns[mconnid]
	}
	
	train.path_ext_f=0
	train.path_ext_b=0
	train.path_trk_f=0
	train.path_trk_b=0
	train.path_req_f=0
	train.path_req_b=0
	
end

-- Function to get path entry at a position. This function will automatically calculate more of the path when required.
-- returns: pos, on_track
function advtrains.path_get(train, index)
	if index ~= atfloor(index) then
		error("For train "..train.id..": Called path_get() but index="..index.." is not a round number")
	end
	while index > train.path_ext_f do
		local pos = train.path[train.path_ext_f]
		local connid = train.path_cn[train.path_ext_f]
		local node_ok, this_conns, adj_pos, adj_connid, conn_idx, nextrail_y
		if train.path_ext_f == train.path_trk_f then
			node_ok, this_conns = advtrains.get_rail_info_at(this_pos)
			if not node_ok then error("For train "..train.id..": Path item "..train.path_ext_f.." on-track but not a valid node!") end
			adj_pos, adj_connid, conn_idx, nextrail_y = advtrains.get_adjacent_rail(pos, this_conns, connid, train.drives_on)
		end
		train.path_ext_f = train.path_ext_f + 1
		if adj_pos then
			adj_pos.y = adj_pos.y + nextrail_y
			train.path_cp[train.path_ext_f] = adj_connid
			local mconnid = advtrains.get_matching_conn(adj_connid)
			train.path_cn[train.path_ext_f] = mconnid
			train.path_dir[train.path_ext_f] = this_conns[mconnid]
			train.path_trk_f = train.path_ext_f
		else
			-- off-track fallback behavior
			adj_pos = advtrains.pos_add_dir(pos, train.path_dir[train.path_ext_f-1])
			train.path_dir[train.path_ext_f] = train.path_dir[train.path_ext_f-1]
		end
		train.path[train.path_ext_f] = adj_pos
		train.path_dist[train.path_ext_f - 1] = vector.distance(pos, adj_pos)
	end
	while index < train.path_ext_b do
		local pos = train.path[train.path_ext_b]
		local connid = train.path_cp[train.path_ext_b]
		local node_ok, this_conns, adj_pos, adj_connid, conn_idx, nextrail_y
		if train.path_ext_b == train.path_trk_b then
			node_ok, this_conns = advtrains.get_rail_info_at(this_pos)
			if not node_ok then error("For train "..train.id..": Path item "..train.path_ext_f.." on-track but not a valid node!") end
			adj_pos, adj_connid, conn_idx, nextrail_y = advtrains.get_adjacent_rail(pos, this_conns, connid, train.drives_on)
		end
		train.path_ext_b = train.path_ext_b - 1
		if adj_pos then
			adj_pos.y = adj_pos.y + nextrail_y
			train.path_cp[train.path_ext_b] = adj_connid
			local mconnid = advtrains.get_matching_conn(adj_connid)
			train.path_cn[train.path_ext_b] = mconnid
			train.path_dir[train.path_ext_b] = advtrains.oppd(this_conns[mconnid]) --we need to rotate this here so that it points in positive path direction
			train.path_trk_b = train.path_ext_b
		else
			-- off-track fallback behavior
			adj_pos = advtrains.pos_add_dir(pos, train.path_dir[train.path_ext_b-1])
			train.path_dir[train.path_ext_b] = train.path_dir[train.path_ext_b-1]
		end
		train.path[train.path_ext_b] = adj_pos
		train.path_dist[train.path_ext_b] = vector.distance(pos, adj_pos)
	end
	
	return train.path[index], (index<=train.path_trk_f and index>=train.path_trk_b)
	
end

-- interpolated position to fractional index given, and angle based on path_dir
-- returns: pos, angle(yaw), p_floor, p_ceil
function advtrains.path_get_interpolated(train, index)
	local i_floor = atfloor(index)
	local i_ceil = i_floor + 1
	local frac = index - i_floor
	local p_floor,  = advtrains.path_get(train, i_floor)
	local p_ceil = advtrains.path_get(train, i_ceil)
	-- Note: minimal code duplication to path_get_adjacent, for performance
	
	local d_floor = train.path_dir[i_floor]
	local d_ceil = train.path_dir[i_ceil]
	local a_floor = advtrains.dir_to_angle(d_floor)
	local a_ceil = advtrains.dir_to_angle(d_ceil)
	
	local ang = advtrains.minAngleDiffRad(a_floor, a_ceil)
	
	return vector.add(p_floor, vector.multiply(vector.subtract(npos2, npos), frac), (a_floor + frac * ang)%(2*math.pi), p_floor, p_ceil -- TODO does this behave correctly?
end
-- returns the 2 path positions directly adjacent to index and the fraction on how to interpolate between them
-- returns: pos_floor, pos_ceil, fraction
function advtrains.path_get_adjacent(train, index)
	local i_floor = atfloor(index)
	local i_ceil = i_floor + 1
	local frac = index - i_floor
	local p_floor,  = advtrains.path_get(train, i_floor)
	local p_ceil = advtrains.path_get(train, i_ceil)
	return p_floor, p_ceil, frac
end

function advtrains.path_get_index_by_offset(train, index, offset)
	local pos_in_train_left=pit
	local index=train.index
	if pos_in_train_left>(index-math.floor(index))*(train.path_dist[math.floor(index)] or 1) then
		pos_in_train_left=pos_in_train_left - (index-math.floor(index))*(train.path_dist[math.floor(index)] or 1)
		index=math.floor(index)
		while pos_in_train_left>(train.path_dist[index-1] or 1) do
			pos_in_train_left=pos_in_train_left - (train.path_dist[index-1] or 1)
			index=index-1
		end
		index=index-(pos_in_train_left/(train.path_dist[index-1] or 1))
	else
		index=index-(pos_in_train_left/(train.path_dist[math.floor(index-1)] or 1))
	end
	return index
end
