--atc.lua
--registers and controls the ATC system

local atc={}
-- ATC persistence table. advtrains.atc is created by init.lua when it loads the save file.
atc.controllers = {}
function atc.load_data(data)
	atc.controllers = data and data.controllers or {}
end
function atc.save_data()
	return atc.controllers
end
--contents: {command="...", arrowconn=0-15 where arrow points}

--call from advtrains.detector subprogram

function atc.trigger_controller_train_enter(pos, train_id)
	atc.send_command(pos)
end

--general

function atc.send_command(pos)
	local pts=minetest.pos_to_string(pos)
	if atc.controllers[pts] then
		atprint("Called send_command at "..pts)
		local train_id = advtrains.detector.on_node[pts]
		if train_id then
			if advtrains.trains[train_id] then
				atprint("send_command inside if: "..sid(train_id))
				atc.train_reset_command(train_id)
				local arrowconn=atc.controllers[pts].arrowconn
				local train=advtrains.trains[train_id]
				for index, ppos in pairs(train.path) do
					if vector.equals(advtrains.round_vector_floor_y(ppos), pos) then
						advtrains.trains[train_id].atc_arrow =
								vector.equals(
										advtrains.dirCoordSet(pos, arrowconn),
										advtrains.round_vector_floor_y(train.path[index+train.movedir])
								)
						advtrains.trains[train_id].atc_command=atc.controllers[pts].command
						atprint("Sending ATC Command: "..atc.controllers[pts].command)
					end
				end
			end
		end
	end
	return false
end

function atc.train_reset_command(train_id)
	advtrains.trains[train_id].atc_command=nil
	advtrains.trains[train_id].atc_delay=0
	advtrains.trains[train_id].atc_brake_target=nil
	advtrains.trains[train_id].atc_wait_finish=nil
	advtrains.trains[train_id].atc_arrow=nil
end

--nodes
local idxtrans={static=1, mesecon=2, digiline=3}
local apn_func=function(pos, node)
	advtrains.ndb.update(pos, node)
	local meta=minetest.get_meta(pos)
	if meta then
		meta:set_string("infotext", "ATC controller, unconfigured.")
		meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
	end
end

advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_atc",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack_detector",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail_atc.png",
	description="ATC controller",
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
			after_place_node=apn_func,
			after_dig_node=function(pos)
				advtrains.invalidate_all_paths()
				advtrains.ndb.clear(pos)
				local pts=minetest.pos_to_string(pos)
				atc.controllers[pts]=nil
			end,
			on_receive_fields = function(pos, formname, fields, player)
				if minetest.is_protected(pos, player:get_player_name()) then
					minetest.chat_send_player(player:get_player_name(), "This position is protected!")
					return
				end
				local meta=minetest.get_meta(pos)
				if meta then
					if not fields.save then 
						--maybe only the dropdown changed
						if fields.mode then
							meta:set_string("mode", idxtrans[fields.mode])
							meta:set_string("infotext", "ATC controller, mode "..fields.mode.."\n"..( fields.mode=="digiline" and "Channel: "..meta:get_string("channel") or "Command: "..meta:get_string("command") ) )
							meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
						end
						return
					end
					meta:set_string("mode", idxtrans[fields.mode])
					meta:set_string("command", fields.command)
					meta:set_string("command_on", fields.command_on)
					meta:set_string("channel", fields.channel)
					meta:set_string("infotext", "ATC controller, mode "..fields.mode.."\n"..( fields.mode=="digiline" and "Channel: "..meta:get_string("channel") or "Command: "..meta:get_string("command") ) )
					meta:set_string("formspec", atc.get_atc_controller_formspec(pos, meta))
					
					local pts=minetest.pos_to_string(pos)
					local _, conn1=advtrains.get_rail_info_at(pos, advtrains.all_tracktypes)
					atc.controllers[pts]={command=fields.command, arrowconn=conn1}
					atc.send_command(pos)
				end
			end,
		}
	end
}, advtrains.trackpresets.t_30deg_straightonly)


function atc.get_atc_controller_formspec(pos, meta)
	local mode=tonumber(meta:get_string("mode")) or 1
	local command=meta:get_string("command")
	local command_on=meta:get_string("command_on")
	local channel=meta:get_string("channel")
	local formspec="size[8,6]"..
		"dropdown[0,0;3;mode;static,mesecon,digiline;"..mode.."]"
	if mode<3 then
		formspec=formspec.."field[0.5,1.5;7,1;command;Command;"..minetest.formspec_escape(command).."]"
		if tonumber(mode)==2 then
			formspec=formspec.."field[0.5,3;7,1;command_on;Command (on);"..minetest.formspec_escape(command_on).."]"
		end
	else
		formspec=formspec.."field[0.5,1.5;7,1;channel;Digiline channel;"..minetest.formspec_escape(channel).."]"
	end
	return formspec.."button_exit[0.5,4.5;7,1;save;Save]"
end

--from trainlogic.lua train step
local matchptn={
	["SM"]=function(id, train)
		train.tarvelocity=train.max_speed
		return 2
	end,
	["S([0-9]+)"]=function(id, train, match)
		train.tarvelocity=tonumber(match)
		return #match+1
	end,
	["B([0-9]+)"]=function(id, train, match)
		if train.velocity>tonumber(match) then
			train.atc_brake_target=tonumber(match)
			if train.tarvelocity>train.atc_brake_target then
				train.tarvelocity=train.atc_brake_target
			end
		end
		return #match+1
	end,
	["W"]=function(id, train)
		train.atc_wait_finish=true
		return 1
	end,
	["D([0-9]+)"]=function(id, train, match)
		train.atc_delay=tonumber(match)
		return #match+1
	end,
	["R"]=function(id, train)
		if train.velocity<=0 then
			train.movedir=train.movedir*-1
			train.atc_arrow = not train.atc_arrow
		else
			minetest.chat_send_all("ATC Reverse command warning: didn't reverse train!")
		end
		return 1
	end,
}

function atc.execute_atc_command(id, train)
	--strip whitespaces
	local command=string.match(train.atc_command, "^%s*(.*)$")
	
	
	if string.match(command, "^%s*$") then
		train.atc_command=nil
		return
	end
	--conditional statement?
	local is_cond, cond_applies
	local cond, rest=string.match(command, "^I([%+%-])(.+)$")
	if cond then
		is_cond=true
		if cond=="+" then
			cond_applies=train.atc_arrow
		end
		if cond=="-" then
			cond_applies=not train.atc_arrow
		end
	else 
		cond, compare, rest=string.match(command, "^I([<>]=?)([0-9]+)(.+)$")
		if cond and compare then
			is_cond=true
			if cond=="<" then
				cond_applies=train.velocity<tonumber(compare)
			end
			if cond==">" then
				cond_applies=train.velocity>tonumber(compare)
			end
			if cond=="<=" then
				cond_applies=train.velocity<=tonumber(compare)
			end
			if cond==">=" then
				cond_applies=train.velocity>=tonumber(compare)
			end
		end
	end	
	if is_cond then
		atprint("Evaluating if statement: "..command)
		atprint("Cond: "..(cond or "nil"))
		atprint("Applies: "..(cond_applies and "true" or "false"))
		atprint("Rest: "..rest)
		--find end of conditional statement
		local nest, pos, elsepos=0, 1
		while nest>=0 do
			if pos>#rest then
				minetest.chat_send_all("ATC command syntax error: I statement not closed: "..command)
				atc.train_reset_command(id)
				return
			end
			local char=string.sub(rest, pos, pos)
			if char=="I" then
				nest=nest+1
			end
			if char==";" then
				nest=nest-1
			end
			if nest==0 and char=="E" then
				elsepos=pos+0
			end
			pos=pos+1
		end
		if not elsepos then elsepos=pos-1 end
		if cond_applies then
			command=string.sub(rest, 1, elsepos-1)..string.sub(rest, pos)
		else
			command=string.sub(rest, elsepos+1, pos-2)..string.sub(rest, pos)
		end
		atprint("Result: "..command)
		train.atc_command=command
		atc.execute_atc_command(id, train)
		return
	else
		for pattern, func in pairs(matchptn) do
			local match=string.match(command, "^"..pattern)
			if match then
				local patlen=func(id, train, match)
				
				atprint("Executing: "..string.sub(command, 1, patlen))
				
				train.atc_command=string.sub(command, patlen+1)
				if train.atc_delay<=0 and not train.atc_wait_finish then
					--continue (recursive, cmds shouldn't get too long, and it's a end-recursion.)
					atc.execute_atc_command(id, train)
				end
				return
			end
		end
	end
	minetest.chat_send_all("ATC command parse error: "..command)
	atc.train_reset_command(id)
end



--move table to desired place
advtrains.atc=atc
