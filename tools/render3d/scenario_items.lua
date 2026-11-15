-- Exports single stage items in close-up (for tools/render3d/view.html): instruments, lifts, effects, stadium pieces
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
local People = require(root.Client.People)
local Stage3D = require(root.Client.Stage3D)
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
local groups = {
	{ { t = "piano", x = -12, z = 0 }, { t = "drums", x = 2, z = -2 }, { t = "keys", x = 14, z = 0 }, { t = "guitarstand", x = 22, z = 2 } },
	{ { t = "lift", x = -14, z = 0, play = 2 }, { t = "poplift", x = 0, z = 0, play = 3 }, { t = "towerlift", x = 16, z = 0, play = 4 } },
	{ { t = "pyro", x = -12, z = 0 }, { t = "sparks", x = -4, z = 0 }, { t = "co2", x = 4, z = 0 }, { t = "confetti", x = 12, z = 0 } },
	{ { t = "stadiumroof", x = 0, z = -40 }, { t = "delaytower", x = 40, z = 60 } },
	{ { t = "harp", x = -16, z = 0, r = 90 }, { t = "column", x = -6, z = -4 }, { t = "giantguitar", x = 4, z = -4 }, { t = "drapes", x = 20, z = -6 } },
	{ { t = "truss", x = 0, z = 0 }, { t = "sidewash", x = 1.05, z = 0, r = 90, yo = 12, y = 0 }, { t = "sidebeam", x = -1.05, z = 0, r = 270, yo = 9, y = 0 }, { t = "sideblinder", x = 0, z = 1.05, r = 0, yo = 18, y = 0 }, { t = "sidespeaker", x = 0, z = 1.05, r = 0, yo = 30, y = 0 }, { t = "sidestrobe", x = 0, z = -1.05, r = 180, yo = 14, y = 0 } },
	{ { t = "band_drums", x = -16, z = -4 }, { t = "band_guitar", x = -6, z = 0 }, { t = "band_bass", x = 4, z = 0 }, { t = "band_keys", x = 14, z = 0 }, { t = "band_backing", x = 24, z = 2 }, { t = "curtain", x = 4, z = -14, w = 50, d = 16, cc = "purple" } },
	{ { t = "barrels", x = -16, z = 0 }, { t = "bookshelf", x = -6, z = -4 }, { t = "lanternline", x = 8, z = -6 }, { t = "golddiscs", x = 22, z = -2 }, { t = "plant", x = -12, z = 6 } },
}
for k, items in ipairs(groups) do
	app.state.money = 90000000
	local d = GS.addDesign(app.state, "Items " .. k, items, k == 4 and "Stadium" or "Arena", "end")
	app:openDesigner(d.id)
	for _ = 1, 3 do MOCK.step(1 / 30) end
	if k == 2 then
		-- half-way: lift doors folding, tower half up
		for _, r in ipairs(Stage3D.items) do
			if r.kind == "lift" then r.liftT = 0.15 end
			if r.kind == "poplift" then r.liftT = 0.6 end
			if r.kind == "towerlift" then r.towerT = 0.6 end
			require(root.Client.Builder).animate(r, { t = 0, c1 = Color3.fromRGB(255, 60, 160), c2 = Color3.fromRGB(60, 200, 255), hit = {}, beat = 0, beatCount = 0, liftT = 1 })
		end
	end
	if k == 1 then
		local g = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "guitar", 11)
		g:update(Vector3.new(30, 0, 4), 0, { t = 0, beat = 0, energy = 1, walking = false, armsUp = 0, move = "idle" })
	end
	local parts = {}
	for _, d2 in ipairs(workspace.HeadlinerWorld:GetDescendants()) do
		local cls = d2.ClassName
		if (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 and d2.Name ~= "Ground" and not d2:FindFirstAncestor("VenueBuild") then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d2.Size, d2.Color
			table.insert(parts, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
		end
	end
	local y = Stage3D.surfaceY(0, 0)
	local cams
	if k == 7 then
		cams = { CFrame.lookAt(Vector3.new(4, y + 16, 40), Vector3.new(4, y + 4, 0)), CFrame.lookAt(Vector3.new(-6, y + 8, 14), Vector3.new(-8, y + 3, 0)) }
	elseif k == 6 then
		cams = { CFrame.lookAt(Vector3.new(22, y + 26, 30), Vector3.new(0, y + 18, 0)), CFrame.lookAt(Vector3.new(-20, y + 14, 16), Vector3.new(0, y + 14, 0)) }
	elseif k >= 5 then
		cams = { CFrame.lookAt(Vector3.new(2, y + 14, 44), Vector3.new(2, y + 5, 0)), CFrame.lookAt(Vector3.new(-26, y + 8, 6), Vector3.new(-16, y + 4, 0)) }
	elseif k == 4 then
		cams = { CFrame.lookAt(Vector3.new(60, 60, 180), Vector3.new(0, 40, -30)), CFrame.lookAt(Vector3.new(60, 40, 90), Vector3.new(40, 25, 60)) }
	else
		cams = { CFrame.lookAt(Vector3.new(4, y + 12, 26), Vector3.new(4, y + 3, 0)), CFrame.lookAt(Vector3.new(-14, y + 9, 12), Vector3.new(-12, y + 3, 0)) }
		if k == 1 then cams[3] = CFrame.lookAt(Vector3.new(26, y + 6, 12), Vector3.new(26, y + 4, 2)) end
	end
	local cs = {}
	for _, c in ipairs(cams) do cs[#cs + 1] = cfs(c) end
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(parts, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
	print("exported", k, #parts)
	MOCK.clickExact("DONE")
end
