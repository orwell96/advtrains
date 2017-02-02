--chatcmds.lua
--Registers commands to modify the init and step code for LuaAutomation

local function get_init_form(env)
	local err = env.init_err or ""
	local code = env.init_code or ""
	atprint(err)
	local form = "size[10,10]button[0,0;2,1;run;Run InitCode]button[2,0;2,1;cls;Clear S]"
		.."button[4,0;2,1;save;Save] button[6,0;2,1;del;Delete Env.] textarea[0.2,1;10,10;code;Environment initialization code;"..minetest.formspec_escape(code).."]"
		.."label[0,9.8;"..err.."]"
	return form
end

core.register_chatcommand("env_setup", {
	params = "<environment name>",
	description = "Set up and modify AdvTrains LuaAutomation environment",
	privs = {atlatc=true},
	func = function(name, param)
		local env=atlatc.envs[param]
		if not env then return false,"Invalid environment name!" end
		minetest.show_formspec(name, "atlatc_envsetup_"..param, get_init_form(env))
		return true
	end,
})

core.register_chatcommand("env_create", {
	params = "<environment name>",
	description = "Create an AdvTrains LuaAutomation environment",
	privs = {atlatc=true},
	func = function(name, param)
		if not param or param=="" then return false, "Name required!" end
		if atlatc.envs[param] then return false, "Environment already exists!" end
		atlatc.envs[param] = atlatc.env_new(param)
		return true, "Created environment '"..param.."'. Use '/env_setup "..param.."' to define global initialization code, or start building LuaATC components!"
	end,
})


minetest.register_on_player_receive_fields(function(player, formname, fields)
	
	local pname=player:get_player_name()
	if not minetest.check_player_privs(pname, {atlatc=true}) then return end
	
	local envname=string.match(formname, "^atlatc_delconfirm_(.+)$")
	if envname and fields.sure=="YES" then
		atlatc.envs[envname]=nil
		minetest.chat_send_player(pname, "Environment deleted!")
		return
	end
	
	envname=string.match(formname, "^atlatc_envsetup_(.+)$")
	if not envname then return end
	
	local env=atlatc.envs[envname]
	if not env then return end
	
	if fields.del then
		minetest.show_formspec(pname, "atlatc_delconfirm_"..envname, "field[sure;"..minetest.formspec_escape("SURE TO DELETE ENVIRONMENT "..envname.."? Type YES (all uppercase) to continue or just quit form to cancel.")..";]")
		return
	end
	
	env.init_err=nil
	if fields.code then
		env.init_code=fields.code
	end
	if fields.run then
		env:run_initcode()
		minetest.show_formspec(pname, formname, get_init_form(env))
	end
end)
