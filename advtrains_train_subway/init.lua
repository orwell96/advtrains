
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

--wagons
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
