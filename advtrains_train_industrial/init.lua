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
