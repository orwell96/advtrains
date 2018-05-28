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

minetest.register_chatcommand("atyaw",
	{
        params = "angledeg conn1 conn2", 
        description = "", 
        func = function(name, param)
			local angledegs, conn1s, conn2s = string.match(param, "^(%S+)%s(%S+)%s(%S+)$")
			if angledegs and conn1s and conn2s then
				local angledeg, conn1, conn2 = angledegs+0,conn1s+0,conn2s+0
				local yaw = angledeg*math.pi/180
				local yaw1 = advtrains.dir_to_angle(conn1)
				local yaw2 = advtrains.dir_to_angle(conn2)
				local adiff1 = advtrains.minAngleDiffRad(yaw, yaw1)
				local adiff2 = advtrains.minAngleDiffRad(yaw, yaw2)
				
				atdebug("yaw1",atfloor(yaw1*180/math.pi))
				atdebug("yaw2",atfloor(yaw2*180/math.pi))
				atdebug("dif1",atfloor(adiff1*180/math.pi))
				atdebug("dif2",atfloor(adiff2*180/math.pi))
				
				minetest.chat_send_all(advtrains.yawToAnyDir(yaw))
				return true, advtrains.yawToDirection(yaw, conn1, conn2)
			end
        end,
})
