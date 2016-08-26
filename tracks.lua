--advtrains by orwell96, see readme.txt

--dev-time settings:
--EDIT HERE
--If the old non-model rails on straight tracks should be replaced by the new...
--false: no
--true: yes
advtrains.register_straight_rep_lbm=true

--[[TracksDefinition
nodename_prefix
texture_prefix
description
common={}
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

--definition preparation
local function conns(c1, c2, r1, r2, rh, rots) return {conn1=c1, conn2=c2, rely1=r1, rely2=r2, railheight=rh} end

local t_30deg={
	regstep=1,
	variant={
		st=conns(0,8),
		cr=conns(0,7),
		swlst=conns(0,8),
		swlcr=conns(0,7),
		swrst=conns(0,8),
		swrcr=conns(0,9),
		vst1=conns(8,0,0,0.5,0.25),
		vst2=conns(8,0,0.5,1,0.75),
	},
	switch={
		swlst="swlcr",
		swlcr="swlst",
		swrst="swrcr",
		swrcr="swrst",
	},
	trackplacer={
		st=true,
		cr=true,
	},
	tpsingle={
		st=true,
	},
	tpdefault="st",
	trackworker={
		["swrcr"]="st",
		["swrst"]="st",
		["st"]="cr",
		["cr"]="swlst",
		["swlcr"]="swrcr",
		["swlst"]="swrst",
	},
	rotation={"", "_30", "_45", "_60"},
	increativeinv={vst1=true, vst2=true}
}
local t_45deg={
	regstep=2,
	variant={
		st=conns(0,8),
		cr=conns(0,6),
		swlst=conns(0,8),
		swlcr=conns(0,6),
		swrst=conns(0,8),
		swrcr=conns(0,10),
		vst1=conns(8,0,0,0.5,0.25),
		vst2=conns(8,0,0.5,1,0.75),
	},
	switch={
		swlst="swlcr",
		swlcr="swlst",
		swrst="swrcr",
		swrcr="swrst",
	},
	trackplacer={
		st=true,
		cr=true,
	},
	tpsingle={
		st=true,
	},
	tpdefault="st",
	trackworker={
		["swrcr"]="st",
		["swrst"]="st",
		["st"]="cr",
		["cr"]="swlst",
		["swlcr"]="swrcr",
		["swlst"]="swrst",
	},
	rotation={"", "_45"},
	increativeinv={vst1=true, vst2=true}
}

--definition format: ([] optional)
--[[{
	nodename_prefix
	texture_prefix
	[shared_texture]
	models_prefix
	models_suffix (with dot)
	[shared_model]
	formats={
		st,cr,swlst,swlcr,swrst,swrcr,vst1,vst2
		(each a table with indices 0-3, for if to register a rail with this 'rotation' table entry. nil is assumed as 'all', set {} to not register at all)
	}
	common={} change something on common rail appearance
}]]
function advtrains.register_tracks(tracktype, def, preset)
	local function make_switchfunc(suffix_target)
		return function(pos, node)
			if advtrains.is_train_at_pos(pos) then return end
			advtrains.invalidate_all_paths()
			minetest.set_node(pos, {name=def.nodename_prefix.."_"..suffix_target, param2=node.param2})
			advtrains.reset_trackdb_position(pos)
		end
	end
	local function make_overdef(img_suffix, conns, switchfunc)
		return {
			mesh = def.shared_model or (def.models_prefix.."_"..img_suffix..def.models_suffix),
			tiles = {def.shared_texture or (def.texture_prefix.."_"..img_suffix..".png")},
			inventory_image = def.texture_prefix.."_"..img_suffix..".png",
			wield_image = def.texture_prefix.."_"..img_suffix..".png",
			connect1=conns.conn1,
			connect2=conns.conn2,
			rely1=conns.rely1 or 0,
			rely2=conns.rely2 or 0,
			railheight=conns.railheight or 0,
			on_rightclick=switchfunc,
		}
	end
	local function cycle_conns(conns, rotid)
		local add=(rotid-1)*preset.regstep
		return {
			conn1=(conns.conn1+add)%16,
			conn2=(conns.conn2+add)%16,
			rely1=conns.rely1 or 0,
			rely2=conns.rely2 or 0,
			railheight=conns.railheight or 0,
		}
	end
	local common_def=advtrains.merge_tables({
		description = def.description,
		drawtype = "mesh",
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
			not_in_creative_inventory=1,--NOTE see below when changing groups
		},
		rely1=0,
		rely2=0,
		railheight=0,
		drop="advtrains:placetrack_"..tracktype,
		can_dig=function(pos)
			return not advtrains.is_train_at_pos(pos)
		end,
		after_dig_node=function(pos)
			advtrains.invalidate_all_paths()
			advtrains.reset_trackdb_position(pos)
		end,
		after_place_node=function(pos)
			advtrains.reset_trackdb_position(pos)
		end,
	}, def.common or {})
	--make trackplacer base def
	advtrains.trackplacer.register_tracktype(def.nodename_prefix, preset.tpdefault)
	advtrains.trackplacer.register_track_placer(def.nodename_prefix, def.texture_prefix, def.description)
	
	for suffix, conns in pairs(preset.variant) do
		for rotid, rotation in ipairs(preset.rotation) do
			if not def.formats[suffix] or def.formats[suffix][rotid] then
				local switchfunc
				if preset.switch[suffix] then
					switchfunc=make_switchfunc(preset.switch[suffix]..rotation)
				end
				minetest.register_node(def.nodename_prefix.."_"..suffix..rotation, advtrains.merge_tables(
					common_def, 
					make_overdef(
						suffix..rotation,
						cycle_conns(conns, rotid),
						switchfunc
						)
					),
					preset.increativeinv[suffix] and {
						groups = {--NOTE change groups here too
							attached_node=1,
							["advtrains_track_"..tracktype]=1,
							dig_immediate=2,
						},
					} or {}
				)
				--trackplacer
				if preset.trackplacer[suffix] then
					advtrains.trackplacer.add_double_conn(def.nodename_prefix, suffix, rotation, cycle_conns(conns, rotid))
				end
				if preset.tpsingle[suffix] then
					advtrains.trackplacer.add_single_conn(def.nodename_prefix, suffix, rotation, cycle_conns(conns, rotid))
				end
				advtrains.trackplacer.add_worked(def.nodename_prefix, suffix, rotation, preset.trackworker[suffix])
			end
		end
	end
	table.insert(advtrains.all_tracktypes, tracktype)
end


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
	if not nodedef then print("[advtrains] get_track_connections couldn't find nodedef for nodename "..(name or "nil")) return 0, 8, 0, 0, 0 end
	local noderot=param2
	if not param2 then noderot=0 end
	if noderot > 3 then print("[advtrains] get_track_connections: rail has invaild param2 of "..noderot) noderot=0 end
	
	return (nodedef.connect1 + 4 * noderot)%16, (nodedef.connect2  + 4 * noderot)%16, nodedef.rely1 or 0, nodedef.rely2 or 0, nodedef.railheight or 0
end

--END code, BEGIN definition
--definition format: ([] optional)
--[[{
	nodename_prefix
	texture_prefix
	[shared_texture]
	models_prefix
	models_suffix (with dot)
	[shared_model]
	formats={
		st,cr,swlst,swlcr,swrst,swrcr,vst1,vst2
		(each a table with indices 0-3, for if to register a rail with this 'rotation' table entry. nil is assumed as 'all', set {} to not register at all)
	}
	common={} change something on common rail appearance
}]]

advtrains.register_tracks("regular", {
	nodename_prefix="advtrains:track",
	texture_prefix="advtrains_track",
	shared_model="trackplane.b3d",
	description="Regular Train Track",
	formats={vst1={}, vst2={}},
}, t_45deg)


advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail.png",
	description="New Default Train Track",
	formats={vst1={true}, vst2={true}},
}, t_30deg)

--TODO legacy
--I know lbms are better for this purpose
for name,rep in pairs({swl_st="swlst", swr_st="swrst", swl_cr="swlcr", swr_cr="swrcr", }) do
	minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep, param2=node.param2}) end,
    })
    minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name.."_45"},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep.."_45", param2=node.param2}) end,
    })
end

minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert1"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst1", param2=(node.param2+2)%4}) end,
})
minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  --  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert2"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst2", param2=(node.param2+2)%4}) end,
})
if advtrains.register_straight_rep_lbm then
	minetest.register_abm({
		name = "advtrains:st_rep_1",
	--  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st"},
		interval=1,
		chance=1,
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st", param2=node.param2}) end,
	})
	minetest.register_lbm({
		name = "advtrains:st_rep_1",
	--  --  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st_45"},
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st_45", param2=node.param2}) end,
	})
end








