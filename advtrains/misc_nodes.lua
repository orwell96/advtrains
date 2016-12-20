--all nodes that do not fit in any other category

function advtrains.register_platform(preset)
	local ndef=minetest.registered_nodes[preset]
	if not ndef then 
		minetest.log("warning", "[advtrains] register_platform couldn't find preset node "..preset)
		return
	end
	local btex=ndef.tiles
	if type(btex)=="table" then
		btex=btex[1]
	end
	local desc=ndef.description or ""
	local nodename=string.match(preset, ":(.+)$")
	minetest.register_node("advtrains:platform_low_"..nodename, {
		description = desc.." Platform (low)",
		tiles = {btex.."^advtrains_platform.png", btex, btex, btex, btex, btex},
		groups = {cracky = 1, not_blocking_trains = 1, platform=1},
		sounds = default.node_sound_stone_defaults(),
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.1, -0.1, 0.5,  0  , 0.5},
				{-0.5, -0.5,  0  , 0.5, -0.1, 0.5}
			},
		},
		paramtype2="facedir",
		paramtype = "light",
		sunlight_propagates = true,
	})
	minetest.register_node("advtrains:platform_high_"..nodename, {
		description = desc.." Platform (high)",
		tiles = {btex.."^advtrains_platform.png", btex, btex, btex, btex, btex},
		groups = {cracky = 1, not_blocking_trains = 1, platform=2},
		sounds = default.node_sound_stone_defaults(),
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5,  0.3, -0.1, 0.5,  0.5, 0.5},
				{-0.5, -0.5,  0  , 0.5,  0.3, 0.5}
			},
		},
		paramtype2="facedir",
		paramtype = "light",
		sunlight_propagates = true,
	})
	minetest.register_craft({
		type="shapeless",
		output = "advtrains:platform_high_"..nodename.." 4",
		recipe = {
			"dye:yellow", preset, preset
		},
	})
	minetest.register_craft({
		type="shapeless",
		output = "advtrains:platform_low_"..nodename.." 4",
		recipe = {
			"dye:yellow", preset
		},
	})
end


advtrains.register_platform("default:stonebrick")
advtrains.register_platform("default:sandstonebrick")
