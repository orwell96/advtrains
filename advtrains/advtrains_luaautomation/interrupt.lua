-- interrupt.lua
-- implements interrupt queue

--to be saved: pos and evtdata
local iq={}
local queue={}
local timer=0
local run=false

function iq.load(data)
	local d=data or {}
	queue = d.queue or {}
	timer = d.timer or 0
end
function iq.save()
	return {queue = queue}
end

function iq.add(t, pos, evtdata)
	queue[#queue+1]={t=t+timer, p=pos, e=evtdata}
	run=true
end

minetest.register_globalstep(function(dtime)
	if run then
		timer=timer + math.min(dtime, 0.2)
		for i=1,#queue do
			local qe=queue[i]
			if not qe then
				table.remove(queue, i)
				i=i-1
			elseif timer>qe.t then
				local pos, evtdata=queue[i].p, queue[i].e
				local node=advtrains.ndb.get_node(pos)
				local ndef=minetest.registered_nodes[node.name]
				if ndef and ndef.luaautomation and ndef.luaautomation.fire_event then
					ndef.luaautomation.fire_event(pos, evtdata)
				end
				table.remove(queue, i)
				i=i-1
			end
		end
	end
end)



atlatc.interrupt=iq
