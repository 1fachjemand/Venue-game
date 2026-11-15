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
local People = require(Root.Client.People)

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

-- the camera stays close: you are in the street, not above the city
World.MAX_ZOOM = 22
function World.setZoom(maxZoom)
	local player = Players.LocalPlayer
	player.CameraMinZoomDistance = 2
	player.CameraMaxZoomDistance = maxZoom or World.MAX_ZOOM
end

local function onCharacter(char)
	local h = char:WaitForChild("Humanoid", 10)
	if not h then
		return
	end
	World.setZoom()
	World.freeze(World.frozen)
	World.resetCamera()
	h.Seated:Connect(function(active)
		if not active then
			World.endMeeting()
		end
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
	local a = cpart(m, "ArmA", Vector3.new(0.8, 3.2, 0.8), CFrame.new(), T.gold, Enum.Material.SmoothPlastic)
	local b = cpart(m, "ArmB", Vector3.new(0.8, 3.2, 0.74), CFrame.new(), T.gold, Enum.Material.SmoothPlastic)
	local stem = cpart(m, "Stem", Vector3.new(0.68, 3.4, 0.68), CFrame.new(), T.gold, Enum.Material.SmoothPlastic)
	local target = New("Attachment", { Name = "BeamTarget", Parent = stem })
	World.arrow = { model = m, a = a, b = b, stem = stem, target = target }
	local beam = New("Beam", {
		Name = "GuideBeam",
		Parent = m,
		Attachment1 = target,
		Color = ColorSequence.new(T.gold, T.accent2),
		Transparency = NumberSequence.new(0.35, 0.7),
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
	local visible = target ~= nil and not World.frozen and World.app.mode == "world"
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
	return O + Vector3.new(-lon * MAP_S, y or 3.23, 6 + (lat - 11) * MAP_S)
end
World.mapPos = mapPos

local function buildTableMap()
	local f = New("Folder", { Name = "TableMap", Parent = World.folder })
	local deg = 360 / WorldMap.W
	for _, r in ipairs(WorldMap.land) do
		local row, col, w, h = r[1], r[2], r[3], r[4]
		local lon = -180 + (col + w / 2) * deg
		local lat = WorldMap.LAT_TOP - (row + h / 2) * deg
		cpart(f, "Land", Vector3.new(w * deg * MAP_S, 0.06, h * deg * MAP_S), CFrame.new(mapPos(lat, lon)), Color3.fromRGB(150, 206, 132), Enum.Material.SmoothPlastic)
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
					cpart(World.pinFolder, "Pin", Vector3.new(0.18, 1.4, 0.18), CFrame.new(mapPos(c.lat, c.lon, 3.96)), Color3.fromRGB(230, 230, 236), Enum.Material.Metal)
					cpart(World.pinFolder, "PinHead", Vector3.new(0.6, 0.6, 0.6), CFrame.new(mapPos(c.lat, c.lon, 4.75)), col, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Ball
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

------------------------------------------------------------------ posters of the artists (on walls, bus stop, billboard)
-- signed artists first (with "ON TOUR" when a tour runs), then the stars you can still sign
local FACES = { Back = Enum.NormalId.Back, Front = Enum.NormalId.Front, Left = Enum.NormalId.Left, Right = Enum.NormalId.Right }
function World.refreshPosters()
	local state = World.app.state
	local order = {}
	for _, ad in ipairs(Artists.list) do
		if state.artists[ad.id].signed then
			table.insert(order, ad)
		end
	end
	for _, ad in ipairs(Artists.list) do
		if not state.artists[ad.id].signed then
			table.insert(order, ad)
		end
	end
	local key = ""
	for _, ad in ipairs(order) do
		key = key .. ad.id .. (state.artists[ad.id].signed and "1" or "0") .. (GS.activeTour(state, ad.id) and "t" or "")
	end
	if World.posterKey == key then
		return
	end
	World.posterKey = key
	for _, p in ipairs(World.posters or {}) do
		local idx = p:GetAttribute("Poster")
		local ad = order[(idx - 1) % #order + 1]
		local old = p:FindFirstChild("PosterGui")
		if old then
			old:Destroy()
		end
		local g = New("SurfaceGui", { Name = "PosterGui", Parent = p, Face = FACES[p:GetAttribute("Face")] or Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(420, 600), LightInfluence = 0.3 })
		local col = UI.rgb(ad.color)
		local bg = New("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BorderSizePixel = 0, UI.New("UIGradient", { Color = ColorSequence.new(col, Color3.fromRGB(24, 22, 40)), Rotation = 90 }) })
		-- spotlight + a silhouette of the artist
		New("Frame", { Parent = bg, Position = UDim2.fromOffset(60, 40), Size = UDim2.fromOffset(300, 300), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0, UI.Corner(150) })
		New("Frame", { Parent = bg, Position = UDim2.fromOffset(165, 110), Size = UDim2.fromOffset(90, 90), BackgroundColor3 = Color3.fromRGB(26, 22, 40), BorderSizePixel = 0, UI.Corner(45) })
		New("Frame", { Parent = bg, Position = UDim2.fromOffset(130, 205), Size = UDim2.fromOffset(160, 190), BackgroundColor3 = Color3.fromRGB(26, 22, 40), BorderSizePixel = 0, UI.Corner(40) })
		New("Frame", { Parent = bg, Position = UDim2.fromOffset(90, 150), Size = UDim2.fromOffset(40, 140), Rotation = -25, BackgroundColor3 = Color3.fromRGB(26, 22, 40), BorderSizePixel = 0, UI.Corner(20) })
		New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(16, 410), Size = UDim2.fromOffset(388, 90), BackgroundTransparency = 1, Text = string.upper(ad.name), TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Font = UI.FontBlack })
		local signed = state.artists[ad.id].signed
		local onTour = GS.activeTour(state, ad.id) ~= nil
		local line = onTour and "ON TOUR NOW" or (signed and (ad.genre .. "  ·  " .. string.upper(state.labelName)) or (ad.genre .. "  ·  COMING SOON"))
		New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(16, 504), Size = UDim2.fromOffset(388, 40), BackgroundTransparency = 1, Text = line, TextScaled = true, TextColor3 = onTour and T.gold or Color3.fromRGB(230, 230, 240), Font = UI.FontBold })
		New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(16, 552), Size = UDim2.fromOffset(388, 30), BackgroundTransparency = 1, Text = "LIVE  ·  WORLD TOUR  ·  TICKETS SOON", TextScaled = true, TextColor3 = Color3.fromRGB(200, 200, 220), Font = UI.FontBold })
	end
end

------------------------------------------------------------------ people: staff at work, people in the street, at the cafe
local LOOK_TOPS = { { 240, 120, 100 }, { 110, 160, 230 }, { 250, 210, 90 }, { 120, 200, 170 }, { 236, 236, 240 }, { 150, 120, 220 }, { 60, 64, 80 } }
local HAIRS = { "short", "long", "bun", "pony", "afro", "buzz", "messy" }
local function randomLook(i)
	local rng = Random.new(i * 7919 + 13)
	return {
		skin = rng:NextInteger(1, #People.SKINS),
		hair = HAIRS[rng:NextInteger(1, #HAIRS)],
		top = LOOK_TOPS[rng:NextInteger(1, #LOOK_TOPS)],
		pants = ({ { 40, 50, 80 }, { 50, 50, 56 }, { 170, 150, 120 } })[rng:NextInteger(1, 3)],
		shoes = { 30, 30, 34 },
	}
end

local function buildPeople()
	local f = New("Folder", { Name = "People", Parent = World.folder })
	World.npcs = {}
	local n = 0
	local function add(kind, data)
		n = n + 1
		local look = randomLook(n)
		local fig = People.new(f, UI.rgb(look.top), 1, "dancer", n, look)
		table.insert(World.npcs, { fig = fig, kind = kind, data = data, ph = n * 1.7, seg = 1, t = 0 })
	end
	for _, st in ipairs(Hub.STAFF) do
		add("sit", { pos = st.pos, yaw = st.yaw, work = st.desk })
	end
	for _, st in ipairs(Hub.SITTERS) do
		add("sit", { pos = st.pos, yaw = st.yaw })
	end
	for i, path in ipairs(Hub.WALKS) do
		add("walk", { path = path, speed = 6 + (i % 3) * 1.5 })
		if i <= 4 then
			add("walk", { path = path, speed = 5 + (i % 2) * 2, offset = 0.5 })
		end
	end
end

local function pathLength(path)
	local len = 0
	for i = 2, #path do
		len = len + (path[i] - path[i - 1]).Magnitude
	end
	return len
end

local function animatePeople(t)
	for _, npc in ipairs(World.npcs or {}) do
		local d = npc.data
		if npc.kind == "sit" then
			-- sitting; office staff type on the keyboard
			npc.fig:update(O + d.pos, d.yaw, { t = t + npc.ph, beat = 0, energy = 0, walking = false, move = "piano" })
		else
			local path = d.path
			local len = d.len or pathLength(path)
			d.len = len
			-- walk the path forward and back
			local dist = ((t * d.speed) + (d.offset or 0) * len) % (len * 2)
			local back = dist > len
			if back then
				dist = len * 2 - dist
			end
			local pos, dir = path[1], path[2] - path[1]
			local acc = 0
			for i = 2, #path do
				local segLen = (path[i] - path[i - 1]).Magnitude
				if acc + segLen >= dist then
					local f = (dist - acc) / math.max(0.01, segLen)
					pos = path[i - 1]:Lerp(path[i], f)
					dir = path[i] - path[i - 1]
					break
				end
				acc = acc + segLen
			end
			if back then
				dir = -dir
			end
			npc.fig:update(O + pos, math.atan2(dir.X, dir.Z), { t = t + npc.ph, beat = 0, energy = 0, walking = true })
		end
	end
end

------------------------------------------------------------------ stations
local OPEN = {
	laptop = function(app)
		app:openStation("laptop", "office")
	end,
	maptable = function(app)
		app:openStation("maptable", "planner")
	end,
	meeting = function()
		World.startMeeting()
	end,
	stagehall = function(app)
		app:openStation("stagehall", "stages")
	end,
	charts = function(app)
		app:openStation("charts", "charts")
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
	if World.override == id then
		World.override = nil
	end
	if OPEN[id] then
		OPEN[id](app)
	end
end

-- send the player to a station (from a button somewhere else): the arrow points there
function World.guide(id)
	World.override = id
	World.refresh()
end

------------------------------------------------------------------ the meeting: sit down, the board shows your artists and new talent
local BOARD_W, BOARD_H = 1600, 710
local function boardCard(parent, ad, state, signed, y, x)
	local app = World.app
	local a = state.artists[ad.id]
	local total = Util.totalFans(a.fans)
	local card = New("Frame", { Parent = parent, Position = UI.px(x, y), Size = UI.px(372, 270), BackgroundColor3 = T.panel2, BorderSizePixel = 0, UI.Corner(14) })
	New("Frame", { Parent = card, Size = UI.px(372, 8), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0, UI.Corner(14) })
	People.preview(card, ad.look, UI.rgb(ad.color), UI.px(10, 16), UI.px(110, 170), Color3.fromRGB(32, 36, 54))
	UI.Label(card, ad.name, UI.px(130, 16), UI.px(236, 32), { textSize = 26, font = UI.FontBlack })
	UI.Label(card, ad.genre .. (ad.members > 1 and ("  ·  " .. ad.members .. " members") or "  ·  solo"), UI.px(130, 50), UI.px(236, 22), { textSize = 16, color = UI.rgb(ad.color), font = UI.FontBold })
	local function stat(yy, label, frac, txt, col)
		UI.Label(card, label, UI.px(130, yy), UI.px(60, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Bar(card, UI.px(190, yy + 7), UI.px(110, 9), math.clamp(frac, 0, 1), col)
		UI.Label(card, txt, UI.px(304, yy), UI.px(60, 22), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	end
	stat(82, "FANS", math.log10(1 + total / 10000) / 4, Util.short(total), T.good)
	stat(110, "SKILL", ad.skill / 100, tostring(ad.skill), T.accent2)
	stat(138, "HYPE", a.hype / 100, tostring(math.floor(a.hype)), T.accent)
	if signed then
		local tour = GS.activeTour(state, ad.id)
		UI.Label(card, tour and ("ON TOUR: " .. tour.name) or "Ready for a tour", UI.px(130, 168), UI.px(236, 22), { textSize = 15, color = tour and T.gold or T.good, font = UI.FontBold })
		UI.Label(card, ad.bio, UI.px(14, 196), UI.px(346, 66), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	else
		local lvl = GS.level(state)
		local locked = ad.level > lvl
		local afford = state.money >= ad.signCost
		UI.Label(card, "Costs " .. Util.money(ad.signCost), UI.px(130, 168), UI.px(236, 22), { textSize = 16, color = T.gold, font = UI.FontBold })
		local txt = locked and ("LOCKED · needs level " .. ad.level) or (afford and "SIGN" or "NOT ENOUGH MONEY")
		UI.Button(card, txt, UI.px(14, 204), UI.px(344, 52), { color = (not locked and afford) and T.good or T.panel3, disabled = locked or not afford, textSize = 18 }, function()
			app:confirm("Sign " .. ad.name .. "?", "Signing costs <b>" .. Util.money(ad.signCost) .. "</b>. Then you can book their tours at the world map table.", function()
				local ok, msg, data = app:act("sign", { artistId = ad.id })
				app:toast(msg or "", ok and T.good or T.bad)
				for _, id in ipairs((data and data.achievements) or {}) do
					local Achievements = require(Root.Data.Achievements)
					app:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name, T.accent, 8)
				end
				World.drawBoard()
				app:refreshHud()
			end)
		end)
	end
end

function World.drawBoard()
	local g = World.boardGui
	if not g then
		return
	end
	g:ClearAllChildren()
	local state = World.app.state
	local bg = New("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 18, 30), BorderSizePixel = 0 })
	UI.Label(bg, "MEETING  ·  " .. string.upper(state.labelName), UI.px(30, 14), UI.px(1000, 44), { textSize = 34, font = UI.FontBlack, color = T.text })
	UI.Label(bg, "Stand up (SPACE) to end the meeting", UI.px(1040, 22), UI.px(530, 30), { textSize = 18, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local cols = { { "YOUR ROSTER", GS.signedArtists(state), true, 30 }, { "AVAILABLE TALENT", GS.unsignedArtists(state), false, 818 } }
	for _, c in ipairs(cols) do
		UI.Label(bg, c[1] .. "  (" .. #c[2] .. ")", UI.px(c[4], 70), UI.px(700, 30), { textSize = 22, font = UI.FontBlack, color = c[3] and T.accent2 or T.gold })
		local sc = UI.Scroll(bg, UI.px(c[4] - 6, 106), UI.px(770, 590))
		sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		local holder = New("Frame", { Parent = sc, Size = UI.px(760, math.ceil(#c[2] / 2) * 284), BackgroundTransparency = 1 })
		for k, ad in ipairs(c[2]) do
			boardCard(holder, ad, state, c[3], math.floor((k - 1) / 2) * 284, ((k - 1) % 2) * 384)
		end
		if #c[2] == 0 then
			UI.Label(sc, c[3] and "Nobody yet." or "You signed everyone. What a label!", UI.px(10, 10), UI.px(700, 40), { textSize = 20, color = T.sub })
		end
	end
end

function World.startMeeting()
	local app = World.app
	if World.meeting or not World.inMeetingSeat() then
		return
	end
	local board = World.root and World.root:FindFirstChild("Board", true)
	if not board then
		return
	end
	World.meeting = true
	app.mode = "meeting"
	pcall(function()
		ProximityPromptService.Enabled = false
	end)
	-- the board shows its own screen (buttons work because it lives in the PlayerGui)
	World.boardGui = New("SurfaceGui", { Name = "MeetingBoard", Parent = Players.LocalPlayer:WaitForChild("PlayerGui"), Adornee = board, Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(BOARD_W, BOARD_H), LightInfluence = 0, ResetOnSpawn = false })
	World.drawBoard()
	-- look at the board from the table
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(board.Position + Vector3.new(0, -0.4, 30), board.Position + Vector3.new(0, -0.6, 0))
	cam.FieldOfView = 50
	app:refreshHud()
	if not (app.state.visited or {}).meeting then
		app:act("visit", { station = "meeting" })
	end
end

function World.endMeeting()
	if not World.meeting then
		return
	end
	World.meeting = false
	if World.boardGui then
		World.boardGui:Destroy()
		World.boardGui = nil
	end
	local app = World.app
	app.mode = "world"
	pcall(function()
		ProximityPromptService.Enabled = true
	end)
	World.resetCamera()
	World.refresh()
	app:refreshHud()
	app:processLiveQueue()
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
			door:PivotTo(CFrame.new(O + Vector3.new(40.18, 7.2 + up, 10)))
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
	World.target = World.override or GS.objective(state).target
	refreshChartsWall(un.charts)
	refreshPins()
	World.refreshPosters()
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
	buildPeople()
	World.posters = {}
	if World.root then
		for _, d in ipairs(World.root:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("Poster") then
				table.insert(World.posters, d)
			end
		end
	end
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
	local peopleT = 0
	RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		if app.mode == "world" then
			placeArrow(t)
			peopleT = peopleT + dt
			if peopleT > 1 / 30 then
				peopleT = 0
				animatePeople(t)
			end
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
