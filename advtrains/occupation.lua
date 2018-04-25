-- occupation.lua
--[[
Collects and manages positions where trains occupy and/or reserve/require space

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

*Sequence number:
Sequence number system reserved for possible future use, but unused.
The train will (and has to) memorize it's zone path indexes ("windows"), and do all actions that in any way modify these zone lengths
in the movement phase (after restore, but before reporting occupations)
((
The sequence number is used to determine out-of-date entries to the occupation list
The current sequence number (seqnum) is increased each step, until it rolls over MAX_SEQNUM, which is when a complete reset is triggered
Inside a step, when a train updates an occupation, the sequence number is set to the currently active sequence number
Whenever checking an entry for other occupations (e.g. in the aware zone), all entries that have a seqnum different from the current seqnum
are considered not existant, and are cleared.
Note that those outdated entries are only cleared on-demand, so there will be a large memory overhead over time. This is why in certain time intervals
complete resets are required (however, this method should be much more performant than resetting the whole occ table each step, to spare continuous memory allocations)
This complex behavior is required because there is no way to reliably determine which positions are _no longer_ occupied...
))

Composition of a step:

1. (only when needed) restore step - write all current occupations into the table
2. trains move
3. trains pass new occupations to here. We keep track of which entries have changed
4. we iterate our change lists and determine what to do

]]--
local o = {}

o.restore_required = true

local MAX_SEQNUM = 65500
local seqnum = 0

local occ = {}
local occ_chg = {}

local addchg, handle_chg


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

-- Resets the occupation memory, and sets the o.restore_required flag that instructs trains to report their occupations before moving
function o.reset()
	o.restore_required = true
	occ = {}
	occ_chg = {}
	seqnum = 0
end

-- set occupation inside the restore step
function o.init_occupation(train_id, pos, oid)
	local t = occgetcreate(pos)
	local i = 1
	while t[i] do
		if t[i]==train_id then
			break
		end
		i = i + 2
	end
	t[i] = train_id
	t[i+1] = oid
end

function o.set_occupation(train_id, pos, oid)
	local t = occgetcreate(pos)
	local i = 1
	while t[i] do
		if t[i]==train_id then
			break
		end
		i = i + 2
	end
	local oldoid = t[i+1] or 0
	if oldoid ~= oid then
		addchg(pos, train_id, oldoid, oid)
	end
	t[i] = train_id
	t[i+1] = oid
end


function o.clear_occupation(train_id, pos)
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
			local oldoid = t[i+1] or 0
			addchg(pos, train_id, oldoid, 0)
			moving = true
		end
		if moving then
			t[i]   = t[i+2]
			t[i+1] = t[i+3]
		end
		i = i + 2
	end
end

function addchg(pos, train_id, old, new)
	occ_chg[#occ_chg + 1] = {
		pos = pos,
		train_id = train_id,
		old_val = old,
		new_val = new,
	}
end

-- Called after all occupations have been fed in
-- This function is doing the interesting work...
function o.end_step()
	count_chg = false
	
	for _,chg in ipairs(occ_chg) do
		local t = occget(chg.pos)
		if not t then
			atwarn("o.end_step() change entry but there's no entry in occ table!",chg)
		end
		handle_chg(t, chg.pos, chg.train_id, chg.old_val, chg.new_val)
	end
	
	seqnum = seqnum + 1
end

function handle_chg(t, pos, train_id, old, new)
	-- Handling the actual "change" is only necessary on_train_enter (change to 1) and on_train_leave (change from 1)
	if new==1 then
		o.call_enter_callback(pos, train_id)
	elseif old==1 then
		o.call_leave_callback(pos, train_id)
	end
	
	--all other cases check the simultaneous presence of 2 or more occupations
	if #t<=2 then
		return
	end
	local blocking = {}
	local aware = {}
	local i = 1
	while t[i] do
		if t[i+1] ~= 7 then --anything not aware zone:
			blocking[#blocking+1] = i
		else
			aware[#aware+1] = i
		end
		i = i + 2
	end
	if #blocking > 0 then
		-- the aware trains should brake
		for _, ix in ipairs(aware) do
			atc.train_set_command(t[ix], "B2")
		end
		if #blocking > 1 then
			-- not good, 2 trains interfered with their blocking zones
			-- make them brake too
			local txt = {}
			for _, ix in ipairs(blocking) do
				atc.train_set_command(t[ix], "B2")
				txt[#txt+1] = t[ix]
			end
			atwarn("Trains",table.concat(txt, ","), "interfered with their blocking zones, braking...")
			-- TODO: different behavior for automatic trains! they need to be notified of those brake events and handle them!
			-- To drive in safety zone is ok when train is controlled by hand
		end
	end
	
end

function o.call_enter_callback(pos, train_id)
	--atprint("instructed to call enter calback")

	local node = advtrains.ndb.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_enter then
		mregnode.advtrains.on_train_enter(pos, train_id)
	end
end
function o.call_leave_callback(pos, train_id)
	--atprint("instructed to call leave calback")

	local node = advtrains.ndb.get_node(pos) --this spares the check if node is nil, it has a name in any case
	local mregnode=minetest.registered_nodes[node.name]
	if mregnode and mregnode.advtrains and mregnode.advtrains.on_train_leave then
		mregnode.advtrains.on_train_leave(pos, train_id)
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
			if t[i+1] ~= 7 then
				return true
			end
		end
		i = i + 2
	end
	return false
end

advtrains.occ = o
