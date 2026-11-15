-- Mini tasks during a live show (planned for a later update: fix a spotlight, refill the merch stand ...).
-- The live show calls start / update / stop; every task registered here gets the show context:
--   ctx = { app, venue, look, crowd (Venue.build info), items (stage items), overlay (UI frame),
--           character, t (show time), seg (current part of the show), timeScale }
-- A task is a table { id = "...", start = function(ctx) end, update = function(dt, ctx) end, stop = function(ctx) end }.
-- Nothing is registered yet, so shows play exactly like before.
local ShowTasks = {}
ShowTasks.list = {}

function ShowTasks.register(task)
	table.insert(ShowTasks.list, task)
end

local function each(fnName, ...)
	for _, task in ipairs(ShowTasks.list) do
		local fn = task[fnName]
		if fn then
			local ok, err = pcall(fn, ...)
			if not ok then
				warn("ShowTasks." .. tostring(task.id) .. "." .. fnName .. ": " .. tostring(err))
			end
		end
	end
end

function ShowTasks.start(ctx)
	each("start", ctx)
end

function ShowTasks.update(dt, ctx)
	each("update", dt, ctx)
end

function ShowTasks.stop(ctx)
	each("stop", ctx)
end

return ShowTasks
