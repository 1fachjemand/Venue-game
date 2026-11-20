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
	Builder.rigTop = Stage3D.class.rigY - Stage3D.BEAM_DROP
end
-- truss beams hang with their bottom this far below the rig height: towers end there
Stage3D.BEAM_DROP = 1.9
Stage3D.TOWERS = { truss = 1.05, truss_xl = 2.1 } -- tower kinds and half their width (side mounts clamp there)
function Stage3D.isTower(r)
	return r ~= nil and Stage3D.TOWERS[r.kind] ~= nil
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

-- shows: a hazy hall (the beams glow in the dust), soft bloom around bright lights, a little contrast
local showFx = nil
local function setShowEffects(on)
	if on and not showFx then
		showFx = {
			atmosphere = Instance.new("Atmosphere"),
			bloom = Instance.new("BloomEffect"),
			cc = Instance.new("ColorCorrectionEffect"),
		}
		local a = showFx.atmosphere
		a.Name, a.Density, a.Offset, a.Color, a.Decay, a.Glare, a.Haze = "ShowHaze", 0.36, 0.05, Color3.fromRGB(52, 46, 62), Color3.fromRGB(24, 20, 30), 0, 2.2
		local b = showFx.bloom
		b.Name, b.Intensity, b.Size, b.Threshold = "ShowBloom", 0.8, 30, 1.3
		local c = showFx.cc
		c.Name, c.Contrast, c.Saturation, c.Brightness = "ShowColor", 0.1, 0.06, 0
	end
	if showFx then
		for _, fx in pairs(showFx) do
			fx.Parent = on and Lighting or nil
		end
	end
end

function Stage3D.setLighting(mode)
	setShowEffects(mode == "show")
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
		-- a show is dark, but the stage must always be easy to see (see also the stage wash in LiveShow)
		Lighting.Brightness = 1.7
		Lighting.Ambient = Color3.fromRGB(88, 86, 108)
		Lighting.OutdoorAmbient = Color3.fromRGB(92, 92, 116)
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
-- the Truss Tower closest to x, z (within 9 studs) or nil
-- every post a side mount can clamp onto: Truss Towers and the front columns of a Stadium Structure
-- returns a list of { refs, cf (post at its foot, in the item's turn), half (half the post's width) }
function Stage3D.mountPosts(except)
	local out = {}
	for _, t in ipairs(Stage3D.items) do
		if t ~= except then
			if Stage3D.TOWERS[t.kind] then
				table.insert(out, { refs = t, cf = t.cf, half = Stage3D.TOWERS[t.kind], base = t.cf.Position.Y - (t.rec and t.rec.yo or 0) })
			elseif t.mounts then
				for _, mp in ipairs(t.mounts) do
					local c = t.cf * mp.cf
					table.insert(out, { refs = t, cf = c, half = mp.half, base = c.Position.Y })
				end
			end
		end
	end
	return out
end
local function nearestPost(x, z, except)
	local best, bestD = nil, 9
	for _, p in ipairs(Stage3D.mountPosts(except)) do
		local q = p.cf.Position
		local d = math.sqrt((x - q.X) ^ 2 + (z - q.Z) ^ 2)
		if d < bestD then
			best, bestD = p, d
		end
	end
	return best
end
-- the post (tower) closest to x, z (within 9 studs) or nil: { refs, cf, half, base }
function Stage3D.nearestTower(x, z)
	return nearestPost(x, z)
end

function Stage3D.snapToTower(x, z, except)
	local best = nearestPost(x, z, except)
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
	local wp = best.cf * (dir * best.half)
	local wd = best.cf:VectorToWorldSpace(dir)
	local r = math.floor(math.deg(math.atan2(wd.X, wd.Z)) + 0.5) % 360
	return wp.X, wp.Z, r, best.base
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
	-- only when the beam is (almost) parallel or square to the other one: a beam turned on purpose
	-- (R / E, the orange ring) keeps its angle
	if diff < 3 or diff > 177 then
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
	elseif diff > 87 and diff < 93 then
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

-- A truss beam near Truss Towers: its ends click onto the middle of the towers. With a tower at both ends
-- it spans exactly from one to the other (centred, turned along the line). returns x, z, r, w (or nil)
function Stage3D.beamToTowers(x, z, r, w)
	local a = math.rad(r or 0)
	local dir = Vector3.new(math.cos(a), 0, -math.sin(a))
	local c = Vector3.new(x, 0, z)
	local function near(p, skip)
		local best, bestD = nil, 7
		for _, t in ipairs(Stage3D.items) do
			if Stage3D.TOWERS[t.kind] and t ~= skip then
				local q = t.cf.Position
				local d = (Vector3.new(q.X, 0, q.Z) - p).Magnitude
				if d < bestD then
					best, bestD = t, d
				end
			end
		end
		return best
	end
	local t1 = near(c - dir * w / 2)
	local t2 = near(c + dir * w / 2, t1)
	if t1 and t2 then
		local p1, p2 = t1.cf.Position, t2.cf.Position
		local d = Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z)
		if d.Magnitude < 4 then
			return nil
		end
		local nr = math.deg(math.atan2(-d.Z, d.X))
		-- keep the beam's own direction (no 180 degree flip)
		if math.abs(((nr - (r or 0)) % 360 + 540) % 360 - 180) > 90 then
			nr = nr + 180
		end
		nr = math.floor(nr * 2 + 0.5) / 2 % 360
		return (p1.X + p2.X) / 2, (p1.Z + p2.Z) / 2, nr, math.floor(d.Magnitude * 2 + 0.5) / 2
	end
	local t = t1 or t2
	if t then
		local q = t.cf.Position
		local sign = (t == t1) and 1 or -1
		local nc = Vector3.new(q.X, 0, q.Z) + dir * (w / 2) * sign
		return nc.X, nc.Z, r, w
	end
	return nil
end

function Stage3D.itemCFrame(def, rec, except)
	local y
	if def.mount == "rig" then
		-- truss beams sit at rig height, lights hang just below them
		y = Stage3D.rigY() - ((def.id == "truss_beam") and 0 or 2)
	elseif def.ground then
		y = 0 -- big structures always stand on the ground (never on a deck)
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
	if Stage3D.TOWERS[def.id] then
		o.rigTop = Stage3D.rigY() - Stage3D.BEAM_DROP - Stage3D.surfaceY(rec.x, rec.z) - (rec.yo or 0)
	end
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
			local m = r.rec and plan.momentOf[r.rec]
			-- a moment inside a song: "2.5" (or "2.25", "2.75")
			r.label.Text = m and tostring(m):gsub("%.?0+$", "") or tostring(r.spotIndex or "?")
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
