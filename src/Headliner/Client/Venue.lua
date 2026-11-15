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
	theatre = { w = 124, d = 90, roof = 68 },
	arena = { w = 176, d = 140, roof = 118 },
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
-- adds a point where the path crosses z (so no stand section is half in front of, half behind a drape)
local function splitAtZ(path, z)
	local out = {}
	local n = #path
	for i = 1, n do
		local a, b = path[i], path[i % n + 1]
		table.insert(out, a)
		if (a.Z - z) * (b.Z - z) < 0 then
			local f = (z - a.Z) / (b.Z - a.Z)
			table.insert(out, a:Lerp(b, f))
		end
	end
	return out
end

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
				local top = o.base + (r + 1) * o.step + (s % 2) * 0.07
				local L = len + off * (o.grow or 0.8)
				local c = Vector3.new(mid.X, 0, mid.Z) + nrm * (off + o.depth / 2)
				local col = (r % 2 == 0) and o.color or o.color:Lerp(Color3.new(0, 0, 0), 0.18)
				local draped = o.killZ and (mid.Z + nrm.Z * (off + o.depth / 2)) < o.killZ
				if draped then
					col = DRAPE
				end
				-- at an end stage, coloured seats never reach behind the side drapes (and black ones never in front)
				if o.killZ and math.abs(dir.Z) > 0.3 then
					local e1, e2 = c - dir * (L / 2), c + dir * (L / 2)
					local function clip(pA, pB, keepFront)
						-- moves pA along the tier to the drape line if it is on the wrong side
						local bad = keepFront and (pA.Z < o.killZ) or (not keepFront and pA.Z > o.killZ)
						if bad and math.abs(pB.Z - pA.Z) > 0.01 then
							local f = (o.killZ - pA.Z) / (pB.Z - pA.Z)
							return pA:Lerp(pB, math.clamp(f, 0, 1))
						end
						return pA
					end
					e1 = clip(e1, e2, not draped)
					e2 = clip(e2, e1, not draped)
					c = (e1 + e2) / 2
					L = math.max(1, (e2 - e1).Magnitude)
				end
				local h = math.min(top, o.step * 3 + (o.base > 0 and 2 or top))
				local p = blk(folder, draped and "DrapedTier" or "Tier", Vector3.new(L, h, o.depth), CFrame.new(c.X, top - h / 2, c.Z) * CFrame.Angles(0, yaw + math.pi / 2, 0), col, Enum.Material.Fabric)
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

local function sign(part, face, text, color)
	local g = New("SurfaceGui", { Parent = part, Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0.2 })
	New("TextLabel", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = text, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = color })
end
-- exit tunnels at floor level in the long stand sections: a concrete frame, a dark opening, a lit EXIT sign
local function exitTunnels(folder, path, center, killZ, big)
	local n = #path
	for s = 1, n do
		local a, b = path[s], path[s % n + 1]
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local len = dir.Magnitude
		local mid = (a + b) / 2
		if len > 30 and (not killZ or mid.Z > killZ + 10) then
			dir = dir.Unit
			local nrm = Vector3.new(dir.Z, 0, -dir.X)
			if (Vector3.new(mid.X, 0, mid.Z) - Vector3.new(center.X, 0, center.Z)):Dot(nrm) < 0 then
				nrm = -nrm
			end
			local yaw = math.atan2(nrm.X, nrm.Z)
			local count = (len > 90) and 2 or 1
			for k = 1, count do
				local u = -len / 2 + k * len / (count + 1)
				local base = Vector3.new(mid.X, 0, mid.Z) + dir * u
				local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0) -- local -Z points out of the stand, into the hall
				local w, h = big and 10 or 8, big and 9 or 8
				blk(folder, "TunnelFrame", Vector3.new(w + 2, h + 1, 2.4), cf * CFrame.new(0, (h + 1) / 2, 0.2), Color3.fromRGB(96, 98, 106), Enum.Material.Concrete)
				blk(folder, "TunnelOpening", Vector3.new(w, h, 2.6), cf * CFrame.new(0, h / 2 - 0.05, 0.2), Color3.fromRGB(6, 6, 8))
				local sg = blk(folder, "ExitSign", Vector3.new(4.6, 1.5, 0.3), cf * CFrame.new(0, h + 2, -1.2), Color3.fromRGB(20, 140, 60), Enum.Material.Neon)
				sign(sg, Enum.NormalId.Back, "EXIT", Color3.new(1, 1, 1))
				sign(sg, Enum.NormalId.Front, "EXIT", Color3.new(1, 1, 1))
			end
		end
	end
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
			local c = Vector3.new(mid.X, y + (s % 2) * 0.06, mid.Z) + nrm * (offset + (s % 2) * 0.05)
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
		if idx % 16 == 0 then
			table.insert(staffPos, Vector3.new(cx - e.d[1] * 1.2, 0.2, cz - e.d[2] * 1.2))
		end
	end
	-- front edge of the main stage: the first row (from the back) that is less than half as wide as the
	-- widest row is a runway or B-stage, everything before it is the main stage
	local rowW, widest = {}, 0
	for k in pairs(stage) do
		local j = k % 1000
		rowW[j] = (rowW[j] or 0) + 1
	end
	for _, n in pairs(rowW) do
		widest = math.max(widest, n)
	end
	local mainFront = -math.huge
	for j = 0, nz - 1 do
		if (rowW[j] or 0) >= widest * 0.5 and widest > 0 then
			mainFront = z0 + (j + 1) * G
		elseif mainFront > -math.huge and (rowW[j] or 0) < widest * 0.5 then
			break
		end
	end
	return function(x, z)
		local i, j = math.floor((x - x0) / G), math.floor((z - z0) / G)
		return crowdCell(i, j)
	end, staffPos, mainFront
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

------------------------------------------------------------------ the city around the venue
-- streets, a plaza, parking and rows of buildings, so you never look at an empty baseplate
local FACADES = { Color3.fromRGB(150, 146, 140), Color3.fromRGB(120, 80, 64), Color3.fromRGB(90, 96, 110), Color3.fromRGB(196, 190, 176), Color3.fromRGB(60, 66, 80), Color3.fromRGB(170, 160, 136) }
local function city(folder, x0, x1, z0, z1, seed)
	local rng = Random.new(seed or 11)
	local function flat(name, cx, cz, w, d, top, color, mat)
		local p = blk(folder, name, Vector3.new(w, 0.1, d), CFrame.new(cx, top - 0.05, cz), color, mat)
		p.CanCollide = false
		return p
	end
	local m = 34
	flat("Plaza", (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0 + m * 2, z1 - z0 + m * 2, 0.06, Color3.fromRGB(110, 110, 114), Enum.Material.Pavement)
	-- ring road with lane markings
	local r0x, r1x, r0z, r1z = x0 - m - 22, x1 + m + 22, z0 - m - 22, z1 + m + 22
	flat("Road", (r0x + r1x) / 2, r0z, r1x - r0x + 44, 44, 0.08, Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt)
	flat("Road", (r0x + r1x) / 2, r1z, r1x - r0x + 44, 44, 0.08, Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt)
	flat("Road", r0x, (r0z + r1z) / 2, 44, r1z - r0z - 44, 0.081, Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt)
	flat("Road", r1x, (r0z + r1z) / 2, 44, r1z - r0z - 44, 0.081, Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt)
	for x = r0x, r1x, 30 do
		flat("LaneDash", x, r0z, 10, 0.8, 0.11, Color3.fromRGB(220, 220, 220))
		flat("LaneDash", x, r1z, 10, 0.8, 0.11, Color3.fromRGB(220, 220, 220))
	end
	for z = r0z + 30, r1z - 30, 30 do
		flat("LaneDash", r0x, z, 0.8, 10, 0.11, Color3.fromRGB(220, 220, 220))
		flat("LaneDash", r1x, z, 0.8, 10, 0.11, Color3.fromRGB(220, 220, 220))
	end
	-- street lamps along the inner side of the ring road
	for x = r0x + 20, r1x - 20, 60 do
		for _, z in ipairs({ r0z + 25, r1z - 25 }) do
			blk(folder, "LampPole", Vector3.new(0.6, 16, 0.6), CFrame.new(x, 8, z), Color3.fromRGB(46, 48, 54), Enum.Material.Metal).CanCollide = false
			blk(folder, "LampHead", Vector3.new(1.6, 0.6, 2.4), CFrame.new(x, 16, z), Color3.fromRGB(255, 214, 140), Enum.Material.Neon).CanCollide = false
		end
	end
	-- buildings in two rows outside the ring road, a parking lot and a park here and there
	local function building(cx, cz, w, d, h)
		local col = FACADES[rng:NextInteger(1, #FACADES)]
		blk(folder, "Building", Vector3.new(w, h, d), CFrame.new(cx, h / 2, cz), col, (rng:NextNumber() < 0.4) and Enum.Material.Glass or Enum.Material.Concrete).CanCollide = false
		local y = 7
		while y < h - 4 do
			if rng:NextNumber() < 0.7 then
				local lit = rng:NextNumber() < 0.45
				blk(folder, "Windows", Vector3.new(w + 0.3, 2.4, d + 0.3), CFrame.new(cx, y, cz), lit and Color3.fromRGB(255, 214, 150):Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.5) or Color3.fromRGB(40, 50, 66), lit and Enum.Material.Neon or Enum.Material.Glass).CanCollide = false
			end
			y = y + 7
		end
		blk(folder, "RoofTop", Vector3.new(w * 0.3, 4, d * 0.3), CFrame.new(cx + w * 0.2, h + 2, cz - d * 0.2), Color3.fromRGB(70, 72, 78), Enum.Material.Metal).CanCollide = false
	end
	local b0x, b1x, b0z, b1z = r0x - 40, r1x + 40, r0z - 40, r1z + 40
	local function side(ax, az, bx, bz, nx, nz)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local dx, dz = (bx - ax) / len, (bz - az) / len
		local t = 0
		while t < len do
			local w = rng:NextNumber() * 30 + 34
			for depthRow = 0, 1 do
				local k = rng:NextNumber()
				local dist = 30 + depthRow * 80
				local cx, cz = ax + dx * (t + w / 2) + nx * dist, az + dz * (t + w / 2) + nz * dist
				if k < 0.82 then
					local h = (depthRow == 0) and (rng:NextNumber() * 50 + 24) or (rng:NextNumber() * 120 + 40)
					local bw, bd = (dx ~= 0) and w - 4 or 50, (dx ~= 0) and 50 or w - 4
					building(cx, cz, bw, bd, h)
				elseif depthRow == 0 then
					local pw, pd = (dx ~= 0) and w - 4 or 50, (dx ~= 0) and 50 or w - 4
					flat("Parking", cx, cz, pw, pd, 0.07, Color3.fromRGB(46, 46, 50), Enum.Material.Asphalt)
				end
			end
			t = t + w
		end
	end
	side(b0x, b0z, b1x, b0z, 0, -1)
	side(b0x, b1z, b1x, b1z, 0, 1)
	side(b0x, b0z, b0x, b1z, -1, 0)
	side(b1x, b0z, b1x, b1z, 1, 0)
end
Venue.city = city

------------------------------------------------------------------ build
-- look: key of LOOKS, fill: 0..1, merchColor: artist colour for some shirts
-- opts: { layout = "end" | "center", empty = bool, noRoof = bool, standingColor = Color3, wristbands = bool }
------------------------------------------------------------------ extra detail (you walk through the venue now)
local function solidOff(p)
	p.CanCollide = false
	return p
end
-- a bar / merch stand on the floor: counter, back wall with a lit name, things on the counter. faces -z (the stage)
-- (Venue.noCrowd collects the places where nobody may stand)
Venue.noCrowd = {}
local function stand(folder, x, z, w, title, accent, shirts)
	table.insert(Venue.noCrowd, { x = x, z = z + 1.5, w = w + 4, d = 9 })
	blk(folder, "StandBack", Vector3.new(w, 9, 0.9), CFrame.new(x, 4.5, z + 3.45), DARK)
	local sb = solidOff(blk(folder, "StandSign", Vector3.new(w - 2, 1.6, 0.2), CFrame.new(x, 7.6, z + 2.9), Color3.fromRGB(20, 20, 26)))
	sign(sb, Enum.NormalId.Front, title, accent)
	blk(folder, "StandCounter", Vector3.new(w, 3.6, 2), CFrame.new(x, 1.8, z), Color3.fromRGB(40, 36, 44), Enum.Material.WoodPlanks)
	blk(folder, "StandTop", Vector3.new(w + 0.4, 0.3, 2.4), CFrame.new(x, 3.75, z), Color3.fromRGB(20, 20, 24), Enum.Material.Marble)
	for k = 0, math.floor(w / 2.4) - 2 do
		local px = x - w / 2 + 2 + k * 2.4
		if shirts then
			solidOff(blk(folder, "MerchShirt", Vector3.new(1.8, 2, 0.2), CFrame.new(px, 5.6, z + 2.9), (k % 2 == 0) and accent or Color3.fromRGB(20, 20, 24), Enum.Material.Fabric))
		else
			solidOff(blk(folder, "Bottle", Vector3.new(0.4, 1.3, 0.4), CFrame.new(px, 5.6, z + 2.9), Color3.fromRGB(80 + (k * 30) % 150, 140, 90), Enum.Material.Glass))
		end
	end
end

function Venue.arenaDetails(folder, d)
	local halfW, z0, z1, cz, roofY = d.halfW, d.z0, d.z1, d.cz, d.roofY
	local steel = Color3.fromRGB(70, 72, 80)
	-- roof truss grid under the roof
	for k = -3, 3 do
		solidOff(blk(folder, "RoofTruss", Vector3.new(halfW * 2 + 30, 1.6, 1.6), CFrame.new(0, roofY - 2.4, cz + k * 26), steel, Enum.Material.DiamondPlate))
	end
	for k = -3, 3 do
		solidOff(blk(folder, "RoofTrussZ", Vector3.new(1.4, 1.2, (z1 - d.bz0) + 40), CFrame.new(k * 30, roofY - 3.9, (z1 + d.bz0) / 2), steel, Enum.Material.DiamondPlate))
	end
	-- house lights in the roof (dim)
	for k = -2, 2 do
		for j = -1, 1 do
			solidOff(blk(folder, "HouseLight", Vector3.new(4, 0.3, 4), CFrame.new(j * 46, roofY - 1.2, cz + k * 26 + 13), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)).Transparency = 0.4
		end
	end
	-- hanging speaker line arrays left and right of the stage (four around a center stage)
	local arrays = d.center and { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } or { { -1, 0 }, { 1, 0 } }
	for _, a in ipairs(arrays) do
		local ax = a[1] * (d.center and 34 or (halfW * 0.4))
		local az = d.center and (a[2] * 34) or 10
		local yaw = d.center and math.atan2(ax, az) or 0
		local top = roofY - 14
		solidOff(blk(folder, "ArrayBar", Vector3.new(4, 0.6, 4), CFrame.new(ax, top + 0.6, az) * CFrame.Angles(0, yaw, 0), steel, Enum.Material.Metal))
		solidOff(blk(folder, "ArrayCable", Vector3.new(0.2, roofY - top - 3, 0.2), CFrame.new(ax, (roofY + top) / 2 - 1, az), steel, Enum.Material.Metal))
		for k = 0, 9 do
			local tilt = math.rad(2 + k * k * 0.6)
			solidOff(blk(folder, "LineArray", Vector3.new(3.6 - (k % 2) * 0.06, 1.22, 2.6 - (k % 2) * 0.06), CFrame.new(ax, top - 0.7 - k * 1.32, az) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, 0, (k % 2) * 0.03), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric))
		end
	end
	-- lighting trusses over the floor with lamps
	for _, tz in ipairs({ cz - 20, cz + 18 }) do
		solidOff(blk(folder, "FloorTruss", Vector3.new(halfW * 1.6, 1.4, 1.4), CFrame.new(0, roofY - 18, tz), Color3.fromRGB(150, 152, 160), Enum.Material.DiamondPlate))
		for k = -5, 5 do
			local lx = k * halfW * 0.14
			solidOff(blk(folder, "ParCan", Vector3.new(1, 1.4, 1), CFrame.new(lx, roofY - 19.4, tz), Color3.fromRGB(16, 16, 18)))
			solidOff(blk(folder, "ParLens", Vector3.new(0.7, 0.1, 0.7), CFrame.new(lx, roofY - 20.15, tz), (k % 2 == 0) and d.accent or Color3.fromRGB(255, 240, 210), Enum.Material.Neon))
		end
		for _, sx in ipairs({ -1, 1 }) do
			solidOff(blk(folder, "TrussHang", Vector3.new(0.2, 15, 0.2), CFrame.new(sx * halfW * 0.78, roofY - 10.5, tz), steel, Enum.Material.Metal))
		end
	end
	-- banners in the artist colour hanging from the roof at the back
	for k = -3, 3 do
		local bx = k * 18
		local bz = z1 + 26
		solidOff(blk(folder, "Banner", Vector3.new(8, 16, 0.3), CFrame.new(bx, roofY - 12, bz + (k % 2) * 0.05), (k % 2 == 0) and d.accent or Color3.fromRGB(26, 26, 32), Enum.Material.Fabric))
		solidOff(blk(folder, "BannerStripe", Vector3.new(8.2, 1.2, 0.4), CFrame.new(bx, roofY - 17, bz + (k % 2) * 0.05), Color3.fromRGB(230, 230, 236), Enum.Material.Fabric))
	end
	-- bars and the merch stand at the back of the floor
	if not d.center then
		stand(folder, -halfW + 16, z1 - 4, 18, "BAR", Color3.fromRGB(255, 200, 80), false)
		stand(folder, halfW - 16, z1 - 4, 18, "MERCH", d.accent, true)
	end
	-- followspot platforms high on the back stands
	for _, sx in ipairs({ -1, 1 }) do
		local fx, fz = sx * halfW * 0.35, z1 + 2 + d.uOut - 3
		blk(folder, "SpotPlatform", Vector3.new(6, 1, 5), CFrame.new(fx, d.uTop + 1, fz), steel, Enum.Material.DiamondPlate)
		solidOff(blk(folder, "Followspot", Vector3.new(1.6, 1.6, 4), CFrame.new(fx, d.uTop + 3, fz - 0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal))
		solidOff(blk(folder, "SpotLens", Vector3.new(1.2, 1.2, 0.1), CFrame.new(fx, d.uTop + 3.4, fz - 2.55) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(255, 250, 230), Enum.Material.Neon))
	end
end

function Venue.clubDetails(folder, d)
	local halfW, z1, H = d.halfW, d.z1, d.wallH
	local pipe = Color3.fromRGB(80, 80, 88)
	-- ducts and pipes under the ceiling
	for _, x in ipairs({ -halfW * 0.6, halfW * 0.55 }) do
		local duct = solidOff(blk(folder, "Duct", Vector3.new(z1 + 24, 3.4, 3.4), CFrame.new(x, H - 3, (z1 - 28) / 2) * CFrame.Angles(0, math.pi / 2, 0), pipe, Enum.Material.Metal))
		duct.Shape = Enum.PartType.Cylinder
	end
	for k = 0, 4 do
		solidOff(blk(folder, "Pipe", Vector3.new(halfW * 2, 0.5, 0.5), CFrame.new(0, H - 1.4 - (k % 2) * 0.7, -10 + k * 14), Color3.fromRGB(150, 60, 40), Enum.Material.Metal))
	end
	-- truss over the stage with par cans, a mirror ball over the floor
	solidOff(blk(folder, "ClubTruss", Vector3.new(50, 1.2, 1.2), CFrame.new(0, H - 6, 6), Color3.fromRGB(150, 152, 160), Enum.Material.DiamondPlate))
	for k = -6, 6 do
		solidOff(blk(folder, "ParCan", Vector3.new(0.9, 1.3, 0.9), CFrame.new(k * 3.6, H - 7.3, 6), Color3.fromRGB(16, 16, 18)))
		solidOff(blk(folder, "ParLens", Vector3.new(0.6, 0.1, 0.6), CFrame.new(k * 3.6, H - 8, 6), (k % 2 == 0) and d.accent or Color3.fromRGB(255, 200, 120), Enum.Material.Neon))
	end
	local ball = solidOff(blk(folder, "MirrorBall", Vector3.new(3.4, 3.4, 3.4), CFrame.new(0, H - 9, z1 * 0.5), Color3.fromRGB(220, 220, 230), Enum.Material.Foil))
	ball.Shape = Enum.PartType.Ball
	solidOff(blk(folder, "BallChain", Vector3.new(0.15, 7, 0.15), CFrame.new(0, H - 4, z1 * 0.5), pipe, Enum.Material.Metal))
	-- gig posters on the brick walls, the exit, the merch table
	local cols = { Color3.fromRGB(240, 80, 120), Color3.fromRGB(80, 160, 240), Color3.fromRGB(250, 200, 60), Color3.fromRGB(120, 220, 140), Color3.fromRGB(200, 120, 255) }
	for k = 0, 7 do
		local side = (k % 2 == 0) and -1 or 1
		local z = 6 + math.floor(k / 2) * 12
		solidOff(blk(folder, "GigPoster", Vector3.new(0.12, 5, 3.6), CFrame.new(side * (halfW + 0.94), 9 + (k % 3) * 0.8, z), cols[k % #cols + 1], Enum.Material.SmoothPlastic))
	end
	local exit = solidOff(blk(folder, "ExitSign", Vector3.new(5, 1.6, 0.3), CFrame.new(halfW * 0.6, 12, z1 + 0.8), Color3.fromRGB(20, 120, 50), Enum.Material.SmoothPlastic))
	sign(exit, Enum.NormalId.Front, "EXIT", Color3.fromRGB(230, 255, 230))
	blk(folder, "ExitDoor", Vector3.new(7, 9, 0.4), CFrame.new(halfW * 0.6, 4.5, z1 + 0.8), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	if not d.center then
		stand(folder, halfW - 10, z1 - 4, 12, "MERCH", d.accent, true)
	end
end

function Venue.theatreDetails(folder, d)
	local halfW, H = d.halfW, d.wallH
	local gold, cream = Color3.fromRGB(210, 170, 70), Color3.fromRGB(230, 214, 180)
	-- pillars and wall lamps along the side walls
	for _, sx in ipairs({ -1, 1 }) do
		for k = 0, 5 do
			local z = -10 + k * 22
			local pil = solidOff(blk(folder, "Pillar", Vector3.new(H, 2.4, 2.4), CFrame.new(sx * (halfW + 1.6), H / 2, z) * CFrame.Angles(0, 0, math.pi / 2), cream, Enum.Material.Marble))
			pil.Shape = Enum.PartType.Cylinder
			solidOff(blk(folder, "Sconce", Vector3.new(0.6, 1.2, 0.8), CFrame.new(sx * (halfW + 0.2), 11, z + 11), Color3.fromRGB(255, 214, 150), Enum.Material.Neon))
		end
	end
	if not d.noRoof then
		-- ceiling coffers with gold frames and a big round medallion
		for gx = -2, 2 do
			for gz = 0, 4 do
				solidOff(blk(folder, "Coffer", Vector3.new(halfW * 0.34, 0.5, 14), CFrame.new(gx * halfW * 0.4, H - 1 - ((gx + gz) % 2) * 0.04, -6 + gz * 22), Color3.fromRGB(110, 40, 44), Enum.Material.Fabric))
			end
		end
		local med = solidOff(blk(folder, "Medallion", Vector3.new(0.6, 30, 30), CFrame.new(0, H - 1.6, d.z1 * 0.45) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Metal))
		med.Shape = Enum.PartType.Cylinder
	end
	-- exit signs at the back
	-- exit doors: at the top of the stalls (back wall) and in the side walls near the stage
	for _, sx in ipairs({ -1, 1 }) do
		local e = solidOff(blk(folder, "ExitSign", Vector3.new(5, 1.6, 0.3), CFrame.new(sx * halfW * 0.7, 19.4, d.z1 + d.out1 - 0.2), Color3.fromRGB(20, 140, 60), Enum.Material.Neon))
		sign(e, Enum.NormalId.Front, "EXIT", Color3.new(1, 1, 1))
		blk(folder, "ExitDoor", Vector3.new(6, 8, 0.4), CFrame.new(sx * halfW * 0.7, 10 + 4, d.z1 + d.out1 - 0.15), Color3.fromRGB(50, 30, 30), Enum.Material.Wood)
		blk(folder, "ExitDoor", Vector3.new(0.4, 9, 6), CFrame.new(sx * (halfW + 1.8), 4.5, 12), Color3.fromRGB(50, 30, 30), Enum.Material.Wood)
		local e2 = solidOff(blk(folder, "ExitSign", Vector3.new(0.3, 1.5, 4.6), CFrame.new(sx * (halfW + 1.6), 10.6, 12), Color3.fromRGB(20, 140, 60), Enum.Material.Neon))
		sign(e2, (sx < 0) and Enum.NormalId.Right or Enum.NormalId.Left, "EXIT", Color3.new(1, 1, 1))
	end
end

-- you walk through the venue: walls, stands, barriers and the stage are solid (the crowd is not),
-- and invisible walls keep you inside
function Venue.makeWalkable(info, extraFolders)
	local crowdPart = {}
	for _, p in ipairs(info.parts) do
		crowdPart[p] = true
	end
	local function solid(p)
		if not p:IsA("BasePart") or crowdPart[p] then
			return
		end
		local n = p.Name
		if p.Transparency > 0.5 or p.Material == Enum.Material.Neon or n:find("^Security") or n:find("^Vest") or n:find("^Fan") then
			return
		end
		p.CanCollide = true
	end
	for _, d in ipairs(info.folder:GetDescendants()) do
		solid(d)
	end
	for _, f in ipairs(extraFolders or {}) do
		for _, d in ipairs(f:GetDescendants()) do
			solid(d)
		end
	end
	local sz = info.size
	local out = sz.outer + 2
	local zA = sz.center and -(out) or -90
	local zB = sz.floorEnd + (sz.outer - sz.halfW) + 6
	local H = 200
	local function wall(size, pos)
		New("Part", { Name = "VenueBoundary", Size = size, CFrame = CFrame.new(pos), Anchored = true, CanCollide = true, CanTouch = false, CanQuery = false, Transparency = 1, Parent = info.folder })
	end
	wall(Vector3.new(2, H, zB - zA), Vector3.new(-out, H / 2, (zA + zB) / 2))
	wall(Vector3.new(2, H, zB - zA), Vector3.new(out, H / 2, (zA + zB) / 2))
	wall(Vector3.new(out * 2, H, 2), Vector3.new(0, H / 2, zA))
	wall(Vector3.new(out * 2, H, 2), Vector3.new(0, H / 2, zB))
end

function Venue.build(lookKey, fill, merchColor, opts)
	opts = opts or {}
	local center = opts.layout == "center"
	local L = LOOKS[lookKey] or LOOKS.arena
	local folder = New("Folder", { Name = "VenueBuild", Parent = Stage3D.venueFolder })
	Venue.noCrowd = {}
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
		-- the whole pitch is covered with floor protection tiles (from behind the stage to the stands)
		floor.Color = Color3.fromRGB(70, 74, 82)
		floor.Material = Enum.Material.DiamondPlate
		local fz0, fz1 = center and (z0 - 4) or (zBack - 2), z1 + 4
		floor.Size = Vector3.new(halfW * 2 + 6, 0.2, fz1 - fz0)
		floor.CFrame = CFrame.new(0, 0.05, (fz0 + fz1) / 2)
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
			blk(folder, "FOHBarrier", Vector3.new(14.4, 3.0, 0.35), CFrame.new(0, 1.7, fz + bz), Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate)
		end
		for _, px in ipairs({ -6.7, 6.7 }) do
			for _, pz in ipairs({ -4.05, 4.05 }) do
				blk(folder, "FOHPole", Vector3.new(0.4, 8, 0.4), CFrame.new(px, 4.8, fz + pz), METAL, Enum.Material.Metal)
			end
		end
	end
	local function blocked(x, z)
		if foh and math.abs(x - foh.x) < foh.w / 2 + 1 and math.abs(z - foh.z) < foh.d / 2 + 1 then
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
	local crowdOk, staff, mainFront = function(x, z)
		return not blocked(x, z)
	end, {}, nil
	if not opts.empty then
		crowdOk, staff, mainFront = barriers(folder, -halfW, halfW, z0 - (center and 0 or 40), z1, blocked)
	end

	-- floor slots (standing crowd)
	if not opts.empty then
		local sp = 3.2
		for z = z0 + 2, z1 - 1, sp do
			for x = -halfW + 2, halfW - 2, sp do
				local px, pz = x + (math.random() - 0.5) * 1.2, z + (math.random() - 0.5) * 1.2
				local nearBar = lookKey == "club" and px < -halfW + 9
				local m = 2.6 -- body + barrier foot
				-- nobody stands beside the main stage (you could not see anything from there)
				local beside = (not center) and mainFront and mainFront > -math.huge and pz < mainFront + 1
				if not nearBar and not beside and crowdOk(px, pz) and crowdOk(px + m, pz) and crowdOk(px - m, pz) and crowdOk(px, pz + m) and crowdOk(px, pz - m) then
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
		if killZ then
			path = splitAtZ(path, killZ)
		end
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
		exitTunnels(folder, path, ctr, killZ, big)
		local upper = big and { rows = 14, depth = 4.4, step = 3.2 } or { rows = 7, depth = 5, step = 3.8 }
		upper.offset, upper.base, upper.color, upper.killZ = lOut + 5, lTop + 9.5, seat:Lerp(Color3.new(0, 0, 0), 0.1), killZ
		local uOut, uTop = stands(folder, path, true, ctr, upper, slotList, 1.1)
		outer = halfW + uOut + 4
		wallH = uTop + 8
		if not big then
			roofY = math.max(roofY, wallH + 18)
			if not opts.noRoof then
				wallH = roofY + 0.6
			end
		end
		band(folder, path, true, ctr, uOut + 1, wallH / 2, wallH, 2, DARK, Enum.Material.Concrete, "OuterWall")
		local sbz = nil
		if big then
			-- roof canopy all around with a row of floodlights
			band(folder, path, true, ctr, uOut - 18, uTop + 14, 1.5, 44, Color3.fromRGB(200, 205, 215), Enum.Material.Metal, "Canopy")
			band(folder, path, true, ctr, uOut - 38, uTop + 12.6, 1, 1, Color3.fromRGB(255, 250, 230), Enum.Material.Neon, "Floodlights")
			-- video screens behind the last row of the end stand, under the roof, on a steel frame
			local sz = z1 + 2 + uOut - 3
			for _, x in ipairs({ -1, 1 }) do
				local cx = x * halfW * 0.5
				blk(folder, "ScreenFrame", Vector3.new(40, 14, 1.6), CFrame.new(cx, uTop + 7.5, sz + 0.9), Color3.fromRGB(24, 24, 28), Enum.Material.Metal).CanCollide = false
				blk(folder, "BigScreen", Vector3.new(38, 12, 0.4), CFrame.new(cx, uTop + 7.5, sz), Color3.fromRGB(30, 60, 140), Enum.Material.Neon).CanCollide = false
				for _, lx in ipairs({ -16, 16 }) do
					blk(folder, "ScreenLeg", Vector3.new(1, 8, 1), CFrame.new(cx + lx, uTop - 2, sz + 1), METAL, Enum.Material.Metal).CanCollide = false
					blk(folder, "ScreenHanger", Vector3.new(0.5, 1.2, 0.5), CFrame.new(cx + lx, uTop + 14.1, sz + 1), METAL, Enum.Material.Metal).CanCollide = false
				end
			end
			roofY = uTop + 16
		else
			-- roof, rig catwalks, centre-hung scoreboard
			local roof = blk(folder, "Roof", Vector3.new(outer * 2, 2, (z1 + 2 - bz0) + uOut * 2 + 10), CFrame.new(0, roofY, bcz), Color3.fromRGB(14, 14, 20))
			roof.CanCollide = false
			if opts.noRoof then
				roof:Destroy()
			end
			for k = (opts.noRoof and 1 or -3), (opts.noRoof and 0 or 3) do
				blk(folder, "Catwalk", Vector3.new(outer * 2 - 3, 1.2, 2), CFrame.new(0, roofY - 6, cz + k * 30), METAL, Enum.Material.DiamondPlate).CanCollide = false
			end
			for k = (opts.noRoof and 1 or -2), (opts.noRoof and 0 or 2) do
				blk(folder, "Catwalk", Vector3.new(2, 1.2, (z1 - z0) + 37), CFrame.new(k * 40, roofY - 6.4, cz), METAL, Enum.Material.DiamondPlate).CanCollide = false
			end
			sbz = center and (z1 - 30) or (z0 + (z1 - z0) * 0.55)
			if opts.noRoof then
				sbz = nil
			end
		end
		if not big and not opts.noRoof then
			Venue.arenaDetails(folder, { halfW = halfW, z0 = z0, z1 = z1, cz = cz, bz0 = bz0, roofY = roofY, center = center, accent = accent, lTop = lTop, uTop = uTop, uOut = uOut, outer = outer, lower = lower })
		end
		if sbz then
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
				blk(folder, "SideDrape", Vector3.new(1, dh - 0.3, 1.3 - zBack), CFrame.new(x * (halfW + 1), (dh - 0.3) / 2, (zBack + 1.3) / 2), DRAPE, Enum.Material.Fabric).CanCollide = false
				blk(folder, "SideDrape", Vector3.new(outer - halfW, dh - 0.6, 1.2), CFrame.new(x * (halfW + (outer - halfW) / 2), (dh - 0.6) / 2, 2), DRAPE, Enum.Material.Fabric).CanCollide = false
			end
			blk(folder, "BackstageFloor", Vector3.new(halfW * 2 - 0.4, 0.2, 2 - zBack), CFrame.new(0, -0.03, (zBack + 2) / 2), Color3.fromRGB(20, 20, 24), Enum.Material.Concrete).CanCollide = false
		end
	elseif lookKey == "theatre" then
		-- stalls rake at the back, two separate balcony levels (U shape: back section + side arms),
		-- boxes next to the stage, red and gold proscenium. Every row is its own block (no overlaps).
		local red, gold = Color3.fromRGB(120, 24, 32), Color3.fromRGB(210, 170, 70)
		local function row(x, z, w, d, yTop, h, alongX, rank)
			local size = alongX and Vector3.new(w, h, d) or Vector3.new(d, h, w)
			blk(folder, "Tier", size, CFrame.new(x, yTop - h / 2, z), (math.floor(yTop) % 2 == 0) and seat or seat:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Fabric).CanCollide = false
			if slotList then
				local k = -w / 2 + 2
				while k < w / 2 - 2 do
					local px = alongX and (x + k) or x
					local pz = alongX and z or (z + k)
					local face = alongX and Vector3.new(0, 0, -1) or Vector3.new((x > 0) and -1 or 1, 0, 0)
					table.insert(slotList, { pos = Vector3.new(px, yTop, pz), rank = rank + math.random() * 0.3, face = face })
					k = k + 3.3
				end
			end
		end
		-- rear stalls rake
		for r = 0, 5 do
			row(0, z1 + 2 + r * 4, halfW * 2, 4, 0.4 + (r + 1) * 1.6, 0.4 + (r + 1) * 1.6, true, 0.7)
		end
		local out1 = 26
		for i, lvl in ipairs({ 15, 29 }) do
			local front = z1 - 10 - i * 2 -- the higher circle hangs a bit less far forward
			-- underside and front parapet with a gold rail
			blk(folder, "Soffit", Vector3.new(halfW * 2, 1.6, z1 + out1 - front), CFrame.new(0, lvl - 0.8, (front + z1 + out1) / 2), Color3.fromRGB(70, 20, 26), Enum.Material.Fabric).CanCollide = false
			blk(folder, "BalconyLip", Vector3.new(halfW * 2 - 16, 3.4, 1), CFrame.new(0, lvl + 1.2, front - 0.5), red, Enum.Material.Fabric).CanCollide = false
			blk(folder, "BalconyGold", Vector3.new(halfW * 2 - 15.6, 0.4, 1.3), CFrame.new(0, lvl + 3.1, front - 0.5), gold, Enum.Material.Metal).CanCollide = false
			for r = 0, 6 do
				row(0, front + 2.5 + r * 4.4, halfW * 2 - 0.4, 4.4, lvl + (r + 1) * 1.8, 1.8 + ((r == 0) and 0 or 0.2), true, 0.85 + i * 0.2)
			end
			-- side arms along the walls
			for _, sx in ipairs({ -1, 1 }) do
				local zA, zB = 22, front
				blk(folder, "Soffit", Vector3.new(8, 1.6, zB - zA), CFrame.new(sx * (halfW - 4), lvl - 0.8, (zA + zB) / 2), Color3.fromRGB(70, 20, 26), Enum.Material.Fabric).CanCollide = false
				blk(folder, "BalconyLip", Vector3.new(1, 3.2, zB - zA - 1.4), CFrame.new(sx * (halfW - 8.5), lvl + 1.1, (zA + zB - 1.4) / 2), red, Enum.Material.Fabric).CanCollide = false
				blk(folder, "BalconyGold", Vector3.new(1.2, 0.4, zB - zA - 1.4), CFrame.new(sx * (halfW - 8.5), lvl + 2.95, (zA + zB - 1.4) / 2), gold, Enum.Material.Metal).CanCollide = false
				row(sx * (halfW - 6), (zA + zB) / 2, zB - zA - 2, 3.6, lvl + 1.8, 1.8, false, 1 + i * 0.2)
				row(sx * (halfW - 2.4), (zA + zB) / 2, zB - zA - 2, 3.6, lvl + 3.6, 3.6, false, 1.1 + i * 0.2)
				-- private box next to the stage on this level
				blk(folder, "Box", Vector3.new(7, 1.2, 12), CFrame.new(sx * (halfW - 3.5), lvl - 0.6, 8), red, Enum.Material.Fabric).CanCollide = false
				blk(folder, "BoxFront", Vector3.new(1, 3.2, 12), CFrame.new(sx * (halfW - 7.5), lvl + 1.6, 8), red, Enum.Material.Fabric).CanCollide = false
				blk(folder, "BoxGold", Vector3.new(1.3, 0.4, 12.2), CFrame.new(sx * (halfW - 7.5), lvl + 3.4, 8), gold, Enum.Material.Metal).CanCollide = false
				blk(folder, "BoxLight", Vector3.new(0.3, 2, 9), CFrame.new(sx * (halfW + 1.9), lvl + 6, 8), Color3.fromRGB(255, 210, 140), Enum.Material.Neon).CanCollide = false
			end
		end
		local _ = out1
		outer = halfW + out1 + 6
		wallH = L.roof
		for _, x in ipairs({ -1, 1 }) do
			local wz0, wz1 = -90, z1 + out1 + 2
			blk(folder, "Wall", Vector3.new(2, wallH, wz1 - wz0), CFrame.new(x * (halfW + 3), wallH / 2, (wz0 + wz1) / 2), Color3.fromRGB(90, 20, 28), Enum.Material.Fabric).CanCollide = false
			blk(folder, "StageCurtain", Vector3.new(14, wallH - 6, 2), CFrame.new(x * (halfW - 6), (wallH - 6) / 2, -30), Color3.fromRGB(150, 18, 30), Enum.Material.Fabric).CanCollide = false
		end
		blk(folder, "Valance", Vector3.new(halfW * 2, 10, 2), CFrame.new(0, wallH - 10, -30.7), Color3.fromRGB(150, 18, 30), Enum.Material.Fabric).CanCollide = false
		blk(folder, "ProsceniumGold", Vector3.new(halfW * 2, 1, 2.2), CFrame.new(0, wallH - 15.5, -30), Color3.fromRGB(210, 170, 70), Enum.Material.Metal).CanCollide = false
		blk(folder, "Backdrop", Vector3.new(halfW * 2, wallH, 1), CFrame.new(0, wallH / 2, -46), DRAPE, Enum.Material.Fabric).CanCollide = false
		blk(folder, "BackWall", Vector3.new(halfW * 2 + 4, wallH, 2), CFrame.new(0, wallH / 2, z1 + out1 + 1), Color3.fromRGB(70, 18, 24), Enum.Material.Fabric).CanCollide = false
		if not opts.noRoof then
			blk(folder, "Ceiling", Vector3.new(halfW * 2 + 7.4, 2, z1 + out1 + 91), CFrame.new(0, wallH + 0.3, (z1 + out1 + 1.5 - 89.5) / 2), Color3.fromRGB(60, 30, 30)).CanCollide = false
			for k = 0, 5 do
				local a = k * math.pi / 3
				local b = blk(folder, "Chandelier", Vector3.new(2, 2, 2), CFrame.new(math.cos(a) * 3, wallH - 9, cz + 10 + math.sin(a) * 3), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
				b.Shape = Enum.PartType.Ball
				b.CanCollide = false
			end
		end
		Venue.theatreDetails(folder, { halfW = halfW, z1 = z1, wallH = wallH, out1 = out1, noRoof = opts.noRoof })
	elseif lookKey == "club" then
		local brick = Color3.fromRGB(70, 40, 34)
		wallH = L.roof
		for _, x in ipairs({ -1, 1 }) do
			-- the side walls run on to the outside of the back wall (no gap in the corners)
			blk(folder, "Wall", Vector3.new(2, wallH, z1 + 33), CFrame.new(x * (halfW + 2), wallH / 2, (z1 + 3 - 30) / 2), brick, Enum.Material.Brick).CanCollide = false
			blk(folder, "WallSpeaker", Vector3.new(3, 4.5, 3), CFrame.new(x * (halfW - 2), 22, -6), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric).CanCollide = false
		end
		blk(folder, "BackWall", Vector3.new(halfW * 2 + 2, wallH, 2), CFrame.new(0, wallH / 2, z1 + 2), brick, Enum.Material.Brick).CanCollide = false
		-- right behind the stage: brick wall with a velvet curtain, a neon sign, speakers and road cases
		local bz = -27
		blk(folder, "StageBackWall", Vector3.new(halfW * 2 + 2, wallH, 2), CFrame.new(0, wallH / 2, bz - 1), brick, Enum.Material.Brick).CanCollide = false
		for k = -6, 6 do
			blk(folder, "Curtain", Vector3.new(4.2, wallH * 0.62 + (k % 2) * 0.1, 1 + (k % 2) * 0.3), CFrame.new(k * 4, wallH * 0.31 + (k % 2) * 0.05, bz + 0.6 + (k % 2) * 0.2), Color3.fromRGB(110, 14, 30), Enum.Material.Fabric).CanCollide = false
		end
		blk(folder, "CurtainRail", Vector3.new(56, 1, 1), CFrame.new(0, wallH * 0.62 + 0.5, bz + 0.8), Color3.fromRGB(40, 40, 44), Enum.Material.Metal).CanCollide = false
		blk(folder, "LiveSign", Vector3.new(16, 3, 0.4), CFrame.new(0, wallH * 0.62 + 5, bz + 0.3), Color3.fromRGB(255, 60, 170), Enum.Material.Neon).CanCollide = false
		for _, x in ipairs({ -1, 1 }) do
			blk(folder, "WingCurtain", Vector3.new(halfW - 30, wallH, 1), CFrame.new(x * (30 + (halfW - 30) / 2 + 1), wallH / 2, bz + 0.8), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric).CanCollide = false
			for k = 0, (center and -1 or 2) do
				blk(folder, "RoadCase", Vector3.new(4, 3, 3), CFrame.new(x * (halfW - 4), 1.5 + k * 3.05, bz + 3), Color3.fromRGB(22, 22, 24)).CanCollide = false
				blk(folder, "CaseEdge", Vector3.new(4.2, 0.25, 3.2), CFrame.new(x * (halfW - 4), 2.9 + k * 3.05, bz + 3), Color3.fromRGB(170, 170, 176), Enum.Material.Metal).CanCollide = false
			end
		end
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
			blk(folder, "Ceiling", Vector3.new(halfW * 2 + 6, 2, z1 + 33), CFrame.new(0, wallH + 0.3, (z1 + 3 - 30) / 2), Color3.fromRGB(18, 18, 22)).CanCollide = false
		end
		Venue.clubDetails(folder, { halfW = halfW, z0 = z0, z1 = z1, wallH = wallH, accent = accent, center = center })
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
				local rr = R + (k % 2) * 0.12
				local p = blk(folder, "Shell", Vector3.new(seg, 1.6 + (k % 2) * 0.1, 9.4 - (k % 2) * 0.2), CFrame.new(math.cos(a0) * rr, math.sin(a0) * rr * 0.75, z) * CFrame.Angles(0, 0, math.atan2(math.cos(a0) * 0.75, -math.sin(a0))), Color3.fromRGB(225 - j * 8, 225 - j * 8, 232 - j * 8), Enum.Material.Concrete)
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
	-- nobody stands inside a bar or merch stand
	if #Venue.noCrowd > 0 then
		local keep = {}
		for _, sl in ipairs(slots) do
			local ok = true
			for _, r in ipairs(Venue.noCrowd) do
				if math.abs(sl.pos.X - r.x) < r.w / 2 and math.abs(sl.pos.Z - r.z) < r.d / 2 then
					ok = false
				end
			end
			if ok then
				table.insert(keep, sl)
			end
		end
		slots = keep
	end
	info.slots = #slots
	info.size = { halfW = halfW, floorEnd = z1, floorStart = z0, outer = outer, height = wallH, center = center }
	-- outside: streets and buildings all around (footprint of the hall from its outer walls)
	local backZ = center and (z0 - (outer - halfW)) or math.min(zBack - (outer - halfW) * 0.5, -90)
	city(folder, -outer, outer, backZ, z1 + (outer - halfW) + 4, #lookKey * 7)

	-- security in the photo pit
	if not opts.empty then
		for _, p in ipairs(staff) do
			local yaw = center and math.atan2(-p.X, -p.Z) or math.pi
			local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
			blk(folder, "SecurityLegs", Vector3.new(1.4, 1.8, 0.8), cf * CFrame.new(0, 0.9, 0), Color3.fromRGB(20, 20, 24)).CanCollide = false
			blk(folder, "SecurityVest", Vector3.new(1.8, 1.8, 1), cf * CFrame.new(0, 2.7, 0), Color3.fromRGB(230, 200, 40), Enum.Material.SmoothPlastic).CanCollide = false
			blk(folder, "VestStripe", Vector3.new(1.84, 0.2, 1.04), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Foil).CanCollide = false
			blk(folder, "VestStripe", Vector3.new(1.84, 0.2, 1.04), cf * CFrame.new(0, 3.1, 0), Color3.fromRGB(220, 220, 230), Enum.Material.Foil).CanCollide = false
			local head = blk(folder, "SecurityHead", Vector3.new(1.1, 1.2, 1.1), cf * CFrame.new(0, 4.2, 0), People.SKINS[math.random(1, #People.SKINS)])
			head.CanCollide = false
			New("SpecialMesh", { MeshType = Enum.MeshType.Head, Parent = head })
			blk(folder, "SecurityCap", Vector3.new(1.2, 0.35, 1.2), cf * CFrame.new(0, 4.8, 0), Color3.fromRGB(20, 20, 24)).CanCollide = false
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
	-- dust in the air: tiny slow specks everywhere above the floor and the stage, they catch the light
	if not opts.empty then
		local top = math.min(48, (L.roof or 60) - 6)
		local dz0 = center and z0 or (FLOOR_START - 40)
		local dust = New("Part", { Name = "Dust", Parent = folder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(halfW * 2, top, z1 - dz0), CFrame = CFrame.new(0, top / 2 + 1, (z1 + dz0) / 2) })
		New("ParticleEmitter", {
			Parent = dust,
			Shape = Enum.ParticleEmitterShape.Box,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Rate = math.floor(math.clamp(halfW * (z1 - dz0) / 90, 25, 140) * (((Venue.maxFigures or 1100) < 600) and 0.5 or 1)),
			Lifetime = NumberRange.new(9, 14),
			Speed = NumberRange.new(0.2, 0.7),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.22) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(0.75, 0.6), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(230, 226, 214)),
			LightEmission = 0.4,
			LightInfluence = 1,
			Acceleration = Vector3.new(0, -0.03, 0),
		})
	end
	info.pars = {}
	for _, d in ipairs(folder:GetDescendants()) do
		if d.Name == "ParLens" then
			table.insert(info.pars, d)
		end
	end
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
	-- the venue's own PAR cans change colour with the music (every 4 beats, neighbours take turns)
	if info.pars and c1 then
		local q = math.floor((beatCount or 0) / 4)
		if info.parQ ~= q or info.parC1 ~= c1 then
			info.parQ, info.parC1 = q, c1
			for i, p in ipairs(info.pars) do
				p.Color = ((i + q) % 2 == 0) and c1 or (c2 or c1)
			end
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
