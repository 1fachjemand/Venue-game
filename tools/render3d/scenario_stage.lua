-- Exports the stage templates as they look in the stage builder (for tools/render3d/view.html)
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
local Designer = require(root.Client.Designer)
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
local k = 0
for _, p in ipairs(StageItems.PRESETS) do
	if p.shop then
		k = k + 1
		app.state.money = 9000000
		local d = GS.addDesignFromTemplate(app.state, p)
		app:openDesigner(d.id)
		for _ = 1, 3 do MOCK.step(1 / 30) end
		local items = {}
		for _, d2 in ipairs(workspace.HeadlinerWorld:GetDescendants()) do
			local cls = d2.ClassName
			if (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 and d2.Name ~= "Ground" then
				local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
				for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
				local s, c = d2.Size, d2.Color
				table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
			end
		end
		local cam = workspace.CurrentCamera.CFrame
		local reach = (p.class == "Stadium") and 230 or 120
		local look = CFrame.lookAt(Vector3.new(reach * 0.55, reach * 0.55, reach * (p.layout == "center" and 0.9 or 1.0)), Vector3.new(0, 10, p.layout == "center" and 0 or 0))
		WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. cfs(cam) .. "," .. cfs(look) .. ']}')
		print("exported", p.name, #items)
		MOCK.clickExact("DONE")
	end
end
