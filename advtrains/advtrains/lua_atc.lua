-------------
--LUA ATC controllers

local latc={}

function latc.load_data(data)
end
function latc.save_data()
	return stuff
end

latc.data
latc.env_cdata
latc.init_code=""
latc.step_code=""

advtrains.fpath_latc=minetest.get_worldpath().."/advtrains_latc"
local file, err = io.open(advtrains.fpath_atc, "r")
if not file then
	local er=err or "Unknown Error"
	atprint("Failed loading advtrains latc save file "..er)
else
	local tbl = minetest.deserialize(file:read("*a"))
	if type(tbl) == "table" then
		atc.controllers=tbl.controllers
	end
	file:close()
end
function latc.save()
	
	local datastr = minetest.serialize({controllers = atc.controllers})
	if not datastr then
		minetest.log("error", " Failed to serialize latc data!")
		return
	end
	local file, err = io.open(advtrains.fpath_atc, "w")
	if err then
		return err
	end
	file:write(datastr)
	file:close()
end

--Privilege
--Only trusted players should be enabled to build stuff which can break the server.
--If I later decide to have multiple environments ('data' tables), I better store an owner for every controller for future reference.

minetest.register_privilege("advtrains_lua_atc", { description = "Player can place and modify LUA ATC components. Grant with care! Allows to execute bad LUA code.", give_to_singleplayer = false, default= false })

--Environment
--Code from mesecons_luacontroller (credit goes to Jeija and mesecons contributors)

local safe_globals = {
	"assert", "error", "ipairs", "next", "pairs", "select",
	"tonumber", "tostring", "type", "unpack", "_VERSION"
}
local function safe_print(param)
	print(dump(param))
end

local function safe_date()
	return(os.date("*t",os.time()))
end

-- string.rep(str, n) with a high value for n can be used to DoS
-- the server. Therefore, limit max. length of generated string.
local function safe_string_rep(str, n)
	if #str * n > mesecon.setting("luacontroller_string_rep_max", 64000) then
		debug.sethook() -- Clear hook
		error("string.rep: string length overflow", 2)
	end

	return string.rep(str, n)
end

-- string.find with a pattern can be used to DoS the server.
-- Therefore, limit string.find to patternless matching.
local function safe_string_find(...)
	if (select(4, ...)) ~= true then
		debug.sethook() -- Clear hook
		error("string.find: 'plain' (fourth parameter) must always be true in a LuaController")
	end

	return string.find(...)
end

latc.static_env = {
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
		datetable = safe_date,
	},
}
latc.static_env._G = env

for _, name in pairs(safe_globals) do
	latc.static_env[name] = _G[name]
end


--The environment all code calls get is a proxy table with a metatable.
--When an index is read:
-- Look in static_env
-- Look in volatile_env (user_written functions and userdata)
-- Look in saved_env (everything that's not a function or userdata)
--when an index is written:
-- If in static_env, do not allow
-- if function or userdata, volatile_env
-- if table, see below
-- else, save in saved_env



advtrains.latc=latc
