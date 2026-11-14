-- Main menu background: detailed parody versions of famous venues at night.
-- Every scene is a whole city district built from parts. The camera flies through the streets
-- (Catmull-Rom spline through key points) and ends at the venue. Between scenes the 3D view
-- fades to black (ColorCorrection, so the menu UI stays visible) while the next district is built.
-- Scale: 1 stud ~ 0.5 m. Real dimensions (rounded) from public sources:
--   The O2: dome 365 m wide, ~50 m high, 12 yellow masts ~100 m (Guinness / ICE)
--   Madison Square Garden: 404 ft (123 m) round cable roof, 48 cables, between 7th/8th Ave and 31st/33rd St
--   Lanxess Arena: steel arch 76 m high carrying the roof (koeln.de), cathedral spires 157 m
--   Hallenstadion Zurich: opened 1939, rebuilt 2004-05, ~13,000 at concerts / 15,000 max (hallenstadion.ch)
--   Stade de France: ~80,000 seats, elliptical roof on 18 masts, ~43 m above the pitch
--   Santiago Bernabeu: rebuilt 2019-24 with a steel louvre skin, retractable roof, 360-degree screen
--   Wembley Stadium: 90,000 seats, arch 133 m high with a 315 m span (wembleystadium.com)
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)

local New = UI.New
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rgb = Color3.fromRGB
local M = Enum.Material
local PI = math.pi

local MenuScene = {}

local ORIGIN = V(0, 0, -9000)
local OCF = CF(ORIGIN)

local WARM = rgb(255, 214, 140)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local LIT = { rgb(255, 214, 150), rgb(255, 230, 192), rgb(214, 228, 255), rgb(255, 196, 120), rgb(196, 214, 255), rgb(255, 240, 220) }
local SHOPC = { rgb(255, 236, 200), rgb(120, 230, 255), rgb(255, 120, 170), rgb(255, 190, 90), rgb(160, 255, 170), rgb(255, 250, 240) }
local AWNING = { rgb(150, 30, 40), rgb(30, 70, 50), rgb(30, 40, 90), rgb(20, 20, 24), rgb(160, 110, 30) }
local SHIRTS = { rgb(20, 20, 24), rgb(230, 230, 235), rgb(200, 40, 60), rgb(40, 90, 200), rgb(250, 200, 50), rgb(150, 60, 200), rgb(60, 140, 90) }
local SKINS = { rgb(255, 220, 190), rgb(234, 184, 146), rgb(198, 134, 94), rgb(141, 85, 54), rgb(90, 56, 37) }
local CARC = { rgb(30, 30, 34), rgb(200, 200, 205), rgb(120, 20, 26), rgb(30, 50, 100), rgb(90, 92, 98), rgb(235, 235, 235) }

------------------------------------------------------------------ build state
-- FRAME: venue-local coordinates -> scene coordinates (the venue models are built around their own centre
-- and then turned onto the real footprint from the map data)
local FRAME = CFrame.new()
local function toScene(v)
	return (FRAME * CFrame.new(v)).Position
end
-- spatial grid of everything that stands on the ground (real buildings, the venue), for free-ground checks
local GRIDC = 64
local ground = {}
local folder, rng, count
local movers, blinkers, crowd, walkers, screens, beams, built
local lightsLeft, guisLeft
local samples = {}

local function reset(seed)
	rng = Random.new(seed)
	count = 0
	movers, blinkers, crowd, walkers, screens, beams, built = {}, {}, {}, {}, {}, {}, {}
	lightsLeft, guisLeft = 36, 28
	samples = {}
	FRAME = CFrame.new()
	ground = {}
end

local function groundAdd(e)
	-- e = { x, z, hw, hd, c, s, ell }: rotated box (c, s = cos/sin of its yaw), ell = rounded (venues)
	local r = math.sqrt(e.hw * e.hw + e.hd * e.hd)
	for gx = math.floor((e.x - r) / GRIDC), math.floor((e.x + r) / GRIDC) do
		for gz = math.floor((e.z - r) / GRIDC), math.floor((e.z + r) / GRIDC) do
			local k = gx * 4096 + gz
			ground[k] = ground[k] or {}
			table.insert(ground[k], e)
		end
	end
end

-- true if nothing stands at this scene position (p = Vector3 in scene coordinates)
local function freeAt(p, margin)
	margin = margin or 1.5
	local cell = ground[math.floor(p.X / GRIDC) * 4096 + math.floor(p.Z / GRIDC)]
	if not cell then
		return true
	end
	for _, e in ipairs(cell) do
		local dx, dz = p.X - e.x, p.Z - e.z
		local lx, lz = dx * e.c + dz * e.s, -dx * e.s + dz * e.c
		if e.ell then
			local u, w = lx / (e.hw + margin), lz / (e.hd + margin)
			if u * u * u * u + w * w * w * w < 1 then
				return false
			end
		elseif math.abs(lx) < e.hw + margin and math.abs(lz) < e.hd + margin then
			return false
		end
	end
	return true
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function rnd(a, b)
	return a + rng:NextNumber() * (b - a)
end

------------------------------------------------------------------ part helpers (local coordinates)
local function P(name, size, cf, color, mat, tr, refl)
	count = count + 1
	return New("Part", {
		Name = name,
		Size = size,
		CFrame = OCF * FRAME * cf,
		Color = color,
		Material = mat or M.SmoothPlastic,
		Transparency = tr or 0,
		Reflectance = refl or 0,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = folder,
	})
end

-- wedge: full height at local +Z, slope falls towards -Z
local function W(name, size, cf, color, mat)
	count = count + 1
	return New("WedgePart", {
		Name = name,
		Size = size,
		CFrame = OCF * FRAME * cf,
		Color = color,
		Material = mat or M.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = folder,
	})
end

local function cyl(name, len, d, cf, color, mat, tr)
	local p = P(name, V(len, d, d), cf, color, mat, tr)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local ROTZ = ANG(0, 0, PI / 2)
local function cylV(name, h, d, pos, color, mat, tr)
	return cyl(name, h, d, CF(pos) * ROTZ, color, mat, tr)
end

local function ball(name, d, pos, color, mat)
	local p = P(name, V(d, d, d), CF(pos), color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

-- stretched sphere (domes, tents)
local function ellip(name, size, cf, color, mat)
	local p = P(name, size, cf, color, mat)
	New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

local function vertical(a, b)
	return math.abs(a.X - b.X) + math.abs(a.Z - b.Z) < 0.01
end

local function bar(name, a, b, t, color, mat)
	local len = (b - a).Magnitude
	if vertical(a, b) then
		return P(name, V(t, len, t), CF((a + b) / 2), color, mat or M.Metal)
	end
	return P(name, V(t, t, len), CFrame.lookAt((a + b) / 2, b), color, mat or M.Metal)
end

local function tube(name, a, b, d, color, mat)
	local len = (b - a).Magnitude
	if vertical(a, b) then
		return cylV(name, len, d, (a + b) / 2, color, mat or M.Metal)
	end
	return cyl(name, len, d, CFrame.lookAt((a + b) / 2, b) * ANG(0, PI / 2, 0), color, mat or M.Metal)
end

-- gable roof, ridge along local X, cf = centre of the roof base
local function gable(cf, len, w, h, color, mat)
	W("Roof", V(len, h, w / 2), cf * CF(0, h / 2, -w / 4), color, mat)
	W("Roof", V(len, h, w / 2), cf * CF(0, h / 2, w / 4) * ANG(0, PI, 0), color, mat)
end

-- ground slab split into tiles (parts are limited to 2048 studs)
local function slab(name, x0, z0, x1, z1, top, th, color, mat, tr, refl)
	local nx, nz = math.ceil((x1 - x0) / 2000), math.ceil((z1 - z0) / 2000)
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			P(name, V(sx, th, sz), CF(x0 + sx * (i + 0.5), top - th / 2, z0 + sz * (j + 0.5)), color, mat, tr, refl)
		end
	end
end

local function glow(part, range, bright, color)
	if lightsLeft > 0 then
		lightsLeft = lightsLeft - 1
		New("PointLight", { Range = range, Brightness = bright, Color = color or WARM, Shadows = false, Parent = part })
	end
end

local function sign(part, face, text, textColor, bg, ppS, font)
	if guisLeft <= 0 then
		return nil
	end
	guisLeft = guisLeft - 1
	local gui = New("SurfaceGui", { Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = ppS or 8, LightInfluence = 0, Brightness = 2.2, Parent = part })
	local f = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = bg or BLACK, BackgroundTransparency = bg and 0 or 1, BorderSizePixel = 0, Parent = gui })
	return New("TextLabel", {
		Size = UDim2.fromScale(0.92, 0.8),
		Position = UDim2.fromScale(0.04, 0.1),
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = font or Enum.Font.GothamBlack,
		TextColor3 = textColor or WHITE,
		Parent = f,
	})
end

-- LED screen that cycles through texts
local function ledScreen(cf, w, h, texts, bg, face)
	local scr = P("LEDScreen", V(w, h, 1), cf, BLACK)
	local back = (face == Enum.NormalId.Back) and -0.3 or 0.3
	P("LEDFrame", V(w + 1.2, h + 1.2, 0.8), cf * CF(0, 0, back), rgb(30, 30, 34), M.Metal)
	local label = sign(scr, face or Enum.NormalId.Front, texts[1], WHITE, bg, math.max(4, math.floor(700 / w)))
	if label then
		table.insert(screens, { label = label, texts = texts, i = 1 })
	end
	return scr
end

local function blinker(pos, d)
	local b = P("AirLight", V(d or 1.6, d or 1.6, d or 1.6), CF(pos), rgb(255, 40, 40), M.Neon)
	table.insert(blinkers, { part = b, ph = rng:NextNumber() * 6 })
end

------------------------------------------------------------------ camera path
local function crPoint(p0, p1, p2, p3, u)
	local u2, u3 = u * u, u * u * u
	return (p1 * 2 + (p2 - p0) * u + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 + (p1 * 3 - p0 - p2 * 3 + p3) * u3) * 0.5
end

local function sampleKeys(keys, t, field)
	local n = #keys
	if t <= keys[1].t then
		return keys[1][field]
	end
	if t >= keys[n].t then
		return keys[n][field]
	end
	local i = 1
	while keys[i + 1].t < t do
		i = i + 1
	end
	local u = (t - keys[i].t) / (keys[i + 1].t - keys[i].t)
	local p0 = keys[math.max(1, i - 1)][field]
	local p3 = keys[math.min(n, i + 2)][field]
	return crPoint(p0, keys[i][field], keys[i + 1][field], p3, u)
end

local function makeSamples(keys)
	samples = {}
	local t = 0
	while t <= keys[#keys].t do
		table.insert(samples, sampleKeys(keys, t, "p"))
		t = t + 0.12
	end
end

-- distance (XZ) from a footprint to the flight path, and the lowest camera height above it
local function pathInfo(x, z, hw, hd)
	local best, low = 1e9, 1e9
	for _, s in ipairs(samples) do
		local dx = math.max(0, math.abs(s.X - x) - hw)
		local dz = math.max(0, math.abs(s.Z - z) - hd)
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
		if d < 26 and s.Y < low then
			low = s.Y
		end
	end
	return best, low
end

local function near(x, z, r)
	local d = pathInfo(x, z, 0, 0)
	return d < r
end

------------------------------------------------------------------ buildings
local STYLES = {
	glass = { core = rgb(34, 46, 66), mat = M.Glass, refl = 0.12, pier = rgb(140, 150, 166), pmat = M.Metal, pw = 0.7, step = 6, lit = 0.62, band = 5.2, dark = rgb(20, 26, 38), cool = true },
	dark = { core = rgb(18, 20, 26), mat = M.Glass, refl = 0.1, pier = rgb(56, 60, 70), pmat = M.Metal, pw = 0.8, step = 7, lit = 0.5, band = 5.2, cool = true },
	steel = { core = rgb(120, 126, 136), mat = M.Metal, pier = rgb(165, 170, 180), pmat = M.Metal, pw = 1.2, step = 6, lit = 0.65, band = 4.6, cool = true },
	stone = { core = rgb(168, 156, 136), mat = M.Limestone, pier = rgb(178, 166, 146), pmat = M.Limestone, pw = 2.6, step = 9, lit = 0.68, band = 4.4, cornice = true },
	brick = { core = rgb(122, 70, 54), mat = M.Brick, pier = rgb(130, 76, 60), pmat = M.Brick, pw = 2.8, step = 9, lit = 0.66, band = 4.4, cornice = true },
	white = { core = rgb(196, 194, 186), mat = M.Concrete, pier = rgb(206, 204, 196), pmat = M.Concrete, pw = 2.2, step = 8, lit = 0.62, band = 4.4, cornice = true },
	tan = { core = rgb(150, 128, 100), mat = M.Sandstone, pier = rgb(160, 138, 110), pmat = M.Sandstone, pw = 2.4, step = 8, lit = 0.64, band = 4.4, cornice = true },
}
local FACES = { n = 0, w = PI / 2, s = PI, e = -PI / 2 }

-- storefronts along one face: fcf = face frame (local X along the face, -Z points outwards)
local function storefront(fcf, len)
	local segs = math.max(1, math.floor(len / 18))
	local sw = len / segs
	for i = 1, segs do
		local x = -len / 2 + (i - 0.5) * sw
		local c = BLACK:Lerp(pick(SHOPC), rnd(0.55, 0.9))
		P("Shop", V(sw - 3, 6.5, 0.4), fcf * CF(x, 4.4, -0.2), c, M.Neon)
		if rng:NextNumber() < 0.55 then
			P("Awning", V(sw - 2, 0.5, 3.6), fcf * CF(x, 8.9, -1.8) * ANG(-0.25, 0, 0), pick(AWNING), M.Fabric)
		end
		if rng:NextNumber() < 0.22 then
			P("BladeSign", V(0.5, 4, 2.6), fcf * CF(x - sw / 2 + 2, 12.5, -1.6), pick(SHOPC), M.Neon)
		end
	end
end

local function roofStuff(cf, w, d, top, S, h)
	if S.cornice then
		if rng:NextNumber() < 0.35 and w > 26 and d > 26 then
			-- New York style wooden water tower
			local p = cf * CF(rnd(-w / 4, w / 4), top, rnd(-d / 4, d / 4))
			for _, o in ipairs({ { -2.6, -2.6 }, { 2.6, -2.6 }, { -2.6, 2.6 }, { 2.6, 2.6 } }) do
				P("WTLeg", V(0.5, 7, 0.5), p * CF(o[1], 3.5, o[2]), rgb(50, 46, 42), M.Metal)
			end
			cyl("WaterTank", 10, 8, p * CF(0, 12, 0) * ROTZ, rgb(96, 70, 50), M.WoodPlanks)
			cyl("WTRoof", 1.6, 7, p * CF(0, 17.8, 0) * ROTZ, rgb(60, 56, 54), M.Metal)
			cyl("WTRoof", 1.4, 3.6, p * CF(0, 19.2, 0) * ROTZ, rgb(60, 56, 54), M.Metal)
		else
			P("Bulkhead", V(rnd(10, 18), 9, rnd(10, 16)), cf * CF(rnd(-w / 5, w / 5), top + 4.5, rnd(-d / 5, d / 5)), S.core, S.mat)
		end
	else
		P("RoofPlant", V(w * 0.5, 6, d * 0.5), cf * CF(0, top + 3, 0), rgb(54, 56, 62), M.Metal)
		if h > 150 and rng:NextNumber() < 0.6 then
			P("Crown", V(w + 0.4, 1.4, d + 0.4), cf * CF(0, top - 1, 0), pick({ rgb(120, 200, 255), rgb(255, 255, 255), rgb(255, 120, 200), rgb(140, 255, 200) }), M.Neon)
		end
	end
	if h > 140 then
		P("Antenna", V(0.6, 24, 0.6), cf * CF(w / 6, top + 12, 0), rgb(150, 150, 156), M.Metal)
		blinker((cf * CF(w / 6, top + 24.6, 0)).Position)
	end
end

-- one vertical section of a building (walls, lit window bands, piers, dark windows)
local function tierBox(cf, w, d, y0, y1, S, lod, shops, faces)
	local h = y1 - y0
	P("Bldg", V(w, h, d), cf * CF(0, y0 + h / 2, 0), S.core, S.mat, 0, S.refl)
	local step = lod == 2 and 16 or 8
	local y = y0 + (shops and y0 == 0 and 12 or 0) + 4.6
	local litYs = {}
	while y < y1 - 3 do
		if rng:NextNumber() < S.lit then
			local base = pick(LIT)
			if S.cool and rng:NextNumber() < 0.6 then
				base = rgb(205, 222, 255)
			end
			local c = BLACK:Lerp(base, rnd(0.45, 0.85))
			P("Win", V(w + 0.3, S.band, d + 0.3), cf * CF(0, y, 0), c, M.Neon)
			table.insert(litYs, y)
		elseif S.dark then
			P("WinDark", V(w + 0.2, S.band, d + 0.2), cf * CF(0, y, 0), S.dark, M.Glass, 0, 0.15)
		end
		y = y + step
	end
	if lod == 2 then
		return
	end
	local st = (lod == 1) and S.step * 2 or S.step
	local nx = math.max(2, math.floor(w / st + 0.5))
	local nz = math.max(2, math.floor(d / st + 0.5))
	local yc = y0 + h / 2
	-- piers only on the faces that can be seen (street side), all faces for free-standing towers
	for i = 0, nx do
		local x = -w / 2 + i * w / nx
		if not faces or faces.n then
			P("Pier", V(S.pw, h, 0.9), cf * CF(x, yc, -d / 2 - 0.2), S.pier, S.pmat)
		end
		if not faces or faces.s then
			P("Pier", V(S.pw, h, 0.9), cf * CF(x, yc, d / 2 + 0.2), S.pier, S.pmat)
		end
	end
	for i = 0, nz do
		local z = -d / 2 + i * d / nz
		if not faces or faces.w then
			P("Pier", V(0.9, h, S.pw), cf * CF(-w / 2 - 0.2, yc, z), S.pier, S.pmat)
		end
		if not faces or faces.e then
			P("Pier", V(0.9, h, S.pw), cf * CF(w / 2 + 0.2, yc, z), S.pier, S.pmat)
		end
	end
	-- a few switched-off windows on lit floors make the grid look real
	if lod == 0 and #litYs > 0 then
		for _ = 1, math.min(10, #litYs * 2) do
			local yy = litYs[rng:NextInteger(1, #litYs)]
			local side = rng:NextInteger(0, 3)
			if faces then
				side = faces.n and 0 or (faces.s and 2 or (faces.w and 1 or 3))
			end
			local a = side * PI / 2
			local len = (side % 2 == 0) and w or d
			local depth = (side % 2 == 0) and d or w
			local n = (side % 2 == 0) and nx or nz
			local cell = len / n
			local k = rng:NextInteger(0, n - 1)
			P("WinOff", V(cell - S.pw, S.band + 0.1, 0.25), cf * ANG(0, a, 0) * CF(-len / 2 + (k + 0.5) * cell, yy, -depth / 2 - 0.22), S.dark or rgb(24, 26, 32), M.Glass)
		end
	end
end

-- full building at local (x, z). o: yaw, shops = {n=true,...}, lod, setback, tiers, y
local function building(x, z, w, d, h, style, o)
	o = o or {}
	local r = math.max(w, d) / 2
	local dist, low = pathInfo(x, z, o.yaw and r or w / 2, o.yaw and r or d / 2)
	if low < 1e8 and not o.force then
		local cap = low - 16
		if cap < 14 then
			return nil
		end
		if h > cap then
			h = cap
		end
	end
	local S = STYLES[style]
	local lod = o.lod or ((dist > 280) and 2 or ((dist > 70) and 1 or 0))
	local faces = o.faces or o.shops
	local cf = CF(x, o.y or 0, z) * ANG(0, o.yaw or 0, 0)
	local hasShops = o.shops and lod == 0
	-- setbacks ("wedding cake") for tall masonry towers
	if (o.setback ~= false) and S.cornice and h > 150 then
		local h1, h2 = math.floor(h * 0.58 / 8) * 8, math.floor(h * 0.84 / 8) * 8
		tierBox(cf, w, d, 0, h1, S, lod, hasShops, faces)
		tierBox(cf, w - 10, d - 10, h1, h2, S, math.max(lod, 1), false)
		tierBox(cf, w - 24, d - 24, h2, h, S, math.max(lod, 1), false)
		if lod < 2 then
			P("Cornice", V(w + 1.6, 1.6, d + 1.6), cf * CF(0, h1, 0), S.pier, S.pmat)
			P("Cornice", V(w - 8.4, 1.6, d - 8.4), cf * CF(0, h2, 0), S.pier, S.pmat)
			roofStuff(cf, w - 24, d - 24, h, S, h)
		end
	else
		tierBox(cf, w, d, 0, h, S, lod, hasShops, faces)
		if lod < 2 then
			if S.cornice then
				P("Cornice", V(w + 1.6, 1.6, d + 1.6), cf * CF(0, h, 0), S.pier, S.pmat)
			end
			roofStuff(cf, w, d, h, S, h)
		end
	end
	if hasShops then
		for face, on in pairs(o.shops) do
			if on then
				local a = FACES[face]
				local len = (a == 0 or a == PI) and w or d
				local depth = (a == 0 or a == PI) and d or w
				storefront(cf * ANG(0, a, 0) * CF(0, 0, -depth / 2 - 0.25), len)
			end
		end
	end
	if o.blink and h > 100 then
		blinker(V(x, h + 2, z))
	end
	if not o.yaw then
		table.insert(built, { x0 = x - w / 2, x1 = x + w / 2, z0 = z - d / 2, z1 = z + d / 2, h = h })
	end
	return h
end

-- cheap distant skyline tower
local function farTower(x, z, w, d, h, color)
	P("FarTower", V(w, h, d), CF(x, h / 2, z), color, M.Glass, 0, 0.1)
	local y = 10
	while y < h - 6 do
		if rng:NextNumber() < 0.7 then
			P("FarWin", V(w + 0.4, 6, d + 0.4), CF(x, y, z), BLACK:Lerp(pick(LIT), rnd(0.35, 0.7)), M.Neon)
		end
		y = y + 18
	end
	if h > 300 then
		blinker(V(x, h + 2, z), 3)
	end
end

------------------------------------------------------------------ street furniture
local function streetLamp(x, z, yaw, h)
	h = h or 18
	if not freeAt(toScene(V(x, 0, z)), 0.5) then
		return
	end
	local base = CF(x, 0, z) * ANG(0, yaw, 0)
	P("LampPole", V(0.7, h, 0.7), base * CF(0, h / 2, 0), rgb(46, 48, 54), M.Metal)
	P("LampArm", V(0.4, 0.4, 7), base * CF(0, h - 0.2, -3.5), rgb(46, 48, 54), M.Metal)
	local head = P("LampHead", V(1.6, 0.6, 2.6), base * CF(0, h - 0.6, -7), WARM, M.Neon)
	if near(x, z, 150) then
		glow(head, 28, 1.4, WARM)
	end
end

local function oldLamp(x, z)
	if not freeAt(toScene(V(x, 0, z)), 0.5) then
		return
	end
	P("LampPost", V(0.6, 11, 0.6), CF(x, 5.5, z), rgb(30, 34, 32), M.Metal)
	local head = P("LampLantern", V(1.6, 2, 1.6), CF(x, 12, z), WARM, M.Neon)
	if near(x, z, 120) then
		glow(head, 20, 1.2, WARM)
	end
end

-- traffic signal on a mast arm (arm along local -Z, lamps visible from both sides)
local function signal(x, z, yaw, armLen)
	local base = CF(x, 0, z) * ANG(0, yaw, 0)
	local dark = rgb(40, 44, 40)
	P("SignalPole", V(1, 20, 1), base * CF(0, 10, 0), dark, M.Metal)
	P("SignalArm", V(0.6, 0.6, armLen), base * CF(0, 19.4, -armLen / 2), dark, M.Metal)
	for _, f in ipairs({ 0.45, 0.85 }) do
		local off = -armLen * f
		P("SignalBox", V(1.4, 4.6, 1.6), base * CF(0, 16.8, off), rgb(28, 28, 26))
		local green = rng:NextNumber() < 0.55
		P("SignalLamp", V(1.8, 1.1, 1.1), base * CF(0, 16.8 + (green and -1.4 or 1.4), off), green and rgb(70, 255, 150) or rgb(255, 50, 40), M.Neon)
	end
end

local function tree(x, z, s)
	s = s or 1
	if not freeAt(toScene(V(x, 0, z)), 2) then
		return
	end
	P("Trunk", V(1 * s, 8 * s, 1 * s), CF(x, 4 * s, z), rgb(70, 50, 36), M.Wood)
	ball("Leaves", 8 * s, V(x, 10 * s, z), rgb(38, 70, 44), M.Grass)
	ball("Leaves", 6 * s, V(x + 1.5 * s, 12.5 * s, z - 1 * s), rgb(46, 82, 50), M.Grass)
end

local function steamStack(x, z)
	for i = 0, 3 do
		cylV("SteamStack", 1.6, 2.6, V(x, 0.8 + i * 1.6, z), (i % 2 == 0) and rgb(255, 110, 20) or rgb(240, 240, 240), M.SmoothPlastic)
	end
	local top = cylV("SteamTop", 0.4, 2.2, V(x, 6.6, z), rgb(30, 30, 30))
	New("Smoke", { Color = rgb(220, 222, 230), Opacity = 0.18, RiseVelocity = 5, Size = 4, Parent = top })
end

-- figures: a simple fan (body + head) that bounces
local PANTS = { rgb(30, 34, 50), rgb(20, 20, 24), rgb(60, 70, 100), rgb(110, 90, 70), rgb(200, 200, 205) }
local HAIRC = { rgb(30, 24, 20), rgb(90, 60, 30), rgb(220, 190, 120), rgb(160, 60, 40), rgb(20, 20, 20) }
local function fan(pos, shirt, yaw, holdSign, calm)
	-- nobody stands inside a building
	if not freeAt(toScene(pos), 1) then
		return
	end
	local legs = P("FanLegs", V(1.3, 1.5, 0.8), CF(pos + V(0, 0.75, 0)), pick(PANTS))
	local body = P("Fan", V(1.6, 1.6, 0.95), CF(pos + V(0, 2.3, 0)), shirt)
	local head = P("FanHead", V(1.1, 1.15, 1.1), CF(pos + V(0, 3.7, 0)), pick(SKINS))
	New("SpecialMesh", { MeshType = Enum.MeshType.Head, Parent = head })
	local hair = P("FanHair", V(1.18, 0.4, 1.18), CF(pos + V(0, 4.2, 0)), pick(HAIRC))
	table.insert(crowd, { parts = { legs, body, head, hair }, offs = { 0.75, 2.3, 3.7, 4.2 }, base = ORIGIN + toScene(pos), ph = rng:NextNumber() * 6.28, calm = calm })
	if holdSign then
		P("FanSign", V(2.4, 1.4, 0.15), CF(pos + V(0, 5.4, 0)) * ANG(0, yaw or 0, 0), holdSign, M.Neon)
	end
end

local function walker(a, b, shirt, seed)
	a, b = toScene(a), toScene(b)
	if not freeAt(a, 1) or not freeAt(b, 1) or not freeAt((a + b) / 2, 1) then
		return
	end
	local fig = People.new(folder, shirt or pick(SHIRTS), 0.9, "crowd", seed or rng:NextInteger(1, 9999))
	count = count + 10
	table.insert(walkers, { fig = fig, a = a, b = b, len = (b - a).Magnitude, speed = rnd(5, 8), ph = rng:NextNumber() * 2 })
end

-- groups of 2-6 people standing together and chatting
local function mingle(cx, cz, rx, rz, groups, y, color)
	for _ = 1, groups do
		local gx, gz = cx + rnd(-rx, rx), cz + rnd(-rz, rz)
		local n = rng:NextInteger(2, 6)
		local r = 1.3 + n * 0.3
		for k = 1, n do
			local a = k / n * 2 * PI + rnd(-0.25, 0.25)
			local pos = V(gx + math.cos(a) * r, y, gz + math.sin(a) * r)
			local shirt = (rng:NextNumber() < 0.35) and color or pick(SHIRTS)
			fan(pos, shirt, math.atan2(gx - pos.X, gz - pos.Z), (rng:NextNumber() < 0.07) and color or nil, true)
		end
	end
end

-- a natural queue (no fences), slightly wavy
local function line(start, dir, len, y, color)
	local side = V(dir.Z, 0, -dir.X)
	local n = math.floor(len / 2.4)
	for i = 0, n do
		local p = start + dir * (i * 2.4 + rnd(-0.4, 0.4)) + side * (math.sin(i * 0.7) * 1.5 + rnd(-0.6, 0.6))
		fan(V(p.X, y, p.Z), (rng:NextNumber() < 0.35) and color or pick(SHIRTS), 0, (rng:NextNumber() < 0.05) and color or nil, true)
	end
end

-- security in yellow vests and photographers with flashes
local function staff(pos, kind)
	fan(pos, (kind == "security") and rgb(255, 214, 0) or rgb(30, 30, 34), 0, nil, true)
	if kind == "photo" then
		local flash = P("Flash", V(0.6, 0.4, 0.4), CF(pos + V(0.6, 3.6, 0.5)), WHITE, M.Neon)
		table.insert(blinkers, { part = flash, ph = rng:NextNumber() * 6, flash = true })
	end
end

local function hotdogCart(pos, yaw)
	if not freeAt(toScene(pos), 5) then
		return
	end
	local cf = CF(pos) * ANG(0, yaw, 0)
	P("Cart", V(6, 3.5, 3), cf * CF(0, 2.6, 0), rgb(220, 220, 225), M.Metal)
	P("CartWheels", V(5.4, 1.2, 3.2), cf * CF(0, 0.6, 0), rgb(30, 30, 30))
	P("Umbrella", V(8, 0.4, 8), cf * CF(0, 8, 0), rgb(220, 60, 40), M.Fabric)
	P("UmbrellaPole", V(0.3, 4, 0.3), cf * CF(0, 6, 0), WHITE, M.Metal)
	P("CartGlow", V(5, 0.6, 0.2), cf * CF(0, 3.6, 1.6), WARM, M.Neon)
	fan((cf * CF(0, 0, -2.6)).Position, rgb(230, 230, 235), yaw, nil, true)
	fan((cf * CF(1.5, 0, 3.4)).Position, pick(SHIRTS), yaw + PI, nil, true)
	fan((cf * CF(-1.5, 0, 3.8)).Position, pick(SHIRTS), yaw + PI, nil, true)
end

-- billboard mounted flat on the avenue side of a building (never sticks through other buildings)
local function facadeBillboard(west, zWant, text, bg)
	local best, bestD = nil, 1e9
	for _, b in ipairs(built) do
		local onAve = west and (b.x1 > 262 and b.x1 < 274) or ((not west) and b.x0 > 346 and b.x0 < 360)
		if onAve and b.h >= 90 and (b.z1 - b.z0) >= 30 then
			local zc = math.clamp(zWant, b.z0 + 15, b.z1 - 15)
			local d = math.abs(zc - zWant)
			if d < bestD then
				best, bestD = b, d
			end
		end
	end
	if not best or bestD > 220 then
		return
	end
	local wdt = math.min(40, (best.z1 - best.z0) - 6)
	local zc = math.clamp(zWant, best.z0 + wdt / 2 + 2, best.z1 - wdt / 2 - 2)
	local y = math.min(best.h - 18, 64)
	local x = west and (best.x1 + 1.1) or (best.x0 - 1.1)
	P("BillboardFrame", V(0.5, 28, wdt + 1.4), CF(x + (west and -0.4 or 0.4), y, zc), rgb(30, 30, 34), M.Metal)
	local bb = P("Billboard", V(0.6, 26, wdt), CF(x, y, zc), BLACK)
	sign(bb, west and Enum.NormalId.Right or Enum.NormalId.Left, text, WHITE, bg, 10)
	P("BillboardLamp", V(1.2, 0.5, wdt * 0.8), CF(x + (west and 1.2 or -1.2), y - 14, zc), WARM, M.Neon)
end

local function banner(pos, text, color, yaw)
	if not freeAt(toScene(pos), 2) then
		return
	end
	P("FlagPole", V(0.5, 26, 0.5), CF(pos + V(0, 13, 0)), rgb(180, 182, 190), M.Metal)
	local b = P("Banner", V(6, 16, 0.2), CF(pos) * ANG(0, yaw or 0, 0) * CF(3.4, 16, 0), color, M.Fabric)
	sign(b, Enum.NormalId.Front, text, WHITE, nil, 10)
end

local function searchlights(list)
	for _, s in ipairs(list) do
		P("SearchlightBase", V(4, 3, 4), CF(s.pos + V(0, 1.5, 0)), rgb(40, 40, 46), M.Metal)
		local beam = P("Beam", V(5, 5, 700), CF(s.pos), s.color or rgb(220, 230, 255), M.Neon, 0.88)
		table.insert(beams, { part = beam, pos = toScene(s.pos), ph = s.ph or 0, speed = s.speed or 0.35, tilt = s.tilt or 0.45 })
	end
end

------------------------------------------------------------------ vehicles (animated)
local function vehicle(parts, pathA, pathB, speed, phase, loop)
	pathA, pathB = toScene(pathA), toScene(pathB)
	local dir = (pathB - pathA)
	local len = dir.Magnitude
	table.insert(movers, { parts = parts, a = pathA, dir = dir.Unit, len = len, speed = speed, s = phase * len, yaw = math.atan2(-dir.X, -dir.Z) })
end

-- builds a car at the origin: returns { {part, offsetCF}, ... } (front = local -Z)
local function carParts(kind, color)
	local list = {}
	local function add(p, off)
		table.insert(list, { p, off })
	end
	if kind == "bus" or kind == "dd" or kind == "tram" or kind == "train" then
		local len = (kind == "train") and 50 or ((kind == "tram") and 30 or 24)
		local h = (kind == "dd") and 9 or 6.5
		add(P("BusBody", V(5, h, len), CF(), color), CF(0, h / 2 + 0.6, 0))
		add(P("BusWindows", V(5.1, 1.8, len - 4), CF(), BLACK:Lerp(WARM, 0.6), M.Neon), CF(0, h - 1.6, 0))
		if kind == "dd" then
			add(P("BusWindows", V(5.1, 1.8, len - 4), CF(), BLACK:Lerp(WARM, 0.55), M.Neon), CF(0, 3.6, 0))
		end
		if kind == "train" then
			add(P("TrainStripe", V(5.15, 0.6, len), CF(), rgb(230, 20, 40), M.Neon), CF(0, 2.2, 0))
		elseif kind == "tram" then
			add(P("TramStripe", V(5.15, 2, len), CF(), rgb(220, 30, 40)), CF(0, 2, 0))
			add(P("Pantograph", V(0.3, 2.4, 3), CF(), rgb(40, 40, 40), M.Metal), CF(0, h + 1.8, 0))
		else
			add(P("BusSign", V(4, 0.8, 0.2), CF(), rgb(255, 170, 40), M.Neon), CF(0, h - 0.2, -len / 2 - 0.1))
		end
		add(P("HeadL", V(4, 0.5, 0.2), CF(), rgb(255, 250, 230), M.Neon), CF(0, 1.6, -len / 2 - 0.1))
		add(P("TailL", V(4, 0.5, 0.2), CF(), rgb(255, 30, 30), M.Neon), CF(0, 1.6, len / 2 + 0.1))
		return list
	end
	add(P("CarBody", V(4.6, 2, 11), CF(), color), CF(0, 1.7, 0))
	add(P("CarWheels", V(4.7, 1.3, 8), CF(), rgb(16, 16, 18)), CF(0, 0.65, 0))
	add(P("CarCabin", V(4.2, 1.7, 5.8), CF(), rgb(26, 30, 38), M.Glass), CF(0, 3.5, 0.6))
	add(P("HeadL", V(1, 0.55, 0.2), CF(), rgb(255, 250, 225), M.Neon), CF(-1.5, 1.9, -5.55))
	add(P("HeadL", V(1, 0.55, 0.2), CF(), rgb(255, 250, 225), M.Neon), CF(1.5, 1.9, -5.55))
	add(P("TailL", V(1, 0.55, 0.2), CF(), rgb(255, 30, 30), M.Neon), CF(-1.5, 1.9, 5.55))
	add(P("TailL", V(1, 0.55, 0.2), CF(), rgb(255, 30, 30), M.Neon), CF(1.5, 1.9, 5.55))
	if kind == "taxi" then
		add(P("TaxiLight", V(2, 0.6, 0.9), CF(), rgb(255, 245, 190), M.Neon), CF(0, 4.6, 0.6))
	elseif kind == "cab" then
		add(P("CabLight", V(1.6, 0.6, 0.7), CF(), rgb(255, 180, 40), M.Neon), CF(0, 4.6, -1))
	end
	return list
end

-- a lane of traffic from a to b (looping), n vehicles
local function lane(a, b, n, kinds, colors, speed)
	for i = 1, n do
		local kind = pick(kinds)
		local col = colors and pick(colors) or pick(CARC)
		if kind == "taxi" then
			col = rgb(255, 196, 18)
		elseif kind == "cab" then
			col = rgb(18, 18, 22)
		elseif kind == "dd" then
			col = rgb(200, 20, 26)
		end
		vehicle(carParts(kind, col), a, b, (speed or 26) * rnd(0.85, 1.15), (i - 1 + rnd(0, 0.6)) / n)
	end
end

------------------------------------------------------------------ SCENES
------------------------------------------------------------------ the real city around each venue
-- Data/MenuCity/<name> is made by tools/osm/build_city.py from OpenStreetMap (ODbL, via OpenFreeMap / OpenMapTiles):
-- every building with its real height, roads, railways, water, parks and squares. 1 stud = 0.5 m, venue at (0, 0).
local CITY_FACADES = {
	{ rgb(150, 142, 130), M.Concrete }, { rgb(124, 76, 60), M.Brick }, { rgb(54, 66, 86), M.Glass },
	{ rgb(186, 180, 166), M.Concrete }, { rgb(92, 96, 108), M.Concrete }, { rgb(168, 146, 112), M.Sandstone },
}
local ROAD_COLOR = { rgb(38, 38, 44), rgb(42, 42, 48), rgb(46, 46, 52), rgb(54, 54, 58), rgb(96, 94, 90) }
local function yawCF(x, y, z, yaw)
	return CF(x, y, z) * ANG(0, -math.rad(yaw), 0)
end
local function osmCity(name, o)
	o = o or {}
	local d = require(Root.Data.MenuCity[name])
	local half = d.half
	slab("Ground", -half - 800, -half - 800, half + 800, half + 800, 0, 2, o.ground or rgb(34, 36, 40), M.Asphalt)
	-- flat layers: parks, squares, water (each piece slightly higher than its neighbour: no flicker)
	local function flats(arr, top, color, mat, refl, nm)
		for i = 1, #arr, 5 do
			local k = ((i - 1) / 5) % 4
			P(nm, V(arr[i + 2], 0.4, arr[i + 3]), yawCF(arr[i], top - 0.2 + k * 0.03, arr[i + 1], arr[i + 4]), color, mat, 0, refl)
		end
	end
	flats(d.G, 0.25, rgb(30, 54, 34), M.Grass, 0, "Park")
	flats(d.P, 0.32, rgb(98, 98, 102), M.Pavement, 0, "Square")
	flats(d.W, 0.42, rgb(14, 30, 50), M.Glass, 0.3, "Water")
	-- roads and railways
	local R = d.R
	local lamps, lanes = 0, {}
	for i = 1, #R, 6 do
		local a, b = V(R[i], 0, R[i + 1]), V(R[i + 2], 0, R[i + 3])
		local w, k = R[i + 4], R[i + 5]
		local bridge = k > 10
		if bridge then
			k = k - 10
		end
		local len = (b - a).Magnitude
		local y = (bridge and 10 or 0.55) + ((i - 1) / 6 % 5) * 0.025
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid + V(0, y, 0), b + V(0, y, 0))
		if k == 6 or k == 7 then
			if k == 6 then
				P("RailBed", V(w, 0.4, len + 1), cf, rgb(70, 62, 56), M.Slate)
			end
			for _, sx in ipairs({ -1.4, 1.4 }) do
				P("Rail", V(0.35, 0.3, len + 1), cf * CF(sx, 0.3, 0), rgb(150, 150, 156), M.Metal)
			end
		else
			P("Road", V(w, 0.3, len + w * 0.5), cf, ROAD_COLOR[k] or ROAD_COLOR[3], (k == 5) and M.Pavement or M.Asphalt)
		end
		if bridge then
			P("BridgeDeck", V(w + 2, 2.4, len + 1), cf * CF(0, -1.4, 0), rgb(70, 70, 74), M.Concrete)
			if len > 40 then
				for u = 0.2, 0.81, 0.6 do
					local p = a:Lerp(b, u)
					cylV("BridgePier", y, 5, V(p.X, y / 2, p.Z), rgb(110, 106, 100), M.Concrete)
				end
			end
		end
		-- street lamps and traffic near the camera path
		if (k == 2 or k == 3) and lamps < (o.lamps or 90) then
			local dist = pathInfo(mid.X, mid.Z, 0, 0)
			if dist < 260 and len > 50 then
				local dir = (b - a).Unit
				local side = V(dir.Z, 0, -dir.X)
				local n = math.floor(len / 70)
				for j = 0, n - 1 do
					local sg = (j % 2 == 0) and 1 or -1
					local p = a + dir * (35 + j * 70) + side * sg * (w / 2 + 3)
					streetLamp(p.X, p.Z, math.atan2(side.X * sg, side.Z * sg), 18)
					lamps = lamps + 1
				end
			end
		end
		if (k == 1 or k == 2) and len > 140 and not bridge then
			table.insert(lanes, { a = a, b = b, w = w, len = len, dist = pathInfo(mid.X, mid.Z, 0, 0) })
		end
	end
	table.sort(lanes, function(p, q)
		return p.dist < q.dist
	end)
	for j = 1, math.min(o.traffic or 8, #lanes) do
		local l = lanes[j]
		if l.dist < 700 then
			local dir = (l.b - l.a).Unit
			local side = V(dir.Z, 0, -dir.X) * (l.w * 0.22)
			local n = math.max(1, math.floor(l.len / 90))
			lane(l.a + side + V(0, 0.7, 0), l.b + side + V(0, 0.7, 0), n, o.cars or { "car", "car", "taxi" }, nil, 24)
			lane(l.b - side + V(0, 0.7, 0), l.a - side + V(0, 0.7, 0), n, o.cars or { "car", "car", "taxi" }, nil, 24)
		end
	end
	-- buildings with lit window bands (detail depends on the distance to the flight path)
	local B = d.B
	for i = 1, #B, 8 do
		local x, z, w, dd, yaw, h, mh, st = B[i], B[i + 1], B[i + 2], B[i + 3], B[i + 4], B[i + 5], B[i + 6], B[i + 7]
		local r = math.max(w, dd) / 2
		local dist, low = pathInfo(x, z, r, r)
		if low < 1e8 and dist < 4 and h > low - 10 then
			h = math.max(mh + 6, low - 14) -- never fly through a roof
		end
		local f = CITY_FACADES[st] or CITY_FACADES[1]
		local a = math.rad(yaw)
		groundAdd({ x = x, z = z, hw = w / 2, hd = dd / 2, c = math.cos(a), s = math.sin(a) })
		local cf = yawCF(x, 0, z, yaw)
		P("Building", V(w, h - mh, dd), cf * CF(0, mh + (h - mh) / 2, 0), f[1], f[2], 0, (f[2] == M.Glass) and 0.08 or 0)
		local bands = 0
		if dist < 420 then
			bands = math.min(7, math.floor((h - mh - 6) / 7))
		elseif dist < 1400 and h > 50 then
			bands = math.min(3, math.floor(h / 40))
		end
		for k2 = 1, bands do
			if rng:NextNumber() < 0.8 then
				local y = mh + 5 + (k2 - 1) * (h - mh - 8) / math.max(1, bands - 1)
				local lit = rng:NextNumber() < 0.6
				P("Windows", V(w + 0.4, 2.2, dd + 0.4), cf * CF(0, y, 0), lit and BLACK:Lerp(pick(LIT), rnd(0.35, 0.75)) or rgb(28, 34, 46), lit and M.Neon or M.Glass)
			end
		end
		if dist < 220 and h > 16 and w > 12 and dd > 12 then
			P("RoofBox", V(w * 0.25, 3, dd * 0.25), cf * CF(w * 0.18, h + 1.5, -dd * 0.15), rgb(80, 82, 88), M.Metal)
		end
		if h > 220 then
			blinker(V(x, h + 2, z), 2.4)
		end
	end
	-- the replaced footprints (venue, landmarks) count as occupied ground too
	for i = 1, #d.X, 5 do
		if d.X[i + 2] > 0 then
			local a = math.rad(d.X[i + 4])
			groundAdd({ x = d.X[i], z = d.X[i + 1], hw = d.X[i + 2] / 2, hd = d.X[i + 3] / 2, c = math.cos(a), s = math.sin(a), ell = true })
		end
	end
	-- skyline beyond the map
	for _ = 1, o.skyline or 30 do
		local a = rnd(0, 2 * PI)
		local rr = rnd(half + 300, half + 900)
		farTower(math.cos(a) * rr, math.sin(a) * rr, rnd(40, 90), rnd(40, 90), rnd(60, o.skyMax or 220), pick({ rgb(40, 50, 70), rgb(60, 64, 76), rgb(70, 62, 56) }))
	end
	return d
end

-- puts the venue model onto the real footprint: X entry k (centre, size, yaw) and an extra turn in degrees
local function venueFrame(d, k, extra)
	local i = (k - 1) * 5 + 1
	FRAME = CF(d.X[i], 0, d.X[i + 1]) * ANG(0, -math.rad(d.X[i + 4] + (extra or 0)), 0)
	return d.X[i + 2], d.X[i + 3]
end
local function sceneFrame()
	FRAME = CFrame.new()
end

------------------------------------------------------------------ shared helpers for the stadium scenes
-- calls fn(mid, dir, out, len, i, angle) for n segments of the ellipse (a, b) around (0, 0)
local function ellRing(a, b, n, fn)
	for i = 0, n - 1 do
		local t0, t1 = i / n * 2 * PI, (i + 1) / n * 2 * PI
		local p0 = V(a * math.cos(t0), 0, b * math.sin(t0))
		local p1 = V(a * math.cos(t1), 0, b * math.sin(t1))
		local dir = p1 - p0
		local len = dir.Magnitude
		dir = dir.Unit
		fn((p0 + p1) / 2, dir, V(dir.Z, 0, -dir.X), len, i, (t0 + t1) / 2)
	end
end

-- a ring of blocks along an ellipse: width = radial thickness
local function ellBand(name, a, b, n, y, h, width, color, mat, tr)
	local parts = {}
	ellRing(a, b, n, function(mid, dir, _, len)
		local c = V(mid.X, y, mid.Z)
		table.insert(parts, P(name, V(width, h, len + 1.5), CFrame.lookAt(c, c + dir), color, mat, tr))
	end)
	return parts
end

-- inside of a stadium seen from above: stands in rings, pitch with floor cover, the stage at one end,
-- thousands of phone lights (a, b = inner edge of the roof; top = height of the last row)
local function bowlInside(a, b, top, seat, color, n)
	local a0, b0 = a * 0.5, b * 0.42
	P("Pitch", V(a0 * 2.1, 0.4, b0 * 2.1), CF(0, 0.2, 0), rgb(34, 92, 44), M.Grass)
	P("FloorCover", V(a0 * 1.5, 0.5, b0 * 1.7), CF(-a0 * 0.15, 0.3, 0), rgb(60, 62, 70), M.DiamondPlate)
	local rings = 7
	for k = 0, rings - 1 do
		local u = k / rings
		local ra, rb = a0 * 1.08 + (a - a0 * 1.08) * u, b0 * 1.12 + (b - b0 * 1.12) * u
		local w = (a - a0) / rings + 3
		ellBand("Stand", ra + w / 2, rb + w / 2, n, 2 + u * top, 4 + top / rings, w, (k % 2 == 0) and seat or seat:Lerp(BLACK, 0.25), M.Fabric)
	end
	-- the stage at the +x end: deck, LED wall, wings, light beams up through the open roof
	local sx = a0 * 0.95
	P("StageDeck", V(26, 10, b0 * 1.3), CF(sx, 5, 0), rgb(24, 24, 30))
	P("StageLED", V(3, 46, b0 * 1.1), CF(sx + 10, 33, 0), color, M.Neon)
	P("StageRoof", V(34, 4, b0 * 1.5), CF(sx + 2, 60, 0), rgb(40, 40, 46), M.Metal)
	for _, z in ipairs({ -b0 * 0.75, b0 * 0.75 }) do
		P("StageTower", V(8, 60, 8), CF(sx + 2, 30, z), rgb(60, 60, 70), M.Metal)
		P("SideScreen", V(2, 24, 30), CF(sx + 6, 34, z * 1.35), color:Lerp(WHITE, 0.3), M.Neon)
	end
	for i = 0, 7 do
		local z = -b0 * 0.6 + i * b0 * 1.2 / 7
		P("StageBeam", V(2.5, 160, 2.5), CF(sx - 4, 80, z) * ANG(rnd(-0.3, 0.3), 0, rnd(-0.35, 0.1)), (i % 2 == 0) and color or WHITE, M.Neon, 0.82)
	end
	-- phone lights on the floor and in the stands
	for _ = 1, 220 do
		local x, z = rnd(-a0 * 0.85, a0 * 0.55), rnd(-b0 * 0.8, b0 * 0.8)
		P("PhoneLight", V(1, 1, 1), CF(x, 3, z), (rng:NextNumber() < 0.7) and rgb(255, 255, 230) or color, M.Neon)
	end
	for _ = 1, 260 do
		local th, u = rnd(0, 2 * PI), rnd(0.05, 0.95)
		local ra, rb = a0 * 1.1 + (a - a0 * 1.1) * u, b0 * 1.14 + (b - b0 * 1.14) * u
		if math.cos(th) < 0.75 then
			P("PhoneLight", V(1, 1, 1), CF(math.cos(th) * ra, 6 + u * top, math.sin(th) * rb), rgb(255, 255, 230), M.Neon)
		end
	end
end

-- city block filler: a grid of buildings in a rectangle (keeps clear of the given boxes)
local function blocks(x0, z0, x1, z1, step, hMin, hMax, styles, keep)
	for gx = x0, x1, step do
		for gz = z0, z1, step do
			local x, z = gx + rnd(-step * 0.15, step * 0.15), gz + rnd(-step * 0.15, step * 0.15)
			local ok = true
			for _, k in ipairs(keep or {}) do
				if x > k[1] - 40 and x < k[3] + 40 and z > k[2] - 40 and z < k[4] + 40 then
					ok = false
				end
			end
			if ok then
				building(x, z, step * rnd(0.55, 0.75), step * rnd(0.55, 0.75), rnd(hMin, hMax), pick(styles), { setback = false })
			end
		end
	end
end

-- a straight road with lane markings, lamps on both sides and traffic in both directions
local function road(a, b, width, kinds, n, colors, speed, lampStep)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local side = V(dir.Z, 0, -dir.X)
	P("Road", V(width, 0.5, len), CFrame.lookAt(mid + V(0, 0.25, 0), mid + dir + V(0, 0.25, 0)), rgb(30, 30, 34), M.Asphalt)
	for _, sgn in ipairs({ -1, 1 }) do
		local c = mid + side * sgn * (width / 2 + 5)
		P("Sidewalk", V(10, 0.7, len), CFrame.lookAt(c + V(0, 0.35, 0), c + dir + V(0, 0.35, 0)), rgb(96, 96, 100), M.Pavement)
	end
	local d = 0
	while d < len do
		local p = a + dir * d
		P("LaneDash", V(0.6, 0.1, 10), CFrame.lookAt(p + V(0, 0.55, 0), p + dir + V(0, 0.55, 0)), rgb(230, 230, 230))
		d = d + 30
	end
	if lampStep then
		d = 10
		while d < len do
			for _, sgn in ipairs({ -1, 1 }) do
				local p = a + dir * d + side * sgn * (width / 2 + 3)
				streetLamp(p.X, p.Z, math.atan2(side.X * sgn, side.Z * sgn), 18)
			end
			d = d + lampStep
		end
	end
	if n and n > 0 then
		lane(a + side * (width * 0.25) + V(0, 0.3, 0), b + side * (width * 0.25) + V(0, 0.3, 0), n, kinds, colors, speed)
		lane(b - side * (width * 0.25) + V(0, 0.3, 0), a - side * (width * 0.25) + V(0, 0.3, 0), n, kinds, colors, speed)
	end
end

local SCENES = {}

------------------------------------------------------------------ 1) THE O3 (London, Greenwich Peninsula)
SCENES[1] = {
	name = "The O3 Arena",
	city = "London - Greenwich Peninsula",
	tonight = "NOVA RAY",
	color = rgb(255, 105, 180),
	clock = 20.4,
	haze = 1.8,
	keys = {
		{ t = 0, p = V(-1300, 36, 420), l = V(-400, 60, 100) },
		{ t = 7, p = V(-950, 40, 260), l = V(0, 80, 0) },
		{ t = 13, p = V(-620, 60, 80), l = V(0, 110, 0) },
		{ t = 19, p = V(-400, 175, -110), l = V(100, 120, 100) },
		{ t = 25, p = V(-60, 265, 120), l = V(150, 60, 520) },
		{ t = 31, p = V(240, 150, 560), l = V(60, 40, 300) },
		{ t = 37, p = V(380, 75, 760), l = V(40, 40, 380) },
		{ t = 44, p = V(-170, 48, 780), l = V(0, 60, 330) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("o3", { cars = { "cab", "cab", "car", "dd" }, skyline = 30 })
		-- the dome sits on its real footprint; the entrance (local +z) faces Peninsula Square
		FRAME = CF(d.X[1], 0, d.X[2]) * ANG(0, 0.25, 0)
		-- DOME: PTFE membrane, 365 m wide (730 studs), ~50 m high (100 studs)
		local R, H = 365, 100
		ellip("Dome", V(R * 2, H * 2, R * 2), CF(0, 0, 0), rgb(226, 222, 240), M.Fabric)
		for i = 0, 35 do
			local a = i * PI / 18
			P("DomeUplight", V(3, 1.2, 3), CF(math.cos(a) * 372, 0.6, math.sin(a) * 372), (i % 2 == 0) and color or rgb(90, 140, 255), M.Neon)
		end
		local function surf(r, a, lift)
			local y = H * math.sqrt(math.max(0, 1 - (r / R) ^ 2))
			return V(math.cos(a) * (r + lift), y + lift, math.sin(a) * (r + lift))
		end
		-- radial cables and circumferential rings on the membrane
		local RS = { 362, 352, 335, 312, 282, 245, 200, 150, 95, 40 }
		for i = 0, 47 do
			local a = i * PI / 24
			for k = 1, #RS - 1 do
				bar("DomeCable", surf(RS[k], a, 1.6), surf(RS[k + 1], a, 1.6), 0.6, rgb(205, 200, 196))
			end
		end
		for _, r in ipairs({ 312, 245, 150 }) do
			for i = 0, 47 do
				bar("DomeRing", surf(r, i * PI / 24, 1.5), surf(r, (i + 1) * PI / 24, 1.5), 0.5, rgb(205, 200, 196))
			end
		end
		cylV("DomeVent", 6, 60, V(0, H + 2, 0), rgb(200, 198, 204), M.Metal)
		-- 12 yellow masts (~100 m = 200 studs), slightly inclined, poking through the roof
		for i = 0, 11 do
			local a = i * PI / 6
			local dir = V(math.cos(a), 0, math.sin(a))
			local foot = dir * 200
			local top = dir * 232 + V(0, 200, 0)
			local mid = foot:Lerp(top, 0.62)
			tube("Mast", foot, top, 4.4, rgb(255, 196, 0))
			for k = 0, 2 do
				local sa = a + k * 2 * PI / 3
				local arm = mid + V(math.cos(sa) * 9, 0, math.sin(sa) * 9)
				tube("MastSpreader", mid, arm, 1.4, rgb(255, 196, 0))
				bar("MastTie", arm, top, 0.5, rgb(230, 200, 60))
				bar("MastTie", arm, foot:Lerp(top, 0.45), 0.5, rgb(230, 200, 60))
			end
			P("MastCap", V(5, 3, 5), CFrame.lookAt(top, top + dir), rgb(255, 196, 0), M.Metal)
			blinker(top + V(0, 2.6, 0), 2.2)
			for _, c in ipairs({ { 330, 0.1 }, { 330, -0.1 }, { 150, 0.16 }, { 150, -0.16 }, { 250, 0 } }) do
				bar("HangCable", top, surf(c[1], a + c[2], 1), 0.45, rgb(220, 220, 224))
			end
		end
		-- "Up at the O3": fabric walkway across the roof with climbers
		local wa = 1.9
		local last = nil
		for k = 0, 9 do
			local r = 360 - k * 38
			local p = surf(r, wa, 2.4)
			if last then
				bar("Walkway", last, p, 4, rgb(214, 196, 150), M.Fabric)
				if k % 2 == 0 then
					P("Climber", V(1.4, 2.6, 1), CF(p + V(0, 2, 0)), pick({ rgb(255, 120, 30), rgb(40, 120, 255) }))
				end
			end
			last = p
		end
		P("ViewPlatform", V(18, 1.2, 12), CF(surf(10, wa, 3)), rgb(150, 150, 156), M.DiamondPlate)
		-- entrance: glazed hall with the O-logo, canopy, LED screens
		local ez = R - 40
		-- glass front with a real lobby behind it (dark back wall, lit ceiling, people) - you never look through
		P("Lobby", V(140, 36, 50), CF(0, 18, ez + 30), rgb(24, 22, 26), M.Concrete)
		P("LobbyFloor", V(146, 1, 22), CF(0, 0.6, ez + 64), rgb(70, 64, 60), M.Marble)
		P("LobbyCeiling", V(144, 1, 20), CF(0, 34, ez + 64), BLACK:Lerp(WARM, 0.75), M.Neon)
		for k = -3, 3 do
			P("LobbyLight", V(2, 30, 0.6), CF(k * 20, 18, ez + 55.2), BLACK:Lerp(WARM, 0.55), M.Neon)
		end
		for _ = 1, 22 do
			fan(V(rnd(-64, 64), 1.1, ez + rnd(60, 72)), pick(SHIRTS), 0, nil, true)
		end
		P("EntranceHall", V(150, 40, 70), CF(0, 20, ez + 40), rgb(70, 110, 150), M.Glass, 0.45, 0.25)
		for i = -7, 7 do
			P("Mullion", V(0.8, 40, 0.8), CF(i * 10, 20, ez + 75.5), rgb(180, 186, 196), M.Metal)
		end
		P("Canopy", V(170, 2, 30), CF(0, 41, ez + 85), rgb(60, 62, 70), M.Metal)
		P("CanopyGlow", V(170, 0.5, 2), CF(0, 40, ez + 99.5), color, M.Neon)
		cyl("LogoRing", 1.5, 34, CF(0, 62, ez + 80) * ANG(0, PI / 2, 0), rgb(30, 140, 255), M.Neon)
		cyl("LogoInner", 1.7, 27, CF(0, 62, ez + 80) * ANG(0, PI / 2, 0), rgb(10, 20, 50), M.SmoothPlastic)
		local nb = P("NameBoard", V(26, 12, 0.5), CF(0, 62, ez + 81.2), rgb(10, 20, 50))
		sign(nb, Enum.NormalId.Back, "O3", WHITE, nil, 20)
		ledScreen(CF(-110, 26, ez + 90) * ANG(0, PI, 0), 44, 22, { "NOVA RAY\nLIVE TONIGHT", "SOLD OUT", "THE STARLIGHT TOUR" }, rgb(200, 40, 140), Enum.NormalId.Front)
		ledScreen(CF(110, 26, ez + 90) * ANG(0, PI, 0), 44, 22, { "NOVA RAY", "DOORS 18:30", "TONIGHT" }, rgb(40, 40, 120), Enum.NormalId.Front)
		for _, x in ipairs({ -110, 110 }) do
			P("ScreenLeg", V(1.6, 15, 1.6), CF(x, 7.5, ez + 91), rgb(40, 40, 46), M.Metal)
		end
		-- peninsula square: plaza, fans, queues, food stalls
		for i = -2, 2 do
			line(V(i * 26, 0.5, ez + 170), V(0, 0, -1), 64, 0.5, color)
		end
		mingle(0, ez + 200, 210, 90, 70, 0.5, color)
		mingle(120, 590, 140, 30, 18, 0.5, color)
		mingle(-380, 300, 60, 160, 10, 0.6, color)
		for i = -4, 4 do
			staff(V(i * 16, 0.5, ez + 98), "security")
		end
		for i = 1, 4 do
			staff(V(rnd(-120, 120), 0.5, ez + rnd(140, 260)), "photo")
		end
		for i = 1, 12 do
			local z0 = rnd(-300, 400)
			walker(V(-534, 0.6, z0), V(-534, 0.6, z0 + rnd(80, 160)))
		end
		for i, a in ipairs({ "NOVA RAY", "STARLYTE", "IRONCLAD", "LUNA SOL", "KAI RIVERS" }) do
			banner(V(-200 + i * 66, 0.5, ez + 250), a, ({ color, rgb(150, 90, 255), rgb(120, 120, 130), rgb(255, 120, 60), rgb(255, 190, 40) })[i], 0)
		end
		for k = 0, 3 do
			local x = -200 + k * 130
			P("FoodTruck", V(10, 9, 22), CF(x, 4.5, ez + 300), pick({ rgb(240, 240, 240), rgb(40, 120, 200), rgb(220, 60, 60) }))
			P("TruckHatch", V(0.4, 3.4, 14), CF(x + 5.1, 6, ez + 300), WARM, M.Neon)
		end
		for i = -5, 5 do
			streetLamp(i * 40, ez + 330, 0, 16)
		end
		for i = 1, 22 do
			local x0 = rnd(-220, 220)
			walker(V(x0, 0.5, ez + 330), V(x0 + rnd(-60, 60), 0.5, ez + 130))
		end
		searchlights({
			{ pos = V(-90, 1, ez + 120), color = rgb(255, 160, 220), ph = 0 },
			{ pos = V(90, 1, ez + 120), color = rgb(200, 220, 255), ph = 2 },
			{ pos = V(0, 1, ez + 260), color = color, ph = 4, speed = 0.25 },
		})
		sceneFrame()
		-- river boats on the Thames west of the peninsula
		for k = 0, 2 do
			local boat = {
				{ P("Boat", V(8, 4, 30), CF(), rgb(230, 230, 236)), CF(0, 1.5, 0) },
				{ P("BoatCabin", V(6, 4, 14), CF(), rgb(40, 60, 90), M.Glass), CF(0, 5, 2) },
				{ P("BoatLights", V(6.2, 0.6, 14.2), CF(), WARM, M.Neon), CF(0, 6.6, 2) },
			}
			vehicle(boat, V(-930, 0.6, -500), V(-1050, 0.6, 1300), 9, k * 0.33)
		end
	end,
}

------------------------------------------------------------------ 2) MADISON CIRCLE GARDEN (New York, 7th/8th Ave, 31st-33rd St)
SCENES[2] = {
	name = "Madison Circle Garden",
	city = "New York - Midtown Manhattan",
	tonight = "STARLYTE",
	color = rgb(150, 90, 255),
	clock = 20.8,
	haze = 1.4,
	keys = {
		{ t = 0, p = V(365, 27, -1480), l = V(362, 30, -1100) },
		{ t = 7, p = V(358, 26, -980), l = V(356, 32, -600) },
		{ t = 13, p = V(352, 30, -580), l = V(320, 46, -250) },
		{ t = 18, p = V(360, 50, -262), l = V(200, 60, -80) },
		{ t = 23, p = V(230, 85, -150), l = V(0, 50, 0) },
		{ t = 29, p = V(0, 160, -150), l = V(0, 40, 10) },
		{ t = 35, p = V(-260, 140, 120), l = V(0, 40, 0) },
		{ t = 41, p = V(80, 122, 170), l = V(0, 46, 0) },
		{ t = 47, p = V(380, 40, 200), l = V(200, 34, 60) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("msg", { cars = { "taxi", "taxi", "car", "bus" }, traffic = 10, skyline = 40, skyMax = 420 })
		FRAME = CF(d.X[1], 0, d.X[2])
		-- MADISON CIRCLE GARDEN: drum ~123 m (246 studs), 48 roof cables, ~46 m high
		local C = V(0, 0, 0)
		local beige = rgb(196, 186, 168)
		cylV("Podium", 10, 262, C + V(0, 5, 0), rgb(120, 118, 116), M.Concrete)
		cylV("ConcourseGlass", 22, 250, C + V(0, 21, 0), rgb(60, 80, 100), M.Glass, 0.3)
		cylV("ConcourseGlow", 20, 246, C + V(0, 21, 0), BLACK:Lerp(WARM, 0.7), M.Neon, 0.25)
		cylV("Drum", 62, 244, C + V(0, 63, 0), beige, M.Concrete)
		for i = 0, 47 do
			local a = i * PI / 24
			local dir = V(math.cos(a), 0, math.sin(a))
			local cfF = CFrame.lookAt(C + dir * 124 + V(0, 58, 0), C + dir * 200 + V(0, 58, 0))
			P("Fin", V(3, 84, 5), cfF, rgb(214, 206, 190), M.Concrete)
			P("FinWash", V(2.4, 26, 0.3), cfF * CF(0, -26, -2.65), color, M.Neon, 0.35)
			P("FinUplight", V(2.6, 0.8, 1.2), cfF * CF(0, -41, -3), WHITE, M.Neon)
			-- roof cable from the rim to the centre ring
			bar("RoofCable", C + dir * 120 + V(0, 98, 0), C + dir * 13 + V(0, 104, 0), 0.8, rgb(150, 150, 156))
		end
		cylV("Cornice", 5, 254, C + V(0, 97, 0), rgb(70, 72, 78), M.Metal)
		cylV("TopBand", 2, 256, C + V(0, 91, 0), color, M.Neon)
		cylV("Roof", 3, 244, C + V(0, 98, 0), rgb(120, 122, 128), M.Metal)
		cylV("RoofRing", 4, 26, C + V(0, 104, 0), rgb(90, 92, 98), M.Metal)
		-- name panels on the drum
		for _, a in ipairs({ -PI / 2 + 0.25, PI / 2 + 0.3 }) do
			local dir = V(math.cos(a), 0, math.sin(a))
			local pnl = P("NamePanel", V(70, 12, 1), CFrame.lookAt(C + dir * 128 + V(0, 76, 0), C + dir * 300 + V(0, 76, 0)), BLACK)
			sign(pnl, Enum.NormalId.Front, "MADISON CIRCLE GARDEN", WHITE, rgb(20, 20, 30), 8)
		end
		sceneFrame()
		-- 7th Avenue side (+x): marquee, LED screen, queues and street life
		local ax = 344 -- west sidewalk of 7th Ave
		P("Canopy", V(16, 2.4, 140), CF(ax - 6, 30, -10), rgb(50, 52, 60), M.Metal)
		P("CanopyGlow", V(0.6, 0.6, 140), CF(ax + 2, 29, -10), WHITE, M.Neon)
		local mq = P("Marquee", V(2, 12, 120), CF(ax + 2, 38, -10), BLACK)
		sign(mq, Enum.NormalId.Right, "MADISON CIRCLE GARDEN", WHITE, rgb(18, 18, 26), 8)
		ledScreen(CF(ax + 6, 24, -170) * ANG(0, PI / 2, 0), 34, 20, { "STARLYTE\nTONIGHT", "SOLD OUT", "DREAMWAVE\nWORLD TOUR" }, rgb(110, 60, 220), Enum.NormalId.Back)
		P("LEDPost", V(2, 14, 2), CF(ax + 6, 7, -170), rgb(40, 40, 46), M.Metal)
		for k = 0, 2 do
			line(V(ax + 4 + k * 4, 0.8, -120), V(0, 0, 1), 200, 0.8, color)
		end
		for z = -1400, 600, 60 do
			if rng:NextNumber() < 0.6 then
				mingle(ax + rnd(-2, 4), z, 1, 10, 1, 0.6, color)
			end
			if rng:NextNumber() < 0.6 then
				mingle(380 + rnd(-2, 2), z + 30, 1, 10, 1, 0.6, color)
			end
		end
		mingle(100, -150, 120, 6, 16, 0.6, color) -- 33rd Street
		for k = 0, 5 do
			staff(V(ax, 0.8, -80 + k * 30), "security")
		end
		staff(V(370, 0.2, 40), "photo")
		hotdogCart(V(ax + 8, 0.6, -230), PI / 2)
		hotdogCart(V(ax + 8, 0.6, 160), PI / 2)
		for i = 1, 14 do
			walker(V(ax + 6, 0.6, -1400 + i * 100), V(ax + 6, 0.6, -1400 + i * 100 + rnd(60, 140)))
			walker(V(384, 0.6, -1450 + i * 100), V(384, 0.6, -1450 + i * 100 + rnd(60, 140)))
		end
		searchlights({
			{ pos = V(250, 1, -150), color = color, ph = 0 },
			{ pos = V(250, 1, 160), color = rgb(220, 230, 255), ph = 2.5 },
		})
		-- Empire State style tower two avenues east (lit in the artist colour)
		local ex, ez = d.A.empire[1], d.A.empire[2]
		local es = STYLES.stone
		tierBox(CF(ex, 0, ez), 220, 110, 0, 44, es, 1, false)
		tierBox(CF(ex, 0, ez), 160, 96, 44, 140, es, 1, false)
		tierBox(CF(ex, 0, ez), 110, 80, 140, 590, es, 1, false)
		tierBox(CF(ex, 0, ez), 90, 66, 590, 640, es, 1, false)
		tierBox(CF(ex, 0, ez), 70, 52, 640, 680, es, 1, false)
		for k = 0, 4 do
			local s2 = 46 - k * 7
			P("ESBCrown", V(s2, 14, s2 * 0.8), CF(ex, 687 + k * 14, ez), (k % 2 == 0) and color or WHITE, M.Neon)
		end
		cylV("ESBMast", 90, 4, V(ex, 800, ez), rgb(190, 190, 200), M.Metal)
		blinker(V(ex, 846, ez), 3)
	end,
}

------------------------------------------------------------------ 3) LANXUS ARENA (Cologne, Deutz) with the cathedral across the Rhine
SCENES[3] = {
	name = "Lanxus Arena",
	city = "Cologne - Deutz",
	tonight = "IRONCLAD",
	color = rgb(230, 60, 50),
	clock = 20.6,
	haze = 1.5,
	keys = {
		{ t = 0, p = V(-2900, 42, -380), l = V(-3480, 165, -640) },
		{ t = 6, p = V(-2860, 78, -520), l = V(-3480, 180, -640) },
		{ t = 11, p = V(-2480, 86, -760), l = V(-1900, 70, -660) },
		{ t = 17, p = V(-1980, 64, -700), l = V(-1200, 60, -500) },
		{ t = 23, p = V(-1300, 66, -470), l = V(-500, 70, -150) },
		{ t = 29, p = V(-660, 64, -240), l = V(0, 70, 0) },
		{ t = 35, p = V(-380, 96, 160), l = V(0, 70, 0) },
		{ t = 41, p = V(80, 150, 360), l = V(0, 60, 0) },
		{ t = 47, p = V(380, 190, 60), l = V(0, 60, 0) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("lanxus", { cars = { "car", "car", "taxi" }, skyline = 30 })
		-- cathedral on its real place (the model is built around x = -1480, z = -180)
		FRAME = CF(d.X[6] + 1480, 0, d.X[7] + 180)
		-- CATHEDRAL (west bank): twin spires 157 m (314 studs), nave vault ~43 m
		local cz = -180
		local stone = rgb(176, 156, 126) -- floodlit at night
		local dark = rgb(96, 88, 80)
		local winC = BLACK:Lerp(rgb(255, 190, 110), 0.55)
		P("Nave", V(250, 86, 64), CF(-1470, 43, cz), stone, M.Sandstone)
		gable(CF(-1470, 86, cz), 250, 66, 36, dark, M.Slate)
		for _, s in ipairs({ -1, 1 }) do
			P("Aisle", V(250, 40, 26), CF(-1470, 20, cz + s * 45), stone, M.Sandstone)
			W("AisleRoof", V(250, 10, 26), CF(-1470, 45, cz + s * 45) * ANG(0, s > 0 and PI or 0, 0), dark, M.Slate)
			for k = 0, 9 do
				local x = -1580 + k * 24
				P("NaveWin", V(6, 30, 0.4), CF(x, 62, cz + s * 32.3), winC, M.Neon)
				P("AisleWin", V(6, 22, 0.4), CF(x, 18, cz + s * 58.3), winC, M.Neon)
				P("Pinnacle", V(3, 24, 3), CF(x, 52, cz + s * 58), stone, M.Sandstone)
				P("PinnacleTip", V(1.4, 8, 1.4), CF(x, 68, cz + s * 58), stone, M.Sandstone)
				bar("Buttress", V(x, 58, cz + s * 58), V(x, 80, cz + s * 33), 2, stone, M.Sandstone)
			end
		end
		P("Transept", V(56, 86, 170), CF(-1440, 43, cz), stone, M.Sandstone)
		gable(CF(-1440, 86, cz) * ANG(0, PI / 2, 0), 170, 58, 32, dark, M.Slate)
		for _, s in ipairs({ -1, 1 }) do
			P("RoseWindow", V(20, 20, 0.4), CF(-1440, 58, cz + s * 85.3), winC, M.Neon)
		end
		P("CrossingTower", V(10, 40, 10), CF(-1440, 136, cz), dark, M.Slate)
		P("CrossingSpire", V(4, 30, 4), CF(-1440, 170, cz), dark, M.Slate)
		cylV("Choir", 86, 64, V(-1345, 43, cz), stone, M.Sandstone)
		for k = 0, 6 do
			local a = -PI / 2 + k * PI / 6
			local p = V(-1345 + math.cos(a) * 33, 0, cz + math.sin(a) * 33)
			P("ChoirWin", V(0.4, 34, 6), CFrame.lookAt(V(p.X, 60, p.Z), V(-1345, 60, cz)), winC, M.Neon)
			P("ChoirPinnacle", V(3, 30, 3), CF(-1345 + math.cos(a) * 46, 50, cz + math.sin(a) * 46), stone, M.Sandstone)
		end
		for _, s in ipairs({ -1, 1 }) do
			local tz = cz + s * 36
			local tx = -1620
			P("Tower", V(52, 150, 52), CF(tx, 75, tz), stone, M.Sandstone)
			P("TowerWin", V(53, 50, 14), CF(tx, 100, tz), BLACK:Lerp(rgb(255, 190, 110), 0.25), M.Neon)
			P("TowerOct", V(40, 80, 40), CF(tx, 190, tz), stone, M.Sandstone)
			P("TowerOct", V(40, 80, 40), CF(tx, 190, tz) * ANG(0, PI / 4, 0), stone, M.Sandstone)
			for _, c in ipairs({ { -24, -24 }, { 24, -24 }, { -24, 24 }, { 24, 24 } }) do
				P("TowerPinnacle", V(4, 60, 4), CF(tx + c[1], 170, tz + c[2]), stone, M.Sandstone)
				P("TowerPinnacleTip", V(2, 14, 2), CF(tx + c[1], 207, tz + c[2]), stone, M.Sandstone)
			end
			for k = 0, 5 do
				local w = 34 - k * 5.6
				P("Spire", V(w, 15, w), CF(tx, 237 + k * 15, tz) * ANG(0, (k % 2) * PI / 4, 0), stone, M.Sandstone)
			end
			P("Finial", V(4, 10, 4), CF(tx, 312, tz), stone, M.Sandstone)
			P("Finial", V(10, 3, 3), CF(tx, 308, tz), stone, M.Sandstone)
			local fl = P("Floodlight", V(3, 1, 3), CF(tx + 50, 0.8, tz), WARM, M.Neon)
			New("SpotLight", { Face = Enum.NormalId.Top, Angle = 50, Range = 60, Brightness = 3, Color = WARM, Parent = fl })
		end
		P("WestFront", V(10, 120, 40), CF(-1650, 60, cz), stone, M.Sandstone)
		P("Portal", V(1, 50, 20), CF(-1656, 25, cz), BLACK:Lerp(WARM, 0.45), M.Neon)
		P("DomPlatz", V(200, 0.6, 320), CF(-1480, 0.3, cz), rgb(110, 104, 96), M.Cobblestone)
		sceneFrame()
		-- Hohenzollern bridge: three bowstring arches per span along the real railway bridge
		local bx0, bx1, bz, n = 1e9, -1e9, 0, 0
		for i = 1, #d.R, 6 do
			if d.R[i + 5] == 16 and math.abs(d.R[i + 1] - d.X[7]) < 160 and d.R[i] < -1700 and d.R[i] > -2900 then
				bx0 = math.min(bx0, d.R[i], d.R[i + 2])
				bx1 = math.max(bx1, d.R[i], d.R[i + 2])
				bz = bz + (d.R[i + 1] + d.R[i + 3]) / 2
				n = n + 1
			end
		end
		if n > 0 then
			bz = bz / n
			local by = 10
			local spanL = (bx1 - bx0) / 3
			for sp = 0, 2 do
				local s0 = bx0 + sp * spanL
				for _, dz in ipairs({ -16, 0, 16 }) do
					local lastA = nil
					for i = 0, 10 do
						local u = i / 10
						local p = V(s0 + spanL * u, by + 2 + 50 * math.sin(u * PI), bz + dz)
						if lastA then
							bar("BridgeArch", lastA, p, 2.4, rgb(80, 104, 92))
							bar("BridgeHanger", p, V(p.X, by, bz + dz), 0.6, rgb(80, 104, 92))
						end
						lastA = p
					end
				end
				P("BridgePier", V(14, by, 44), CF(s0, by / 2, bz), rgb(120, 110, 100), M.Granite)
			end
			P("BridgeLightLine", V(bx1 - bx0, 0.4, 0.4), CF((bx0 + bx1) / 2, by + 2, bz - 20), rgb(255, 230, 180), M.Neon)
			for k = 0, 3 do
				local tr = carParts("train", rgb(240, 240, 245))
				vehicle(tr, V(bx0 - 600, by + 0.6, bz + ((k % 2 == 0) and -6 or 6)), V(bx1 + 900, by + 0.6, bz + ((k % 2 == 0) and -6 or 6)), (k % 2 == 0) and 40 or -40, k * 0.25)
			end
		end
		-- the arena on its footprint: entrance (local +z) towards Willy-Brandt-Platz and the station
		FRAME = CF(d.X[1], 0, d.X[2]) * ANG(0, -math.rad(d.X[5]), 0)
		-- LANXUS ARENA: hall with rounded ends, glass facade, steel arch 76 m (152 studs)
		local hallH = 72
		P("HallCore", V(120, 14, 190), CF(0, 7, 0), rgb(110, 110, 114), M.Concrete)
		P("HallGlass", V(120, hallH - 14, 190), CF(0, 14 + (hallH - 14) / 2, 0), rgb(60, 84, 104), M.Glass, 0.2, 0.18)
		P("HallGlow", V(116, hallH - 18, 186), CF(0, 14 + (hallH - 14) / 2, 0), BLACK:Lerp(WARM, 0.5), M.Neon, 0.5)
		for _, s in ipairs({ -1, 1 }) do
			local ec = V(s * 60, 0, 0)
			cylV("HallEndCore", 14, 190, ec + V(0, 7, 0), rgb(110, 110, 114), M.Concrete)
			cylV("HallEnd", hallH - 14, 190, ec + V(0, 14 + (hallH - 14) / 2, 0), rgb(60, 84, 104), M.Glass, 0.2)
			cylV("HallEndGlow", hallH - 18, 186, ec + V(0, 14 + (hallH - 14) / 2, 0), BLACK:Lerp(WARM, 0.5), M.Neon, 0.5)
			cylV("HallEndRoof", 4, 192, ec + V(0, hallH + 2, 0), rgb(70, 72, 78), M.Metal)
			for k = -6, 6 do
				local a = k * PI / 14
				local dir = V(s * math.cos(a), 0, math.sin(a))
				P("EndMullion", V(1, hallH - 14, 1), CF(ec + dir * 95.5 + V(0, 14 + (hallH - 14) / 2, 0)), rgb(170, 176, 186), M.Metal)
			end
			for y = 26, hallH - 4, 12 do
				cylV("EndBand", 1.4, 192, ec + V(0, y, 0), rgb(170, 176, 186), M.Metal)
			end
		end
		for y = 26, hallH - 4, 12 do
			P("Band", V(121, 1.4, 192), CF(0, y, 0), rgb(170, 176, 186), M.Metal)
		end
		for k = -6, 6 do
			for _, s in ipairs({ -1, 1 }) do
				P("Mullion", V(1, hallH - 14, 1), CF(k * 10, 14 + (hallH - 14) / 2, s * 95.5), rgb(170, 176, 186), M.Metal)
			end
		end
		P("HallRoof", V(122, 4, 192), CF(0, hallH + 2, 0), rgb(70, 72, 78), M.Metal)
		P("RoofEdgeGlow", V(124, 1, 194), CF(0, hallH - 1, 0), color, M.Neon)
		-- the arch (feet outside the hall), roof hangers
		local span = 215
		local last = nil
		for i = 0, 30 do
			local u = i / 30
			local x = -span + 2 * span * u
			local p = V(x, 152 * (1 - (x / span) ^ 2) + 4, 0)
			if last then
				tube("Arch", last, p, 8, rgb(226, 228, 234))
				if i % 3 == 0 and p.Y > hallH + 10 and math.abs(x) < 150 then
					bar("Hanger", p, V(x * 0.9, hallH + 4, 70), 0.6, rgb(210, 210, 216))
					bar("Hanger", p, V(x * 0.9, hallH + 4, -70), 0.6, rgb(210, 210, 216))
				end
			end
			last = p
		end
		for _, s in ipairs({ -1, 1 }) do
			P("ArchFoot", V(22, 10, 22), CF(s * span, 5, 0), rgb(130, 130, 134), M.Concrete)
			local fl = P("ArchLight", V(3, 1, 3), CF(s * (span - 16), 1, 0), WARM, M.Neon)
			New("SpotLight", { Face = Enum.NormalId.Top, Angle = 40, Range = 60, Brightness = 2, Color = rgb(220, 230, 255), Parent = fl })
		end
		-- entrance on the plaza side (+Z)
		P("EntranceCanopy", V(110, 2, 30), CF(0, 16, 110), rgb(50, 52, 58), M.Metal)
		P("EntranceGlow", V(100, 12, 0.5), CF(0, 7, 96), BLACK:Lerp(WARM, 0.8), M.Neon)
		local nm = P("NameSign", V(120, 14, 1), CF(0, 60, 97), BLACK)
		sign(nm, Enum.NormalId.Back, "LANXUS ARENA", WHITE, rgb(20, 40, 110), 8)
		ledScreen(CF(-90, 28, 128) * ANG(0, PI, 0), 40, 22, { "IRONCLAD\nTONIGHT", "FORGED IN FIRE\nTOUR", "SOLD OUT" }, rgb(150, 20, 30), Enum.NormalId.Front)
		ledScreen(CF(90, 28, 128) * ANG(0, PI, 0), 40, 22, { "IRONCLAD", "DOORS 19:00", "WELCOME!" }, rgb(40, 40, 50), Enum.NormalId.Front)
		for _, x in ipairs({ -90, 90 }) do
			P("ScreenLeg", V(1.6, 17, 1.6), CF(x, 8.5, 129), rgb(40, 40, 46), M.Metal)
		end
		-- plaza life: queues, crowd, food trucks, beer stand, banners
		for i = -2, 2 do
			line(V(i * 20, 0.65, 170), V(0, 0, -1), 56, 0.65, rgb(40, 40, 44))
		end
		mingle(0, 220, 190, 70, 66, 0.65, rgb(40, 40, 44))
		mingle(220, 245, 14, 10, 4, 0.65, rgb(40, 40, 44))
		mingle(-330, 168, 120, 3, 8, 0.5, rgb(40, 40, 44))
		for i = -4, 4 do
			staff(V(i * 14, 0.6, 104), "security")
		end
		for i = 1, 3 do
			staff(V(rnd(-150, 150), 0.65, rnd(150, 290)), "photo")
		end
		for k = 0, 3 do
			local x = -180 + k * 120
			P("FoodTruck", V(22, 9, 10), CF(x, 4.8, 270), pick({ rgb(240, 240, 240), rgb(230, 170, 40), rgb(40, 40, 46) }))
			P("TruckHatch", V(14, 3.4, 0.4), CF(x, 6.2, 264.8), WARM, M.Neon)
		end
		P("BeerStand", V(20, 10, 10), CF(220, 5.6, 230), rgb(200, 40, 40), M.WoodPlanks)
		local bs = P("BeerSign", V(18, 4, 0.4), CF(220, 12.6, 235.4), BLACK)
		sign(bs, Enum.NormalId.Back, "KOELSCH", WHITE, rgb(200, 30, 30), 12)
		for i, a in ipairs({ "IRONCLAD", "THE RUSTY WIRES", "NEON HARBOR", "DJ VOLTAGE" }) do
			banner(V(-170 + i * 68, 0.6, 300), a, ({ rgb(90, 90, 100), rgb(230, 90, 60), rgb(60, 200, 160), rgb(80, 120, 255) })[i], 0)
		end
		for i = -5, 5 do
			streetLamp(i * 40, 315, 0, 16)
		end
		for i = 1, 22 do
			local x0 = rnd(-220, 220)
			walker(V(x0, 0.6, 330), V(x0 + rnd(-50, 50), 0.6, 140))
		end
		for i = 1, 8 do
			local x0 = rnd(-700, -300)
			walker(V(x0, 0.6, 158), V(x0 + rnd(80, 160), 0.6, 158))
		end
		searchlights({
			{ pos = V(-120, 1, 120), color = color, ph = 0 },
			{ pos = V(120, 1, 120), color = rgb(220, 230, 255), ph = 3 },
		})
		-- distant skyline (Cologne is low, a few towers)
		for _ = 1, 22 do
			local x, zz = rnd(-2100, 1500), rnd(-1600, 1400)
			if (x > 900 or zz > 1050 or zz < -700) and (x > -700) then
				farTower(x, zz, rnd(40, 80), rnd(40, 80), rnd(60, 200), pick({ rgb(50, 54, 62), rgb(70, 66, 60) }))
			end
		end
		sceneFrame()
	end,
}

------------------------------------------------------------------ 4) HALL OF THE STADIUM (Zurich-Oerlikon)
-- Hallenstadion: opened 1939, rebuilt 2004-05, about 13,000 at concerts (15,000 max). Main entrance on the
-- south side: a wide forecourt, then the street with the tram; a second entrance on the north side.
SCENES[4] = {
	name = "Hall of the Stadium",
	city = "Zurich - Oerlikon",
	tonight = "VELVET JUNE",
	color = rgb(255, 60, 70),
	clock = 20.3,
	haze = 1.4,
	keys = {
		{ t = 0, p = V(-720, 74, 262), l = V(-200, 40, 240) },
		{ t = 7, p = V(-470, 52, 266), l = V(-150, 40, 220) },
		{ t = 14, p = V(-300, 36, 310), l = V(0, 40, 160) },
		{ t = 20, p = V(-60, 46, 380), l = V(0, 36, 140) },
		{ t = 26, p = V(220, 66, 330), l = V(0, 40, 60) },
		{ t = 32, p = V(360, 120, 20), l = V(0, 40, 40) },
		{ t = 38, p = V(150, 160, -330), l = V(0, 30, 40) },
		{ t = 44, p = V(-260, 110, -220), l = V(0, 30, 60) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("zurich", { cars = { "car", "car", "bus" }, skyline = 26, skyMax = 160 })
		-- the hall on its footprint; local x = long axis (north-south), local +x = south
		local fw, fd = venueFrame(d, 1)
		local hl, hwid, hh = fw * 0.4, fd * 0.42, 56
		local wall = rgb(196, 198, 204)
		local ex = d.X[5] -- turn the entrances so that local +x points south
		local _ = ex
		P("HallCore", V(hl * 2 - hwid * 1.2, hh, hwid * 2), CF(0, hh / 2, 0), wall, M.Concrete)
		for _, sx in ipairs({ -1, 1 }) do
			cylV("HallEnd", hh, hwid * 2, V(sx * (hl - hwid), hh / 2, 0), wall, M.Concrete)
			for k = 0, 4 do
				cylV("FacadeBandEnd", 2.2, hwid * 2 + 1 + (k % 2) * 0.2, V(sx * (hl - hwid), 8 + k * 10, 0), rgb(150, 156, 168), M.Metal)
			end
		end
		for k = 0, 4 do
			P("FacadeBand", V(hl * 2 - hwid * 1.2 + 0.4, 2.2, hwid * 2 + 1), CF(0, 8 + k * 10 + 0.05, 0), rgb(150, 156, 168), M.Metal)
		end
		for k = -3, 3 do
			P("Roof", V(hl * 2 - hwid * 0.8, 3, hwid * 2 / 7 + 2), CF(0, hh + 4 - math.abs(k) * 1.2, k * hwid * 2 / 7), rgb(120, 124, 130), M.Metal)
		end
		-- the two entrances: glass foyers with a lit lobby behind (south = main entrance with the name)
		for _, sx in ipairs({ 1, -1 }) do
			local fx = sx * (hl + 8)
			P("FoyerLobby", V(20, 22, hwid * 1.4), CF(fx - sx * 2, 11, 0), rgb(26, 24, 28), M.Concrete)
			P("FoyerCeiling", V(10, 1, hwid * 1.4), CF(fx + sx * 6, 21, 0), BLACK:Lerp(WARM, 0.75), M.Neon)
			P("FoyerFloor", V(14, 1, hwid * 1.4), CF(fx + sx * 6, 0.6, 0), rgb(70, 64, 60), M.Marble)
			P("Foyer", V(26, 24, hwid * 1.5), CF(fx, 12, 0), rgb(60, 80, 110), M.Glass, 0.45, 0.2)
			P("FoyerRoof", V(30, 1.5, hwid * 1.56), CF(fx, 24.5, 0), rgb(80, 84, 92), M.Metal)
			for _ = 1, 16 do
				fan(V(fx + sx * rnd(4, 10), 1.1, rnd(-hwid * 0.6, hwid * 0.6)), pick(SHIRTS), 0, nil, true)
			end
		end
		local sgn = P("HallSign", V(1, 14, hwid * 1.5), CF(hl + 0.6, hh - 12, 0), BLACK)
		sign(sgn, Enum.NormalId.Right, "HALL OF THE STADIUM", WHITE, nil, 6)
		local sgn2 = P("HallSign", V(1, 14, hwid * 1.2), CF(-hl - 0.6, hh - 12, 0), BLACK)
		sign(sgn2, Enum.NormalId.Left, "HALL OF THE STADIUM", WHITE, nil, 6)
		ledScreen(CF(hl + 50, 26, -hwid * 0.9) * ANG(0, PI / 2, 0), 40, 22, { sc.tonight, "TONIGHT 20:00", "SOLD OUT", "HALL OF THE STADIUM" }, BLACK:Lerp(color, 0.4), Enum.NormalId.Back)
		P("ScreenPole", V(2, 24, 2), CF(hl + 50, 12, -hwid * 0.9), rgb(60, 60, 66), M.Metal)
		-- forecourt in front of the main entrance (south) and the smaller one (north): queues, fans, food
		for i = -3, 3 do
			line(V(hl + 30, 0.5, i * 22), V(1, 0, 0), 26, 0.5, color)
			staff(V(hl + 26, 0.5, i * 22 + 3), "security")
		end
		mingle(hl + 60, 0, 22, hwid * 1.2, 34, 0.5, color)
		mingle(-hl - 40, 0, 16, hwid, 16, 0.5, color)
		hotdogCart(V(hl + 70, 0.5, hwid * 1.1), 0)
		hotdogCart(V(-hl - 50, 0.5, -hwid), PI)
		for i = 0, 5 do
			banner(V(hl + 80, 0, -100 + i * 40), sc.tonight, color, PI / 2)
		end
		searchlights({ { pos = V(hl + 40, 0, -hwid), color = color, ph = 0 }, { pos = V(hl + 40, 0, hwid), ph = 2, color = WHITE } })
		sceneFrame()
		for i = 1, 16 do
			walker(V(-700 + i * 30, 1, 262 + rnd(-3, 3)), V(-60 + i * 8, 1, 240), pick(SHIRTS))
		end
		-- Swiss flags and the hills beyond
		for i = 0, 3 do
			P("FlagPole", V(0.6, 30, 0.6), CF(160 + i * 18, 15, 230), rgb(200, 200, 205), M.Metal)
			P("SwissFlag", V(8, 8, 0.2), CF(164 + i * 18, 26, 230), rgb(220, 30, 40), M.Fabric)
			P("SwissCross", V(5, 1.6, 0.3), CF(164 + i * 18, 26, 230), WHITE)
			P("SwissCross", V(1.6, 5, 0.3), CF(164 + i * 18, 26, 230), WHITE)
		end
		for i = 0, 8 do
			ellip("Hill", V(1100, 260, 600), CF(-2200 + i * 550, -30, -2900 - (i % 3) * 160), rgb(22, 40, 30), M.Grass)
		end
	end,
}

------------------------------------------------------------------ 5) STADIUM OF FRANCE (Saint-Denis)
-- Stade de France: ~80,000 seats, an elliptical roof that seems to float above the stands, held by 18 masts;
-- canal Saint-Denis on the east side, the A1 motorway south of it.
SCENES[5] = {
	name = "Stadium of France",
	city = "Paris - Saint-Denis",
	tonight = "KAI RIVERS",
	color = rgb(80, 140, 255),
	clock = 20.8,
	haze = 1.6,
	keys = {
		{ t = 0, p = V(-1100, 34, -930), l = V(-600, 40, -760) },
		{ t = 7, p = V(-560, 42, -720), l = V(0, 60, -400) },
		{ t = 13, p = V(-120, 64, -600), l = V(0, 80, 0) },
		{ t = 19, p = V(-430, 56, -160), l = V(0, 80, 0) },
		{ t = 25, p = V(-380, 96, 300), l = V(0, 90, 0) },
		{ t = 31, p = V(-120, 200, 470), l = V(0, 50, 0) },
		{ t = 37, p = V(250, 270, 300), l = V(0, 20, -30) },
		{ t = 44, p = V(430, 210, -260), l = V(0, 30, 40) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("paris", { cars = { "car", "car", "bus" }, skyline = 30 })
		local fw, fd = venueFrame(d, 1)
		local A, B, n = fw / 2 - 48, fd / 2 - 48, 40
		local concrete = rgb(176, 174, 168)
		ellBand("Stands", A, B, n, 36, 72, 12, concrete, M.Concrete)
		for _, y in ipairs({ 18, 38, 58 }) do
			ellBand("Concourse", A + 6.6, B + 6.6, n, y, 2.5, 1, BLACK:Lerp(WARM, 0.6), M.Neon)
		end
		ellRing(A + 10, B + 10, 20, function(mid, dir)
			for k = 0, 5 do
				local y0 = k * 12
				local p0 = mid - dir * 8 + V(0, y0, 0)
				local p1 = mid + dir * 8 + V(0, y0 + 12, 0)
				if k % 2 == 1 then
					p0, p1 = mid + dir * 8 + V(0, y0, 0), mid - dir * 8 + V(0, y0 + 12, 0)
				end
				bar("Stairway", p0, p1, 3, rgb(150, 150, 150), M.Concrete)
			end
		end)
		-- the floating roof: an elliptical ring 43 m above the pitch, lit from below
		local roofY = 92
		local iA, iB = A * 0.6, B * 0.52
		ellRing((A + 30 + iA) / 2, (B + 30 + iB) / 2, 48, function(mid, dir, out, len, i)
			local c = V(mid.X, roofY + (i % 2) * 0.08, mid.Z)
			P("Roof", V(A + 30 - iA, 5, len + 3), CFrame.lookAt(c, c + dir), rgb(206, 210, 216), M.Metal)
			P("RoofUnder", V(A + 24 - iA, 0.6, len + 3), CFrame.lookAt(c - V(0, 2.9, 0), c - V(0, 2.9, 0) + dir), rgb(255, 238, 210), M.Neon, 0.35)
		end)
		ellBand("RoofEdge", iA, iB, 40, roofY - 2, 3, 3, rgb(240, 244, 250), M.Neon)
		for i = 0, 17 do
			local th = i / 18 * 2 * PI
			local base = V(math.cos(th) * (A + 40), 0, math.sin(th) * (B + 40))
			local top = V(math.cos(th) * (A + 30), roofY + 46, math.sin(th) * (B + 30))
			tube("Mast", base, top, 4, rgb(220, 224, 230))
			blinker(top + V(0, 3, 0), 2)
			for _, f in ipairs({ 0.55, 0.85 }) do
				local rp = V(math.cos(th) * (A + 30 - (A - iA) * f), roofY + 2, math.sin(th) * (B + 30 - (B - iB) * f))
				bar("TieRod", top, rp, 0.6, rgb(200, 204, 210))
			end
		end
		bowlInside(iA, iB, 70, rgb(40, 70, 160), color, 36)
		-- gates and crowds on the esplanade all around
		for i = 0, 11 do
			local th = i / 12 * 2 * PI
			local p = V(math.cos(th) * (A + 22), 0, math.sin(th) * (B + 22))
			P("Gate", V(14, 10, 2), CFrame.lookAt(p + V(0, 5, 0), V(0, 5, 0)), BLACK:Lerp(WARM, 0.5), M.Neon)
			line(p + p.Unit * 6, p.Unit, 30, 0.5, color)
			staff(p + p.Unit * 4 + V(4, 0.5, 0), "security")
		end
		for i = 0, 5 do
			local th = i / 6 * 2 * PI + 0.3
			mingle(math.cos(th) * (A + 70), math.sin(th) * (B + 70), 40, 40, 10, 0.5, color)
			banner(V(math.cos(th) * (A + 50), 0, math.sin(th) * (B + 50)), sc.tonight, color, -th)
		end
		ledScreen(CF(0, 30, B + 90) * ANG(0, PI, 0), 46, 24, { sc.tonight, "WORLD TOUR", "SAINT-DENIS", "STADIUM OF FRANCE" }, BLACK:Lerp(color, 0.4), Enum.NormalId.Front)
		P("ScreenPole", V(2, 30, 2), CF(0, 15, B + 90), rgb(60, 60, 66), M.Metal)
		searchlights({ { pos = V(A + 60, 0, 0), color = color }, { pos = V(-A - 60, 0, 0), color = WHITE, ph = 1.5 }, { pos = V(0, 0, -B - 60), color = color, ph = 3 } })
		sceneFrame()
		for i = 1, 18 do
			walker(V(-600 + i * 20, 1, -700 + rnd(-10, 10)), V(-200 + rnd(-20, 20), 1, -400 + rnd(-40, 40)), pick(SHIRTS))
		end
		-- the Eiffel tower far away to the south-west, sparkling
		local ex, ez = -2400, 4200
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				bar("EiffelLeg", V(ex + sx * 40, 0, ez + sz * 40), V(ex + sx * 8, 220, ez + sz * 8), 6, rgb(180, 130, 60))
			end
		end
		bar("EiffelTop", V(ex, 220, ez), V(ex, 600, ez), 6, rgb(190, 140, 70))
		P("EiffelDeck", V(60, 5, 60), CF(ex, 110, ez), rgb(200, 150, 80), M.Neon)
		blinker(V(ex, 605, ez), 5)
	end,
}

------------------------------------------------------------------ 6) BERNABEO STADIUM (Madrid)
-- Santiago Bernabeu after the 2019-24 rebuild: a skin of curved steel louvres with light between them,
-- retractable roof, 360 degree screen inside; Paseo de la Castellana on the west side.
SCENES[6] = {
	name = "Bernabeo Stadium",
	city = "Madrid - Paseo de la Castellana",
	tonight = "LUNA SOL",
	color = rgb(255, 196, 60),
	clock = 21,
	haze = 1.2,
	keys = {
		{ t = 0, p = V(-340, 40, 1300), l = V(-340, 60, 800) },
		{ t = 7, p = V(-336, 36, 900), l = V(-270, 60, 400) },
		{ t = 14, p = V(-340, 44, 520), l = V(-60, 90, 100) },
		{ t = 20, p = V(-380, 64, 230), l = V(0, 90, 0) },
		{ t = 26, p = V(-440, 76, -140), l = V(0, 80, 0) },
		{ t = 32, p = V(-200, 140, -440), l = V(0, 60, 0) },
		{ t = 38, p = V(230, 290, -340), l = V(0, 60, 40) },
		{ t = 45, p = V(440, 210, 150), l = V(0, 70, 0) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("madrid", { cars = { "car", "car", "taxi", "bus" }, traffic = 10, skyline = 34, skyMax = 260 })
		local fw, fd = venueFrame(d, 1)
		local hw, hd, hh, rc = fw / 2 - 6, fd / 2 - 6, 140, 70
		-- inner walls (dark, lit floors), only around the edge: the roof is open tonight
		for _, sz in ipairs({ -1, 1 }) do
			P("Core", V(hw * 2 - 20, hh - 4, 34), CF(0, (hh - 4) / 2, sz * (hd - 27)), rgb(26, 26, 32))
			P("Core", V(34, hh - 4, hd * 2 - 88), CF(sz * (hw - 27), (hh - 4) / 2, 0), rgb(26, 26, 32))
			for k = 0, 12 do
				P("InnerGlow", V(hw * 2 - 18, 1.2, 1), CF(0, 8 + k * 10, sz * (hd - 9.3)), BLACK:Lerp(WARM, 0.45), M.Neon)
				P("InnerGlow", V(1, 1.2, hd * 2 - 90), CF(sz * (hw - 9.3), 8 + k * 10 + 0.3, 0), BLACK:Lerp(WARM, 0.45), M.Neon)
			end
		end
		-- rounded rectangle for the skin (8 points per corner)
		local outline = {}
		local function arc(cx, cz, a0)
			for k = 0, 8 do
				local a = a0 + k * PI / 16
				table.insert(outline, V(cx + math.cos(a) * rc, 0, cz + math.sin(a) * rc))
			end
		end
		arc(hw - rc, hd - rc, 0)
		arc(-hw + rc, hd - rc, PI / 2)
		arc(-hw + rc, -hd + rc, PI)
		arc(hw - rc, -hd + rc, PI * 1.5)
		local steel = rgb(196, 200, 208)
		for lvl = 0, 8 do
			local y = 12 + lvl * 15
			local seg = 0
			for i = 1, #outline do
				local a, b = outline[i], outline[i % #outline + 1]
				local dir = b - a
				local len = dir.Magnitude
				if len > 1 then
					local segs = math.max(1, math.floor(len / 40))
					for s2 = 0, segs - 1 do
						seg = seg + 1
						local p0 = a + dir * (s2 / segs)
						local p1 = a + dir * ((s2 + 1) / segs)
						local mid = (p0 + p1) / 2
						local out = V(dir.Unit.Z, 0, -dir.Unit.X)
						local wave = math.sin(mid.X * 0.016 + mid.Z * 0.013 + lvl * 0.8) * 4
						local c = mid + out * (7 + wave + (seg % 2) * 0.12) + V(0, y, 0)
						-- curved steel strip (tilted) with a line of light underneath
						P("Louvre", V(1.4, 10, len / segs + 1.2), CFrame.lookAt(c, c + dir) * ANG(0, 0, 0.3), steel, M.Metal, 0, 0.2)
						if lvl % 2 == 0 then
							P("LouvreLight", V(0.6, 0.6, len / segs + 0.4), CFrame.lookAt(c - V(0, 5.6, 0), c - V(0, 5.6, 0) + dir), (lvl % 4 == 0) and color or WHITE, M.Neon)
						end
					end
				end
			end
		end
		-- roof ring around the opening, parked roof panels, the bowl, the 360 screen
		local ox, oz = hw * 0.78, hd * 0.78
		for _, sg in ipairs({ -1, 1 }) do
			P("RoofRing", V(hw * 2 + 10, 4, hd + 5 - oz), CF(0, hh, sg * (oz + (hd + 5 - oz) / 2)), rgb(200, 204, 210), M.Metal)
			P("RoofRing", V(hw + 5 - ox, 4.2, oz * 2), CF(sg * (ox + (hw + 5 - ox) / 2), hh + 0.05, 0), rgb(200, 204, 210), M.Metal)
			P("RoofOpeningRim", V(ox * 2, 1.2, 1.2), CF(0, hh + 2.2, sg * oz), rgb(255, 230, 190), M.Neon)
			P("RoofOpeningRim", V(1.2, 1.3, oz * 2), CF(sg * ox, hh + 2.25, 0), rgb(255, 230, 190), M.Neon)
		end
		P("RoofPanels", V(hw * 0.45, 2, oz * 2), CF(-ox + hw * 0.22, hh + 3.2, 0), rgb(220, 224, 230), M.Metal)
		bowlInside(hw * 0.75, hd * 0.75, 110, rgb(240, 240, 245), color, 32)
		ellBand("Screen360", hw * 0.78, hd * 0.78, 32, hh - 16, 12, 2, color, M.Neon)
		local logo = P("StadiumSign", V(0.5, 16, 140), CF(-hw - 12, hh - 24, 0), BLACK)
		sign(logo, Enum.NormalId.Left, "BERNABEO", color, nil, 6)
		-- plazas full of fans, metro entrance, kiosks
		mingle(-hw - 50, 0, 20, 140, 40, 0.5, color)
		mingle(0, hd + 45, 150, 16, 30, 0.5, color)
		mingle(0, -hd - 45, 150, 16, 30, 0.5, color)
		for i = -4, 4 do
			line(V(-hw - 14, 0, i * 30), V(-1, 0, 0), 26, 0.5, color)
			staff(V(-hw - 10, 0.5, i * 30 + 4), "security")
		end
		ledScreen(CF(-hw - 40, 40, -120) * ANG(0, -PI / 2, 0), 50, 26, { sc.tonight, "WORLD TOUR", "MADRID", "BERNABEO STADIUM" }, BLACK:Lerp(color, 0.35))
		P("ScreenPole", V(2, 40, 2), CF(-hw - 40, 20, -120), rgb(60, 60, 66), M.Metal)
		searchlights({ { pos = V(-hw - 20, 0, 160), color = color }, { pos = V(hw + 20, 0, -160), color = WHITE, ph = 2 } })
		for i = 0, 9 do
			banner(V(-hw - 60, 0, -180 + i * 40), sc.tonight, color, -PI / 2)
		end
		sceneFrame()
		local mx = -300
		P("MetroSign", V(1, 8, 8), CF(mx, 14, 120) * ANG(0, 0, PI / 4), rgb(220, 30, 40), M.Neon)
		P("MetroPole", V(0.6, 10, 0.6), CF(mx, 5, 120), rgb(60, 60, 66), M.Metal)
		for i = 1, 20 do
			walker(V(-300, 1, 700 - i * 30), V(-280, 1, rnd(-120, 120)), pick(SHIRTS))
		end
	end,
}

------------------------------------------------------------------ 7) WEMBLEE STADIUM (London)
-- Wembley: 90,000 seats, the arch is 133 m high and spans 315 m; fans walk up Wembley Way from the station.
SCENES[7] = {
	name = "Wemblee Stadium",
	city = "London - Wembley Park",
	tonight = "JUNO PARK",
	color = rgb(200, 60, 255),
	clock = 20.6,
	haze = 1.7,
	keys = {
		{ t = 0, p = V(-20, 40, -1300), l = V(-20, 120, -300) },
		{ t = 7, p = V(-10, 28, -1060), l = V(-20, 120, -200) },
		{ t = 14, p = V(-30, 24, -800), l = V(-10, 110, -100) },
		{ t = 20, p = V(20, 36, -560), l = V(0, 150, 0) },
		{ t = 26, p = V(-140, 100, -460), l = V(0, 200, 0) },
		{ t = 32, p = V(-420, 250, -150), l = V(0, 140, 0) },
		{ t = 38, p = V(-320, 350, 280), l = V(0, 60, 0) },
		{ t = 45, p = V(240, 310, 400), l = V(0, 80, -40) },
	},
	build = function(sc)
		local color = sc.color
		local d = osmCity("wembley", { cars = { "dd", "car", "cab" }, skyline = 30 })
		local fw, fd = venueFrame(d, 1)
		local A, B, n = fw / 2 - 12, fd / 2 - 30, 44
		ellBand("Bowl", A, B, n, 50, 100, 14, rgb(170, 174, 182), M.Metal)
		for _, y in ipairs({ 16, 40, 66 }) do
			ellBand("Glazing", A + 7.6, B + 7.6, n, y, 7, 1, rgb(40, 50, 70), M.Glass)
			ellBand("ConcourseLight", A + 8.2, B + 8.2, n, y - 2.5, 1.2, 0.8, BLACK:Lerp(WARM, 0.7), M.Neon)
		end
		local iA, iB = A * 0.53, B * 0.52
		ellRing((A + iA) / 2, (B + iB) / 2, 52, function(mid, dir, out, len, i)
			local c = V(mid.X, 108 + (i % 2) * 0.08, mid.Z)
			P("Roof", V(A - iA + 2, 4, len + 3), CFrame.lookAt(c, c + dir) * ANG(0, 0, 0.06), rgb(214, 218, 224), M.Metal)
		end)
		ellBand("RoofEdgeLight", iA, iB, 44, 104, 2, 2, rgb(255, 240, 220), M.Neon)
		bowlInside(iA, iB, 80, rgb(200, 30, 40), color, 36)
		-- the arch: 133 m (266 studs) high, 315 m (630 studs) span, leaning north over the stadium
		local seg = 40
		local prev = nil
		local lean = CFrame.Angles(math.rad(-22), 0, 0)
		for i = 0, seg do
			local u = i / seg
			local x = -315 + u * 630
			local h = 266 * (1 - (x / 315) ^ 2)
			local p = (CF(0, 0, -60) * lean * CF(x, h, 0)).Position
			if prev then
				tube("Arch", prev, p, 9, rgb(240, 242, 246))
			end
			if i > 2 and i < seg - 2 and i % 3 == 0 then
				local q = V(p.X * 0.92, 108, math.clamp(p.Z, -B * 0.6, B * 0.6))
				bar("ArchCable", p, q, 0.6, rgb(210, 210, 216))
			end
			prev = p
		end
		for _, x in ipairs({ -315, 315 }) do
			P("ArchFoot", V(30, 10, 30), CF(x, 5, -60), rgb(150, 150, 156), M.Concrete)
		end
		local top = (CF(0, 0, -60) * lean * CF(0, 266, 0)).Position
		blinker(top + V(0, 6, 0), 4)
		P("ArchGlow", V(8, 8, 8), CF(top), color, M.Neon)
		local logo = P("StadiumSign", V(150, 18, 1), CF(0, 84, -B - 18), BLACK)
		sign(logo, Enum.NormalId.Front, "WEMBLEE STADIUM", WHITE, nil, 6)
		ledScreen(CF(90, 34, -B - 70), 44, 24, { sc.tonight, "TONIGHT", "WEMBLEE STADIUM", "LONDON" }, BLACK:Lerp(color, 0.4), Enum.NormalId.Back)
		P("ScreenPole", V(2, 34, 2), CF(90, 17, -B - 70), rgb(60, 60, 66), M.Metal)
		-- statue at the top of the steps
		P("Plinth", V(10, 10, 10), CF(0, 5, -B - 40), rgb(120, 116, 110), M.Granite)
		P("Statue", V(5, 14, 3), CF(0, 17, -B - 40), rgb(80, 70, 60), M.Metal)
		ball("StatueHead", 3.2, V(0, 25.6, -B - 40), rgb(80, 70, 60), M.Metal)
		searchlights({ { pos = V(-120, 0, -B - 30), color = color }, { pos = V(120, 0, -B - 30), color = WHITE, ph = 1.6 }, { pos = V(0, 0, -B - 80), color = color, ph = 3.2 } })
		sceneFrame()
		-- Wemblee Way: the walk from the station, full of fans, lamps and banners
		local wx, wz0, wz1 = -20, -B - 60, (d.A.station and d.A.station[2] or -1500) + 120
		for i = 0, 20 do
			local z = wz1 + i * (wz0 - wz1) / 20
			for _, x in ipairs({ -40, 40 }) do
				streetLamp(wx + x, z, (x < 0) and -PI / 2 or PI / 2, 20)
			end
			if i % 2 == 0 then
				banner(V(wx - 32, 0, z), sc.tonight, color, PI / 2)
				banner(V(wx + 32, 0, z + 19), "WEMBLEE", rgb(30, 60, 160), -PI / 2)
			end
		end
		for i = 0, 30 do
			line(V(wx + rnd(-28, 28), 0, wz1 + 20 + i * (wz0 - wz1) / 32), V(0, 0, 1), 16, 1, color)
		end
		mingle(wx, (wz0 + wz1) / 2, 28, math.abs(wz0 - wz1) / 2 - 20, 60, 1, color)
		for i = 1, 30 do
			walker(V(wx + rnd(-28, 28), 1.2, wz1 + 20), V(wx + rnd(-28, 28), 1.2, wz0 - 10), pick(SHIRTS))
		end
		for i = 0, 5 do
			hotdogCart(V(wx + ((i % 2 == 0) and -32 or 32), 1, wz0 - 100 - i * 140), (i % 2 == 0) and PI / 2 or -PI / 2)
		end
	end,
}



------------------------------------------------------------------ control
local conn = nil
local effects = {}

local function setLighting(scene)
	Lighting.ClockTime = scene.clock or 20.5
	Lighting.Brightness = 1.4
	Lighting.Ambient = rgb(60, 62, 84)
	Lighting.OutdoorAmbient = rgb(86, 88, 120)
	Lighting.GlobalShadows = false
	if not effects.atmosphere then
		effects.atmosphere = New("Atmosphere", { Density = 0.3, Offset = 0.12, Color = rgb(140, 150, 196), Decay = rgb(80, 66, 120), Glare = 0.25, Haze = 1.5, Parent = Lighting })
		effects.bloom = New("BloomEffect", { Intensity = 0.7, Size = 26, Threshold = 1.5, Parent = Lighting })
		effects.cc = New("ColorCorrectionEffect", { Brightness = 0, Contrast = 0.08, Saturation = 0.12, TintColor = BLACK, Parent = Lighting })
	end
	effects.atmosphere.Haze = scene.haze or 1.5
end

-- onScene(scene) is called whenever the shown venue changes (for the caption)
function MenuScene.start(onScene)
	MenuScene.stop()
	local index = 0
	local bag = {}
	local t, sceneT = 0, 0
	local scene = nil
	local duration = 40
	local function nextScene()
		if folder then
			folder:Destroy()
		end
		-- random order: every venue once per round, never the same one twice in a row
		if #bag == 0 then
			for i = 1, #SCENES do
				table.insert(bag, i)
			end
			for i = #bag, 2, -1 do
				local j = math.random(1, i)
				bag[i], bag[j] = bag[j], bag[i]
			end
			if bag[#bag] == index and #bag > 1 then
				bag[1], bag[#bag] = bag[#bag], bag[1]
			end
		end
		index = table.remove(bag)
		if MenuScene.forceOrder then
			index = MenuScene.forceOrder[1]
			table.remove(MenuScene.forceOrder, 1)
		end
		MenuScene.index = index
		scene = SCENES[index]
		setLighting(scene)
		reset(index * 97)
		folder = New("Folder", { Name = "MenuScene", Parent = workspace })
		makeSamples(scene.keys)
		scene.build(scene)
		scene.parts = count
		duration = scene.keys[#scene.keys].t
		sceneT = 0
		if onScene then
			onScene(scene)
		end
	end
	nextScene()
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		t = t + dt
		sceneT = sceneT + dt
		if sceneT > duration + 0.2 then
			nextScene()
		end
		-- fade: black at the start/end of every flight (only the 3D view, the menu stays)
		local fade = math.min(1, sceneT / 1.4, math.max(0, (duration + 0.2 - sceneT) / 1.4))
		effects.cc.TintColor = BLACK:Lerp(WHITE, math.clamp(fade, 0, 1))
		-- camera along the spline; the look target is shifted left so the subject sits right of the menu
		local camPos = sampleKeys(scene.keys, sceneT, "p")
		local look = sampleKeys(scene.keys, sceneT, "l")
		local fwd = (look - camPos).Unit
		local right = fwd:Cross(V(0, 1, 0)).Unit
		local dist = (look - camPos).Magnitude
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 62
		cam.CFrame = OCF * CFrame.lookAt(camPos, look - right * (dist * 0.2))
		-- traffic, boats, gondolas, trains
		for _, m in ipairs(movers) do
			if m.speed > 0 then
				m.s = (m.s + m.speed * dt) % m.len
			end
			local base = OCF * CF(m.a + m.dir * m.s) * ANG(0, m.yaw, 0)
			for _, pp in ipairs(m.parts) do
				pp[1].CFrame = base * pp[2]
			end
		end
		-- pedestrians walk back and forth
		for _, w in ipairs(walkers) do
			local u = (w.ph + t * w.speed / w.len) % 2
			local fromA = u <= 1
			if not fromA then
				u = 2 - u
			end
			local pos = w.a:Lerp(w.b, u)
			local d = fromA and (w.b - w.a) or (w.a - w.b)
			w.fig:update(ORIGIN + pos, math.atan2(d.X, d.Z), { t = t + w.ph * 3, beat = 0, energy = 0, walking = true })
		end
		-- fans bounce (half of them per frame)
		local half = math.floor(t * 4) % 2
		for i, f in ipairs(crowd) do
			if i % 2 == half then
				local j = f.calm and (math.sin(t * 1.6 + f.ph) * 0.08) or (math.max(0, math.sin(t * 6 + f.ph)) * 0.6)
				for k, part in ipairs(f.parts) do
					part.CFrame = CF(f.base + V(0, f.offs[k] + j, 0))
				end
			end
		end
		-- searchlights sweep, aircraft lights blink, LED screens cycle
		for _, b in ipairs(beams) do
			local a = t * b.speed + b.ph
			b.part.CFrame = OCF * CF(b.pos) * ANG(0, a, 0) * ANG(math.pi / 2 - b.tilt + math.sin(t * 0.4 + b.ph) * 0.15, 0, 0) * CF(0, 0, -350)
		end
		for _, b in ipairs(blinkers) do
			if b.flash then
				b.part.Transparency = (math.sin(t * 1.9 + b.ph) > 0.96) and 0 or 1
			else
				b.part.Transparency = (math.sin(t * 2.6 + b.ph) > 0.55) and 0 or 0.85
			end
		end
		for _, s in ipairs(screens) do
			local i = math.floor(t / 3.5) % #s.texts + 1
			if i ~= s.i then
				s.i = i
				s.label.Text = s.texts[i]
			end
		end
	end)
end

function MenuScene.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	for k, e in pairs(effects) do
		e:Destroy()
		effects[k] = nil
	end
end

return MenuScene
