--advtrains by orwell96
--signals.lua

--this code /should/ work but does not.
local mrules_wallsignal = advtrains.meseconrules

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
			sunlight_propagates=true,
			groups = {
				cracky=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
				save_in_at_nodedb=1,
			},
			mesecons = {effector = {
				rules=advtrains.meseconrules,
				["action_"..f.as] = function (pos, node)
					advtrains.ndb.swap_node(pos, {name = "advtrains:retrosignal_"..f.as..rotation, param2 = node.param2})
				end
			}},
			on_rightclick=function(pos, node, player)
				if minetest.check_player_privs(player:get_player_name(), {train_operator=true}) then
					advtrains.ndb.swap_node(pos, {name = "advtrains:retrosignal_"..f.as..rotation, param2 = node.param2})
				end
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
			groups = {
				cracky=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
				save_in_at_nodedb=1,
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
			on_rightclick=function(pos, node, player)
				if minetest.check_player_privs(player:get_player_name(), {train_operator=true}) then
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_"..f.as..rotation, param2 = node.param2})
				end
			end,
		})
		advtrains.trackplacer.add_worked("advtrains:signal", r, rotation, nil)
	end
	
	local crea=1
	if r=="off" then crea=0 end
	
	--tunnel signals. no rotations.
	for loc, sbox in pairs({l={-1/2, -1/2, -1/4, 0, 1/2, 1/4}, r={0, -1/2, -1/4, 1/2, 1/2, 1/4}, t={-1/2, 0, -1/4, 1/2, 1/2, 1/4}}) do
		minetest.register_node("advtrains:signal_wall_"..loc.."_"..r, {
			drawtype = "mesh",
			paramtype="light",
			paramtype2="facedir",
			walkable = false,
			selection_box = {
				type = "fixed",
				fixed = sbox,
			},
			mesh = "advtrains_signal_wall_"..loc..".b3d",
			tiles = {"advtrains_signal_wall_"..r..".png"},
			drop="advtrains:signal_wall_"..loc.."_off",
			description=attrans("Wallmounted Signal ("..loc..")"),
			groups = {
				cracky=3,
				not_blocking_trains=1,
				not_in_creative_inventory=crea,
				save_in_at_nodedb=1,
			},
			light_source = 1,
			sunlight_propagates=true,
			mesecons = {effector = {
				rules = mrules_wallsignal,
				["action_"..f.as] = function (pos, node)
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_"..loc.."_"..f.as, param2 = node.param2})
				end
			}},
			luaautomation = {
				getstate = f.ls,
				setstate = function(pos, node, newstate)
					if newstate == f.als then
						advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_"..loc.."_"..f.as, param2 = node.param2})
					end
				end,
			},
			on_rightclick=function(pos, node, player)
				if minetest.check_player_privs(player:get_player_name(), {train_operator=true}) then
					advtrains.ndb.swap_node(pos, {name = "advtrains:signal_wall_"..loc.."_"..f.as, param2 = node.param2})
				end
			end,
		})
	end
end

-- level crossing
-- german version (Andrew's Cross)
minetest.register_node("advtrains:across_off", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="facedir",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/2, 1/4, 1.5, 0},
	},
	mesh = "advtrains_across.obj",
	tiles = {"advtrains_across.png"},
	drop="advtrains:across_off",
	description=attrans("Andrew's Cross"),
	groups = {
		cracky=3,
		not_blocking_trains=1,
		save_in_at_nodedb=1,
		not_in_creative_inventory=nil,
	},
	light_source = 1,
	sunlight_propagates=true,
	mesecons = {effector = {
		rules = advtrains.meseconrules,
		action_on = function (pos, node)
			advtrains.ndb.swap_node(pos, {name = "advtrains:across_on", param2 = node.param2})
		end
	}},
	luaautomation = {
		getstate = "off",
		setstate = function(pos, node, newstate)
			if newstate == "on" then
				advtrains.ndb.swap_node(pos, {name = "advtrains:across_on", param2 = node.param2})
			end
		end,
	},
	on_rightclick=function(pos, node, player)
		if minetest.check_player_privs(player:get_player_name(), {train_operator=true}) then
			advtrains.ndb.swap_node(pos, {name = "advtrains:across_on", param2 = node.param2})
		end
	end,
})
minetest.register_node("advtrains:across_on", {
	drawtype = "mesh",
	paramtype="light",
	paramtype2="facedir",
	walkable = false,
	selection_box = {
		type = "fixed",
		fixed = {-1/4, -1/2, -1/2, 1/4, 1.5, 0},
	},
	mesh = "advtrains_across.obj",
	tiles = {{name="advtrains_across_anim.png", animation={type="vertical_frames", aspect_w=64, aspect_h=64, length=1.0}}},
	drop="advtrains:across_off",
	description=attrans("Andrew's Cross (on) (you hacker you)"),
	groups = {
		cracky=3,
		not_blocking_trains=1,
		save_in_at_nodedb=1,
		not_in_creative_inventory=1,
	},
	light_source = 1,
	sunlight_propagates=true,
	mesecons = {effector = {
		rules = advtrains.meseconrules,
		action_off = function (pos, node)
			advtrains.ndb.swap_node(pos, {name = "advtrains:across_off", param2 = node.param2})
		end
	}},
	luaautomation = {
		getstate = "on",
		setstate = function(pos, node, newstate)
			if newstate == "off" then
				advtrains.ndb.swap_node(pos, {name = "advtrains:across_off", param2 = node.param2})
			end
		end,
	},
	on_rightclick=function(pos, node, player)
		if minetest.check_player_privs(player:get_player_name(), {train_operator=true}) then
			advtrains.ndb.swap_node(pos, {name = "advtrains:across_off", param2 = node.param2})
		end
	end,
})

minetest.register_abm(
	{
        label = "Sound for Level Crossing",
        nodenames = {"advtrains:across_on"},
        interval = 3,
        chance = 1,
        action = function(pos, node, active_object_count, active_object_count_wider)
			minetest.sound_play("advtrains_crossing_bell", {
				pos = pos,
				gain = 1.0, -- default
				max_hear_distance = 16, -- default, uses an euclidean metric
			})
        end,
    }
)
