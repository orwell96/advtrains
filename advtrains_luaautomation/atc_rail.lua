-- atc_rail.lua
-- registers and handles the ATC rail. Active component.
-- This is the only component that can interface with trains, so train interface goes here too.

--Using subtable
local r={}

function r.fire_event(pos, evtdata)
	
	local ph=minetest.pos_to_string(pos)
	local railtbl = atlatc.active.nodes[ph]
	
	if not railtbl then
		atwarn("LuaAutomation ATC interface rail at",ph,": Data not in memory! Please visit position and click 'Save'!")
		return
	end
	
	
	local arrowconn = railtbl.arrowconn
	if not arrowconn then
		atwarn("LuaAutomation ATC interface rail at",ph,": Incomplete Data! Please visit position and click 'Save'!")
		return
	end
	
	--prepare ingame API for ATC. Regenerate each time since pos needs to be known
	--If no train, then return false.
	local train_id=advtrains.get_train_at_pos(pos)
	local train, atc_arrow, tvel
	if train_id then train=advtrains.trains[train_id] end
	if train then 
		if not train.path then
			--we happened to get in between an invalidation step
			--delay
			atlatc.interrupt.add(0,pos,evtdata)
			return
		end
		local index = advtrains.path_lookup(train, pos)
				
		local iconnid = 1
		if index then
			iconnid = train.path_cn[index]
		else
			atwarn("ATC rail at", pos, ": Rail not on train's path! Can't determine arrow direction. Assuming +!")
		end
		atc_arrow = iconnid == 1
		
		tvel=train.velocity
	end
	local customfct={
		atc_send = function(cmd)
			if not train_id then return false end
			assertt(cmd, "string")
			advtrains.atc.train_reset_command(train_id)
			train.atc_command=cmd
			train.atc_arrow=atc_arrow
			return true
		end,
		set_line = function(line)
		   train.line = line
		   return true
		end,
		atc_reset = function(cmd)
			if not train_id then return false end
			assertt(cmd, "string")
			advtrains.atc.train_reset_command(train_id)
			return true
		end,
		atc_arrow = atc_arrow,
		atc_id = train_id,
		atc_speed = tvel,
		atc_set_text_outside = function(text)
			if not train_id then return false end
			if text then assertt(text, "string") end
			advtrains.trains[train_id].text_outside=text
			return true
		end,
		atc_set_text_inside = function(text)
			if not train_id then return false end
			if text then assertt(text, "string") end
			advtrains.trains[train_id].text_inside=text
			return true
		end,
	}
	
	atlatc.active.run_in_env(pos, evtdata, customfct)
	
end

advtrains.register_tracks("default", {
	nodename_prefix="advtrains_luaautomation:dtrack",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_atc.png",
	description=atltrans("LuaAutomation ATC Rail"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
			after_place_node = atlatc.active.after_place_node,
			after_dig_node = atlatc.active.after_dig_node,

			on_receive_fields = function(pos, ...)
				atlatc.active.on_receive_fields(pos, ...)
				
				--set arrowconn (for ATC)
				local ph=minetest.pos_to_string(pos)
				local _, conns=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
				atlatc.active.nodes[ph].arrowconn=conns[1].c
			end,

			advtrains = {
				on_train_enter = function(pos, train_id)
					--do async. Event is fired in train steps
					atlatc.interrupt.add(0, pos, {type="train", train=true, id=train_id})
				end,
			},
			luaautomation = {
				fire_event=r.fire_event
			},
			digiline = {
				receptor = {},
				effector = {
					action = atlatc.active.on_digiline_receive
				},
			},
		}
	end,
}, advtrains.trackpresets.t_30deg_straightonly)


atlatc.rail = r
