-- The label building "Starlight Records": the walkable hub. Built once by the server (so seats and
-- prompts work for the player), the client adds labels, screens and the guide arrow (Client/World.lua).
-- 1 stud ~ 0.3 m (Roblox character ~5 studs). Floor top = y 0. Street side = +Z.
local Hub = {}

Hub.ORIGIN = Vector3.new(4000, 0, 0)
local O = Hub.ORIGIN

-- where things are (relative to ORIGIN); the client uses these for markers and the guide arrow
Hub.SPAWN = Vector3.new(0, 0, -20)
Hub.STATIONS = {
	laptop = { pos = Vector3.new(14, 3.6, -36), name = "LAPTOP", sub = "Overview & tours", action = "Open laptop" },
	maptable = { pos = Vector3.new(0, 3.4, 6), name = "WORLD MAP", sub = "Plan a tour", action = "Plan a tour" },
	meeting = { pos = Vector3.new(-63, 3.4, -22), name = "MEETING ROOM", sub = "Artists & talent", action = "Start meeting" },
	stagehall = { pos = Vector3.new(58, 3.6, -26), name = "STAGE HALL", sub = "Build stages", action = "Build stages" },
	charts = { pos = Vector3.new(-20, 9, -45.4), name = "CHARTS", sub = "Top grossing tours", action = "View charts" },
}

local C = {
	wall = Color3.fromRGB(30, 32, 46),
	wall2 = Color3.fromRGB(40, 43, 60),
	floor = Color3.fromRGB(24, 26, 36),
	ceiling = Color3.fromRGB(18, 19, 27),
	trim = Color3.fromRGB(14, 15, 21),
	purple = Color3.fromRGB(108, 99, 255),
	teal = Color3.fromRGB(45, 212, 191),
	wood = Color3.fromRGB(92, 64, 46),
	woodDark = Color3.fromRGB(58, 40, 30),
	metal = Color3.fromRGB(120, 124, 136),
	black = Color3.fromRGB(12, 12, 16),
	carpet = Color3.fromRGB(44, 38, 74),
	glass = Color3.fromRGB(150, 180, 220),
	white = Color3.fromRGB(235, 235, 245),
	gold = Color3.fromRGB(255, 205, 60),
	plant = Color3.fromRGB(50, 130, 70),
	asphalt = Color3.fromRGB(30, 30, 34),
	concrete = Color3.fromRGB(70, 72, 78),
}
Hub.COLORS = C

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do
		i[k] = v
	end
	i.Parent = parent
	return i
end

local function part(parent, name, size, cf, color, material, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
	p.Name = name
	p.Size = size
	p.CFrame = (typeof(cf) == "Vector3") and CFrame.new(O + cf) or (CFrame.new(O) * cf)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = opts.collide ~= false
	p.CanTouch = opts.touch == true
	p.CastShadow = opts.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.transparency then
		p.Transparency = opts.transparency
	end
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Parent = parent
	return p
end
Hub.part = part

local function light(p, range, brightness, color, kind)
	return new(kind or "PointLight", { Range = range, Brightness = brightness, Color = color or Color3.fromRGB(255, 240, 220), Shadows = false }, p)
end

-- a sign with text on one face (server text; the client renames the label sign)
local function sign(p, face, text, color, size, font)
	local g = new("SurfaceGui", { Name = "Sign", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0, AlwaysOnTop = false }, p)
	new("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color or C.white,
		TextScaled = true,
		Font = font or Enum.Font.GothamBlack,
	}, g)
	return g
end

local function prompt(p, id, action, objectText, dist)
	local pr = new("ProximityPrompt", {
		Name = "Prompt",
		ActionText = action,
		ObjectText = objectText,
		KeyboardKeyCode = Enum.KeyCode.E,
		HoldDuration = 0,
		MaxActivationDistance = dist or 9,
		RequiresLineOfSight = false,
		Style = Enum.ProximityPromptStyle.Default,
	}, p)
	pr:SetAttribute("Station", id)
	return pr
end

------------------------------------------------------------------ furniture helpers
local function chairDecor(parent, pos, yaw, color)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "ChairSeat", Vector3.new(2.6, 0.5, 2.6), cf * CFrame.new(0, 2, 0), color or C.black)
	part(parent, "ChairBack", Vector3.new(2.6, 3, 0.4), cf * CFrame.new(0, 3.5, 1.2), color or C.black)
	part(parent, "ChairPole", Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(0, 0.9, 0), C.metal, Enum.Material.Metal)
	part(parent, "ChairFoot", Vector3.new(2.2, 0.2, 2.2), cf * CFrame.new(0, 0.1, 0), C.metal, Enum.Material.Metal)
end

local function plant(parent, pos, big)
	local s = big and 1.6 or 1
	part(parent, "Pot", Vector3.new(2.2 * s, 2.2 * s, 2.2 * s), pos + Vector3.new(0, 1.1 * s, 0), C.black, Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder }).CFrame = CFrame.new(O + pos + Vector3.new(0, 1.1 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	for i = 0, 4 do
		local a = i * 1.26
		part(parent, "Leaf", Vector3.new(1.4 * s, 3.4 * s, 0.3), CFrame.new(pos + Vector3.new(math.cos(a) * 0.7 * s, 3.6 * s, math.sin(a) * 0.7 * s)) * CFrame.Angles(0, -a, 0.35), C.plant, Enum.Material.Grass, { collide = false })
	end
	part(parent, "Bush", Vector3.new(2.6 * s, 2.6 * s, 2.6 * s), pos + Vector3.new(0, 3 * s, 0), C.plant, Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
end

local function sofa(parent, pos, yaw, color, len)
	len = len or 10
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "SofaBase", Vector3.new(len, 1.6, 4), cf * CFrame.new(0, 0.8, 0), C.black)
	part(parent, "SofaCushion", Vector3.new(len - 1, 0.8, 3.2), cf * CFrame.new(0, 2, -0.3), color)
	part(parent, "SofaBack", Vector3.new(len, 3, 1), cf * CFrame.new(0, 2.6, 1.6), color)
	part(parent, "SofaArmL", Vector3.new(1, 2.6, 4), cf * CFrame.new(-len / 2, 1.9, 0), color)
	part(parent, "SofaArmR", Vector3.new(1, 2.6, 4), cf * CFrame.new(len / 2, 1.9, 0), color)
end

-- framed gold / platinum record on a wall; normal = direction the front faces
local function record(parent, pos, yaw, gold)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "RecordFrame", Vector3.new(3.6, 4.4, 0.2), cf, C.black)
	part(parent, "RecordMat", Vector3.new(3.2, 4, 0.1), cf * CFrame.new(0, 0, 0.12), C.white)
	part(parent, "Record", Vector3.new(0.1, 2.6, 2.6), cf * CFrame.new(0, 0.3, 0.2) * CFrame.Angles(0, math.pi / 2, 0), gold and C.gold or Color3.fromRGB(220, 225, 235), Enum.Material.Metal, { shape = Enum.PartType.Cylinder })
	part(parent, "Plate", Vector3.new(2, 0.4, 0.1), cf * CFrame.new(0, -1.6, 0.2), C.gold, Enum.Material.Metal)
end

local function ceilingLight(parent, pos, len, rot)
	local p = part(parent, "CeilingLight", Vector3.new(len, 0.2, 1.2), CFrame.new(pos) * CFrame.Angles(0, rot or 0, 0), Color3.fromRGB(240, 238, 255), Enum.Material.Neon, { collide = false })
	new("SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 22, Brightness = 1.3, Angle = 120, Color = Color3.fromRGB(255, 244, 230), Shadows = false }, p)
	return p
end

------------------------------------------------------------------ the building
function Hub.build(parentFolder)
	local old = workspace:FindFirstChild("StarlightRecords")
	if old then
		old:Destroy()
	end
	local root = new("Model", { Name = "StarlightRecords" }, parentFolder or workspace)
	local shell = new("Folder", { Name = "Shell" }, root)
	local deco = new("Folder", { Name = "Decor" }, root)
	local stations = new("Folder", { Name = "Stations" }, root)

	local H = 18 -- ceiling height (office, meeting room, lounge)
	local HH = 34 -- stage hall height
	-- floors
	part(shell, "Floor", Vector3.new(128, 1, 94), Vector3.new(-23, -0.5, 0), C.floor, Enum.Material.Marble)
	part(shell, "HallFloor", Vector3.new(80, 1, 94), Vector3.new(81, -0.5, 0), Color3.fromRGB(58, 60, 66), Enum.Material.Concrete)
	part(deco, "MeetingCarpet", Vector3.new(44, 0.1, 48), Vector3.new(-63, 0.05, -21), C.carpet, Enum.Material.Fabric, { collide = false })
	part(deco, "LoungeRug", Vector3.new(30, 0.1, 22), Vector3.new(-63, 0.05, 26), Color3.fromRGB(34, 60, 70), Enum.Material.Fabric, { collide = false })
	-- floor accent lines leading to the stations
	part(deco, "FloorLinePurple", Vector3.new(0.6, 0.06, 60), Vector3.new(-6, 0.03, 10), C.purple, Enum.Material.Neon, { collide = false })
	part(deco, "FloorLineTeal", Vector3.new(0.6, 0.06, 60), Vector3.new(6, 0.03, 10), C.teal, Enum.Material.Neon, { collide = false })

	-- outer walls
	part(shell, "BackWall", Vector3.new(130, H, 2), Vector3.new(-23, H / 2, -47), C.wall, Enum.Material.SmoothPlastic)
	part(shell, "LeftWall", Vector3.new(2, H, 96), Vector3.new(-88, H / 2, 0), C.wall, Enum.Material.SmoothPlastic)
	-- lounge front (solid with windows)
	part(shell, "LoungeFrontLow", Vector3.new(48, 4, 2), Vector3.new(-64, 2, 47), C.wall)
	part(shell, "LoungeFrontHigh", Vector3.new(48, 4, 2), Vector3.new(-64, H - 2, 47), C.wall)
	part(shell, "LoungeWindow", Vector3.new(48, H - 8, 0.4), Vector3.new(-64, H / 2, 47), C.glass, Enum.Material.Glass, { transparency = 0.55 })
	for x = -86, -42, 11 do
		part(shell, "Mullion", Vector3.new(0.6, H - 8, 0.8), Vector3.new(x, H / 2, 47), C.trim)
	end
	-- office glass front with the entrance (x -6..6)
	part(shell, "FrontBase", Vector3.new(80, 1.2, 2), Vector3.new(0, 0.6, 47), C.trim)
	part(shell, "FrontTop", Vector3.new(80, 3, 2), Vector3.new(0, H - 1.5, 47), C.wall)
	part(shell, "FrontGlassL", Vector3.new(34, H - 4.2, 0.4), Vector3.new(-23, (H - 1.8) / 2 + 0.6, 47), C.glass, Enum.Material.Glass, { transparency = 0.6 })
	part(shell, "FrontGlassR", Vector3.new(34, H - 4.2, 0.4), Vector3.new(23, (H - 1.8) / 2 + 0.6, 47), C.glass, Enum.Material.Glass, { transparency = 0.6 })
	part(shell, "DoorHeader", Vector3.new(12, H - 13, 2), Vector3.new(0, 10 + (H - 13) / 2 + 0, 47), C.wall)
	for _, x in ipairs({ -40, -29, -18, -6.2, 6.2, 18, 29, 40 }) do
		part(shell, "Mullion", Vector3.new(0.7, H - 1, 0.9), Vector3.new(x, (H - 1) / 2, 47), C.trim)
	end
	-- entrance: glowing threshold and open sliding doors
	part(deco, "Threshold", Vector3.new(12, 0.08, 2), Vector3.new(0, 0.04, 47), C.purple, Enum.Material.Neon, { collide = false })
	part(deco, "SlideDoorL", Vector3.new(6, 10, 0.3), Vector3.new(-9, 5, 48.4), C.glass, Enum.Material.Glass, { transparency = 0.5 })
	part(deco, "SlideDoorR", Vector3.new(6, 10, 0.3), Vector3.new(9, 5, 48.4), C.glass, Enum.Material.Glass, { transparency = 0.5 })
	-- meeting room / office: glass partition with a door (z -16..-8)
	part(shell, "MeetGlassA", Vector3.new(0.4, H - 1, 30), Vector3.new(-40, (H - 1) / 2, -31), C.glass, Enum.Material.Glass, { transparency = 0.6 })
	part(shell, "MeetGlassB", Vector3.new(0.4, H - 1, 13), Vector3.new(-40, (H - 1) / 2, -1.5), C.glass, Enum.Material.Glass, { transparency = 0.6 })
	part(shell, "MeetDoorTop", Vector3.new(1, H - 11, 8), Vector3.new(-40, 11 + (H - 11) / 2, -12), C.wall)
	for _, z in ipairs({ -46, -36, -26, -16, -8, 5 }) do
		part(shell, "Post", Vector3.new(1, H, 1), Vector3.new(-40, H / 2, z), C.trim)
	end
	part(deco, "MeetingSignBar", Vector3.new(0.3, 1.6, 8), Vector3.new(-39.6, 12.4, -12), C.black)
	sign(part(deco, "MeetingSign", Vector3.new(0.2, 1.2, 7.6), Vector3.new(-39.4, 12.4, -12), C.black), Enum.NormalId.Right, "MEETING ROOM", C.teal)
	-- meeting room / lounge wall
	part(shell, "LoungeWall", Vector3.new(47, H, 2), Vector3.new(-64, H / 2, 5), C.wall2)
	-- office / stage hall wall with the roll-up door (z 2..18, 14 high)
	part(shell, "HallWallA", Vector3.new(2, HH, 49), Vector3.new(41, HH / 2, -22.5), C.wall)
	part(shell, "HallWallB", Vector3.new(2, HH, 29), Vector3.new(41, HH / 2, 32.5), C.wall)
	part(shell, "HallWallTop", Vector3.new(2, HH - 14, 16), Vector3.new(41, 14 + (HH - 14) / 2, 10), C.wall)
	-- stage hall shell
	part(shell, "HallBack", Vector3.new(82, HH, 2), Vector3.new(81, HH / 2, -47), C.wall2, Enum.Material.Concrete)
	part(shell, "HallRight", Vector3.new(2, HH, 96), Vector3.new(122, HH / 2, 0), C.wall2, Enum.Material.Concrete)
	part(shell, "HallFront", Vector3.new(82, HH, 2), Vector3.new(81, HH / 2, 47), C.wall2, Enum.Material.Concrete)
	part(shell, "HallRoof", Vector3.new(84, 1, 98), Vector3.new(81, HH + 0.5, 0), C.ceiling)
	-- the roll-up door (the client opens it when the hall is unlocked)
	local door = new("Model", { Name = "HallDoor" }, stations)
	for i = 0, 13 do
		part(door, "Slat", Vector3.new(0.6, 0.96, 16), Vector3.new(40.4, 0.5 + i, 10), (i % 2 == 0) and Color3.fromRGB(80, 84, 96) or Color3.fromRGB(70, 74, 86), Enum.Material.DiamondPlate)
	end
	local doorSign = part(door, "DoorSign", Vector3.new(0.2, 2.4, 12), Vector3.new(39.9, 7, 10), C.black, Enum.Material.SmoothPlastic, { collide = false })
	sign(doorSign, Enum.NormalId.Left, "STAGE HALL", C.gold)
	door.PrimaryPart = doorSign
	part(deco, "DoorFrameTop", Vector3.new(2.6, 1, 17), Vector3.new(41, 14.5, 10), C.gold, Enum.Material.Metal)
	-- ceilings
	part(shell, "Ceiling", Vector3.new(130, 1, 96), Vector3.new(-23, H + 0.5, 0), C.ceiling)
	for _, x in ipairs({ -26, -10, 10, 26 }) do
		for _, z in ipairs({ -32, -12, 10, 30 }) do
			ceilingLight(deco, Vector3.new(x, H - 0.1, z), 10)
		end
	end
	ceilingLight(deco, Vector3.new(-63, H - 0.1, -32), 14)
	ceilingLight(deco, Vector3.new(-63, H - 0.1, -12), 14)
	ceilingLight(deco, Vector3.new(-63, H - 0.1, 26), 14)
	-- cove light strips along the office walls
	part(deco, "CoveBack", Vector3.new(78, 0.3, 0.3), Vector3.new(0, H - 1, -45.8), C.purple, Enum.Material.Neon, { collide = false })
	part(deco, "CoveFront", Vector3.new(78, 0.3, 0.3), Vector3.new(0, H - 3.2, 45.8), C.teal, Enum.Material.Neon, { collide = false })
	-- skirting boards
	part(deco, "SkirtBack", Vector3.new(126, 0.6, 0.3), Vector3.new(-23, 0.3, -45.85), C.purple, Enum.Material.Neon, { collide = false })

	------------------------------------------------------------ spawn
	local spawn = part(root, "Spawn", Vector3.new(6, 0.2, 6), CFrame.lookAt(Hub.SPAWN + Vector3.new(0, 0.1, 0), Hub.SPAWN + Vector3.new(0, 0.1, 10)), C.purple, Enum.Material.Neon, { class = "SpawnLocation", collide = false, transparency = 0.6 })
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	Hub.spawnPart = spawn

	------------------------------------------------------------ OFFICE: desk + laptop (back of the office)
	local desk = new("Model", { Name = "Desk" }, stations)
	local dp = Vector3.new(14, 0, -37)
	part(desk, "DeskTop", Vector3.new(16, 0.6, 6), dp + Vector3.new(0, 3.2, 0), C.wood, Enum.Material.Wood)
	part(desk, "DeskSideL", Vector3.new(0.6, 3, 5.4), dp + Vector3.new(-7.4, 1.5, 0), C.black)
	part(desk, "DeskSideR", Vector3.new(0.6, 3, 5.4), dp + Vector3.new(7.4, 1.5, 0), C.black)
	part(desk, "DeskFront", Vector3.new(14.2, 2.4, 0.3), dp + Vector3.new(0, 1.8, 2.6), C.black)
	part(desk, "DeskGlow", Vector3.new(14, 0.15, 0.15), dp + Vector3.new(0, 0.6, 2.8), C.purple, Enum.Material.Neon, { collide = false })
	local laptop = part(desk, "Laptop", Vector3.new(3, 0.2, 2), dp + Vector3.new(0, 3.6, 0.6), Color3.fromRGB(60, 62, 72), Enum.Material.Metal)
	local lscreen = part(desk, "LaptopScreen", Vector3.new(3, 2, 0.12), CFrame.new(dp + Vector3.new(0, 4.55, -0.45)) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
	local lglow = part(desk, "LaptopDisplay", Vector3.new(2.7, 1.7, 0.05), CFrame.new(dp + Vector3.new(0, 4.55, -0.45)) * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 0, 0.08), Color3.fromRGB(90, 80, 255), Enum.Material.Neon, { collide = false })
	local _ = lscreen
	light(lglow, 8, 0.8, Color3.fromRGB(140, 130, 255))
	prompt(laptop, "laptop", "Open laptop", "Office", 9)
	-- monitors + desk lamp + records
	for _, mx in ipairs({ -4.5, 4.5 }) do
		part(desk, "MonitorStand", Vector3.new(0.4, 1.2, 0.4), dp + Vector3.new(mx, 4.1, -1.6), C.black)
		part(desk, "Monitor", Vector3.new(4, 2.4, 0.2), CFrame.new(dp + Vector3.new(mx, 5.6, -1.7)) * CFrame.Angles(0, (mx > 0) and math.rad(-14) or math.rad(14), 0), C.black)
		part(desk, "MonitorGlow", Vector3.new(3.7, 2.1, 0.05), CFrame.new(dp + Vector3.new(mx, 5.6, -1.7)) * CFrame.Angles(0, (mx > 0) and math.rad(-14) or math.rad(14), 0) * CFrame.new(0, 0, 0.12), (mx > 0) and C.teal or Color3.fromRGB(255, 120, 200), Enum.Material.Neon, { collide = false })
	end
	chairDecor(desk, O + dp + Vector3.new(0, 0, -5.5) - O, math.pi, C.purple)
	part(desk, "Lamp", Vector3.new(0.3, 2.4, 0.3), dp + Vector3.new(7, 4.7, -1.5), C.metal, Enum.Material.Metal)
	light(part(desk, "LampHead", Vector3.new(1.2, 0.6, 1.2), dp + Vector3.new(7, 6, -1.2), C.gold, Enum.Material.Neon, { collide = false }), 10, 0.8)
	for i, x in ipairs({ 1, 27, 33 }) do
		record(deco, Vector3.new(x, 9, -45.7), 0, i % 2 == 1)
	end
	-- shelves with vinyl behind the desk
	part(deco, "Shelf1", Vector3.new(14, 0.4, 2), Vector3.new(14, 6.5, -45), C.wood, Enum.Material.Wood)
	part(deco, "Shelf2", Vector3.new(14, 0.4, 2), Vector3.new(14, 12.5, -45), C.wood, Enum.Material.Wood)
	for i = 0, 11 do
		local col = ({ C.purple, C.teal, C.gold, Color3.fromRGB(230, 80, 90) })[i % 4 + 1]
		part(deco, "Vinyl", Vector3.new(0.3, 2.8, 2.8), Vector3.new(8 + i * 1.1, 8.1, -45), col)
	end
	local logoWall = part(deco, "LogoWall", Vector3.new(14, 4, 0.3), Vector3.new(14, 15.2, -45.7), C.black)
	sign(logoWall, Enum.NormalId.Back, "STARLIGHT RECORDS", C.purple).Name = "LabelSign"

	------------------------------------------------------------ OFFICE: world map table (centre)
	local mt = new("Model", { Name = "MapTable" }, stations)
	local tp = Vector3.new(0, 0, 6)
	part(mt, "TableBase", Vector3.new(18, 2.6, 10), tp + Vector3.new(0, 1.3, 0), C.black)
	part(mt, "TableGlow", Vector3.new(18.4, 0.2, 10.4), tp + Vector3.new(0, 0.3, 0), C.teal, Enum.Material.Neon, { collide = false })
	part(mt, "TableRim", Vector3.new(24, 0.5, 14), tp + Vector3.new(0, 2.85, 0), Color3.fromRGB(46, 48, 64), Enum.Material.Metal)
	local mapTop = part(mt, "MapSurface", Vector3.new(22, 0.1, 11), tp + Vector3.new(0, 3.15, 0), Color3.fromRGB(10, 26, 52), Enum.Material.SmoothPlastic)
	light(mapTop, 14, 1, C.teal)
	prompt(mapTop, "maptable", "Plan a tour", "World Map", 11)
	-- hologram ring above the table
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		part(mt, "Holo", Vector3.new(0.25, 0.25, 2.6), CFrame.new(tp + Vector3.new(math.cos(a) * 4.8, 8.6, math.sin(a) * 4.8)) * CFrame.Angles(0, -a, 0), C.teal, Enum.Material.Neon, { collide = false, transparency = 0.35 })
	end
	part(mt, "HoloLamp", Vector3.new(6, 0.4, 6), tp + Vector3.new(0, H - 0.8, 0), C.black, Enum.Material.Metal, { collide = false })

	------------------------------------------------------------ OFFICE: charts wall (back wall, left)
	local cw = new("Model", { Name = "ChartsWall" }, stations)
	part(cw, "ChartsFrame", Vector3.new(26, 14, 0.6), Vector3.new(-20, 9, -45.6), C.black)
	local chartsScreen = part(cw, "ChartsScreen", Vector3.new(24.4, 12.4, 0.2), Vector3.new(-20, 9, -45.2), Color3.fromRGB(16, 18, 30), Enum.Material.SmoothPlastic)
	part(cw, "ChartsGlow", Vector3.new(26, 0.3, 0.3), Vector3.new(-20, 1.8, -45.3), C.gold, Enum.Material.Neon, { collide = false })
	prompt(chartsScreen, "charts", "View charts", "Charts", 16)

	------------------------------------------------------------ OFFICE: reception, sofas, plants
	local rp = Vector3.new(-22, 0, 30)
	part(deco, "Reception", Vector3.new(14, 3.6, 3), rp + Vector3.new(0, 1.8, 0), C.black)
	part(deco, "ReceptionTop", Vector3.new(14.6, 0.3, 3.6), rp + Vector3.new(0, 3.75, 0), C.white, Enum.Material.Marble)
	part(deco, "ReceptionGlow", Vector3.new(14, 0.2, 0.2), rp + Vector3.new(0, 0.4, 1.6), C.purple, Enum.Material.Neon, { collide = false })
	sign(part(deco, "ReceptionLogo", Vector3.new(10, 1.4, 0.1), rp + Vector3.new(0, 2, 1.56), C.black, nil, { collide = false }), Enum.NormalId.Back, "STARLIGHT RECORDS", C.white).Name = "LabelSign"
	sofa(deco, Vector3.new(24, 0, 30), math.pi / 2, C.purple, 12)
	part(deco, "CoffeeTable", Vector3.new(4, 1.4, 8), Vector3.new(18, 0.7, 30), C.wood, Enum.Material.Wood)
	plant(deco, Vector3.new(-36, 0, -42), true)
	plant(deco, Vector3.new(36, 0, -42), true)
	plant(deco, Vector3.new(-36, 0, 42), false)
	plant(deco, Vector3.new(36, 0, 42), false)
	plant(deco, Vector3.new(-12, 0, 42), false)
	plant(deco, Vector3.new(12, 0, 42), false)
	-- big neon "ON AIR" style sign over the hall door
	local neon = part(deco, "HallNeon", Vector3.new(0.3, 2, 14), Vector3.new(39.8, 16.4, 10), C.black, nil, { collide = false })
	sign(neon, Enum.NormalId.Left, "BACKSTAGE", C.teal)

	------------------------------------------------------------ MEETING ROOM: table, seats, board
	local mr = new("Model", { Name = "Meeting" }, stations)
	local mc = Vector3.new(-63, 0, -24)
	part(mr, "MeetTable", Vector3.new(9, 0.5, 20), mc + Vector3.new(0, 3.2, 0), C.woodDark, Enum.Material.Wood)
	part(mr, "MeetTableEndA", Vector3.new(0.5, 9, 9), CFrame.new(mc + Vector3.new(0, 3.2, -10)) * CFrame.Angles(0, 0, math.pi / 2), C.woodDark, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	part(mr, "MeetTableEndB", Vector3.new(0.5, 9, 9), CFrame.new(mc + Vector3.new(0, 3.2, 10)) * CFrame.Angles(0, 0, math.pi / 2), C.woodDark, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	part(mr, "MeetTableLeg", Vector3.new(3, 3, 14), mc + Vector3.new(0, 1.5, 0), C.black)
	part(mr, "MeetTableGlow", Vector3.new(3.2, 0.15, 14.2), mc + Vector3.new(0, 0.2, 0), C.purple, Enum.Material.Neon, { collide = false })
	local seats = new("Folder", { Name = "Seats" }, mr)
	local seatSpots = {}
	for _, z in ipairs({ -6, 0, 6 }) do
		table.insert(seatSpots, { mc + Vector3.new(-6.4, 0, z), mc + Vector3.new(0, 0, z) })
		table.insert(seatSpots, { mc + Vector3.new(6.4, 0, z), mc + Vector3.new(0, 0, z) })
	end
	table.insert(seatSpots, { mc + Vector3.new(0, 0, 17), mc + Vector3.new(0, 0, -10) })
	for i, sp in ipairs(seatSpots) do
		local pos, at = sp[1], sp[2]
		local look = CFrame.lookAt(pos + Vector3.new(0, 1.8, 0), Vector3.new(at.X, 1.8, at.Z))
		local seat = part(seats, "MeetingSeat" .. i, Vector3.new(2.8, 0.6, 2.8), look, C.purple, Enum.Material.Fabric, { class = "Seat" })
		seat:SetAttribute("Meeting", true)
		part(mr, "SeatBack", Vector3.new(2.8, 3.4, 0.5), look * CFrame.new(0, 1.9, 1.3), C.black)
		part(mr, "SeatPole", Vector3.new(0.4, 1.6, 0.4), look * CFrame.new(0, -1, 0), C.metal, Enum.Material.Metal)
		part(mr, "SeatFoot", Vector3.new(2.2, 0.2, 2.2), look * CFrame.new(0, -1.7, 0), C.metal, Enum.Material.Metal)
	end
	-- the board on the back wall (the client draws roster + talent on it)
	part(mr, "BoardFrame", Vector3.new(32, 15.6, 0.6), Vector3.new(-63, 9.6, -45.6), C.black)
	local board = part(mr, "Board", Vector3.new(30.6, 14.2, 0.2), Vector3.new(-63, 9.6, -45.2), Color3.fromRGB(14, 16, 28), Enum.Material.SmoothPlastic)
	part(mr, "BoardGlow", Vector3.new(32, 0.3, 0.3), Vector3.new(-63, 1.6, -45.3), C.purple, Enum.Material.Neon, { collide = false })
	prompt(part(mr, "MeetPromptSpot", Vector3.new(1, 1, 1), mc + Vector3.new(0, 4, 0), C.black, nil, { collide = false, transparency = 1 }), "meeting", "Start meeting", "Meeting Room", 18)
	local _b = board
	-- plants, water cooler and a whiteboard
	plant(deco, Vector3.new(-84, 0, -42), true)
	plant(deco, Vector3.new(-44, 0, -42), false)
	part(deco, "Cooler", Vector3.new(2, 4.4, 2), Vector3.new(-84, 2.2, 0), C.white)
	part(deco, "CoolerBottle", Vector3.new(1.6, 2, 1.6), Vector3.new(-84, 5.4, 0), Color3.fromRGB(120, 180, 255), Enum.Material.Glass, { transparency = 0.3 })

	------------------------------------------------------------ LOUNGE: sofas, records, vending machine
	sofa(deco, Vector3.new(-63, 0, 36), 0, C.teal, 14)
	sofa(deco, Vector3.new(-78, 0, 24), math.pi / 2, C.purple, 10)
	part(deco, "LoungeTable", Vector3.new(10, 1.4, 5), Vector3.new(-63, 0.7, 25), C.wood, Enum.Material.Wood)
	for i, z in ipairs({ 14, 22, 30, 38 }) do
		record(deco, Vector3.new(-86.8, 9, z), math.pi / 2, i % 2 == 0)
	end
	local vend = part(deco, "Vending", Vector3.new(5, 9, 3.6), Vector3.new(-46, 4.5, 41), Color3.fromRGB(200, 40, 70))
	part(deco, "VendingGlass", Vector3.new(3.4, 6, 0.1), Vector3.new(-46.6, 5.2, 39.15), Color3.fromRGB(255, 200, 220), Enum.Material.Neon, { collide = false, transparency = 0.2 })
	light(vend, 10, 0.6, Color3.fromRGB(255, 120, 150))
	local loungeNeon = part(deco, "LoungeNeon", Vector3.new(16, 3, 0.2), Vector3.new(-63, 12, 6.1), C.black, nil, { collide = false })
	sign(loungeNeon, Enum.NormalId.Back, "MAKE SOME NOISE", Color3.fromRGB(255, 110, 200))
	-- arcade cabinet
	part(deco, "Arcade", Vector3.new(3.6, 7, 3.4), Vector3.new(-84, 3.5, 12), C.black)
	part(deco, "ArcadeScreen", Vector3.new(0.1, 2.6, 2.6), Vector3.new(-82.15, 5.2, 12), C.teal, Enum.Material.Neon, { collide = false })

	------------------------------------------------------------ STAGE HALL: rehearsal stage + build console
	local hall = new("Model", { Name = "Hall" }, stations)
	part(hall, "RehearsalDeck", Vector3.new(40, 4, 20), Vector3.new(92, 2, -32), C.black)
	part(hall, "DeckEdge", Vector3.new(40.2, 0.3, 0.3), Vector3.new(92, 3.85, -21.9), C.teal, Enum.Material.Neon, { collide = false })
	local led = part(hall, "LedWall", Vector3.new(32, 14, 1), Vector3.new(92, 12, -41), Color3.fromRGB(20, 18, 40), Enum.Material.SmoothPlastic)
	sign(part(hall, "LedText", Vector3.new(30, 6, 0.1), Vector3.new(92, 12, -40.45), Color3.fromRGB(20, 18, 40), nil, { collide = false }), Enum.NormalId.Back, "STARLIGHT RECORDS", C.purple).Name = "LabelSign"
	light(led, 30, 1.2, C.purple)
	for _, x in ipairs({ 70, 114 }) do
		part(hall, "TrussTower", Vector3.new(2, 26, 2), Vector3.new(x, 13, -36), C.metal, Enum.Material.DiamondPlate)
		part(hall, "Speaker", Vector3.new(4, 8, 4), Vector3.new(x + ((x < 90) and 4 or -4), 8, -30), C.black)
	end
	part(hall, "TrussTop", Vector3.new(46, 2, 2), Vector3.new(92, 26, -36), C.metal, Enum.Material.DiamondPlate)
	for i = 0, 5 do
		local lx = 74 + i * 7
		local lamp = part(hall, "MovingHead", Vector3.new(1.6, 1.8, 1.6), Vector3.new(lx, 24.2, -36), C.black)
		part(hall, "Lens", Vector3.new(1, 0.2, 1), Vector3.new(lx, 23.2, -36), (i % 2 == 0) and C.purple or C.teal, Enum.Material.Neon, { collide = false })
		if i % 2 == 0 then
			new("SpotLight", { Face = Enum.NormalId.Bottom, Range = 40, Angle = 40, Brightness = 2, Color = (i % 4 == 0) and C.purple or C.teal, Shadows = false }, lamp)
		end
	end
	-- road cases
	for i = 0, 4 do
		local col = (i % 2 == 0) and Color3.fromRGB(20, 20, 24) or Color3.fromRGB(36, 36, 42)
		part(hall, "RoadCase", Vector3.new(5, 4, 4), Vector3.new(112 - (i % 3) * 6, 2 + math.floor(i / 3) * 4, 30), col, Enum.Material.DiamondPlate)
	end
	part(hall, "CaseStripes", Vector3.new(17, 0.3, 4.2), Vector3.new(106, 3.2, 30), C.gold, Enum.Material.Metal, { collide = false })
	-- the build console (opens My Stages / the stage builder)
	local cp = Vector3.new(58, 0, -24)
	part(hall, "Console", Vector3.new(10, 3.4, 4), cp + Vector3.new(0, 1.7, 0), C.black)
	local consoleTop = part(hall, "ConsoleTop", Vector3.new(10.4, 0.4, 4.6), CFrame.new(cp + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(46, 48, 64), Enum.Material.Metal)
	for i = -1, 1 do
		part(hall, "ConsoleScreen", Vector3.new(3, 2, 0.2), CFrame.new(cp + Vector3.new(i * 3.2, 5.3, -1.6)) * CFrame.Angles(0, i * -0.25, 0), (i == 0) and C.teal or C.purple, Enum.Material.Neon, { collide = false })
	end
	prompt(consoleTop, "stagehall", "Build stages", "Stage Hall", 10)
	-- hall lights
	for _, z in ipairs({ -20, 10, 36 }) do
		for _, x in ipairs({ 60, 100 }) do
			local l = part(hall, "HallLamp", Vector3.new(6, 0.4, 2), Vector3.new(x, HH - 2, z), Color3.fromRGB(255, 240, 210), Enum.Material.Neon, { collide = false })
			new("SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 36, Brightness = 1.1, Angle = 110, Shadows = false }, l)
		end
	end
	part(deco, "HallFloorMark", Vector3.new(40, 0.06, 0.5), Vector3.new(80, 0.03, 0), C.gold, Enum.Material.Neon, { collide = false })

	------------------------------------------------------------ outside: sidewalk, street, the city across the road
	local out = new("Folder", { Name = "Outside" }, root)
	part(out, "Ground", Vector3.new(700, 1, 600), Vector3.new(20, -1.5, 40), Color3.fromRGB(26, 28, 30), Enum.Material.Concrete)
	part(out, "Sidewalk", Vector3.new(220, 1, 14), Vector3.new(17, -0.5, 55), C.concrete, Enum.Material.Concrete)
	part(out, "Curb", Vector3.new(220, 1.2, 1), Vector3.new(17, -0.4, 62.5), Color3.fromRGB(110, 110, 116), Enum.Material.Concrete)
	part(out, "Street", Vector3.new(700, 1, 26), Vector3.new(20, -1, 76), C.asphalt, Enum.Material.Asphalt)
	for x = -300, 320, 16 do
		part(out, "LaneMark", Vector3.new(8, 0.06, 0.5), Vector3.new(x, -0.47, 76), C.white, Enum.Material.SmoothPlastic, { collide = false })
	end
	for i = 0, 6 do
		part(out, "Crosswalk", Vector3.new(1.6, 0.06, 22), Vector3.new(-6 + i * 2, -0.47, 76), C.white, Enum.Material.SmoothPlastic, { collide = false })
	end
	part(out, "SidewalkFar", Vector3.new(700, 1, 12), Vector3.new(20, -0.5, 95), C.concrete, Enum.Material.Concrete)
	-- street lamps
	for x = -80, 120, 40 do
		part(out, "LampPost", Vector3.new(0.6, 16, 0.6), Vector3.new(x, 8, 60), C.black, Enum.Material.Metal)
		part(out, "LampArm", Vector3.new(0.4, 0.4, 4), Vector3.new(x, 16, 62), C.black, Enum.Material.Metal)
		light(part(out, "LampHead", Vector3.new(1.6, 0.6, 2), Vector3.new(x, 15.7, 63.8), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, { collide = false }), 30, 1.2, Color3.fromRGB(255, 210, 150))
	end
	-- buildings across the street and behind
	local rnd = Random.new(7)
	local x = -300
	while x < 340 do
		local w = rnd:NextInteger(26, 50)
		local h = rnd:NextInteger(40, 140)
		local d = rnd:NextInteger(30, 50)
		local col = Color3.fromRGB(rnd:NextInteger(26, 44), rnd:NextInteger(28, 46), rnd:NextInteger(40, 62))
		part(out, "Building", Vector3.new(w, h, d), Vector3.new(x + w / 2, h / 2 - 1, 102 + d / 2), col, Enum.Material.Concrete)
		-- lit windows: a few glowing bands on the street side
		for b = 1, math.floor(h / 14) do
			if rnd:NextNumber() < 0.7 then
				local wc = (rnd:NextNumber() < 0.5) and Color3.fromRGB(255, 214, 150) or Color3.fromRGB(150, 190, 255)
				part(out, "Windows", Vector3.new(w - 6, 2.4, 0.2), Vector3.new(x + w / 2, b * 14 - 6, 101.85), wc, Enum.Material.Neon, { collide = false, transparency = 0.25 })
			end
		end
		x = x + w + rnd:NextInteger(4, 12)
	end
	-- buildings left and right of the label + skyline behind it
	part(out, "NeighbourL", Vector3.new(60, 70, 90), Vector3.new(-130, 34, 0), Color3.fromRGB(32, 34, 46), Enum.Material.Concrete)
	part(out, "NeighbourR", Vector3.new(60, 90, 90), Vector3.new(166, 44, 0), Color3.fromRGB(36, 34, 50), Enum.Material.Concrete)
	for i = 0, 9 do
		local h = 80 + (i * 37) % 120
		part(out, "Skyline", Vector3.new(40, h, 40), Vector3.new(-200 + i * 50, h / 2 - 1, -120 - (i % 3) * 30), Color3.fromRGB(22 + i % 3 * 4, 24, 36), Enum.Material.Concrete)
	end
	-- the facade: big sign with the label name over the entrance + roof sign
	part(out, "Canopy", Vector3.new(24, 0.6, 8), Vector3.new(0, 11, 51), C.black, Enum.Material.Metal)
	part(out, "CanopyGlow", Vector3.new(24.2, 0.2, 0.2), Vector3.new(0, 10.7, 55), C.purple, Enum.Material.Neon, { collide = false })
	local facade = part(out, "FacadeSign", Vector3.new(60, 6, 0.6), Vector3.new(0, 22, 48.4), C.black)
	sign(facade, Enum.NormalId.Back, "STARLIGHT RECORDS", C.white).Name = "LabelSign"
	part(out, "FacadeGlow", Vector3.new(60, 0.3, 0.3), Vector3.new(0, 18.8, 48.8), C.teal, Enum.Material.Neon, { collide = false })
	part(out, "Parapet", Vector3.new(130, 6, 96), Vector3.new(-23, H + 4, 0), C.wall)
	local star = part(out, "RoofStar", Vector3.new(1, 12, 12), CFrame.new(Vector3.new(-60, H + 13, 30)) * CFrame.Angles(0, math.pi / 2, math.pi / 4), C.gold, Enum.Material.Neon, { collide = false })
	light(star, 40, 1.5, C.gold)
	-- parked tour bus on the street
	local bp = Vector3.new(70, 0, 70)
	part(out, "BusBody", Vector3.new(40, 11, 9), bp + Vector3.new(0, 6, 0), Color3.fromRGB(20, 20, 26), Enum.Material.Metal)
	part(out, "BusStripe", Vector3.new(40.2, 1.2, 9.2), bp + Vector3.new(0, 4, 0), C.purple, Enum.Material.Neon, { collide = false })
	part(out, "BusWindows", Vector3.new(36, 2.4, 9.3), bp + Vector3.new(-1, 8.5, 0), Color3.fromRGB(40, 50, 70), Enum.Material.Glass)
	for _, wx in ipairs({ -14, 12, 16 }) do
		for _, wz in ipairs({ -4.6, 4.6 }) do
			part(out, "Wheel", Vector3.new(1.4, 3.6, 3.6), CFrame.new(bp + Vector3.new(wx, 1.4, wz)) * CFrame.Angles(0, math.pi / 2, 0), C.black, nil, { shape = Enum.PartType.Cylinder })
		end
	end
	return root
end

return Hub
