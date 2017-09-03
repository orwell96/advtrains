--trackdb_legacy.lua
--loads the (old) track database. the only use for this is to provide data for rails that haven't been written into the ndb database.
--nothing will be saved.
--if the user thinks that he has loaded every track in his world at least once, he can delete the track database.

--trackdb[[y][x][z]={conn1, conn2, rely1, rely2, railheight}


--trackdb keeps its own save file.
advtrains.fpath_tdb=minetest.get_worldpath().."/advtrains_trackdb2"
local file, err = io.open(advtrains.fpath_tdb, "r")
if not file then
	atprint("Not loading a trackdb file.")
else
	local tbl = minetest.deserialize(file:read("*a"))
	if type(tbl) == "table" then
		advtrains.trackdb=tbl
		atprint("Loaded trackdb file.")
	end
	file:close()
end
	





