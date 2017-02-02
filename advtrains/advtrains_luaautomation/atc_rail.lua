-- atc_rail.lua
-- registers and handles the ATC rail. Active component.
-- This is the only component that can interface with trains, so train interface goes here too.

--Using subtable
local r={}

function r.fire_event(pos, evtdata)
	
	local ph=minetest.hash_node_position(pos)
	local railtbl = atlatc.active.nodes[ph] or {}
	
	local arrowconn = railtbl.arrowconn
	
	--prepare ingame API for ATC. Regenerate each time since pos needs to be known
	local atc_valid, atc_arrow
	local train_id=advtrains.detector.on_node[ph]
	local train=advtrains.trains[train_id]
	if not train then return false end
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
			atc_valid = true
		end
	end
	local customfct={
		atc_send = function(cmd)
			advtrains.atc.train_reset_command(train_id)
			if atc_valid then
				train.atc_command=cmd
				train.atc_arrow=atc_arrow
				return atc_valid
			end
		end,
		atc_reset = function(cmd)
			advtrains.atc.train_reset_command(train_id)
			return true
		end,
		atc_arrow = atc_arrow
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
				local ph=minetest.hash_node_position(pos)
				local _, conn1=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
				atlatc.active.nodes[ph].arrowconn=conn1
			end,

			advtrains = {
				on_train_enter = function(pos, train_id)
					--do async. Event is fired in train steps
					atlatc.interrupt.add(0, pos, {type="train", id=train_id})
				end,
			},
			luaautomation = {
				fire_event=r.fire_event
			}
		}
	end
}, advtrains.trackpresets.t_30deg_straightonly)


atlatc.rail = r
