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
	-- do in two steps: 
	--  a: predict path and add all nodes to the advtrains.detector.on_node table
	--  b: check for collisions based on these data
	--  (and more)
	local t=os.clock()
	advtrains.detector.on_node={}
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=sid(k)
		advtrains.atprint_context_tid_full=k
		advtrains.train_step_a(k, v, dtime)
	end
	for k,v in pairs(advtrains.trains) do
		advtrains.atprint_context_tid=sid(k)
		advtrains.atprint_context_tid_full=k
		advtrains.train_step_b(k, v, dtime)
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
train step structure:


- legacy stuff
- preparing the initial path and creating index
- setting node coverage old indices
- handle velocity influences:
	- off-track
	- atc
	- player controls
	- environment collision
- update index = move
- create path
- call stay_node on all old positions to register train there, for collision system
- do less important stuff such as checking trainpartload or removing

-- break --
- Call enter_node and leave_node callbacks (required here because stay_node needs to be called on all trains first)
- handle train collisions

]]

function advtrains.train_step_a(id, train, dtime)
	--atprint("--- runcnt ",advtrains.mainloop_runcnt,": index",train.index,"end_index", train.end_index,"| max_iot", train.max_index_on_track, "min_iot", train.min_index_on_track, "<> pe_min", train.path_extent_min,"pe_max", train.path_extent_max)
	if train.min_index_on_track then
		assert(math.floor(train.min_index_on_track)==train.min_index_on_track)
	end
	--- 1. not exactly legacy. required now because of saving ---
	if not train.drives_on or not train.max_speed then
		advtrains.update_trainpart_properties(id)
	end
	--TODO check for all vars to be present
	if not train.velocity then
		train.velocity=0
	end
	if not train.movedir or (train.movedir~=1 and train.movedir~=-1) then
		train.movedir=1
	end
	--- 2. prepare initial path and index if needed ---
	if not train.index then train.index=0 end
	if not train.path then
		if not train.last_pos then
			--no chance to recover
			atwarn("Unable to restore train ",id,": missing last_pos")
			advtrains.trains[id]=nil
			return false
		end
		
		local node_ok=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(train.last_pos), train.drives_on)
		
		if node_ok==nil then
			--block not loaded, do nothing
			atprint("last_pos", advtrains.round_vector_floor_y(train.last_pos), "not loaded and not in ndb, waiting")
			return nil
		elseif node_ok==false then
			atprint("Unable to restore train ",id,": No rail at train's position")
			return false
		end
		
		if not train.last_pos_prev then
			--no chance to recover
			atwarn("Unable to restore train ",id,": missing last_pos_prev")
			advtrains.trains[id]=nil
			return false
		end
		
		local prevnode_ok=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(train.last_pos_prev), train.drives_on)
		
		if prevnode_ok==nil then
			--block not loaded, do nothing
			atprint("last_pos_prev", advtrains.round_vector_floor_y(train.last_pos_prev), "not loaded and not in ndb, waiting")
			return nil
		elseif prevnode_ok==false then
			atprint("Unable to restore train ",id,": No rail at train's position")
			return false
		end
		
		train.index=(train.restore_add_index or 0)+(train.savedpos_off_track_index_offset or 0)
		--restore_add_index is set by save() to prevent trains hopping to next round index. should be between -0.5 and 0.5
		--savedpos_off_track_index_offset is set if train went off track. see below.
		train.path={}
		train.path_dist={}
		train.path[0]=train.last_pos
		train.path[-1]=train.last_pos_prev
		train.path_dist[-1]=vector.distance(train.last_pos, train.last_pos_prev)
		train.path_extent_min=-1
		train.path_extent_max=0
		train.min_index_on_track=-1
		train.max_index_on_track=0
		
		--[[
		Bugfix for trains randomly ignoring ATC rails:
		- Paths have been invalidated. 1 gets executed and ensures an initial path
		- 2a sets train end index. The problem is that path_dist is not known for the whole path, so train end index will be nearly trainlen
		- Since the detector indices are also unknown, they get set to the new (wrong) train_end_index. Enter_node calls are not executed for the nodes that lie in between real end_index and trainlen.
		- The next step, mistake is recognized, train leaves some positions. From there, everything works again.
		To overcome this, we will generate the full required path here so that path_dist is available for get_train_end_index(). 
		]]
		advtrains.pathpredict(id, train, 3, -train.trainlen-3)
	end
	
	--- 2a. set train.end_index which is required in different places, IF IT IS NOT SET YET by STMT afterwards. ---
	---   table entry to avoid triple recalculation ---
	if not train.end_index then
		train.end_index=advtrains.get_train_end_index(train)
	end
	
	--- 2b. set node coverage old indices ---
	
	train.detector_old_index = atround(train.index)
	train.detector_old_end_index = atround(train.end_index)
	
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
	local t_info, train_pos=sid(id), train.path[atround(train.index)]
	if train_pos then
		t_info=t_info.." @"..minetest.pos_to_string(train_pos)
		--atprint("train_pos:",train_pos)
	end
	
	--apply off-track handling:
	local front_off_track=train.max_index_on_track and train.index>train.max_index_on_track
	local back_off_track=train.min_index_on_track and train.end_index<train.min_index_on_track
	local pprint
	
	if front_off_track and back_off_track then--allow movement in both directions
		tarvel_cap=1
	elseif front_off_track then--allow movement only backward
		if train.movedir==1 then
			tarvel_cap=0
		end
		if train.movedir==-1 then
			tarvel_cap=1
		end
	elseif back_off_track then--allow movement only forward
		if train.movedir==1 then
			tarvel_cap=1
		end
		if train.movedir==-1 then
			tarvel_cap=0
		end
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
		train.last_accel=(vdiff*train.movedir)
		train.velocity=train.velocity+vdiff
		if train.active_control then
			train.tarvelocity = train.velocity
		end
	else
		train.last_accel = 0
	end
	
	--- 4. move train ---
	
	train.index=train.index and train.index+(((train.velocity*train.movedir)/(train.path_dist[math.floor(train.index)] or 1))*dtime) or 0
	
	--- 4a. update train.end_index to the new position ---
	train.end_index=advtrains.get_train_end_index(train)
	
	--- 4b calculate how far a path is required ---
	local path_req_dd = 10 -- path required in driving direction
	local path_req_ndd = 4 -- path required against driving direction
	
	-- when using easyBSS (block signalling), we need to make sure that the whole brake distance is known
	if advtrains_easybss then
		local acc_all = t_accel_all[1]
		local acc_eng = t_accel_eng[1]
		local nwagons = #train.trainparts
		local acc = acc_all + (acc_eng*train.locomotives_in_train)/nwagons
		local vel = train.velocity
		local brakedst = (vel*vel) / (2*acc)
		path_req_dd = math.ceil(brakedst+10)
	end
	
	
	local idx_front=math.max(train.index, train.detector_old_index)
	local idx_back=math.min(train.end_index, train.detector_old_end_index)
	local path_req_front, path_req_back
	if train.movedir == 1 then
		path_req_front = atround(idx_front + path_req_dd)
		path_req_back = atround(idx_back - path_req_ndd)
	else
		path_req_front = atround(idx_front + path_req_ndd)
		path_req_back = atround(idx_back - path_req_dd)		
	end
	
	--- 5. extend path as necessary ---
	--why this is an extra function, see under 3.
	advtrains.pathpredict(id, train, path_req_front, path_req_back)
	
	--- 5a. make pos/yaw available for possible recover calls ---
	if train.max_index_on_track<train.index then --whoops, train went too far. the saved position will be the last one that lies on a track, and savedpos_off_track_index_offset will hold how far to go from here
		train.savedpos_off_track_index_offset=atround(train.index)-train.max_index_on_track
		train.last_pos=train.path[train.max_index_on_track]
		train.last_pos_prev=train.path[train.max_index_on_track-1]
		atprint("train is off-track (front), last positions kept at", train.last_pos, "/", train.last_pos_prev)
	elseif train.min_index_on_track+1>train.index then --whoops, train went even more far. same behavior
		train.savedpos_off_track_index_offset=atround(train.index)-train.min_index_on_track
		train.last_pos=train.path[train.min_index_on_track+1]
		train.last_pos_prev=train.path[train.min_index_on_track]
		atprint("train is off-track (back), last positions kept at", train.last_pos, "/", train.last_pos_prev)
	else --regular case
		train.savedpos_off_track_index_offset=nil
		train.last_pos=train.path[math.floor(train.index+1)]
		train.last_pos_prev=train.path[math.floor(train.index)]
	end
	
	--- 5b. Remove path items that are no longer used ---
	-- Necessary since path items are no longer invalidated in save steps
	local del_keep=8
	local offtrack_keep=4
	
	local delete_min=math.min(train.max_index_on_track - offtrack_keep, path_req_back - del_keep)
	local delete_max=math.max(train.min_index_on_track + offtrack_keep, path_req_front + del_keep)
	
	if train.path_extent_min<delete_min then
		--atprint(sid(id),"clearing path min ",train.path_extent_min," to ",delete_min)
		for i=train.path_extent_min,delete_min-1 do
			train.path[i]=nil
			train.path_dist[i]=nil
		end
		train.path_extent_min=delete_min
		train.min_index_on_track=math.max(train.min_index_on_track, delete_min)
	end
	if train.path_extent_max>delete_max then
		--atprint(sid(id),"clearing path max ",train.path_extent_max," to ",delete_max)
		train.path_dist[delete_max]=nil
		for i=delete_max+1,train.path_extent_max do
			train.path[i]=nil
			train.path_dist[i]=nil
		end
		train.path_extent_max=delete_max
		train.max_index_on_track=math.min(train.max_index_on_track, delete_max)
	end
	
	--- 6b. call stay_node to register trains in the location table - actual enter_node stuff is done in step b ---
	
	local ifo, ibo = train.detector_old_index, train.detector_old_end_index
	local path=train.path
	
	for i=ibo, ifo do
		if path[i] then
			advtrains.detector.stay_node(path[i], id)
		end
	end
	
	--- 7. do less important stuff ---
	--check for any trainpart entities if they have been unloaded. do this only if train is near a player, to not spawn entities into unloaded areas
	
	train.check_trainpartload=(train.check_trainpartload or 0)-dtime
	local node_range=(math.max((minetest.settings:get("active_block_range") or 0),1)*16)
	if train.check_trainpartload<=0 then
		local ori_pos=train_pos --see 3a.
		--atprint("[train "..id.."] at "..minetest.pos_to_string(vector.round(ori_pos)))
		
		local should_check=false
		for _,p in ipairs(minetest.get_connected_players()) do
			should_check=should_check or (ori_pos and ((vector.distance(ori_pos, p:getpos())<node_range)))
		end
		if should_check then
			advtrains.update_trainpart_properties(id)
		end
		train.check_trainpartload=2
	end
	--remove?
	if #train.trainparts==0 then
		atprint("[train "..sid(id).."] has empty trainparts, removing.")
		advtrains.detector.leave_node(path[train.detector_old_index], id)
		advtrains.trains[id]=nil
		return
	end
end


function advtrains.train_step_b(id, train, dtime)

	--hacky fix: if train_step_a returned in phase 2, end_index may not be set.
	--just return
	if not train.index or not train.end_index then
		return
	end
	
	--- 6. update node coverage ---
	
	-- when paths get cleared, the old indices set above will be up-to-date and represent the state in which the last run of this code was made
	local ifo, ifn, ibo, ibn = train.detector_old_index, atround(train.index), train.detector_old_end_index, atround(train.end_index)
	--atprint(ifo,">", ifn, "<==>", ibo,">", ibn)
		
	local path=train.path
	
	if train.enter_node_all then
		--field set by create_new_train_at.
		--ensures that new train calls enter_node on all nodes
		for i=ibn, ifn do
			if path[i] then
				advtrains.detector.enter_node(path[i], id)
			end
		end
		train.enter_node_all=nil
	else
		if ifn>ifo then
			for i=ifo+1, ifn do
				if path[i] then
					if advtrains.detector.occupied(path[i], id) then
						--if another train has signed up for this position first, it won't be recognized in train_step_b. So do collision here.
						atprint("Collision detected in enter_node callbacks (front) @",path[i],"with",sid(advtrains.detector.get(path[i], id)))
						advtrains.collide_and_spawn_couple(id, path[i], advtrains.detector.get(path[i], id), false)
					end
					atprint("enter_node (front) @index",i,"@",path[i],"on_node",sid(advtrains.detector.get(path[i], id)))
					advtrains.detector.enter_node(path[i], id)
				end
			end
		elseif ifn<ifo then
			for i=ifn+1, ifo do
				if path[i] then
					advtrains.detector.leave_node(path[i], id)
				end
			end
		end
		if ibn<ibo then
			for i=ibn, ibo-1 do
				if path[i] then
					local pts=minetest.pos_to_string(path[i])
					if advtrains.detector.occupied(path[i], id) then
						--if another train has signed up for this position first, it won't be recognized in train_step_b. So do collision here.
						atprint("Collision detected in enter_node callbacks (back) @",path[i],"with",sid(advtrains.detector.get(path[i], id)))
						advtrains.collide_and_spawn_couple(id, path[i], advtrains.detector.get(path[i], id), true)
					end
					atprint("enter_node (back) @index",i,"@",path[i],"on_node",sid(advtrains.detector.get(path[i], id)))
					advtrains.detector.enter_node(path[i], id)
				end
			end
		elseif ibn>ibo then
			for i=ibo, ibn-1 do
				if path[i] then
					advtrains.detector.leave_node(path[i], id)
				end
			end
		end
	end

	--- 8. check for collisions with other trains and damage players ---
	
	local train_moves=(train.velocity~=0)
	
	if train_moves then
	
		--TO BE REMOVED:
		if not train.extent_h then advtrains.update_trainpart_properties(id) end
		
		local collpos
		local coll_grace=1
		if train.movedir==1 then
			collpos=advtrains.get_real_index_position(train.path, train.index-coll_grace)
		else
			collpos=advtrains.get_real_index_position(train.path, train.end_index+coll_grace)
		end
		if collpos then
			local rcollpos=advtrains.round_vector_floor_y(collpos)
			for x=-train.extent_h,train.extent_h do
				for z=-train.extent_h,train.extent_h do
					local testpos=vector.add(rcollpos, {x=x, y=0, z=z})
					--- 8a Check collision ---
					if advtrains.detector.occupied(testpos, id) then
						--collides
						advtrains.collide_and_spawn_couple(id, testpos, advtrains.detector.get(testpos, id), train.movedir==-1)
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

--returns new id
function advtrains.create_new_train_at(pos, pos_prev)
	local newtrain_id=advtrains.random_id()
	while advtrains.trains[newtrain_id] do newtrain_id=advtrains.random_id() end--ensure uniqueness
	
	advtrains.trains[newtrain_id]={}
	advtrains.trains[newtrain_id].id = newtrain_id
	advtrains.trains[newtrain_id].last_pos=pos
	advtrains.trains[newtrain_id].last_pos_prev=pos_prev
	advtrains.trains[newtrain_id].tarvelocity=0
	advtrains.trains[newtrain_id].velocity=0
	advtrains.trains[newtrain_id].trainparts={}
	
	advtrains.trains[newtrain_id].enter_node_all=true
	
	return newtrain_id
end


function advtrains.get_train_end_index(train)
	return advtrains.get_real_path_index(train, train.trainlen or 2)--this function can be found inside wagons.lua since it's more related to wagons. we just set trainlen as pos_in_train
end

function advtrains.add_wagon_to_train(wagon, train_id, index)
	local train=advtrains.trains[train_id]
	if index then
		table.insert(train.trainparts, index, wagon.unique_id)
	else
		table.insert(train.trainparts, wagon.unique_id)
	end
	--this is not the usual case!!!
	--we may set initialized because the wagon has no chance to step()
	wagon.initialized=true
	--TODO is this art or can we throw it away?
	advtrains.update_trainpart_properties(train_id)
end
function advtrains.update_trainpart_properties(train_id, invert_flipstate)
	local train=advtrains.trains[train_id]
	train.drives_on=advtrains.merge_tables(advtrains.all_tracktypes)
	--FIX: deep-copy the table!!!
	train.max_speed=20
	train.extent_h = 0;
	
	local rel_pos=0
	local count_l=0
	for i, w_id in ipairs(train.trainparts) do
		local wagon=nil
		local shift_dcpl_lock=false
		for aoid,iwagon in pairs(minetest.luaentities) do
			if iwagon.is_wagon and iwagon.unique_id==w_id then
				if wagon then
					--duplicate
					atprint("update_trainpart_properties: Removing duplicate wagon with id="..aoid)
					iwagon.object:remove()
				else
					wagon=iwagon
				end
			end
		end
		if not wagon then
			if advtrains.wagon_save[w_id] then
				--spawn a new and initialize it with the properties from wagon_save
				wagon=minetest.add_entity(train.last_pos, advtrains.wagon_save[w_id].entity_name):get_luaentity()
				if not wagon then
					minetest.chat_send_all("[advtrains] Warning: Wagon "..advtrains.wagon_save[w_id].entity_name.." does not exist. Make sure all required modules are loaded!")
				else
					wagon:init_from_wagon_save(w_id)
				end
			end
		end
		if wagon then
			rel_pos=rel_pos+wagon.wagon_span
			wagon.train_id=train_id
			wagon.pos_in_train=rel_pos
			wagon.pos_in_trainparts=i
			wagon.old_velocity_vector=nil
			if wagon.is_locomotive then
				count_l=count_l+1
			end
			if invert_flipstate then
				wagon.wagon_flipped = not wagon.wagon_flipped
				shift_dcpl_lock, wagon.dcpl_lock = wagon.dcpl_lock, shift_dcpl_lock
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
			
		else
			atwarn("Did not find save data for wagon",w_id,". The wagon will be deleted.")
			--what the hell...
			table.remove(train.trainparts, pit)
		end
	end
	train.trainlen=rel_pos
	train.locomotives_in_train=count_l
end

function advtrains.split_train_at_wagon(wagon)
	--get train
	local train=advtrains.trains[wagon.train_id]
	if not train.path then return end
	
	local real_pos_in_train=advtrains.get_real_path_index(train, wagon.pos_in_train)
	local pos_for_new_train=train.path[math.floor(real_pos_in_train+wagon.wagon_span)]
	local pos_for_new_train_prev=train.path[math.floor(real_pos_in_train+wagon.wagon_span-1)]
	
	--before doing anything, check if both are rails. else do not allow
	if not pos_for_new_train then
		atprint("split_train: pos_for_new_train not set")
		return false
	end
	local node_ok=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(pos_for_new_train), train.drives_on)
	if not node_ok then
		atprint("split_train: pos_for_new_train ",advtrains.round_vector_floor_y(pos_for_new_train_prev)," not loaded or is not a rail")
		return false
	end
	
	if not train.last_pos_prev then
		atprint("split_train: pos_for_new_train_prev not set")
		return false
	end
	
	local prevnode_ok=advtrains.get_rail_info_at(advtrains.round_vector_floor_y(pos_for_new_train), train.drives_on)
	if not prevnode_ok then
		atprint("split_train: pos_for_new_train_prev ", advtrains.round_vector_floor_y(pos_for_new_train_prev), " not loaded or is not a rail")
		return false
	end
	
	--create subtrain
	local newtrain_id=advtrains.create_new_train_at(pos_for_new_train, pos_for_new_train_prev)
	local newtrain=advtrains.trains[newtrain_id]
	--insert all wagons to new train
	for k,v in ipairs(train.trainparts) do
		if k>=wagon.pos_in_trainparts then
			table.insert(newtrain.trainparts, v)
			train.trainparts[k]=nil
		end
	end
	--update train parts
	advtrains.update_trainpart_properties(wagon.train_id)--atm it still is the desierd id.
	advtrains.update_trainpart_properties(newtrain_id)
	train.tarvelocity=0
	newtrain.velocity=train.velocity
	newtrain.tarvelocity=0
	newtrain.enter_node_all=true
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
