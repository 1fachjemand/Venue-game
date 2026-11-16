-- Sam, the label manager (the R15 character "Guide" in the building, made by Hub.buildGuide).
-- He walks from room to room on checked ways (Hub.SAM_ROUTES), talks and waves in the tutorial,
-- works at the desk of his own office after it, and joins your meetings on a meeting chair.
--   Sam.start(app)  Sam.stop()
--   Sam.walkTo(spot)            "start" | "meeting" | "laptop" | "maptable" | "stagehall" | "office"
--   Sam.sitDown(kind)           "office" | "meeting" (walks there first)
--   Sam.setTalk(talking, wave)  the tutorial bubble: hands move while he talks, wave = 0..1
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Root = script:FindFirstAncestor("Headliner")
local Hub = require(Root.World.Hub)

local O = Hub.ORIGIN
local SPEED = 9 -- studs per second (a calm walk)
local Sam = { at = "start" }

local function model()
	local root = workspace:FindFirstChild("StarlightRecords")
	return root and root:FindFirstChild("Guide")
end
Sam.model = model

local function joint(g, partName, jointName)
	local p = g:FindFirstChild(partName)
	local j = p and p:FindFirstChild(jointName)
	return (j and j:IsA("Motor6D")) and j or nil
end

-- height of the root above the floor when standing, and above the hips (for sitting)
local function heights(g)
	local h = g:GetAttribute("RootHeight") or 3
	if not Sam.hipOffset then
		local hrp = g.PrimaryPart
		local leg = g:FindFirstChild("LeftUpperLeg")
		if hrp and leg then
			Sam.hipOffset = math.clamp(hrp.CFrame.Position.Y - (leg.CFrame.Position.Y + leg.Size.Y / 2), 0.2, 2)
		else
			Sam.hipOffset = 0.9
		end
	end
	return h, Sam.hipOffset
end

local function place(pos, look, y)
	local g = model()
	if not g then
		return
	end
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, 1)
	end
	local p = O + Vector3.new(pos.X, y, pos.Z)
	local target = CFrame.lookAt(p, p + dir.Unit)
	local root = g.PrimaryPart
	if not root then
		return
	end
	if g:FindFirstChildOfClass("Humanoid") then
		-- a real character: the joints carry every body part with the (anchored) root part
		root.CFrame = target
	else
		-- a figure from loose parts: each part keeps its place relative to the root (measured once,
		-- so no rounding errors add up over thousands of frames)
		if not Sam.offsets or Sam.offsetModel ~= g then
			Sam.offsets, Sam.offsetModel = {}, g
			local inv = root.CFrame:Inverse()
			for _, d in ipairs(g:GetDescendants()) do
				if d:IsA("BasePart") and d ~= root then
					Sam.offsets[d] = inv * d.CFrame
				end
			end
		end
		root.CFrame = target
		for part, off in pairs(Sam.offsets) do
			part.CFrame = target * off
		end
	end
	Sam.pos, Sam.look = Vector3.new(pos.X, 0, pos.Z), dir.Unit
end

-- stands at a spot, looking at the player (or into the room)
local function standAt(spot)
	local p = Hub.GUIDE_SPOTS[spot or "start"]
	if not p then
		return
	end
	local h = heights(model() or Instance.new("Model"))
	local look = Vector3.new(0, 0, 1)
	local char = Players.LocalPlayer.Character
	if char and char.PrimaryPart then
		look = (char.PrimaryPart.CFrame.Position - O) - p
	end
	place(p, look, h)
	Sam.at = spot
end

------------------------------------------------------------------ moving
-- walk along points (hub coordinates); onDone when there
local function follow(points, onDone)
	if #points == 0 then
		if onDone then
			onDone()
		end
		return
	end
	Sam.sitting = nil
	Sam.walk = { pts = points, i = 1, from = Sam.pos or points[1], t = 0, onDone = onDone }
end

function Sam.walkTo(spot, onDone)
	if not Hub.GUIDE_SPOTS[spot] then
		return
	end
	Sam.goal = spot
	local from = Sam.at or "start"
	if Sam.sitting then
		-- stand up first: back to the floor point next to the chair
		local s = Sam.sitting
		Sam.sitting = nil
		local back = { s.standAt }
		for _, p in ipairs(s.wayBack or {}) do
			table.insert(back, p)
		end
		follow(back, function()
			Sam.at = s.spot
			Sam.walkTo(spot, onDone)
		end)
		return
	end
	if from == spot then
		Sam.walk = nil
		standAt(spot)
		if onDone then
			onDone()
		end
		return
	end
	local pts = Hub.samRoute(from, spot)
	Sam.at = nil
	follow(pts, function()
		Sam.at = spot
		standAt(spot)
		if onDone then
			onDone()
		end
	end)
end

-- walk to a chair and sit down (office: at his desk, meeting: a free meeting chair)
function Sam.sitDown(kind)
	if Sam.sitting and Sam.sitting.kind == kind then
		return
	end
	local seat, spot, way
	if kind == "office" then
		seat, spot, way = Hub.SAM_SEATS.office, "office", {}
	else
		local occupied = {}
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart then
			occupied[hum.SeatPart.Name] = true
		end
		for _, m in ipairs(Hub.SAM_SEATS.meeting) do
			if not occupied[m.seat] then
				seat = m
				break
			end
		end
		seat = seat or Hub.SAM_SEATS.meeting[1]
		spot, way = "meeting", seat.way or {}
	end
	Sam.walkTo(spot, function()
		follow(way, function()
			local h, hip = heights(model() or Instance.new("Model"))
			local standAt = (#way > 0) and way[#way] or Hub.GUIDE_SPOTS[spot]
			local back = {}
			for i = #way - 1, 1, -1 do
				table.insert(back, way[i])
			end
			Sam.sitting = { kind = kind, spot = spot, standAt = standAt, wayBack = back, pos = seat.pos, look = seat.look, y = seat.seatTop + hip + 0.25, t = 0 }
			Sam.at = nil
			local _ = h
		end)
	end)
end

function Sam.setTalk(talking, wave)
	Sam.talking, Sam.wave = talking, wave or 0
end

------------------------------------------------------------------ animation
local function pose(g, t, mode)
	local rs, ls = joint(g, "RightUpperArm", "RightShoulder"), joint(g, "LeftUpperArm", "LeftShoulder")
	local re = joint(g, "RightLowerArm", "RightElbow")
	local lh, rh = joint(g, "LeftUpperLeg", "LeftHip"), joint(g, "RightUpperLeg", "RightHip")
	local lk, rk = joint(g, "LeftLowerLeg", "LeftKnee"), joint(g, "RightLowerLeg", "RightKnee")
	local neck, waist = joint(g, "Head", "Neck"), joint(g, "UpperTorso", "Waist")
	local function set(j, cf)
		if j then
			j.Transform = cf
		end
	end
	local rad = math.rad
	if mode == "walk" then
		local s = math.sin(t * 8)
		set(lh, CFrame.Angles(rad(28) * s, 0, 0))
		set(rh, CFrame.Angles(-rad(28) * s, 0, 0))
		set(lk, CFrame.Angles(-rad(30) * math.max(0, -s), 0, 0))
		set(rk, CFrame.Angles(-rad(30) * math.max(0, s), 0, 0))
		set(rs, CFrame.Angles(rad(22) * s, 0, 0))
		set(re, CFrame.Angles(rad(12), 0, 0))
		set(ls, CFrame.Angles(rad(55), 0, rad(-6))) -- the clipboard stays in front
		set(neck, CFrame.Angles(0, 0, 0))
		set(waist, CFrame.Angles(0, rad(4) * s, 0))
	elseif mode == "sit" or mode == "type" then
		set(lh, CFrame.Angles(rad(90), 0, 0))
		set(rh, CFrame.Angles(rad(90), 0, 0))
		set(lk, CFrame.Angles(-rad(90), 0, 0))
		set(rk, CFrame.Angles(-rad(90), 0, 0))
		if mode == "type" then
			-- both hands on the keyboard, small quick moves, a look at the screen now and then
			set(rs, CFrame.Angles(rad(52 + math.sin(t * 11) * 3), 0, rad(6)))
			set(ls, CFrame.Angles(rad(52 + math.sin(t * 13 + 1) * 3), 0, rad(-6)))
			set(re, CFrame.Angles(rad(25), 0, 0))
			set(neck, CFrame.Angles(rad(-8 + math.sin(t * 0.4) * 4), rad(math.sin(t * 0.3) * 10), 0))
		else
			-- in the meeting: listens, nods, hands on the table
			set(rs, CFrame.Angles(rad(40 + (Sam.talking and math.sin(t * 3) * 12 or 0)), 0, rad(6)))
			set(ls, CFrame.Angles(rad(48), 0, rad(-6)))
			set(re, CFrame.Angles(rad(20), 0, 0))
			set(neck, CFrame.Angles(rad(math.sin(t * 1.3) * 4), rad(math.sin(t * 0.5) * 12), 0))
		end
		set(waist, CFrame.Angles(rad(4), 0, 0))
	else
		-- standing: talking hands, waving, or calm
		set(lh, CFrame.new())
		set(rh, CFrame.new())
		set(lk, CFrame.new())
		set(rk, CFrame.new())
		set(re, CFrame.new())
		local wave = math.min(1, Sam.wave or 0)
		if wave > 0 then
			set(rs, CFrame.Angles(0, 0, rad(150 + math.sin(t * 9) * 18) * wave))
		elseif Sam.talking then
			set(rs, CFrame.Angles(rad(35 + math.sin(t * 3.1) * 14), 0, rad(8 + math.sin(t * 2.3) * 6)))
		else
			set(rs, CFrame.Angles(rad(math.sin(t * 1.2) * 3), 0, 0))
		end
		set(ls, CFrame.Angles(rad(55 + math.sin(t * 1.3) * 2), 0, rad(-6)))
		set(neck, Sam.talking and CFrame.Angles(rad(math.sin(t * 5) * 5), rad(math.sin(t * 1.7) * 8), 0) or CFrame.Angles(0, rad(math.sin(t * 0.6) * 6), 0))
		set(waist, CFrame.Angles(rad(math.sin(t * 1.6) * 1.2), 0, 0))
	end
end

local function step(dt)
	local g = model()
	if not g then
		return
	end
	Sam.t = (Sam.t or 0) + dt
	Sam.wave = math.max(0, (Sam.wave or 0) - dt)
	local h = heights(g)
	local w = Sam.walk
	if w then
		local target = w.pts[w.i]
		local cur = Sam.pos or target
		local d = target - cur
		local stepLen = SPEED * dt
		if d.Magnitude <= stepLen then
			cur = target
			w.i = w.i + 1
		else
			cur = cur + d.Unit * stepLen
		end
		local look = (d.Magnitude > 0.05) and d or (Sam.look or Vector3.new(0, 0, 1))
		place(cur, look, h)
		pose(g, Sam.t, "walk")
		if w.i > #w.pts then
			Sam.walk = nil
			if w.onDone then
				w.onDone()
			end
		end
		return
	end
	local s = Sam.sitting
	if s then
		-- slides onto the chair, then sits (typing at his desk, listening in a meeting)
		s.t = math.min(1, s.t + dt * 2)
		local from = s.standAt
		local p = from:Lerp(s.pos, s.t)
		local y = h + (s.y - h) * s.t
		place(p, s.look, y)
		pose(g, Sam.t, (s.kind == "office") and "type" or "sit")
		return
	end
	pose(g, Sam.t, "stand")
end

function Sam.start(app)
	Sam.stop()
	Sam.app = app
	Sam.pos, Sam.walk, Sam.sitting, Sam.at = nil, nil, nil, "start"
	local g = model()
	if g and g.PrimaryPart then
		local p = g.PrimaryPart.CFrame.Position - O
		Sam.pos = Vector3.new(p.X, 0, p.Z)
	end
	Sam.conn = RunService.Heartbeat:Connect(function(dt)
		step(math.min(dt, 0.1))
		Sam.behave()
	end)
end

function Sam.stop()
	if Sam.conn then
		Sam.conn:Disconnect()
		Sam.conn = nil
	end
	Sam.walk, Sam.sitting = nil, nil
end

-- after the tutorial: Sam works in his office, and sits in when you hold a meeting
function Sam.behave()
	local app = Sam.app
	if not app or not app.state then
		return
	end
	local tut = app.state.tutorial
	if type(tut) == "table" and not tut.done then
		return
	end
	if app.mode == "meeting" then
		if not (Sam.sitting and Sam.sitting.kind == "meeting") and Sam.goal ~= "meeting" then
			Sam.goal = "meeting"
			Sam.sitDown("meeting")
		end
	elseif Sam.goal ~= "office" then
		Sam.goal = "office"
		Sam.sitDown("office")
	end
end

-- instantly at his desk (a loaded game after the tutorial)
function Sam.placeAtDesk()
	local s = Hub.SAM_SEATS.office
	local g = model()
	if not g then
		return
	end
	local h, hip = heights(g)
	local _ = h
	Sam.walk = nil
	Sam.goal = "office"
	Sam.pos = Hub.GUIDE_SPOTS.office
	Sam.sitting = { kind = "office", spot = "office", standAt = Hub.GUIDE_SPOTS.office, wayBack = {}, pos = s.pos, look = s.look, y = s.seatTop + hip + 0.25, t = 1 }
end

return Sam
