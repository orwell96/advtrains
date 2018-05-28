--trackplacer.lua
--holds code for the track-placing system. the default 'track' item will be a craftitem that places rails as needed. this will neither place or change switches nor place vertical rails.

--all new trackplacer code
local tp={
	tracks={}
}

function tp.register_tracktype(nnprefix, n_suffix)
	if tp.tracks[nnprefix] then return end--due to the separate registration of slopes and flats for the same nnpref, definition would be overridden here. just don't.
	tp.tracks[nnprefix]={
		default=n_suffix,
		single_conn={},
		single_conn_1={},
		single_conn_2={},
		double_conn={},
		double_conn_1={},
		double_conn_2={},
		--keys:conn1_conn2 (example:1_4)
		--values:{name=x, param2=x}
		twcycle={},
		twrotate={},--indexed by suffix, list, tells order of rotations
		modify={},
	}
end
function tp.add_double_conn(nnprefix, suffix, rotation, conns)
	local nodename=nnprefix.."_"..suffix..rotation
	for i=0,3 do
		tp.tracks[nnprefix].double_conn[((conns.conn1+4*i)%16).."_"..((conns.conn2+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].double_conn[((conns.conn2+4*i)%16).."_"..((conns.conn1+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].double_conn_1[((conns.conn1+4*i)%16).."_"..((conns.conn2+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].double_conn_2[((conns.conn2+4*i)%16).."_"..((conns.conn1+4*i)%16)]={name=nodename, param2=i}
	end
	tp.tracks[nnprefix].modify[nodename]=true
end
function tp.add_single_conn(nnprefix, suffix, rotation, conns)
	local nodename=nnprefix.."_"..suffix..rotation
	for i=0,3 do
		tp.tracks[nnprefix].single_conn[((conns.conn1+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].single_conn[((conns.conn2+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].single_conn_1[((conns.conn1+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].single_conn_2[((conns.conn2+4*i)%16)]={name=nodename, param2=i}
	end
	tp.tracks[nnprefix].modify[nodename]=true
end


function tp.add_worked(nnprefix, suffix, rotation, cycle_follows)
	tp.tracks[nnprefix].twcycle[suffix]=cycle_follows
	if not tp.tracks[nnprefix].twrotate[suffix] then tp.tracks[nnprefix].twrotate[suffix]={} end
	table.insert(tp.tracks[nnprefix].twrotate[suffix], rotation)
end


--[[
	rewrite algorithm.
	selection criteria: these will never be changed or even selected:
	- tracks being already connected on both sides
	- tracks that are already connected on one side but are not bendable to the desired position
	the following situations can occur:
	1. there are two more than two rails around
		1.1 there is one or more subset(s) that can be directly connected
			-> choose the first possibility
		2.2 not
			-> choose the first one and orient straight
	2. there's exactly 1 rail around
		-> choose and orient straight
	3. there's no rail around
		-> set straight
]]

local function istrackandbc(pos_p, conn)
	local tpos = pos_p
	local cnode=minetest.get_node(advtrains.dirCoordSet(tpos, conn.c))
	if advtrains.is_track_and_drives_on(cnode.name, advtrains.all_tracktypes) then
		local cconns=advtrains.get_track_connections(cnode.name, cnode.param2)
		return advtrains.conn_matches_to(conn, cconns)
	end
	--try the same 1 node below
	tpos = {x=tpos.x, y=tpos.y-1, z=tpos.z}
	cnode=minetest.get_node(advtrains.dirCoordSet(tpos, conn.c))
	if advtrains.is_track_and_drives_on(cnode.name, advtrains.all_tracktypes) then
		local cconns=advtrains.get_track_connections(cnode.name, cnode.param2)
		return advtrains.conn_matches_to(conn, cconns)
	end
	return false
end

function tp.find_already_connected(pos)
	local dnode=minetest.get_node(pos)
	local dconns=advtrains.get_track_connections(dnode.name, dnode.param2)
	local found_conn
	for connid, conn in ipairs(dconns) do
		if istrackandbc(pos, conn) then
			if found_conn then --we found one in previous iteration
				return true, true --signal that it's connected
			else
				found_conn = conn.c
			end
		end
	end
	return found_conn
end
function tp.rail_and_can_be_bent(originpos, conn)
	local pos=advtrains.dirCoordSet(originpos, conn)
	local newdir=(conn+8)%16
	local node=minetest.get_node(pos)
	if not advtrains.is_track_and_drives_on(node.name, advtrains.all_tracktypes) then
		return false
	end
	local ndef=minetest.registered_nodes[node.name]
	local nnpref = ndef and ndef.at_nnpref
	if not nnpref then return false end
	local tr=tp.tracks[nnpref]
	if not tr then return false end
	if not tr.modify[node.name] then 
		--we actually can use this rail, but only if it already points to the desired direction.
		if advtrains.is_track_and_drives_on(node.name, advtrains.all_tracktypes) then
			local cconns=advtrains.get_track_connections(node.name, node.param2)
			return advtrains.conn_matches_to(conn, cconns)
		end
	end
	--rail at other end?
	local adj1, adj2=tp.find_already_connected(pos)
	if adj1 and adj2 then
		return false--dont destroy existing track
	elseif adj1 and not adj2 then
		if tr.double_conn[adj1.."_"..newdir] then
			return true--if exists, connect new rail and old end
		end
		return false
	else
		if tr.single_conn[newdir] then--just rotate old rail to right orientation
			return true
		end
		return false
	end
end
function tp.bend_rail(originpos, conn)
	local pos=advtrains.dirCoordSet(originpos, conn)
	local newdir=advtrains.oppd(conn)
	local node=minetest.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	local nnpref = ndef and ndef.at_nnpref
	if not nnpref then return false end
	local tr=tp.tracks[nnpref]
	if not tr then return false end
	--is rail already connected? no need to bend.
	local conns=advtrains.get_track_connections(node.name, node.param2)
	if advtrains.conn_matches_to(conn, conns) then
		return
	end
	--rail at other end?
	local adj1, adj2=tp.find_already_connected(pos)
	if adj1 and adj2 then
		return false--dont destroy existing track
	elseif adj1 and not adj2 then
		if tr.double_conn[adj1.."_"..newdir] then
			advtrains.ndb.swap_node(pos, tr.double_conn[adj1.."_"..newdir])
			return true--if exists, connect new rail and old end
		end
		return false
	else
		if tr.single_conn[newdir] then--just rotate old rail to right orientation
			advtrains.ndb.swap_node(pos, tr.single_conn[newdir])
			return true
		end
		return false
	end
end
function tp.placetrack(pos, nnpref, placer, itemstack, pointed_thing, yaw)
	--1. find all rails that are likely to be connected
	local tr=tp.tracks[nnpref]
	local p_rails={}
	local p_railpos={}
	for i=0,15 do
		if tp.rail_and_can_be_bent(pos, i, nnpref) then
			p_rails[#p_rails+1]=i
			p_railpos[i] = pos
		else
			local upos = {x=pos.x, y=pos.y-1, z=pos.z}
			if tp.rail_and_can_be_bent(upos, i, nnpref) then
				p_rails[#p_rails+1]=i
				p_railpos[i] = upos
			end
		end
	end
	
	-- try double_conn
	if #p_rails > 1 then
		--iterate subsets
		for k1, conn1 in ipairs(p_rails) do
			for k2, conn2 in ipairs(p_rails) do
				if k1~=k2 then
					local dconn1 = tr.double_conn_1
					local dconn2 = tr.double_conn_2
					if not (advtrains.yawToDirection(yaw, conn1, conn2) == conn1) then
						dconn1 = tr.double_conn_2
						dconn2 = tr.double_conn_1
					end
					-- Checks are made this way round so that dconn1 has priority (this will make arrows of atc rails
					-- point in the right direction)
					local using
					if (dconn2[conn1.."_"..conn2]) then
						using = dconn2[conn1.."_"..conn2]
					end
					if (dconn1[conn1.."_"..conn2]) then
						using = dconn1[conn1.."_"..conn2]
					end
					
					tp.bend_rail(p_railpos[conn1], conn1, nnpref)
					tp.bend_rail(p_railpos[conn2], conn2, nnpref)
					advtrains.ndb.swap_node(pos, using)
					local nname=using.name
					if minetest.registered_nodes[nname] and minetest.registered_nodes[nname].after_place_node then
						minetest.registered_nodes[nname].after_place_node(pos, placer, itemstack, pointed_thing)
					end
					return
				end
			end
		end
	end
	-- try single_conn
	if #p_rails > 0 then
		for ix, p_rail in ipairs(p_rails) do
			local sconn1 = tr.single_conn_1
			local sconn2 = tr.single_conn_2
			if not (advtrains.yawToDirection(yaw, p_rail, (p_rail+8)%16) == p_rail) then
				sconn1 = tr.single_conn_2
				sconn2 = tr.single_conn_1
			end
			if sconn1[p_rail] then
				local using = sconn1[p_rail]
				tp.bend_rail(p_railpos[p_rail], p_rail, nnpref)
				advtrains.ndb.swap_node(pos, using)
				local nname=using.name
				if minetest.registered_nodes[nname] and minetest.registered_nodes[nname].after_place_node then
					minetest.registered_nodes[nname].after_place_node(pos, placer, itemstack, pointed_thing)
				end
				return
			end
			if sconn2[p_rail] then
				local using = sconn2[p_rail]
				tp.bend_rail(p_railpos[p_rail], p_rail, nnpref)
				advtrains.ndb.swap_node(pos, using)
				local nname=using.name
				if minetest.registered_nodes[nname] and minetest.registered_nodes[nname].after_place_node then
					minetest.registered_nodes[nname].after_place_node(pos, placer, itemstack, pointed_thing)
				end
				return
			end
		end
	end
	--use default
	minetest.set_node(pos, {name=nnpref.."_"..tr.default})
	if minetest.registered_nodes[nnpref.."_"..tr.default] and minetest.registered_nodes[nnpref.."_"..tr.default].after_place_node then
		minetest.registered_nodes[nnpref.."_"..tr.default].after_place_node(pos, placer, itemstack, pointed_thing)
	end
end


function tp.register_track_placer(nnprefix, imgprefix, dispname)
	minetest.register_craftitem(":"..nnprefix.."_placer",{
		description = dispname,
		inventory_image = imgprefix.."_placer.png",
		wield_image = imgprefix.."_placer.png",
		groups={advtrains_trackplacer=1},
		on_place = function(itemstack, placer, pointed_thing)
			return advtrains.pcall(function()
					local name = placer:get_player_name()
				if not name then
				   return itemstack, false
				end
				if pointed_thing.type=="node" then
					local pos=pointed_thing.above
					local upos=vector.subtract(pointed_thing.above, {x=0, y=1, z=0})
					if advtrains.is_protected(pos,name) then
						minetest.record_protection_violation(pos, name)
						return itemstack, false
					end
					if minetest.registered_nodes[minetest.get_node(pos).name] and minetest.registered_nodes[minetest.get_node(pos).name].buildable_to
					and minetest.registered_nodes[minetest.get_node(upos).name] and minetest.registered_nodes[minetest.get_node(upos).name].walkable then
--						minetest.chat_send_all(nnprefix)
						local yaw = placer:get_look_horizontal()
						tp.placetrack(pos, nnprefix, placer, itemstack, pointed_thing, yaw)
						if not minetest.settings:get_bool("creative_mode") then
							itemstack:take_item()
						end
					end
				end
				return itemstack, true
			end)
		end,
	})
end



minetest.register_craftitem("advtrains:trackworker",{
	description = attrans("Track Worker Tool\n\nLeft-click: change rail type (straight/curve/switch)\nRight-click: rotate rail/bumper/signal/etc."),
	groups = {cracky=1}, -- key=name, value=rating; rating=1..3.
	inventory_image = "advtrains_trackworker.png",
	wield_image = "advtrains_trackworker.png",
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		return advtrains.pcall(function()
			local name = placer:get_player_name()
			if not name then
				return
			end
			local has_aux1_down = placer:get_player_control().aux1
			if pointed_thing.type=="node" then
				local pos=pointed_thing.under
				if advtrains.is_protected(pos, name) then
					minetest.record_protection_violation(pos, name)
					return
				end
				local node=minetest.get_node(pos)

				--if not advtrains.is_track_and_drives_on(minetest.get_node(pos).name, advtrains.all_tracktypes) then return end
				if advtrains.get_train_at_pos(pos) then return end
				
				if has_aux1_down then
					--feature: flip the node by 180°
					--i've always wanted this!
					advtrains.ndb.swap_node(pos, {name=node.name, param2=(node.param2+2)%4})
					return
				end

				local nnprefix, suffix, rotation=string.match(node.name, "^(.+)_([^_]+)(_[^_]+)$")
				--atprint(node.name.."\npattern recognizes:"..nodeprefix.." / "..railtype.." / "..rotation)
				if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twrotate[suffix] then
					nnprefix, suffix=string.match(node.name, "^(.+)_([^_]+)$")
					rotation = ""
					if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twrotate[suffix] then
						minetest.chat_send_player(placer:get_player_name(), attrans("This node can't be rotated using the trackworker!"))
						return
					end
				end
				local modext=tp.tracks[nnprefix].twrotate[suffix]

				if rotation==modext[#modext] then --increase param2
					advtrains.ndb.swap_node(pos, {name=nnprefix.."_"..suffix..modext[1], param2=(node.param2+1)%4})
					return
				else
					local modpos
					for k,v in pairs(modext) do if v==rotation then modpos=k end end
						if not modpos then
							minetest.chat_send_player(placer:get_player_name(), attrans("This node can't be rotated using the trackworker!"))
						return
					end
					advtrains.ndb.swap_node(pos, {name=nnprefix.."_"..suffix..modext[modpos+1], param2=node.param2})
				end
			end
		end)
	end,
	on_use=function(itemstack, user, pointed_thing)
		return advtrains.pcall(function()
				local name = user:get_player_name()
			if not name then
			   return
			end
			if pointed_thing.type=="node" then
				local pos=pointed_thing.under
				local node=minetest.get_node(pos)
				if advtrains.is_protected(pos, name) then
					minetest.record_protection_violation(pos, name)
					return
				end
				
				--if not advtrains.is_track_and_drives_on(minetest.get_node(pos).name, advtrains.all_tracktypes) then return end
				if advtrains.get_train_at_pos(pos) then return end
				local nnprefix, suffix, rotation=string.match(node.name, "^(.+)_([^_]+)(_[^_]+)$")
				--atprint(node.name.."\npattern recognizes:"..nodeprefix.." / "..railtype.." / "..rotation)
				if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twcycle[suffix] then
				  nnprefix, suffix=string.match(node.name, "^(.+)_([^_]+)$")
				  rotation = ""
				  if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twcycle[suffix] then
					minetest.chat_send_player(user:get_player_name(), attrans("This node can't be changed using the trackworker!"))
					return
				  end
				end
				local nextsuffix=tp.tracks[nnprefix].twcycle[suffix]
				advtrains.ndb.swap_node(pos, {name=nnprefix.."_"..nextsuffix..rotation, param2=node.param2})
				
			else
				atprint(name, dump(tp.tracks))
			end
		end)
	end,
})

--putting into right place
advtrains.trackplacer=tp
