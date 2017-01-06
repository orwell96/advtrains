
advtrains.register_wagon("subway_wagon", {
	mesh="advtrains_subway_train.b3d",
	textures = {"advtrains_subway_train.png"},
	drives_on={default=true},
	max_speed=15,
	seats = {
		{
			name="Front driver stand",
			attach_offset={x=0, y=10, z=10},
			view_offset={x=0, y=6, z=0},
			driving_ctrl_access=true,
		},
		{
			name="Back driver stand",
			attach_offset={x=0, y=10, z=10},
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
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	is_locomotive=true,
	drops={"default:steelblock 4"},
}, "Subway Passenger Wagon", "advtrains_subway_train_inv.png")

--wagons
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
