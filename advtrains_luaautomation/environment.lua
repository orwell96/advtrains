-------------
-- lua sandboxed environment

-- function to cross out functions and userdata.
-- modified from dump()
function atlatc.remove_invalid_data(o, nested)
	if o==nil then return nil end
	local valid_dt={["nil"]=true, boolean=true, number=true, string=true}
	if type(o) ~= "table" then
		--check valid data type
		if not valid_dt[type(o)] then
			return nil
		end
		return o
	end
	-- Contains table -> true/nil of currently nested tables
	nested = nested or {}
	if nested[o] then
		return nil
	end
	nested[o] = true
	for k, v in pairs(o) do
		v = atlatc.remove_invalid_data(v, nested)
	end
	nested[o] = nil
	return o
end


local env_proto={
	load = function(self, envname, data)
		self.name=envname
		self.sdata=data.sdata and atlatc.remove_invalid_data(data.sdata) or {}
		self.fdata={}
		self.init_code=data.init_code or ""
		self.step_code=data.step_code or ""
	end,
	save = function(self)
		-- throw any function values out of the sdata table
		self.sdata = atlatc.remove_invalid_data(self.sdata)
		return {sdata = self.sdata, init_code=self.init_code, step_code=self.step_code}
	end,
}

--Environment
--Code modified from mesecons_luacontroller (credit goes to Jeija and mesecons contributors)

local safe_globals = {
	"assert", "error", "ipairs", "next", "pairs", "select",
	"tonumber", "tostring", "type", "unpack", "_VERSION"
}

--print is actually minetest.chat_send_all()
--using advtrains.print_concat_table because it's cool
local function safe_print(t, ...)
	local str=advtrains.print_concat_table({t, ...})
	minetest.log("action", "[atlatc] "..str)
	minetest.chat_send_all(str)
end

local function safe_date()
	return(os.date("*t",os.time()))
end

-- string.rep(str, n) with a high value for n can be used to DoS
-- the server. Therefore, limit max. length of generated string.
local function safe_string_rep(str, n)
	if #str * n > 2000 then
		debug.sethook() -- Clear hook
		error("string.rep: string length overflow", 2)
	end

	return string.rep(str, n)
end

-- string.find with a pattern can be used to DoS the server.
-- Therefore, limit string.find to patternless matching.
-- Note: Disabled security since there are enough security leaks and this would be unneccessary anyway to DoS the server
local function safe_string_find(...)
	--if (select(4, ...)) ~= true then
	--	debug.sethook() -- Clear hook
	--	error("string.find: 'plain' (fourth parameter) must always be true for security reasons.")
	--end

	return string.find(...)
end

local mp=minetest.get_modpath("advtrains_luaautomation")
local p_api_getstate, p_api_setstate, p_api_is_passive = dofile(mp.."/passive.lua")

local static_env = {
	--core LUA functions
	print = safe_print,
	string = {
		byte = string.byte,
		char = string.char,
		format = string.format,
		len = string.len,
		lower = string.lower,
		upper = string.upper,
		rep = safe_string_rep,
		reverse = string.reverse,
		sub = string.sub,
		find = safe_string_find,
	},
	math = {
		abs = math.abs,
		acos = math.acos,
		asin = math.asin,
		atan = math.atan,
		atan2 = math.atan2,
		ceil = math.ceil,
		cos = math.cos,
		cosh = math.cosh,
		deg = math.deg,
		exp = math.exp,
		floor = math.floor,
		fmod = math.fmod,
		frexp = math.frexp,
		huge = math.huge,
		ldexp = math.ldexp,
		log = math.log,
		log10 = math.log10,
		max = math.max,
		min = math.min,
		modf = math.modf,
		pi = math.pi,
		pow = math.pow,
		rad = math.rad,
		random = math.random,
		sin = math.sin,
		sinh = math.sinh,
		sqrt = math.sqrt,
		tan = math.tan,
		tanh = math.tanh,
	},
	table = {
		concat = table.concat,
		insert = table.insert,
		maxn = table.maxn,
		remove = table.remove,
		sort = table.sort,
	},
	os = {
		clock = os.clock,
		difftime = os.difftime,
		time = os.time,
		date = safe_date,
	},
	POS = function(x,y,z) return {x=x, y=y, z=z} end,
	getstate = p_api_getstate,
	setstate = p_api_setstate,
	is_passive = p_api_is_passive,
	--interrupts are handled per node, position unknown. (same goes for digilines)
	--however external interrupts can be set here.
	interrupt_pos = function(pos, imesg)
		if not type(pos)=="table" or not pos.x or not pos.y or not pos.z then
			debug.sethook()
			error("Invalid position supplied to interrupt_pos")
		end
		atlatc.interrupt.add(0, pos, {type="ext_int", ext_int=true, message=imesg})
	end,
}

for _, name in pairs(safe_globals) do
	static_env[name] = _G[name]
end


--The environment all code calls get is a table that has set static_env as metatable.
--In general, every variable is local to a single code chunk, but kept persistent over code re-runs. Data is also saved, but functions and userdata and circular references are removed
--Init code and step code's environments are not saved
-- S - Table that can contain any save data global to the environment. Will be saved statically. Can't contain functions or userdata or circular references.
-- F - Table global to the environment, can contain volatile data that is deleted when server quits.
--     The init code should populate this table with functions and other definitions.

local proxy_env={}
--proxy_env gets a new metatable in every run, but is the shared environment of all functions ever defined.

-- returns: true, fenv if successful; nil, error if error 
function env_proto:execute_code(localenv, code, evtdata, customfct)
	local metatbl ={
		__index = function(t, i)
			if i=="S" then
				return self.sdata
			elseif i=="F" then
				return self.fdata
			elseif i=="event" then
				return evtdata
			elseif customfct and customfct[i] then
				return customfct[i]
			elseif localenv and localenv[i] then
				return localenv[i]
			end
			return static_env[i]
		end,
		__newindex = function(t, i, v)
			if i=="S" or i=="F" or i=="event" or (customfct and customfct[i]) or static_env[i] then
				debug.sethook()
				error("Trying to overwrite environment contents")
			end
			localenv[i]=v
		end,
	}
	setmetatable(proxy_env, metatbl)
	local fun, err=loadstring(code)
	if not fun then
		return false, err
	end
	
	setfenv(fun, proxy_env)
	local succ, data = pcall(fun)
	if succ then
		data=localenv
	end
	return succ, data
end

function env_proto:run_initcode()
	if self.init_code and self.init_code~="" then
		local old_fdata=self.fdata
		self.fdata = {}
		atprint("[atlatc]Running initialization code for environment '"..self.name.."'")
		local succ, err = self:execute_code({}, self.init_code, {type="init", init=true})
		if not succ then
			atwarn("[atlatc]Executing InitCode for '"..self.name.."' failed:"..err)
			self.init_err=err
			if old_fdata then
				self.fdata=old_fdata
				atwarn("[atlatc]The 'F' table has been restored to the previous state.")
			end
		end
	end
end
function env_proto:run_stepcode()
	if self.step_code and self.step_code~="" then
		local succ, err = self:execute_code({}, self.step_code, nil, {})
		if not succ then
			--TODO
		end
	end
end

--- class interface

function atlatc.env_new(name)
	local newenv={
		name=name,
		init_code="",
		step_code="",
		sdata={}
	}
	setmetatable(newenv, {__index=env_proto})
	return newenv
end
function atlatc.env_load(name, data)
	local newenv={}
	setmetatable(newenv, {__index=env_proto})
	newenv:load(name, data)
	return newenv
end

function atlatc.run_initcode()
	for envname, env in pairs(atlatc.envs) do
		env:run_initcode()
	end
end
function atlatc.run_stepcode()
	for envname, env in pairs(atlatc.envs) do
		env:run_stepcode()
	end
end




