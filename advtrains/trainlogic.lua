--trainlogic.lua
--controls train entities stuff about connecting/disconnecting/colliding trains and other things


local benchmark=false
local bm={}
local bmlt=0
local bmsteps=0
local bmstepint=200
atprintbm=function(action, ta)
	if not benchmark then return end
	local t=(os.clock()-ta)*1000
	if not bm[action] then
		bm[action]=t
	else
		bm[action]=bm[action]+t
	end
	bmlt=bmlt+t
end
function endstep()
	if not benchmark then return end
	bmsteps=bmsteps-1
	if bmsteps<=0 then
		bmsteps=bmstepint
		for key, value in pairs(bm) do
			minetest.chat_send_all(key.." "..(value/bmstepint).." ms avg.")
		end
		minetest.chat_send_all("Total time consumed by all advtrains actions per step: "..(bmlt/bmstepint).." ms avg.")
		bm={}
		bmlt=0
	end
end

--acceleration for lever modes (trainhud.lua), per wagon
local t_accel_all={
	[0] = -10,
	[1] = -3,
	[2] = -0.5,
	[4] = 0.5,
}
--acceleration per engine
local t_accel_eng={
	[0] = 0,
	[1] = 0,
	[2] = 0,
	[4] = 1.5,
}

advtrains.mainloop_trainlogic=function(dtime)
	--build a table of all players indexed by pts. used by damage and door system.
	advtrains.playersbypts={}
	for _, player in pairs(minetest.get_connected_players()) do
		if not advtrains.player_to_train_mapping[player:get_player_name()] then
			--players in train are not subject to damage
			local ptspos=minetest.pos_to_string(vector.round(player:getpos()))
			advtrains.playersbypts[ptspos]=player
		end
	end
	--regular train step
	--[[ structure:
	1. make trains calculate their occupation windows when needed (a)
	2. when occupation tells us so, restore the occupation tables (a)
	4. make trains move and update their new occupation windows and write changes
	   to occupation tables (b)
	5. make trains do other stuff (c)
	]]--
	local t=os.clock()
	
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=k
		advtrains.train_ensure_init(k, v)
	end
	
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=k
		advtrains.train_step_b(k, v, dtime)
	end
	
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=k
		advtrains.train_step_c(k, v, dtime)
	end
	
	advtrains.atprint_context_tid=nil
	
	atprintbm("trainsteps", t)
	endstep()
end

minetest.register_on_joinplayer(function(player)
	return advtrains.pcall(function()
		local pname=player:get_player_name()
		local id=advtrains.player_to_train_mapping[pname]
		if id then
			local train=advtrains.trains[id]
			if not train then advtrains.player_to_train_mapping[pname]=nil return end
			--set the player to the train position.
			--minetest will emerge the area and load the objects, which then will call reattach_all().
			--because player is in mapping, it will not be subject to dying.
			player:setpos(train.last_pos_prev)
			--independent of this, cause all wagons of the train which are loaded to reattach their players
			--needed because already loaded wagons won't call reattach_all()
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.train_id==id then
					wagon:reattach_all()
				end
			end
		end
	end)
end)

minetest.register_on_dieplayer(function(player)
	return advtrains.pcall(function()
		local pname=player:get_player_name()
		local id=advtrains.player_to_train_mapping[pname]
		if id then
			local train=advtrains.trains[id]
			if not train then advtrains.player_to_train_mapping[pname]=nil return end
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.train_id==id then
					--when player dies, detach him from the train
					--call get_off_plr on every wagon since we don't know which one he's on.
					wagon:get_off_plr(pname)
				end
			end
		end
	end)
end)

--[[

Zone diagram of a train (copy from occupation.lua!):
              |___| |___| --> Direction of travel
              oo oo+oo oo
=|=======|===|===========|===|=======|===================|========|===
 |SafetyB|CpB|   Train   |CpF|SafetyF|        Brake      |Aware   |
[1]     [2] [3]         [4] [5]     [6]                 [7]      [8]
This mapping from indices in occwindows to zone ids is contained in WINDOW_ZONE_IDS


The occupation system has been abandoned. The constants will still be used
to determine the couple distance
(because of the reverse lookup, the couple system simplifies a lot...)

]]--
-- unless otherwise stated, in meters.
local SAFETY_ZONE = 10
local COUPLE_ZONE = 2 --value in index positions!
local BRAKE_SPACE = 10
local AWARE_ZONE = 10
local WINDOW_ZONE_IDS = {
	2, -- 1 - SafetyB
	4, -- 2 - CpB
	1, -- 3 - Train
	5, -- 4 - CpF
	3, -- 5 - SafetyF
	6, -- 6 - Brake
	7, -- 7 - Aware
}


-- If a variable does not exist in the table, it is assigned the default value
local function assertdef(tbl, var, def)
	if not tbl[var] then
		tbl[var] = def
	end
end


-- Small local util function to recalculate train's end index
local function recalc_end_index(train)
	train.end_index = advtrains.path_get_index_by_offset(train, train.index, -train.trainlen)
end

-- Occupation Callback system
-- see occupation.lua

local function mkcallback(name)
	local callt = {}
	advtrains["te_register_on_"..name] = function(func)
		assertt(func, "function")
		table.insert(callt, func)
	end
	return callt, function(id, train)
		for _,f in ipairs(callt) do
			f(id, train)
		end
	end
end

local callbacks_new_path, run_callbacks_new_path = mkcallback("new_path")
local callbacks_update, run_callbacks_update = mkcallback("update")
local callbacks_create, run_callbacks_create = mkcallback("create")
local callbacks_remove, run_callbacks_remove = mkcallback("remove")


-- train_ensure_init: responsible for creating a state that we can work on, after one of the following events has happened:
-- - the train's path got cleared
-- - save files were loaded
-- Additionally, this gets called outside the step cycle to initialize and/or remove a train, then occ_write_mode is set.
function advtrains.train_ensure_init(id, train)
	train.dirty = true
	if train.no_step then return end

	assertdef(train, "velocity", 0)
	assertdef(train, "tarvelocity", 0)
	assertdef(train, "acceleration", 0)
	assertdef(train, "id", id)
	
	
	if not train.drives_on or not train.max_speed then
		advtrains.update_trainpart_properties(id)
	end
	
	--restore path
	if not train.path then
		if not train.last_pos then
			atwarn("Train",id,": Restoring path failed, no last_pos set! Train will be disabled. You can try to fix the issue in the save file.")
			train.no_step = true
			return
		end
		if not train.last_connid then
			atwarn("Train",id,": Restoring path: no last_connid set! Will assume 1")
		end
		
		local result = advtrains.path_create(train, train.last_pos, train.last_connid or 1, train.last_frac or 0)
		
		if result==false then
			atwarn("Train",id,": Restoring path failed, node at",train.last_pos,"is gone! Train will be disabled. You can try to fix the issue in the save file.")
			train.no_step = true
			return
		elseif result==nil then
			if not train.wait_for_path then
				atwarn("Train",id,": Can't initialize: Waiting for the (yet unloaded) node at",train.last_pos," to be loaded.")
			end
			train.wait_for_path = true
		end
		-- by now, we should have a working initial path
		train.wait_for_path = false
		
		advtrains.update_trainpart_properties(id)
		recalc_end_index(train)
		
		--atdebug("Train",id,": Successfully restored path at",train.last_pos," connid",train.last_connid," frac",train.last_frac)
		
		-- run on_new_path callbacks
		run_callbacks_new_path(id, train)
	end
	
	train.dirty = false -- TODO einbauen!
end

function advtrains.train_step_b(id, train, dtime)
	if train.no_step or train.wait_for_path then return end
	
	-- in this code, we check variables such as path_trk_? and path_dist. We need to ensure that the path is known for the whole 'Train' zone
	advtrains.path_get(train, atfloor(train.index + 2))
	advtrains.path_get(train, atfloor(train.end_index - 1))
	
	--- 3. handle velocity influences ---
	local train_moves=(train.velocity~=0)
	local tarvel_cap
	
	if train.recently_collided_with_env then
		tarvel_cap=0
		train.active_control=false
		if not train_moves then
			train.recently_collided_with_env=nil--reset status when stopped
		end
	end
	if train.locomotives_in_train==0 then
		tarvel_cap=0
	end
	
	--- 3a. this can be useful for debugs/warnings and is used for check_trainpartload ---
	local t_info, train_pos=sid(id), advtrains.path_get(train, atfloor(train.index))
	if train_pos then
		t_info=t_info.." @"..minetest.pos_to_string(train_pos)
		--atprint("train_pos:",train_pos)
	end
	
	--apply off-track handling:
	local front_off_track = train.index>train.path_trk_f
	local back_off_track=train.end_index<train.path_trk_b
	local pprint
	
	if front_off_track then
		tarvel_cap=0
	end
	if back_off_track then -- eventually overrides front_off_track restriction
		tarvel_cap=1
	end
	
	--interpret ATC command and apply auto-lever control when not actively controlled
	local trainvelocity = train.velocity
	if not train.lever then train.lever=3 end
	if train.active_control then
		advtrains.atc.train_reset_command(id)
	else
		local braketar = train.atc_brake_target
		local emerg = false -- atc_brake_target==-1 means emergency brake (BB command)
		if braketar == -1 then
			braketar = 0
			emerg = true
		end
		if braketar and braketar>=trainvelocity then
			train.atc_brake_target=nil
			braketar = nil
		end
		if train.atc_wait_finish then
			if not train.atc_brake_target and train.velocity==train.tarvelocity then
				train.atc_wait_finish=nil
			end
		end
		if train.atc_command then
			if train.atc_delay<=0 and not train.atc_wait_finish then
				advtrains.atc.execute_atc_command(id, train)
			else
				train.atc_delay=train.atc_delay-dtime
			end
		end
		
		train.lever = 3
		if train.tarvelocity>trainvelocity then train.lever=4 end
		if train.tarvelocity<trainvelocity then
			if (braketar and braketar<trainvelocity) then
				if emerg then
					train.lever = 0
				else
					train.lever=1
				end
			else
				train.lever=2
			end
		end
	end
	
	if tarvel_cap and tarvel_cap<train.tarvelocity then
		train.tarvelocity=tarvel_cap
	end
	local tmp_lever = train.lever
	if tarvel_cap and trainvelocity>tarvel_cap then
		tmp_lever = 0
	end
	
	--- 3a. actually calculate new velocity ---
	if tmp_lever~=3 then
		local acc_all = t_accel_all[tmp_lever]
		local acc_eng = t_accel_eng[tmp_lever]
		local nwagons = #train.trainparts
		local accel = acc_all + (acc_eng*train.locomotives_in_train)/nwagons
		local vdiff = accel*dtime
		if not train.active_control then
			local tvdiff = train.tarvelocity - trainvelocity
			if math.abs(vdiff) > math.abs(tvdiff) then
				--applying this change would cross tarvelocity
				vdiff=tvdiff
			end
		end
		if tarvel_cap and trainvelocity<=tarvel_cap and trainvelocity+vdiff>tarvel_cap then
			vdiff = tarvel_cap - train.velocity
		end
		if trainvelocity+vdiff < 0 then
			vdiff = - trainvelocity
		end
		local mspeed = (train.max_speed or 10)
		if trainvelocity+vdiff > mspeed then
			vdiff = mspeed - trainvelocity
		end
		train.acceleration=vdiff
		train.velocity=train.velocity+vdiff
		if train.active_control then
			train.tarvelocity = train.velocity
		end
	else
		train.acceleration = 0
	end
	
	--- 4. move train ---
	
	train.index=train.index and train.index+((train.velocity/(train.path_dist[math.floor(train.index)] or 1))*dtime) or 0
	recalc_end_index(train)

end

function advtrains.train_step_c(id, train, dtime)
if train.no_step or train.wait_for_path then return end
	
	-- all location/extent-critical actions have been done.
	-- calculate the new occupation window
	run_callbacks_update(id, train)
	
	advtrains.path_clear_unused(train)
	
	advtrains.path_setrestore(train)
	
	-- less important stuff
	
	train.check_trainpartload=(train.check_trainpartload or 0)-dtime
	if train.check_trainpartload<=0 then
		advtrains.spawn_wagons(id)
		train.check_trainpartload=2
	end
	
	--- 8. check for collisions with other trains and damage players ---
	
	local train_moves=(train.velocity~=0)
	
	--- Check whether this train can be coupled to another, and set couple entities accordingly
	if not train.was_standing and not train_moves then
		advtrains.train_check_couples(train)
	end
	train.was_standing = not train_moves
	
	if train_moves then
		
		local collided = false
		local coll_grace=1
		local collindex = advtrains.path_get_index_by_offset(train, train.index, -coll_grace)
		local collpos = advtrains.path_get(train, atround(collindex))
		if collpos then
			local rcollpos=advtrains.round_vector_floor_y(collpos)
			for x=-train.extent_h,train.extent_h do
				for z=-train.extent_h,train.extent_h do
					local testpos=vector.add(rcollpos, {x=x, y=0, z=z})
					--- 8a Check collision ---
					if not collided and advtrains.occ.check_collision(testpos, id) then
						--collides
						train.velocity = 0
						train.tarvelocity = 0
						collided = true
					end
					--- 8b damage players ---
					if not minetest.settings:get_bool("creative_mode") then
						local testpts = minetest.pos_to_string(testpos)
						local player=advtrains.playersbypts[testpts]
						if player and not minetest.check_player_privs(player, "creative") and train.velocity>3 then
							--instantly kill player
							--drop inventory contents first, to not to spawn bones
							local player_inv=player:get_inventory()
							for i=1,player_inv:get_size("main") do
								minetest.add_item(testpos, player_inv:get_stack("main", i))
							end
							for i=1,player_inv:get_size("craft") do
								minetest.add_item(testpos, player_inv:get_stack("craft", i))
							end
							-- empty lists main and craft
							player_inv:set_list("main", {})
							player_inv:set_list("craft", {})
							player:set_hp(0)
						end
					end
				end
			end
			--- 8c damage other objects ---
			local objs = minetest.get_objects_inside_radius(rcollpos, 2)
			for _,obj in ipairs(objs) do
				if not obj:is_player() and obj:get_armor_groups().fleshy and obj:get_armor_groups().fleshy > 0 
						and obj:get_luaentity() and obj:get_luaentity().name~="signs:text" then
					obj:punch(obj, 1, { full_punch_interval = 1.0, damage_groups = {fleshy = 1000}, }, nil)
				end
			end
		end
	end
end

-- Default occupation callbacks for node callbacks
-- (remember, train.end_index is set separately because callbacks are
--  asserted to rely on this)

local function tnc_call_enter_callback(pos, train_id)
	--atdebug("tnc enter",pos,train_id)
	local node = advtrains.ndb.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_enter then
		mregnode.advtrains.on_train_enter(pos, train_id)
	end
end
local function tnc_call_leave_callback(pos, train_id)
	--atdebug("tnc leave",pos,train_id)
	local node = advtrains.ndb.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_leave then
		mregnode.advtrains.on_train_leave(pos, train_id)
	end 
end

advtrains.te_register_on_new_path(function(id, train)
	train.tnc = {
		old_index = atround(train.index),
		old_end_index = atround(train.end_index),
	}
	--atdebug(id,"tnc init",train.index,train.end_index)
end)

advtrains.te_register_on_update(function(id, train)
	local new_index = atround(train.index)
	local new_end_index = atround(train.end_index)
	local old_index = train.tnc.old_index
	local old_end_index = train.tnc.old_end_index
	while old_index < new_index do
		old_index = old_index + 1
		local pos = advtrains.round_vector_floor_y(advtrains.path_get(train,old_index))
		tnc_call_enter_callback(pos, id)
	end
	while old_end_index < new_end_index do
		local pos = advtrains.round_vector_floor_y(advtrains.path_get(train,old_end_index))
		tnc_call_leave_callback(pos, id)
		old_end_index = old_end_index + 1
	end
	train.tnc.old_index = new_index
	train.tnc.old_end_index = new_end_index
end)

advtrains.te_register_on_create(function(id, train)
	local index = atround(train.index)
	local end_index = atround(train.end_index)
	while end_index <= index do
		local pos = advtrains.round_vector_floor_y(advtrains.path_get(train,end_index))
		tnc_call_enter_callback(pos, id)
		end_index = end_index + 1
	end
	--atdebug(id,"tnc create",train.index,train.end_index)
end)

advtrains.te_register_on_remove(function(id, train)
	local index = atround(train.index)
	local end_index = atround(train.end_index)
	while end_index <= index do
		local pos = advtrains.round_vector_floor_y(advtrains.path_get(train,end_index))
		tnc_call_leave_callback(pos, id)
		end_index = end_index + 1
	end
	--atdebug(id,"tnc remove",train.index,train.end_index)
end)

-- Calculates the indices where the window borders of the occupation windows are.
-- TODO adapt this code to new system, probably into a callback (probably only the brake distance code is needed)
local function calc_occwindows(id, train)
	local end_index = advtrains.path_get_index_by_offset(train, train.index, -train.trainlen)
	train.end_index = end_index
	local cpl_b = end_index - COUPLE_ZONE
	local safety_b = advtrains.path_get_index_by_offset(train, cpl_b, -SAFETY_ZONE)
	local cpl_f = end_index + COUPLE_ZONE
	local safety_f = advtrains.path_get_index_by_offset(train, cpl_f, SAFETY_ZONE)
	
	-- calculate brake distance
	local acc_all = t_accel_all[1]
	local acc_eng = t_accel_eng[1]
	local nwagons = #train.trainparts
	local acc = acc_all + (acc_eng*train.locomotives_in_train)/nwagons
	local vel = train.velocity
	local brakedst = (vel*vel) / (2*acc)
	
	local brake_i = math.max(advtrains.path_get_index_by_offset(train, train.index, brakedst + BRAKE_SPACE), safety_f)
	local aware_i = advtrains.path_get_index_by_offset(train, brake_i, AWARE_ZONE)
	
	return {
		safety_b,
		cpl_b,
		end_index,
		train.index,
		cpl_f,
		safety_f,
		brake_i,
		aware_i,
	}
end


--returns new id
function advtrains.create_new_train_at(pos, connid, ioff, trainparts)
	local new_id=advtrains.random_id()
	while advtrains.trains[new_id] do new_id=advtrains.random_id() end--ensure uniqueness
	
	local t={}
	t.id = new_id
	
	t.last_pos=pos
	t.last_connid=connid
	t.last_frac=ioff
	
	t.tarvelocity=0
	t.velocity=0
	t.trainparts=trainparts
	
	advtrains.trains[new_id] = t
	--atdebug("Created new train:",t)
	
	advtrains.train_ensure_init(new_id, advtrains.trains[new_id])
	
	run_callbacks_create(new_id, advtrains.trains[new_id])
	
	return new_id
end

function advtrains.remove_train(id)
	local train = advtrains.trains[id]
	
	advtrains.train_ensure_init(id, train)
	
	run_callbacks_remove(id, train)
	
	advtrains.path_invalidate(train)
	advtrains.couple_invalidate(train)
	
	local tp = train.trainparts
	--atdebug("Removing train",id,"leftover trainparts:",tp)
	
	advtrains.trains[id] = nil
	
	return tp
	
end


function advtrains.add_wagon_to_train(wagon_id, train_id, index)
	local train=advtrains.trains[train_id]
	
	advtrains.train_ensure_init(train_id, train)
	
	if index then
		table.insert(train.trainparts, index, wagon_id)
	else
		table.insert(train.trainparts, wagon_id)
	end
	
	advtrains.update_trainpart_properties(train_id)
	recalc_end_index(train)
	run_callbacks_update(train_id, train)
end

function advtrains.safe_decouple_wagon(w_id, pname)
	if not minetest.check_player_privs(pname, "train_operator") then
		minetest.chat_send_player(pname, "Missing train_operator privilege")
		return false
	end
	local data = advtrains.wagons[w_id]
	if data.dcpl_lock then
		minetest.chat_send_player(pname, "Couple is locked (ask owner or admin to unlock it)")
		return false
	end
	atprint("wagon:discouple() Splitting train", data.train_id)
	local train = advtrains.trains[data.train_id]
	advtrains.log("Discouple", pname, train.last_pos, train.text_outside)
	advtrains.split_train_at_wagon(w_id)
	return true
end

-- this function sets wagon's pos_in_train(parts) properties and train's max_speed and drives_on (and more)
function advtrains.update_trainpart_properties(train_id, invert_flipstate)
	local train=advtrains.trains[train_id]
	train.drives_on=advtrains.merge_tables(advtrains.all_tracktypes)
	--FIX: deep-copy the table!!!
	train.max_speed=20
	train.extent_h = 0;
	
	local rel_pos=0
	local count_l=0
	local shift_dcpl_lock=false
	for i, w_id in ipairs(train.trainparts) do
		
		local data = advtrains.wagons[w_id]
		
		-- 1st: update wagon data (pos_in_train a.s.o)
		if data then
			local wagon = advtrains.wagon_prototypes[data.type]
			if not wagon then
				atwarn("Wagon '",data.type,"' couldn't be found. Please check that all required modules are loaded!")
				wagon = advtrains.wagon_prototypes["advtrains:wagon_placeholder"]
			end
			
			rel_pos=rel_pos+wagon.wagon_span
			data.train_id=train_id
			data.pos_in_train=rel_pos
			data.pos_in_trainparts=i
			if wagon.is_locomotive then
				count_l=count_l+1
			end
			if invert_flipstate then
				data.wagon_flipped = not data.wagon_flipped
				shift_dcpl_lock, data.dcpl_lock = data.dcpl_lock, shift_dcpl_lock
			end
			rel_pos=rel_pos+wagon.wagon_span
			
			if wagon.drives_on then
				for k,_ in pairs(train.drives_on) do
					if not wagon.drives_on[k] then
						train.drives_on[k]=nil
					end
				end
			end
			train.max_speed=math.min(train.max_speed, wagon.max_speed)
			train.extent_h = math.max(train.extent_h, wagon.extent_h or 1);
		end
	end
	train.trainlen = rel_pos
	train.locomotives_in_train = count_l
end


local ablkrng = minetest.settings:get("active_block_range")*16
-- This function checks whether entities need to be spawned for certain wagons, and spawns them.
function advtrains.spawn_wagons(train_id)
	local train = advtrains.trains[train_id]
	
	for i = 1, #train.trainparts do
		local w_id = train.trainparts[i]
		local data = advtrains.wagons[w_id]
		if data then
			if data.train_id ~= train_id then
				atwarn("Train",train_id,"Wagon #",1,": Saved train ID",data.train_id,"did not match!")
				data.train_id = train_id
			end
			if not advtrains.wagon_objects[w_id] or not advtrains.wagon_objects[w_id]:getyaw() then
				-- eventually need to spawn new object. check if position is loaded.
				local index = advtrains.path_get_index_by_offset(train, train.index, -data.pos_in_train)
				local pos   = advtrains.path_get(train, atfloor(index))
				
				local spawn = false
				for _,p in pairs(minetest.get_connected_players()) do
					if vector.distance(p:get_pos(),pos)<=ablkrng then
						spawn = true
					end
				end
				
				if spawn then
					local wt = advtrains.get_wagon_prototype(data)
					local wagon = minetest.add_entity(pos, wt):get_luaentity()
					wagon:set_id(w_id)
				end
			end
		else
			atwarn("Train",train_id,"Wagon #",1,": A wagon with id",w_id,"does not exist! Wagon will be removed from train.")
			table.remove(train.trainparts, i)
			i = i - 1
		end
	end
end
		

function advtrains.split_train_at_wagon(wagon_id)
	--get train
	local data = advtrains.wagons[wagon_id]
	local old_id = data.train_id
	local train=advtrains.trains[old_id]
	local _, wagon = advtrains.get_wagon_prototype(data)
	
	advtrains.train_ensure_init(old_id, train)
	
	local index=advtrains.path_get_index_by_offset(train, train.index, - data.pos_in_train + wagon.wagon_span)
	
	-- find new initial path position for this train
	local pos, connid, frac = advtrains.path_getrestore(train, index)
	
	-- build trainparts table, passing it directly to the train constructor
	local tp = {}
	for k,v in ipairs(train.trainparts) do
		if k >= data.pos_in_trainparts then
			table.insert(tp, v)
			train.trainparts[k]=nil
		end
	end
	
	--update train parts
	advtrains.update_trainpart_properties(old_id)
	recalc_end_index(train)
	run_callbacks_update(old_id, train)
	
	--create subtrain
	local newtrain_id=advtrains.create_new_train_at(pos, connid, frac, tp)
	local newtrain=advtrains.trains[newtrain_id]
	
	train.tarvelocity=0
	newtrain.velocity=train.velocity
	newtrain.tarvelocity=0
	
	newtrain.couple_lck_back=train.couple_lck_back
	newtrain.couple_lck_front=false
	train.couple_lck_back=false
	
end

-- coupling
local CPL_CHK_DST = -1
local CPL_ZONE = 2

-- train.couple_* contain references to ObjectRefs of couple objects, which contain all relevant information
-- These objectRefs will delete themselves once the couples no longer match
local function createcouple(pos, train1, t1_is_front, train2, t2_is_front)
	local obj=minetest.add_entity(pos, "advtrains:couple")
	if not obj then error("Failed creating couple object!") return end
	local le=obj:get_luaentity()
	le.train_id_1=train1.id
	le.train_id_2=train2.id
	le.t1_is_front=t1_is_front
	le.t2_is_front=t2_is_front
	--atdebug("created couple between",train1.id,t1_is_front,train2.id,t2_is_front)
	if t1_is_front then
		train1.cpl_front = obj
	else
		train1.cpl_back = obj
	end
	if t2_is_front then
		train2.cpl_front = obj
	else
		train2.cpl_back = obj
	end
	
end

function advtrains.train_check_couples(train)
	--atdebug("rechecking couples")
	if train.cpl_front then
		if not train.cpl_front:getyaw() then
			-- objectref is no longer valid. reset.
			train.cpl_front = nil
		end
	end
	if not train.cpl_front then
		-- recheck front couple
		local front_trains, pos = advtrains.occ.get_occupations(train, atround(train.index) + CPL_CHK_DST)
		for tid, idx in pairs(front_trains) do
			local other_train = advtrains.trains[tid]
			advtrains.train_ensure_init(tid, other_train)
			--atdebug(train.id,"front: ",idx,"on",tid,atround(other_train.index),atround(other_train.end_index))
			if other_train.velocity == 0 then
				if idx>=other_train.index and idx<=other_train.index + CPL_ZONE then
					createcouple(pos, train, true, other_train, true)
					break
				end
				if idx<=other_train.end_index and idx>=other_train.end_index - CPL_ZONE then
					createcouple(pos, train, true, other_train, false)
					break
				end
			end
		end
	end
	if train.cpl_back then
		if not train.cpl_back:getyaw() then
			-- objectref is no longer valid. reset.
			train.cpl_back = nil
		end
	end
	if not train.cpl_back then
		-- recheck back couple
		local back_trains, pos = advtrains.occ.get_occupations(train, atround(train.end_index) - CPL_CHK_DST)
		for tid, idx in pairs(back_trains) do
			local other_train = advtrains.trains[tid]
			advtrains.train_ensure_init(tid, other_train)
			if other_train.velocity == 0 then
				if idx>=other_train.index and idx<=other_train.index + CPL_ZONE then
					createcouple(pos, train, false, other_train, true)
					break
				end
				if idx<=other_train.end_index and idx>=other_train.end_index - CPL_ZONE then
					createcouple(pos, train, false, other_train, false)
					break
				end
			end
		end
	end
end

function advtrains.couple_invalidate(train)
	if train.cpl_back then
		train.cpl_back:remove()
		train.cpl_back = nil
	end
	if train.cpl_front then
		train.cpl_front:remove()
		train.cpl_front = nil
	end
	train.was_standing = nil
end

-- relevant code for this comment is in couple.lua

--there are 4 cases:
--1/2. F<->R F<->R regular, put second train behind first
--->frontpos of first train will match backpos of second
--3.   F<->R R<->F flip one of these trains, take the other as new train
--->backpos's will match
--4.   R<->F F<->R flip one of these trains and take it as new parent
--->frontpos's will match


function advtrains.do_connect_trains(first_id, second_id)
	local first, second=advtrains.trains[first_id], advtrains.trains[second_id]
	
	advtrains.train_ensure_init(first_id, first)
	advtrains.train_ensure_init(second_id, second)
	
	if first.couple_lck_back or second.couple_lck_front then
		-- trains are ordered correctly!
		-- Note, this is already checked in the rightclick step of the couple entity before trains are actually reversed
		return
	end
	
	local first_wagoncnt=#first.trainparts
	local second_wagoncnt=#second.trainparts
	
	for _,v in ipairs(second.trainparts) do
		table.insert(first.trainparts, v)
	end
	
	local tmp_cpl_lck=second.couple_lck_back
	
	advtrains.remove_train(second_id)
	
	first.velocity=0
	first.tarvelocity=0
	first.couple_lck_back=tmp_cpl_lck
	
	advtrains.update_trainpart_properties(first_id)
	advtrains.couple_invalidate(first)
	return true
end

function advtrains.invert_train(train_id)
	local train=advtrains.trains[train_id]
	
	advtrains.train_ensure_init(train_id, train)
	
	advtrains.path_setrestore(train, true)
	
	-- rotate some other stuff
	train.couple_lck_back, train.couple_lck_front = train.couple_lck_front, train.couple_lck_back
	if train.door_open then
		train.door_open = - train.door_open
	end
	
	advtrains.path_invalidate(train)
	advtrains.couple_invalidate(train)
	
	local old_trainparts=train.trainparts
	train.trainparts={}
	for k,v in ipairs(old_trainparts) do
		table.insert(train.trainparts, 1, v)--notice insertion at first place
	end
	advtrains.update_trainpart_properties(train_id, true)
end

-- returns: train id, index of one of the trains that stand at this position.
function advtrains.get_train_at_pos(pos)
	local t = advtrains.occ.get_trains_at(pos)
	for tid,idx in pairs(t) do
		return tid, idx
	end
end

function advtrains.invalidate_all_paths(pos)
	--if a position is given, only invalidate inside a radius to save performance
	local inv_radius=50
	atprint("invalidating all paths")
	for k,v in pairs(advtrains.trains) do
		local exec=true
		if pos and v.path and v.index and v.end_index then
			--start and end pos of the train
			local cmp1=v.path[atround(v.index)]
			local cmp2=v.path[atround(v.end_index)]
			if vector.distance(pos, cmp1)>inv_radius and vector.distance(pos, cmp2)>inv_radius then
				exec=false
			end
		end
		if exec then
			advtrains.invalidate_path(k)
		end
	end
end
function advtrains.invalidate_path(id)
	local v=advtrains.trains[id]
	if not v then return end
	advtrains.path_invalidate(v)
	advtrains.couple_invalidate(v)
	v.dirty = true
end

--not blocking trains group
function advtrains.train_collides(node)
	if node and minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].walkable then
		if not minetest.registered_nodes[node.name].groups.not_blocking_trains then
			return true
		end
	end
	return false
end

local nonblocknodes={
	"default:fence_wood",
	"default:fence_acacia_wood",
	"default:fence_aspen_wood",
	"default:fence_pine_wood",
	"default:fence_junglewood",
	"default:torch",
	
	"default:sign_wall",
	"signs:sign_wall",
	"signs:sign_wall_blue",
	"signs:sign_wall_brown",
	"signs:sign_wall_orange",
	"signs:sign_wall_green",
	"signs:sign_yard",
	"signs:sign_wall_white_black",
	"signs:sign_wall_red",
	"signs:sign_wall_white_red",
	"signs:sign_wall_yellow",
	"signs:sign_post",
	"signs:sign_hanging",
	
	
}
minetest.after(0, function()
	for _,name in ipairs(nonblocknodes) do
		if minetest.registered_nodes[name] then
			minetest.registered_nodes[name].groups.not_blocking_trains=1
		end
	end
end)
