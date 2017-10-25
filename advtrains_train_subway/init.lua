local S
if minetest.get_modpath("intllib") then
    S = intllib.Getter()
else
    S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

advtrains.register_wagon("subway_wagon", {
	mesh="advtrains_subway_wagon.b3d",
	textures = {"advtrains_subway_wagon.png"},
	drives_on={default=true},
	max_speed=15,
	seats = {
		{
			name="Driver stand",
			attach_offset={x=0, y=10, z=0},
			view_offset={x=0, y=0, z=0},
			driving_ctrl_access=true,
			group="dstand",
		},
		{
			name="1",
			attach_offset={x=-4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="2",
			attach_offset={x=4, y=8, z=8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="3",
			attach_offset={x=-4, y=8, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
		{
			name="4",
			attach_offset={x=4, y=8, z=-8},
			view_offset={x=0, y=0, z=0},
			group="pass",
		},
	},
	seat_groups = {
		dstand={
			name = "Driver Stand",
			access_to = {"pass"},
			require_doors_open=true,
		},
		pass={
			name = "Passenger area",
			access_to = {"dstand"},
			require_doors_open=true,
		},
	},
	assign_to_seat_group = {"pass","dstand"},
	doors={
		open={
			[-1]={frames={x=0, y=20}, time=1},
			[1]={frames={x=40, y=60}, time=1}
		},
		close={
			[-1]={frames={x=20, y=40}, time=1},
			[1]={frames={x=60, y=80}, time=1}
		}
	},
	door_entry={-1, 1},
	visual_size = {x=1, y=1},
	wagon_span=2,
	--collisionbox = {-1.0,-0.5,-1.8, 1.0,2.5,1.8},
	collisionbox = {-1.0,-0.5,-1.0, 1.0,2.5,1.0},
	is_locomotive=true,
	drops={"default:steelblock 4"},
	--custom_on_activate = function(self, dtime_s)
	--	atprint("subway custom_on_activate")
	--	self.object:set_animation({x=1,y=80}, 15, 0, true)
	--end,
}, S("Subway Passenger Wagon"), "advtrains_subway_wagon_inv.png")

--wagons
minetest.register_craft({
	output = 'advtrains:subway_wagon',
	recipe = {
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
		{'default:steelblock', 'dye:yellow', 'default:steelblock'},
		{'default:steelblock', 'default:steelblock', 'default:steelblock'},
	},
})

minetest.register_craftitem(":advtrains:subway_train", {
		description = "Subway train, will drive forward when placed",
		inventory_image = "advtrains_subway_wagon_inv.png",
		wield_image = "advtrains_subway_wagon_inv.png",
		
		on_place = function(itemstack, placer, pointed_thing)
			return advtrains.pcall(function()
				if not pointed_thing.type == "node" then
					return
				end
				

				local node=minetest.get_node_or_nil(pointed_thing.under)
				if not node then atprint("[advtrains]Ignore at placer position") return itemstack end
				local nodename=node.name
				if(not advtrains.is_track_and_drives_on(nodename, prototype.drives_on)) then
					atprint("no track here, not placing.")
					return itemstack
				end
				if not minetest.check_player_privs(placer, {train_place = true }) and minetest.is_protected(pointed_thing.under, placer:get_player_name()) then
					minetest.record_protection_violation(pointed_thing.under, placer:get_player_name())
					return
				end
				local conn1=advtrains.get_track_connections(node.name, node.param2)
				local id=advtrains.create_new_train_at(pointed_thing.under, advtrains.dirCoordSet(pointed_thing.under, conn1))
				
				for i=1,3 do
					local ob=minetest.add_entity(pointed_thing.under, "advtrains:"..sysname)
					if not ob then
						atprint("couldn't add_entity, aborting")
					end
					local le=ob:get_luaentity()
					
					le.owner=placer:get_player_name()
					
					local wagon_uid=le:init_new_instance(id, {})
					
					advtrains.add_wagon_to_train(le, id)
				end
				advtrains.trains[id].velocity=2
				if not minetest.settings:get_bool("creative_mode") then
					itemstack:take_item()
				end
				return itemstack
				
			end)
		end,
	})
