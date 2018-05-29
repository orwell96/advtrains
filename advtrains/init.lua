
local lot = os.clock()
minetest.log("action", "[advtrains] Loading...")

-- Boilerplate to support localized strings if intllib mod is installed.
if minetest.get_modpath("intllib") then
    attrans = intllib.Getter()
else
    attrans = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

--advtrains

--Constant for maximum connection value/division of the circle
AT_CMAX = 16

advtrains = {trains={}, player_to_train_mapping={}}

--pcall
local no_action=false

local function reload_saves()
	atwarn("Restoring saved state in 1 second...")
	no_action=true
	--read last save state and continue, as if server was restarted
	for aoi, le in pairs(minetest.luaentities) do
		if le.is_wagon then
			le.object:remove()
		end
	end
	minetest.after(1, function()
		advtrains.load()
		atwarn("Reload successful!")
		advtrains.ndb.restore_all()
	end)
end

function advtrains.pcall(fun)
	if no_action then return end
	
	local succ, return1, return2, return3, return4=xpcall(fun, function(err)
			atwarn("Lua Error occured: ", err)
			atwarn(debug.traceback())
			if advtrains.atprint_context_tid_full then
				advtrains.path_print(advtrains.trains[advtrains.atprint_context_tid_full], atdebug)
			end
		end)
	if not succ then
		--reload_saves()
		no_action=true --this does also not belong here!
		minetest.request_shutdown()
	else
		return return1, return2, return3, return4
	end
end


advtrains.modpath = minetest.get_modpath("advtrains")

function advtrains.print_concat_table(a)
	local str=""
	local stra=""
	local t
	for i=1,20 do
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
			elseif type(t)=="function" then
				str=str.."<function>"
			elseif type(t)=="userdata" then
				str=str.."<userdata>"
			else
				str=str..t
			end
			str=str.." "
		end
	end
	return str
end

atprint=function() end
atlog=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("action", "[advtrains]"..text)
end
atwarn=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("warning", "[advtrains]"..text)
	minetest.chat_send_all("[advtrains] -!- "..text)
end
sid=function(id) if id then return string.sub(id, -6) end end


--ONLY use this function for temporary debugging. for consistent debug prints use atprint
atdebug=function(t, ...)
	local text=advtrains.print_concat_table({t, ...})
	minetest.log("action", "[advtrains]"..text)
	minetest.chat_send_all("[advtrains]"..text)
end

if minetest.settings:get_bool("advtrains_enable_debugging") then
	atprint=function(t, ...)
		local context=advtrains.atprint_context_tid or ""
		if not context then return end
		local text=advtrains.print_concat_table({t, ...})
		advtrains.drb_record(context, text)
		
		--atlog("@@",advtrains.atprint_context_tid,t,...)
	end
	dofile(advtrains.modpath.."/debugringbuffer.lua")
end

function assertt(var, typ)
	if type(var)~=typ then
		error("Assertion failed, variable has to be of type "..typ)
	end
end

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

advtrains.fpath=minetest.get_worldpath().."/advtrains"

dofile(advtrains.modpath.."/path.lua")
dofile(advtrains.modpath.."/trainlogic.lua")
dofile(advtrains.modpath.."/trainhud.lua")
dofile(advtrains.modpath.."/trackplacer.lua")
dofile(advtrains.modpath.."/tracks.lua")
dofile(advtrains.modpath.."/occupation.lua")
dofile(advtrains.modpath.."/atc.lua")
dofile(advtrains.modpath.."/wagons.lua")
dofile(advtrains.modpath.."/protection.lua")

dofile(advtrains.modpath.."/trackdb_legacy.lua")
dofile(advtrains.modpath.."/nodedb.lua")
dofile(advtrains.modpath.."/couple.lua")

dofile(advtrains.modpath.."/signals.lua")
dofile(advtrains.modpath.."/misc_nodes.lua")
dofile(advtrains.modpath.."/crafting.lua")
dofile(advtrains.modpath.."/craft_items.lua")

dofile(advtrains.modpath.."/log.lua")

if minetest.global_exists("digtron") then
	dofile(advtrains.modpath.."/digtron.lua")
end

--load/save


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
				--Save the train id into the train table to avoid having to pass id around
				for id, train in pairs(advtrains.trains) do
					train.id = id
				end
				advtrains.wagon_save = tbl.wagon_save
				advtrains.player_to_train_mapping = tbl.ptmap or {}
				advtrains.ndb.load_data(tbl.ndb)
				advtrains.atc.load_data(tbl.atc)
				--remove wagon_save entries that are not part of a train
				local todel=advtrains.merge_tables(advtrains.wagon_save)
				for tid, train in pairs(advtrains.trains) do
					train.id = tid
					for _, wid in ipairs(train.trainparts) do
						todel[wid]=nil
					end
				end
				for wid, _ in pairs(todel) do
					atwarn("Removing unused wagon", wid, "from wagon_save table.")
					advtrains.wagon_save[wid]=nil
				end
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

advtrains.avt_save = function(remove_players_from_wagons)
	--atprint("saving")
	--No more invalidating.
	--Instead, remove path a.s.o from the saved table manually
	
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
		if remove_players_from_wagons then
			data.seatp={}
		end
	end
	if remove_players_from_wagons then
		advtrains.player_to_train_mapping={}
	end
	
	local tmp_trains={}
	for id, train in pairs(advtrains.trains) do
		--first, deep_copy the train
		local v=advtrains.save_keys(train, {
			"last_pos", "last_pos_prev", "movedir", "velocity", "tarvelocity",
			"trainparts", "savedpos_off_track_index_offset", "recently_collided_with_env",
			"atc_brake_target", "atc_wait_finish", "atc_command", "atc_delay", "door_open",
			"text_outside", "text_inside", "couple_lck_front", "couple_lck_back", "line"
		})
		--then save it
		tmp_trains[id]=v
	end
	
	--versions:
	-- 1 - Initial new save format.
	local save_tbl={
		trains = tmp_trains,
		wagon_save = advtrains.wagons,
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
local init_load=false
local save_interval=20
local save_timer=save_interval
advtrains.mainloop_runcnt=0

minetest.register_globalstep(function(dtime_mt)
	return advtrains.pcall(function()
		advtrains.mainloop_runcnt=advtrains.mainloop_runcnt+1
		--atprint("Running the main loop, runcnt",advtrains.mainloop_runcnt)
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
			--advtrains.save()
			save_timer=save_interval
			atprintbm("saving", t)
		end
	end)
end)

--if something goes wrong in these functions, there is no help. no pcall here.

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
	no_action=false
	atlog("[load_all]Loaded advtrains save files")
end

--## MAIN SAVE ROUTINE ##
-- Causes the saving of everything
function advtrains.save(remove_players_from_wagons)
	if not init_load then
		--wait... we haven't loaded yet?!
		atwarn("Instructed to save() but load() was never called!")
		return
	end
	advtrains.avt_save(remove_players_from_wagons) --saving advtrains. includes ndb at advtrains.ndb.save_data()
	if atlatc then
		atlatc.save()
	end
	atprint("[save_all]Saved advtrains save files")
end
--minetest.register_on_shutdown(advtrains.save)

-- This chat command provides a solution to the problem known on the LinuxWorks server
-- There are many players that joined a single time, got on a train and then left forever
-- These players still occupy seats in the trains.
minetest.register_chatcommand("at_empty_seats",
	{
        params = "", -- Short parameter description
        description = "Detach all players, especially the offline ones, from all trains. Use only when no one serious is on a train.", -- Full description
        privs = {train_operator=true, server=true}, -- Require the "privs" privilege to run
        func = function(name, param)
			return advtrains.pcall(function()
				atwarn("Data is being saved. While saving, advtrains will remove the players from trains. Save files will be reloaded afterwards!")
				advtrains.save(true)
				reload_saves()
			end)
        end,
})
-- This chat command solves another problem: Trains getting randomly stuck.
minetest.register_chatcommand("at_reroute",
	{
        params = "", 
        description = "Delete all train routes, force them to recalculate", 
        privs = {train_operator=true}, -- Only train operator is required, since this is relatively safe.
        func = function(name, param)
			return advtrains.pcall(function()
				advtrains.invalidate_all_paths()
				return true, "Successfully invalidated train routes"
			end)
        end,
})


local tot=(os.clock()-lot)*1000
minetest.log("action", "[advtrains] Loaded in "..tot.."ms")
