

local map_def={
	example = {
		p1x=168,
		p1z=530,
		p2x=780,
		p2z=1016,
		background="itm_example.png",
	},
}

local itm_cache={}
local itm_pdata={}
local itm_conf_mindia=0.1

minetest.register_privilege("itm", { description = "Allows to display train map", give_to_singleplayer = true, default = false })

local function create_map_form_with_bg(d)
	local minx, minz, maxx, maxz = math.min(d.p1x, d.p2x), math.min(d.p1z, d.p2z), math.max(d.p1x, d.p2x), math.max(d.p1z, d.p2z)
	local form_x, form_z=10,10
	local edge_x, edge_z = form_x/(maxx-minx), form_z/(maxz-minz)
	local len_x, len_z=math.max(edge_x, itm_conf_mindia), math.max(edge_z, itm_conf_mindia)
	local form="size["..(form_x+edge_x)..","..(form_z+edge_z).."] background[0,0;0,0;"..d.background..";true] "
	local lbl={}
	
	for pts, tid in pairs(advtrains.detector.on_node) do
		local pos=minetest.get_pos_from_hash(pts)
		form=form.."box["..(edge_x*(pos.x-minx))..","..(form_z-(edge_z*(pos.z-minz)))..";"..len_x..","..len_z..";red]"
		lbl[sid(tid)]=pos
	end
	
	for t_id, xz in pairs(lbl) do
		form=form.."label["..(edge_x*(xz.x-minx))..","..(form_x-(edge_z*(xz.z-minz)))..";"..t_id.."]"
	end
	return form
end

local function create_map_form(d)
	if d.background then
		return create_map_form_with_bg(d)
	end
	
	local minx, minz, maxx, maxz = math.min(d.p1x, d.p2x), math.min(d.p1z, d.p2z), math.max(d.p1x, d.p2x), math.max(d.p1z, d.p2z)
	local form_x, form_z=10,10
	local edge_x, edge_z = form_x/(maxx-minx), form_z/(maxz-minz)
	local len_x, len_z=math.max(edge_x, itm_conf_mindia), math.max(edge_z, itm_conf_mindia)
	local form="size["..(form_x+edge_x)..","..(form_z+edge_z).."]"
	local lbl={}
	
	for x,itx in pairs(itm_cache) do
		if x>=minx and x<=maxx then
			for z,y in pairs(itx) do
				if z>=minz and z<=maxz then
					local adn=advtrains.detector.on_node[minetest.hash_node_position({x=x, y=y, z=z})]
					local color="gray"
					if adn then
						color="red"
						lbl[sid(adn)]={x=x, z=z}
					end
					form=form.."box["..(edge_x*(x-minx))..","..(form_z-(edge_z*(z-minz)))..";"..len_x..","..len_z..";"..color.."]"
				end
			end
		end
	end
	for t_id, xz in pairs(lbl) do
		form=form.."label["..(edge_x*(xz.x-minx))..","..(form_x-(edge_z*(xz.z-minz)))..";"..t_id.."]"
	end
	return form
end

local function cache_ndb()
	itm_cache={}
	local ndb_nodes=advtrains.ndb.get_nodes()
	for phs,_ in pairs(ndb_nodes) do
		local pos=minetest.get_position_from_hash(phs)
		if not itm_cache[pos.x] then
			itm_cache[pos.x]={}
		end
		itm_cache[pos.x][pos.z]=pos.y
	end
end

minetest.register_chatcommand("itm", {
	params="[x1 z1 x2 z2] or [mdef]",
	description="Display advtrains train map of given area.\nFirst form:[x1 z1 x2 z2] - specify area directly.\nSecond form:[mdef] - Use a predefined map background(see init.lua)\nThird form: No parameters - use WorldEdit position markers.",
	privs={itm=true},
	func = function(name, param)
		local mdef=string.match(param, "^(%S+)$")
		if mdef then
			local d=map_def[mdef]
			if not d then
				return false, "Map definiton not found: "..mdef
			end
			itm_pdata[name]=map_def[mdef]
			minetest.show_formspec(name, "itrainmap", create_map_form(d))
			return true, "Showing train map: "..mdef
		end
		local x1, z1, x2, z2=string.match(param, "^(%S+) (%S+) (%S+) (%S+)$")
		if not (x1 and z1 and x2 and z2) then
			if worldedit then
				local wep1, wep2=worldedit.pos1[name], worldedit.pos2[name]
				if wep1 and wep2 then
					x1, z1, x2, z2=wep1.x, wep1.z, wep2.x, wep2.z
				end
			end
		end
		if not (x1 and z1 and x2 and z2) then
			return false, "Invalid parameters and no WE positions set"
		end
		local d={p1x=x1, p1z=z1, p2x=x2, p2z=z2}
		itm_pdata[name]=d
		minetest.show_formspec(name, "itrainmap", create_map_form(d))
		return true, "Showing ("..x1..","..z1..")-("..x2..","..z2..")"
	end,
})
minetest.register_chatcommand("itm_cache_ndb", {
	params="",
	description="Cache advtrains node database again. Run when tracks changed.",
	privs={itm=true},
	func = function(name, param)
		cache_ndb()
		return true, "Done caching node database."
	end,
})

local timer=0
minetest.register_globalstep(function(dtime)
	timer=timer-math.min(dtime, 0.1)
	if timer<=0 then
		local t1=os.clock()
		local any=false
		for pname,d in pairs(itm_pdata) do
			minetest.show_formspec(pname, "itrainmap", create_map_form(d))
			any=true
		end
		if any then
			minetest.log("action", "itm "..math.floor((os.clock()-t1)*1000).."ms")
		end
		timer=2
	end
end)
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname=="itrainmap" and fields.quit then
		minetest.log("action", "itm form quit")
		itm_pdata[player:get_player_name()]=nil
	end
end)

--automatically run itm_cache_ndb
minetest.after(2, cache_ndb)
