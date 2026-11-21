-- Walking in a venue: under every seat (also in the upper tiers / balconies) there must be something solid,
-- so you never fall through. python3 tools/run_mock.py <api> tools/checks/scenario_walk_stands.lua
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local Stage3D = require(root.Client.Stage3D)
local Venue = require(root.Client.Venue)
Stage3D.init()
local bad = 0
for _, look in ipairs({ "club", "theatre", "arena", "amphi", "stadium" }) do
	Stage3D.setDesign({ class = (look == "stadium") and "Stadium" or "Arena", layout = "end", items = {} })
	local info = Venue.build(look, 1, Color3.new(1, 0, 0), { layout = "end" })
	Venue.makeWalkable(info, {})
	local solids = {}
	for _, d in ipairs(info.folder:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide and d.Name ~= "VenueBoundary" then
			table.insert(solids, d)
		end
	end
	local miss, n = 0, 0
	local examples = {}
	for _, sl in ipairs(info.slotsAll or {}) do
		n = n + 1
		local p = sl.pos
		local found = false
		for _, s in ipairs(solids) do
			local lp = s.CFrame:PointToObjectSpace(p + Vector3.new(0, -0.6, 0))
			if math.abs(lp.X) <= s.Size.X / 2 + 0.3 and math.abs(lp.Y) <= s.Size.Y / 2 + 0.8 and math.abs(lp.Z) <= s.Size.Z / 2 + 0.3 then
				found = true
				break
			end
		end
		if not found then
			miss = miss + 1
			if #examples < 4 then table.insert(examples, string.format("(%.0f,%.0f,%.0f)", p.X, p.Y, p.Z)) end
		end
	end
	print("[test]", look, "seats", n, "without floor", miss, table.concat(examples, " "))
	bad = bad + miss
	Venue.destroy(info)
end
if bad > 0 then MOCK.errors.stands = "seats without a solid floor" end
