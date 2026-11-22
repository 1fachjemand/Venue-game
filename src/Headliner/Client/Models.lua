-- Detailed stage pieces (set pieces, special elements, shapes). Builder installs them into its builder
-- table: Models.install(B, H) with H = Builder's part helpers. Every model is built around the local origin
-- (bottom centre), the front (towards the fans) is +Z unless a comment says otherwise.
-- Geometry helpers:
--   trapPanel  a flat trapezoid (one block + two wedges): edges meet exactly, no gaps, no overlaps
--   frustum    a smooth cone / skirt / lamp shade from trapezoid panels (rTop = 0: a cone or pyramid)
--   H.ringPieces  a flat ring or disc slice from exact pieces
local Models = {}

local CHROME = Color3.fromRGB(226, 228, 234)
local BLACK = Color3.fromRGB(22, 22, 24)

------------------------------------------------------------------ geometry
-- a planar trapezoid centred at cf: local X = width (wTop at +Y, wBot at -Y), Y = its height L, Z = thickness t
-- mk(size, cf, kind) makes one part ("block" or "wedge")
local function trapPanel(mk, cf, wTop, wBot, L, t)
	local made = {}
	local a = math.min(wTop, wBot)
	if a > 0.01 then
		table.insert(made, mk(Vector3.new(a, L, t), cf, "block"))
	end
	local tw = math.abs(wBot - wTop) / 2
	if tw > 0.005 then
		-- the right angle of each triangle sits at the wide end, next to the middle block
		local sy = (wBot > wTop) and -1 or 1
		for _, sx in ipairs({ 1, -1 }) do
			local vY = cf:VectorToWorldSpace(Vector3.new(sx, 0, 0))
			local vZ = cf:VectorToWorldSpace(Vector3.new(0, sy, 0))
			local vX = vY:Cross(vZ)
			local pos = cf * Vector3.new(sx * (a / 2 + tw / 2), 0, 0)
			table.insert(made, mk(Vector3.new(t, tw, L), CFrame.fromMatrix(pos, vX, vY, vZ), "wedge"))
		end
	end
	return made
end
Models.trapPanel = trapPanel

-- a cone / frustum standing on `base` (bottom centre), n sides, radius rBot at the bottom, rTop at the top,
-- height h, panels t thick. The corners lie on the two circles. Returns the parts.
local function frustum(mk, rBot, rTop, h, n, base, t)
	local th = math.pi / n
	local c, s = math.cos(th), math.sin(th)
	local aB, aT = rBot * c, rTop * c
	local L = math.sqrt(h * h + (aB - aT) ^ 2)
	local tilt = math.atan2(aT - aB, h)
	local made = {}
	for i = 0, n - 1 do
		local cf = base * CFrame.Angles(0, (2 * i + 1) * th, 0) * CFrame.new(0, h / 2, (aB + aT) / 2) * CFrame.Angles(tilt, 0, 0)
		for _, p in ipairs(trapPanel(mk, cf, 2 * rTop * s, 2 * rBot * s, L, t or 0.2)) do
			table.insert(made, p)
		end
	end
	return made
end
Models.frustum = frustum

function Models.install(B, H)
	local part, cyl, tube, arcTube, oval, New = H.part, H.cyl, H.tube, H.arcTube, H.oval, H.New
	local ringPieces = H.ringPieces
	local dims = H.dims

	-- a part maker for frustum / trapPanel / ringPieces with one look
	local function maker(m, name, color, mat, refl)
		return function(size, cf, kind)
			local p
			if kind == "wedge" then
				p = New("WedgePart", { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
			else
				p = part(m, name, size, cf, color, mat)
			end
			if refl then
				p.Reflectance = refl
			end
			return p
		end
	end
	H.maker = maker
	-- cylinder along local X (Roblox's own cylinder axis): length len, diameter d
	local function cylX(m, name, len, d, cf, color, mat)
		return part(m, name, Vector3.new(len, d, d), cf, color, mat, Enum.PartType.Cylinder)
	end
	-- cylinder along Z (lights, lenses facing front / back)
	local function cylZ(m, name, len, d, cf, color, mat)
		return part(m, name, Vector3.new(len, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, mat, Enum.PartType.Cylinder)
	end
	local function chrome(p)
		p.Reflectance = 0.3
		return p
	end
	local function ball(m, name, d, pos, color, mat)
		return part(m, name, Vector3.new(d, d, d), CFrame.new(pos), color, mat, Enum.PartType.Ball)
	end
	H.cylX, H.cylZ, H.chrome, H.ball = cylX, cylZ, chrome, ball
	H.Builder.modelsAnimate = function(refs, ctx)
		return Models.animate(refs, ctx)
	end

	---------------------------------------------------------------- 1950s convertible (front = -Z)
	function B.vintagecar(m, r)
		local paint = r.color:Lerp(Color3.fromRGB(196, 30, 46), 0.55)
		local cream = Color3.fromRGB(246, 238, 220)
		local SP = Enum.Material.SmoothPlastic
		-- wheels: black tyres with wide white walls and chrome hubcaps
		for _, z in ipairs({ -5.1, 5.0 }) do
			for _, sx in ipairs({ -1, 1 }) do
				local c = CFrame.new(sx * 2.55, 1.3, z)
				cylX(m, "Tyre", 1.0, 2.6, c, BLACK)
				cylX(m, "WhiteWall", 1.04, 1.95, c, Color3.fromRGB(240, 240, 238))
				chrome(cylX(m, "Hubcap", 1.08, 1.3, c, CHROME, SP))
				cylX(m, "HubCentre", 1.14, 0.45, c, paint)
			end
		end
		-- body: sills between the wheels, the main body above them (it covers the tops of the wheels like a fender)
		part(m, "Sill", Vector3.new(6.4, 0.8, 6.9), CFrame.new(0, 1.35, -0.05), paint, SP)
		part(m, "Sill", Vector3.new(6.4, 0.8, 1.2), CFrame.new(0, 1.35, -7.3), paint, SP)
		part(m, "Sill", Vector3.new(6.4, 0.8, 1.3), CFrame.new(0, 1.35, 7.25), paint, SP)
		part(m, "Body", Vector3.new(6.4, 1.2, 15.8), CFrame.new(0, 2.35, 0), paint, SP)
		cylX(m, "Nose", 6.4, 1.2, CFrame.new(0, 2.35, -7.9), paint, SP)
		cylX(m, "Tail", 6.4, 1.2, CFrame.new(0, 2.35, 7.9), paint, SP)
		part(m, "WheelArchShade", Vector3.new(6.2, 0.06, 3.0), CFrame.new(0, 1.72, -5.1), Color3.fromRGB(16, 16, 18))
		part(m, "WheelArchShade", Vector3.new(6.2, 0.06, 3.0), CFrame.new(0, 1.72, 5.0), Color3.fromRGB(16, 16, 18))
		-- hood, rear deck, door tops; the open cockpit in between
		part(m, "Hood", Vector3.new(6.2, 0.4, 5.2), CFrame.new(0, 3.15, -5.1), paint, SP)
		cylX(m, "HoodNose", 6.2, 0.4, CFrame.new(0, 3.15, -7.7), paint, SP)
		part(m, "RearDeck", Vector3.new(6.2, 0.4, 3.6), CFrame.new(0, 3.15, 5.8), paint, SP)
		cylX(m, "DeckTail", 6.2, 0.4, CFrame.new(0, 3.15, 7.6), paint, SP)
		for _, sx in ipairs({ -1, 1 }) do
			-- soft rounded shoulders along the hood and the rear deck
			cylZ(m, "Shoulder", 5.0, 0.5, CFrame.new(sx * 3.0, 3.1, -5.1), paint, SP)
			cylZ(m, "Shoulder", 3.4, 0.5, CFrame.new(sx * 3.0, 3.1, 5.8), paint, SP)
			part(m, "DoorTop", Vector3.new(0.5, 0.4, 6.6), CFrame.new(sx * 2.95, 3.15, 0.7), paint, SP)
			cylZ(m, "DoorRoll", 6.6, 0.5, CFrame.new(sx * 2.95, 3.37, 0.7), paint, SP)
			-- tail fins with bullet tail lights
			New("WedgePart", { Name = "Fin", Size = Vector3.new(0.45, 1.5, 4.0), CFrame = CFrame.new(sx * 2.95, 4.1, 6.0), Color = paint, Material = SP, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
			chrome(cylZ(m, "TailBezel", 0.3, 0.72, CFrame.new(sx * 2.95, 3.75, 8.02), CHROME, SP))
			cylZ(m, "TailLight", 0.36, 0.5, CFrame.new(sx * 2.95, 3.75, 8.05), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
			-- round headlights in chrome rings
			chrome(cylZ(m, "HeadBezel", 0.36, 1.12, CFrame.new(sx * 2.25, 2.62, -8.4), CHROME, SP))
			cylZ(m, "HeadLight", 0.4, 0.82, CFrame.new(sx * 2.25, 2.62, -8.42), Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
			-- cream side cove with chrome edges, a chrome spear along the body
			part(m, "Cove", Vector3.new(0.06, 0.55, 6.6), CFrame.new(sx * 3.22, 2.25, 2.4), cream, SP)
			chrome(part(m, "CoveTrim", Vector3.new(0.08, 0.1, 6.8), CFrame.new(sx * 3.23, 2.56, 2.4), CHROME, SP))
			chrome(part(m, "CoveTrim", Vector3.new(0.08, 0.1, 6.8), CFrame.new(sx * 3.23, 1.94, 2.4), CHROME, SP))
			chrome(part(m, "Spear", Vector3.new(0.08, 0.12, 9.0), CFrame.new(sx * 3.23, 2.8, -2.9), CHROME, SP))
			-- bumper ends and the "bullets" on the front bumper
			chrome(ball(m, "BumperEnd", 0.76, Vector3.new(sx * 3.4, 1.55, -8.75), CHROME, SP))
			chrome(ball(m, "BumperEnd", 0.76, Vector3.new(sx * 3.4, 1.55, 8.75), CHROME, SP))
			chrome(oval(m, "Bullet", Vector3.new(0.5, 0.5, 0.9), CFrame.new(sx * 1.3, 1.95, -8.95), CHROME, SP))
		end
		-- grille and bumpers
		part(m, "Grille", Vector3.new(3.4, 0.7, 0.1), CFrame.new(0, 2.25, -8.43), Color3.fromRGB(30, 30, 34))
		for k = 0, 2 do
			chrome(cylX(m, "GrilleBar", 3.5, 0.12, CFrame.new(0, 2.05 + k * 0.2, -8.5), CHROME, SP))
		end
		chrome(cylX(m, "Bumper", 6.8, 0.75, CFrame.new(0, 1.55, -8.75), CHROME, SP))
		chrome(cylX(m, "Bumper", 6.8, 0.75, CFrame.new(0, 1.55, 8.75), CHROME, SP))
		part(m, "Plate", Vector3.new(1.6, 0.75, 0.08), CFrame.new(0, 2.0, 8.46), Color3.fromRGB(250, 210, 60))
		chrome(part(m, "HoodOrnament", Vector3.new(0.15, 0.3, 0.9), CFrame.new(0, 3.5, -7.2), CHROME, SP))
		chrome(tube(m, Vector3.new(1.6, 0.95, 8.0), Vector3.new(1.6, 0.95, 9.0), 0.32, CHROME))
		-- wrap-around windshield in a chrome frame
		local ws = CFrame.new(0, 4.15, -2.35) * CFrame.Angles(0.42, 0, 0)
		local glass = part(m, "Windshield", Vector3.new(5.6, 1.8, 0.08), ws, Color3.fromRGB(180, 215, 235), Enum.Material.Glass)
		glass.Transparency = 0.6
		chrome(cylX(m, "ScreenTop", 5.8, 0.16, ws * CFrame.new(0, 0.92, 0), CHROME, SP))
		for _, sx in ipairs({ -1, 1 }) do
			chrome(part(m, "ScreenPost", Vector3.new(0.14, 1.9, 0.14), ws * CFrame.new(sx * 2.85, 0, 0), CHROME, SP))
		end
		-- dashboard, steering wheel, bench seats, the folded top behind them
		part(m, "Dash", Vector3.new(5.6, 0.6, 0.7), CFrame.new(0, 3.55, -2.25), paint, SP)
		for _, gx in ipairs({ -1.6, -0.8 }) do
			chrome(cylZ(m, "Gauge", 0.12, 0.42, CFrame.new(gx, 3.6, -1.88), CHROME, SP))
		end
		local wc = CFrame.new(-1.2, 3.9, -1.25) * CFrame.Angles(-0.55, 0, 0)
		arcTube(m, "SteeringWheel", wc, 0.75, 0, math.pi * 2, 14, 0.13, cream, SP)
		tube(m, wc * Vector3.new(-0.72, 0, 0), wc * Vector3.new(0.72, 0, 0), 0.08, cream)
		tube(m, wc.Position, Vector3.new(-1.2, 3.4, -2.1), 0.14, Color3.fromRGB(40, 40, 44))
		part(m, "Carpet", Vector3.new(5.4, 0.05, 6.2), CFrame.new(0, 2.98, 0.8), Color3.fromRGB(110, 20, 30), Enum.Material.Fabric)
		for _, z in ipairs({ -0.2, 2.7 }) do
			part(m, "SeatBase", Vector3.new(5.3, 0.6, 2.0), CFrame.new(0, 3.3, z), cream, Enum.Material.Leather)
			local back = CFrame.new(0, 4.1, z + 1.05) * CFrame.Angles(0.14, 0, 0)
			part(m, "SeatBack", Vector3.new(5.3, 1.5, 0.45), back, cream, Enum.Material.Leather)
			cylX(m, "SeatRoll", 5.3, 0.5, back * CFrame.new(0, 0.75, 0), cream, Enum.Material.Leather)
			for k = -2, 2 do
				part(m, "Piping", Vector3.new(0.06, 1.3, 0.47), back * CFrame.new(k * 1.05, -0.05, 0), Color3.fromRGB(180, 30, 40), Enum.Material.Leather)
			end
		end
		oval(m, "FoldedTop", Vector3.new(5.6, 0.7, 1.3), CFrame.new(0, 3.45, 4.45), cream, Enum.Material.Fabric)
		r.neon = {}
	end

	---------------------------------------------------------------- chopper on its kickstand (front = -Z)
	local function spokedWheel(m, c, R, tyreD, spokes, paint)
		-- a torus tyre, a thin chrome rim, spokes from the hub: you can see through it
		local plane = c * CFrame.Angles(0, math.pi / 2, 0)
		arcTube(m, "Tyre", plane, R, 0, math.pi * 2, 18, tyreD, BLACK, Enum.Material.SmoothPlastic)
		local rimR = R - tyreD * 0.45
		for _, p in ipairs(arcTube(m, "Rim", plane, rimR, 0, math.pi * 2, 18, 0.12, CHROME, Enum.Material.SmoothPlastic)) do
			chrome(p)
		end
		chrome(cylX(m, "Hub", 0.7, 0.55, c, CHROME, Enum.Material.SmoothPlastic))
		for k = 0, spokes - 1 do
			local a = k / spokes * math.pi * 2
			local side = (k % 2 == 0) and 0.22 or -0.22
			tube(m, c * Vector3.new(side, 0, 0), c * Vector3.new(0, math.sin(a) * rimR, math.cos(a) * rimR), 0.05, CHROME)
		end
		if paint then
			cylX(m, "HubCap", 0.76, 0.25, c, paint)
		end
	end
	function B.motorbike(m, r)
		local paint = r.color
		local SP = Enum.Material.SmoothPlastic
		local rear, front = CFrame.new(0, 1.4, 3.3), CFrame.new(0, 1.5, -4.7)
		spokedWheel(m, rear, 1.15, 0.62, 16, paint)
		spokedWheel(m, front, 1.25, 0.38, 20, nil)
		-- frame: backbone, down tube, rails to the rear axle
		local neck = Vector3.new(0, 4.9, -2.3)
		local seat = Vector3.new(0, 3.2, 1.0)
		local function frame(a, b, d)
			return tube(m, a, b, d or 0.2, Color3.fromRGB(30, 30, 34))
		end
		frame(neck, seat, 0.24)
		frame(neck, Vector3.new(0, 1.35, -0.9), 0.24)
		frame(Vector3.new(0, 1.35, -0.9), Vector3.new(0, 1.35, 1.2))
		for _, sx in ipairs({ -0.4, 0.4 }) do
			frame(Vector3.new(sx, 1.35, 1.2), Vector3.new(sx, 1.4, 3.3))
			frame(Vector3.new(sx, 3.2, 1.2), Vector3.new(sx, 1.45, 3.3))
		end
		-- long raked fork, triple tree, ape-hanger bars with black grips
		for _, sx in ipairs({ -0.36, 0.36 }) do
			chrome(tube(m, Vector3.new(sx, 1.5, -4.7), Vector3.new(sx, 5.15, -2.45), 0.2, CHROME))
		end
		chrome(part(m, "TripleTree", Vector3.new(1.1, 0.25, 0.5), CFrame.new(0, 5.2, -2.42), CHROME, SP))
		for _, sx in ipairs({ -1, 1 }) do
			chrome(tube(m, Vector3.new(sx * 0.3, 5.3, -2.4), Vector3.new(sx * 0.85, 6.9, -2.1), 0.14, CHROME))
			chrome(tube(m, Vector3.new(sx * 0.85, 6.9, -2.1), Vector3.new(sx * 1.45, 6.85, -1.7), 0.14, CHROME))
			tube(m, Vector3.new(sx * 1.35, 6.86, -1.77), Vector3.new(sx * 1.75, 6.84, -1.5), 0.22, BLACK)
		end
		chrome(cylZ(m, "LampShell", 0.7, 1.0, CFrame.new(0, 4.6, -3.05), CHROME, SP))
		cylZ(m, "Lamp", 0.72, 0.78, CFrame.new(0, 4.6, -3.07), Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
		-- teardrop tank with a chrome cap
		oval(m, "Tank", Vector3.new(1.35, 1.0, 2.9), CFrame.new(0, 4.45, -0.8) * CFrame.Angles(0.22, 0, 0), paint, SP).Reflectance = 0.12
		chrome(cylX(m, "TankCap", 0.4, 0.34, CFrame.new(0, 4.95, -1.0) * CFrame.Angles(0, 0, math.pi / 2), CHROME, SP))
		-- V-twin: crankcase and two finned cylinders, chrome rocker covers
		chrome(part(m, "Crankcase", Vector3.new(1.1, 1.0, 1.7), CFrame.new(0, 1.95, -0.3), Color3.fromRGB(170, 172, 180), Enum.Material.Metal))
		for _, cdef in ipairs({ { Vector3.new(0, 2.4, -0.7), Vector3.new(0, 3.75, -1.45) }, { Vector3.new(0, 2.4, 0.1), Vector3.new(0, 3.75, 0.75) } }) do
			local a, b = cdef[1], cdef[2]
			tube(m, a, b, 0.72, Color3.fromRGB(60, 60, 66))
			local dir = (b - a).Unit
			for k = 1, 5 do
				local p = a + dir * (k * 0.24)
				tube(m, p - dir * 0.03, p + dir * 0.03, 1.02, Color3.fromRGB(150, 152, 160))
			end
			chrome(oval(m, "Rocker", Vector3.new(0.9, 0.5, 0.9), CFrame.new(b + dir * 0.15), CHROME, SP))
		end
		-- two exhaust pipes on the right, back to the rear wheel
		for k, y in ipairs({ 3.3, 2.7 }) do
			local z0 = (k == 1) and -1.3 or 0.6
			chrome(tube(m, Vector3.new(0.45, y, z0), Vector3.new(0.85, 1.55 + k * 0.25, 0.2), 0.3, CHROME))
			chrome(tube(m, Vector3.new(0.85, 1.55 + k * 0.25, 0.2), Vector3.new(0.95, 1.2 + k * 0.3, 3.9), 0.3, CHROME))
		end
		-- low seat, the passenger hump and a sissy bar, fenders over both wheels
		oval(m, "Seat", Vector3.new(1.15, 0.45, 2.2), CFrame.new(0, 3.35, 1.0), Color3.fromRGB(34, 24, 20), Enum.Material.Leather)
		oval(m, "Pillion", Vector3.new(1.0, 0.5, 1.1), CFrame.new(0, 3.5, 2.2), Color3.fromRGB(34, 24, 20), Enum.Material.Leather)
		for _, p in ipairs(arcTube(m, "SissyBar", CFrame.new(0, 4.4, 2.7), 0.55, 0, math.pi, 8, 0.12, CHROME, SP)) do
			chrome(p)
		end
		for _, sx in ipairs({ -0.55, 0.55 }) do
			chrome(tube(m, Vector3.new(sx, 3.4, 2.7), Vector3.new(sx, 4.4, 2.7), 0.12, CHROME))
		end
		local fender = CFrame.new(0, 1.4, 3.3) * CFrame.Angles(0, 0, math.pi / 2)
		ringPieces(maker(m, "Fender", paint, SP, 0.1), 1.5, 1.62, -0.2, 2.1, 12, 0.95, fender)
		ringPieces(maker(m, "Fender", paint, SP, 0.1), 1.45, 1.55, 0.6, 2.4, 8, 0.6, CFrame.new(0, 1.5, -4.7) * CFrame.Angles(0, 0, math.pi / 2))
		-- kickstand: the bike leans a little to the left on it
		tube(m, Vector3.new(-0.35, 1.5, -0.3), Vector3.new(-1.2, 0.06, 0.3), 0.12, Color3.fromRGB(40, 40, 44))
		local lean = CFrame.Angles(0, 0, math.rad(6))
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "Pivot" then
				p.CFrame = lean * p.CFrame
			end
		end
		r.neon = {}
	end
	---------------------------------------------------------------- flowers
	-- one rose: open outer petals, a cupped inner ring and a tight bud (the flower looks along `cf`'s +Z)
	local ROSES = {
		{ Color3.fromRGB(246, 170, 190), Color3.fromRGB(232, 130, 160) }, -- blush
		{ Color3.fromRGB(252, 250, 246), Color3.fromRGB(236, 230, 222) }, -- white
		{ Color3.fromRGB(250, 140, 120), Color3.fromRGB(230, 100, 90) }, -- coral
		{ Color3.fromRGB(200, 30, 60), Color3.fromRGB(150, 16, 40) }, -- deep red
		{ Color3.fromRGB(255, 200, 150), Color3.fromRGB(245, 170, 120) }, -- peach
		{ Color3.fromRGB(220, 170, 240), Color3.fromRGB(190, 130, 220) }, -- lilac
	}
	local function rose(m, cf, D, cols)
		local outer, inner = cols[1], cols[2]
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2 + D
			local pc = cf * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.new(0, 0.27 * D, 0.02 * D) * CFrame.Angles(0.45, 0, 0)
			oval(m, "Petal", Vector3.new(0.6 * D, 0.52 * D, 0.16 * D), pc, outer, Enum.Material.SmoothPlastic)
		end
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2 + 0.5
			local pc = cf * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.new(0, 0.13 * D, 0.14 * D) * CFrame.Angles(0.95, 0, 0)
			oval(m, "Petal", Vector3.new(0.42 * D, 0.36 * D, 0.14 * D), pc, inner:Lerp(outer, 0.3), Enum.Material.SmoothPlastic)
		end
		oval(m, "Bud", Vector3.new(0.3 * D, 0.3 * D, 0.32 * D), cf * CFrame.new(0, 0, 0.2 * D), inner, Enum.Material.SmoothPlastic)
	end
	Models.rose = rose
	local function leaf(m, cf, L, color)
		oval(m, "Leaf", Vector3.new(0.45 * L, L, 0.08 * L), cf, color, Enum.Material.SmoothPlastic)
	end
	-- a wall of roses on a green hedge (any size): the front is +Z
	function B.flowerwall(m, r)
		local w, h = dims(r, r.def)
		local rng = Random.new(math.floor(w * 7 + h * 13))
		part(m, "Frame", Vector3.new(w + 0.6, h + 0.6, 0.8), CFrame.new(0, h / 2, -0.7), Color3.fromRGB(40, 36, 34), Enum.Material.Wood)
		part(m, "Hedge", Vector3.new(w, h, 0.6), CFrame.new(0, h / 2, -0.25), Color3.fromRGB(40, 86, 44), Enum.Material.Grass)
		-- bushy green between the flowers
		local greens = { Color3.fromRGB(52, 104, 52), Color3.fromRGB(66, 124, 60), Color3.fromRGB(44, 92, 50) }
		for _ = 1, math.clamp(math.floor(w * h / 4), 8, 70) do
			local x, y = rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), rng:NextNumber(0.6, h - 0.6)
			leaf(m, CFrame.new(x, y, 0.1) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28)), rng:NextNumber(1.0, 1.7), greens[rng:NextInteger(1, 3)])
		end
		-- roses in a loose grid with a little jitter, bigger and smaller ones, a few colours that go together
		local palette = { ROSES[1], ROSES[2], ROSES[1], ROSES[5], ROSES[2], ROSES[3] }
		local step = 1.9
		local nx, ny = math.max(1, math.floor(w / step)), math.max(1, math.floor(h / step))
		local count = 0
		for j = 0, ny - 1 do
			for i = 0, nx - 1 do
				if count < 90 then
					count = count + 1
					local x = -w / 2 + (i + 0.5) * w / nx + rng:NextNumber(-0.35, 0.35)
					local y = (j + 0.5) * h / ny + rng:NextNumber(-0.3, 0.3)
					local D = rng:NextNumber(1.25, 1.9)
					rose(m, CFrame.new(x, y, 0.25) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(-0.25, 0.25), 0), D, palette[rng:NextInteger(1, #palette)])
				end
			end
		end
		r.neon = {}
	end

	---------------------------------------------------------------- a burnt-out wooden house, overgrown (front = +Z)
	function B.ruinedhouse(m, r)
		local char = Color3.fromRGB(44, 36, 32)
		local burnt = Color3.fromRGB(78, 60, 48)
		local wood = Color3.fromRGB(112, 86, 64)
		local WP = Enum.Material.WoodPlanks
		local rng = Random.new(42)
		local W, D, WH = 20, 14, 10 -- width, depth, wall height
		local hw, hd = W / 2, D / 2
		part(m, "Floor", Vector3.new(W, 0.6, D), CFrame.new(0, 0.3, 0), burnt, WP)
		-- a wall with holes: rects = { {x0, x1, y0, y1}, ... } are the solid pieces (local x along the wall)
		local function wall(cf, rects, color)
			for _, q in ipairs(rects) do
				part(m, "Wall", Vector3.new(q[2] - q[1], q[4] - q[3], 0.6), cf * CFrame.new((q[1] + q[2]) / 2, (q[3] + q[4]) / 2, 0), color or burnt, WP)
			end
		end
		-- back wall with a window, and its gable up to the ridge
		local back = CFrame.new(0, 0.6, -hd + 0.3)
		wall(back, { { -hw, hw, 0, 3.5 }, { -hw, -5, 3.5, 7 }, { -1, hw, 3.5, 7 }, { -hw, hw, 7, WH } })
		for _, sx in ipairs({ -1, 1 }) do
			New("WedgePart", { Name = "Gable", Size = Vector3.new(0.6, 5.2, hw), CFrame = back * CFrame.new(sx * hw / 2, WH + 2.6, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0), Color = burnt, Material = WP, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
		end
		-- left side: whole, with a window and a broken shutter
		local left = CFrame.new(-hw + 0.3, 0.6, 0) * CFrame.Angles(0, math.pi / 2, 0)
		wall(left, { { -hd, hd, 0, 3.5 }, { -hd, -1.5, 3.5, 7 }, { 2.5, hd, 3.5, 7 }, { -hd, hd, 7, WH } })
		part(m, "Shutter", Vector3.new(0.2, 3.2, 1.8), CFrame.new(-hw - 0.4, 4.6, 1.6) * CFrame.Angles(0.2, 0, 0.35), wood, WP)
		-- right side: burnt down to broken stumps of different heights
		for k, hgt in ipairs({ 8.5, 5.5, 2.6, 6.8, 3.4, 1.4 }) do
			local z = -hd + (k - 0.5) * D / 6
			part(m, "Wall", Vector3.new(0.6, hgt, D / 6), CFrame.new(hw - 0.3, 0.6 + hgt / 2, z), (k % 2 == 0) and char or burnt, WP)
		end
		-- front: the left part with an empty door frame, the right part fallen to a low stump
		local front = CFrame.new(0, 0.6, hd - 0.3)
		wall(front, { { -hw, -6, 0, WH }, { -2.5, 1, 0, 6.6 }, { 1, 4, 0, 2.2 }, { -6, -2.5, 7.6, WH } })
		for _, x in ipairs({ -6.1, -2.4 }) do
			part(m, "DoorPost", Vector3.new(0.5, 7.6, 0.8), CFrame.new(x, 0.6 + 3.8, hd - 0.3), wood, Enum.Material.Wood)
		end
		part(m, "Lintel", Vector3.new(4.4, 0.5, 0.8), CFrame.new(-4.25, 0.6 + 7.6, hd - 0.3), wood, Enum.Material.Wood)
		-- thick corner posts, a burnt ridge beam and rafters (two missing, one fallen)
		for _, c in ipairs({ { -hw, -hd }, { hw, -hd }, { -hw, hd }, { hw, hd } }) do
			part(m, "Post", Vector3.new(0.9, WH + 0.6, 0.9), CFrame.new(c[1] + (c[1] > 0 and -0.3 or 0.3), (WH + 0.6) / 2 + 0.3, c[2] + (c[2] > 0 and -0.3 or 0.3)), char, Enum.Material.Wood)
		end
		local ridgeY = WH + 0.6 + 5.4
		part(m, "Ridge", Vector3.new(0.7, 0.7, 9.5), CFrame.new(0, ridgeY, -hd + 4.75), char, Enum.Material.Wood)
		local slope = math.atan2(5.4, hw)
		local rafterL = math.sqrt(hw * hw + 5.4 * 5.4) + 0.6
		for k, z in ipairs({ -hd + 0.6, -3.5, 0.5, 3.8, hd - 0.6 }) do
			for _, sx in ipairs({ -1, 1 }) do
				local skip = (k == 3 and sx == 1) or (k == 5 and sx == -1)
				if not skip then
					local cf = CFrame.new(sx * hw / 2, WH + 0.6 + 2.7, z) * CFrame.Angles(0, 0, -sx * slope)
					if k == 4 and sx == 1 then
						-- broken: one end has come down onto the floor
						cf = CFrame.new(5.5, 3.6, z) * CFrame.Angles(0.15, 0, -0.75)
					end
					part(m, "Rafter", Vector3.new(rafterL, 0.5, 0.45), cf, (k % 2 == 0) and burnt or char, Enum.Material.Wood)
				end
			end
		end
		-- what is left of the roof: dark boards on the back of the left slope
		local roof = CFrame.new(-hw / 2, WH + 0.6 + 2.95, -hd + 3.2) * CFrame.Angles(0, 0, slope)
		part(m, "RoofBoards", Vector3.new(rafterL - 0.4, 0.3, 6.6), roof, Color3.fromRGB(46, 40, 38), Enum.Material.Slate)
		part(m, "RoofBoards", Vector3.new(rafterL * 0.55, 0.3, 3.0), CFrame.new(-hw * 0.72, WH + 0.6 + 1.5, -hd + 8.0) * CFrame.Angles(0, 0, slope), Color3.fromRGB(46, 40, 38), Enum.Material.Slate)
		-- a brick chimney at the back right, half fallen, bricks on the floor
		part(m, "Chimney", Vector3.new(2.4, 12, 2.4), CFrame.new(hw - 3, 6.6, -hd + 1.4), Color3.fromRGB(120, 60, 46), Enum.Material.Brick)
		part(m, "Chimney", Vector3.new(2.4, 2.2, 1.2), CFrame.new(hw - 3, 13.7, -hd + 0.8), Color3.fromRGB(110, 54, 42), Enum.Material.Brick)
		for i = 1, 9 do
			part(m, "Brick", Vector3.new(0.9, 0.45, 0.45), CFrame.new(hw - 4.5 + rng:NextNumber(-1.5, 1.5), 0.82, -hd + 4 + rng:NextNumber(-1, 1.5)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color3.fromRGB(120, 60, 46), Enum.Material.Brick)
		end
		-- debris: fallen beams and a pile of planks, a broken chair
		part(m, "FallenBeam", Vector3.new(0.6, 0.6, 9), CFrame.new(-2, 1.4, 1) * CFrame.Angles(0.12, 0.6, 0.05), char, Enum.Material.Wood)
		for k = 0, 5 do
			part(m, "Plank", Vector3.new(4.5, 0.18, 0.7), CFrame.new(3.5 + rng:NextNumber(-0.4, 0.4), 0.7 + k * 0.17, 3.5 + rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), (k % 2 == 0) and wood or burnt, WP)
		end
		part(m, "ChairSeat", Vector3.new(1.6, 0.2, 1.6), CFrame.new(-6, 2.0, -2) * CFrame.Angles(0, 0.4, 0.3), wood, Enum.Material.Wood)
		part(m, "ChairBack", Vector3.new(1.6, 1.8, 0.2), CFrame.new(-6.4, 2.9, -2.7) * CFrame.Angles(0, 0.4, 0.3), wood, Enum.Material.Wood)
		-- nature takes it back: ivy up the walls, roses and wild flowers by the door and inside
		local greens = { Color3.fromRGB(56, 112, 56), Color3.fromRGB(74, 132, 64), Color3.fromRGB(46, 96, 52) }
		local function ivy(x0, x1, z, side)
			for _ = 1, 16 do
				local x, y = rng:NextNumber(x0, x1), rng:NextNumber(0.8, 6.5) ^ 1.0
				leaf(m, CFrame.new(x, y, z) * CFrame.Angles(0, side, rng:NextNumber(0, 6.28)), rng:NextNumber(0.8, 1.3), greens[rng:NextInteger(1, 3)])
			end
		end
		ivy(-hw + 0.4, -6.4, hd + 0.05, 0)
		ivy(1.2, 3.8, hd + 0.05, 0)
		ivy(-hd + 0.5, hd - 0.5, 0, 0)
		for i = 1, 10 do
			local p = Vector3.new(-hw + rng:NextNumber(0.6, 3.8), rng:NextNumber(1.4, 7.2), -hd + rng:NextNumber(1, D - 1))
			rose(m, CFrame.new(-hw - 0.15, p.Y, p.Z) * CFrame.Angles(0, -math.pi / 2, 0), rng:NextNumber(0.9, 1.3), (i % 3 == 0) and ROSES[2] or ROSES[1])
		end
		for i = 1, 12 do
			local x = rng:NextNumber(-hw + 1, hw - 1)
			local z = hd + rng:NextNumber(0.4, 1.6)
			rose(m, CFrame.new(x, rng:NextNumber(0.5, 1.4), z) * CFrame.Angles(-0.6, rng:NextNumber(-0.4, 0.4), 0), rng:NextNumber(0.9, 1.3), ROSES[(i % 4) + 1])
			leaf(m, CFrame.new(x + 0.6, 0.5, z - 0.2) * CFrame.Angles(-1.2, 0, rng:NextNumber(-0.5, 0.5)), 1.2, greens[(i % 3) + 1])
		end
		-- a faint warm glow of embers in the debris
		local ember = part(m, "Embers", Vector3.new(3, 0.1, 2), CFrame.new(-1.5, 0.66, 2.5), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
		ember.Transparency = 0.55
		r.neon = {}
	end

	---------------------------------------------------------------- special elements (the artist rides them)
	-- Timing: LiveShow sets refs.readyAt / refs.readySong when the artist has arrived at the element in its
	-- song. Nothing moves before that (no platform leaves without the artist). rt = seconds since arrival.
	local smooth = H.smooth
	local DARKC = H.DARK
	local TEX_SMOKE = H.TEX_SMOKE

	-- Shower stage (after the rain B-stage of a big arena tour): a round glossy platform, a tall chrome shower
	-- pole that curves over it to a huge round rain shower head. In its song the head lights up and real-looking
	-- rain pours down over the whole platform: falling streaks, particles, splashes, mist, wet shine.
	function B.showerstage(m, r)
		local R = 9
		local SP = Enum.Material.SmoothPlastic
		local plat = cyl(m, "Deck", 1.2, R * 2, CFrame.new(0, 0.6, 0), Color3.fromRGB(20, 22, 30), SP)
		plat.Reflectance = 0.12
		r.surfaces = { plat }
		-- a light ring round the edge and a chrome drain in the middle
		r.neon = arcTube(m, "EdgeRing", CFrame.new(0, 1.18, 0) * CFrame.Angles(math.pi / 2, 0, 0), R - 0.25, 0, math.pi * 2, 32, 0.28, Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
		chrome(cyl(m, "Drain", 0.06, 2.2, CFrame.new(0, 1.22, 0), CHROME, SP))
		for k = -2, 2 do
			part(m, "DrainSlot", Vector3.new(1.6 - math.abs(k) * 0.3, 0.02, 0.12), CFrame.new(0, 1.26, k * 0.3), Color3.fromRGB(30, 30, 34))
		end
		-- the pole at the back, the curved arm, the neck and the big head
		local HY = 30
		local poleZ = -R + 0.6
		chrome(cyl(m, "Pole", HY - 4, 1.0, CFrame.new(0, 1.2 + (HY - 4) / 2, poleZ), CHROME, SP))
		chrome(cyl(m, "PoleFoot", 0.6, 2.2, CFrame.new(0, 1.5, poleZ), CHROME, SP))
		for _, p in ipairs(arcTube(m, "Arm", CFrame.new(0, HY - 2.8, poleZ + 4) * CFrame.Angles(0, math.pi / 2, 0), 4, 0, math.pi / 2, 10, 1.0, CHROME, SP)) do
			chrome(p)
		end
		chrome(tube(m, Vector3.new(0, HY + 1.2, poleZ + 3.6), Vector3.new(0, HY + 1.2, -0.4), 1.0, CHROME))
		chrome(tube(m, Vector3.new(0, HY + 1.2, 0), Vector3.new(0, HY - 0.3, 0), 0.8, CHROME))
		chrome(cyl(m, "Head", 0.9, 13, CFrame.new(0, HY - 0.6, 0), CHROME, SP))
		chrome(cyl(m, "HeadDome", 0.6, 9, CFrame.new(0, HY - 0.05, 0), CHROME, SP))
		r.face = cyl(m, "HeadFace", 0.12, 12.2, CFrame.new(0, HY - 1.08, 0), Color3.fromRGB(70, 80, 96), Enum.Material.Neon)
		r.face.Transparency = 0.2
		r.nozzles = {}
		for ring = 1, 3 do
			local rr = ring * 1.75
			for k = 0, ring * 7 - 1 do
				local a = k / (ring * 7) * math.pi * 2
				part(m, "Nozzle", Vector3.new(0.3, 0.06, 0.3), CFrame.new(math.sin(a) * rr, HY - 1.17, math.cos(a) * rr), Color3.fromRGB(46, 50, 58))
			end
		end
		r.showerLights = {}
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + 0.4
			local lp = part(m, "ShowerSpot", Vector3.new(0.6, 0.3, 0.6), CFrame.new(math.sin(a) * 4.6, HY - 1.2, math.cos(a) * 4.6), DARKC)
			table.insert(r.showerLights, New("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 70, Range = 44, Brightness = 0, Color = Color3.fromRGB(220, 235, 255), Shadows = false, Parent = lp }))
		end
		-- the rain: long thin falling streaks you can really see, plus fine particles
		r.streaks = {}
		local rng = Random.new(5)
		for i = 1, 70 do
			local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber(0, 1)) * 5.6
			local st = part(m, "RainStreak", Vector3.new(0.06, rng:NextNumber(2.2, 3.6), 0.06), CFrame.new(math.sin(a) * d, 10, math.cos(a) * d), Color3.fromRGB(200, 225, 255), Enum.Material.Neon)
			st.Transparency = 1
			table.insert(r.streaks, { p = st, x = math.sin(a) * d, z = math.cos(a) * d, o = rng:NextNumber(0, 1), v = rng:NextNumber(0.9, 1.1) })
		end
		r.headY = HY - 1.2
		r.rainSrc = part(m, "RainSource", Vector3.new(11, 0.1, 11), CFrame.new(0, HY - 1.3, 0), DARKC)
		r.rainSrc.Transparency = 1
		r.rain = New("ParticleEmitter", {
			Enabled = false,
			Rate = 1400,
			EmissionDirection = Enum.NormalId.Bottom,
			Lifetime = NumberRange.new((HY - 2.5) / 64, (HY - 2.5) / 58),
			Speed = NumberRange.new(58, 64),
			SpreadAngle = Vector2.new(0, 1),
			Size = NumberSequence.new(0.1),
			Squash = NumberSequence.new(3),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.9, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(225, 238, 255)),
			LightEmission = 0.75,
			LightInfluence = 0.3,
			Parent = r.rainSrc,
		})
		r.splashSrc = part(m, "SplashSource", Vector3.new(11, 0.1, 11), CFrame.new(0, 1.3, 0), DARKC)
		r.splashSrc.Transparency = 1
		r.splash = New("ParticleEmitter", { Enabled = false, Rate = 160, Lifetime = NumberRange.new(0.25, 0.45), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, -30, 0), Size = NumberSequence.new(0.14, 0.02), Transparency = NumberSequence.new(0.3, 1), Color = ColorSequence.new(Color3.fromRGB(230, 240, 255)), LightEmission = 0.6, Parent = r.splashSrc })
		r.mist = New("ParticleEmitter", { Enabled = false, Rate = 26, Texture = TEX_SMOKE, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(80, 80), Size = NumberSequence.new(3, 8), Transparency = NumberSequence.new(0.82, 1), Color = ColorSequence.new(Color3.fromRGB(220, 232, 248)), Parent = r.splashSrc })
		-- a film of water on the platform that shines while it rains
		r.water = cyl(m, "Water", 0.04, R * 2 - 1.2, CFrame.new(0, 1.23, 0), Color3.fromRGB(150, 190, 230), Enum.Material.Glass)
		r.water.Transparency = 1
		r.water.Reflectance = 0.5
	end

	-- Gown riser: a giant dress in four telescoping tiers around a hidden lift. The artist steps onto the low
	-- round hem, then the dress grows out of the stage around them and lifts them about 18 studs up.
	local GOWN = { { 1.1, 2.7 }, { 2.5, 4.5 }, { 4.3, 6.5 }, { 6.3, 8.8 } } -- top / bottom radius per tier
	local TIER_H = 6
	function B.gownriser(m, r)
		local dress = r.color:Lerp(Color3.fromRGB(150, 14, 34), 0.55)
		local gold = Color3.fromRGB(214, 172, 80)
		r.tiers = {}
		for i, tr in ipairs(GOWN) do
			local parts = frustum(maker(m, "Gown", dress:Lerp(Color3.new(0, 0, 0), (i - 1) * 0.05), Enum.Material.SmoothPlastic, 0.08), tr[2], tr[1], TIER_H, 22, CFrame.new(0, -TIER_H, 0), 0.25)
			for _, p in ipairs(arcTube(m, "Hem", CFrame.new(0, -TIER_H + 0.15, 0) * CFrame.Angles(math.pi / 2, 0, 0), tr[2] + 0.05, 0, math.pi * 2, 22, 0.32, gold, Enum.Material.SmoothPlastic)) do
				table.insert(parts, p)
			end
			if i > 1 then
				-- a flat flounce on top of the tier (hidden inside the tier above when the dress is up)
				for _, p in ipairs(ringPieces(maker(m, "Gown", dress:Lerp(Color3.new(1, 1, 1), 0.06), Enum.Material.SmoothPlastic, 0.08), GOWN[i - 1][1] - 0.1, tr[1] + 0.05, 0, math.pi * 2, 22, 0.1, CFrame.new(0, -0.05, 0))) do
					table.insert(parts, p)
				end
			end
			if i == 1 then
				table.insert(parts, cyl(m, "Stand", 0.3, 2.3, CFrame.new(0, -0.15, 0), dress, Enum.Material.SmoothPlastic))
				for _, p in ipairs(arcTube(m, "Waist", CFrame.new(0, 0, 0) * CFrame.Angles(math.pi / 2, 0, 0), 1.15, 0, math.pi * 2, 14, 0.25, gold, Enum.Material.SmoothPlastic)) do
					table.insert(parts, p)
				end
			end
			local list = {}
			for _, p in ipairs(parts) do
				table.insert(list, { p = p, off = p.CFrame }) -- built with the tier's top at y = 0
			end
			table.insert(r.tiers, list)
		end
		-- a flat hem on the floor that the artist steps onto (the lowest point of the dress)
		r.floorHem = frustum(maker(m, "Gown", dress, Enum.Material.SmoothPlastic, 0.08), 9.6, 8.6, 0.8, 22, CFrame.new(0, 0, 0), 0.25)
		ringPieces(maker(m, "Gown", dress, Enum.Material.SmoothPlastic, 0.08), 6.2, 8.7, 0, math.pi * 2, 22, 0.1, CFrame.new(0, 0.78, 0))
		local top = part(m, "HemTop", Vector3.new(17, 0.2, 17), CFrame.new(0, 1.2, 0), dress)
		top.Transparency = 1
		r.surfaces = { top }
		r.gownUp = -1
		Models.layoutGown(r, CFrame.new(), 0)
	end
	local GOWN_REST = { 1.45, 1.35, 1.25, 1.15 } -- tier tops when it is down (nested in each other)
	local GOWN_UP = { 19.5, 14.5, 9.5, 4.6 } -- tier tops when it is up (each overlaps the next by a stud)
	local function gownTop(i, e)
		return GOWN_REST[i] + (GOWN_UP[i] - GOWN_REST[i]) * e
	end
	function Models.layoutGown(refs, base, e)
		local parts, cfs = {}, {}
		for i, list in ipairs(refs.tiers) do
			local top = base * CFrame.new(0, gownTop(i, e), 0)
			for _, it in ipairs(list) do
				table.insert(parts, it.p)
				table.insert(cfs, top * it.off)
			end
		end
		for i, it in ipairs(parts) do
			it.CFrame = cfs[i]
		end
	end

	-- Glass cube lift: a glass cube on a plinth. The artist walks in, the glass walls roll down, the cube lifts
	-- them high above the stage on four cables and brings them back; the walls open again.
	function B.descendcube(m, r)
		local W, HH = 8, 9
		r.cubeW, r.cubeH = W, HH
		r.cubeAll = {}
		local function add(p)
			table.insert(r.cubeAll, { p = p, off = p.CFrame })
			return p
		end
		local plinth = part(m, "Plinth", Vector3.new(W + 1.6, 0.5, W + 1.6), CFrame.new(0, 0.25, 0), Color3.fromRGB(26, 26, 32))
		r.surfaces = { plinth }
		for _, e in ipairs({ { 0, (W + 1.6) / 2, W + 1.7, 0.14 }, { 0, -(W + 1.6) / 2, W + 1.7, 0.14 }, { (W + 1.6) / 2, 0, 0.14, W + 1.7 }, { -(W + 1.6) / 2, 0, 0.14, W + 1.7 } }) do
			part(m, "PlinthEdge", Vector3.new(e[3], 0.14, e[4]), CFrame.new(e[1], 0.45, e[2]), r.color, Enum.Material.Neon)
		end
		local floor = add(part(m, "CubeFloor", Vector3.new(W, 0.3, W), CFrame.new(0, 0.65, 0), Color3.fromRGB(240, 240, 246), Enum.Material.SmoothPlastic))
		floor.Reflectance = 0.2
		r.neon = {}
		for _, x in ipairs({ -W / 2, W / 2 }) do
			for _, z in ipairs({ -W / 2, W / 2 }) do
				add(part(m, "CubePost", Vector3.new(0.35, HH, 0.35), CFrame.new(x, 0.8 + HH / 2, z), Color3.fromRGB(30, 30, 34), Enum.Material.Metal))
				table.insert(r.neon, add(part(m, "CubeLight", Vector3.new(0.12, HH - 0.6, 0.12), CFrame.new(x * 1.04, 0.8 + HH / 2, z * 1.04), r.color, Enum.Material.Neon)))
			end
		end
		local topY = 0.8 + HH
		for _, z in ipairs({ -W / 2, W / 2 }) do
			add(part(m, "CubeRail", Vector3.new(W + 0.35, 0.7, 0.35), CFrame.new(0, topY, z), Color3.fromRGB(30, 30, 34), Enum.Material.Metal))
		end
		for _, x in ipairs({ -W / 2, W / 2 }) do
			add(part(m, "CubeRail", Vector3.new(0.35, 0.7, W + 0.35), CFrame.new(x, topY, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal))
		end
		local roof = add(part(m, "CubeRoof", Vector3.new(W, 0.2, W), CFrame.new(0, topY + 0.2, 0), Color3.fromRGB(36, 36, 40), Enum.Material.Metal))
		local dl = add(part(m, "CubeDownlight", Vector3.new(1.2, 0.1, 1.2), CFrame.new(0, topY - 0.15, 0), Color3.fromRGB(255, 245, 230), Enum.Material.Neon))
		r.cubeLight = New("SpotLight", { Face = Enum.NormalId.Bottom, Angle = 80, Range = 16, Brightness = 0, Color = Color3.fromRGB(255, 240, 220), Shadows = false, Parent = dl })
		local _ = roof
		-- four glass walls that roll down from the top rail (open = rolled up)
		r.walls = {}
		for k = 0, 3 do
			local a = k * math.pi / 2
			local g = part(m, "CubeGlass", Vector3.new(W - 0.4, 0.2, 0.1), CFrame.new(0, 0, 0), Color3.fromRGB(190, 220, 245), Enum.Material.Glass)
			g.Transparency = 0.55
			g.Reflectance = 0.15
			table.insert(r.walls, { p = g, a = a })
		end
		r.cubeTopY = topY
		r.cables = {}
		for _, c in ipairs({ { -W / 2, -W / 2 }, { W / 2, -W / 2 }, { -W / 2, W / 2 }, { W / 2, W / 2 } }) do
			table.insert(r.cables, { p = part(m, "CubeCable", Vector3.new(0.08, 1, 0.08), CFrame.new(), Color3.fromRGB(170, 170, 178), Enum.Material.Metal), x = c[1], z = c[2] })
		end
		r.cubeUp, r.cubeShut = -1, -1
		Models.layoutCube(r, CFrame.new(), 0, 0)
	end

	-- Floating platform: a slim round platform with a light ring and a glowing underside on four cables. It
	-- waits until the artist stands on it, then lifts them straight up (no flying over the crowd).
	function B.floatplat(m, r)
		r.floatAll = {}
		local function add(p)
			table.insert(r.floatAll, { p = p, off = p.CFrame })
			return p
		end
		local plat = add(cyl(m, "FloatDeck", 0.6, 10, CFrame.new(0, 0.3, 0), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic))
		plat.Reflectance = 0.15
		add(cyl(m, "FloatTop", 0.06, 9.2, CFrame.new(0, 0.62, 0), Color3.fromRGB(240, 240, 246), Enum.Material.SmoothPlastic))
		r.neon = {}
		for _, p in ipairs(arcTube(m, "FloatRing", CFrame.new(0, 0.3, 0) * CFrame.Angles(math.pi / 2, 0, 0), 5.05, 0, math.pi * 2, 28, 0.22, r.color, Enum.Material.Neon)) do
			add(p)
			table.insert(r.neon, p)
		end
		local under = add(cyl(m, "FloatGlow", 0.06, 8.6, CFrame.new(0, -0.02, 0), r.color, Enum.Material.Neon))
		table.insert(r.neon, under)
		r.cables = {}
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			table.insert(r.cables, { p = part(m, "FloatCable", Vector3.new(0.07, 1, 0.07), CFrame.new(), Color3.fromRGB(190, 190, 198), Enum.Material.Metal), x = math.sin(a) * 4.3, z = math.cos(a) * 4.3 })
		end
		r.surfaces = { plat }
		r.floatUp = -1
		Models.layoutFloat(r, CFrame.new(), 0)
	end

	-- the rig height above an element (cables go up there; at least 24 studs over the element)
	local function rigAbove(refs, base)
		return math.max((H.Builder.rigTop or 36) + 1, base.Position.Y + 24)
	end
	function Models.layoutCube(refs, base, up, shut)
		local lift = 14 * up
		local c = base * CFrame.new(0, lift, 0)
		for _, it in ipairs(refs.cubeAll) do
			it.p.CFrame = c * it.off
		end
		-- the glass rolls down from the top rail
		local hh = math.max(0.2, (refs.cubeH - 0.4) * shut)
		for _, wl in ipairs(refs.walls) do
			wl.p.Size = Vector3.new(refs.cubeW - 0.4, hh, 0.1)
			wl.p.CFrame = c * CFrame.Angles(0, wl.a, 0) * CFrame.new(0, refs.cubeTopY - 0.35 - hh / 2, refs.cubeW / 2 - 0.05)
			wl.p.Transparency = (shut > 0.02) and 0.55 or 1
		end
		local top = rigAbove(refs, base) - base.Position.Y
		for _, cb in ipairs(refs.cables) do
			local y0 = refs.cubeTopY + lift + 0.3
			local len = math.max(0.2, top - y0)
			cb.p.Size = Vector3.new(0.08, len, 0.08)
			cb.p.CFrame = base * CFrame.new(cb.x, y0 + len / 2, cb.z)
		end
		refs.cubeLight.Brightness = (shut > 0.5) and 2.5 or 0
	end
	function Models.layoutFloat(refs, base, e)
		local lift = 14 * e
		local c = base * CFrame.new(0, lift, 0)
		for _, it in ipairs(refs.floatAll) do
			it.p.CFrame = c * it.off
		end
		local top = rigAbove(refs, base) - base.Position.Y
		for _, cb in ipairs(refs.cables) do
			local y0 = lift + 0.5
			local len = math.max(0.2, top - y0)
			cb.p.Size = Vector3.new(0.07, len, 0.07)
			cb.p.CFrame = base * CFrame.new(cb.x, y0 + len / 2, cb.z)
		end
	end

	-- animation of the special elements; returns true when it handled the kind
	function Models.animate(refs, ctx)
		local k = refs.kind
		if k == "grandclock" then
			local sw = CFrame.Angles(0, 0, math.sin((ctx.t or 0) * 2.4) * 0.22)
			for _, p in ipairs(refs.pendulum) do
				p.p.CFrame = refs.cf * refs.pendTop * sw * p.off
			end
			return true
		end
		if k ~= "showerstage" and k ~= "gownriser" and k ~= "descendcube" and k ~= "floatplat" then
			return false
		end
		local rec = refs.rec or {}
		local active = type(rec.play) == "number" and rec.play == ctx.songNum
		local f = active and (ctx.songFrac or 0) or 0
		-- seconds since the artist arrived (nil: not there yet)
		local rt = nil
		if active and refs.readySong == ctx.songNum and refs.readyAt then
			rt = (ctx.t or 0) - refs.readyAt
		end
		local base = refs.cf
		if k == "showerstage" then
			local on = rt ~= nil and rt > 3 and f < 0.97
			local glow = active and math.clamp((rt or 0) / 3, 0, 1) or 0
			refs.face.Color = Color3.fromRGB(70, 80, 96):Lerp(Color3.fromRGB(225, 238, 255), glow)
			if refs.raining ~= on then
				refs.raining = on
				refs.rain.Enabled = on
				refs.splash.Enabled = on
				refs.mist.Enabled = on
				for _, sl in ipairs(refs.showerLights) do
					sl.Brightness = on and 3.2 or 0
				end
				refs.water.Transparency = on and 0.55 or 1
				for _, st in ipairs(refs.streaks) do
					st.p.Transparency = on and 0.35 or 1
				end
			end
			if on then
				-- every streak falls from the head to the platform and starts again at the top
				local fall = refs.headY - 1.4
				for _, st in ipairs(refs.streaks) do
					local u = ((ctx.t or 0) * st.v * 1.6 + st.o) % 1
					st.p.CFrame = base * CFrame.new(st.x, refs.headY - u * fall, st.z)
				end
			end
			refs.ride = nil
			return true
		elseif k == "gownriser" then
			local e = 0
			if rt then
				e = smooth(rt, 1.5, 9) * (1 - smooth(f, 0.86, 0.97))
			end
			if math.abs(e - refs.gownUp) > 0.001 then
				refs.gownUp = e
				Models.layoutGown(refs, base, e)
			end
			refs.ride = active and { pos = (base * CFrame.new(0, gownTop(1, e) + 0.05, 0)).Position, move = (e > 0.2) and "gown" or nil } or nil
			return true
		elseif k == "descendcube" then
			local shut, up = 0, 0
			if rt then
				shut = smooth(rt, 0.6, 2.4) * (1 - smooth(f, 0.93, 0.98))
				up = smooth(rt, 3, 9) * (1 - smooth(f, 0.8, 0.92))
			end
			local lift = 14 * up
			if math.abs(up - refs.cubeUp) > 0.001 or math.abs(shut - refs.cubeShut) > 0.001 then
				refs.cubeUp, refs.cubeShut = up, shut
				Models.layoutCube(refs, base, up, shut)
			end
			refs.ride = active and { pos = (base * CFrame.new(0, 0.8 + lift, 0)).Position, move = (up > 0.1) and "wave" or nil } or nil
			return true
		elseif k == "floatplat" then
			local e = 0
			if rt then
				e = smooth(rt, 1.5, 7.5) * (1 - smooth(f, 0.86, 0.96))
			end
			local lift = 14 * e
			if math.abs(e - refs.floatUp) > 0.001 then
				refs.floatUp = e
				Models.layoutFloat(refs, base, e)
			end
			-- up there the artist strikes their own pose (LiveShow picks it per artist: lie down, sit ...)
			refs.ride = active and { pos = (base * CFrame.new(0, lift + 0.65, 0)).Position, posing = e > 0.95 } or nil
			return true
		end
		return false
	end

	---------------------------------------------------------------- shapes (build your own set pieces)
	-- every shape takes its colour and material from Style (rec.col, rec.mat): H.primPart
	local primPart = H.primPart
	local function pm(m, r)
		return function(size, cf, kind)
			return primPart(m, r, size, cf, kind ~= "block" and kind or nil)
		end
	end
	local function primDims(r)
		local w, d, h = dims(r, r.def)
		return w, d, h
	end
	function B.prim_cone(m, r)
		local w, _, h = primDims(r)
		frustum(pm(m, r), w / 2, 0, h, 24, CFrame.new(), 0.3)
		ringPieces(pm(m, r), 0, w / 2, 0, math.pi * 2, 24, 0.2, CFrame.new(0, 0.1, 0))
	end
	function B.prim_frustum(m, r)
		local w, _, h = primDims(r)
		frustum(pm(m, r), w / 2, w / 4, h, 24, CFrame.new(), 0.3)
		ringPieces(pm(m, r), 0, w / 4, 0, math.pi * 2, 24, 0.2, CFrame.new(0, h - 0.1, 0))
		ringPieces(pm(m, r), 0, w / 2, 0, math.pi * 2, 24, 0.2, CFrame.new(0, 0.1, 0))
	end
	function B.prim_pyramid(m, r)
		local w, _, h = primDims(r)
		local R = w / 2 / math.cos(math.pi / 4)
		frustum(pm(m, r), R, 0, h, 4, CFrame.Angles(0, math.pi / 4, 0), 0.3)
		r.surfaces = { primPart(m, r, Vector3.new(w, 0.2, w), CFrame.new(0, 0.1, 0)) }
	end
	function B.prim_dome(m, r)
		local w, _, h = primDims(r)
		-- a half ball from 6 bands, each band a smooth frustum
		local R = w / 2
		local n = 6
		for i = 0, n - 1 do
			local a0, a1 = i / n * math.pi / 2, (i + 1) / n * math.pi / 2
			local y0, y1 = math.sin(a0) * h, math.sin(a1) * h
			frustum(pm(m, r), math.cos(a0) * R, math.cos(a1) * R, y1 - y0, 24, CFrame.new(0, y0, 0), 0.3)
		end
		ringPieces(pm(m, r), 0, R, 0, math.pi * 2, 24, 0.2, CFrame.new(0, 0.1, 0))
	end
	function B.prim_hex(m, r)
		local w, _, h = primDims(r)
		r.surfaces = ringPieces(pm(m, r), 0, w / 2, 0, math.pi * 2, 6, h, CFrame.new(0, h / 2, 0))
	end
	function B.prim_oct(m, r)
		local w, _, h = primDims(r)
		r.surfaces = ringPieces(pm(m, r), 0, w / 2, math.pi / 8, math.pi * 2 + math.pi / 8, 8, h, CFrame.new(0, h / 2, 0))
	end
	function B.prim_pipe(m, r)
		-- a cylinder lying along X (pipes, logs, rollers): w = length, d = thickness
		local w, d = primDims(r)
		primPart(m, r, Vector3.new(w, d, d), CFrame.new(0, d / 2, 0)).Shape = Enum.PartType.Cylinder
	end
	function B.prim_halfcyl(m, r)
		-- half a cylinder lying along X, round side up (tunnels, arches you can stand on)
		local w, d = primDims(r)
		ringPieces(pm(m, r), 0, d / 2, 0, math.pi, 16, w, CFrame.Angles(0, 0, math.pi / 2))
	end
	function B.prim_arch(m, r)
		-- a standing arch (portal, frame of a doorway): w = width, h = height of the opening's top, d = depth
		local w, d, h = primDims(r)
		local R = w / 2
		local thick = math.clamp(w * 0.12, 0.4, 6)
		local legH = math.max(0, h - R)
		for _, sx in ipairs({ -1, 1 }) do
			if legH > 0.05 then
				primPart(m, r, Vector3.new(thick, legH, d), CFrame.new(sx * (R - thick / 2), legH / 2, 0))
			end
		end
		ringPieces(pm(m, r), R - thick, R, -math.pi / 2, math.pi / 2, 18, d, CFrame.new(0, legH, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
	end
	function B.prim_curve(m, r)
		-- a curved wall: a quarter of a ring, w = radius, h = height
		local w, _, h = primDims(r)
		ringPieces(pm(m, r), w - 0.6, w, -math.pi / 4, math.pi / 4, 12, h, CFrame.new(0, h / 2, -w * 0.85))
	end
	function B.prim_prism(m, r)
		-- a triangular prism lying along X, the ridge on top
		local w, d, h = primDims(r)
		for _, sx in ipairs({ -1, 1 }) do
			-- the wedge's tall face in the middle, its slope down to the outside
			local vY = Vector3.new(0, 1, 0)
			local vZ = Vector3.new(0, 0, -sx)
			local vX = vY:Cross(vZ)
			primPart(m, r, Vector3.new(w, h, d / 2), CFrame.fromMatrix(Vector3.new(0, h / 2, sx * d / 4), vX, vY, vZ), "wedge")
		end
	end
	function B.prim_star(m, r)
		-- a five-pointed star standing upright (thickness d)
		local w, d = primDims(r)
		local R = w / 2
		local Ri = R * 0.4
		local th = math.pi / 5
		local up = CFrame.new(0, R * 0.95, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		ringPieces(pm(m, r), 0, Ri, -th, math.pi * 2 - th, 5, d, up)
		local ap = Ri * math.cos(th)
		local edgeW = 2 * Ri * math.sin(th)
		local L = R - ap
		for i = 0, 4 do
			local cf = up * CFrame.Angles(0, 2 * i * th, 0) * CFrame.new(0, 0, (ap + R) / 2) * CFrame.Angles(math.pi / 2, 0, 0)
			trapPanel(pm(m, r), cf, 0, edgeW, L, d)
		end
	end
	function B.prim_heart(m, r)
		-- a heart standing upright (thickness d)
		local w, d = primDims(r)
		local a = w / 1.707
		local q = a / math.sqrt(2)
		primPart(m, r, Vector3.new(a, a, d), CFrame.new(0, q, 0) * CFrame.Angles(0, 0, math.pi / 4))
		for _, sx in ipairs({ -1, 1 }) do
			primPart(m, r, Vector3.new(d, a, a), CFrame.new(sx * q / 2, q * 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0)).Shape = Enum.PartType.Cylinder
		end
	end
	function B.prim_frame(m, r)
		-- a frame standing upright (picture frame, window, portal): w x h, d deep
		local w, d, h = primDims(r)
		local t = math.clamp(math.min(w, h) * 0.12, 0.3, 4)
		primPart(m, r, Vector3.new(w, t, d), CFrame.new(0, t / 2, 0))
		primPart(m, r, Vector3.new(w, t, d), CFrame.new(0, h - t / 2, 0))
		for _, sx in ipairs({ -1, 1 }) do
			primPart(m, r, Vector3.new(t, h - 2 * t, d), CFrame.new(sx * (w / 2 - t / 2), h / 2, 0))
		end
	end
	function B.prim_cross(m, r)
		local w, d, h = primDims(r)
		local t = math.min(w, h) * 0.3
		primPart(m, r, Vector3.new(w, t, d), CFrame.new(0, h / 2, 0))
		primPart(m, r, Vector3.new(t, h, d), CFrame.new(0, h / 2, 0))
	end
	function B.prim_steps(m, r)
		local w, d, h = primDims(r)
		local n = math.max(2, math.floor(h / 0.8 + 0.5))
		r.surfaces = {}
		for i = 1, n do
			local sh = i * h / n
			table.insert(r.surfaces, primPart(m, r, Vector3.new(w, sh, d / n), CFrame.new(0, sh / 2, d / 2 - (i - 0.5) * d / n)))
		end
	end
	function B.prim_torus(m, r)
		-- a lying ring with a round cross-section (h = thickness)
		local w, _, h = primDims(r)
		local color, mat = H.primLook(r)
		arcTube(m, "Shape", CFrame.new(0, h / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0), w / 2 - h / 2, 0, math.pi * 2, 28, h, color, mat)
	end
	function B.prim_capsule(m, r)
		local w, d = primDims(r)
		local len = math.max(0.1, w - d)
		primPart(m, r, Vector3.new(len, d, d), CFrame.new(0, d / 2, 0)).Shape = Enum.PartType.Cylinder
		for _, sx in ipairs({ -1, 1 }) do
			primPart(m, r, Vector3.new(d, d, d), CFrame.new(sx * len / 2, d / 2, 0)).Shape = Enum.PartType.Ball
		end
	end
	function B.prim_disc(m, r)
		-- a thin round plate lying flat (tables, platforms, halos)
		local w, _, h = primDims(r)
		r.surfaces = { cyl(m, "Shape", h, w, CFrame.new(0, h / 2, 0), H.primLook(r)) }
		local _, mat = H.primLook(r)
		r.surfaces[1].Material = mat
	end

	---------------------------------------------------------------- more decor and set pieces (front = +Z)
	local WOOD = Color3.fromRGB(120, 82, 52)
	local GOLD = Color3.fromRGB(212, 170, 80)
	local function turnedLeg(m, x, z, h, d, color, mat)
		cyl(m, "Leg", h, d, CFrame.new(x, h / 2, z), color, mat or Enum.Material.Wood)
		ball(m, "LegKnob", d * 1.5, Vector3.new(x, h * 0.55, z), color, mat or Enum.Material.Wood)
	end

	-- dressing table with a bulb-lit mirror and a stool (backstage look)
	function B.vanity(m, r)
		local white = Color3.fromRGB(240, 236, 230)
		part(m, "Top", Vector3.new(7, 0.4, 2.6), CFrame.new(0, 3.2, 0), white, Enum.Material.Wood)
		for _, x in ipairs({ -3.1, 3.1 }) do
			part(m, "Drawers", Vector3.new(1.6, 3, 2.4), CFrame.new(x * 0.82, 1.5, 0), white, Enum.Material.Wood)
			for k = 0, 2 do
				part(m, "DrawerFront", Vector3.new(1.4, 0.8, 0.06), CFrame.new(x * 0.82, 0.55 + k * 0.95, 1.22), Color3.fromRGB(230, 226, 220), Enum.Material.Wood)
				chrome(ball(m, "Knob", 0.18, Vector3.new(x * 0.82, 0.55 + k * 0.95, 1.3), GOLD, Enum.Material.SmoothPlastic))
			end
		end
		part(m, "MirrorBack", Vector3.new(6.2, 4.6, 0.3), CFrame.new(0, 5.7, -1.0), white, Enum.Material.Wood)
		local mirror = part(m, "Mirror", Vector3.new(5.2, 3.6, 0.06), CFrame.new(0, 5.7, -0.83), Color3.fromRGB(200, 210, 225), Enum.Material.Glass)
		mirror.Reflectance = 0.5
		r.neon = {}
		for k = 0, 4 do
			for _, x in ipairs({ -2.85, 2.85 }) do
				table.insert(r.neon, ball(m, "Bulb", 0.4, Vector3.new(x, 4.0 + k * 0.85, -0.8), Color3.fromRGB(255, 236, 190), Enum.Material.Neon))
			end
			table.insert(r.neon, ball(m, "Bulb", 0.4, Vector3.new(-2 + k, 7.8, -0.8), Color3.fromRGB(255, 236, 190), Enum.Material.Neon))
		end
		-- make-up, brushes, a vase of roses
		for k = 0, 3 do
			cyl(m, "Bottle", 0.5 + (k % 2) * 0.3, 0.32, CFrame.new(-2 + k * 0.45, 3.6 + (k % 2) * 0.15, -0.3), ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(240, 200, 120), Color3.fromRGB(160, 120, 220), Color3.fromRGB(230, 230, 236) })[k + 1], Enum.Material.Glass)
		end
		cyl(m, "Vase", 1.0, 0.6, CFrame.new(2.2, 3.9, -0.2), Color3.fromRGB(220, 230, 240), Enum.Material.Glass)
		for k = 0, 2 do
			rose(m, CFrame.new(2.0 + k * 0.25, 4.7 + (k % 2) * 0.3, 0.0) * CFrame.Angles(-0.4, 0, 0), 0.7, ROSES[1 + k % 2])
		end
		cyl(m, "Stool", 2.1, 0.3, CFrame.new(0, 1.05, 2.4), Color3.fromRGB(200, 196, 190), Enum.Material.Metal)
		cyl(m, "StoolSeat", 0.6, 2.0, CFrame.new(0, 2.3, 2.4), Color3.fromRGB(240, 170, 190), Enum.Material.Fabric)
	end

	-- claw-foot bathtub (white enamel, gold feet and taps)
	function B.bathtub(m, r)
		local enamel = Color3.fromRGB(246, 246, 250)
		frustum(maker(m, "Tub", enamel, Enum.Material.SmoothPlastic), 2.6, 2.95, 2.6, 20, CFrame.new(0, 0.9, 0) * CFrame.new(), 0.3)
		-- stretch the round tub into a long oval: built round, then squeezed along X
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Tub" then
				local c = p.CFrame
				p.CFrame = CFrame.new(c.Position.X, c.Position.Y, c.Position.Z * 0.55) * (c - c.Position)
			end
		end
		oval(m, "TubBody", Vector3.new(5.6, 2.6, 3.2), CFrame.new(0, 2.1, 0), enamel, Enum.Material.SmoothPlastic)
		arcTube(m, "Rim", CFrame.new(0, 3.45, 0) * CFrame.Angles(math.pi / 2, 0, 0), 2.9, 0, math.pi * 2, 22, 0.35, enamel, Enum.Material.SmoothPlastic)
		local water = cyl(m, "Water", 0.1, 5.0, CFrame.new(0, 3.1, 0), Color3.fromRGB(180, 215, 240), Enum.Material.Glass)
		water.Transparency = 0.3
		for _, x in ipairs({ -2, 2 }) do
			for _, z in ipairs({ -0.9, 0.9 }) do
				chrome(ball(m, "ClawFoot", 0.6, Vector3.new(x, 0.45, z), GOLD, Enum.Material.SmoothPlastic))
				chrome(tube(m, Vector3.new(x, 0.45, z), Vector3.new(x * 0.9, 1.3, z * 0.85), 0.3, GOLD))
			end
		end
		chrome(tube(m, Vector3.new(-2.7, 3.0, 0), Vector3.new(-2.7, 4.6, 0), 0.22, GOLD))
		chrome(tube(m, Vector3.new(-2.7, 4.6, 0), Vector3.new(-2.1, 4.6, 0), 0.22, GOLD))
		for _, z in ipairs({ -0.5, 0.5 }) do
			chrome(cyl(m, "Tap", 0.3, 0.4, CFrame.new(-2.75, 3.8, z), GOLD, Enum.Material.SmoothPlastic))
		end
		-- bubbles
		for k = 0, 7 do
			ball(m, "Foam", 0.6 + (k % 3) * 0.2, Vector3.new(-1.5 + (k % 4) * 1.0, 3.25, -0.5 + math.floor(k / 4) * 1.0), Color3.fromRGB(250, 250, 255), Enum.Material.SmoothPlastic)
		end
	end
	-- deep velvet armchair with rolled arms
	function B.armchair(m, r)
		local velvet = r.color:Lerp(Color3.fromRGB(120, 20, 50), 0.6)
		local SPm = Enum.Material.Fabric
		for _, x in ipairs({ -1.6, 1.6 }) do
			for _, z in ipairs({ -1.3, 1.3 }) do
				turnedLeg(m, x, z, 0.9, 0.3, WOOD)
			end
		end
		part(m, "Base", Vector3.new(4.0, 1.0, 3.4), CFrame.new(0, 1.3, 0), velvet, SPm)
		oval(m, "Cushion", Vector3.new(3.0, 0.9, 2.8), CFrame.new(0, 2.0, 0.2), velvet:Lerp(Color3.new(1, 1, 1), 0.05), SPm)
		part(m, "Back", Vector3.new(4.0, 3.4, 0.8), CFrame.new(0, 3.2, -1.4) * CFrame.Angles(-0.12, 0, 0), velvet, SPm)
		cylX(m, "BackRoll", 4.0, 0.9, CFrame.new(0, 4.85, -1.6), velvet, SPm)
		for _, x in ipairs({ -1.85, 1.85 }) do
			part(m, "Arm", Vector3.new(0.7, 1.4, 3.2), CFrame.new(x, 2.2, 0.05), velvet, SPm)
			cylZ(m, "ArmRoll", 3.3, 1.0, CFrame.new(x, 2.95, 0.05), velvet, SPm)
			for k = 0, 3 do
				chrome(ball(m, "Stud", 0.12, Vector3.new(x * 1.01 + (x > 0 and 0.36 or -0.36), 1.6, -1.2 + k * 0.8), GOLD, Enum.Material.SmoothPlastic))
			end
		end
		for k = -2, 2 do
			ball(m, "Button", 0.16, Vector3.new(k * 0.7, 3.3 + (k % 2) * 0.6, -0.95), velvet:Lerp(Color3.new(0, 0, 0), 0.3), SPm)
		end
	end
	-- grandfather clock with a swinging pendulum
	function B.grandclock(m, r)
		local wood = Color3.fromRGB(90, 52, 30)
		part(m, "Base", Vector3.new(3.0, 2.4, 1.8), CFrame.new(0, 1.2, 0), wood, Enum.Material.Wood)
		part(m, "Body", Vector3.new(2.3, 6.0, 1.4), CFrame.new(0, 5.4, 0), wood, Enum.Material.Wood)
		local glass = part(m, "Window", Vector3.new(1.5, 4.6, 0.06), CFrame.new(0, 5.4, 0.72), Color3.fromRGB(200, 215, 230), Enum.Material.Glass)
		glass.Transparency = 0.55
		part(m, "Hood", Vector3.new(3.0, 3.2, 1.8), CFrame.new(0, 10.0, 0), wood, Enum.Material.Wood)
		cylX(m, "Crown", 3.2, 1.6, CFrame.new(0, 11.6, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0), wood, Enum.Material.Wood).Size = Vector3.new(1.8, 1.6, 3.2)
		cylZ(m, "Face", 0.1, 2.3, CFrame.new(0, 10.0, 0.92), Color3.fromRGB(246, 238, 218), Enum.Material.SmoothPlastic)
		arcTube(m, "FaceRing", CFrame.new(0, 10.0, 0.95), 1.15, 0, math.pi * 2, 18, 0.14, GOLD, Enum.Material.SmoothPlastic)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			part(m, "Tick", Vector3.new(0.08, (k % 3 == 0) and 0.3 or 0.16, 0.04), CFrame.new(math.sin(a) * 0.9, 10.0 + math.cos(a) * 0.9, 0.99) * CFrame.Angles(0, 0, -a), Color3.fromRGB(30, 30, 34))
		end
		part(m, "HandH", Vector3.new(0.1, 0.55, 0.04), CFrame.new(0.18, 10.2, 1.01) * CFrame.Angles(0, 0, -0.9), Color3.fromRGB(30, 30, 34))
		part(m, "HandM", Vector3.new(0.07, 0.85, 0.04), CFrame.new(-0.05, 10.42, 1.02) * CFrame.Angles(0, 0, 0.1), Color3.fromRGB(30, 30, 34))
		r.pendulum = {}
		r.pendTop = CFrame.new(0, 8.1, 0.2)
		table.insert(r.pendulum, { p = part(m, "PendulumRod", Vector3.new(0.1, 3.4, 0.08), r.pendTop * CFrame.new(0, -1.7, 0), GOLD, Enum.Material.SmoothPlastic), off = CFrame.new(0, -1.7, 0) })
		table.insert(r.pendulum, { p = cylZ(m, "PendulumBob", 0.12, 0.9, r.pendTop * CFrame.new(0, -3.5, 0), GOLD, Enum.Material.SmoothPlastic), off = CFrame.new(0, -3.5, 0) * CFrame.Angles(0, math.pi / 2, 0) })
		for _, p in ipairs(r.pendulum) do
			chrome(p.p)
		end
	end
	-- classic red telephone box with glowing windows
	function B.phonebooth(m, r)
		local red = Color3.fromRGB(196, 24, 30)
		part(m, "Base", Vector3.new(4.2, 0.5, 4.2), CFrame.new(0, 0.25, 0), red, Enum.Material.SmoothPlastic)
		for _, c in ipairs({ { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } }) do
			part(m, "Post", Vector3.new(0.5, 9, 0.5), CFrame.new(c[1], 4.95, c[2]), red, Enum.Material.SmoothPlastic)
		end
		r.neon = {}
		for k = 0, 3 do
			local a = k * math.pi / 2
			local f = CFrame.Angles(0, a, 0)
			part(m, "Door", Vector3.new(3.2, 9, 0.2), f * CFrame.new(0, 4.95, 1.85), red, Enum.Material.SmoothPlastic)
			for row = 0, 5 do
				for col = 0, 2 do
					local g = part(m, "Pane", Vector3.new(0.82, 0.95, 0.08), f * CFrame.new(-0.95 + col * 0.95, 2.4 + row * 1.1, 1.97), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
					g.Transparency = 0.15
				end
			end
			part(m, "Sign", Vector3.new(3.0, 0.8, 0.1), f * CFrame.new(0, 9.0, 1.98), Color3.fromRGB(250, 250, 250), Enum.Material.Neon)
			part(m, "Pediment", Vector3.new(4.0, 0.5, 0.3), f * CFrame.new(0, 9.7, 1.9), red, Enum.Material.SmoothPlastic)
		end
		part(m, "Roof", Vector3.new(4.4, 0.6, 4.4), CFrame.new(0, 9.9, 0), red, Enum.Material.SmoothPlastic)
		ringPieces(maker(m, "Dome", red, Enum.Material.SmoothPlastic), 0, 2.2, 0, math.pi, 10, 4.0, CFrame.new(0, 10.2, 0) * CFrame.Angles(0, 0, math.pi / 2))
		chrome(ball(m, "Crown", 0.6, Vector3.new(0, 12.5, 0), GOLD, Enum.Material.SmoothPlastic))
	end
	-- white picket fence (any length)
	function B.picketfence(m, r)
		local w = dims(r, r.def)
		local white = Color3.fromRGB(246, 246, 242)
		for _, y in ipairs({ 1.0, 2.6 }) do
			part(m, "Rail", Vector3.new(w, 0.35, 0.2), CFrame.new(0, y, -0.15), white, Enum.Material.Wood)
		end
		local n = math.max(2, math.floor(w / 0.9))
		for i = 0, n - 1 do
			local x = -w / 2 + (i + 0.5) * w / n
			part(m, "Picket", Vector3.new(0.5, 3.2, 0.14), CFrame.new(x, 1.6, 0), white, Enum.Material.Wood)
			New("WedgePart", { Name = "PicketTip", Size = Vector3.new(0.14, 0.4, 0.25), CFrame = CFrame.new(x - 0.125, 3.4, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = white, Material = Enum.Material.Wood, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
			New("WedgePart", { Name = "PicketTip", Size = Vector3.new(0.14, 0.4, 0.25), CFrame = CFrame.new(x + 0.125, 3.4, 0) * CFrame.Angles(0, -math.pi / 2, 0), Color = white, Material = Enum.Material.Wood, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
		end
	end
	-- cherry blossom tree: a crooked trunk, branches and pink clouds of blossom, petals on the ground
	function B.cherrytree(m, r)
		local bark = Color3.fromRGB(70, 48, 40)
		local rng = Random.new(11)
		local pinks = { Color3.fromRGB(255, 190, 210), Color3.fromRGB(250, 170, 196), Color3.fromRGB(255, 214, 228), Color3.fromRGB(240, 150, 186) }
		local pts = { Vector3.new(0, 0, 0), Vector3.new(0.3, 4, 0.2), Vector3.new(-0.2, 7.5, 0) }
		for i = 1, #pts - 1 do
			tube(m, pts[i], pts[i + 1], 1.5 - i * 0.3, bark).Material = Enum.Material.Wood
		end
		local tips = {}
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + 0.3
			local tip = Vector3.new(math.sin(a) * 6, 9 + rng:NextNumber(-1, 2), math.cos(a) * 5)
			local mid = Vector3.new(math.sin(a) * 2.6, 8.5, math.cos(a) * 2.2)
			tube(m, pts[3], mid, 0.7, bark).Material = Enum.Material.Wood
			tube(m, mid, tip, 0.45, bark).Material = Enum.Material.Wood
			table.insert(tips, tip)
		end
		table.insert(tips, Vector3.new(0, 12, 0))
		for _, tip in ipairs(tips) do
			for _ = 1, 5 do
				local c = tip + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-0.8, 1.6), rng:NextNumber(-2, 2))
				oval(m, "Blossom", Vector3.new(rng:NextNumber(3, 4.6), rng:NextNumber(2.2, 3.2), rng:NextNumber(3, 4.6)), CFrame.new(c), pinks[rng:NextInteger(1, 4)], Enum.Material.SmoothPlastic)
			end
		end
		for _ = 1, 26 do
			local a, d = rng:NextNumber(0, 6.28), rng:NextNumber(1, 7)
			part(m, "Petal", Vector3.new(0.4, 0.04, 0.3), CFrame.new(math.sin(a) * d, 0.03, math.cos(a) * d) * CFrame.Angles(0, a, 0), pinks[rng:NextInteger(1, 4)])
		end
	end
	-- crystal chandelier (hangs from the rig: built downwards)
	function B.chandelier(m, r)
		local cr = Color3.fromRGB(235, 240, 255)
		tube(m, Vector3.new(0, 0, 0), Vector3.new(0, -4, 0), 0.12, GOLD)
		chrome(oval(m, "Body", Vector3.new(1.4, 2.4, 1.4), CFrame.new(0, -5, 0), GOLD, Enum.Material.SmoothPlastic))
		r.neon = {}
		for tier, def in ipairs({ { R = 4.2, y = -6.2, n = 12 }, { R = 2.8, y = -4.6, n = 8 } }) do
			for _, p in ipairs(arcTube(m, "Ring", CFrame.new(0, def.y, 0) * CFrame.Angles(math.pi / 2, 0, 0), def.R, 0, math.pi * 2, 18, 0.18, GOLD, Enum.Material.SmoothPlastic)) do
				chrome(p)
			end
			for k = 0, def.n - 1 do
				local a = k / def.n * math.pi * 2
				local x, z = math.sin(a) * def.R, math.cos(a) * def.R
				chrome(tube(m, Vector3.new(0, -5, 0), Vector3.new(x, def.y, z), 0.1, GOLD))
				cyl(m, "Candle", 0.7, 0.25, CFrame.new(x, def.y + 0.45, z), Color3.fromRGB(250, 246, 236))
				table.insert(r.neon, ball(m, "Flame", 0.3, Vector3.new(x, def.y + 0.95, z), Color3.fromRGB(255, 220, 150), Enum.Material.Neon))
				for d = 1, 3 do
					local g = oval(m, "Crystal", Vector3.new(0.22, 0.5, 0.22), CFrame.new(x * 0.98, def.y - 0.3 - d * 0.55, z * 0.98), cr, Enum.Material.Glass)
					g.Transparency = 0.25
				end
			end
			local _ = tier
		end
		for d = 1, 6 do
			oval(m, "Crystal", Vector3.new(0.3, 0.7, 0.3), CFrame.new(0, -6.2 - d * 0.7, 0), cr, Enum.Material.Glass).Transparency = 0.25
		end
	end
	-- glowing stars on wires (hang from the rig)
	function B.hangingstars(m, r)
		local w = dims(r, r.def)
		local rng = Random.new(3)
		r.neon = {}
		local n = math.clamp(math.floor(w / 2.2), 4, 40)
		for i = 0, n - 1 do
			local x = -w / 2 + (i + 0.5) * w / n
			local drop = rng:NextNumber(3, 12)
			part(m, "Wire", Vector3.new(0.04, drop, 0.04), CFrame.new(x, -drop / 2, rng:NextNumber(-0.5, 0.5) * 0), Color3.fromRGB(180, 180, 186))
			local sz = rng:NextNumber(1.2, 2.4)
			local mk = maker(m, "Star", Color3.fromRGB(255, 226, 140), Enum.Material.Neon)
			local up = CFrame.new(x, -drop - sz * 0.5, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			local th = math.pi / 5
			local Ri = sz * 0.4
			for _, p in ipairs(ringPieces(mk, 0, Ri, -th, math.pi * 2 - th, 5, 0.2, up)) do
				table.insert(r.neon, p)
			end
			for k = 0, 4 do
				local cf = up * CFrame.Angles(0, 2 * k * th, 0) * CFrame.new(0, 0, (Ri * math.cos(th) + sz) / 2) * CFrame.Angles(math.pi / 2, 0, 0)
				for _, p in ipairs(trapPanel(mk, cf, 0, 2 * Ri * math.sin(th), sz - Ri * math.cos(th), 0.2)) do
					table.insert(r.neon, p)
				end
			end
		end
	end
	-- a neon heart on a black board
	function B.neonheart(m, r)
		part(m, "Board", Vector3.new(8, 7, 0.3), CFrame.new(0, 3.5 + 0.6, -0.2), Color3.fromRGB(16, 16, 18))
		local col = r.color:Lerp(Color3.fromRGB(255, 60, 130), 0.5)
		local base = CFrame.new(0, 1.6, 0)
		local pts = {}
		for k = 0, 40 do
			local t = k / 40 * math.pi * 2
			local x = 16 * math.sin(t) ^ 3
			local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
			table.insert(pts, base * Vector3.new(x * 0.17, 2.6 + y * 0.17, 0.05))
		end
		r.neon = {}
		for k = 1, #pts - 1 do
			local t = tube(m, pts[k], pts[k + 1], 0.3, col)
			if t then
				t.Material = Enum.Material.Neon
				t.Size = t.Size + Vector3.new(0.25, 0, 0)
				table.insert(r.neon, t)
			end
		end
		for _, x in ipairs({ -3.5, 3.5 }) do
			tube(m, Vector3.new(x, 0, -0.2), Vector3.new(x, 0.9, -0.2), 0.2, Color3.fromRGB(60, 60, 66))
		end
	end
	-- garden gazebo: eight white columns, a railing and a domed roof
	function B.gazebo(m, r)
		local white = Color3.fromRGB(246, 244, 238)
		local R = 7
		r.surfaces = ringPieces(maker(m, "Floor", Color3.fromRGB(200, 196, 188), Enum.Material.WoodPlanks), 0, R + 0.4, math.pi / 8, math.pi * 2 + math.pi / 8, 8, 1.0, CFrame.new(0, 0.5, 0))
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + math.pi / 8
			local x, z = math.sin(a) * R, math.cos(a) * R
			cyl(m, "Column", 9, 0.7, CFrame.new(x, 5.5, z), white, Enum.Material.SmoothPlastic)
			cyl(m, "ColumnBase", 0.4, 1.1, CFrame.new(x, 1.2, z), white)
			cyl(m, "ColumnTop", 0.4, 1.1, CFrame.new(x, 9.8, z), white)
			if k ~= 0 then
				-- a railing between the columns (open at the front)
				local a2 = (k + 1) / 8 * math.pi * 2 + math.pi / 8
				local p1, p2 = Vector3.new(x, 3.2, z), Vector3.new(math.sin(a2) * R, 3.2, math.cos(a2) * R)
				if k ~= 7 then
					tube(m, p1, p2, 0.25, white)
					for b = 1, 5 do
						local q = p1:Lerp(p2, b / 6)
						cyl(m, "Baluster", 2.1, 0.18, CFrame.new(q.X, 2.1, q.Z), white)
					end
				end
			end
		end
		frustum(maker(m, "Eave", white, Enum.Material.SmoothPlastic), R + 1.2, R - 0.5, 0.8, 8, CFrame.Angles(0, math.pi / 8 * 0, 0) * CFrame.new(0, 10, 0), 0.3)
		for i = 0, 4 do
			local a0, a1 = i / 5 * math.pi / 2, (i + 1) / 5 * math.pi / 2
			frustum(maker(m, "Roof", Color3.fromRGB(110, 150, 140), Enum.Material.SmoothPlastic), math.cos(a0) * (R + 0.6), math.cos(a1) * (R + 0.6), (math.sin(a1) - math.sin(a0)) * 4.5, 16, CFrame.new(0, 10.8 + math.sin(a0) * 4.5, 0), 0.3)
		end
		chrome(ball(m, "Finial", 0.9, Vector3.new(0, 15.6, 0), GOLD, Enum.Material.SmoothPlastic))
		r.neon = {}
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			table.insert(r.neon, ball(m, "FairyLight", 0.3, Vector3.new(math.sin(a) * (R + 1.0), 9.8, math.cos(a) * (R + 1.0)), Color3.fromRGB(255, 226, 170), Enum.Material.Neon))
		end
	end
	-- a spiral staircase (decor: a tall white spiral with a gold handrail)
	function B.spiralstair(m, r)
		local white = Color3.fromRGB(246, 246, 248)
		local n, H0 = 22, 15
		cyl(m, "Core", H0 + 1, 1.0, CFrame.new(0, (H0 + 1) / 2, 0), white)
		local prev = nil
		for i = 0, n - 1 do
			local a = i / n * math.pi * 2 * 1.25
			local y = (i + 1) * H0 / n
			ringPieces(maker(m, "Step", white, Enum.Material.SmoothPlastic), 0.4, 4.2, a, a + 0.32, 1, 0.35, CFrame.new(0, y, 0))
			local post = Vector3.new(math.sin(a + 0.16) * 4.0, y + 3.2, math.cos(a + 0.16) * 4.0)
			tube(m, Vector3.new(post.X, y, post.Z), post, 0.12, GOLD)
			if prev then
				chrome(tube(m, prev, post, 0.2, GOLD))
			end
			prev = post
		end
		cyl(m, "Landing", 0.4, 6, CFrame.new(0, H0 + 0.2, 0), white)
	end
	-- circus tent: striped walls, a cone roof, flags and a glowing entrance
	function B.circustent(m, r)
		local R, wallH = 10, 7
		local red, white = Color3.fromRGB(210, 30, 40), Color3.fromRGB(248, 244, 236)
		local n = 16
		local th = math.pi / n
		for i = 0, n - 1 do
			local a = (2 * i + 1) * th
			if i ~= 0 then
				local cf = CFrame.Angles(0, a, 0) * CFrame.new(0, wallH / 2, R * math.cos(th))
				part(m, "Wall", Vector3.new(2 * R * math.sin(th) + 0.02, wallH, 0.3), cf, (i % 2 == 0) and red or white, Enum.Material.Fabric)
			end
		end
		for i = 0, n - 1 do
			local mk = maker(m, "Roof", (i % 2 == 0) and red or white, Enum.Material.Fabric)
			local s, c = math.sin(th), math.cos(th)
			local aB, h = (R + 1) * c, 9
			local L = math.sqrt(h * h + aB * aB)
			local cf = CFrame.Angles(0, (2 * i + 1) * th, 0) * CFrame.new(0, wallH + h / 2, aB / 2) * CFrame.Angles(math.atan2(-aB, h), 0, 0)
			trapPanel(mk, cf, 0, 2 * (R + 1) * s, L, 0.3)
		end
		arcTube(m, "Scallop", CFrame.new(0, wallH - 0.1, 0) * CFrame.Angles(math.pi / 2, 0, 0), R + 0.9, 0, math.pi * 2, 32, 0.5, Color3.fromRGB(250, 200, 60), Enum.Material.Fabric)
		tube(m, Vector3.new(0, wallH + 9, 0), Vector3.new(0, wallH + 12, 0), 0.2, Color3.fromRGB(60, 60, 66))
		part(m, "Flag", Vector3.new(0.08, 1.2, 2.0), CFrame.new(0, wallH + 11.4, 1.0), Color3.fromRGB(250, 200, 60))
		r.neon = {}
		local door = part(m, "Entrance", Vector3.new(2 * R * math.sin(th) * 0.9, wallH - 0.5, 0.2), CFrame.Angles(0, th, 0) * CFrame.new(0, (wallH - 0.5) / 2, R * math.cos(th) - 0.3), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
		door.Transparency = 0.3
		for k = 0, 9 do
			local a = th + (k - 4.5) * 0.06
			table.insert(r.neon, ball(m, "Bulb", 0.35, Vector3.new(math.sin(a) * (R * math.cos(th) + 0.2), wallH + 0.2, math.cos(a) * (R * math.cos(th) + 0.2)), Color3.fromRGB(255, 230, 170), Enum.Material.Neon))
		end
	end
	-- wooden rowing boat with oars (a ballad on the lake)
	function B.rowboat(m, r)
		local hull = Color3.fromRGB(70, 110, 150)
		local wood = Color3.fromRGB(150, 110, 70)
		oval(m, "Hull", Vector3.new(4.2, 2.4, 11), CFrame.new(0, 1.0, 0), hull, Enum.Material.WoodPlanks)
		oval(m, "Inside", Vector3.new(3.4, 1.6, 9.8), CFrame.new(0, 1.75, 0), wood, Enum.Material.WoodPlanks)
		arcTube(m, "Gunwale", CFrame.new(0, 2.15, 0) * CFrame.Angles(math.pi / 2, 0, 0), 2.05, 0, math.pi * 2, 20, 0.25, Color3.fromRGB(240, 236, 226), Enum.Material.Wood)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Gunwale" then
				local c = p.CFrame
				p.CFrame = CFrame.new(c.Position.X, c.Position.Y, c.Position.Z * 2.55) * (c - c.Position)
			end
		end
		for _, z in ipairs({ -2.5, 0.6, 3.2 }) do
			part(m, "Thwart", Vector3.new(3.6, 0.25, 0.9), CFrame.new(0, 1.95, z), wood, Enum.Material.Wood)
		end
		for _, sx in ipairs({ -1, 1 }) do
			tube(m, Vector3.new(sx * 1.6, 2.3, 0.6), Vector3.new(sx * 5.2, 0.4, 1.4), 0.18, wood)
			part(m, "Blade", Vector3.new(0.12, 0.6, 1.4), CFrame.new(sx * 5.3, 0.35, 1.45) * CFrame.Angles(0, 0, sx * 0.5), wood, Enum.Material.Wood)
		end
		local water = cyl(m, "Water", 0.1, 16, CFrame.new(0, 0.05, 0), Color3.fromRGB(40, 90, 140), Enum.Material.Glass)
		water.Transparency = 0.35
		water.Reflectance = 0.3
	end
	-- a broken marble column (with a fallen piece next to it)
	function B.brokencolumn(m, r)
		local marble = Color3.fromRGB(232, 230, 226)
		part(m, "Plinth", Vector3.new(4.2, 1.0, 4.2), CFrame.new(0, 0.5, 0), marble, Enum.Material.Marble)
		cyl(m, "Base", 0.6, 3.6, CFrame.new(0, 1.3, 0), marble, Enum.Material.Marble)
		cyl(m, "Shaft", 7, 3.0, CFrame.new(0, 5.1, 0), marble, Enum.Material.Marble)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			part(m, "Flute", Vector3.new(0.3, 7, 0.12), CFrame.new(math.sin(a) * 1.48, 5.1, math.cos(a) * 1.48) * CFrame.Angles(0, a, 0), Color3.fromRGB(210, 208, 204), Enum.Material.Marble)
		end
		New("WedgePart", { Name = "Break", Size = Vector3.new(3.0, 1.2, 3.0), CFrame = CFrame.new(0, 9.2, 0), Color = marble, Material = Enum.Material.Marble, Anchored = true, CanCollide = false, CanTouch = false, CastShadow = false, Parent = m })
		local fallen = CFrame.new(3.6, 1.5, 2.2) * CFrame.Angles(0, 0.6, math.pi / 2)
		cyl(m, "Fallen", 4, 3.0, fallen, marble, Enum.Material.Marble)
		cyl(m, "Capital", 1.0, 3.8, fallen * CFrame.new(0, 2.3, 0), marble, Enum.Material.Marble)
	end
	-- four-poster bed with curtains
	function B.bed(m, r)
		local wood = Color3.fromRGB(96, 60, 40)
		local sheet = Color3.fromRGB(246, 242, 236)
		local cover = r.color:Lerp(Color3.fromRGB(150, 40, 70), 0.6)
		part(m, "Frame", Vector3.new(7.4, 1.2, 9.4), CFrame.new(0, 1.2, 0), wood, Enum.Material.Wood)
		part(m, "Mattress", Vector3.new(7.0, 1.2, 9.0), CFrame.new(0, 2.4, 0), sheet, Enum.Material.Fabric)
		part(m, "Cover", Vector3.new(7.2, 0.4, 6.2), CFrame.new(0, 3.1, 1.5), cover, Enum.Material.Fabric)
		part(m, "CoverSide", Vector3.new(7.25, 1.4, 6.2), CFrame.new(0, 2.5, 1.5), cover, Enum.Material.Fabric).Size = Vector3.new(7.25, 1.4, 6.2)
		for _, x in ipairs({ -1.8, 1.8 }) do
			oval(m, "Pillow", Vector3.new(2.8, 0.9, 1.6), CFrame.new(x, 3.4, -3.4), sheet, Enum.Material.Fabric)
		end
		part(m, "Headboard", Vector3.new(7.4, 4.0, 0.5), CFrame.new(0, 3.8, -4.5), wood, Enum.Material.Wood)
		for _, x in ipairs({ -3.6, 3.6 }) do
			for _, z in ipairs({ -4.6, 4.6 }) do
				cyl(m, "Post", 10, 0.45, CFrame.new(x, 5, z), wood, Enum.Material.Wood)
				ball(m, "Finial", 0.7, Vector3.new(x, 10.2, z), wood, Enum.Material.Wood)
			end
		end
		for _, z in ipairs({ -4.6, 4.6 }) do
			part(m, "Canopy", Vector3.new(7.6, 0.4, 0.4), CFrame.new(0, 9.8, z), wood, Enum.Material.Wood)
		end
		for _, x in ipairs({ -3.6, 3.6 }) do
			part(m, "Canopy", Vector3.new(0.4, 0.4, 9.6), CFrame.new(x, 9.8, 0), wood, Enum.Material.Wood)
			-- curtains tied back to the posts
			for _, z in ipairs({ -4.1, 4.1 }) do
				oval(m, "Drape", Vector3.new(0.5, 8.4, 1.3), CFrame.new(x, 5.6, z), cover:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Fabric)
			end
		end
		part(m, "CanopyCloth", Vector3.new(7.4, 0.1, 9.4), CFrame.new(0, 10.0, 0), cover:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.Fabric)
	end

	-- flower garden: a bed of soil with roses on stems and leaves (the flowers look up and to the front)
	function B.flowers(m, r)
		local rng = Random.new(21)
		part(m, "Edge", Vector3.new(10.4, 1, 6.4), CFrame.new(0, 0.5, 0), Color3.fromRGB(150, 130, 110), Enum.Material.Brick)
		part(m, "Bed", Vector3.new(10, 1.1, 6), CFrame.new(0, 0.55, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Ground)
		local greens = { Color3.fromRGB(56, 118, 56), Color3.fromRGB(70, 136, 62), Color3.fromRGB(46, 100, 50) }
		for i = 0, 20 do
			local x, z = -4.1 + (i % 7) * 1.37 + rng:NextNumber(-0.3, 0.3), -2.0 + math.floor(i / 7) * 2.0 + rng:NextNumber(-0.3, 0.3)
			local h = rng:NextNumber(1.2, 2.4)
			part(m, "Stem", Vector3.new(0.12, h, 0.12), CFrame.new(x, 1.1 + h / 2, z), Color3.fromRGB(50, 120, 50))
			for k = 0, 1 do
				leaf(m, CFrame.new(x + (k == 0 and 0.35 or -0.35), 1.3 + h * (0.3 + k * 0.25), z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), (k == 0) and -1.0 or 1.0), 0.9, greens[rng:NextInteger(1, 3)])
			end
			rose(m, CFrame.new(x, 1.2 + h, z) * CFrame.Angles(-1.1, rng:NextNumber(-0.4, 0.4), 0), rng:NextNumber(0.9, 1.3), ROSES[rng:NextInteger(1, #ROSES)])
		end
	end

end

return Models
