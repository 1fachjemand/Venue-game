-- Exports the small venue pictures of the tour planner (Client/VenueModels.lua) for view.html
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local VenueModels = require(root.Client.VenueModels)
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local types = { "Club", "Theatre", "Hall", "Arena", "Amphitheatre", "Stadium" }
for k, vt in ipairs(types) do
	local m = Instance.new("Model")
	m.Parent = workspace
	VenueModels.build(m, vt, Color3.fromRGB(37, 99, 235))
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		local cls = d.ClassName
		if cls == "Part" or cls == "WedgePart" then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d.Size, d.Color
			table.insert(parts, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Material.Name, num(d.Transparency), cfs(d.CFrame)))
		end
	end
	local dd = VenueModels.CAMERA[vt]
	local cam = CFrame.lookAt(Vector3.new(dd * 0.62, dd * 0.5, dd * 0.86), Vector3.new(0, dd * 0.08, 0))
	WRITEFILE(OUT_DIR .. "/scene" .. k .. ".json", '{"parts":[' .. table.concat(parts, ",") .. '],"cams":[' .. cfs(cam) .. ']}')
	print("exported", vt, #parts)
	m:Destroy()
end
