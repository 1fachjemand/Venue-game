-- Where the artist can walk on the stage: a grid over all decks (2 studs per cell). The artist only walks
-- where there is a deck and steps up/down small heights (stairs). Used by the show (LiveShow) and by the
-- stage builder, so the golden path in SETLIST & SHOW shows the real way.
local Root = script:FindFirstAncestor("Headliner")
local Stage3D = require(Root.Client.Stage3D)

local StageNav = {}
-- the biggest step up or down the artist takes without stairs (a stair step is about 1 stud): a higher deck
-- is only reached over Stairs
StageNav.STEP = 1.6

function StageNav.new()
	-- grid over all decks (2 studs per cell); the artist only walks where there is a deck
	-- and can only step up/down small heights (stairs). Unreachable spots are reached "backstage".
	local NAV = 2
	local navC, navW, navD = Stage3D.deckBox()
	local nx0, nz0 = navC.X - navW / 2 - 2, navC.Z - navD / 2 - 2
	local ncols, nrows = math.max(1, math.ceil((navW + 4) / NAV)), math.max(1, math.ceil((navD + 4) / NAV))
	local navH, navStair = {}, {}
	local function cellH(i, j)
		local key = i * 10000 + j
		local h = navH[key]
		if h == nil then
			-- a cell counts as stage if the centre or a point near it is on a deck (small gaps between decks are fine)
			local cx, cz = nx0 + (i + 0.5) * NAV, nz0 + (j + 0.5) * NAV
			local inst
			h, inst = Stage3D.surfaceY(cx, cz)
			if h < 0.5 then
				for _, o in ipairs({ { 0.8, 0 }, { -0.8, 0 }, { 0, 0.8 }, { 0, -0.8 } }) do
					local h2, i2 = Stage3D.surfaceY(cx + o[1], cz + o[2])
					if h2 > h then
						h, inst = h2, i2
					end
				end
			end
			navH[key] = h
			navStair[key] = inst ~= nil and inst.Name == "Step"
		end
		return h
	end
	-- a step between two cells: small steps anywhere, bigger ones only on Stairs
	local function canStep(i, j, ni, nj)
		local h, nh = cellH(i, j), cellH(ni, nj)
		if nh <= 0.5 then
			return false
		end
		local diff = math.abs(nh - h)
		if diff <= StageNav.STEP then
			return true
		end
		return diff <= 4.2 and (navStair[i * 10000 + j] or navStair[ni * 10000 + nj])
	end
	local function cellOf(p)
		return math.clamp(math.floor((p.X - nx0) / NAV), 0, ncols - 1), math.clamp(math.floor((p.Z - nz0) / NAV), 0, nrows - 1)
	end
	local function findPath(from, to)
		local si, sj = cellOf(from)
		local ti, tj = cellOf(to)
		if si == ti and sj == tj then
			return { from, to }
		end
		if ncols * nrows > 40000 then
			return nil
		end
		local prev, queue, head = {}, { si * 10000 + sj }, 1
		prev[si * 10000 + sj] = -1
		local goal = ti * 10000 + tj
		while queue[head] do
			local key = queue[head]
			head = head + 1
			if key == goal then
				break
			end
			local i, j = math.floor(key / 10000), key % 10000
			local h = cellH(i, j)
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
				local ni, nj = i + d[1], j + d[2]
				local nk = ni * 10000 + nj
				if ni >= 0 and nj >= 0 and ni < ncols and nj < nrows and not prev[nk] then
					local ok = canStep(i, j, ni, nj)
					if ok and d[1] ~= 0 and d[2] ~= 0 then
						-- no cutting corners over gaps
						ok = cellH(i + d[1], j) > 0.5 and cellH(i, j + d[2]) > 0.5
					end
					if ok then
						prev[nk] = key
						table.insert(queue, nk)
					end
				end
			end
		end
		if not prev[goal] then
			return nil
		end
		local cells = {}
		local k = goal
		while k ~= -1 do
			table.insert(cells, 1, k)
			k = prev[k]
		end
		local pts = { from }
		for n = 2, #cells - 1 do
			local i, j = math.floor(cells[n] / 10000), cells[n] % 10000
			table.insert(pts, Vector3.new(nx0 + (i + 0.5) * NAV, cellH(i, j), nz0 + (j + 0.5) * NAV))
		end
		table.insert(pts, to)
		return pts
	end

	-- the same way with fewer corners: points are skipped while the straight line between stays on the stage
	local function clearLine(a, b)
		local d = b - a
		local n = math.max(1, math.ceil(d.Magnitude / (NAV * 0.5)))
		local h0 = nil
		for k = 0, n do
			local p = a + d * (k / n)
			local i, j = cellOf(p)
			local h = cellH(i, j)
			if h <= 0.5 then
				return false
			end
			if h0 and math.abs(h - h0) > StageNav.STEP then
				return false
			end
			h0 = h
		end
		return true
	end
	local function smooth(pts)
		if not pts or #pts <= 2 then
			return pts
		end
		local out = { pts[1] }
		local k = 1
		while k < #pts do
			local far = k + 1
			for m = #pts, k + 2, -1 do
				if clearLine(pts[k], pts[m]) then
					far = m
					break
				end
			end
			table.insert(out, pts[far])
			k = far
		end
		return out
	end
	local function walkable(p)
		local i, j = cellOf(p)
		local h = cellH(i, j)
		return h > 0.5 and math.abs(h - p.Y) < StageNav.STEP + 0.1, Vector3.new(nx0 + (i + 0.5) * NAV, h, nz0 + (j + 0.5) * NAV)
	end
	return { findPath = findPath, cellH = cellH, cellOf = cellOf, smooth = smooth, walkable = walkable, NAV = NAV, navC = navC, navW = navW, navD = navD }
end

return StageNav
