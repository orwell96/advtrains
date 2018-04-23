--trainlogic.lua
--controls train entities stuff about connecting/disconnecting/colliding trains and other things

-- TODO: what should happen when a train has no trainparts anymore?

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
		advtrains.atprint_context_tid=sid(k)
		advtrains.atprint_context_tid_full=k
		train_ensure_clean(k, v, dtime)
	end
	
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=sid(k)
		advtrains.atprint_context_tid_full=k
		train_step_b(k, v, dtime)
	end
	
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=sid(k)
		advtrains.atprint_context_tid_full=k
		train_step_c(k, v, dtime)
	end
	
	advtrains.atprint_context_tid=nil
	advtrains.atprint_context_tid_full=nil
	
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
The occupation window system.

Each train occupies certain nodes as certain occupation types. See occupation.lua for a graphic and an ID listing.
There's an occwindows table in the train table. This is clearable, such as the path, and therefore needs to be exactly reconstructible.
During runtime, the extents (in meters) of the zones are determined. the occwindows table holds the assigned fractional path indices.
After the train moves, the occupation windows are re-calculated, and all differences are written to the occupation tables.

Zone diagram of a train (copy from occupation.lua!):
              |___| |___| --> Direction of travel
              oo oo+oo oo
=|=======|===|===========|===|=======|===================|========|===
 |SafetyB|CpB|   Train   |CpF|SafetyF|        Brake      |Aware   |
[1]     [2] [3]         [4] [5]     [6]                 [7]      [8]
This mapping from indices in occwindows to zone ids is contained in WINDOW_ZONE_IDS

occwindows = {
[n] = (index of the position determined in the graphic above,
	where floor(i) belongs to the left zone and floor(i+1) belongs to the right.
}

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


-- Calculates the indices where the window borders of the occupation windows are.
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

-- this function either inits (no write_mode), sets(1) or clears(2) the occupations for train
local function write_occupation(win, train_id, train, write_mode)
	local n_window = 2
	local c_index = math.ceil(win[1])
	while win[n_window] do
		local winix = win[n_window]
		local oid = WINDOW_ZONE_IDS[n_windows - 1]
		while winix > c_index do
			local pos = advtrains.path_get(train, c_index)
			if write_mode == 1 then
				advtrains.occ.set_occupation(train_id, pos, oid)
			elseif write_mode == 2 then
				advtrains.occ.clear_occupation(train_id, pos)
			else
				advtrains.occ.init_occupation(train_id, pos, oid)
			end
			c_index = c_index + 1
		end
		c_index = math.ceil(winix)
		n_window = n_window + 1
	end
	
end
local function apply_occupation_changes(old, new, train_id, train)
	-- TODO
end


-- train_ensure_clean: responsible for creating a state that we can work on, after one of the following events has happened:
-- - the train's path got cleared
-- - the occupation table got cleared
-- Additionally, this gets called outside the step cycle to initialize and/or remove a train, then occ_write_mode is set.
local function train_ensure_clean(id, train, dtime, report_occupations, occ_write_mode)
	train.dirty = true
	if train.no_step then return end

	assertdef(train, "velocity", 0)
	assertdef(train, "tarvelocity", 0)
	assertdef(train, "acceleration", 0)
	
	
	if not train.drives_on or not train.max_speed then
		advtrains.update_trainpart_properties(id)
	end
	
	--restore path
	if not train.path then
		if not train.last_pos then
			atwarn("Train",id": Restoring path failed, no last_pos set! Train will be disabled. You can try to fix the issue in the save file.")
			train.no_step = true
			return
		end
		if not train.last_connid then
			atwarn("Train",id": Restoring path failed, no last_connid set! Will assume 1")
		end
		
		local result = advtrains.path_create(train, train.last_pos, train.last_connid, train.last_frac or 0)
		
		if result==false then
			atwarn("Train",id": Restoring path failed, node at",train.last_pos,"is gone! Train will be disabled. You can try to fix the issue in the save file.")
			train.no_step = true
			return
		elseif result==nil then
			if not train.wait_for_path then
				atwarn("Train",id": Can't initialize: Waiting for the (yet unloaded) node at",train.last_pos," to be loaded.")
			end
			train.wait_for_path = true
		end
		-- by now, we should have a working initial path
		train.occwindows = nil
		advtrains.update_trainpart_properties(id)
		-- TODO recoverposition?!
	end
	
	--restore occupation windows
	if not train.occwindows then
		train.occwindows = calc_occwindows(id, train)
	end
	if report_occupations then
		write_occupation(train.occwindows, train, occ_write_mode)
	end
	
	train.dirty = false -- TODO einbauen!
end

local function train_step_b(id, train, dtime)
	if train.no_step or train.wait_for_path then return end
	
	-- in this code, we check variables such as path_trk_? and path_dist. We need to ensure that the path is known for the whole 'Train' zone
	advtrains.path_get(train, train.index + 1)
	advtrains.path_get(train, train.end_index - 1)
	
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
	local t_info, train_pos=sid(id), advtrains.path_get(atfloor(train.index))
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
		if train.atc_brake_target and train.atc_brake_target>=trainvelocity then
			train.atc_brake_target=nil
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
			if (train.atc_brake_target and train.atc_brake_target<trainvelocity) then
				train.lever=1
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
		train.last_accel = 0
	end
	
	--- 4. move train ---
	
	train.index=train.index and train.index+((train.velocity/(train.path_dist[math.floor(train.index)] or 1))*dtime) or 0

end

local function train_recalc_occupation()
	local new_occwindows = calc_occwindows(id, train)
	apply_occupation_changes(train.occwindows, new_occwindows, id)
	train.occwindows = new_occwindows
end

local function train_step_c(id, train, dtime)
if train.no_step or train.wait_for_path then return end
	
	-- all location/extent-critical actions have been done.
	-- calculate the new occupation window
	train_recalc_occupation(id, train)
	
	advtrains.path_clear_unused(train)
	
	-- Set our path restoration position
	local fli = atfloor(train.index)
	train.last_pos = advtrains.path_get(fli)
	train.last_connid = train.path_cn[fli]
	train.last_frac = train.index - fli
	
	-- less important stuff
	
	train.check_trainpartload=(train.check_trainpartload or 0)-dtime
	if train.check_trainpartload<=0 then
		advtrains.spawn_wagons(id)
		train.check_trainpartload=2
	end
	
	--- 8. check for collisions with other trains and damage players ---
	
	local train_moves=(train.velocity~=0)
	
	if train_moves then
		
		local collpos
		local coll_grace=1
		collpos=advtrains.path_get_index_by_offset(train, train.index-coll_grace)
		if collpos then
			local rcollpos=advtrains.round_vector_floor_y(collpos)
			for x=-train.extent_h,train.extent_h do
				for z=-train.extent_h,train.extent_h do
					local testpos=vector.add(rcollpos, {x=x, y=0, z=z})
					--- 8a Check collision ---
					if advtrains.occ.check_collision(testpos, id) then
						--collides
						--advtrains.collide_and_spawn_couple(id, testpos, advtrains.detector.get(testpos, id), train.movedir==-1)
						train.velocity = 0
						train.tarvelocity = 0
						atwarn("Train",id,"collided!")
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

--TODO: Collisions!


--returns new id
function advtrains.create_new_train_at(pos, connid, ioff, trainparts)
	local new_id=advtrains.random_id()
	while advtrains.trains[new_id] do new_id=advtrains.random_id() end--ensure uniqueness
	
	t={}
	t.id = newtrain_id
	
	t.last_pos=pos
	t.last_connid=connid
	t.last_frac=ioff
	
	t.tarvelocity=0
	t.velocity=0
	t.trainparts=trainparts
	
	
	advtrains.trains[new_id] = t
	
	advtrains.update_trainpart_properties(new_id)
	
	train_ensure_clean(new_id, advtrains.trains[new_id], 0, true, 1)
	
	return newtrain_id
end

function advtrains.remove_train(id)
	local train = advtrains.trains[id]
	
	advtrains.update_trainpart_properties(id)
	
	train_ensure_clean(id, train, 0, true, 2)
	
	local tp = train.trainparts
	
	advtrains.trains[id] = nil
	
	return tp
	
end


function advtrains.add_wagon_to_train(wagon_id, train_id, index)
	local train=advtrains.trains[train_id]
	
	train_ensure_clean(train_id, train)
	
	if index then
		table.insert(train.trainparts, index, wagon_id)
	else
		table.insert(train.trainparts, wagon_id)
	end
	
	advtrains.update_trainpart_properties(train_id)
	train_recalc_occupation(train_id, train)
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
			local wagon = minetest.registered_luaentites[data.type]
			if not wagon then
				atwarn("Wagon '",data.type,"' couldn't be found. Please check that all required modules are loaded!")
				wagon = minetest.registered_luaentites["advtrains:wagon_placeholder"]
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
end

-- This function checks whether entities need to be spawned for certain wagons, and spawns them.
function advtrains.spawn_wagons(train_id)
	local train = advtrains.trains[train_id]
	
	for i, w_id in ipairs(train.trainparts) do
		local data = advtrains.wagons[w_id]
		if data then
			if not data.object or not data.object:getyaw() then
				-- eventually need to spawn new object. check if position is loaded.
				local index = advtrains.path_get_index_by_offset(train, train.index, -data.pos_in_train)
				local pos   = advtrains.path_get(train, atfloor(index))
				
				if minetest.get_node_or_nil(pos) then
					local wt = advtrains.get_wagon_prototype(data)
					wagon=minetest.add_entity(pos, wt):get_luaentity()
					wagon:set_id(w_id)
				end
			end
		end
		
		
	end
end
		

function advtrains.split_train_at_wagon(wagon_id)
	--get train
	local data = advtrains.wagons[wagon_id]
	local train=advtrains.trains[data.train_id]
	local _, wagon = advtrains.get_wagon_prototype(data)
	
	train_ensure_clean(data.train_id, train)
	
	local index=advtrains.path_get_index_by_offset(train, train.index, -(data.pos_in_train + wagon.wagon_span))
	
	if index < train.path_trk_b or index > train.path_trk_f then
		atprint("split_train: pos_for_new_train is off-track") -- TODO function for finding initial positions from a path
		return false
	end
	
	local pos, _, frac = advtrains.path_get_adjacent(train, index)
	local nconn = train.path_cn[atfloor(index)]
	--before doing anything, check if both are rails. else do not allow
	if not pos then
		atprint("split_train: pos_for_new_train not set")
		return false
	end
	local npos = advtrains.round_vector_floor_y(pos)
	local node_ok=advtrains.get_rail_info_at(npos, train.drives_on)
	if not node_ok then
		atprint("split_train: pos_for_new_train ",advtrains.round_vector_floor_y(pos_for_new_train_prev)," not loaded or is not a rail")
		return false
	end
	
	-- build trainparts table, passing it directly to the train constructor
	local tp = {}
	for k,v in ipairs(train.trainparts) do
		if k>=wagon.pos_in_trainparts then
			table.insert(tp, v)
			train.trainparts[k]=nil
		end
	end
	
	--create subtrain
	local newtrain_id=advtrains.create_new_train_at(npos, nconn, frac, tp)
	local newtrain=advtrains.trains[newtrain_id]
	
	--update train parts
	advtrains.update_trainpart_properties(data.train_id)--atm it still is the desierd id.
	
	train.tarvelocity=0
	newtrain.velocity=train.velocity
	newtrain.tarvelocity=0
	
	newtrain.couple_lck_back=train.couple_lck_back
	newtrain.couple_lck_front=false
	train.couple_lck_back=false
	
end

--there are 4 cases:
--1/2. F<->R F<->R regular, put second train behind first
--->frontpos of first train will match backpos of second
--3.   F<->R R<->F flip one of these trains, take the other as new train
--->backpos's will match
--4.   R<->F F<->R flip one of these trains and take it as new parent
--->frontpos's will match

--true when trains are facing each other. needed on colliding.
-- check done by iterating paths and checking their direction
--returns nil when not on the same track at all OR when required path items are not generated. this distinction may not always be needed.
-- TODO do we need to change this behavior, since direct path accesses are now discouraged?
function advtrains.trains_facing(train1, train2)
	local sr_pos=train1.path[atround(train1.index)]
	local sr_pos_p=train1.path[atround(train1.index)-1]

	for i=advtrains.minN(train2.path), advtrains.maxN(train2.path) do
		if vector.equals(sr_pos, train2.path[i]) then
			if train2.path[i+1] and vector.equals(sr_pos_p, train2.path[i+1]) then return true end
			if train2.path[i-1] and vector.equals(sr_pos_p, train2.path[i-1]) then return false end
			return nil
		end
	end
	return nil
end

function advtrains.collide_and_spawn_couple(id1, pos, id2, t1_is_backpos)
	if minetest.settings:get_bool("advtrains_disable_collisions") then
		return
	end
	
	atprint("COLLISION: ",sid(id1)," and ",sid(id2)," at ",pos,", t1_is_backpos=",(t1_is_backpos and "true" or "false"))
	--TODO:
	local train1=advtrains.trains[id1]
	
	-- do collision
	train1.recently_collided_with_env=true
	train1.velocity=0.5*train1.velocity
	train1.movedir=train1.movedir*-1
	train1.tarvelocity=0
	
	local train2=advtrains.trains[id2]
	
	if not train1 or not train2 then return end
	
	local found
	for i=advtrains.minN(train1.path), advtrains.maxN(train1.path) do
		if vector.equals(train1.path[i], pos) then
			found=true
		end
	end
	if not found then
		atprint("Err: pos not in path. Not spawning a couple")
		return 
	end
	
	local frontpos2=train2.path[atround(train2.detector_old_index)]
	local backpos2=train2.path[atround(train2.detector_old_end_index)]
	local t2_is_backpos
	atprint("End positions: ",frontpos2,backpos2)
	
	t2_is_backpos = vector.distance(backpos2, pos) < vector.distance(frontpos2, pos)
	
	atprint("t2_is_backpos="..(t2_is_backpos and "true" or "false"))
	
	local t1_has_couple, t1_couple_lck
	if t1_is_backpos then
		t1_has_couple=train1.couple_eid_back
		t1_couple_lck=train1.couple_lck_back
	else
		t1_has_couple=train1.couple_eid_front
		t1_couple_lck=train1.couple_lck_front
	end
	local t2_has_couple, t2_couple_lck
	if t2_is_backpos then
		t2_has_couple=train2.couple_eid_back
		t2_couple_lck=train2.couple_lck_back
	else
		t2_has_couple=train2.couple_eid_front
		t2_couple_lck=train2.couple_lck_front
	end
	
	if t1_has_couple then
		if minetest.object_refs[t1_has_couple] then minetest.object_refs[t1_has_couple]:remove() end
	end
	if t2_has_couple then
		if minetest.object_refs[t2_has_couple] then minetest.object_refs[t2_has_couple]:remove() end
	end
	if t1_couple_lck or t2_couple_lck then
		minetest.add_entity(pos, "advtrains:lockmarker")
		return
	end
	local obj=minetest.add_entity(pos, "advtrains:couple")
	if not obj then atprint("failed creating object") return end
	local le=obj:get_luaentity()
	le.train_id_1=id1
	le.train_id_2=id2
	le.train1_is_backpos=t1_is_backpos
	le.train2_is_backpos=t2_is_backpos
	--find in object_refs
	local p_aoi
	for aoi, compare in pairs(minetest.object_refs) do
		if compare==obj then
			if t1_is_backpos then
				train1.couple_eid_back=aoi
			else
				train1.couple_eid_front=aoi
			end
			if t2_is_backpos then
				train2.couple_eid_back=aoi
			else
				train2.couple_eid_front=aoi
			end
			p_aoi=aoi
		end
	end
	atprint("Couple spawned (ActiveObjectID ",p_aoi,")")
end
--order of trains may be irrelevant in some cases. check opposite cases. TODO does this work?
--pos1 and pos2 are just needed to form a median.


function advtrains.do_connect_trains(first_id, second_id, player)
	local first, second=advtrains.trains[first_id], advtrains.trains[second_id]
	
	if not first or not second or not first.index or not second.index or not first.end_index or not second.end_index then
		return false
	end
	
	if first.couple_lck_back or second.couple_lck_front then
		-- trains are ordered correctly!
		if player then
			minetest.chat_send_player(player:get_player_name(), "Can't couple: couples locked!")
		end
		return
	end
	
	local first_wagoncnt=#first.trainparts
	local second_wagoncnt=#second.trainparts
	
	for _,v in ipairs(second.trainparts) do
		table.insert(first.trainparts, v)
	end
	--kick it like physics (with mass being #wagons)
	local new_velocity=((first.velocity*first_wagoncnt)+(second.velocity*second_wagoncnt))/(first_wagoncnt+second_wagoncnt)
	local tmp_cpl_lck=second.couple_lck_back
	advtrains.trains[second_id]=nil
	advtrains.update_trainpart_properties(first_id)
	local train1=advtrains.trains[first_id]
	train1.velocity=new_velocity
	train1.tarvelocity=0
	train1.couple_eid_front=nil
	train1.couple_eid_back=nil
	train1.couple_lck_back=tmp_cpl_lck
	return true
end

-- TODO
function advtrains.invert_train(train_id)
	local train=advtrains.trains[train_id]
	
	local old_path=train.path
	local old_path_dist=train.path_dist
	train.path={}
	train.path_dist={}
	train.index, train.end_index= -train.end_index, -train.index
	train.path_extent_min, train.path_extent_max = -train.path_extent_max, -train.path_extent_min
	train.min_index_on_track, train.max_index_on_track = -train.max_index_on_track, -train.min_index_on_track
	train.detector_old_index, train.detector_old_end_index = -train.detector_old_end_index, -train.detector_old_index
	train.couple_lck_back, train.couple_lck_front = train.couple_lck_front, train.couple_lck_back 
	
	train.velocity=-train.velocity
	train.tarvelocity=-train.tarvelocity
	for k,v in pairs(old_path) do
		train.path[-k]=v
		train.path_dist[-k-1]=old_path_dist[k]
	end
	local old_trainparts=train.trainparts
	train.trainparts={}
	for k,v in ipairs(old_trainparts) do
		table.insert(train.trainparts, 1, v)--notice insertion at first place
	end
	advtrains.update_trainpart_properties(train_id, true)
end

function advtrains.get_train_at_pos(pos)
	return advtrains.detector.get(pos)
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
	--TODO duplicate code in init.lua avt_save()!
	if v.index then
		v.restore_add_index=v.index-math.floor(v.index+1)
	end
	v.path=nil
	v.path_dist=nil
	v.index=nil
	v.end_index=nil
	v.min_index_on_track=nil
	v.max_index_on_track=nil
	v.path_extent_min=nil
	v.path_extent_max=nil

	v.detector_old_index=nil
	v.detector_old_end_index=nil
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
