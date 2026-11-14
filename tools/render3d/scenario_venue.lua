-- Exports venue interiors with a crowd (for tools/render3d/view.html): arena end/center, stadium, theatre, club, amphi
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
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
MOCK.clickExact("Let's go!")
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
	{ "amphi", "Arena End Stage", "Arena", "end" },
}
Venue.maxFigures = 1100
for k, v in ipairs(list) do
	app.state.money = 90000000
	local p = preset(v[2])
	local d = GS.addDesign(app.state, v[2], p.items, v[3], v[4])
	app:openDesigner(d.id)
	for _ = 1, 3 do MOCK.step(1 / 30) end
	local crowd = Venue.build(v[1], 0.85, Color3.fromRGB(255, 80, 160), { layout = v[4] })
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
	local sz = crowd.size
	local o = sz.outer
	local cz = (sz.floorStart + sz.floorEnd) / 2
	local cams = {
		CFrame.lookAt(Vector3.new(o * 0.15, sz.height * 0.9, sz.floorEnd + o * 0.25), Vector3.new(0, 8, sz.center and 0 or -10)), -- from the back stands
		CFrame.lookAt(Vector3.new(-sz.halfW * 0.9, sz.height * 0.75, cz + 20), Vector3.new(sz.halfW * 0.3, 0, sz.center and 0 or -30)), -- from the side stands
		CFrame.lookAt(Vector3.new(0, 30, sz.center and 70 or 60), Vector3.new(0, 10, sz.center and 0 or -40)), -- from the floor to the stage (or the drapes)
		CFrame.lookAt(Vector3.new(0.1, o * 2.3, cz + 0.1), Vector3.new(0, 0, cz)), -- top-down
	}
	local cs = {}
	for _, c in ipairs(cams) do cs[#cs + 1] = cfs(c) end
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
	print("exported", v[1], v[4], #items, "fans", crowd.count, "slots", crowd.slots)
	Venue.destroy(crowd)
	MOCK.clickExact("DONE")
end
