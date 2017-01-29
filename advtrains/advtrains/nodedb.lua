--nodedb.lua
--database of all nodes that have 'save_in_nodedb' field set to true in node definition



--serialization format:
--(6byte poshash) (2byte contentid)
--contentid := (14bit nodeid, 2bit param2)

local function hash_to_bytes(x)
	local aH = math.floor(x / 1099511627776) % 256;
	local aL = math.floor(x /    4294967296) % 256;
	local bH = math.floor(x /      16777216) % 256;
	local bL = math.floor(x /         65536) % 256;
	local cH = math.floor(x /           256) % 256;
	local cL = math.floor(x                ) % 256;
	return(string.char(aH, aL, bH, bL, cH, cL));
end
local function cid_to_bytes(x)
	local cH = math.floor(x /           256) % 256;
	local cL = math.floor(x                ) % 256;
	return(string.char(cH, cL));
end
local function bytes_to_hash(bytes)
	local t={string.byte(bytes,1,-1)}
	local n = 
		t[1] * 1099511627776 +
		t[2] *    4294967296 +
		t[3] *      16777216 +
		t[4] *         65536 +
		t[5] *           256 +
		t[6]
    return n
end
local function bytes_to_cid(bytes)
	local t={string.byte(bytes,1,-1)}
	local n = 
		t[1] *           256 +
		t[2]
    return n
end
local function l2b(x)
	return x%4
end
local function u14b(x)
	return math.floor(x/4)
end
local ndb={}

--local variables for performance
local ndb_nodeids={}
local ndb_nodes={}

--load
--nodeids get loaded by advtrains init.lua and passed here
function ndb.load_data(data)
	ndb_nodeids = data and data.nodeids or {}
end

local path=minetest.get_worldpath().."/advtrains_ndb"

local file, err = io.open(path, "r")
if not file then
	atprint("load ndb failed: ", err or "Unknown Error")
else
	local cnt=0
	local hst=file:read(6)
	local cid=file:read(2)
	while hst and #hst==6 and cid and #cid==2 do
		ndb_nodes[bytes_to_hash(hst)]=bytes_to_cid(cid)
		cnt=cnt+1
		hst=file:read(6)
		cid=file:read(2)
	end
	atprint("nodedb: read", cnt, "nodes.")
	file:close()
end

--save
function ndb.save_data()
	local file, err = io.open(path, "w")
	if not file then
		atprint("load ndb failed: ", err or "Unknown Error")
	else
		for hash, cid in pairs(ndb_nodes) do
			file:write(hash_to_bytes(hash))
			file:write(cid_to_bytes(cid))
		end
		file:close()
	end
	return {nodeids = ndb_nodeids}
end

--function to get node. track database is not helpful here.
function ndb.get_node_or_nil(pos)
	local node=minetest.get_node_or_nil(pos)
	if node then
		return node
	else
		--maybe we have the node in the database...
		local cid=ndb_nodes[minetest.hash_node_position(pos)]
		if cid then
			local nodeid = ndb_nodeids[u14b(cid)]
			if nodeid then
				--atprint("ndb.get_node_or_nil",pos,"found node",nodeid,"cid",cid,"par2",l2b(cid))
				return {name=nodeid, param2 = l2b(cid)}
			end
		end
	end
	atprint("ndb.get_node_or_nil",pos,"not found")
end
function ndb.get_node(pos)
	local n=ndb.get_node_or_nil(pos)
	if not n then
		return {name="ignore", param2=0}
	end
	return n
end

function ndb.swap_node(pos, node)
	minetest.swap_node(pos, node)
	ndb.update(pos, node)
end

function ndb.update(pos, pnode)
	local node = pnode or minetest.get_node_or_nil(pos)
	if not node or node.name=="ignore" then return end
	if minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].groups.save_in_nodedb then
		local nid
		for tnid, nname in pairs(ndb_nodeids) do
			if nname==node.name then
				nid=tnid
			end
		end
		if not nid then
			nid=#ndb_nodeids+1
			ndb_nodeids[nid]=node.name
		end
		local hash = minetest.hash_node_position(pos)
		ndb_nodes[hash] = (nid * 4) + (l2b(node.param2 or 0))
		--atprint("nodedb: updating node", pos, "stored nid",nid,"assigned",ndb_nodeids[nid],"resulting cid",ndb_nodes[hash])
	else
		--at this position there is no longer a node that needs to be tracked.
		local hash = minetest.hash_node_position(pos)
		ndb_nodes[hash] = nil
	end
end

function ndb.clear(pos)
	local hash = minetest.hash_node_position(pos)
	ndb_nodes[hash] = nil
end


--get_node with pseudoload. now we only need track data, so we can use the trackdb as second fallback
--nothing new will be saved inside the trackdb.
--returns:
--true, conn1, conn2, rely1, rely2, railheight   in case everything's right.
--false  if it's not a rail or the train does not drive on this rail, but it is loaded or
--nil    if the node is neither loaded nor in trackdb
--the distraction between false and nil will be needed only in special cases.(train initpos)
function advtrains.get_rail_info_at(pos, drives_on)
	local rdp=advtrains.round_vector_floor_y(pos)
	
	local node=ndb.get_node_or_nil(rdp)
	
	--still no node?
	--advtrains.trackdb is nil when there's no data available.
	if not node then
		if advtrains.trackdb then
			--try raildb (see trackdb_legacy.lua)
			local dbe=(advtrains.trackdb[rdp.y] and advtrains.trackdb[rdp.y][rdp.x] and advtrains.trackdb[rdp.y][rdp.x][rdp.z])
			if dbe then
				for tt,_ in pairs(drives_on) do
					if not dbe.tracktype or tt==dbe.tracktype then
						return true, dbe.conn1, dbe.conn2, dbe.rely1 or 0, dbe.rely2 or 0, dbe.railheight or 0
					end
				end
			end
		end
		return nil
	end
	local nodename=node.name
	if(not advtrains.is_track_and_drives_on(nodename, drives_on)) then
		return false
	end
	local conn1, conn2, rely1, rely2, railheight, tracktype=advtrains.get_track_connections(node.name, node.param2)
	
	return true, conn1, conn2, rely1, rely2, railheight
end


minetest.register_abm({
        name = "advtrains:nodedb_on_load_update",
        nodenames = {"group:save_in_nodedb"},
        run_at_every_load = true,
        action = function(pos, node)
			local cid=ndb_nodes[minetest.hash_node_position(pos)]
			if cid then
				--if in database, detect changes and apply.
				local nodeid = ndb_nodeids[u14b(cid)]
				local param2 = l2b(cid)
				if not nodeid then
					--something went wrong
					atprint("nodedb: lbm nid not found", pos, "with nid", u14b(cid), "param2", param2, "cid is", cid)
					ndb.update(pos, node)
				else
					if (nodeid~=node.name or param2~=node.param2) then
						atprint("nodedb: lbm replaced", pos, "with nodeid", nodeid, "param2", param2, "cid is", cid)
						minetest.swap_node(pos, {name=nodeid, param2 = param2})
					end
				end
			else
				--if not in database, take it.
				atprint("nodedb: ", pos, "not in database")
				ndb.update(pos, node)
			end
        end,
        interval=10,
        chance=1,
    })
    
minetest.register_on_dignode(function(pos, oldnode, digger)
	ndb.clear(pos)
end)

function ndb.get_nodes()
	return ndb_nodes
end
function ndb.get_nodeids()
	return ndb_nodeids
end


advtrains.ndb=ndb

