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
	
	--prepare ingame API for ATC. Regenerate each time since pos needs to be known
	--If no train, then return false.
	local train_id=advtrains.detector.on_node[ph]
	local train, atc_arrow, tvel
	if train_id then train=advtrains.trains[train_id] end
	if train then 
		if not train.path then
			--we happened to get in between an invalidation step
			--delay
			atlatc.interrupt.add(0,pos,evtdata)
			return
		end
		for index, ppos in pairs(train.path) do
			if vector.equals(advtrains.round_vector_floor_y(ppos), pos) then
				atc_arrow =
						vector.equals(
								advtrains.dirCoordSet(pos, arrowconn),
								advtrains.round_vector_floor_y(train.path[index+train.movedir])
						)
			end
		end
		if atc_arrow==nil then
			atwarn("LuaAutomation ATC rail at", pos, ": Rail not on train's path! Can't determine arrow direction. Assuming +!")
			atc_arrow=true
		end
		tvel=train.velocity
	end
	local customfct={
		atc_send = function(cmd)
			if not train_id then return false end
			advtrains.atc.train_reset_command(train_id)
			train.atc_command=cmd
			train.atc_arrow=atc_arrow
			return true
		end,
		atc_reset = function(cmd)
			if not train_id then return false end
			advtrains.atc.train_reset_command(train_id)
			return true
		end,
		atc_arrow = atc_arrow,
		atc_id = train_id,
		atc_speed = tvel,
	}
	
	atlatc.active.run_in_env(pos, evtdata, customfct)
	
end

advtrains.register_tracks("default", {
	nodename_prefix="advtrains_luaautomation:dtrack",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack_detector",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail_atc.png",
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
				local _, conn1=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
				atlatc.active.nodes[ph].arrowconn=conn1
			end,

			advtrains = {
				on_train_enter = function(pos, train_id)
					--do async. Event is fired in train steps
					atlatc.interrupt.add(0, pos, {type="train", train=true, id=train_id})
				end,
			},
			luaautomation = {
				fire_event=r.fire_event
			}
		}
	end
}, advtrains.trackpresets.t_30deg_straightonly)


atlatc.rail = r
