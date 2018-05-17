--couple.lua
--defines couple entities.

--advtrains:discouple
--set into existing trains to split them when punched.
--they are attached to the wagons.
--[[fields
wagon

wagons keep their couple entity minetest-internal id inside the field discouple_id. if it refers to nowhere, they will spawn a new one if player is near
]]

local couple_max_dist=3

minetest.register_entity("advtrains:discouple", {
	visual="sprite",
	textures = {"advtrains_discouple.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	
	is_discouple=true,
	on_activate=function(self, staticdata) 
		if staticdata=="DISCOUPLE" then
			--couple entities have no right to exist further...
			atprint("Discouple loaded from staticdata, destroying")
			self.object:remove()
			return
		end
		self.object:set_armor_groups({immortal=1})
	end,
	get_staticdata=function() return "DISCOUPLE" end,
	on_punch=function(self, player)
		return advtrains.pcall(function()
			local pname = player:get_player_name()
			if pname and pname~="" and self.wagon then
				if self.wagon:safe_decouple(pname) then
					self.object:remove()
				else
					minetest.add_entity(self.object:getpos(), "advtrains:lockmarker")
				end
			end
		end)
	end,
	on_step=function(self, dtime)
		return advtrains.pcall(function()
			local t=os.clock()
			if not self.wagon then
				self.object:remove()
				atprint("Discouple: no wagon, destroying")
				return
			end
			--getyaw seems to be a reliable method to check if an object is loaded...if it returns nil, it is not.
			if not self.wagon.object:getyaw() then
				atprint("Discouple: wagon no longer loaded, destroying")
				self.object:remove()
				return
			end
			atprintbm("discouple_step", t)
		end)
	end,
})

-- advtrains:couple
-- Couple entity 
local function lockmarker(obj)
	minetest.spawn_entity(obj:get_pos(), "advtrains.lockmarker")
	obj:remove()
end

minetest.register_entity("advtrains:couple", {
	visual="sprite",
	textures = {"advtrains_couple.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	
	is_couple=true,
	on_activate=function(self, staticdata)
		return advtrains.pcall(function()
			if staticdata=="COUPLE" then
				--couple entities have no right to exist further...
				atprint("Couple loaded from staticdata, destroying")
				self.object:remove()
				return
			end
			self.object:set_armor_groups({immmortal=1})
		end)
	end,
	get_staticdata=function(self) return "COUPLE" end,
	on_rightclick=function(self, clicker)
		return advtrains.pcall(function()
			if not self.train_id_1 or not self.train_id_2 then return end
			
			local pname=clicker
			if type(clicker)~="string" then pname=clicker:get_player_name() end
			if not minetest.check_player_privs(pname, "train_operator") then return end
			
			local train1=advtrains.trains[self.train_id_1]
			local train2=advtrains.trains[self.train_id_2]
			advtrains.train_ensure_init(self.train_id_1, train1)
			advtrains.train_ensure_init(self.train_id_2, train2)
			
			local id1, id2=self.train_id_1, self.train_id_2
			local bp1, bp2 = self.t1_is_backpos, self.t2_is_backpos
			if not bp1 then
				if train1.couple_lock_front then
					lockmarker(self.object)
					return
				end
				if not bp2 then
					if train2.couple_lock_front then
						lockmarker(self.object)
						return
					end
					advtrains.invert_train(id1)
					advtrains.do_connect_trains(id1, id2, clicker)
				else
					if train2.couple_lock_back then
						lockmarker(self.object)
						return
					end
					advtrains.do_connect_trains(id2, id1, clicker)
				end
			else
				if train1.couple_lock_back then
					lockmarker(self.object)
					return
				end
				if not bp2 then
					if train2.couple_lock_front then
						lockmarker(self.object)
						return
					end
					advtrains.do_connect_trains(id1, id2, clicker)
				else
					if train2.couple_lock_back then
						lockmarker(self.object)
						return
					end
					advtrains.invert_train(id2)
				advtrains.do_connect_trains(id1, id2, clicker)
				end
			end
			
			atprint("Coupled trains", id1, id2)
			self.object:remove()
		end)
	end,
	on_step=function(self, dtime)
		return advtrains.pcall(function()
			advtrains.atprint_context_tid=self.train_id_1

			if not self.train_id_1 or not self.train_id_2 then atprint("Couple: train ids not set!") self.object:remove() return end
			local train1=advtrains.trains[self.train_id_1]
			local train2=advtrains.trains[self.train_id_2]
			if not train1 or not train2 then
				atprint("Couple: trains missing, destroying")
				self.object:remove()
				return
			end
			
			advtrains.train_ensure_init(self.train_id_1, train1)
			advtrains.train_ensure_init(self.train_id_2, train2)
			
			if train1.velocity>0 or train2.velocity>0 then
				if not self.position_set then --ensures that train stands a single time before check fires. Using flag below
					return
				end
				atprint("Couple: train is moving, destroying")
				self.object:remove()
				return
			end
			
			if not self.position_set then
				local tp1
				if not self.train1_is_backpos then
					tp1=advtrains.path_get_interpolated(train1, train1.index)
				else
					tp1=advtrains.path_get_interpolated(train1, train1.end_index)
				end
				local tp2
				if not self.train2_is_backpos then
					tp2=advtrains.path_get_interpolated(train2, train2.index)
				else
					tp2=advtrains.path_get_interpolated(train2, train2.end_index)
				end
				local pos_median=advtrains.pos_median(tp1, tp2)
				if not vector.equals(pos_median, self.object:getpos()) then
					self.object:setpos(pos_median)
				end
				self.position_set=true
			end
			atprintbm("couple step", t)
			advtrains.atprint_context_tid=nil

		end)
	end,
})
minetest.register_entity("advtrains:lockmarker", {
	visual="sprite",
	textures = {"advtrains_cpl_lock.png"},
	collisionbox = {-0.3,-0.3,-0.3, 0.3,0.3,0.3},
	visual_size = {x=0.7, y=0.7},
	initial_sprite_basepos = {x=0, y=0},
	
	is_lockmarker=true,
	on_activate=function(self, staticdata)
		return advtrains.pcall(function()
			if staticdata=="COUPLE" then
				--couple entities have no right to exist further...
				atprint("Couple loaded from staticdata, destroying")
				self.object:remove()
				return
			end
			self.object:set_armor_groups({immmortal=1})
			self.life=5
		end)
	end,
	get_staticdata=function(self) return "COUPLE" end,
	on_step=function(self, dtime)
		self.life=(self.life or 5)-dtime
		if self.life<0 then
			self.object:remove()
		end
	end,
}) 
