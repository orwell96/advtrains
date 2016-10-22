--atan2 counts angles clockwise, minetest does counterclockwise
local print=function(t) minetest.log("action", t) minetest.chat_send_all(t) end

local wagon={
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	--physical = true,
	visual = "mesh",
	mesh = "wagon.b3d",
	visual_size = {x=3, y=3},
	textures = {"black.png"},
	is_wagon=true,
	wagon_span=1,--how many index units of space does this wagon consume
	attach_offset={x=0, y=0, z=0},
	view_offset={x=0, y=0, z=0},
}



function wagon:on_rightclick(clicker)
	--print("[advtrains] wagon rightclick")
	if not clicker or not clicker:is_player() then
		return
	end
	if not self.initialized then
		print("[advtrains] not initiaalized")
		return
	end
	if clicker:get_player_control().aux1 then
		--advtrains.dumppath(self:train().path)
		--minetest.chat_send_all("at index "..(self:train().index or "nil"))
		--advtrains.invert_train(self.train_id)
		minetest.chat_send_all(dump(self:train()))
		return
	end	
	local no=self:get_seatno(clicker:get_player_name())
	if no then
		self:get_off(no)
	else
		self:show_get_on_form(clicker:get_player_name())
	end
end

function wagon:train()
	return advtrains.trains[self.train_id]
end

function wagon:on_activate(staticdata, dtime_s)
	--print("[advtrains][wagon "..(self.unique_id or "no-id").."] activated")
	self.object:set_armor_groups({immortal=1})
	if staticdata then
		local tmp = minetest.deserialize(staticdata)
		if tmp then
			self.unique_id=tmp.unique_id
			self.train_id=tmp.train_id
			self.wagon_flipped=tmp.wagon_flipped
			self.owner=tmp.owner
			self.seatp=tmp.seatp
		end

	end
	self.old_pos = self.object:getpos()
	self.old_velocity = self.velocity
	self.initialized_pre=true
	self.entity_name=self.name
	
	--same code is in on_step
	--does this object already have an ID?
	if not self.unique_id then
		self.unique_id=os.time()..os.clock()--should be random enough.
	else
		for _,wagon in pairs(minetest.luaentities) do
			if wagon.is_wagon and wagon.initialized and wagon.unique_id==self.unique_id then--i am a duplicate!
				self.object:remove()
				return
			end
		end
	end
	--is my train still here
	if not self.train_id or not self:train() then
		if self.initialized then
			print("[advtrains][wagon "..self.unique_id.."] missing train_id, destroying")
			self.object:remove()
			return
		end
		print("[advtrains][wagon "..self.unique_id.."] missing train_id, but not yet initialized, returning")
		return
	elseif not self.initialized then
		self.initialized=true
	end
	advtrains.update_trainpart_properties(self.train_id)
	minetest.after(1, function() self:reattach_all() end)
end

function wagon:get_staticdata()
	--save to table before being unloaded
	advtrains.wagon_save[self.unique_id]=advtrains.merge_tables(self)
	return minetest.serialize({
		unique_id=self.unique_id,
		train_id=self.train_id,
		wagon_flipped=self.wagon_flipped,
		owner=self.owner,
		seatp=self.seatp,
	})
end

-- Remove the wagon
function wagon:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() then
		return
	end
	if self.owner and puncher:get_player_name()~=self.owner then
		minetest.chat_send_player(puncher:get_player_name(), "This wagon is owned by "..self.owner..", you can't destroy it.")
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
			minetest.chat_send_player(puncher:get_player_name(), "Warning: If you destroy this wagon, you only get some steel back! If you are sure, shift-leftclick the wagon.")
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
	
	self.object:remove()

	if not self.initialized then return end

	table.remove(self:train().trainparts, self.pos_in_trainparts)
	advtrains.update_trainpart_properties(self.train_id)
	advtrains.wagon_save[self.unique_id]=nil
	if self.discouple then self.discouple.object:remove() end--will have no effect on unloaded objects
	return true
end


function wagon:on_step(dtime)
	local t=os.clock()
	local pos = self.object:getpos()
	if not self.initialized_pre then 
		print("[advtrains] wagon stepping while not yet initialized_pre, returning")
		self.object:setvelocity({x=0,y=0,z=0})
		return
	end

	self.entity_name=self.name
	--does this object already have an ID?
	if not self.unique_id then
		self.unique_id=os.time()..os.clock()--should be random enough.
	end
	--is my train still here
	if not self.train_id or not self:train() then
		print("[advtrains][wagon "..self.unique_id.."] missing train_id, destroying")
		self.object:remove()
		return
	elseif not self.initialized then
		self.initialized=true
	end

	--re-attach driver if he got lost
	--if not self.driver and self.driver_name then
	--	local clicker=minetest.get_player_by_name(self.driver_name)
	--	if clicker then
	--		self.driver = clicker
	--		advtrains.player_to_wagon_mapping[clicker:get_player_name()]=self
	--		clicker:set_attach(self.object, "", self.attach_offset, {x=0,y=0,z=0})
	--		clicker:set_eye_offset(self.view_offset, self.view_offset)
	--	end
	--end

	--custom on_step function
	if self.custom_on_step then
		self.custom_on_step(self, dtime)
	end

	--driver control
	for seatno, seat in ipairs(self.seats) do
		if seat.driving_ctrl_access then
			if not self.seatp then
				self.seatp={}
			end
			local driver=self.seatp[seatno] and minetest.get_player_by_name(self.seatp[seatno])
			if driver and driver:get_player_control_bits()~=self.old_player_control_bits then
				local pc=driver:get_player_control()
				if pc.sneak then --stop
					self:train().tarvelocity=0
				elseif (not self.wagon_flipped and pc.up) or (self.wagon_flipped and pc.down) then --faster
					self:train().tarvelocity=math.min(self:train().tarvelocity+1, advtrains.all_traintypes[self:train().traintype].max_speed or 10)
				elseif (not self.wagon_flipped and pc.down) or (self.wagon_flipped and pc.up) then --slower
					self:train().tarvelocity=math.max(self:train().tarvelocity-1, -(advtrains.all_traintypes[self:train().traintype].max_speed or 10))
				elseif pc.aux1 then --slower
					if true or math.abs(self:train().velocity)<=3 then--TODO debug
						self:get_off(seatno)
						return
					else
						minetest.chat_send_player(driver:get_player_name(), "Can't get off driving train!")
					end
				end
				self.old_player_control_bits=driver:get_player_control_bits()
			end
			if driver then
				advtrains.set_trainhud(driver:get_player_name(), advtrains.hud_train_format(self:train(), self.wagon_flipped))
			end
		end
	end

	local gp=self:train()

	--DisCouple
	if self.pos_in_trainparts and self.pos_in_trainparts>1 then
		if gp.velocity==0 then
			if not self.discouple or not self.discouple.object:getyaw() then
				local object=minetest.add_entity(pos, "advtrains:discouple")
				if object then
					local le=object:get_luaentity()
					le.wagon=self
					--box is hidden when attached, so unuseful.
					--object:set_attach(self.object, "", {x=0, y=0, z=self.wagon_span*10}, {x=0, y=0, z=0})
					self.discouple=le
				else
					print("Couldn't spawn DisCouple")
				end
			end
		else
			if self.discouple and self.discouple.object:getyaw() then
				self.discouple.object:remove()
			end
		end
	end
	--for path to be available. if not, skip step
	if not advtrains.get_or_create_path(self.train_id, gp) then
		self.object:setvelocity({x=0, y=0, z=0})
		return
	end
	
	local index=advtrains.get_real_path_index(self:train(), self.pos_in_train)
	--print("trainindex "..gp.index.." wagonindex "..index)
	
	--position recalculation
	local first_pos=gp.path[math.floor(index)]
	local second_pos=gp.path[math.floor(index)+1]
	if not first_pos or not second_pos then
		--print("[advtrains] object "..self.unique_id.." path end reached!")
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
			gp.recently_collided_with_env=true
			gp.velocity=-0.5*gp.velocity
			gp.tarvelocity=0
		end
	end
	
	--FIX: use index of the wagon, not of the train.
	local velocity=gp.velocity/(gp.path_dist[math.floor(index)] or 1)
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
	printbm("wagon step", t)
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

function wagon:get_on(clicker, seatno)
	if not self.seatp then
		self.seatp={}
	end
	if not self.seats[seatno] then return end
	if self.seatp[seatno] then
		self:get_off(seatno)
	end
	self.seatp[seatno] = clicker:get_player_name()
	advtrains.player_to_wagon_mapping[clicker:get_player_name()]={wagon=self, seatno=seatno}
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
	for no, cont in ipairs(self.seatp) do
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
	advtrains.player_to_wagon_mapping[pname]=nil
	advtrains.set_trainhud(pname, "")
	if clicker then
		clicker:set_detach()
		clicker:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
	end
	self.seatp[seatno]=nil
end
function wagon:show_get_on_form(pname)
	if not self.initialized then return end
	local form, comma="size[5,7]label[0.5,0.5;Select seat:]textlist[0.5,1;4,6;seat;", ""
	for seatno, seattbl in ipairs(self.seats) do
		local addtext, colorcode="", ""
		if self.seatp and self.seatp[seatno] then
			colorcode="#FF0000"
			addtext=" ("..self.seatp[seatno]..")"
		end
		form=form..comma..colorcode..seattbl.name..addtext
		comma=","
	end
	minetest.show_formspec(pname, "advtrains_geton_"..self.unique_id, form..";0,false")
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local uid=string.match(formname, "^advtrains_geton_(.+)$")
	if uid and fields.seat then
		local val=minetest.explode_textlist_event(fields.seat)
		if val and val.type=="CHG" then
			--get on
			for _,wagon in pairs(minetest.luaentities) do
				if wagon.is_wagon and wagon.initialized and wagon.unique_id==uid then
					wagon:get_on(player, val.index)
					minetest.show_formspec(player:get_player_name(), "none", "")
				end
			end
		end
	end
end)
function wagon:reattach_all()
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

function advtrains.register_wagon(sysname, traintype, prototype, desc, inv_img)
	setmetatable(prototype, {__index=wagon})
	minetest.register_entity("advtrains:"..sysname,prototype)
	
	minetest.register_craftitem("advtrains:"..sysname, {
		description = desc,
		inventory_image = inv_img,
		wield_image = inv_img,
		stack_max = 1,
		
		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return
			end
			local ob=minetest.env:add_entity(pointed_thing.under, "advtrains:"..sysname)
			if not ob then
				print("[advtrains]couldn't add_entity, aborting")
			end
			local le=ob:get_luaentity()
			
			le.owner=placer:get_player_name()
			le.infotext=desc..", owned by "..placer:get_player_name()
			
			local node=minetest.env:get_node_or_nil(pointed_thing.under)
			if not node then print("[advtrains]Ignore at placer position") return itemstack end
			local nodename=node.name
			if(not advtrains.is_track_and_drives_on(nodename, advtrains.all_traintypes[traintype].drives_on)) then
				print("[advtrains]no trck here, not placing.")
				return itemstack
			end
			local conn1=advtrains.get_track_connections(node.name, node.param2)
			local id=advtrains.create_new_train_at(pointed_thing.under, advtrains.dirCoordSet(pointed_thing.under, conn1), traintype)
			advtrains.add_wagon_to_train(le, id)
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
			
		end,
	})
end
advtrains.register_train_type("steam", {"regular", "default"})

--[[advtrains.register_wagon("blackwagon", "steam",{textures = {"black.png"}})
advtrains.register_wagon("bluewagon", "steam",{textures = {"blue.png"}})
advtrains.register_wagon("greenwagon", "steam",{textures = {"green.png"}})
advtrains.register_wagon("redwagon", "steam",{textures = {"red.png"}})
advtrains.register_wagon("yellowwagon", "steam",{textures = {"yellow.png"}})
]]

--[[
	wagons can define update_animation(self, velocity) if they have a speed-dependent animation
	this function will be called when the velocity vector changes or every 2 seconds.
]]
advtrains.register_wagon("newlocomotive", "steam",{
	mesh="advtrains_engine_steam.b3d",
	textures = {"advtrains_newlocomotive.png"},
	is_locomotive=true,
	seats = {
		{
			name="Driver Stand (left)",
			attach_offset={x=-5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
		{
			name="Driver Stand (right)",
			attach_offset={x=5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=1.85,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	update_animation=function(self, velocity)
		--if self.old_anim_velocity~=advtrains.abs_ceil(velocity) then
			self.object:set_animation({x=1,y=60}, 100)--math.floor(velocity))
			--self.old_anim_velocity=advtrains.abs_ceil(velocity)
		--end
	end,
	drops={"default:steelblock 4"},
}, "Steam Engine", "advtrains_newlocomotive_inv.png")
advtrains.register_wagon("wagon_default", "steam",{
	mesh="wagon.b3d",
	textures = {"advtrains_wagon.png"},
	seats = {
		{
			name="Default Seat",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Passenger Wagon", "advtrains_wagon_inv.png")

advtrains.register_train_type("electric", {"regular", "default"}, 20)

advtrains.register_wagon("engine_japan", "electric",{
	mesh="advtrains_engine_japan.b3d",
	textures = {"advtrains_engine_japan.png"},
	seats = {
		{
			name="Default Seat (driver stand)",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Engine", "green.png")

advtrains.register_wagon("wagon_japan", "electric",{
	mesh="advtrains_wagon_japan.b3d",
	textures = {"advtrains_wagon_japan.png"},
	seats = {
		{
			name="Default Seat",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Wagon", "blue.png")


advtrains.register_train_type("subway", {"default"}, 15)

advtrains.register_wagon("subway_wagon", "subway",{
	mesh="advtrains_subway_train.b3d",
	textures = {"advtrains_subway_train.png"},
	seats = {
		{
			name="Default Seat (driver stand)",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	is_locomotive=true,
	drops={"default:steelblock 4"},
}, "Subway Passenger Wagon", "advtrains_subway_train_inv.png")
--[[
advtrains.register_wagon("wagontype1",{on_rightclick=function(self, clicker)
	if clicker:get_player_control().sneak then
		advtrains.disconnect_train_before_wagon(self)
		return
	end
	--just debugging. look for first active wagon and attach to it.
	for _,v in pairs(minetest.luaentities) do
		if v.is_wagon and v.unique_id and v.unique_id~=self.unique_id then
			self.train_id=v.unique_id
		end
	end
	if not self.train_id then minetest.chat_send_all("not found") return end
	minetest.chat_send_all(self.train_id.." found and attached.")
end})
]]


