-- Exports the 7 main-menu scenes (parts + 8 camera positions) as JSON for tools/render3d/view.html
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local OUT = OUT_DIR .. "/"
local MenuScene = require(root.Client.MenuScene)
MenuScene.forceOrder = { 1, 2, 3, 4, 5, 6, 7, 1 }
MenuScene.start()
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local function export(k)
	local items = {}
	for _, d in ipairs(workspace.MenuScene:GetDescendants()) do
		local cls = d.ClassName
		if cls == "Part" or cls == "WedgePart" then
			local shape = "Block"
			if cls == "WedgePart" then shape = "Wedge" else
				local ok, sh = true, rawget(d, "__props") and d.__props.Shape
				if ok and sh then shape = sh.Name end
				for _, ch in ipairs(d:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			end
			local s, c = d.Size, d.Color
			table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Material.Name, num(d.Transparency), cfs(d.CFrame)))
		end
	end
	local cams = {}
	for i = 1, 8 do
		for _ = 1, (i == 1 and 10 or 60) do MOCK.step(0.1) end
		table.insert(cams, cfs(workspace.CurrentCamera.CFrame))
	end
	WRITEFILE(OUT .. "scene" .. k .. ".json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. table.concat(cams, ",") .. ']}')
	print("exported", k, #items)
end
for k = 1, 7 do
	export(k)
	-- finish this scene
	while workspace.MenuScene:FindFirstChild("Ground") == nil or true do
		local before = workspace.MenuScene
		MOCK.step(0.1)
		if workspace.MenuScene ~= before then break end
	end
end
