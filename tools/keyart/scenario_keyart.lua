-- Key art for the game page: runs a real live show in the mock and exports the scene at a few moments
-- (parts, light beams, lamps) as JSON for tools/keyart/keyart.html (three.js renderer with light and glow).
-- OUT_DIR=<dir> python3 tools/run_mock.py api_classes.lua tools/keyart/scenario_keyart.lua
math.randomseed(11)
-- the mock does not keep the values of colour / number sequences: remember them for the export
do
	local oldC, oldN = ColorSequence.new, NumberSequence.new
	ColorSequence.new = function(a, b)
		local r = oldC(a, b)
		rawset(r, "_c", (typeof(a) == "Color3") and a or a[1].Value)
		return r
	end
	NumberSequence.new = function(a, b)
		local r = oldN(a, b)
		if type(a) == "number" then
			rawset(r, "_v", { a, b or a })
		else
			local v = {}
			for _, kp in ipairs(a) do v[#v + 1] = kp.Value end
			rawset(r, "_v", v)
		end
		return r
	end
end
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
for k in pairs(require(root.Data.Audio).IDS) do require(root.Data.Audio).IDS[k] = 1000 end
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
local LiveShow = require(root.Client.LiveShow)
local app = App.instance
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
for _ = 1, 40 do MOCK.step(0.05) end
MOCK.clickExact("Skip tutorial")
for _ = 1, 4 do MOCK.step(0.05) end

local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local function col(c) return string.format("[%d,%d,%d]", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function vec(v) return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]" end
local function esc(s) return (tostring(s):gsub('[^%w_%- ]', "")) end
local function worldOf(att)
	local p = att.Parent
	if not (p and p:IsA("BasePart")) then return nil end
	return p.CFrame * att.Position
end
local function export(path, info)
	local count = 0
	local parts, beams, lights = {}, {}, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		local skip = d:FindFirstAncestor("StarlightRecords") or d:FindFirstAncestor("MenuScene")
		if not skip then
			local cls = d.ClassName
			if (cls == "Part" or cls == "WedgePart") and d.Transparency < 0.99 then
				local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block")
				for _, ch in ipairs(d:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
				local perf = d:FindFirstAncestor("Performer") and 1 or 0
				local s = d.Size
				parts[#parts + 1] = string.format('{"n":"%s","s":"%s","z":[%s,%s,%s],"c":%s,"m":"%s","t":%s,"p":%d,"f":%s}', esc(d.Name), shape, num(s.X), num(s.Y), num(s.Z), col(d.Color), d.Material.Name, num(d.Transparency), perf, cfs(d.CFrame))
			elseif cls == "Beam" and d.Enabled ~= false and d.Attachment0 and d.Attachment1 then
				local a, b = worldOf(d.Attachment0), worldOf(d.Attachment1)
				local c = d.Color and rawget(d.Color, "_c")
				local tv = d.Transparency and rawget(d.Transparency, "_v") or { 0.5 }
				if a and b and c then
					local tmin = 1
					for _, v in ipairs(tv) do tmin = math.min(tmin, v) end
					beams[#beams + 1] = string.format('{"n":"%s","a":%s,"b":%s,"w0":%s,"w1":%s,"c":%s,"t":%s}', esc(d.Name), vec(a), vec(b), num(d.Width0), num(d.Width1), col(c), num(tmin))
				end
			elseif (cls == "SpotLight" or cls == "PointLight" or cls == "SurfaceLight") and d.Enabled ~= false and d.Brightness > 0 then
				local p = d.Parent
				if p and p:IsA("BasePart") then
					local face = (cls == "SurfaceLight") and d.Face.Name or "Front"
					local dirs = { Front = Vector3.new(0, 0, -1), Back = Vector3.new(0, 0, 1), Top = Vector3.new(0, 1, 0), Bottom = Vector3.new(0, -1, 0), Left = Vector3.new(-1, 0, 0), Right = Vector3.new(1, 0, 0) }
					local dir = p.CFrame:VectorToWorldSpace(dirs[face] or Vector3.new(0, 0, -1))
					lights[#lights + 1] = string.format('{"k":"%s","p":%s,"d":%s,"c":%s,"b":%s,"r":%s,"a":%s}', cls, vec(p.CFrame.Position), vec(dir), col(d.Color), num(d.Brightness), num(d.Range), num((cls == "SpotLight") and d.Angle or 90))
				end
			end
		end
	end
	WRITEFILE(path, '{"info":' .. info .. ',"parts":[' .. table.concat(parts, ",") .. '],"beams":[' .. table.concat(beams, ",") .. '],"lights":[' .. table.concat(lights, ",") .. ']}')
	print("exported", path, #parts, "parts", #beams, "beams", #lights, "lights")
end

-- a big rock show for the picture: wide stage with runway, LED wall + side screens, three truss lines full of lights,
-- lasers, a light halo, flames, sparks, confetti
local function line(t, n, x0, x1, z, extra)
	local out = {}
	for i = 0, n - 1 do
		local rec = { t = t, x = math.floor(x0 + (x1 - x0) * (n > 1 and i / (n - 1) or 0.5) + 0.5), z = z, r = 0 }
		for k, v in pairs(extra or {}) do rec[k] = v end
		out[#out + 1] = rec
	end
	return out
end
local items = {
	{ t = "deck", x = 0, z = -8, r = 0, w = 76, d = 30, h = 6 },
	{ t = "spot", x = -20, z = -5, r = 0 }, { t = "spot", x = 20, z = -5, r = 0 }, { t = "spot", x = 0, z = -6, r = 0 }, { t = "spot", x = 0, z = 3, r = 0 },
	{ t = "led", x = 0, z = -22, r = 0, w = 60, d = 26 }, { t = "led_side", x = -48, z = -12, r = 0 }, { t = "led_side", x = 48, z = -12, r = 0 },
	{ t = "speakers", x = -42, z = 5, r = 0 }, { t = "speakers", x = 42, z = 5, r = 0 },
	{ t = "truss_beam", x = 0, z = -14, r = 0, w = 84 }, { t = "truss_beam", x = 0, z = 3, r = 0, w = 84 },
	{ t = "halo", x = 0, z = -6, r = 0, w = 22 },
	{ t = "laser", x = -18, z = -14, r = 0 }, { t = "laser", x = 18, z = -14, r = 0 },
	{ t = "pyro", x = -32, z = 5, r = 0 }, { t = "pyro", x = 32, z = 5, r = 0 }, { t = "pyro", x = -10, z = 5, r = 0 }, { t = "pyro", x = 10, z = 5, r = 0 },
	{ t = "sparks", x = -22, z = 6, r = 0 }, { t = "sparks", x = 22, z = 6, r = 0 },
	{ t = "co2", x = -14, z = 6, r = 0 }, { t = "co2", x = 14, z = 6, r = 0 },
	{ t = "confetti", x = -34, z = -20, r = 0 }, { t = "confetti", x = 34, z = -20, r = 0 },
}
for _, l in ipairs({ line("moving", 8, -36, 36, -14), line("beambar", 7, -33, 33, 3), line("par", 4, -24, 24, 3) }) do
	for _, r in ipairs(l) do items[#items + 1] = r end
end
local Venue = require(root.Client.Venue)
Venue.maxFigures = 6000
local SHOWS = { { key = "rock", artist = KEYART_ARTIST or "rusty", look = "arena" } }
for _, sh in ipairs(SHOWS) do
	app.state.money = 90000000
	local d = GS.addDesign(app.state, "Key Art", items, "Arena", "end")
	local done = false
	LiveShow.run(app, { artistId = sh.artist, design = d, look = sh.look, cap = 15000, sold = 15000, tourName = "Headliner", preview = true, onDone = function() done = true end })
	local nextT, k = KEYART_FROM or 70, 1
	local f = 0
	while not done and f < 40000 do
		MOCK.step(1 / 15)
		f = f + 1
		local t = LiveShow.debugT and LiveShow.debugT() or 0
		if t >= nextT then
			local leads = {}
			for _, m in ipairs(workspace:GetDescendants()) do
				if m.Name == "Performer" and m:FindFirstChild("Head") and math.abs(m.Head.CFrame.Position.X) < 600 then
					leads[#leads + 1] = vec(m.Head.CFrame.Position)
				end
			end
			export(OUT_DIR .. "/keyart_" .. sh.key .. "_" .. k .. ".json", string.format('{"t":%s,"performers":[%s]}', num(t), table.concat(leads, ",")))
			k = k + 1
			nextT = nextT + 2
		end
	end
end
print("KEYART DONE")
