-- Builds 3D models for stage items and animates them during shows.
-- Every item is built around the local origin (bottom centre for floor items, hanging point for rig items)
-- and then moved into place with Builder.place().
local TweenService = game:GetService("TweenService")
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)

local New = UI.New
local Builder = {}

local DARK = Color3.fromRGB(28, 28, 32)
local METAL = Color3.fromRGB(90, 92, 100)
local WHITE = Color3.new(1, 1, 1)
local WARM = Color3.fromRGB(255, 196, 120)

local function part(model, name, size, cf, color, material, shape)
	local p = New("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color or DARK,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- vertical cylinder: height h, diameter d, centred at cf
local function cyl(model, name, h, d, cf, color, material)
	return part(model, name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
end

local function beam(p, a0Pos, a1Pos, width0, width1, color, transparency0)
	local a0 = New("Attachment", { Position = a0Pos, Parent = p })
	local a1 = New("Attachment", { Position = a1Pos, Parent = p })
	return New("Beam", {
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = width0,
		Width1 = width1,
		Color = ColorSequence.new(color),
		Transparency = NumberSequence.new(transparency0 or 0.35, 1),
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 1,
		Parent = p,
	})
end

local function surfaceText(p, face, text, textColor, bg)
	local gui = New("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Brightness = 2,
		Parent = p,
	})
	local frame = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = bg or Color3.new(0, 0, 0),
		BackgroundTransparency = bg and 0 or 1,
		BorderSizePixel = 0,
		Parent = gui,
	})
	local grad = nil
	if bg then
		grad = New("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 90)),
			Rotation = 0,
			Parent = frame,
		})
	end
	local label = New("TextLabel", {
		Size = UDim2.fromScale(0.9, 0.6),
		Position = UDim2.fromScale(0.05, 0.2),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = textColor or WHITE,
		Parent = frame,
	})
	return frame, label, grad
end

------------------------------------------------------------------ builders
local B = {}

-- thin glowing line between two points (local coords) at height y
local function edge(m, x1, z1, x2, z2, y, color)
	local dx, dz = x2 - x1, z2 - z1
	local len = math.sqrt(dx * dx + dz * dz)
	return part(m, "Edge", Vector3.new(0.35, 0.35, len), CFrame.new((x1 + x2) / 2, y, (z1 + z2) / 2) * CFrame.Angles(0, math.atan2(dx, dz), 0), color, Enum.Material.Neon)
end

local DECK_COLOR = Color3.fromRGB(46, 46, 56)

local function dims(r, def)
	local rec = r.rec or {}
	local w = rec.w or (def.size and def.size.w) or 8
	local d = rec.d or (def.size and def.size.d) or w
	local h = rec.h or def.h or 6
	return w, d, h
end

-- deck surfaces: rec.skin = "black" | "white" | "wood" | "metal" | "mirror" | "led"; rec.edge = glowing edges on/off
local SKINS = {
	black = { Color3.fromRGB(46, 46, 56), Enum.Material.SmoothPlastic, 0 },
	white = { Color3.fromRGB(222, 222, 228), Enum.Material.SmoothPlastic, 0 },
	wood = { Color3.fromRGB(112, 80, 54), Enum.Material.WoodPlanks, 0 },
	metal = { Color3.fromRGB(120, 124, 132), Enum.Material.DiamondPlate, 0 },
	mirror = { Color3.fromRGB(196, 202, 214), Enum.Material.Glass, 0.45 },
	led = { Color3.fromRGB(40, 30, 90), Enum.Material.Neon, 0 },
}
Builder.SKINS = { "black", "white", "wood", "metal", "mirror", "led" }

local function finishDeck(r)
	local rec = r.rec or {}
	local sk = SKINS[rec.skin or "black"] or SKINS.black
	for _, p in ipairs(r.surfaces or {}) do
		p.Color = sk[1]
		p.Material = sk[2]
		p.Reflectance = sk[3]
	end
	if rec.skin == "led" then
		r.ledParts = {}
		for _, p in ipairs(r.surfaces or {}) do
			p.Color = SKINS.black[1]
			p.Material = SKINS.black[2]
			local alongX = p:IsA("WedgePart") or (p:IsA("Part") and p.Shape == Enum.PartType.Cylinder)
			local h = alongX and p.Size.X or p.Size.Y
			local top = p:Clone()
			top.Name = "LedTop"
			top.Size = alongX and Vector3.new(0.12, p.Size.Y, p.Size.Z) or Vector3.new(p.Size.X, 0.12, p.Size.Z)
			top.CFrame = p.CFrame + Vector3.new(0, h / 2 - 0.04, 0)
			top.Material = Enum.Material.Neon
			top.Color = SKINS.led[1]
			top.Parent = p.Parent
			table.insert(r.ledParts, top)
		end
	end
	if not rec.edge and r.neon then
		for _, n in ipairs(r.neon) do
			n:Destroy()
		end
		r.neon = nil
	end
end

function B.stairs(m, r)
	local w, d, h = dims(r, r.def)
	local n = math.max(2, math.floor(h + 0.5))
	r.surfaces = {}
	for i = 1, n do
		local sh = i * h / n
		table.insert(r.surfaces, part(m, "Step", Vector3.new(w, sh, d / n), CFrame.new(0, sh / 2, d / 2 - (i - 0.5) * d / n), DECK_COLOR))
	end
	finishDeck(r)
end

function B.deck(m, r)
	local w, d, h = dims(r, r.def)
	r.surfaces = { part(m, "Deck", Vector3.new(w, h, d), CFrame.new(0, h / 2, 0), DECK_COLOR) }
	r.neon = {
		edge(m, -w / 2, d / 2, w / 2, d / 2, h, r.color),
		edge(m, -w / 2, -d / 2, w / 2, -d / 2, h, r.color),
		edge(m, -w / 2, -d / 2, -w / 2, d / 2, h, r.color),
		edge(m, w / 2, -d / 2, w / 2, d / 2, h, r.color),
	}
	finishDeck(r)
end

-- Wedges are rotated so their triangle lies flat (plan view). Right angle at (x min, z min) of the box.
local function flatWedge(m, cx, cz, w, d, h, mirror)
	local cf = CFrame.new(cx, h / 2, cz) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, mirror and -math.pi / 2 or math.pi / 2)
	local p = New("WedgePart", {
		Name = "Deck",
		Size = Vector3.new(h, w, d),
		CFrame = cf,
		Color = DECK_COLOR,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
		Parent = m,
	})
	return p
end

function B.deck_tri(m, r)
	local w, d, h = dims(r, r.def)
	-- isosceles triangle: base along the back (z = -d/2), tip at the front (z = +d/2)
	r.surfaces = { flatWedge(m, w / 4, 0, w / 2, d, h, false), flatWedge(m, -w / 4, 0, w / 2, d, h, true) }
	r.neon = {
		edge(m, -w / 2, -d / 2, w / 2, -d / 2, h, r.color),
		edge(m, -w / 2, -d / 2, 0, d / 2, h, r.color),
		edge(m, w / 2, -d / 2, 0, d / 2, h, r.color),
	}
	finishDeck(r)
end

function B.deck_corner(m, r)
	local w, d, h = dims(r, r.def)
	-- right angle at the back-left corner
	r.surfaces = { flatWedge(m, 0, 0, w, d, h, false) }
	r.neon = {
		edge(m, -w / 2, -d / 2, w / 2, -d / 2, h, r.color),
		edge(m, -w / 2, -d / 2, -w / 2, d / 2, h, r.color),
		edge(m, w / 2, -d / 2, -w / 2, d / 2, h, r.color),
	}
	finishDeck(r)
end

function B.deck_round(m, r)
	local w, _, h = dims(r, r.def)
	r.surfaces = { cyl(m, "Deck", h, w, CFrame.new(0, h / 2, 0), DECK_COLOR) }
	r.neon = { cyl(m, "Ring", 0.3, w + 0.5, CFrame.new(0, h - 0.1, 0), r.color, Enum.Material.Neon) }
	finishDeck(r)
end

function B.spot(m, r)
	r.marker = cyl(m, "Marker", 0.2, 3.5, CFrame.new(0, 0.12, 0), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
	r.marker.CanQuery = true
	r.gui = New("BillboardGui", { Size = UDim2.fromOffset(46, 46), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, Parent = r.marker })
	r.label = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 220, 60),
		Text = "?",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(0, 0, 0),
		Parent = r.gui,
	})
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = r.label })
end

function B.pit(m, r)
	local w, d = dims(r, r.def)
	local c = Color3.fromRGB(150, 155, 165)
	part(m, "FenceF", Vector3.new(w, 3, 0.4), CFrame.new(0, 1.5, d / 2), c, Enum.Material.DiamondPlate)
	part(m, "FenceB", Vector3.new(w, 3, 0.4), CFrame.new(0, 1.5, -d / 2), c, Enum.Material.DiamondPlate)
	part(m, "FenceL", Vector3.new(0.4, 3, d), CFrame.new(-w / 2, 1.5, 0), c, Enum.Material.DiamondPlate)
	part(m, "FenceR", Vector3.new(0.4, 3, d), CFrame.new(w / 2, 1.5, 0), c, Enum.Material.DiamondPlate)
	r.pitW, r.pitD = w, d
end

-- thin metal tube between two local points
local function tube(m, a, b, d, color)
	local dir = b - a
	local len = dir.Magnitude
	if len < 0.01 then
		return nil
	end
	return part(m, "Tube", Vector3.new(d or 0.18, d or 0.18, len), CFrame.lookAt((a + b) / 2, b), color or METAL, Enum.Material.Metal)
end

-- box truss along local X (length L) centred on `c` (local CFrame), 2x2 cross-section, zigzag bracing
local function lattice(m, c, L)
	local h = 0.9
	local corners = { Vector3.new(0, h, h), Vector3.new(0, h, -h), Vector3.new(0, -h, h), Vector3.new(0, -h, -h) }
	for _, k in ipairs(corners) do
		tube(m, (c * CFrame.new(-L / 2, k.Y, k.Z)).Position, (c * CFrame.new(L / 2, k.Y, k.Z)).Position, 0.22)
	end
	local seg = math.max(1, math.floor(L / 3))
	local step = L / seg
	for i = 0, seg - 1 do
		local x0, x1 = -L / 2 + i * step, -L / 2 + (i + 1) * step
		local flip = (i % 2 == 0) and 1 or -1
		tube(m, (c * CFrame.new(x0, h * flip, h)).Position, (c * CFrame.new(x1, -h * flip, h)).Position, 0.12)
		tube(m, (c * CFrame.new(x0, h * flip, -h)).Position, (c * CFrame.new(x1, -h * flip, -h)).Position, 0.12)
		tube(m, (c * CFrame.new(x0, h, -h * flip)).Position, (c * CFrame.new(x1, h, h * flip)).Position, 0.12)
	end
end

function B.truss_beam(m, r)
	local w = dims(r, r.def)
	lattice(m, CFrame.new(0, -1, 0), w)
end

function B.truss(m, r)
	part(m, "Foot", Vector3.new(3.4, 0.3, 3.4), CFrame.new(0, 0.15, 0), DARK)
	lattice(m, CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.pi / 2), 40)
end

function B.par(m, r)
	part(m, "Clamp", Vector3.new(0.5, 0.5, 0.8), CFrame.new(0, -0.3, 0), METAL, Enum.Material.Metal)
	part(m, "Yoke", Vector3.new(2.2, 0.2, 0.3), CFrame.new(0, -0.65, 0), METAL, Enum.Material.Metal)
	part(m, "YokeL", Vector3.new(0.2, 1.4, 0.3), CFrame.new(-1.05, -1.3, 0), METAL, Enum.Material.Metal)
	part(m, "YokeR", Vector3.new(0.2, 1.4, 0.3), CFrame.new(1.05, -1.3, 0), METAL, Enum.Material.Metal)
	cyl(m, "Body", 2.2, 1.8, CFrame.new(0, -2, 0), DARK)
	r.lens = cyl(m, "Lens", 0.2, 1.4, CFrame.new(0, -3.15, 0), r.color, Enum.Material.Neon)
	r.light = New("SpotLight", { Face = Enum.NormalId.Left, Angle = 50, Range = 45, Brightness = 1.2, Color = r.color, Shadows = false, Parent = r.lens })
end

function B.moving(m, r)
	part(m, "Base", Vector3.new(2.6, 0.9, 2.2), CFrame.new(0, -0.45, 0), DARK)
	part(m, "ArmL", Vector3.new(0.35, 2.2, 1.2), CFrame.new(-1.2, -1.9, 0), Color3.fromRGB(40, 40, 46))
	part(m, "ArmR", Vector3.new(0.35, 2.2, 1.2), CFrame.new(1.2, -1.9, 0), Color3.fromRGB(40, 40, 46))
	r.headLocal = CFrame.new(0, -2.6, 0)
	r.head = part(m, "Head", Vector3.new(1.9, 2.2, 1.9), r.headLocal, Color3.fromRGB(22, 22, 26))
	r.lensLocal = CFrame.new(0, -1.12, 0)
	r.lens = part(m, "Lens", Vector3.new(1.3, 0.1, 1.3), r.headLocal * r.lensLocal, r.color, Enum.Material.Neon)
	r.lens.Shape = Enum.PartType.Cylinder
	r.lens.Size = Vector3.new(0.1, 1.3, 1.3)
	r.lens.CFrame = r.headLocal * r.lensLocal * CFrame.Angles(0, 0, math.pi / 2)
	r.beam = beam(r.head, Vector3.new(0, -1.2, 0), Vector3.new(0, -95, 0), 1.2, 16, r.color, 0.45)
	r.light = New("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 25, Range = 60, Brightness = 1.2, Color = r.color, Shadows = false, Parent = r.head })
end

function B.speakers(m, r)
	-- two subwoofers on the floor, a slightly curved column of line-array boxes on top
	for i = 0, 1 do
		local y = 1.4 + i * 2.8
		part(m, "Sub", Vector3.new(4.4, 2.7, 3.2), CFrame.new(0, y, 0), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric)
		cyl(m, "Woofer", 0.15, 2.1, CFrame.new(-1, y, 1.62) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(34, 34, 38))
		cyl(m, "Woofer", 0.15, 2.1, CFrame.new(1, y, 1.62) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(34, 34, 38))
	end
	local y = 5.7
	for i = 0, 4 do
		local tilt = math.rad(i * 3)
		local cf = CFrame.new(0, y + i * 1.25, -i * 0.06) * CFrame.Angles(tilt, 0, 0)
		part(m, "Line", Vector3.new(4.2, 1.15, 2.6), cf, Color3.fromRGB(22, 22, 25))
		part(m, "Grille", Vector3.new(4, 0.9, 0.08), cf * CFrame.new(0, 0, 1.32), Color3.fromRGB(45, 45, 50), Enum.Material.Fabric)
	end
	part(m, "Logo", Vector3.new(1.2, 0.25, 0.06), CFrame.new(0, 0.6, 1.62), r.color, Enum.Material.Neon)
end

function B.drums(m, r)
	local red = Color3.fromRGB(150, 20, 34)
	local chrome = Color3.fromRGB(200, 200, 210)
	local gold = Color3.fromRGB(220, 180, 70)
	part(m, "Riser", Vector3.new(9, 1, 8), CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 40, 46))
	part(m, "RiserEdge", Vector3.new(9.1, 0.15, 0.15), CFrame.new(0, 1, 4), r.color, Enum.Material.Neon)
	local top = 1
	-- bass drum (lying, facing the crowd) with a printed front head
	cyl(m, "Kick", 1.8, 2.9, CFrame.new(0, top + 1.5, 1.2) * CFrame.Angles(math.pi / 2, 0, 0), red)
	cyl(m, "KickHead", 0.08, 2.7, CFrame.new(0, top + 1.5, 2.12) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(235, 235, 240))
	cyl(m, "KickLogo", 0.1, 1.2, CFrame.new(0, top + 1.5, 2.15) * CFrame.Angles(math.pi / 2, 0, 0), r.color, Enum.Material.Neon)
	-- rack toms on the bass drum
	for _, x in ipairs({ -0.7, 0.7 }) do
		cyl(m, "RackTom", 0.9, 1.2, CFrame.new(x, top + 3.3, 1.0) * CFrame.Angles(math.rad(-20), 0, 0), red)
	end
	-- floor tom with legs
	cyl(m, "FloorTom", 1.3, 1.7, CFrame.new(2.3, top + 1.7, 0.2), red)
	for _, a in ipairs({ 0, 2.1, 4.2 }) do
		tube(m, Vector3.new(2.3 + math.cos(a) * 0.9, top + 1.4, 0.2 + math.sin(a) * 0.9), Vector3.new(2.3 + math.cos(a) * 1.1, top, 0.2 + math.sin(a) * 1.1), 0.1, chrome)
	end
	-- snare on a stand
	tube(m, Vector3.new(-1.9, top, 0.4), Vector3.new(-1.9, top + 2, 0.4), 0.12, chrome)
	cyl(m, "Snare", 0.6, 1.4, CFrame.new(-1.9, top + 2.3, 0.4), Color3.fromRGB(230, 230, 236))
	-- hi-hat
	tube(m, Vector3.new(-3.1, top, -0.2), Vector3.new(-3.1, top + 3.1, -0.2), 0.1, chrome)
	cyl(m, "HiHat", 0.06, 1.4, CFrame.new(-3.1, top + 3.0, -0.2), gold, Enum.Material.Metal)
	cyl(m, "HiHat", 0.06, 1.4, CFrame.new(-3.1, top + 3.15, -0.2), gold, Enum.Material.Metal)
	-- crash and ride on boom stands
	for _, c in ipairs({ { -2.6, 1.3, 4.2 }, { 3.0, 1.5, 3.9 } }) do
		tube(m, Vector3.new(c[1], top, c[2] - 0.6), Vector3.new(c[1], top + c[3], c[2] - 0.6), 0.1, chrome)
		cyl(m, "Cymbal", 0.06, 2.2, CFrame.new(c[1], top + c[3] + 0.1, c[2] - 0.3) * CFrame.Angles(math.rad(12), 0, 0), gold, Enum.Material.Metal)
	end
	-- throne
	tube(m, Vector3.new(0, top, -1.8), Vector3.new(0, top + 1.6, -1.8), 0.15, chrome)
	cyl(m, "Seat", 0.4, 1.4, CFrame.new(0, top + 1.8, -1.8), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
end

function B.piano(m, r)
	local black = Color3.fromRGB(8, 8, 10)
	-- curved grand piano body: keyboard case + tapering tail
	part(m, "Case", Vector3.new(5.2, 1.3, 2.6), CFrame.new(0, 3.3, 2.0), black, Enum.Material.Glass)
	part(m, "Body", Vector3.new(4.6, 1.3, 3), CFrame.new(-0.3, 3.3, -0.8), black, Enum.Material.Glass)
	cyl(m, "Tail", 1.3, 3.6, CFrame.new(-0.8, 3.3, -2.3), black, Enum.Material.Glass)
	part(m, "Lid", Vector3.new(4.8, 0.12, 5.6), CFrame.new(0.4, 5.1, -0.4) * CFrame.Angles(0, 0, math.rad(28)), black, Enum.Material.Glass)
	tube(m, Vector3.new(1.9, 3.95, -0.4), Vector3.new(2.3, 5.1, -0.4), 0.1, Color3.fromRGB(30, 30, 30))
	part(m, "WhiteKeys", Vector3.new(4.6, 0.25, 0.9), CFrame.new(0, 3.55, 3.55), Color3.new(1, 1, 1))
	for i = 0, 8 do
		part(m, "BlackKey", Vector3.new(0.2, 0.2, 0.5), CFrame.new(-2 + i * 0.5, 3.75, 3.35), black)
	end
	for _, p in ipairs({ { -2.2, 2.9 }, { 2.2, 2.9 }, { -0.8, -2.8 } }) do
		part(m, "Leg", Vector3.new(0.5, 2.7, 0.5), CFrame.new(p[1], 1.35, p[2]), black, Enum.Material.Glass)
	end
	part(m, "Bench", Vector3.new(2.6, 0.4, 1.1), CFrame.new(0, 1.9, 5.2), black, Enum.Material.Leather)
	part(m, "BenchLegs", Vector3.new(2.4, 1.7, 0.9), CFrame.new(0, 0.85, 5.2), black)
end

function B.djbooth(m, r)
	part(m, "Table", Vector3.new(9, 3.6, 3.2), CFrame.new(0, 1.8, 0), Color3.fromRGB(16, 16, 20))
	part(m, "Top", Vector3.new(9.2, 0.2, 3.4), CFrame.new(0, 3.7, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	-- LED front made of glowing bars
	r.neon = {}
	for i = 0, 7 do
		table.insert(r.neon, part(m, "LED", Vector3.new(0.9, 3, 0.1), CFrame.new(-3.85 + i * 1.1, 1.8, 1.62), r.color, Enum.Material.Neon))
	end
	for _, x in ipairs({ -2.8, 2.8 }) do
		part(m, "Deck", Vector3.new(2.2, 0.3, 2), CFrame.new(x, 3.95, 0), Color3.fromRGB(28, 28, 32))
		r.platter = cyl(m, "Platter", 0.12, 1.6, CFrame.new(x, 4.15, 0), Color3.fromRGB(20, 20, 22), Enum.Material.Metal)
		cyl(m, "Label", 0.14, 0.5, CFrame.new(x, 4.17, 0), r.color, Enum.Material.Neon)
	end
	part(m, "Mixer", Vector3.new(1.8, 0.4, 1.8), CFrame.new(0, 4, 0), Color3.fromRGB(55, 55, 62))
	part(m, "LaptopBase", Vector3.new(1.6, 0.1, 1.1), CFrame.new(0, 4.5, -0.9), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
	part(m, "LaptopScreen", Vector3.new(1.6, 1.1, 0.08), CFrame.new(0, 5.05, -1.45) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
	part(m, "LaptopGlow", Vector3.new(1.4, 0.9, 0.02), CFrame.new(0, 5.05, -1.4) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon)
end

function B.beambar(m, r)
	part(m, "Base", Vector3.new(2.4, 1.2, 2.4), CFrame.new(0, 0.6, 0), DARK)
	r.headLocal = CFrame.new(0, 2, 0)
	r.head = part(m, "Head", Vector3.new(1.6, 1.6, 1.6), r.headLocal, Color3.fromRGB(20, 20, 24))
	r.beam = beam(r.head, Vector3.new(0, 0.8, 0), Vector3.new(0, 140, 0), 0.8, 7, r.color, 0.3)
end

function B.strobe(m, r)
	part(m, "Clamp", Vector3.new(0.4, 1, 0.4), CFrame.new(0, -0.5, 0), METAL)
	part(m, "Body", Vector3.new(3.4, 1.4, 1), CFrame.new(0, -1.6, 0), DARK)
	r.flash = part(m, "Flash", Vector3.new(3, 1, 0.2), CFrame.new(0, -1.6, 0.55), Color3.fromRGB(60, 60, 66), Enum.Material.Neon)
	r.light = New("PointLight", { Range = 40, Brightness = 0, Color = WHITE, Shadows = false, Parent = r.flash })
end

function B.blinder(m, r)
	part(m, "Clamp", Vector3.new(0.4, 1, 0.4), CFrame.new(0, -0.5, 0), METAL)
	part(m, "Body", Vector3.new(4.4, 2.4, 1), CFrame.new(0, -2.2, 0), DARK)
	r.bulbs = {}
	for i = 0, 3 do
		local x = -1.5 + i
		table.insert(r.bulbs, part(m, "Bulb", Vector3.new(0.8, 1.6, 0.2), CFrame.new(x, -2.2, 0.55), Color3.fromRGB(60, 50, 40), Enum.Material.Neon))
	end
	r.light = New("PointLight", { Range = 50, Brightness = 0, Color = WARM, Shadows = false, Parent = r.bulbs[2] })
end

function B.followspot(m, r)
	cyl(m, "Stand", 6, 0.6, CFrame.new(0, 3, 0), METAL)
	r.head = part(m, "Body", Vector3.new(1.6, 1.6, 3.2), CFrame.new(0, 6.6, 0), DARK)
	r.target = part(m, "Target", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 6, -30), DARK)
	r.target.Transparency = 1
	local a0 = New("Attachment", { Position = Vector3.new(0, 0, -1.6), Parent = r.head })
	local a1 = New("Attachment", { Parent = r.target })
	r.beam = New("Beam", {
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = 1,
		Width1 = 7,
		Color = ColorSequence.new(WARM),
		Transparency = NumberSequence.new(0.5, 0.8),
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 1,
		Enabled = false,
		Parent = r.head,
	})
end

function B.discoball(m, r)
	part(m, "String", Vector3.new(0.15, 4, 0.15), CFrame.new(0, -2, 0), METAL)
	r.ball = part(m, "Ball", Vector3.new(3.5, 3.5, 3.5), CFrame.new(0, -5.5, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Foil, Enum.PartType.Ball)
	r.ball.Reflectance = 0.6
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 25,
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(20, 30),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.6, 0),
		LightEmission = 1,
		Parent = r.ball,
	})
end

local function screen(m, r, w, h, legs)
	local y = 1 + h / 2
	if legs then
		part(m, "LegL", Vector3.new(0.6, 1, 0.6), CFrame.new(-w / 2 + 1, 0.5, 0), METAL)
		part(m, "LegR", Vector3.new(0.6, 1, 0.6), CFrame.new(w / 2 - 1, 0.5, 0), METAL)
	end
	r.panel = part(m, "Screen", Vector3.new(w, h, 0.6), CFrame.new(0, y, 0), Color3.fromRGB(8, 8, 10))
	r.frame, r.label, r.grad = surfaceText(r.panel, Enum.NormalId.Back, r.artistName or "HEADLINER", WHITE, r.color)
	-- optional content layers: an image (decal id) and a live camera (ViewportFrame)
	r.image = New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, Parent = r.frame })
	r.live = New("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Ambient = Color3.fromRGB(200, 200, 210), LightColor = Color3.new(1, 1, 1), Visible = false, Parent = r.frame })
	r.liveCam = New("Camera", { FieldOfView = 35, Parent = r.live })
	r.live.CurrentCamera = r.liveCam
	local rec = r.rec or {}
	if rec.screen == "image" and rec.screenImage then
		r.image.Image = "rbxassetid://" .. tostring(rec.screenImage)
	end
end

-- copies of real parts inside a screen's ViewportFrame ("live camera")
local function liveFeed(refs, sources, camCF)
	if not refs.liveCopies then
		refs.liveCopies = {}
		for _, src in ipairs(sources) do
			local c = src:Clone()
			c.Parent = refs.live
			table.insert(refs.liveCopies, { src = src, copy = c })
		end
	end
	for _, pair in ipairs(refs.liveCopies) do
		pair.copy.CFrame = pair.src.CFrame
		pair.copy.Transparency = pair.src.Transparency
	end
	refs.liveCam.CFrame = camCF
end

function B.led(m, r)
	local w, d = dims(r, r.def)
	screen(m, r, w, d, true)
end

function B.led_side(m, r)
	screen(m, r, 10, 18, true)
end

function B.led_floor(m, r)
	local w, d = dims(r, r.def)
	local nx, nz = math.clamp(math.floor(w / 4 + 0.5), 1, 10), math.clamp(math.floor(d / 4 + 0.5), 1, 10)
	local tw, td = w / nx, d / nz
	r.tiles = {}
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local t = part(m, "Tile", Vector3.new(tw - 0.1, 0.3, td - 0.1), CFrame.new(-w / 2 + tw * (ix + 0.5), 0.15, -d / 2 + td * (iz + 0.5)), r.color, Enum.Material.Neon)
			t.Transparency = 0.15
			table.insert(r.tiles, t)
		end
	end
end

function B.neonsign(m, r)
	part(m, "PoleL", Vector3.new(0.5, 6, 0.5), CFrame.new(-8, 3, 0), METAL)
	part(m, "PoleR", Vector3.new(0.5, 6, 0.5), CFrame.new(8, 3, 0), METAL)
	r.panel = part(m, "Sign", Vector3.new(20, 5, 0.4), CFrame.new(0, 8.5, 0), Color3.fromRGB(12, 12, 14))
	r.panel.Transparency = 0.2
	r.frame, r.label = surfaceText(r.panel, Enum.NormalId.Back, r.artistName or "HEADLINER", r.color, nil)
end

function B.lift(m, r)
	r.platformLocal = CFrame.new(0, 0.2, 0)
	r.platform = part(m, "Platform", Vector3.new(6, 0.4, 6), r.platformLocal, Color3.fromRGB(60, 60, 70), Enum.Material.DiamondPlate)
	r.ring = part(m, "Ring", Vector3.new(6.6, 0.1, 6.6), CFrame.new(0, 0.05, 0), r.color, Enum.Material.Neon)
end

function B.scissor(m, r)
	part(m, "Base", Vector3.new(8, 0.6, 8), CFrame.new(0, 0.3, 0), DARK)
	r.column = part(m, "Column", Vector3.new(3, 0.6, 3), CFrame.new(0, 0.6, 0), METAL, Enum.Material.DiamondPlate)
	r.platform = part(m, "Platform", Vector3.new(8, 0.6, 8), CFrame.new(0, 0.9, 0), Color3.fromRGB(60, 60, 70), Enum.Material.DiamondPlate)
	r.edge = part(m, "Edge", Vector3.new(8.4, 0.2, 8.4), CFrame.new(0, 1.2, 0), r.color, Enum.Material.Neon)
end

function B.pyro(m, r)
	part(m, "Box", Vector3.new(2.2, 1, 2.2), CFrame.new(0, 0.5, 0), DARK)
	r.nozzle = part(m, "Nozzle", Vector3.new(1, 1, 1), CFrame.new(0, 1.5, 0), DARK)
	r.nozzle.Transparency = 1
	r.fire = New("Fire", { Size = 14, Heat = 25, Color = Color3.fromRGB(255, 140, 30), SecondaryColor = Color3.fromRGB(255, 60, 0), Enabled = false, Parent = r.nozzle })
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(30, 45),
		SpreadAngle = Vector2.new(8, 8),
		Size = NumberSequence.new(3, 0.5),
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 0)),
		LightEmission = 1,
		Acceleration = Vector3.new(0, -5, 0),
		Parent = r.nozzle,
	})
	r.light = New("PointLight", { Range = 60, Brightness = 0, Color = Color3.fromRGB(255, 150, 50), Shadows = false, Parent = r.nozzle })
end

function B.sparks(m, r)
	cyl(m, "Base", 1, 1.6, CFrame.new(0, 0.5, 0), DARK)
	r.nozzle = part(m, "Nozzle", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.2, 0), DARK)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 220,
		Lifetime = NumberRange.new(1, 1.6),
		Speed = NumberRange.new(25, 35),
		SpreadAngle = Vector2.new(12, 12),
		Size = NumberSequence.new(0.5, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 170, 40)),
		LightEmission = 1,
		Acceleration = Vector3.new(0, -40, 0),
		Parent = r.nozzle,
	})
end

function B.confetti(m, r)
	part(m, "Base", Vector3.new(2, 1, 2), CFrame.new(0, 0.5, 0), DARK)
	r.nozzle = cyl(m, "Tube", 3, 1.2, CFrame.new(0, 2.5, 0), METAL)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(60, 85),
		SpreadAngle = Vector2.new(22, 22),
		Size = NumberSequence.new(0.7, 0.5),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 64, 129)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 220, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 255, 120)),
		}),
		Drag = 1.6,
		Acceleration = Vector3.new(0, -9, 0),
		RotSpeed = NumberRange.new(-300, 300),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.4,
		EmissionDirection = Enum.NormalId.Right, -- the tube is a rotated cylinder: its +X points up
		Parent = r.nozzle,
	})
end

function B.co2(m, r)
	part(m, "Base", Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 0.7, 0), Color3.fromRGB(200, 200, 210))
	r.nozzle = part(m, "Nozzle", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 1.6, 0), DARK)
	r.smoke = New("Smoke", { Color = Color3.fromRGB(235, 240, 255), Opacity = 0.6, RiseVelocity = 25, Size = 3, Enabled = false, Parent = r.nozzle })
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(45, 60),
		SpreadAngle = Vector2.new(6, 6),
		Size = NumberSequence.new(2, 7),
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)),
		Drag = 2,
		Parent = r.nozzle,
	})
end

function B.laser(m, r)
	part(m, "Clamp", Vector3.new(0.4, 1, 0.4), CFrame.new(0, -0.5, 0), METAL)
	r.headLocal = CFrame.new(0, -1.6, 0)
	r.head = part(m, "Head", Vector3.new(2, 1.2, 2), r.headLocal, DARK)
	r.beams = {}
	for i = -3, 3 do
		local ang = math.rad(i * 9)
		local dir = Vector3.new(math.sin(ang), -0.35, math.cos(ang)).Unit * 160
		local b = beam(r.head, Vector3.new(0, -0.4, 0.8), dir, 0.15, 0.4, Color3.fromRGB(60, 255, 90), 0)
		b.Enabled = false
		table.insert(r.beams, b)
	end
end

function B.haze(m, r)
	part(m, "Box", Vector3.new(2.5, 1.5, 3), CFrame.new(0, 0.75, 0), DARK)
	r.nozzle = part(m, "Nozzle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.6, 1.2), DARK)
	r.smoke = New("Smoke", { Color = Color3.fromRGB(180, 180, 200), Opacity = 0.08, RiseVelocity = 1.5, Size = 18, Enabled = false, Parent = r.nozzle })
end

function B.fireworks(m, r)
	part(m, "Rack", Vector3.new(4, 2, 2), CFrame.new(0, 1, 0), DARK)
	for i = -1, 1 do
		cyl(m, "Mortar", 1.6, 0.8, CFrame.new(i * 1.2, 2.6, 0), METAL)
	end
	r.burst = part(m, "Burst", Vector3.new(1, 1, 1), CFrame.new(0, 75, 0), DARK)
	r.burst.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(28, 40),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(1.6, 0),
		Color = ColorSequence.new(r.color, Color3.fromRGB(255, 240, 200)),
		LightEmission = 1,
		Drag = 0.8,
		Acceleration = Vector3.new(0, -12, 0),
		Parent = r.burst,
	})
end

function B.inflatable(m, r)
	part(m, "Base", Vector3.new(6, 0.5, 6), CFrame.new(0, 0.25, 0), DARK)
	r.ball = part(m, "Ball", Vector3.new(1, 1, 1), CFrame.new(0, 1, 0), r.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	r.eyeL = part(m, "EyeL", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1, 0), WHITE, nil, Enum.PartType.Ball)
	r.eyeR = part(m, "EyeR", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1, 0), WHITE, nil, Enum.PartType.Ball)
	r.inflate = 0.05
end

function B.palm(m, r)
	for i = 0, 5 do
		cyl(m, "Trunk", 2.2, 1.2 - i * 0.08, CFrame.new(i * 0.25, 1.1 + i * 2.1, 0), Color3.fromRGB(120, 80, 50))
	end
	r.neon = {}
	for i = 0, 5 do
		local a = i * math.pi / 3
		local leaf = part(m, "Leaf", Vector3.new(0.5, 0.3, 7), CFrame.new(1.4, 13.2, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, 3.2), Color3.fromRGB(60, 255, 140), Enum.Material.Neon)
		table.insert(r.neon, leaf)
	end
end

------------------------------------------------------------------ public API
-- opts: { color = Color3, artistName = string }
function Builder.build(def, opts)
	opts = opts or {}
	local model = New("Model", { Name = def.id })
	local base = part(model, "Pivot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), DARK)
	base.Transparency = 1
	model.PrimaryPart = base
	local refs = {
		def = def,
		rec = opts.rec,
		kind = def.id,
		model = model,
		color = opts.color or UI.Theme.accent,
		artistName = opts.artistName,
		phase = math.random() * 6.28,
		cf = CFrame.new(),
	}
	local fn = B[def.id]
	if fn then
		fn(model, refs)
	end
	return refs
end

function Builder.place(refs, cf)
	refs.cf = cf
	refs.model:PivotTo(cf)
	if refs.head and refs.headLocal then
		refs.headHome = cf * refs.headLocal
	end
end

-- Makes a model see-through for the placement preview (green = ok, red = not allowed)
function Builder.ghost(refs, ok)
	New("Highlight", {
		FillColor = ok and Color3.fromRGB(60, 255, 120) or Color3.fromRGB(255, 60, 60),
		FillTransparency = 0.55,
		OutlineColor = Color3.new(1, 1, 1),
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Parent = refs.model,
	})
	for _, d in ipairs(refs.model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name ~= "Pivot" and d.Name ~= "Target" and d.Name ~= "Nozzle" and d.Name ~= "Burst" then
				d.Transparency = 0.25
			end
			d.CanQuery = false
		elseif d:IsA("Beam") or d:IsA("SurfaceGui") or d:IsA("Light") then
			d.Enabled = false
		end
	end
end

local function setNeon(refs, c)
	if refs.neon then
		for _, p in ipairs(refs.neon) do
			p.Color = c
		end
	end
end

local function launchShell(refs)
	local start = refs.cf * CFrame.new(0, 3, 0)
	local shell = part(refs.model, "Shell", Vector3.new(0.8, 0.8, 0.8), start, WARM, Enum.Material.Neon, Enum.PartType.Ball)
	local tw = TweenService:Create(shell, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = refs.cf * CFrame.new(math.random(-6, 6), 75, math.random(-6, 6)) })
	tw.Completed:Connect(function()
		if refs.burst and refs.burst.Parent then
			refs.burst.CFrame = shell.CFrame
			refs.emitter:Emit(140)
		end
		shell:Destroy()
	end)
	tw:Play()
end

-- Called every frame during a show. ctx: see LiveShow.lua
function Builder.animate(refs, ctx)
	local k = refs.kind
	local t = ctx.t
	local c1, c2 = ctx.c1, ctx.c2
	local hit = ctx.hit
	if k == "par" then
		local c = (refs.phase > 3.14) and c2 or c1
		if refs.lastC ~= c then
			refs.lastC = c
			refs.lens.Color = c
			refs.light.Color = c
		end
		refs.light.Brightness = 0.4 + 1.2 * ctx.intensity
	elseif k == "moving" then
		local sp = ctx.sweep
		local yaw = math.sin(t * 0.8 * sp + refs.phase) * 0.7
		local tilt = -0.5 + math.sin(t * 1.1 * sp + refs.phase * 1.3) * 0.38
		refs.head.CFrame = refs.headHome * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		refs.lens.CFrame = refs.head.CFrame * refs.lensLocal * CFrame.Angles(0, 0, math.pi / 2)
		local c = (math.floor(ctx.beatCount / 8) % 2 == 0) and c1 or c2
		if refs.lastC ~= c then
			refs.lastC = c
			refs.beam.Color = ColorSequence.new(c)
			refs.light.Color = c
			refs.lens.Color = c
		end
		refs.beam.Enabled = ctx.intensity > 0.15
	elseif k == "beambar" then
		local sp = ctx.sweep
		refs.head.CFrame = refs.headHome * CFrame.Angles(math.sin(t * 0.9 * sp + refs.phase) * 0.5, 0, math.cos(t * 0.7 * sp + refs.phase) * 0.35)
		local c = (math.floor(ctx.beatCount / 4) % 2 == 0) and c2 or c1
		if refs.lastC ~= c then
			refs.lastC = c
			refs.beam.Color = ColorSequence.new(c)
		end
		refs.beam.Enabled = ctx.intensity > 0.3
	elseif k == "strobe" then
		local on = ctx.strobe and (math.floor(t * 14 + refs.phase) % 2 == 0)
		refs.flash.Color = on and WHITE or Color3.fromRGB(60, 60, 66)
		refs.light.Brightness = on and 3 or 0
	elseif k == "blinder" then
		local b = ctx.blind
		local c = Color3.fromRGB(60, 50, 40):Lerp(WARM, b)
		for _, bulb in ipairs(refs.bulbs) do
			bulb.Color = c
		end
		refs.light.Brightness = b * 3.5
	elseif k == "followspot" then
		refs.target.CFrame = CFrame.new(ctx.artistPos)
		refs.beam.Enabled = true
	elseif k == "discoball" then
		refs.ball.CFrame = refs.cf * CFrame.new(0, -5.5, 0) * CFrame.Angles(0, t * 1.5, 0)
		refs.emitter.Enabled = ctx.seg == 3 or ctx.seg == 4
	elseif k == "led" or k == "led_side" then
		refs.frame.BackgroundColor3 = c1:Lerp(c2, 0.5 + 0.5 * math.sin(t * 1.3))
		if refs.grad then
			refs.grad.Rotation = (t * 40) % 360
		end
		-- what is on the screen (set in the stage designer)
		local cfg = Builder.screenConfig(refs, ctx.spotIndex)
		local mode = cfg.m
		local txt = ""
		if mode == "song" then
			txt = ctx.screenText or ""
		elseif mode == "artist" then
			txt = ctx.artistName or ""
		elseif mode == "text" then
			txt = cfg.text or ""
		end
		if refs.label.Text ~= txt then
			refs.label.Text = txt
		end
		refs.image.Visible = mode == "image"
		if mode == "image" and cfg.img then
			local img = "rbxassetid://" .. tostring(cfg.img)
			if refs.image.Image ~= img then
				refs.image.Image = img
			end
		end
		local live = (mode == "liveArtist" and ctx.livePerformer) or (mode == "liveCrowd" and ctx.liveCrowd) or nil
		refs.live.Visible = live ~= nil
		if live then
			liveFeed(refs, live.parts, live.cam)
		end
	elseif k == "led_floor" then
		if refs.lastBeat ~= ctx.beatCount then
			refs.lastBeat = ctx.beatCount
			for i, tile in ipairs(refs.tiles) do
				tile.Color = ((i + ctx.beatCount) % 2 == 0) and c1 or c2
			end
		end
	elseif k == "neonsign" then
		refs.label.TextColor3 = c1
		refs.label.TextTransparency = 0.25 * ctx.beat
		if ctx.artistName and refs.label.Text ~= ctx.artistName then
			refs.label.Text = ctx.artistName
		end
	elseif k == "lift" then
		refs.platform.CFrame = refs.cf * refs.platformLocal * CFrame.new(0, ((refs.liftT or ctx.liftT) - 1) * 10, 0)
		refs.ring.Color = c1
	elseif k == "scissor" then
		local h = ctx.scissorT * 16
		refs.column.Size = Vector3.new(3, 0.6 + h, 3)
		refs.column.CFrame = refs.cf * CFrame.new(0, 0.6 + h / 2, 0)
		refs.platform.CFrame = refs.cf * CFrame.new(0, 0.9 + h, 0)
		refs.edge.CFrame = refs.cf * CFrame.new(0, 1.2 + h, 0)
		refs.edge.Color = c1
	elseif k == "pyro" then
		if hit.pyro then
			refs.fire.Enabled = true
			refs.emitter:Emit(45)
			refs.light.Brightness = 2.5
			refs.offAt = t + 0.9
		elseif refs.offAt and t > refs.offAt then
			refs.offAt = nil
			refs.fire.Enabled = false
			refs.light.Brightness = 0
		end
	elseif k == "sparks" then
		if hit.sparks then
			refs.emitter.Enabled = true
			refs.offAt = t + 2.5
		elseif refs.offAt and t > refs.offAt then
			refs.offAt = nil
			refs.emitter.Enabled = false
		end
	elseif k == "confetti" then
		if hit.confetti then
			refs.emitter:Emit(160)
		end
	elseif k == "co2" then
		if hit.co2 then
			refs.smoke.Enabled = true
			refs.emitter:Emit(60)
			refs.offAt = t + 1.2
		elseif refs.offAt and t > refs.offAt then
			refs.offAt = nil
			refs.smoke.Enabled = false
		end
	elseif k == "laser" then
		local on = ctx.lasers
		if refs.lastOn ~= on then
			refs.lastOn = on
			for _, b in ipairs(refs.beams) do
				b.Enabled = on
			end
		end
		if on then
			refs.head.CFrame = refs.headHome * CFrame.Angles(0, math.sin(t * 0.9 + refs.phase) * 0.8, 0) * CFrame.Angles(math.sin(t * 1.4) * 0.25, 0, 0)
			local c = (math.floor(ctx.beatCount / 16) % 2 == 0) and Color3.fromRGB(60, 255, 90) or c2
			if refs.lastC ~= c then
				refs.lastC = c
				for _, b in ipairs(refs.beams) do
					b.Color = ColorSequence.new(c)
				end
			end
		end
	elseif k == "haze" then
		refs.smoke.Enabled = true
	elseif k == "fireworks" then
		if hit.fireworks then
			for i = 0, 2 do
				task.delay(i * 0.35, function()
					if refs.model.Parent then
						launchShell(refs)
					end
				end)
			end
		end
	elseif k == "inflatable" then
		local target = 0.05 + 0.95 * ctx.inflate
		if math.abs(target - refs.inflate) > 0.002 then
			refs.inflate = target
			local d = 20 * target
			refs.ball.Size = Vector3.new(d, d, d)
			refs.ball.CFrame = refs.cf * CFrame.new(0, 0.5 + d / 2, 0)
			local e = math.max(0.2, d * 0.14)
			refs.eyeL.Size = Vector3.new(e, e, e)
			refs.eyeR.Size = Vector3.new(e, e, e)
			refs.eyeL.CFrame = refs.cf * CFrame.new(-d * 0.18, 0.5 + d * 0.62, d * 0.44)
			refs.eyeR.CFrame = refs.cf * CFrame.new(d * 0.18, 0.5 + d * 0.62, d * 0.44)
		end
	elseif (k == "deck" or k == "deck_tri" or k == "deck_corner" or k == "deck_round" or k == "stairs") and refs.ledParts then
		-- LED video floor: colours run across the stage on the beat
		if refs.lastBeat ~= ctx.beatCount then
			refs.lastBeat = ctx.beatCount
			local c = ((ctx.beatCount % 2) == 0) and c1 or c2
			for _, p in ipairs(refs.ledParts) do
				p.Color = c:Lerp(Color3.new(0, 0, 0), 0.55)
			end
			setNeon(refs, c)
		end
	elseif k == "deck" or k == "deck_tri" or k == "deck_corner" or k == "deck_round" or k == "djbooth" or k == "palm" then
		local c = (k == "palm") and c2 or c1
		if refs.lastC ~= c then
			refs.lastC = c
			setNeon(refs, c)
		end
	end
end

-- Spot markers are only visible in the designer
function Builder.hideMarker(refs)
	if refs.marker then
		refs.marker.Transparency = 1
		refs.gui.Enabled = false
	end
end

-- What a screen shows at a spot (falls back to the default, then to the old single setting)
local SCREEN_NAMES = { song = "SONG TITLE", artist = "ARTIST NAME", text = "TEXT", image = "IMAGE", liveArtist = "LIVE CAM: ARTIST", liveCrowd = "LIVE CAM: CROWD" }
Builder.SCREEN_NAMES = SCREEN_NAMES
function Builder.screenConfig(refs, spot)
	local rec = refs.rec or {}
	local base = (refs.kind == "led_side") and "artist" or "song"
	if rec.scr then
		return rec.scr[tostring(spot or 0)] or rec.scr.default or { m = base }
	end
	if rec.screenSpot and spot ~= rec.screenSpot then
		return { m = "song" }
	end
	return { m = rec.screen or base, text = rec.screenText, img = rec.screenImage }
end

-- Resets an item to its resting look (used after a show and in the designer)
function Builder.rest(refs)
	local k = refs.kind
	if (k == "led" or k == "led_side") and refs.label then
		-- designer preview: say what the screen will show
		local cfg = Builder.screenConfig(refs, nil)
		local rec = refs.rec or {}
		local extra = 0
		for key in pairs(rec.scr or {}) do
			if key ~= "default" then
				extra = extra + 1
			end
		end
		local txt = (cfg.m == "text" and (cfg.text or "")) or SCREEN_NAMES[cfg.m] or ""
		refs.label.Text = txt .. ((extra > 0) and ("  (+" .. extra .. " spot" .. (extra > 1 and "s" or "") .. ")") or "")
		refs.image.Visible = cfg.m == "image" and cfg.img ~= nil
		if cfg.img then
			refs.image.Image = "rbxassetid://" .. tostring(cfg.img)
		end
	end
	if k == "lift" then
		refs.platform.CFrame = refs.cf * refs.platformLocal
	elseif k == "inflatable" then
		refs.inflate = 0
		Builder.animate(refs, { t = 0, c1 = refs.color, c2 = refs.color, hit = {}, inflate = 0.25, beat = 0, beatCount = 0 })
	end
end

return Builder
