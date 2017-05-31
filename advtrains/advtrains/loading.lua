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
			 

advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_unload",
	texture_prefix="advtrains_dtrack_unload",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_unload.png",
	description=attrans("Unloading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		      --				local pts=minetest.pos_to_string(pos)
		      --				atc.controllers[pts]=nil
		   end,
		   -- on_receive_fields = function(pos, formname, fields, player)
		   --    if minetest.is_protected(pos, player:get_player_name()) then
		   -- 	 minetest.chat_send_player(player:get_player_name(), attrans("This position is protected!"))
		   -- 	 return
		   --    end
		   -- end,
		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, true)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_load",
	texture_prefix="advtrains_dtrack_load",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_load.png",
	description=attrans("Loading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		   end,

		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, false)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)
