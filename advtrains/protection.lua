-- advtrains
-- protection.lua: privileges and rail protection, and some helpers


-- Privileges to control TRAIN DRIVING/COUPLING
minetest.register_privilege("train_operator", {
	description = "Without this privilege, a player can't do anything about trains, neither place or remove them nor drive or couple them (but he can build tracks if he has track_builder)",
	give_to_singleplayer= true,
});

minetest.register_privilege("train_admin", {
	description = "Player may drive, place or remove any trains from/to anywhere, regardless of owner, whitelist or protection",
	give_to_singleplayer= true,
});

-- Privileges to control TRACK BUILDING
minetest.register_privilege("track_builder", {
	description = "Player can place and/or dig rails not protected from him. If he also has protection_bypass, he can place/dig any rails",
	give_to_singleplayer= true,
});

-- Privileges to control OPERATING TURNOUTS/SIGNALS
minetest.register_privilege("railway_operator", {
	description = "Player can operate turnouts and signals not protected from him. If he also has protection_bypass, he can operate any turnouts/signals",
	give_to_singleplayer= true,
});

-- there is a configuration option "allow_build_only_owner". If this is active, a player having track_builder can only build rails and operate signals/turnouts in an area explicitly belonging to him
-- (checked using a dummy player called "*dummy*" (which is not an allowed player name))

--[[
Protection/privilege concept:
Tracks:
	Protected 1 node all around a rail and 4 nodes upward (maybe make this dynamically determined by the rail...)
	if track_builder privilege:
		if not protected from* player:
			if allow_build_only_owner:
				if unprotected:
					deny
			else:
				allow
	deny
Wagons in general:
	Players can only place/destroy wagons if they have train_operator
Wagon driving controls:
	The former seat_access tables are unnecessary, instead there is a whitelist for the driving stands
	on player trying to access a driver stand:
	if is owner or is on whitelist:
		allow
	else:
		deny
Wagon coupling:
	Derived from the privileges for driving stands. The whitelist is shared (and also settable on non-driverstand wagons)
	for each of the two bordering wagons:
		if is owner or is on whitelist:
			allow

*"protected from" means the player is not allowed to do things, while "protected by" means that the player is (one of) the owner(s) of this area

]]--

local boo = minetest.settings:get_bool("advtrains_allow_build_to_owner")


local nocheck
-- Check if the node we are about to check is in the range of a track that is protected from a player
--WARN: true means here that the action is forbidden!
function advtrains.check_track_protection(pos, pname)
	if nocheck or pname=="" then
		return false
	end
	nocheck=true --prevent recursive calls, never check this again if we're already in
	local r, vr = 1, 3
	local nodes = minetest.find_nodes_in_area(
		{x = pos.x - r, y = pos.y - vr, z = pos.z - r},
		{x = pos.x + r, y = pos.y, z = pos.z + r},
		{"group:advtrains_track"})
	for _,npos in ipairs(nodes) do
		if not minetest.check_player_privs(pname, {track_builder = true}) then
			if boo and not minetest.is_protected(npos, pname) and minetest.is_protected(npos, "*dummy*") then
				nocheck = false
				return false
			else
				minetest.chat_send_player(pname, "You are not allowed to dig or place nodes near tracks (missing track_builder privilege)")
				minetest.log("action", pname.." tried to dig/place nodes near the track at "..minetest.pos_to_string(npos).." but does not have track_builder")
				nocheck = false
				return true
			end
		end
		if not minetest.check_player_privs(pname, {protection_bypass = true}) then
			if minetest.is_protected(npos, pname) then
				nocheck = false
				minetest.record_protection_violation(pos, pname)
				return true
			end
		end
	end
	nocheck=false
	return false
end

local old_is_protected = minetest.is_protected
minetest.is_protected = function(pos, pname)
	if advtrains.check_track_protection(pos, pname) then
		return true
	end
	return old_is_protected(pos, pname)
end

--WARN: true means here that the action is allowed!
function advtrains.check_driving_couple_protection(pname, owner, whitelist)
	if minetest.check_player_privs(pname, {train_admin = true}) then
		return true
	end
	if not minetest.check_player_privs(pname, {train_operator = true}) then
		return false
	end
	if not owner or owner == pname then
		return true
	end
	if whitelist and string.find(" "..whitelist.." ", " "..pname.." ", nil, true) then
		return true
	end
	return false
end
function advtrains.check_turnout_signal_protection(pos, pname)
	nocheck=true
	if not minetest.check_player_privs(pname, {railway_operator = true}) then
		if boo and not minetest.is_protected(pos, pname) and minetest.is_protected(pos, "*dummy*") then
			nocheck=false
			return true
		else
			minetest.chat_send_player(pname, "You are not allowed to operate turnouts and signals (missing railway_operator privilege)")
			minetest.log("action", pname.." tried to operate turnout/signal at "..minetest.pos_to_string(pos).." but does not have railway_operator")
			nocheck=false
			return false
		end
	end
	if not minetest.check_player_privs(pname, {protection_bypass = true}) then
		if minetest.is_protected(pos, pname) then
			minetest.record_protection_violation(pos, pname)
			nocheck=false
			return false
		end
	end
	nocheck=false
	return true
end
