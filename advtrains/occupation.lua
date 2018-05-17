-- occupation.lua
--[[
Collects and manages positions where trains occupy and/or reserve/require space
THIS SECTION ABOVE IS OUTDATED, look below

Zone diagram of a train:
              |___| |___| --> Direction of travel
              oo oo+oo oo
=|=======|===|===========|===|=======|===================|========|===
 |SafetyB|CpB|   Train   |CpF|SafetyF|        Brake      |Aware   |
[1]     [2] [3]         [4] [5]     [6]                 [7]      [8]

ID|Name   |Desc
 0 Free    Zone that was occupied before, which has now been left
 1 Train   Zone where the train actually is.
 2 SafetyB Safety zone behind the train. extends 4m
 3 SafetyF Safety zone in front of the train. extends 4m
			If a train is about to enter this zone, immediately brake it down to 2
 4 CpB     Backside coupling zone. If the coupling zones of 2 trains overlap, they can be coupled
 5 CpF     Frontside coupling zone
 6 Brake   Brake distance of the train. Extends to the point ~5 nodes in front
			of the point where the train would stop if it would regularily brake now.
 7 Aware   Awareness zone. Extends 10-20 nodes beyond the Brake zone
			Whenever any of the non-aware zones of other trains are detected here, the train will start to brake.
			
Table format:
occ[y][x][z] = {
	[1] = train 1 id
	[2] = train 1 ZoneID
//	[3] = entry seqnum*
	...
	[2n-1] = train n id
	[2n  ] = train n ZoneID
//	[3n-2] = train n id
//	[3n-1] = train n ZoneID
//	[3n  ] = entry seqnum*
}
occ_chg[n] = {
	pos = vector,
	train_id,
	old_val, (0 when entry did not exist before)
	new_val, (0 when entry was deleted)
}

---------------------
It turned out that, especially for the TSS, some more, even overlapping zones are required.
Packing those into a data structure would just become a huge mess!
Instead, this occupation system will store the path indices of positions in the corresponding.
train's paths.
So, the occupation is a reverse lookup of paths.
Then, a callback system will handle changes in those indices, as follows:

Whenever the train generates new path items (path_get/path_create), their counterpart indices will be filled in here.
Whenever a path gets invalidated or path items are deleted, their index counterpart is erased from here.

When a train needs to know whether a position is blocked by another train, it will (and is permitted to)
query the train.index and train.end_index and compare them to the blocked position's index.

Callback system for 3rd-party path checkers: TODO
advtrains.te_register_on_new_path(func(id, train))
-- Called when a train's path is re-initalized, either when it was invalidated
-- or the saves were just loaded
-- It can be assumed that everything is in the state of when the last run
-- of on_update was made, but all indices are shifted by an unknown amount.

advtrains.te_register_on_update(func(id, train))
-- Called each step and after a train moved, its length changed or some other event occured
-- The path is unmodified, and train.index and train.end_index can be reliably
-- queried for the new position and length of the train.
-- note that this function might be called multiple times per step, and this 
-- function being called does not necessarily mean that something has changed.
-- It is ensured that on_new_path callbacks are executed prior to these callbacks whenever
-- an invalidation or a reload occured.

All callbacks are allowed to save certain values inside the train table, but they must ensure that
those are reinitialized in the on_new_path callback. The on_new_path callback must explicitly
set ALL OF those values to nil or to a new updated value, and must not rely on their existence.

]]--
local o = {}

local occ = {}
local occ_chg = {}


local function occget(p)
	local t = occ[p.y]
	if not t then
		occ[p.y] = {}
		t = occ[p.y]
	end
	local s = t
	t = t[p.x]
	if not t then
		s[p.x] = {}
		t = s[p.x]
	end
	return t[p.z]
end
local function occgetcreate(p)
	local t = occ[p.y]
	if not t then
		occ[p.y] = {}
		t = occ[p.y]
	end
	local s = t
	t = t[p.x]
	if not t then
		s[p.x] = {}
		t = s[p.x]
	end
	s = t
	t = t[p.z]
	if not t then
		s[p.z] = {}
		t = s[p.z]
	end
	return t
end


function o.set_item(train_id, pos, idx)
	local t = occgetcreate(pos)
	local i = 1
	while t[i] do
		if t[i]==train_id then
			break
		end
		i = i + 2
	end
	t[i] = train_id
	t[i+1] = idx
end


function o.clear_item(train_id, pos)
	local t = occget(pos)
	if not t then return end
	local i = 1
	local moving = false
	while t[i] do
		if t[i]==train_id then
			if moving then
				-- if, for some occasion, there should be a duplicate entry, erase this one too
				atwarn("Duplicate occupation entry at",pos,"for train",train_id,":",t)
				i = i - 2
			end
			moving = true
		end
		if moving then
			t[i]   = t[i+2]
			t[i+1] = t[i+3]
		end
		i = i + 2
	end
end

-- Checks whether some other train (apart from train_id) has it's 0 zone here
function o.check_collision(pos, train_id)
	local npos = advtrains.round_vector_floor_y(pos)
	local t = occget(npos)
	if not t then return end
	local i = 1
	while t[i] do
		if t[i]~=train_id then
			local idx = t[i+1]
			local train = advtrains.trains[train_id]
			advtrains.train_ensure_init(train_id, train)
			if idx >= train.end_index and idx <= train.index then
				return true
			end
		end
		i = i + 2
	end
	return false
end

-- Gets a mapping of train id's to indexes of trains that share this path item with this train
-- The train itself will not be included.
-- If the requested index position is off-track, returns {}.
-- returns (table with train_id->index), position
function o.get_occupations(train, index)
	local ppos, ontrack = advtrains.path_get(train, index)
	if not ontrack then
		atdebug("Train",train.id,"get_occupations requested off-track",index)
		return {}, pos
	end
	local pos = advtrains.round_vector_floor_y(ppos)
	local t = occget(pos)
	local r = {}
	local i = 1
	local train_id = train.id
	while t[i] do
		if t[i]~=train_id then
			r[train_id] = t[i+1]
		end
		i = i + 2
	end
	return r, pos
end
advtrains.occ = o
