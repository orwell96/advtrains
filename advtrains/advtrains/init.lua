--advtrains

advtrains={}

advtrains.modpath = minetest.get_modpath("advtrains")

local function print_concat_table(a)
	local str=""
	local stra=""
	for i=1,50 do
		t=a[i]
		if t==nil then
			stra=stra.."nil "
		else
			str=str..stra
			stra=""
			if type(t)=="table" then
				if t.x and t.y and t.z then
					str=str..minetest.pos_to_string(t)
				else
					str=str..dump(t)
				end
			elseif type(t)=="boolean" then
				if t then
					str=str.."true"
				else
					str=str.."false"
				end
			else
				str=str..t
			end
			str=str.." "
		end
	end
	return str
end
--atprint=function() end
atprint=function(t, ...) minetest.log("action", "[advtrains]"..print_concat_table({t, ...})) minetest.chat_send_all("[advtrains]"..print_concat_table({t, ...})) end
sid=function(id) return string.sub(id, -4) end

dofile(advtrains.modpath.."/helpers.lua");
dofile(advtrains.modpath.."/debugitems.lua");

advtrains.meseconrules = 
{{x=0,  y=0,  z=-1},
 {x=1,  y=0,  z=0},
 {x=-1, y=0,  z=0},
 {x=0,  y=0,  z=1},
 {x=1,  y=1,  z=0},
 {x=1,  y=-1, z=0},
 {x=-1, y=1,  z=0},
 {x=-1, y=-1, z=0},
 {x=0,  y=1,  z=1},
 {x=0,  y=-1, z=1},
 {x=0,  y=1,  z=-1},
 {x=0,  y=-1, z=-1},
 {x=0, y=-2, z=0}}
dofile(advtrains.modpath.."/trainlogic.lua")
dofile(advtrains.modpath.."/trainhud.lua")
dofile(advtrains.modpath.."/trackplacer.lua")
dofile(advtrains.modpath.."/tracks.lua")
dofile(advtrains.modpath.."/atc.lua")
dofile(advtrains.modpath.."/wagons.lua")

dofile(advtrains.modpath.."/pseudoload.lua")
dofile(advtrains.modpath.."/couple.lua")
dofile(advtrains.modpath.."/damage.lua")

dofile(advtrains.modpath.."/signals.lua")
dofile(advtrains.modpath.."/misc_nodes.lua")
dofile(advtrains.modpath.."/crafting.lua")
