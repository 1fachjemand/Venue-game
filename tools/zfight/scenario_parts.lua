-- Dumps every stage item (built alone at the origin) and the venue interiors as part lists for tools/zfight/check.py
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
local Venue = require(root.Client.Venue)
local function num(x) return string.format("%.3f", x) end
local out = {}
local function dump(group, inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if (d.ClassName == "Part" or d.ClassName == "WedgePart") and d.Transparency < 0.99 then
			local shape = (d.ClassName == "WedgePart") and "Wedge" or ((rawget(d, "__props") and d.__props.Shape and d.__props.Shape.Name) or "Block")
			for _, ch in ipairs(d:GetChildren()) do if ch.ClassName == "SpecialMesh" then shape = "Mesh" end end
			local c = d.CFrame
			local r = c._r
			local t = { group, d.Name, shape, num(d.Size.X), num(d.Size.Y), num(d.Size.Z), num(c._p.X), num(c._p.Y), num(c._p.Z) }
			for i = 1, 9 do t[#t + 1] = string.format("%.5f", r[i]) end
			out[#out + 1] = table.concat(t, " ")
		end
	end
end
for _, def in ipairs(StageItems.list) do
	if not def.hidden then
		local refs = Builder.build(def, { rec = { t = def.id }, preview = true })
		refs.model.Parent = workspace
		Builder.place(refs, CFrame.new())
		pcall(function() Builder.animate(refs, { t = 0, c1 = Color3.new(1, 0, 0), c2 = Color3.new(0, 0, 1), hit = {}, beat = 0, beatCount = 0, liftT = 1, intensity = 1, curtainT = 0, inflate = 0, scissorT = 0 }) end)
		dump("item:" .. def.id, refs.model)
		refs.model:Destroy()
	end
end
for _, look in ipairs({ "club", "theatre", "arena", "stadium", "amphi" }) do
	for _, layout in ipairs({ "end", "center" }) do
		local info = Venue.build(look, 0.5, Color3.new(1, 0, 1), { layout = layout })
		dump("venue:" .. look .. ":" .. layout, info.folder)
		Venue.destroy(info)
	end
end
WRITEFILE(OUT_DIR .. "/parts.txt", table.concat(out, "\n"))
print("parts dumped", #out)
