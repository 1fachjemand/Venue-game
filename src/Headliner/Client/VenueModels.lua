-- Small 3D pictures of venues from the outside (tour planner cards): a ViewportFrame with a simple model
-- per venue type (Club, Theatre, Hall, Arena, Amphitheatre, Stadium).
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)

local New = UI.New
local VenueModels = {}

local function part(parent, size, cf, color, material, shape)
	local p = New("Part", { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Anchored = true, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth })
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
local function cyl(parent, h, d, cf, color, material)
	return part(parent, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end
local function oval(parent, size, cf, color, material)
	local p = part(parent, size, cf, color, material)
	New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end
-- a ring of boxes (stands, walls): centre, radius x/z, height, depth, segments
local function ring(parent, rx, rz, y, h, depth, n, color, a0, a1, tilt)
	a0, a1 = a0 or 0, a1 or math.pi * 2
	for i = 0, n - 1 do
		local a = a0 + (a1 - a0) * (i + 0.5) / n
		local x, z = math.cos(a) * rx, math.sin(a) * rz
		local seg = 2 * math.pi * math.max(rx, rz) / n * ((a1 - a0) / (2 * math.pi)) * 1.15
		part(parent, Vector3.new(seg, h, depth), CFrame.new(x, y, z) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(tilt or 0, 0, 0), color)
	end
end

local GROUND = Color3.fromRGB(196, 200, 206)
local GRASS = Color3.fromRGB(120, 176, 96)

local BUILD = {}
function BUILD.Club(m, col)
	part(m, Vector3.new(34, 0.4, 26), CFrame.new(0, -0.2, 2), GROUND)
	part(m, Vector3.new(18, 11, 12), CFrame.new(0, 5.5, -2), Color3.fromRGB(150, 70, 56), Enum.Material.Brick)
	part(m, Vector3.new(18.4, 0.8, 12.4), CFrame.new(0, 11.2, -2), Color3.fromRGB(70, 70, 76))
	part(m, Vector3.new(3.2, 5, 0.3), CFrame.new(-4, 2.5, 4.1), Color3.fromRGB(24, 24, 28))
	part(m, Vector3.new(8, 1.4, 0.3), CFrame.new(2, 8, 4.15), col, Enum.Material.Neon)
	part(m, Vector3.new(6, 0.3, 2.4), CFrame.new(-4, 5.4, 5.2), Color3.fromRGB(30, 30, 34))
	for _, x in ipairs({ 2, 6.5 }) do
		part(m, Vector3.new(3, 3, 0.2), CFrame.new(x, 3.4, 4.05), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
	end
end
function BUILD.Theatre(m, col)
	part(m, Vector3.new(40, 0.4, 30), CFrame.new(0, -0.2, 2), GROUND)
	part(m, Vector3.new(24, 14, 16), CFrame.new(0, 7, -4), Color3.fromRGB(232, 222, 200), Enum.Material.SmoothPlastic)
	for k = 0, 3 do
		cyl(m, 11, 1.4, CFrame.new(-7.5 + k * 5, 6.1, 5.2), Color3.fromRGB(244, 238, 226))
	end
	part(m, Vector3.new(24, 1.6, 4), CFrame.new(0, 12.4, 5), Color3.fromRGB(232, 222, 200))
	-- stepped top above the columns
	part(m, Vector3.new(20, 1.3, 3.6), CFrame.new(0, 13.85, 5), Color3.fromRGB(240, 232, 214))
	part(m, Vector3.new(13, 1.2, 3.2), CFrame.new(0, 15.1, 5), Color3.fromRGB(240, 232, 214))
	part(m, Vector3.new(14, 1.6, 3), CFrame.new(0, 4.6, 6.4), Color3.fromRGB(30, 30, 34))
	part(m, Vector3.new(14.2, 0.4, 3.2), CFrame.new(0, 3.7, 6.4), col, Enum.Material.Neon)
	part(m, Vector3.new(6, 3.4, 0.3), CFrame.new(0, 1.7, 4.1), Color3.fromRGB(140, 30, 40))
	part(m, Vector3.new(26, 0.6, 4), CFrame.new(0, 0.3, 8), Color3.fromRGB(210, 206, 196))
end
function BUILD.Hall(m, col)
	part(m, Vector3.new(44, 0.4, 36), CFrame.new(0, -0.2, 0), GROUND)
	cyl(m, 12, 28, CFrame.new(0, 6, 0), Color3.fromRGB(196, 110, 80), Enum.Material.Brick)
	cyl(m, 1.4, 28.6, CFrame.new(0, 9.5, 0), Color3.fromRGB(236, 228, 210))
	oval(m, Vector3.new(26, 10, 26), CFrame.new(0, 12, 0), Color3.fromRGB(150, 170, 176), Enum.Material.Metal)
	part(m, Vector3.new(8, 6, 4), CFrame.new(0, 3, 14), Color3.fromRGB(236, 228, 210))
	part(m, Vector3.new(8.2, 0.6, 4.2), CFrame.new(0, 5.4, 14.2), col, Enum.Material.Neon)
end
function BUILD.Arena(m, col)
	part(m, Vector3.new(60, 0.4, 50), CFrame.new(0, -0.2, 0), GROUND)
	cyl(m, 12, 40, CFrame.new(0, 6, 0), Color3.fromRGB(70, 76, 90), Enum.Material.Metal)
	cyl(m, 3, 40.6, CFrame.new(0, 7.5, 0), Color3.fromRGB(120, 170, 220), Enum.Material.Glass)
	cyl(m, 0.8, 40.8, CFrame.new(0, 11.4, 0), col, Enum.Material.Neon)
	oval(m, Vector3.new(40, 8, 40), CFrame.new(0, 12, 0), Color3.fromRGB(220, 224, 230), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(14, 1, 6), CFrame.new(0, 5, 20.5), Color3.fromRGB(40, 40, 46))
	part(m, Vector3.new(10, 4.5, 1), CFrame.new(0, 2.3, 19.6), Color3.fromRGB(150, 200, 240), Enum.Material.Glass)
end
function BUILD.Amphitheatre(m, col)
	part(m, Vector3.new(60, 0.4, 50), CFrame.new(0, -0.2, 0), GRASS, Enum.Material.Grass)
	-- the rows of seats rise at the back, the band shell stands in front of them
	for r = 0, 4 do
		ring(m, 12 + r * 3.2, 12 + r * 3.2, 0.6 + r * 1.3, 1.2 + r * 2.6 - r * 1.3, 3, 9, Color3.fromRGB(196, 190, 176):Lerp(Color3.fromRGB(150, 146, 136), r / 4), math.pi * 1.05, math.pi * 1.95)
	end
	oval(m, Vector3.new(16, 14, 12), CFrame.new(0, 4, 9), Color3.fromRGB(246, 246, 246))
	part(m, Vector3.new(14, 1.2, 8), CFrame.new(0, 0.6, 6), Color3.fromRGB(50, 50, 56))
	part(m, Vector3.new(12, 0.4, 0.4), CFrame.new(0, 8, 3.5), col, Enum.Material.Neon)
end
function BUILD.Stadium(m, col)
	part(m, Vector3.new(90, 0.4, 72), CFrame.new(0, -0.2, 0), GROUND)
	part(m, Vector3.new(36, 0.5, 22), CFrame.new(0, 0.3, 0), GRASS, Enum.Material.Grass)
	for r = 0, 2 do
		ring(m, 22 + r * 4, 15 + r * 4, 1.5 + r * 2.4, 3 + r * 1.6, 4.4, 20, Color3.fromRGB(200, 60, 70):Lerp(Color3.fromRGB(150, 150, 160), r / 3))
	end
	ring(m, 33, 26, 12.5, 0.8, 7, 20, Color3.fromRGB(226, 230, 236), nil, nil, -0.15)
	for _, p in ipairs({ { -30, -22 }, { 30, -22 }, { -30, 22 }, { 30, 22 } }) do
		part(m, Vector3.new(0.8, 20, 0.8), CFrame.new(p[1], 10, p[2]), Color3.fromRGB(120, 124, 132), Enum.Material.Metal)
		part(m, Vector3.new(4, 2, 1), CFrame.new(p[1], 20.5, p[2]) * CFrame.Angles(0, math.atan2(-p[1], -p[2]), 0), Color3.fromRGB(255, 250, 220), Enum.Material.Neon)
	end
	part(m, Vector3.new(10, 0.8, 0.8), CFrame.new(0, 13.6, 26.5), col, Enum.Material.Neon)
end
local CAMERA = { Club = 26, Theatre = 33, Hall = 38, Arena = 48, Amphitheatre = 46, Stadium = 70 }

-- the model alone (for previews / tests)
function VenueModels.build(model, vtype, accent)
	local build = BUILD[vtype] or BUILD.Club
	build(model, accent or Color3.fromRGB(37, 99, 235))
	return model
end
VenueModels.CAMERA = CAMERA

-- picture(parent, venueType, pos, size, accentColor) -> ViewportFrame
function VenueModels.picture(parent, vtype, pos, size, accent)
	local vp = New("ViewportFrame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(205, 226, 246),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		UI.Corner(10),
	})
	local m = New("Model", { Parent = vp })
	local build = BUILD[vtype] or BUILD.Club
	build(m, accent or Color3.fromRGB(37, 99, 235))
	local d = CAMERA[vtype] or 40
	local cam = New("Camera", { FieldOfView = 38, Parent = vp })
	cam.CFrame = CFrame.lookAt(Vector3.new(d * 0.62, d * 0.5, d * 0.86), Vector3.new(0, d * 0.08, 0))
	vp.CurrentCamera = cam
	return vp
end

return VenueModels
