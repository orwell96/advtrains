minetest.register_tool("advtrains:tunnelborer",
{
	description = "tunnelborer",
	groups = {cracky=1}, -- key=name, value=rating; rating=1..3.
	inventory_image = "drwho_screwdriver.png",
	wield_image = "drwho_screwdriver.png",
	stack_max = 1,
	range = 7.0,
		
	on_place = function(itemstack, placer, pointed_thing)
	
	end,
	--[[
	^ Shall place item and return the leftover itemstack
	^ default: minetest.item_place ]]
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type=="node" then
			for x=-1,1 do
				for y=-1,1 do
					for z=-1,1 do
						minetest.remove_node(vector.add(pointed_thing.under, {x=x, y=y, z=z}))
					end
				end
			end
		end
	end,
}
)
