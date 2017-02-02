--advtrains by orwell96, see readme.txt

--dev-time settings:
--EDIT HERE
--If the old non-model rails on straight tracks should be replaced by the new...
--false: no
--true: yes
advtrains.register_replacement_lbms=false

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

local ap={}
ap.t_30deg={
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
		vst31=conns(8,0,0,0.33,0.16),
		vst32=conns(8,0,0.33,0.66,0.5),
		vst33=conns(8,0,0.66,1,0.83),
	},
	description={
		st="straight",
		cr="curve",
		swlst="left switch (straight)",
		swlcr="left switch (curve)",
		swrst="right switch (straight)",
		swrcr="right switch (curve)",
		vst1="steep uphill 1/2",
		vst2="steep uphill 2/2",
		vst31="uphill 1/3",
		vst32="uphill 2/3",
		vst33="uphill 3/3",
	},
	switch={
		swlst="swlcr",
		swlcr="swlst",
		swrst="swrcr",
		swrcr="swrst",
	},
	switchmc={
		swlst="on",
		swlcr="off",
		swrst="on",
		swrcr="off",
	},
	switchst={
		swlst="st",
		swlcr="cr",
		swrst="st",
		swrcr="cr",
	},
	regtp=true,
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
	regsp=true,
	slopenodes={
		vst1=true, vst2=true,
		vst31=true, vst32=true, vst33=true,
	},
	slopeplacer={
		[2]={"vst1", "vst2"},
		[3]={"vst31", "vst32", "vst33"},
		max=3,--highest entry
	},
	slopeplacer_45={
		[2]={"vst1_45", "vst2_45"},
		max=2,
	},
	rotation={"", "_30", "_45", "_60"},
	increativeinv={},
}
ap.t_30deg_straightonly={
	regstep=1,
	variant={
		st=conns(0,8),
	},
	description={
		st="straight",
	},
	switch={
	},
	switchmc={
	},
	regtp=true,
	trackplacer={
	},
	tpsingle={
	},
	tpdefault="st",
	trackworker={
		["st"]="st",
	},
	slopenodes={},
	rotation={"", "_30", "_45", "_60"},
	increativeinv={st},
}
ap.t_30deg_straightonly_noplacer={
	regstep=1,
	variant={
		st=conns(0,8),
	},
	description={
		st="straight",
	},
	switch={
	},
	switchmc={
	},
	regtp=false,
	trackplacer={
	},
	tpsingle={
	},
	tpdefault="st",
	trackworker={
		["st"]="st",
	},
	slopenodes={},
	rotation={"", "_30", "_45", "_60"},
	increativeinv={st},
}
ap.t_45deg={
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
	description={
		st="straight",
		cr="curve",
		swlst="left switch (straight)",
		swlcr="left switch (curve)",
		swrst="right switch (straight)",
		swrcr="right switch (curve)",
		vst1="vertical lower node",
		vst2="vertical upper node",
	},
	switch={
		swlst="swlcr",
		swlcr="swlst",
		swrst="swrcr",
		swrcr="swrst",
	},
	switchmc={
		swlst="on",
		swlcr="off",
		swrst="on",
		swrcr="off",
	},
	switchst={
		swlst="st",
		swlcr="cr",
		swrst="st",
		swrcr="cr",
	},
	regtp=true,
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
	slopenodes={},
	rotation={"", "_45"},
	increativeinv={vst1=true, vst2=true}
}
advtrains.trackpresets = ap

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
	local function make_switchfunc(suffix_target, mesecon_state, is_state)
		local switchfunc=function(pos, node, newstate)
			if newstate~=is_state then
				advtrains.ndb.swap_node(pos, {name=def.nodename_prefix.."_"..suffix_target, param2=node.param2})
			end
			advtrains.invalidate_all_paths()
		end
		local mesec
		if mesecon_state then -- if mesecons is not wanted, do not.
			mesec = {effector = {
				["action_"..mesecon_state] = switchfunc,
				rules=advtrains.meseconrules
			}}
		end
		return switchfunc, mesec,
		{ 
			getstate = is_state,
			setstate = switchfunc,
		}
	end
	local function make_overdef(suffix, rotation, conns, switchfunc, mesecontbl, luaautomation, in_creative_inv, drop_slope)
		local img_suffix=suffix..rotation
		return {
			mesh = def.shared_model or (def.models_prefix.."_"..img_suffix..def.models_suffix),
			tiles = {def.shared_texture or (def.texture_prefix.."_"..img_suffix..".png")},
			--inventory_image = def.texture_prefix.."_"..img_suffix..".png",
			--wield_image = def.texture_prefix.."_"..img_suffix..".png",
			description=def.description.."("..preset.description[suffix]..rotation..")",
			connect1=conns.conn1,
			connect2=conns.conn2,
			rely1=conns.rely1 or 0,
			rely2=conns.rely2 or 0,
			railheight=conns.railheight or 0,
			
			on_rightclick=switchfunc,
			groups = {
				attached_node=1,
				["advtrains_track_"..tracktype]=1,
				save_in_nodedb=1,
				dig_immediate=2,
				not_in_creative_inventory=(not in_creative_inv and 1 or nil),
				not_blocking_trains=1,
			},
			mesecons=mesecontbl,
			luaautomation=luaautomation,
			drop = increativeinv and def.nodename_prefix.."_"..suffix..rotation or (drop_slope and def.nodename_prefix.."_slopeplacer" or def.nodename_prefix.."_placer"),
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
		rely1=0,
		rely2=0,
		railheight=0,
		drop=def.nodename_prefix.."_placer",
		can_dig=function(pos)
			return not advtrains.get_train_at_pos(pos)
		end,
		after_dig_node=function(pos)
			advtrains.invalidate_all_paths()
			advtrains.ndb.update(pos)
		end,
		after_place_node=function(pos)
			advtrains.ndb.update(pos)
		end,
	}, def.common or {})
	--make trackplacer base def
	advtrains.trackplacer.register_tracktype(def.nodename_prefix, preset.tpdefault)
	if preset.regtp then
		advtrains.trackplacer.register_track_placer(def.nodename_prefix, def.texture_prefix, def.description)			
	end
	if preset.regsp then
		advtrains.slope.register_placer(def, preset)			
	end
	for suffix, conns in pairs(preset.variant) do
		for rotid, rotation in ipairs(preset.rotation) do
			if not def.formats[suffix] or def.formats[suffix][rotid] then
				local switchfunc, mesecontbl, luaautomation
				if preset.switch[suffix] then
					switchfunc, mesecontbl, luaautomation=make_switchfunc(preset.switch[suffix]..rotation, preset.switchmc[suffix], preset.switchst[suffix])
				end
				local adef={}
				if def.get_additional_definiton then
					adef=def.get_additional_definiton(def, preset, suffix, rotation)
				end

				minetest.register_node(def.nodename_prefix.."_"..suffix..rotation, advtrains.merge_tables(
					common_def, 
					make_overdef(
						suffix, rotation,
						cycle_conns(conns, rotid),
						switchfunc, mesecontbl, luaautomation, preset.increativeinv[suffix], preset.slopenodes[suffix]
						),
					adef
					)
				)
				--trackplacer
				if preset.regtp then
					if preset.trackplacer[suffix] then
						advtrains.trackplacer.add_double_conn(def.nodename_prefix, suffix, rotation, cycle_conns(conns, rotid))
					end
					if preset.tpsingle[suffix] then
						advtrains.trackplacer.add_single_conn(def.nodename_prefix, suffix, rotation, cycle_conns(conns, rotid))
					end
				end
				advtrains.trackplacer.add_worked(def.nodename_prefix, suffix, rotation, preset.trackworker[suffix])
			end
		end
	end
	advtrains.all_tracktypes[tracktype]=true
end


function advtrains.is_track_and_drives_on(nodename, drives_on_p)
	if not minetest.registered_nodes[nodename] then
		return false
	end
	local nodedef=minetest.registered_nodes[nodename]
	for k,v in pairs(drives_on_p) do
		if nodedef.groups["advtrains_track_"..k] then
			return true
		end
	end
	return false
end

function advtrains.get_track_connections(name, param2)
	local nodedef=minetest.registered_nodes[name]
	if not nodedef then atprint(" get_track_connections couldn't find nodedef for nodename "..(name or "nil")) return 0, 8, 0, 0, 0 end
	local noderot=param2
	if not param2 then noderot=0 end
	if noderot > 3 then atprint(" get_track_connections: rail has invaild param2 of "..noderot) noderot=0 end
	
	local tracktype
	for k,_ in pairs(nodedef.groups) do
		local tt=string.match(k, "^advtrains_track_(.+)$")
		if tt then
			tracktype=tt
		end
	end
	return (nodedef.connect1 + 4 * noderot)%16, (nodedef.connect2  + 4 * noderot)%16, nodedef.rely1 or 0, nodedef.rely2 or 0, nodedef.railheight or 0, tracktype
end

--detector code
--holds a table with nodes on which trains are on.

advtrains.detector = {}
advtrains.detector.on_node = {}

function advtrains.detector.enter_node(pos, train_id)
	local ppos=advtrains.round_vector_floor_y(pos)
	local pts=minetest.hash_node_position(ppos)
	advtrains.detector.on_node[pts]=train_id
	advtrains.detector.call_enter_callback(ppos, train_id)
end
function advtrains.detector.leave_node(pos, train_id)
	local ppos=advtrains.round_vector_floor_y(pos)
	local pts=minetest.hash_node_position(ppos)
	advtrains.detector.on_node[pts]=nil
	advtrains.detector.call_leave_callback(ppos, train_id)
end
function advtrains.detector.stay_node(pos, train_id)
	local ppos=advtrains.round_vector_floor_y(pos)
	local pts=minetest.hash_node_position(ppos)
	advtrains.detector.on_node[pts]=train_id
end



function advtrains.detector.call_enter_callback(pos, train_id)
	--atprint("instructed to call enter calback")

	local node = minetest.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_enter then
		mregnode.advtrains.on_train_enter(pos, train_id)
	end
	
	--atc code wants to be notified too
	advtrains.atc.trigger_controller_train_enter(pos, train_id)
end
function advtrains.detector.call_leave_callback(pos, train_id)
	--atprint("instructed to call leave calback")

	local node = minetest.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_leave then
		mregnode.advtrains.on_train_leave(pos, train_id)
	end 
end

-- slope placer. Defined in register_tracks.
--crafted with rail and gravel
local sl={}
function sl.register_placer(def, preset)
	minetest.register_craftitem(def.nodename_prefix.."_slopeplacer",{
		description = attrans("@1 Slope", def.description),
		inventory_image = def.texture_prefix.."_slopeplacer.png",
		wield_image = def.texture_prefix.."_slopeplacer.png",
		groups={},
		on_place = sl.create_slopeplacer_on_place(def, preset)
	})
end
--(itemstack, placer, pointed_thing)
function sl.create_slopeplacer_on_place(def, preset)
	return function(istack, player, pt)
		if not pt.type=="node" then 
			minetest.chat_send_player(player:get_player_name(), attrans("Can't place: not pointing at node"))
			return istack 
		end
		local pos=pt.above
		if not pos then 
			minetest.chat_send_player(player:get_player_name(), attrans("Can't place: not pointing at node"))
			return istack
		end
		local node=minetest.get_node(pos)
		if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to then
			minetest.chat_send_player(player:get_player_name(), attrans("Can't place: space occupied!"))
			return istack
		end
		if minetest.is_protected(pos, player:get_player_name()) then 
			minetest.chat_send_player(player:get_player_name(), attrans("Can't place: protected position!"))
			return istack
		end
		--determine player orientation (only horizontal component)
		--get_look_horizontal may not be available
		local yaw=player.get_look_horizontal and player:get_look_horizontal() or (player:get_look_yaw() - math.pi/2)
		
		--rounding unit vectors is a nice way for selecting 1 of 8 directions since sin(30°) is 0.5.
		dirvec={x=math.floor(math.sin(-yaw)+0.5), y=0, z=math.floor(math.cos(-yaw)+0.5)}
		--translate to direction to look up inside the preset table
		local param2, rot45=({
			[-1]={
				[-1]=2,
				[0]=3,
				[1]=3,
				},
			[0]={
				[-1]=2,
				[1]=0,
				},
			[1]={
				[-1]=1,
				[0]=1,
				[1]=0,
				},
		})[dirvec.x][dirvec.z], dirvec.x~=0 and dirvec.z~=0
		local lookup=preset.slopeplacer
		if rot45 then lookup=preset.slopeplacer_45 end
		
		--go unitvector forward and look how far the next node is
		local step=1
		while step<=lookup.max do
			local node=minetest.get_node(vector.add(pos, dirvec))
			--next node solid?
			if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to or minetest.is_protected(pos, player:get_player_name()) then 
				--do slopes of this distance exist?
				if lookup[step] then
					if minetest.setting_getbool("creative_mode") or istack:get_count()>=step then
						--start placing
						local placenodes=lookup[step]
						while step>0 do
							minetest.set_node(pos, {name=def.nodename_prefix.."_"..placenodes[step], param2=param2})
							if not minetest.setting_getbool("creative_mode") then
								istack:take_item()
							end
							step=step-1
							pos=vector.subtract(pos, dirvec)
						end
					else
						minetest.chat_send_player(player:get_player_name(), attrans("Can't place: Not enough slope items left (@1 required)", step))
					end
				else
					minetest.chat_send_player(player:get_player_name(), attrans("Can't place: There's no slope of length @1",step))
				end
				return istack
			end
			step=step+1
			pos=vector.add(pos, dirvec)
		end
		minetest.chat_send_player(player:get_player_name(), attrans("Can't place: no supporting node at upper end."))
		return itemstack
	end
end

advtrains.slope=sl

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
	description=attrans("Deprecated Track"),
	formats={vst1={}, vst2={}},
}, ap.t_45deg)


advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail.png",
	description=attrans("Track"),
	formats={vst1={true, false, true}, vst2={true, false, true}, vst31={true}, vst32={true}, vst33={true}},
}, ap.t_30deg)

--bumpers
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_bumper",
	texture_prefix="advtrains_dtrack_bumper",
	models_prefix="advtrains_dtrack_bumper",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail.png",
	description=attrans("Bumper"),
	formats={},
}, ap.t_30deg_straightonly)
--legacy bumpers
for _,rot in ipairs({"", "_30", "_45", "_60"}) do
	minetest.register_alias("advtrains:dtrack_bumper"..rot, "advtrains:dtrack_bumper_st"..rot)
end

if mesecon then
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_off",
		texture_prefix="advtrains_dtrack_detector",
		models_prefix="advtrains_dtrack_detector",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_rail.png",
		description=attrans("Detector Rail"),
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.off,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_train_enter=function(pos, train_id)
						minetest.swap_node(pos, {name="advtrains:dtrack_detector_on".."_"..suffix..rotation, param2=minetest.get_node(pos).param2})
						mesecon.receptor_on(pos, advtrains.meseconrules)
					end
				}
			}
		end
	}, ap.t_30deg_straightonly)
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_on",
		texture_prefix="advtrains_dtrack_detector",
		models_prefix="advtrains_dtrack_detector",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_rail_detector_on.png",
		description="Detector(on)(you hacker you)",
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.on,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_train_leave=function(pos, train_id)
						minetest.swap_node(pos, {name="advtrains:dtrack_detector_off".."_"..suffix..rotation, param2=minetest.get_node(pos).param2})
						mesecon.receptor_off(pos, advtrains.meseconrules)
					end
				}
			}
		end
	}, ap.t_30deg_straightonly_noplacer)
end
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

if advtrains.register_replacement_lbms then
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








