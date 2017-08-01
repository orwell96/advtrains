local S
if minetest.get_modpath("intllib") then
    S = intllib.Getter()
else
    S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

advtrains.register_wagon("newlocomotive", {
	mesh="advtrains_engine_steam.b3d",
	textures = {"advtrains_engine_steam.png"},
	is_locomotive=true,
	drives_on={default=true},
	max_speed=10,
	seats = {
		{
			name=S("Driver Stand (left)"),
			attach_offset={x=-5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
		{
			name=S("Driver Stand (right)"),
			attach_offset={x=5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
	},
	seat_groups = {
		dstand={
			name = "Driver Stand",
			access_to = {},
		},
	},
	assign_to_seat_group = {"dstand"},
	visual_size = {x=1, y=1},
	wagon_span=1.85,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	update_animation=function(self, velocity)
		if self.old_anim_velocity~=advtrains.abs_ceil(velocity) then
			self.object:set_animation({x=1,y=80}, advtrains.abs_ceil(velocity)*15, 0, true)
			self.old_anim_velocity=advtrains.abs_ceil(velocity)
		end
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
}, S("Steam Engine"), "advtrains_engine_steam_inv.png")

advtrains.register_wagon("detailed_steam_engine", {
	mesh="advtrains_detailed_steam_engine.b3d",
	textures = {"advtrains_detailed_steam_engine.png"},
	is_locomotive=true,
	drives_on={default=true},
	max_speed=10,
	seats = {
		{
			name=S("Driver Stand (left)"),
			attach_offset={x=-5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
		{
			name=S("Driver Stand (right)"),
			attach_offset={x=5, y=10, z=-10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
	},
	seat_groups = {
		dstand={
			name = "Driver Stand",
			access_to = {},
		},
	},
	assign_to_seat_group = {"dstand"},
	visual_size = {x=1, y=1},
	wagon_span=2.05,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	update_animation=function(self, velocity)
		if self.old_anim_velocity~=advtrains.abs_ceil(velocity) then
			self.object:set_animation({x=1,y=80}, advtrains.abs_ceil(velocity)*15, 0, true)
			self.old_anim_velocity=advtrains.abs_ceil(velocity)
		end
	end,
	custom_on_activate = function(self, staticdata_table, dtime_s)
		minetest.add_particlespawner({
			amount = 10,
			time = 0,
		--  ^ If time is 0 has infinite lifespan and spawns the amount on a per-second base
			minpos = {x=0, y=2.3, z=1.45},
			maxpos = {x=0, y=2.3, z=1.4},
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
}, S("Detailed Steam Engine"), "advtrains_detailed_engine_steam_inv.png")

advtrains.register_wagon("wagon_default", {
	mesh="advtrains_passenger_wagon.b3d",
	textures = {"advtrains_wagon.png"},
	drives_on={default=true},
	max_speed=10,
	seats = {
		{
			name="1",
			attach_offset={x=-4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="2",
			attach_offset={x=4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="3",
			attach_offset={x=-4, y=8, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="4",
			attach_offset={x=4, y=8, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
	},
	seat_groups = {
		pass={
			name = "Passenger area",
			access_to = {},
		},
	},
	assign_to_seat_group = {"pass"},
	visual_size = {x=1, y=1},
	wagon_span=3.1,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, S("Passenger Wagon"), "advtrains_wagon_inv.png")
advtrains.register_wagon("wagon_box", {
	mesh="advtrains_wagon.b3d",
	textures = {"advtrains_wagon_box.png"},
	drives_on={default=true},
	max_speed=10,
	seats = {},
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,3;]"..
			"list[current_player;main;0,5;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*3,
	},
}, S("Box Wagon"), "advtrains_wagon_box_inv.png")

minetest.register_craft({
	output = 'advtrains:newlocomotive',
	recipe = {
		{'', '', 'advtrains:chimney'},
		{'advtrains:driver_cab', 'dye:black', 'advtrains:boiler'},
		{'advtrains:wheel', 'advtrains:wheel', 'advtrains:wheel'},
	},
})

minetest.register_craft({
	output = 'advtrains:detailed_steam_engine',
	recipe = {
		{'', '', 'advtrains:chimney'},
		{'advtrains:driver_cab', 'dye:green', 'advtrains:boiler'},
		{'advtrains:wheel', 'advtrains:wheel', 'advtrains:wheel'},
	},
})

minetest.register_craft({
	output = 'advtrains:wagon_default',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:glass', 'dye:dark_green', 'default:glass'},
		{'advtrains:wheel', 'advtrains:wheel', 'advtrains:wheel'},
	},
})
minetest.register_craft({
	output = 'advtrains:wagon_box',
	recipe = {
		{'group:wood', 'group:wood', 'group:wood'},
		{'group:wood', 'default:chest', 'group:wood'},
		{'advtrains:wheel', '', 'advtrains:wheel'},
	},
})
