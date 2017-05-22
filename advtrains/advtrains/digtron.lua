--digtron.lua
--make tracks placeable by digtrons by overriding the place function.

local old_item_place = digtron.item_place_node

digtron.item_place_node = function(itemstack, placer, place_to, param2)
	if minetest.get_item_group(itemstack:get_name(), "advtrains_trackplacer")>0 then
		return advtrains.pcall(function()
			local def = minetest.registered_items[itemstack:get_name()]
			if not def then return itemstack, false end
			
			local pointed_thing = {}
			pointed_thing.type = "node"
			pointed_thing.above = {x=place_to.x, y=place_to.y, z=place_to.z}
			pointed_thing.under = {x=place_to.x, y=place_to.y - 1, z=place_to.z}
			
			--call the on_rightclick callback
			local success
			itemstack, success = def.on_place(itemstack, placer, pointed_thing)
			return itemstack, success
		end)
	else
		return old_item_place(itemstack, placer, place_to, param2)
	end
end
