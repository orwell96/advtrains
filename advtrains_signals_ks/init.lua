-- Ks Signals for advtrains
-- will implement the advtrains signal API (which does not exist yet)

local function place_degrotate(pos, placer, itemstack, pointed_thing)
	local yaw = placer:get_look_horizontal()
	local param = math.floor(yaw * 90 / math.pi + 0.5)
	local n = minetest.get_node(pos)
	n.param2 = param
	minetest.set_node(pos, n)
end

minetest.register_node("advtrains_signals_ks:mast", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="degrotate",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/4, 1/4, 1/2, 1/4},
	},
	mesh = "advtrains_signals_ks_mast.obj",
	tiles = {"advtrains_signals_ks_mast.png"},
	description="Ks Signal Mast",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
	},
	after_place_node = place_degrotate,
})

minetest.register_node("advtrains_signals_ks:head_main", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="degrotate",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/4, 1/4, 1/2, 1/4},
	},
	mesh = "advtrains_signals_ks_head_main.obj",
	tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png"},
	description="Ks Main Signal Screen",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
	},
	after_place_node = place_degrotate,
})

minetest.register_node("advtrains_signals_ks:zs_top", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="degrotate",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/4, 1/4, 1/2, 1/4},
	},
	mesh = "advtrains_signals_ks_zs_top.obj",
	tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png"},
	description="Ks Speed Restriction Signal (top)",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
	},
	after_place_node = place_degrotate,
})

minetest.register_node("advtrains_signals_ks:zs_bottom", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="degrotate",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/4, 1/4, 1/2, 1/4},
	},
	mesh = "advtrains_signals_ks_zs_bottom.obj",
	tiles = {"advtrains_signals_ks_mast.png", "advtrains_signals_ks_head.png"},
	description="Ks Speed Restriction Signal (bottom)",
	sunlight_propagates=true,
	groups = {
		cracky=3,
		not_blocking_trains=1,
		--save_in_at_nodedb=2,
	},
	after_place_node = place_degrotate,
})
