-- Checks the live "fans" screen scene (Client/LiveFeed.lua): no two fans / figures may run into each other
-- at any time (bodies, heads, arms, phones, light sticks). python3 tools/run_mock.py <api> tools/checks/scenario_livefeed.lua
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local LiveFeed = require(root.Client.LiveFeed)
local vp = Instance.new("ViewportFrame")
local cam = Instance.new("Camera")
cam.Parent = vp
local face = { live = vp, liveCam = cam, seed = 1 }
local feed = LiveFeed.new({ performers = {}, color = Color3.fromRGB(255, 100, 180) })
-- owner of every part: a crowd fan (table) or a People figure (model)
local function owners()
	local own = {}
	local sc = face.scene
	for i, f in ipairs(sc.fans) do
		for _, p in ipairs({ f.body, f.head, f.armL, f.armR, f.stick }) do
			own[p] = "fan" .. i
		end
	end
	for gi, g in ipairs(sc.groups) do
		for fi, fo in ipairs(g.figs) do
			for _, p in ipairs(fo.fig.model:GetDescendants()) do
				if p:IsA("BasePart") then
					own[p] = "g" .. gi .. "f" .. fi
				end
			end
			if fo.phone then own[fo.phone] = "g" .. gi .. "f" .. fi end
		end
	end
	return own
end
local function box(p)
	-- axis aligned box of a (maybe turned) part, a little smaller (touching is fine)
	local cf, s = p.CFrame, p.Size * 0.45
	local lo, hi = nil, nil
	for _, c in ipairs({ { 1, 1, 1 }, { -1, -1, -1 }, { 1, -1, 1 }, { -1, 1, -1 }, { 1, 1, -1 }, { -1, -1, 1 }, { 1, -1, -1 }, { -1, 1, 1 } }) do
		local w = cf * Vector3.new(s.X * c[1], s.Y * c[2], s.Z * c[3])
		lo = lo and Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z)) or w
		hi = hi and Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z)) or w
	end
	return lo, hi
end
local worst, hits, seen = 0, 0, {}
for k = 0, 600 do
	local t = k / 20
	feed:update(face, "liveCrowd", { t = t, c1 = Color3.new(1, 0, 0), c2 = Color3.new(0, 0, 1), beat = (t * 2) % 1, phones = (k % 200) > 100, crowdEnergy = 1 })
	if k % 4 == 0 then
		local own = owners()
		local list = {}
		for p, o in pairs(own) do
			local lo, hi = box(p)
			table.insert(list, { p = p, o = o, lo = lo, hi = hi })
		end
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				if a.o ~= b.o and a.lo.X < b.hi.X and b.lo.X < a.hi.X and a.lo.Y < b.hi.Y and b.lo.Y < a.hi.Y and a.lo.Z < b.hi.Z and b.lo.Z < a.hi.Z then
					hits = hits + 1
					local key = a.o .. "/" .. b.o .. ":" .. a.p.Name .. "/" .. b.p.Name
					if not seen[key] then
						seen[key] = t
						print("[overlap]", key, "t", t)
					end
				end
			end
		end
	end
end
print("[test]", "overlaps", hits)
if hits > 0 then
	MOCK.errors.livefeed = "fans run into each other on the live screen"
end
