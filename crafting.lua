--advtrains by orwell96, see readme.txt and license.txt
--crafting.lua
--registers crafting recipes

--tracks
minetest.register_craft({
	output = 'advtrains:dtrack_placer 50',
	recipe = {
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
		{'default:steel_ingot', 'group:stick', 'default:steel_ingot'},
	},
})
minetest.register_craft({
	output = 'advtrains:dtrack_puffer 2',
	recipe = {
		{'default:wood', 'dye:red', ''},
		{'default:steel_ingot', '', 'default:steel_ingot'},
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer', ''},
	},
})
--temporary, as long as puffers do not rotate
minetest.register_craft({
	output = 'advtrains:dtrack_puffer_30',
	recipe = {
		{'advtrains:dtrack_puffer'},
	},
})
minetest.register_craft({
	output = 'advtrains:dtrack_puffer_45',
	recipe = {
		{'advtrains:dtrack_puffer_30'},
	},
})
minetest.register_craft({
	output = 'advtrains:dtrack_puffer_60',
	recipe = {
		{'advtrains:dtrack_puffer_45'},
	},
})
minetest.register_craft({
	output = 'advtrains:dtrack_puffer',
	recipe = {
		{'advtrains:dtrack_puffer_60'},
	},
})


--wagons
minetest.register_craft({
	output = 'advtrains:newlocomotive',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:black', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
minetest.register_craft({
	output = 'advtrains:wagon_default',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:dark_green', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})

--misc_nodes
--crafts for platforms see misc_nodes.lua
