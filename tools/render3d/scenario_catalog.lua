-- Exports catalog items in groups of six (built alone, side by side) for tools/render3d/view.html
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local Builder = require(root.Client.Builder)
local StageItems = require(root.Data.StageItems)
local function num(x) return string.format("%.2f", x) end
local function cfs(c)
	local r = c._r
	local t = { num(c._p.X), num(c._p.Y), num(c._p.Z) }
	for i = 1, 9 do t[#t + 1] = string.format("%.4f", r[i]) end
	return "[" .. table.concat(t, ",") .. "]"
end
local GROUPS = GROUPS or {
	{ "par", "moving", "beambar", "strobe", "blinder", "laser" },
	{ "followspot", "discoball", "uplight", "speakers", "amps", "congas" },
	{ "acoustic", "harp", "upright_bass", "strings", "horns", "choir" },
	{ "vintagecar", "motorbike", "throne", "hand", "swing", "fireworks" },
	{ "ferris", "rocket", "fountain", "lighthouse", "cloud", "rainbow" },
	{ "statue", "robotarm", "house", "skyline", "flowers", "tvstack" },
	{ "chair", "table", "plant", "tree", "bench", "streetlamp" },
	{ "scissor", "led", "ledtower", "portal", "arch", "neonstar" },
}
for gi, g in ipairs(GROUPS) do
	local items = {}
	local holder = Instance.new("Folder")
	holder.Parent = workspace
	for i, id in ipairs(g) do
		local def = StageItems.byId[id]
		local refs = Builder.build(def, { rec = { t = id }, color = Color3.fromRGB(255, 60, 170), artistName = "NOVA", preview = true })
		refs.model.Parent = holder
		local y = (def.mount == "rig") and 14 or 0
		Builder.place(refs, CFrame.new((i - 3.5) * 34, y, 0))
		pcall(function() Builder.animate(refs, { t = 1, dt = 0.03, c1 = Color3.fromRGB(255, 60, 170), c2 = Color3.fromRGB(60, 200, 255), hit = {}, beat = 0.5, beatCount = 1, liftT = 1, intensity = 1, sweep = 1, curtainT = 0, inflate = 0.5, scissorT = 0.6, seg = 1, artistPos = Vector3.new(0, 5, 20) }) end)
	end
	for _, d in ipairs(holder:GetDescendants()) do
		local cls = d.ClassName
		if (cls == "Part" or cls == "WedgePart") and d.Transparency < 0.99 then
			local shape = (cls == "WedgePart") and "Wedge" or ((rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Ellip" end end
			local s, c = d.Size, d.Color
			table.insert(items, string.format('{"s":"%s","z":[%s,%s,%s],"c":[%d,%d,%d],"m":"%s","t":%s,"f":%s}', shape, num(s.X), num(s.Y), num(s.Z), math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), d.Material.Name, num(d.Transparency), cfs(d.CFrame)))
		end
	end
	local cams = {}
	for i, id in ipairs(g) do
		local def = StageItems.byId[id]
		local big = ({ ferris = 1, rocket = 1, lighthouse = 1, statue = 1, robotarm = 1, skyline = 1, led = 1, ledtower = 1, portal = 1, swing = 1, rainbow = 1, harp = 1 })[id]
		local x = (i - 3.5) * 34
		local ty = (def.mount == "rig") and 10 or (big and 12 or 4)
		local dist = big and 46 or 18
		table.insert(cams, cfs(CFrame.lookAt(Vector3.new(x + dist * 0.35, ty + dist * 0.35, dist), Vector3.new(x, ty, 0))))
	end
	WRITEFILE(OUT_DIR .. "/scene" .. gi .. ".json", '{"parts":[' .. table.concat(items, ",") .. '],"fov":40,"bg":[40,44,60],"cams":[' .. table.concat(cams, ",") .. ']}')
	holder:Destroy()
	print("group", gi, #items)
end
