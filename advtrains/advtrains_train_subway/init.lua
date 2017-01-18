
advtrains.register_wagon("subway_wagon", {
	mesh="advtrains_subway_wagon.b3d",
	textures = {"advtrains_subway_wagon.png"},
	drives_on={default=true},
	max_speed=15,
	seats = {
		{
			name="Default Seat (driver stand)",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=0, z=0},
			driving_ctrl_access=true,
		},
	},
	visual_size = {x=1, y=1},
	wagon_span=2,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	is_locomotive=true,
	drops={"default:steelblock 4"},
	--custom_on_activate = function(self, dtime_s)
	--	atprint("subway custom_on_activate")
	--	self.object:set_animation({x=1,y=80}, 15, 0, true)
	--end,
}, "Subway Passenger Wagon", "advtrains_subway_wagon_inv.png")

--wagons
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
