--couple.lua
--defines couple entities.

--advtrains:discouple
--set into existing trains to split them when punched.
--they are attached to the wagons.
--[[fields
wagon

wagons keep their couple entity minetest-internal id inside the field discouple_id. if it refers to nowhere, they will spawn a new one if player is near
]]


minetest.register_entity("advtrains:discouple", {
	visual="sprite",
	textures = {"advtrains_discouple.png"},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual_size = {x=1, y=1},
	initial_sprite_basepos = {x=0, y=0},
	
	is_discouple=true,
	on_activate=function(self, staticdata) 
		if staticdata=="DISCOUPLE" then
			--couple entities have no right to exist further...
			self.object:remove()
			return
		end
		self.object:set_armor_groups({immortal=1})
	end,
	get_staticdata=function() return "DISCOUPLE" end,
	on_punch=function(self, player)
		--only if player owns at least one wagon next to this
		local own=player:get_player_name()
		if self.wagon.owner and self.wagon.owner==own then
			local train=advtrains.trains[self.wagon.train_id]
			local nextwgn_id=train.trainparts[self.wagon.pos_in_trainparts-1]
			for aoi, le in pairs(minetest.luaentities) do
				if le and le.is_wagon then
					if le.unique_id==nextwgn_id then
						if le.owner and le.owner~=own then
							minetest.chat_send_player(own, attrans("You need to own at least one neighboring wagon to destroy this couple."))
							return
						end
					end
				end
			end
			advtrains.split_train_at_wagon(self.wagon)--found in trainlogic.lua
			self.object:remove()
		else
			minetest.chat_send_player(own, attrans("You need to own at least one neighboring wagon to destroy this couple."))
		end
	end,
	on_step=function(self, dtime)
		local t=os.clock()
		if not self.wagon then
			self.object:remove()
			return
		end
		--getyaw seems to be a reliable method to check if an object is loaded...if it returns nil, it is not.
		if not self.wagon.object:getyaw() then
			self.object:remove()
			return
		end
		local velocityvec=self.wagon.object:getvelocity()
		self.updatepct_timer=(self.updatepct_timer or 0)-dtime
		if not self.old_velocity_vector or not vector.equals(velocityvec, self.old_velocity_vector) or self.updatepct_timer<=0 then--only send update packet if something changed
			local flipsign=self.wagon.wagon_flipped and -1 or 1
			self.object:setpos(vector.add(self.wagon.object:getpos(), {y=0, x=-math.sin(self.wagon.object:getyaw())*self.wagon.wagon_span*flipsign, z=math.cos(self.wagon.object:getyaw())*self.wagon.wagon_span*flipsign}))
			self.object:setvelocity(velocityvec)
			self.updatepct_timer=2
		end
		atprintbm("discouple_step", t)
	end,
})

--advtrains:couple
--when two trains overlap with their end-positions, this entity will be spawned and both trains set its id into appropiate fields for them to know when to free them again. The entity will destroy automatically when it recognizes that any of the trains left the common position. 
--[[fields
train_id_1
train_id_2
train1_is_backpos
train2_is_backpos
]]


minetest.register_entity("advtrains:couple", {
	visual="sprite",
	textures = {"advtrains_couple.png"},
	collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},
	visual_size = {x=1, y=1},
	initial_sprite_basepos = {x=0, y=0},
	
	is_couple=true,
	on_activate=function(self, staticdata) 
		if staticdata=="COUPLE" then
			--couple entities have no right to exist further...
			self.object:remove()
			return
		end
	end,
	get_staticdata=function(self) return "COUPLE" end,
	on_rightclick=function(self)
		if not self.train_id_1 or not self.train_id_2 then return end
		
		local id1, id2=self.train_id_1, self.train_id_2
		
		if self.train1_is_backpos and not self.train2_is_backpos then
			advtrains.do_connect_trains(id1, id2)
			--case 2 (second train is front)
		elseif self.train2_is_backpos and not self.train1_is_backpos then
			advtrains.do_connect_trains(id2, id1)
			--case 3 
		elseif self.train1_is_backpos and self.train2_is_backpos then
			advtrains.invert_train(id2)
			advtrains.do_connect_trains(id1, id2)
			--case 4 
		elseif not self.train1_is_backpos and not self.train2_is_backpos then
			advtrains.invert_train(id1)
			advtrains.do_connect_trains(id1, id2)
		end
		self.object:remove()
	end,
	on_step=function(self, dtime)
		local t=os.clock()
		if not self.train_id_1 or not self.train_id_2 then atprint("wtf no train ids?")return end
		local train1=advtrains.trains[self.train_id_1]
		local train2=advtrains.trains[self.train_id_2]
		if not train1 or not train2 or not train1.path or not train2.path or not train1.index or not train2.index then
			self.object:remove()
			return
		end
		
		local tp1
		if not self.train1_is_backpos then
			tp1=advtrains.get_real_index_position(train1.path, train1.index)
		else
			tp1=advtrains.get_real_index_position(train1.path, advtrains.get_train_end_index(train1))
		end
		local tp2
		if not self.train2_is_backpos then
			tp2=advtrains.get_real_index_position(train2.path, train2.index)
		else
			tp2=advtrains.get_real_index_position(train2.path, advtrains.get_train_end_index(train2))
		end
		if not tp1 or not tp2 or not (vector.distance(tp1,tp2)<1.5) then
			self.object:remove()
			return
		else
			local pos_median=advtrains.pos_median(tp1, tp2)
			if not vector.equals(pos_median, self.object:getpos()) then
				self.object:setpos(pos_median)
			end
		end
		atprintbm("couple step", t)
	end,
}) 
