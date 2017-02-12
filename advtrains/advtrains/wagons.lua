--atan2 counts angles clockwise, minetest does counterclockwise

minetest.register_privilege("train_place", {
	description = "Player can place trains on tracks not owned by player",
	give_to_singleplayer= false,
});
minetest.register_privilege("train_remove", {
	description = "Player can remove trains not owned by player",
	give_to_singleplayer= false,
});

local wagon={
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	--physical = true,
	visual = "mesh",
	mesh = "wagon.b3d",
	visual_size = {x=3, y=3},
	textures = {"black.png"},
	is_wagon=true,
	wagon_span=1,--how many index units of space does this wagon consume
	has_inventory=false,
}


function wagon:train()
	return advtrains.trains[self.train_id]
end

--[[about 'initalized':
	when initialized is false, the entity hasn't got any data yet and should wait for these to be set before doing anything
	when loading an existing object (with staticdata), it will be set
	when instanciating a new object via add_entity, it is not set at the time on_activate is called.
	then, wagon:initialize() will be called
	
	wagon will save only uid in staticdata, no serialized table
]]
function wagon:on_activate(sd_uid, dtime_s)
	if sd_uid~="" then
		--destroy when loaded from static block.
		self.object:remove()
		return
	end
	self.object:set_armor_groups({immortal=1})
	self.entity_name=self.name
end

function wagon:get_staticdata()
	if not self:ensure_init() then return end
	atprint("[wagon "..((self.unique_id and self.unique_id~="" and self.unique_id) or "no-id").."]: saving to wagon_save")
	--serialize inventory, if it has one
	if self.has_inventory then
		local inv=minetest.get_inventory({type="detached", name="advtrains_wgn_"..self.unique_id})
		self.ser_inv=advtrains.serialize_inventory(inv)
	end
	--save to table before being unloaded
	advtrains.wagon_save[self.unique_id]=advtrains.merge_tables(self)
	advtrains.wagon_save[self.unique_id].entity_name=self.name
	advtrains.wagon_save[self.unique_id].name=nil
	advtrains.wagon_save[self.unique_id].object=nil
	return self.unique_id
end
--returns: uid of wagon
function wagon:init_new_instance(train_id, properties)
	self.unique_id=os.time()..os.clock()
	self.train_id=train_id
	for k,v in pairs(properties) do
		if k~="name" and k~="object" then
			self[k]=v
		end
	end
	self:init_shared()
	self.initialized=true
	atprint("init_new_instance "..self.unique_id.." ("..self.train_id..")")
	return self.unique_id
end
function wagon:init_from_wagon_save(uid)
	if not advtrains.wagon_save[uid] then
		self.object:remove()
		return
	end
	self.unique_id=uid
	for k,v in pairs(advtrains.wagon_save[uid]) do
		if k~="name" and k~="object" then
			self[k]=v
		end
	end
	if not self.train_id or not self:train() then
		self.object:remove()
		return
	end
	self:init_shared()
	self.initialized=true
	minetest.after(0.2, function() self:reattach_all() end)
	atprint("init_from_wagon_save "..self.unique_id.." ("..self.train_id..")")
end
function wagon:init_shared()
	if self.has_inventory then
		local uid_noptr=self.unique_id..""
		--to be used later
		local inv=minetest.create_detached_inventory("advtrains_wgn_"..self.unique_id, {
			allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				return count
			end,
			allow_put = function(inv, listname, index, stack, player)
				return stack:get_count()
			end,
			allow_take = function(inv, listname, index, stack, player)
				return stack:get_count()
			end
		})
		if self.ser_inv then
			advtrains.deserialize_inventory(self.ser_inv, inv)
		end
		if self.inventory_list_sizes then
			for lst, siz in pairs(self.inventory_list_sizes) do
				inv:set_size(lst, siz)
			end
		end
	end
	if self.doors then
		self.door_anim_timer=0
		self.door_state=0
	end
	if self.custom_on_activate then
		self:custom_on_activate(dtime_s)
	end
end
function wagon:ensure_init()
	if self.initialized then
		if self.noninitticks then self.noninitticks=nil end
		return true
	end
	if not self.noninitticks then self.noninitticks=0 end
	self.noninitticks=self.noninitticks+1
	if self.noninitticks>20 then
		self.object:remove()
	else
		self.object:setvelocity({x=0,y=0,z=0})
	end
	return false
end

-- Remove the wagon
function wagon:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not self:ensure_init() then return end
	if not puncher or not puncher:is_player() then
		return
	end
	if self.owner and puncher:get_player_name()~=self.owner and (not minetest.check_player_privs(puncher, {train_remove = true })) then
	   minetest.chat_send_player(puncher:get_player_name(), attrans("This wagon is owned by @1, you can't destroy it.", self.owner));
	   return
	end
	
	if minetest.setting_getbool("creative_mode") then
		if not self:destroy() then return end
		
		local inv = puncher:get_inventory()
		if not inv:contains_item("main", self.name) then
			inv:add_item("main", self.name)
		end
	else
		local pc=puncher:get_player_control()
		if not pc.sneak then
			minetest.chat_send_player(puncher:get_player_name(), attrans("Warning: If you destroy this wagon, you only get some steel back! If you are sure, shift-leftclick the wagon."))
			return
		end

		if not self:destroy() then return end

		local inv = puncher:get_inventory()
		for _,item in ipairs(self.drops or {self.name}) do
			inv:add_item("main", item)
		end
	end
end
function wagon:destroy()
	--some rules:
	-- you get only some items back
	-- single left-click shows warning
	-- shift leftclick destroys
	-- not when a driver is inside
	
	for _,_ in pairs(self.seatp) do
		return
	end
	
	if self.custom_may_destroy then
		if not self.custom_may_destroy(self, puncher, time_from_last_punch, tool_capabilities, direction) then
			return
		end
	end
	if self.custom_on_destroy then
		self.custom_on_destroy(self, puncher, time_from_last_punch, tool_capabilities, direction)
	end
	
	atprint("[wagon "..((self.unique_id and self.unique_id~="" and self.unique_id) or "no-id").."]: destroying")
	
	self.object:remove()

	table.remove(self:train().trainparts, self.pos_in_trainparts)
	advtrains.update_trainpart_properties(self.train_id)
	advtrains.wagon_save[self.unique_id]=nil
	if self.discouple then self.discouple.object:remove() end--will have no effect on unloaded objects
	return true
end


function wagon:on_step(dtime)
	if not self:ensure_init() then return end
	
	local t=os.clock()
	local pos = self.object:getpos()
	
	if not pos then
		atprint("["..self.unique_id.."][fatal] missing position (object:getpos() returned nil)")
		return
	end

	self.entity_name=self.name
	
	--is my train still here
	if not self.train_id or not self:train() then
		atprint("[wagon "..self.unique_id.."] missing train_id, destroying")
		self.object:remove()
		return
	elseif not self.initialized then
		self.initialized=true
	end
	if not self.seatp then
		self.seatp={}
	end

	--custom on_step function
	if self.custom_on_step then
		self:custom_on_step(self, dtime)
	end

	--driver control
	for seatno, seat in ipairs(self.seats) do
		if seat.driving_ctrl_access then
			local driver=self.seatp[seatno] and minetest.get_player_by_name(self.seatp[seatno])
			local get_off_pressed=false
			if driver and driver:get_player_control_bits()~=self.old_player_control_bits then
				local pc=driver:get_player_control()
				
				advtrains.on_control_change(pc, self:train(), self.wagon_flipped)
				if pc.aux1 and pc.sneak then
					get_off_pressed=true
				end
				
				self.old_player_control_bits=driver:get_player_control_bits()
			end
			if driver then
				if get_off_pressed then
					self:get_off(seatno)
				else
					advtrains.update_driver_hud(driver:get_player_name(), self:train(), self.wagon_flipped)
				end
			end
		else
		   local pass = self.seatp[seatno] and minetest.get_player_by_name(self.seatp[seatno])
		   if pass and self:train().door_open~=0 then
		      local pc=pass:get_player_control()
		      if pc.up or pc.down then
			 self:get_off(seatno)
		      end
		   end		      
		end
	end

	local gp=self:train()
	
	--door animation
	if self.doors then
		if (self.door_anim_timer or 0)<=0 then
			local fct=self.wagon_flipped and -1 or 1
			local dstate = (gp.door_open or 0) * fct
			if dstate ~= self.door_state then
				local at
				--meaning of the train.door_open field:
				-- -1: left doors (rel. to train orientation)
				--  0: closed
				--  1: right doors
				--this code produces the following behavior:
				-- if changed from 0 to +-1, play open anim. if changed from +-1 to 0, play close.
				-- if changed from +-1 to -+1, first close and set 0, then it will detect state change again and run open.
				if self.door_state == 0 then
					at=self.doors.open[dstate]
					self.object:set_animation(at.frames, at.speed or 15, at.blend or 0, false)
					self.door_state = dstate
				else
					at=self.doors.close[self.door_state or 1]--in case it has not been set yet
					self.object:set_animation(at.frames, at.speed or 15, at.blend or 0, false)
					self.door_state = 0
				end
				self.door_anim_timer = at.time
			end
		else
			self.door_anim_timer = (self.door_anim_timer or 0) - dtime
		end
	end
	--DisCouple
	if self.pos_in_trainparts and self.pos_in_trainparts>1 then
		if gp.velocity==0 and not self.lock_couples then
			if not self.discouple or not self.discouple.object:getyaw() then
				local object=minetest.add_entity(pos, "advtrains:discouple")
				if object then
					local le=object:get_luaentity()
					le.wagon=self
					--box is hidden when attached, so unuseful.
					--object:set_attach(self.object, "", {x=0, y=0, z=self.wagon_span*10}, {x=0, y=0, z=0})
					self.discouple=le
				else
					atprint("Couldn't spawn DisCouple")
				end
			end
		else
			if self.discouple and self.discouple.object:getyaw() then
				self.discouple.object:remove()
			end
		end
	end
	--for path to be available. if not, skip step
	if not gp.path then
		self.object:setvelocity({x=0, y=0, z=0})
		return
	end
	if not self.pos_in_train then
		--why ever. but better continue next step...
		advtrains.update_trainpart_properties(self.train_id)
		return
	end
	
	local index=advtrains.get_real_path_index(self:train(), self.pos_in_train)
	--atprint("trainindex "..gp.index.." wagonindex "..index)
	
	--position recalculation
	local first_pos=gp.path[math.floor(index)]
	local second_pos=gp.path[math.floor(index)+1]
	if not first_pos or not second_pos then
		--atprint(" object "..self.unique_id.." path end reached!")
		self.object:setvelocity({x=0,y=0,z=0})
		return
	end
	
	--checking for environment collisions(a 3x3 cube around the center)
	if not gp.recently_collided_with_env then
		local collides=false
		for x=-1,1 do
			for y=0,2 do
				for z=-1,1 do
					local node=minetest.get_node_or_nil(vector.add(first_pos, {x=x, y=y, z=z}))
					if (advtrains.train_collides(node)) then
						collides=true
					end
				end
			end
		end
		if collides then
			if self.collision_count and self.collision_count>10 then
				--enable collision mercy to get trains stuck in walls out of walls
				--actually do nothing except limiting the velocity to 1
				gp.velocity=math.min(gp.velocity, 1)
				gp.tarvelocity=math.min(gp.tarvelocity, 1)
			else
				gp.recently_collided_with_env=true
				gp.velocity=2*gp.velocity
				gp.movedir=-gp.movedir
				gp.tarvelocity=0
				self.collision_count=(self.collision_count or 0)+1
			end
		else
			self.collision_count=nil
		end
	end
	
	--FIX: use index of the wagon, not of the train.
	local velocity=(gp.velocity*gp.movedir)/(gp.path_dist[math.floor(index)] or 1)
	local acceleration=(gp.last_accel or 0)/(gp.path_dist[math.floor(index)] or 1)
	local factor=index-math.floor(index)
	local actual_pos={x=first_pos.x-(first_pos.x-second_pos.x)*factor, y=first_pos.y-(first_pos.y-second_pos.y)*factor, z=first_pos.z-(first_pos.z-second_pos.z)*factor,}
	local velocityvec={x=(first_pos.x-second_pos.x)*velocity*-1, z=(first_pos.z-second_pos.z)*velocity*-1, y=(first_pos.y-second_pos.y)*velocity*-1}
	local accelerationvec={x=(first_pos.x-second_pos.x)*acceleration*-1, z=(first_pos.z-second_pos.z)*acceleration*-1, y=(first_pos.y-second_pos.y)*acceleration*-1}
	
	--some additional positions to determine orientation
	local aposfwd=gp.path[math.floor(index+2)]
	local aposbwd=gp.path[math.floor(index-1)]
	
	local yaw
	if aposfwd and aposbwd then
		yaw=advtrains.get_wagon_yaw(aposfwd, second_pos, first_pos, aposbwd, factor)+math.pi--TODO remove when cleaning up
	else
		yaw=math.atan2((first_pos.x-second_pos.x), (second_pos.z-first_pos.z))
	end
	if self.wagon_flipped then
		yaw=yaw+math.pi
	end
	
	self.updatepct_timer=(self.updatepct_timer or 0)-dtime
	if not self.old_velocity_vector 
			or not vector.equals(velocityvec, self.old_velocity_vector)
			or not self.old_acceleration_vector 
			or not vector.equals(accelerationvec, self.old_acceleration_vector)
			or self.old_yaw~=yaw
			or self.updatepct_timer<=0 then--only send update packet if something changed
			self.object:setpos(actual_pos)
		self.object:setvelocity(velocityvec)
		self.object:setacceleration(accelerationvec)
		self.object:setyaw(yaw)
		self.updatepct_timer=2
		if self.update_animation then
			self:update_animation(gp.velocity)
		end
	end
	
	
	self.old_velocity_vector=velocityvec
	self.old_acceleration_vector=accelerationvec
	self.old_yaw=yaw
	atprintbm("wagon step", t)
end

function advtrains.get_real_path_index(train, pit)
	local pos_in_train_left=pit
	local index=train.index
	if pos_in_train_left>(index-math.floor(index))*(train.path_dist[math.floor(index)] or 1) then
		pos_in_train_left=pos_in_train_left - (index-math.floor(index))*(train.path_dist[math.floor(index)] or 1)
		index=math.floor(index)
		while pos_in_train_left>(train.path_dist[index-1] or 1) do
			pos_in_train_left=pos_in_train_left - (train.path_dist[index-1] or 1)
			index=index-1
		end
		index=index-(pos_in_train_left/(train.path_dist[index-1] or 1))
	else
		index=index-(pos_in_train_left/(train.path_dist[math.floor(index-1)] or 1))
	end
	return index
end

function wagon:on_rightclick(clicker)
	if not self:ensure_init() then return end
	if not clicker or not clicker:is_player() then
		return
	end
	if clicker:get_player_control().aux1 then
		--advtrains.dumppath(self:train().path)
		--minetest.chat_send_all("at index "..(self:train().index or "nil"))
		--advtrains.invert_train(self.train_id)
		atprint(dump(self))
		return
	end	
	local pname=clicker:get_player_name()
	local no=self:get_seatno(pname)
	if no then
		if self.seat_groups then
			local poss={}
			local sgr=self.seats[no].group
			for _,access in ipairs(self.seat_groups[sgr].access_to) do
				if self:check_seat_group_access(pname, access) then
					poss[#poss+1]={name=self.seat_groups[access].name, key="sgr_"..access}
				end
			end
			if self.has_inventory and self.get_inventory_formspec then
				poss[#poss+1]={name=attrans("Show Inventory"), key="inv"}
			end
			if self.owner==pname then
				poss[#poss+1]={name=attrans("Wagon properties"), key="prop"}
			end
			if not self.seat_groups[sgr].require_doors_open or self:train().door_open~=0 then
				poss[#poss+1]={name=attrans("Get off"), key="off"}
			else
				if clicker:get_player_control().sneak then
					poss[#poss+1]={name=attrans("Get off (forced)"), key="off"}
				else
					poss[#poss+1]={name=attrans("(Doors closed)"), key="dcwarn"}
				end
			end
			if #poss==0 then
				--can't do anything.
			elseif #poss==1 then
				self:seating_from_key_helper(pname, {[poss[1].key]=true}, no)
			else
				local form = "size[5,"..1+(#poss).."]"
				for pos,ent in ipairs(poss) do
					form = form .. "button_exit[0.5,"..(pos-0.5)..";4,1;"..ent.key..";"..ent.name.."]"
				end
				minetest.show_formspec(pname, "advtrains_seating_"..self.unique_id, form)
			end
		else
			self:get_off(no)
		end
	else
		if self.seat_groups then
			if #self.seats==0 then
				if self.has_inventory and self.get_inventory_formspec then
					minetest.show_formspec(pname, "advtrains_inv_"..self.unique_id, self:get_inventory_formspec(pname))
				end
				return
			end
			
			local doors_open = self:train().door_open~=0 or clicker:get_player_control().sneak
			for _,sgr in ipairs(self.assign_to_seat_group) do
				if self:check_seat_group_access(pname, sgr) then
					for seatid, seatdef in ipairs(self.seats) do
						if seatdef.group==sgr and not self.seatp[seatid] and (not self.seat_groups[sgr].require_doors_open or doors_open) then
							self:get_on(clicker, seatid)
							return
						end
					end
				end
			end
			minetest.chat_send_player(pname, attrans("Can't get on: wagon full or doors closed!"))
			minetest.chat_send_player(pname, attrans("Use shift+click to open doors forcefully!"))
		else
			self:show_get_on_form(pname)
		end
	end
end

function wagon:get_on(clicker, seatno)
	if not self.seatp then
		self.seatp={}
	end
	if not self.seats[seatno] then return end
	local oldno=self:get_seatno(clicker:get_player_name())
	if oldno then
		atprint("get_on: clearing oldno",seatno)
		advtrains.player_to_train_mapping[clicker:get_player_name()]=nil
		advtrains.clear_driver_hud(clicker:get_player_name())
		self.seatp[oldno]=nil
	end
	if self.seatp[seatno] and self.seatp[seatno]~=clicker:get_player_name() then
		atprint("get_on: throwing off",self.seatp[seatno],"from seat",seatno)
		self:get_off(seatno)
	end
	atprint("get_on: attaching",clicker:get_player_name())
	self.seatp[seatno] = clicker:get_player_name()
	advtrains.player_to_train_mapping[clicker:get_player_name()]=self.train_id
	clicker:set_attach(self.object, "", self.seats[seatno].attach_offset, {x=0,y=0,z=0})
	clicker:set_eye_offset(self.seats[seatno].view_offset, self.seats[seatno].view_offset)
end
function wagon:get_off_plr(pname)
	local no=self:get_seatno(pname)
	if no then
		self:get_off(no)
	end
end
function wagon:get_seatno(pname)
	for no, cont in pairs(self.seatp) do
		if cont==pname then
			return no
		end
	end
	return nil
end
function wagon:get_off(seatno)
	if not self.seatp[seatno] then return end
	local pname = self.seatp[seatno]
	local clicker = minetest.get_player_by_name(pname)
	advtrains.player_to_train_mapping[pname]=nil
	advtrains.clear_driver_hud(pname)
	if clicker then
		atprint("get_off: detaching",clicker:get_player_name())
		clicker:set_detach()
		clicker:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
		local objpos=advtrains.round_vector_floor_y(self.object:getpos())
		local yaw=self.object:getyaw()
		local isx=(yaw < math.pi/4) or (yaw > 3*math.pi/4 and yaw < 5*math.pi/4) or (yaw > 7*math.pi/4)
		--abuse helper function
		for _,r in ipairs({-1, 1}) do
			local p=vector.add({x=isx and r or 0, y=0, z=not isx and r or 0}, objpos)
			if minetest.get_item_group(minetest.get_node(p).name, "platform")>0 then
				minetest.after(0.2, function() clicker:setpos({x=p.x, y=p.y+1, z=p.z}) end)
			end
		end
	end
	self.seatp[seatno]=nil
end
function wagon:show_get_on_form(pname)
	if not self.initialized then return end
	if #self.seats==0 then
		if self.has_inventory and self.get_inventory_formspec then
			minetest.show_formspec(pname, "advtrains_inv_"..self.unique_id, self:get_inventory_formspec(pname))
		end
		return
	end
	local form, comma="size[5,8]label[0.5,0.5;"..attrans("Select seat:").."]textlist[0.5,1;4,6;seat;", ""
	for seatno, seattbl in ipairs(self.seats) do
		local addtext, colorcode="", ""
		if self.seatp and self.seatp[seatno] then
			colorcode="#FF0000"
			addtext=" ("..self.seatp[seatno]..")"
		end
		form=form..comma..colorcode..seattbl.name..addtext
		comma=","
	end
	form=form..";0,false]"
	if self.has_inventory and self.get_inventory_formspec then
		form=form.."button_exit[1,7;3,1;inv;"..attrans("Show Inventory").."]"
	end
	minetest.show_formspec(pname, "advtrains_geton_"..self.unique_id, form)
end
function wagon:show_wagon_properties(pname)
	if not self.seat_groups then
		return
	end
	if not self.seat_access then
		self.seat_access={}
	end
	--[[
	fields: seat access: empty: everyone
	checkbox: lock couples
	button: save
	]]
	local form="size[5,"..(#self.seat_groups*1.5+5).."]"
	local at=0
	for sgr,sgrdef in pairs(self.seat_groups) do
		local text = attrans("Access to @1",sgrdef.name)
		form=form.."field[0.5,"..(0.5+at*1.5)..";4,1;sgr_"..sgr..";"..text..";"..(self.seat_access[sgr] or "").."]"
		at=at+1
	end
	form=form.."checkbox[0,"..(at*1.5)..";lock_couples;"..attrans("Lock couples")..";"..(self.lock_couples and "true" or "false").."]"
	form=form.."button_exit[0.5,"..(1+at*1.5)..";4,1;save;"..attrans("Save wagon properties").."]"
	minetest.show_formspec(pname, "advtrains_prop_"..self.unique_id, form)
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local uid=string.match(formname, "^advtrains_geton_(.+)$")
	if uid then
		for _,wagon in pairs(minetest.luaentities) do
			if wagon.is_wagon and wagon.initialized and wagon.unique_id==uid then
				if fields.inv then
					if wagon.has_inventory and wagon.get_inventory_formspec then
						minetest.show_formspec(player:get_player_name(), "advtrains_inv_"..uid, wagon:get_inventory_formspec(player:get_player_name()))
					end
				elseif fields.seat then
					local val=minetest.explode_textlist_event(fields.seat)
					if val and val.type~="INV" and not wagon.seatp[player:get_player_name()] then
					--get on
						wagon:get_on(player, val.index)
						--will work with the new close_formspec functionality. close exactly this formspec.
						minetest.show_formspec(player:get_player_name(), formname, "")
					end
				end
			end
		end
	end
	uid=string.match(formname, "^advtrains_seating_(.+)$")
	if uid then
		for _,wagon in pairs(minetest.luaentities) do
			if wagon.is_wagon and wagon.initialized and wagon.unique_id==uid then
				local pname=player:get_player_name()
				local no=wagon:get_seatno(pname)
				if no then
					if wagon.seat_groups then
						wagon:seating_from_key_helper(pname, fields, no)
					end
				end
			end
		end
	end
	uid=string.match(formname, "^advtrains_prop_(.+)$")
	if uid then
		atprint(fields)
		for _,wagon in pairs(minetest.luaentities) do
			if wagon.is_wagon and wagon.initialized and wagon.unique_id==uid then
				local pname=player:get_player_name()
				if pname~=wagon.owner then
					return true
				end
				if fields.save or not fields.quit then
					for sgr,sgrdef in pairs(wagon.seat_groups) do
						if fields["sgr_"..sgr] then
							local fcont = fields["sgr_"..sgr]
							wagon.seat_access[sgr] = fcont~="" and fcont or nil
						end
					end
					wagon.lock_couples = fields.lock_couples == "true"
				end
			end
		end
	end
end)
function wagon:seating_from_key_helper(pname, fields, no)
	local sgr=self.seats[no].group
	for _,access in ipairs(self.seat_groups[sgr].access_to) do
		if fields["sgr_"..access] and self:check_seat_group_access(pname, access) then
			for seatid, seatdef in ipairs(self.seats) do
				if seatdef.group==access and not self.seatp[seatid] then
					self:get_on(minetest.get_player_by_name(pname), seatid)
					return
				end
			end
		end
	end
	if fields.inv and self.has_inventory and self.get_inventory_formspec then
		minetest.show_formspec(player:get_player_name(), "advtrains_inv_"..self.unique_id, wagon:get_inventory_formspec(player:get_player_name()))
	end
	if fields.prop and self.owner==pname then
		self:show_wagon_properties(pname)
	end
	if fields.dcwarn then
		minetest.chat_send_player(pname, attrans("Doors are closed! Use shift-rightclick to open doors with force and get off!"))
	end
	if fields.off then
		self:get_off(no)
	end
end
function wagon:check_seat_group_access(pname, sgr)
	if not self.seat_access then
		return true
	end
	local sae=self.seat_access[sgr]
	if not sae or sae=="" then
		return true
	end
	for name in string.gmatch(sae, "%S+") do
		if name==pname then
			return true
		end
	end
	return false
end
function wagon:reattach_all()
	if not self.seatp then self.seatp={} end
	for seatno, pname in pairs(self.seatp) do
		local p=minetest.get_player_by_name(pname)
		if p then
			self:get_on(p ,seatno)
		end
	end
end
minetest.register_on_joinplayer(function(player)
	for _,wagon in pairs(minetest.luaentities) do
		if wagon.is_wagon and wagon.initialized then
			wagon:reattach_all()
		end
	end
end)

function advtrains.register_wagon(sysname, prototype, desc, inv_img)
	setmetatable(prototype, {__index=wagon})
	minetest.register_entity(":advtrains:"..sysname,prototype)
	
	minetest.register_craftitem(":advtrains:"..sysname, {
		description = desc,
		inventory_image = inv_img,
		wield_image = inv_img,
		stack_max = 1,
		
		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return
			end
			

			local node=minetest.get_node_or_nil(pointed_thing.under)
			if not node then atprint("[advtrains]Ignore at placer position") return itemstack end
			local nodename=node.name
			if(not advtrains.is_track_and_drives_on(nodename, prototype.drives_on)) then
				atprint("no track here, not placing.")
				return itemstack
			end
			if minetest.is_protected(pointed_thing.under, placer:get_player_name()) and (not minetest.check_player_privs(puncher, {train_remove = true }))then
	   			minetest.chat_send_player(placer:get_player_name(), S("This position is protected!"))
	   			return itemstack
	   		end
			local conn1=advtrains.get_track_connections(node.name, node.param2)
			local id=advtrains.create_new_train_at(pointed_thing.under, advtrains.dirCoordSet(pointed_thing.under, conn1))
			
			local ob=minetest.add_entity(pointed_thing.under, "advtrains:"..sysname)
			if not ob then
				atprint("couldn't add_entity, aborting")
			end
			local le=ob:get_luaentity()
			
			le.owner=placer:get_player_name()
			le.infotext=desc..", owned by "..placer:get_player_name()
			
			local wagon_uid=le:init_new_instance(id, {})
			
			advtrains.add_wagon_to_train(le, id)
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
			
		end,
	})
end

--[[
	wagons can define update_animation(self, velocity) if they have a speed-dependent animation
	this function will be called when the velocity vector changes or every 2 seconds.
]]


