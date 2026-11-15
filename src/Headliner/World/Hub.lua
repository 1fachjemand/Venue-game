-- The label building "Starlight Records" and its little street: the walkable hub.
-- Built once by the server (so seats and prompts work); the client adds name tags, posters, people,
-- the table map and the charts screen (Client/World.lua).
-- Style: bright and friendly (daylight, light wood, white walls, painted colour accents, no neon strips).
-- Rule against z-fighting: parts never share a face plane with another part of a different colour;
-- decorations sit at least 0.04 studs in front of the surface they hang on.
-- 1 stud ~ 0.3 m. Floor top = y 0. The street is on the +Z side.
local Hub = {}

Hub.ORIGIN = Vector3.new(4000, 0, 0)
local O = Hub.ORIGIN

Hub.SPAWN = Vector3.new(0, 0, -16)
Hub.STATIONS = {
	laptop = { pos = Vector3.new(14, 3.6, -37), name = "LAPTOP", sub = "Overview & tours", action = "Open laptop" },
	maptable = { pos = Vector3.new(0, 3.4, 6), name = "WORLD MAP", sub = "Plan a tour", action = "Plan a tour" },
	meeting = { pos = Vector3.new(-63, 3.4, -24), name = "MEETING ROOM", sub = "Artists & talent", action = "Start meeting" },
	stagehall = { pos = Vector3.new(58, 3.6, -24), name = "STAGE HALL", sub = "Build stages", action = "Build stages" },
	charts = { pos = Vector3.new(-20, 9, -45.4), name = "CHARTS", sub = "Top grossing tours", action = "View charts" },
}

-- people (the client builds and animates them): staff at their desks, walkers, people at the cafe
Hub.STAFF = {
	{ pos = Vector3.new(24, 0, -15.4), yaw = math.pi, desk = true },
	{ pos = Vector3.new(32, 0, -15.4), yaw = math.pi, desk = true },
	{ pos = Vector3.new(24, 0, -3.4), yaw = math.pi, desk = true },
	{ pos = Vector3.new(32, 0, -3.4), yaw = math.pi, desk = true },
	{ pos = Vector3.new(-22, 0, 25.2), yaw = 0 }, -- reception
}
Hub.WALKS = {
	{ Vector3.new(-140, 0, 54), Vector3.new(180, 0, 54) },
	{ Vector3.new(180, 0, 57), Vector3.new(-140, 0, 57) },
	{ Vector3.new(-140, 0, 96), Vector3.new(180, 0, 96) },
	{ Vector3.new(180, 0, 99), Vector3.new(-140, 0, 99) },
	{ Vector3.new(-6, 0, 22), Vector3.new(30, 0, 22), Vector3.new(30, 0, 27), Vector3.new(-6, 0, 22) }, -- office: to the coffee bar
	{ Vector3.new(-70, 0, 12), Vector3.new(-60, 0, 18), Vector3.new(-46, 0, 20) }, -- lounge
}
Hub.SITTERS = {
	{ pos = Vector3.new(-100, 0, 100.6), yaw = math.pi },
	{ pos = Vector3.new(-88, 0, 95.4), yaw = 0 },
	{ pos = Vector3.new(-76, 0, 100.6), yaw = math.pi },
	{ pos = Vector3.new(-63, 0, 37.6), yaw = math.pi, sofa = true },
}

local C = {
	wall = Color3.fromRGB(240, 236, 228),
	wallWarm = Color3.fromRGB(236, 226, 210),
	ceiling = Color3.fromRGB(246, 246, 244),
	floorWood = Color3.fromRGB(200, 158, 112),
	wood = Color3.fromRGB(176, 128, 84),
	woodDark = Color3.fromRGB(120, 84, 56),
	purple = Color3.fromRGB(126, 112, 232),
	teal = Color3.fromRGB(64, 186, 170),
	coral = Color3.fromRGB(240, 122, 100),
	yellow = Color3.fromRGB(250, 204, 82),
	white = Color3.fromRGB(250, 250, 248),
	grey = Color3.fromRGB(136, 140, 150),
	dark = Color3.fromRGB(46, 48, 58),
	screen = Color3.fromRGB(28, 30, 40),
	glass = Color3.fromRGB(190, 218, 238),
	carpet = Color3.fromRGB(120, 132, 168),
	plant = Color3.fromRGB(70, 150, 80),
	pot = Color3.fromRGB(214, 196, 170),
	brick = Color3.fromRGB(164, 92, 70),
	concrete = Color3.fromRGB(168, 170, 172),
	sidewalk = Color3.fromRGB(196, 192, 184),
	asphalt = Color3.fromRGB(70, 72, 78),
	lamp = Color3.fromRGB(255, 248, 228),
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

-- a part from a relative CFrame (or a relative position)
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
	p.CastShadow = false
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

-- a box given by its min / max corner (relative), easier to keep parts from overlapping
local function box(parent, name, x0, y0, z0, x1, y1, z1, color, material, opts)
	return part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, opts)
end

local function light(p, range, brightness, color, kind)
	return new(kind or "PointLight", { Range = range, Brightness = brightness, Color = color or Color3.fromRGB(255, 240, 220), Shadows = false }, p)
end

local function sign(p, face, text, color, font)
	local g = new("SurfaceGui", { Name = "Sign", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 40, LightInfluence = 0.2 }, p)
	new("TextLabel", { Name = "Text", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextColor3 = color or C.white, TextScaled = true, Font = font or Enum.Font.GothamBlack }, g)
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

-- a poster frame on a wall; the client paints an artist on it (attribute Poster = index)
-- face: the side the poster shows ("Back" = +Z, "Front" = -Z, "Right" = +X, "Left" = -X)
local posters = 0
local function poster(parent, center, face, w, h)
	posters = posters + 1
	local size
	if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
		size = Vector3.new(0.2, h, w)
	else
		size = Vector3.new(w, h, 0.2)
	end
	local p = part(parent, "Poster", size, center, C.white, Enum.Material.SmoothPlastic, { collide = false })
	p:SetAttribute("Poster", posters)
	p:SetAttribute("Face", face.Name)
	return p
end

------------------------------------------------------------------ furniture
local function plant(parent, pos, big)
	local s = big and 1.5 or 1
	local pot = part(parent, "Pot", Vector3.new(2.4 * s, 2.2 * s, 2.4 * s), CFrame.new(pos + Vector3.new(0, 1.1 * s, 0)) * CFrame.Angles(0, 0, math.pi / 2), C.pot, Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
	pot.Size = Vector3.new(2.2 * s, 2.4 * s, 2.4 * s)
	part(parent, "Leaves", Vector3.new(3.4 * s, 3.4 * s, 3.4 * s), pos + Vector3.new(0, 3.6 * s, 0), C.plant, Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
	part(parent, "Leaves", Vector3.new(2.4 * s, 2.4 * s, 2.4 * s), pos + Vector3.new(0.6 * s, 5 * s, 0.3 * s), Color3.fromRGB(86, 168, 92), Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
end

local function chair(parent, pos, yaw, color)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "ChairSeat", Vector3.new(2.6, 0.5, 2.6), cf * CFrame.new(0, 2.05, 0), color)
	part(parent, "ChairBack", Vector3.new(2.6, 2.8, 0.4), cf * CFrame.new(0, 3.65, 1.25), color)
	part(parent, "ChairPole", Vector3.new(0.35, 1.8, 0.35), cf * CFrame.new(0, 0.9, 0), C.grey, Enum.Material.Metal)
	part(parent, "ChairFoot", Vector3.new(2, 0.15, 2), cf * CFrame.new(0, 0.075, 0), C.grey, Enum.Material.Metal)
end

local function sofa(parent, pos, yaw, color, len)
	len = len or 10
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "SofaBase", Vector3.new(len, 1.6, 4), cf * CFrame.new(0, 0.8, 0), C.woodDark)
	part(parent, "SofaCushion", Vector3.new(len - 2, 0.8, 3.2), cf * CFrame.new(0, 2, -0.3), color, Enum.Material.Fabric)
	part(parent, "SofaBack", Vector3.new(len - 2.2, 2.6, 0.9), cf * CFrame.new(0, 2.9, 1.5), color, Enum.Material.Fabric)
	part(parent, "SofaArm", Vector3.new(1, 2.4, 4), cf * CFrame.new(-len / 2 + 0.5, 2.8, 0), color, Enum.Material.Fabric)
	part(parent, "SofaArm", Vector3.new(1, 2.4, 4), cf * CFrame.new(len / 2 - 0.5, 2.8, 0), color, Enum.Material.Fabric)
	for i = 0, 1 do
		part(parent, "Pillow", Vector3.new(1.6, 1.6, 0.5), cf * CFrame.new(-len / 2 + 2 + i * (len - 4), 3.2, 0.9) * CFrame.Angles(math.rad(-15), 0, 0), (i == 0) and C.yellow or C.white, Enum.Material.Fabric, { collide = false })
	end
end

-- framed gold / platinum record; yaw 0 = the front shows +Z
local function record(parent, pos, yaw, gold)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "RecordFrame", Vector3.new(3.6, 4.4, 0.2), cf, C.woodDark, nil, { collide = false })
	part(parent, "RecordMat", Vector3.new(3.2, 4, 0.1), cf * CFrame.new(0, 0, 0.14), C.white, nil, { collide = false })
	part(parent, "Record", Vector3.new(0.1, 2.6, 2.6), cf * CFrame.new(0, 0.3, 0.24) * CFrame.Angles(0, math.pi / 2, 0), gold and C.yellow or Color3.fromRGB(214, 218, 228), Enum.Material.Metal, { shape = Enum.PartType.Cylinder, collide = false })
	part(parent, "Plate", Vector3.new(2, 0.4, 0.1), cf * CFrame.new(0, -1.6, 0.24), C.yellow, Enum.Material.Metal, { collide = false })
end

local function ceilingLight(parent, pos, len)
	local p = part(parent, "CeilingLight", Vector3.new(len, 0.3, 2), pos, C.lamp, Enum.Material.Neon, { collide = false })
	new("SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 24, Brightness = 0.9, Angle = 120, Color = Color3.fromRGB(255, 246, 232), Shadows = false }, p)
	return p
end

local function desk(parent, pos, yaw, withScreen)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "DeskTop", Vector3.new(8, 0.4, 4), cf * CFrame.new(0, 3.1, 0), C.white)
	part(parent, "DeskLeg", Vector3.new(0.4, 2.9, 3.6), cf * CFrame.new(-3.6, 1.45, 0), C.grey, Enum.Material.Metal)
	part(parent, "DeskLeg", Vector3.new(0.4, 2.9, 3.6), cf * CFrame.new(3.6, 1.45, 0), C.grey, Enum.Material.Metal)
	if withScreen then
		part(parent, "MonitorFoot", Vector3.new(1.2, 0.1, 0.8), cf * CFrame.new(0, 3.35, -1.1), C.dark)
		part(parent, "MonitorArm", Vector3.new(0.3, 1, 0.3), cf * CFrame.new(0, 3.9, -1.1), C.dark)
		part(parent, "Monitor", Vector3.new(3.6, 2.2, 0.25), cf * CFrame.new(0, 5.3, -1.2), C.dark)
		part(parent, "MonitorImage", Vector3.new(3.3, 1.9, 0.05), cf * CFrame.new(0, 5.3, -1.05), (pos.X % 2 < 1) and Color3.fromRGB(110, 160, 230) or Color3.fromRGB(150, 130, 230), Enum.Material.SmoothPlastic, { collide = false })
		part(parent, "Keyboard", Vector3.new(2.6, 0.12, 0.9), cf * CFrame.new(0, 3.36, 0.4), C.white, nil, { collide = false })
		part(parent, "Mug", Vector3.new(0.5, 0.6, 0.5), cf * CFrame.new(2.6, 3.6, 0.2), C.coral, nil, { collide = false })
	end
end

local function shelf(parent, x0, z, x1, y0, rows, faceSign)
	-- a bookshelf against a wall at z (front towards faceSign * Z)
	local d = 1.6
	local zc = z + faceSign * d / 2
	part(parent, "ShelfBack", Vector3.new(x1 - x0 - 0.1, rows * 3 + 0.4, 0.2), Vector3.new((x0 + x1) / 2, y0 + (rows * 3 + 0.4) / 2, z + faceSign * 0.12), C.wood, Enum.Material.Wood, { collide = false })
	for r = 0, rows do
		part(parent, "ShelfBoard", Vector3.new(x1 - x0, 0.3, d), Vector3.new((x0 + x1) / 2, y0 + r * 3 + 0.15, zc), C.wood, Enum.Material.Wood)
	end
	local cols = { C.purple, C.teal, C.coral, C.yellow, C.white, Color3.fromRGB(90, 140, 220) }
	local n = 0
	for r = 0, rows - 1 do
		local x = x0 + 0.5
		while x < x1 - 1.2 do
			n = n + 1
			local w = 0.35 + (n % 3) * 0.15
			local h = 2.1 + (n % 4) * 0.15
			part(parent, "Book", Vector3.new(w, h, d - 0.3), Vector3.new(x + w / 2, y0 + r * 3 + 0.3 + h / 2, zc), cols[n % #cols + 1], nil, { collide = false })
			x = x + w + 0.06
			if n % 7 == 0 then
				x = x + 1.4
			end
		end
	end
end

local function tree(parent, pos)
	part(parent, "TreePit", Vector3.new(4, 0.2, 4), pos + Vector3.new(0, 0.1, 0), Color3.fromRGB(110, 90, 70), Enum.Material.Ground, { collide = false })
	part(parent, "Trunk", Vector3.new(9, 1, 1), CFrame.new(pos + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 80, 56), Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	part(parent, "Crown", Vector3.new(9, 8, 9), pos + Vector3.new(0, 11, 0), Color3.fromRGB(80, 156, 76), Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
	part(parent, "Crown", Vector3.new(6, 6, 6), pos + Vector3.new(1.8, 13.4, 1), Color3.fromRGB(96, 172, 88), Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
end

local function bench(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "BenchSeat", Vector3.new(7, 0.4, 2), cf * CFrame.new(0, 1.9, 0), C.wood, Enum.Material.Wood)
	part(parent, "BenchBack", Vector3.new(7, 1.6, 0.3), cf * CFrame.new(0, 3, 0.9), C.wood, Enum.Material.Wood)
	part(parent, "BenchLeg", Vector3.new(0.3, 1.7, 1.8), cf * CFrame.new(-3, 0.85, 0), C.dark, Enum.Material.Metal)
	part(parent, "BenchLeg", Vector3.new(0.3, 1.7, 1.8), cf * CFrame.new(3, 0.85, 0), C.dark, Enum.Material.Metal)
end

local function streetLamp(parent, pos, armDir)
	part(parent, "LampPost", Vector3.new(0.6, 15, 0.6), pos + Vector3.new(0, 7.5, 0), C.dark, Enum.Material.Metal)
	part(parent, "LampArm", Vector3.new(0.4, 0.4, 3.2), pos + Vector3.new(0, 15.2, armDir * 1.6), C.dark, Enum.Material.Metal)
	local head = part(parent, "LampHead", Vector3.new(1.4, 0.7, 2), pos + Vector3.new(0, 14.9, armDir * 3), C.dark, Enum.Material.Metal, { collide = false })
	part(parent, "LampGlass", Vector3.new(1.2, 0.1, 1.8), pos + Vector3.new(0, 14.5, armDir * 3), C.lamp, Enum.Material.Glass, { collide = false })
	return head
end

local function car(parent, pos, yaw, color)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	part(parent, "CarBody", Vector3.new(14, 3, 6.4), cf * CFrame.new(0, 2.3, 0), color, Enum.Material.SmoothPlastic)
	part(parent, "CarCabin", Vector3.new(7.6, 2.4, 5.8), cf * CFrame.new(-0.6, 5, 0), color, Enum.Material.SmoothPlastic)
	part(parent, "CarWindows", Vector3.new(7.8, 1.8, 5.9), cf * CFrame.new(-0.6, 5.1, 0), Color3.fromRGB(120, 150, 175), Enum.Material.Glass, { collide = false })
	for _, wx in ipairs({ -4.4, 4.4 }) do
		for _, wz in ipairs({ -3.25, 3.25 }) do
			part(parent, "Wheel", Vector3.new(1, 2.6, 2.6), cf * CFrame.new(wx, 1.3, wz) * CFrame.Angles(0, math.pi / 2, 0), C.dark, nil, { shape = Enum.PartType.Cylinder })
		end
	end
end

-- a shop across the street: facade, shop window, door, awning, sign
local function shop(parent, x0, x1, h, color, name, signColor, awning)
	local z0 = 104
	box(parent, "Shop", x0, -0.5, z0, x1, h, 150, color, Enum.Material.SmoothPlastic)
	local w = x1 - x0
	-- shop window and door (in front of the facade)
	box(parent, "ShopWindow", x0 + 3, 1.2, z0 - 0.3, x0 + w * 0.62, 9, z0 - 0.06, C.glass, Enum.Material.Glass, { transparency = 0.25 })
	box(parent, "ShopDoor", x0 + w * 0.68, 0, z0 - 0.3, x0 + w * 0.68 + 4, 8.6, z0 - 0.06, C.woodDark, Enum.Material.Wood)
	-- upper windows
	for fl = 1, math.floor((h - 16) / 9) do
		for k = 0, math.floor((w - 6) / 8) - 1 do
			box(parent, "Window", x0 + 4 + k * 8, 16 + (fl - 1) * 9, z0 - 0.3, x0 + 8.5 + k * 8, 21 + (fl - 1) * 9, z0 - 0.06, Color3.fromRGB(170, 196, 220), Enum.Material.Glass)
		end
	end
	-- awning (stripes)
	for k = 0, math.floor(w / 2) - 1 do
		local p = part(parent, "Awning", Vector3.new(2, 0.3, 5), CFrame.new(Vector3.new(x0 + 1 + k * 2, 10.4, z0 - 2.4)) * CFrame.Angles(math.rad(-18), 0, 0), (k % 2 == 0) and awning or C.white, Enum.Material.Fabric, { collide = false })
		local _ = p
	end
	local s = box(parent, "ShopSign", x0 + 2, 11.6, z0 - 0.6, x1 - 2, 14.2, z0 - 0.06, C.white)
	sign(s, Enum.NormalId.Front, name, signColor)
end

------------------------------------------------------------------ the building
function Hub.build(parentFolder)
	posters = 0
	local old = workspace:FindFirstChild("StarlightRecords")
	if old then
		old:Destroy()
	end
	local root = new("Model", { Name = "StarlightRecords" }, parentFolder or workspace)
	local shell = new("Folder", { Name = "Shell" }, root)
	local deco = new("Folder", { Name = "Decor" }, root)
	local stations = new("Folder", { Name = "Stations" }, root)
	local out = new("Folder", { Name = "Outside" }, root)
	local spots = new("Folder", { Name = "Spots" }, root)

	local H = 18 -- ceiling (office, meeting room, lounge)
	local HH = 34 -- stage hall

	------------------------------------------------------------ floors (walls stand on them)
	box(shell, "Floor", -88, -1, -46, 40, 0, 46, C.floorWood, Enum.Material.WoodPlanks)
	box(shell, "HallFloor", 42, -1, -46, 122, 0, 46, C.concrete, Enum.Material.Concrete)
	box(shell, "HallDoorSill", 40, -1, 2, 42, 0, 18, C.concrete, Enum.Material.Concrete)
	box(shell, "EntranceSill", -6, -1, 46, 6, 0, 48, C.sidewalk, Enum.Material.Concrete)
	box(deco, "MeetingCarpet", -86, 0, -44, -42, 0.06, 3, C.carpet, Enum.Material.Fabric, { collide = false })
	box(deco, "LoungeRug", -76, 0, 16, -50, 0.06, 34, Color3.fromRGB(230, 170, 120), Enum.Material.Fabric, { collide = false })
	box(deco, "OfficeRug", -10, 0, -2, 10, 0.06, 14, Color3.fromRGB(214, 206, 236), Enum.Material.Fabric, { collide = false })
	box(deco, "DoorMat", -5, 0, 40, 5, 0.06, 45.9, C.dark, Enum.Material.Fabric, { collide = false })

	------------------------------------------------------------ outer walls (all one colour, so corners never flicker)
	box(shell, "BackWall", -90, 0, -48, 40, H + 1, -46, C.wall)
	box(shell, "LeftWall", -90, 0, -46, -88, H + 1, 48, C.wall)
	-- lounge front: low wall, window, top wall
	box(shell, "LoungeFrontLow", -88, 0, 46, -40, 3.5, 48, C.wall)
	box(shell, "LoungeFrontTop", -88, 14, 46, -40, H + 1, 48, C.wall)
	box(shell, "LoungeGlass", -88, 3.5, 46.8, -40, 14, 47.2, C.glass, Enum.Material.Glass, { transparency = 0.55 })
	for _, x in ipairs({ -76, -64, -52 }) do
		box(shell, "Mullion", x - 0.3, 3.52, 46.3, x + 0.3, 13.98, 47.7, C.white)
	end
	-- office front: big windows and the entrance (x -6..6, 11 high)
	box(shell, "FrontLowL", -40, 0, 46, -7, 1.2, 48, C.wall)
	box(shell, "FrontLowR", 7, 0, 46, 40, 1.2, 48, C.wall)
	box(shell, "FrontTop", -40, 15, 46, 40, H + 1, 48, C.wall)
	box(shell, "DoorHeader", -6, 11, 46, 6, 15, 48, C.wall)
	box(shell, "FrontGlassL", -40, 1.2, 46.8, -7, 15, 47.2, C.glass, Enum.Material.Glass, { transparency = 0.55 })
	box(shell, "FrontGlassR", 7, 1.2, 46.8, 40, 15, 47.2, C.glass, Enum.Material.Glass, { transparency = 0.55 })
	for _, x in ipairs({ -29, -18, 18, 29 }) do
		box(shell, "Mullion", x - 0.3, 1.22, 46.3, x + 0.3, 14.98, 47.7, C.white)
	end
	box(shell, "DoorPostL", -7, 0, 46, -6, 15, 48, C.white)
	box(shell, "DoorPostR", 6, 0, 46, 7, 15, 48, C.white)
	-- the glass doors stand open (slid to the sides, in front of the glass)
	box(deco, "SlideDoorL", -12, 0.05, 48.1, -6.2, 11, 48.4, C.glass, Enum.Material.Glass, { transparency = 0.45, collide = false })
	box(deco, "SlideDoorR", 6.2, 0.05, 48.1, 12, 11, 48.4, C.glass, Enum.Material.Glass, { transparency = 0.45, collide = false })
	-- roof
	box(shell, "Roof", -90, H + 1, -48, 40, H + 2, 48, C.grey, Enum.Material.Concrete)
	box(shell, "Ceiling", -88, H, -46, 40, H + 1, 46, C.ceiling)

	------------------------------------------------------------ inner walls
	-- meeting room / office: glass with a door (z -16..-8), white frame
	box(shell, "MeetGlassA", -40.2, 0, -46, -39.8, H - 0.02, -16.4, C.glass, Enum.Material.Glass, { transparency = 0.6 })
	box(shell, "MeetGlassB", -40.2, 0, -7.6, -39.8, H - 0.02, 4, C.glass, Enum.Material.Glass, { transparency = 0.6 })
	box(shell, "MeetDoorTop", -40.6, 10, -16, -39.4, H, -8, C.wall)
	for _, z in ipairs({ -36, -26 }) do
		box(shell, "GlassPost", -40.6, 0, z - 0.4, -39.4, H, z + 0.4, C.white)
	end
	box(shell, "DoorFrame", -40.6, 0, -16.8, -39.4, 10, -16, C.white)
	box(shell, "DoorFrame", -40.6, 0, -8, -39.4, 10, -7.2, C.white)
	local ms = box(deco, "MeetingSign", -39.36, 11, -15.4, -39.2, 13, -8.6, C.purple, nil, { collide = false })
	sign(ms, Enum.NormalId.Right, "MEETING ROOM", C.white)
	-- meeting room / lounge
	box(shell, "LoungeWall", -88, 0, 4, -40.6, H, 6, C.wallWarm)
	box(shell, "LoungeWallEnd", -40.6, 0, 4, -39.4, H, 6, C.white)
	-- office / stage hall: wall with the roll-up door (z 2..18, 14 high)
	box(shell, "HallWallA", 40, 0, -46, 42, HH, 2, C.wall)
	box(shell, "HallWallB", 40, 0, 18, 42, HH, 48, C.wall)
	box(shell, "HallWallTop", 40, 14, 2, 42, HH, 18, C.wall)
	box(deco, "HallDoorFrame", 39.6, 14, 1.4, 39.96, 15, 18.6, C.yellow, nil, { collide = false })
	box(deco, "HallDoorPostA", 39.6, 0, 1.4, 39.96, 14, 2, C.yellow, nil, { collide = false })
	box(deco, "HallDoorPostB", 39.6, 0, 18, 39.96, 14, 18.6, C.yellow, nil, { collide = false })
	local hs = box(deco, "HallSign", 39.56, 15.6, 4, 39.96, 17.6, 16, C.dark, nil, { collide = false })
	sign(hs, Enum.NormalId.Left, "STAGE HALL", C.yellow)
	-- stage hall shell (brick warehouse)
	box(shell, "HallBack", 40, 0, -48, 124, HH, -46, C.brick, Enum.Material.Brick)
	box(shell, "HallRight", 122, 0, -46, 124, HH, 48, C.brick, Enum.Material.Brick)
	box(shell, "HallFront", 42, 0, 46, 122, HH, 48, C.brick, Enum.Material.Brick)
	box(shell, "HallRoof", 40, HH, -48, 124, HH + 1, 48, C.grey, Enum.Material.Concrete)
	-- the roll-up door (the client rolls it up once the hall is open)
	local door = new("Model", { Name = "HallDoor" }, stations)
	for i = 0, 13 do
		box(door, "Slat", 40.3, i, 2, 41.7, i + 1, 18, (i % 2 == 0) and Color3.fromRGB(190, 194, 200) or Color3.fromRGB(176, 180, 188), Enum.Material.Metal)
	end
	local doorSign = box(door, "DoorSign", 40.1, 6, 6, 40.26, 8.4, 14, C.yellow, nil, { collide = false })
	sign(doorSign, Enum.NormalId.Left, "STAGE HALL", C.dark)
	door.PrimaryPart = doorSign

	------------------------------------------------------------ light
	for _, x in ipairs({ -26, -10, 10, 26 }) do
		for _, z in ipairs({ -32, -14, 6, 26 }) do
			ceilingLight(deco, Vector3.new(x, H - 0.15, z), 8)
		end
	end
	for _, z in ipairs({ -34, -14, 22 }) do
		ceilingLight(deco, Vector3.new(-64, H - 0.15, z), 12)
	end

	------------------------------------------------------------ spawn
	local spawn = part(root, "Spawn", Vector3.new(6, 0.1, 6), CFrame.lookAt(Hub.SPAWN + Vector3.new(0, 0.1, 0), Hub.SPAWN + Vector3.new(0, 0.1, 10)), C.purple, Enum.Material.SmoothPlastic, { class = "SpawnLocation", collide = false, transparency = 1 })
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.AllowTeamChangeOnTouch = false
	Hub.spawnPart = spawn

	------------------------------------------------------------ OFFICE: boss desk with the laptop
	local dk = new("Model", { Name = "BossDesk" }, stations)
	local dp = Vector3.new(14, 0, -37)
	box(dk, "DeskTop", 6, 3, -40, 22, 3.5, -34, C.wood, Enum.Material.Wood)
	box(dk, "DeskSide", 6.4, 0, -39.6, 7, 3, -34.4, C.white)
	box(dk, "DeskSide", 21, 0, -39.6, 21.6, 3, -34.4, C.white)
	box(dk, "DeskFront", 7, 0.6, -34.7, 21, 3, -34.4, C.purple)
	local laptop = box(dk, "Laptop", 12.5, 3.5, -36.6, 15.5, 3.7, -34.6, C.grey, Enum.Material.Metal)
	part(dk, "LaptopScreen", Vector3.new(3, 2, 0.12), CFrame.new(dp + Vector3.new(0, 4.55, -0.45)) * CFrame.Angles(math.rad(-12), 0, 0), C.grey, Enum.Material.Metal)
	part(dk, "LaptopDisplay", Vector3.new(2.7, 1.7, 0.04), CFrame.new(dp + Vector3.new(0, 4.55, -0.45)) * CFrame.Angles(math.rad(-12), 0, 0) * CFrame.new(0, 0, 0.09), Color3.fromRGB(150, 140, 250), Enum.Material.SmoothPlastic, { collide = false })
	prompt(laptop, "laptop", "Open laptop", "Office", 9)
	for _, mx in ipairs({ -4.5, 4.5 }) do
		box(dk, "MonitorStand", dp.X + mx - 0.2, 3.5, -39.2, dp.X + mx + 0.2, 4.6, -38.8, C.dark)
		box(dk, "Monitor", dp.X + mx - 2, 4.6, -39.3, dp.X + mx + 2, 7, -39.05, C.dark)
		box(dk, "MonitorImage", dp.X + mx - 1.8, 4.75, -39.05, dp.X + mx + 1.8, 6.85, -39.0, (mx > 0) and Color3.fromRGB(110, 200, 190) or Color3.fromRGB(240, 150, 190), nil, { collide = false })
	end
	chair(dk, dp + Vector3.new(0, 0, -6.2), math.pi, C.purple)
	box(dk, "Lamp", 20.85, 3.5, -35.75, 21.15, 5.6, -35.45, C.dark)
	part(dk, "LampShade", Vector3.new(1.2, 0.9, 1.2), Vector3.new(21, 6.05, -35.6), C.yellow, Enum.Material.SmoothPlastic, { collide = false })
	-- painted accent wall behind the desk + shelves + label logo
	box(deco, "AccentWall", 2, 0, -46, 26, H, -45.94, C.purple)
	shelf(deco, 4, -45.94, 13, 6, 2, 1)
	shelf(deco, 15, -45.94, 24, 6, 2, 1)
	local logo = box(deco, "LogoBoard", 5, 13.2, -45.9, 23, 16.8, -45.7, C.white, nil, { collide = false })
	sign(logo, Enum.NormalId.Back, "STARLIGHT RECORDS", C.purple).Name = "LabelSign"
	record(deco, Vector3.new(30, 9, -45.74), 0, true)
	record(deco, Vector3.new(35.5, 9, -45.74), 0, false)
	record(deco, Vector3.new(-3, 9, -45.74), 0, true)

	------------------------------------------------------------ OFFICE: the world map table (centre)
	local mt = new("Model", { Name = "MapTable" }, stations)
	box(mt, "TableLegs", -8, 0, 2, 8, 2.6, 10, C.white)
	box(mt, "TableTop", -12, 2.6, -1, 12, 3.1, 13, C.wood, Enum.Material.Wood)
	local mapTop = box(mt, "MapSurface", -11, 3.1, 0.5, 11, 3.2, 11.5, Color3.fromRGB(70, 130, 190), Enum.Material.SmoothPlastic)
	prompt(mapTop, "maptable", "Plan a tour", "World Map", 11)
	local mapSign = box(mt, "MapSign", -5, 0.6, 1.92, 5, 2.2, 1.96, C.purple, nil, { collide = false })
	sign(mapSign, Enum.NormalId.Front, "PLAN A TOUR", C.white)
	for i, p in ipairs({ { -14.5, 3 }, { 14.5, 3 }, { -14.5, 9 }, { 14.5, 9 } }) do
		local yaw = (p[1] < 0) and -math.pi / 2 or math.pi / 2
		local _ = i
		chair(mt, Vector3.new(p[1], 0, p[2]), yaw, C.teal)
	end

	------------------------------------------------------------ OFFICE: charts TV (back wall, left)
	local cw = new("Model", { Name = "ChartsWall" }, stations)
	box(cw, "ChartsFrame", -33, 2.5, -45.9, -7, 15.5, -45.5, C.dark)
	local chartsScreen = box(cw, "ChartsScreen", -32.3, 3.2, -45.5, -7.7, 14.8, -45.3, C.screen)
	prompt(chartsScreen, "charts", "View charts", "Charts", 16)
	box(cw, "ChartsShelf", -30, 0, -45.9, -10, 2.2, -43, C.white)
	for i = 0, 3 do
		box(cw, "Trophy", -27 + i * 4.5, 2.2, -44.8, -26 + i * 4.5, 4 + (i % 2) * 0.8, -43.8, C.yellow, Enum.Material.Metal, { collide = false })
	end

	------------------------------------------------------------ OFFICE: staff desks (people work here)
	local staff = new("Folder", { Name = "StaffDesks" }, deco)
	for _, st in ipairs(Hub.STAFF) do
		if st.desk then
			desk(staff, st.pos + Vector3.new(0, 0, -2.6), 0, true)
			chair(staff, st.pos, 0, C.dark)
		end
	end
	for _, z in ipairs({ -20.2, -8.2 }) do
		box(staff, "Divider", 20, 0, z - 0.2, 36, 5.2, z, C.teal)
	end
	chair(deco, Vector3.new(-22, 0, 25.2), math.pi, C.coral)
	plant(deco, Vector3.new(36, 0, -24), true)
	plant(deco, Vector3.new(36, 0, 6), false)

	------------------------------------------------------------ OFFICE: coffee bar (front right)
	local cb = new("Folder", { Name = "CoffeeBar" }, deco)
	box(cb, "Counter", 24, 0, 30, 38, 3.6, 34, C.white)
	box(cb, "CounterTop", 23.8, 3.6, 29.8, 38.2, 3.9, 34.2, C.woodDark, Enum.Material.Wood)
	box(cb, "CounterFront", 24, 0.6, 29.76, 38, 3.2, 29.8, C.coral, nil, { collide = false })
	box(cb, "CoffeeMachine", 33, 3.9, 31, 36, 6.4, 33.4, C.dark, Enum.Material.Metal)
	box(cb, "Fridge", 36, 0, 38, 39.9, 9, 44, C.white, Enum.Material.Metal)
	for k = 0, 2 do
		part(cb, "Cup", Vector3.new(0.5, 0.6, 0.5), Vector3.new(26 + k * 2, 4.2, 32), (k % 2 == 0) and C.teal or C.yellow, nil, { collide = false })
		local sx = 26 + k * 4.4
		part(cb, "StoolSeat", Vector3.new(0.6, 2, 2), CFrame.new(Vector3.new(sx, 3, 27.4)) * CFrame.Angles(0, 0, math.pi / 2), C.yellow, nil, { shape = Enum.PartType.Cylinder })
		box(cb, "StoolLeg", sx - 0.2, 0, 27.2, sx + 0.2, 2.7, 27.6, C.dark, Enum.Material.Metal)
	end

	------------------------------------------------------------ OFFICE: reception (front left)
	box(deco, "Reception", -30, 0, 28, -14, 3.6, 31, C.white)
	box(deco, "ReceptionTop", -30.3, 3.6, 27.7, -13.7, 3.9, 31.3, C.wood, Enum.Material.Wood)
	local rl = box(deco, "ReceptionLogo", -28, 1.2, 31.04, -16, 3, 31.08, C.purple, nil, { collide = false })
	sign(rl, Enum.NormalId.Back, "STARLIGHT RECORDS", C.white).Name = "LabelSign"
	plant(deco, Vector3.new(-36, 0, 42), true)
	plant(deco, Vector3.new(-10, 0, 42), false)
	plant(deco, Vector3.new(10, 0, 42), false)
	plant(deco, Vector3.new(-36, 0, -42), true)
	-- waiting sofa
	sofa(deco, Vector3.new(-31, 0, 14), -math.pi / 2, C.teal, 12)

	------------------------------------------------------------ posters of the label's artists (filled by the client)
	poster(deco, Vector3.new(39.86, 9, -40), Enum.NormalId.Left, 7, 10)
	poster(deco, Vector3.new(39.86, 9, -30), Enum.NormalId.Left, 7, 10)
	poster(deco, Vector3.new(39.86, 9, 26), Enum.NormalId.Left, 7, 10)

	------------------------------------------------------------ MEETING ROOM: table, seats, board
	local mr = new("Model", { Name = "Meeting" }, stations)
	local mc = Vector3.new(-63, 0, -24)
	box(mr, "MeetTable", mc.X - 4.5, 3, mc.Z - 10, mc.X + 4.5, 3.5, mc.Z + 10, C.wood, Enum.Material.Wood)
	part(mr, "MeetTableEnd", Vector3.new(0.5, 9, 9), CFrame.new(mc + Vector3.new(0, 3.25, -10)) * CFrame.Angles(0, 0, math.pi / 2), C.wood, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	part(mr, "MeetTableEnd", Vector3.new(0.5, 9, 9), CFrame.new(mc + Vector3.new(0, 3.25, 10)) * CFrame.Angles(0, 0, math.pi / 2), C.wood, Enum.Material.Wood, { shape = Enum.PartType.Cylinder })
	box(mr, "MeetTableLeg", mc.X - 1.5, 0, mc.Z - 7, mc.X + 1.5, 3, mc.Z + 7, C.white)
	local seats = new("Folder", { Name = "Seats" }, mr)
	local seatSpots = {}
	for _, z in ipairs({ -6, 0, 6 }) do
		table.insert(seatSpots, { mc + Vector3.new(-6.6, 0, z), mc + Vector3.new(0, 0, z) })
		table.insert(seatSpots, { mc + Vector3.new(6.6, 0, z), mc + Vector3.new(0, 0, z) })
	end
	table.insert(seatSpots, { mc + Vector3.new(0, 0, 17), mc + Vector3.new(0, 0, -10) })
	for i, sp in ipairs(seatSpots) do
		local pos, at = sp[1], sp[2]
		local look = CFrame.lookAt(pos + Vector3.new(0, 1.8, 0), Vector3.new(at.X, 1.8, at.Z))
		local seat = part(seats, "MeetingSeat" .. i, Vector3.new(2.8, 0.6, 2.8), look, (i % 2 == 0) and C.purple or C.teal, Enum.Material.Fabric, { class = "Seat", touch = true })
		seat:SetAttribute("Meeting", true)
		part(mr, "SeatBack", Vector3.new(2.8, 3.2, 0.5), look * CFrame.new(0, 1.9, 1.35), C.white)
		part(mr, "SeatPole", Vector3.new(0.4, 1.5, 0.4), look * CFrame.new(0, -1.05, 0), C.grey, Enum.Material.Metal)
		part(mr, "SeatFoot", Vector3.new(2.2, 0.15, 2.2), look * CFrame.new(0, -1.725, 0), C.grey, Enum.Material.Metal)
	end
	-- the big screen on the back wall (the client draws roster + talent on it)
	box(mr, "BoardFrame", -79, 2, -45.9, -47, 17, -45.5, C.dark)
	box(mr, "Board", -78.3, 2.7, -45.5, -47.7, 16.3, -45.3, C.screen)
	prompt(part(mr, "MeetPromptSpot", Vector3.new(1, 1, 1), mc + Vector3.new(0, 4, 0), C.white, nil, { collide = false, transparency = 1 }), "meeting", "Start meeting", "Meeting Room", 18)
	-- whiteboard, plants
	local wb = box(deco, "Whiteboard", -87.94, 5, -36, -87.8, 12, -20, C.white, nil, { collide = false })
	sign(wb, Enum.NormalId.Right, "TOUR IDEAS:  bigger venues  ·  new stage  ·  sign a star", Color3.fromRGB(60, 80, 160), Enum.Font.GothamBold)
	plant(deco, Vector3.new(-85, 0, -42), true)
	plant(deco, Vector3.new(-44, 0, -42), false)
	plant(deco, Vector3.new(-85, 0, 0), false)

	------------------------------------------------------------ LOUNGE: sofas, ping pong, arcade, records
	sofa(deco, Vector3.new(-63, 0, 38), 0, C.coral, 14)
	sofa(deco, Vector3.new(-80, 0, 25), -math.pi / 2, C.purple, 10)
	box(deco, "LoungeTable", -68, 0, 22, -58, 1.6, 28, C.wood, Enum.Material.Wood)
	-- ping pong table
	box(deco, "PingPong", -56, 2.6, 8.5, -44, 3, 15.5, Color3.fromRGB(40, 110, 90))
	box(deco, "PingPongLine", -56, 3, 11.95, -44, 3.04, 12.05, C.white, nil, { collide = false })
	box(deco, "PingPongNet", -50.1, 3, 8.5, -49.9, 3.8, 15.5, C.white, nil, { collide = false })
	box(deco, "PingPongLegs", -54, 0, 10, -46, 2.6, 14, C.dark, Enum.Material.Metal)
	-- arcade + vending machine
	box(deco, "Arcade", -87.9, 0, 8, -84, 7, 12, C.purple)
	box(deco, "ArcadeScreen", -84, 4, 8.6, -83.96, 6.4, 11.4, C.teal, nil, { collide = false })
	box(deco, "Vending", -47, 0, 40.5, -41.5, 9, 45.9, C.coral)
	box(deco, "VendingGlass", -46.6, 2, 40.46, -42.4, 8, 40.5, C.glass, Enum.Material.Glass, { collide = false })
	for i, z in ipairs({ 14, 22, 30, 38 }) do
		record(deco, Vector3.new(-87.74, 9, z), math.pi / 2, i % 2 == 0)
	end
	-- beanbags
	for i, p in ipairs({ { -72, 30 }, { -54, 30 } }) do
		part(deco, "Beanbag", Vector3.new(4, 3, 4), Vector3.new(p[1], 1.5, p[2]), (i == 1) and C.teal or C.yellow, Enum.Material.Fabric, { shape = Enum.PartType.Ball })
	end
	poster(deco, Vector3.new(-78, 9, 6.14), Enum.NormalId.Back, 7, 10)
	poster(deco, Vector3.new(-63, 9, 6.14), Enum.NormalId.Back, 7, 10)
	poster(deco, Vector3.new(-48, 9, 6.14), Enum.NormalId.Back, 7, 10)
	plant(deco, Vector3.new(-85, 0, 44), true)

	------------------------------------------------------------ STAGE HALL: rehearsal stage + build console
	local hall = new("Model", { Name = "Hall" }, stations)
	box(hall, "RehearsalDeck", 72, 0, -42, 112, 4, -22, Color3.fromRGB(40, 40, 46))
	box(hall, "DeckEdge", 72, 3.6, -21.98, 112, 4, -21.94, C.yellow, nil, { collide = false })
	box(hall, "LedWall", 76, 4, -42, 108, 19, -41, C.screen)
	local ledText = box(hall, "LedText", 77, 9, -41, 107, 15, -40.96, C.screen, nil, { collide = false })
	sign(ledText, Enum.NormalId.Back, "STARLIGHT RECORDS", C.purple).Name = "LabelSign"
	for _, x in ipairs({ 70, 114 }) do
		box(hall, "TrussTower", x - 1, 0, -37, x + 1, 26, -35, C.grey, Enum.Material.DiamondPlate)
	end
	box(hall, "Speaker", 74.5, 4, -32, 78.5, 12, -28, C.dark)
	box(hall, "Speaker", 105.5, 4, -32, 109.5, 12, -28, C.dark)
	box(hall, "TrussTop", 69, 26, -37, 115, 28, -35, C.grey, Enum.Material.DiamondPlate)
	for i = 0, 5 do
		local lx = 74 + i * 7
		local lamp = box(hall, "MovingHead", lx - 0.8, 24, -36.8, lx + 0.8, 26, -35.2, C.dark)
		box(hall, "Lens", lx - 0.5, 23.9, -36.5, lx + 0.5, 24, -35.5, (i % 2 == 0) and C.purple or C.teal, Enum.Material.Neon, { collide = false })
		if i % 2 == 0 then
			new("SpotLight", { Face = Enum.NormalId.Bottom, Range = 40, Angle = 40, Brightness = 1.5, Color = (i % 4 == 0) and C.purple or C.teal, Shadows = false }, lamp)
		end
	end
	for i = 0, 4 do
		local x = 112 - (i % 3) * 6
		local y = math.floor(i / 3) * 4
		box(hall, "RoadCase", x - 2.5, y, 28, x + 2.5, y + 4, 32, (i % 2 == 0) and Color3.fromRGB(40, 40, 46) or Color3.fromRGB(60, 60, 68), Enum.Material.DiamondPlate)
	end
	-- the build console (opens My Stages / the stage builder)
	local cp = Vector3.new(58, 0, -24)
	box(hall, "Console", cp.X - 5, 0, cp.Z - 2, cp.X + 5, 3.4, cp.Z + 2, C.white)
	local consoleTop = part(hall, "ConsoleTop", Vector3.new(10.4, 0.4, 4.6), CFrame.new(cp + Vector3.new(0, 3.7, 0)) * CFrame.Angles(math.rad(-10), 0, 0), C.dark, Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		part(hall, "ConsoleScreen", Vector3.new(3, 2, 0.2), CFrame.new(cp + Vector3.new(i * 3.2, 5.6, -1.7)) * CFrame.Angles(0, i * -0.25, 0), (i == 0) and Color3.fromRGB(110, 200, 190) or Color3.fromRGB(160, 150, 240), Enum.Material.SmoothPlastic, { collide = false })
	end
	prompt(consoleTop, "stagehall", "Build stages", "Stage Hall", 10)
	box(hall, "FloorTape", 48, 0, -12, 116, 0.04, -11.6, C.yellow, nil, { collide = false })
	for _, z in ipairs({ -20, 10, 36 }) do
		for _, x in ipairs({ 60, 100 }) do
			local l = box(hall, "HallLamp", x - 4, HH - 1.4, z - 1, x + 4, HH - 1, z + 1, C.lamp, Enum.Material.Neon, { collide = false })
			new("SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 36, Brightness = 1, Angle = 110, Shadows = false }, l)
		end
	end

	------------------------------------------------------------ OUTSIDE: one short street, closed at both ends
	-- sidewalk in front of the label, the road, the sidewalk across, the shops
	box(out, "Sidewalk", -150, -1, 48, 190, 0, 62, C.sidewalk, Enum.Material.Concrete)
	box(out, "Curb", -150, -1, 62, 190, 0.02, 63, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	box(out, "Road", -150, -1.5, 63, 190, -0.5, 89, C.asphalt, Enum.Material.Asphalt)
	box(out, "CurbFar", -150, -1, 89, 190, 0.02, 90, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	box(out, "SidewalkFar", -150, -1, 90, 190, 0, 104, C.sidewalk, Enum.Material.Concrete)
	for x = -140, 180, 16 do
		if x + 8 < -9 or x > 9 then
			box(out, "LaneMark", x, -0.5, 75.75, x + 8, -0.46, 76.25, C.white, nil, { collide = false })
		end
	end
	for i = 0, 6 do
		box(out, "Crosswalk", -7 + i * 2.2, -0.5, 64, -5.6 + i * 2.2, -0.46, 88, C.white, nil, { collide = false })
	end
	-- the street is closed by buildings at both ends (and the label's neighbours)
	box(out, "EndWest", -170, -1, -60, -150, 70, 150, Color3.fromRGB(200, 170, 140), Enum.Material.Brick)
	box(out, "EndEast", 190, -1, -60, 210, 80, 150, Color3.fromRGB(176, 186, 200), Enum.Material.Concrete)
	box(out, "NeighbourWest", -150, -1, -60, -90, 54, 48, Color3.fromRGB(212, 186, 150), Enum.Material.Brick)
	box(out, "NeighbourEast", 124, -1, -60, 190, 64, 48, Color3.fromRGB(190, 200, 214), Enum.Material.Concrete)
	for _, nb in ipairs({ { -150, -90, 54 }, { 124, 190, 64 } }) do
		for fl = 0, math.floor((nb[3] - 8) / 10) do
			for k = 0, math.floor((nb[2] - nb[1] - 8) / 9) do
				local wx, wy = nb[1] + 5 + k * 9, 6 + fl * 10
				local underBillboard = nb[1] > 0 and wx + 5 > 130 and wx < 184 and wy + 6 > 24 and wy < 54
				if not underBillboard then
					box(out, "Window", nb[1] + 5 + k * 9, 6 + fl * 10, 48.06, nb[1] + 10 + k * 9, 12 + fl * 10, 48.3, Color3.fromRGB(170, 196, 220), Enum.Material.Glass)
				end
			end
		end
	end
	-- the facade of the label: canopy over the door and the big name sign
	box(out, "Canopy", -12, 15.2, 48, 12, 15.8, 54, C.white)
	local facade = box(out, "FacadeSign", -30, H + 2.4, 48.04, 30, H + 7.6, 48.6, C.purple)
	sign(facade, Enum.NormalId.Back, "STARLIGHT RECORDS", C.white).Name = "LabelSign"
	box(out, "FacadeSignBack", -30, H + 2, 46, 30, H + 8, 48.04, C.wall)
	-- (stands on the roof: the roof top is at H + 2)
	-- shops across the street
	shop(out, -150, -108, 48, Color3.fromRGB(226, 200, 170), "BAKERY", C.coral, C.coral)
	shop(out, -108, -60, 40, Color3.fromRGB(240, 214, 200), "MOONBEAM CAFE", C.purple, C.purple)
	shop(out, -60, -18, 56, Color3.fromRGB(200, 214, 230), "VINYL VAULT", Color3.fromRGB(40, 90, 160), C.teal)
	shop(out, -18, 24, 44, Color3.fromRGB(236, 224, 190), "AMP CITY", C.coral, C.yellow)
	shop(out, 24, 66, 52, Color3.fromRGB(214, 226, 206), "SLICE PIZZA", Color3.fromRGB(200, 60, 50), Color3.fromRGB(200, 60, 50))
	shop(out, 66, 120, 60, Color3.fromRGB(228, 210, 226), "BACKSTAGE BAR", C.purple, C.purple)
	shop(out, 120, 190, 46, Color3.fromRGB(222, 206, 184), "GUITAR & CO", Color3.fromRGB(120, 70, 40), C.teal)
	-- cafe tables on the far sidewalk
	for i, x in ipairs({ -100, -88, -76 }) do
		box(out, "CafeTable", x - 1.6, 2.6, 96.4, x + 1.6, 2.9, 99.6, C.white)
		box(out, "CafeTableLeg", x - 0.2, 0, 97.8, x + 0.2, 2.6, 98.2, C.dark, Enum.Material.Metal)
		box(out, "UmbrellaPole", x - 0.15, 2.9, 97.85, x + 0.15, 9, 98.15, C.white)
		part(out, "Umbrella", Vector3.new(0.6, 8, 8), CFrame.new(Vector3.new(x, 9.2, 98)) * CFrame.Angles(0, 0, math.pi / 2), (i % 2 == 0) and C.purple or C.coral, Enum.Material.Fabric, { shape = Enum.PartType.Cylinder, collide = false })
	end
	for _, st in ipairs(Hub.SITTERS) do
		if not st.sofa then
			chair(out, st.pos, st.yaw + math.pi, C.white)
		end
	end
	-- trees, benches, lamps, bus stop, parked cars, the tour bus
	for _, x in ipairs({ -130, -96, -54, 28, 70, 140, 176 }) do
		tree(out, Vector3.new(x, 0, 58))
	end
	for _, x in ipairs({ -130, -40, 40, 100, 160 }) do
		tree(out, Vector3.new(x, 0, 94))
	end
	for _, x in ipairs({ -110, -20, 54, 120, 170 }) do
		streetLamp(out, Vector3.new(x, 0, 60.5), 1)
	end
	bench(out, Vector3.new(-74, 0, 52), math.pi)
	bench(out, Vector3.new(148, 0, 52), math.pi)
	-- bus stop with a poster
	box(out, "BusStopRoof", -46, 10, 50, -30, 10.4, 56, C.white)
	box(out, "BusStopPost", -45.7, 0, 50.3, -45.3, 10, 50.7, C.grey, Enum.Material.Metal)
	box(out, "BusStopPost", -30.7, 0, 50.3, -30.3, 10, 50.7, C.grey, Enum.Material.Metal)
	box(out, "BusStopBack", -45.3, 1, 50.3, -30.7, 9, 50.6, C.glass, Enum.Material.Glass, { transparency = 0.5 })
	bench(out, Vector3.new(-38, 0, 52.4), math.pi)
	poster(out, Vector3.new(-38, 5, 50.2), Enum.NormalId.Front, 6, 7.6)
	-- billboard on the eastern neighbour (big poster)
	box(out, "BillboardFrame", 132, 26, 48.06, 182, 52, 48.6, C.dark)
	poster(out, Vector3.new(157, 39, 48.72), Enum.NormalId.Back, 48, 24)
	car(out, Vector3.new(-120, -0.5, 67), 0, Color3.fromRGB(210, 70, 70))
	car(out, Vector3.new(-80, -0.5, 67), 0, Color3.fromRGB(70, 120, 210))
	car(out, Vector3.new(110, -0.5, 85), math.pi, Color3.fromRGB(240, 210, 90))
	car(out, Vector3.new(150, -0.5, 85), math.pi, Color3.fromRGB(240, 240, 240))
	-- the tour bus in front of the stage hall
	local bp = Vector3.new(80, -0.5, 69)
	box(out, "BusBody", bp.X - 20, bp.Y + 1.2, bp.Z - 4.5, bp.X + 20, bp.Y + 12, bp.Z + 4.5, C.white)
	box(out, "BusStripe", bp.X - 20.04, bp.Y + 3.4, bp.Z - 4.54, bp.X + 20.04, bp.Y + 5, bp.Z + 4.54, C.purple, nil, { collide = false })
	box(out, "BusWindows", bp.X - 18, bp.Y + 6.6, bp.Z - 4.56, bp.X + 18, bp.Y + 9.6, bp.Z + 4.56, Color3.fromRGB(70, 90, 120), Enum.Material.Glass, { collide = false })
	local busName = box(out, "BusName", bp.X - 14, bp.Y + 9.8, bp.Z - 4.6, bp.X + 14, bp.Y + 11.6, bp.Z - 4.56, C.white, nil, { collide = false })
	sign(busName, Enum.NormalId.Front, "STARLIGHT RECORDS ON TOUR", C.purple).Name = "LabelSign"
	for _, wx in ipairs({ -14, 12, 16 }) do
		for _, wz in ipairs({ -4.6, 4.6 }) do
			part(out, "Wheel", Vector3.new(1.2, 3.6, 3.6), CFrame.new(bp + Vector3.new(wx, 1.6, wz)) * CFrame.Angles(0, math.pi / 2, 0), C.dark, nil, { shape = Enum.PartType.Cylinder })
		end
	end
	-- invisible walls: nobody walks out of the street or onto the roofs
	box(out, "Boundary", -150, -1, 48, -149, 60, 104, C.white, nil, { transparency = 1 })
	box(out, "Boundary", 189, -1, 48, 190, 60, 104, C.white, nil, { transparency = 1 })
	box(out, "Boundary", -150, 40, 48, 190, 41, 104, C.white, nil, { transparency = 1 })

	local _sp = spots
	return root
end

return Hub
