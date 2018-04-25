-- passive.lua
-- API to passive components, as described in passive_api.txt

local function getstate(parpos)
	local pos=atlatc.pcnaming.resolve_pos(parpos)
	if type(pos)~="table" or (not pos.x or not pos.y or not pos.z) then
		debug.sethook()
		error("Invalid position supplied to getstate")
	end
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.luaautomation and ndef.luaautomation.getstate then
		local st=ndef.luaautomation.getstate
		if type(st)=="function" then
			return st(pos, node)
		else
			return st
		end
	end
	return nil
end

local function setstate(parpos, newstate)
	local pos=atlatc.pcnaming.resolve_pos(parpos)
	if type(pos)~="table" or (not pos.x or not pos.y or not pos.z) then
		debug.sethook()
		error("Invalid position supplied to setstate")
	end
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.luaautomation and ndef.luaautomation.setstate then
		local st=ndef.luaautomation.setstate
		st(pos, node, newstate)
	end
end

local function is_passive(parpos)
	local pos=atlatc.pcnaming.resolve_pos(parpos)
	if type(pos)~="table" or (not pos.x or not pos.y or not pos.z) then
		return false
	end
	local node=advtrains.ndb.get_node(pos)
	local ndef=minetest.registered_nodes[node.name]
	if ndef and ndef.luaautomation and ndef.luaautomation.getstate then
		return true
	end
	return false
end

-- gets called from environment.lua
-- return the values here to keep them local
return getstate, setstate, is_passive
