--damage.lua
--a globalstep that damages players overrolled by trains.

advtrains.player_to_train_mapping={}

local tmr=0
minetest.register_globalstep(function(dtime)
	tmr=tmr-dtime
	if tmr<=0 then
	
	for _, player in pairs(minetest.get_connected_players()) do
		local pos=player:getpos()
		for _, object in pairs(minetest.get_objects_inside_radius(pos, 1)) do
			local le=object:get_luaentity()
			if le and le.is_wagon and le.initialized and le:train() then
				if (not advtrains.player_to_train_mapping[player:get_player_name()] or le.train_id~=advtrains.player_to_train_mapping[player:get_player_name()]) and math.abs(le:train().velocity)>2 then
					--player:punch(object, 1000, {damage={fleshy=3*math.abs(le:train().velocity)}})
					player:set_hp(player:get_hp()-math.abs(le:train().velocity)-3)
				end
			end
		end
	end
	
	tmr=0.5
	end
end)
