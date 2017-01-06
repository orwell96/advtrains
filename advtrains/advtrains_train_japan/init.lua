advtrains.register_wagon("engine_japan", {
	mesh="advtrains_engine_japan.b3d",
	textures = {"advtrains_engine_japan.png"},
	drives_on={default=true},
	max_speed=20,
	seats = {
		{
			name="Driver stand",
			attach_offset={x=0, y=10, z=6},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
		{
			name="1",
			attach_offset={x=-5, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
		{
			name="2",
			attach_offset={x=5, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2.5,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Engine", "advtrains_engine_japan_inv.png")

advtrains.register_wagon("wagon_japan", {
	mesh="advtrains_wagon_japan.b3d",
	textures = {"advtrains_wagon_japan.png"},
	drives_on={default=true},
	max_speed=20,
	seats = {
		{
			name="1",
			attach_offset={x=-5, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
		{
			name="2",
			attach_offset={x=5, y=10, z=0},
			view_offset={x=0, y=6, z=0},
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2.3,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
}, "Japanese Train Wagon", "advtrains_wagon_japan_inv.png")

