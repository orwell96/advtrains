--advtrains

advtrains={}

advtrains.modpath = minetest.get_modpath("advtrains")

print=function(text)
	minetest.log("action", tostring(text) or "<non-string>")
end


dofile(advtrains.modpath.."/helpers.lua");
dofile(advtrains.modpath.."/debugitems.lua");

dofile(advtrains.modpath.."/trainlogic.lua");
dofile(advtrains.modpath.."/trainhud.lua")
dofile(advtrains.modpath.."/trackplacer.lua")
dofile(advtrains.modpath.."/tracks.lua")
dofile(advtrains.modpath.."/wagons.lua")
