-- Exports the 3D world map of the tour planner (World, Europe and Latin America views)
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local App = require(root.Client.App)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
MOCK.clickExact("Let's go!")
MOCK.clickExact("+ PLAN A TOUR")
MOCK.clickExact("SELECT")
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local cams = {}
for _, view in ipairs({ "World", "Europe", "Latin America" }) do
	MOCK.clickExact(view)
	for _ = 1, 90 do MOCK.step(1 / 30) end
	table.insert(cams, cfs(workspace.CurrentCamera.CFrame))
end
local items = {}
for _, d in ipairs(workspace.WorldMap3D:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency < 0.99 then
		local s, c = d.Size, d.Color
		local shape = (rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block"
		table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Material.Name, num(d.Transparency), cfs(d.CFrame)))
	end
end
WRITEFILE(OUT_DIR .. "/scene1.json", '{"parts":[' .. table.concat(items, ",") .. '],"fov":50,"cams":[' .. table.concat(cams, ",") .. ']}')
print("map parts", #items)
