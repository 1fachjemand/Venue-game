-- Exports venue interiors with a crowd (for tools/render3d/view.html): arena end/center, stadium, theatre, club, amphi
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local server = MOCK.newRaw("Script")
server.__props.Name = "GameServer"
rawset(server, "__path", SERVER_PATH)
MOCK.runScript(server)
MOCK.runTasks()
game:GetService("Players").PlayerAdded:Fire(MOCK.player)
MOCK.runTasks()
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local App = require(root.Client.App)
local GS = require(root.Logic.GameState)
local StageItems = require(root.Data.StageItems)
local Venue = require(root.Client.Venue)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 3)
for _ = 1, 40 do MOCK.step(0.05) end MOCK.clickExact("Skip tutorial")
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local function preset(name)
	for _, p in ipairs(StageItems.PRESETS) do if p.name == name then return p end end
end
local list = {
	{ "arena", "Arena End Stage", "Arena", "end" },
	{ "arena", "Center Stage", "Arena", "center" },
	{ "stadium", "Runway & Moon", "Stadium", "end" },
	{ "theatre", "Club Stage", "Theatre", "end" },
	{ "club", "Club Stage", "Club", "end" },
	{ "amphi", "Arena End Stage", "Arena", "end", "rock" },
	{ "amphi", "Arena End Stage", "Arena", "end", "forest" },
	{ "amphi", "Arena End Stage", "Arena", "end", "city" },
}
Venue.maxFigures = 1100
local only = {}
for n in string.gmatch(ARGS or "", "[^,]+") do only[tonumber(n)] = true end
for k, v in ipairs(list) do if next(only) == nil or only[k] then
	app.state.money = 90000000
	local p = preset(v[2])
	local d = GS.addDesign(app.state, v[2], p.items, v[3], v[4])
	app:openDesigner(d.id)
	for _ = 1, 3 do MOCK.step(1 / 30) end
	local crowd = Venue.build(v[1], 0.85, Color3.fromRGB(255, 80, 160), { layout = v[4], amphi = v[5] })
	local items = {}
	for _, d2 in ipairs(workspace.HeadlinerWorld:GetDescendants()) do
		local cls = d2.ClassName
		local vb = d2:FindFirstAncestor("VenueBuild")
		local skip = vb and vb ~= crowd.folder
		if not skip and (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 and d2.Name ~= "Ground" then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d2.Size, d2.Color
			table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
		end
	end
	-- end stages: no coloured seat block may reach behind the side drapes (z < 2), no black one in front
	if v[4] == "end" and (v[1] == "arena" or v[1] == "stadium") then
		local worst, worstD = 99, -99
		for _, d2 in ipairs(crowd.folder:GetDescendants()) do
			if d2.Name == "Tier" or d2.Name == "DrapedTier" then
				local cf, s2 = d2.CFrame, d2.Size
				local zmin, zmax = 1e9, -1e9
				for _, sx in ipairs({ -1, 1 }) do for _, sz2 in ipairs({ -1, 1 }) do
					local wp = cf * Vector3.new(sx * s2.X / 2, 0, sz2 * s2.Z / 2)
					zmin, zmax = math.min(zmin, wp.Z), math.max(zmax, wp.Z)
				end end
				if d2.Name == "Tier" then worst = math.min(worst, zmin) else worstD = math.max(worstD, zmax) end
			end
		end
		print("seat blocks: front-most coloured z", string.format("%.2f", worst), "back-most black z", string.format("%.2f", worstD))
	end
	local sz = crowd.size
	local o = sz.outer
	local cz = (sz.floorStart + sz.floorEnd) / 2
	local cams = {
		CFrame.lookAt(Vector3.new(o * 0.15, sz.height * 0.9, sz.floorEnd + o * 0.25), Vector3.new(0, 8, sz.center and 0 or -10)), -- from the back stands
		CFrame.lookAt(Vector3.new(-sz.halfW * 0.9, sz.height * 0.75, cz + 20), Vector3.new(sz.halfW * 0.3, 0, sz.center and 0 or -30)), -- from the side stands
		CFrame.lookAt(Vector3.new(0, 30, sz.center and 70 or 60), Vector3.new(0, 10, sz.center and 0 or -40)), -- from the floor to the stage (or the drapes)
		CFrame.lookAt(Vector3.new(o * 1.2, o * 1.4, cz + o * 1.6), Vector3.new(0, 0, cz)), -- outside view
		CFrame.lookAt(Vector3.new(6, 6, sz.floorEnd - 8), Vector3.new(0, 14, sz.center and 0 or -10)), -- 4: standing at the back of the floor
		CFrame.lookAt(Vector3.new(-sz.halfW * 0.5, 6, cz), Vector3.new(sz.halfW * 0.3, sz.height * 0.8, cz + 20)), -- 5: looking up at the roof
		CFrame.lookAt(Vector3.new(sz.halfW * 0.3, 10, 34), Vector3.new(-sz.halfW - 10, 10, -4)), -- 6: the side drape next to the stage
		CFrame.lookAt(Vector3.new(-sz.halfW * 0.3, 8, sz.floorEnd - 24), Vector3.new(sz.halfW + 2, 8, sz.floorEnd + 2)), -- 7: a back corner
	}
	local cs = {}
	for _, c in ipairs(cams) do cs[#cs + 1] = cfs(c) end
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
	print("exported", v[1], v[4], #items, "fans", crowd.count, "slots", crowd.slots)
	Venue.destroy(crowd)
	MOCK.clickExact("DONE")
end end
