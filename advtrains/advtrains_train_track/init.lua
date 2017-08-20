advtrains.register_tracks("regular", {
	nodename_prefix="advtrains:track",
	texture_prefix="advtrains_track",
	shared_model="trackplane.b3d",
	description=attrans("Deprecated Track"),
	formats={vst1={}, vst2={}},
}, advtrains.ap.t_45deg)

--flat
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared.png",
	description=attrans("Track"),
	formats={},
}, advtrains.ap.t_30deg_flat)
--slopes
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack",
	texture_prefix="advtrains_dtrack",
	models_prefix="advtrains_dtrack",
	models_suffix=".obj",
	shared_texture="advtrains_dtrack_shared.png",
	second_texture="default_gravel.png",
	description=attrans("Track"),
	formats={vst1={true, false, true}, vst2={true, false, true}, vst31={true}, vst32={true}, vst33={true}},
}, advtrains.ap.t_30deg_slope)

--bumpers
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_bumper",
	texture_prefix="advtrains_dtrack_bumper",
	models_prefix="advtrains_dtrack_bumper",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_rail.png",
	--bumpers still use the old texture until the models are redone.
	description=attrans("Bumper"),
	formats={},
}, advtrains.ap.t_30deg_straightonly)
--legacy bumpers
for _,rot in ipairs({"", "_30", "_45", "_60"}) do
	minetest.register_alias("advtrains:dtrack_bumper"..rot, "advtrains:dtrack_bumper_st"..rot)
end
-- atc track
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_atc",
	texture_prefix="advtrains_dtrack_atc",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_atc.png",
	description=attrans("ATC controller"),
	formats={},
	get_additional_definiton = advtrains.atc_function
}, advtrains.trackpresets.t_30deg_straightonly)
-- loading and unloading tracks
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_unload",
	texture_prefix="advtrains_dtrack_unload",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_unload.png",
	description=attrans("Unloading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		   end,
		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, true)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)
advtrains.register_tracks("default", {
	nodename_prefix="advtrains:dtrack_load",
	texture_prefix="advtrains_dtrack_load",
	models_prefix="advtrains_dtrack",
	models_suffix=".b3d",
	shared_texture="advtrains_dtrack_shared_load.png",
	description=attrans("Loading Track"),
	formats={},
	get_additional_definiton = function(def, preset, suffix, rotation)
		return {
		   after_dig_node=function(pos)
		      advtrains.invalidate_all_paths()
		      advtrains.ndb.clear(pos)
		   end,

		   advtrains = {
		      on_train_enter = function(pos, train_id)
			 train_load(pos, train_id, false)
		      end,
		   },
		}
	end
				     }, advtrains.trackpresets.t_30deg_straightonly)



if mesecon then
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_off",
		texture_prefix="advtrains_dtrack_detector",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_detector_off.png",
		description=attrans("Detector Rail"),
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.off,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_train_enter=function(pos, train_id)
						advtrains.ndb.swap_node(pos, {name="advtrains:dtrack_detector_on".."_"..suffix..rotation, param2=advtrains.ndb.get_node(pos).param2})
						mesecon.receptor_on(pos, advtrains.meseconrules)
					end
				}
			}
		end
	}, advtrains.ap.t_30deg_straightonly)
	advtrains.register_tracks("default", {
		nodename_prefix="advtrains:dtrack_detector_on",
		texture_prefix="advtrains_dtrack",
		models_prefix="advtrains_dtrack",
		models_suffix=".b3d",
		shared_texture="advtrains_dtrack_shared_detector_on.png",
		description="Detector(on)(you hacker you)",
		formats={},
		get_additional_definiton = function(def, preset, suffix, rotation)
			return {
				mesecons = {
					receptor = {
						state = mesecon.state.on,
						rules = advtrains.meseconrules
					}
				},
				advtrains = {
					on_train_leave=function(pos, train_id)
						advtrains.ndb.swap_node(pos, {name="advtrains:dtrack_detector_off".."_"..suffix..rotation, param2=advtrains.ndb.get_node(pos).param2})
						mesecon.receptor_off(pos, advtrains.meseconrules)
					end
				}
			}
		end
	}, advtrains.ap.t_30deg_straightonly_noplacer)
end
--TODO legacy
--I know lbms are better for this purpose
for name,rep in pairs({swl_st="swlst", swr_st="swrst", swl_cr="swlcr", swr_cr="swrcr", }) do
	minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep, param2=node.param2}) end,
    })
    minetest.register_abm({
    --  In the following two fields, also group:groupname will work.
        nodenames = {"advtrains:track_"..name.."_45"},
       interval = 1.0, -- Operation interval in seconds
       chance = 1, -- Chance of trigger per-node per-interval is 1.0 / this
       action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:track_"..rep.."_45", param2=node.param2}) end,
    })
end

if advtrains.register_replacement_lbms then
minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert1"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst1", param2=(node.param2+2)%4}) end,
})
minetest.register_lbm({
	name = "advtrains:ramp_replacement_1",
--  --  In the following two fields, also group:groupname will work.
	nodenames = {"advtrains:track_vert2"},
	action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_vst2", param2=(node.param2+2)%4}) end,
})
	minetest.register_abm({
		name = "advtrains:st_rep_1",
	--  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st"},
		interval=1,
		chance=1,
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st", param2=node.param2}) end,
	})
	minetest.register_lbm({
		name = "advtrains:st_rep_1",
	--  --  In the following two fields, also group:groupname will work.
		nodenames = {"advtrains:track_st_45"},
		action = function(pos, node, active_object_count, active_object_count_wider) minetest.set_node(pos, {name="advtrains:dtrack_st_45", param2=node.param2}) end,
	})
end
