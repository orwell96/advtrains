--advtrains by orwell96
--signals.lua

for r,f in pairs({on="off", off="on"}) do
	minetest.register_node("advtrains:retrosignal_"..r, {
		drawtype = "mesh",
		paramtype="light",
		paramtype2="facedir",
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-1/4, -1/2, -1/4, 1/4, 2, 1/4},
		},
		mesh = "advtrains_retrosignal_"..r..".b3d",
		tiles = {"advtrains_retrosignal.png"},
		description="Lampless Signal ("..r..")",
		on_rightclick=switchfunc,
		sunlight_propagates=true,
		groups = {
			choppy=3,
			not_blocking_trains=1
		},
		mesecons = {effector = {
			["action_"..f] = function (pos, node)
				minetest.swap_node(pos, {name = "advtrains:retrosignal_"..f, param2 = node.param2})
			end
		}},
		on_rightclick=function(pos, node, clicker)
			minetest.swap_node(pos, {name = "advtrains:retrosignal_"..f, param2 = node.param2})
		end,
	})
	minetest.register_node("advtrains:signal_"..r, {
		drawtype = "mesh",
		paramtype="light",
		paramtype2="facedir",
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-1/4, -1/2, -1/4, 1/4, 2, 1/4},
		},
		mesh = "advtrains_signal.b3d",
		tiles = {"advtrains_signal_"..r..".png"},
		description="Signal ("..r..")",
		on_rightclick=switchfunc,
		groups = {
			choppy=3,
			not_blocking_trains=1
		},
		light_source = 1,
		sunlight_propagates=true,
		mesecons = {effector = {
			["action_"..f] = function (pos, node)
				minetest.swap_node(pos, {name = "advtrains:signal_"..f, param2 = node.param2})
			end
		}},
		on_rightclick=function(pos, node, clicker)
			minetest.swap_node(pos, {name = "advtrains:signal_"..f, param2 = node.param2})
		end,
	})
end
