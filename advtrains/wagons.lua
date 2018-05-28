-- wagon.lua
-- Holds all logic related to wagons
-- From now on, wagons are, just like trains, just entries in a table
-- All data that is static is stored in the entity prototype (self).
--   A copy of the entity prototype is always available inside wagon_prototypes
-- All dynamic data is stored in the (new) wagons table
-- An entity is ONLY spawned by update_trainpart_properties when it finds it useful.
-- Only data that are only important to the entity itself are stored in the luaentity

advtrains.wagons = {}
advtrains.wagon_prototypes = {}

--
function advtrains.create_wagon(wtype, owner)
	local new_id=advtrains.random_id()
	while advtrains.wagons[new_id] do new_id=advtrains.random_id() end
	local wgn = {}
	wgn.type = wtype
	wgn.seatp = {}
	wgn.owner = owner
	wgn.id = new_id
	---wgn.train_id = train_id   --- will get this via update_trainpart_properties
	advtrains.wagons[new_id] = wgn
	atdebug("Created new wagon:",wgn)
	return new_id
end


local wagon={
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	--physical = true,
	visual = "mesh",
	mesh = "wagon.b3d",
	visual_size = {x=1, y=1},
	textures = {"black.png"},
	is_wagon=true,
	wagon_span=1,--how many index units of space does this wagon consume
	has_inventory=false,
	static_save=false,
}


function wagon:train()
	local data = advtrains.wagons[self.id]
	return advtrains.trains[data.train_id]
end


function wagon:on_activate(sd_uid, dtime_s)
	if sd_uid~="" then
		--destroy when loaded from static block.
		self.object:remove()
		return
	end
	self.object:set_armor_groups({immortal=1})
end

function wagon:set_id(wid)
	self.id = wid
	self.initialized = true
	
	local data = advtrains.wagons[self.id]
	
	data.object = self.object
	atdebug("Created wagon entity:",self.name," w_id",wid," t_id",data.train_id)
	
	if self.has_inventory then
		--to be used later
		local inv=minetest.create_detached_inventory("advtrains_wgn_"..self.id, {
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
			advtrains.deserialize_inventory(data.ser_inv, inv)
		end
		if self.inventory_list_sizes then
			for lst, siz in pairs(self.inventory_list_sizes) do
				inv:set_size(lst, siz)
			end
		end
	end
	self.door_anim_timer=0
	self.door_state=0
	
	minetest.after(0.2, function() self:reattach_all() end)
	
	if self.custom_on_activate then
		self:custom_on_activate(dtime_s)
	end
end

function wagon:get_staticdata()
	return "STATIC"
end

function wagon:ensure_init()
			-- Note: A wagon entity won't exist when there's no train, because the train is
			-- the thing that actually creates the entity
			-- Train not being set just means that this will happen as soon as the train calls update_trainpart_properties.
	if self.initialized and self.id then
		local data = advtrains.wagons[self.id]
		if data and data.train_id and self:train() then
			if self.noninitticks then self.noninitticks=nil end
			return true
		end
	end
	if not self.noninitticks then
		atwarn("wagon",self.id,"uninitialized init=",self.initialized)
		self.noninitticks=0
	end
	self.noninitticks=self.noninitticks+1
	if self.noninitticks>20 then
		atwarn("wagon",self.id,"uninitialized, removing")
		self:destroy()
	else
		self.object:setvelocity({x=0,y=0,z=0})
	end
	return false
end

function wagon:train()
	local data = advtrains.wagons[self.id]
	return advtrains.trains[data.train_id]
end

-- Remove the wagon
function wagon:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	return advtrains.pcall(function()
		if not self:ensure_init() then return end
		
		local data = advtrains.wagons[self.id]
	
		if not puncher or not puncher:is_player() then
			return
		end
		if data.owner and puncher:get_player_name()~=data.owner and (not minetest.check_player_privs(puncher, {train_admin = true })) then
		   minetest.chat_send_player(puncher:get_player_name(), attrans("This wagon is owned by @1, you can't destroy it.", data.owner));
		   return
		end
		if #(self:train().trainparts)>1 then
		   minetest.chat_send_player(puncher:get_player_name(), attrans("Wagon needs to be decoupled from other wagons in order to destroy it."));
		   return
		end
		
		local pc=puncher:get_player_control()
		if not pc.sneak then
			minetest.chat_send_player(puncher:get_player_name(), attrans("Warning: If you destroy this wagon, you only get some steel back! If you are sure, hold Sneak and left-click the wagon."))
			return
		end
		
		if self.custom_may_destroy then
			if not self.custom_may_destroy(self, puncher, time_from_last_punch, tool_capabilities, direction) then
				return
			end
		end

		if not self:destroy() then return end

		local inv = puncher:get_inventory()
		for _,item in ipairs(self.drops or {self.name}) do
			inv:add_item("main", item)
		end
	end)
end
function wagon:destroy()
	--some rules:
	-- you get only some items back
	-- single left-click shows warning
	-- shift leftclick destroys
	-- not when a driver is inside
	if self.id then
		local data = advtrains.wagons[self.id]
		if not data then
			atwarn("wagon:destroy(): data is not set!")
			return
		end
		
		if self.custom_on_destroy then
			self.custom_on_destroy(self)
		end
		
		for seat,_ in pairs(data.seatp) do
			self:get_off(seat)
		end
		
		if data.train_id and self:train() then
			advtrains.remove_train(data.train_id)
			advtrains.wagons[self.id]=nil
			if self.discouple then self.discouple.object:remove() end--will have no effect on unloaded objects
		end
	end
	atdebug("[wagon ", self.id, "]: destroying")
	
	self.object:remove()
end

function wagon:on_step(dtime)
	return advtrains.pcall(function()
		if not self:ensure_init() then return end
		
		local t=os.clock()
		local pos = self.object:getpos()
		local data = advtrains.wagons[self.id]
		
		if not pos then
			atdebug("["..self.id.."][fatal] missing position (object:getpos() returned nil)")
			return
		end
		
		if not data.seatp then
			data.seatp={}
		end
		if not self.seatpc then
			self.seatpc={}
		end

		--custom on_step function
		if self.custom_on_step then
			self:custom_on_step(self, dtime)
		end

		--driver control
		for seatno, seat in ipairs(self.seats) do
			local pname=data.seatp[seatno]
			local driver=pname and minetest.get_player_by_name(pname)
			local has_driverstand = pname and advtrains.check_driving_couple_protection(pname, data.owner, data.whitelist)
			if self.seat_groups then
				has_driverstand = has_driverstand and (seat.driving_ctrl_access or self.seat_groups[seat.group].driving_ctrl_access)
			else
				has_driverstand = has_driverstand and (seat.driving_ctrl_access)
			end
			if has_driverstand and driver then
				advtrains.update_driver_hud(driver:get_player_name(), self:train(), data.wagon_flipped)
			elseif driver then
				--only show the inside text
				local inside=self:train().text_inside or ""
				advtrains.set_trainhud(driver:get_player_name(), inside)
			end
			if driver and driver:get_player_control_bits()~=self.seatpc[seatno] then
				local pc=driver:get_player_control()
				self.seatpc[seatno]=driver:get_player_control_bits()
				
				if has_driverstand then
					--regular driver stand controls
					advtrains.on_control_change(pc, self:train(), data.wagon_flipped)
					--bordcom
					if pc.sneak and pc.jump then
						self:show_bordcom(data.seatp[seatno])
					end
					--sound horn when required
					if self.horn_sound and pc.aux1 and not pc.sneak and not self.horn_handle then
						self.horn_handle = minetest.sound_play(self.horn_sound, {
							object = self.object,
							gain = 1.0, -- default
							max_hear_distance = 128, -- default, uses an euclidean metric
							loop = true,
						})
					elseif not pc.aux1 and self.horn_handle then
						minetest.sound_stop(self.horn_handle)
						self.horn_handle = nil
					end
				else
					-- If on a passenger seat and doors are open, get off when W or D pressed.
					local pass = data.seatp[seatno] and minetest.get_player_by_name(data.seatp[seatno])
					if pass and self:train().door_open~=0 then
					local pc=pass:get_player_control()
						if pc.up or pc.down then
							self:get_off(seatno)
						end
					end		      
				end
				if pc.aux1 and pc.sneak then
					self:get_off(seatno)
				end
			end
		end
		
		--check infotext
		local outside=self:train().text_outside or ""
		
		local train=self:train()
		--show off-track information in outside text instead of notifying the whole server about this
		if not train.dirty and train.end_index < train.path_trk_b or train.index > train.path_trk_f then
			outside = outside .."\n!!! Train off track !!!"
		end
		
		if self.infotext_cache~=outside  then
			self.object:set_properties({infotext=outside})
			self.infotext_cache=outside
		end
		
		local fct=data.wagon_flipped and -1 or 1
		--set line number
		if self.name == "advtrains:subway_wagon" and train.line and train.line~=self.line_cache then
			local new_line_tex="advtrains_subway_wagon.png^advtrains_subway_wagon_line"..train.line..".png"
			self.object:set_properties({
				textures={new_line_tex},
		 	})
			self.line_cache=train.line
		elseif self.line_cache~=nil and train.line==nil then
			self.object:set_properties({
				textures=self.textures,
		 	})
			self.line_cache=nil
		end
		--door animation
		if self.doors then
			if (self.door_anim_timer or 0)<=0 then
				local dstate = (train.door_open or 0) * fct
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
						if self.doors.open.sound then minetest.sound_play(self.doors.open.sound, {object = self.object}) end
						at=self.doors.open[dstate]
						self.object:set_animation(at.frames, at.speed or 15, at.blend or 0, false)
						self.door_state = dstate
					else
						if self.doors.close.sound then minetest.sound_play(self.doors.close.sound, {object = self.object}) end
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
		if data.pos_in_trainparts and data.pos_in_trainparts>1 then
			if train.velocity==0 and not data.dcpl_lock then
				if not self.discouple or not self.discouple.object:getyaw() then
					atprint(self.id,"trying to spawn discouple")
					local yaw = self.object:getyaw()
					local flipsign=data.wagon_flipped and -1 or 1
					local dcpl_pos = vector.add(pos, {y=0, x=-math.sin(yaw)*self.wagon_span*flipsign, z=math.cos(yaw)*self.wagon_span*flipsign})
					local object=minetest.add_entity(dcpl_pos, "advtrains:discouple")
					if object then
						local le=object:get_luaentity()
						le.wagon=self
						--box is hidden when attached, so unuseful.
						--object:set_attach(self.object, "", {x=0, y=0, z=self.wagon_span*10}, {x=0, y=0, z=0})
						self.discouple=le
						atprint(self.id,"success")
					else
						atprint("Couldn't spawn DisCouple")
					end
				end
			else
				if self.discouple and self.discouple.object:getyaw() then
					self.discouple.object:remove()
					atprint(self.id," removing discouple")
				end
			end
		end
		--for path to be available. if not, skip step
		if not train.path or train.no_step then
			self.object:setvelocity({x=0, y=0, z=0})
			self.object:setacceleration({x=0, y=0, z=0})
			return
		end
		if not data.pos_in_train then
			return
		end
		
		-- Calculate new position, yaw and direction vector
		local index = advtrains.path_get_index_by_offset(train, train.index, -data.pos_in_train)
		local pos, yaw, npos, npos2 = advtrains.path_get_interpolated(train, index)
		local vdir = vector.normalize(vector.subtract(npos2, npos))
		
		--automatic get_on
		--needs to know index and path
		if self.door_entry and train.door_open and train.door_open~=0 and train.velocity==0 then
			--using the mapping created by the trainlogic globalstep
			for i, ino in ipairs(self.door_entry) do
				--fct is the flipstate flag from door animation above
				local aci = advtrains.path_get_index_by_offset(train, index, ino*fct)
				local ix1, ix2 = advtrains.path_get_adjacent(train, aci)
				-- the two wanted positions are ix1 and ix2 + (2nd-1st rotated by 90deg)
				-- (x z) rotated by 90deg is (-z x)  (http://stackoverflow.com/a/4780141)
				local add = { x = (ix2.z-ix1.z)*train.door_open, y = 0, z = (ix1.x-ix2.x)*train.door_open }
				local pts1=vector.round(vector.add(ix1, add))
				local pts2=vector.round(vector.add(ix2, add))
				if minetest.get_item_group(minetest.get_node(pts1).name, "platform")>0 then
					local ckpts={
						pts1,
						pts2,
						vector.add(pts1, {x=0, y=1, z=0}),
						vector.add(pts2, {x=0, y=1, z=0}),
					}
					for _,ckpos in ipairs(ckpts) do
						local cpp=minetest.pos_to_string(ckpos)
						if advtrains.playersbypts[cpp] then
							self:on_rightclick(advtrains.playersbypts[cpp])
						end
					end
				end
			end
		end
		
		--checking for environment collisions(a 3x3 cube around the center)
		if not train.recently_collided_with_env then
			local collides=false
			local exh = self.extent_h or 1
			local exv = self.extent_v or 2
			for x=-exh,exh do
				for y=0,exv do
					for z=-exh,exh do
						local node=minetest.get_node_or_nil(vector.add(npos, {x=x, y=y, z=z}))
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
					train.velocity=math.min(train.velocity, 1)
					train.tarvelocity=math.min(train.tarvelocity, 1)
				else
					train.recently_collided_with_env=true
					train.velocity=0
					-- TODO what should happen when a train collides?
					train.tarvelocity=0
					self.collision_count=(self.collision_count or 0)+1
				end
			else
				self.collision_count=nil
			end
		end
		
		--FIX: use index of the wagon, not of the train.
		local velocity = train.velocity
		local acceleration = (train.acceleration or 0)
		local velocityvec = vector.multiply(vdir, velocity)
		local accelerationvec = vector.multiply(vdir, acceleration)
		
		if data.wagon_flipped then
			yaw=yaw+math.pi
		end
		
		self.updatepct_timer=(self.updatepct_timer or 0)-dtime
		if not self.old_velocity_vector 
				or not vector.equals(velocityvec, self.old_velocity_vector)
				or not self.old_acceleration_vector 
				or not vector.equals(accelerationvec, self.old_acceleration_vector)
				or self.old_yaw~=yaw
				or self.updatepct_timer<=0 then--only send update packet if something changed
			
			self.object:setpos(pos)
			self.object:setvelocity(velocityvec)
			self.object:setacceleration(accelerationvec)
			
			if #self.seats > 0 and self.old_yaw ~= yaw then
				if not self.player_yaw then
					self.player_yaw = {}
				end
				if not self.old_yaw then
					self.old_yaw=yaw
				end
				for _,name in pairs(data.seatp) do
					local p = minetest.get_player_by_name(name)
					if p then
						if not self.turning then
							-- save player looking direction offset
							self.player_yaw[name] = p:get_look_horizontal()-self.old_yaw
						end
						-- set player looking direction using calculated offset
						p:set_look_horizontal((self.player_yaw[name] or 0)+yaw)
					end
				end
				self.turning = true							 
			elseif self.old_yaw == yaw then
				-- train is no longer turning
				self.turning = false
			end
			
			self.object:setyaw(yaw)
			self.updatepct_timer=2
			if self.update_animation then
				self:update_animation(train.velocity, self.old_velocity)
			end
			if self.custom_on_velocity_change then
				self:custom_on_velocity_change(train.velocity, self.old_velocity or 0, dtime)
			end
			-- remove discouple object, because it will be in a wrong location
			if self.discouple then
				self.discouple.object:remove()
			end
		end
		
		
		self.old_velocity_vector=velocityvec
		self.old_velocity = train.velocity
		self.old_acceleration_vector=accelerationvec
		self.old_yaw=yaw
		atprintbm("wagon step", t)
	end)
end

function wagon:on_rightclick(clicker)
	return advtrains.pcall(function()
		if not self:ensure_init() then return end
		if not clicker or not clicker:is_player() then
			return
		end
		
		local data = advtrains.wagons[self.id]
		
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
				if self.seat_groups[sgr].driving_ctrl_access and advtrains.check_driving_couple_protection(pname, data.owner, data.whitelist) then
					poss[#poss+1]={name=attrans("Board Computer"), key="bordcom"}
				end
				if data.owner==pname then
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
					minetest.show_formspec(pname, "advtrains_seating_"..self.id, form)
				end
			else
				self:get_off(no)
			end
		else
			--do not attach if already on a train
			if advtrains.player_to_train_mapping[pname] then return end
			if self.seat_groups then
				if #self.seats==0 then
					if self.has_inventory and self.get_inventory_formspec then
						minetest.show_formspec(pname, "advtrains_inv_"..self.id, self:get_inventory_formspec(pname))
					end
					return
				end
				
				local doors_open = self:train().door_open~=0 or clicker:get_player_control().sneak
				local allow, rsn=false, "unknown reason"
				for _,sgr in ipairs(self.assign_to_seat_group) do
					allow, rsn = self:check_seat_group_access(pname, sgr)
					if allow then
						for seatid, seatdef in ipairs(self.seats) do
							if seatdef.group==sgr then
								if (not self.seat_groups[sgr].require_doors_open or doors_open) then
									if not data.seatp[seatid] then
										self:get_on(clicker, seatid)
										return
									else
										rsn="Wagon is full."
									end
								else
									rsn="Doors are closed! (try holding sneak key!)"
								end
							end
						end
					end
				end
				minetest.chat_send_player(pname, attrans("Can't get on: "..rsn))
			else
				self:show_get_on_form(pname)
			end
		end
	end)
end

function wagon:get_on(clicker, seatno)
	
	local data = advtrains.wagons[self.id]
		
	if not data.seatp then data.seatp={}end
	if not self.seatpc then self.seatpc={}end--player controls in driver stands
	
	if not self.seats[seatno] then return end
	local oldno=self:get_seatno(clicker:get_player_name())
	if oldno then
		atprint("get_on: clearing oldno",seatno)
		advtrains.player_to_train_mapping[clicker:get_player_name()]=nil
		advtrains.clear_driver_hud(clicker:get_player_name())
		data.seatp[oldno]=nil
	end
	if data.seatp[seatno] and data.seatp[seatno]~=clicker:get_player_name() then
		atprint("get_on: throwing off",data.seatp[seatno],"from seat",seatno)
		self:get_off(seatno)
	end
	atprint("get_on: attaching",clicker:get_player_name())
	data.seatp[seatno] = clicker:get_player_name()
	self.seatpc[seatno] = clicker:get_player_control_bits()
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
	
	local data = advtrains.wagons[self.id]
	
	for no, cont in pairs(data.seatp) do
		if cont==pname then
			return no
		end
	end
	return nil
end
function wagon:get_off(seatno)
	
	local data = advtrains.wagons[self.id]
	
	if not data.seatp[seatno] then return end
	local pname = data.seatp[seatno]
	local clicker = minetest.get_player_by_name(pname)
	advtrains.player_to_train_mapping[pname]=nil
	advtrains.clear_driver_hud(pname)
	data.seatp[seatno]=nil
	self.seatpc[seatno]=nil
	if clicker then
		atprint("get_off: detaching",clicker:get_player_name())
		clicker:set_detach()
		clicker:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
		local train=self:train()
		--code as in step - automatic get on
		if self.door_entry and train.door_open and train.door_open~=0 and train.velocity==0 and train.index and train.path then
			local index = advtrains.path_get_index_by_offset(train, train.index, -data.pos_in_train)
			for i, ino in ipairs(self.door_entry) do
				local fct=data.wagon_flipped and -1 or 1
				local aci = advtrains.path_get_index_by_offset(train, index, ino*fct)
				local ix1, ix2 = advtrains.path_get_adjacent(train, aci)
				-- the two wanted positions are ix1 and ix2 + (2nd-1st rotated by 90deg)
				-- (x z) rotated by 90deg is (-z x)  (http://stackoverflow.com/a/4780141)
				local add = { x = (ix2.z-ix1.z)*train.door_open, y = 0, z = (ix1.x-ix2.x)*train.door_open }
				local oadd = { x = (ix2.z-ix1.z)*train.door_open*2, y = 1, z = (ix1.x-ix2.x)*train.door_open*2}
				local platpos=vector.round(vector.add(ix1, add))
				local offpos=vector.round(vector.add(ix1, oadd))
				atprint("platpos:", platpos, "offpos:", offpos)
				if minetest.get_item_group(minetest.get_node(platpos).name, "platform")>0 then
					minetest.after(0.2, function() clicker:setpos(offpos) end)
					return
				end
			end
		else--if not door_entry, or paths missing, fall back to old method
			local objpos=advtrains.round_vector_floor_y(self.object:getpos())
			local yaw=self.object:getyaw()
			local isx=(yaw < math.pi/4) or (yaw > 3*math.pi/4 and yaw < 5*math.pi/4) or (yaw > 7*math.pi/4)
			--abuse helper function
			for _,r in ipairs({-1, 1}) do
				local p=vector.add({x=isx and r or 0, y=0, z=not isx and r or 0}, objpos)
				local offp=vector.add({x=isx and r*2 or 0, y=1, z=not isx and r*2 or 0}, objpos)
				if minetest.get_item_group(minetest.get_node(p).name, "platform")>0 then
					minetest.after(0.2, function() clicker:setpos(offp) end)
					return
				end
			end
		end
	end
end
function wagon:show_get_on_form(pname)
	if not self.initialized then return end
	
	local data = advtrains.wagons[self.id]
	if #self.seats==0 then
		if self.has_inventory and self.get_inventory_formspec then
			minetest.show_formspec(pname, "advtrains_inv_"..self.id, self:get_inventory_formspec(pname))
		end
		return
	end
	local form, comma="size[5,8]label[0.5,0.5;"..attrans("Select seat:").."]textlist[0.5,1;4,6;seat;", ""
	for seatno, seattbl in ipairs(self.seats) do
		local addtext, colorcode="", ""
		if data.seatp and data.seatp[seatno] then
			colorcode="#FF0000"
			addtext=" ("..data.seatp[seatno]..")"
		end
		form=form..comma..colorcode..seattbl.name..addtext
		comma=","
	end
	form=form..";0,false]"
	if self.has_inventory and self.get_inventory_formspec then
		form=form.."button_exit[1,7;3,1;inv;"..attrans("Show Inventory").."]"
	end
	minetest.show_formspec(pname, "advtrains_geton_"..self.id, form)
end
function wagon:show_wagon_properties(pname)
	--[[
	fields: 
	field: driving/couple whitelist
	button: save
	]]
	local data = advtrains.wagons[self.id]
	local form="size[5,5]"
	form = form .. "field[0.5,1;4,1;whitelist;Allow these players to drive your wagon:;"..(data.whitelist or "").."]"
	--seat groups access lists were here
	form=form.."button_exit[0.5,3;4,1;save;"..attrans("Save wagon properties").."]"
	minetest.show_formspec(pname, "advtrains_prop_"..self.id, form)
end

--BordCom
local function checkcouple(ent)
	if not ent or not ent:getyaw() then
		return nil
	end
	local le = ent:get_luaentity()
	if not le or not le.is_couple then
		return nil
	end
	return le
end
local function checklock(pname, own1, own2, wl1, wl2)
	return advtrains.check_driving_couple_protection(pname, own1, wl1)
		or advtrains.check_driving_couple_protection(pname, own2, wl2)
end
function wagon:show_bordcom(pname)
	if not self:train() then return end
	local train = self:train()
	local data = advtrains.wagons[self.id]
	
	local form = "size[11,9]label[0.5,0;AdvTrains Boardcom v0.1]"
	form=form.."textarea[0.5,1.5;7,1;text_outside;"..attrans("Text displayed outside on train")..";"..(train.text_outside or "").."]"
	form=form.."textarea[0.5,3;7,1;text_inside;"..attrans("Text displayed inside train")..";"..(train.text_inside or "").."]"
	--row 5 : train overview and autocoupling
	if train.velocity==0 then
		form=form.."label[0.5,4.5;Train overview /coupling control:]"
		linhei=5
		local pre_own, pre_wl, owns_any = nil, nil, minetest.check_player_privs(pname, "train_admin")
		for i, tpid in ipairs(train.trainparts) do
			local ent = advtrains.wagons[tpid]
			if ent then
				local ename = ent.type
				form = form .. "item_image["..i..","..linhei..";1,1;"..ename.."]"
				if i~=1 then
					if not ent.dcpl_lock then
						form = form .. "image_button["..(i-0.5)..","..(linhei+1)..";1,1;advtrains_discouple.png;dcpl_"..i..";]"
						if checklock(pname, ent.owner, pre_own, ent.whitelist, pre_wl) then
							form = form .. "image_button["..(i-0.5)..","..(linhei+2)..";1,1;advtrains_cpl_unlock.png;dcpl_lck_"..i..";]"
						end
					else
						form = form .. "image_button["..(i-0.5)..","..(linhei+2)..";1,1;advtrains_cpl_lock.png;dcpl_ulck_"..i..";]"
					end
				end
				if i == data.pos_in_trainparts then
					form = form .. "box["..(i-0.1)..","..(linhei-0.1)..";1,1;green]"
				end
				pre_own = ent.owner
				pre_wl = ent.whitelist
				owns_any = owns_any or (not ent.owner or ent.owner==pname)
			end
		end
		
		if train.movedir==1 then
			form = form .. "label["..(#train.trainparts+1)..","..(linhei)..";-->]"
		else
			form = form .. "label[0.5,"..(linhei)..";<--]"
		end
		--check cpl_eid_front and _back of train
		local couple_front = checkcouple(train.cpl_front)
		local couple_back = checkcouple(train.cpl_back)
		if couple_front then
			form = form .. "image_button[0.5,"..(linhei+1)..";1,1;advtrains_couple.png;cpl_f;]"
		end
		if couple_back then
			form = form .. "image_button["..(#train.trainparts+0.5)..","..(linhei+1)..";1,1;advtrains_couple.png;cpl_b;]"
		end
		if owns_any then
			if train.couple_lck_front then
				form = form .. "image_button[0.5,"..(linhei+2)..";1,1;advtrains_cpl_lock.png;cpl_ulck_f;]"
			else
				form = form .. "image_button[0.5,"..(linhei+2)..";1,1;advtrains_cpl_unlock.png;cpl_lck_f;]"
			end
			if train.couple_lck_back then
				form = form .. "image_button["..(#train.trainparts+0.5)..","..(linhei+2)..";1,1;advtrains_cpl_lock.png;cpl_ulck_b;]"
			else
				form = form .. "image_button["..(#train.trainparts+0.5)..","..(linhei+2)..";1,1;advtrains_cpl_unlock.png;cpl_lck_b;]"
			end
		end
		
	else
		form=form.."label[0.5,4.5;Train overview / coupling control is only shown when the train stands.]"
	end
	form = form .. "button[0.5,8;3,1;Save;save]"
	
	minetest.show_formspec(pname, "advtrains_bordcom_"..self.id, form)
end
function wagon:handle_bordcom_fields(pname, formname, fields)
	local data = advtrains.wagons[self.id]
	
	local seatno=self:get_seatno(pname)
	if not seatno or not self.seat_groups[self.seats[seatno].group].driving_ctrl_access or not advtrains.check_driving_couple_protection(pname, self.owner, self.whitelist) then
		return
	end
	local train = self:train()
	if not train then return end
	if fields.text_outside then
		if fields.text_outside~="" then
			train.text_outside=fields.text_outside
		else
			train.text_outside=nil
		end
	end
	if fields.text_inside then
		if fields.text_inside~="" then
			train.text_inside=fields.text_inside
		else
			train.text_inside=nil
		end
	end
	for i, tpid in ipairs(train.trainparts) do
		if fields["dcpl_"..i] then
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.id==tpid then
					wagon:safe_decouple(pname)										-- TODO: Move this into external function (don't search entity?)
				end
			end
		end
		if i>1 and fields["dcpl_lck_"..i] then
			local ent = advtrains.wagons[tpid]
			local pent = advtrains.wagons[train.trainparts[i-1]]
			if ent and pent then
				if checklock(pname, ent.owner, pent.owner, ent.whitelist, pent.whitelist) then
					ent.dcpl_lock = true
				end
			end
		end
		if i>1 and fields["dcpl_ulck_"..i] then
			local ent = advtrains.wagons[tpid]
			local pent = advtrains.wagons[train.trainparts[i-1]]
			if ent and pent then
				if checklock(pname, ent.owner, pent.owner, ent.whitelist, pent.whitelist) then
					ent.dcpl_lock = false
				end
			end
		end
	end
	--check cpl_eid_front and _back of train
	local couple_front = checkcouple(train.cpl_front)
	local couple_back = checkcouple(train.cpl_back)
	
	if fields.cpl_f and couple_front then
		couple_front:on_rightclick(pname)
	end
	if fields.cpl_b and couple_back then
		couple_back:on_rightclick(pname)
	end
	
	local function chkownsany()
		local owns_any = minetest.check_player_privs(pname, "train_admin")
		for i, tpid in ipairs(train.trainparts) do
			local ent = advtrains.wagons[tpid]
			if ent then
				owns_any = owns_any or advtrains.check_driving_couple_protection(pname, ent.owner, ent.whitelist)
			end
		end
		return owns_any
	end
	if fields.cpl_lck_f and chkownsany() then
		train.couple_lck_front=true
	end
	if fields.cpl_lck_b and chkownsany() then
		train.couple_lck_back=true
	end
	if fields.cpl_ulck_f and chkownsany() then
		train.couple_lck_front=false
	end
	if fields.cpl_ulck_b and chkownsany() then
		train.couple_lck_back=false
	end
	
	
	if not fields.quit then
		self:show_bordcom(pname)
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	return advtrains.pcall(function()
		local uid=string.match(formname, "^advtrains_geton_(.+)$")
		if uid then
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.id==uid then
					local data = advtrains.wagons[wagon.id]
					if fields.inv then
						if wagon.has_inventory and wagon.get_inventory_formspec then
							minetest.show_formspec(player:get_player_name(), "advtrains_inv_"..uid, wagon:get_inventory_formspec(player:get_player_name()))
						end
					elseif fields.seat then
						local val=minetest.explode_textlist_event(fields.seat)
						if val and val.type~="INV" and not data.seatp[player:get_player_name()] then
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
				if wagon.is_wagon and wagon.initialized and wagon.id==uid then
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
			local pname=player:get_player_name()
			local data = advtrains.wagons[uid]
			if pname~=data.owner and not minetest.check_player_privs(pname, {train_admin = true}) then
				return true
			end
			if fields.save or not fields.quit then
				if fields.whitelist then
					data.whitelist = fields.whitelist
				end
			end
		end
		uid=string.match(formname, "^advtrains_bordcom_(.+)$")
		if uid then
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.id==uid then
					wagon:handle_bordcom_fields(player:get_player_name(), formname, fields)
				end
			end
		end
	end)
end)
function wagon:seating_from_key_helper(pname, fields, no)
	local data = advtrains.wagons[self.id]
	local sgr=self.seats[no].group
	for _,access in ipairs(self.seat_groups[sgr].access_to) do
		if fields["sgr_"..access] and self:check_seat_group_access(pname, access) then
			for seatid, seatdef in ipairs(self.seats) do
				if seatdef.group==access and not data.seatp[seatid] then
					self:get_on(minetest.get_player_by_name(pname), seatid)
					return
				end
			end
		end
	end
	if fields.inv and self.has_inventory and self.get_inventory_formspec then
		minetest.show_formspec(player:get_player_name(), "advtrains_inv_"..self.id, self:get_inventory_formspec(player:get_player_name()))
	end
	if fields.prop and self.owner==pname then
		self:show_wagon_properties(pname)
	end
	if fields.bordcom and self.seat_groups[sgr].driving_ctrl_access and advtrains.check_driving_couple_protection(pname, self.owner, self.whitelist) then
		self:show_bordcom(pname)
	end
	if fields.dcwarn then
		minetest.chat_send_player(pname, attrans("Doors are closed! Use Sneak+rightclick to ignore the closed doors and get off!"))
	end
	if fields.off then
		self:get_off(no)
	end
end
function wagon:check_seat_group_access(pname, sgr)
	if self.seat_groups[sgr].driving_ctrl_access and not (advtrains.check_driving_couple_protection(pname, self.owner, self.whitelist)) then
		return false, "Not allowed to access a driver stand!"
	end
	if self.seat_groups[sgr].driving_ctrl_access then
		advtrains.log("Drive", pname, self.object:getpos(), self:train().text_outside)
	end
	return true
end
function wagon:reattach_all()
	local data = advtrains.wagons[self.id]
	if not data.seatp then data.seatp={} end
	for seatno, pname in pairs(data.seatp) do
		local p=minetest.get_player_by_name(pname)
		if p then
			self:get_on(p ,seatno)
		end
	end
end

function wagon:safe_decouple(pname)
	if not minetest.check_player_privs(pname, "train_operator") then
		minetest.chat_send_player(pname, "Missing train_operator privilege")
		return false
	end
	local data = advtrains.wagons[self.id]
	if data.dcpl_lock then
		minetest.chat_send_player(pname, "Couple is locked (ask owner or admin to unlock it)")
		return false
	end
	atprint("wagon:discouple() Splitting train", self.train_id)
	advtrains.log("Discouple", pname, self.object:getpos(), self:train().text_outside)
	advtrains.split_train_at_wagon(self.id)--found in trainlogic.lua
	return true
end

function advtrains.get_wagon_prototype(data)
	local wt = data.type
	if not advtrains.wagon_prototypes[wt] then
		atprint("Unable to load wagon type",wt,", using placeholder")
		wt="advtrains:wagon_placeholder"
	end
	return wt, advtrains.wagon_prototypes[wt]
end

function advtrains.register_wagon(sysname_p, prototype, desc, inv_img, nincreative)
	local sysname = sysname_p
	if not string.match(sysname, ":") then
		sysname = "advtrains:"..sysname_p
	end
	setmetatable(prototype, {__index=wagon})
	minetest.register_entity(":"..sysname,prototype)
	advtrains.wagon_prototypes[sysname] = prototype
	
	minetest.register_craftitem(":"..sysname, {
		description = desc,
		inventory_image = inv_img,
		wield_image = inv_img,
		stack_max = 1,
		
		groups = { not_in_creative_inventory = nincreative and 1 or 0},
		
		on_place = function(itemstack, placer, pointed_thing)
			return advtrains.pcall(function()
				if not pointed_thing.type == "node" then
					return
				end
				local pname = placer:get_player_name()

				local node=minetest.get_node_or_nil(pointed_thing.under)
				if not node then atprint("[advtrains]Ignore at placer position") return itemstack end
				local nodename=node.name
				if(not advtrains.is_track_and_drives_on(nodename, prototype.drives_on)) then
					atprint("no track here, not placing.")
					return itemstack
				end
				if not minetest.check_player_privs(placer, {train_operator = true }) then
					minetest.chat_send_player(pname, "You don't have the train_operator privilege.")
					return itemstack
				end
				if not minetest.check_player_privs(placer, {train_admin = true }) and minetest.is_protected(pointed_thing.under, placer:get_player_name()) then
					return itemstack
				end
				local tconns=advtrains.get_track_connections(node.name, node.param2)
				local yaw = placer:get_look_horizontal()
				local plconnid = advtrains.yawToClosestConn(yaw, tconns)
				
				local prevpos = advtrains.get_adjacent_rail(pointed_thing.under, tconns, plconnid, prototype.drives_on)
				if not prevpos then
					minetest.chat_send_player(pname, "The track you are trying to place the wagon on is not long enough!")
					return
				end
				
				local wid = advtrains.create_wagon(sysname, pname)
				
				local id=advtrains.create_new_train_at(pointed_thing.under, plconnid, 0, {wid})
				
				if not advtrains.is_creative(pname) then
					itemstack:take_item()
				end
				return itemstack
				
			end)
		end,
	})
end

-- Placeholder wagon. Will be spawned whenever a mod is missing
advtrains.register_wagon("advtrains:wagon_placeholder", {
	visual="sprite",
	textures = {"advtrains_wagon_placeholder.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	drives_on = advtrains.all_tracktypes,
	max_speed = 5,
	seats = {
	},
	seat_groups = {
	},
	assign_to_seat_group = {},
	wagon_span=1,
	drops={},
}, "Wagon placeholder", "advtrains_wagon_placeholder.png", true)

