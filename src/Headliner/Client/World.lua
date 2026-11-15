-- The label building on the client: the player's character, the stations (ProximityPrompts),
-- name tags over the stations, the guide arrow, the world map on the table, the charts wall and
-- the stage hall door. The building itself is built by the server (World/Hub.lua).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Root = script:FindFirstAncestor("Headliner")
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local WorldMap = require(Root.Data.WorldMap)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Hub = require(Root.World.Hub)
local Stage3D = require(Root.Client.Stage3D)

local T = UI.Theme
local New = UI.New
local O = Hub.ORIGIN

local World = {}
World.prompts = {} -- station id -> ProximityPrompt
World.markers = {} -- station id -> { gui, name, sub }
World.frozen = false

local function hum()
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char
end
World.humanoid = hum

------------------------------------------------------------------ character
function World.freeze(on)
	World.frozen = on
	pcall(function()
		ProximityPromptService.Enabled = not on
	end)
	local h = hum()
	if h then
		h.WalkSpeed = on and 0 or 16
		h.JumpPower = on and 0 or 50
		h.JumpHeight = on and 0 or 7.2
	end
end

function World.resetCamera()
	local cam = workspace.CurrentCamera
	local h = hum()
	cam.CameraType = Enum.CameraType.Custom
	if h then
		cam.CameraSubject = h
	end
	cam.FieldOfView = 70
end

-- puts the character back at the label office (after a show)
function World.toSpawn()
	local _, char = hum()
	if char and char.PrimaryPart then
		char:PivotTo(CFrame.lookAt(O + Hub.SPAWN + Vector3.new(0, 3.5, 0), O + Hub.SPAWN + Vector3.new(0, 3.5, 10)))
	end
end

local function onCharacter(char)
	local h = char:WaitForChild("Humanoid", 10)
	if not h then
		return
	end
	World.freeze(World.frozen)
	World.resetCamera()
	h.Seated:Connect(function()
		World.refresh()
	end)
end

------------------------------------------------------------------ 3D helpers (client-only parts)
local function cpart(parent, name, size, cf, color, material, transparency)
	return New("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Transparency = transparency or 0,
		Parent = parent,
	})
end

-- name tag floating over a station
local function marker(id, info)
	local anchor = cpart(World.folder, "Marker_" .. id, Vector3.new(0.2, 0.2, 0.2), CFrame.new(O + info.pos + Vector3.new(0, (id == "charts") and 7.2 or 6, (id == "charts") and 1.5 or 0)), T.accent, nil, 1)
	local gui = New("BillboardGui", { Parent = anchor, Size = UDim2.fromOffset(260, 74), AlwaysOnTop = false, LightInfluence = 0, MaxDistance = 90 })
	local box = New("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.panel, BackgroundTransparency = 0.15, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.accent2, 2, 0.2) })
	local name = New("TextLabel", { Parent = box, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = info.name, TextColor3 = T.text, TextSize = 24, Font = UI.FontBlack })
	local sub = New("TextLabel", { Parent = box, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = info.sub, TextColor3 = T.accent2, TextSize = 16, Font = UI.FontBold })
	World.markers[id] = { gui = gui, box = box, name = name, sub = sub, anchor = anchor }
end

-- glowing arrow over the next station + a light beam from the player to it
local function buildArrow()
	local m = New("Model", { Name = "GuideArrow", Parent = World.folder })
	local a = cpart(m, "ArmA", Vector3.new(0.7, 3.2, 0.7), CFrame.new(), T.gold, Enum.Material.Neon)
	local b = cpart(m, "ArmB", Vector3.new(0.7, 3.2, 0.7), CFrame.new(), T.gold, Enum.Material.Neon)
	local stem = cpart(m, "Stem", Vector3.new(0.7, 3.4, 0.7), CFrame.new(), T.gold, Enum.Material.Neon)
	New("PointLight", { Parent = stem, Range = 14, Brightness = 1.5, Color = T.gold })
	local target = New("Attachment", { Name = "BeamTarget", Parent = stem })
	World.arrow = { model = m, a = a, b = b, stem = stem, target = target }
	local beam = New("Beam", {
		Name = "GuideBeam",
		Parent = m,
		Attachment1 = target,
		Color = ColorSequence.new(T.gold, T.accent2),
		Transparency = NumberSequence.new(0.45, 0.75),
		Width0 = 0.35,
		Width1 = 0.35,
		FaceCamera = true,
		LightEmission = 1,
		Segments = 12,
		CurveSize0 = 4,
		CurveSize1 = -4,
	})
	World.beam = beam
end

local function placeArrow(t)
	local ar = World.arrow
	if not ar then
		return
	end
	local target = World.target and Hub.STATIONS[World.target]
	local visible = target ~= nil and not World.frozen
	if not visible then
		for _, p in ipairs({ ar.a, ar.b, ar.stem }) do
			p.Transparency = 1
		end
		World.beam.Enabled = false
		return
	end
	local base = O + target.pos + Vector3.new(0, ((World.target == "charts") and 3 or 9) + math.sin(t * 3) * 0.6, (World.target == "charts") and 3 or 0)
	local spin = CFrame.Angles(0, t * 1.5, 0)
	local cf = CFrame.new(base) * spin
	ar.stem.CFrame = cf * CFrame.new(0, 2.2, 0)
	-- arrow head pointing down (a V under the stem)
	ar.a.CFrame = cf * CFrame.new(-0.85, 0.9, 0) * CFrame.Angles(0, 0, math.rad(40))
	ar.b.CFrame = cf * CFrame.new(0.85, 0.9, 0) * CFrame.Angles(0, 0, math.rad(-40))
	for _, p in ipairs({ ar.a, ar.b, ar.stem }) do
		p.Transparency = 0
	end
	-- the beam starts at the character's chest
	local _, char = hum()
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		local att = root:FindFirstChild("GuideFrom")
		if not att then
			att = New("Attachment", { Name = "GuideFrom", Parent = root })
		end
		World.beam.Attachment0 = att
		World.beam.Enabled = (root.Position - base).Magnitude > 14
	else
		World.beam.Enabled = false
	end
end

------------------------------------------------------------------ the world map on the table (land as glowing tiles)
local MAP_S = 22 / 360
local function mapPos(lat, lon, y)
	-- north is the far side seen from the office (+Z), east to the right (-X)
	return O + Vector3.new(-lon * MAP_S, y or 3.24, 6 + (lat - 11) * MAP_S)
end
World.mapPos = mapPos

local function buildTableMap()
	local f = New("Folder", { Name = "TableMap", Parent = World.folder })
	local deg = 360 / WorldMap.W
	for _, r in ipairs(WorldMap.land) do
		local row, col, w, h = r[1], r[2], r[3], r[4]
		local lon = -180 + (col + w / 2) * deg
		local lat = WorldMap.LAT_TOP - (row + h / 2) * deg
		cpart(f, "Land", Vector3.new(w * deg * MAP_S, 0.06, h * deg * MAP_S), CFrame.new(mapPos(lat, lon)), T.accent2, Enum.Material.Neon, 0.35)
	end
	World.pinFolder = New("Folder", { Name = "Pins", Parent = World.folder })
end

-- pins on the table: where the running tours play
local function refreshPins()
	if not World.pinFolder then
		return
	end
	World.pinFolder:ClearAllChildren()
	local seen = {}
	for _, t in ipairs(World.app.state.tours) do
		if t.status ~= "done" then
			local col = UI.rgb(Artists.byId[t.artistId].color)
			for _, s in ipairs(t.shows) do
				local c = Countries.byId[s.countryId]
				if c and not seen[c.id] and not s.done then
					seen[c.id] = true
					cpart(World.pinFolder, "Pin", Vector3.new(0.18, 1.4, 0.18), CFrame.new(mapPos(c.lat, c.lon, 3.95)), col, Enum.Material.Neon)
					cpart(World.pinFolder, "PinHead", Vector3.new(0.5, 0.5, 0.5), CFrame.new(mapPos(c.lat, c.lon, 4.7)), col, Enum.Material.Neon).Shape = Enum.PartType.Ball
				end
			end
		end
	end
end

------------------------------------------------------------------ charts wall
local function buildChartsWall()
	local screen = World.root:FindFirstChild("ChartsScreen", true)
	if not screen then
		return
	end
	local g = New("SurfaceGui", { Name = "ChartsGui", Parent = screen, Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(1220, 620), LightInfluence = 0 })
	World.chartsGui = New("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 14, 26), BorderSizePixel = 0 })
end

local function refreshChartsWall(unlocked)
	local f = World.chartsGui
	if not f then
		return
	end
	f:ClearAllChildren()
	if not unlocked then
		UI.Label(f, "🔒  CHARTS", UI.px(0, 220), UI.px(1220, 90), { textSize = 72, font = UI.FontBlack, color = T.sub, alignX = Enum.TextXAlignment.Center })
		UI.Label(f, GS.UNLOCK_HINT.charts, UI.px(0, 320), UI.px(1220, 50), { textSize = 34, color = T.sub, alignX = Enum.TextXAlignment.Center })
		return
	end
	UI.Label(f, "TOP GROSSING TOURS", UI.px(36, 20), UI.px(900, 64), { textSize = 50, font = UI.FontBlack, color = T.gold })
	local rows, best = GS.chart(World.app.state)
	local shown = {}
	for i = 1, math.min(6, #rows) do
		table.insert(shown, rows[i])
	end
	if best and best > 6 then
		shown[6] = rows[best]
	end
	for i, r in ipairs(shown) do
		local y = 100 + (i - 1) * 84
		local row = New("Frame", { Parent = f, Position = UI.px(30, y), Size = UI.px(1160, 76), BackgroundColor3 = r.player and Color3.fromRGB(50, 44, 110) or Color3.fromRGB(24, 28, 44), BorderSizePixel = 0, UI.Corner(10) })
		UI.Label(row, "#" .. r.rank, UI.px(20, 0), UI.px(120, 76), { textSize = 40, font = UI.FontBlack, color = r.player and T.gold or T.sub })
		UI.Label(row, r.artist, UI.px(150, 4), UI.px(560, 40), { textSize = 34, font = UI.FontBlack })
		UI.Label(row, r.tour, UI.px(150, 42), UI.px(560, 30), { textSize = 24, color = T.sub })
		UI.Label(row, Util.moneyShort(r.gross), UI.px(760, 0), UI.px(380, 76), { textSize = 40, font = UI.FontBlack, color = r.player and T.good or T.text, alignX = Enum.TextXAlignment.Right })
	end
end

------------------------------------------------------------------ stations
local OPEN = {
	laptop = function(app)
		app:go("office")
	end,
	maptable = function(app)
		app:go("planner")
	end,
	meeting = function(app)
		app:go("artists")
	end,
	stagehall = function(app)
		app:go("stages")
	end,
	charts = function(app)
		app:go("charts")
	end,
}
World.OPEN = OPEN

function World.trigger(id)
	local app = World.app
	if app.mode ~= "world" or app.modalOpen then
		return
	end
	local un = GS.unlocks(app.state)
	if un[id] == false then
		app:toast("<b>Locked.</b> " .. (GS.UNLOCK_HINT[id] or ""), T.warn)
		return
	end
	if not (app.state.visited or {})[id] then
		app:act("visit", { station = id })
	end
	if OPEN[id] then
		OPEN[id](app)
	end
end

-- is the player sitting on a meeting room chair?
function World.inMeetingSeat()
	local h = hum()
	local seat = h and h.SeatPart
	return seat ~= nil and seat:GetAttribute("Meeting") == true
end

function World.refresh()
	local app = World.app
	if not app or not app.state or not World.root then
		return
	end
	local state = app.state
	local un = GS.unlocks(state)
	for id, info in pairs(Hub.STATIONS) do
		local open = un[id] ~= false
		local pr = World.prompts[id]
		if pr then
			pr.Enabled = open and (id ~= "meeting" or World.inMeetingSeat())
		end
		local mk = World.markers[id]
		if mk then
			mk.name.Text = (open and "" or "🔒  ") .. info.name
			mk.name.TextColor3 = open and T.text or T.sub
			mk.sub.Text = open and ((id == "meeting" and not World.inMeetingSeat()) and "Sit down to start a meeting" or info.sub) or (GS.UNLOCK_HINT[id] or "")
			mk.sub.TextColor3 = open and T.accent2 or T.warn
		end
	end
	-- the stage hall door rolls up once the hall is open
	local door = World.root:FindFirstChild("HallDoor", true)
	if door and door.PrimaryPart then
		local up = un.stagehall and 15 or 0
		if World.doorUp ~= up then
			World.doorUp = up
			door:PivotTo(CFrame.new(O + Vector3.new(39.9, 7 + up, 10)))
			for _, p in ipairs(door:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Slat" then
					p.CanCollide = not un.stagehall
				end
			end
		end
	end
	-- signs with the label name
	for _, d in ipairs(World.root:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "LabelSign" then
			local lbl = d:FindFirstChild("Text")
			if lbl then
				lbl.Text = string.upper(state.labelName)
			end
		end
	end
	World.target = GS.objective(state).target
	refreshChartsWall(un.charts)
	refreshPins()
end

------------------------------------------------------------------ start
function World.start(app)
	World.app = app
	Stage3D.setLighting("hub")
	World.root = workspace:WaitForChild("StarlightRecords", 20)
	local old = workspace:FindFirstChild("HubClient")
	if old then
		old:Destroy()
	end
	World.folder = New("Folder", { Name = "HubClient", Parent = workspace })
	if World.root then
		for _, d in ipairs(World.root:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				local id = d:GetAttribute("Station")
				if id then
					World.prompts[id] = d
				end
			end
		end
	end
	for id, info in pairs(Hub.STATIONS) do
		marker(id, info)
	end
	buildArrow()
	buildTableMap()
	if World.root then
		buildChartsWall()
	end
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("Station")
		if id then
			World.trigger(id)
		end
	end)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	app:act("enterWorld")
	World.freeze(false)
	World.refresh()
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		if app.mode == "world" then
			placeArrow(t)
			-- the meeting prompt only shows while sitting
			local pr = World.prompts.meeting
			if pr then
				local want = World.inMeetingSeat() and GS.unlocks(app.state).meeting
				if pr.Enabled ~= want then
					World.refresh()
				end
			end
		elseif World.arrow then
			placeArrow(t)
		end
	end)
end

return World
