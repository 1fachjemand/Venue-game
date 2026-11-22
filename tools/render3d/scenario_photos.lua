-- Fan photos (Screens/SocialScreen.lua) as 3D scenes for tools/render3d/view.html: one scene per photo kind,
-- with the real stage of a tour. SCENARIO_ARGS = kinds (comma separated)
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
local SocialScreen = require(root.Client.Screens.SocialScreen)
local StageItems = require(root.Data.StageItems)
local Artists = require(root.Data.Artists)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
for _ = 1, 40 do MOCK.step(0.05) end
MOCK.clickExact("Skip tutorial")
local preset
for _, p in ipairs(StageItems.PRESETS) do if p.name == "Arena End Stage" then preset = p end end
local d = GS.addDesign(app.state, "Photo Stage", preset.items, "Arena", "end")
SocialScreen.app = app
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local holder = Instance.new("Frame")
holder.Parent = MOCK.playerGui
local k = 0
for kind in string.gmatch(ARGS or "stage", "[^,]+") do
	k = k + 1
	SocialScreen.realBudget = 1
	local vp = SocialScreen.photo(holder, Artists.byId.juno, 1000 + k * 7, kind, { designId = d.id, artistId = "juno" })
	local parts = {}
	for _, d2 in ipairs(vp:GetDescendants()) do
		local cls = d2.ClassName
		if (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d2.Size, d2.Color
			table.insert(parts, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
		end
	end
	local cam = vp.CurrentCamera
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"fov":' .. num(cam.FieldOfView) .. ',"parts":[' .. table.concat(parts, ",") .. '],"cams":[' .. cfs(cam.CFrame) .. ']}')
	print("exported photo", k, kind, #parts)
end
