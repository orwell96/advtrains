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

