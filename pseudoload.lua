
--pseudoload.lua
--responsible for keeping up a database of all rail nodes existant in the world, regardless of whether the mapchunk is loaded.

advtrains.trackdb={}
--trackdb[tt][y][x][z]={conn1, conn2, rely1, rely2, railheight}
--serialization format:
--(2byte x)(2byte y)(2byte z)(4bits conn1, 4bits conn2)[(plain rely1)|(plain rely2)|(plain railheight)]\n
--[] may be missing if 0,0,0

--load initially
for tt, _ in pairs(advtrains.all_traintypes) do
	local pl_fpath=minetest.get_worldpath().."/advtrains_trackdb_"..tt
	advtrains.trackdb[tt]={}
	local file, err = io.open(pl_fpath, "r")
	if not file then
		local er=err or "Unknown Error"
		print("[advtrains]Failed loading advtrains trackdb save file "..er)
	else
		--custom format to save memory
		while true do
			local xbytes=file:read(2)
			if not xbytes then
				break --eof reached
			end
			local ybytes=file:read(2)
			local zbytes=file:read(2)
			local x=(string.byte(xbytes[1])-128)*256+(string.byte(xbytes[2]))
			local y=(string.byte(ybytes[1])-128)*256+(string.byte(ybytes[2]))
			local z=(string.byte(zbytes[1])-128)*256+(string.byte(zbytes[2]))
			
			local conn1=string.byte(file:read(1))
			local conn1=string.byte(file:read(1))
			
			if not advtrains.trackdb[tt][y] then advtrains.trackdb[tt][y]={} end
			if not advtrains.trackdb[tt][y][x] then advtrains.trackdb[tt][y][x]={} end
			
			local rest=file.read("*l")
			if rest~="" then
				local rely1, rely2, railheight=string.match(rest, "([^|]+)|([^|]+)|([^|]+)")
				if rely1 and rely2 and railheight then
					advtrains.trackdb[tt][y][x][z]={
						conn1=conn1, conn2=conn2,
						rely1=rely1, rely2=rely2,
						railheight=railheight
					}
				else
					advtrains.trackdb[tt][y][x][z]={
						conn1=conn1, conn2=conn2
					}
				end
			else
				advtrains.trackdb[tt][y][x][z]={
					conn1=conn1, conn2=conn2
				}
			end
		end
		file:close()
	end
end


function advtrains.save_trackdb()
	for tt, _ in pairs(advtrains.all_traintypes) do
		local pl_fpath=minetest.get_worldpath().."/advtrains_trackdb_"..tt
		local file, err = io.open(pl_fpath, "w")
		if not file then
			local er=err or "Unknown Error"
			print("[advtrains]Failed saving advtrains trackdb save file "..er)
		else
			--custom format to save memory
			for x,txl in pairs(advtrains.trackdb[tt]) do
				for y,tyl in pairs(txl) do
					for z,rail in pairs(tyl) do
						file:write(string.char(math.floor(x/256)+128)..string.char((x%256)))
						file:write(string.char(math.floor(y/256)+128)..string.char((y%256)))
						file:write(string.char(math.floor(z/256)+128)..string.char((z%256)))
						file:write(string.char(rail.conn1))
						file:write(string.char(rail.conn2))
						if (rail.rely1 and rail.rely1~=0) or (rail.rely2 and rail.rely2~=0) or (rail.railheight and rail.railheight~=0) then
							file:write(rail.rely1.."|"..rail.rely2.."|"..rail.railheight)
						end
						file:write("\n")
					end
				end
			end
			file:close()
		end
	end
end

--get_node with pseudoload.
--returns:
--true, conn1, conn2, rely1, rely2, railheight   in case everything's right.
--false  if it's not a rail or the train does not drive on this rail, but it is loaded or
--nil    if the node is neither loaded nor in trackdb
--the distraction between false and nil will be needed only in special cases.(train initpos)
function advtrains.get_rail_info_at(pos, traintype)
	local node=minetest.get_node_or_nil(pos)
	if not node then
		--try raildb
		local rdp=vector.round(rdp)
		local dbe=advtrains.trackdb[traintype][rdp.y][rdp.x][rdp.z]
		if dbe then
			return true, dbe.conn1, dbe.conn2, dbe.rely1 or 0, dbe.rely2 or 0, dbe.railheight or 0
		else
			return nil
		end
	end
	local nodename=node.name
	if(not advtrains.is_track_and_drives_on(nodename, advtrains.all_traintypes[traintype].drives_on)) then
		return false
	end
	local conn1, conn2, rely1, rely2, railheight=advtrains.get_track_connections(node.name, node.param2)
	
	--already in trackdb?
	local rdp=vector.round(rdp)
	if not advtrains.trackdb[traintype][rdp.y][rdp.x][rdp.z] then--TODO is this necessary?
		advtrains.trackdb[rdp.y][rdp.x][rdp.z]={
			conn1=conn1, conn2=conn2,
			rely1=rely1, rely2=rely2,
			railheight=railheight
		}
	end
	
	return true, conn1, conn2, rely1, rely2, railheight
end
function advtrains.reset_trackdb_position(pos)
	local rdp=vector.round(pos)
	for tt, _ in pairs(advtrains.all_traintypes) do
		advtrains.trackdb[tt][rdp.y][rdp.x][rdp.z]=nil
		advtrains.get_rail_info_at(pos, tt)--to restore it.
	end
end
	

