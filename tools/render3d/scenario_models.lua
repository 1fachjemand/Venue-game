-- Close-ups of single stage pieces from 4 sides (front, front-left high, side, back) for checking models.
-- SCENARIO_ARGS = comma separated group names (see MODELS below), OUT_DIR = where sceneN.json go.
--   SCENARIO_ARGS=rings,specials OUT_DIR=$D python3 tools/run_mock.py api_classes.lua tools/render3d/scenario_models.lua
-- Every group writes scene<k>.json (k = position in SCENARIO_ARGS) with 4 cameras around its pieces.
-- An entry may carry anim = { songFrac = 0.5 } (animated in the middle of its song).
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
local Stage3D = require(root.Client.Stage3D)
local Builder = require(root.Client.Builder)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 3)
for _ = 1, 40 do MOCK.step(0.05) end
MOCK.clickExact("Skip tutorial")
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local MODELS = SHARED_MODELS or {}
local list = {}
for name in string.gmatch(ARGS or "", "[^,]+") do table.insert(list, name) end
for k, name in ipairs(list) do
	local g = MODELS[name]
	if not g then error("no model group " .. name) end
	app.state.money = 90000000
	local items = {}
	for _, e in ipairs(g.items) do
		local c = {}
		for kk, v in pairs(e) do if kk ~= "anim" then c[kk] = v end end
		table.insert(items, c)
	end
	local d = GS.addDesign(app.state, "Models " .. k, items, g.class or "Stadium", "end")
	app:openDesigner(d.id)
	for _ = 1, 3 do MOCK.step(1 / 30) end
	for i, r in ipairs(Stage3D.items) do
		local e = g.items[i]
		if e and e.anim then
			if e.anim.rt then
				r.readySong, r.readyAt = e.play or 1, (e.anim.t or 30) - e.anim.rt
			end
			local ctx = { t = e.anim.t or 30, dt = 0.03, c1 = Color3.fromRGB(255, 60, 160), c2 = Color3.fromRGB(60, 200, 255), hit = {}, beat = 0, beatCount = 0, songNum = e.play or 1, songFrac = e.anim.songFrac or 0.5, intensity = 0.7 }
			for _ = 1, e.anim.frames or 1 do Builder.animate(r, ctx) end
		end
	end
	local parts = {}
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, d2 in ipairs(workspace.HeadlinerWorld:GetDescendants()) do
		local cls = d2.ClassName
		if (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 and d2.Name ~= "Ground" and not d2:FindFirstAncestor("VenueBuild") then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d2.Size, d2.Color
			table.insert(parts, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
			if d2:IsDescendantOf(Stage3D.designFolder) then
				local p = d2.CFrame.Position
				if math.abs(p.X) < 400 and math.abs(p.Z) < 400 then
					lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
					hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
				end
			end
		end
	end
	local c = g.center or (lo + hi) / 2
	local size = g.size or math.max(hi.X - lo.X, hi.Z - lo.Z, hi.Y - lo.Y, 8)
	local dist = size * (g.zoom or 0.62) + 3
	local cams = {
		CFrame.lookAt(c + Vector3.new(0, size * 0.25 + 2, dist), c),
		CFrame.lookAt(c + Vector3.new(-dist * 0.7, size * 0.55 + 4, dist * 0.7), c),
		CFrame.lookAt(c + Vector3.new(dist, size * 0.15 + 2, 0), c),
		CFrame.lookAt(c + Vector3.new(dist * 0.5, size * 0.3 + 3, -dist * 0.85), c),
	}
	local cs = {}
	for _, cc in ipairs(cams) do cs[#cs + 1] = cfs(cc) end
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(parts, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
	print("exported", k, name, #parts)
	MOCK.clickExact("DONE")
end
