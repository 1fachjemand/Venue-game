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
	{ pos = Vector3.new(24, 0, -14.2), yaw = math.pi, desk = Vector3.new(24, 0, -18), seatY = 2.3 },
	{ pos = Vector3.new(32, 0, -14.2), yaw = math.pi, desk = Vector3.new(32, 0, -18), seatY = 2.3 },
	{ pos = Vector3.new(24, 0, -2.2), yaw = math.pi, desk = Vector3.new(24, 0, -6), seatY = 2.3 },
	{ pos = Vector3.new(32, 0, -2.2), yaw = math.pi, desk = Vector3.new(32, 0, -6), seatY = 2.3 },
	{ pos = Vector3.new(-22, 0, 25.2), yaw = 0, seatY = 2.3 }, -- reception
}
-- the street: straight from XW to XE, bends away around the corners CW / CE (radius 20 inner sidewalk .. 76)
Hub.STREET = { xw = -130, xe = 170, cw = Vector3.new(-130, 0, 124), ce = Vector3.new(170, 0, 124), laneEast = 80, laneWest = 74.5 }
-- walking paths stay in the free lanes of the sidewalks (trees, lamps, benches and tables are elsewhere)
Hub.WALKS = {
	{ Vector3.new(-124, 0, 52.4), Vector3.new(164, 0, 52.4) },
	{ Vector3.new(164, 0, 55.2), Vector3.new(-124, 0, 55.2) },
	{ Vector3.new(-124, 0, 96), Vector3.new(164, 0, 96) },
	{ Vector3.new(164, 0, 98.2), Vector3.new(-124, 0, 98.2) },
	{ Vector3.new(-6, 0, 22), Vector3.new(28, 0, 22), Vector3.new(28, 0, 25.4) }, -- office: to the coffee bar
	{ Vector3.new(-70, 0, 12.5), Vector3.new(-62, 0, 18), Vector3.new(-48, 0, 19.5) }, -- lounge
}
Hub.CAFE_TABLES = { -84, -72, -60 }
Hub.SITTERS = {
	{ pos = Vector3.new(-63, 0, 36.9), yaw = math.pi, seatY = 2.4 }, -- lounge sofa
	{ pos = Vector3.new(-40, 0, 58.4), yaw = 0, seatY = 2.1 }, -- bus stop
}
for i, x in ipairs(Hub.CAFE_TABLES) do
	table.insert(Hub.SITTERS, { pos = Vector3.new(x - 2.9, 0, 101.8), yaw = math.pi / 2, seatY = 2.3, kind = "chair" })
	if i ~= 2 then
		table.insert(Hub.SITTERS, { pos = Vector3.new(x + 2.9, 0, 101.8), yaw = -math.pi / 2, seatY = 2.3, kind = "chair" })
	end
end

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

-- a shop across the street: own front, shop window with a room behind it (you look into it),
-- door, sign, maybe an awning, upper floors with windows and balconies
local SHOP_Z = 104 -- facade line
local function shop(parent, x0, x1, o)
	local h, col, mat = o.h, o.color, o.mat or Enum.Material.SmoothPlastic
	local z0, depth = SHOP_Z, 12 -- the shop room is 12 deep
	local inner = Color3.fromRGB(236, 230, 220)
	-- the building above and behind the shop room
	box(parent, "ShopUpper", x0, 12, z0, x1, h, 150, col, mat)
	box(parent, "ShopBack", x0, -0.5, z0 + depth, x1, 12, 150, col, mat)
	box(parent, "ShopCornice", x0, h, z0 - 0.6, x1, h + 1, z0 + 8, C.white)
	-- the room: floor, side walls, back wall, ceiling light
	box(parent, "ShopFloor", x0 + 0.6, -0.5, z0 + 0.6, x1 - 0.6, 0.1, z0 + depth, Color3.fromRGB(196, 170, 140), Enum.Material.WoodPlanks)
	box(parent, "ShopSide", x0, -0.5, z0 + 0.6, x0 + 0.6, 12, z0 + depth, inner)
	box(parent, "ShopSide", x1 - 0.6, -0.5, z0 + 0.6, x1, 12, z0 + depth, inner)
	box(parent, "ShopBackWall", x0 + 0.6, 0.1, z0 + depth - 0.06, x1 - 0.6, 12, z0 + depth, inner)
	local lamp = box(parent, "ShopLamp", (x0 + x1) / 2 - 4, 11.6, z0 + 4, (x0 + x1) / 2 + 4, 11.9, z0 + 6, C.lamp, Enum.Material.Neon, { collide = false })
	new("PointLight", { Range = 16, Brightness = 0.8, Color = Color3.fromRGB(255, 236, 210), Shadows = false }, lamp)
	-- ground floor front: piers, sill, lintel, glass, door
	local doorX = x1 - 7
	box(parent, "ShopPier", x0, 0, z0, x0 + 2, 12, z0 + 0.6, col, mat)
	box(parent, "ShopPier", x1 - 2, 0, z0, x1, 12, z0 + 0.6, col, mat)
	box(parent, "ShopPier", doorX - 1, 0, z0, doorX, 9.6, z0 + 0.6, col, mat)
	box(parent, "ShopSill", x0 + 2, 0, z0, doorX - 1, 1.4, z0 + 0.6, col, mat)
	box(parent, "ShopLintel", x0 + 2, 9.6, z0, x1 - 2, 12, z0 + 0.6, col, mat)
	box(parent, "ShopGlass", x0 + 2, 1.4, z0 + 0.2, doorX - 1, 9.6, z0 + 0.4, C.glass, Enum.Material.Glass, { transparency = 0.55 })
	box(parent, "ShopDoorTop", doorX, 8.6, z0, x1 - 2, 9.6, z0 + 0.6, col, mat)
	box(parent, "ShopDoor", doorX, 0, z0 + 0.15, x1 - 2, 8.6, z0 + 0.45, C.woodDark, Enum.Material.Wood)
	box(parent, "ShopDoorGlass", doorX + 1, 3, z0 + 0.1, x1 - 3, 7.6, z0 + 0.15, C.glass, Enum.Material.Glass)
	box(parent, "DoorHandle", doorX + 0.6, 4, z0 - 0.15, doorX + 0.8, 5.4, z0 + 0.1, C.grey, Enum.Material.Metal)
	-- name board over the window
	local s = box(parent, "ShopSign", x0 + 2.5, 12.4, z0 - 0.5, x1 - 2.5, 14.6, z0 - 0.06, C.white)
	sign(s, Enum.NormalId.Front, o.name, o.signColor)
	if o.awning then
		for k = 0, math.floor((doorX - 1 - x0 - 2) / 2) - 1 do
			part(parent, "Awning", Vector3.new(1.96, 0.3, 4.6), CFrame.new(Vector3.new(x0 + 3.1 + k * 2, 10.6, z0 - 2.1)) * CFrame.Angles(math.rad(-20), 0, 0), (k % 2 == 0) and o.awning or C.white, Enum.Material.Fabric, { collide = false })
		end
	end
	-- upper floors: windows with sills, sometimes a balcony
	local floors = math.floor((h - 16) / 9)
	for fl = 0, floors - 1 do
		local y = 17 + fl * 9
		for k = 0, math.floor((x1 - x0 - 6) / 8) - 1 do
			local wx = x0 + 4 + k * 8
			box(parent, "Window", wx, y, z0 - 0.3, wx + 4.5, y + 5, z0 - 0.06, Color3.fromRGB(170, 196, 220), Enum.Material.Glass)
			box(parent, "WindowSill", wx - 0.3, y - 0.5, z0 - 0.7, wx + 4.8, y - 0.1, z0 - 0.06, C.white)
			if o.balcony and fl == 0 and k % 2 == 1 then
				box(parent, "BalconySlab", wx - 1, y - 0.9, z0 - 3, wx + 5.5, y - 0.5, z0 - 0.06, C.white)
				box(parent, "BalconyRail", wx - 1, y + 2.4, z0 - 3, wx + 5.5, y + 2.7, z0 - 2.8, C.dark, Enum.Material.Metal, { collide = false })
				for bx = wx - 0.9, wx + 5.4, 1.3 do
					box(parent, "BalconyBar", bx, y - 0.5, z0 - 2.98, bx + 0.12, y + 2.4, z0 - 2.86, C.dark, Enum.Material.Metal, { collide = false })
				end
				part(parent, "BalconyPlant", Vector3.new(1.6, 1.6, 1.6), Vector3.new(wx + 4.6, y + 0.3, z0 - 1.4), C.plant, Enum.Material.Grass, { shape = Enum.PartType.Ball, collide = false })
			end
		end
	end
	-- inside (seen through the shop window)
	local cx, iz = (x0 + x1) / 2, z0 + depth
	local kind = o.kind
	if kind == "pizza" then
		box(parent, "Oven", cx - 5, 0.1, iz - 4, cx + 5, 8, iz - 0.06, Color3.fromRGB(170, 90, 60), Enum.Material.Brick)
		box(parent, "OvenMouth", cx - 2.5, 3, iz - 4.04, cx + 2.5, 5.5, iz - 4, Color3.fromRGB(30, 20, 16), nil, { collide = false })
		local fire = box(parent, "OvenFire", cx - 1.5, 3.1, iz - 4.08, cx + 1.5, 4.2, iz - 4.04, Color3.fromRGB(255, 140, 40), Enum.Material.Neon, { collide = false })
		new("PointLight", { Range = 10, Brightness = 1, Color = Color3.fromRGB(255, 150, 60), Shadows = false }, fire)
		for i, tx in ipairs({ x0 + 7, x0 + 17 }) do
			box(parent, "PizzaTable", tx - 2, 2.8, z0 + 3, tx + 2, 3.1, z0 + 6.5, (i == 1) and Color3.fromRGB(200, 60, 50) or C.white)
			box(parent, "PizzaTableLeg", tx - 0.2, 0.1, z0 + 4.55, tx + 0.2, 2.8, z0 + 4.95, C.dark)
			chair(parent, Vector3.new(tx - 3.4, 0.1, z0 + 4.75), math.pi / 2, Color3.fromRGB(46, 140, 70))
			chair(parent, Vector3.new(tx + 3.4, 0.1, z0 + 4.75), -math.pi / 2, Color3.fromRGB(46, 140, 70))
			part(parent, "Pizza", Vector3.new(0.12, 2.4, 2.4), CFrame.new(Vector3.new(tx, 3.16, z0 + 4.75)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(240, 170, 70), nil, { shape = Enum.PartType.Cylinder, collide = false })
		end
		-- a big round pizza sign sticking out over the sidewalk
		box(parent, "PizzaSignArm", x1 - 4.2, 18.6, z0 - 5, x1 - 3.8, 19, z0 - 0.06, C.dark, Enum.Material.Metal)
		part(parent, "PizzaSign", Vector3.new(0.5, 6, 6), CFrame.new(Vector3.new(x1 - 4, 15, z0 - 3.4)), Color3.fromRGB(240, 170, 70), nil, { shape = Enum.PartType.Cylinder, collide = false })
		part(parent, "PizzaCrust", Vector3.new(0.4, 6.6, 6.6), CFrame.new(Vector3.new(x1 - 4, 15, z0 - 3.4)), Color3.fromRGB(196, 120, 50), nil, { shape = Enum.PartType.Cylinder, collide = false })
		for k = 0, 5 do
			local a = k * 1.05
			part(parent, "Pepperoni", Vector3.new(0.6, 1, 1), CFrame.new(Vector3.new(x1 - 4, 15 + math.sin(a) * 1.7, z0 - 3.4 + math.cos(a) * 1.7)), Color3.fromRGB(200, 40, 40), nil, { shape = Enum.PartType.Cylinder, collide = false })
		end
	elseif kind == "cafe" then
		box(parent, "Counter", x0 + 3, 0.1, iz - 4, x1 - 9, 3.6, iz - 1.5, C.wood, Enum.Material.Wood)
		box(parent, "CoffeeMachine", x0 + 5, 3.6, iz - 3.4, x0 + 8, 6, iz - 1.8, C.dark, Enum.Material.Metal)
		for k = 0, 3 do
			box(parent, "CakeStand", x0 + 12 + k * 3.2, 3.6, iz - 3.2, x0 + 14 + k * 3.2, 4.6, iz - 2.2, (k % 2 == 0) and C.coral or Color3.fromRGB(240, 220, 170), nil, { collide = false })
		end
		local board = box(parent, "Chalkboard", x0 + 4, 6, iz - 0.12, x0 + 16, 10, iz - 0.06, Color3.fromRGB(40, 50, 44), nil, { collide = false })
		sign(board, Enum.NormalId.Front, "LATTE | CAKE | TOUR SPECIAL", C.white, Enum.Font.Antique)
		box(parent, "CafeTableIn", x0 + 8, 2.6, z0 + 3.5, x0 + 11, 2.9, z0 + 6, C.white)
		box(parent, "CafeTableInLeg", x0 + 9.3, 0.1, z0 + 4.5, x0 + 9.7, 2.6, z0 + 5, C.dark)
		plant(parent, Vector3.new(x1 - 4, 0.1, iz - 3), false)
	elseif kind == "records" then
		for r = 0, 2 do
			local rx = x0 + 5 + r * 9
			box(parent, "Crate", rx, 0.1, z0 + 3, rx + 6, 3, z0 + 7, C.woodDark, Enum.Material.Wood)
			for k = 0, 9 do
				local c = ({ C.purple, C.teal, C.coral, C.yellow, C.dark, C.white })[(k + r) % 6 + 1]
				box(parent, "Record", rx + 0.3 + k * 0.55, 3, z0 + 3.4, rx + 0.7 + k * 0.55, 5.6, z0 + 6.6, c, nil, { collide = false })
			end
		end
		for k = 0, 11 do
			local c = ({ C.purple, C.teal, C.coral, C.yellow, Color3.fromRGB(90, 140, 220), C.dark })[k % 6 + 1]
			local col = k % 6
			local row = math.floor(k / 6)
			box(parent, "AlbumCover", x0 + 4 + col * 5, 5 + row * 3.4, iz - 0.12, x0 + 7 + col * 5, 8 + row * 3.4, iz - 0.06, c, nil, { collide = false })
		end
	elseif kind == "music" then
		for k = 0, 4 do
			local gx = x0 + 5 + k * 5
			local c = ({ Color3.fromRGB(200, 40, 40), C.white, Color3.fromRGB(30, 30, 34), Color3.fromRGB(230, 150, 40), Color3.fromRGB(60, 110, 200) })[k + 1]
			part(parent, "GuitarBody", Vector3.new(2.4, 3, 0.5), Vector3.new(gx, 4.4, iz - 0.4), c, nil, { shape = Enum.PartType.Ball, collide = false })
			box(parent, "GuitarNeck", gx - 0.18, 5.6, iz - 0.45, gx + 0.18, 9.6, iz - 0.25, C.woodDark, Enum.Material.Wood, { collide = false })
		end
		box(parent, "Amp", x0 + 4, 0.1, z0 + 3, x0 + 8, 4, z0 + 5.4, C.dark, Enum.Material.Leather)
		box(parent, "Amp", x0 + 9, 0.1, z0 + 3, x0 + 13, 5.5, z0 + 5.4, C.dark, Enum.Material.Leather)
		box(parent, "AmpGrille", x0 + 9.4, 0.6, z0 + 2.96, x0 + 12.6, 4.8, z0 + 3, Color3.fromRGB(90, 76, 60), Enum.Material.Fabric, { collide = false })
		part(parent, "DrumKick", Vector3.new(2, 3, 3), CFrame.new(Vector3.new(x0 + 20, 1.6, z0 + 5)) * CFrame.Angles(0, math.pi / 2, 0), C.white, nil, { shape = Enum.PartType.Cylinder })
		part(parent, "Cymbal", Vector3.new(0.1, 2.4, 2.4), CFrame.new(Vector3.new(x0 + 22.4, 5, z0 + 4.6)) * CFrame.Angles(0, 0, math.pi / 2), C.yellow, Enum.Material.Metal, { shape = Enum.PartType.Cylinder, collide = false })
	elseif kind == "bakery" then
		box(parent, "Display", x0 + 3, 0.1, z0 + 3, x1 - 9, 3.2, z0 + 6, C.white)
		box(parent, "DisplayGlass", x0 + 3, 3.2, z0 + 3, x1 - 9, 4.6, z0 + 3.2, C.glass, Enum.Material.Glass, { transparency = 0.4, collide = false })
		for k = 0, 9 do
			part(parent, "Bread", Vector3.new(1.6, 0.9, 0.9), Vector3.new(x0 + 4.5 + k * 2.4, 3.65, z0 + 4.5 + (k % 2) * 0.6), Color3.fromRGB(200, 140, 70), nil, { shape = Enum.PartType.Ball, collide = false })
		end
		for r = 0, 2 do
			box(parent, "BreadShelf", x0 + 3, 4 + r * 2.6, iz - 1.6, x1 - 3, 4.3 + r * 2.6, iz - 0.06, C.wood, Enum.Material.Wood)
			for k = 0, 7 do
				part(parent, "Loaf", Vector3.new(2, 1, 1), Vector3.new(x0 + 5 + k * 4, 4.8 + r * 2.6, iz - 0.9), Color3.fromRGB(180, 120, 60), nil, { shape = Enum.PartType.Ball, collide = false })
			end
		end
	elseif kind == "bar" then
		box(parent, "BarCounter", x0 + 3, 0.1, iz - 5, x1 - 9, 3.8, iz - 3, C.woodDark, Enum.Material.Wood)
		box(parent, "BarTop", x0 + 2.8, 3.8, iz - 5.2, x1 - 8.8, 4.1, iz - 2.8, C.dark)
		for r = 0, 1 do
			box(parent, "BottleShelf", x0 + 3, 5 + r * 2.6, iz - 1.2, x1 - 3, 5.2 + r * 2.6, iz - 0.06, C.wood, Enum.Material.Wood)
			for k = 0, 14 do
				local c = ({ Color3.fromRGB(60, 140, 70), Color3.fromRGB(150, 90, 40), Color3.fromRGB(200, 200, 220), Color3.fromRGB(150, 40, 60) })[k % 4 + 1]
				box(parent, "Bottle", x0 + 3.6 + k * 2.4, 5.2 + r * 2.6, iz - 0.9, x0 + 4.2 + k * 2.4, 6.9 + r * 2.6, iz - 0.3, c, Enum.Material.Glass, { collide = false })
			end
		end
		for k = 0, 3 do
			part(parent, "BarStool", Vector3.new(0.5, 2, 2), CFrame.new(Vector3.new(x0 + 6 + k * 5, 2.9, iz - 6.5)) * CFrame.Angles(0, 0, math.pi / 2), C.purple, nil, { shape = Enum.PartType.Cylinder })
			box(parent, "StoolLeg", x0 + 5.8 + k * 5, 0.1, iz - 6.7, x0 + 6.2 + k * 5, 2.65, iz - 6.3, C.dark, Enum.Material.Metal)
		end
		local ls = box(parent, "LiveSign", x0 + 4, 8.6, z0 + 0.5, x0 + 14, 9.4, z0 + 0.56, C.dark, nil, { collide = false })
		sign(ls, Enum.NormalId.Front, "LIVE MUSIC TONIGHT", C.yellow)
	elseif kind == "fashion" then
		for r = 0, 1 do
			local ry = z0 + 3.5 + r * 4
			box(parent, "Rack", x0 + 4, 7, ry - 0.1, x1 - 12, 7.2, ry + 0.1, C.grey, Enum.Material.Metal, { collide = false })
			box(parent, "RackLeg", x0 + 4, 0.1, ry - 0.1, x0 + 4.2, 7, ry + 0.1, C.grey, Enum.Material.Metal)
			for k = 0, 9 do
				local c = ({ C.purple, C.teal, C.coral, C.yellow, C.white, C.dark })[(k + r) % 6 + 1]
				box(parent, "Shirt", x0 + 5 + k * 2.6, 3.6, ry - 0.9, x0 + 6.8 + k * 2.6, 6.8, ry + 0.9, c, Enum.Material.Fabric, { collide = false })
			end
		end
		for k = 0, 1 do
			local mx = x1 - 10 + k * 4
			box(parent, "Mannequin", mx - 0.9, 3.4, z0 + 4, mx + 0.9, 7, z0 + 5, (k == 0) and C.coral or C.dark, Enum.Material.Fabric)
			box(parent, "MannequinLegs", mx - 0.7, 0.1, z0 + 4.1, mx + 0.7, 3.4, z0 + 4.9, C.white)
			part(parent, "MannequinHead", Vector3.new(1.2, 1.2, 1.2), Vector3.new(mx, 7.7, z0 + 4.5), C.white, nil, { shape = Enum.PartType.Ball })
		end
	end
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
			desk(staff, st.desk, 0, true)
			chair(staff, st.pos, 0, C.dark)
		end
	end
	for _, z in ipairs({ -20.2, -8.2 }) do
		box(staff, "Divider", 20, 0, z - 0.2, 36, 5.2, z, C.teal)
	end
	chair(deco, Vector3.new(-22, 0, 25.2), math.pi, C.coral)
	plant(deco, Vector3.new(36, 0, -24), true)
	plant(deco, Vector3.new(37, 0, 22), false)

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
	sign(wb, Enum.NormalId.Right, "TOUR IDEAS:  bigger venues  |  new stage  |  sign a star", Color3.fromRGB(60, 80, 160), Enum.Font.GothamBold)
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
	-- the stage design workstation (opens My Stages / the stage builder): desk, three monitors, PC, chair
	local cp = Vector3.new(58, 0, -24)
	box(hall, "WorkDesk", cp.X - 6, 3, cp.Z - 2.4, cp.X + 6, 3.4, cp.Z + 2.4, C.woodDark, Enum.Material.Wood)
	for _, dx in ipairs({ -5.6, 5.6 }) do
		box(hall, "WorkDeskLeg", cp.X + dx - 0.2, 0, cp.Z - 2.2, cp.X + dx + 0.2, 3, cp.Z + 2.2, C.grey, Enum.Material.Metal)
	end
	box(hall, "WorkDeskPanel", cp.X - 5.4, 0.8, cp.Z - 2.2, cp.X + 5.4, 3, cp.Z - 2, C.dark)
	local monitorCol = { Color3.fromRGB(110, 200, 190), Color3.fromRGB(160, 150, 240), Color3.fromRGB(250, 200, 110) }
	for i = -1, 1 do
		local mcf = CFrame.new(cp + Vector3.new(i * 3.8, 0, -1.2)) * CFrame.Angles(0, i * -0.3, 0)
		part(hall, "MonitorFoot", Vector3.new(1.4, 0.12, 1), mcf * CFrame.new(0, 3.46, 0), C.dark)
		part(hall, "MonitorStand", Vector3.new(0.35, 1.3, 0.35), mcf * CFrame.new(0, 4.1, -0.1), C.dark)
		part(hall, "Monitor", Vector3.new(3.6, 2.3, 0.3), mcf * CFrame.new(0, 5.8, -0.1), C.dark)
		part(hall, "MonitorScreen", Vector3.new(3.3, 2, 0.05), mcf * CFrame.new(0, 5.8, 0.075), monitorCol[i + 2], Enum.Material.SmoothPlastic, { collide = false })
	end
	local consoleTop = box(hall, "Keyboard", cp.X - 1.4, 3.4, cp.Z + 0.6, cp.X + 1.4, 3.55, cp.Z + 1.5, C.white)
	box(hall, "Mouse", cp.X + 2.2, 3.4, cp.Z + 0.8, cp.X + 2.7, 3.6, cp.Z + 1.4, C.white)
	box(hall, "Tablet", cp.X - 4.6, 3.4, cp.Z + 0.4, cp.X - 2.6, 3.5, cp.Z + 1.8, C.dark)
	box(hall, "PCTower", cp.X + 6.4, 0, cp.Z - 1.5, cp.X + 8, 4, cp.Z + 1.5, C.dark)
	box(hall, "PCLight", cp.X + 6.6, 3.2, cp.Z + 1.5, cp.X + 7.8, 3.4, cp.Z + 1.54, C.teal, nil, { collide = false })
	chair(hall, cp + Vector3.new(0, 0, 4.2), 0, C.purple)
	local ws = box(hall, "WorkSign", cp.X - 5, 9, cp.Z - 2.6, cp.X + 5, 10.6, cp.Z - 2.44, C.dark, nil, { collide = false })
	sign(ws, Enum.NormalId.Back, "STAGE DESIGN", C.yellow)
	box(hall, "WorkSignPole", cp.X - 0.15, 3.4, cp.Z - 2.4, cp.X + 0.15, 9, cp.Z - 2.1, C.grey, Enum.Material.Metal)
	prompt(consoleTop, "stagehall", "Build stages", "Stage Hall", 10)
	box(hall, "FloorTape", 48, 0, -12, 116, 0.04, -11.6, C.yellow, nil, { collide = false })
	for _, z in ipairs({ -20, 10, 36 }) do
		for _, x in ipairs({ 60, 100 }) do
			local l = box(hall, "HallLamp", x - 4, HH - 1.4, z - 1, x + 4, HH - 1, z + 1, C.lamp, Enum.Material.Neon, { collide = false })
			new("SurfaceLight", { Face = Enum.NormalId.Bottom, Range = 36, Brightness = 1, Angle = 110, Shadows = false }, l)
		end
	end

	------------------------------------------------------------ OUTSIDE: the street. Straight in front of the label,
	-- at both ends it bends away around the corner (you see the city go on; an invisible wall stops you there)
	local XW, XE = Hub.STREET.xw, Hub.STREET.xe
	local CW, CE = Hub.STREET.cw, Hub.STREET.ce
	local AS = C.asphalt
	box(out, "Ground", -340, -2.2, -90, 380, -1.5, 330, Color3.fromRGB(86, 88, 92), Enum.Material.Concrete)
	-- straight part
	box(out, "Sidewalk", XW, -1, 48, XE, 0, 62, C.sidewalk, Enum.Material.Concrete)
	box(out, "Curb", XW, -1, 62, XE, 0.02, 63, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	box(out, "Road", XW, -1.5, 63, XE, -0.5, 89, AS, Enum.Material.Asphalt)
	box(out, "CurbFar", XW, -1, 89, XE, 0.02, 90, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	box(out, "SidewalkFar", XW, -1, 90, XE, 0, 104, C.sidewalk, Enum.Material.Concrete)
	for x = XW + 6, XE - 10, 16 do
		if x + 8 < -9 or x > 9 then
			box(out, "LaneMark", x, -0.5, 77, x + 8, -0.46, 77.5, C.white, nil, { collide = false })
		end
	end
	-- zebra crossing: stripes parallel to the road, one after another across it
	for z = 64.2, 87, 3.2 do
		box(out, "Crosswalk", -6, -0.5, z, 6, -0.46, z + 1.6, C.white, nil, { collide = false })
	end
	-- the two bends (ring pieces around a corner point) and the street going on behind them
	local function ringPiece(name, ctr, dir, r0, r1, a0, a1, y0, y1, color, material)
		local am = (a0 + a1) / 2
		local rm = (r0 + r1) / 2
		local chord = 2 * r1 * math.sin((a1 - a0) / 2) + 0.1
		local pos = ctr + Vector3.new(dir * math.sin(am) * rm, (y0 + y1) / 2, -math.cos(am) * rm)
		local yaw = math.atan2(math.cos(am), dir * math.sin(am))
		return part(out, name, Vector3.new(r1 - r0, y1 - y0, chord), CFrame.new(pos) * CFrame.Angles(0, yaw, 0), color, material)
	end
	local LAYERS = {
		{ "ArcSidewalkIn", 20, 34, -1, 0, C.sidewalk, Enum.Material.Concrete },
		{ "ArcCurbIn", 34, 35, -1, 0.02, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete },
		{ "ArcRoad", 35, 61, -1.5, -0.5, AS, Enum.Material.Asphalt },
		{ "ArcCurbOut", 61, 62, -1, 0.02, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete },
		{ "ArcSidewalkOut", 62, 76, -1, 0, C.sidewalk, Enum.Material.Concrete },
	}
	local rng = Random.new(21)
	for _, side in ipairs({ { CW, -1 }, { CE, 1 } }) do
		local ctr, dir = side[1], side[2]
		local steps = 9
		for k = 0, steps - 1 do
			local a0, a1 = k * (math.pi / 2) / steps, (k + 1) * (math.pi / 2) / steps
			for _, L in ipairs(LAYERS) do
				ringPiece(L[1], ctr, dir, L[2], L[3], a0, a1, L[4], L[5], L[6], L[7])
			end
		end
		-- outer buildings along the bend
		for k = 0, 5 do
			local a0, a1 = k * (math.pi / 12), (k + 1) * (math.pi / 12)
			local h = 36 + ((k % 2 == 0) and 0 or 14) + k * 3 + rng:NextInteger(0, 2)
			local col = Color3.fromRGB(rng:NextInteger(170, 230), rng:NextInteger(150, 210), rng:NextInteger(130, 200))
			local b = ringPiece("ArcBuilding", ctr, dir, 77, 108, a0, a1, -1, h, col, (k % 2 == 0) and Enum.Material.Brick or Enum.Material.SmoothPlastic)
			for fl = 0, math.floor((h - 10) / 10) do
				local wnd = ringPiece("ArcWindows", ctr, dir, 76.9, 77, a0 + 0.03, a1 - 0.03, 5 + fl * 10, 10 + fl * 10, Color3.fromRGB(170, 196, 220), Enum.Material.Glass)
				local _w = wnd
			end
			local _b = b
		end
		-- the street goes on after the bend
		local xr = function(r)
			return ctr.X + dir * r
		end
		local function strip(name, r0, r1, y0, y1, color, material)
			local xa, xb = xr(r0), xr(r1)
			box(out, name, math.min(xa, xb), y0, ctr.Z, math.max(xa, xb), y1, ctr.Z + 190, color, material)
		end
		for _, L in ipairs(LAYERS) do
			strip(L[1]:gsub("Arc", "Cont"), L[2], L[3], L[4], L[5], L[6], L[7])
		end
		for i = 0, 4 do
			local z0 = ctr.Z + i * 38
			local h = rng:NextInteger(30, 64)
			local xa, xb = xr(77), xr(108)
			box(out, "ContBuilding", math.min(xa, xb), -1, z0, math.max(xa, xb), h, z0 + 36, Color3.fromRGB(rng:NextInteger(160, 220), rng:NextInteger(150, 200), rng:NextInteger(140, 200)), Enum.Material.Brick)
		end
		box(out, "ContEnd", math.min(xr(0), xr(110)), -1, ctr.Z + 190, math.max(xr(0), xr(110)), 70, ctr.Z + 220, Color3.fromRGB(190, 180, 170), Enum.Material.Concrete)
		-- the inner corner: a round corner house and the block along the side street
		part(out, "CornerTower", Vector3.new(52, 40, 40), CFrame.new(ctr + Vector3.new(0, 25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(214, 196, 172), Enum.Material.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		local xi0, xi1 = xr(0), xr(20)
		box(out, "CornerBlock", math.min(xi0, xi1), -1, ctr.Z, math.max(xi0, xi1), 42, ctr.Z + 190, Color3.fromRGB(200, 186, 168), Enum.Material.Brick)
		-- invisible wall where the bend starts: you can look around the corner, not walk there
		local xw = (dir < 0) and XW or XE
		box(out, "Boundary", xw - 0.5, -1, 48, xw + 0.5, 60, 104, C.white, nil, { transparency = 1 })
	end

	-- the label's neighbours (left and right) and the billboard
	box(out, "NeighbourWest", XW, -1, -60, -90, 54, 48, Color3.fromRGB(212, 186, 150), Enum.Material.Brick)
	box(out, "NeighbourEast", 124, -1, -60, XE, 64, 48, Color3.fromRGB(190, 200, 214), Enum.Material.Concrete)
	for _, nb in ipairs({ { XW, -90, 54 }, { 124, XE, 64 } }) do
		for fl = 0, math.floor((nb[3] - 8) / 10) do
			for k = 0, math.floor((nb[2] - nb[1] - 8) / 9) do
				local wx, wy = nb[1] + 5 + k * 9, 6 + fl * 10
				local underBillboard = nb[1] > 0 and wx + 5 > 128 and wx < 168 and wy + 6 > 24 and wy < 54
				if not underBillboard then
					box(out, "Window", wx, wy, 48.06, wx + 5, wy + 6, 48.3, Color3.fromRGB(170, 196, 220), Enum.Material.Glass)
					box(out, "WindowSill", wx - 0.3, wy - 0.4, 48.04, wx + 5.3, wy, 48.5, C.white)
				end
			end
		end
	end
	box(out, "BillboardFrame", 130, 26, 48.06, 166, 52, 48.6, C.dark)
	poster(out, Vector3.new(148, 39, 48.72), Enum.NormalId.Back, 34, 24)
	-- the label's facade: canopy over the door and the big name sign on the roof
	box(out, "Canopy", -12, 15.2, 48, 12, 15.8, 54, C.white)
	local facade = box(out, "FacadeSign", -30, H + 2.4, 48.04, 30, H + 7.6, 48.6, C.purple)
	sign(facade, Enum.NormalId.Back, "STARLIGHT RECORDS", C.white).Name = "LabelSign"
	box(out, "FacadeSignBack", -30, H + 2, 46, 30, H + 8, 48.04, C.wall)

	-- shops across the street (each with its own front, a shop window and something to see inside)
	shop(out, -130, -90, { h = 38, color = Color3.fromRGB(226, 200, 170), name = "BAKERY", signColor = C.coral, awning = C.coral, kind = "bakery", mat = Enum.Material.Brick })
	shop(out, -90, -46, { h = 30, color = Color3.fromRGB(240, 214, 200), name = "MOONBEAM CAFE", signColor = C.purple, awning = C.purple, kind = "cafe", balcony = true })
	shop(out, -46, -6, { h = 52, color = Color3.fromRGB(200, 214, 230), name = "VINYL VAULT", signColor = Color3.fromRGB(40, 90, 160), kind = "records" })
	shop(out, -6, 34, { h = 44, color = Color3.fromRGB(150, 70, 56), name = "AMP CITY", signColor = C.yellow, awning = C.dark, kind = "music", mat = Enum.Material.Brick })
	shop(out, 34, 76, { h = 36, color = Color3.fromRGB(214, 226, 206), name = "SLICE PIZZA", signColor = Color3.fromRGB(200, 60, 50), awning = Color3.fromRGB(46, 140, 70), kind = "pizza", balcony = true })
	shop(out, 76, 120, { h = 58, color = Color3.fromRGB(110, 84, 120), name = "BACKSTAGE BAR", signColor = C.yellow, kind = "bar" })
	shop(out, 120, XE, { h = 46, color = Color3.fromRGB(236, 230, 214), name = "STAGE WEAR", signColor = C.dark, awning = Color3.fromRGB(30, 30, 36), kind = "fashion", balcony = true })

	-- far sidewalk: trees and lamps at the curb, cafe tables at the cafe front (people walk in between)
	for _, x in ipairs({ -112, -40, 46, 100, 150 }) do
		tree(out, Vector3.new(x, 0, 92.5))
	end
	for _, x in ipairs({ -70, 14, 76, 128 }) do
		streetLamp(out, Vector3.new(x, 0, 90.9), -1)
	end
	for i, x in ipairs(Hub.CAFE_TABLES) do
		box(out, "CafeTable", x - 1.4, 2.6, 100.4, x + 1.4, 2.9, 103.2, C.white)
		box(out, "CafeTableLeg", x - 0.2, 0, 101.6, x + 0.2, 2.6, 102, C.dark, Enum.Material.Metal)
		box(out, "UmbrellaPole", x - 0.15, 2.9, 101.65, x + 0.15, 9, 101.95, C.white)
		part(out, "Umbrella", Vector3.new(0.6, 8, 8), CFrame.new(Vector3.new(x, 9.2, 101.8)) * CFrame.Angles(0, 0, math.pi / 2), (i % 2 == 0) and C.purple or C.coral, Enum.Material.Fabric, { shape = Enum.PartType.Cylinder, collide = false })
	end
	for _, st in ipairs(Hub.SITTERS) do
		if st.kind == "chair" then
			chair(out, st.pos, st.yaw + math.pi, C.white)
		end
	end
	-- front sidewalk: trees, lamps, the bus stop and benches in the strip at the curb
	for _, x in ipairs({ -115, -75, 26, 118, 158 }) do
		tree(out, Vector3.new(x, 0, 59.5))
	end
	for _, x in ipairs({ -95, -20, 50, 100, 140 }) do
		streetLamp(out, Vector3.new(x, 0, 60.8), 1)
	end
	box(out, "BusStopRoof", -48, 10, 56.8, -32, 10.4, 62, C.white)
	box(out, "BusStopPost", -47.7, 0, 61.2, -47.3, 10, 61.6, C.grey, Enum.Material.Metal)
	box(out, "BusStopPost", -32.7, 0, 61.2, -32.3, 10, 61.6, C.grey, Enum.Material.Metal)
	box(out, "BusStopBack", -47.3, 1, 56.9, -32.7, 9, 57.2, C.glass, Enum.Material.Glass, { transparency = 0.5 })
	box(out, "BusStopSign", -47.8, 10.4, 61.2, -45.8, 12.4, 61.6, Color3.fromRGB(40, 110, 200))
	bench(out, Vector3.new(-40, 0, 58.6), math.pi)
	poster(out, Vector3.new(-40, 5, 56.8), Enum.NormalId.Front, 6, 7.6)
	bench(out, Vector3.new(-58, 0, 59), math.pi)
	bench(out, Vector3.new(130, 0, 59), math.pi)
	-- parked cars in the parking strips, the label's tour bus in front of the stage hall
	car(out, Vector3.new(-110, -0.5, 66.4), 0, Color3.fromRGB(210, 70, 70))
	car(out, Vector3.new(-82, -0.5, 66.4), 0, Color3.fromRGB(70, 120, 210))
	car(out, Vector3.new(20, -0.5, 86.6), math.pi, Color3.fromRGB(240, 210, 90))
	car(out, Vector3.new(110, -0.5, 86.6), math.pi, Color3.fromRGB(240, 240, 240))
	car(out, Vector3.new(150, -0.5, 86.6), math.pi, Color3.fromRGB(60, 160, 120))
	local bp = Vector3.new(80, -0.5, 67.25)
	box(out, "BusBody", bp.X - 20, bp.Y + 1.2, bp.Z - 3.75, bp.X + 20, bp.Y + 12, bp.Z + 3.75, C.white)
	box(out, "BusStripe", bp.X - 20.04, bp.Y + 3.4, bp.Z - 3.79, bp.X + 20.04, bp.Y + 5, bp.Z + 3.79, C.purple, nil, { collide = false })
	box(out, "BusWindows", bp.X - 18, bp.Y + 6.6, bp.Z - 3.81, bp.X + 18, bp.Y + 9.6, bp.Z + 3.81, Color3.fromRGB(70, 90, 120), Enum.Material.Glass, { collide = false })
	local busName = box(out, "BusName", bp.X - 14, bp.Y + 9.8, bp.Z - 3.85, bp.X + 14, bp.Y + 11.6, bp.Z - 3.81, C.white, nil, { collide = false })
	sign(busName, Enum.NormalId.Front, "STARLIGHT RECORDS ON TOUR", C.purple).Name = "LabelSign"
	for _, wx in ipairs({ -14, 12, 16 }) do
		for _, wz in ipairs({ -3.8, 3.8 }) do
			part(out, "Wheel", Vector3.new(1.2, 3.6, 3.6), CFrame.new(bp + Vector3.new(wx, 1.6, wz)) * CFrame.Angles(0, math.pi / 2, 0), C.dark, nil, { shape = Enum.PartType.Cylinder })
		end
	end
	box(out, "Boundary", XW, 40, 48, XE, 41, 104, C.white, nil, { transparency = 1 })
	return root
end

return Hub
