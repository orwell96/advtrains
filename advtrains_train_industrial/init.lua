-- Boilerplate to support localized strings if intllib mod is installed.
local S
if minetest.get_modpath("intllib") then
    S = intllib.Getter()
else
    S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

advtrains.register_wagon("engine_industrial", {
	mesh="advtrains_engine_industrial.b3d",
	textures = {"advtrains_engine_industrial.png"},
	drives_on={default=true},
	max_speed=20,
	seats = {
		{
			name=S("Driver Stand (right)"),
			attach_offset={x=5, y=7, z=-8},
			view_offset={x=5.2, y=-4, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
		{
			name=S("Driver Stand (left)"),
			attach_offset={x=5, y=7, z=-8},
			view_offset={x=-5.2, y=-4, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
	},
	seat_groups = {
		dstand={
            
			name = "Driver Stand",
			access_to = {},
		},
	},
	assign_to_seat_group = {"dstand"},
	visual_size = {x=1, y=1},
	wagon_span=2.6,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	horn_sound = "advtrains_industrial_horn",
	glow = -1, --supposed to disable effect of light to texture color, so that the entity always appears as full-bright
}, S("Industrial Train Engine"), "advtrains_engine_industrial_inv.png")
--big--
advtrains.register_wagon("engine_industrial_big", {
	mesh="advtrains_engine_industrial_big.b3d",
	textures = {"advtrains_engine_industrial_big.png"},
	drives_on={default=true},
	max_speed=30,
	seats = {
		{
			name=S("Driver Stand (right)"),
			attach_offset={x=5, y=7, z=20},
			view_offset={x=5.2, y=-4, z=11},
			driving_ctrl_access=true,
			group = "dstand",
		},
		{
			name=S("Driver Stand (left)"),
			attach_offset={x=5, y=7, z=-8},
			view_offset={x=-5.2, y=-4, z=0},
			driving_ctrl_access=true,
			group = "dstand",
		},
	},
	seat_groups = {
		dstand={
            
			name = "Driver Stand",
			access_to = {},
		},
	},
	assign_to_seat_group = {"dstand"},
	visual_size = {x=1, y=1},
	wagon_span=4,
	is_locomotive=true,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	horn_sound = "advtrains_industrial_horn",
	glow = -1, --supposed to disable effect of light to texture color, so that the entity always appears as full-bright
}, S("Big Industrial Train Engine"), "advtrains_engine_industrial_inv.png")
advtrains.register_wagon("wagon_tank", {
	mesh="advtrains_wagon_tank.b3d",
	textures = {"advtrains_wagon_tank.png"},
	seats = {},
	drives_on={default=true},
	max_speed=20,
	visual_size = {x=1, y=1},
	wagon_span=2.2,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,3;]"..
			"list[current_player;main;0,5;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*3,
	},
	glow = -1, --supposed to disable effect of light to texture color, so that the entity always appears as full-bright
}, S("Industrial tank wagon"), "advtrains_wagon_tank_inv.png")
advtrains.register_wagon("wagon_wood", {
	mesh="advtrains_wagon_wood.b3d",
	textures = {"advtrains_wagon_wood.png"},
	seats = {},
	drives_on={default=true},
	max_speed=20,
	visual_size = {x=1, y=1},
	wagon_span=1.8,
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	drops={"default:steelblock 4"},
	has_inventory = true,
	get_inventory_formspec = function(self)
		return "size[8,11]"..
			"list[detached:advtrains_wgn_"..self.unique_id..";box;0,0;8,3;]"..
			"list[current_player;main;0,5;8,4;]"..
			"listring[]"
	end,
	inventory_list_sizes = {
		box=8*3,
	},
	glow = -1, --supposed to disable effect of light to texture color, so that the entity always appears as full-bright
}, S("Industrial wood wagon"), "advtrains_wagon_wood_inv.png")
