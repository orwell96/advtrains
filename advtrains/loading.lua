-- Tracks for loading and unloading trains
-- Copyright (C) 2017 Gabriel Pérez-Cerezo <gabriel@gpcf.eu>

local function get_far_node(pos)
	local node = minetest.get_node(pos)
	if node.name == "ignore" then
		minetest.get_voxel_manip():read_from_map(pos, pos)
		node = minetest.get_node(pos)
	end
	return node
end

local function train_load(pos, train_id, unload)
   local train=advtrains.trains[train_id]
   local below = get_far_node({x=pos.x, y=pos.y-1, z=pos.z})
   if not string.match(below.name, "chest") then
      atprint("this is not a chest! at "..minetest.pos_to_string(pos))
      return
   end
   local inv = minetest.get_inventory({type="node", pos={x=pos.x, y=pos.y-1, z=pos.z}})
   if inv and train.velocity < 2 then
      for k, v in ipairs(train.trainparts) do
	 
	 local i=minetest.get_inventory({type="detached", name="advtrains_wgn_"..v})
	 if i then
	    if not unload then
	       for _, item in ipairs(inv:get_list("main")) do
		  if i:get_list("box") and i:room_for_item("box", item)  then
		     i:add_item("box", item)
		     inv:remove_item("main", item)
		  end
	    end
	    else
	       for _, item in ipairs(i:get_list("box")) do
		  if inv:get_list("main") and inv:room_for_item("main", item)  then
		     i:remove_item("box", item)
		     inv:add_item("main", item)
		  end
	       end
	    end
	 end
      end
   end
end
			 

