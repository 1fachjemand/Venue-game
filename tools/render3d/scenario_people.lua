-- A line of figures with every hair style (and some hats) for tools/render3d/view.html
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local People = require(root.Client.People)
local folder = Instance.new("Folder")
folder.Parent = workspace
local styles = { "short", "messy", "long", "bun", "pony", "pigtails", "afro", "buzz", "mohawk" }
local hairs = { { 30, 22, 18 }, { 200, 160, 90 }, { 120, 60, 30 }, { 240, 200, 120 }, { 20, 20, 20 }, { 255, 120, 180 }, { 40, 30, 26 }, { 90, 60, 40 }, { 230, 40, 60 } }
for i, st in ipairs(styles) do
	local f = People.new(folder, Color3.fromRGB(80, 90, 200), 1.4, "dancer", i, { hair = st, hairColor = hairs[i], skin = (i % 5) + 1 })
	f:update(Vector3.new((i - 5) * 5, 0, 0), 0.35, { t = 1, beat = 0, energy = 0, walking = false, move = "idle" })
end
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local parts = {}
for _, d2 in ipairs(folder:GetDescendants()) do
	local cls = d2.ClassName
	if (cls == "Part" or cls == "WedgePart") and d2.Transparency < 0.99 then
		local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d2, "__props") and d2.__props.Shape and d2.__props.Shape.Name) or "Block")
		for _, ch in ipairs(d2:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
		local s, c = d2.Size, d2.Color
		table.insert(parts, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d2.Material.Name, num(d2.Transparency), cfs(d2.CFrame)))
	end
end
local cams = { cfs(CFrame.lookAt(Vector3.new(-8, 7.2, 11), Vector3.new(-8, 6.2, 0))), cfs(CFrame.lookAt(Vector3.new(8, 7.2, 11), Vector3.new(8, 6.2, 0))), cfs(CFrame.lookAt(Vector3.new(-4, 8, -10), Vector3.new(-4, 6.2, 0))) }
WRITEFILE(OUT_DIR .. "/scene1.json", '{"parts":[' .. table.concat(parts, ",") .. '],"cams":[' .. table.concat(cams, ",") .. ']}')
print("exported people", #parts)
