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
local Config = require(Root.Config)

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
	if not char.Parent then
		return -- an old character that was removed (back from the main menu)
	end
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
		UI.Label(f, "LOCKED  CHARTS", UI.px(0, 220), UI.px(1220, 90), { textSize = 72, font = UI.FontBlack, color = T.sub, alignX = Enum.TextXAlignment.Center })
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
-- signed artists first (with "ON TOUR" when a tour runs), then the stars you can still sign.
-- Each poster shows the artist as a 3D picture (ViewportFrame: the SurfaceGui lives in the PlayerGui,
-- Roblox does not draw ViewportFrames on SurfaceGuis in the Workspace) and has its own layout.
local FACES = { Back = Enum.NormalId.Back, Front = Enum.NormalId.Front, Left = Enum.NormalId.Left, Right = Enum.NormalId.Right }
local GENRE_FONT = {
	Pop = Enum.Font.FredokaOne, ["K-Pop"] = Enum.Font.FredokaOne, Rock = Enum.Font.Bangers, Metal = Enum.Font.Fantasy,
	EDM = Enum.Font.Arcade, Indie = Enum.Font.Antique, Country = Enum.Font.Antique, ["R&B"] = Enum.Font.Garamond,
	["Hip-Hop"] = Enum.Font.GothamBlack, Latin = Enum.Font.Bangers,
}
local POSES = { "point", "wave", "micout", "dance", "jump", "idle" }
local function posterPicture(parent, ad, pos, size, idx, bg)
	local vp = New("ViewportFrame", { Parent = parent, Position = pos, Size = size, BackgroundColor3 = bg or Color3.new(0, 0, 0), BackgroundTransparency = bg and 0 or 1, BorderSizePixel = 0, Ambient = Color3.fromRGB(200, 196, 210), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.9) })
	local col = UI.rgb(ad.color)
	local role = (ad.genre == "Rock" or ad.genre == "Metal" or ad.genre == "Country") and "guitar" or "lead"
	local fig = People.new(vp, col, 1, role, idx * 3 + 1, ad.look)
	fig:update(Vector3.new(0, 0, 0), math.rad(((idx % 2 == 0) and 1 or -1) * 22), { t = idx * 0.7, beat = 0.3, energy = 0.6, walking = false, move = POSES[idx % #POSES + 1] })
	-- bands: two more members behind
	if ad.members > 1 then
		for k = 1, math.min(2, ad.members - 1) do
			local m = People.new(vp, col, 0.95, (k == 1) and "bass" or "dancer", idx * 7 + k, People.bandLook(ad, k, Artists.BAND_STYLE))
			m:update(Vector3.new((k == 1) and -2.6 or 2.6, 0, -2), math.rad((k == 1) and 20 or -20), { t = 0, beat = 0, energy = 0.4, walking = false, move = "idle" })
		end
	end
	local cam = New("Camera", { FieldOfView = 34, Parent = vp })
	local close = idx % 3 == 1 -- every third poster is a close-up
	cam.CFrame = close and CFrame.lookAt(Vector3.new(0, 6.6, 7.5), Vector3.new(0, 5.6, 0)) or CFrame.lookAt(Vector3.new(0, 4.4, 13), Vector3.new(0, 3.4, 0))
	vp.CurrentCamera = cam
	return vp
end

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
	local key = state.labelName
	for _, ad in ipairs(order) do
		key = key .. ad.id .. (state.artists[ad.id].signed and "1" or "0") .. (GS.activeTour(state, ad.id) and "t" or "")
	end
	if World.posterKey == key then
		return
	end
	World.posterKey = key
	for _, g in ipairs(World.posterGuis or {}) do
		g:Destroy()
	end
	World.posterGuis = {}
	local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for _, p in ipairs(World.posters or {}) do
		local idx = p:GetAttribute("Poster")
		local ad = order[(idx - 1) % #order + 1]
		local wide = math.max(p.Size.X, p.Size.Z) > p.Size.Y * 1.2
		local g = New("SurfaceGui", { Name = "Poster", Parent = pg, Adornee = p, Face = FACES[p:GetAttribute("Face")] or Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = wide and Vector2.new(840, 600) or Vector2.new(420, 600), LightInfluence = 0.2, ResetOnSpawn = false })
		table.insert(World.posterGuis, g)
		local W = wide and 840 or 420
		local col = UI.rgb(ad.color)
		local dark = Color3.fromRGB(22, 20, 36)
		local font = GENRE_FONT[ad.genre] or UI.FontBlack
		local signed = state.artists[ad.id].signed
		local onTour = GS.activeTour(state, ad.id) ~= nil
		local layout = idx % 4
		local bg = New("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = col, BorderSizePixel = 0, ClipsDescendants = true })
		local line = onTour and "ON TOUR NOW" or (signed and string.upper(state.labelName) or "COMING SOON")
		if wide then
			-- billboard: picture left, big name right
			New("UIGradient", { Parent = bg, Color = ColorSequence.new(col, dark), Rotation = 0 })
			posterPicture(bg, ad, UDim2.fromOffset(0, 0), UDim2.fromOffset(420, 600), idx)
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(420, 120), Size = UDim2.fromOffset(400, 160), BackgroundTransparency = 1, Text = string.upper(ad.name), TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Font = font })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(420, 300), Size = UDim2.fromOffset(400, 60), BackgroundTransparency = 1, Text = onTour and "WORLD TOUR | ON SALE NOW" or "NEW ALBUM OUT NOW", TextScaled = true, TextColor3 = T.gold, Font = UI.FontBlack })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(420, 380), Size = UDim2.fromOffset(400, 40), BackgroundTransparency = 1, Text = ad.genre .. "  |  " .. line, TextScaled = true, TextColor3 = Color3.fromRGB(230, 230, 240), Font = UI.FontBold })
		elseif layout == 0 then
			-- tour poster: gradient, the artist full figure, name on top, dates below
			New("UIGradient", { Parent = bg, Color = ColorSequence.new(col, dark), Rotation = 90 })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(392, 80), BackgroundTransparency = 1, Text = string.upper(ad.name), TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Font = font })
			posterPicture(bg, ad, UDim2.fromOffset(10, 96), UDim2.fromOffset(400, 380), idx)
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(14, 486), Size = UDim2.fromOffset(392, 46), BackgroundTransparency = 1, Text = onTour and "WORLD TOUR | ON SALE NOW" or "LIVE " .. (Config.START_YEAR + 1), TextScaled = true, TextColor3 = T.gold, Font = UI.FontBlack })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(14, 540), Size = UDim2.fromOffset(392, 34), BackgroundTransparency = 1, Text = "LONDON | PARIS | BERLIN | NEW YORK", TextScaled = true, TextColor3 = Color3.fromRGB(230, 230, 240), Font = UI.FontBold })
		elseif layout == 1 then
			-- album cover: a big sun behind a close-up, title at the bottom
			bg.BackgroundColor3 = Color3.fromRGB(246, 236, 220)
			New("Frame", { Parent = bg, Position = UDim2.fromOffset(40, 60), Size = UDim2.fromOffset(340, 340), BackgroundColor3 = col, BorderSizePixel = 0, UI.Corner(170) })
			posterPicture(bg, ad, UDim2.fromOffset(10, 30), UDim2.fromOffset(400, 420), idx)
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(20, 456), Size = UDim2.fromOffset(380, 70), BackgroundTransparency = 1, Text = ad.name, TextScaled = true, TextColor3 = dark, Font = font })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(20, 530), Size = UDim2.fromOffset(380, 40), BackgroundTransparency = 1, Text = "THE NEW ALBUM | " .. line, TextScaled = true, TextColor3 = col:Lerp(dark, 0.4), Font = UI.FontBold })
		elseif layout == 2 then
			-- festival / club night: dark with stripes
			bg.BackgroundColor3 = dark
			-- stripes stay inside the poster (rotated frames are not clipped in Roblox)
			for k = 0, 4 do
				New("Frame", { Parent = bg, Position = UDim2.fromOffset(18 + k * 84, 0), Size = UDim2.fromOffset(34, 600), BackgroundColor3 = col, BackgroundTransparency = 0.6 + k * 0.06, BorderSizePixel = 0 })
			end
			posterPicture(bg, ad, UDim2.fromOffset(10, 20), UDim2.fromOffset(400, 400), idx)
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(14, 420), Size = UDim2.fromOffset(392, 90), BackgroundTransparency = 1, Text = string.upper(ad.name), TextScaled = true, TextColor3 = col:Lerp(Color3.new(1, 1, 1), 0.4), Font = font })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(14, 516), Size = UDim2.fromOffset(392, 40), BackgroundTransparency = 1, Text = ad.genre .. " NIGHT | " .. line, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Font = UI.FontBold })
		else
			-- minimal: white with a coloured frame
			bg.BackgroundColor3 = Color3.new(1, 1, 1)
			New("Frame", { Parent = bg, Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(380, 400), BackgroundColor3 = col, BorderSizePixel = 0 })
			posterPicture(bg, ad, UDim2.fromOffset(20, 20), UDim2.fromOffset(380, 400), idx)
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(20, 436), Size = UDim2.fromOffset(380, 80), BackgroundTransparency = 1, Text = ad.name, TextScaled = true, TextColor3 = Color3.new(0.1, 0.1, 0.12), Font = font })
			New("TextLabel", { Parent = bg, Position = UDim2.fromOffset(20, 524), Size = UDim2.fromOffset(380, 40), BackgroundTransparency = 1, Text = line, TextScaled = true, TextColor3 = col, Font = UI.FontBlack })
		end
	end
end

------------------------------------------------------------------ people: staff at work, people in the street, at the cafe
local TOPS = { { 240, 120, 100 }, { 110, 160, 230 }, { 250, 210, 90 }, { 120, 200, 170 }, { 236, 236, 240 }, { 150, 120, 220 }, { 60, 64, 80 }, { 200, 60, 70 }, { 80, 140, 90 }, { 240, 170, 200 }, { 30, 30, 34 }, { 170, 120, 80 } }
local PANTS = { { 40, 50, 80 }, { 50, 50, 56 }, { 170, 150, 120 }, { 30, 30, 34 }, { 90, 110, 150 }, { 120, 70, 60 }, { 220, 220, 214 } }
local HAIRS = { "short", "long", "bun", "pony", "afro", "buzz", "messy", "pigtails", "mohawk" }
local HAIR_COL = { { 30, 24, 20 }, { 90, 60, 30 }, { 230, 200, 120 }, { 200, 60, 60 }, { 180, 120, 255 }, { 240, 240, 250 }, { 150, 90, 50 }, { 60, 40, 30 } }
local ACCS = { "none", "none", "none", "cap", "beanie", "sunglasses", "headphones", "earrings", "chain", "backpack", "backpack" }
local function randomLook(i)
	local rng = Random.new(i * 7919 + 13)
	local function pick(list)
		return list[rng:NextInteger(1, #list)]
	end
	local look = {
		skin = rng:NextInteger(1, #People.SKINS),
		hair = pick(HAIRS),
		hairColor = pick(HAIR_COL),
		top = pick(TOPS),
		pants = pick(PANTS),
		shoes = pick({ { 30, 30, 34 }, { 240, 240, 240 }, { 120, 70, 40 }, { 200, 50, 60 } }),
		acc = pick(ACCS),
		bag = pick(TOPS),
	}
	if rng:NextNumber() < 0.3 then
		look.jacket = pick({ { 40, 40, 46 }, { 60, 80, 130 }, { 120, 90, 60 }, { 150, 40, 50 } })
	end
	return look
end

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- a sitting person, built once (thighs on the seat, knees bent, feet on the floor). yaw = the way they face
local function seatedFigure(f, data, look, n)
	local cf = CFrame.new(O + data.pos) * CFrame.Angles(0, data.yaw, 0)
	local seatY = data.seatY or 2.3
	local hipY = seatY + 0.4
	local skin = People.SKINS[look.skin]
	local m = New("Model", { Name = "Sitter", Parent = f })
	local function p(name, size, off, color, material, shape)
		local pp = cpart(m, name, size, cf * off, color, material)
		if shape then
			pp.Shape = shape
		end
		return pp
	end
	local pants, top = c3(look.pants), c3(look.top)
	for _, sx in ipairs({ -0.48, 0.48 }) do
		p("Thigh", Vector3.new(0.86, 0.8, 1.9), CFrame.new(sx, hipY, 0.65), pants)
		p("Shin", Vector3.new(0.8, hipY - 0.35, 0.8), CFrame.new(sx, (hipY - 0.35) / 2 + 0.3, 1.18), pants)
		p("Shoe", Vector3.new(0.9, 0.32, 1.1), CFrame.new(sx, 0.16, 1.32), c3(look.shoes))
	end
	local torsoY = hipY + 0.4 + 1
	p("Torso", Vector3.new(2, 2, 1), CFrame.new(0, torsoY, -0.3), top)
	local armCol = look.jacket and c3(look.jacket) or top
	for _, sx in ipairs({ -1.43, 1.43 }) do
		if data.work then
			-- typing: forearms forward on the desk
			p("Arm", Vector3.new(0.8, 2, 0.8), CFrame.new(sx * 0.92, torsoY + 0.7, -0.3) * CFrame.Angles(math.rad(-75), 0, 0) * CFrame.new(0, -1, 0), armCol)
		else
			p("Arm", Vector3.new(0.8, 2, 0.8), CFrame.new(sx, torsoY + 0.1, -0.2) * CFrame.Angles(math.rad(-25), 0, 0), armCol)
		end
	end
	local headCF = CFrame.new(0, torsoY + 1.6, -0.3)
	p("Head", Vector3.new(1.2, 1.2, 1.2), headCF, skin)
	p("Eye", Vector3.new(0.18, 0.22, 0.05), headCF * CFrame.new(-0.25, 0.1, 0.61), Color3.new(0, 0, 0))
	p("Eye", Vector3.new(0.18, 0.22, 0.05), headCF * CFrame.new(0.25, 0.1, 0.61), Color3.new(0, 0, 0))
	local hairC = c3(look.hairColor)
	if look.acc == "cap" then
		p("Cap", Vector3.new(1.36, 0.36, 1.36), headCF * CFrame.new(0, 0.72, 0), top)
		p("CapBrim", Vector3.new(1.2, 0.1, 0.7), headCF * CFrame.new(0, 0.58, 0.85), top)
	elseif look.acc == "beanie" then
		p("Beanie", Vector3.new(1.38, 0.6, 1.38), headCF * CFrame.new(0, 0.72, 0), c3(look.bag), Enum.Material.Fabric)
	elseif look.hair == "afro" then
		p("Afro", Vector3.new(1.7, 0.78, 1.6), headCF * CFrame.new(0, 0.74, -0.1), hairC)
		p("Afro", Vector3.new(1.36, 0.36, 1.3), headCF * CFrame.new(0, 1.28, -0.12), hairC)
		p("Afro", Vector3.new(0.3, 1.0, 1.4), headCF * CFrame.new(-0.76, 0.25, -0.12), hairC)
		p("Afro", Vector3.new(0.3, 1.0, 1.4), headCF * CFrame.new(0.76, 0.25, -0.12), hairC)
		p("Afro", Vector3.new(1.6, 1.1, 0.35), headCF * CFrame.new(0, 0.2, -0.8), hairC)
	elseif look.hair ~= "buzz" then
		p("Hair", Vector3.new(1.3, 0.45, 1.3), headCF * CFrame.new(0, 0.7, -0.05), hairC)
		if look.hair == "long" or look.hair == "pigtails" then
			p("HairBack", Vector3.new(1.26, 1.6, 0.36), headCF * CFrame.new(0, -0.15, -0.6), hairC)
		elseif look.hair == "bun" then
			p("Bun", Vector3.new(0.72, 0.5, 0.72), headCF * CFrame.new(0, 1.05, -0.3) * CFrame.Angles(0, math.rad(45), 0), hairC)
			p("Bun", Vector3.new(0.5, 0.36, 0.5), headCF * CFrame.new(0, 1.36, -0.3), hairC)
		end
	end
	if look.acc == "sunglasses" then
		for _, sx in ipairs({ -0.25, 0.25 }) do
			p("ShadesLens", Vector3.new(0.38, 0.26, 0.05), headCF * CFrame.new(sx, 0.1, 0.625), Color3.fromRGB(40, 50, 70), Enum.Material.Glass)
			p("ShadesArm", Vector3.new(0.04, 0.05, 0.62), headCF * CFrame.new(sx * 2.48, 0.2, 0.32), Color3.fromRGB(20, 20, 24))
		end
		p("ShadesTop", Vector3.new(0.9, 0.05, 0.05), headCF * CFrame.new(0, 0.235, 0.628), Color3.fromRGB(20, 20, 24))
	end
	local _ = n
	return m
end

local function pathLength(path)
	local len = 0
	for i = 2, #path do
		len = len + (path[i] - path[i - 1]).Magnitude
	end
	return len
end

-- a point at distance `dist` along a path (and the direction there)
local function alongPath(path, dist)
	for i = 2, #path do
		local segLen = (path[i] - path[i - 1]).Magnitude
		if dist <= segLen or i == #path then
			local f = math.clamp(dist / math.max(0.01, segLen), 0, 1)
			return path[i - 1]:Lerp(path[i], f), path[i] - path[i - 1]
		end
		dist = dist - segLen
	end
	return path[#path], path[#path] - path[#path - 1]
end
World.alongPath = alongPath

local streetTrip = Hub.streetTrip

local function buildPeople()
	local f = New("Folder", { Name = "People", Parent = World.folder })
	World.npcs = {}
	local n = 0
	for _, st in ipairs(Hub.STAFF) do
		n = n + 1
		seatedFigure(f, { pos = st.pos, yaw = st.yaw, seatY = st.seatY, work = st.desk ~= nil }, randomLook(n), n)
	end
	for _, st in ipairs(Hub.SITTERS) do
		n = n + 1
		seatedFigure(f, st, randomLook(n), n)
	end
	local rng = Random.new(77)
	-- indoor: walk to the coffee bar / the arcade, wait there, walk back, wait
	for _, path in ipairs(Hub.WALKS) do
		n = n + 1
		local look = randomLook(n)
		table.insert(World.npcs, { fig = People.new(f, c3(look.top), 1, "dancer", n, look), kind = "loop", path = path, len = pathLength(path), speed = 4.5, pause = 4, t = rng:NextNumber(0, 10), ph = n * 1.7 })
	end
	-- street: from door to door
	for k = 1, 14 do
		n = n + 1
		local look = randomLook(n)
		local npc = { fig = People.new(f, c3(look.top), 1, "dancer", n, look), kind = "street", speed = 4.6 + rng:NextNumber() * 1.8, ph = n * 1.7, rng = Random.new(n * 13) }
		npc.door = Hub.DOORS[(k % #Hub.DOORS) + 1]
		npc.wait = rng:NextNumber(0, 12) -- some start inside
		table.insert(World.npcs, npc)
	end
end

local function animatePeople(t, dt)
	World.crossing = false
	for _, npc in ipairs(World.npcs or {}) do
		if npc.kind == "loop" then
			-- there and back with a pause at both ends
			npc.t = npc.t + dt
			local walk = npc.len / npc.speed
			local cycle = (walk + npc.pause) * 2
			local u = npc.t % cycle
			local dist, dirSign, moving
			if u < walk then
				dist, dirSign, moving = u * npc.speed, 1, true
			elseif u < walk + npc.pause then
				dist, dirSign, moving = npc.len, 1, false
			elseif u < walk * 2 + npc.pause then
				dist, dirSign, moving = npc.len - (u - walk - npc.pause) * npc.speed, -1, true
			else
				dist, dirSign, moving = 0, -1, false
			end
			local pos, dir = alongPath(npc.path, dist)
			dir = dir * dirSign
			npc.fig:update(O + pos, math.atan2(dir.X, dir.Z), { t = t + npc.ph, beat = 0, energy = 0, walking = moving, move = "idle" })
		else
			if npc.wait > 0 then
				-- inside a shop
				npc.wait = npc.wait - dt
				if npc.visible ~= false then
					npc.visible = false
					npc.fig:setVisible(false)
				end
				if npc.wait <= 0 then
					local to = npc.door
					while to == npc.door do
						to = Hub.DOORS[npc.rng:NextInteger(1, #Hub.DOORS)]
					end
					npc.path = streetTrip(npc.door, to)
					npc.len = pathLength(npc.path)
					npc.dist = 0
					npc.door = to
				end
			else
				if npc.visible == false then
					npc.visible = true
					npc.fig:setVisible(true)
				end
				npc.dist = npc.dist + dt * npc.speed
				local pos, dir = alongPath(npc.path, npc.dist)
				npc.fig:update(O + pos, math.atan2(dir.X, dir.Z), { t = t + npc.ph, beat = 0, energy = 0, walking = true })
				if pos.Z > 62 and pos.Z < 90 then
					World.crossing = true
				end
				if npc.dist >= npc.len then
					npc.wait = npc.rng:NextNumber(4, 14)
				end
			end
		end
	end
end

------------------------------------------------------------------ traffic: cars, city buses and tour buses drive along the street and around both bends
local ST = Hub.STREET
-- the lane as a path: down the side street, around the bend, along the straight, around the other bend, away
local function lanePath(z, eastbound)
	local pts = {}
	local rw, re = ST.cw.Z - z, ST.ce.Z - z
	table.insert(pts, Vector3.new(ST.cw.X - rw, -0.5, ST.cw.Z + 180))
	for k = 0, 12 do
		local a = (math.pi / 2) * (1 - k / 12)
		table.insert(pts, Vector3.new(ST.cw.X - math.sin(a) * rw, -0.5, ST.cw.Z - math.cos(a) * rw))
	end
	for k = 0, 12 do
		local a = (math.pi / 2) * (k / 12)
		table.insert(pts, Vector3.new(ST.ce.X + math.sin(a) * re, -0.5, ST.ce.Z - math.cos(a) * re))
	end
	table.insert(pts, Vector3.new(ST.ce.X + re, -0.5, ST.ce.Z + 180))
	if not eastbound then
		local rev = {}
		for i = #pts, 1, -1 do
			table.insert(rev, pts[i])
		end
		pts = rev
	end
	return pts
end

local function vehicle(f, kind, color, label)
	local m = New("Model", { Name = "Vehicle", Parent = f })
	local parts = {}
	local function p(name, size, off, col, mat, shape)
		local pp = cpart(m, name, size, CFrame.new(), col, mat)
		if shape then
			pp.Shape = shape
		end
		table.insert(parts, { pp, off })
		return pp
	end
	local L = (kind == "bus" or kind == "tourbus") and 34 or ((kind == "van") and 15 or 13)
	local Hh = (kind == "bus" or kind == "tourbus") and 10 or ((kind == "van") and 6.5 or 3)
	-- the vehicle drives along its local -Z (LookVector)
	p("Body", Vector3.new(6.2, Hh, L), CFrame.new(0, 1.2 + Hh / 2, 0), color)
	if kind == "car" or kind == "taxi" then
		p("Cabin", Vector3.new(5.6, 2.3, 7), CFrame.new(0, 1.2 + Hh + 1.15, 0.6), color)
		p("Glass", Vector3.new(5.7, 1.7, 7.1), CFrame.new(0, 1.2 + Hh + 1.2, 0.6), Color3.fromRGB(120, 150, 175), Enum.Material.Glass)
		if kind == "taxi" then
			p("TaxiSign", Vector3.new(1.6, 0.6, 0.8), CFrame.new(0, 1.2 + Hh + 2.6, 0.6), Color3.fromRGB(255, 240, 160))
		end
	else
		p("WindowBand", Vector3.new(6.3, 2.6, L - 3), CFrame.new(0, 1.2 + Hh * 0.68, 0.5), Color3.fromRGB(70, 90, 120), Enum.Material.Glass)
		p("Windshield", Vector3.new(5.6, Hh * 0.45, 0.1), CFrame.new(0, 1.2 + Hh * 0.68, -L / 2 - 0.05), Color3.fromRGB(110, 140, 170), Enum.Material.Glass)
	end
	for _, z in ipairs({ -L / 2 + 2.6, L / 2 - 2.6 }) do
		for _, x in ipairs({ -3.1, 3.1 }) do
			p("Wheel", Vector3.new(1, 2.6, 2.6), CFrame.new(x, 1.3, z) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(26, 26, 30), nil, Enum.PartType.Cylinder)
		end
	end
	p("HeadLight", Vector3.new(1.2, 0.6, 0.1), CFrame.new(-2.2, 2.4, -L / 2 - 0.06), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
	p("HeadLight", Vector3.new(1.2, 0.6, 0.1), CFrame.new(2.2, 2.4, -L / 2 - 0.06), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
	p("TailLight", Vector3.new(1.2, 0.6, 0.1), CFrame.new(-2.2, 2.4, L / 2 + 0.06), Color3.fromRGB(220, 30, 30))
	p("TailLight", Vector3.new(1.2, 0.6, 0.1), CFrame.new(2.2, 2.4, L / 2 + 0.06), Color3.fromRGB(220, 30, 30))
	if label then
		for _, side in ipairs({ -1, 1 }) do
			local sp = p("Label", Vector3.new(0.1, 1.8, L - 8), CFrame.new(side * 3.16, 1.2 + Hh * 0.28, 0), Color3.new(1, 1, 1))
			local g = New("SurfaceGui", { Parent = sp, Face = (side < 0) and Enum.NormalId.Left or Enum.NormalId.Right, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0.3 })
			New("TextLabel", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label, TextScaled = true, Font = UI.FontBlack, TextColor3 = (kind == "tourbus") and color or Color3.fromRGB(30, 60, 140) })
		end
	end
	return { model = m, parts = parts, len = L }
end

local function buildTraffic()
	local f = New("Folder", { Name = "Traffic", Parent = World.folder })
	World.traffic = {}
	-- one queue per lane: every vehicle of a lane drives at the same speed with a fixed gap, so nobody
	-- drives through another; a lane waits in front of the zebra crossing while people cross
	local lanes = {
		{ path = lanePath(ST.laneEast, true), z = ST.laneEast, east = true, fleet = { "car", "bus", "taxi", "car" } },
		{ path = lanePath(ST.laneWest, false), z = ST.laneWest, east = false, fleet = { "taxi", "car", "tourbus", "van" } },
	}
	local CAR_COLORS = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(230, 230, 230), Color3.fromRGB(40, 40, 46), Color3.fromRGB(80, 160, 110), Color3.fromRGB(150, 150, 160) }
	local n = 0
	for li, lane in ipairs(lanes) do
		lane.len = pathLength(lane.path)
		lane.dist = li * 37
		lane.speed = 20
		for k, kind in ipairs(lane.fleet) do
			n = n + 1
			local color, label = CAR_COLORS[n % #CAR_COLORS + 1], nil
			if kind == "taxi" then
				color = Color3.fromRGB(250, 200, 40)
			elseif kind == "bus" then
				color, label = Color3.fromRGB(220, 230, 240), "CITY LINE 7"
			elseif kind == "van" then
				color = Color3.fromRGB(240, 240, 236)
			end
			local veh = vehicle(f, kind, color, label)
			veh.kind = kind
			veh.lane = lane
			veh.offset = (k - 1) / #lane.fleet * lane.len
			table.insert(World.traffic, veh)
		end
	end
	World.lanes = lanes
	World.trafficFolder = f
end

-- the tour bus shows a tour of the label (or a famous rival)
local function tourBusLabel()
	local state = World.app.state
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			return string.upper(Artists.byId[t.artistId].name) .. " | " .. string.upper(t.name), UI.rgb(Artists.byId[t.artistId].color)
		end
	end
	return "NOVA RAY | STARDUST WORLD TOUR", Color3.fromRGB(255, 120, 180)
end

local function animateTraffic(t, dt)
	-- does a lane have to wait at the zebra crossing?
	for _, lane in ipairs(World.lanes or {}) do
		local wait, onZebra = false, false
		if World.crossing then
			for _, v in ipairs(World.traffic) do
				if v.lane == lane and v.pos and math.abs(v.pos.Z - lane.z) < 3 then
					local x = v.pos.X
					local approaching = lane.east and (x > -34 and x < -8) or (not lane.east and x < 34 and x > 8)
					if approaching then
						wait = true
					elseif math.abs(x) <= 8 then
						onZebra = true -- a car already on the crossing drives on and clears it
					end
				end
			end
		end
		if onZebra then
			wait = false
		end
		if not wait then
			lane.dist = lane.dist + dt * lane.speed
		end
	end
	for _, v in ipairs(World.traffic or {}) do
		local lane = v.lane
		local dist = (lane.dist + v.offset) % lane.len
		if v.kind == "tourbus" and (not v.labelled or math.floor(t) % 20 == 0) then
			-- (re)paint the tour bus with the running tour
			local txt, col = tourBusLabel()
			if v.labelText ~= txt then
				v.labelText = txt
				local lab = vehicle(World.trafficFolder, "tourbus", col, txt)
				v.model:Destroy()
				v.model, v.parts = lab.model, lab.parts
				for _, pp in ipairs(v.parts) do
					if pp[1].Name == "Body" then
						pp[1].Color = Color3.fromRGB(26, 26, 32)
					end
				end
			end
			v.labelled = true
		end
		local pos, dir = alongPath(lane.path, dist)
		v.pos = pos
		local cf = CFrame.lookAt(O + pos, O + pos + Vector3.new(dir.X, 0, dir.Z))
		for _, pp in ipairs(v.parts) do
			pp[1].CFrame = cf * pp[2]
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
	UI.Label(card, ad.genre .. (ad.members > 1 and ("  |  " .. ad.members .. " members") or "  |  solo"), UI.px(130, 50), UI.px(236, 22), { textSize = 16, color = UI.rgb(ad.color), font = UI.FontBold })
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
		local planned = (state.draft or {}).artistId == ad.id
		UI.Label(card, tour and ("ON TOUR: " .. tour.name) or (planned and "Tour in planning" or "Ready for a tour"), UI.px(130, 168), UI.px(236, 22), { textSize = 15, color = tour and T.gold or T.good, font = UI.FontBold })
		if tour then
			UI.Label(card, ad.bio, UI.px(14, 204), UI.px(346, 58), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
		else
			UI.Button(card, planned and "IN PLANNING  |  GO ON" or "PLAN A TOUR", UI.px(14, 204), UI.px(344, 52), { color = planned and T.panel3 or T.accent, textSize = 18 }, function()
				World.planTour(ad.id)
			end)
		end
	else
		local lvl = GS.level(state)
		local locked = ad.level > lvl
		local afford = state.money >= ad.signCost
		UI.Label(card, "Costs " .. Util.money(ad.signCost), UI.px(130, 168), UI.px(236, 22), { textSize = 16, color = T.gold, font = UI.FontBold })
		local txt = locked and ("LOCKED | needs level " .. ad.level) or (afford and "SIGN" or "NOT ENOUGH MONEY")
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
	UI.Label(bg, "MEETING  |  " .. string.upper(state.labelName), UI.px(30, 14), UI.px(1000, 44), { textSize = 34, font = UI.FontBlack, color = T.text })
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

-- PLAN A TOUR on the board: this artist goes on tour; next stop: the world map table
function World.planTour(artistId)
	local app = World.app
	local d = app.state.draft or {}
	local function go()
		if d.artistId ~= artistId then
			app:act("setDraft", { draft = { artistId = artistId } })
		end
		World.standUp()
		World.guide("maptable")
		app:toast("<b>" .. Artists.byId[artistId].name .. "</b> goes on tour! Next: plan the dates at the <b>WORLD MAP</b> table.", T.accent2, 7)
	end
	if d.artistId and d.artistId ~= artistId and #(d.shows or {}) > 0 then
		app:confirm("New tour plan?", "The plan for <b>" .. Artists.byId[d.artistId].name .. "</b> (" .. #d.shows .. " shows) will be dropped.", go)
	else
		go()
	end
end

-- get up from the chair (ends the meeting)
function World.standUp()
	local h = hum()
	if h then
		h.Sit = false
		h.Jump = true
	end
	World.endMeeting()
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
			mk.name.Text = (open and "" or "LOCKED  ") .. info.name
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
	-- the arrow is a tutorial: it guides until the first show; later only when a button sends you somewhere
	local tutorial = state.stats.shows == 0
	World.target = World.override or (tutorial and GS.objective(state).target or nil)
	refreshChartsWall(un.charts)
	refreshPins()
	World.refreshPosters()
end

------------------------------------------------------------------ start
-- leaves the world (back to the main menu): everything the client built goes away
function World.stop()
	for _, c in ipairs(World.conns or {}) do
		c:Disconnect()
	end
	World.conns = {}
	for _, g in ipairs(World.posterGuis or {}) do
		g:Destroy()
	end
	World.posterGuis = {}
	if World.boardGui then
		World.boardGui:Destroy()
		World.boardGui = nil
	end
	if World.root then
		for _, d in ipairs(World.root:GetDescendants()) do
			if d:IsA("SurfaceGui") and d.Name == "ChartsGui" then
				d:Destroy()
			end
		end
	end
	if World.folder then
		World.folder:Destroy()
		World.folder = nil
	end
	World.prompts = {}
	World.markers = {}
	World.npcs = {}
	World.traffic = {}
	World.lastStep = nil
end

function World.start(app)
	World.app = app
	World.conns = {}
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
	buildTraffic()
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
	World.conns[#World.conns + 1] = ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("Station")
		if id then
			World.trigger(id)
		end
	end)
	local player = Players.LocalPlayer
	World.conns[#World.conns + 1] = player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	app:act("enterWorld")
	World.freeze(false)
	World.refresh()
	local t = 0
	local peopleT = 0
	World.conns[#World.conns + 1] = RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		local showTags = app.mode == "world"
		if World.tagsShown ~= showTags then
			World.tagsShown = showTags
			for _, mk in pairs(World.markers) do
				mk.gui.Enabled = showTags
			end
		end
		if app.mode == "world" then
			placeArrow(t)
			peopleT = peopleT + dt
			if peopleT > 1 / 30 then
				peopleT = 0
				local step = math.min(0.2, World.lastStep and (t - World.lastStep) or 0)
				World.lastStep = t
				animatePeople(t, step)
				animateTraffic(t, step)
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
