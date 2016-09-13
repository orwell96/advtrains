--advtrains by orwell96
--signals.lua
for r,f in pairs({on="off", off="on"}) do

	advtrains.trackplacer.register_tracktype("advtrains:retrosignal", "")
	advtrains.trackplacer.register_tracktype("advtrains:signal", "")

	for rotid, rotation in ipairs({"", "_30", "_45", "_60"}) do
		local crea=1
		if rotid==1 and r=="off" then crea=0 end
		
		minetest.register_node("advtrains:retrosignal_"..r..rotation, {
			drawtype = "mesh",
			paramtype="light",
			paramtype2="facedir",
			walkable = false,
			selection_box = {
				type = "fixed",
				fixed = {-1/4, -1/2, -1/4, 1/4, 2, 1/4},
			},
			mesh = "advtrains_retrosignal_"..r..rotation..".b3d",
			tiles = {"advtrains_retrosignal.png"},
			inventory_image="advtrains_retrosignal_inv.png",
			drop="advtrains:retrosignal_off",
			description="Lampless Signal ("..r..rotation..")",
			on_rightclick=switchfunc,
			sunlight_propagates=true,
			groups = {
				choppy=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
			},
			mesecons = {effector = {
				["action_"..f] = function (pos, node)
					minetest.swap_node(pos, {name = "advtrains:retrosignal_"..f..rotation, param2 = node.param2})
				end
			}},
			on_rightclick=function(pos, node, clicker)
				minetest.swap_node(pos, {name = "advtrains:retrosignal_"..f..rotation, param2 = node.param2})
			end,
		})
		advtrains.trackplacer.add_worked("advtrains:retrosignal", r, rotation, nil)
		minetest.register_node("advtrains:signal_"..r..rotation, {
			drawtype = "mesh",
			paramtype="light",
			paramtype2="facedir",
			walkable = false,
			selection_box = {
				type = "fixed",
				fixed = {-1/4, -1/2, -1/4, 1/4, 2, 1/4},
			},
			mesh = "advtrains_signal"..rotation..".b3d",
			tiles = {"advtrains_signal_"..r..".png"},
			inventory_image="advtrains_signal_inv.png",
			drop="advtrains:signal_off",
			description="Signal ("..r..rotation..")",
			on_rightclick=switchfunc,
			groups = {
				choppy=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
			},
			light_source = 1,
			sunlight_propagates=true,
			mesecons = {effector = {
				["action_"..f] = function (pos, node)
					minetest.swap_node(pos, {name = "advtrains:signal_"..f..rotation, param2 = node.param2})
				end
			}},
			on_rightclick=function(pos, node, clicker)
				minetest.swap_node(pos, {name = "advtrains:signal_"..f..rotation, param2 = node.param2})
			end,
		})
		advtrains.trackplacer.add_worked("advtrains:signal", r, rotation, nil)
	end
end
