-- Log accesses to driver stands and changes to switches

advtrains.log = function() end

if minetest.settings:get_bool("advtrains_enable_logging") then
	advtrains.logfile = advtrains.fpath .. "_log"

	function advtrains.log (event, player, pos, data)
	   local log = io.open(advtrains.logfile, "a+")
	   log:write(os.date()..": "..event.." by "..player.." at "..minetest.pos_to_string(pos).." -- "..(data or "").."\n")
	   log:close()
	end
end
