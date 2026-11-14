-- Builds the inside of a venue around the stage and fills it with a crowd.
--   arena:   oval bowl with lower and upper tier, sections with stairs, concourse, suites, LED ribbon, roof rig,
--            black drapes behind an end stage (or a full bowl around a center stage)
--   stadium: football stadium with pitch and floor cover, two tiers all around, roof with floodlights
--   theatre: balconies and boxes, curtains framing the stage;  club: bar and brick walls;  amphi: open-air half bowl
-- Every venue gets crowd barriers that follow the stage shape (photo pit with security in front).
-- The number of visible people matches how many tickets were sold (scaled down for performance).
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local Stage3D = require(Root.Client.Stage3D)
local People = require(Root.Client.People)

local New = UI.New
local Venue = {}

Venue.maxFigures = 1100

-- crowd detail setting (main menu > settings)
function Venue.setDetail(level)
	Venue.maxFigures = (level == "Low") and 400 or ((level == "Medium") and 750 or 1100)
end

local LOOKS = {
	club = { w = 90, d = 60, roof = 46 },
	theatre = { w = 110, d = 80, roof = 62 },
	arena = { w = 150, d = 120, roof = 104 },
	amphi = { w = 150, d = 90, roof = nil },
	stadium = { w = 250, d = 300, roof = nil },
}
Venue.LOOKS = LOOKS

local SHIRTS = {
	Color3.fromRGB(20, 20, 24), Color3.fromRGB(230, 230, 235), Color3.fromRGB(200, 40, 60),
	Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 200, 50), Color3.fromRGB(60, 160, 90),
	Color3.fromRGB(150, 60, 200), Color3.fromRGB(255, 120, 170), Color3.fromRGB(90, 90, 100),
}
local PANTS = { Color3.fromRGB(30, 34, 50), Color3.fromRGB(20, 20, 24), Color3.fromRGB(60, 70, 100), Color3.fromRGB(110, 90, 70), Color3.fromRGB(200, 200, 205) }
local HAIRS = { Color3.fromRGB(30, 24, 20), Color3.fromRGB(90, 60, 30), Color3.fromRGB(220, 190, 120), Color3.fromRGB(160, 60, 40), Color3.fromRGB(20, 20, 20) }

local FLOOR_START = -10
local METAL = Color3.fromRGB(90, 92, 100)
local DARK = Color3.fromRGB(16, 16, 22)
local DRAPE = Color3.fromRGB(12, 12, 14)

local function blk(folder, name, size, cf, color, material)
	return Stage3D.block(folder, name, size, cf, color, material)
end

-- stage height at (x, z); one RaycastParams per build (thousands of probes)
local probe = nil
local function sy(x, z)
	if not probe then
		return (Stage3D.surfaceY(x, z))
	end
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), probe)
	return hit and hit.Position.Y or 0
end

------------------------------------------------------------------ stands along a path
-- path: points on the floor edge (Vector3, y ignored). Rows go outwards and upwards.
-- returns the outer offset; adds crowd slots for every row
local function stands(folder, path, closed, center, o, slots, rankBase)
	local n = #path
	local segs = closed and n or n - 1
	for s = 1, segs do
		local a, b = path[s], path[s % n + 1]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = dir.Magnitude
		if len > 1 then
			dir = dir.Unit
			local nrm = Vector3.new(dir.Z, 0, -dir.X)
			local mid = (a + b) / 2
			if (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(center.X, 0, center.Z)):Dot(nrm) < 0 then
				nrm = -nrm
			end
			local yaw = math.atan2(dir.X, dir.Z)
			for r = 0, o.rows - 1 do
				local off = o.offset + r * o.depth
				local top = o.base + (r + 1) * o.step
				local L = len + off * (o.grow or 0.8)
				local c = Vector3.new(mid.X, 0, mid.Z) + nrm * (off + o.depth / 2)
				local col = (r % 2 == 0) and o.color or o.color:Lerp(Color3.new(0, 0, 0), 0.18)
				local h = math.min(top, o.step * 3 + (o.base > 0 and 2 or top))
				local p = blk(folder, "Tier", Vector3.new(L, h, o.depth), CFrame.new(c.X, top - h / 2, c.Z) * CFrame.Angles(0, yaw + math.pi / 2, 0), col, Enum.Material.Fabric)
				p.CanCollide = false
				-- seats for fans (skip the aisles)
				if slots then
					local k = -L / 2 + 2
					local i = 0
					while k < L / 2 - 2 do
						i = i + 1
						local pos = c + dir * k + nrm * (math.random() - 0.5) * 1.2
						if i % 8 ~= 0 and (not o.killZ or pos.Z > o.killZ) then
							table.insert(slots, { pos = Vector3.new(pos.X, top, pos.Z), rank = rankBase + r * 0.06 + math.random() * 0.3, face = -nrm })
						end
						k = k + 3.3
					end
				end
			end
			-- section stairs (light strips up the slope)
			local tierW = o.rows * o.depth
			local nAisles = math.max(1, math.floor(len / 26))
			for k = 1, nAisles do
				local u = -len / 2 + k * len / (nAisles + 1)
				local p0 = Vector3.new(mid.X, o.base + o.step, mid.Z) + dir * u + nrm * o.offset
				local p1 = p0 + nrm * tierW + Vector3.new(0, o.rows * o.step - o.step, 0)
				local L2 = (p1 - p0).Magnitude
				local st = blk(folder, "Stairs", Vector3.new(2.2, 0.3, L2), CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 0.3, 0), p1 + Vector3.new(0, 0.3, 0)), Color3.fromRGB(120, 122, 130), Enum.Material.Concrete)
				st.CanCollide = false
			end
		end
	end
	return o.offset + o.rows * o.depth, o.base + o.rows * o.step
end

-- a band (wall, LED ribbon, roof edge...) along the same path at an offset
local function band(folder, path, closed, center, offset, y, h, thick, color, material, name)
	local n = #path
	local segs = closed and n or n - 1
	local parts = {}
	for s = 1, segs do
		local a, b = path[s], path[s % n + 1]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = dir.Magnitude
		if len > 1 then
			dir = dir.Unit
			local nrm = Vector3.new(dir.Z, 0, -dir.X)
			local mid = (a + b) / 2
			if (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(center.X, 0, center.Z)):Dot(nrm) < 0 then
				nrm = -nrm
			end
			local c = Vector3.new(mid.X, y, mid.Z) + nrm * offset
			local p = blk(folder, name or "Band", Vector3.new(len + offset * 0.8, h, thick), CFrame.new(c) * CFrame.Angles(0, math.atan2(dir.X, dir.Z) + math.pi / 2, 0), color, material)
			p.CanCollide = false
			table.insert(parts, p)
		end
	end
	return parts
end

-- rounded rectangle path around (cx, cz), half sizes hx, hz, corner cut c. sides = "all" | "u" (open towards -z)
local function roundRect(cx, cz, hx, hz, c, sides)
	local pts = {
		Vector3.new(cx - hx, 0, cz - hz + c), Vector3.new(cx - hx, 0, cz + hz - c), Vector3.new(cx - hx + c * 0.3, 0, cz + hz - c * 0.3),
		Vector3.new(cx - hx + c, 0, cz + hz), Vector3.new(cx + hx - c, 0, cz + hz), Vector3.new(cx + hx - c * 0.3, 0, cz + hz - c * 0.3),
		Vector3.new(cx + hx, 0, cz + hz - c), Vector3.new(cx + hx, 0, cz - hz + c),
	}
	if sides == "all" then
		table.insert(pts, Vector3.new(cx + hx - c * 0.3, 0, cz - hz + c * 0.3))
		table.insert(pts, Vector3.new(cx + hx - c, 0, cz - hz))
		table.insert(pts, Vector3.new(cx - hx + c, 0, cz - hz))
		table.insert(pts, Vector3.new(cx - hx + c * 0.3, 0, cz - hz + c * 0.3))
	end
	return pts
end

------------------------------------------------------------------ crowd barriers that follow the stage shape
local function barriers(folder, x0, x1, z0, z1, blocked)
	local G = 4
	local nx, nz = math.ceil((x1 - x0) / G), math.ceil((z1 - z0) / G)
	local stage = {}
	local function key(i, j)
		return i * 1000 + j
	end
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local cx, cz = x0 + (i + 0.5) * G, z0 + (j + 0.5) * G
			if sy(cx, cz) > 0.5 then
				stage[key(i, j)] = true
			end
		end
	end
	-- photo pit: 2 cells (8 studs) around the stage
	local pit = {}
	for k in pairs(stage) do
		local i, j = math.floor(k / 1000), k % 1000
		for di = -2, 2 do
			for dj = -2, 2 do
				local nk = key(i + di, j + dj)
				if i + di >= 0 and j + dj >= 0 and i + di < nx and j + dj < nz and not stage[nk] then
					pit[nk] = true
				end
			end
		end
	end
	local function crowdCell(i, j)
		if i < 0 or j < 0 or i >= nx or j >= nz then
			return false
		end
		local k = key(i, j)
		return not stage[k] and not pit[k] and not (blocked and blocked(x0 + (i + 0.5) * G, z0 + (j + 0.5) * G))
	end
	-- barrier edges between pit cells and crowd cells, merged into straight runs
	local runs = {}
	for k in pairs(pit) do
		local i, j = math.floor(k / 1000), k % 1000
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			if crowdCell(i + d[1], j + d[2]) then
				table.insert(runs, { i = i, j = j, d = d })
			end
		end
	end
	local barrierColor = Color3.fromRGB(150, 155, 165)
	local staffPos = {}
	for idx, e in ipairs(runs) do
		local cx, cz = x0 + (e.i + 0.5) * G, z0 + (e.j + 0.5) * G
		local ex, ez = cx + e.d[1] * G / 2, cz + e.d[2] * G / 2
		local along = (e.d[1] ~= 0) and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
		local size = (e.d[1] ~= 0) and Vector3.new(0.35, 3.2, G) or Vector3.new(G, 3.2, 0.35)
		local panel = blk(folder, "Barrier", size, CFrame.new(ex, 1.8, ez), barrierColor, Enum.Material.DiamondPlate)
		panel.CanCollide = false
		local rail = blk(folder, "BarrierRail", size + Vector3.new(0.15, -2.9, 0.15), CFrame.new(ex, 3.5, ez), Color3.fromRGB(190, 195, 205), Enum.Material.Metal)
		rail.CanCollide = false
		local foot = blk(folder, "BarrierFoot", (e.d[1] ~= 0) and Vector3.new(2.4, 0.2, G) or Vector3.new(G, 0.2, 2.4), CFrame.new(ex + e.d[1] * 1.2, 0.25, ez + e.d[2] * 1.2), barrierColor, Enum.Material.DiamondPlate)
		foot.CanCollide = false
		local _ = along
		if idx % 7 == 0 then
			table.insert(staffPos, Vector3.new(cx - e.d[1] * 1.2, 0.2, cz - e.d[2] * 1.2))
		end
	end
	return function(x, z)
		local i, j = math.floor((x - x0) / G), math.floor((z - z0) / G)
		return crowdCell(i, j)
	end, staffPos
end

------------------------------------------------------------------ one fan: legs, body, round head, hair or cap
local function fan(folder, info, pos, yaw, shirt, raise)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local ph = math.random() * 6.28
	local function add(name, size, off, color, material, shape)
		local p = New("Part", {
			Name = name,
			Size = size,
			Color = color,
			Material = material or Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			CFrame = base * off,
			Parent = folder,
		})
		if shape then
			p.Shape = shape
		end
		table.insert(info.parts, p)
		table.insert(info.base, p.CFrame)
		table.insert(info.phase, ph)
		return p
	end
	add("FanLegs", Vector3.new(1.4, 1.7, 0.8), CFrame.new(0, 0.85, 0), PANTS[math.random(1, #PANTS)])
	add("Fan", Vector3.new(1.7, 1.7, 0.95), CFrame.new(0, 2.55, 0), shirt)
	local head = add("FanHead", Vector3.new(1.15, 1.2, 1.15), CFrame.new(0, 3.95, 0), People.SKINS[math.random(1, #People.SKINS)])
	New("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1, 1, 1), Parent = head })
	if math.random() < 0.25 then
		add("FanCap", Vector3.new(1.25, 0.35, 1.25), CFrame.new(0, 4.55, 0), SHIRTS[math.random(1, #SHIRTS)])
	else
		add("FanHair", Vector3.new(1.22, 0.4, 1.22), CFrame.new(0, 4.5, 0.08), HAIRS[math.random(1, #HAIRS)])
	end
	if raise then
		add("FanArm", Vector3.new(0.45, 1.8, 0.45), CFrame.new(0.95, 4.1, -0.1) * CFrame.Angles(0, 0, -0.25), shirt)
	end
	return ph
end

------------------------------------------------------------------ build
-- look: key of LOOKS, fill: 0..1, merchColor: artist colour for some shirts
-- opts: { layout = "end" | "center", empty = bool, noRoof = bool, standingColor = Color3, wristbands = bool }
function Venue.build(lookKey, fill, merchColor, opts)
	opts = opts or {}
	local center = opts.layout == "center"
	local L = LOOKS[lookKey] or LOOKS.arena
	local folder = New("Folder", { Name = "VenueBuild", Parent = Stage3D.venueFolder })
	probe = RaycastParams.new()
	probe.FilterType = Enum.RaycastFilterType.Include
	probe.FilterDescendantsInstances = Stage3D.surfaceParts()
	local info = { folder = folder, look = L, parts = {}, base = {}, phase = {}, phones = {}, bands = {}, slots = 0 }
	local slots = {}
	local halfW, z0, z1
	if center then
		halfW = math.max(L.w, L.d) / 2
		z0, z1 = -halfW, halfW
	else
		halfW = L.w / 2
		z0, z1 = FLOOR_START, FLOOR_START + L.d + 22
	end
	local cz = (z0 + z1) / 2
	local ctr = Vector3.new(0, 0, cz)
	local seatColors = { club = Color3.fromRGB(60, 40, 40), theatre = Color3.fromRGB(150, 30, 40), arena = Color3.fromRGB(32, 60, 140), amphi = Color3.fromRGB(120, 116, 104), stadium = Color3.fromRGB(170, 40, 40) }
	local seat = seatColors[lookKey] or seatColors.arena
	local accent = merchColor or Color3.fromRGB(108, 99, 255)
	local roofY = L.roof or 0
	local outer, wallH = halfW + 10, (L.roof or 40)
	-- behind an end stage: room for the deepest stage of the class
	local zBack = (lookKey == "stadium") and -80 or -56

	-- floor
	local floor = blk(folder, "Floor", Vector3.new(halfW * 2, 0.2, z1 - z0), CFrame.new(0, 0.05, cz), Color3.fromRGB(28, 28, 34), Enum.Material.Concrete)
	floor.CanCollide = false
	if lookKey == "stadium" then
		local pitch = blk(folder, "Pitch", Vector3.new(halfW * 2 + 30, 0.18, z1 - z0 + 30), CFrame.new(0, 0.02, cz), Color3.fromRGB(34, 96, 44), Enum.Material.Grass)
		pitch.CanCollide = false
		floor.Color = Color3.fromRGB(70, 74, 82) -- floor protection tiles over the grass
		floor.Material = Enum.Material.DiamondPlate
		floor.Size = Vector3.new(halfW * 2 - 30, 0.2, z1 - z0 - 20)
		for _, x in ipairs({ -halfW - 8, halfW + 8 }) do
			blk(folder, "PitchLine", Vector3.new(0.4, 0.06, z1 - z0 + 10), CFrame.new(x, 0.13, cz), Color3.new(1, 1, 1)).CanCollide = false
		end
	end
	if opts.standingColor then
		floor.Color = opts.standingColor
	end

	-- mixing desk (FOH) in the middle of the floor at end stages
	local foh = nil
	if not center and not opts.empty and (L.d or 0) >= 70 then
		local fz = z0 + (z1 - z0) * 0.6
		foh = { x = 0, z = fz, w = 14, d = 9 }
		blk(folder, "FOHRiser", Vector3.new(14, 1.2, 9), CFrame.new(0, 0.6, fz), Color3.fromRGB(30, 30, 34))
		blk(folder, "FOHDesk", Vector3.new(10, 1.6, 2.4), CFrame.new(0, 2, fz - 1.5), Color3.fromRGB(22, 22, 26))
		blk(folder, "FOHFaders", Vector3.new(9.4, 0.15, 1.8), CFrame.new(0, 2.85, fz - 1.5), Color3.fromRGB(60, 120, 200), Enum.Material.Neon)
		blk(folder, "FOHRoof", Vector3.new(15, 0.4, 10), CFrame.new(0, 9, fz), Color3.fromRGB(18, 18, 22))
		for _, bx in ipairs({ -7.2, 7.2 }) do
			blk(folder, "FOHBarrier", Vector3.new(0.35, 3.2, 11), CFrame.new(bx, 1.8, fz), Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate)
		end
		for _, bz in ipairs({ -5.5, 5.5 }) do
			blk(folder, "FOHBarrier", Vector3.new(14.4, 3.2, 0.35), CFrame.new(0, 1.8, fz + bz), Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate)
		end
		for _, px in ipairs({ -6.8, 6.8 }) do
			for _, pz in ipairs({ -4.3, 4.3 }) do
				blk(folder, "FOHPole", Vector3.new(0.4, 8, 0.4), CFrame.new(px, 4.8, fz + pz), METAL, Enum.Material.Metal)
			end
		end
	end
	local function blocked(x, z)
		if foh and math.abs(x - foh.x) < foh.w / 2 + 1.5 and math.abs(z - foh.z) < foh.d / 2 + 1.5 then
			return true
		end
		for _, p in ipairs(opts.pits or {}) do
			local lp = p.cf:PointToObjectSpace(Vector3.new(x, p.cf.Position.Y, z))
			if math.abs(lp.X) < p.w / 2 - 0.8 and math.abs(lp.Z) < p.d / 2 - 0.8 then
				return true
			end
		end
		return false
	end

	-- crowd barriers + photo pit around the stage (any shape)
	local crowdOk, staff = function(x, z)
		return not blocked(x, z)
	end, {}
	if not opts.empty then
		crowdOk, staff = barriers(folder, -halfW, halfW, z0 - (center and 0 or 40), z1, blocked)
	end

	-- floor slots (standing crowd)
	if not opts.empty then
		local sp = 3.2
		for z = z0 + 2, z1 - 1, sp do
			for x = -halfW + 2, halfW - 2, sp do
				local px, pz = x + (math.random() - 0.5) * 1.2, z + (math.random() - 0.5) * 1.2
				local nearBar = lookKey == "club" and px < -halfW + 9
				if not nearBar and crowdOk(px, pz) then
					local rank = center and (math.sqrt(px * px + pz * pz) / halfW) or ((pz - z0) / (z1 - z0))
					table.insert(slots, { pos = Vector3.new(px, 0.2, pz), rank = rank + math.random() * 0.3 })
				end
			end
		end
	end
	local slotList = (not opts.empty) and slots or nil

	------------------------------------------------------------------ venue types
	if lookKey == "arena" or lookKey == "stadium" then
		local big = lookKey == "stadium"
		local c = big and 40 or 26
		-- the bowl goes all the way round; at an end stage it also runs behind the stage (those seats stay empty, draped)
		local bz0 = center and (z0 - 2) or zBack
		local bcz = (bz0 + z1 + 2) / 2
		local path = roundRect(0, bcz, halfW + 2, (z1 + 2 - bz0) / 2, c, "all")
		ctr = Vector3.new(0, 0, bcz)
		local killZ = (not center) and 2 or nil
		local lower = big and { rows = 12, depth = 4.6, step = 2.4 } or { rows = 8, depth = 5.2, step = 3.0 }
		lower.offset, lower.base, lower.color, lower.killZ = 1, 0.4, seat, killZ
		local lOut, lTop = stands(folder, path, true, ctr, lower, slotList, 0.55)
		-- concourse with exit tunnels (green signs), suites with lit windows, LED ribbon
		band(folder, path, true, ctr, lOut + 1.5, lTop + 1, 2, 3, DARK, Enum.Material.Concrete, "Concourse")
		for _, p in ipairs(band(folder, path, true, ctr, lOut + 0.4, lTop + 2.6, 1.6, 0.4, accent, Enum.Material.Neon, "LEDRibbon")) do
			table.insert(info.bands, { part = p, x = p.Position.X, z = p.Position.Z, ribbon = true })
		end
		band(folder, path, true, ctr, lOut + 2.8, lTop + 6.5, 6, 1, Color3.fromRGB(30, 30, 38), Enum.Material.Glass, "Suites")
		band(folder, path, true, ctr, lOut + 2.2, lTop + 6.5, 2, 0.3, Color3.fromRGB(255, 214, 150), Enum.Material.Neon, "SuiteWindows")
		local exits = band(folder, path, true, ctr, 0.3, lower.base + lower.step * 3, 0.9, 0.2, Color3.fromRGB(40, 220, 90), Enum.Material.Neon, "ExitSign")
		for _, e in ipairs(exits) do
			e.Size = Vector3.new(3, 0.9, 0.2)
		end
		local upper = big and { rows = 14, depth = 4.4, step = 3.2 } or { rows = 7, depth = 5, step = 3.8 }
		upper.offset, upper.base, upper.color, upper.killZ = lOut + 5, lTop + 9.5, seat:Lerp(Color3.new(0, 0, 0), 0.1), killZ
		local uOut, uTop = stands(folder, path, true, ctr, upper, slotList, 1.1)
		outer = halfW + uOut + 4
		wallH = uTop + 8
		band(folder, path, true, ctr, uOut + 1, wallH / 2, wallH, 2, DARK, Enum.Material.Concrete, "OuterWall")
		if big then
			-- roof canopy all around with a row of floodlights
			band(folder, path, true, ctr, uOut - 18, uTop + 14, 1.5, 44, Color3.fromRGB(200, 205, 215), Enum.Material.Metal, "Canopy")
			band(folder, path, true, ctr, uOut - 38, uTop + 12.6, 1, 1, Color3.fromRGB(255, 250, 230), Enum.Material.Neon, "Floodlights")
			for _, x in ipairs({ -1, 1 }) do
				local sc = blk(folder, "CornerScreen", Vector3.new(36, 20, 1), CFrame.new(x * (halfW - 10), uTop + 2, z1 + 30) * CFrame.Angles(0, x * 0.6, 0), Color3.fromRGB(20, 40, 90), Enum.Material.Neon)
				sc.CanCollide = false
			end
			roofY = uTop + 16
		else
			-- roof, rig catwalks, centre-hung scoreboard
			roofY = math.max(roofY, wallH + 18)
			local roof = blk(folder, "Roof", Vector3.new(outer * 2, 2, (z1 + 2 - bz0) + uOut * 2 + 10), CFrame.new(0, roofY, bcz), Color3.fromRGB(14, 14, 20))
			roof.CanCollide = false
			if opts.noRoof then
				roof:Destroy()
			end
			for k = -3, 3 do
				blk(folder, "Catwalk", Vector3.new(outer * 2, 1.2, 2), CFrame.new(0, roofY - 6, cz + k * 30), METAL, Enum.Material.DiamondPlate).CanCollide = false
			end
			for k = -2, 2 do
				blk(folder, "Catwalk", Vector3.new(2, 1.2, (z1 - z0) + 40), CFrame.new(k * 40, roofY - 6, cz), METAL, Enum.Material.DiamondPlate).CanCollide = false
			end
			local sbz = center and (z1 - 30) or (z0 + (z1 - z0) * 0.55)
			local sby = roofY - 20
			blk(folder, "Scoreboard", Vector3.new(18, 10, 18), CFrame.new(0, sby, sbz), Color3.fromRGB(20, 20, 24)).CanCollide = false
			for _, f in ipairs({ { 0, 9.1 }, { 0, -9.1 }, { 9.1, 0 }, { -9.1, 0 } }) do
				local sz = (f[1] == 0) and Vector3.new(16, 8, 0.2) or Vector3.new(0.2, 8, 16)
				blk(folder, "ScoreScreen", sz, CFrame.new(f[1], sby, sbz + f[2]), Color3.fromRGB(40, 70, 140), Enum.Material.Neon).CanCollide = false
			end
			blk(folder, "ScoreCable", Vector3.new(0.3, roofY - sby - 5, 0.3), CFrame.new(0, (sby + 5 + roofY) / 2, sbz), METAL, Enum.Material.Metal).CanCollide = false
		end
		if not center then
			-- black drapes hang from the roof in front of the seats behind the stage and the sections next to it
			local dh = big and (uTop + 6) or (roofY - 4)
			blk(folder, "BackDrape", Vector3.new(halfW * 2 + 4, dh, 1), CFrame.new(0, dh / 2, zBack + 1), DRAPE, Enum.Material.Fabric).CanCollide = false
			for _, x in ipairs({ -1, 1 }) do
				blk(folder, "SideDrape", Vector3.new(1, dh, 2 - zBack), CFrame.new(x * (halfW + 1), dh / 2, (zBack + 2) / 2), DRAPE, Enum.Material.Fabric).CanCollide = false
				blk(folder, "SideDrape", Vector3.new(outer - halfW, dh, 1), CFrame.new(x * (halfW + (outer - halfW) / 2), dh / 2, 2), DRAPE, Enum.Material.Fabric).CanCollide = false
			end
			blk(folder, "BackstageFloor", Vector3.new(halfW * 2, 0.2, 2 - zBack), CFrame.new(0, 0.04, (zBack + 2) / 2), Color3.fromRGB(20, 20, 24), Enum.Material.Concrete).CanCollide = false
		end
	elseif lookKey == "theatre" then
		-- balconies (U shape) with gold lips, boxes at the sides, curtains framing the stage
		local path = { Vector3.new(-halfW, 0, z1 - 40), Vector3.new(-halfW, 0, z1), Vector3.new(halfW, 0, z1), Vector3.new(halfW, 0, z1 - 40) }
		local o1 = { rows = 5, depth = 5, step = 2.6, offset = 1, base = 0.4, color = seat }
		local out1, top1 = stands(folder, path, false, ctr, o1, slotList, 0.7)
		for i, lvl in ipairs({ 14, 26 }) do
			local o = { rows = 4, depth = 5, step = 2.6, offset = -12 + i * 2, base = lvl, color = seat }
			stands(folder, path, false, ctr, o, slotList, 0.9 + i * 0.2)
			band(folder, path, false, ctr, -12 + i * 2, lvl - 0.5, 3, 1, Color3.fromRGB(120, 24, 32), Enum.Material.Fabric, "BalconyLip")
			band(folder, path, false, ctr, -12.6 + i * 2, lvl + 1.1, 0.4, 1.2, Color3.fromRGB(210, 170, 70), Enum.Material.Metal, "BalconyGold")
		end
		outer = halfW + out1 + 6
		wallH = L.roof
		for _, x in ipairs({ -1, 1 }) do
			blk(folder, "Wall", Vector3.new(2, wallH, z1 - z0 + 100), CFrame.new(x * (halfW + 3), wallH / 2, cz - 30), Color3.fromRGB(90, 20, 28), Enum.Material.Fabric).CanCollide = false
			for k = 0, 2 do
				local y = 12 + k * 11
				local bz = 10
				blk(folder, "Box", Vector3.new(6, 1.5, 12), CFrame.new(x * (halfW - 1), y, bz), Color3.fromRGB(120, 24, 32), Enum.Material.Fabric).CanCollide = false
				blk(folder, "BoxGold", Vector3.new(6.2, 0.4, 12.2), CFrame.new(x * (halfW - 1), y + 0.9, bz), Color3.fromRGB(210, 170, 70), Enum.Material.Metal).CanCollide = false
				blk(folder, "BoxLight", Vector3.new(0.3, 2, 10), CFrame.new(x * (halfW + 1.5), y + 4, bz), Color3.fromRGB(255, 210, 140), Enum.Material.Neon).CanCollide = false
			end
			blk(folder, "StageCurtain", Vector3.new(14, wallH - 6, 2), CFrame.new(x * (halfW - 6), (wallH - 6) / 2, -30), Color3.fromRGB(150, 18, 30), Enum.Material.Fabric).CanCollide = false
		end
		blk(folder, "Valance", Vector3.new(halfW * 2, 10, 2), CFrame.new(0, wallH - 10, -30), Color3.fromRGB(150, 18, 30), Enum.Material.Fabric).CanCollide = false
		blk(folder, "ProsceniumGold", Vector3.new(halfW * 2, 1, 2.2), CFrame.new(0, wallH - 15.5, -30), Color3.fromRGB(210, 170, 70), Enum.Material.Metal).CanCollide = false
		blk(folder, "Backdrop", Vector3.new(halfW * 2, wallH, 1), CFrame.new(0, wallH / 2, -46), DRAPE, Enum.Material.Fabric).CanCollide = false
		blk(folder, "BackWall", Vector3.new(halfW * 2 + 6, wallH, 2), CFrame.new(0, wallH / 2, z1 + out1 + 4), Color3.fromRGB(70, 18, 24), Enum.Material.Fabric).CanCollide = false
		if not opts.noRoof then
			blk(folder, "Ceiling", Vector3.new(halfW * 2 + 8, 2, z1 - z0 + 110), CFrame.new(0, wallH, cz - 30), Color3.fromRGB(60, 30, 30)).CanCollide = false
			for k = 0, 5 do
				local a = k * math.pi / 3
				local b = blk(folder, "Chandelier", Vector3.new(2, 2, 2), CFrame.new(math.cos(a) * 3, wallH - 9, cz + 10 + math.sin(a) * 3), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
				b.Shape = Enum.PartType.Ball
				b.CanCollide = false
			end
		end
	elseif lookKey == "club" then
		local brick = Color3.fromRGB(70, 40, 34)
		wallH = L.roof
		for _, x in ipairs({ -1, 1 }) do
			blk(folder, "Wall", Vector3.new(2, wallH, z1 - z0 + 70), CFrame.new(x * (halfW + 2), wallH / 2, cz - 20), brick, Enum.Material.Brick).CanCollide = false
			blk(folder, "WallSpeaker", Vector3.new(3, 4.5, 3), CFrame.new(x * (halfW - 2), 22, -6), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric).CanCollide = false
		end
		blk(folder, "BackWall", Vector3.new(halfW * 2 + 4, wallH, 2), CFrame.new(0, wallH / 2, z1 + 2), brick, Enum.Material.Brick).CanCollide = false
		blk(folder, "Backdrop", Vector3.new(halfW * 2, wallH, 1), CFrame.new(0, wallH / 2, z0 - 40), DRAPE, Enum.Material.Fabric).CanCollide = false
		local neon = blk(folder, "ClubNeon", Vector3.new(30, 1, 0.3), CFrame.new(0, wallH - 8, z1 + 0.8), Color3.fromRGB(255, 60, 170), Enum.Material.Neon)
		neon.CanCollide = false
		-- bar along the side wall
		blk(folder, "Bar", Vector3.new(4, 4, 26), CFrame.new(-halfW + 4, 2, z0 + 30), Color3.fromRGB(40, 26, 20), Enum.Material.WoodPlanks).CanCollide = false
		blk(folder, "BarTop", Vector3.new(4.4, 0.3, 26.4), CFrame.new(-halfW + 4, 4.15, z0 + 30), Color3.fromRGB(20, 20, 24), Enum.Material.Marble).CanCollide = false
		blk(folder, "BarNeon", Vector3.new(0.2, 0.3, 26), CFrame.new(-halfW + 6.1, 3.4, z0 + 30), Color3.fromRGB(255, 60, 170), Enum.Material.Neon).CanCollide = false
		blk(folder, "Shelf", Vector3.new(1, 6, 22), CFrame.new(-halfW + 1.6, 7, z0 + 30), Color3.fromRGB(30, 22, 18), Enum.Material.WoodPlanks).CanCollide = false
		for i = 0, 9 do
			blk(folder, "Bottle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(-halfW + 1.8, 9.2, z0 + 21 + i * 2), Color3.fromRGB(60 + i * 15, 140, 90), Enum.Material.Glass).CanCollide = false
		end
		if not opts.noRoof then
			blk(folder, "Ceiling", Vector3.new(halfW * 2 + 6, 2, z1 - z0 + 70), CFrame.new(0, wallH, cz - 20), Color3.fromRGB(18, 18, 22)).CanCollide = false
		end
		outer = halfW + 4
	elseif lookKey == "amphi" then
		-- open-air half bowl around the floor and a band shell over the stage
		local pts = {}
		for k = 0, 8 do
			local a = math.pi * k / 8
			table.insert(pts, Vector3.new(-math.cos(a) * (halfW + 2), 0, cz + math.sin(a) * ((z1 - z0) / 2 + 2)))
		end
		local o = { rows = 16, depth = 4.5, step = 2.2, offset = 1, base = 0.4, color = Color3.fromRGB(130, 124, 112) }
		local out, top = stands(folder, pts, false, ctr, o, slotList, 0.6)
		outer = halfW + out + 4
		wallH = top + 6
		-- band shell: stepped concrete arches over the stage, smaller towards the back
		for j = 0, 4 do
			local R = 36 + j * 9
			local z = -58 + j * 9
			local n = 14
			for k = 0, n - 1 do
				local a0 = math.pi * (k + 0.5) / n
				local seg = math.pi * R / n + 0.6
				local p = blk(folder, "Shell", Vector3.new(seg, 1.6, 9.4), CFrame.new(math.cos(a0) * R, math.sin(a0) * R * 0.75, z) * CFrame.Angles(0, 0, math.atan2(math.cos(a0) * 0.75, -math.sin(a0))), Color3.fromRGB(225 - j * 8, 225 - j * 8, 232 - j * 8), Enum.Material.Concrete)
				p.CanCollide = false
			end
			blk(folder, "ShellLED", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, R * 0.75 - 1.4, z + 4.4), Color3.fromRGB(255, 220, 160), Enum.Material.Neon).CanCollide = false
		end
		for k = 0, 9 do
			local x = -outer + k * outer / 4.5
			local tz = z1 + out + 12 + (k % 2) * 6
			blk(folder, "Trunk", Vector3.new(1.5, 12, 1.5), CFrame.new(x, 6, tz), Color3.fromRGB(90, 60, 40), Enum.Material.Wood).CanCollide = false
			local crown = blk(folder, "Crown", Vector3.new(10, 10, 10), CFrame.new(x, 15, tz), Color3.fromRGB(40, 90, 50), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
		end
	end
	info.slots = #slots
	info.size = { halfW = halfW, floorEnd = z1, floorStart = z0, outer = outer, height = wallH, center = center }

	-- security in the photo pit
	if not opts.empty then
		for _, p in ipairs(staff) do
			fan(folder, info, p, center and math.atan2(-p.X, -p.Z) or math.pi, Color3.fromRGB(255, 214, 0), false)
		end
	end

	-- choose which slots get people
	if #slots > Venue.maxFigures then
		for i = #slots, 2, -1 do
			local j = math.random(1, i)
			slots[i], slots[j] = slots[j], slots[i]
		end
		for i = #slots, Venue.maxFigures + 1, -1 do
			slots[i] = nil
		end
	end
	table.sort(slots, function(a, b)
		return a.rank < b.rank
	end)
	local count = math.floor(#slots * math.clamp(fill, 0, 1) + 0.5)
	for i = 1, count do
		local s = slots[i]
		local pos = s.pos
		-- a figure looks along -Z at yaw 0 (towards an end stage); face = direction to look at
		local yaw
		if s.face then
			yaw = math.atan2(-s.face.X, -s.face.Z)
		elseif center then
			yaw = math.atan2(pos.X, pos.Z)
		else
			yaw = (math.random() - 0.5) * 0.4
		end
		local shirt = SHIRTS[math.random(1, #SHIRTS)]
		if merchColor and math.random() < 0.25 then
			shirt = merchColor
		end
		local raise = math.random() < 0.22
		local ph = fan(folder, info, pos, yaw, shirt, raise)
		if opts.wristbands and math.random() < 0.75 then
			local band = New("Part", {
				Name = "Wristband",
				Size = Vector3.new(0.5, 0.5, 0.5),
				Color = merchColor or Color3.new(1, 1, 1),
				Material = Enum.Material.Neon,
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
				CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.new(raise and 1.1 or -0.9, raise and 5 or 2.4, 0),
				Parent = folder,
			})
			table.insert(info.parts, band)
			table.insert(info.base, band.CFrame)
			table.insert(info.phase, ph)
			table.insert(info.bands, { part = band, x = pos.X, z = pos.Z })
		end
		if math.random() < 0.3 then
			local phone = New("Part", {
				Name = "Phone",
				Size = Vector3.new(0.35, 0.6, 0.1),
				Color = Color3.fromRGB(255, 255, 230),
				Material = Enum.Material.Neon,
				Transparency = 1,
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
				CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.new(0.9, 5.4, -0.1),
				Parent = folder,
			})
			table.insert(info.phones, phone)
		end
	end
	info.count = count
	info.cfs = table.create(#info.parts)
	return info
end

-- energy: jump height factor, speed: jumps per second-ish
function Venue.animate(info, t, energy, speed, phonesOn, c1, c2, beatCount)
	local parts, base, phase, cfs = info.parts, info.base, info.phase, info.cfs
	for i = 1, #parts do
		local j = math.sin(t * speed + phase[i])
		if j < 0 then
			j = 0
		end
		cfs[i] = base[i] + Vector3.new(0, j * energy, 0)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- LED wristbands and the arena's LED ribbon: colour waves on the beat
	if #info.bands > 0 and c1 and info.lastBeat ~= beatCount then
		info.lastBeat = beatCount
		local b = beatCount or 0
		for _, w in ipairs(info.bands) do
			local wave = math.floor((w.z * 0.08 + w.x * 0.03) + b) % 3
			w.part.Color = (wave == 0) and c1 or ((wave == 1) and c2 or Color3.new(1, 1, 1))
		end
	end
	if info.phonesOn ~= phonesOn then
		info.phonesOn = phonesOn
		for _, p in ipairs(info.phones) do
			p.Transparency = phonesOn and 0 or 1
		end
	end
end

function Venue.destroy(info)
	if info and info.folder then
		info.folder:Destroy()
	end
end

return Venue
