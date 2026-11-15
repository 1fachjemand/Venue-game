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
for _ = 1, 90 do MOCK.step(1 / 30) end
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
		if (cls == "Part" or cls == "Seat" or cls == "SpawnLocation") and d.Transparency < 0.99 and not d:FindFirstAncestor("People") and not d:FindFirstAncestor("Traffic") and not d:FindFirstAncestor("GuideArrow") then
			local shape = (rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block"
			local c = d.CFrame
			local t = { "hub", d.Name, shape, string.format("%.3f", d.Size.X), string.format("%.3f", d.Size.Y), string.format("%.3f", d.Size.Z), string.format("%.3f", c._p.X), string.format("%.3f", c._p.Y), string.format("%.3f", c._p.Z) }
			for i = 1, 9 do t[#t + 1] = string.format("%.5f", c._r[i]) end
			zl[#zl + 1] = table.concat(t, " ")
		end
	end
end
WRITEFILE(OUT_DIR .. "/parts.txt", table.concat(zl, "\n"))
-- people must not walk through things: sample every walking path against the parts of the building
local FLAT = { Floor = true, HallFloor = true, Sidewalk = true, SidewalkFar = true, Road = true, Curb = true, CurbFar = true, Ground = true, Crosswalk = true, LaneMark = true, OfficeRug = true, LoungeRug = true, MeetingCarpet = true, DoorMat = true, EntranceSill = true, TreePit = true, Spawn = true, Boundary = true }
local hits = {}
for wi, path in ipairs(Hub.WALKS) do
	for i = 2, #path do
		local a0, a1 = path[i - 1], path[i]
		local n = math.ceil((a1 - a0).Magnitude / 1)
		for k = 0, n do
			local pt = Hub.ORIGIN + a0:Lerp(a1, k / n)
			for _, d in ipairs(workspace.StarlightRecords:GetDescendants()) do
				if (d.ClassName == "Part" or d.ClassName == "Seat") and not FLAT[d.Name] and not d.Name:find("^Arc") and not d.Name:find("^Cont") then
					local cf, sz = d.CFrame, d.Size
					if cf.Position.Y - sz.Y / 2 < 6 and cf.Position.Y + sz.Y / 2 > 0.3 then
						for _, h in ipairs({ 1, 3, 5 }) do
							local lp = cf:PointToObjectSpace(pt + Vector3.new(0, h, 0))
							if math.abs(lp.X) < sz.X / 2 + 0.9 and math.abs(lp.Y) < sz.Y / 2 and math.abs(lp.Z) < sz.Z / 2 + 0.9 then
								hits[d.Name .. " (path " .. wi .. ")"] = true
							end
						end
					end
				end
			end
		end
	end
end
local hl = {}
for k in pairs(hits) do hl[#hl + 1] = k end
table.sort(hl)
print("walk path blocked by:", #hl == 0 and "nothing" or table.concat(hl, ", "))
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
	CFrame.lookAt(P(-100, 8, 76), P(-160, 6, 110)), -- 8 the western bend
	CFrame.lookAt(P(40, 8, 84), P(56, 5, 108)), -- 9 the pizza place
	CFrame.lookAt(P(-70, 7, 88), P(-78, 3, 102)), -- 10 cafe guests
	CFrame.lookAt(P(28, 7, 4), P(28, 3, -14)), -- 11 staff at their desks
	CFrame.lookAt(P(-63, 6, 28), P(-63, 3, 38)), -- 12 lounge sofa
	CFrame.lookAt(P(58, 7, -14), P(58, 4.5, -24)), -- 13 stage design workstation
	CFrame.lookAt(P(140, 8, 76), P(200, 6, 110)), -- 14 the eastern bend
}
local cs = {}
for _, c in ipairs(cams) do cs[#cs + 1] = cfs(c) end
WRITEFILE(OUT_DIR .. "/scene1.json", '{"parts":[' .. table.concat(items, ",") .. '],"cams":[' .. table.concat(cs, ",") .. ']}')
print("exported hub parts", #items)
