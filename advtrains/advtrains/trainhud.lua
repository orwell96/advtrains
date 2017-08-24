--trainhud.lua: holds all the code for train controlling

advtrains.hud = {}

minetest.register_on_leaveplayer(function(player)
advtrains.hud[player:get_player_name()] = nil
end)

local mletter={[1]="F", [-1]="R", [0]="N"}
local doorstr={[-1]="|<>| >|<", [0]=">|< >|<", [1]=">|< |<>|"}

function advtrains.on_control_change(pc, train, flip)
   	local maxspeed = train.max_speed or 10
	if pc.sneak then
		if pc.up then
			train.tarvelocity = maxspeed
		end
		if pc.down then
			train.tarvelocity = 0
		end
		if pc.left then
			train.tarvelocity = 4
		end
		if pc.right then
			train.tarvelocity = 8
		end
		if pc.jump then
			train.brake = true
			--0: released, 1: brake and pressed, 2: released and brake, 3: pressed and brake
			if not train.brake_hold_state or train.brake_hold_state==0 then
				train.brake_hold_state = 1
			elseif train.brake_hold_state==2 then
				train.brake_hold_state = 3
			end
		elseif train.brake_hold_state==1 then
			train.brake_hold_state = 2
		elseif train.brake_hold_state==3 then
			train.brake = false
			train.brake_hold_state = 0
		end
		--shift+use:see wagons.lua
	else
		if pc.up then
		   train.tarvelocity = math.min(train.tarvelocity + 1, maxspeed)
		end
		if pc.down then
			if train.velocity>0 then
				train.tarvelocity = math.max(train.tarvelocity - 1, 0)
			else
				train.movedir = -train.movedir
			end
		end
		if pc.left then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = -train.movedir
			end
		end
		if pc.right then
			if train.door_open ~= 0 then
				train.door_open = 0
			else
				train.door_open = train.movedir
			end
		end
		if train.brake_hold_state~=2 then
			train.brake = false
		end
		if pc.jump then
			train.brake = true
		end
		if pc.aux1 then
			--horn
		end
	end
end
function advtrains.update_driver_hud(pname, train, flip)
	local inside=train.text_inside or ""
	advtrains.set_trainhud(pname, inside.."\n"..advtrains.hud_train_format(train, flip))
end
function advtrains.clear_driver_hud(pname)
	advtrains.set_trainhud(pname, "")
end

function advtrains.set_trainhud(name, text)
	local hud = advtrains.hud[name]
	local player=minetest.get_player_by_name(name)
	if not player then
	   return
	end
	if not hud then
		hud = {}
		advtrains.hud[name] = hud
		hud.id = player:hud_add({
			hud_elem_type = "text",
			name = "ADVTRAINS",
			number = 0xFFFFFF,
			position = {x=0.5, y=0.7},
			offset = {x=0, y=0},
			text = text,
			scale = {x=200, y=60},
			alignment = {x=0, y=0},
		})
		hud.oldText=text
		return
	elseif hud.oldText ~= text then
		player:hud_change(hud.id, "text", text)
		hud.oldText=text
	end
end
function advtrains.hud_train_format(train, flip)
	local fct=flip and -1 or 1
	if not train then return "" end
	
	local max=train.max_speed or 10
	local vel=advtrains.abs_ceil(train.velocity)
	local tvel=advtrains.abs_ceil(train.tarvelocity)
	local vel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.velocity))
	local tvel_kmh=advtrains.abs_ceil(advtrains.ms_to_kmh(train.tarvelocity))
	local topLine, firstLine, secondLine
	
	topLine="  ["..mletter[fct*train.movedir].."]  "..doorstr[(train.door_open or 0) * train.movedir].."  "..(train.brake and "="..( train.brake_hold_state==2 and "^" or "" ).."B=" or "")
	firstLine=attrans("Speed:").." |"..string.rep("+", vel)..string.rep("_", max-vel).."> "..vel_kmh.." km/h"
	secondLine=attrans("Target:").." |"..string.rep("+", tvel)..string.rep("_", max-tvel).."> "..tvel_kmh.." km/h"
	
	return topLine.."\n"..firstLine.."\n"..secondLine
end
