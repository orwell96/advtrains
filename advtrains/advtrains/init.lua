-- Boilerplate to support localized strings if intllib mod is installed.
if minetest.get_modpath("intllib") then
    attrans = intllib.Getter()
else
    attrans = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

--advtrains

advtrains = {trains={}, wagon_save={}, player_to_train_mapping={}}

advtrains.modpath = minetest.get_modpath("advtrains")

function advtrains.print_concat_table(a)
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
atprint=function() end
if minetest.setting_getbool("advtrains_debug") then
	atprint=function(t, ...)
		local text=advtrains.print_concat_table({t, ...})
		minetest.log("action", "[advtrains]"..text)
		minetest.chat_send_all("[advtrains]"..text)
	end
end
atwarn=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("warning", "[advtrains]"..text)
	minetest.chat_send_all("[advtrains] -!- "..text)
end
sid=function(id) return string.sub(id, -4) end

dofile(advtrains.modpath.."/helpers.lua");
--dofile(advtrains.modpath.."/debugitems.lua");

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

dofile(advtrains.modpath.."/trackdb_legacy.lua")
dofile(advtrains.modpath.."/nodedb.lua")
dofile(advtrains.modpath.."/couple.lua")

dofile(advtrains.modpath.."/signals.lua")
dofile(advtrains.modpath.."/misc_nodes.lua")
dofile(advtrains.modpath.."/crafting.lua")
dofile(advtrains.modpath.."/craft_items.lua")


--load/save

advtrains.fpath=minetest.get_worldpath().."/advtrains"
function advtrains.avt_load()
	local file, err = io.open(advtrains.fpath, "r")
	if not file then
		minetest.log("error", " Failed to read advtrains save data from file "..advtrains.fpath..": "..(err or "Unknown Error"))
	else
		local tbl = minetest.deserialize(file:read("*a"))
		if type(tbl) == "table" then
			if tbl.version then
				--congrats, we have the new save format.
				advtrains.trains = tbl.trains
				advtrains.wagon_save = tbl.wagon_save
				advtrains.player_to_train_mapping = tbl.ptmap or {}
				advtrains.ndb.load_data(tbl.ndb)
				advtrains.atc.load_data(tbl.atc)
			else
				--oh no, its the old one...
				advtrains.trains=tbl
				--load ATC
				advtrains.fpath_atc=minetest.get_worldpath().."/advtrains_atc"
				local file, err = io.open(advtrains.fpath_atc, "r")
				if not file then
					local er=err or "Unknown Error"
					atprint("Failed loading advtrains atc save file "..er)
				else
					local tbl = minetest.deserialize(file:read("*a"))
					if type(tbl) == "table" then
						advtrains.atc.controllers=tbl.controllers
					end
					file:close()
				end
				--load wagon saves
				advtrains.fpath_ws=minetest.get_worldpath().."/advtrains_wagon_save"
				local file, err = io.open(advtrains.fpath_ws, "r")
				if not file then
					local er=err or "Unknown Error"
					atprint("Failed loading advtrains save file "..er)
				else
					local tbl = minetest.deserialize(file:read("*a"))
					if type(tbl) == "table" then
						advtrains.wagon_save=tbl
					end
					file:close()
				end
			end
		else
			minetest.log("error", " Failed to deserialize advtrains save data: Not a table!")
		end
		file:close()
	end
end

advtrains.avt_save = function()
	--atprint("saving")
	advtrains.invalidate_all_paths()
	
	-- update wagon saves
	for _,wagon in pairs(minetest.luaentities) do
		if wagon.is_wagon and wagon.initialized then
			wagon:get_staticdata()
		end
	end
	--cross out userdata
	for w_id, data in pairs(advtrains.wagon_save) do
		data.name=nil
		data.object=nil
		if data.driver then
			data.driver_name=data.driver:get_player_name()
			data.driver=nil
		else
			data.driver_name=nil
		end
		if data.discouple then
			data.discouple.object:remove()
			data.discouple=nil
		end
	end
	
	--versions:
	-- 1 - Initial new save format.
	local save_tbl={
		trains = advtrains.trains,
		wagon_save = advtrains.wagon_save,
		ptmap = advtrains.player_to_train_mapping,
		atc = advtrains.atc.save_data(),
		ndb = advtrains.ndb.save_data(),
		version = 1,
	}
	local datastr = minetest.serialize(save_tbl)
	if not datastr then
		minetest.log("error", " Failed to serialize advtrains save data!")
		return
	end
	local file, err = io.open(advtrains.fpath, "w")
	if err then
		minetest.log("error", " Failed to write advtrains save data to file "..advtrains.fpath..": "..(err or "Unknown Error"))
		return
	end
	file:write(datastr)
	file:close()
end

--## MAIN LOOP ##--
--Calls all subsequent main tasks of both advtrains and atlatc
local init_load
local save_interval=20
local save_timer=save_interval

minetest.register_globalstep(function(dtime_mt)
	--call load once. see advtrains.load() comment
	if not init_load then
		advtrains.load()
	end
	--limit dtime: if trains move too far in one step, automation may cause stuck and wrongly braking trains
	local dtime=dtime_mt
	if dtime>0.2 then
		atprint("Limiting dtime to 0.2!")
		dtime=0.2
	end
	
	advtrains.mainloop_trainlogic(dtime)
	if advtrains_itm_mainloop then
		advtrains_itm_mainloop(dtime)
	end
	if atlatc then
		atlatc.mainloop_stepcode(dtime)
		atlatc.interrupt.mainloop(dtime)
	end
	
	
	--trigger a save when necessary
	save_timer=save_timer-dtime
	if save_timer<=0 then
		local t=os.clock()
		--save
		advtrains.save()
		save_timer=save_interval
		atprintbm("saving", t)
	end
	
end)

--## MAIN LOAD ROUTINE ##
-- Causes the loading of everything
-- first time called in main loop (after the init phase) because luaautomation has to initialize first.
function advtrains.load()
	advtrains.avt_load() --loading advtrains. includes ndb at advtrains.ndb.load_data()
	if atlatc then
		atlatc.load() --includes interrupts
	end
	if advtrains_itm_init then
		advtrains_itm_init()
	end
	init_load=true
end

--## MAIN SAVE ROUTINE ##
-- Causes the saving of everything
function advtrains.save()
	if not init_load then
		--wait... we haven't loaded yet?!
		atwarn("Instructed to save() but load() was never called!")
		return
	end
	advtrains.avt_save() --saving advtrains. includes ndb at advtrains.ndb.save_data()
	if atlatc then
		atlatc.save()
	end
end
minetest.register_on_shutdown(advtrains.save)
