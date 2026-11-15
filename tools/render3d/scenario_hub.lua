-- Exports the label building "Starlight Records" (server parts + client parts) for tools/render3d/view.html
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
local Hub = require(root.World.Hub)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
MOCK.clickExact("Let's go!")
if HUB_SANDBOX then shared.HeadlinerServer.sessions[MOCK.player].state.stats.shows = 9 app:applyDelta(app:call("resync").delta) app.world.refresh() end
for _ = 1, 3 do MOCK.step(1 / 30) end
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local items = {}
local function add(folder)
	for _, d in ipairs(folder:GetDescendants()) do
		local cls = d.ClassName
		if (cls == "Part" or cls == "Seat" or cls == "SpawnLocation" or cls == "WedgePart") and d.Transparency < 0.99 and d.Name ~= "Ground" then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block")
			local s, c = d.Size, d.Color
			table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Material.Name, num(d.Transparency), cfs(d.CFrame)))
		end
	end
end
add(workspace.StarlightRecords)
add(workspace.HubClient)
-- the same parts as a list for tools/zfight/check.py
local zl = {}
for _, folder in ipairs({ workspace.StarlightRecords, workspace.HubClient }) do
	for _, d in ipairs(folder:GetDescendants()) do
		local cls = d.ClassName
		if (cls == "Part" or cls == "Seat" or cls == "SpawnLocation") and d.Transparency < 0.99 and not d:FindFirstAncestor("People") then
			local shape = (rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block"
			local c = d.CFrame
			local t = { "hub", d.Name, shape, string.format("%.3f", d.Size.X), string.format("%.3f", d.Size.Y), string.format("%.3f", d.Size.Z), string.format("%.3f", c._p.X), string.format("%.3f", c._p.Y), string.format("%.3f", c._p.Z) }
			for i = 1, 9 do t[#t + 1] = string.format("%.5f", c._r[i]) end
			zl[#zl + 1] = table.concat(t, " ")
		end
	end
end
WRITEFILE(OUT_DIR .. "/parts.txt", table.concat(zl, "\n"))
local O = Hub.ORIGIN
local function P(x, y, z) return O + Vector3.new(x, y, z) end
local cams = {
	CFrame.lookAt(P(0, 9, -26), P(0, 3, 10)), -- from the spawn to the map table
	CFrame.lookAt(P(14, 7, -24), P(14, 4, -40)), -- the desk
	CFrame.lookAt(P(-50, 10, 0), P(-63, 6, -30)), -- meeting room
	CFrame.lookAt(P(50, 16, 30), P(92, 8, -30)), -- stage hall
	CFrame.lookAt(P(0, 12, 0), P(-20, 9, -46)), -- charts wall
	CFrame.lookAt(P(40, 26, 96), P(0, 12, 46)), -- outside, from across the street
	CFrame.lookAt(P(-30, 9, 40), P(-70, 5, 25)), -- lounge
	CFrame.lookAt(P(0, 120, 30), P(10, 0, 0)), -- top
}
local cs = {}
for _, c in ipairs(cams) do cs[#cs + 1] = cfs(c) end
WRITEFILE(OUT_DIR .. "/scene1.json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
print("exported hub parts", #items)
