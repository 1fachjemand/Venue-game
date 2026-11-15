-- The 3D world: ground, the build area of the current stage design, and the placed design items.
-- There is no fixed stage: everything (decks, catwalks, center stages) is built from items.
local Lighting = game:GetService("Lighting")
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local StageItems = require(Root.Data.StageItems)
local UI = require(Root.Client.UI)
local Builder = require(Root.Client.Builder)
local GS = require(Root.Logic.GameState)

local New = UI.New

local Stage3D = {}
Stage3D.items = {} -- list of refs currently placed
Stage3D.class = Config.STAGE_CLASS_BY_ID.Arena
Stage3D.layout = "end"

local function block(parent, name, size, cf, color, material, queryable)
	return New("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = true,
		CanTouch = false,
		CanQuery = queryable == true,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
end
Stage3D.block = block

function Stage3D.init()
	local old = workspace:FindFirstChild("HeadlinerWorld")
	if old then
		old:Destroy()
	end
	local world = New("Folder", { Name = "HeadlinerWorld", Parent = workspace })
	Stage3D.world = world
	Stage3D.ground = block(world, "Ground", Vector3.new(2048, 2, 2048), CFrame.new(0, -1, 0), Color3.fromRGB(22, 22, 26), Enum.Material.Concrete, true)
	Stage3D.grid = New("Folder", { Name = "Grid", Parent = world })
	Stage3D.designFolder = New("Folder", { Name = "Design", Parent = world })
	Stage3D.venueFolder = New("Folder", { Name = "Venue", Parent = world })
	Stage3D.peopleFolder = New("Folder", { Name = "People", Parent = world })
	Stage3D.setLighting("designer")
end

-- Build area of the current design: { minX, maxX, minZ, maxZ }
function Stage3D.bounds()
	local c = Stage3D.class
	if Stage3D.layout == "center" then
		return -c.center, c.center, -c.center, c.center
	end
	return c.minX, c.maxX, c.minZ, c.maxZ
end

function Stage3D.setDesign(design)
	Stage3D.design = design
	Stage3D.class = Config.STAGE_CLASS_BY_ID[(design and design.class) or "Arena"]
	Stage3D.layout = (design and design.layout) or "end"
end

-- Grid + glowing outline of the build area (designer only)
function Stage3D.showGrid(on)
	Stage3D.grid:ClearAllChildren()
	if not on then
		return
	end
	local x0, x1, z0, z1 = Stage3D.bounds()
	local step = (Stage3D.class.order >= 3) and 8 or 4
	for x = x0, x1, step do
		local p = block(Stage3D.grid, "GridX", Vector3.new(0.12, 0.05, z1 - z0), CFrame.new(x, 0.03, (z0 + z1) / 2), UI.Theme.accent2, Enum.Material.Neon)
		p.Transparency = 0.6
		p.CanCollide = false
	end
	for z = z0, z1, step do
		local p = block(Stage3D.grid, "GridZ", Vector3.new(x1 - x0, 0.05, 0.12), CFrame.new((x0 + x1) / 2, 0.03, z), UI.Theme.accent2, Enum.Material.Neon)
		p.Transparency = 0.6
		p.CanCollide = false
	end
	local gold = UI.Theme.gold
	block(Stage3D.grid, "Edge", Vector3.new(x1 - x0, 0.3, 0.5), CFrame.new((x0 + x1) / 2, 0.1, z0), gold, Enum.Material.Neon).CanCollide = false
	block(Stage3D.grid, "Edge", Vector3.new(x1 - x0, 0.3, 0.5), CFrame.new((x0 + x1) / 2, 0.1, z1), gold, Enum.Material.Neon).CanCollide = false
	block(Stage3D.grid, "Edge", Vector3.new(0.5, 0.3, z1 - z0), CFrame.new(x0, 0.1, (z0 + z1) / 2), gold, Enum.Material.Neon).CanCollide = false
	block(Stage3D.grid, "Edge", Vector3.new(0.5, 0.3, z1 - z0), CFrame.new(x1, 0.1, (z0 + z1) / 2), gold, Enum.Material.Neon).CanCollide = false
	if Stage3D.layout == "end" then
		-- arrow on the floor showing where the audience is
		local a = block(Stage3D.grid, "AudienceArrow", Vector3.new(6, 0.2, 14), CFrame.new(0, 0.1, z1 - 12), UI.Theme.accent, Enum.Material.Neon)
		a.Transparency = 0.4
		a.CanCollide = false
	end
end

function Stage3D.setLighting(mode)
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 100000
	Lighting.ClockTime = (mode == "show") and 0 or 14
	Stage3D.ground.Color = (mode == "show") and Color3.fromRGB(22, 22, 26) or Color3.fromRGB(78, 82, 92)
	if mode == "hub" then
		-- the label building on a sunny afternoon: bright inside, daylight through the big windows
		Lighting.ClockTime = 14.5
		Lighting.Brightness = 2.4
		Lighting.Ambient = Color3.fromRGB(150, 146, 140)
		Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 165)
		Lighting.EnvironmentDiffuseScale = 0.8
		Lighting.EnvironmentSpecularScale = 0.5
	elseif mode == "show" then
		Lighting.Brightness = 1.5
		Lighting.Ambient = Color3.fromRGB(62, 60, 80)
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 92)
		Lighting.EnvironmentDiffuseScale = 0.35
		Lighting.EnvironmentSpecularScale = 0.4
	else
		Lighting.Brightness = 3
		Lighting.Ambient = Color3.fromRGB(165, 165, 175)
		Lighting.OutdoorAmbient = Color3.fromRGB(160, 160, 170)
		Lighting.EnvironmentDiffuseScale = 0.6
		Lighting.EnvironmentSpecularScale = 0.5
	end
end

------------------------------------------------------------------ surfaces & placement
-- Parts you can stand on: the ground and every deck. `except` (refs) is left out (used while moving it).
function Stage3D.surfaceParts(except)
	local list = { Stage3D.ground }
	for _, r in ipairs(Stage3D.items) do
		if r ~= except and r.surfaces then
			for _, p in ipairs(r.surfaces) do
				table.insert(list, p)
			end
		end
	end
	return list
end

function Stage3D.raycast(origin, direction, except)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = Stage3D.surfaceParts(except)
	return workspace:Raycast(origin, direction, params)
end

function Stage3D.surfaceY(x, z, except)
	local hit = Stage3D.raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), except)
	if hit then
		return hit.Position.Y, hit.Instance
	end
	return 0, nil
end

function Stage3D.rigY()
	return Stage3D.class.rigY
end

-- World CFrame of an item. Floor items stand at rec.y (or on the surface below), rig items hang in the rig.
-- if (x, z) is close to a truss beam, move it onto the beam's centre line
function Stage3D.snapToTruss(x, z)
	for _, r in ipairs(Stage3D.items) do
		if r.kind == "truss_beam" then
			local lp = r.cf:PointToObjectSpace(Vector3.new(x, r.cf.Position.Y, z))
			local half = ((r.rec and r.rec.w) or 24) / 2
			if math.abs(lp.Z) < 5 and math.abs(lp.X) <= half + 1.5 then
				local wp = r.cf * Vector3.new(math.clamp(math.floor(lp.X + 0.5), -half, half), 0, 0)
				return wp.X, wp.Z, true
			end
		end
	end
	return x, z, false
end

-- side mounts: the closest Truss Tower within reach. Returns x, z (on the side of the tower that faces the
-- point), r (the item looks away from the tower), the tower's base height - or nil if no tower is near
Stage3D.TOWER_HALF = 1.05
function Stage3D.snapToTower(x, z, except)
	local best, bestD = nil, 9
	for _, t in ipairs(Stage3D.items) do
		if t.kind == "truss" and t ~= except then
			local p = t.cf.Position
			local d = math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2)
			if d < bestD then
				best, bestD = t, d
			end
		end
	end
	if not best then
		return nil
	end
	-- which side: the one of the four faces that points to the mouse (in the tower's own turn)
	local lp = best.cf:PointToObjectSpace(Vector3.new(x, best.cf.Position.Y, z))
	local dir
	if math.abs(lp.X) > math.abs(lp.Z) then
		dir = Vector3.new(lp.X >= 0 and 1 or -1, 0, 0)
	else
		dir = Vector3.new(0, 0, lp.Z >= 0 and 1 or -1)
	end
	local wp = best.cf * (dir * Stage3D.TOWER_HALF)
	local wd = best.cf:VectorToWorldSpace(dir)
	local r = math.floor(math.deg(math.atan2(wd.X, wd.Z)) + 0.5) % 360
	return wp.X, wp.Z, r, best.cf.Position.Y - (best.rec and best.rec.yo or 0)
end

-- Lines a new truss beam up with the nearest other beam: same direction (or square to it), on one line,
-- end to end or parallel at whole studs. returns x, z, r
function Stage3D.alignTruss(x, z, r, w, except)
	local best, bestD = nil, 40
	for _, o in ipairs(Stage3D.items) do
		if o.kind == "truss_beam" and o ~= except and o.rec then
			local lp = o.cf:PointToObjectSpace(Vector3.new(x, o.cf.Position.Y, z))
			local half = (o.rec.w or 24) / 2
			local dx = math.max(0, math.abs(lp.X) - half - w / 2)
			local d = math.sqrt(dx * dx + lp.Z * lp.Z)
			if d < bestD then
				best, bestD = o, d
			end
		end
	end
	if not best then
		return x, z, r
	end
	local orot = best.rec.r or 0
	local diff = ((r - orot) % 180 + 180) % 180
	local half = (best.rec.w or 24) / 2
	local lp = best.cf:PointToObjectSpace(Vector3.new(x, best.cf.Position.Y, z))
	local lx, lz = lp.X, lp.Z
	if diff < 25 or diff > 155 then
		-- parallel: on the same line (if close) or at a whole-stud distance; ends meet when they are close
		r = orot
		if math.abs(lz) < 5 then
			lz = 0
			local gap = math.abs(lx) - (half + w / 2)
			if math.abs(gap) < 4 then
				lx = (lx >= 0 and 1 or -1) * (half + w / 2)
			end
		else
			lz = math.floor(lz + 0.5)
			if math.abs(lx) < 3 then
				lx = 0
			end
		end
	elseif diff > 65 and diff < 115 then
		-- square to it: one end touches the other beam
		r = orot + 90
		if math.abs(lx) <= half + 2 then
			lx = math.floor(lx + 0.5)
			if math.abs(math.abs(lz) - w / 2) < 5 then
				lz = (lz >= 0 and 1 or -1) * w / 2
			end
		end
	else
		return x, z, r
	end
	local wp = best.cf * Vector3.new(lx, 0, lz)
	return wp.X, wp.Z, r % 360
end

function Stage3D.itemCFrame(def, rec, except)
	local y
	if def.mount == "rig" then
		-- truss beams sit at rig height, lights hang just below them
		y = Stage3D.rigY() - ((def.id == "truss_beam") and 0 or 2)
	else
		y = rec.y or Stage3D.surfaceY(rec.x, rec.z, except)
	end
	-- extra height set with the green (Y) arrow
	y = y + (rec.yo or 0)
	return CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, math.rad(rec.r or 0), 0)
end

function Stage3D.inBounds(x, z)
	local x0, x1, z0, z1 = Stage3D.bounds()
	return x >= x0 and x <= x1 and z >= z0 and z <= z1
end

-- opts: { color = Color3, artistName = string }
function Stage3D.addItem(rec, opts)
	local def = StageItems.byId[rec.t]
	if not def then
		return nil
	end
	local o = { color = opts and opts.color, artistName = opts and opts.artistName, rec = rec }
	local refs = Builder.build(def, o)
	Builder.place(refs, Stage3D.itemCFrame(def, rec))
	refs.rec = rec
	refs.model.Parent = Stage3D.designFolder
	Builder.rest(refs)
	table.insert(Stage3D.items, refs)
	Stage3D.numberSpots()
	return refs
end

function Stage3D.removeItem(refs)
	for i, r in ipairs(Stage3D.items) do
		if r == refs then
			table.remove(Stage3D.items, i)
			break
		end
	end
	refs.model:Destroy()
	Stage3D.numberSpots()
end

function Stage3D.clearDesign()
	for _, r in ipairs(Stage3D.items) do
		r.model:Destroy()
	end
	Stage3D.items = {}
end

-- Artist spots show their song number (lifts and instruments keep theirs, spots fill the free numbers)
function Stage3D.numberSpots(design)
	design = design or Stage3D.design
	local plan = GS.songPlan(design)
	for _, r in ipairs(Stage3D.items) do
		r.spotIndex = r.rec and plan.songOf[r.rec] or nil
	end
	for _, r in ipairs(Stage3D.items) do
		if r.kind == "spot" and r.label then
			r.label.Text = tostring(r.spotIndex or "?")
		end
	end
end

function Stage3D.renderDesign(design, opts)
	Stage3D.clearDesign()
	Stage3D.setDesign(design)
	if not design then
		return Stage3D.items
	end
	-- decks first (in their saved order) so other items can stand on them
	for _, rec in ipairs(design.items) do
		local def = StageItems.byId[rec.t]
		if def and def.deck then
			Stage3D.addItem(rec, opts)
		end
	end
	for _, rec in ipairs(design.items) do
		local def = StageItems.byId[rec.t]
		if def and not def.deck then
			Stage3D.addItem(rec, opts)
		end
	end
	Stage3D.numberSpots(design)
	return Stage3D.items
end

-- Finds the placed item a part belongs to
function Stage3D.itemFromPart(p)
	for _, r in ipairs(Stage3D.items) do
		if p:IsDescendantOf(r.model) then
			return r
		end
	end
	return nil
end

-- Bounding box of all decks: centre position on top, size. Used by the show camera and the crowd.
function Stage3D.deckBox()
	local x0, x1, z0, z1, top = math.huge, -math.huge, math.huge, -math.huge, 0
	for _, r in ipairs(Stage3D.items) do
		if r.surfaces then
			for _, p in ipairs(r.surfaces) do
				local pos, sz = p.Position, p.Size
				local ext = math.max(sz.X, sz.Y, sz.Z) / 2
				x0, x1 = math.min(x0, pos.X - ext), math.max(x1, pos.X + ext)
				z0, z1 = math.min(z0, pos.Z - ext), math.max(z1, pos.Z + ext)
				top = math.max(top, pos.Y + math.min(sz.X, sz.Y, sz.Z) / 2)
			end
		end
	end
	if x0 == math.huge then
		return Vector3.new(0, 0, 0), 20, 20, 0
	end
	return Vector3.new((x0 + x1) / 2, top, (z0 + z1) / 2), x1 - x0, z1 - z0, top
end

return Stage3D
