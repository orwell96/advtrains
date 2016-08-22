--trackplacer.lua
--holds code for the track-placing system. the default 'track' item will be a craftitem that places rails as needed. this will neither place or change switches nor place vertical rails.

local print=function(t, ...) minetest.log("action", table.concat({t, ...}, " ")) minetest.chat_send_all(table.concat({t, ...}, " ")) end

--all new trackplacer code
local tp={
	tracks={}
}

function tp.register_tracktype(nnprefix, n_suffix)
	tp.tracks[nnprefix]={
		default=n_suffix,
		single_conn={},
		double_conn={},
		--keys:conn1_conn2 (example:1_4)
		--values:{name=x, param2=x}
		twcycle={},
		twrotate={},--indexed by suffix, list, tells order of rotations
		modify={}
	}
end
function tp.add_double_conn(nnprefix, suffix, rotation, conns)
	local nodename=nnprefix.."_"..suffix..rotation
	for i=0,3 do
		tp.tracks[nnprefix].double_conn[((conns.conn1+4*i)%16).."_"..((conns.conn2+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].double_conn[((conns.conn2+4*i)%16).."_"..((conns.conn1+4*i)%16)]={name=nodename, param2=i}
	end
	tp.tracks[nnprefix].modify[nodename]=true
end
function tp.add_single_conn(nnprefix, suffix, rotation, conns)
	local nodename=nnprefix.."_"..suffix..rotation
	for i=0,3 do
		tp.tracks[nnprefix].single_conn[((conns.conn1+4*i)%16)]={name=nodename, param2=i}
		tp.tracks[nnprefix].single_conn[((conns.conn2+4*i)%16)]={name=nodename, param2=i}
	end
	tp.tracks[nnprefix].modify[nodename]=true
end

function tp.add_worked(nnprefix, suffix, rotation, cycle_follows)
	tp.tracks[nnprefix].twcycle[suffix]=cycle_follows
	if not tp.tracks[nnprefix].twrotate[suffix] then tp.tracks[nnprefix].twrotate[suffix]={} end
	table.insert(tp.tracks[nnprefix].twrotate[suffix], rotation)
end

function tp.find_adjacent_tracks(pos)--TODO vertical calculations(check node below)
	local conn1=0
	while conn1<16 and not advtrains.is_track_and_drives_on(minetest.get_node(advtrains.dirCoordSet(pos, conn1)).name, advtrains.all_tracktypes) do
		conn1=conn1+1
	end
	if conn1>=16 then
		return nil, nil
	end
	local conn2=0
	while conn2<16 and not advtrains.is_track_and_drives_on(minetest.get_node(advtrains.dirCoordSet(pos, conn2)).name, advtrains.all_tracktypes) or conn2==conn1 do
		conn2=conn2+1
	end
	if conn2>=16 then
		return conn1, nil
	end
	return conn1, conn2
end
function tp.find_already_connected(pos)--TODO vertical calculations(check node below)
	local function istrackandbc(pos, conn)
		local cnode=minetest.get_node(advtrains.dirCoordSet(pos, conn))
		local bconn=(conn+8)%16
		if advtrains.is_track_and_drives_on(cnode.name, advtrains.all_tracktypes) then
			local cconn1, cconn2=advtrains.get_track_connections(cnode.name, cnode.param2)
			return cconn1==bconn or cconn2==bconn
		end
		return false
	end
	local conn1=0
	while conn1<16 and not istrackandbc(pos, conn1) do
		conn1=conn1+1
	end
	if conn1>=16 then
		return nil, nil
	end
	local conn2=0
	while conn2<16 and not istrackandbc(pos, conn2) or conn2==conn1 do
		conn2=conn2+1
	end
	if conn2>=16 then
		return conn1, nil
	end
	return conn1, conn2
end

function tp.placetrack(pos, nnpref)
	local conn1, conn2=tp.find_adjacent_tracks(pos)
	local tr=tp.tracks[nnpref]
	if not conn1 and not conn2 then
		minetest.set_node(pos, {name=nnpref.."_"..tr.default})
	elseif conn1 and not conn2 then
		if tr.single_conn[conn1] then
			tp.try_adjust_rail(tr, advtrains.dirCoordSet(pos, conn1), (conn1+8)%16)
			minetest.set_node(pos, tr.single_conn[conn1])
		else
			minetest.set_node(pos, {name=nnpref.."_"..tr.default})
		end
	elseif conn1 and conn2 then
		if tr.double_conn[conn1.."_"..conn2] then
			tp.try_adjust_rail(tr, advtrains.dirCoordSet(pos, conn1), (conn1+8)%16)
			tp.try_adjust_rail(tr, advtrains.dirCoordSet(pos, conn2), (conn1+8)%16)
			minetest.set_node(pos, tr.double_conn[conn1.."_"..conn2])
		elseif tr.single_conn[conn1] then --try at least one side
			tp.try_adjust_rail(tr, advtrains.dirCoordSet(pos, conn1), (conn1+8)%16)
			minetest.set_node(pos, tr.single_conn[conn1])
		else
			minetest.set_node(pos, {name=nnpref.."_"..tr.default})
		end
	end
end
function tp.try_adjust_rail(tr, pos, newdir)
	--is rail already connected?
	local node=minetest.get_node(pos)
	local conn1, conn2=advtrains.get_track_connections(node.name, node.param2)
	if newdir==conn1 or newdir==conn2 then
		return
	end
	--rail at other end?
	local adj1, adj2=tp.find_already_connected(pos)
	if adj1 and adj2 then
		return false--dont destroy existing track
	elseif adj1 and not adj2 then
		if tr.double_conn[adj1.."_"..newdir] then
			minetest.set_node(pos, tr.double_conn[adj1.."_"..newdir])
			return true--if exists, connect new rail and old end
		end
		return false
	else
		if tr.single_conn[newdir] then--just rotate old rail to right orientation
			minetest.set_node(pos, tr.single_conn[newdir])
			return true
		end
		return false
	end
end


function tp.register_track_placer(nnprefix, imgprefix, dispname)
	minetest.register_craftitem(nnprefix.."_placer",{
		description = dispname,
		inventory_image = imgprefix.."_placer.png",
		wield_image = imgprefix.."_placer.png",
		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type=="node" then
				local pos=pointed_thing.above
				if minetest.registered_nodes[minetest.get_node(pos).name] and minetest.registered_nodes[minetest.get_node(pos).name].buildable_to then
					tp.placetrack(pos, nnprefix)
					if not minetest.setting_getbool("creative_mode") then
						itemstack:take_item()
					end
				end
			end
			return itemstack
		end,
	})
end



minetest.register_craftitem("advtrains:trackworker",{
	description = "Track Worker Tool\n\nLeft-click: change rail type (straight/curve/switch)\nRight-click: rotate rail",
	groups = {cracky=1}, -- key=name, value=rating; rating=1..3.
	inventory_image = "advtrains_trackworker.png",
	wield_image = "advtrains_trackworker.png",
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type=="node" then
			local pos=pointed_thing.under
			local node=minetest.get_node(pos)
			
			if not advtrains.is_track_and_drives_on(minetest.get_node(pos).name, advtrains.all_tracktypes) then return end
			if advtrains.is_train_at_pos(pos) then return end
			
			local nnprefix, suffix, rotation=string.match(node.name, "^([^_]+)_([^_]+)(_?.*)$")
			--print(node.name.."\npattern recognizes:"..nodeprefix.." / "..railtype.." / "..rotation)
			if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twrotate[suffix] then
				print("[advtrains]railtype not workable by trackworker")
				return
			end
			local modext=tp.tracks[nnprefix].twrotate[suffix]

			if rotation==modext[#modext] then --increase param2
				minetest.set_node(pos, {name=nnprefix.."_"..suffix..modext[1], param2=(node.param2+1)%4})
				return
			else
				local modpos
				for k,v in pairs(modext) do if v==rotation then modpos=k end end
				if not modpos then
					print("[advtrains]rail not workable by trackworker")
					return
				end
				minetest.set_node(pos, {name=nnprefix.."_"..suffix..modext[modpos+1], param2=node.param2})
			end
			advtrains.invalidate_all_paths()
		end
	end,
	on_use=function(itemstack, user, pointed_thing)
		if pointed_thing.type=="node" then
			local pos=pointed_thing.under
			local node=minetest.get_node(pos)
			
			if not advtrains.is_track_and_drives_on(minetest.get_node(pos).name, advtrains.all_tracktypes) then return end
			if advtrains.is_train_at_pos(pos) then return end
			local nnprefix, suffix, rotation=string.match(node.name, "^([^_]+)_([^_]+)(_?.*)$")
			
			if not tp.tracks[nnprefix] or not tp.tracks[nnprefix].twcycle[suffix] then
				print("[advtrains]railtype not workable by trackworker")
				return
			end
			local nextsuffix=tp.tracks[nnprefix].twcycle[suffix]
			minetest.set_node(pos, {name=nnprefix.."_"..nextsuffix..rotation, param2=node.param2})
			--invalidate trains
			advtrains.invalidate_all_paths()
		end
	end,
})

--putting into right place
advtrains.trackplacer=tp
