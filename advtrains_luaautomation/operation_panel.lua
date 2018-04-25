
local function on_punch(pos, player)
	atlatc.interrupt.add(0, pos, {type="punch", punch=true})
end


minetest.register_node("advtrains_luaautomation:oppanel", {
	drawtype = "normal",
	tiles={"atlatc_oppanel.png"},
	description = "LuaAutomation operation panel",
	groups = {
		choppy = 1,
		save_in_nodedb=1,
	},
	after_place_node = atlatc.active.after_place_node,
	after_dig_node = atlatc.active.after_dig_node,
	on_receive_fields = atlatc.active.on_receive_fields,
	on_punch = on_punch,
	luaautomation = {
		fire_event=atlatc.active.run_in_env
	},
	digiline = {
		receptor = {},
		effector = {
			action = atlatc.active.on_digiline_receive
		},
	},
})
