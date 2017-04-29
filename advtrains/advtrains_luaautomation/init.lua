-- advtrains_luaautomation/init.lua
-- Lua automation features for advtrains
-- Uses global table 'atlatc' (AdvTrains_LuaATC)

-- Boilerplate to support localized strings if intllib mod is installed.
if minetest.get_modpath("intllib") then
    atltrans = intllib.Getter()
else
    atltrans = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

--Privilege
--Only trusted players should be enabled to build stuff which can break the server.

atlatc = { envs = {}}

minetest.register_privilege("atlatc", { description = "Player can place and modify LUA ATC components. Grant with care! Allows to execute bad LUA code.", give_to_singleplayer = false, default= false })

--assertt helper. error if a variable is not of a type
function assertt(var, typ)
	if type(var)~=typ then
		error("Assertion failed, variable has to be of type "..typ)
	end
end

local mp=minetest.get_modpath("advtrains_luaautomation")
if not mp then
	error("Mod name error: Mod folder is not named 'advtrains_luaautomation'!")
end
dofile(mp.."/environment.lua")
dofile(mp.."/interrupt.lua")
dofile(mp.."/active_common.lua")
dofile(mp.."/atc_rail.lua")
dofile(mp.."/operation_panel.lua")
dofile(mp.."/pcnaming.lua")
if mesecon then
	dofile(mp.."/p_mesecon_iface.lua")
end
dofile(mp.."/chatcmds.lua")


local filename=minetest.get_worldpath().."/advtrains_luaautomation"

function atlatc.load()
	local file, err = io.open(filename, "r")
	if not file then
		minetest.log("error", " Failed to read advtrains_luaautomation save data from file "..filename..": "..(err or "Unknown Error"))
	else
		atprint("luaautomation reading file:",filename)
		local tbl = minetest.deserialize(file:read("*a"))
		if type(tbl) == "table" then
			if tbl.version==1 then
				for envname, data in pairs(tbl.envs) do
					atlatc.envs[envname]=atlatc.env_load(envname, data)
				end
				atlatc.active.load(tbl.active)
				atlatc.interrupt.load(tbl.interrupt)
				atlatc.pcnaming.load(tbl.pcnaming)
			end
		else
			minetest.log("error", " Failed to read advtrains_luaautomation save data from file "..filename..": Not a table!")
		end
		file:close()
	end
	-- run init code of all environments
	atlatc.run_initcode()
end


atlatc.save = function()
	--versions:
	-- 1 - Initial save format.
	
	local envdata={}
	for envname, env in pairs(atlatc.envs) do
		envdata[envname]=env:save()
	end
	local save_tbl={
		version = 1,
		envs=envdata,
		active = atlatc.active.save(),
		interrupt = atlatc.interrupt.save(),
		pcnaming = atlatc.pcnaming.save(),
	}
	
	local datastr = minetest.serialize(save_tbl)
	if not datastr then
		minetest.log("error", " Failed to save advtrains_luaautomation save data to file "..filename..": Can't serialize!")
		return
	end
	local file, err = io.open(filename, "w")
	if err then
		minetest.log("error", " Failed to save advtrains_luaautomation save data to file "..filename..": "..(err or "Unknown Error"))
		return
	end
	file:write(datastr)
	file:close()
end


-- globalstep for step code
local timer, step_int=0, 2

function atlatc.mainloop_stepcode(dtime)
	timer=timer+dtime
	if timer>step_int then
		timer=0
		atlatc.run_stepcode()
	end
end
