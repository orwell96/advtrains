--advtrains by orwell96
--signals.lua

--this code /should/ work but does not.
local mrules_wallsignal_l, mrules_wallsignal_r
if mesecon then
	mrules_wallsignal_l = function(node, isright)
		local rules = mesecon.rules.buttonlike
		if node.param2 == 1 then
			rules=mesecon.rotate_rules_left(rules)
		elseif node.param2 == 2 then
			rules=mesecon.rotate_rules_right(mesecon.rotate_rules_right(rules))
		elseif node.param2 == 3 then
			rules=mesecon.rotate_rules_right(rules)
		end
		return rules
	end
	mrules_wallsignal_r = function(node)
		local rules = mesecon.rules.buttonlike
		if node.param2 == 3 then
			rules=mesecon.rotate_rules_left(rules)
		elseif node.param2 == 0 then
			rules=mesecon.rotate_rules_right(mesecon.rotate_rules_right(rules))
		elseif node.param2 == 1 then
			rules=mesecon.rotate_rules_right(rules)
		end
		return rules
	end
end

for r,f in pairs({on={as="off", ls="green", als="red"}, off={as="on", ls="red", als="green"}}) do

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
			description=attrans("Lampless Signal (@1)", attrans(r..rotation)),
			on_rightclick=switchfunc,
			sunlight_propagates=true,
			groups = {
				choppy=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
				save_in_nodedb=1,
			},
			mesecons = {effector = {
				rules=advtrains.meseconrules,
				["action_"..f.as] = function (pos, node)
					advtrains.ndb.swap_node(pos, {name = "advtrains:retrosignal_"..f.as..rotation, param2 = node.param2})
				end
			}},
			on_rightclick=function(pos, node, clicker)
				advtrains.ndb.swap_node(pos, {name = "advtrains:retrosignal_"..f.as..rotation, param2 = node.param2})
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
			description=attrans("Signal (@1)", attrans(r..rotation)),
			on_rightclick=switchfunc,
			groups = {
				choppy=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
				save_in_nodedb=1,
			},
			light_source = 1,
			sunlight_propagates=true,
			mesecons = {effector = {
				rules=advtrains.meseconrules,
				["action_"..f.as] = function (pos, node)
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_"..f.as..rotation, param2 = node.param2})
				end
			}},
			luaautomation = {
				getstate = f.ls,
				setstate = function(pos, node, newstate)
					if newstate == f.als then
						advtrains.ndb.swap_node(pos, {name = "advtrains:signal_"..f.as..rotation, param2 = node.param2})
					end
				end,
			},
			on_rightclick=function(pos, node, clicker)
				advtrains.ndb.swap_node(pos, {name = "advtrains:signal_"..f.as..rotation, param2 = node.param2})
			end,
		})
		advtrains.trackplacer.add_worked("advtrains:signal", r, rotation, nil)
	end
	
	local crea=1
	if r=="off" then crea=0 end
	
	--tunnel signals. no rotations.
	minetest.register_node("advtrains:signal_wall_l_"..r, {
		drawtype = "mesh",
		paramtype="light",
		paramtype2="facedir",
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {-1/2, -1/2, -1/4, 0, 1/2, 1/4},
		},
		mesh = "advtrains_signal_wall_l.b3d",
		tiles = {"advtrains_signal_wall_"..r..".png"},
		drop="advtrains:signal_wall_l_off",
		description=attrans("Wallmounted Signal, left"),
		groups = {
			choppy=3,
			not_blocking_trains=1,
			not_in_creative_inventory=crea,
			save_in_nodedb=1,
		},
		light_source = 1,
		sunlight_propagates=true,
		mesecons = {effector = {
			mrules_wallsignal_l,
			["action_"..f.as] = function (pos, node)
				advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_l_"..f.as, param2 = node.param2})
			end
		}},
		luaautomation = {
			getstate = f.ls,
			setstate = function(pos, node, newstate)
				if newstate == f.als then
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_l_"..f.as, param2 = node.param2})
				end
			end,
		},
		on_rightclick=function(pos, node, clicker)
			advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_l_"..f.as, param2 = node.param2})
		end,
	})
	minetest.register_node("advtrains:signal_wall_r_"..r, {
		drawtype = "mesh",
		paramtype="light",
		paramtype2="facedir",
		walkable = false,
		selection_box = {
			type = "fixed",
			fixed = {0, -1/2, -1/4, 1/2, 1/2, 1/4},
		},
		mesh = "advtrains_signal_wall_r.b3d",
		tiles = {"advtrains_signal_wall_"..r..".png"},
		drop="advtrains:signal_wall_r_off",
		description=attrans("Wallmounted Signal, right"),
		groups = {
			choppy=3,
			not_blocking_trains=1,
			not_in_creative_inventory=crea,
			save_in_nodedb=1,
		},
		light_source = 1,
		sunlight_propagates=true,
		mesecons = {effector = {
			rules = mrules_wallsignal_r,
			["action_"..f.as] = function (pos, node)
				advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_r_"..f.as, param2 = node.param2})
			end
		}},
		luaautomation = {
			getstate = f.ls,
			setstate = function(pos, node, newstate)
				if newstate == f.als then
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_r_"..f.as, param2 = node.param2})
				end
			end,
		},
		on_rightclick=function(pos, node, clicker)
			advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_r_"..f.as, param2 = node.param2})
		end,
	})
	
end
