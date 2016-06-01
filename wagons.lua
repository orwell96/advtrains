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
	print("[advtrains] wagon rightclick")
	if not clicker or not clicker:is_player() then
		return
	end
	if not self.initialized then
		print("[advtrains] not initiaalized")
		return
	end
	if clicker:get_player_control().sneak then
		advtrains.split_train_at_wagon(self)
		return
	end
	if clicker:get_player_control().aux1 then
		--advtrains.dumppath(self:train().path)
		--minetest.chat_send_all("at index "..(self:train().index or "nil"))
		--advtrains.invert_train(self.train_id)
		minetest.chat_send_all(dump(self:train()))
		return
	end	
	if self.driver and clicker == self.driver then
		advtrains.set_trainhud(self.driver:get_player_name(), "")
		self.driver = nil
		clicker:set_detach()
		clicker:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
	elseif not self.driver then
		self.driver = clicker
		clicker:set_attach(self.object, "", self.attach_offset, {x=0,y=0,z=0})
		clicker:set_eye_offset(self.view_offset, self.view_offset)
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
end

function wagon:get_staticdata()
	--save to table before being unloaded
	advtrains.wagon_save[self.unique_id]=advtrains.merge_tables(self)
	return minetest.serialize({
		unique_id=self.unique_id,
		train_id=self.train_id,
		wagon_flipped=self.wagon_flipped,
	})
end

-- Remove the wagon
function wagon:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not puncher or not puncher:is_player() then
		return
	end

		self.object:remove()
		if not self.initialized then return end
		
		local inv = puncher:get_inventory()
		if minetest.setting_getbool("creative_mode") then
			if not inv:contains_item("main", "advtrains:locomotive") then
				inv:add_item("main", "advtrains:locomotive")
			end
		else
			inv:add_item("main", "advtrains:locomotive")
		end
		
		table.remove(self:train().trainparts, self.pos_in_trainparts)
		advtrains.update_trainpart_properties(self.train_id)
		advtrains.wagon_save[self.unique_id]=nil
		if self.discouple_id and minetest.object_refs[self.discouple_id] then minetest.object_refs[self.discouple_id]:remove() end
		return


end

function wagon:on_step(dtime)
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
	
	--DisCouple
	if self.pos_in_trainparts and self.pos_in_trainparts>1 then
		if not self.discouple_id or not minetest.luaentities[self.discouple_id] then
			local object=minetest.add_entity(pos, "advtrains:discouple")
			if object then
				print("spawning discouple")
				local le=object:get_luaentity()
				le.wagon=self
				--box is hidden when attached, so unuseful.
				--object:set_attach(self.object, "", {x=0, y=0, z=self.wagon_span*10}, {x=0, y=0, z=0})
				--find in object_refs
				for aoi, compare in pairs(minetest.object_refs) do
					if compare==object then
						self.discouple_id=aoi
					end
				end
			else
				print("Couldn't spawn DisCouple")
			end
		end
	end
	
	--driver control
	if self.driver and self.is_locomotive then
		if self.driver:get_player_control_bits()~=self.old_player_control_bits then
			local pc=self.driver:get_player_control()
			if pc.sneak then --stop
				self:train().tarvelocity=0
			elseif (not self.wagon_flipped and pc.up) or (self.wagon_flipped and pc.down) then --faster
				self:train().tarvelocity=math.min(self:train().tarvelocity+1, advtrains.all_traintypes[self:train().traintype].max_speed or 10)
			elseif (not self.wagon_flipped and pc.down) or (self.wagon_flipped and pc.up) then --slower
				self:train().tarvelocity=math.max(self:train().tarvelocity-1, -(advtrains.all_traintypes[self:train().traintype].max_speed or 10))
			elseif pc.aux1 then --slower
				if true or math.abs(self:train().velocity)<=3 then--TODO debug
					self.driver:set_detach()
					self.driver:set_eye_offset({x=0,y=0,z=0}, {x=0,y=0,z=0})
					advtrains.set_trainhud(self.driver:get_player_name(), "")
					self.driver = nil
					return--(don't let it crash because of statement below)
				else
					minetest.chat_send_player(self.driver:get_player_name(), "Can't get off driving train!")
				end
			end
			self.old_player_control_bits=self.driver:get_player_control_bits()
		end
		advtrains.set_trainhud(self.driver:get_player_name(), advtrains.hud_train_format(self:train(), self.wagon_flipped))
	end
	
	local gp=self:train()
	--for path to be available. if not, skip step
	if not advtrains.get_or_create_path(self.train_id, gp) then
		self.object:setvelocity({x=0, y=0, z=0})
		return
	end
	
	local pos_in_train_left=self.pos_in_train+0
	local index=gp.index
	if pos_in_train_left>(index-math.floor(index))*(gp.path_dist[math.floor(index)] or 1) then
		pos_in_train_left=pos_in_train_left - (index-math.floor(index))*(gp.path_dist[math.floor(index)] or 1)
		index=math.floor(index)
		while pos_in_train_left>(gp.path_dist[index-1] or 1) do
			pos_in_train_left=pos_in_train_left - (gp.path_dist[index-1] or 1)
			index=index-1
		end
		index=index-(pos_in_train_left/(gp.path_dist[index-1] or 1))
	else
		index=index-(pos_in_train_left*(gp.path_dist[math.floor(index-1)] or 1))
	end
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
					if node and minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].walkable then
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
	
	local velocity=gp.velocity/(gp.path_dist[math.floor(gp.index)] or 1)
	local factor=index-math.floor(index)
	local actual_pos={x=first_pos.x-(first_pos.x-second_pos.x)*factor, y=first_pos.y-(first_pos.y-second_pos.y)*factor, z=first_pos.z-(first_pos.z-second_pos.z)*factor,}
	local velocityvec={x=(first_pos.x-second_pos.x)*velocity*-1, z=(first_pos.z-second_pos.z)*velocity*-1, y=(first_pos.y-second_pos.y)*velocity*-1}
	
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
	if not self.old_velocity_vector or not vector.equals(velocityvec, self.old_velocity_vector) or self.old_yaw~=yaw or self.updatepct_timer<=0 then--only send update packet if something changed
		self.object:setpos(actual_pos)
		self.object:setvelocity(velocityvec)
		self.object:setyaw(yaw)
		self.updatepct_timer=2
	end
	
	self.old_velocity_vector=velocityvec
	self.old_yaw=yaw
end


function advtrains.register_wagon(sysname, traintype, prototype)
	setmetatable(prototype, {__index=wagon})
	minetest.register_entity("advtrains:"..sysname,prototype)
	
	minetest.register_craftitem("advtrains:"..sysname, {
		description = sysname,
		inventory_image = prototype.textures[1],
		wield_image = prototype.textures[1],
		stack_max = 1,
		
		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return
			end
			local le=minetest.env:add_entity(pointed_thing.under, "advtrains:"..sysname):get_luaentity()
			
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
			print(dump(advtrains.trains))
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
			
		end,
	})
end
advtrains.register_train_type("steam", {"regular"})

--[[advtrains.register_wagon("blackwagon", "steam",{textures = {"black.png"}})
advtrains.register_wagon("bluewagon", "steam",{textures = {"blue.png"}})
advtrains.register_wagon("greenwagon", "steam",{textures = {"green.png"}})
advtrains.register_wagon("redwagon", "steam",{textures = {"red.png"}})
advtrains.register_wagon("yellowwagon", "steam",{textures = {"yellow.png"}})
]]
advtrains.register_wagon("newlocomotive", "steam",{
	mesh="newlocomotive.b3d",
	textures = {"advtrains_newlocomotive.png"},
	is_locomotive=true,
	attach_offset={x=5, y=10, z=-10},
	view_offset={x=0, y=6, z=18},
	visual_size = {x=1, y=1},
	wagon_span=1.85,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
})
advtrains.register_wagon("wagon_default", "steam",{
	mesh="wagon.b3d",
	textures = {"advtrains_wagon.png"},
	attach_offset={x=0, y=10, z=0},
	view_offset={x=0, y=6, z=0},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
})

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


