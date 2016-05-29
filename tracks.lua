--advtrains by orwell96, see readme.txt

--[[TracksDefinition
nodename_prefix
texture_prefix
description
straight={}
straight45={}
curve={}
curve45={}
lswitchst={}
lswitchst45={}
rswitchst={}
rswitchst45={}
lswitchcr={}
lswitchcr45={}
rswitchcr={}
rswitchcr45={}
vert1={
	--you'll probably want to override mesh here
}
vert2={
	--you'll probably want to override mesh here
}
]]--
advtrains.all_tracktypes={}

function advtrains.register_tracks(tracktype, def)
	local function make_switchfunc(suffix_target)
		return function(pos, node)
			if advtrains.is_train_at_pos(pos) then return end
			advtrains.invalidate_all_paths()
			minetest.set_node(pos, {name=def.nodename_prefix.."_"..suffix_target, param2=node.param2})
		end
	end
	local function make_overdef(img_suffix, conn1, conn2, switchfunc)
		return {
			tiles = {def.texture_prefix.."_"..img_suffix..".png"},
			inventory_image = def.texture_prefix.."_"..img_suffix..".png",
			wield_image = def.texture_prefix.."_"..img_suffix..".png",
			connect1=conn1,
			connect2=conn2,
			on_rightclick=switchfunc,
		}
	end
	local common_def={
		description = def.description,
		drawtype = "mesh",
		mesh = "trackplane.b3d",
		paramtype="light",
		paramtype2="facedir",
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
		},
		groups = {
			attached_node=1,
			["advtrains_track_"..tracktype]=1,
			dig_immediate=2,
			not_in_creative_inventory=1,
		},
		rely1=0,
		rely2=0,
		railheight=0,
		drop="advtrains:placetrack_"..tracktype,
		--on_rightclick=function(pos, node, clicker)
		--	minetest.set_node(pos, {name=node.name, param2=(node.param2+1)%4})
		--end
		can_dig=function(pos)
			return not advtrains.is_train_at_pos(pos)
		end,
		after_dig_node=function()
			advtrains.invalidate_all_paths()
		end
	}
	minetest.register_node(def.nodename_prefix.."_st", advtrains.merge_tables(common_def, make_overdef("st", 0, 4), def.straight or {}))
	minetest.register_node(def.nodename_prefix.."_st_45", advtrains.merge_tables(common_def, make_overdef("st_45", 1, 5), def.straight45 or {}))
	
	minetest.register_node(def.nodename_prefix.."_cr", advtrains.merge_tables(common_def, make_overdef("cr", 0, 3), def.curve or {}))
	minetest.register_node(def.nodename_prefix.."_cr_45", advtrains.merge_tables(common_def, make_overdef("cr_45", 1, 4), def.curve45 or {}))
	
	advtrains.trackplacer_register(def.nodename_prefix.."_st", 0, 4)
	advtrains.trackplacer_register(def.nodename_prefix.."_st_45", 1, 5)
	advtrains.trackplacer_register(def.nodename_prefix.."_cr", 0, 3)
	advtrains.trackplacer_register(def.nodename_prefix.."_cr_45", 1, 4)
	
	
	minetest.register_node(def.nodename_prefix.."_swl_st", advtrains.merge_tables(common_def, make_overdef("swl_st", 0, 4, make_switchfunc("swl_cr")), def.lswitchst or {}))
	minetest.register_node(def.nodename_prefix.."_swl_st_45", advtrains.merge_tables(common_def, make_overdef("swl_st_45", 1, 5, make_switchfunc("swl_cr_45")), def.lswitchst45 or {}))
	minetest.register_node(def.nodename_prefix.."_swl_cr", advtrains.merge_tables(common_def, make_overdef("swl_cr", 0, 3, make_switchfunc("swl_st")), def.lswitchcr or {}))
	minetest.register_node(def.nodename_prefix.."_swl_cr_45", advtrains.merge_tables(common_def, make_overdef("swl_cr_45", 1, 4, make_switchfunc("swl_st_45")), def.lswitchcr45 or {}))
	
	minetest.register_node(def.nodename_prefix.."_swr_st", advtrains.merge_tables(common_def, make_overdef("swr_st", 0, 4, make_switchfunc("swr_cr")), def.rswitchst or {}))
	minetest.register_node(def.nodename_prefix.."_swr_st_45", advtrains.merge_tables(common_def, make_overdef("swr_st_45", 1, 5, make_switchfunc("swr_cr_45")), def.rswitchst45 or {}))
	minetest.register_node(def.nodename_prefix.."_swr_cr", advtrains.merge_tables(common_def, make_overdef("swr_cr", 0, 5, make_switchfunc("swr_st")), def.rswitchcr or {}))
	minetest.register_node(def.nodename_prefix.."_swr_cr_45", advtrains.merge_tables(common_def, make_overdef("swr_cr_45", 1, 6, make_switchfunc("swr_st_45")), def.rswitchcr45 or {}))
	
	minetest.register_node(def.nodename_prefix.."_vert1", advtrains.merge_tables(common_def, make_overdef("vert1", 0, 4), {
		mesh = "trackvertical1.b3d",
		rely1=0,
		rely2=0.5,
		railheight=0.25,
		description = def.description.." (vertical track lower node)",
		}, def.vert1 or {}))
	minetest.register_node(def.nodename_prefix.."_vert2", advtrains.merge_tables(common_def, make_overdef("vert2", 0, 4), {
		mesh = "trackvertical2.b3d",
		rely1=0.5,
		rely2=1,
		railheight=0.75,
		description = def.description.." (vertical track lower node)",
		},def.vert2 or {}))
	
	advtrains.register_track_placer(def.nodename_prefix, def.texture_prefix, def.description)
	table.insert(advtrains.all_tracktypes, tracktype)
end

advtrains.register_tracks("regular", {
	nodename_prefix="advtrains:track",
	texture_prefix="track",
	description="Regular Train Track",
})

function advtrains.is_track_and_drives_on(nodename, drives_on)
	if not minetest.registered_nodes[nodename] then
		return false
	end
	local nodedef=minetest.registered_nodes[nodename]
	for k,v in ipairs(drives_on) do
		if nodedef.groups["advtrains_track_"..v] then
			return true
		end
	end
	return false
end

function advtrains.get_track_connections(name, param2)
	local nodedef=minetest.registered_nodes[name]
	if not nodedef then print("[advtrains] get_track_connections couldn't find nodedef for nodename "..(name or "nil")) return 0,4 end
	local noderot=param2
	if not param2 then noderot=0 end
	if noderot > 3 then print("[advtrains] get_track_connections: rail has invaild param2 of "..noderot) noderot=0 end
	
	return (nodedef.connect1 + 2 * noderot)%8, (nodedef.connect2  + 2 * noderot)%8, nodedef.rely1 or 0, nodedef.rely2 or 0, nodedef.railheight or 0
end







