--atan2 counts angles clockwise, minetest does counterclockwise
--local print=function(t) minetest.log("action", t) minetest.chat_send_all(t) end
local print=function() end

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



function wagon:on_rightclick(clicker)
	if not self:ensure_init() then return end
	if not clicker or not clicker:is_player() then
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

--[[about 'initalized':
	when initialized is false, the entity hasn't got any data yet and should wait for these to be set before doing anything
	when loading an existing object (with staticdata), it will be set
	when instanciating a new object via add_entity, it is not set at the time on_activate is called.
	then, wagon:initialize() will be called
	
	wagon will save only uid in staticdata, no serialized table
]]
function wagon:on_activate(sd_uid, dtime_s)
	print("[advtrains][wagon "..((sd_uid and sd_uid~="" and sd_uid) or "no-id").."] activated")
	self.object:set_armor_groups({immortal=1})
	if sd_uid and sd_uid~="" then
		--legacy
		--expect this to be a serialized table and handle
		if minetest.deserialize(sd_uid) then
			self:init_from_wagon_save(minetest.deserialize(sd_uid).unique_id)
		else
			self:init_from_wagon_save(sd_uid)
		end
	end
	self.entity_name=self.name
	
	--duplicates?
	for ao_id,wagon in pairs(minetest.luaentities) do
		if wagon.is_wagon and wagon.initialized and wagon.unique_id==self.unique_id and wagon~=self then--i am a duplicate!
			print("[advtrains][wagon "..((sd_uid and sd_uid~="" and sd_uid) or "no-id").."] duplicate found(ao_id:"..ao_id.."), removing")
			self.object:remove()
			minetest.after(0.5, function() advtrains.update_trainpart_properties(self.train_id) end)
			return
		end
	end
	
	if self.custom_on_activate then
		self:custom_on_activate(staticdata_table, dtime_s)
	end
end

function wagon:get_staticdata()
	if not self:ensure_init() then return end
	print("[advtrains][wagon "..((self.unique_id and self.unique_id~="" and self.unique_id) or "no-id").."]: saving to wagon_save")
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
	print("init_new_instance "..self.unique_id.." ("..self.train_id..")")
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
	minetest.after(1, function() self:reattach_all() end)
	print("init_from_wagon_save "..self.unique_id.." ("..self.train_id..")")
	advtrains.update_trainpart_properties(self.train_id)
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
end
function wagon:ensure_init()
	if self.initialized then return true end
	self.object:setvelocity({x=0,y=0,z=0})
	return false
end

-- Remove the wagon
function wagon:on_punch(puncher, time_from_last_punch, tool_capabilities, direction)
	if not self:ensure_init() then return end
	if not puncher or not puncher:is_player() then
		return
	end
	if self.owner and puncher:get_player_name()~=self.owner and (not minetest.check_player_privs(puncher, {train_remove = true })) then
	   minetest.chat_send_player(puncher:get_player_name(), "This wagon is owned by "..self.owner..", you can't destroy it.");
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
	
	print("[advtrains][wagon "..((self.unique_id and self.unique_id~="" and self.unique_id) or "no-id").."]: destroying")
	
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
		print("["..self.unique_id.."][fatal] missing position (object:getpos() returned nil)")
		return
	end

	self.entity_name=self.name
	
	--is my train still here
	if not self.train_id or not self:train() then
		print("[advtrains][wagon "..self.unique_id.."] missing train_id, destroying")
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
	if not self.pos_in_train then
		--why ever. but better continue next step...
		advtrains.update_trainpart_properties(self.train_id)
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
	if self.seatp[seatno] and self.seatp[seatno]~=clicker:get_player_name() then
		self:get_off(seatno)
	end
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
			minetest.show_formspec(pname, "advtrains_inv_"..self.unique_id, self:get_inventory_formspec())
		end
		return
	end
	local form, comma="size[5,8]label[0.5,0.5;Select seat:]textlist[0.5,1;4,6;seat;", ""
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
		form=form.."button_exit[1,7;3,1;inv;Show Inventory]"
	end
	minetest.show_formspec(pname, "advtrains_geton_"..self.unique_id, form)
end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	local uid=string.match(formname, "^advtrains_geton_(.+)$")
	if uid then
		for _,wagon in pairs(minetest.luaentities) do
			if wagon.is_wagon and wagon.initialized and wagon.unique_id==uid then
				if fields.inv then
					if wagon.has_inventory and wagon.get_inventory_formspec then
						minetest.show_formspec(player:get_player_name(), "advtrains_inv_"..uid, wagon:get_inventory_formspec())
					end
				elseif fields.seat then
					local val=minetest.explode_textlist_event(fields.seat)
					if val and val.type~="INV" then
					--get on
						wagon:get_on(player, val.index)
						--will work with the new close_formspec functionality. close exactly this formspec.
						minetest.show_formspec(player:get_player_name(), formname, "")
					end
				end
			end
		end
	end
end)
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
			
			local node=minetest.get_node_or_nil(pointed_thing.under)
			if not node then print("[advtrains]Ignore at placer position") return itemstack end
			local nodename=node.name
			if(not advtrains.is_track_and_drives_on(nodename, advtrains.all_traintypes[traintype].drives_on)) then
				print("[advtrains]no track here, not placing.")
				return itemstack
			end
			local conn1=advtrains.get_track_connections(node.name, node.param2)
			local id=advtrains.create_new_train_at(pointed_thing.under, advtrains.dirCoordSet(pointed_thing.under, conn1), traintype)
			
			local ob=minetest.add_entity(pointed_thing.under, "advtrains:"..sysname)
			if not ob then
				print("[advtrains]couldn't add_entity, aborting")
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
	custom_on_activate = function(self, staticdata_table, dtime_s)
		minetest.add_particlespawner({
			amount = 10,
			time = 0,
		--  ^ If time is 0 has infinite lifespan and spawns the amount on a per-second base
			minpos = {x=0, y=2, z=1.2},
			maxpos = {x=0, y=2, z=1.2},
			minvel = {x=-0.2, y=1.8, z=-0.2},
			maxvel = {x=0.2, y=2, z=0.2},
			minacc = {x=0, y=-0.1, z=0},
			maxacc = {x=0, y=-0.3, z=0},
			minexptime = 2,
			maxexptime = 4,
			minsize = 1,
			maxsize = 5,
		--  ^ The particle's properties are random values in between the bounds:
		--  ^ minpos/maxpos, minvel/maxvel (velocity), minacc/maxacc (acceleration),
		--  ^ minsize/maxsize, minexptime/maxexptime (expirationtime)
			collisiondetection = true,
		--  ^ collisiondetection: if true uses collision detection
			vertical = false,
		--  ^ vertical: if true faces player using y axis only
			texture = "smoke_puff.png",
		--  ^ Uses texture (string)
			attached = self.object,
		})
	end,
	drops={"default:steelblock 4"},
}, "Steam Engine", "advtrains_newlocomotive_inv.png")
advtrains.register_wagon("wagon_default", "steam",{
	mesh="advtrains_wagon.b3d",
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
advtrains.register_wagon("wagon_box", "steam",{
	mesh="advtrains_wagon.b3d",
	textures = {"advtrains_wagon_box.png"},
	seats = {},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,6;]"..
			"list[current_player;main;0,7;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*6,
	},
}, "Box Wagon", "advtrains_wagon_box_inv.png")

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
	wagon_span=2.5,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Engine", "advtrains_engine_japan_inv.png")

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
	wagon_span=2.3,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Wagon", "advtrains_wagon_japan_inv.png")

advtrains.register_wagon("engine_industrial", "electric",{
	mesh="advtrains_engine_industrial.b3d",
	textures = {"advtrains_engine_industrial.png"},
	seats = {
		{
			name="Driver Stand (left)",
			attach_offset={x=-5, y=10, z=-10},
			view_offset={x=0, y=10, z=0},
			driving_ctrl_access=true,
		},
		{
			name="Driver Stand (right)",
			attach_offset={x=5, y=10, z=-10},
			view_offset={x=0, y=10, z=0},
			driving_ctrl_access=true,
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2.6,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Industrial Train Engine", "advtrains_engine_industrial_inv.png")
advtrains.register_wagon("wagon_tank", "electric",{
	mesh="advtrains_wagon_tank.b3d",
	textures = {"advtrains_wagon_tank.png"},
	seats = {},
	visual_size = {x=1, y=1},
	wagon_span=2.2,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,6;]"..
			"list[current_player;main;0,7;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*6,
	},
}, "Industrial tank wagon", "advtrains_wagon_tank_inv.png")
advtrains.register_wagon("wagon_wood", "electric",{
	mesh="advtrains_wagon_wood.b3d",
	textures = {"advtrains_wagon_wood.png"},
	seats = {},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,6;]"..
			"list[current_player;main;0,7;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*6,
	},
}, "Industrial wood wagon", "advtrains_wagon_wood_inv.png")

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



