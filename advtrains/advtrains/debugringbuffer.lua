--so, some ringbuffers one for each train

local ringbuflen=200

local ringbufs={}
local ringbufcnt={}

function advtrains.drb_record(tid, msg)
	if not ringbufs[tid] then
		ringbufs[tid]={}
		ringbufcnt[tid]=0
	end
	ringbufs[tid][ringbufcnt[tid]]=msg
	ringbufcnt[tid]=ringbufcnt[tid]+1
	if ringbufcnt[tid] > ringbuflen then
		ringbufcnt[tid]=0
	end
end
function advtrains.drb_dump(tid)
	minetest.chat_send_all("Debug ring buffer output for '"..tid.."':")
	local stopcnt=ringbufcnt[tid]
	if not stopcnt then
		minetest.chat_send_all("ID unknown!")
		return
	end
	repeat
		minetest.chat_send_all(ringbufs[tid][ringbufcnt[tid]])
		ringbufcnt[tid]=ringbufcnt[tid]+1
		if ringbufcnt[tid] > ringbuflen then
			ringbufcnt[tid]=0
		end
	until ringbufcnt[tid]==stopcnt
end

minetest.register_chatcommand("atdebug_show",
	{
        params = "train sid", -- Short parameter description
        description = "Dump debug log", -- Full description
        privs = {train_operator=true}, -- Require the "privs" privilege to run
        func = function(name, param)
			advtrains.drb_dump(param)
        end, -- Called when command is run.
                                      -- Returns boolean success and text output.
    })
