-- Builds a venue (walls, stands, roof) around the main stage and fills it with a crowd.
-- The number of visible people matches how many tickets were sold (scaled down for performance).
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local Stage3D = require(Root.Client.Stage3D)
local People = require(Root.Client.People)

local New = UI.New
local Venue = {}

Venue.maxFigures = 1300

-- crowd detail setting (main menu > settings)
function Venue.setDetail(level)
	Venue.maxFigures = (level == "Low") and 500 or ((level == "Medium") and 900 or 1300)
end

local LOOKS = {
	club = { w = 90, d = 60, side = 0, back = 0, roof = 46, label = "club" },
	theatre = { w = 110, d = 80, side = 0, back = 7, roof = 62, label = "theatre" },
	arena = { w = 150, d = 120, side = 10, back = 10, roof = 100 },
	amphi = { w = 150, d = 80, side = 0, back = 14, roof = nil },
	stadium = { w = 240, d = 230, side = 14, back = 14, roof = nil },
}
Venue.LOOKS = LOOKS

local SHIRTS = {
	Color3.fromRGB(20, 20, 24), Color3.fromRGB(230, 230, 235), Color3.fromRGB(200, 40, 60),
	Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 200, 50), Color3.fromRGB(60, 160, 90),
	Color3.fromRGB(150, 60, 200), Color3.fromRGB(255, 120, 170), Color3.fromRGB(90, 90, 100),
}

local TIER_STEP = 3.4
local TIER_DEPTH = 6.5 -- roomy stands with space between the rows
local FLOOR_START = -10

-- look: key of LOOKS, fill: 0..1, merchColor: artist colour for some shirts
-- opts: { layout = "end" | "center", pits = { { cf = CFrame, w = number, d = number } } }
function Venue.build(lookKey, fill, merchColor, opts)
	opts = opts or {}
	local center = opts.layout == "center"
	local L = LOOKS[lookKey] or LOOKS.arena
	local folder = New("Folder", { Name = "VenueBuild", Parent = Stage3D.venueFolder })
	local info = { folder = folder, look = L, parts = {}, base = {}, phase = {}, phones = {}, slots = 0 }
	local halfW, z0, z1
	if center then
		halfW = math.max(L.w, L.d) / 2
		z0, z1 = -halfW, halfW
	else
		halfW = L.w / 2
		z0, z1 = FLOOR_START, FLOOR_START + L.d + 22
	end
	local wallColor = Color3.fromRGB(16, 16, 22)
	local seatColor = Color3.fromRGB(48, 48, 60)
	local SEATS = { club = Color3.fromRGB(60, 40, 40), theatre = Color3.fromRGB(150, 30, 40), arena = Color3.fromRGB(30, 70, 150), amphi = Color3.fromRGB(120, 116, 104), stadium = Color3.fromRGB(170, 40, 40) }
	local seatRow = SEATS[lookKey] or SEATS.arena
	-- mixing desk (FOH) in the middle of the floor at end stages
	local foh = nil
	if not center and not opts.empty and (L.d or 0) >= 70 then
		local fz = z0 + (z1 - z0) * 0.6
		foh = { x = 0, z = fz, w = 14, d = 9 }
		Stage3D.block(folder, "FOHRiser", Vector3.new(14, 1.2, 9), CFrame.new(0, 0.6, fz), Color3.fromRGB(30, 30, 34))
		Stage3D.block(folder, "FOHDesk", Vector3.new(10, 1.6, 2.4), CFrame.new(0, 2, fz - 1.5), Color3.fromRGB(22, 22, 26))
		Stage3D.block(folder, "FOHFaders", Vector3.new(9.4, 0.15, 1.8), CFrame.new(0, 2.85, fz - 1.5), Color3.fromRGB(60, 120, 200), Enum.Material.Neon)
		Stage3D.block(folder, "FOHRoof", Vector3.new(15, 0.4, 10), CFrame.new(0, 9, fz), Color3.fromRGB(18, 18, 22))
		for _, cx in ipairs({ -6.8, 6.8 }) do
			for _, cz in ipairs({ -4.3, 4.3 }) do
				Stage3D.block(folder, "FOHPole", Vector3.new(0.4, 8, 0.4), CFrame.new(cx, 4.8, fz + cz), Color3.fromRGB(90, 92, 100), Enum.Material.Metal)
			end
		end
	end

	local floor = Stage3D.block(folder, "Floor", Vector3.new(halfW * 2, 0.2, z1 - z0), CFrame.new(0, 0.05, (z0 + z1) / 2), Color3.fromRGB(28, 28, 34), Enum.Material.Concrete)
	floor.CanCollide = false
	if lookKey == "stadium" then
		floor.Color = Color3.fromRGB(30, 70, 40)
		floor.Material = Enum.Material.Grass
	end
	if opts.standingColor then
		floor.Color = opts.standingColor
	end

	local function inPit(pos)
		for _, p in ipairs(opts.pits or {}) do
			local lp = p.cf:PointToObjectSpace(pos)
			if math.abs(lp.X) < p.w / 2 - 0.8 and math.abs(lp.Z) < p.d / 2 - 0.8 then
				return true
			end
		end
		return false
	end

	local slots = {} -- { pos = Vector3, rank = number } (lower rank = sold first)
	local sp = opts.empty and 1e9 or 3.4 -- empty hall (designer): no crowd slots needed
	for z = z0 + 2, z1 - 1, sp do
		for x = -halfW + 2, halfW - 2, sp do
			local px = x + (math.random() - 0.5) * 1.2
			local pz = z + (math.random() - 0.5) * 1.2
			-- nobody stands inside the stage
			local inFoh = foh and math.abs(px - foh.x) < foh.w / 2 + 1 and math.abs(pz - foh.z) < foh.d / 2 + 1
			inFoh = inFoh or (lookKey == "club" and px < -halfW + 8) -- keep the bar free
			if not inFoh and Stage3D.surfaceY(px, pz) < 0.5 and Stage3D.surfaceY(px + 1, pz + 1) < 0.5 and Stage3D.surfaceY(px - 1, pz - 1) < 0.5 then
				local pos = Vector3.new(px, 0.2, pz)
				local rank
				if inPit(pos) then
					rank = -1 + math.random() * 0.1
				elseif center then
					rank = math.sqrt(px * px + pz * pz) / halfW + math.random() * 0.3
				else
					rank = (pz - z0) / (z1 - z0) + math.random() * 0.3
				end
				table.insert(slots, { pos = pos, rank = rank })
			end
		end
	end

	-- stands: left/right along the floor, back behind it, and (center stage) also in front
	local sideT = center and math.max(L.side, L.back) or L.side
	local backT = center and sideT or L.back
	local sideOuter = halfW + sideT * TIER_DEPTH
	for i = 0, sideT - 1 do
		local h = TIER_STEP * (i + 1)
		local len = z1 - z0
		for _, sgn in ipairs({ -1, 1 }) do
			local x = sgn * (halfW + TIER_DEPTH / 2 + i * TIER_DEPTH)
			Stage3D.block(folder, "Tier", Vector3.new(TIER_DEPTH, h, len), CFrame.new(x, h / 2, (z0 + z1) / 2), seatColor, Enum.Material.SmoothPlastic)
			Stage3D.block(folder, "SeatRow", Vector3.new(1.2, 1.4, len), CFrame.new(x + sgn * (TIER_DEPTH / 2 - 0.8), h + 0.7, (z0 + z1) / 2), seatRow, Enum.Material.Fabric)
			for z = z0 + 2, z1 - 2, 4 do
				table.insert(slots, { pos = Vector3.new(x, h, z + math.random() * 0.6), rank = 0.6 + i / math.max(1, sideT) + math.random() * 0.3 })
			end
		end
	end
	local ends = center and { 1, -1 } or { 1 }
	for _, sgn in ipairs(ends) do
		for i = 0, backT - 1 do
			local h = TIER_STEP * (i + 1) + ((lookKey == "theatre") and 10 or 0)
			local zEdge = (sgn > 0) and z1 or z0
			local z = zEdge + sgn * (TIER_DEPTH / 2 + i * TIER_DEPTH)
			Stage3D.block(folder, "Tier", Vector3.new(sideOuter * 2, h, TIER_DEPTH), CFrame.new(0, h / 2, z), seatColor, Enum.Material.SmoothPlastic)
			Stage3D.block(folder, "SeatRow", Vector3.new(sideOuter * 2, 1.4, 1.2), CFrame.new(0, h + 0.7, z + sgn * (TIER_DEPTH / 2 - 0.8)), seatRow, Enum.Material.Fabric)
			for x = -sideOuter + 2, sideOuter - 2, 4 do
				table.insert(slots, { pos = Vector3.new(x + math.random() * 0.6, h, z), rank = 0.7 + i / math.max(1, backT) + math.random() * 0.3 })
			end
		end
	end
	info.slots = #slots

	-- walls / roof (indoor) or a low rim (outdoor)
	local wallH = L.roof or (TIER_STEP * math.max(sideT, backT) + 8)
	local zMax = z1 + backT * TIER_DEPTH + 2
	local zMin = center and (z0 - backT * TIER_DEPTH - 2) or math.min(-60, z0 - 50)
	local xOut = sideOuter + 2
	Stage3D.block(folder, "WallL", Vector3.new(2, wallH, zMax - zMin), CFrame.new(-xOut, wallH / 2, (zMin + zMax) / 2), wallColor)
	Stage3D.block(folder, "WallR", Vector3.new(2, wallH, zMax - zMin), CFrame.new(xOut, wallH / 2, (zMin + zMax) / 2), wallColor)
	Stage3D.block(folder, "WallBack", Vector3.new(xOut * 2, wallH, 2), CFrame.new(0, wallH / 2, zMax), wallColor)
	Stage3D.block(folder, "WallStage", Vector3.new(xOut * 2, wallH, 2), CFrame.new(0, wallH / 2, zMin), wallColor)
	if L.roof and not opts.noRoof then
		Stage3D.block(folder, "Roof", Vector3.new(xOut * 2, 2, zMax - zMin), CFrame.new(0, L.roof, (zMin + zMax) / 2), wallColor)
	end
	-- venue specific details
	local metal = Color3.fromRGB(90, 92, 100)
	if lookKey == "club" then
		-- bar along the side wall, wall speakers, low truss frame
		Stage3D.block(folder, "Bar", Vector3.new(4, 4, 26), CFrame.new(-xOut + 4, 2, z0 + 30), Color3.fromRGB(40, 26, 20), Enum.Material.WoodPlanks)
		Stage3D.block(folder, "BarTop", Vector3.new(4.4, 0.3, 26.4), CFrame.new(-xOut + 4, 4.15, z0 + 30), Color3.fromRGB(20, 20, 24), Enum.Material.Marble)
		Stage3D.block(folder, "BarNeon", Vector3.new(0.2, 0.3, 26), CFrame.new(-xOut + 6.1, 3.4, z0 + 30), Color3.fromRGB(255, 60, 170), Enum.Material.Neon)
		Stage3D.block(folder, "Shelf", Vector3.new(1, 6, 22), CFrame.new(-xOut + 1.6, 7, z0 + 30), Color3.fromRGB(30, 22, 18), Enum.Material.WoodPlanks)
		for i = 0, 9 do
			Stage3D.block(folder, "Bottle", Vector3.new(0.4, 1.2, 0.4), CFrame.new(-xOut + 1.8, 9.2, z0 + 21 + i * 2), Color3.fromRGB(60 + i * 15, 140, 90), Enum.Material.Glass)
		end
		for _, x in ipairs({ -1, 1 }) do
			Stage3D.block(folder, "WallSpeaker", Vector3.new(3, 4.5, 3), CFrame.new(x * (xOut - 3), 22, -6), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric)
			Stage3D.block(folder, "ClubTruss", Vector3.new(1.4, 1.4, 70), CFrame.new(x * 20, 30, z0 + 20), metal, Enum.Material.DiamondPlate)
		end
		Stage3D.block(folder, "ClubTrussX", Vector3.new(42, 1.4, 1.4), CFrame.new(0, 30, z0 + 40), metal, Enum.Material.DiamondPlate)
	elseif lookKey == "theatre" then
		Stage3D.block(folder, "BalconyLip", Vector3.new(sideOuter * 2, 2.5, 1), CFrame.new(0, 11.5, z1 + 0.5), Color3.fromRGB(120, 30, 36), Enum.Material.Fabric)
		Stage3D.block(folder, "BalconyGold", Vector3.new(sideOuter * 2, 0.3, 1.1), CFrame.new(0, 12.9, z1 + 0.5), Color3.fromRGB(210, 170, 70), Enum.Material.Metal)
		for _, x in ipairs({ -1, 1 }) do
			Stage3D.block(folder, "Curtain", Vector3.new(6, wallH - 4, 1), CFrame.new(x * (xOut - 4), (wallH - 4) / 2, -30), Color3.fromRGB(130, 18, 28), Enum.Material.Fabric)
		end
	elseif lookKey == "arena" and not center then
		-- centre-hung video cube over the floor
		local cz = z0 + (z1 - z0) * 0.45
		local cy = (L.roof or 90) - 22
		Stage3D.block(folder, "CubeFrame", Vector3.new(16, 9, 16), CFrame.new(0, cy, cz), Color3.fromRGB(20, 20, 24))
		for _, f in ipairs({ { 0, 8.1 }, { 0, -8.1 }, { 8.1, 0 }, { -8.1, 0 } }) do
			local sz = (f[1] == 0) and Vector3.new(14, 7, 0.2) or Vector3.new(0.2, 7, 14)
			Stage3D.block(folder, "CubeScreen", sz, CFrame.new(f[1], cy, cz + f[2]), Color3.fromRGB(40, 70, 140), Enum.Material.Neon)
		end
		Stage3D.block(folder, "CubeCable", Vector3.new(0.3, (L.roof or 90) - cy - 4.5, 0.3), CFrame.new(0, (cy + 4.5 + (L.roof or 90)) / 2, cz), metal, Enum.Material.Metal)
	elseif lookKey == "stadium" then
		-- roof canopies over the stands and four floodlight masts
		local rimY = TIER_STEP * math.max(sideT, backT) + 14
		for _, x in ipairs({ -1, 1 }) do
			Stage3D.block(folder, "Canopy", Vector3.new(sideT * TIER_DEPTH + 6, 1.5, z1 - z0), CFrame.new(x * (halfW + sideT * TIER_DEPTH / 2 + 2), rimY, (z0 + z1) / 2) * CFrame.Angles(0, 0, x * math.rad(-8)), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		end
		Stage3D.block(folder, "CanopyBack", Vector3.new(sideOuter * 2, 1.5, backT * TIER_DEPTH + 6), CFrame.new(0, rimY, z1 + backT * TIER_DEPTH / 2 + 2) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ z0 - 10, zMax - 4 }) do
				local mx = x * (xOut + 6)
				Stage3D.block(folder, "Mast", Vector3.new(2, rimY + 30, 2), CFrame.new(mx, (rimY + 30) / 2, z), metal, Enum.Material.Metal)
				Stage3D.block(folder, "Floodlight", Vector3.new(10, 6, 1), CFrame.new(mx, rimY + 32, z) * CFrame.Angles(0, math.atan2(-mx, (z0 + z1) / 2 - z), 0), Color3.fromRGB(255, 250, 230), Enum.Material.Neon)
			end
		end
	elseif lookKey == "amphi" then
		for i = 0, 7 do
			local x = -sideOuter + i * sideOuter / 3.5
			local tz = zMax + 8 + (i % 2) * 6
			Stage3D.block(folder, "Trunk", Vector3.new(1.5, 12, 1.5), CFrame.new(x, 6, tz), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
			local crown = Stage3D.block(folder, "Crown", Vector3.new(10, 10, 10), CFrame.new(x, 15, tz), Color3.fromRGB(40, 90, 50), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	end
	info.size = { halfW = halfW, floorEnd = z1, floorStart = z0, outer = math.max(sideOuter, zMax), height = wallH, center = center }

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
		local pos = slots[i].pos
		local shirt = SHIRTS[math.random(1, #SHIRTS)]
		if merchColor and math.random() < 0.25 then
			shirt = merchColor
		end
		local body = New("Part", {
			Name = "Fan",
			Size = Vector3.new(1.6, 2.8, 1),
			Color = shirt,
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)),
			Parent = folder,
		})
		local head = New("Part", {
			Name = "FanHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.3, 1.3),
			Color = People.SKINS[math.random(1, #People.SKINS)],
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			CastShadow = false,
			CFrame = CFrame.new(pos + Vector3.new(0, 3.45, 0)),
			Parent = folder,
		})
		local ph = math.random() * 6.28
		table.insert(info.parts, body)
		table.insert(info.base, body.CFrame)
		table.insert(info.phase, ph)
		table.insert(info.parts, head)
		table.insert(info.base, head.CFrame)
		table.insert(info.phase, ph)
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
				CFrame = CFrame.new(pos + Vector3.new(0.4, 5, 0)),
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
function Venue.animate(info, t, energy, speed, phonesOn)
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
