--advtrains

advtrains={}

advtrains.modpath = minetest.get_modpath("advtrains")

--print=function(text)
--	minetest.log("action", tostring(text) or "<non-string>")
--end
print = function(t) minetest.log("action", t) minetest.chat_send_all(t) end

dofile(advtrains.modpath.."/helpers.lua");
dofile(advtrains.modpath.."/debugitems.lua");

advtrains.meseconrules = mesecon.rules.pplate

dofile(advtrains.modpath.."/trainlogic.lua");
dofile(advtrains.modpath.."/trainhud.lua")
dofile(advtrains.modpath.."/trackplacer.lua")
dofile(advtrains.modpath.."/tracks.lua")
dofile(advtrains.modpath.."/atc.lua")
dofile(advtrains.modpath.."/wagons.lua")

dofile(advtrains.modpath.."/pseudoload.lua");
dofile(advtrains.modpath.."/couple.lua");
dofile(advtrains.modpath.."/damage.lua");

dofile(advtrains.modpath.."/signals.lua");
dofile(advtrains.modpath.."/misc_nodes.lua");
dofile(advtrains.modpath.."/crafting.lua");
