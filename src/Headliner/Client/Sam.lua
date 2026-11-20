-- Sam, the label manager (the R15 character "Guide" in the building, made by Hub.buildGuide).
-- He walks from room to room on checked ways (Hub.SAM_ROUTES), talks and waves in the tutorial,
-- works at the desk of his own office after it, and stands next to the board in your meetings
-- (click an artist on the board: Sam says a few words about them, Sam.say).
-- In Roblox he moves with the real character animations (walk / idle / sit, the same ones your own
-- character has: they are read from its Animate script); the hands (clipboard, talking, typing) are
-- set on top of them every frame (PreSimulation). Without an Animator (tests) he is posed by hand.
--   Sam.start(app)  Sam.stop()
--   Sam.walkTo(spot)            "start" | "meeting" | "board" | "laptop" | "maptable" | "stagehall" | "office"
--   Sam.sitDown("office")       walks there first
--   Sam.setTalk(talking, wave)  the tutorial bubble: hands move while he talks, wave = 0..1
--   Sam.say(app, text)          a short speech bubble at the bottom
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Root = script:FindFirstAncestor("Headliner")
local Hub = require(Root.World.Hub)
local UI = require(Root.Client.UI)

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
	if not Sam.rootHeight then
		-- measured from the feet (the character stands on the floor, never above it)
		local hrp, foot = g.PrimaryPart, g:FindFirstChild("LeftFoot")
		if hrp and foot then
			-- the character was built with its root at RootHeight above the floor
			Sam.rootHeight = math.clamp(hrp.CFrame.Position.Y - (foot.CFrame.Position.Y - foot.Size.Y / 2), 1, 6)
		else
			Sam.rootHeight = g:GetAttribute("RootHeight") or 3
		end
	end
	local h = Sam.rootHeight
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

-- walk to his office chair and sit down at the desk
function Sam.sitDown(kind)
	if Sam.sitting and Sam.sitting.kind == kind then
		return
	end
	local seat, spot = Hub.SAM_SEATS.office, "office"
	Sam.walkTo(spot, function()
		local _, hip = heights(model() or Instance.new("Model"))
		Sam.sitting = { kind = kind, spot = spot, standAt = Hub.GUIDE_SPOTS[spot], wayBack = {}, pos = seat.pos, look = seat.look, y = seat.seatTop + hip + 0.25, t = 0 }
		Sam.at = nil
	end)
end

function Sam.setTalk(talking, wave)
	Sam.talking, Sam.wave = talking, wave or 0
end

------------------------------------------------------------------ animation
-- the real animations: the same ones the player's character uses (its Animate script), else Roblox's defaults
local FALLBACK = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388", sit = "rbxassetid://2506281703" }
local ANIMATE_NAMES = { walk = { "walk", "WalkAnim" }, idle = { "idle", "Animation1" }, sit = { "sit", "SitAnim" } }
local function animationId(kind)
	local char = Players.LocalPlayer.Character
	local animate = char and char:FindFirstChild("Animate")
	local folder = animate and animate:FindFirstChild(ANIMATE_NAMES[kind][1])
	local a = folder and folder:FindFirstChild(ANIMATE_NAMES[kind][2])
	if a and a:IsA("Animation") and a.AnimationId ~= "" then
		return a.AnimationId
	end
	return nil
end
local function loadTracks(g)
	if Sam.tracks ~= nil then
		return Sam.tracks
	end
	local hum = g:FindFirstChildOfClass("Humanoid")
	if not hum then
		Sam.tracks = false
		return false
	end
	-- wait up to 4 s for the player's own animations, then take the defaults
	local ready = animationId("walk") ~= nil
	if not ready and (Sam.t or 0) < 4 then
		return nil
	end
	local ok, tracks = pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		local out = {}
		for kind in pairs(FALLBACK) do
			local anim = Instance.new("Animation")
			anim.AnimationId = animationId(kind) or FALLBACK[kind]
			local tr = animator:LoadAnimation(anim)
			tr.Looped = true
			tr.Priority = (kind == "idle") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
			out[kind] = tr
		end
		return out
	end)
	Sam.tracks = ok and tracks or false
	return Sam.tracks
end
local function playTrack(kind, speed)
	local tracks = Sam.tracks
	if not tracks then
		return
	end
	if Sam.playing ~= kind then
		for k, tr in pairs(tracks) do
			if k ~= kind and tr.IsPlaying then
				tr:Stop(0.25)
			end
		end
		tracks[kind]:Play(0.25)
		Sam.playing = kind
	end
	if speed then
		tracks[kind]:AdjustSpeed(speed)
	end
end

-- hands on top of the animations: the clipboard arm, talking, waving, typing at the desk
local function overlay(g, t, mode)
	local rs, ls = joint(g, "RightUpperArm", "RightShoulder"), joint(g, "LeftUpperArm", "LeftShoulder")
	local re, le = joint(g, "RightLowerArm", "RightElbow"), joint(g, "LeftLowerArm", "LeftElbow")
	local neck = joint(g, "Head", "Neck")
	local function set(j, cf)
		if j then
			j.Transform = cf
		end
	end
	local rad = math.rad
	if mode == "type" then
		set(rs, CFrame.Angles(rad(52 + math.sin(t * 11) * 3), 0, rad(6)))
		set(ls, CFrame.Angles(rad(52 + math.sin(t * 13 + 1) * 3), 0, rad(-6)))
		set(re, CFrame.Angles(rad(25), 0, 0))
		set(le, CFrame.Angles(rad(25), 0, 0))
		set(neck, CFrame.Angles(rad(-8 + math.sin(t * 0.4) * 4), rad(math.sin(t * 0.3) * 10), 0))
		return
	end
	set(ls, CFrame.Angles(rad(55 + math.sin(t * 1.3) * 2), 0, rad(-6))) -- the clipboard stays in front
	set(le, CFrame.Angles(rad(20), 0, 0))
	local wave = math.min(1, Sam.wave or 0)
	if mode == "stand" and wave > 0 then
		set(rs, CFrame.Angles(0, 0, rad(150 + math.sin(t * 9) * 18) * wave))
	elseif mode == "stand" and Sam.talking then
		set(rs, CFrame.Angles(rad(35 + math.sin(t * 3.1) * 14), 0, rad(8 + math.sin(t * 2.3) * 6)))
		set(neck, CFrame.Angles(rad(math.sin(t * 5) * 5), rad(math.sin(t * 1.7) * 8), 0))
	end
end

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
	if Sam.tracks == nil then
		loadTracks(g)
	end
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
		Sam.mode = "walk"
		if Sam.tracks then
			playTrack("walk", 0.75)
		else
			pose(g, Sam.t, "walk")
		end
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
		Sam.mode = (s.kind == "office") and "type" or "sit"
		if Sam.tracks then
			playTrack("sit")
		else
			pose(g, Sam.t, Sam.mode)
		end
		return
	end
	Sam.mode = "stand"
	if Sam.tracks then
		playTrack("idle")
	else
		pose(g, Sam.t, "stand")
	end
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
	Sam.tracks, Sam.playing = nil, nil
	Sam.conn = RunService.Heartbeat:Connect(function(dt)
		step(math.min(dt, 0.1))
		Sam.behave()
	end)
	-- the hands go on top of the animations, after the Animator wrote the joints for this frame
	local ok, ev = pcall(function()
		return RunService.PreSimulation
	end)
	Sam.conn2 = (ok and ev or RunService.Stepped):Connect(function()
		local g2 = model()
		if g2 and Sam.tracks then
			overlay(g2, Sam.t or 0, Sam.mode or "stand")
		end
	end)
end

function Sam.stop()
	for _, k in ipairs({ "conn", "conn2" }) do
		if Sam[k] then
			Sam[k]:Disconnect()
			Sam[k] = nil
		end
	end
	if Sam.tracks then
		for _, tr in pairs(Sam.tracks) do
			pcall(function()
				tr:Stop(0)
			end)
		end
	end
	Sam.tracks, Sam.playing = nil, nil
	if Sam.bubble then
		Sam.bubble:Destroy()
		Sam.bubble = nil
	end
	Sam.walk, Sam.sitting = nil, nil
end

-- after the tutorial: Sam works in his office, and stands next to the board when you hold a meeting
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
		if Sam.goal ~= "board" then
			Sam.walkTo("board")
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

------------------------------------------------------------------ what Sam knows about an artist (1-2 sentences)
function Sam.artistLine(ad, state)
	local Util = require(Root.Logic.Util)
	local GS = require(Root.Logic.GameState)
	local a = state.artists[ad.id]
	local fans = Util.short(Util.totalFans(a.fans))
	local who = (ad.members > 1) and (ad.genre .. " group of " .. ad.members) or (ad.genre .. ", solo")
	local name = "<b>" .. UI.esc(ad.name) .. "</b>"
	if a.signed then
		local tour = GS.activeTour(state, ad.id)
		local next
		local rest = GS.restLeft(state, ad.id)
		if tour then
			next = "On tour right now: keep an eye on the ticket sales."
		elseif rest > 0 then
			next = "After the last tour they need a break: " .. rest .. " more days, then we plan the next one."
		elseif a.hype >= 60 then
			next = "The fans are hungry: book bigger venues this time!"
		else
			next = "A tour in small clubs would build the hype."
		end
		return name .. " is one of ours (" .. who .. "), " .. fans .. " fans, hype " .. math.floor(a.hype) .. ". " .. next
	end
	local lvl = GS.level(state)
	local about = ad.pitch or ad.bio
	if ad.level > lvl then
		return name .. " (" .. who .. ", " .. fans .. " fans): " .. about .. " They only talk to labels of level " .. ad.level .. " and up."
	end
	local busy, days = GS.artistBusy(state, ad.id)
	if busy then
		return name .. " (" .. who .. ", " .. fans .. " fans): " .. about .. " But right now they " .. busy:gsub("^is ", "are ") .. ". Ask again in " .. days .. " days."
	end
	return name .. " (" .. who .. ", " .. fans .. " fans): " .. about .. " Signing costs " .. Util.money(ad.signCost) .. "."
end

------------------------------------------------------------------ Sam says something (a short bubble at the bottom)
function Sam.say(app, text, seconds)
	if Sam.bubble then
		Sam.bubble:Destroy()
	end
	local T = UI.Theme
	local f = UI.New("TextButton", { Parent = app.canvas, Name = "SamSays", AnchorPoint = Vector2.new(0.5, 1), Position = UI.px(960, 1010), Size = UI.px(900, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 84, UI.Corner(16), UI.Stroke(T.accent, 2, 0), UI.Padding(24, 24, 14, 16) })
	UI.New("UIListLayout", { Parent = f, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local name = UI.Label(f, "SAM  |  LABEL MANAGER", nil, UI.px(852, 22), { textSize = 15, font = UI.FontBlack, color = T.accent })
	name.LayoutOrder = 1
	name.ZIndex = 85
	local body = UI.New("TextLabel", { Parent = f, Size = UI.px(852, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = text, RichText = true, TextWrapped = true, TextColor3 = T.text, TextSize = 21, Font = UI.Font, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 85 })
	Sam.bubble = f
	Sam.sayText = text
	Sam.talking = true
	local token = {}
	Sam.sayToken = token
	local function close()
		if Sam.sayToken == token then
			Sam.talking = false
			if Sam.bubble == f then
				Sam.bubble = nil
			end
		end
		f:Destroy()
	end
	f.MouseButton1Click:Connect(close)
	task.delay(seconds or 8, close)
	local _ = body
	return f
end

return Sam
