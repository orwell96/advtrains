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

--about regular: Used by 1. to ensure path gets generated far enough, since end index is not known at this time.
function advtrains.pathpredict(id, train, regular)
	--TODO duplicate code under 5b.
	local path_pregen=10
	
	local gen_front= path_pregen
	local gen_back= - train.trainlen - path_pregen
	if regular then
		gen_front=math.max(train.index, train.detector_old_index) + path_pregen
		gen_back=math.min(train.end_index, train.detector_old_end_index) - path_pregen
	end
	
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
