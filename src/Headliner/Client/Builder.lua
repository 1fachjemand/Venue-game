-- Builds 3D models for stage items and animates them during shows.
-- Every item is built around the local origin (bottom centre for floor items, hanging point for rig items)
-- and then moved into place with Builder.place().
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local Visuals = require(Root.Client.Visuals)

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

-- light in the haze: not a hard "laser" but a soft cone. A core that is softer right at the lamp, gets
-- stronger, then fades out slowly, and a much wider, very faint glow around it (Builder.glowOf).
Builder.glowOf = setmetatable({}, { __mode = "k" })
local function softFade(t0, k)
	t0 = math.clamp(t0, 0, 0.95)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.min(1, t0 + 0.2 * k)),
		NumberSequenceKeypoint.new(0.1, t0),
		NumberSequenceKeypoint.new(0.45, t0 + (1 - t0) * 0.45),
		NumberSequenceKeypoint.new(0.8, t0 + (1 - t0) * 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
end
Builder.softFade = softFade
-- the light a fixture throws (a SpotLight in the beam's direction): lights up the stage and the artist.
-- Only in shows, and at most Builder.LIGHT_BUDGET of them (Stage3D.renderDesign resets the count)
Builder.lightOf = setmetatable({}, { __mode = "k" })
Builder.LIGHT_BUDGET = 48
Builder.lightsUsed = 0
local function addLight(p, dir, width1, len, color)
	if Builder.editMode or Builder.buildingPreview or Builder.lightsUsed >= Builder.LIGHT_BUDGET then
		return nil
	end
	Builder.lightsUsed = Builder.lightsUsed + 1
	-- the face of the part that looks most along the beam
	local best, bestDot = Enum.NormalId.Bottom, -2
	for _, nid in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top, Enum.NormalId.Bottom }) do
		local d = Vector3.FromNormalId(nid):Dot(dir.Unit)
		if d > bestDot then
			best, bestDot = nid, d
		end
	end
	local angle = math.clamp(math.deg(2 * math.atan((width1 / 2) / math.max(1, len))) * 1.3, 20, 90)
	return New("SpotLight", { Face = best, Angle = angle, Range = 60, Brightness = 1.6, Color = color, Shadows = false, Parent = p })
end
local function beam(p, a0Pos, a1Pos, width0, width1, color, transparency0, noGlow)
	local a0 = New("Attachment", { Position = a0Pos, Parent = p })
	local a1 = New("Attachment", { Position = a1Pos, Parent = p })
	-- the beam in the haze is only a soft hint now: the light itself (SpotLight) does the work
	local t0 = math.min(0.93, (transparency0 or 0.35) + 0.38)
	local core = New("Beam", {
		Name = "SoftBeam",
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = width0,
		Width1 = width1,
		Color = ColorSequence.new(color),
		Transparency = softFade(t0, 1),
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 10,
		Parent = p,
	})
	if noGlow then
		return core
	end
	local glow = New("Beam", {
		Name = "BeamGlow",
		Attachment0 = a0,
		Attachment1 = a1,
		Width0 = width0 * 2.6,
		Width1 = width1 * 2.1,
		Color = ColorSequence.new(color),
		Transparency = softFade(math.min(0.96, t0 + 0.3), 0.5),
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 10,
		Parent = p,
	})
	Builder.glowOf[core] = glow
	local L = addLight(p, a1Pos - a0Pos, width1, (a1Pos - a0Pos).Magnitude, color)
	if L then
		Builder.lightOf[core] = L
	end
	return core
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
		Brightness = 0.85, -- screens glow, but you can still see what is on them (2 was far too bright)
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
			top.CFrame = p.CFrame + Vector3.new(0, h / 2 - 0.01, 0)
			if Builder.editMode then
				-- while building: a dark screen panel with a soft tint (a big glowing blue floor is blinding)
				top.Material = Enum.Material.Glass
				top.Color = Color3.fromRGB(30, 34, 52)
				top.Reflectance = 0.08
			else
				top.Material = Enum.Material.Neon
				top.Color = SKINS.led[1]
			end
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

-- decks keep exactly the height you choose (no hidden offsets), so decks of the same height line up
local function deckH(r, h)
	return h
end

function B.deck(m, r)
	local w, d, h = dims(r, r.def)
	h = deckH(r, h)
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

-- a flat right triangle filling one corner of the box (cx, cz, w, d): corner = where the right angle is
-- "bl" back-left (x min, z min), "br" back-right, "fl" front-left (x min, z max), "fr" front-right
local function cornerWedge(m, cx, cz, w, d, h, corner)
	local back = corner == "bl" or corner == "br"
	local mirror = (corner == "br") or (corner == "fl")
	local cf = CFrame.new(cx, h / 2, cz) * CFrame.Angles(0, back and math.pi or 0, 0) * CFrame.Angles(0, 0, mirror and -math.pi / 2 or math.pi / 2)
	return New("WedgePart", { Name = "Deck", Size = Vector3.new(h, w, d), CFrame = cf, Color = DECK_COLOR, Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
end
local function deckBlock(m, cx, cz, w, d, h)
	return part(m, "Deck", Vector3.new(w, h, d), CFrame.new(cx, h / 2, cz), DECK_COLOR)
end
-- A smooth ring (or a part of one) from exact pieces: every segment is a trapezoid made of one block and two
-- flat wedges, so neighbours meet edge to edge (no gaps outside, no overlaps inside, no z-fighting).
-- ri = 0 makes a filled disc slice (two wedges per segment). The ring lies flat in the XZ plane of `base`
-- (thickness h along base's Y, angle 0 = base's +Z, growing towards +X). mk(size, cf, kind) makes a part.
local function ringPieces(mk, ri, ro, a0, a1, n, h, base)
	local th = (a1 - a0) / n / 2
	local c, t = math.cos(th), math.tan(th)
	-- apothems: the corners of every piece lie exactly on the two circles
	local rI, rO = ri * c, ro * c
	local bi, bo = rI * t, rO * t
	local depth = rO - rI
	local zc = (rI + rO) / 2
	local tw = bo - bi
	local made = {}
	for i = 0, n - 1 do
		local seg = base * CFrame.Angles(0, a0 + (2 * i + 1) * th, 0)
		if bi > 0.02 then
			table.insert(made, mk(Vector3.new(2 * bi + 0.002, h, depth), seg * CFrame.new(0, 0, zc), "block"))
		end
		if tw > 0.01 then
			-- right angle at the outer edge, next to the block: "fl" on the +X side, "fr" on the -X side
			table.insert(made, mk(Vector3.new(h, tw, depth), seg * CFrame.new(bi + tw / 2, 0, zc) * CFrame.Angles(0, 0, -math.pi / 2), "wedge"))
			table.insert(made, mk(Vector3.new(h, tw, depth), seg * CFrame.new(-bi - tw / 2, 0, zc) * CFrame.Angles(0, 0, math.pi / 2), "wedge"))
		end
	end
	return made
end
Builder.ringPieces = ringPieces
local function deckMaker(m)
	return function(size, cf, kind)
		if kind == "wedge" then
			return New("WedgePart", { Name = "Deck", Size = size, CFrame = cf, Color = DECK_COLOR, Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
		end
		return part(m, "Deck", size, cf, DECK_COLOR)
	end
end
-- the light line along a circle: short straight pieces on the same polygon as the deck's edge
local function circleEdge(m, list, cx, cz, rad, a0, a1, n, h, color)
	for i = 0, n - 1 do
		local p0, p1 = a0 + i * (a1 - a0) / n, a0 + (i + 1) * (a1 - a0) / n
		table.insert(list, edge(m, cx + math.sin(p0) * rad, cz + math.cos(p0) * rad, cx + math.sin(p1) * rad, cz + math.cos(p1) * rad, h, color))
	end
end

-- octagon (regular when w = d): a cross of two blocks and four corner triangles
function B.deck_oct(m, r)
	local w, d, h = dims(r, r.def)
	local c = math.min(w, d) * 0.2929
	local hw, hd = w / 2, d / 2
	r.surfaces = {
		deckBlock(m, 0, 0, w, d - 2 * c, h),
		deckBlock(m, 0, -hd + c / 2, w - 2 * c, c, h),
		deckBlock(m, 0, hd - c / 2, w - 2 * c, c, h),
		cornerWedge(m, -hw + c / 2, -hd + c / 2, c, c, h, "fr"),
		cornerWedge(m, hw - c / 2, -hd + c / 2, c, c, h, "fl"),
		cornerWedge(m, -hw + c / 2, hd - c / 2, c, c, h, "br"),
		cornerWedge(m, hw - c / 2, hd - c / 2, c, c, h, "bl"),
	}
	r.neon = {}
	local pts = { { -hw + c, -hd }, { hw - c, -hd }, { hw, -hd + c }, { hw, hd - c }, { hw - c, hd }, { -hw + c, hd }, { -hw, hd - c }, { -hw, -hd + c } }
	for i = 1, 8 do
		local a, b = pts[i], pts[i % 8 + 1]
		table.insert(r.neon, edge(m, a[1], a[2], b[1], b[2], h, r.color))
	end
	finishDeck(r)
end
-- hexagon: points left and right, flat at the back and the front
function B.deck_hex(m, r)
	local w, d, h = dims(r, r.def)
	local q = w / 4
	r.surfaces = {
		deckBlock(m, 0, 0, w / 2, d, h),
		cornerWedge(m, -w / 2 + q / 2, -d / 4, q, d / 2, h, "fr"),
		cornerWedge(m, w / 2 - q / 2, -d / 4, q, d / 2, h, "fl"),
		cornerWedge(m, -w / 2 + q / 2, d / 4, q, d / 2, h, "br"),
		cornerWedge(m, w / 2 - q / 2, d / 4, q, d / 2, h, "bl"),
	}
	r.neon = {}
	local pts = { { -q, -d / 2 }, { q, -d / 2 }, { w / 2, 0 }, { q, d / 2 }, { -q, d / 2 }, { -w / 2, 0 } }
	for i = 1, 6 do
		local a, b = pts[i], pts[i % 6 + 1]
		table.insert(r.neon, edge(m, a[1], a[2], b[1], b[2], h, r.color))
	end
	finishDeck(r)
end
-- trapezoid: full width at the back, half as wide at the front (a stage that narrows into a runway)
function B.deck_trap(m, r)
	local w, d, h = dims(r, r.def)
	local q = w / 4
	r.surfaces = {
		deckBlock(m, 0, 0, w / 2, d, h),
		cornerWedge(m, -w / 2 + q / 2, 0, q, d, h, "br"),
		cornerWedge(m, w / 2 - q / 2, 0, q, d, h, "bl"),
	}
	r.neon = {
		edge(m, -w / 2, -d / 2, w / 2, -d / 2, h, r.color),
		edge(m, -q, d / 2, q, d / 2, h, r.color),
		edge(m, -w / 2, -d / 2, -q, d / 2, h, r.color),
		edge(m, w / 2, -d / 2, q, d / 2, h, r.color),
	}
	finishDeck(r)
end
-- half round: the flat side at the back, the round side to the front (smooth: exact slices of a disc)
function B.deck_half(m, r)
	local w, _, h = dims(r, r.def)
	local rad = w / 2
	local n = math.clamp(math.floor(w / 2), 16, 32)
	r.surfaces = ringPieces(deckMaker(m), 0, rad, -math.pi / 2, math.pi / 2, n, h, CFrame.new(0, h / 2, -rad / 2))
	r.neon = { edge(m, -rad, -rad / 2, rad, -rad / 2, h, r.color) }
	circleEdge(m, r.neon, 0, -rad / 2, rad, -math.pi / 2, math.pi / 2, n, h, r.color)
	finishDeck(r)
end
-- ring: a round runway around a hole in the middle (in-the-round shows walk all the way round)
function B.deck_ring(m, r)
	local w, _, h = dims(r, r.def)
	local outer = w / 2
	local width = math.clamp(w * 0.22, 4, 18)
	local n = math.clamp(math.floor(w * 0.6), 32, 56)
	r.surfaces = ringPieces(deckMaker(m), outer - width, outer, 0, math.pi * 2, n, h, CFrame.new(0, h / 2, 0))
	r.neon = {}
	circleEdge(m, r.neon, 0, 0, outer, 0, math.pi * 2, n, h, r.color)
	circleEdge(m, r.neon, 0, 0, outer - width, 0, math.pi * 2, n, h, r.color)
	finishDeck(r)
end
-- rounded rectangle: soft corners
function B.deck_rounded(m, r)
	local w, d, h = dims(r, r.def)
	local rr = math.min(w, d) * 0.22
	r.surfaces = {
		deckBlock(m, 0, 0, w, d - 2 * rr, h),
		deckBlock(m, 0, 0, w - 2 * rr, d, h),
	}
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		table.insert(r.surfaces, cyl(m, "Deck", h, rr * 2, CFrame.new(c[1] * (w / 2 - rr), h / 2, c[2] * (d / 2 - rr)), DECK_COLOR))
	end
	r.neon = {
		edge(m, -w / 2 + rr, -d / 2, w / 2 - rr, -d / 2, h, r.color),
		edge(m, -w / 2 + rr, d / 2, w / 2 - rr, d / 2, h, r.color),
		edge(m, -w / 2, -d / 2 + rr, -w / 2, d / 2 - rr, h, r.color),
		edge(m, w / 2, -d / 2 + rr, w / 2, d / 2 - rr, h, r.color),
	}
	finishDeck(r)
end

function B.deck_tri(m, r)
	local w, d, h = dims(r, r.def)
	h = deckH(r, h)
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
	h = deckH(r, h)
	-- right angle at the back-left corner (rec.flip = mirrored: back-right corner); the "right" deck
	-- in the catalog is the mirrored one from the start
	local flip = (r.rec and r.rec.flip == true) ~= (r.def.id == "deck_corner_r")
	local f = flip and -1 or 1
	r.surfaces = { flatWedge(m, 0, 0, w, d, h, flip) }
	r.neon = {
		edge(m, -w / 2, -d / 2, w / 2, -d / 2, h, r.color),
		edge(m, -w / 2 * f, -d / 2, -w / 2 * f, d / 2, h, r.color),
		edge(m, w / 2 * f, -d / 2, -w / 2 * f, d / 2, h, r.color),
	}
	finishDeck(r)
end

------------------------------------------------------------------ shapes (build your own): rec.col = {r,g,b}, rec.mat = material name
Builder.PRIM_COLORS = {
	{ 245, 245, 248 }, { 30, 30, 34 }, { 120, 124, 132 }, { 220, 40, 50 }, { 255, 130, 40 }, { 255, 210, 60 },
	{ 70, 190, 90 }, { 40, 180, 200 }, { 50, 100, 230 }, { 140, 80, 230 }, { 255, 110, 190 }, { 190, 150, 90 },
}
Builder.PRIM_MATERIALS = { "SmoothPlastic", "Plastic", "Neon", "Metal", "Glass", "Wood", "WoodPlanks", "Fabric", "Marble", "Brick", "Concrete", "Foil", "DiamondPlate", "Granite", "Ice", "Slate" }
local function primLook(r)
	local rec = r.rec or {}
	local c = rec.col
	local color = (type(c) == "table" and #c >= 3) and Color3.fromRGB(c[1], c[2], c[3]) or Color3.fromRGB(220, 220, 226)
	local mat = Enum.Material.SmoothPlastic
	for _, name in ipairs(Builder.PRIM_MATERIALS) do
		if name == rec.mat then
			mat = Enum.Material[name]
		end
	end
	return color, mat
end
local function primPart(m, r, size, cf, kind)
	local color, mat = primLook(r)
	local p
	if kind == "wedge" then
		p = New("WedgePart", { Name = "Shape", Size = size, CFrame = cf, Color = color, Material = mat, Anchored = true, CanCollide = false, CanTouch = false, Parent = m })
	elseif kind == "corner" then
		p = New("CornerWedgePart", { Name = "Shape", Size = size, CFrame = cf, Color = color, Material = mat, Anchored = true, CanCollide = false, CanTouch = false, Parent = m })
	else
		p = part(m, "Shape", size, cf, color, mat)
	end
	if mat == Enum.Material.Glass then
		p.Transparency = 0.4
	end
	return p
end
function B.prim_block(m, r)
	local w, d, h = dims(r, r.def)
	r.surfaces = { primPart(m, r, Vector3.new(w, h, d), CFrame.new(0, h / 2, 0)) }
end
function B.prim_cyl(m, r)
	local w, _, h = dims(r, r.def)
	local color, mat = primLook(r)
	r.surfaces = { cyl(m, "Shape", h, w, CFrame.new(0, h / 2, 0), color, mat) }
end
function B.prim_ball(m, r)
	local w, d, h = dims(r, r.def)
	local p = primPart(m, r, Vector3.new(w, h, d), CFrame.new(0, h / 2, 0))
	New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
end
function B.prim_wedge(m, r)
	local w, d, h = dims(r, r.def)
	r.surfaces = { primPart(m, r, Vector3.new(w, h, d), CFrame.new(0, h / 2, 0), "wedge") }
end
function B.prim_corner(m, r)
	local w, d, h = dims(r, r.def)
	primPart(m, r, Vector3.new(w, h, d), CFrame.new(0, h / 2, 0), "corner")
end
local function primMaker(m, r)
	return function(size, cf, kind)
		return primPart(m, r, size, cf, kind ~= "block" and kind or nil)
	end
end
function B.prim_tube(m, r)
	local w, _, h = dims(r, r.def)
	local rad = w / 2
	local thick = math.max(0.3, w * 0.1)
	r.surfaces = ringPieces(primMaker(m, r), rad - thick, rad, 0, math.pi * 2, math.clamp(math.floor(w * 2), 32, 56), h, CFrame.new(0, h / 2, 0))
end

B.deck_corner_r = function(m, r)
	return B.deck_corner(m, r)
end

function B.deck_round(m, r)
	local w, _, h = dims(r, r.def)
	h = deckH(r, h)
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
local function lattice(m, c, L, s)
	s = s or 1
	local h = 0.9 * s
	local corners = { Vector3.new(0, h, h), Vector3.new(0, h, -h), Vector3.new(0, -h, h), Vector3.new(0, -h, -h) }
	for _, k in ipairs(corners) do
		tube(m, (c * CFrame.new(-L / 2, k.Y, k.Z)).Position, (c * CFrame.new(L / 2, k.Y, k.Z)).Position, 0.22 * math.sqrt(s))
	end
	local seg = math.max(1, math.floor(L / (3 * s)))
	local step = L / seg
	for i = 0, seg - 1 do
		local x0, x1 = -L / 2 + i * step, -L / 2 + (i + 1) * step
		local flip = (i % 2 == 0) and 1 or -1
		local t = 0.12 * math.sqrt(s)
		tube(m, (c * CFrame.new(x0, h * flip, h)).Position, (c * CFrame.new(x1, -h * flip, h)).Position, t)
		tube(m, (c * CFrame.new(x0, h * flip, -h)).Position, (c * CFrame.new(x1, -h * flip, -h)).Position, t)
		tube(m, (c * CFrame.new(x0, h, -h * flip)).Position, (c * CFrame.new(x1, h, h * flip)).Position, t)
		if s > 1.5 then
			tube(m, (c * CFrame.new(x0, -h, -h * flip)).Position, (c * CFrame.new(x1, -h, h * flip)).Position, t)
		end
	end
end

-- trusses are mostly holes: an invisible solid box makes every click on them hit
local function hitBox(m, size, cf)
	local p = part(m, "HitBox", size, cf, DARK)
	p.Transparency = 1
	p.CastShadow = false
	return p
end
function B.truss_beam(m, r)
	local w = dims(r, r.def)
	lattice(m, CFrame.new(0, -1, 0), w)
	hitBox(m, Vector3.new(w, 2.2, 2.2), CFrame.new(0, -1, 0))
end

-- truss towers always reach up to the rig (the beams rest on top): height from the stage they stand on
-- (refs.rigTop, set by Stage3D) or the rig of the stage size being built (Builder.rigTop)
local function towerHeight(r)
	return math.clamp(r.rigTop or Builder.rigTop or 38, 8, 140)
end
function B.truss(m, r)
	local H = towerHeight(r)
	part(m, "Foot", Vector3.new(3.4, 0.3, 3.4), CFrame.new(0, 0.15, 0), DARK)
	lattice(m, CFrame.new(0, H / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), H)
	part(m, "TopPlate", Vector3.new(2.3, 0.2, 2.3), CFrame.new(0, H + 0.1, 0), METAL, Enum.Material.Metal)
	hitBox(m, Vector3.new(2.2, H, 2.2), CFrame.new(0, H / 2, 0))
	r.towerH = H
end
function B.truss_xl(m, r)
	local H = towerHeight(r)
	-- heavy steel base with ballast blocks, wide box truss, a sleeve block on top
	part(m, "Base", Vector3.new(8, 0.6, 8), CFrame.new(0, 0.3, 0), DARK, Enum.Material.DiamondPlate)
	for _, o in ipairs({ { 3, 3 }, { -3, 3 }, { 3, -3 }, { -3, -3 } }) do
		part(m, "Ballast", Vector3.new(1.6, 1.2, 1.6), CFrame.new(o[1], 1.2, o[2]), Color3.fromRGB(70, 72, 78), Enum.Material.Concrete)
	end
	lattice(m, CFrame.new(0, H / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), H - 0.6, 2)
	part(m, "Sleeve", Vector3.new(4.4, 1.6, 4.4), CFrame.new(0, H - 1.2, 0), DARK, Enum.Material.Metal)
	part(m, "TopPlate", Vector3.new(4.2, 0.25, 4.2), CFrame.new(0, H + 0.12, 0), METAL, Enum.Material.Metal)
	-- a ladder up the front
	part(m, "LadderL", Vector3.new(0.12, H - 2, 0.12), CFrame.new(-0.5, H / 2, 1.95), METAL, Enum.Material.Metal)
	part(m, "LadderR", Vector3.new(0.12, H - 2, 0.12), CFrame.new(0.5, H / 2, 1.95), METAL, Enum.Material.Metal)
	for y = 2, H - 2, 1.5 do
		part(m, "Rung", Vector3.new(1, 0.1, 0.1), CFrame.new(0, y, 1.95), METAL, Enum.Material.Metal)
	end
	hitBox(m, Vector3.new(4, H, 4), CFrame.new(0, H / 2, 0))
	r.towerH = H
end

-- parts that move with a light's head: r.head is an invisible pivot, the visible body follows it
local function headPart(r, p, off)
	r.headParts = r.headParts or {}
	table.insert(r.headParts, { p, off })
	p.CFrame = r.headLocal * off
	return p
end
local function followHead(refs)
	if refs.headParts then
		local h = refs.head.CFrame
		for _, hp in ipairs(refs.headParts) do
			hp[1].CFrame = h * hp[2]
		end
	end
end
Builder.followHead = followHead
-- hanging clamp with safety cable (rig lights)
local function rigClamp(m, y)
	part(m, "Clamp", Vector3.new(0.5, 0.5, 0.9), CFrame.new(0, -0.25, 0), METAL, Enum.Material.Metal)
	cyl(m, "ClampBolt", 0.9, 0.18, CFrame.new(0, -0.3, 0) * CFrame.Angles(0, 0, -math.pi / 2), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	part(m, "SafetyCable", Vector3.new(0.07, (y or 1) - 0.1, 0.07), CFrame.new(0.31, -(y or 1) / 2 - 0.03, 0.37), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
end

function B.par(m, r)
	-- LED PAR can on a U-yoke: round body, cooling ribs, front rim with a gel frame
	rigClamp(m, 0.8)
	part(m, "Yoke", Vector3.new(2.5, 0.22, 0.4), CFrame.new(0, -0.65, 0), METAL, Enum.Material.Metal)
	part(m, "YokeL", Vector3.new(0.24, 1.6, 0.46), CFrame.new(-1.15, -1.4, 0), METAL, Enum.Material.Metal)
	part(m, "YokeR", Vector3.new(0.24, 1.6, 0.46), CFrame.new(1.15, -1.4, 0), METAL, Enum.Material.Metal)
	for _, x in ipairs({ -1.3, 1.3 }) do
		cyl(m, "YokeKnob", 0.3, 0.55, CFrame.new(x, -2, 0) * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.Angles(0, 0, 0), Color3.fromRGB(30, 30, 34))
	end
	cyl(m, "Body", 2.1, 1.85, CFrame.new(0, -2.05, 0), DARK)
	for k = 0, 3 do
		cyl(m, "Rib", 0.12, 1.98, CFrame.new(0, -1.3 - k * 0.32, 0), Color3.fromRGB(46, 46, 52), Enum.Material.Metal)
	end
	cyl(m, "Rim", 0.3, 2.05, CFrame.new(0, -3.1, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	local gel = part(m, "GelFrame", Vector3.new(2.1, 0.12, 2.1), CFrame.new(0, -3.3, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	r.lens = cyl(m, "Lens", 0.14, 1.5, CFrame.new(0, -3.16, 0), r.color, Enum.Material.Neon)
	r.light = New("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 55, Range = 60, Brightness = 1.6, Color = r.color, Shadows = false, Parent = gel })
	-- a soft wide cone of light (a wash), so you can see what the PAR does in the haze
	if not r.preview then
		r.beam = beam(gel, Vector3.new(0, -0.1, 0), Vector3.new(0, -42, 0), 1.6, 18, r.color, 0.72)
	end
end

function B.moving(m, r)
	-- moving head spot: base with display and handles, U-yoke, round head with a big lens
	rigClamp(m, 0.5)
	part(m, "Base", Vector3.new(2.7, 0.9, 2.2), CFrame.new(0, -0.55, 0), DARK)
	cyl(m, "BaseRound", 0.9, 2.2, CFrame.new(0, -0.55, 0), DARK)
	part(m, "Display", Vector3.new(0.9, 0.4, 0.06), CFrame.new(0.6, -0.6, 1.12), Color3.fromRGB(80, 170, 255), Enum.Material.Neon)
	for _, x in ipairs({ -1.45, 1.45 }) do
		part(m, "Handle", Vector3.new(0.14, 0.5, 1.2), CFrame.new(x, -0.55, 0), Color3.fromRGB(40, 40, 46))
	end
	part(m, "YokeTop", Vector3.new(2.9, 0.35, 1.1), CFrame.new(0, -1.15, 0), Color3.fromRGB(40, 40, 46))
	part(m, "ArmL", Vector3.new(0.35, 2.1, 1.16), CFrame.new(-1.3, -2.15, 0), Color3.fromRGB(40, 40, 46))
	part(m, "ArmR", Vector3.new(0.35, 2.1, 1.16), CFrame.new(1.3, -2.15, 0), Color3.fromRGB(40, 40, 46))
	r.headLocal = CFrame.new(0, -2.7, 0)
	r.head = part(m, "Head", Vector3.new(0.3, 0.3, 0.3), r.headLocal, DARK)
	r.head.Transparency = 1
	headPart(r, cyl(m, "HeadBody", 2.4, 2.1, CFrame.new(), Color3.fromRGB(22, 22, 26)), CFrame.new(0, 0.1, 0))
	headPart(r, part(m, "HeadSide", Vector3.new(2.25, 1.6, 1.6), CFrame.new(), Color3.fromRGB(28, 28, 32)), CFrame.new(0, 0.3, 0))
	headPart(r, cyl(m, "LensRim", 0.3, 1.9, CFrame.new(), Color3.fromRGB(50, 50, 56), Enum.Material.Metal), CFrame.new(0, -1.25, 0))
	r.lensLocal = CFrame.new(0, -1.42, 0)
	r.lens = cyl(m, "Lens", 0.1, 1.5, r.headLocal * r.lensLocal, r.color, Enum.Material.Neon)
	r.beam = beam(r.head, Vector3.new(0, -1.4, 0), Vector3.new(0, -95, 0), 1.2, 16, r.color, 0.45)
	r.light = New("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 25, Range = 60, Brightness = 1.2, Color = r.color, Shadows = false, Parent = r.head })
end

------------------------------------------------------------------ band (musicians play the whole show, see LiveShow)
local function bandWedge(m, z)
	part(m, "Wedge", Vector3.new(2.6, 1.2, 1.6), CFrame.new(0, 0.6, z) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(20, 20, 24))
	part(m, "WedgeGrille", Vector3.new(2.3, 0.9, 0.06), CFrame.new(0, 0.66, z) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -0.82), Color3.fromRGB(46, 46, 52), Enum.Material.Fabric)
end
function B.band_drums(m, r)
	B.drums(m, r)
end
function B.band_keys(m, r)
	B.keys(m, r)
end
function B.band_guitar(m, r)
	-- combo amp behind the player, pedals and a monitor in front
	part(m, "Amp", Vector3.new(2.8, 2.4, 1.3), CFrame.new(1.4, 1.2, -2.6), Color3.fromRGB(26, 22, 20), Enum.Material.Fabric)
	part(m, "AmpPanel", Vector3.new(2.6, 0.4, 0.08), CFrame.new(1.4, 2.15, -1.92), Color3.fromRGB(200, 170, 110), Enum.Material.Metal)
	part(m, "Pedalboard", Vector3.new(2.0, 0.2, 0.8), CFrame.new(0, 0.1, 1.0), Color3.fromRGB(30, 30, 34))
	for k = 0, 3 do
		part(m, "Pedal", Vector3.new(0.4, 0.2, 0.55), CFrame.new(-0.7 + k * 0.46, 0.3, 1.0), ({ Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 200, 60), Color3.fromRGB(60, 160, 230), Color3.fromRGB(90, 200, 120) })[k + 1])
	end
	bandWedge(m, 2.4)
end
function B.band_bass(m, r)
	-- a tall bass cabinet with the amp head on top
	part(m, "BassCab", Vector3.new(2.8, 4.4, 1.7), CFrame.new(-1.4, 2.2, -2.8), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
	part(m, "BassHead", Vector3.new(2.8, 0.9, 1.5), CFrame.new(-1.4, 4.85, -2.8), Color3.fromRGB(34, 34, 38))
	part(m, "HeadPanel", Vector3.new(2.5, 0.3, 0.06), CFrame.new(-1.4, 4.9, -2.02), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	bandWedge(m, 2.4)
end
function B.band_backing(m, r)
	-- a small round riser and a monitor
	cyl(m, "BackingRiser", 0.4, 4.2, CFrame.new(0, 0.2, 0), Color3.fromRGB(30, 30, 36))
	cyl(m, "RiserRing", 0.14, 4.3, CFrame.new(0, 0.34, 0), r.color, Enum.Material.Neon)
	bandWedge(m, 2.8)
end

------------------------------------------------------------------ side mounts (on a vertical truss tower)
-- The item's origin is on the side of the tower (rec.x/z, see Stage3D.snapToTower), +Z points away from it.
-- A bracket clamps onto the tower; the fixture is the normal rig / floor version turned by `turn`.
local function sideMount(m, r, build, turn)
	build(m, r)
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "Pivot" and p.Name ~= "SafetyCable" then
			p.CFrame = turn * p.CFrame
		elseif p:IsA("BasePart") and p.Name == "SafetyCable" then
			p:Destroy()
		end
	end
	if r.headLocal then
		r.headLocal = turn * r.headLocal
	end
	-- the bracket: two clamps around the tower post and an arm out to the fixture
	part(m, "SideClamp", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, 0.6, 0.25), METAL, Enum.Material.Metal)
	part(m, "SideClamp", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, -0.6, 0.25), METAL, Enum.Material.Metal)
	part(m, "SideArm", Vector3.new(0.4, 0.4, 1.0), CFrame.new(0, 0, 0.75), DARK, Enum.Material.Metal)
end
function B.sidewash(m, r)
	-- a PAR can looking out from the tower, a little down
	sideMount(m, r, B.par, CFrame.new(0, 0.9, 1.1) * CFrame.Angles(math.rad(-75), 0, 0))
end
function B.sidebeam(m, r)
	-- a beam light lying on its side: the beam shoots out over the crowd and sweeps
	sideMount(m, r, B.beambar, CFrame.new(0, -1.1, 1.2) * CFrame.Angles(math.rad(80), 0, 0))
end
function B.sideblinder(m, r)
	sideMount(m, r, B.blinder, CFrame.new(0, 2.9, 1.6))
end
function B.sidestrobe(m, r)
	sideMount(m, r, B.strobe, CFrame.new(0, 1.6, 1.4))
end
function B.sidespeaker(m, r)
	-- a line array hanging from a bar on the side of the tower, curved at the bottom
	part(m, "SideClamp", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, 1.2, 0.25), METAL, Enum.Material.Metal)
	part(m, "SideClamp", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, -0.4, 0.25), METAL, Enum.Material.Metal)
	part(m, "SideArm", Vector3.new(0.4, 0.4, 2.6), CFrame.new(0, 1.2, 1.5), DARK, Enum.Material.Metal)
	part(m, "HangBar", Vector3.new(4.4, 0.4, 2.2), CFrame.new(0, 0.9, 2.8), DARK, Enum.Material.Metal)
	local y = 0.1
	for i = 0, 5 do
		local tilt = math.rad(i * i * 0.8)
		local cf = CFrame.new(0, y - i * 1.2, 2.8 + i * 0.05) * CFrame.Angles(-tilt, 0, 0)
		part(m, "Line", Vector3.new(4.2 + (i % 2) * 0.06, 1.12, 2.4 + (i % 2) * 0.04), cf, Color3.fromRGB(22, 22, 25))
		part(m, "Grille", Vector3.new(4.0, 0.88, 0.08), cf * CFrame.new(0, 0, 1.23), Color3.fromRGB(45, 45, 50), Enum.Material.Fabric)
	end
	part(m, "Logo", Vector3.new(1.0, 0.22, 0.06), CFrame.new(0, -6.25, 4.12), r.color, Enum.Material.Neon)
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
		part(m, "Line", Vector3.new(4.2 + (i % 2) * 0.06, 1.15, 2.6 + (i % 2) * 0.04), cf, Color3.fromRGB(22, 22, 25))
		part(m, "Grille", Vector3.new(4, 0.9, 0.08), cf * CFrame.new(0, 0, 1.32), Color3.fromRGB(45, 45, 50), Enum.Material.Fabric)
	end
	part(m, "Logo", Vector3.new(1.2, 0.25, 0.06), CFrame.new(0, 0.6, 1.62), r.color, Enum.Material.Neon)
end

-- drum shell with chrome hoops on both ends, lugs around it and a white head (axis = cf's up vector)
local LUG_N = 0 -- every lug a bit different
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
		local rr = d / 2 + 0.06 + (i % 2) * 0.03 + (math.abs(cf.Position.X * 7.3 + cf.Position.Z * 3.1) % 1) * 0.03
		-- every lug a little different (height on the shell, length): no two end faces in one plane
		LUG_N = LUG_N + 1
		local ly = (LUG_N % 7) * 0.017
		part(m, "Lug", Vector3.new(0.14, math.min(0.5, len * 0.45) - (i % 2) * 0.04, 0.14), cf * CFrame.new(math.cos(a) * rr, ly, math.sin(a) * rr) * CFrame.Angles(0, -a, 0), chrome, Enum.Material.Metal)
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
	for _, x in ipairs({ -0.82, 0.82 }) do
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
			local hh = h + (i % 3) * 0.04 -- neighbours overlap at the corners: different heights, no flicker
			part(m, "Rim", Vector3.new(len + 0.12, hh, 0.18 + (i % 2) * 0.04), CFrame.new((a[1] + b[1]) / 2, y0 + hh / 2, (a[2] + b[2]) / 2) * CFrame.Angles(0, -math.atan2(dz, dx), 0), black, Enum.Material.Glass)
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
	for _, x in ipairs({ -2.6, 2.6 }) do
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
	-- floor beam light: base with display, yoke, round head pointing up
	part(m, "Base", Vector3.new(2.6, 1.1, 2.2), CFrame.new(0, 0.55, 0), DARK)
	cyl(m, "BaseRound", 1.1, 2.2, CFrame.new(0, 0.55, 0), DARK)
	part(m, "Display", Vector3.new(0.8, 0.35, 0.06), CFrame.new(0.6, 0.6, 1.12), Color3.fromRGB(80, 170, 255), Enum.Material.Neon)
	part(m, "YokeBase", Vector3.new(2.5, 0.3, 1), CFrame.new(0, 1.25, 0), Color3.fromRGB(40, 40, 46))
	part(m, "ArmL", Vector3.new(0.3, 1.6, 1.06), CFrame.new(-1.15, 2, 0), Color3.fromRGB(40, 40, 46))
	part(m, "ArmR", Vector3.new(0.3, 1.6, 1.06), CFrame.new(1.15, 2, 0), Color3.fromRGB(40, 40, 46))
	r.headLocal = CFrame.new(0, 2.3, 0)
	r.head = part(m, "Head", Vector3.new(0.3, 0.3, 0.3), r.headLocal, Color3.fromRGB(20, 20, 24))
	r.head.Transparency = 1
	headPart(r, cyl(m, "HeadBody", 1.7, 1.75, CFrame.new(), Color3.fromRGB(20, 20, 24)), CFrame.new(0, 0, 0))
	headPart(r, cyl(m, "LensRim", 0.2, 1.6, CFrame.new(), Color3.fromRGB(50, 50, 56), Enum.Material.Metal), CFrame.new(0, 0.86, 0))
	headPart(r, cyl(m, "Lens", 0.08, 1.2, CFrame.new(), WHITE, Enum.Material.Neon), CFrame.new(0, 0.95, 0))
	r.beam = beam(r.head, Vector3.new(0, 0.9, 0), Vector3.new(0, 140, 0), 0.8, 7, r.color, 0.3)
end

function B.strobe(m, r)
	-- atomic-style strobe: long body with cooling fins and a grid over the flash tube
	rigClamp(m, 0.8)
	part(m, "Bracket", Vector3.new(3.8, 0.2, 0.5), CFrame.new(0, -0.65, 0), METAL, Enum.Material.Metal)
	part(m, "Body", Vector3.new(3.6, 1.4, 1.1), CFrame.new(0, -1.6, -0.1), DARK)
	for k = 0, 6 do
		part(m, "Fin", Vector3.new(0.12, 1.1, 0.4), CFrame.new(-1.5 + k * 0.5, -1.6, -0.8), Color3.fromRGB(46, 46, 52), Enum.Material.Metal)
	end
	r.flash = part(m, "Flash", Vector3.new(3.1, 0.9, 0.2), CFrame.new(0, -1.6, 0.5), Color3.fromRGB(60, 60, 66), Enum.Material.Neon)
	for k = 0, 5 do
		part(m, "Grid", Vector3.new(0.06, 0.95, 0.06), CFrame.new(-1.25 + k * 0.5, -1.6, 0.66), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	end
	part(m, "GridBar", Vector3.new(3.2, 0.06, 0.06), CFrame.new(0, -1.6, 0.7), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	r.light = New("PointLight", { Range = 40, Brightness = 0, Color = WHITE, Shadows = false, Parent = r.flash })
end

function B.blinder(m, r)
	-- 2x2 audience blinder: four round lamps in a frame
	rigClamp(m, 0.8)
	part(m, "Bracket", Vector3.new(4.6, 0.2, 0.5), CFrame.new(0, -0.65, 0), METAL, Enum.Material.Metal)
	part(m, "Frame", Vector3.new(4.4, 4.2, 1.1), CFrame.new(0, -2.9, -0.1), DARK)
	r.bulbs = {}
	for _, x in ipairs({ -1.05, 1.05 }) do
		for _, y in ipairs({ -1.85, -3.95 }) do
			cyl(m, "Reflector", 0.4, 1.95, CFrame.new(x, y, 0.5) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
			table.insert(r.bulbs, cyl(m, "Bulb", 0.12, 1.5, CFrame.new(x, y, 0.72) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(60, 50, 40), Enum.Material.Neon))
		end
	end
	r.light = New("PointLight", { Range = 50, Brightness = 0, Color = WARM, Shadows = false, Parent = r.bulbs[2] })
end

function B.followspot(m, r)
	-- follow spot on a tripod: long round body, lens hood, handles and an operator chair
	for _, a in ipairs({ 0.4, 2.5, 4.6 }) do
		tube(m, Vector3.new(0, 3, 0), Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8), 0.18, METAL)
	end
	cyl(m, "Stand", 3.4, 0.4, CFrame.new(0, 4.5, 0), METAL, Enum.Material.Metal)
	part(m, "Fork", Vector3.new(1.9, 0.3, 0.6), CFrame.new(0, 6.1, 0), METAL, Enum.Material.Metal)
	cyl(m, "BodyTube", 4.2, 1.5, CFrame.new(0, 6.7, 0.3) * CFrame.Angles(math.pi / 2, 0, 0), DARK)
	cyl(m, "Hood", 1, 1.9, CFrame.new(0, 6.7, -2.2) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	cyl(m, "FrontLens", 0.1, 1.5, CFrame.new(0, 6.7, -2.72) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(255, 240, 210), Enum.Material.Neon)
	cyl(m, "RearCap", 0.5, 1.7, CFrame.new(0, 6.7, 2.5) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(40, 40, 46), Enum.Material.Metal)
	for _, x in ipairs({ -0.9, 0.9 }) do
		part(m, "Handle", Vector3.new(0.16, 0.16, 1.2), CFrame.new(x, 6.4, 2.6), METAL, Enum.Material.Metal)
	end
	cyl(m, "Stool", 0.3, 1.4, CFrame.new(0, 3.2, 4.2), Color3.fromRGB(30, 30, 34), Enum.Material.Leather)
	tube(m, Vector3.new(0, 0, 4.2), Vector3.new(0, 3.1, 4.2), 0.2, METAL)
	r.head = part(m, "Body", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 6.7, -1.2), DARK)
	r.head.Transparency = 1
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
	-- mirror ball on a motor: facet rings make the surface sparkle
	part(m, "Motor", Vector3.new(1, 0.8, 1), CFrame.new(0, -0.4, 0), DARK)
	part(m, "String", Vector3.new(0.12, 1.2, 0.12), CFrame.new(0, -1.4, 0), METAL)
	r.ball = part(m, "Ball", Vector3.new(3.5, 3.5, 3.5), CFrame.new(0, -3.3, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Foil, Enum.PartType.Ball)
	r.ball.Reflectance = 0.6
	r.facets = {}
	for k = -2, 2 do
		local y = k * 0.62
		local d = math.sqrt(math.max(0.2, 3.56 * 3.56 - (y * 2) ^ 2))
		table.insert(r.facets, cyl(m, "FacetRing", 0.08, d, CFrame.new(0, -3.3 + y, 0), Color3.fromRGB(240, 240, 250), Enum.Material.Glass))
	end
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 25,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
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
		Ambient = Color3.fromRGB(105, 105, 120),
		LightColor = Color3.fromRGB(215, 215, 225),
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
-- screens without feet: standing right on the deck, hanging in the rig, a ribbon, curved, round, kinetic
function B.led_flat(m, r)
	local w, h = dims(r, r.def)
	screenFace(m, r, Vector3.new(w, h, 0.5), CFrame.new(0, h / 2, 0))
	part(m, "ScreenBack", Vector3.new(w + 0.2, h + 0.2, 0.25), CFrame.new(0, h / 2, -0.37), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
end
local function hangCables(m, w, top, span)
	for _, x in ipairs({ -span / 2, span / 2 }) do
		part(m, "Cable", Vector3.new(0.08, top, 0.08), CFrame.new(x, -top / 2, 0), Color3.fromRGB(170, 170, 176), Enum.Material.Metal)
		part(m, "Shackle", Vector3.new(0.4, 0.3, 0.4), CFrame.new(x, -0.15, 0), METAL, Enum.Material.Metal)
	end
end
-- hangs from the rig (its top edge 2 studs under the truss)
function B.led_hang(m, r)
	local w, h = dims(r, r.def)
	hangCables(m, w, 2, w * 0.7)
	part(m, "HangBar", Vector3.new(w + 0.4, 0.4, 0.6), CFrame.new(0, -2.2, 0), DARK, Enum.Material.Metal)
	screenFace(m, r, Vector3.new(w, h, 0.5), CFrame.new(0, -2.4 - h / 2, 0))
	part(m, "ScreenBack", Vector3.new(w + 0.2, h + 0.2, 0.25), CFrame.new(0, -2.4 - h / 2, -0.37), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
end
function B.led_flown(m, r)
	-- portrait side screen hanging from the rig, turned a little towards the middle of the hall
	hangCables(m, 10, 2, 7)
	part(m, "HangBar", Vector3.new(10.4, 0.4, 0.6), CFrame.new(0, -2.2, 0), DARK, Enum.Material.Metal)
	screenFace(m, r, Vector3.new(10, 17, 0.5), CFrame.new(0, -2.4 - 8.5, 0))
	part(m, "ScreenBack", Vector3.new(10.2, 17.2, 0.25), CFrame.new(0, -2.4 - 8.5, -0.37), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
end
function B.led_ribbon(m, r)
	-- a thin LED strip: along the front of a deck, around a balcony, as a header over the stage
	local w, h = dims(r, r.def)
	screenFace(m, r, Vector3.new(w, h, 0.3), CFrame.new(0, h / 2, 0))
end
function B.led_curve(m, r)
	-- a curved wall: segments on an arc (the middle bends back), every segment shows the same picture
	local w, h = dims(r, r.def)
	local n = math.clamp(math.floor(w / 8), 3, 9)
	local arc = math.rad(70)
	local rad = w / arc
	for i = 0, n - 1 do
		local a = -arc / 2 + (i + 0.5) * arc / n
		local segW = 2 * rad * math.sin(arc / n / 2) + 0.15
		-- the arc opens towards the fans (+Z): the middle is at the back, the sides come forward;
		-- every segment looks at the middle of the circle
		local zc = (-math.cos(a) + (1 + math.cos(arc / 2)) / 2) * rad
		local cf = CFrame.new(math.sin(a) * rad, h / 2, zc) * CFrame.Angles(0, -a, 0)
		screenFace(m, r, Vector3.new(segW, h, 0.5), cf)
	end
end
function B.led_round(m, r)
	-- a round screen in a glowing ring, hanging from the rig (the picture is cut round)
	local w = dims(r, r.def)
	hangCables(m, w, 2, w * 0.5)
	local cy = -2.4 - w / 2
	local f = screenFace(m, r, Vector3.new(w, w, 0.4), CFrame.new(0, cy, 0))
	New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f.frame })
	f.panel.Transparency = 1
	r.neon = {}
	local n = 28
	for i = 0, n - 1 do
		local a0 = i / n * math.pi * 2
		local len = math.pi * (w + 0.6) / n + 0.1
		table.insert(r.neon, part(m, "RingLED", Vector3.new(len, 0.5, 0.5), CFrame.new(math.cos(a0) * (w / 2 + 0.3), cy + math.sin(a0) * (w / 2 + 0.3), 0) * CFrame.Angles(0, 0, a0 + math.pi / 2), r.color, Enum.Material.Neon))
	end
end
function B.led_kinetic(m, r)
	-- a row of hanging screen panels on winches: they move up and down in waves during the show
	local w = dims(r, r.def)
	local n = math.clamp(math.floor(w / 6), 3, 12)
	local pw = w / n - 0.6
	r.kinetic = {}
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		part(m, "Winch", Vector3.new(1, 0.8, 1), CFrame.new(x, -0.4, 0), DARK, Enum.Material.Metal)
		local cable = part(m, "Cable", Vector3.new(0.08, 6, 0.08), CFrame.new(x, -3.4, 0), Color3.fromRGB(170, 170, 176), Enum.Material.Metal)
		local f = screenFace(m, r, Vector3.new(pw, 6, 0.4), CFrame.new(x, -10, 0))
		table.insert(r.kinetic, { panel = f.panel, cable = cable, x = x, i = i })
	end
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
	-- steel cables from the cube up to the roof rig ("Connect to roof", on unless switched off); they get
	-- longer when the cube hangs lower (Lift up < 0) and when it lowers in the ballad
	local rec = r.rec or {}
	r.cables = {}
	if rec.roof ~= false then
		local top = -(rec.yo or 0) -- the rig, seen from the cube's own height
		for _, c in ipairs({ { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } }) do
			local len = math.max(0.5, top - (cy + 4.5))
			local cable = part(m, "Cable", Vector3.new(0.18, len, 0.18), CFrame.new(c[1], cy + 4.5 + len / 2, c[2]), METAL, Enum.Material.Metal)
			table.insert(r.cables, { cable, c[1], c[2], top })
		end
	end
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
	-- a stadium screen tower: heavy base, a box-truss mast with lights on brackets, a 4-sided LED head
	-- with lit edges on top, a PA hang under it and a red aviation light
	part(m, "Base", Vector3.new(8, 0.8, 8), CFrame.new(0, 0.4, 0), DARK, Enum.Material.DiamondPlate)
	for _, o in ipairs({ { 3, 3 }, { -3, 3 }, { 3, -3 }, { -3, -3 } }) do
		part(m, "Ballast", Vector3.new(1.8, 1.4, 1.8), CFrame.new(o[1], 1.5, o[2]), Color3.fromRGB(64, 66, 72), Enum.Material.Concrete)
	end
	lattice(m, CFrame.new(0, 21.4, 0) * CFrame.Angles(0, 0, math.pi / 2), 41.2, 1.8)
	r.neon = {}
	-- lights on brackets at three levels, one on every side
	for _, y in ipairs({ 12, 22, 32 }) do
		for i = 0, 3 do
			local c = CFrame.new(0, y, 0) * CFrame.Angles(0, i * math.pi / 2, 0)
			part(m, "LightArm", Vector3.new(0.3, 0.3, 1.6), c * CFrame.new(0, 0, 2.3), METAL, Enum.Material.Metal)
			part(m, "LightBody", Vector3.new(1.1, 1.1, 1.2), c * CFrame.new(0, 0, 3.4), DARK, Enum.Material.Metal)
			table.insert(r.neon, part(m, "LightLens", Vector3.new(0.85, 0.85, 0.12), c * CFrame.new(0, 0, 4.05), r.color, Enum.Material.Neon))
		end
	end
	-- the LED head: a frame with four screens and glowing edges
	part(m, "HeadFrame", Vector3.new(10.2, 11, 10.2), CFrame.new(0, 47.5, 0), DARK, Enum.Material.Metal)
	for i = 0, 3 do
		screenFace(m, r, Vector3.new(10, 10, 0.3), CFrame.new(0, 47.5, 0) * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0, 5.25))
	end
	for _, y in ipairs({ 42, 53 }) do
		for i = 0, 3 do
			local c = CFrame.new(0, y, 0) * CFrame.Angles(0, i * math.pi / 2, 0)
			table.insert(r.neon, part(m, "EdgeLED", Vector3.new(10.8, 0.45, 0.45), c * CFrame.new(0, 0, 5.4), r.color, Enum.Material.Neon))
		end
	end
	part(m, "Cap", Vector3.new(8, 0.8, 8), CFrame.new(0, 53.6, 0), DARK, Enum.Material.Metal)
	part(m, "Beacon", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 54.4, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball)
	-- PA line array under the head, facing the crowd
	for i = 0, 5 do
		part(m, "PA", Vector3.new(3.6, 1.2, 2.2), CFrame.new(0, 40.6 - i * 1.25, 3) * CFrame.Angles(-math.rad(i * 2.5), 0, 0), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
	end
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
	r.topRing = cyl(m, "PlatformLED", 0.25, 10.4, CFrame.new(0, 1.42, 0), r.color, Enum.Material.Neon)
	r.under = cyl(m, "UnderLight", 0.1, 6, CFrame.new(0, 0.5, 0), WHITE, Enum.Material.Neon)
	r.rails = {}
	for i = 0, 7 do
		local a = i * math.pi / 4
		r.rails[i + 1] = part(m, "Rail", Vector3.new(0.18, 2.6, 0.18), CFrame.new(math.cos(a) * 4.8, 2.9, math.sin(a) * 4.8), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
	end
	r.towerT = 0
end

-- stadium superstructure: two scaffold towers with PA hangs, a roof grid and mesh-covered wings
-- the giant steel structure of a stadium tour (like the scaffold "wings" and roof of real stadium shows):
-- two scaffold towers with a grid of tubes, braces and black scrim, PA hangs, a lattice roof with lights,
-- a header with an LED strip and covered wings. It always stands on the ground. The roof and the wings are
-- see-through while building (r.roofParts) so you can build under it; side lights clamp onto its front
-- columns (r.mounts, like on a Truss Tower).
function B.stadiumroof(m, r)
	local w, h = dims(r, r.def)
	local hw = w / 2
	local depth = 34
	local STEEL = Color3.fromRGB(70, 72, 80)
	r.roofParts = {}
	r.mounts = {}
	local function roof(p)
		table.insert(r.roofParts, p)
		return p
	end
	local function scaffoldTower(cx)
		-- standards (vertical tubes) on a 6-stud grid, ledgers every 8 studs, diagonal braces
		local tw = 14
		local xs, zs = {}, {}
		for x = -tw / 2, tw / 2 + 0.01, tw / 2 do
			table.insert(xs, x)
		end
		for z = -depth / 2, depth / 2 + 0.01, depth / 4 do
			table.insert(zs, z)
		end
		for _, x in ipairs(xs) do
			for _, z in ipairs(zs) do
				local leg = part(m, "Leg", Vector3.new(1, h, 1), CFrame.new(cx + x, h / 2, z), STEEL, Enum.Material.Metal)
				leg.CanQuery = true
			end
		end
		for y = 8, h - 2, 8 do
			for _, x in ipairs(xs) do
				roof(part(m, "Ledger", Vector3.new(0.5, 0.5, depth), CFrame.new(cx + x, y, 0), STEEL, Enum.Material.Metal))
			end
			for _, z in ipairs(zs) do
				roof(part(m, "Ledger", Vector3.new(tw, 0.5, 0.5), CFrame.new(cx, y, z), STEEL, Enum.Material.Metal))
			end
			-- a walkway deck every second level
			if y % 16 == 0 then
				roof(part(m, "Walkway", Vector3.new(tw, 0.3, depth), CFrame.new(cx, y + 0.4, 0), Color3.fromRGB(40, 40, 46), Enum.Material.DiamondPlate))
			end
		end
		for _, x in ipairs({ -tw / 2, tw / 2 }) do
			for y = 0, h - 10, 8 do
				local len = math.sqrt(8 * 8 + (depth / 4) ^ 2)
				for k = 0, 3 do
					local z0 = -depth / 2 + k * depth / 4
					local flip = (k % 2 == 0) and 1 or -1
					roof(part(m, "Brace", Vector3.new(0.35, 0.35, len), CFrame.new(cx + x, y + 4, z0 + depth / 8) * CFrame.Angles(flip * math.atan2(8, depth / 4), 0, 0), STEEL, Enum.Material.Metal))
				end
			end
		end
		-- black scrim on the outer side and the back
		local side = (cx > 0) and 1 or -1
		local scrim = roof(part(m, "Scrim", Vector3.new(0.3, h * 0.8, depth), CFrame.new(cx + side * (tw / 2 + 0.4), h * 0.45, 0), Color3.fromRGB(16, 16, 20), Enum.Material.Fabric))
		scrim.Transparency = 0.08
		local back = roof(part(m, "Scrim", Vector3.new(tw, h * 0.8, 0.3), CFrame.new(cx, h * 0.45, -depth / 2 - 0.4), Color3.fromRGB(16, 16, 20), Enum.Material.Fabric))
		back.Transparency = 0.08
		-- side lights clamp onto the front columns of the tower (both sides of it)
		for _, x in ipairs({ -tw / 2, tw / 2 }) do
			table.insert(r.mounts, { cf = CFrame.new(cx + x, 0, depth / 2), half = 0.55 })
		end
		return tw
	end
	local towerW = 14
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * (hw - towerW / 2)
		scaffoldTower(cx)
		-- wings: mesh scrim on scaffolding next to the stage
		local wing = roof(part(m, "WingScrim", Vector3.new(26, h * 0.7, 0.4), CFrame.new(sx * (hw + 14), h * 0.35, -depth / 2 + 4), Color3.fromRGB(20, 20, 26), Enum.Material.Fabric))
		wing.Transparency = 0.15
		for k = 0, 2 do
			roof(part(m, "WingPole", Vector3.new(0.8, h * 0.7, 0.8), CFrame.new(sx * (hw + 2 + k * 12), h * 0.35, -depth / 2 + 4.8), METAL, Enum.Material.Metal))
		end
		roof(part(m, "WingLED", Vector3.new(26, 0.6, 0.3), CFrame.new(sx * (hw + 14), h * 0.7 + 0.3, -depth / 2 + 4.3), r.color, Enum.Material.Neon))
		-- PA line array (curved J) and subs hanging under the front of the roof: a bumper frame on two chains
		-- right under the roof girder, the boxes below it
		for _, px in ipairs({ sx * (hw - towerW - 4), sx * (hw - towerW - 10) }) do
			roof(part(m, "Bumper", Vector3.new(4.6, 0.5, 2.8), CFrame.new(px, h - 2.2, depth / 2 - 0.5), DARK, Enum.Material.Metal))
			for _, cx in ipairs({ -1.6, 1.6 }) do
				roof(part(m, "Chain", Vector3.new(0.18, 2, 0.18), CFrame.new(px + cx, h - 1, depth / 2 - 0.5), Color3.fromRGB(150, 150, 158), Enum.Material.Metal))
			end
		end
		for i = 0, 11 do
			local ang = math.rad(math.max(0, i - 5) * 3)
			roof(part(m, "LineArray", Vector3.new(4.2, 1.4, 2.6), CFrame.new(sx * (hw - towerW - 4), h - 3.2 - i * 1.45, depth / 2 - 0.5 + math.max(0, i - 5) * 0.25) * CFrame.Angles(-ang, 0, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Fabric))
		end
		for i = 0, 7 do
			roof(part(m, "SubArray", Vector3.new(3.6, 1.6, 2.4), CFrame.new(sx * (hw - towerW - 10), h - 3.3 - i * 1.65, depth / 2 - 0.5), Color3.fromRGB(14, 14, 18), Enum.Material.Fabric))
		end
	end
	-- roof: three lattice girders across, cross trusses, a canopy skin
	for _, z in ipairs({ -depth / 2, 0, depth / 2 }) do
		local L = w + 2
		roof(part(m, "GirderTop", Vector3.new(L, 0.5, 0.5), CFrame.new(0, h + 4, z), STEEL, Enum.Material.Metal))
		roof(part(m, "GirderBottom", Vector3.new(L, 0.5, 0.5), CFrame.new(0, h, z), STEEL, Enum.Material.Metal))
		local n = math.max(2, math.floor(L / 5))
		for i = 0, n - 1 do
			local x0 = -L / 2 + i * L / n
			local flip = (i % 2 == 0) and 1 or -1
			local dx = L / n
			roof(part(m, "GirderWeb", Vector3.new(0.3, math.sqrt(16 + dx * dx), 0.3), CFrame.new(x0 + dx / 2, h + 2, z) * CFrame.Angles(0, 0, flip * math.atan2(dx, 4)), STEEL, Enum.Material.Metal))
		end
	end
	for x = -hw + towerW, hw - towerW + 0.01, 10 do
		roof(part(m, "RoofTruss", Vector3.new(1.2, 1.2, depth), CFrame.new(x, h + 0.6, 0), STEEL, Enum.Material.Metal))
	end
	local canopy = roof(part(m, "Canopy", Vector3.new(w + 4, 0.4, depth + 4), CFrame.new(0, h + 4.6, 0), Color3.fromRGB(26, 26, 32), Enum.Material.Fabric))
	canopy.CastShadow = true
	-- header at the front: a black fascia with an LED strip, and rows of lights under the roof
	roof(part(m, "Header", Vector3.new(w + 2, 5, 0.6), CFrame.new(0, h + 2, depth / 2 + 1.2), Color3.fromRGB(14, 14, 18), Enum.Material.SmoothPlastic))
	r.roofLED = roof(part(m, "RoofLED", Vector3.new(w, 1.2, 0.3), CFrame.new(0, h + 2, depth / 2 + 1.65), r.color, Enum.Material.Neon))
	r.neon = {}
	for _, z in ipairs({ depth / 2 - 4, 4, -8 }) do
		for x = -hw + towerW + 4, hw - towerW - 3.99, 8 do
			roof(part(m, "RoofSpotBody", Vector3.new(1.4, 1.6, 1.4), CFrame.new(x, h - 1.1, z), DARK, Enum.Material.Metal))
			local lens = roof(part(m, "RoofSpotLens", Vector3.new(1, 0.15, 1), CFrame.new(x, h - 1.95, z), r.color, Enum.Material.Neon))
			table.insert(r.neon, lens)
		end
	end
end

-- delay tower in the crowd: scaffold with a speaker cluster and a follow-spot platform
function B.delaytower(m, r)
	local h = 34
	for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		part(m, "Leg", Vector3.new(0.7, h, 0.7), CFrame.new(c[1], h / 2, c[2]), METAL, Enum.Material.Metal)
	end
	for y = 4, h - 4, 7 do
		part(m, "Ring", Vector3.new(7.4, 0.5, 0.5), CFrame.new(0, y, -3.5), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(7.4, 0.5, 0.5), CFrame.new(0, y, 3.5), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(0.5, 0.5, 6.4), CFrame.new(-3.5, y + 0.6, 0), METAL, Enum.Material.Metal)
		part(m, "Ring", Vector3.new(0.5, 0.5, 6.4), CFrame.new(3.5, y + 0.6, 0), METAL, Enum.Material.Metal)
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


-- flame projector: black box with a hazard stripe and a nozzle; a column of flame with a rolling top and black smoke
function B.pyro(m, r)
	part(m, "Box", Vector3.new(2.4, 1.3, 2.4), CFrame.new(0, 0.65, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
	part(m, "Stripe", Vector3.new(2.56, 0.25, 2.56), CFrame.new(0, 1.05, 0), Color3.fromRGB(240, 190, 20), Enum.Material.SmoothPlastic)
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

-- flame bar: a long low box with five flame jets that fire one after the other (a chase), then all at once
function B.flamebar(m, r)
	local w = dims(r, r.def)
	part(m, "Bar", Vector3.new(w, 1, 1.8), CFrame.new(0, 0.5, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
	part(m, "BarStripe", Vector3.new(w + 0.1, 0.2, 1.9), CFrame.new(0, 0.82, 0), Color3.fromRGB(240, 190, 20))
	r.jets = {}
	local n = math.clamp(math.floor(w / 3), 2, 10)
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		cyl(m, "Jet", 0.5, 0.5, CFrame.new(x, 1.25, 0), METAL, Enum.Material.Metal)
		local noz = part(m, "Nozzle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, 1.6, 0), DARK)
		noz.Transparency = 1
		local em = New("ParticleEmitter", {
			Enabled = false,
			Rate = 0,
			Texture = TEX_FIRE,
			Lifetime = NumberRange.new(0.4, 0.6),
			Speed = NumberRange.new(28, 36),
			SpreadAngle = Vector2.new(4, 4),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 3.2), NumberSequenceKeypoint.new(1, 5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), Color3.fromRGB(230, 60, 0)),
			LightEmission = 1,
			Drag = 2,
			Parent = noz,
		})
		table.insert(r.jets, em)
	end
	r.light = New("PointLight", { Range = 50, Brightness = 0, Color = Color3.fromRGB(255, 150, 50), Shadows = false, Parent = m:FindFirstChild("Bar") })
end

-- spark rain: hangs in the rig, a curtain of sparks falls down from it
function B.sparkrain(m, r)
	local w = dims(r, r.def)
	rigClamp(m, 0.8)
	part(m, "RainBar", Vector3.new(w, 0.6, 0.7), CFrame.new(0, -0.9, 0), DARK, Enum.Material.Metal)
	r.emitters = {}
	local n = math.clamp(math.floor(w / 4), 2, 12)
	for i = 0, n - 1 do
		local noz = part(m, "Nozzle", Vector3.new(0.4, 0.2, 0.4), CFrame.new(-w / 2 + (i + 0.5) * w / n, -1.3, 0), METAL, Enum.Material.Metal)
		table.insert(r.emitters, New("ParticleEmitter", {
			Enabled = false,
			Rate = 160,
			Texture = TEX_SPARK,
			Lifetime = NumberRange.new(1.4, 2),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Bottom,
			Size = NumberSequence.new(0.28, 0.05),
			Squash = NumberSequence.new(1.3),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Color = ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(255, 160, 40)),
			LightEmission = 1,
			Acceleration = Vector3.new(0, -22, 0),
			Parent = noz,
		}))
	end
end

-- light halo: a big ring of lights in the rig, turning and pulsing with the beat
function B.halo(m, r)
	local w = dims(r, r.def)
	local rad = w / 2
	rigClamp(m, 0.8)
	r.ring = {}
	local n = math.clamp(math.floor(rad * 1.2), 10, 36)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local cf = CFrame.new(math.cos(a) * rad, -2, math.sin(a) * rad) * CFrame.Angles(0, -a, 0)
		part(m, "HaloSeg", Vector3.new(0.6, 0.5, 2 * math.pi * rad / n * 0.92), cf, Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		table.insert(r.ring, { part(m, "HaloLamp", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, -0.45, 0), WHITE, Enum.Material.Neon, Enum.PartType.Ball), i })
	end
	for i = 0, 3 do
		local a = i * math.pi / 2
		tube(m, Vector3.new(0, 0, 0), Vector3.new(math.cos(a) * rad, -2, math.sin(a) * rad), 0.12, METAL)
	end
end

-- cold spark machine: low black box with a grille; a fountain of thin sparks that fall back down
function B.sparks(m, r)
	-- cold spark machine: a black box on little feet, carry handles, a round outlet with a glowing hot core
	for _, c in ipairs({ { -0.8, -0.8 }, { 0.8, -0.8 }, { -0.8, 0.8 }, { 0.8, 0.8 } }) do
		part(m, "Foot", Vector3.new(0.3, 0.15, 0.3), CFrame.new(c[1], 0.075, c[2]), Color3.fromRGB(60, 60, 66))
	end
	part(m, "Box", Vector3.new(2.2, 1.1, 2.2), CFrame.new(0, 0.7, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Metal)
	for _, x in ipairs({ -1.16, 1.16 }) do
		part(m, "Handle", Vector3.new(0.1, 0.18, 1), CFrame.new(x, 1.05, 0), Color3.fromRGB(150, 150, 158), Enum.Material.Metal)
	end
	part(m, "Grille", Vector3.new(1.8, 0.06, 1.8), CFrame.new(0, 1.27, 0), Color3.fromRGB(60, 60, 66), Enum.Material.DiamondPlate)
	cyl(m, "Outlet", 0.25, 0.8, CFrame.new(0, 1.42, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal)
	cyl(m, "HotCore", 0.06, 0.45, CFrame.new(0, 1.56, 0), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
	part(m, "Status", Vector3.new(0.3, 0.12, 0.05), CFrame.new(0.6, 0.9, -1.11), Color3.fromRGB(40, 255, 90), Enum.Material.Neon)
	part(m, "Label", Vector3.new(1, 0.25, 0.04), CFrame.new(-0.3, 0.9, -1.11), Color3.fromRGB(250, 200, 40))
	r.nozzle = part(m, "Nozzle", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 1.5, 0), DARK)
	r.nozzle.Transparency = 1
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

-- confetti cannon: a red barrel tilted to the front on a tripod with a CO2 bottle; paper confetti in the muzzle
function B.confetti(m, r)
	local tilt = CFrame.Angles(math.rad(-18), 0, 0)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		part(m, "Leg", Vector3.new(0.18, 2.4, 0.18), CFrame.new(math.cos(a) * 0.8, 1.1, math.sin(a) * 0.8) * CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), DARK, Enum.Material.Metal)
	end
	part(m, "Mount", Vector3.new(0.8, 0.5, 0.8), CFrame.new(0, 2.3, 0), DARK, Enum.Material.Metal)
	local base = CFrame.new(0, 3.6, 0.2) * tilt
	cyl(m, "Barrel", 3.6, 1.1, base, Color3.fromRGB(200, 30, 40), Enum.Material.SmoothPlastic)
	cyl(m, "Stripe", 0.35, 1.14, base * CFrame.new(0, 0.9, 0), Color3.fromRGB(250, 210, 40))
	cyl(m, "Muzzle", 0.3, 1.25, base * CFrame.new(0, 1.85, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	-- coloured paper bits peeking out of the muzzle
	local cols = { Color3.fromRGB(255, 64, 129), Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 220, 60), Color3.fromRGB(140, 255, 120) }
	for k = 1, 8 do
		local a = k * 2.4
		part(m, "Paper", Vector3.new(0.3, 0.05, 0.22), base * CFrame.new(math.cos(a) * 0.32, 1.95, math.sin(a) * 0.32) * CFrame.Angles(a, a * 2, 0), cols[k % 4 + 1])
	end
	cyl(m, "Bottle", 2.4, 0.5, CFrame.new(0.9, 1.2, -0.6), Color3.fromRGB(140, 150, 160), Enum.Material.Metal)
	part(m, "Hose", Vector3.new(0.12, 0.12, 1.6), CFrame.new(0.5, 2.5, -0.2) * CFrame.Angles(0.6, 0.8, 0), Color3.fromRGB(20, 20, 22))
	r.nozzle = cyl(m, "Tube", 0.2, 0.9, base * CFrame.new(0, 2.0, 0), Color3.fromRGB(30, 30, 34))
	r.nozzle.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(60, 85),
		SpreadAngle = Vector2.new(22, 22),
		Size = NumberSequence.new(0.6, 0.45),
		Squash = NumberSequence.new(-0.4),
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
		EmissionDirection = Enum.NormalId.Right, -- the tube is a rotated cylinder: its +X points along the barrel
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
	-- laser projector: housing with vents and a glowing aperture
	rigClamp(m, 0.8)
	part(m, "Bracket", Vector3.new(2.6, 0.2, 0.5), CFrame.new(0, -0.65, 0), METAL, Enum.Material.Metal)
	r.headLocal = CFrame.new(0, -1.6, 0)
	r.head = part(m, "Head", Vector3.new(0.3, 0.3, 0.3), r.headLocal, DARK)
	r.head.Transparency = 1
	headPart(r, part(m, "Housing", Vector3.new(2.4, 1.3, 2.4), CFrame.new(), DARK), CFrame.new())
	for k = 0, 4 do
		headPart(r, part(m, "Vent", Vector3.new(0.1, 0.9, 0.22), CFrame.new(), Color3.fromRGB(46, 46, 52), Enum.Material.Metal), CFrame.new(-1.25, 0, -0.8 + k * 0.4))
	end
	headPart(r, part(m, "Aperture", Vector3.new(1.4, 0.4, 0.1), CFrame.new(), Color3.fromRGB(60, 255, 90), Enum.Material.Neon), CFrame.new(0, -0.3, 1.22))
	headPart(r, part(m, "Warning", Vector3.new(0.6, 0.6, 0.05), CFrame.new(), Color3.fromRGB(255, 210, 30)), CFrame.new(0.7, 0.2, 1.22) * CFrame.Angles(0, 0, math.pi / 4))
	r.beams = {}
	for i = -3, 3 do
		local ang = math.rad(i * 9)
		local dir = Vector3.new(math.sin(ang), -0.35, math.cos(ang)).Unit * 160
		local b = beam(r.head, Vector3.new(0, -0.3, 1.2), dir, 0.15, 0.4, Color3.fromRGB(60, 255, 90), 0, true)
		b.Enabled = false
		table.insert(r.beams, b)
	end
end

function B.haze(m, r)
	-- hazer: a box with a fan grille at the front, a display and a fluid tank on the side
	part(m, "Box", Vector3.new(2.5, 1.5, 3), CFrame.new(0, 0.75, 0), DARK)
	cyl(m, "FanGrille", 0.08, 1.2, CFrame.new(0, 0.8, 1.52) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(70, 70, 76), Enum.Material.DiamondPlate)
	part(m, "Display", Vector3.new(0.7, 0.3, 0.05), CFrame.new(0.7, 1.2, 1.51), Color3.fromRGB(60, 160, 255), Enum.Material.Neon)
	part(m, "Tank", Vector3.new(0.6, 1, 1.4), CFrame.new(-1.55, 0.6, -0.4), Color3.fromRGB(220, 230, 240), Enum.Material.Glass).Transparency = 0.3
	part(m, "Handle", Vector3.new(1.6, 0.12, 0.12), CFrame.new(0, 1.62, -0.6), Color3.fromRGB(150, 150, 158), Enum.Material.Metal)
	r.nozzle = part(m, "Nozzle", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.6, 1.2), DARK)
	r.smoke = New("Smoke", { Color = Color3.fromRGB(180, 180, 200), Opacity = 0.08, RiseVelocity = 1.5, Size = 18, Enabled = false, Parent = r.nozzle })
end

-- rain curtain: a pipe in the rig with nozzles; in its songs (or automatically in the ballad) rain pours down
-- in a long sheet onto the stage, glittering in the light, with a little mist where it lands
function B.raincurtain(m, r)
	local w = dims(r, r.def)
	part(m, "Pipe", Vector3.new(w, 0.5, 0.5), CFrame.new(0, 0, 0), METAL, Enum.Material.Metal)
	part(m, "Hanger", Vector3.new(0.2, 1.6, 0.2), CFrame.new(-w / 2 + 1, 0.8, 0), METAL, Enum.Material.Metal)
	part(m, "Hanger", Vector3.new(0.2, 1.6, 0.2), CFrame.new(w / 2 - 1, 0.8, 0), METAL, Enum.Material.Metal)
	local n = math.max(2, math.floor(w / 1.5))
	for i = 0, n - 1 do
		part(m, "Nozzle", Vector3.new(0.22, 0.3, 0.22), CFrame.new(-w / 2 + (i + 0.5) * w / n, -0.35, 0), DARK, Enum.Material.Metal)
	end
	local fall = math.clamp((Builder.rigTop or 36) - 6, 8, 90)
	r.rainSrc = part(m, "RainSource", Vector3.new(w, 0.1, 0.6), CFrame.new(0, -0.55, 0), DARK)
	r.rainSrc.Transparency = 1
	r.rain = New("ParticleEmitter", {
		Enabled = false,
		Rate = math.floor(36 * w),
		EmissionDirection = Enum.NormalId.Bottom,
		Lifetime = NumberRange.new(fall / 62, fall / 54),
		Speed = NumberRange.new(54, 62),
		SpreadAngle = Vector2.new(0, 2),
		Size = NumberSequence.new(0.09),
		Squash = NumberSequence.new(2.6),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.85, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(210, 230, 255)),
		LightEmission = 0.55,
		LightInfluence = 0.6,
		Parent = r.rainSrc,
	})
	r.mistSrc = part(m, "MistSource", Vector3.new(w, 0.1, 1.2), CFrame.new(0, -fall + 0.6, 0), DARK)
	r.mistSrc.Transparency = 1
	r.mist = New("ParticleEmitter", {
		Enabled = false,
		Rate = math.floor(2 * w),
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new(2, 5),
		Transparency = NumberSequence.new(0.8, 1),
		Color = ColorSequence.new(Color3.fromRGB(220, 230, 245)),
		Parent = r.mistSrc,
	})
end
------------------------------------------------------------------ special stage elements the artist rides / uses
-- (set to a song like an instrument; LiveShow puts the artist where refs.ride says while they are active)
local function smooth(x, a, b)
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
Builder.smooth = smooth

-- flying harness: a winch on a track in the rig; in its song the artist is lifted up, flies out over the
-- front of the stage and back, and comes down again
------------------------------------------------------------------ set pieces after real tours
-- gothic opera house front (three levels of boxes with arches, gold railings, red curtains)
function B.operahouse(m, r)
	local w = dims(r, r.def)
	local H = 36
	local wall = Color3.fromRGB(60, 22, 26)
	local gold = Color3.fromRGB(200, 160, 80)
	part(m, "OperaBack", Vector3.new(w, H, 1), CFrame.new(0, H / 2, -2), wall, Enum.Material.Fabric)
	local n = math.max(3, math.floor(w / 8))
	for lvl = 0, 2 do
		local y = 4 + lvl * 10
		part(m, "BoxFloor", Vector3.new(w, 0.8, 3.6), CFrame.new(0, y, -0.2), Color3.fromRGB(40, 16, 18), Enum.Material.Wood)
		part(m, "BoxFront", Vector3.new(w, 2.6, 0.4), CFrame.new(0, y + 1.6, 1.5), Color3.fromRGB(80, 30, 34), Enum.Material.Fabric)
		part(m, "BoxRail", Vector3.new(w, 0.3, 0.5), CFrame.new(0, y + 3, 1.5), gold, Enum.Material.Metal)
		for i = 0, n - 1 do
			local x = -w / 2 + (i + 0.5) * w / n
			-- an arch over every box: two posts and a rounded top, a red curtain inside
			part(m, "ArchPost", Vector3.new(0.6, 7, 0.6), CFrame.new(x - w / n / 2 + 0.4, y + 3.5, -1.2), gold, Enum.Material.Metal)
			part(m, "Curtain", Vector3.new(w / n - 1.6, 6, 0.2), CFrame.new(x, y + 3.6, -1.45), Color3.fromRGB(150, 18, 30), Enum.Material.Fabric)
			local arch = part(m, "Arch", Vector3.new(0.5, w / n - 0.8, w / n - 0.8), CFrame.new(x, y + 7, -1.2) * CFrame.Angles(0, math.pi / 2, 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
			arch.Transparency = 0
			part(m, "BoxLamp", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, y + 5.5, -1), Color3.fromRGB(255, 214, 150), Enum.Material.Neon, Enum.PartType.Ball)
		end
	end
	part(m, "Cornice", Vector3.new(w + 2, 1.6, 4), CFrame.new(0, H + 0.4, -0.6), gold, Enum.Material.Metal)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		part(m, "Column", Vector3.new(2, H, 2), CFrame.new(x, H / 2, 0.4), Color3.fromRGB(90, 40, 40), Enum.Material.Marble)
	end
	part(m, "Pediment", Vector3.new(w * 0.4, 5, 1.2), CFrame.new(0, H + 3.6, -1), gold, Enum.Material.Metal)
end
-- a two-storey house front with a balcony and warm windows (a home on stage)
function B.housefront(m, r)
	local wall = Color3.fromRGB(250, 214, 220)
	local trim = Color3.fromRGB(255, 255, 255)
	part(m, "HouseWall", Vector3.new(30, 22, 1), CFrame.new(0, 11, -1), wall, Enum.Material.SmoothPlastic)
	-- roof
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Roof", Vector3.new(18, 1, 6), CFrame.new(sx * 7.5, 26, -1.5) * CFrame.Angles(0, 0, -sx * 0.55), Color3.fromRGB(190, 90, 110), Enum.Material.Slate)
	end
	part(m, "Gable", Vector3.new(16, 6, 0.8), CFrame.new(0, 24, -1.1), wall)
	-- door with steps
	part(m, "Door", Vector3.new(4, 7.5, 0.4), CFrame.new(0, 3.75, -0.4), Color3.fromRGB(120, 60, 90), Enum.Material.Wood)
	part(m, "DoorFrame", Vector3.new(5, 8.5, 0.3), CFrame.new(0, 4.25, -0.55), trim)
	part(m, "Step", Vector3.new(6, 0.6, 2), CFrame.new(0, 0.3, 0.6), trim)
	-- windows (warm light)
	for _, w2 in ipairs({ { -9, 5 }, { 9, 5 }, { -9, 16 }, { 9, 16 } }) do
		part(m, "WindowFrame", Vector3.new(6, 5, 0.3), CFrame.new(w2[1], w2[2], -0.42), trim)
		part(m, "WindowLight", Vector3.new(5, 4, 0.1), CFrame.new(w2[1], w2[2], -0.25), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
		part(m, "WindowCross", Vector3.new(0.3, 4, 0.12), CFrame.new(w2[1], w2[2], -0.15), trim)
	end
	-- the balcony in the middle of the first floor
	part(m, "BalconyDoor", Vector3.new(5, 7, 0.2), CFrame.new(0, 15.5, -0.4), Color3.fromRGB(255, 220, 170), Enum.Material.Neon)
	part(m, "Balcony", Vector3.new(10, 0.6, 3.4), CFrame.new(0, 12, 0.9), trim)
	part(m, "BalconyRail", Vector3.new(10, 0.3, 0.3), CFrame.new(0, 14.6, 2.5), trim)
	for k = -4, 4 do
		part(m, "Baluster", Vector3.new(0.2, 2.6, 0.2), CFrame.new(k * 1.1, 13.4, 2.5), trim)
	end
	r.neon = {}
end
function B.rimfireworks(m, r)
	-- the firing system: a case with a key switch and an antenna; the shells start from the stadium roof
	part(m, "Case", Vector3.new(2.4, 1.4, 1.6), CFrame.new(0, 0.7, 0), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
	part(m, "Panel", Vector3.new(2, 0.08, 1.2), CFrame.new(0, 1.44, 0), Color3.fromRGB(60, 62, 70), Enum.Material.Metal)
	part(m, "ArmLight", Vector3.new(0.25, 0.12, 0.25), CFrame.new(-0.6, 1.52, 0.2), Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
	part(m, "Antenna", Vector3.new(0.08, 2.2, 0.08), CFrame.new(0.9, 2.5, -0.5), DARK, Enum.Material.Metal)
	r.burst = part(m, "Burst", Vector3.new(1, 1, 1), CFrame.new(0, 75, 0), DARK)
	r.burst.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(1.2, 2.2),
		Speed = NumberRange.new(30, 46),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(2, 0),
		Color = ColorSequence.new(r.color, Color3.fromRGB(255, 245, 210)),
		LightEmission = 1,
		Drag = 0.8,
		Acceleration = Vector3.new(0, -12, 0),
		Parent = r.burst,
	})
end
function B.fireworks(m, r)
	-- a crate of mortar tubes (4 x 3) with a firing cable box and a hazard stripe
	part(m, "Rack", Vector3.new(4.6, 1.6, 3.6), CFrame.new(0, 0.8, 0), Color3.fromRGB(60, 48, 36), Enum.Material.WoodPlanks)
	part(m, "Stripe", Vector3.new(4.7, 0.3, 3.7), CFrame.new(0, 1.4, 0), Color3.fromRGB(240, 190, 20))
	for ix = 0, 3 do
		for iz = 0, 2 do
			local c = CFrame.new(-1.65 + ix * 1.1, 2.3, -1.1 + iz * 1.1)
			cyl(m, "Mortar", 1.8, 0.8, c, Color3.fromRGB(50, 52, 58), Enum.Material.Metal)
			cyl(m, "MortarTop", 0.1, 0.62, c * CFrame.new(0, 0.86, 0), Color3.fromRGB(20, 20, 22))
		end
	end
	part(m, "CableBox", Vector3.new(1, 0.8, 0.6), CFrame.new(2.7, 0.4, 0), Color3.fromRGB(200, 40, 40), Enum.Material.Metal)
	part(m, "Cable", Vector3.new(0.1, 0.1, 1.2), CFrame.new(2.4, 0.9, 0.4) * CFrame.Angles(0, 0.8, 0), Color3.fromRGB(20, 20, 22))
	r.burst = part(m, "Burst", Vector3.new(1, 1, 1), CFrame.new(0, 75, 0), DARK)
	r.burst.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(36, 54),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(2.4, 0),
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
		local leaf = part(m, "Leaf", Vector3.new(0.5, 0.3, 7), CFrame.new(1.4, 13.2 + i * 0.07, 0) * CFrame.Angles(0, a + i * 0.02, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, 3.2), Color3.fromRGB(60, 255, 140), Enum.Material.Neon)
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
		local p = part(m, "RingSeg", Vector3.new(seg, 2.4, 2.4), CFrame.new(math.cos(a) * R, R + 2 + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2), r.color, Enum.Material.Neon, Enum.PartType.Cylinder)
		table.insert(r.ring, p)
		part(m, "RingBack", Vector3.new(seg, 3.2, 3.2), CFrame.new(math.cos(a) * (R + 0.6), R + 2 + math.sin(a) * (R + 0.6), -1.9) * CFrame.Angles(0, 0, a + math.pi / 2), Color3.fromRGB(28, 28, 32), Enum.Material.Metal, Enum.PartType.Cylinder)
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
		local bar = part(m, "KineticBar", Vector3.new(0.6, 0.6, 7), CFrame.new(x, -3, 0), r.color, Enum.Material.Neon)
		local wa = part(m, "Wire", Vector3.new(0.08, 2.6, 0.08), CFrame.new(x, -1.7, -3), METAL)
		local wb = part(m, "Wire", Vector3.new(0.08, 2.6, 0.08), CFrame.new(x, -1.7, 3), METAL)
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
function B.arch(m, r)
	local w = dims(r, r.def)
	local R = w / 2
	local n = math.clamp(math.floor(w * 0.9), 10, 40)
	r.ring = {}
	for i = 0, n do
		local a = i * math.pi / n
		local seg = math.pi * R / n + 0.2
		table.insert(r.ring, part(m, "ArchSeg", Vector3.new(seg, 1.2, 1.2), CFrame.new(math.cos(a) * R, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2), r.color, Enum.Material.Neon, Enum.PartType.Cylinder))
	end
end
-- Kabuki curtain: rec.cc = colour, rec.anim = "drop" (falls) | "rise" (pulled up) | "split" (opens to the sides),
-- rec.cs = the song it opens in (nil = when the show starts)
Builder.CURTAIN_COLORS = {
	{ "red", "Red", Color3.fromRGB(160, 20, 30) },
	{ "black", "Black", Color3.fromRGB(18, 18, 22) },
	{ "white", "White", Color3.fromRGB(236, 236, 240) },
	{ "gold", "Gold", Color3.fromRGB(200, 160, 60) },
	{ "purple", "Purple", Color3.fromRGB(96, 30, 150) },
	{ "blue", "Blue", Color3.fromRGB(30, 54, 150) },
	{ "artist", "Artist colour", nil },
}
Builder.CURTAIN_ANIMS = { { "drop", "Drop" }, { "rise", "Pull up" }, { "split", "Open sideways" } }
function B.curtain(m, r)
	local w, h = dims(r, r.def)
	local rec = r.rec or {}
	local col = Color3.fromRGB(160, 20, 30)
	for _, c in ipairs(Builder.CURTAIN_COLORS) do
		if c[1] == rec.cc then
			col = c[3] or r.color
		end
	end
	r.curtainW, r.curtainH = w, h
	r.anim = rec.anim or "drop"
	part(m, "Track", Vector3.new(w + 2, 1, 1), CFrame.new(0, h + 1.5, 0), DARK, Enum.Material.Metal)
	local light = col:Lerp(Color3.new(1, 1, 1), 0.7)
	if r.anim == "split" then
		-- two halves that slide apart
		r.halves = {}
		for _, side in ipairs({ -1, 1 }) do
			local home = CFrame.new(side * w / 4, h / 2 + 1, 0)
			local p = part(m, "Drape", Vector3.new(w / 2, h, 0.5 + (side > 0 and 0.06 or 0)), home, col, Enum.Material.Fabric)
			table.insert(r.halves, { p = p, home = home, side = side })
		end
		r.drapeLabel = select(2, surfaceText(r.halves[1].p, Enum.NormalId.Back, r.artistName or "", light, nil))
	else
		r.drapeHome = CFrame.new(0, h / 2 + 1, 0)
		r.drape = part(m, "Drape", Vector3.new(w, h, 0.5), r.drapeHome, col, Enum.Material.Fabric)
		r.drapeLabel = select(2, surfaceText(r.drape, Enum.NormalId.Back, r.artistName or "", light, nil))
	end
end
function B.balls(m, r)
	-- a crate full of giant balloons under a net: you can see the balloons waiting
	part(m, "Box", Vector3.new(5, 3, 4), CFrame.new(0, 1.5, 0), DARK)
	part(m, "Rim", Vector3.new(5.2, 0.3, 4.2), CFrame.new(0, 3.05, 0), METAL, Enum.Material.Metal)
	local cols = { r.color, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 210, 60) }
	for i, o in ipairs({ { -1.3, -0.8 }, { 1.2, -0.9 }, { 0, 0.8 }, { -1.4, 1 }, { 1.4, 0.9 } }) do
		part(m, "WaitingBalloon", Vector3.new(2, 2, 2), CFrame.new(o[1], 3.6 + (i % 2) * 0.4, o[2]), cols[i % 3 + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	for k = -2, 2 do
		part(m, "Net", Vector3.new(0.06, 0.06, 4.4), CFrame.new(k * 1.1, 4.7, 0), Color3.fromRGB(30, 30, 34))
		part(m, "Net", Vector3.new(5.4, 0.06, 0.06), CFrame.new(0, 4.72, k * 0.9), Color3.fromRGB(30, 30, 34))
	end
	r.balloons = {}
end
function B.wristbands(m, r)
	part(m, "Desk", Vector3.new(5, 3, 3), CFrame.new(0, 1.5, 0), DARK)
	r.neon = { part(m, "DeskScreen", Vector3.new(4, 1.6, 0.2), CFrame.new(0, 3.6, 0) * CFrame.Angles(-0.3, 0, 0), r.color, Enum.Material.Neon) }
	part(m, "Antenna", Vector3.new(0.2, 4, 0.2), CFrame.new(2, 5, -1), METAL)
end
function B.lowfog(m, r)
	-- low fog machine: a white chiller on wheels with a frosty outlet duct at the front
	part(m, "Box", Vector3.new(3, 2, 3.5), CFrame.new(0, 1.3, 0), Color3.fromRGB(200, 200, 210))
	for _, c in ipairs({ { -1.2, -1.4 }, { 1.2, -1.4 }, { -1.2, 1.4 }, { 1.2, 1.4 } }) do
		cyl(m, "Wheel", 0.25, 0.5, CFrame.new(c[1], 0.25, c[2]) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(30, 30, 34))
	end
	part(m, "Vent", Vector3.new(2.4, 0.8, 0.05), CFrame.new(0, 1.8, -1.77), Color3.fromRGB(150, 150, 160), Enum.Material.DiamondPlate)
	part(m, "Duct", Vector3.new(2.2, 0.8, 1.2), CFrame.new(0, 0.8, 2.3), Color3.fromRGB(230, 236, 245), Enum.Material.Ice)
	part(m, "Panel", Vector3.new(0.8, 0.4, 0.05), CFrame.new(0.8, 2.0, 1.76), Color3.fromRGB(60, 200, 255), Enum.Material.Neon)
	r.nozzle = part(m, "Nozzle", Vector3.new(1, 1, 1), CFrame.new(0, 0.8, 2.9), DARK)
	r.nozzle.Transparency = 1
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
-- streamer cannon: two wide golden barrels side by side, standing upright on a flat base, with the streamer
-- rolls loaded on top; it shoots long shiny ribbons that float down slowly
function B.streamers(m, r)
	part(m, "Base", Vector3.new(3.6, 0.6, 2), CFrame.new(0, 0.3, 0), Color3.fromRGB(26, 26, 30), Enum.Material.DiamondPlate)
	part(m, "Panel", Vector3.new(1.2, 0.5, 0.06), CFrame.new(0.9, 0.35, 1.03), Color3.fromRGB(60, 200, 90), Enum.Material.Neon)
	for _, x in ipairs({ -0.85, 0.85 }) do
		local c = CFrame.new(x, 2.4, 0) * CFrame.Angles(math.rad(-8), 0, x * 0.08)
		cyl(m, "Barrel", 3.6, 1.5, c, Color3.fromRGB(214, 180, 90), Enum.Material.Metal)
		cyl(m, "BarrelRing", 0.3, 1.58, c * CFrame.new(0, -1.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		cyl(m, "BarrelRing", 0.3, 1.58, c * CFrame.new(0, 1.65, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
		-- the streamer roll in the barrel: silver and the artist's colour
		cyl(m, "Roll", 0.4, 1.1, c * CFrame.new(0, 1.85, 0), Color3.fromRGB(235, 235, 245), Enum.Material.Foil)
		cyl(m, "RollCore", 0.42, 0.4, c * CFrame.new(0, 1.86, 0), r.color, Enum.Material.Foil)
	end
	r.nozzle = cyl(m, "Tube", 0.2, 2.4, CFrame.new(0, 4.3, 0), DARK)
	r.nozzle.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Lifetime = NumberRange.new(6, 9),
		Speed = NumberRange.new(70, 90),
		SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new(0.35, 0.3),
		Squash = NumberSequence.new(2.6), -- long thin ribbons
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(230, 230, 240)),
		Drag = 1.3,
		Acceleration = Vector3.new(0, -6, 0),
		RotSpeed = NumberRange.new(-180, 180),
		Rotation = NumberRange.new(0, 360),
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
	-- the singer stands behind it (towards -Z) and looks to the crowd: the boom and the mic point back to them
	cyl(m, "Foot", 0.2, 2, CFrame.new(0, 0.1, 0), DARK)
	tube(m, Vector3.new(0, 0, 0), Vector3.new(0, 5.6, 0), 0.16, METAL)
	tube(m, Vector3.new(0, 5.6, 0), Vector3.new(0, 6.7, -0.9), 0.12, METAL)
	part(m, "MicClip", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 6.72, -0.95), DARK, Enum.Material.Metal)
	part(m, "Mic", Vector3.new(0.34, 0.34, 0.85), CFrame.new(0, 6.85, -1.3) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(30, 30, 32), Enum.Material.Metal)
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
	return part(m, "NeonLine", Vector3.new(len + (t or 0.5) * 0.9, t or 0.5, t or 0.5), CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, 0) * CFrame.Angles(0, 0, math.atan2(dy, dx)), color, Enum.Material.Neon, Enum.PartType.Cylinder)
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
	part(m, "Headstock", Vector3.new(0.45, 0.85, 0.12), cf * CFrame.new(0.08, 4.5, 0.075) * CFrame.Angles(0, 0, -0.12), Color3.fromRGB(150, 100, 55), Enum.Material.Wood)
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
function B.stool(m, r)
	cyl(m, "Seat", 0.3, 1.6, CFrame.new(0, 3.2, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Leather)
	for _, a in ipairs({ 0, 2.1, 4.2 }) do
		tube(m, Vector3.new(math.cos(a) * 0.4, 3.1, math.sin(a) * 0.4), Vector3.new(math.cos(a) * 0.9, 0, math.sin(a) * 0.9), 0.12, METAL)
	end
	cyl(m, "Ring", 0.1, 1.5, CFrame.new(0, 1.2, 0), METAL, Enum.Material.Metal)
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
		table.insert(r.blades, { p = part(m, "Blade", Vector3.new(0.6, 1.9, 0.1), r.hubLocal, Color3.fromRGB(200, 200, 210), Enum.Material.Metal), a = i * 2.094, z = i * 0.05 })
	end
	r.spin = 0
end
function B.sofa(m, r)
	local c = r.color:Lerp(Color3.fromRGB(60, 50, 60), 0.5)
	part(m, "Base", Vector3.new(7, 1.6, 3), CFrame.new(0, 0.8, 0), c, Enum.Material.Fabric)
	part(m, "Back", Vector3.new(6.8, 2.4, 0.8), CFrame.new(0, 2.6, -1.2), c, Enum.Material.Fabric)
	part(m, "ArmL", Vector3.new(0.9, 1.5, 3.3), CFrame.new(-3.2, 2.3, 0.12), c, Enum.Material.Fabric)
	part(m, "ArmR", Vector3.new(0.9, 1.5, 3.3), CFrame.new(3.2, 2.3, 0.12), c, Enum.Material.Fabric)
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
function B.roadcase(m, r)
	local black = Color3.fromRGB(22, 22, 24)
	for _, c in ipairs({ { 0, 1.2, 0, 4, 2.4, 2.4 }, { 0, 3.3, 0, 3.4, 1.8, 2.2 }, { 3.6, 1, 0.2, 2.6, 2, 2.2 } }) do
		local cf = CFrame.new(c[1], c[2], c[3])
		part(m, "Case", Vector3.new(c[4], c[5], c[6]), cf, black)
		part(m, "Edge", Vector3.new(c[4] + 0.2, 0.2, c[6] + 0.2), cf * CFrame.new(0, c[5] / 2 - 0.2, 0), Color3.fromRGB(170, 170, 176), Enum.Material.Metal)
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
function B.drapes(m, r)
	-- a frame (20 wide, 12 high) with a pelmet and two red drapes tied back at the sides
	local red = Color3.fromRGB(150, 20, 34)
	part(m, "FramePostL", Vector3.new(0.6, 12, 0.6), CFrame.new(-10, 6, 0), DARK, Enum.Material.Metal)
	part(m, "FramePostR", Vector3.new(0.6, 12, 0.6), CFrame.new(10, 6, 0), DARK, Enum.Material.Metal)
	part(m, "Pelmet", Vector3.new(21.4, 1.6, 0.9), CFrame.new(0, 11.4, 0.2), red, Enum.Material.Fabric)
	part(m, "PelmetTrim", Vector3.new(21.5, 0.25, 1.04), CFrame.new(0, 10.55, 0.2), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		-- folds: a few panels that get narrower towards the tie-back
		for k = 0, 3 do
			local x = side * (9.4 - k * 0.9)
			part(m, "Drape", Vector3.new(0.95, 9.6 - k * 0.4, 0.5 + k * 0.07), CFrame.new(x, 5.6 + k * 0.2, -0.1 - k * 0.05) * CFrame.Angles(0, 0, side * k * 0.03), red, Enum.Material.Fabric)
		end
		part(m, "TieBack", Vector3.new(4.2, 0.3, 1.2), CFrame.new(side * 8.3, 4.6, 0.1), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
	end
end

function B.barrels(m, r)
	local wood = Color3.fromRGB(130, 84, 46)
	local hoop = Color3.fromRGB(60, 60, 66)
	for i, o in ipairs({ { -1.6, 0, 0 }, { 1.4, 0, -0.6 } }) do
		local c = CFrame.new(o[1], 0, o[3])
		cyl(m, "Barrel", 3.4, 2.4, c * CFrame.new(0, 1.7, 0), wood, Enum.Material.WoodPlanks)
		cyl(m, "BarrelBelly", 1.6, 2.7, c * CFrame.new(0, 1.7, 0), wood, Enum.Material.WoodPlanks)
		for _, y in ipairs({ 0.5, 2.9 }) do
			cyl(m, "Hoop", 0.2, 2.5, c * CFrame.new(0, y, 0), hoop, Enum.Material.Metal)
		end
		local _ = i
	end
	part(m, "Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0.2, 1.1, 2.2) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(170, 130, 80), Enum.Material.WoodPlanks)
	part(m, "CrateTop", Vector3.new(1.8, 1.8, 1.8), CFrame.new(0.3, 3.1, 2.1) * CFrame.Angles(0, -0.2, 0), Color3.fromRGB(160, 120, 74), Enum.Material.WoodPlanks)
end

function B.bookshelf(m, r)
	local wood = Color3.fromRGB(110, 70, 40)
	part(m, "ShelfBack", Vector3.new(6, 9, 0.3), CFrame.new(0, 4.5, -0.85), wood, Enum.Material.Wood)
	part(m, "ShelfSideL", Vector3.new(0.3, 9, 2), CFrame.new(-3.15, 4.5, 0), wood, Enum.Material.Wood)
	part(m, "ShelfSideR", Vector3.new(0.3, 9, 2), CFrame.new(3.15, 4.5, 0), wood, Enum.Material.Wood)
	local rng = Random.new(5)
	local BOOK = { Color3.fromRGB(180, 50, 50), Color3.fromRGB(50, 90, 160), Color3.fromRGB(220, 190, 90), Color3.fromRGB(60, 130, 80), Color3.fromRGB(230, 230, 230), Color3.fromRGB(40, 40, 46) }
	for k = 0, 3 do
		local y = 0.15 + k * 2.25
		part(m, "Shelf", Vector3.new(5.96, 0.25, 1.9), CFrame.new(0, y + 0.12, 0.05), wood, Enum.Material.Wood)
		if k < 3 then
			local x = -2.8
			while x < 2.5 do
				local w = 0.25 + rng:NextNumber() * 0.2
				local h = 1.3 + rng:NextNumber() * 0.6
				part(m, "Book", Vector3.new(w, h, 1.3), CFrame.new(x + w / 2, y + 0.25 + h / 2, 0.05), BOOK[rng:NextInteger(1, #BOOK)])
				x = x + w + 0.03
				if rng:NextNumber() < 0.08 then
					x = x + 0.9
				end
			end
		end
	end
	part(m, "ShelfTop", Vector3.new(6.6, 0.3, 2.1), CFrame.new(0, 9.15, 0), wood, Enum.Material.Wood)
	cyl(m, "LampFoot", 1.0, 0.3, CFrame.new(1.8, 9.8, 0), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
	r.glow = cyl(m, "LampShade", 0.9, 1.2, CFrame.new(1.8, 10.6, 0), Color3.fromRGB(255, 220, 160), Enum.Material.Neon)
end

function B.lanternline(m, r)
	-- two poles 18 apart, a line between them with paper lanterns
	part(m, "PoleL", Vector3.new(0.4, 11, 0.4), CFrame.new(-9, 5.5, 0), DARK, Enum.Material.Metal)
	part(m, "PoleR", Vector3.new(0.4, 11, 0.4), CFrame.new(9, 5.5, 0), DARK, Enum.Material.Metal)
	local COLS = { Color3.fromRGB(255, 120, 90), Color3.fromRGB(255, 210, 110), Color3.fromRGB(255, 160, 200), Color3.fromRGB(150, 220, 255) }
	local prev = Vector3.new(-9, 10.6, 0)
	r.lamps = {}
	for k = 1, 9 do
		local x = -9 + k * 1.8
		local y = 10.6 - math.sin(k / 10 * math.pi) * 2.2
		local pnt = Vector3.new(x, y, 0)
		tube(m, prev, pnt, 0.06, DARK)
		prev = pnt
		if k < 10 then
			local lamp = part(m, "Lantern", Vector3.new(1.2, 1.2, 1.2), CFrame.new(x, y - 1.0, 0), COLS[k % #COLS + 1], Enum.Material.Neon, Enum.PartType.Ball)
			part(m, "LanternCap", Vector3.new(0.5, 0.14, 0.5), CFrame.new(x, y - 0.28, 0), DARK)
			table.insert(r.lamps, lamp)
		end
	end
	tube(m, prev, Vector3.new(9, 10.6, 0), 0.06, DARK)
end

function B.golddiscs(m, r)
	-- a black wall on two feet with framed records in rows
	part(m, "DiscWall", Vector3.new(9, 6.4, 0.4), CFrame.new(0, 4.4, 0), Color3.fromRGB(24, 24, 30))
	for _, x in ipairs({ -3.6, 3.6 }) do
		part(m, "DiscFoot", Vector3.new(0.5, 1.2, 2.4), CFrame.new(x, 0.6, 0), DARK, Enum.Material.Metal)
	end
	for row = 0, 1 do
		for col = 0, 2 do
			local x, y = -2.9 + col * 2.9, 5.9 - row * 3
			local plat = (row + col) % 3 == 0
			part(m, "DiscFrame", Vector3.new(2.4, 2.6, 0.16), CFrame.new(x, y, 0.27), Color3.fromRGB(240, 240, 244))
			cyl(m, "Disc", 0.06, 1.7, CFrame.new(x, y + 0.15, 0.37) * CFrame.Angles(math.pi / 2, 0, 0), plat and Color3.fromRGB(220, 224, 232) or Color3.fromRGB(230, 185, 60), Enum.Material.Metal)
			part(m, "DiscPlate", Vector3.new(1.6, 0.3, 0.06), CFrame.new(x, y - 1.0, 0.38), Color3.fromRGB(30, 30, 34))
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
------------------------------------------------------------------ reworked props and new props (Nov 2026)
-- round tube along the arc of a circle in the XY plane (centre c, radius R, from angle a0 to a1)
local function arcTube(m, name, c, R, a0, a1, n, d, color, mat)
	local parts = {}
	for i = 0, n - 1 do
		local u0, u1 = a0 + (a1 - a0) * i / n, a0 + (a1 - a0) * (i + 1) / n
		local p0 = c * CFrame.new(math.cos(u0) * R, math.sin(u0) * R, 0)
		local p1 = c * CFrame.new(math.cos(u1) * R, math.sin(u1) * R, 0)
		local t = tube(m, p0.Position, p1.Position, d, color)
		if t then
			t.Name = name
			t.Material = mat or Enum.Material.SmoothPlastic
			-- tubes overlap a little at the joints (round, so no flicker)
			t.Size = t.Size + Vector3.new(d * 0.8, 0, 0)
			table.insert(parts, t)
		end
	end
	return parts
end
local function oval(m, name, size, cf, color, mat)
	local p = part(m, name, size, cf, color, mat)
	New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

function B.scissor(m, r)
	-- scissor lift: chassis, crossed arms that open as it rises, platform with railings
	part(m, "Base", Vector3.new(8, 0.8, 9), CFrame.new(0, 0.4, 0), Color3.fromRGB(40, 40, 46))
	part(m, "BaseStripe", Vector3.new(8.1, 0.3, 9.1), CFrame.new(0, 0.6, 0), Color3.fromRGB(240, 190, 20))
	for _, x in ipairs({ -3.4, 3.4 }) do
		for _, z in ipairs({ -3.6, 3.6 }) do
			cyl(m, "Wheel", 0.6, 1.1, CFrame.new(x, 0.5, z) * CFrame.Angles(0, 0, -math.pi / 2), Color3.fromRGB(20, 20, 22))
		end
	end
	r.column = part(m, "Column", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.6, 0), METAL)
	r.column.Transparency = 1
	r.arms = {}
	for _, x in ipairs({ -3.2, 3.2 }) do
		for k = 1, 2 do
			table.insert(r.arms, { p = part(m, "ScissorArm", Vector3.new(0.4, 0.6 - (k - 1) * 0.05, 8.4 - (k - 1) * 0.1 - ((x > 0) and 0.05 or 0)), CFrame.new(x, 1, 0), METAL, Enum.Material.Metal), x = x + ((k == 2) and 0.45 or 0), k = k })
		end
	end
	r.platform = part(m, "Platform", Vector3.new(7.8, 0.64, 8.8), CFrame.new(0, 0.9, 0), Color3.fromRGB(60, 60, 70), Enum.Material.DiamondPlate)
	r.edge = part(m, "Edge", Vector3.new(8.4, 0.2, 9.4), CFrame.new(0, 1.25, 0), r.color, Enum.Material.Neon)
	r.rails = {}
	for _, c in ipairs({ { 0, -4.4, 7.6, 0.15 }, { -3.9, 0, 0.15, 8.6 }, { 3.9, 0, 0.15, 8.6 } }) do
		table.insert(r.rails, { p = part(m, "Railing", Vector3.new(c[3], 0.15, c[4]), CFrame.new(c[1], 4.2, c[2]), Color3.fromRGB(240, 190, 20), Enum.Material.Metal), x = c[1], z = c[2], y = 4.2 })
		table.insert(r.rails, { p = part(m, "MidRail", Vector3.new(math.max(0.12, c[3] - 0.04), 0.12, math.max(0.12, c[4] - 0.04)), CFrame.new(c[1], 2.8, c[2]), Color3.fromRGB(240, 190, 20), Enum.Material.Metal), x = c[1], z = c[2], y = 2.8 })
	end
	-- posts hold the railings on the platform (they rise with it)
	for _, pp in ipairs({ { -3.9, -4.4 }, { 3.9, -4.4 }, { -3.9, 4.3 }, { 3.9, 4.3 }, { -3.9, 0 }, { 3.9, 0 }, { 0, -4.4 } }) do
		table.insert(r.rails, { p = part(m, "RailPost", Vector3.new(0.21, 3, 0.21), CFrame.new(pp[1], 2.7, pp[2]), Color3.fromRGB(240, 190, 20), Enum.Material.Metal), x = pp[1], z = pp[2], y = 2.7 })
	end
	r.scissorH = 0
end

function B.amps(m, r)
	-- full stack: 2x2 cabinets with piping, corner protectors and handles, amp head with knobs
	local tolex = Color3.fromRGB(18, 18, 20)
	for i = 0, 1 do
		for k = 0, 1 do
			local cf = CFrame.new(-2.1 + i * 4.2, 1.6 + k * 3.2, 0)
			part(m, "Cab", Vector3.new(4, 3.1, 2.4), cf, tolex, Enum.Material.Leather)
			part(m, "Grille", Vector3.new(3.5, 2.6, 0.08), cf * CFrame.new(0, 0, 1.22), Color3.fromRGB(70, 60, 50), Enum.Material.Fabric)
			part(m, "Piping", Vector3.new(3.6, 0.08, 0.06), cf * CFrame.new(0, 1.33, 1.26), Color3.fromRGB(230, 225, 210))
			for _, cx in ipairs({ -1.85, 1.85 }) do
				for _, cy in ipairs({ -1.4, 1.4 }) do
					part(m, "Corner", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(cx, cy, 1.05), Color3.fromRGB(190, 190, 196), Enum.Material.Metal)
				end
			end
			part(m, "Handle", Vector3.new(0.12, 0.4, 1.2), cf * CFrame.new(-2.06, 0.5, 0), Color3.fromRGB(30, 30, 30))
		end
	end
	part(m, "Head", Vector3.new(8.2, 1.6, 2.2), CFrame.new(0, 7.2, 0), tolex, Enum.Material.Leather)
	part(m, "Panel", Vector3.new(7.4, 0.8, 0.06), CFrame.new(0, 7.2, 1.13), Color3.fromRGB(200, 170, 90), Enum.Material.Metal)
	for k = 0, 9 do
		cyl(m, "Knob", 0.2, 0.32, CFrame.new(-2.2 + k * 0.5, 7.2, 1.2) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(20, 20, 20))
	end
	r.neon = { part(m, "AmpLogo", Vector3.new(1.8, 0.4, 0.06), CFrame.new(-2.9, 7.75, 1.16), r.color, Enum.Material.Neon) }
end

function B.congas(m, r)
	-- two congas in a stand with rims and tuning lugs, a bongo pair and a cymbal
	for i, x in ipairs({ -0.9, 0.9 }) do
		local h, d = 3.4 - i * 0.3, 1.5 - i * 0.15
		oval(m, "Conga", Vector3.new(d * 1.08, h, d * 1.08), CFrame.new(x, h / 2 + 0.3, 0), Color3.fromRGB(150, 80, 40), Enum.Material.Wood)
		cyl(m, "Rim", 0.18, d + 0.05, CFrame.new(x, h + 0.25, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		cyl(m, "CongaHead", 0.08, d - 0.05, CFrame.new(x, h + 0.33, 0), Color3.fromRGB(235, 225, 200))
		for k = 0, 4 do
			local a = k * math.pi * 2 / 5
			part(m, "Lug", Vector3.new(0.1, 0.8, 0.1), CFrame.new(x + math.cos(a) * d * 0.5, h - 0.2, math.sin(a) * d * 0.5), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		end
		cyl(m, "StandRing", 0.1, d * 1.1, CFrame.new(x, h * 0.4, 0), METAL, Enum.Material.Metal)
	end
	tube(m, Vector3.new(0, 0, 1.6), Vector3.new(0, 2.6, 1.6), 0.12, METAL)
	for _, x in ipairs({ -0.4, 0.45 }) do
		cyl(m, "Bongo", 0.6, (x < 0) and 0.8 or 0.95, CFrame.new(x, 2.9, 1.6), Color3.fromRGB(170, 100, 50), Enum.Material.Wood)
	end
	tube(m, Vector3.new(2.2, 0, -0.5), Vector3.new(2.2, 3.8, -0.5), 0.1, METAL)
	cyl(m, "Cymbal", 0.06, 2, CFrame.new(2.2, 3.9, -0.5) * CFrame.Angles(0.2, 0, 0), Color3.fromRGB(220, 180, 70), Enum.Material.Metal)
end

function B.tvstack(m, r)
	-- stacked old CRT tellies: wooden cases, rounded screens, knobs, rabbit-ear antennas on top
	r.tvs = {}
	local rows = { 3, 2, 1 }
	for row, n in ipairs(rows) do
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 3.4
			local y = 1.3 + (row - 1) * 2.7
			local cf = CFrame.new(x, y, 0) * CFrame.Angles(0, (i - (n + 1) / 2) * 0.12, 0)
			part(m, "TV", Vector3.new(3.2, 2.6, 2.4), cf, Color3.fromRGB(70, 52, 40), Enum.Material.Wood)
			part(m, "Bezel", Vector3.new(2.5, 2, 0.1), cf * CFrame.new(-0.25, 0, 1.22), Color3.fromRGB(30, 30, 30))
			local scr = oval(m, "TVScreen", Vector3.new(2.2, 1.7, 0.25), cf * CFrame.new(-0.25, 0, 1.25), r.color, Enum.Material.Neon)
			table.insert(r.tvs, scr)
			for k = 0, 1 do
				cyl(m, "Knob", 0.12, 0.3, cf * CFrame.new(1.25, 0.4 - k * 0.6, 1.22) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(200, 190, 170))
			end
		end
	end
	tube(m, Vector3.new(0, 7.8, 0), Vector3.new(-1.2, 10, -0.3), 0.08, METAL)
	tube(m, Vector3.new(0, 7.8, 0), Vector3.new(1.2, 10, -0.3), 0.08, METAL)
end

function B.statue(m, r)
	-- giant chrome figure with rounded limbs; the head turns, the visor glows
	local chrome = Color3.fromRGB(200, 204, 214)
	local function c(name, size, cf)
		local p = oval(m, name, size, cf, chrome, Enum.Material.Foil)
		p.Reflectance = 0.35
		return p
	end
	local plinth = part(m, "Plinth", Vector3.new(11, 3, 11), CFrame.new(0, 1.5, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Marble)
	local _ = plinth
	part(m, "PlinthGlow", Vector3.new(11.3, 0.3, 11.3), CFrame.new(0, 2.6, 0), r.color, Enum.Material.Neon)
	c("FootL", Vector3.new(3.4, 1.6, 5), CFrame.new(-2.3, 3.8, 0.6))
	c("FootR", Vector3.new(3.4, 1.6, 5), CFrame.new(2.3, 3.8, 0.6))
	c("ShinL", Vector3.new(3, 7.5, 3), CFrame.new(-2.3, 7.8, 0))
	c("ShinR", Vector3.new(3, 7.5, 3), CFrame.new(2.3, 7.8, 0))
	c("ThighL", Vector3.new(3.6, 7, 3.6), CFrame.new(-2.2, 13.6, 0))
	c("ThighR", Vector3.new(3.6, 7, 3.6), CFrame.new(2.2, 13.6, 0))
	c("Hips", Vector3.new(8, 4, 5), CFrame.new(0, 17, 0))
	c("Body", Vector3.new(9, 10, 5.5), CFrame.new(0, 21.5, 0))
	c("Chest", Vector3.new(10, 5, 5.8), CFrame.new(0, 24.5, 0.2))
	for _, sx in ipairs({ -1, 1 }) do
		c("Shoulder", Vector3.new(4, 4, 4), CFrame.new(sx * 5.6, 25.6, 0))
		c("UpperArm", Vector3.new(2.8, 7, 2.8), CFrame.new(sx * 6.4, 21.5, 0) * CFrame.Angles(0, 0, sx * 0.12))
		c("ForeArm", Vector3.new(2.5, 6.5, 2.5), CFrame.new(sx * 7.1, 15.8, 0.4) * CFrame.Angles(0.1, 0, sx * 0.06))
		c("Hand", Vector3.new(2.4, 2.8, 1.6), CFrame.new(sx * 7.4, 12, 0.6))
	end
	c("Neck", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 27.6, 0))
	r.headLocal = CFrame.new(0, 30.5, 0)
	r.head = part(m, "Head", Vector3.new(5.6, 5.6, 5.6), r.headLocal, chrome, Enum.Material.Foil, Enum.PartType.Ball)
	r.head.Reflectance = 0.35
	r.visor = part(m, "Visor", Vector3.new(4.6, 1, 0.3), r.headLocal * CFrame.new(0, 0.4, 2.65), r.color, Enum.Material.Neon)
end

function B.robotarm(m, r)
	-- industrial robot: base with warning stripes, turret, round joints that follow the arm
	local yellow = Color3.fromRGB(240, 170, 20)
	cyl(m, "Base", 2, 7.4, CFrame.new(0, 1, 0), DARK)
	cyl(m, "BaseStripe", 0.5, 7.6, CFrame.new(0, 1.4, 0), yellow)
	part(m, "Cable", Vector3.new(0.6, 0.6, 5), CFrame.new(0, 0.3, -5), Color3.fromRGB(20, 20, 22))
	r.turret = cyl(m, "Turret", 2.5, 5, CFrame.new(0, 3.2, 0), yellow, Enum.Material.Metal)
	r.lower = part(m, "Lower", Vector3.new(2.2, 14, 2.2), CFrame.new(0, 11, 0), yellow, Enum.Material.Metal)
	r.upper = part(m, "Upper", Vector3.new(1.8, 12, 1.8), CFrame.new(0, 24, 0), yellow, Enum.Material.Metal)
	r.tool = part(m, "Tool", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 31, 0), Color3.fromRGB(30, 30, 34))
	r.lamp = part(m, "Lamp", Vector3.new(1.6, 0.3, 1.6), CFrame.new(0, 32.4, 0), r.color, Enum.Material.Neon)
	r.shoulderJoint = part(m, "Joint", Vector3.new(3.6, 3.6, 3.6), CFrame.new(0, 4, 0), Color3.fromRGB(50, 50, 56), Enum.Material.Metal, Enum.PartType.Ball)
	r.elbowJoint = part(m, "Joint", Vector3.new(3, 3, 3), CFrame.new(0, 18, 0), Color3.fromRGB(50, 50, 56), Enum.Material.Metal, Enum.PartType.Ball)
	r.wristJoint = part(m, "Joint", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 30, 0), Color3.fromRGB(50, 50, 56), Enum.Material.Metal, Enum.PartType.Ball)
	r.beam = beam(r.tool, Vector3.new(0, 1.4, 0), Vector3.new(0, 90, 0), 1, 9, r.color, 0.45)
end

function B.house(m, r)
	-- little wooden house on a porch: siding, window frames with crosses, steps, railing, flower boxes
	local wood = Color3.fromRGB(150, 110, 80)
	local trim = Color3.fromRGB(235, 228, 214)
	part(m, "Porch", Vector3.new(16, 1, 14), CFrame.new(0, 0.5, 1), Color3.fromRGB(110, 80, 56), Enum.Material.WoodPlanks)
	part(m, "Walls", Vector3.new(14, 10, 10), CFrame.new(0, 6, 0), wood, Enum.Material.WoodPlanks)
	for k = 0, 8 do
		part(m, "Siding", Vector3.new(14.1, 0.12, 10.1), CFrame.new(0, 1.6 + k * 1.1, 0), wood:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood)
	end
	local roofCF = CFrame.new(0, 11, 0)
	New("WedgePart", { Name = "Roof", Size = Vector3.new(15.6, 5, 6.4), CFrame = roofCF * CFrame.new(0, 2.5, 3.2) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Slate, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	New("WedgePart", { Name = "Roof", Size = Vector3.new(15.6, 5, 6.4), CFrame = roofCF * CFrame.new(0, 2.5, -3.2), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Slate, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	part(m, "Ridge", Vector3.new(15.8, 0.4, 0.5), CFrame.new(0, 16.1, 0), Color3.fromRGB(60, 40, 32))
	part(m, "Chimney", Vector3.new(1.6, 5, 1.6), CFrame.new(4, 14.5, -1.5), Color3.fromRGB(120, 60, 50), Enum.Material.Brick)
	part(m, "Door", Vector3.new(2.6, 5.5, 0.2), CFrame.new(0, 3.75, 5.05), Color3.fromRGB(70, 40, 30), Enum.Material.Wood)
	part(m, "DoorFrame", Vector3.new(3.2, 6, 0.15), CFrame.new(0, 3.95, 5.02), trim)
	part(m, "Knob", Vector3.new(0.25, 0.25, 0.25), CFrame.new(0.9, 3.6, 5.2), Color3.fromRGB(210, 170, 70), Enum.Material.Metal, Enum.PartType.Ball)
	r.windows = {}
	for _, x in ipairs({ -4.5, 4.5 }) do
		part(m, "WindowFrame", Vector3.new(3.6, 3.6, 0.15), CFrame.new(x, 6.5, 5.02), trim)
		table.insert(r.windows, part(m, "Window", Vector3.new(3, 3, 0.2), CFrame.new(x, 6.5, 5.06), WARM, Enum.Material.Neon))
		part(m, "Cross", Vector3.new(3, 0.18, 0.1), CFrame.new(x, 6.5, 5.18), trim)
		part(m, "Cross", Vector3.new(0.18, 3, 0.1), CFrame.new(x, 6.5, 5.23), trim)
		part(m, "FlowerBox", Vector3.new(3.4, 0.6, 0.7), CFrame.new(x, 4.5, 5.4), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
		for k = 0, 3 do
			part(m, "Flower", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x - 1.2 + k * 0.8, 5, 5.45), (k % 2 == 0) and Color3.fromRGB(255, 90, 140) or Color3.fromRGB(255, 220, 80), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
	table.insert(r.windows, part(m, "AtticWindow", Vector3.new(2, 2, 0.2), CFrame.new(0, 13, 4.6), WARM, Enum.Material.Neon))
	for k = 0, 1 do
		part(m, "Step", Vector3.new(4, 0.5, 1.2), CFrame.new(0, 0.22 + 0.48 * (1 - k), 8.2 + k * 1.2), Color3.fromRGB(120, 88, 60), Enum.Material.WoodPlanks)
	end
	for _, x in ipairs({ -7.5, -5, 5, 7.5 }) do
		part(m, "Post", Vector3.new(0.3, 2.4, 0.3), CFrame.new(x, 2.2, 7.6), trim)
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(m, "Rail", Vector3.new(2.9, 0.2, 0.2), CFrame.new(sx * 6.25, 3.2, 7.6), trim)
	end
	part(m, "Lantern", Vector3.new(0.8, 1.2, 0.8), CFrame.new(2.2, 6.2, 5.4), WARM, Enum.Material.Neon)
	part(m, "Mailbox", Vector3.new(0.8, 0.8, 1.4), CFrame.new(-6.5, 3.6, 7.3), Color3.fromRGB(40, 70, 140), Enum.Material.Metal)
end

function B.skyline(m, r)
	-- a row of skyscrapers: setbacks, window grids, water tanks and blinking antennas
	local w = dims(r, r.def)
	r.windows = {}
	local x = -w / 2
	local i = 0
	local cols = { Color3.fromRGB(26, 26, 32), Color3.fromRGB(34, 38, 50), Color3.fromRGB(44, 36, 34), Color3.fromRGB(30, 34, 30) }
	while x < w / 2 - 3 do
		i = i + 1
		local bw = 4 + (i * 37 % 5)
		bw = math.min(bw, w / 2 - x)
		local bh = 12 + (i * 53 % 23)
		local col = cols[i % #cols + 1]
		part(m, "Building", Vector3.new(bw - 0.3, bh, 4), CFrame.new(x + bw / 2, bh / 2, 0), col)
		if i % 3 == 0 and bw > 4.5 then
			part(m, "Setback", Vector3.new(bw - 1.6, 5, 3), CFrame.new(x + bw / 2, bh + 2.5, -0.3), col)
		end
		local cols2 = (bw > 6) and 2 or 1
		for k = 1, math.floor(bh / 3.2) do
			for c = 1, cols2 do
				local wx = x + 0.8 + (c - 0.5) * (bw - 1.6) / cols2 + 0.0
				local win = part(m, "Window", Vector3.new((bw - 1.6) / cols2 - 0.4, 1.4, 0.2), CFrame.new(wx, k * 3.2 - 1.2, 2.05), WARM, Enum.Material.Neon)
				win.Transparency = ((i + k + c) % 3 == 0) and 0.9 or 0.2
				table.insert(r.windows, win)
			end
		end
		if i % 5 == 2 then
			cyl(m, "WaterTank", 2, 1.6, CFrame.new(x + bw / 2 - 0.8, bh + 2, -0.5), Color3.fromRGB(90, 70, 50), Enum.Material.WoodPlanks)
		end
		if i % 4 == 0 then
			part(m, "Antenna", Vector3.new(0.3, 6, 0.3), CFrame.new(x + bw / 2, bh + 3, 0), METAL)
			part(m, "RedLight", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + bw / 2, bh + 6.2, 0), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
		end
		x = x + bw
	end
end

function B.chair(m, r)
	-- wooden chair with turned legs, stretchers and a slatted back
	local wood = Color3.fromRGB(120, 80, 50)
	part(m, "Seat", Vector3.new(2, 0.3, 2), CFrame.new(0, 2, 0), wood, Enum.Material.Wood)
	for _, x in ipairs({ -0.85, 0.85 }) do
		for _, z in ipairs({ -0.85, 0.85 }) do
			cyl(m, "Leg", 1.85, 0.22, CFrame.new(x, 0.93, z), wood, Enum.Material.Wood)
		end
		cyl(m, "BackPost", 2.4, 0.22, CFrame.new(x, 3.25, -0.85), wood, Enum.Material.Wood)
	end
	for k = 0, 2 do
		part(m, "Slat", Vector3.new(1.5, 0.3, 0.12), CFrame.new(0, 2.8 + k * 0.6, -0.85), wood, Enum.Material.Wood)
	end
	part(m, "Stretcher", Vector3.new(1.7, 0.12, 0.12), CFrame.new(0, 0.6, 0.85), wood, Enum.Material.Wood)
	part(m, "Stretcher", Vector3.new(1.7, 0.12, 0.12), CFrame.new(0, 0.6, -0.85), wood, Enum.Material.Wood)
end

function B.uplight(m, r)
	-- LED uplight: round body on a bracket, bright lens, beam up the wall
	part(m, "Bracket", Vector3.new(1.8, 0.15, 1.2), CFrame.new(0, 0.08, 0), METAL, Enum.Material.Metal)
	cyl(m, "Body", 1, 1.5, CFrame.new(0, 0.7, 0), DARK)
	cyl(m, "Rim", 0.15, 1.55, CFrame.new(0, 1.2, 0), Color3.fromRGB(46, 46, 52), Enum.Material.Metal)
	r.lens = cyl(m, "Lens", 0.08, 1.2, CFrame.new(0, 1.28, 0), r.color, Enum.Material.Neon)
	r.light = New("SpotLight", { Face = Enum.NormalId.Right, Angle = 60, Range = 30, Brightness = 2, Color = r.color, Shadows = false, Parent = r.lens })
	r.beam = beam(r.lens, Vector3.new(0.05, 0, 0), Vector3.new(18, 0, 2), 1, 6, r.color, 0.7)
end

function B.table(m, r)
	-- round café table with a pedestal foot, a glass of wine and a vase
	cyl(m, "Top", 0.2, 2.6, CFrame.new(0, 2.6, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
	cyl(m, "TopEdge", 0.12, 2.7, CFrame.new(0, 2.48, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	cyl(m, "Leg", 2.3, 0.3, CFrame.new(0, 1.25, 0), Color3.fromRGB(40, 30, 24))
	cyl(m, "Foot", 0.2, 1.4, CFrame.new(0, 0.1, 0), Color3.fromRGB(40, 30, 24))
	cyl(m, "GlassStem", 0.4, 0.08, CFrame.new(-0.6, 2.9, 0.3), Color3.fromRGB(220, 230, 240), Enum.Material.Glass)
	oval(m, "Glass", Vector3.new(0.4, 0.5, 0.4), CFrame.new(-0.6, 3.3, 0.3), Color3.fromRGB(150, 20, 40), Enum.Material.Glass)
	oval(m, "Vase", Vector3.new(0.6, 1, 0.6), CFrame.new(0.5, 3.2, -0.2), Color3.fromRGB(240, 240, 245))
	part(m, "Flower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0.5, 3.95, -0.2), r.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

function B.plant(m, r)
	-- potted plant: tapered pot, soil, big drooping leaves
	oval(m, "Pot", Vector3.new(1.9, 2, 1.9), CFrame.new(0, 0.8, 0), Color3.fromRGB(180, 100, 70), Enum.Material.Concrete)
	cyl(m, "PotRim", 0.3, 2, CFrame.new(0, 1.7, 0), Color3.fromRGB(160, 86, 60), Enum.Material.Concrete)
	cyl(m, "Soil", 0.1, 1.7, CFrame.new(0, 1.76, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Ground) -- just below the rim (no flicker)
	for i = 0, 8 do
		local a = i * 2.4
		local up = 0.5 + (i % 3) * 0.25
		oval(m, "Leaf", Vector3.new(0.6, 0.14, 2.4), CFrame.new(0, 2.2 + (i % 3) * 0.5, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(-up, 0, 0) * CFrame.new(0, 0, 1.1), Color3.fromRGB(40 + i * 5, 110 + i * 6, 50), Enum.Material.Grass)
	end
end

function B.column(m, r)
	-- classic column: square plinth, round base, fluted shaft, capital with a glowing top
	local white = Color3.fromRGB(236, 232, 222)
	part(m, "Plinth", Vector3.new(3.4, 0.8, 3.4), CFrame.new(0, 0.4, 0), white, Enum.Material.Marble)
	cyl(m, "ColBase", 0.7, 2.9, CFrame.new(0, 1.15, 0), white, Enum.Material.Marble)
	cyl(m, "Shaft", 11, 2.2, CFrame.new(0, 7, 0), white, Enum.Material.Marble)
	for k = 0, 7 do
		local a = k * math.pi / 4
		part(m, "Flute", Vector3.new(0.18, 10.6, 0.18), CFrame.new(math.cos(a) * 1.08, 7, math.sin(a) * 1.08), Color3.fromRGB(210, 206, 196), Enum.Material.Marble)
	end
	cyl(m, "Neck", 0.5, 2.6, CFrame.new(0, 12.75, 0), white, Enum.Material.Marble)
	part(m, "Capital", Vector3.new(3.4, 0.9, 3.4), CFrame.new(0, 13.45, 0), white, Enum.Material.Marble)
	r.glow = part(m, "Glow", Vector3.new(3.0, 0.2, 3.0), CFrame.new(0, 14.0, 0), r.color, Enum.Material.Neon)
end

function B.giantguitar(m, r)
	-- a guitar 16 studs tall leaning back on an A-frame stand
	local body = Color3.fromRGB(200, 40, 50)
	local lean = CFrame.new(0, 0.5, 0) * CFrame.Angles(math.rad(-12), 0, 0)
	part(m, "StandFoot", Vector3.new(6, 0.4, 1), CFrame.new(0, 0.2, 0.6), DARK, Enum.Material.Metal)
	tube(m, Vector3.new(-2.6, 0.3, 0.6), Vector3.new(0, 6.5, -1.6), 0.3, DARK)
	tube(m, Vector3.new(2.6, 0.3, 0.6), Vector3.new(0, 6.5, -1.6), 0.3, DARK)
	tube(m, Vector3.new(0, 0.3, -3), Vector3.new(0, 9, -2.2), 0.3, DARK)
	oval(m, "BodyLow", Vector3.new(6.4, 5.6, 1.4), lean * CFrame.new(0, 3.2, 0), body, Enum.Material.SmoothPlastic)
	oval(m, "BodyHigh", Vector3.new(5, 4.4, 1.4), lean * CFrame.new(0, 6.6, 0), body, Enum.Material.SmoothPlastic)
	part(m, "Pickguard", Vector3.new(2.2, 2.6, 0.1), lean * CFrame.new(1.2, 4.2, 0.72), Color3.fromRGB(240, 236, 228))
	part(m, "Bridge", Vector3.new(2.4, 0.4, 0.2), lean * CFrame.new(0, 2.4, 0.78), Color3.fromRGB(30, 30, 34))
	part(m, "Neck", Vector3.new(1.2, 8.6, 0.6), lean * CFrame.new(0, 12.8, 0.25), Color3.fromRGB(120, 76, 40), Enum.Material.Wood)
	part(m, "Fretboard", Vector3.new(1.0, 8.6, 0.12), lean * CFrame.new(0, 12.8, 0.6), Color3.fromRGB(40, 26, 18), Enum.Material.Wood)
	part(m, "Head", Vector3.new(1.8, 2.4, 0.5), lean * CFrame.new(0, 18.2, 0.15), Color3.fromRGB(30, 30, 34))
	r.strings = {}
	for k = 0, 5 do
		local x = -0.4 + k * 0.16
		table.insert(r.strings, part(m, "String", Vector3.new(0.06, 15.8, 0.06), lean * CFrame.new(x, 10.2, 0.72), r.color, Enum.Material.Neon))
	end
end

function B.tree(m, r)
	-- tree with a forked trunk, branches and several leaf clusters
	cyl(m, "Trunk", 6, 1, CFrame.new(0, 3, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
	tube(m, Vector3.new(0, 5.5, 0), Vector3.new(1.6, 8.5, 0.4), 0.6, Color3.fromRGB(90, 60, 40)).Material = Enum.Material.Wood
	tube(m, Vector3.new(0, 5.5, 0), Vector3.new(-1.4, 8.2, -0.5), 0.6, Color3.fromRGB(90, 60, 40)).Material = Enum.Material.Wood
	for i, o in ipairs({ { 0, 9, 0, 5.5 }, { 1.9, 9.6, 0.6, 4.4 }, { -1.8, 9.2, -0.6, 4.6 }, { 0.2, 11.2, 0.2, 4 }, { 0.8, 8.2, -1.6, 3.4 }, { -0.8, 8.4, 1.6, 3.4 } }) do
		part(m, "Leaves", Vector3.new(o[4], o[4], o[4]), CFrame.new(o[1], o[2], o[3]), Color3.fromRGB(40 + i * 6, 100 + i * 8, 50), Enum.Material.Grass, Enum.PartType.Ball)
	end
	for k = 0, 3 do
		local a = k * math.pi / 2
		oval(m, "Root", Vector3.new(0.5, 0.4, 1.6), CFrame.new(math.cos(a) * 0.7, 0.2, math.sin(a) * 0.7) * CFrame.Angles(0, -a, 0), Color3.fromRGB(80, 54, 36), Enum.Material.Wood)
	end
end

function B.bench(m, r)
	-- park bench: cast iron sides with armrests, slatted seat and back
	local wood = Color3.fromRGB(130, 90, 55)
	for i = 0, 2 do
		part(m, "Plank", Vector3.new(6, 0.25, 0.5), CFrame.new(0, 1.8, -0.6 + i * 0.6), wood, Enum.Material.WoodPlanks)
	end
	for i = 0, 1 do
		part(m, "BackPlank", Vector3.new(6, 0.45, 0.2), CFrame.new(0, 2.6 + i * 0.7, -1.15 - i * 0.1) * CFrame.Angles(-0.2, 0, 0), wood, Enum.Material.WoodPlanks)
	end
	for _, x in ipairs({ -2.7, 2.7 }) do
		part(m, "Leg", Vector3.new(0.3, 1.8, 0.3), CFrame.new(x, 0.9, 0.6), DARK, Enum.Material.Metal)
		part(m, "Leg", Vector3.new(0.3, 3.8, 0.3), CFrame.new(x, 1.9, -1.1) * CFrame.Angles(-0.12, 0, 0), DARK, Enum.Material.Metal)
		part(m, "SeatRail", Vector3.new(0.2, 0.3, 2), CFrame.new(x, 1.6, -0.2), DARK, Enum.Material.Metal)
		part(m, "Armrest", Vector3.new(0.35, 0.25, 1.9), CFrame.new(x, 2.7, -0.15), DARK, Enum.Material.Metal)
		cyl(m, "ArmScroll", 0.36, 0.5, CFrame.new(x, 2.55, 0.75) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, 0, 0), DARK, Enum.Material.Metal)
	end
end

function B.streetlamp(m, r)
	-- old-town street lamp: fluted base, cast pole, glass lantern with a roof
	local iron = Color3.fromRGB(30, 34, 32)
	cyl(m, "Base", 1, 1.6, CFrame.new(0, 0.5, 0), iron, Enum.Material.Metal)
	cyl(m, "BaseRing", 0.3, 1.2, CFrame.new(0, 1.15, 0), iron, Enum.Material.Metal)
	cyl(m, "Pole", 10, 0.45, CFrame.new(0, 6.3, 0), iron, Enum.Material.Metal)
	cyl(m, "PoleRing", 0.25, 0.7, CFrame.new(0, 4, 0), iron, Enum.Material.Metal)
	part(m, "CrossArm", Vector3.new(1.8, 0.2, 0.2), CFrame.new(0, 10.4, 0), iron, Enum.Material.Metal)
	local head = part(m, "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(0, 12.2, 0), WARM, Enum.Material.Neon)
	for _, x in ipairs({ -0.75, 0.75 }) do
		for _, z in ipairs({ -0.75, 0.75 }) do
			part(m, "Frame", Vector3.new(0.12, 2, 0.12), CFrame.new(x, 12.2, z), iron, Enum.Material.Metal)
		end
	end
	New("WedgePart", { Name = "LampRoof", Size = Vector3.new(2, 0.8, 1), CFrame = CFrame.new(0, 13.6, 0.5) * CFrame.Angles(0, math.pi, 0), Color = iron, Material = Enum.Material.Metal, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	New("WedgePart", { Name = "LampRoof", Size = Vector3.new(2, 0.8, 1), CFrame = CFrame.new(0, 13.6, -0.5), Color = iron, Material = Enum.Material.Metal, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	part(m, "Finial", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, 14.2, 0), iron, Enum.Material.Metal)
	New("PointLight", { Range = 20, Brightness = 1.2, Color = WARM, Shadows = false, Parent = head })
end

------------------------------------------------------------------ new instruments
function B.acoustic(m, r)
	-- acoustic corner: stool, mic stand, acoustic guitar on a stand, a small rug
	cyl(m, "Rug", 0.1, 7, CFrame.new(0, 0.05, 0), Color3.fromRGB(120, 50, 40), Enum.Material.Fabric)
	cyl(m, "StoolSeat", 0.35, 1.35, CFrame.new(0, 3.2, 0), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	for _, a in ipairs({ 0.3, 1.87, 3.44, 5.01 }) do
		tube(m, Vector3.new(math.cos(a) * 0.45, 3.05, math.sin(a) * 0.45), Vector3.new(math.cos(a) * 0.9, 0.05, math.sin(a) * 0.9), 0.14, Color3.fromRGB(110, 70, 40)).Material = Enum.Material.Wood
	end
	cyl(m, "Footrest", 0.12, 1.5, CFrame.new(0, 1.2, 0), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	cyl(m, "MicFoot", 0.2, 1.6, CFrame.new(0, 0.12, 2.2), DARK)
	tube(m, Vector3.new(0, 0.2, 2.2), Vector3.new(0, 4.8, 2.2), 0.14, METAL)
	tube(m, Vector3.new(0, 4.8, 2.2), Vector3.new(0, 5.4, 1.2), 0.1, METAL)
	oval(m, "Mic", Vector3.new(0.35, 0.35, 0.8), CFrame.new(0, 5.5, 0.9) * CFrame.Angles(-0.4, 0, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	-- acoustic guitar: bigger rounded body, round sound hole, bridge
	local g = CFrame.new(2.4, 2.6, 0.2) * CFrame.Angles(-0.12, 0, 0)
	oval(m, "Body", Vector3.new(2.6, 2.1, 0.8), g * CFrame.new(0, -0.6, 0), Color3.fromRGB(210, 160, 100), Enum.Material.Wood)
	oval(m, "Body", Vector3.new(2.1, 1.7, 0.8), g * CFrame.new(0, 0.75, 0), Color3.fromRGB(210, 160, 100), Enum.Material.Wood)
	cyl(m, "SoundHole", 0.1, 0.7, g * CFrame.new(0, 0.2, 0.36) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(30, 20, 14))
	part(m, "Bridge", Vector3.new(0.9, 0.18, 0.1), g * CFrame.new(0, -0.8, 0.4), Color3.fromRGB(40, 26, 18), Enum.Material.Wood)
	part(m, "Neck", Vector3.new(0.3, 3, 0.2), g * CFrame.new(0, 2.6, 0.05), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	part(m, "Headstock", Vector3.new(0.45, 0.8, 0.12), g * CFrame.new(0, 4.4, 0.035), Color3.fromRGB(60, 40, 26), Enum.Material.Wood)
	for _, a in ipairs({ 0.6, 2.55, 4.5 }) do
		tube(m, Vector3.new(2.4, 1.1, 0), Vector3.new(2.4 + math.cos(a) * 0.9, 0.05, math.sin(a) * 0.9), 0.08, METAL)
	end
	part(m, "Cradle", Vector3.new(1.8, 0.2, 0.5), CFrame.new(2.4, 1.15, 0.2), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
end

function B.upright_bass(m, r)
	-- double bass on its side stand: big violin body, f-holes, long neck, scroll, end pin
	local wood = Color3.fromRGB(150, 70, 30)
	local c = CFrame.new(0, 0, 0)
	oval(m, "LowerBout", Vector3.new(3.4, 2.8, 1.3), c * CFrame.new(0, 2.4, 0), wood, Enum.Material.Wood)
	oval(m, "UpperBout", Vector3.new(2.7, 2.4, 1.2), c * CFrame.new(0, 4.6, 0), wood, Enum.Material.Wood)
	oval(m, "Waist", Vector3.new(2.2, 1.6, 1.2), c * CFrame.new(0, 3.5, 0), wood, Enum.Material.Wood)
	for _, x in ipairs({ -0.5, 0.5 }) do
		part(m, "FHole", Vector3.new(0.12, 1.1, 0.05), c * CFrame.new(x, 3.4, 0.62), Color3.fromRGB(20, 12, 8))
	end
	part(m, "Bridge", Vector3.new(1, 0.6, 0.12), c * CFrame.new(0, 2.9, 0.68), Color3.fromRGB(220, 200, 160), Enum.Material.Wood)
	part(m, "Tailpiece", Vector3.new(0.5, 1.1, 0.1), c * CFrame.new(0, 1.8, 0.66), Color3.fromRGB(20, 20, 20))
	part(m, "Fingerboard", Vector3.new(0.4, 4.6, 0.2), c * CFrame.new(0, 6.3, 0.55), Color3.fromRGB(20, 18, 16), Enum.Material.Wood)
	part(m, "Neck", Vector3.new(0.35, 3.4, 0.4), c * CFrame.new(0, 7.4, 0.3), wood, Enum.Material.Wood)
	part(m, "Pegbox", Vector3.new(0.45, 1.2, 0.5), c * CFrame.new(0, 9.5, 0.2), wood, Enum.Material.Wood)
	cyl(m, "Scroll", 0.5, 0.6, c * CFrame.new(0, 10.3, 0.2) * CFrame.Angles(0, 0, -math.pi / 2), wood, Enum.Material.Wood)
	part(m, "Strings", Vector3.new(0.3, 7.6, 0.02), c * CFrame.new(0, 5.6, 0.765), Color3.fromRGB(200, 200, 205), Enum.Material.Metal).Transparency = 0.4
	part(m, "EndPin", Vector3.new(0.1, 1.1, 0.1), c * CFrame.new(0, 0.55, 0), METAL, Enum.Material.Metal)
	tube(m, Vector3.new(-1.2, 0, -1), Vector3.new(-0.6, 4.6, -0.5), 0.12, METAL)
	tube(m, Vector3.new(1.2, 0, -1), Vector3.new(0.6, 4.6, -0.5), 0.12, METAL)
end

function B.harp(m, r)
	-- concert harp at the size of a person (about 6 studs). The strings lie in the Y-Z plane: the
	-- harpist sits behind it (-Z) with the sound box leaning on the shoulder, the column stands at the front.
	local gold = Color3.fromRGB(214, 172, 66)
	local wood = Color3.fromRGB(120, 64, 30)
	local board = Color3.fromRGB(214, 170, 112)
	local function V(z, y)
		return Vector3.new(0, y, z)
	end
	local function rod(name, a, b, d, color, mat)
		local t = tube(m, a, b, d, color)
		if t then
			t.Name = name
			t.Material = mat or Enum.Material.SmoothPlastic
		end
		return t
	end
	-- pedestal with the seven pedals on the harpist's side
	part(m, "Base", Vector3.new(1.5, 0.5, 2.8), CFrame.new(0, 0.25, 0.5), wood, Enum.Material.Wood)
	part(m, "BaseTrim", Vector3.new(1.6, 0.12, 2.9), CFrame.new(0, 0.56, 0.5), gold, Enum.Material.Metal)
	for k = 0, 6 do
		part(m, "Pedal", Vector3.new(0.12, 0.08, 0.45), CFrame.new(-0.6 + k * 0.2, 0.12, -1.05), gold, Enum.Material.Metal)
	end
	-- the column at the front with its crown
	rod("Column", V(1.5, 0.6), V(1.5, 6.0), 0.42, gold, Enum.Material.Metal)
	for _, y in ipairs({ 1.0, 5.6 }) do
		cyl(m, "ColumnRing", 0.18, 0.56, CFrame.new(0, y, 1.5), gold, Enum.Material.Metal)
	end
	oval(m, "Crown", Vector3.new(0.7, 0.55, 0.7), CFrame.new(0, 6.2, 1.5), gold, Enum.Material.Metal)
	-- the sound box: from the pedestal up to the harpist's shoulder, wider at the bottom
	local sb0, sb1 = V(0.9, 0.6), V(-0.9, 4.9)
	local dir = (sb1 - sb0).Unit
	local len = (sb1 - sb0).Magnitude
	local back = Vector3.new(0, -dir.Z, dir.Y) * -1 -- points away from the strings (down/back)
	for i = 0, 3 do
		local f0, f1 = i / 4, (i + 1) / 4
		local c = sb0 + dir * len * (f0 + f1) / 2 + back * 0.22
		local wdt = 1.05 - i * 0.18
		part(m, "SoundBox", Vector3.new(wdt, 0.55, len / 4 + 0.02), CFrame.lookAt(c, c + dir), wood, Enum.Material.Wood)
	end
	part(m, "SoundBoard", Vector3.new(0.5, 0.06, len), CFrame.lookAt(sb0 + dir * len / 2 - back * 0.06, sb0 + dir * len / 2 - back * 0.06 + dir), board, Enum.Material.Wood)
	-- the curved neck from the top of the sound box to the crown (an S shape)
	local neck = { V(-0.9, 4.9), V(-0.45, 5.45), V(0.15, 5.4), V(0.75, 5.55), V(1.2, 5.9), V(1.5, 6.05) }
	for i = 2, #neck do
		rod("Neck", neck[i - 1], neck[i], 0.34, gold, Enum.Material.Metal)
	end
	local function neckY(z)
		for i = 2, #neck do
			local a, b = neck[i - 1], neck[i]
			if z >= a.Z and z <= b.Z then
				return a.Y + (b.Y - a.Y) * (z - a.Z) / (b.Z - a.Z)
			end
		end
		return neck[#neck].Y
	end
	-- strings: from the sound board up to the neck; C strings red, F strings dark blue
	local n = 22
	for k = 0, n - 1 do
		local z = -0.72 + k * (1.55 / (n - 1))
		local yb = sb0.Y + (sb0.Z - z) / (sb0.Z - sb1.Z) * (sb1.Y - sb0.Y)
		if z > sb0.Z then
			yb = sb0.Y
		end
		local yt = neckY(z) - 0.12
		local col = (k % 7 == 0) and Color3.fromRGB(200, 40, 40) or ((k % 7 == 3) and Color3.fromRGB(40, 60, 140) or Color3.fromRGB(240, 235, 220))
		part(m, "String", Vector3.new(0.035, math.max(0.2, yt - yb), 0.035), CFrame.new(0, (yt + yb) / 2, z), col)
	end
	-- the harpist's stool
	cyl(m, "Stool", 0.3, 1.4, CFrame.new(0, 2.05, -2.2), Color3.fromRGB(110, 30, 40), Enum.Material.Fabric)
	cyl(m, "StoolLeg", 1.9, 0.26, CFrame.new(0, 0.95, -2.2), gold, Enum.Material.Metal)
	cyl(m, "StoolFoot", 0.12, 1.0, CFrame.new(0, 0.06, -2.2), gold, Enum.Material.Metal)
end

function B.strings(m, r)
	-- string section: four chairs with music stands, two violins/violas and two cellos
	local wood = Color3.fromRGB(150, 75, 32)
	for i = 0, 3 do
		local x = -4.8 + i * 3.2
		local base = CFrame.new(x, 0, 0) * CFrame.Angles(0, (i - 1.5) * -0.15, 0)
		part(m, "ChairSeat", Vector3.new(1.6, 0.25, 1.6), base * CFrame.new(0, 1.8, 0), Color3.fromRGB(30, 30, 34))
		part(m, "ChairBack", Vector3.new(1.6, 1.6, 0.2), base * CFrame.new(0, 2.7, -0.75), Color3.fromRGB(30, 30, 34))
		for _, lx in ipairs({ -0.65, 0.65 }) do
			for _, lz in ipairs({ -0.65, 0.65 }) do
				cyl(m, "ChairLeg", 1.7, 0.15, base * CFrame.new(lx, 0.85, lz), METAL, Enum.Material.Metal)
			end
		end
		-- music stand
		tube(m, (base * CFrame.new(0, 0, 2.2)).Position, (base * CFrame.new(0, 3.8, 2.2)).Position, 0.1, DARK)
		part(m, "Desk", Vector3.new(1.8, 1.2, 0.08), base * CFrame.new(0, 4.2, 2.1) * CFrame.Angles(0.35, 0, 0), DARK)
		part(m, "Sheet", Vector3.new(1.4, 0.9, 0.04), base * CFrame.new(0, 4.25, 2.05) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(245, 240, 225))
		if i < 2 then
			-- violin resting on the chair
			oval(m, "Violin", Vector3.new(0.75, 1.5, 0.3), base * CFrame.new(0.2, 2.15, 0.1) * CFrame.Angles(math.pi / 2, 0, 0.3), wood, Enum.Material.Wood)
			part(m, "ViolinNeck", Vector3.new(0.12, 1.1, 0.12), base * CFrame.new(0.5, 2.1, 1.1) * CFrame.Angles(math.pi / 2, 0, 0.3), Color3.fromRGB(30, 22, 16))
		else
			-- cello standing next to the chair
			local c = base * CFrame.new(0.9, 0, 0.6) * CFrame.Angles(-0.25, 0, 0)
			oval(m, "Cello", Vector3.new(1.7, 1.6, 0.7), c * CFrame.new(0, 1.4, 0), wood, Enum.Material.Wood)
			oval(m, "Cello", Vector3.new(1.4, 1.3, 0.65), c * CFrame.new(0, 2.6, 0), wood, Enum.Material.Wood)
			part(m, "CelloNeck", Vector3.new(0.2, 2.2, 0.2), c * CFrame.new(0, 4.2, 0.2), Color3.fromRGB(30, 22, 16))
			part(m, "CelloPin", Vector3.new(0.08, 0.8, 0.08), c * CFrame.new(0, 0.4, 0), METAL, Enum.Material.Metal)
		end
	end
end

function B.horns(m, r)
	-- horn section: trumpet, saxophone and trombone on stands, music stands with little lamps
	local brass = Color3.fromRGB(220, 175, 70)
	-- trumpet on a cone stand
	tube(m, Vector3.new(-3.5, 0, 0), Vector3.new(-3.5, 2.2, 0), 0.4, DARK)
	cyl(m, "TrumpetPipe", 2.2, 0.2, CFrame.new(-3.5, 2.6, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0, 0, 0), brass, Enum.Material.Metal)
	cyl(m, "TrumpetBell", 0.6, 0.9, CFrame.new(-3.5, 3.9, 0), brass, Enum.Material.Metal)
	part(m, "Valves", Vector3.new(0.6, 0.6, 0.25), CFrame.new(-3.3, 2.4, 0), brass, Enum.Material.Metal)
	-- saxophone: curved body with a bell
	local sax = CFrame.new(0, 0, 0)
	tube(m, (sax * CFrame.new(0, 0.3, 0)).Position, (sax * CFrame.new(0, 1.2, 0)).Position, 0.15, DARK)
	cyl(m, "SaxBody", 3, 0.5, sax * CFrame.new(0, 3.1, 0), brass, Enum.Material.Metal)
	oval(m, "SaxBow", Vector3.new(1, 0.8, 0.6), sax * CFrame.new(0.3, 1.5, 0), brass, Enum.Material.Metal)
	cyl(m, "SaxBell", 0.9, 0.95, sax * CFrame.new(0.65, 2.3, 0), brass, Enum.Material.Metal)
	tube(m, (sax * CFrame.new(0, 4.6, 0)).Position, (sax * CFrame.new(-0.5, 5.1, 0)).Position, 0.15, brass)
	-- trombone standing on its bell
	cyl(m, "TromboneBell", 0.8, 1.2, CFrame.new(3.5, 0.4, 0), brass, Enum.Material.Metal)
	tube(m, Vector3.new(3.5, 0.8, 0), Vector3.new(3.5, 5, 0), 0.15, brass)
	tube(m, Vector3.new(3.85, 0.8, 0), Vector3.new(3.85, 5.4, 0), 0.12, brass)
	part(m, "SlideEnd", Vector3.new(0.5, 0.15, 0.15), CFrame.new(3.68, 5.45, 0), brass, Enum.Material.Metal)
	for _, x in ipairs({ -3.5, 0, 3.5 }) do
		tube(m, Vector3.new(x, 0, 2), Vector3.new(x, 3.8, 2), 0.1, DARK)
		part(m, "Desk", Vector3.new(1.8, 1.2, 0.08), CFrame.new(x, 4.2, 1.9) * CFrame.Angles(0.35, 0, 0), DARK)
		part(m, "DeskLamp", Vector3.new(1, 0.15, 0.15), CFrame.new(x, 4.85, 1.75), WARM, Enum.Material.Neon)
	end
end

function B.choir(m, r)
	-- curved three-step choir riser with a carpet and a front rail
	for k = 0, 2 do
		local R = 8 + k * 2.2
		for i = 0, 6 do
			local a = math.rad(-48 + i * 16)
			local cf = CFrame.new(math.sin(a) * R, (k + 1) * 0.6, -math.cos(a) * R + 8) * CFrame.Angles(0, -a, 0)
			part(m, "Step", Vector3.new(R * 0.29 + (i % 2) * 0.05, (k + 1) * 1.2 + (i % 2) * 0.04, 2.2), cf, Color3.fromRGB(40, 40, 46), Enum.Material.Fabric)
		end
	end
	r.neon = {}
	for i = 0, 6 do
		local a = math.rad(-48 + i * 16)
		table.insert(r.neon, part(m, "EdgeLight", Vector3.new(2.4, 0.15, 0.15), CFrame.new(math.sin(a) * 6.95, 0.1 + (i % 2) * 0.05, -math.cos(a) * 6.95 + 8) * CFrame.Angles(0, -a, 0), r.color, Enum.Material.Neon))
	end
end

------------------------------------------------------------------ new set pieces
function B.throne(m, r)
	-- royal throne on a dais: high carved back, armrests, velvet cushions, gold trim
	local gold = Color3.fromRGB(214, 172, 66)
	local velvet = r.color:Lerp(Color3.fromRGB(120, 10, 30), 0.6)
	cyl(m, "Dais", 1.2, 9, CFrame.new(0, 0.6, 0), Color3.fromRGB(40, 20, 30), Enum.Material.Fabric)
	arcTube(m, "DaisTrim", CFrame.new(0, 1.2, 0) * CFrame.Angles(math.pi / 2, 0, 0), 4.5, 0, math.pi * 2, 20, 0.3, gold, Enum.Material.Metal)
	part(m, "Seat", Vector3.new(4.4, 1.6, 3.6), CFrame.new(0, 2, 0), gold, Enum.Material.Metal)
	part(m, "Cushion", Vector3.new(3.8, 0.6, 3.2), CFrame.new(0, 3.1, 0.1), velvet, Enum.Material.Fabric)
	part(m, "Back", Vector3.new(4.4, 7, 0.8), CFrame.new(0, 6.3, -1.5), gold, Enum.Material.Metal)
	part(m, "BackPad", Vector3.new(3.4, 5.6, 0.2), CFrame.new(0, 6, -1.05), velvet, Enum.Material.Fabric)
	oval(m, "Crest", Vector3.new(3, 2.2, 0.8), CFrame.new(0, 10.2, -1.5), gold, Enum.Material.Metal)
	part(m, "Gem", Vector3.new(0.8, 0.8, 0.3), CFrame.new(0, 10.2, -1.05), r.color, Enum.Material.Neon)
	for _, x in ipairs({ -2.4, 2.4 }) do
		part(m, "Arm", Vector3.new(0.6, 1.2, 3.4), CFrame.new(x, 3.6, 0), gold, Enum.Material.Metal)
		part(m, "Post", Vector3.new(0.7, 8.6, 0.7), CFrame.new(x, 5.4, -1.5), gold, Enum.Material.Metal)
		part(m, "PostBall", Vector3.new(1, 1, 1), CFrame.new(x, 10, -1.5), gold, Enum.Material.Metal, Enum.PartType.Ball)
	end
end

function B.hand(m, r)
	-- giant hand rising out of the stage, palm up (the artist can stand on it)
	local skin = Color3.fromRGB(200, 200, 210)
	oval(m, "Wrist", Vector3.new(5, 8, 4), CFrame.new(0, 3, 0), skin, Enum.Material.Foil)
	oval(m, "Palm", Vector3.new(8, 3, 9), CFrame.new(0, 7.4, 1), skin, Enum.Material.Foil)
	for i = 0, 3 do
		local x = -2.7 + i * 1.8
		local len = 4.6 - math.abs(i - 1.5) * 0.6
		oval(m, "Finger", Vector3.new(1.5, 1.5, len), CFrame.new(x, 8.6, 5 + len / 2) * CFrame.Angles(0.5, 0, 0), skin, Enum.Material.Foil)
		oval(m, "FingerTip", Vector3.new(1.4, 1.4, len * 0.6), CFrame.new(x, 10.6, 7.6 + len * 0.6) * CFrame.Angles(1.1, 0, 0), skin, Enum.Material.Foil)
	end
	oval(m, "Thumb", Vector3.new(1.8, 1.8, 4.2), CFrame.new(-4.6, 8, 1.4) * CFrame.Angles(0.3, 0.9, 0.4), skin, Enum.Material.Foil)
	r.neon = { cyl(m, "Ring", 0.6, 6, CFrame.new(0, 0.3, 0), r.color, Enum.Material.Neon) }
end

function B.swing(m, r)
	-- swing frame: two A-frames of truss, a top bar, ropes and a seat that sways during the show
	for _, x in ipairs({ -5, 5 }) do
		tube(m, Vector3.new(x, 0, -3), Vector3.new(x, 16, 0), 0.5, METAL)
		tube(m, Vector3.new(x, 0, 3), Vector3.new(x, 16, 0), 0.5, METAL)
		part(m, "Foot", Vector3.new(1.2, 0.4, 7), CFrame.new(x, 0.2, 0), DARK)
	end
	cyl(m, "TopBar", 10.6, 0.6, CFrame.new(0, 16, 0) * CFrame.Angles(0, 0, -math.pi / 2), METAL, Enum.Material.Metal)
	r.swingParts = {}
	local function sp(p, off)
		table.insert(r.swingParts, { p, off })
		return p
	end
	sp(part(m, "Rope", Vector3.new(0.12, 12, 0.12), CFrame.new(-1.6, 10, 0), Color3.fromRGB(220, 200, 160), Enum.Material.Fabric), CFrame.new(-1.6, -6, 0))
	sp(part(m, "Rope", Vector3.new(0.12, 12, 0.12), CFrame.new(1.6, 10, 0), Color3.fromRGB(220, 200, 160), Enum.Material.Fabric), CFrame.new(1.6, -6, 0))
	sp(part(m, "Seat", Vector3.new(4, 0.3, 1.4), CFrame.new(0, 4, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Wood), CFrame.new(0, -12, 0))
	r.flowers = {}
	for k = 0, 8 do
		sp(part(m, "Garland", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0, 0), (k % 2 == 0) and r.color or Color3.fromRGB(255, 255, 255), Enum.Material.Neon, Enum.PartType.Ball), CFrame.new((k % 2 == 0) and -1.6 or 1.6, -1 - math.floor(k / 2) * 2.4, 0.1))
	end
	r.swingTop = CFrame.new(0, 16, 0)
	Builder.swingPose(r, 0)
end
function Builder.swingPose(r, a)
	for _, sp in ipairs(r.swingParts) do
		sp[1].CFrame = r.cf * r.swingTop * CFrame.Angles(a, 0, 0) * sp[2]
	end
end

function B.ferris(m, r)
	-- small Ferris wheel with lit spokes and gondolas that turn slowly
	part(m, "Base", Vector3.new(12, 1, 6), CFrame.new(0, 0.5, 0), DARK)
	for _, z in ipairs({ -1.8, 1.8 }) do
		tube(m, Vector3.new(-5, 1, z), Vector3.new(0, 14, z), 0.6, Color3.fromRGB(230, 230, 236))
		tube(m, Vector3.new(5, 1, z), Vector3.new(0, 14, z), 0.6, Color3.fromRGB(230, 230, 236))
	end
	cyl(m, "Axle", 4.2, 1.2, CFrame.new(0, 14, 0) * CFrame.Angles(0, math.pi / 2, 0), METAL, Enum.Material.Metal)
	r.wheelParts = {}
	local R = 11
	for i = 0, 15 do
		local a0, a1 = i * math.pi / 8, (i + 1) * math.pi / 8
		local mid = (a0 + a1) / 2
		local seg = 2 * R * math.sin(math.pi / 16) + 0.4
		table.insert(r.wheelParts, { part(m, "Rim", Vector3.new(seg, 0.6, 0.6), CFrame.new(), r.color, Enum.Material.Neon, Enum.PartType.Cylinder), CFrame.Angles(0, 0, mid) * CFrame.new(R * math.cos(math.pi / 16), 0, 0) * CFrame.Angles(0, 0, math.pi / 2) })
	end
	for i = 0, 7 do
		local a = i * math.pi / 4
		table.insert(r.wheelParts, { part(m, "Spoke", Vector3.new(R, 0.25, 0.25), CFrame.new(), Color3.fromRGB(240, 240, 245), Enum.Material.Neon), CFrame.new(0, 0, (i % 4) * 0.06) * CFrame.Angles(0, 0, a) * CFrame.new(R / 2, 0, 0) })
	end
	r.cabins = {}
	for i = 0, 7 do
		local cab = part(m, "Gondola", Vector3.new(2.2, 2, 2), CFrame.new(), (i % 2 == 0) and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(80, 200, 255))
		local roof = part(m, "GondolaRoof", Vector3.new(2.6, 0.3, 2.4), CFrame.new(), Color3.fromRGB(240, 240, 245))
		table.insert(r.cabins, { cab, roof, i * math.pi / 4 })
	end
	r.wheelA = 0
	Builder.ferrisPose(r)
end
function Builder.ferrisPose(r)
	local hub = r.cf * CFrame.new(0, 14, 0)
	for _, wp in ipairs(r.wheelParts) do
		wp[1].CFrame = hub * CFrame.Angles(0, 0, r.wheelA) * wp[2]
	end
	for _, c in ipairs(r.cabins) do
		local a = c[3] + r.wheelA
		local p = hub * CFrame.new(math.cos(a) * 11, math.sin(a) * 11 - 1.6, 0)
		c[1].CFrame = p
		c[2].CFrame = p * CFrame.new(0, 1.2, 0)
	end
end

function B.rocket(m, r)
	-- retro rocket on a launch pad: round body, nose cone, fins, porthole; smoke on the big moments
	part(m, "Pad", Vector3.new(10, 1, 10), CFrame.new(0, 0.5, 0), Color3.fromRGB(80, 80, 86), Enum.Material.DiamondPlate)
	cyl(m, "Body", 14, 4, CFrame.new(0, 9, 0), Color3.fromRGB(235, 235, 240), Enum.Material.Metal)
	cyl(m, "Band", 1.2, 4.1, CFrame.new(0, 12, 0), r.color, Enum.Material.SmoothPlastic)
	for k = 0, 3 do
		cyl(m, "Nose", 1.2, 3.6 - k * 0.85, CFrame.new(0, 16.6 + k * 1.1, 0), r.color, Enum.Material.SmoothPlastic)
	end
	part(m, "Tip", Vector3.new(0.4, 1.2, 0.4), CFrame.new(0, 21.4, 0), METAL, Enum.Material.Metal)
	cyl(m, "Porthole", 0.3, 1.6, CFrame.new(0, 13.5, 2) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(150, 220, 255), Enum.Material.Neon)
	cyl(m, "PortRing", 0.25, 1.9, CFrame.new(0, 13.5, 1.95) * CFrame.Angles(math.pi / 2, 0, 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	for k = 0, 3 do
		local a = k * math.pi / 2
		New("WedgePart", { Name = "Fin", Size = Vector3.new(0.4, 5, 3), CFrame = CFrame.new(math.cos(a) * 3, 4, math.sin(a) * 3) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = r.color, Material = Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
	end
	cyl(m, "Nozzle", 1.5, 2.6, CFrame.new(0, 1.6, 0), DARK)
	r.nozzle = part(m, "Exhaust", Vector3.new(1, 1, 1), CFrame.new(0, 1, 0), DARK)
	r.nozzle.Transparency = 1
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Texture = TEX_SMOKE,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(10, 18),
		SpreadAngle = Vector2.new(80, 80),
		Size = NumberSequence.new(3, 12),
		Transparency = NumberSequence.new(0.2, 1),
		Color = ColorSequence.new(Color3.fromRGB(240, 240, 245)),
		EmissionDirection = Enum.NormalId.Bottom,
		Drag = 1,
		Parent = r.nozzle,
	})
	r.flame = New("ParticleEmitter", {
		Enabled = false,
		Rate = 0,
		Texture = TEX_FIRE,
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(14, 20),
		SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new(2, 0.5),
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 0)),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Bottom,
		Parent = r.nozzle,
	})
end

function B.fountain(m, r)
	-- stage fountain: round basin with a lit rim, water jets that dance with the music
	cyl(m, "Basin", 1.6, 10, CFrame.new(0, 0.8, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Marble)
	cyl(m, "Water", 0.2, 9, CFrame.new(0, 1.55, 0), Color3.fromRGB(60, 140, 200), Enum.Material.Glass).Transparency = 0.2
	r.neon = arcTube(m, "RimLight", CFrame.new(0, 1.65, 0) * CFrame.Angles(math.pi / 2, 0, 0), 4.95, 0, math.pi * 2, 20, 0.3, r.color, Enum.Material.Neon)
	cyl(m, "Column", 3, 1.2, CFrame.new(0, 3, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Marble)
	cyl(m, "Bowl", 0.6, 4, CFrame.new(0, 4.6, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Marble)
	r.nozzle = part(m, "Jet", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 5, 0), Color3.fromRGB(200, 200, 205))
	r.emitter = New("ParticleEmitter", {
		Enabled = false,
		Rate = 140,
		Lifetime = NumberRange.new(1, 1.4),
		Speed = NumberRange.new(18, 24),
		SpreadAngle = Vector2.new(14, 14),
		Size = NumberSequence.new(0.6, 0.2),
		Transparency = NumberSequence.new(0.2, 0.8),
		Color = ColorSequence.new(Color3.fromRGB(200, 230, 255)),
		LightEmission = 0.4,
		Acceleration = Vector3.new(0, -40, 0),
		Parent = r.nozzle,
	})
end

function B.lighthouse(m, r)
	-- striped lighthouse with a gallery and a lamp room whose beam sweeps over the crowd
	for k = 0, 5 do
		cyl(m, "Tower", 3.4, 6 - k * 0.45, CFrame.new(0, 1.7 + k * 3.4, 0), (k % 2 == 0) and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(200, 30, 40))
	end
	cyl(m, "Gallery", 0.5, 5.4, CFrame.new(0, 20.6, 0), DARK)
	for k = 0, 9 do
		local a = k * math.pi / 5
		part(m, "Railing", Vector3.new(0.12, 1.2, 0.12), CFrame.new(math.cos(a) * 2.6, 21.4, math.sin(a) * 2.6), DARK, Enum.Material.Metal)
	end
	cyl(m, "LampRoom", 2.6, 2.8, CFrame.new(0, 22.2, 0), Color3.fromRGB(255, 240, 200), Enum.Material.Neon).Transparency = 0.3
	for k = 0, 3 do
		cyl(m, "Roof", 0.7, 3.4 - k * 0.8, CFrame.new(0, 23.8 + k * 0.6, 0), DARK)
	end
	r.headLocal = CFrame.new(0, 22.2, 0)
	r.head = part(m, "Lamp", Vector3.new(0.4, 0.4, 0.4), r.headLocal, WARM)
	r.head.Transparency = 1
	r.beam = beam(r.head, Vector3.new(0, 0, 0), Vector3.new(0, -4, -90), 2, 14, Color3.fromRGB(255, 240, 200), 0.55)
	part(m, "Door", Vector3.new(1.4, 2.6, 0.2), CFrame.new(0, 1.3, 3), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
end

function B.cloud(m, r)
	-- fluffy cloud hanging in the rig, glowing softly from inside, bobbing gently
	r.cloudParts = {}
	local blobs = { { 0, 0, 0, 7 }, { 4, -0.5, 0.5, 5.5 }, { -4, -0.6, -0.3, 5.6 }, { 1.8, 1.8, 0, 5 }, { -2, 1.5, 0.4, 4.6 }, { 6.6, -1, 0, 3.8 }, { -6.6, -1, 0, 3.6 } }
	for _, b in ipairs(blobs) do
		local p = part(m, "Cloud", Vector3.new(b[4], b[4], b[4]), CFrame.new(b[1], -8 + b[2], b[3]), Color3.fromRGB(245, 245, 250), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		table.insert(r.cloudParts, { p, p.CFrame })
	end
	r.glow = part(m, "CloudGlow", Vector3.new(9, 4, 4), CFrame.new(0, -8.5, 0), r.color, Enum.Material.Neon)
	r.glow.Transparency = 0.5
	table.insert(r.cloudParts, { r.glow, r.glow.CFrame })
	part(m, "Wire", Vector3.new(0.06, 4, 0.06), CFrame.new(-2, -2, 0), METAL)
	part(m, "Wire", Vector3.new(0.06, 4, 0.06), CFrame.new(2, -2, 0), METAL)
end

function B.rainbow(m, r)
	-- rainbow arch of seven round tubes in neon colours
	local w = dims(r, r.def)
	local cols = { Color3.fromRGB(255, 50, 60), Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 220, 50), Color3.fromRGB(80, 220, 90), Color3.fromRGB(50, 170, 255), Color3.fromRGB(80, 90, 230), Color3.fromRGB(170, 80, 230) }
	r.bands = {}
	for i, c in ipairs(cols) do
		local R = w / 2 - (i - 1) * 1.1
		local parts = arcTube(m, "Rainbow", CFrame.new(0, 0, 0), R, 0, math.pi, math.clamp(math.floor(R * 0.9), 10, 36), 1.05, c, Enum.Material.Neon)
		table.insert(r.bands, parts)
	end
	for _, x in ipairs({ -w / 2 + 3.3, w / 2 - 3.3 }) do
		oval(m, "CloudFoot", Vector3.new(9, 4, 5), CFrame.new(x, 1.5, 0), Color3.fromRGB(245, 245, 250))
	end
end

------------------------------------------------------------------ big backdrops (resizable: width, and height with the top handle)
local FABRIC = Color3.fromRGB(34, 34, 40)
-- a pipe at the top and weighted feet at the bottom, as backdrops hang on stage
local function backdropFrame(m, w, hh)
	part(m, "Pipe", Vector3.new(w + 0.6, 0.35, 0.35), CFrame.new(0, hh + 0.2, 0), METAL, Enum.Material.Metal)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		part(m, "Upright", Vector3.new(0.3, hh + 0.4, 0.3), CFrame.new(x, hh / 2 + 0.2, -0.3), METAL, Enum.Material.Metal)
		part(m, "Foot", Vector3.new(1.2, 0.3, 2.4), CFrame.new(x, 0.15, -0.3), DARK, Enum.Material.Metal)
	end
end
function B.backdrop(m, r)
	-- plain stage cloth with soft vertical folds; the stage lights tint it with the song colours
	local w, hh = dims(r, r.def)
	backdropFrame(m, w, hh)
	r.folds = {}
	local n = math.max(2, math.floor(w / 2.4))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		local shade = (i % 2 == 0) and 1 or 0.86
		local fh = hh - (i % 2) * 0.06 -- the folds overlap a little: different heights and depths
		local p = part(m, "Cloth", Vector3.new(w / n + 0.05, fh, 0.3), CFrame.new(x, fh / 2 + 0.2, (i % 2 == 0) and 0 or 0.12), Color3.new(FABRIC.R * shade, FABRIC.G * shade, FABRIC.B * shade), Enum.Material.Fabric)
		table.insert(r.folds, { p, shade })
	end
end
function B.starcloth(m, r)
	-- black cloth full of tiny twinkling lights
	local w, hh = dims(r, r.def)
	backdropFrame(m, w, hh)
	part(m, "Cloth", Vector3.new(w, hh, 0.25), CFrame.new(0, hh / 2 + 0.2, 0), Color3.fromRGB(10, 10, 14), Enum.Material.Fabric)
	r.stars = {}
	local rng = Random.new(math.floor(w * 7 + hh))
	local count = math.clamp(math.floor(w * hh / 9), 12, 160)
	for _ = 1, count do
		local s = part(m, "Star", Vector3.new(0.22, 0.22, 0.1), CFrame.new(rng:NextNumber(-w / 2 + 0.4, w / 2 - 0.4), rng:NextNumber(0.8, hh - 0.2), 0.15 + (#r.stars % 4) * 0.03), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
		table.insert(r.stars, { s, rng:NextNumber() * 6.28, rng:NextNumber(1.5, 4) })
	end
end
function B.scrim(m, r)
	-- a thin white gauze: lights shine through and colour it
	local w, hh = dims(r, r.def)
	backdropFrame(m, w, hh)
	r.sheet = part(m, "Gauze", Vector3.new(w, hh, 0.1), CFrame.new(0, hh / 2 + 0.2, 0), Color3.fromRGB(235, 235, 240), Enum.Material.Fabric)
	r.sheet.Transparency = 0.45
end
function B.panelwall(m, r)
	-- a wall of square light panels in a black frame (patterns with the beat)
	local w, hh = dims(r, r.def)
	part(m, "Frame", Vector3.new(w, hh, 0.5), CFrame.new(0, hh / 2, 0), Color3.fromRGB(18, 18, 22), Enum.Material.Metal)
	r.cells = {}
	local cols, rows = math.max(1, math.floor(w / 3)), math.max(1, math.floor(hh / 3))
	local cw, ch = w / cols, hh / rows
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local c = part(m, "Panel", Vector3.new(cw - 0.5, ch - 0.5, 0.1), CFrame.new(-w / 2 + (i + 0.5) * cw, (j + 0.5) * ch, 0.28), Color3.fromRGB(230, 230, 236), Enum.Material.Neon)
			c.Transparency = 0.3
			table.insert(r.cells, { c, i, j })
		end
	end
end
function B.bulbwall(m, r)
	-- a retro wall of round light bulbs (chasers run over it)
	local w, hh = dims(r, r.def)
	part(m, "Board", Vector3.new(w, hh, 0.4), CFrame.new(0, hh / 2, 0), Color3.fromRGB(30, 24, 20), Enum.Material.Wood)
	r.bulbs = {}
	local step = math.max(2.2, math.sqrt(w * hh / 140))
	local cols, rows = math.max(1, math.floor(w / step)), math.max(1, math.floor(hh / step))
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local x, y = -w / 2 + (i + 0.5) * w / cols, (j + 0.5) * hh / rows
			part(m, "Socket", Vector3.new(0.8, 0.8, 0.2), CFrame.new(x, y, 0.28), METAL, Enum.Material.Metal)
			local b = part(m, "Bulb", Vector3.new(0.75, 0.75, 0.75), CFrame.new(x, y, 0.55), WARM, Enum.Material.Neon, Enum.PartType.Ball)
			table.insert(r.bulbs, { b, i, j })
		end
	end
end
function B.slatwall(m, r)
	-- dark wooden slats with light shining through the gaps
	local w, hh = dims(r, r.def)
	r.glow = part(m, "Backlight", Vector3.new(w, hh, 0.1), CFrame.new(0, hh / 2, -0.4), r.color, Enum.Material.Neon)
	local n = math.max(3, math.floor(w / 1.6))
	for i = 0, n - 1 do
		part(m, "Slat", Vector3.new(w / n * 0.62, hh, 0.5), CFrame.new(-w / 2 + (i + 0.5) * w / n, hh / 2, 0), Color3.fromRGB(58, 40, 28), Enum.Material.Wood)
	end
	part(m, "Top", Vector3.new(w + 0.4, 0.5, 1.2), CFrame.new(0, hh + 0.25, -0.2), Color3.fromRGB(40, 28, 20), Enum.Material.Wood)
end
function B.brickwall(m, r)
	-- an old brick wall with pillars and a ledge: a club or warehouse look
	local w, hh = dims(r, r.def)
	part(m, "Bricks", Vector3.new(w, hh, 1), CFrame.new(0, hh / 2, 0), Color3.fromRGB(140, 66, 52), Enum.Material.Brick)
	local n = math.max(1, math.floor(w / 12))
	for i = 0, n do
		local x = -w / 2 + i * w / n
		part(m, "Pillar", Vector3.new(1.6, hh + 0.4, 1.6), CFrame.new(x, hh / 2 + 0.2, 0.2), Color3.fromRGB(120, 56, 44), Enum.Material.Brick)
	end
	part(m, "Ledge", Vector3.new(w + 1.9, 0.6, 1.8), CFrame.new(0, hh + 0.5, 0.2), Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
	part(m, "Base", Vector3.new(w + 0.1, 1.2, 1.3), CFrame.new(0, 0.6, 0.1), Color3.fromRGB(110, 106, 100), Enum.Material.Concrete)
end
function B.scaffold(m, r)
	-- industrial scaffolding with LED strips on its bars
	local w, hh = dims(r, r.def)
	local cols, rows = math.max(1, math.floor(w / 8 + 0.5)), math.max(1, math.floor(hh / 6 + 0.5))
	local cw, rh = w / cols, hh / rows
	r.strips = {}
	for i = 0, cols do
		for _, z in ipairs({ -1.5, 1.5 }) do
			tube(m, Vector3.new(-w / 2 + i * cw, 0, z), Vector3.new(-w / 2 + i * cw, hh, z), 0.3, METAL)
		end
	end
	for j = 1, rows do
		local y = j * rh
		for _, z in ipairs({ -1.5, 1.5 }) do
			tube(m, Vector3.new(-w / 2, y, z), Vector3.new(w / 2, y, z), 0.25, METAL)
		end
		local s = part(m, "LEDStrip", Vector3.new(w, 0.25, 0.15), CFrame.new(0, y - 0.3, 1.75), r.color, Enum.Material.Neon)
		table.insert(r.strips, s)
		for i = 0, cols - 1 do
			local x0 = -w / 2 + i * cw
			local a, b = Vector3.new(x0, y - rh, 1.5), Vector3.new(x0 + cw, y, 1.5)
			if (i + j) % 2 == 0 then
				a, b = Vector3.new(x0 + cw, y - rh, 1.5), Vector3.new(x0, y, 1.5)
			end
			tube(m, a, b, 0.18, METAL)
			part(m, "Plank", Vector3.new(cw - 0.3, 0.2, 2.8), CFrame.new(x0 + cw / 2, y + 0.12, 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
		end
	end
end
function B.mirrorwall(m, r)
	-- tilted mirror tiles: they throw the light back into the hall
	local w, hh = dims(r, r.def)
	part(m, "Back", Vector3.new(w, hh, 0.4), CFrame.new(0, hh / 2, 0), Color3.fromRGB(20, 20, 24), Enum.Material.Metal)
	r.tiles = {}
	local cols, rows = math.max(1, math.floor(w / 2.6)), math.max(1, math.floor(hh / 2.6))
	for i = 0, cols - 1 do
		for j = 0, rows - 1 do
			local x, y = -w / 2 + (i + 0.5) * w / cols, (j + 0.5) * hh / rows
			local t = part(m, "Mirror", Vector3.new(w / cols - 0.3, hh / rows - 0.3, 0.12), CFrame.new(x, y, 0.3) * CFrame.Angles(((i + j) % 3 - 1) * 0.035, ((i * 2 + j) % 3 - 1) * 0.045, 0), Color3.fromRGB(200, 210, 220), Enum.Material.Glass)
			t.Reflectance = 0.5
			table.insert(r.tiles, t)
		end
	end
end
Builder.STAIR_COLORS = {
	{ "white", "White", Color3.fromRGB(238, 238, 242) },
	{ "black", "Black", Color3.fromRGB(24, 24, 28) },
	{ "gold", "Gold", Color3.fromRGB(214, 176, 92) },
	{ "silver", "Silver", Color3.fromRGB(176, 182, 192) },
	{ "red", "Red", Color3.fromRGB(170, 30, 40) },
	{ "pink", "Pink", Color3.fromRGB(240, 150, 190) },
	{ "blue", "Blue", Color3.fromRGB(40, 70, 160) },
	{ "mirror", "Mirror", Color3.fromRGB(200, 206, 216) },
}
function Builder.stairColor(id)
	for _, c in ipairs(Builder.STAIR_COLORS) do
		if c[1] == id then
			return c[3]
		end
	end
	return Builder.STAIR_COLORS[1][3]
end
function B.staircase(m, r)
	-- a grand staircase across the back of the stage, with light lines in the steps and handrails on posts
	-- (colour: rec.cc, see Builder.STAIR_COLORS)
	local w = dims(r, r.def)
	local cc = r.rec and r.rec.cc
	local col = Builder.stairColor(cc)
	local mat = (cc == "mirror") and Enum.Material.Glass or ((cc == "gold" or cc == "silver") and Enum.Material.Metal or Enum.Material.SmoothPlastic)
	local rail = (cc == "gold") and Color3.fromRGB(240, 240, 244) or Color3.fromRGB(220, 190, 110)
	r.lines = {}
	local N = 8
	for k = 0, N - 1 do
		local depth = N - k
		local st = part(m, "Step", Vector3.new(w - k * 0.8, 1, depth * 1.4), CFrame.new(0, 0.5 + k, -k * 0.7), col, mat)
		if cc == "mirror" then
			st.Reflectance = 0.25
		end
		local l = part(m, "StepLight", Vector3.new(w - k * 0.8, 0.15, 0.1), CFrame.new(0, 0.85 + k, depth * 0.7 - k * 0.7 + 0.02), WARM, Enum.Material.Neon)
		table.insert(r.lines, l)
	end
	-- handrails: straight over the middle of the treads (rail 3 studs above the steps), on posts
	local function tread(k)
		-- middle of the visible part of step k, and its top
		return 4.9 - 1.4 * k, k + 1
	end
	local railX = w / 2 - 0.4 * (N - 1) - 0.5
	for _, x in ipairs({ -1, 1 }) do
		local z0, y0 = tread(0)
		local z1, y1 = tread(N - 1)
		tube(m, Vector3.new(x * railX, y0 + 3, z0), Vector3.new(x * railX, y1 + 3, z1), 0.25, rail)
		for _, k in ipairs({ 0, 2, 4, 6, N - 1 }) do
			local z, y = tread(k)
			-- the post stands on the step and ends right under the rail
			local railY = y0 + 3 + (y1 - y0) * (z0 - z) / (z0 - z1)
			tube(m, Vector3.new(x * railX, y, z), Vector3.new(x * railX, railY, z), 0.16, rail)
		end
	end
end

------------------------------------------------------------------ neutral decor
function B.ampwall(m, r)
	-- a wall of guitar cabinets with amp heads on top (backline)
	for col = -1, 1 do
		for row = 0, 1 do
			local c = CFrame.new(col * 3.1, 1.5 + row * 3, 0)
			part(m, "Cab", Vector3.new(3, 2.95, 1.6), c, Color3.fromRGB(22, 22, 24))
			part(m, "Grille", Vector3.new(2.5, 2.4, 0.08), c * CFrame.new(0, 0, 0.82), Color3.fromRGB(60, 58, 52), Enum.Material.Fabric)
			part(m, "Badge", Vector3.new(0.7, 0.18, 0.05), c * CFrame.new(0.7, 1.05, 0.88), Color3.fromRGB(220, 220, 225), Enum.Material.Metal)
		end
		local h = CFrame.new(col * 3.1, 6.6, 0)
		part(m, "AmpHead", Vector3.new(3, 1.2, 1.4), h, Color3.fromRGB(26, 26, 28))
		part(m, "Panel", Vector3.new(2.7, 0.5, 0.06), h * CFrame.new(0, 0, 0.72), Color3.fromRGB(190, 170, 120), Enum.Material.Metal)
		part(m, "PowerLight", Vector3.new(0.15, 0.15, 0.05), h * CFrame.new(1.1, 0, 0.76), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
	end
end
function B.lightcube(m, r)
	-- a glowing cube to sit on, changes colour with the music
	r.cube = part(m, "Cube", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), Color3.fromRGB(240, 240, 255), Enum.Material.Neon)
	r.cube.Transparency = 0.15
end
function B.planter(m, r)
	-- a long planter box with grass and round shrubs
	local w = dims(r, r.def)
	part(m, "Box", Vector3.new(w, 1.6, 2.4), CFrame.new(0, 0.8, 0), Color3.fromRGB(70, 70, 74), Enum.Material.Concrete)
	part(m, "Soil", Vector3.new(w - 0.4, 0.2, 2), CFrame.new(0, 1.62, 0), Color3.fromRGB(60, 44, 30), Enum.Material.Ground)
	local n = math.max(1, math.floor(w / 3))
	for i = 0, n - 1 do
		local x = -w / 2 + (i + 0.5) * w / n
		local s = 1.6 + (i % 3) * 0.3
		part(m, "Shrub", Vector3.new(s, s, s), CFrame.new(x, 1.7 + s / 2 - 0.2, 0), Color3.fromRGB(60 + (i % 2) * 14, 120 + (i % 3) * 10, 60), Enum.Material.Grass, Enum.PartType.Ball)
	end
end
function B.neonline(m, r)
	-- a neon tube lying on the floor or along a stage edge
	local w = dims(r, r.def)
	r.tube = part(m, "Neon", Vector3.new(w, 0.3, 0.3), CFrame.new(0, 0.25, 0), r.color, Enum.Material.Neon)
	for _, x in ipairs({ -w / 2 + 0.3, 0, w / 2 - 0.3 }) do
		part(m, "Clip", Vector3.new(0.3, 0.2, 0.5), CFrame.new(x, 0.1, 0), DARK)
	end
end
function B.hedge(m, r)
	-- a trimmed green hedge
	local w = dims(r, r.def)
	part(m, "Hedge", Vector3.new(w, 4, 2.2), CFrame.new(0, 2, 0), Color3.fromRGB(56, 112, 52), Enum.Material.Grass)
	part(m, "HedgeTop", Vector3.new(w - 0.4, 0.6, 1.8), CFrame.new(0, 4.25, 0), Color3.fromRGB(66, 126, 58), Enum.Material.Grass)
end
function B.rope(m, r)
	-- brass posts with a red velvet rope (VIP)
	local w = dims(r, r.def)
	local n = math.max(1, math.floor(w / 4))
	for i = 0, n do
		local x = -w / 2 + i * w / n
		cyl(m, "PostFoot", 0.2, 1.1, CFrame.new(x, 0.1, 0), Color3.fromRGB(200, 165, 80), Enum.Material.Metal)
		cyl(m, "Post", 3, 0.25, CFrame.new(x, 1.6, 0), Color3.fromRGB(200, 165, 80), Enum.Material.Metal)
		part(m, "PostTop", Vector3.new(0.45, 0.45, 0.45), CFrame.new(x, 3.2, 0), Color3.fromRGB(220, 185, 95), Enum.Material.Metal, Enum.PartType.Ball)
		if i < n then
			local x2 = -w / 2 + (i + 1) * w / n
			-- a soft curve: three short pieces
			local pts = { Vector3.new(x, 2.9, 0), Vector3.new(x + (x2 - x) * 0.3, 2.35, 0), Vector3.new(x + (x2 - x) * 0.7, 2.35, 0), Vector3.new(x2, 2.9, 0) }
			for k = 1, 3 do
				tube(m, pts[k], pts[k + 1], 0.22, Color3.fromRGB(150, 20, 34)).Material = Enum.Material.Fabric
			end
		end
	end
end

local artistMark
-- where the artist is while playing an instrument (same places as in LiveShow): x, y, z, turned around, sitting
local ARTIST_MARK = {
	piano = { 0, 0, 5.2, true, true },
	keys = { 0, 0, -2.4, false, false },
	acoustic = { 0, 1.15, 0, false, true },
	harp = { 0, 0, -2.2, false, true },
	drums = { 0, 1, -1.8, false, true },
	djbooth = { 0, 0, -3.2, false, false },
	micstand = { 0, 0, -2.3, false, false },
	showerstage = { 0, 1.2, 0, false, false },
	gownriser = { 0, 1.45, 0, false, false },
	floatplat = { 0, 0.65, 0, false, false },
	descendcube = { 0, 0.8, 0, false, false },
	band_drums = { 0, 1, -1.8, false, true },
	band_guitar = { 0, 0, 0, false, false },
	band_bass = { 0, 0, 0, false, false },
	band_keys = { 0, 0, -2.4, false, false },
	band_backing = { 0, 0.4, 0, false, false },
}
Builder.ARTIST_MARK = ARTIST_MARK
-- in the stage builder: a see-through figure and an arrow on the floor show where the artist stands
-- and which way they look (hidden during shows, see Builder.hideMarker)
artistMark = function(m, r, a)
	local col = Color3.fromRGB(255, 220, 60)
	local base = CFrame.new(a[1], a[2], a[3]) * CFrame.Angles(0, a[4] and math.pi or 0, 0)
	local seat = a[5] and 2.25 or 0
	local list = {}
	local function mk(name, size, cf, color, mat)
		local p = part(m, name, size, base * cf, color, mat)
		p.Transparency = 0.55
		p.CastShadow = false
		p.CanQuery = false
		table.insert(list, p)
		return p
	end
	-- arrow on the floor: a shaft and a head (two turned bars)
	local fy = 0.085 - a[2]
	mk("ArtistMark", Vector3.new(0.35, 0.06, 2.2), CFrame.new(0, fy, 0.9), col, Enum.Material.Neon)
	mk("ArtistMark", Vector3.new(0.35, 0.06, 1.3), CFrame.new(-0.35, fy + 0.03, 1.85) * CFrame.Angles(0, math.rad(-40), 0), col, Enum.Material.Neon)
	mk("ArtistMark", Vector3.new(0.35, 0.06, 1.3), CFrame.new(0.35, fy + 0.06, 1.85) * CFrame.Angles(0, math.rad(40), 0), col, Enum.Material.Neon)
	-- the figure (sitting ones lower, with the thighs forward)
	local ghost = Color3.fromRGB(200, 190, 255)
	if a[5] then
		mk("ArtistMark", Vector3.new(1.8, 0.8, 1.9), CFrame.new(0, seat + 0.4 - a[2], 0.5), ghost)
	else
		mk("ArtistMark", Vector3.new(1.8, 2, 0.9), CFrame.new(0, 1, 0), ghost)
	end
	local torsoY = (a[5] and (seat + 0.8 - a[2]) or 2) + 1
	mk("ArtistMark", Vector3.new(2, 2, 1), CFrame.new(0, torsoY, 0), ghost)
	mk("ArtistMark", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, torsoY + 1.6, 0), ghost)
	mk("ArtistMark", Vector3.new(0.6, 0.3, 0.2), CFrame.new(0, torsoY + 1.6, 0.62), col, Enum.Material.Neon) -- the face side
	r.artistMark = list
end

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
		rigTop = opts.rigTop, -- truss towers: height up to the rig
		phase = math.random() * 6.28,
		cf = CFrame.new(),
	}
	local fn = B[def.id]
	if fn then
		Builder.buildingPreview = opts.preview == true
		fn(model, refs)
		Builder.buildingPreview = false
	end
	if ARTIST_MARK[def.id] then
		artistMark(model, refs, ARTIST_MARK[def.id])
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
			if d.Transparency < 0.99 and d.Name ~= "Pivot" and d.Name ~= "Target" and d.Name ~= "Nozzle" and d.Name ~= "Burst" and d.Name ~= "ArtistMark" and d.Name ~= "HitBox" then
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

-- one firework shell: flies up from `from` (default: the rack) and bursts high in the sky
local function launchShell(refs, from, height)
	local start = from and CFrame.new(from) or (refs.cf * CFrame.new(0, 3, 0))
	height = height or (120 + math.random() * 40)
	local shell = part(refs.model, "Shell", Vector3.new(0.8, 0.8, 0.8), start, WARM, Enum.Material.Neon, Enum.PartType.Ball)
	local tw = TweenService:Create(shell, TweenInfo.new(1.2 + height / 120, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = start * CFrame.new(math.random(-8, 8), height, math.random(-8, 8)) })
	tw.Completed:Connect(function()
		if refs.burst and refs.burst.Parent then
			refs.burst.CFrame = shell.CFrame
			refs.emitter:Emit(height > 90 and 220 or 150)
		end
		shell:Destroy()
	end)
	tw:Play()
end
-- the stadium roof edge (set by Venue.lua while a stadium stands): Roof Fireworks start from there
Builder.rimPoints = nil

-- Called every frame during a show. ctx: see LiveShow.lua
-- side-mounted lights move like their rig / floor versions
local SIDE_ANIM = { sidewash = "par", sidebeam = "beambar", sideblinder = "blinder", sidestrobe = "strobe" }

-- the special elements and moving screens (see LiveShow: refs.ride = where the artist stands)
function Builder.animateExtra(refs, ctx)
	-- the special elements of Client/Models.lua animate themselves
	if Builder.modelsAnimate and Builder.modelsAnimate(refs, ctx) then
		return
	end
	local k = refs.kind
	local rec = refs.rec or {}
	local active = type(rec.play) == "number" and rec.play == ctx.songNum
	local f = active and (ctx.songFrac or 0) or 0
	if k == "led_kinetic" then
		for _, kp in ipairs(refs.kinetic or {}) do
			local drop = 8 + math.sin((ctx.t or 0) * 0.8 + kp.i * 0.7) * 4 * (ctx.intensity or 0.6)
			kp.panel.CFrame = refs.cf * CFrame.new(kp.x, -drop - 3, 0)
			kp.cable.Size = Vector3.new(0.08, drop, 0.08)
			kp.cable.CFrame = refs.cf * CFrame.new(kp.x, -drop / 2 - 0.4, 0)
		end
	end
end

function Builder.animate(refs, ctx)
	Builder.animateKind(refs, ctx)
	Builder.animateExtra(refs, ctx)
	-- the faint glow around a beam follows the beam
	local b = refs.beam
	local glow = b and Builder.glowOf[b]
	if glow then
		if glow.Enabled ~= b.Enabled then
			glow.Enabled = b.Enabled
		end
		if refs.lastGlowC ~= refs.lastC then
			refs.lastGlowC = refs.lastC
			glow.Color = b.Color
		end
	end
	-- the real light follows the beam: on / off and its colour
	local L = b and Builder.lightOf[b]
	if L then
		if L.Enabled ~= b.Enabled then
			L.Enabled = b.Enabled
		end
		if refs.lastC and refs.lastLightC ~= refs.lastC then
			refs.lastLightC = refs.lastC
			L.Color = refs.lastC
		end
	end
end

function Builder.animateKind(refs, ctx)
	local k = SIDE_ANIM[refs.kind] or refs.kind
	local t = ctx.t
	local c1, c2 = ctx.c1, ctx.c2
	local hit = ctx.hit
	if k == "par" then
		-- wash: the colour changes every 4 beats (the cans take turns), the light pulses on the beat
		local c = ((math.floor((ctx.beatCount or 0) / 4 + refs.phase) % 2) == 0) and c1 or c2
		if refs.lastC ~= c then
			refs.lastC = c
			refs.lens.Color = c
			refs.light.Color = c
			if refs.beam then
				refs.beam.Color = ColorSequence.new(c)
			end
		end
		local pulse = 0.55 + 0.45 * (1 - (ctx.beat or 0))
		refs.light.Brightness = (0.6 + 1.8 * (ctx.intensity or 0.5)) * pulse
		if refs.beam then
			refs.beam.Enabled = (ctx.intensity or 0) > 0.2
		end
	elseif k == "moving" then
		local sp = ctx.sweep
		local yaw = math.sin(t * 0.8 * sp + refs.phase) * 0.7
		local tilt = -0.5 + math.sin(t * 1.1 * sp + refs.phase * 1.3) * 0.38
		refs.head.CFrame = refs.headHome * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		refs.lens.CFrame = refs.head.CFrame * refs.lensLocal * CFrame.Angles(0, 0, math.pi / 2)
		followHead(refs)
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
		followHead(refs)
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
		local visuals = mode == "visuals"
		for fi, f in ipairs(refs.faces or {}) do
			if visuals then
				-- tour visuals: the song's colours flicker with the beat; with strobes and blinders white / black flashes
				if ctx.strobe or (ctx.blind or 0) > 0.35 then
					bg = (math.floor(t * 14 + fi) % 2 == 0) and WHITE or Color3.new(0, 0, 0)
				else
					local beatN = (ctx.beatCount or 0) + fi
					local col = (beatN % 2 == 0) and c1 or c2
					bg = col:Lerp(Color3.new(0, 0, 0), math.clamp(1 - (ctx.beat or 0), 0, 1) * 0.55)
				end
			end
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
			-- artist visuals: every song of the artist has its own motif (Client/Visuals.lua); the intro has its own
			local vk = (visuals or ctx.introVisual) and (ctx.introVisual or ctx.visualKind) or nil
			if vk or f.visKind then
				Visuals.draw(f, vk, ctx)
			end
		end
		if k == "ledcube" and refs.cubeParts then
			local target = (ctx.seg == 3) and 1 or 0
			refs.cubeLift = refs.cubeLift + (target - refs.cubeLift) * math.min(1, (ctx.dt or 0.03) * 1.5)
			local off = CFrame.new(0, -refs.cubeLift * 5, 0) * CFrame.Angles(0, t * 0.15, 0)
			for _, cp in ipairs(refs.cubeParts) do
				cp[1].CFrame = refs.cf * off * cp[2]
			end
			-- the cables stay at the roof and reach down to the cube (they turn with it)
			for _, c in ipairs(refs.cables or {}) do
				local low = -15 + 4.5 - refs.cubeLift * 5
				local len = math.max(0.5, c[4] - low)
				local corner = (CFrame.Angles(0, t * 0.15, 0) * Vector3.new(c[2], 0, c[3]))
				c[1].Size = Vector3.new(0.18, len, 0.18)
				c[1].CFrame = refs.cf * CFrame.new(corner.X, low + len / 2, corner.Z)
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
			local len = math.max(0.4, h / 3 + 0.6) + i * 0.07 -- tops at different heights: no flicker
			tube.Size = Vector3.new(len, tube.Size.Y, tube.Size.Z)
			tube.CFrame = refs.cf * CFrame.new(0, y0 + len / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
		refs.top.CFrame = refs.cf * CFrame.new(0, 1.1 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		refs.topRing.CFrame = refs.cf * CFrame.new(0, 1.42 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		refs.under.CFrame = refs.cf * CFrame.new(0, 0.5 + h, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for i, rail in ipairs(refs.rails) do
			local a = (i - 1) * math.pi / 4
			rail.CFrame = refs.cf * CFrame.new(math.cos(a) * 4.8, 2.9 + h, math.sin(a) * 4.8)
		end
		refs.topRing.Color = c1
		refs.baseRing.Color = c2
	elseif k == "stadiumroof" then
		refs.roofLED.Color = c1:Lerp(c2, ctx.beat or 0)
		if refs.neon then
			setNeon(refs, ((ctx.beatCount or 0) % 2 == 0) and c1 or c2)
		end
	elseif k == "delaytower" then
		refs.blink.Transparency = (math.floor(t * 1.5) % 2 == 0) and 0 or 0.8
	elseif k == "scissor" then
		local h = ctx.scissorT * 16
		refs.platform.CFrame = refs.cf * CFrame.new(0, 0.9 + h, 0)
		refs.edge.CFrame = refs.cf * CFrame.new(0, 1.2 + h, 0)
		refs.edge.Color = c1
		-- the crossed arms open up as the platform rises
		for _, a in ipairs(refs.arms) do
			local z0 = (a.k == 1) and -3.9 or 3.9
			local dy = (a.k == 2) and 0.08 or 0
			local p0 = refs.cf * Vector3.new(a.x, 0.9 + dy, z0)
			local p1 = refs.cf * Vector3.new(a.x + ((a.k == 1) and 0.3 or -0.3), 0.9 + h + dy, -z0)
			local len = (p1 - p0).Magnitude
			a.p.Size = Vector3.new(0.4, 0.6 - (a.k - 1) * 0.05, math.max(1, len - (a.k - 1) * 0.14))
			a.p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		end
		for _, rl in ipairs(refs.rails) do
			rl.p.CFrame = refs.cf * CFrame.new(rl.x, (rl.y or 4.2) + h, rl.z)
		end
	elseif k == "swing" then
		Builder.swingPose(refs, math.sin(t * 1.3 + refs.phase) * (0.12 + 0.2 * (ctx.intensity or 0.5)))
	elseif k == "ferris" then
		refs.wheelA = refs.wheelA + (ctx.dt or 0.03) * 0.25
		Builder.ferrisPose(refs)
	elseif k == "lighthouse" then
		refs.head.CFrame = refs.cf * refs.headLocal * CFrame.Angles(0, t * 0.9, 0)
	elseif k == "cloud" then
		local bob = Vector3.new(0, math.sin(t * 0.7 + refs.phase) * 0.6, 0)
		for _, cp in ipairs(refs.cloudParts) do
			cp[1].CFrame = refs.cf * cp[2] + bob
		end
		refs.glow.Color = c1
	elseif k == "rocket" then
		if hit.pyro or hit.fireworks or hit.co2 then
			refs.emitter:Emit(40)
			refs.flame:Emit(60)
		end
	elseif k == "fountain" then
		refs.emitter.Enabled = (ctx.intensity or 0) > 0.3 or ctx.seg == 3
		if refs.lastC ~= c1 then
			refs.lastC = c1
			setNeon(refs, c1)
		end
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
	elseif k == "flamebar" then
		if hit.pyro then
			refs.chaseT = t
		end
		if refs.chaseT then
			-- one jet after the other, then all together
			local u = t - refs.chaseT
			local n = #refs.jets
			for i, em in ipairs(refs.jets) do
				local at = (i - 1) * 0.12
				if not refs.fired then
					refs.fired = {}
				end
				if u >= at and not refs.fired[i] then
					refs.fired[i] = true
					em:Emit(24)
				end
			end
			if u >= n * 0.12 + 0.3 and not refs.allFired then
				refs.allFired = true
				for _, em in ipairs(refs.jets) do
					em:Emit(30)
				end
			end
			refs.light.Brightness = (u < n * 0.12 + 0.9) and 2.2 or 0
			if u > n * 0.12 + 1 then
				refs.chaseT, refs.fired, refs.allFired = nil, nil, nil
			end
		end
	elseif k == "sparkrain" then
		if hit.sparks then
			refs.offAt = t + 4
			for _, em in ipairs(refs.emitters) do
				em.Enabled = true
			end
		elseif refs.offAt and t > refs.offAt then
			refs.offAt = nil
			for _, em in ipairs(refs.emitters) do
				em.Enabled = false
			end
		end
	elseif k == "halo" then
		-- a light runs round the ring, every lamp flashes on the beat
		local n = #refs.ring
		local head = (t * 8) % n
		for _, l in ipairs(refs.ring) do
			local dd = math.abs(l[2] - head)
			dd = math.min(dd, n - dd)
			l[1].Color = (dd < 2.5) and WHITE or c1:Lerp(c2, (l[2] % 2) * 1)
			l[1].Transparency = (dd < 2.5) and 0 or (0.5 - 0.4 * (ctx.beat or 0))
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
			-- while you place it (preview) the beams show where they go, but the head stands still
			if ctx.preview then
				refs.head.CFrame = refs.headHome
			else
				refs.head.CFrame = refs.headHome * CFrame.Angles(0, math.sin(t * 0.9 + refs.phase) * 0.8, 0) * CFrame.Angles(math.sin(t * 1.4) * 0.25, 0, 0)
			end
			followHead(refs)
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
			for i = 0, 3 do
				task.delay(i * 0.35, function()
					if refs.model.Parent then
						launchShell(refs)
					end
				end)
			end
		end
	elseif k == "raincurtain" then
		-- rains in its songs; without chosen songs in the ballad
		local songs = refs.rec and refs.rec.songs
		local on = false
		if type(songs) == "table" and #songs > 0 then
			for _, n in ipairs(songs) do
				if n == ctx.songNum then
					on = true
				end
			end
		else
			on = ctx.seg == 3
		end
		if refs.rain.Enabled ~= on then
			refs.rain.Enabled = on
			refs.mist.Enabled = on
		end
		if on then
			refs.rain.Color = ColorSequence.new(Color3.fromRGB(210, 230, 255):Lerp(c1, 0.25))
		end
	elseif k == "rimfireworks" then
		-- a volley all round the top of the stadium roof (in other venues: from the box itself)
		if hit.fireworks then
			local rim = Builder.rimPoints
			if rim and #rim > 0 then
				for i, p in ipairs(rim) do
					task.delay((i % 6) * 0.18 + math.random() * 0.1, function()
						if refs.model.Parent then
							launchShell(refs, p, 45 + math.random() * 35)
						end
					end)
				end
			else
				for i = 0, 3 do
					task.delay(i * 0.3, function()
						if refs.model.Parent then
							launchShell(refs, nil, 60)
						end
					end)
				end
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
		-- the wave stays high: the bars never come lower than 16 studs over the floor (and only a part of the
		-- way down in calm songs)
		local room = math.max(1, refs.cf.Position.Y - 16 - 2)
		local amp = math.min(room, 3 + 6 * (ctx.intensity or 0.5)) / 2
		for _, b in ipairs(refs.bars) do
			local drop = 2 + (math.sin(t * 0.9 * (ctx.sweep or 1) + b.i * 0.45) + 1) * amp
			b.bar.CFrame = refs.cf * CFrame.new(b.x, -drop, 0)
			b.wa.Size = Vector3.new(0.08, drop - 0.4, 0.08)
			b.wb.Size = Vector3.new(0.08, drop - 0.4, 0.08)
			b.wa.CFrame = refs.cf * CFrame.new(b.x, -(drop + 0.4) / 2, -3)
			b.wb.CFrame = refs.cf * CFrame.new(b.x, -(drop + 0.4) / 2, 3)
			b.bar.Color = (b.i % 2 == 0) and c1 or c2
		end
	elseif k == "moon" then
		refs.moon.CFrame = refs.moon.CFrame * CFrame.Angles(0, (ctx.dt or 0.03) * 0.1, 0)
		refs.halo.Color = Color3.fromRGB(255, 230, 170):Lerp(c1, 0.4)
		refs.halo.Transparency = (ctx.seg == 3) and 0.7 or 0.86
	elseif k == "backdrop" then
		-- the lights tint the cloth a little with the song colours
		local tint = c1:Lerp(c2, 0.5 + 0.5 * math.sin(t * 0.7))
		for _, f in ipairs(refs.folds) do
			local base = Color3.new(FABRIC.R * f[2], FABRIC.G * f[2], FABRIC.B * f[2])
			f[1].Color = base:Lerp(tint, 0.18 + 0.1 * (ctx.beat or 0))
		end
	elseif k == "starcloth" then
		for _, s in ipairs(refs.stars) do
			s[1].Transparency = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * s[3] + s[2]))
		end
	elseif k == "scrim" then
		refs.sheet.Color = Color3.fromRGB(235, 235, 240):Lerp(c1, 0.55 + 0.25 * math.sin(t * 0.9))
	elseif k == "panelwall" then
		if refs.lastBeat ~= ctx.beatCount then
			refs.lastBeat = ctx.beatCount
			local pat = math.floor((ctx.beatCount or 0) / 8) % 3
			for _, c in ipairs(refs.cells) do
				local on
				if pat == 0 then
					on = (c[2] + c[3] + ctx.beatCount) % 2 == 0
				elseif pat == 1 then
					on = (c[2] % 4) == (ctx.beatCount % 4)
				else
					on = (c[3] + ctx.beatCount) % 3 == 0
				end
				c[1].Color = on and c1 or c2:Lerp(Color3.new(0, 0, 0), 0.7)
				c[1].Transparency = on and 0.05 or 0.5
			end
		end
	elseif k == "bulbwall" then
		local run = t * 6
		for _, b in ipairs(refs.bulbs) do
			local on = math.floor(run + b[2] * 0.7 + b[3] * 0.4) % 4 ~= 0
			b[1].Transparency = on and 0 or 0.7
			b[1].Color = (ctx.seg == 3) and c1 or WARM
		end
	elseif k == "slatwall" then
		refs.glow.Color = c1:Lerp(c2, 0.5 + 0.5 * math.sin(t * 0.8))
	elseif k == "scaffold" then
		for i, s in ipairs(refs.strips) do
			s.Color = ((i + (ctx.beatCount or 0)) % 2 == 0) and c1 or c2
		end
	elseif k == "staircase" then
		for i, l in ipairs(refs.lines) do
			l.Color = ((i + (ctx.beatCount or 0)) % 4 == 0) and c1 or WARM
		end
	elseif k == "lightcube" then
		refs.cube.Color = c1:Lerp(c2, 0.5 + 0.5 * math.sin(t * 1.1 + refs.phase))
	elseif k == "neonline" then
		refs.tube.Color = c1
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
		refs.visor.CFrame = refs.head.CFrame * CFrame.new(0, 0.4, 2.65)
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
		refs.shoulderJoint.CFrame = shoulder * CFrame.new(0, 0.8, 0)
		refs.elbowJoint.CFrame = elbow
		refs.wristJoint.CFrame = elbow * CFrame.new(0, 11.8, 0)
		refs.lamp.Color = c1
		refs.beam.Color = ColorSequence.new(c1)
		refs.beam.Enabled = (ctx.intensity or 0) > 0.3
	elseif k == "curtain" then
		-- time since the curtain opens: at the start of its song (rec.cs) or when the show starts
		local dropT = ctx.curtainT or 0
		local cs = refs.rec and refs.rec.cs
		if cs and ctx.songStart and ctx.songStart[cs] and ctx.t then
			dropT = ctx.t - ctx.songStart[cs]
		end
		local w, h = refs.curtainW, refs.curtainH
		local labelT = 0
		if refs.anim == "split" then
			local f = (dropT <= 0) and 0 or math.min(1, dropT / 2.2)
			f = f * f * (3 - 2 * f)
			for _, hv in ipairs(refs.halves) do
				-- each half slides out and bunches up at its side
				local hw = (w / 2) * (1 - 0.8 * f)
				hv.p.Size = Vector3.new(math.max(0.5, hw), h, hv.p.Size.Z)
				hv.p.CFrame = refs.cf * CFrame.new(hv.side * (w / 2 - hw / 2), h / 2 + 1, hv.home.Position.Z)
			end
			labelT = f
		elseif refs.anim == "rise" then
			-- pulled up into the track: the drape gets shorter from the bottom
			local f = (dropT <= 0) and 0 or math.min(1, dropT / 2.5)
			f = f * f * (3 - 2 * f)
			local hh = math.max(0.3, h * (1 - f))
			refs.drape.Size = Vector3.new(w, hh, 0.5)
			refs.drape.CFrame = refs.cf * CFrame.new(0, h + 1 - hh / 2, 0)
			refs.drape.Transparency = (f >= 0.99) and 1 or 0
			labelT = math.min(1, f * 1.5)
		else
			if dropT <= 0 then
				refs.drape.CFrame = refs.cf * refs.drapeHome
				refs.drape.Transparency = 0
			else
				refs.drape.CFrame = refs.cf * refs.drapeHome * CFrame.new(0, -h * math.min(1, dropT * dropT * 2), 0)
				refs.drape.Transparency = math.min(1, dropT * 1.2)
			end
			labelT = refs.drape.Transparency
		end
		if refs.drapeLabel then
			refs.drapeLabel.TextTransparency = labelT
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
	elseif k == "keys" or k == "amps" or k == "wristbands" or k == "choir" or k == "hand" then
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
			b.p.CFrame = refs.cf * refs.hubLocal * CFrame.Angles(0, 0, refs.spin + b.a) * CFrame.new(0, 1, b.z or 0)
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
	elseif refs.ledParts and refs.def and refs.def.deck then
		-- LED video floor: colours run across the stage on the beat
		if refs.lastBeat ~= ctx.beatCount then
			refs.lastBeat = ctx.beatCount
			local c = ((ctx.beatCount % 2) == 0) and c1 or c2
			for _, p in ipairs(refs.ledParts) do
				p.Color = c:Lerp(Color3.new(0, 0, 0), 0.55)
			end
			setNeon(refs, c)
		end
	elseif (refs.def and refs.def.deck and k ~= "stairs") or k == "djbooth" or k == "palm" then
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
	for _, p in ipairs(refs.artistMark or {}) do
		p.Transparency = 1
	end
end

-- What a screen shows at a spot (falls back to the default, then to the old single setting)
Builder.SCREEN_KINDS = { led = true, led_side = true, ledcube = true, ledtower = true, ledpillar = true, led_flat = true, led_hang = true, led_flown = true, led_ribbon = true, led_curve = true, led_round = true, led_kinetic = true }
local SCREEN_NAMES = { song = "SONG TITLE", artist = "ARTIST NAME", visuals = "TOUR VISUALS", text = "TEXT", image = "IMAGE", liveArtist = "LIVE CAM: ARTIST", liveCrowd = "LIVE CAM: CROWD" }
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

-- the detailed models (cars, flowers, special elements, more shapes) live in Client/Models.lua
require(Root.Client.Models).install(B, {
	part = part,
	cyl = cyl,
	tube = tube,
	arcTube = arcTube,
	oval = oval,
	New = New,
	ringPieces = ringPieces,
	dims = dims,
	primPart = primPart,
	primLook = primLook,
	edge = edge,
	beam = beam,
	addLight = addLight,
	smooth = smooth,
	DARK = DARK,
	METAL = METAL,
	TEX_SMOKE = TEX_SMOKE,
	Builder = Builder,
})

return Builder
