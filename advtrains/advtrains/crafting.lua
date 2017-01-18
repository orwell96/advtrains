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
	type = "shapeless",
	output = 'advtrains:dtrack_slopeplacer 2',
	recipe = {
		"advtrains:dtrack_placer",
		"advtrains:dtrack_placer",
		"default:gravel",
	},
})

minetest.register_craft({
	output = 'advtrains:dtrack_bumper_placer 2',
	recipe = {
		{'default:wood', 'dye:red'},
		{'default:steel_ingot', 'default:steel_ingot'},
		{'advtrains:dtrack_placer', 'advtrains:dtrack_placer'},
	},
})
minetest.register_craft({
	type="shapeless",
	output = 'advtrains:dtrack_detector_off_placer',
	recipe = {
		"advtrains:dtrack_placer",
		"mesecons:wire_00000000_off"
	},
})
--signals
minetest.register_craft({
	output = 'advtrains:retrosignal_off 2',
	recipe = {
		{'dye:red', 'default:steel_ingot', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
	},
})
minetest.register_craft({
	output = 'advtrains:signal_off 2',
	recipe = {
		{'', 'dye:red', 'default:steel_ingot'},
		{'', 'dye:dark_green', 'default:steel_ingot'},
		{'', '', 'default:steel_ingot'},
	},
})

--trackworker
minetest.register_craft({
	output = 'advtrains:trackworker',
	recipe = {
		{'default:diamond'},
		{'screwdriver:screwdriver'},
		{'default:steel_ingot'},
	},
})



--misc_nodes
--crafts for platforms see misc_nodes.lua
