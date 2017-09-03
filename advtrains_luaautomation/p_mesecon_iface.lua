-- p_mesecon_iface.lua
-- Mesecons interface by overriding the switch

if not mesecon then return end

minetest.override_item("mesecons_switch:mesecon_switch_off", {
	groups = {
		dig_immediate=2,
		save_in_nodedb=1,
	},
	on_rightclick = function (pos, node)
		advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_on", param2=node.param2})
		mesecon.receptor_on(pos)
		minetest.sound_play("mesecons_switch", {pos=pos})
	end,
	on_updated_from_nodedb = function(pos, node)
		mesecon.receptor_off(pos)
	end,
	luaautomation = {
		getstate = "off",
		setstate = function(pos, node, newstate)
			if newstate=="on" then
				advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_on", param2=node.param2})
				mesecon.receptor_on(pos)
			end
		end,
	},
})

minetest.override_item("mesecons_switch:mesecon_switch_on", {
	groups = {
		dig_immediate=2,
		save_in_nodedb=1,
		not_in_creative_inventory=1,
	},
	on_rightclick = function (pos, node)
		advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_off", param2=node.param2})
		mesecon.receptor_off(pos)
		minetest.sound_play("mesecons_switch", {pos=pos})
	end,
	on_updated_from_nodedb = function(pos, node)
		mesecon.receptor_on(pos)
	end,
	luaautomation = {
		getstate = "on",
		setstate = function(pos, node, newstate)
			if newstate=="off" then
				advtrains.ndb.swap_node(pos, {name="mesecons_switch:mesecon_switch_off", param2=node.param2})
				mesecon.receptor_off(pos)
			end
		end,
	},
})
