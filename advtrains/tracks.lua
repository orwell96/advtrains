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
local function conns(c1, c2, r1, r2) return {{c=c1, y=r1}, {c=c2, y=r2}} end
local function conns3(c1, c2, c3, r1, r2, r3) return {{c=c1, y=r1}, {c=c2, y=r2}, {c=c3, y=r3}} end

advtrains.ap={}
advtrains.ap.t_30deg_flat={
	regstep=1,
	variant={
		st={
			conns = conns(0,8),
			desc = "straight",
			tpdouble = true,
			tpsingle = true,
			trackworker = "cr",
		},
		cr={
			conns = conns(0,7),
			desc = "curve",
			tpdouble = true,
			trackworker = "swlst",
		},
		swlst={
			conns = conns3(0,8,7),
			desc = "left switch (straight)",
			trackworker = "swrst",
			switchalt = "swlcr",
			switchmc = "on",
			switchst = "st",
		},
		swlcr={
			conns = conns3(0,7,8),
			desc = "left switch (curve)",
			trackworker = "swrcr",
			switchalt = "swlst",
			switchmc = "off",
			switchst = "cr",
		},
		swrst={
			conns = conns3(0,8,9),
			desc = "right switch (straight)",
			trackworker = "st",
			switchalt = "swrcr",
			switchmc = "on",
			switchst = "st",
		},
		swrcr={
			conns = conns3(0,9,8),
			desc = "right switch (curve)",
			trackworker = "st",
			switchalt = "swrst",
			switchmc = "off",
			switchst = "cr",
		},
	},
	regtp=true,
	tpdefault="st",
	trackworker={
		["swrcr"]="st",
		["swrst"]="st",
		["cr"]="swlst",
		["swlcr"]="swrcr",
		["swlst"]="swrst",
	},
	rotation={"", "_30", "_45", "_60"},
}
advtrains.ap.t_30deg_slope={
	regstep=1,
	variant={
		vst1={conns = conns(8,0,0,0.5), rail_y = 0.25, desc = "steep uphill 1/2", slope=true},
		vst2={conns = conns(8,0,0.5,1), rail_y = 0.75, desc = "steep uphill 2/2", slope=true},
		vst31={conns = conns(8,0,0,0.33), rail_y = 0.16, desc = "uphill 1/3", slope=true},
		vst32={conns = conns(8,0,0.33,0.66), rail_y = 0.5, desc = "uphill 2/3", slope=true},
		vst33={conns = conns(8,0,0.66,1), rail_y = 0.83, desc = "uphill 3/3", slope=true},
	},
	regsp=true,
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
	trackworker={},
	increativeinv={},
}
advtrains.ap.t_30deg_straightonly={
	regstep=1,
	variant={
		st={
			conns = conns(0,8),
			desc = "straight",
			tpdouble = true,
			tpsingle = true,
			trackworker = "st",
		},
	},
	regtp=true,
	tpdefault="st",
	rotation={"", "_30", "_45", "_60"},
}
advtrains.ap.t_30deg_straightonly_noplacer={
	regstep=1,
	variant={
		st={
			conns = conns(0,8),
			desc = "straight",
			tpdouble = true,
			tpsingle = true,
			trackworker = "st",
		},
	},
	tpdefault="st",
	rotation={"", "_30", "_45", "_60"},
}
advtrains.ap.t_45deg={
	regstep=2,
	variant={
		st={
			conns = conns(0,8),
			desc = "straight",
			tpdouble = true,
			tpsingle = true,
			trackworker = "cr",
		},
		cr={
			conns = conns(0,6),
			desc = "curve",
			tpdouble = true,
			trackworker = "swlst",
		},
		swlst={
			conns = conns3(0,8,6),
			desc = "left switch (straight)",
			trackworker = "swrst",
			switchalt = "swlcr",
			switchmc = "on",
			switchst = "st",
		},
		swlcr={
			conns = conns3(0,6,8),
			desc = "left switch (curve)",
			trackworker = "swrcr",
			switchalt = "swlst",
			switchmc = "off",
			switchst = "cr",
		},
		swrst={
			conns = conns3(0,8,10),
			desc = "right switch (straight)",
			trackworker = "st",
			switchalt = "swrcr",
			switchmc = "on",
			switchst = "st",
		},
		swrcr={
			conns = conns3(0,10,8),
			desc = "right switch (curve)",
			trackworker = "st",
			switchalt = "swrst",
			switchmc = "off",
			switchst = "cr",
		},
	},
	regtp=true,
	tpdefault="st",
	trackworker={
		["swrcr"]="st",
		["swrst"]="st",
		["cr"]="swlst",
		["swlcr"]="swrcr",
		["swlst"]="swrst",
	},
	rotation={"", "_30", "_45", "_60"},
}
advtrains.trackpresets = advtrains.ap

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
}
[18.12.17] Note on new connection system:
In order to support real rail crossing nodes and finally make the trackplacer respect switches, I changed the connection system.
There can be a variable number of connections available. These are specified as tuples {c=<connection>, y=<rely>}
The table "at_conns" consists of {<conn1>, <conn2>...}
the "at_rail_y" property holds the value that was previously called "railheight"
Depending on the number of connections:
2 conns: regular rail
3 conns: switch:
	- when train passes in at conn1, will move out of conn2
	- when train passes in at conn2 or conn3, will move out of conn1
4 conns: cross (or cross switch, depending on arrangement of conns):
	- conn1 <> conn2
	- conn3 <> conn4
]]

function advtrains.register_tracks(tracktype, def, preset)
	advtrains.trackplacer.register_tracktype(def.nodename_prefix, preset.tpdefault)
	if preset.regtp then
		advtrains.trackplacer.register_track_placer(def.nodename_prefix, def.texture_prefix, def.description)			
	end
	if preset.regsp then
		advtrains.slope.register_placer(def, preset)			
	end
	for suffix, var in pairs(preset.variant) do
		for rotid, rotation in ipairs(preset.rotation) do
			if not def.formats[suffix] or def.formats[suffix][rotid] then
				local img_suffix = suffix..rotation
				local ndef = advtrains.merge_tables({
					description=def.description.."("..(var.desc or "any")..rotation..")",
					drawtype = "mesh",
					paramtype="light",
					paramtype2="facedir",
					walkable = false,
					selection_box = {
						type = "fixed",
						fixed = {-1/2, -1/2, -1/2, 1/2, -1/2+1/16, 1/2},
					},
					
					mesh = def.shared_model or (def.models_prefix.."_"..img_suffix..def.models_suffix),
					tiles = {def.shared_texture or (def.texture_prefix.."_"..img_suffix..".png"), def.second_texture},
					
					groups = {
						attached_node=1,
						advtrains_track=1,
						["advtrains_track_"..tracktype]=1,
						save_in_at_nodedb=1,
						dig_immediate=2,
						not_in_creative_inventory=1,
						not_blocking_trains=1,
					},
						
					can_dig=function(pos)
						return not advtrains.get_train_at_pos(pos)
					end,
					after_dig_node=function(pos)
						advtrains.ndb.update(pos)
					end,
					after_place_node=function(pos)
						advtrains.ndb.update(pos)
					end,
					at_nnpref = def.nodename_prefix,
					at_suffix = suffix,
					at_rotation = rotation,
					at_rail_y = var.rail_y
				}, def.common or {})
				
				if preset.regtp then
					ndef.drop = def.nodename_prefix.."_placer"
				end
				if preset.regsp and var.slope then
					ndef.drop = def.nodename_prefix.."_slopeplacer"
				end
				
				--connections
				ndef.at_conns = advtrains.rotate_conn_by(var.conns, (rotid-1)*preset.regstep)
				
				if var.switchalt and var.switchst then
					local switchfunc=function(pos, node, newstate)
						if newstate~=var.switchst then
							advtrains.ndb.swap_node(pos, {name=def.nodename_prefix.."_"..var.switchalt..rotation, param2=node.param2})
							advtrains.invalidate_all_paths(pos)
						end
					end
					ndef.on_rightclick = function(pos, node, player)
						if advtrains.check_turnout_signal_protection(pos, player:get_player_name()) then
							switchfunc(pos, node)
							advtrains.log("Switch", player:get_player_name(), pos)
						end
					end
					if var.switchmc then
						ndef.mesecons = {effector = {
							["action_"..var.switchmc] = switchfunc,
							rules=advtrains.meseconrules
						}}
					end
					ndef.luaautomation = { 
						getstate = var.switchst,
						setstate = switchfunc,
					}
				end
				
				local adef={}
				if def.get_additional_definiton then
					adef=def.get_additional_definiton(def, preset, suffix, rotation)
				end
				ndef = advtrains.merge_tables(ndef, adef)

				minetest.register_node(":"..def.nodename_prefix.."_"..suffix..rotation, ndef)
				--trackplacer
				if preset.regtp then
					local tpconns = {conn1=ndef.at_conns[1].c, conn2=ndef.at_conns[2].c}
					if var.tpdouble then
						advtrains.trackplacer.add_double_conn(def.nodename_prefix, suffix, rotation, tpconns)
					end
					if var.tpsingle then
						advtrains.trackplacer.add_single_conn(def.nodename_prefix, suffix, rotation, tpconns)
					end
				end
				advtrains.trackplacer.add_worked(def.nodename_prefix, suffix, rotation, var.trackworker)
			end
		end
	end
	advtrains.all_tracktypes[tracktype]=true
end

function advtrains.is_track_and_drives_on(nodename, drives_on_p)
	local drives_on = drives_on_p
	if not drives_on then drives_on = advtrains.all_tracktypes end
	local hasentry = false
	for _,_ in pairs(drives_on) do
		hasentry=true
	end
	if not hasentry then drives_on = advtrains.all_tracktypes end
	
	if not minetest.registered_nodes[nodename] then
		return false
	end
	local nodedef=minetest.registered_nodes[nodename]
	for k,v in pairs(drives_on) do
		if nodedef.groups["advtrains_track_"..k] then
			return true
		end
	end
	return false
end

function advtrains.get_track_connections(name, param2)
	local nodedef=minetest.registered_nodes[name]
	if not nodedef then atprint(" get_track_connections couldn't find nodedef for nodename "..(name or "nil")) return nil end
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
	return advtrains.rotate_conn_by(nodedef.at_conns, noderot*AT_CMAX/4), (nodedef.at_rail_y or 0), tracktype
end

-- slope placer. Defined in register_tracks.
--crafted with rail and gravel
local sl={}
function sl.register_placer(def, preset)
	minetest.register_craftitem(":"..def.nodename_prefix.."_slopeplacer",{
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
		if advtrains.is_protected(pos, player:get_player_name()) then 
			minetest.record_protection_violation(pos, player:get_player_name())
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
			if not minetest.registered_nodes[node.name] or not minetest.registered_nodes[node.name].buildable_to or advtrains.is_protected(pos, player:get_player_name()) then 
				--do slopes of this distance exist?
				if lookup[step] then
					if minetest.settings:get_bool("creative_mode") or istack:get_count()>=step then
						--start placing
						local placenodes=lookup[step]
						while step>0 do
							minetest.set_node(pos, {name=def.nodename_prefix.."_"..placenodes[step], param2=param2})
							if not minetest.settings:get_bool("creative_mode") then
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









