-- Builds 3D models for stage items and animates them during shows.
-- Every item is built around the local origin (bottom centre for floor items, hanging point for rig items)
-- and then moved into place with Builder.place().
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
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

-- adorn = true: the SurfaceGui lives in the PlayerGui and points at the part (Adornee).
-- Roblox only draws ViewportFrames (live camera) in SurfaceGuis that are NOT inside the Workspace.
local function surfaceText(p, face, text, textColor, bg, adorn)
	local pg = adorn and Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	local gui = New("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 20,
		LightInfluence = 0,
		Brightness = 2,
		ResetOnSpawn = false,
		Adornee = pg and p or nil,
		Parent = pg or p,
	})
	if pg then
		-- remove the gui together with the screen
		p.Destroying:Connect(function()
			gui:Destroy()
		end)
		p.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				gui:Destroy()
			end
		end)
	end
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
	-- a real cylinder (its axis is local X, turned to point from a to b)
	return part(m, "Tube", Vector3.new(len, d or 0.18, d or 0.18), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color or METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
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

-- drum shell with chrome hoops on both ends, lugs around it and a white head (axis = cf's up vector)
local function drumShell(m, name, len, d, cf, shellColor, head)
	local chrome = Color3.fromRGB(205, 205, 215)
	cyl(m, name, len, d, cf, shellColor, Enum.Material.Glass)
	for _, y in ipairs({ -len / 2, len / 2 }) do
		cyl(m, "Hoop", 0.12, d + 0.14, cf * CFrame.new(0, y, 0), chrome, Enum.Material.Metal)
	end
	cyl(m, "Head", 0.04, d - 0.05, cf * CFrame.new(0, len / 2 + 0.05, 0), head or Color3.fromRGB(238, 236, 228))
	local n = (d > 2) and 10 or 6
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		part(m, "Lug", Vector3.new(0.14, math.min(0.5, len * 0.45), 0.14), cf * CFrame.new(math.cos(a) * (d / 2 + 0.06), 0, math.sin(a) * (d / 2 + 0.06)), chrome, Enum.Material.Metal)
	end
end
-- cymbal: wide thin disc with a bell in the middle
local function cymbal(m, d, cf)
	local gold = Color3.fromRGB(214, 172, 66)
	cyl(m, "Cymbal", 0.05, d, cf, gold, Enum.Material.Metal)
	cyl(m, "CymbalInner", 0.07, d * 0.62, cf * CFrame.new(0, 0.03, 0), gold:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Metal)
	part(m, "Bell", Vector3.new(d * 0.24, d * 0.1, d * 0.24), cf * CFrame.new(0, 0.07, 0), gold, Enum.Material.Metal, Enum.PartType.Ball)
end

function B.drums(m, r)
	local shell = Color3.fromRGB(150, 20, 34)
	local chrome = Color3.fromRGB(205, 205, 215)
	part(m, "Riser", Vector3.new(9, 1, 8), CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 40, 46))
	part(m, "RiserSkirt", Vector3.new(9.05, 0.9, 8.05), CFrame.new(0, 0.45, 0), Color3.fromRGB(14, 14, 16), Enum.Material.Fabric)
	part(m, "RiserEdge", Vector3.new(9.1, 0.15, 0.15), CFrame.new(0, 1, 4), r.color, Enum.Material.Neon)
	part(m, "Carpet", Vector3.new(7, 0.06, 6), CFrame.new(0, 1.03, 0.2), Color3.fromRGB(70, 30, 30), Enum.Material.Fabric)
	local top = 1
	-- bass drum lying on its side, printed front head towards the crowd, spurs
	drumShell(m, "Kick", 1.8, 2.9, CFrame.new(0, top + 1.5, 1.2) * CFrame.Angles(math.pi / 2, 0, 0), shell, Color3.fromRGB(240, 240, 244))
	cyl(m, "KickLogo", 0.1, 1.3, CFrame.new(0, top + 1.5, 2.17) * CFrame.Angles(math.pi / 2, 0, 0), r.color, Enum.Material.Neon)
	for _, sx in ipairs({ -1, 1 }) do
		tube(m, Vector3.new(sx * 1.2, top + 0.7, 1.6), Vector3.new(sx * 1.8, top, 1.9), 0.1, chrome)
	end
	tube(m, Vector3.new(0, top + 0.1, -0.1), Vector3.new(0, top + 0.6, 0.15), 0.2, Color3.fromRGB(40, 40, 44)) -- pedal
	-- rack toms on a mount
	tube(m, Vector3.new(0, top + 2.95, 1.2), Vector3.new(0, top + 3.4, 1.0), 0.12, chrome)
	for _, x in ipairs({ -0.75, 0.75 }) do
		drumShell(m, "RackTom", 0.9, 1.25, CFrame.new(x, top + 3.45, 0.85) * CFrame.Angles(math.rad(-22), 0, x * -0.25), shell)
	end
	-- floor tom on three legs
	drumShell(m, "FloorTom", 1.4, 1.75, CFrame.new(2.4, top + 1.8, 0.1), shell)
	for _, a in ipairs({ 0.4, 2.5, 4.6 }) do
		tube(m, Vector3.new(2.4 + math.cos(a) * 0.95, top + 1.5, 0.1 + math.sin(a) * 0.95), Vector3.new(2.4 + math.cos(a) * 1.2, top, 0.1 + math.sin(a) * 1.2), 0.08, chrome)
	end
	-- snare on a tripod stand
	for _, a in ipairs({ 0, 2.1, 4.2 }) do
		tube(m, Vector3.new(-1.9, top + 1.1, 0.4), Vector3.new(-1.9 + math.cos(a) * 0.7, top, 0.4 + math.sin(a) * 0.7), 0.08, chrome)
	end
	tube(m, Vector3.new(-1.9, top + 1.1, 0.4), Vector3.new(-1.9, top + 2.0, 0.4), 0.1, chrome)
	drumShell(m, "Snare", 0.55, 1.45, CFrame.new(-1.9, top + 2.3, 0.4) * CFrame.Angles(0, 0, 0.08), Color3.fromRGB(215, 215, 222))
	-- hi-hat: tripod, rod, two cymbals
	for _, a in ipairs({ 0.5, 2.6, 4.7 }) do
		tube(m, Vector3.new(-3.1, top + 1, -0.2), Vector3.new(-3.1 + math.cos(a) * 0.7, top, -0.2 + math.sin(a) * 0.7), 0.08, chrome)
	end
	tube(m, Vector3.new(-3.1, top + 1, -0.2), Vector3.new(-3.1, top + 3.2, -0.2), 0.1, chrome)
	cymbal(m, 1.45, CFrame.new(-3.1, top + 3.0, -0.2))
	cymbal(m, 1.45, CFrame.new(-3.1, top + 3.18, -0.2))
	-- crash and ride on boom stands
	for _, c in ipairs({ { -2.6, 1.3, 4.3, 0.25 }, { 3.0, 1.5, 4.0, -0.25 } }) do
		for _, a in ipairs({ 0.3, 2.4, 4.5 }) do
			tube(m, Vector3.new(c[1], top + 1.1, c[2] - 0.6), Vector3.new(c[1] + math.cos(a) * 0.8, top, c[2] - 0.6 + math.sin(a) * 0.8), 0.08, chrome)
		end
		tube(m, Vector3.new(c[1], top + 1.1, c[2] - 0.6), Vector3.new(c[1], top + c[3] - 0.6, c[2] - 0.6), 0.1, chrome)
		tube(m, Vector3.new(c[1], top + c[3] - 0.6, c[2] - 0.6), Vector3.new(c[1] - c[4] * 2, top + c[3], c[2] - 0.3), 0.08, chrome)
		cymbal(m, 2.3, CFrame.new(c[1] - c[4] * 2, top + c[3] + 0.1, c[2] - 0.3) * CFrame.Angles(math.rad(14), 0, c[4]))
	end
	-- throne
	for _, a in ipairs({ 0, 2.1, 4.2 }) do
		tube(m, Vector3.new(0, top + 0.9, -1.8), Vector3.new(math.cos(a) * 0.7, top, -1.8 + math.sin(a) * 0.7), 0.1, chrome)
	end
	tube(m, Vector3.new(0, top + 0.9, -1.8), Vector3.new(0, top + 1.6, -1.8), 0.15, chrome)
	cyl(m, "Seat", 0.45, 1.5, CFrame.new(0, top + 1.8, -1.8), Color3.fromRGB(20, 20, 22), Enum.Material.Leather)
end

-- grand piano: straight bass side, curved treble side, open lid on a prop stick, keyboard towards +z (the player)
local PIANO_OUTLINE = { { -2.5, 2.6 }, { -2.5, -4.2 }, { -2.1, -4.85 }, { -1.3, -4.95 }, { -0.4, -4.4 }, { 0.4, -3.2 }, { 1.0, -1.8 }, { 1.5, -0.6 }, { 2.1, 0.5 }, { 2.5, 1.2 }, { 2.5, 2.6 } }
local function pianoRight(z)
	local o = PIANO_OUTLINE
	for i = 3, #o - 1 do
		local a, b = o[i], o[i + 1]
		if z >= a[2] and z <= b[2] then
			return a[1] + (b[1] - a[1]) * (z - a[2]) / math.max(0.01, b[2] - a[2])
		end
	end
	return 2.5
end
function B.piano(m, r)
	local black = Color3.fromRGB(8, 8, 10)
	local y0, h = 2.7, 1.3
	-- the rim follows the outline
	local o = PIANO_OUTLINE
	for i = 1, #o do
		local a, b = o[i], o[i % #o + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 0.05 then
			part(m, "Rim", Vector3.new(len + 0.12, h, 0.18), CFrame.new((a[1] + b[1]) / 2, y0 + h / 2, (a[2] + b[2]) / 2) * CFrame.Angles(0, -math.atan2(dz, dx), 0), black, Enum.Material.Glass)
		end
	end
	-- inside: golden frame and soundboard, filled in strips
	for z = -4.6, 2.0, 0.6 do
		local xr = pianoRight(z + 0.3)
		local w = xr + 2.4
		if w > 0.3 then
			part(m, "Soundboard", Vector3.new(w, 0.1, 0.62), CFrame.new(-2.4 + w / 2, y0 + h - 0.35, z + 0.3), Color3.fromRGB(176, 136, 60), Enum.Material.Metal)
			part(m, "Bottom", Vector3.new(w, 0.3, 0.62), CFrame.new(-2.4 + w / 2, y0 + 0.15, z + 0.3), black, Enum.Material.Glass)
		end
	end
	for i = 0, 5 do
		part(m, "Strings", Vector3.new(0.05, 0.05, 6), CFrame.new(-2.1 + i * 0.35, y0 + h - 0.25, -1.2) * CFrame.Angles(0, -0.05 * i, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	end
	-- lid: hinged on the straight side, propped open over the curved side
	local hinge = CFrame.new(-2.5, y0 + h, 0) * CFrame.Angles(0, 0, math.rad(32))
	for z = -4.6, 2.0, 0.6 do
		local xr = pianoRight(z + 0.3)
		local w = xr + 2.5
		if w > 0.3 then
			part(m, "Lid", Vector3.new(w, 0.1, 0.62), hinge * CFrame.new(w / 2, 0.05, z + 0.3), black, Enum.Material.Glass)
		end
	end
	tube(m, Vector3.new(1.4, y0 + h, -0.8), (hinge * CFrame.new(3.6, 0, -0.8)).Position, 0.08, Color3.fromRGB(20, 20, 22))
	-- keyboard: key bed, 52 white keys (as 13 groups) and black keys, cheek blocks, fallboard, music stand
	part(m, "KeyBed", Vector3.new(4.9, 0.35, 1.2), CFrame.new(0, y0 + 0.6, 3.15), black, Enum.Material.Glass)
	for i = 0, 12 do
		part(m, "WhiteKeys", Vector3.new(0.33, 0.16, 0.95), CFrame.new(-2.1 + i * 0.35, y0 + 0.86, 3.25), Color3.fromRGB(248, 246, 240))
	end
	for i = 0, 12 do
		if i % 7 ~= 2 and i % 7 ~= 6 and i < 12 then
			part(m, "BlackKey", Vector3.new(0.17, 0.16, 0.55), CFrame.new(-1.925 + i * 0.35, y0 + 0.98, 3.0), black)
		end
	end
	for _, x in ipairs({ -2.55, 2.55 }) do
		part(m, "Cheek", Vector3.new(0.3, 0.75, 1.25), CFrame.new(x, y0 + 0.8, 3.15), black, Enum.Material.Glass)
	end
	part(m, "Fallboard", Vector3.new(4.9, 0.55, 0.12), CFrame.new(0, y0 + 1.15, 2.62), black, Enum.Material.Glass)
	part(m, "MusicStand", Vector3.new(2.6, 1.1, 0.1), CFrame.new(0, y0 + 1.8, 2.3) * CFrame.Angles(math.rad(-14), 0, 0), black, Enum.Material.Glass)
	-- three round legs with castors, pedal lyre
	for _, p in ipairs({ { -2.1, 2.3 }, { 2.1, 2.3 }, { -1.3, -4.3 } }) do
		cyl(m, "Leg", y0, 0.55, CFrame.new(p[1], y0 / 2, p[2]), black, Enum.Material.Glass)
		cyl(m, "Castor", 0.25, 0.7, CFrame.new(p[1], 0.15, p[2]), Color3.fromRGB(190, 160, 80), Enum.Material.Metal)
	end
	part(m, "Lyre", Vector3.new(0.7, y0 - 0.4, 0.2), CFrame.new(0, (y0 - 0.4) / 2 + 0.3, 1.9), black, Enum.Material.Glass)
	part(m, "Pedals", Vector3.new(0.9, 0.1, 0.4), CFrame.new(0, 0.35, 2.15), Color3.fromRGB(200, 170, 80), Enum.Material.Metal)
	-- bench with a padded seat
	part(m, "Bench", Vector3.new(2.6, 0.45, 1.1), CFrame.new(0, 1.95, 5.2), Color3.fromRGB(12, 12, 14), Enum.Material.Leather)
	for _, x in ipairs({ -1.1, 1.1 }) do
		for _, z in ipairs({ 4.8, 5.6 }) do
			cyl(m, "BenchLeg", 1.75, 0.22, CFrame.new(x, 0.87, z), black, Enum.Material.Glass)
		end
	end
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
	part(m, "String", Vector3.new(0.15, 1.6, 0.15), CFrame.new(0, -0.8, 0), METAL)
	r.ball = part(m, "Ball", Vector3.new(3.5, 3.5, 3.5), CFrame.new(0, -3.3, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Foil, Enum.PartType.Ball)
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

-- one video surface: a part with a SurfaceGui (colour gradient + text, an image layer and a live camera layer)
local function screenFace(m, r, size, cf, face)
	local panel = part(m, "Screen", size, cf, Color3.fromRGB(8, 8, 10))
	local frame, label, grad = surfaceText(panel, face or Enum.NormalId.Back, r.artistName or "HEADLINER", WHITE, r.color, not r.preview)
	label.ZIndex = 2
	local f = { panel = panel, frame = frame, label = label, grad = grad, gui = frame.Parent }
	f.image = New("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Visible = false, ZIndex = 3, Parent = frame })
	f.live = New("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(4, 4, 8),
		Ambient = Color3.fromRGB(150, 150, 170),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(0.3, -1, -0.6),
		Visible = false,
		ZIndex = 4,
		Parent = frame,
	})
	f.liveCam = New("Camera", { FieldOfView = 40, Parent = f.live })
	f.live.CurrentCamera = f.liveCam
	r.faces = r.faces or {}
	table.insert(r.faces, f)
	if not r.panel then
		-- first face also under the old names (designer preview text)
		r.panel, r.frame, r.label, r.grad, r.image, r.live = panel, frame, label, grad, f.image, f.live
	end
	return f
end
local function screen(m, r, w, h, legs)
	local y = 1 + h / 2
	if legs then
		part(m, "LegL", Vector3.new(0.6, 1, 0.6), CFrame.new(-w / 2 + 1, 0.5, 0), METAL)
		part(m, "LegR", Vector3.new(0.6, 1, 0.6), CFrame.new(w / 2 - 1, 0.5, 0), METAL)
	end
	screenFace(m, r, Vector3.new(w, h, 0.6), CFrame.new(0, y, 0))
	part(m, "ScreenBack", Vector3.new(w + 0.4, h + 0.4, 0.3), CFrame.new(0, y, -0.4), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
end
function B.led(m, r)
	local w, d = dims(r, r.def)
	screen(m, r, w, d, true)
end
function B.led_side(m, r)
	screen(m, r, 10, 18, true)
end
function B.ledpillar(m, r)
	local w, h = dims(r, r.def)
	part(m, "Foot", Vector3.new(w + 1, 0.5, 2), CFrame.new(0, 0.25, 0), DARK)
	screenFace(m, r, Vector3.new(w, h, 1), CFrame.new(0, h / 2 + 0.5, 0))
end
-- hanging video cube: 4 screens, lowers a bit during the ballad
function B.ledcube(m, r)
	r.cubeParts = {}
	local cy = -15
	local function add(p)
		table.insert(r.cubeParts, { p, p.CFrame })
		return p
	end
	part(m, "Cable", Vector3.new(0.25, 10, 0.25), CFrame.new(0, -5, 0), METAL, Enum.Material.Metal)
	add(part(m, "CubeFrame", Vector3.new(14, 9, 14), CFrame.new(0, cy, 0), Color3.fromRGB(16, 16, 20)))
	for i = 0, 3 do
		add(screenFace(m, r, Vector3.new(13, 8, 0.3), CFrame.new(0, cy, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, 7.05)).panel)
	end
	add(part(m, "CubeGlowTop", Vector3.new(14.2, 0.3, 14.2), CFrame.new(0, cy + 4.6, 0), r.color, Enum.Material.Neon))
	add(part(m, "CubeGlowBottom", Vector3.new(14.2, 0.3, 14.2), CFrame.new(0, cy - 4.6, 0), r.color, Enum.Material.Neon))
	r.cubeLift = 0
end
-- tall video tower (like the towers around an in-the-round stadium stage)
function B.ledtower(m, r)
	part(m, "Base", Vector3.new(7, 1, 7), CFrame.new(0, 0.5, 0), DARK)
	cyl(m, "Column", 44, 3.6, CFrame.new(0, 23, 0), METAL, Enum.Material.Metal)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		screenFace(m, r, Vector3.new(11, 9, 0.4), CFrame.new(0, 47, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 3.4))
	end
	r.neon = { cyl(m, "TopRing", 0.6, 12, CFrame.new(0, 52, 0), r.color, Enum.Material.Neon), cyl(m, "LowRing", 0.6, 12, CFrame.new(0, 42, 0), r.color, Enum.Material.Neon) }
	part(m, "PA", Vector3.new(4, 7, 3), CFrame.new(0, 36, 2.4), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
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

-- realistic particle textures that ship with Roblox
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- trapdoor in the deck: seam, black opening and two doors that fold down into the stage
local function hatch(m, r, size)
	local hs = size / 2
	r.hatchSize = size
	r.hole = part(m, "HatchHole", Vector3.new(size, 0.04, size), CFrame.new(0, 0.03, 0), Color3.fromRGB(4, 4, 6))
	r.doors = {}
	for _, sx in ipairs({ -1, 1 }) do
		local d = part(m, "HatchDoor", Vector3.new(hs, 0.14, size), CFrame.new(sx * hs / 2, 0.08, 0), Color3.fromRGB(52, 52, 60), Enum.Material.DiamondPlate)
		table.insert(r.doors, { part = d, side = sx })
	end
	r.ringParts = {}
	for _, e in ipairs({ { 0, hs + 0.15, size + 0.6, 0.3 }, { 0, -hs - 0.15, size + 0.6, 0.3 }, { hs + 0.15, 0, 0.3, size }, { -hs - 0.15, 0, 0.3, size } }) do
		table.insert(r.ringParts, part(m, "HatchLED", Vector3.new(e[3], 0.1, e[4]), CFrame.new(e[1], 0.06, e[2]), r.color, Enum.Material.Neon))
	end
end

-- open = 0 closed .. 1 folded down under the deck
local function setHatch(refs, open)
	local hs = refs.hatchSize / 2
	for _, d in ipairs(refs.doors) do
		local hinge = refs.cf * CFrame.new(-d.side * 0 + d.side * hs, 0.08, 0)
		d.part.CFrame = hinge * CFrame.Angles(0, 0, d.side * open * math.pi / 2) * CFrame.new(-d.side * hs / 2, 0, 0)
		d.part.Transparency = (open > 0.97) and 1 or 0
	end
	refs.hole.Transparency = (open < 0.03) and 1 or 0
end

function B.lift(m, r)
	hatch(m, r, 6)
	r.platformLocal = CFrame.new(0, 0.2, 0)
	r.platform = part(m, "Platform", Vector3.new(5.9, 0.4, 5.9), r.platformLocal, Color3.fromRGB(60, 60, 70), Enum.Material.DiamondPlate)
	r.ring = r.ringParts[1]
end

-- "toaster" lift: a small hatch that shoots the artist up in a burst of sparks and CO2
function B.poplift(m, r)
	hatch(m, r, 4.4)
	r.platformLocal = CFrame.new(0, 0.2, 0)
	r.platform = part(m, "Platform", Vector3.new(4.3, 0.4, 4.3), r.platformLocal, Color3.fromRGB(70, 70, 80), Enum.Material.DiamondPlate)
	r.ring = r.ringParts[1]
	r.burstParts = {}
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local n = part(m, "PopNozzle", Vector3.new(0.5, 0.3, 0.5), CFrame.new(c[1] * 3, 0.15, c[2] * 3), DARK)
		local sp = New("ParticleEmitter", {
			Enabled = false,
			Rate = 0,
			Texture = TEX_SPARK,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(30, 42),
			SpreadAngle = Vector2.new(10, 10),
			Size = NumberSequence.new(0.35, 0.05),
			Squash = NumberSequence.new(1.6),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 160, 40)),
			LightEmission = 1,
			Acceleration = Vector3.new(0, -45, 0),
			EmissionDirection = Enum.NormalId.Top,
			Parent = n,
		})
		local co = New("ParticleEmitter", {
			Enabled = false,
			Rate = 0,
			Texture = TEX_SMOKE,
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(40, 55),
			SpreadAngle = Vector2.new(5, 5),
			Size = NumberSequence.new(1.2, 7),
			Transparency = NumberSequence.new(0.15, 1),
			Color = ColorSequence.new(Color3.fromRGB(240, 245, 255)),
			Drag = 3,
			EmissionDirection = Enum.NormalId.Top,
			Parent = n,
		})
		table.insert(r.burstParts, { sp, co })
	end
end

-- tower lift: a round platform on a telescopic column that lifts the artist high above the crowd
Builder.TOWER_HEIGHT = 26
function B.towerlift(m, r)
	r.topY = 1.6
	cyl(m, "Base", 0.6, 12, CFrame.new(0, 0.3, 0), DARK)
	r.baseRing = cyl(m, "BaseLED", 0.2, 12.4, CFrame.new(0, 0.55, 0), r.color, Enum.Material.Neon)
	r.tubes = {}
	for i, d in ipairs({ 4.4, 3.5, 2.6 }) do
		r.tubes[i] = cyl(m, "Tube", 0.4, d, CFrame.new(0, 0.6, 0), (i % 2 == 1) and METAL or Color3.fromRGB(150, 152, 160), Enum.Material.Metal)
	end
	r.top = cyl(m, "Platform", 1, 10, CFrame.new(0, 1.1, 0), Color3.fromRGB(40, 40, 48), Enum.Material.DiamondPlate)
	r.topRing = cyl(m, "PlatformLED", 0.3, 10.4, CFrame.new(0, 1.45, 0), r.color, Enum.Material.Neon)
	r.under = cyl(m, "UnderLight", 0.1, 6, CFrame.new(0, 0.55, 0), WHITE, Enum.Material.Neon)
	r.rails = {}
	for i = 0, 7 do
		local a = i * math.pi / 4
		r.rails[i + 1] = part(m, "Rail", Vector3.new(0.18, 2.6, 0.18), CFrame.new(math.cos(a) * 4.8, 2.9, math.sin(a) * 4.8), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
	end
	r.towerT = 0
end

-- stadium superstructure: two scaffold towers with PA hangs, a roof grid and mesh-covered wings
function B.stadiumroof(m, r)
	local w, h = dims(r, r.def)
	local hw = w / 2
	local depth = 34
	local legs = { { -hw, -depth / 2 }, { -hw, depth / 2 }, { hw, -depth / 2 }, { hw, depth / 2 }, { -hw + 10, -depth / 2 }, { hw - 10, -depth / 2 } }
	for _, l in ipairs(legs) do
		part(m, "Leg", Vector3.new(2.4, h, 2.4), CFrame.new(l[1], h / 2, l[2]), METAL, Enum.Material.DiamondPlate)
	end
	-- lattice bracing on the towers
	for _, sx in ipairs({ -1, 1 }) do
		for y = 8, h - 6, 12 do
			part(m, "Brace", Vector3.new(1, 1, depth), CFrame.new(sx * hw, y, 0), METAL, Enum.Material.Metal)
			part(m, "Brace", Vector3.new(0.6, 0.6, math.sqrt(depth * depth + 144)), CFrame.new(sx * hw, y + 6, 0) * CFrame.Angles(math.atan2(12, depth), 0, 0), METAL, Enum.Material.Metal)
		end
		-- wings: mesh scrim on scaffolding next to the stage
		local wing = part(m, "WingScrim", Vector3.new(26, h * 0.7, 0.4), CFrame.new(sx * (hw + 14), h * 0.35, -depth / 2 + 4), Color3.fromRGB(20, 20, 26), Enum.Material.Fabric)
		wing.Transparency = 0.15
		for k = 0, 2 do
			part(m, "WingPole", Vector3.new(0.8, h * 0.7, 0.8), CFrame.new(sx * (hw + 2 + k * 12), h * 0.35, -depth / 2 + 4.8), METAL, Enum.Material.Metal)
		end
		-- PA line array (curved J) hanging from the roof front
		for i = 0, 11 do
			local ang = math.rad(math.max(0, i - 5) * 3)
			part(m, "LineArray", Vector3.new(4.2, 1.4, 2.6), CFrame.new(sx * (hw - 7), h - 6 - i * 1.45, depth / 2 + 2 + math.max(0, i - 5) * 0.25) * CFrame.Angles(-ang, 0, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Fabric)
		end
		for i = 0, 7 do
			part(m, "SubArray", Vector3.new(3.6, 1.6, 2.4), CFrame.new(sx * (hw - 13), h - 6 - i * 1.65, depth / 2 + 2), Color3.fromRGB(14, 14, 18), Enum.Material.Fabric)
		end
	end
	-- roof: front and back girders, cross trusses, a canopy skin
	for _, z in ipairs({ -depth / 2, 0, depth / 2 }) do
		part(m, "Girder", Vector3.new(w + 2.4, 4, 2.4), CFrame.new(0, h + 2, z), METAL, Enum.Material.DiamondPlate)
	end
	for x = -hw, hw, 12 do
		part(m, "RoofTruss", Vector3.new(1.4, 1.4, depth), CFrame.new(x, h + 1, 0), METAL, Enum.Material.Metal)
	end
	part(m, "Canopy", Vector3.new(w + 4, 0.4, depth + 4), CFrame.new(0, h + 4.4, 0), Color3.fromRGB(26, 26, 32), Enum.Material.Fabric)
	r.roofLED = part(m, "RoofLED", Vector3.new(w, 1.2, 0.3), CFrame.new(0, h + 2, depth / 2 + 1.35), r.color, Enum.Material.Neon)
end

-- delay tower in the crowd: scaffold with a speaker cluster and a follow-spot platform
function B.delaytower(m, r)
	local h = 34
	for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		part(m, "Leg", Vector3.new(0.7, h, 0.7), CFrame.new(c[1], h / 2, c[2]), METAL, Enum.Material.Metal)
	end
	for y = 4, h - 4, 7 do
		part(m, "Ring", Vector3.new(6.7, 0.5, 0.5), CFrame.new(0, y, -3), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(6.7, 0.5, 0.5), CFrame.new(0, y, 3), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(0.5, 0.5, 6.7), CFrame.new(-3, y, 0), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(0.5, 0.5, 6.7), CFrame.new(3, y, 0), METAL, Enum.Material.Metal)
	end
	part(m, "Scrim", Vector3.new(7.2, 10, 7.2), CFrame.new(0, 5, 0), Color3.fromRGB(20, 20, 26), Enum.Material.Fabric).Transparency = 0.1
	part(m, "Deck", Vector3.new(9, 0.6, 9), CFrame.new(0, h - 8, 0), Color3.fromRGB(40, 40, 46), Enum.Material.DiamondPlate)
	r.spotHead = cyl(m, "FollowSpot", 3, 1.4, CFrame.new(0, h - 6.6, -2.5) * CFrame.Angles(math.pi / 2 - 0.25, 0, 0), DARK)
	for i = 0, 5 do
		part(m, "Delay", Vector3.new(3.8, 1.3, 2.4), CFrame.new(0, h - 1 - i * 1.35, -2.2) * CFrame.Angles(-math.rad(i * 2), 0, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Fabric)
	end
	part(m, "Header", Vector3.new(7.4, 1, 7.4), CFrame.new(0, h + 0.5, 0), METAL, Enum.Material.DiamondPlate)
	r.blink = part(m, "Aviation", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, h + 1.3, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
end

function B.scissor(m, r)
	part(m, "Base", Vector3.new(8, 0.6, 8), CFrame.new(0, 0.3, 0), DARK)
	r.column = part(m, "Column", Vector3.new(3, 0.6, 3), CFrame.new(0, 0.6, 0), METAL, Enum.Material.DiamondPlate)
	r.platform = part(m, "Platform", Vector3.new(8, 0.6, 8), CFrame.new(0, 0.9, 0), Color3.fromRGB(60, 60, 70), Enum.Material.DiamondPlate)
	r.edge = part(m, "Edge", Vector3.new(8.4, 0.2, 8.4), CFrame.new(0, 1.2, 0), r.color, Enum.Material.Neon)
end

-- flame projector: black box with a hazard stripe and a nozzle; a column of flame with a rolling top and black smoke
function B.pyro(m, r)
	part(m, "Box", Vector3.new(2.4, 1.3, 2.4), CFrame.new(0, 0.65, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
	part(m, "Stripe", Vector3.new(2.42, 0.25, 2.42), CFrame.new(0, 1.05, 0), Color3.fromRGB(240, 190, 20), Enum.Material.SmoothPlastic)
	cyl(m, "NozzleTube", 0.9, 0.6, CFrame.new(0, 1.75, 0), METAL, Enum.Material.Metal)
	r.nozzle = part(m, "Nozzle", Vector3.new(1, 1, 1), CFrame.new(0, 2.2, 0), DARK)
	r.nozzle.Transparency = 1
	r.fire = New("Fire", { Size = 6, Heat = 20, Color = Color3.fromRGB(255, 140, 30), SecondaryColor = Color3.fromRGB(255, 60, 0), Enabled = false, Parent = r.nozzle })
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Texture = TEX_FIRE,
		Lifetime = NumberRange.new(0.55, 0.85),
		Speed = NumberRange.new(38, 50),
		SpreadAngle = Vector2.new(5, 5),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(0.45, 5), NumberSequenceKeypoint.new(1, 8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)), ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 170, 40)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 0)) }),
		LightEmission = 1,
		Drag = 2.2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		Acceleration = Vector3.new(0, 8, 0),
		Parent = r.nozzle,
	})
	r.smokeEmitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Texture = TEX_SMOKE,
		Lifetime = NumberRange.new(1.4, 2.4),
		Speed = NumberRange.new(26, 34),
		SpreadAngle = Vector2.new(8, 8),
		Size = NumberSequence.new(4, 12),
		Transparency = NumberSequence.new(0.55, 1),
		Color = ColorSequence.new(Color3.fromRGB(40, 36, 34)),
		Drag = 1.5,
		Rotation = NumberRange.new(0, 360),
		Parent = r.nozzle,
	})
	r.light = New("PointLight", { Range = 60, Brightness = 0, Color = Color3.fromRGB(255, 150, 50), Shadows = false, Parent = r.nozzle })
end

-- cold spark machine: low black box with a grille; a fountain of thin sparks that fall back down
function B.sparks(m, r)
	part(m, "Box", Vector3.new(2, 1.1, 2), CFrame.new(0, 0.55, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
	part(m, "Grille", Vector3.new(1.6, 0.06, 1.6), CFrame.new(0, 1.12, 0), Color3.fromRGB(60, 60, 66), Enum.Material.DiamondPlate)
	part(m, "Status", Vector3.new(0.3, 0.12, 0.05), CFrame.new(0.6, 0.8, -1.01), Color3.fromRGB(40, 255, 90), Enum.Material.Neon)
	r.nozzle = part(m, "Nozzle", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 1.25, 0), DARK)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 420,
		Texture = TEX_SPARK,
		Lifetime = NumberRange.new(1.1, 1.7),
		Speed = NumberRange.new(30, 40),
		SpreadAngle = Vector2.new(7, 7),
		Size = NumberSequence.new(0.32, 0.04),
		Squash = NumberSequence.new(1.4),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 150, 30)),
		LightEmission = 1,
		Acceleration = Vector3.new(0, -48, 0),
		Drag = 0.3,
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

-- CO2 cryo jet: gas bottle, stand and an angled nozzle head; a hissing white plume
function B.co2(m, r)
	cyl(m, "Bottle", 4.2, 1.1, CFrame.new(-1.1, 2.1, 0.6), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	cyl(m, "Valve", 0.5, 0.5, CFrame.new(-1.1, 4.4, 0.6), METAL, Enum.Material.Metal)
	part(m, "Foot", Vector3.new(1.8, 0.2, 1.8), CFrame.new(0.4, 0.1, 0), DARK)
	part(m, "Pole", Vector3.new(0.3, 2.4, 0.3), CFrame.new(0.4, 1.3, 0), METAL, Enum.Material.Metal)
	part(m, "Head", Vector3.new(0.8, 0.8, 1.6), CFrame.new(0.4, 2.7, 0) * CFrame.Angles(math.rad(-15), 0, 0), DARK)
	part(m, "Hose", Vector3.new(0.2, 0.2, 2), CFrame.new(-0.4, 3.3, 0.4) * CFrame.Angles(0, math.rad(60), 0), Color3.fromRGB(20, 20, 24))
	r.nozzle = part(m, "Nozzle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.4, 3.1, 0), DARK)
	r.nozzle.Transparency = 1
	r.smoke = New("Smoke", { Color = Color3.fromRGB(235, 240, 255), Opacity = 0.35, RiseVelocity = 20, Size = 2, Enabled = false, Parent = r.nozzle })
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Texture = TEX_SMOKE,
		Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(65, 85),
		SpreadAngle = Vector2.new(4, 4),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.3, 4), NumberSequenceKeypoint.new(1, 11) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(245, 248, 255)),
		Drag = 3.2,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
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

-- glowing ring the artist can walk through (in the XY plane, facing the audience)
function B.portal(m, r)
	local w = dims(r, r.def)
	local R = w / 2
	local n = math.clamp(math.floor(w * 1.1), 16, 48)
	r.ring = {}
	for i = 0, n - 1 do
		local a = i * math.pi * 2 / n
		local seg = 2 * math.pi * R / n + 0.2
		local p = part(m, "RingSeg", Vector3.new(seg, 2.4, 2.4), CFrame.new(math.cos(a) * R, R + 2 + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2), r.color, Enum.Material.Neon)
		table.insert(r.ring, p)
		part(m, "RingBack", Vector3.new(seg, 3.4, 1.2), CFrame.new(math.cos(a) * (R + 0.5), R + 2 + math.sin(a) * (R + 0.5), -1.6) * CFrame.Angles(0, 0, a + math.pi / 2), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
	end
	part(m, "FootL", Vector3.new(4, 2, 4), CFrame.new(-R * 0.55, 1, -1), DARK)
	part(m, "FootR", Vector3.new(4, 2, 4), CFrame.new(R * 0.55, 1, -1), DARK)
end
function B.kinetic(m, r)
	local w = dims(r, r.def)
	local n = math.clamp(math.floor(w / 3.5), 2, 26)
	r.bars = {}
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		part(m, "Winch", Vector3.new(1, 0.8, 1), CFrame.new(x, -0.4, -3), DARK)
		part(m, "Winch", Vector3.new(1, 0.8, 1), CFrame.new(x, -0.4, 3), DARK)
		local bar = part(m, "KineticBar", Vector3.new(0.6, 0.6, 7), CFrame.new(x, -8, 0), r.color, Enum.Material.Neon)
		local wa = part(m, "Wire", Vector3.new(0.08, 8, 0.08), CFrame.new(x, -4, -3), METAL)
		local wb = part(m, "Wire", Vector3.new(0.08, 8, 0.08), CFrame.new(x, -4, 3), METAL)
		table.insert(r.bars, { bar = bar, wa = wa, wb = wb, x = x, i = i })
	end
end
function B.moon(m, r)
	local d = dims(r, r.def)
	local cy = d / 2 + 5
	part(m, "Pole", Vector3.new(1.2, cy, 1.2), CFrame.new(0, cy / 2, -d * 0.2), METAL, Enum.Material.Metal)
	r.moon = part(m, "Moon", Vector3.new(d, d, d), CFrame.new(0, cy, 0), Color3.fromRGB(238, 228, 200), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for i = 1, 9 do
		local a, b = i * 2.3, i * 1.1
		local dir = Vector3.new(math.cos(a) * math.cos(b), math.sin(b) * 0.8, math.abs(math.sin(a)) + 0.3).Unit
		part(m, "Crater", Vector3.new(d * 0.16, d * 0.16, d * 0.16), CFrame.new(Vector3.new(0, cy, 0) + dir * d * 0.44), Color3.fromRGB(200, 190, 165), Enum.Material.Slate, Enum.PartType.Ball)
	end
	r.halo = part(m, "Halo", Vector3.new(d * 1.18, d * 1.18, d * 1.18), CFrame.new(0, cy, 0), Color3.fromRGB(255, 230, 170), Enum.Material.Neon, Enum.PartType.Ball)
	r.halo.Transparency = 0.86
	r.light = New("PointLight", { Range = d * 2.5, Brightness = 1.2, Color = Color3.fromRGB(255, 230, 180), Shadows = false, Parent = r.moon })
end
function B.skyline(m, r)
	local w = dims(r, r.def)
	r.windows = {}
	local x = -w / 2
	local i = 0
	while x < w / 2 - 3 do
		i = i + 1
		local bw = 4 + (i * 37 % 5)
		bw = math.min(bw, w / 2 - x)
		local bh = 12 + (i * 53 % 23)
		part(m, "Building", Vector3.new(bw - 0.3, bh, 4), CFrame.new(x + bw / 2, bh / 2, 0), Color3.fromRGB(26, 26, 32))
		for k = 1, math.floor(bh / 5) do
			local win = part(m, "Window", Vector3.new(bw - 1.4, 1, 0.2), CFrame.new(x + bw / 2, k * 5 - 1.5, 2.05), WARM, Enum.Material.Neon)
			win.Transparency = ((i + k) % 3 == 0) and 0.9 or 0.2
			table.insert(r.windows, win)
		end
		if i % 4 == 0 then
			part(m, "Antenna", Vector3.new(0.3, 6, 0.3), CFrame.new(x + bw / 2, bh + 3, 0), METAL)
			part(m, "RedLight", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + bw / 2, bh + 6.2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		end
		x = x + bw
	end
end
function B.statue(m, r)
	local chrome = Color3.fromRGB(200, 204, 214)
	local function c(name, size, cf)
		local p = part(m, name, size, cf, chrome, Enum.Material.Foil)
		p.Reflectance = 0.35
		return p
	end
	c("Plinth", Vector3.new(10, 3, 10), CFrame.new(0, 1.5, 0))
	c("LegL", Vector3.new(3.4, 12, 3.4), CFrame.new(-2.2, 9, 0))
	c("LegR", Vector3.new(3.4, 12, 3.4), CFrame.new(2.2, 9, 0))
	c("Body", Vector3.new(9, 11, 5), CFrame.new(0, 20.5, 0))
	c("ArmL", Vector3.new(3, 11, 3), CFrame.new(-6.2, 20, 0) * CFrame.Angles(0, 0, -0.12))
	c("ArmR", Vector3.new(3, 11, 3), CFrame.new(6.2, 20, 0) * CFrame.Angles(0, 0, 0.12))
	r.headLocal = CFrame.new(0, 29.5, 0)
	r.head = c("Head", Vector3.new(6, 6, 6), r.headLocal)
	r.visor = part(m, "Visor", Vector3.new(4.6, 1, 0.3), r.headLocal * CFrame.new(0, 0.4, 3.05), r.color, Enum.Material.Neon)
end
function B.robotarm(m, r)
	local yellow = Color3.fromRGB(240, 170, 20)
	cyl(m, "Base", 2, 7, CFrame.new(0, 1, 0), DARK)
	r.turret = cyl(m, "Turret", 2.5, 5, CFrame.new(0, 3.2, 0), yellow, Enum.Material.Metal)
	r.lower = part(m, "Lower", Vector3.new(2.2, 14, 2.2), CFrame.new(0, 11, 0), yellow, Enum.Material.Metal)
	r.upper = part(m, "Upper", Vector3.new(1.8, 12, 1.8), CFrame.new(0, 24, 0), yellow, Enum.Material.Metal)
	r.tool = part(m, "Tool", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 31, 0), Color3.fromRGB(30, 30, 34))
	r.lamp = part(m, "Lamp", Vector3.new(1.6, 0.3, 1.6), CFrame.new(0, 32.4, 0), r.color, Enum.Material.Neon)
	r.beam = beam(r.tool, Vector3.new(0, 1.4, 0), Vector3.new(0, 90, 0), 1, 9, r.color, 0.45)
end
function B.house(m, r)
	local wood = Color3.fromRGB(150, 110, 80)
	part(m, "Porch", Vector3.new(16, 1, 14), CFrame.new(0, 0.5, 1), Color3.fromRGB(110, 80, 56), Enum.Material.WoodPlanks)
	part(m, "Walls", Vector3.new(14, 10, 10), CFrame.new(0, 6, 0), wood, Enum.Material.WoodPlanks)
	local roofCF = CFrame.new(0, 11, 0)
	New("WedgePart", { Name = "Roof", Size = Vector3.new(15, 5, 6), CFrame = roofCF * CFrame.new(0, 2.5, 3) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Slate, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	New("WedgePart", { Name = "Roof", Size = Vector3.new(15, 5, 6), CFrame = roofCF * CFrame.new(0, 2.5, -3), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Slate, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	part(m, "Chimney", Vector3.new(1.6, 5, 1.6), CFrame.new(4, 14, -1), Color3.fromRGB(120, 60, 50), Enum.Material.Brick)
	part(m, "Door", Vector3.new(2.6, 5.5, 0.2), CFrame.new(0, 3.75, 5.05), Color3.fromRGB(70, 40, 30), Enum.Material.Wood)
	r.windows = {}
	for _, x in ipairs({ -4.5, 4.5 }) do
		table.insert(r.windows, part(m, "Window", Vector3.new(3, 3, 0.2), CFrame.new(x, 6.5, 5.05), WARM, Enum.Material.Neon))
	end
	table.insert(r.windows, part(m, "AtticWindow", Vector3.new(2, 2, 0.2), CFrame.new(0, 13, 4.6), WARM, Enum.Material.Neon))
	part(m, "Lantern", Vector3.new(0.8, 1.2, 0.8), CFrame.new(2.2, 6.2, 5.4), WARM, Enum.Material.Neon)
end
function B.arch(m, r)
	local w = dims(r, r.def)
	local R = w / 2
	local n = math.clamp(math.floor(w * 0.9), 10, 40)
	r.ring = {}
	for i = 0, n do
		local a = i * math.pi / n
		local seg = math.pi * R / n + 0.2
		table.insert(r.ring, part(m, "ArchSeg", Vector3.new(seg, 1.2, 1.2), CFrame.new(math.cos(a) * R, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2), r.color, Enum.Material.Neon))
	end
end
function B.flowers(m, r)
	part(m, "Bed", Vector3.new(10, 1, 6), CFrame.new(0, 0.5, 0), Color3.fromRGB(40, 90, 40), Enum.Material.Grass)
	local cols = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 130, 60) }
	for i = 0, 27 do
		local x, z = -4.3 + (i % 7) * 1.45, -2.2 + math.floor(i / 7) * 1.45
		local d = 1 + (i * 7 % 5) * 0.15
		part(m, "Bloom", Vector3.new(d, d, d), CFrame.new(x, 1.4 + (i * 3 % 4) * 0.25, z), cols[i % #cols + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end
function B.curtain(m, r)
	local w, h = dims(r, r.def)
	part(m, "Track", Vector3.new(w + 2, 1, 1), CFrame.new(0, h + 1.5, 0), DARK, Enum.Material.Metal)
	r.drapeHome = CFrame.new(0, h / 2 + 1, 0)
	r.drape = part(m, "Drape", Vector3.new(w, h, 0.5), r.drapeHome, Color3.fromRGB(160, 20, 30), Enum.Material.Fabric)
	r.drapeLabel = select(2, surfaceText(r.drape, Enum.NormalId.Back, r.artistName or "", Color3.fromRGB(255, 230, 200), nil))
end
function B.balls(m, r)
	part(m, "Box", Vector3.new(5, 3, 4), CFrame.new(0, 1.5, 0), DARK)
	part(m, "Net", Vector3.new(5.2, 0.2, 4.2), CFrame.new(0, 3.1, 0), r.color, Enum.Material.Neon)
	r.balloons = {}
end
function B.wristbands(m, r)
	part(m, "Desk", Vector3.new(5, 3, 3), CFrame.new(0, 1.5, 0), DARK)
	r.neon = { part(m, "DeskScreen", Vector3.new(4, 1.6, 0.2), CFrame.new(0, 3.6, 0) * CFrame.Angles(-0.3, 0, 0), r.color, Enum.Material.Neon) }
	part(m, "Antenna", Vector3.new(0.2, 4, 0.2), CFrame.new(2, 5, -1), METAL)
end
function B.lowfog(m, r)
	part(m, "Box", Vector3.new(3, 2, 3.5), CFrame.new(0, 1, 0), Color3.fromRGB(200, 200, 210))
	r.nozzle = part(m, "Nozzle", Vector3.new(1, 1, 1), CFrame.new(0, 1, 2), DARK)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 14,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(70, 4),
		Size = NumberSequence.new(6, 16),
		Transparency = NumberSequence.new(0.55, 1),
		Color = ColorSequence.new(Color3.fromRGB(235, 240, 255)),
		Acceleration = Vector3.new(0, -0.6, 0),
		Drag = 0.4,
		EmissionDirection = Enum.NormalId.Back,
		Parent = r.nozzle,
	})
end
function B.streamers(m, r)
	part(m, "Base", Vector3.new(2, 1, 2), CFrame.new(0, 0.5, 0), DARK)
	r.nozzle = cyl(m, "Tube", 3, 1.4, CFrame.new(0, 2.5, 0), Color3.fromRGB(220, 200, 120), Enum.Material.Metal)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(70, 90),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(0.9, 0.7),
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(230, 230, 240)),
		Drag = 1.3,
		Acceleration = Vector3.new(0, -6, 0),
		RotSpeed = NumberRange.new(-180, 180),
		LightEmission = 0.6,
		EmissionDirection = Enum.NormalId.Right,
		Parent = r.nozzle,
	})
end
-- two-tier keyboard rig on an X stand: synth on top, stage piano below, with real keys and knobs
local function keyboard(m, cf, w, body)
	part(m, "KeyboardBody", Vector3.new(w, 0.4, 1.35), cf, body)
	local n = math.floor(w / 0.27)
	part(m, "WhiteKeys", Vector3.new(w - 0.5, 0.1, 0.65), cf * CFrame.new(0, 0.24, 0.32), Color3.fromRGB(246, 244, 238))
	for i = 0, n - 3 do
		if i % 7 ~= 2 and i % 7 ~= 6 then
			part(m, "BlackKey", Vector3.new(0.12, 0.12, 0.38), cf * CFrame.new(-(w - 0.5) / 2 + 0.27 + i * 0.27, 0.32, 0.18), Color3.fromRGB(14, 14, 16))
		end
	end
	for i = 0, 5 do
		cyl(m, "Knob", 0.12, 0.16, cf * CFrame.new(-w / 2 + 0.5 + i * 0.3, 0.27, -0.4), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	end
	part(m, "Display", Vector3.new(0.8, 0.04, 0.3), cf * CFrame.new(w / 2 - 0.9, 0.22, -0.4), Color3.fromRGB(80, 170, 255), Enum.Material.Neon)
end
function B.keys(m, r)
	tube(m, Vector3.new(-1.6, 0, 0.4), Vector3.new(1.6, 3.4, 0.4), 0.16, METAL)
	tube(m, Vector3.new(1.6, 0, 0.4), Vector3.new(-1.6, 3.4, 0.4), 0.16, METAL)
	for _, x in ipairs({ -1.9, 1.9 }) do
		part(m, "Foot", Vector3.new(0.3, 0.15, 1.4), CFrame.new(x, 0.08, 0.4), METAL, Enum.Material.Metal)
	end
	tube(m, Vector3.new(0, 1.7, 0.4), Vector3.new(0, 4.4, -0.4), 0.14, METAL)
	keyboard(m, CFrame.new(0, 3.6, 0.4), 4.8, Color3.fromRGB(26, 26, 30))
	keyboard(m, CFrame.new(0, 4.6, -0.3) * CFrame.Angles(-0.3, 0, 0), 4.4, Color3.fromRGB(165, 28, 30))
	r.neon = { part(m, "KeysLed", Vector3.new(0.6, 0.15, 0.1), CFrame.new(1.6, 3.65, 1.09), r.color, Enum.Material.Neon) }
end
function B.micstand(m, r)
	cyl(m, "Foot", 0.2, 2, CFrame.new(0, 0.1, 0), DARK)
	tube(m, Vector3.new(0, 0, 0), Vector3.new(0, 5.4, 0.2), 0.16, METAL)
	tube(m, Vector3.new(0, 5.4, 0.2), Vector3.new(0, 6.2, 1.4), 0.12, METAL)
	part(m, "Mic", Vector3.new(0.35, 0.35, 0.9), CFrame.new(0, 6.3, 1.7) * CFrame.Angles(-0.5, 0, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
end
function B.amps(m, r)
	for i = 0, 1 do
		for k = 0, 1 do
			local cf = CFrame.new(-2.1 + i * 4.2, 1.6 + k * 3.2, 0)
			part(m, "Cab", Vector3.new(4, 3.1, 2.4), cf, Color3.fromRGB(18, 18, 20), Enum.Material.Leather)
			part(m, "Grille", Vector3.new(3.4, 2.5, 0.08), cf * CFrame.new(0, 0, 1.22), Color3.fromRGB(70, 60, 50), Enum.Material.Fabric)
		end
	end
	part(m, "Head", Vector3.new(8.2, 1.6, 2.2), CFrame.new(0, 7.2, 0), Color3.fromRGB(18, 18, 20), Enum.Material.Leather)
	r.neon = { part(m, "AmpLogo", Vector3.new(2, 0.5, 0.1), CFrame.new(-2.6, 7.2, 1.12), r.color, Enum.Material.Neon) }
end

------------------------------------------------------------------ small props
-- flat disc facing the audience (+Z)
local function disc(m, name, d, cf, color, material)
	return part(m, name, Vector3.new(0.4, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, material, Enum.PartType.Cylinder)
end
-- straight neon line between two points in the XY plane (z = 0)
local function neonLine(m, x1, y1, x2, y2, color, t)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	return part(m, "NeonLine", Vector3.new(len + (t or 0.5), t or 0.5, t or 0.5), CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(dy, dx)), color, Enum.Material.Neon)
end
local function stand(m, h)
	part(m, "Foot", Vector3.new(2, 0.3, 1.2), CFrame.new(0, 0.15, 0), DARK)
	part(m, "Pole", Vector3.new(0.3, h, 0.3), CFrame.new(0, h / 2, -0.3), METAL, Enum.Material.Metal)
end
-- electric guitar: two rounded bouts and a horn, pickups, bridge, knobs, neck with frets and a headstock (lying in the XY plane)
local function guitar(m, cf, color)
	local function oval(name, size, off, c, mat)
		local p = part(m, name, size, cf * off, c, mat)
		New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
		return p
	end
	oval("GuitarLower", Vector3.new(2.2, 1.8, 0.45), CFrame.new(0, -0.55, 0), color, Enum.Material.Glass)
	oval("GuitarUpper", Vector3.new(1.7, 1.45, 0.45), CFrame.new(0.05, 0.55, 0), color, Enum.Material.Glass)
	oval("GuitarHorn", Vector3.new(0.5, 1.1, 0.42), CFrame.new(-0.55, 1.05, 0) * CFrame.Angles(0, 0, 0.25), color, Enum.Material.Glass)
	oval("Pickguard", Vector3.new(1.1, 1.6, 0.06), CFrame.new(0.3, -0.1, 0.22), Color3.fromRGB(240, 240, 236))
	for _, y in ipairs({ -0.45, 0.25 }) do
		part(m, "Pickup", Vector3.new(0.7, 0.22, 0.08), cf * CFrame.new(0, y, 0.26), Color3.fromRGB(20, 20, 22))
	end
	part(m, "Bridge", Vector3.new(0.6, 0.18, 0.1), cf * CFrame.new(0, -0.95, 0.25), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	for i = 0, 2 do
		cyl(m, "Knob", 0.12, 0.2, cf * CFrame.new(0.6 + i * 0.12, -0.9 - i * 0.2, 0.27) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(230, 220, 190))
	end
	part(m, "Neck", Vector3.new(0.32, 3, 0.18), cf * CFrame.new(0, 2.6, 0.06), Color3.fromRGB(150, 100, 55), Enum.Material.Wood)
	part(m, "Fretboard", Vector3.new(0.3, 2.9, 0.04), cf * CFrame.new(0, 2.6, 0.17), Color3.fromRGB(50, 32, 24), Enum.Material.Wood)
	for i = 0, 6 do
		part(m, "Fret", Vector3.new(0.31, 0.03, 0.05), cf * CFrame.new(0, 1.3 + i * 0.4, 0.19), Color3.fromRGB(210, 210, 215), Enum.Material.Metal)
	end
	part(m, "Headstock", Vector3.new(0.45, 0.85, 0.12), cf * CFrame.new(0.08, 4.5, 0.04) * CFrame.Angles(0, 0, -0.12), Color3.fromRGB(150, 100, 55), Enum.Material.Wood)
	for i = 0, 2 do
		cyl(m, "Tuner", 0.18, 0.1, cf * CFrame.new(-0.22, 4.2 + i * 0.25, 0.04), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	end
	part(m, "Strings", Vector3.new(0.18, 4.9, 0.02), cf * CFrame.new(0, 1.9, 0.2), Color3.fromRGB(220, 220, 225), Enum.Material.Metal).Transparency = 0.4
end
Builder.guitar = guitar
function B.guitarstand(m, r)
	-- tripod stand with a padded cradle and a neck holder
	for _, a in ipairs({ 0.6, 2.55, 4.5 }) do
		tube(m, Vector3.new(0, 1.0, 0), Vector3.new(math.cos(a) * 1.1, 0.05, math.sin(a) * 1.1), 0.1, METAL)
	end
	tube(m, Vector3.new(0, 1.0, 0), Vector3.new(0, 4.6, -0.25), 0.1, METAL)
	part(m, "Cradle", Vector3.new(1.8, 0.25, 0.6), CFrame.new(0, 1.15, 0.15), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
	part(m, "NeckYoke", Vector3.new(0.6, 0.2, 0.3), CFrame.new(0, 4.6, -0.25), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
	guitar(m, CFrame.new(0, 2.4, 0.05) * CFrame.Angles(-0.1, 0, 0), r.color)
end
function B.wedge(m, r)
	New("WedgePart", { Name = "Wedge", Size = Vector3.new(3.4, 1.6, 2.4), CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.Fabric, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	part(m, "WedgeGrille", Vector3.new(2.8, 0.1, 1.6), CFrame.new(0, 0.85, -0.05) * CFrame.Angles(math.rad(-34), 0, 0), Color3.fromRGB(50, 50, 55), Enum.Material.Fabric)
end
function B.congas(m, r)
	for i, x in ipairs({ -0.9, 0.9 }) do
		cyl(m, "Conga", 3.4 - i * 0.3, 1.5 - i * 0.15, CFrame.new(x, (3.4 - i * 0.3) / 2, 0), Color3.fromRGB(150, 80, 40), Enum.Material.Wood)
		cyl(m, "CongaHead", 0.1, 1.4 - i * 0.15, CFrame.new(x, 3.4 - i * 0.3 + 0.05, 0), Color3.fromRGB(235, 225, 200))
	end
	tube(m, Vector3.new(2.2, 0, -0.5), Vector3.new(2.2, 3.8, -0.5), 0.1, METAL)
	cyl(m, "Cymbal", 0.06, 2, CFrame.new(2.2, 3.9, -0.5) * CFrame.Angles(0.2, 0, 0), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
end
function B.stool(m, r)
	cyl(m, "Seat", 0.3, 1.6, CFrame.new(0, 3.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Leather)
	for _, a in ipairs({ 0, 2.1, 4.2 }) do
		tube(m, Vector3.new(math.cos(a) * 0.4, 3.1, math.sin(a) * 0.4), Vector3.new(math.cos(a) * 0.9, 0, math.sin(a) * 0.9), 0.12, METAL)
	end
	cyl(m, "Ring", 0.1, 1.5, CFrame.new(0, 1.2, 0), METAL, Enum.Material.Metal)
end
function B.chair(m, r)
	local wood = Color3.fromRGB(120, 80, 50)
	part(m, "Seat", Vector3.new(2, 0.3, 2), CFrame.new(0, 2, 0), wood, Enum.Material.Wood)
	part(m, "Back", Vector3.new(2, 2.2, 0.25), CFrame.new(0, 3.2, -0.9), wood, Enum.Material.Wood)
	for _, x in ipairs({ -0.85, 0.85 }) do
		for _, z in ipairs({ -0.85, 0.85 }) do
			part(m, "Leg", Vector3.new(0.2, 2, 0.2), CFrame.new(x, 1, z), wood, Enum.Material.Wood)
		end
	end
end
function B.uplight(m, r)
	part(m, "Body", Vector3.new(1.4, 1, 1.4), CFrame.new(0, 0.5, 0), DARK)
	r.lens = part(m, "Lens", Vector3.new(1.1, 0.1, 1.1), CFrame.new(0, 1.05, 0), r.color, Enum.Material.Neon)
	r.light = New("SpotLight", { Face = Enum.NormalId.Top, Angle = 60, Range = 30, Brightness = 2, Color = r.color, Shadows = false, Parent = r.lens })
	r.beam = beam(r.lens, Vector3.new(0, 0.1, 0), Vector3.new(0, 18, -2), 1, 6, r.color, 0.7)
end
function B.ledbar(m, r)
	local w = dims(r, r.def)
	local n = math.clamp(math.floor(w), 2, 40)
	r.pixels = {}
	part(m, "BarBody", Vector3.new(w, 0.4, 0.5), CFrame.new(0, 0.2, 0), DARK)
	for i = 0, n - 1 do
		table.insert(r.pixels, part(m, "Pixel", Vector3.new(w / n - 0.1, 0.2, 0.3), CFrame.new(-w / 2 + (i + 0.5) * w / n, 0.45, 0.05), r.color, Enum.Material.Neon))
	end
end
function B.lightpole(m, r)
	cyl(m, "Base", 0.4, 1.6, CFrame.new(0, 0.2, 0), DARK)
	r.tube = cyl(m, "Tube", 12, 0.6, CFrame.new(0, 6.4, 0), r.color, Enum.Material.Neon)
end
function B.stringlights(m, r)
	local w = dims(r, r.def)
	local n = math.clamp(math.floor(w / 2), 4, 40)
	r.bulbs = {}
	local last = nil
	for i = 0, n do
		local u = i / n
		local x = -w / 2 + w * u
		local y = -1 - 4 * (1 - (2 * u - 1) ^ 2)
		local pt = Vector3.new(x, y, 0)
		if last then
			tube(m, last, pt, 0.06, Color3.fromRGB(30, 30, 30))
		end
		table.insert(r.bulbs, part(m, "Bulb", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, y - 0.35, 0), WARM, Enum.Material.Neon, Enum.PartType.Ball))
		last = pt
	end
end
function B.lanterns(m, r)
	r.lanterns = {}
	for i, x in ipairs({ -3, 0, 3 }) do
		local drop = 3 + (i % 2) * 2
		part(m, "String", Vector3.new(0.06, drop, 0.06), CFrame.new(x, -drop / 2, 0), Color3.fromRGB(40, 40, 40))
		local l = part(m, "Lantern", Vector3.new(2.4, 2.4, 2.4), CFrame.new(x, -drop - 1.2, 0), Color3.fromRGB(255, 200, 140), Enum.Material.Neon, Enum.PartType.Ball)
		l.Transparency = 0.25
		table.insert(r.lanterns, { p = l, home = CFrame.new(x, -drop - 1.2, 0), i = i })
	end
end
function B.tvstack(m, r)
	r.tvs = {}
	local rows = { 3, 2, 1 }
	for row, n in ipairs(rows) do
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 3.2
			local y = 1.2 + (row - 1) * 2.5
			local cf = CFrame.new(x, y, 0) * CFrame.Angles(0, (i - (n + 1) / 2) * 0.12, 0)
			part(m, "TV", Vector3.new(3, 2.4, 2.4), cf, Color3.fromRGB(60, 50, 44), Enum.Material.Wood)
			table.insert(r.tvs, part(m, "TVScreen", Vector3.new(2.3, 1.7, 0.1), cf * CFrame.new(-0.15, 0, 1.22), r.color, Enum.Material.Neon))
		end
	end
end
function B.neonheart(m, r)
	stand(m, 4)
	r.neon = {
		disc(m, "HeartL", 3.6, CFrame.new(-1.25, 7.2, 0), r.color, Enum.Material.Neon),
		disc(m, "HeartR", 3.6, CFrame.new(1.25, 7.2, 0), r.color, Enum.Material.Neon),
		part(m, "HeartTip", Vector3.new(3.6, 3.6, 0.4), CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(45)), r.color, Enum.Material.Neon),
	}
end
function B.neonstar(m, r)
	stand(m, 4)
	r.neon = {}
	local pts = {}
	for i = 0, 9 do
		local a = math.pi / 2 + i * math.pi / 5
		local rr = (i % 2 == 0) and 3.4 or 1.4
		table.insert(pts, { math.cos(a) * rr, 7.6 + math.sin(a) * rr })
	end
	for i = 1, 10 do
		local a, b = pts[i], pts[i % 10 + 1]
		table.insert(r.neon, neonLine(m, a[1], a[2], b[1], b[2], r.color, 0.45))
	end
end
function B.neonbolt(m, r)
	stand(m, 3)
	r.neon = {
		neonLine(m, 1.2, 10, -0.8, 6.6, r.color, 0.6),
		neonLine(m, -0.8, 6.6, 1.0, 6.6, r.color, 0.6),
		neonLine(m, 1.0, 6.6, -1.2, 3.2, r.color, 0.6),
	}
end
function B.bubbles(m, r)
	part(m, "Box", Vector3.new(2.4, 1.6, 2), CFrame.new(0, 0.8, 0), Color3.fromRGB(230, 230, 240))
	r.nozzle = part(m, "Nozzle", Vector3.new(1.6, 0.6, 0.4), CFrame.new(0, 1.4, 1.1), DARK)
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 20,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(5, 8),
		SpreadAngle = Vector2.new(35, 25),
		Size = NumberSequence.new(0.7),
		Transparency = NumberSequence.new(0.45, 0.8),
		Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 200, 240)),
		LightEmission = 0.5,
		Acceleration = Vector3.new(0, 1, 0),
		Drag = 0.6,
		EmissionDirection = Enum.NormalId.Back,
		Parent = r.nozzle,
	})
end
function B.snow(m, r)
	part(m, "Box", Vector3.new(3, 1.4, 2), CFrame.new(0, -0.8, 0), DARK)
	r.nozzle = part(m, "SnowArea", Vector3.new(26, 0.2, 14), CFrame.new(0, -1.8, 0), DARK)
	r.nozzle.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 70,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(0.35),
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 0.3,
		Acceleration = Vector3.new(0, -1.5, 0),
		RotSpeed = NumberRange.new(-90, 90),
		EmissionDirection = Enum.NormalId.Bottom,
		Parent = r.nozzle,
	})
end
function B.windfan(m, r)
	part(m, "Base", Vector3.new(3, 0.6, 2), CFrame.new(0, 0.3, 0), DARK)
	part(m, "Mount", Vector3.new(0.4, 3, 0.4), CFrame.new(0, 1.8, 0), METAL, Enum.Material.Metal)
	r.hubLocal = CFrame.new(0, 3.8, 0)
	disc(m, "Cage", 4.4, r.hubLocal * CFrame.new(0, 0, -0.3), Color3.fromRGB(50, 50, 56), Enum.Material.DiamondPlate).Transparency = 0.5
	r.blades = {}
	for i = 0, 2 do
		table.insert(r.blades, { p = part(m, "Blade", Vector3.new(0.6, 1.9, 0.1), r.hubLocal, Color3.fromRGB(200, 200, 210), Enum.Material.Metal), a = i * 2.094 })
	end
	r.spin = 0
end
function B.sofa(m, r)
	local c = r.color:Lerp(Color3.fromRGB(60, 50, 60), 0.5)
	part(m, "Base", Vector3.new(7, 1.6, 3), CFrame.new(0, 0.8, 0), c, Enum.Material.Fabric)
	part(m, "Back", Vector3.new(7, 2.4, 0.8), CFrame.new(0, 2.6, -1.1), c, Enum.Material.Fabric)
	part(m, "ArmL", Vector3.new(0.8, 1.4, 3), CFrame.new(-3.1, 2.3, 0), c, Enum.Material.Fabric)
	part(m, "ArmR", Vector3.new(0.8, 1.4, 3), CFrame.new(3.1, 2.3, 0), c, Enum.Material.Fabric)
	for _, x in ipairs({ -1.4, 1.4 }) do
		part(m, "Cushion", Vector3.new(2.6, 0.5, 2.2), CFrame.new(x, 1.85, 0.2), c:Lerp(Color3.new(1, 1, 1), 0.15), Enum.Material.Fabric)
	end
end
function B.rug(m, r)
	cyl(m, "Rug", 0.12, 10, CFrame.new(0, 0.06, 0), r.color:Lerp(Color3.fromRGB(40, 30, 30), 0.4), Enum.Material.Fabric)
	cyl(m, "RugRing", 0.14, 7, CFrame.new(0, 0.07, 0), Color3.fromRGB(230, 220, 200), Enum.Material.Fabric)
	cyl(m, "RugCenter", 0.16, 5.6, CFrame.new(0, 0.08, 0), r.color:Lerp(Color3.fromRGB(40, 30, 30), 0.4), Enum.Material.Fabric)
end
function B.floorlamp(m, r)
	cyl(m, "Foot", 0.3, 1.6, CFrame.new(0, 0.15, 0), DARK)
	cyl(m, "Pole", 6, 0.25, CFrame.new(0, 3.2, 0), Color3.fromRGB(200, 180, 120), Enum.Material.Metal)
	local shade = cyl(m, "Shade", 1.6, 2.2, CFrame.new(0, 6.8, 0), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
	shade.Transparency = 0.2
	New("PointLight", { Range = 14, Brightness = 1.2, Color = WARM, Shadows = false, Parent = shade })
end
function B.table(m, r)
	cyl(m, "Top", 0.2, 2.6, CFrame.new(0, 2.6, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
	cyl(m, "Leg", 2.5, 0.3, CFrame.new(0, 1.25, 0), Color3.fromRGB(40, 30, 24))
	cyl(m, "Glass", 0.6, 0.35, CFrame.new(-0.6, 3, 0.3), Color3.fromRGB(220, 230, 240), Enum.Material.Glass)
	cyl(m, "Vase", 0.9, 0.5, CFrame.new(0.5, 3.15, -0.2), Color3.fromRGB(240, 240, 245))
	part(m, "Flower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.5, 3.9, -0.2), r.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end
function B.candles(m, r)
	r.flames = {}
	for i, c in ipairs({ { 0, 0, 2.4 }, { 0.8, 0.4, 1.6 }, { -0.7, 0.5, 1.9 }, { 0.3, -0.7, 1.2 }, { -0.4, -0.5, 1.4 } }) do
		cyl(m, "Candle", c[3], 0.5, CFrame.new(c[1], c[3] / 2, c[2]), Color3.fromRGB(245, 235, 215))
		local f = part(m, "Flame", Vector3.new(0.22, 0.4, 0.22), CFrame.new(c[1], c[3] + 0.25, c[2]), Color3.fromRGB(255, 190, 80), Enum.Material.Neon)
		table.insert(r.flames, f)
		if i == 1 then
			r.light = New("PointLight", { Range = 12, Brightness = 1, Color = Color3.fromRGB(255, 180, 90), Shadows = false, Parent = f })
		end
	end
end
function B.plant(m, r)
	cyl(m, "Pot", 1.6, 1.8, CFrame.new(0, 0.8, 0), Color3.fromRGB(180, 100, 70), Enum.Material.Concrete)
	for i, o in ipairs({ { 0, 2.6, 0, 2.2 }, { 0.6, 3.4, 0.3, 1.6 }, { -0.6, 3.2, -0.2, 1.7 }, { 0, 4, 0, 1.3 } }) do
		part(m, "Leaves", Vector3.new(o[4], o[4], o[4]), CFrame.new(o[1], o[2], o[3]), Color3.fromRGB(40 + i * 8, 110 + i * 10, 50), Enum.Material.Grass, Enum.PartType.Ball)
	end
end
function B.tree(m, r)
	cyl(m, "Trunk", 7, 0.9, CFrame.new(0, 3.5, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	for i, o in ipairs({ { 0, 8, 0, 6 }, { 1.5, 9.5, 0.6, 4.5 }, { -1.4, 9, -0.6, 4.6 }, { 0, 11, 0, 3.8 } }) do
		part(m, "Leaves", Vector3.new(o[4], o[4], o[4]), CFrame.new(o[1], o[2], o[3]), Color3.fromRGB(40 + i * 6, 100 + i * 8, 50), Enum.Material.Grass, Enum.PartType.Ball)
	end
end
function B.bench(m, r)
	local wood = Color3.fromRGB(130, 90, 55)
	for i = 0, 2 do
		part(m, "Plank", Vector3.new(6, 0.25, 0.5), CFrame.new(0, 1.8, -0.6 + i * 0.6), wood, Enum.Material.WoodPlanks)
	end
	part(m, "BackPlank", Vector3.new(6, 0.5, 0.25), CFrame.new(0, 3, -1.1), wood, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -2.6, 2.6 }) do
		part(m, "Leg", Vector3.new(0.3, 1.8, 1.6), CFrame.new(x, 0.9, -0.2), DARK, Enum.Material.Metal)
		part(m, "BackLeg", Vector3.new(0.3, 1.4, 0.3), CFrame.new(x, 2.5, -1.1), DARK, Enum.Material.Metal)
	end
end
function B.streetlamp(m, r)
	cyl(m, "Base", 1, 1.4, CFrame.new(0, 0.5, 0), Color3.fromRGB(30, 34, 32), Enum.Material.Metal)
	cyl(m, "Pole", 10, 0.5, CFrame.new(0, 6, 0), Color3.fromRGB(30, 34, 32), Enum.Material.Metal)
	local head = part(m, "Lantern", Vector3.new(1.6, 2, 1.6), CFrame.new(0, 12, 0), WARM, Enum.Material.Neon)
	part(m, "Cap", Vector3.new(2, 0.4, 2), CFrame.new(0, 13.2, 0), Color3.fromRGB(30, 34, 32), Enum.Material.Metal)
	New("PointLight", { Range = 20, Brightness = 1.2, Color = WARM, Shadows = false, Parent = head })
end
function B.roadcase(m, r)
	local black = Color3.fromRGB(22, 22, 24)
	for _, c in ipairs({ { 0, 1.2, 0, 4, 2.4, 2.4 }, { 0, 3.3, 0, 3.4, 1.8, 2.2 }, { 3.6, 1, 0.2, 2.6, 2, 2.2 } }) do
		local cf = CFrame.new(c[1], c[2], c[3])
		part(m, "Case", Vector3.new(c[4], c[5], c[6]), cf, black)
		part(m, "Edge", Vector3.new(c[4] + 0.08, 0.15, c[6] + 0.08), cf * CFrame.new(0, c[5] / 2 - 0.08, 0), Color3.fromRGB(170, 170, 176), Enum.Material.Metal)
		part(m, "Label", Vector3.new(1, 0.5, 0.05), cf * CFrame.new(0, 0, c[6] / 2 + 0.03), Color3.fromRGB(240, 240, 240))
	end
end
function B.balloonarch(m, r)
	local w = dims(r, r.def)
	local R = w / 2
	local n = math.clamp(math.floor(w * 1.2), 10, 50)
	local cols = { r.color, Color3.new(1, 1, 1), Color3.fromRGB(255, 205, 60) }
	for i = 0, n do
		local a = i * math.pi / n
		for k = 0, 1 do
			local rr = R + (k - 0.5) * 1.2
			part(m, "Balloon", Vector3.new(1.4, 1.4, 1.4), CFrame.new(math.cos(a) * rr, math.sin(a) * rr + 0.5, (k - 0.5) * 0.8), cols[(i + k) % 3 + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
end
function B.banner(m, r)
	part(m, "Bar", Vector3.new(11, 0.4, 0.4), CFrame.new(0, -0.4, 0), METAL, Enum.Material.Metal)
	r.panel = part(m, "Banner", Vector3.new(10, 16, 0.2), CFrame.new(0, -8.6, 0), r.color, Enum.Material.Fabric)
	r.frame, r.label = surfaceText(r.panel, Enum.NormalId.Back, r.artistName or "HEADLINER", WHITE, nil)
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
		preview = opts.preview, -- small pictures (catalog, library, ghost): no live screens needed
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
	for _, f in ipairs(refs.faces or {}) do
		f.gui.Enabled = false
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
		refs.ball.CFrame = refs.cf * CFrame.new(0, -3.3, 0) * CFrame.Angles(0, t * 1.5, 0)
		refs.emitter.Enabled = ctx.seg == 3 or ctx.seg == 4
	elseif Builder.SCREEN_KINDS[k] then
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
		local bg = c1:Lerp(c2, 0.5 + 0.5 * math.sin(t * 1.3))
		local live = (mode == "liveArtist" or mode == "liveCrowd") and ctx.liveFeed or nil
		for fi, f in ipairs(refs.faces or {}) do
			f.frame.BackgroundColor3 = bg
			if f.grad then
				f.grad.Rotation = (t * 40) % 360
			end
			if f.label.Text ~= txt then
				f.label.Text = txt
			end
			f.image.Visible = mode == "image"
			if mode == "image" and cfg.img then
				local img = "rbxassetid://" .. tostring(cfg.img)
				if f.image.Image ~= img then
					f.image.Image = img
				end
			end
			f.live.Visible = live ~= nil
			if live then
				live(f, mode, refs, fi)
			end
		end
		if k == "ledcube" and refs.cubeParts then
			local target = (ctx.seg == 3) and 1 or 0
			refs.cubeLift = refs.cubeLift + (target - refs.cubeLift) * math.min(1, (ctx.dt or 0.03) * 1.5)
			local off = CFrame.new(0, -refs.cubeLift * 5, 0) * CFrame.Angles(0, t * 0.15, 0)
			for _, cp in ipairs(refs.cubeParts) do
				cp[1].CFrame = refs.cf * off * cp[2]
			end
		elseif k == "ledtower" then
			setNeon(refs, c1)
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
	elseif k == "lift" or k == "poplift" then
		local lt = refs.liftT or ctx.liftT
		-- the doors fold away first, then the platform comes up through the opening
		setHatch(refs, math.clamp(lt * 5, 0, 1))
		refs.platform.CFrame = refs.cf * refs.platformLocal * CFrame.new(0, (lt - 1) * 10, 0)
		refs.platform.Transparency = (lt < 0.02) and 1 or 0
		if refs.ringColor ~= c1 then
			refs.ringColor = c1
			for _, p in ipairs(refs.ringParts) do
				p.Color = c1
			end
		end
		if k == "poplift" then
			if lt >= 0.999 and not refs.fired and refs.armed then
				refs.fired = true
				for _, b in ipairs(refs.burstParts) do
					b[1]:Emit(70)
					b[2]:Emit(25)
				end
			elseif lt < 0.5 then
				refs.armed = true
				refs.fired = false
			end
		end
	elseif k == "towerlift" then
		local h = (refs.towerT or 0) * Builder.TOWER_HEIGHT
		-- three telescopic sections share the height
		for i, tube in ipairs(refs.tubes) do
			-- section i (widest at the bottom) covers its third of the height
			local y0 = 0.6 + h * (i - 1) / 3
			local len = math.max(0.4, h / 3 + 0.6)
			tube.Size = Vector3.new(len, tube.Size.Y, tube.Size.Z)
			tube.CFrame = refs.cf * CFrame.new(0, y0 + len / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
		refs.top.CFrame = refs.cf * CFrame.new(0, 1.1 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		refs.topRing.CFrame = refs.cf * CFrame.new(0, 1.45 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		refs.under.CFrame = refs.cf * CFrame.new(0, 0.55 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for i, rail in ipairs(refs.rails) do
			local a = (i - 1) * math.pi / 4
			rail.CFrame = refs.cf * CFrame.new(math.cos(a) * 4.8, 2.9 + h, math.sin(a) * 4.8)
		end
		refs.topRing.Color = c1
		refs.baseRing.Color = c2
	elseif k == "stadiumroof" then
		refs.roofLED.Color = c1:Lerp(c2, ctx.beat or 0)
	elseif k == "delaytower" then
		refs.blink.Transparency = (math.floor(t * 1.5) % 2 == 0) and 0 or 0.8
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
			refs.emitter:Emit(55)
			refs.smokeEmitter:Emit(10)
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
	elseif k == "portal" or k == "arch" then
		local n = #refs.ring
		local head = math.floor(t * 12) % n
		if refs.lastHead ~= head then
			refs.lastHead = head
			for i, p in ipairs(refs.ring) do
				local d = (i - head) % n
				p.Color = (d < n * 0.25) and c2 or c1
			end
		end
	elseif k == "kinetic" then
		local amp = 2 + 5 * (ctx.intensity or 0.5)
		for _, b in ipairs(refs.bars) do
			local drop = 7 + (math.sin(t * 0.9 * (ctx.sweep or 1) + b.i * 0.45) + 1) * amp
			b.bar.CFrame = refs.cf * CFrame.new(b.x, -drop, 0)
			b.wa.Size = Vector3.new(0.08, drop, 0.08)
			b.wb.Size = Vector3.new(0.08, drop, 0.08)
			b.wa.CFrame = refs.cf * CFrame.new(b.x, -drop / 2, -3)
			b.wb.CFrame = refs.cf * CFrame.new(b.x, -drop / 2, 3)
			b.bar.Color = (b.i % 2 == 0) and c1 or c2
		end
	elseif k == "moon" then
		refs.moon.CFrame = refs.moon.CFrame * CFrame.Angles(0, (ctx.dt or 0.03) * 0.1, 0)
		refs.halo.Color = Color3.fromRGB(255, 230, 170):Lerp(c1, 0.4)
		refs.halo.Transparency = (ctx.seg == 3) and 0.7 or 0.86
	elseif k == "skyline" or k == "house" then
		if refs.lastBeat ~= ctx.beatCount and ctx.beatCount % 2 == 0 then
			refs.lastBeat = ctx.beatCount
			for i, wnd in ipairs(refs.windows) do
				local on = ((i * 7 + ctx.beatCount) % 5) ~= 0
				wnd.Transparency = on and 0.15 or 0.85
				wnd.Color = (k == "house" or ctx.seg == 3) and WARM or (((i + ctx.beatCount) % 3 == 0) and c1 or WARM)
			end
		end
	elseif k == "statue" then
		refs.head.CFrame = refs.cf * refs.headLocal * CFrame.Angles(0, math.sin(t * 0.25 + refs.phase) * 0.6, 0)
		refs.visor.CFrame = refs.head.CFrame * CFrame.new(0, 0.4, 3.05)
		refs.visor.Color = c1
	elseif k == "robotarm" then
		local sp = ctx.sweep or 1
		local yaw = math.sin(t * 0.5 * sp + refs.phase) * 1.2
		local sh = -0.25 + math.sin(t * 0.7 * sp + refs.phase) * 0.35
		local el = 0.5 + math.sin(t * 0.9 * sp + refs.phase * 2) * 0.45
		local turret = refs.cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, yaw, 0)
		local shoulder = turret * CFrame.Angles(sh, 0, 0)
		refs.turret.CFrame = turret * CFrame.Angles(0, 0, math.pi / 2)
		refs.lower.CFrame = shoulder * CFrame.new(0, 7.8, 0)
		local elbow = shoulder * CFrame.new(0, 14.8, 0) * CFrame.Angles(el, 0, 0)
		refs.upper.CFrame = elbow * CFrame.new(0, 6, 0)
		refs.tool.CFrame = elbow * CFrame.new(0, 13, 0)
		refs.lamp.CFrame = elbow * CFrame.new(0, 14.4, 0)
		refs.lamp.Color = c1
		refs.beam.Color = ColorSequence.new(c1)
		refs.beam.Enabled = (ctx.intensity or 0) > 0.3
	elseif k == "curtain" then
		local dropT = ctx.curtainT or 0
		if dropT <= 0 then
			refs.drape.CFrame = refs.cf * refs.drapeHome
			refs.drape.Transparency = 0
		else
			local h = refs.drape.Size.Y
			refs.drape.CFrame = refs.cf * refs.drapeHome * CFrame.new(0, -h * math.min(1, dropT * dropT * 2), 0)
			refs.drape.Transparency = math.min(1, dropT * 1.2)
		end
		if refs.drapeLabel then
			refs.drapeLabel.TextTransparency = refs.drape.Transparency
		end
	elseif k == "balls" then
		if hit.balls then
			local fwd = refs.cf.LookVector * -1
			for i = 1, 5 do
				local ball = part(refs.model, "Balloon", Vector3.new(8, 8, 8), refs.cf * CFrame.new(0, 5, 0), (i % 2 == 0) and c1 or c2, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				local side = Vector3.new(fwd.Z, 0, -fwd.X) * ((i - 3) * 6)
				table.insert(refs.balloons, { p = ball, v = fwd * (18 + i * 4) + side + Vector3.new(0, 30 + i * 3, 0), age = 0 })
			end
		end
		local dt = ctx.dt or 0.03
		for i = #refs.balloons, 1, -1 do
			local b = refs.balloons[i]
			b.age = b.age + dt
			b.v = b.v + Vector3.new(0, -22 * dt, 0)
			local pos = b.p.Position + b.v * dt
			if pos.Y < 10 and b.v.Y < 0 then
				-- the crowd punches it back up
				b.v = Vector3.new(b.v.X * 0.6 + (math.random() - 0.5) * 12, 22 + math.random() * 10, b.v.Z * 0.6 + (math.random() - 0.5) * 12)
				pos = Vector3.new(pos.X, 10, pos.Z)
			end
			b.p.CFrame = CFrame.new(pos)
			if b.age > 16 then
				b.p:Destroy()
				table.remove(refs.balloons, i)
			end
		end
	elseif k == "lowfog" then
		refs.emitter.Enabled = ctx.fog == true
	elseif k == "streamers" then
		if hit.confetti or hit.streamers then
			refs.emitter:Emit(90)
		end
	elseif k == "keys" or k == "amps" or k == "wristbands" then
		if refs.lastC ~= c1 then
			refs.lastC = c1
			setNeon(refs, c1)
		end
	elseif k == "uplight" then
		if refs.lastC ~= c1 then
			refs.lastC = c1
			refs.lens.Color = c1
			refs.light.Color = c1
			refs.beam.Color = ColorSequence.new(c1)
		end
	elseif k == "ledbar" then
		local n = #refs.pixels
		local head = math.floor(t * 10) % n
		for i, px in ipairs(refs.pixels) do
			px.Color = (((i - head) % n) < n / 3) and c2 or c1
		end
	elseif k == "lightpole" then
		refs.tube.Color = c1:Lerp(Color3.new(1, 1, 1), 0.4 * (1 - (ctx.beat or 0)))
	elseif k == "stringlights" then
		for i, b in ipairs(refs.bulbs) do
			b.Transparency = (math.sin(t * 3 + i * 1.7) > 0.85) and 0.6 or 0
		end
	elseif k == "lanterns" then
		for _, l in ipairs(refs.lanterns) do
			l.p.CFrame = refs.cf * l.home * CFrame.new(math.sin(t * 0.8 + l.i) * 0.3, 0, 0)
		end
	elseif k == "tvstack" then
		if refs.lastBeat ~= ctx.beatCount then
			refs.lastBeat = ctx.beatCount
			for i, tv in ipairs(refs.tvs) do
				local v = (i + ctx.beatCount) % 3
				tv.Color = (v == 0) and c1 or ((v == 1) and c2 or Color3.new(1, 1, 1))
			end
		end
	elseif k == "neonheart" or k == "neonstar" or k == "neonbolt" then
		local c = c1:Lerp(Color3.new(1, 1, 1), 0.3 * (1 - (ctx.beat or 0)))
		for _, p in ipairs(refs.neon) do
			p.Color = c
		end
	elseif k == "bubbles" then
		refs.emitter.Enabled = ctx.seg == 3 or (ctx.intensity or 1) < 0.85
	elseif k == "snow" then
		refs.emitter.Enabled = ctx.seg == 3
	elseif k == "windfan" then
		refs.spin = refs.spin + (ctx.dt or 0.03) * (4 + 10 * (ctx.intensity or 0.5))
		for _, b in ipairs(refs.blades) do
			b.p.CFrame = refs.cf * refs.hubLocal * CFrame.Angles(0, 0, refs.spin + b.a) * CFrame.new(0, 1, 0)
		end
	elseif k == "candles" then
		refs.light.Brightness = 0.8 + math.sin(t * 13) * 0.15 + math.sin(t * 7.3) * 0.1
		for i, f in ipairs(refs.flames) do
			f.Transparency = 0.1 + 0.15 * math.abs(math.sin(t * 9 + i))
		end
	elseif k == "banner" then
		if ctx.artistName and refs.label.Text ~= ctx.artistName then
			refs.label.Text = ctx.artistName
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
Builder.SCREEN_KINDS = { led = true, led_side = true, ledcube = true, ledtower = true, ledpillar = true }
local SCREEN_NAMES = { song = "SONG TITLE", artist = "ARTIST NAME", text = "TEXT", image = "IMAGE", liveArtist = "LIVE CAM: ARTIST", liveCrowd = "LIVE CAM: CROWD" }
Builder.SCREEN_NAMES = SCREEN_NAMES
function Builder.screenConfig(refs, spot)
	local rec = refs.rec or {}
	local base = (refs.kind == "led_side" or refs.kind == "ledtower" or refs.kind == "ledpillar") and "artist" or "song"
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
	if Builder.SCREEN_KINDS[k] and refs.label then
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
		for _, f in ipairs(refs.faces or {}) do
			f.label.Text = txt .. ((extra > 0) and ("  (+" .. extra .. " song" .. (extra > 1 and "s" or "") .. ")") or "")
			f.image.Visible = cfg.m == "image" and cfg.img ~= nil
			if cfg.img then
				f.image.Image = "rbxassetid://" .. tostring(cfg.img)
			end
			f.live.Visible = false
		end
	end
	if k == "curtain" then
		Builder.animate(refs, { t = 0, c1 = refs.color, c2 = refs.color, hit = {}, curtainT = 0, beat = 0, beatCount = 0 })
	elseif k == "lift" or k == "poplift" or k == "towerlift" then
		refs.liftT, refs.towerT = 1, 0
		Builder.animate(refs, { t = 0, c1 = refs.color, c2 = refs.color, hit = {}, beat = 0, beatCount = 0, liftT = 1 })
		refs.liftT = nil
	elseif k == "inflatable" then
		refs.inflate = 0
		Builder.animate(refs, { t = 0, c1 = refs.color, c2 = refs.color, hit = {}, inflate = 0.25, beat = 0, beatCount = 0 })
	end
end

return Builder
