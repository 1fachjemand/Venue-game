-- STAGE BUILDER: build a stage in 3D.
-- Works like park builder games: pick an item in the catalog at the bottom, click into the world to put it down,
-- line it up with the coloured gizmo (red = X, green = height, blue = Z, orange ring = turn, gold cubes = size)
-- and confirm with the green tick. Click a placed item to select and change it.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local StageItems = require(Root.Data.StageItems)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Builder = require(Root.Client.Builder)
local Stage3D = require(Root.Client.Stage3D)
local SoundFX = require(Root.Client.SoundFX)

local T = UI.Theme
local Designer = {}

-- a typical venue size per stage class (for the quality preview)
local CLASS_CAP = { Club = 400, Theatre = 3000, Arena = 18000, Stadium = 70000 }
local CLASS_LOOK = { Club = "club", Theatre = "theatre", Arena = "arena", Stadium = "stadium" }
local CLASS_DIST = { Club = 75, Theatre = 105, Arena = 160, Stadium = 250 }
local CLASS_MAXDIST = { Club = 110, Theatre = 150, Arena = 240, Stadium = 360 }
Designer.CLASS_CAP = CLASS_CAP
Designer.CLASS_LOOK = CLASS_LOOK

local AXIS = {
	x = Color3.fromRGB(235, 70, 60),
	y = Color3.fromRGB(90, 210, 80),
	z = Color3.fromRGB(60, 140, 255),
	rot = Color3.fromRGB(255, 150, 40),
	size = Color3.fromRGB(255, 205, 60),
}
local GRIDS = { 1, 2, 4, 8 }
local TURNS = { 15, 45, 90 }
local BLACK = Color3.new(0, 0, 0)
local GEOMETRY_KEYS = { w = true, d = true, h = true, skin = true, edge = true, scr = true, cc = true, anim = true }
-- settings that only change the show (no new model needed)
local SHOW_KEYS = { play = true, songs = true, cs = true, anim = true }
-- effects that can fire in chosen songs (rec.songs = { 1, 4, ... }; false / nil = automatic)
local FX_SONG_KINDS = { pyro = true, sparks = true, confetti = true, streamers = true, co2 = true, fireworks = true, balls = true, laser = true, lowfog = true }
Designer.FX_SONG_KINDS = FX_SONG_KINDS

local HELP = table.concat({
	"<b>Place</b>   pick an item below, point at the spot and press  <b>Q</b>  (or click, then Q / Enter)",
	"<b>Line up</b>   drag the arrows: <font color='#eb463c'>red</font> / <font color='#3c8cff'>blue</font> move, <font color='#5ad250'>green</font> lifts it up / down. A click never moves a piece",
	"<b>Turn</b>   drag the <font color='#ff9628'>orange ring</font> or press R (E = other way)      <b>Size</b>   drag the <font color='#ffcd3c'>gold cubes</font>",
	"<b>Select</b>   click a placed item, <b>Shift + click</b> more items (a group)      <b>Copy</b>  C (same place)      <b>Mirror</b>  M      <b>Delete</b>  X",
	"<b>Size</b>   pulls one side (the top cube: height); hold <b>Shift</b> to grow both sides      <b>Cancel</b>  Esc / F      Side lights clamp onto Truss Towers, R takes them round the tower",
	"<b>Camera</b>   right mouse = turn, wheel = zoom, WASD = move, T = top view, H = hide menus",
	"<b>Two steps</b>   1. build the stage   2. SETLIST & SHOW: artist spots, what screens show, effects per song",
}, "\n")

function Designer.open(app, designId)
	local state = app.state
	local design = GS.getDesign(state, designId) or state.designs[1]
	local self = { app = app, design = design, conns = {} }
	Designer.current = self
	app:enterMode("designer")
	Stage3D.setLighting("designer")

	local signed = GS.signedArtists(state)
	self.previewIndex = 1
	local function previewArtist()
		return signed[math.clamp(self.previewIndex, 1, math.max(1, #signed))]
	end
	local function itemOpts()
		local ad = previewArtist()
		return { color = ad and UI.rgb(ad.color) or T.accent, artistName = ad and string.upper(ad.name) or "YOUR ARTIST" }
	end

	------------------------------------------------------------ build state
	local mode = "idle" -- "idle" | "place" (piece follows the mouse) | "pending" (put down, waiting for the tick) | "selected"
	local placeDef, ghostRec, ghost, ghostKey = nil, nil, nil, nil
	local pending = nil -- refs of a piece that is not bought yet
	local selected = nil -- refs of a bought piece
	local group = nil -- 2+ bought pieces chosen with Shift + click (moved, copied, mirrored, deleted together)
	local groupBoxes = {}
	local lastSettings = {}
	local gridIndex, turnIndex = 1, 1
	local focus = Vector3.new(0, 6, 0)
	local yaw, pitch, dist = 0, 0.6, 150
	local rotating = false
	local overHandle = false
	local drag = nil
	local screenSong = 0 -- 0 = what screens show for the whole show, n = change for song n
	local copyPick = nil -- choosing screens that get the same settings: { src = rec, recs = { [rec] = true }, boxes = {} }
	local phase = "build" -- "build" (the stage itself) | "show" (setlist & show: spots, screens, effects per song)

	local function grid()
		return GRIDS[gridIndex]
	end
	local function snapG(v)
		return math.floor(v / grid() + 0.5) * grid()
	end

	local selHighlight = UI.New("Highlight", { FillColor = T.gold, FillTransparency = 0.7, OutlineColor = T.gold, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = Stage3D.world })
	local hoverHighlight = UI.New("Highlight", { FillColor = Color3.new(1, 1, 1), FillTransparency = 0.85, OutlineColor = Color3.new(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = Stage3D.world })
	local pendingHighlight = UI.New("Highlight", { FillColor = Color3.fromRGB(60, 255, 120), FillTransparency = 0.7, OutlineColor = Color3.fromRGB(120, 255, 160), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = Stage3D.world })

	local function resetCamera()
		local x0, x1, z0, z1 = Stage3D.bounds()
		focus = Vector3.new((x0 + x1) / 2, 6, self.design.layout == "center" and 0 or (z0 + (z1 - z0) * 0.3))
		dist = CLASS_DIST[self.design.class] or 150
		yaw, pitch = 0, 0.6
	end

	local Venue = require(Root.Client.Venue)
	local venuePreview = nil
	local setGroup
	local function render()
		local keepRec = selected and selected.rec
		local keepGroup = {}
		for _, g in ipairs(group or {}) do
			keepGroup[g.rec] = true
		end
		Stage3D.renderDesign(self.design, itemOpts())
		Stage3D.showGrid(true)
		selected = nil
		local newGroup = {}
		for _, r in ipairs(Stage3D.items) do
			if keepRec and r.rec == keepRec then
				selected = r
			end
			if keepGroup[r.rec] then
				table.insert(newGroup, r)
			end
		end
		if group and setGroup then
			setGroup(newGroup)
		end
		-- an empty venue of this size around the stage, so you can see where the fans stand
		local sig = self.design.class .. self.design.layout
		for _, rec in ipairs(self.design.items) do
			local def = StageItems.byId[rec.t]
			if def and def.deck then
				sig = sig .. "|" .. rec.t .. rec.x .. "," .. rec.z .. "," .. tostring(rec.r) .. tostring(rec.w) .. tostring(rec.d) .. tostring(rec.h) .. tostring(rec.y) .. tostring(rec.yo)
			end
		end
		if venuePreview and sig == self.venueSig then
			return
		end
		self.venueSig = sig
		if venuePreview then
			Venue.destroy(venuePreview)
		end
		venuePreview = Venue.build(CLASS_LOOK[self.design.class] or "arena", 0, nil, { empty = true, layout = self.design.layout, noRoof = true, standingColor = Color3.fromRGB(70, 96, 120) })
	end
	Stage3D.setDesign(self.design)
	render()
	resetCamera()

	------------------------------------------------------------ UI layout
	local root = UI.New("Frame", { Parent = app.canvas, Size = UI.px(1920, 1080), BackgroundTransparency = 1, Name = "Designer" })
	self.root = root

	-- top bar
	local top = UI.New("Frame", { Parent = root, Size = UI.px(1920, 64), BackgroundColor3 = T.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true })
	UI.New("Frame", { Parent = top, Position = UI.px(0, 62), Size = UI.px(1920, 2), BackgroundColor3 = T.accent, BorderSizePixel = 0 })
	-- the buttons start right of Roblox's own buttons in the top left corner
	local topInner = UI.New("Frame", { Parent = top, Position = UI.px(math.max(0, (app.safeX or 16) - 16), 0), Size = UI.px(1760, 64), BackgroundTransparency = 1 })

	-- stats line under the top bar (solid and dark text, so it is easy to read over the stage)
	local statsBar = UI.New("Frame", { Parent = root, Position = UI.px(0, 64), Size = UI.px(1920, 36), BackgroundColor3 = T.bg, BackgroundTransparency = 0.02, BorderSizePixel = 0, Active = true })
	UI.New("Frame", { Parent = statsBar, Position = UI.px(0, 35), Size = UI.px(1920, 1), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	local statsLbl = UI.Label(statsBar, "", UI.px(20, 0), UI.px(1600, 36), { textSize = 16, rich = true, color = T.text })
	-- money (right end of the stats line)
	UI.Label(statsBar, "YOUR MONEY", UI.px(1620, 0), UI.px(120, 36), { textSize = 13, color = T.sub, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	local moneyLbl = UI.Label(statsBar, "", UI.px(1746, 0), UI.px(160, 36), { textSize = 22, font = UI.FontBlack, color = T.good, alignX = Enum.TextXAlignment.Right })

	-- catalog at the bottom: category tabs + a row of item cards
	local catalog = UI.New("Frame", { Parent = root, Position = UI.px(0, 868), Size = UI.px(1920, 212), BackgroundColor3 = T.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, Active = true })
	UI.New("Frame", { Parent = catalog, Size = UI.px(1920, 2), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	local tabs = UI.New("Frame", { Parent = catalog, Position = UI.px(16, 8), Size = UI.px(1400, 36), BackgroundTransparency = 1 })
	UI.List(false, 6).Parent = tabs
	local cardRow = UI.New("ScrollingFrame", {
		Parent = catalog,
		Position = UI.px(12, 50),
		Size = UI.px(1896, 156),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = T.stroke,
	})
	UI.List(false, 8).Parent = cardRow
	local catHint = UI.Label(catalog, "", UI.px(1430, 8), UI.px(474, 36), { textSize = 14, color = T.sub, alignX = Enum.TextXAlignment.Right })

	-- tool bar above the catalog (like the build bar in park games)
	local toolbar = UI.Panel(root, UI.px(560, 800), UI.px(800, 58), T.panel)
	toolbar.BackgroundTransparency = 0.08
	UI.List(false, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = toolbar

	-- inspector (right): only when a piece is selected or being placed
	local inspector = UI.Panel(root, UI.px(1580, 112), UI.px(324, 676), T.panel)
	inspector.BackgroundTransparency = 0.05
	local inspScroll = UI.Scroll(inspector, UI.px(0, 0), UI.px(324, 676))
	UI.Padding(14, 14, 12, 12).Parent = inspScroll
	UI.List(true, 8).Parent = inspScroll

	-- help popup + price tag at the mouse
	local helpBox = UI.Panel(root, UI.px(20, 112), UI.px(900, 236), T.panel)
	helpBox.Visible = false
	UI.Label(helpBox, HELP, UI.px(18, 10), UI.px(864, 216), { textSize = 15, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	local priceTag = UI.New("TextLabel", {
		Parent = root,
		Size = UI.px(150, 26),
		BackgroundColor3 = Color3.fromRGB(10, 12, 20),
		BackgroundTransparency = 0.2,
		Text = "",
		TextColor3 = T.good,
		TextSize = 16,
		Font = UI.FontBold,
		Visible = false,
		UI.Corner(6),
	})
	-- SETLIST & SHOW (second step): the songs on the left
	local setlistPanel = UI.Panel(root, UI.px(20, 112), UI.px(430, 740), T.panel)
	setlistPanel.BackgroundTransparency = 0.05
	setlistPanel.Visible = false
	local dialog = nil
	local panels = { top, statsBar, catalog, toolbar, inspector, helpBox, setlistPanel }

	local currentCat = "Stage"
	local refreshStats, refreshList, refreshTop, refreshInspector, refreshToolbar, refreshSetlist
	local putDown

	------------------------------------------------------------ helpers
	local function cls()
		return Config.STAGE_CLASS_BY_ID[self.design.class]
	end

	local function defaultsFor(def)
		local s = lastSettings[def.id]
		if s then
			return Util.deepCopy(s)
		end
		local rec = { t = def.id, r = 0 }
		if def.size then
			rec.w = def.size.w
			rec.d = def.size.d
		end
		if def.heights then
			rec.h = def.h
		end
		if def.mount == "side" then
			rec.yo = 14 -- up on the tower
		end
		return rec
	end

	local function clearGhost()
		if ghost then
			ghost.model:Destroy()
			ghost = nil
			ghostKey = nil
		end
	end

	local function clearPending()
		local had = pending ~= nil
		if pending then
			pending.model:Destroy()
			pending = nil
		end
		pendingHighlight.Enabled = false
		if had then
			Stage3D.numberSpots(self.design)
		end
	end

	local function target()
		return pending or selected
	end

	local function mouseOverUI()
		if app.modalOpen then
			return true
		end
		local m = UserInputService:GetMouseLocation()
		local all = { top, statsBar, catalog, toolbar, inspector, helpBox, setlistPanel }
		if dialog then
			table.insert(all, dialog)
		end
		for _, p in ipairs(all) do
			if p.Parent and p.Visible then
				local a, s = p.AbsolutePosition, p.AbsoluteSize
				if m.X >= a.X and m.X <= a.X + s.X and m.Y >= a.Y and m.Y <= a.Y + s.Y then
					return true
				end
			end
		end
		return false
	end

	local function mouseRay()
		local m = UserInputService:GetMouseLocation()
		return workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
	end

	-- floor/deck point under the mouse (snapped to the grid)
	-- rig items: the point where the mouse ray meets the rig height (not the floor far below),
	-- so the piece hangs exactly under the cursor. returns x, z (and r for truss beams that line up)
	local function mousePoint(except, def, rec)
		local ray = mouseRay()
		local x, z
		if def and def.mount == "rig" then
			local y = Stage3D.rigY() - ((def.id == "truss_beam") and 0 or 2) + ((rec and rec.yo) or 0)
			if math.abs(ray.Direction.Y) < 1e-4 then
				return nil
			end
			local k = (y - ray.Origin.Y) / ray.Direction.Y
			if k <= 0 then
				return nil
			end
			local p = ray.Origin + ray.Direction * k
			x, z = snapG(p.X), snapG(p.Z)
		else
			local hit = Stage3D.raycast(ray.Origin, ray.Direction * 3000, except)
			if not hit then
				return nil
			end
			x, z = snapG(hit.Position.X), snapG(hit.Position.Z)
		end
		if def and def.mount == "side" then
			-- side mounts clamp onto the closest Truss Tower (returns nil when there is none)
			local hit = Stage3D.raycast(ray.Origin, ray.Direction * 3000, except)
			local sx, sz, sr, sy = Stage3D.snapToTower(hit and hit.Position.X or x, hit and hit.Position.Z or z, except)
			if not sx then
				return x, z, nil, nil, false
			end
			return sx, sz, sr, sy, true
		end
		if def and def.mount == "rig" and def.id ~= "truss_beam" then
			x, z = Stage3D.snapToTruss(x, z) -- lights click onto truss beams
		elseif def and def.id == "truss_beam" and rec then
			local r
			x, z, r = Stage3D.alignTruss(x, z, rec.r or 0, rec.w or (def.size and def.size.w) or 24, except)
			return x, z, r
		end
		return x, z
	end

	local function itemUnderMouse()
		local ray = mouseRay()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Stage3D.designFolder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
		return hit and Stage3D.itemFromPart(hit.Instance) or nil
	end

	-- items standing on a deck move together with it
	local function itemsOnDeck(deckRefs)
		local out = {}
		if not deckRefs.surfaces then
			return out
		end
		for _, r in ipairs(Stage3D.items) do
			if r ~= deckRefs and r.def.mount ~= "rig" then
				local _, inst = Stage3D.surfaceY(r.rec.x, r.rec.z)
				for _, p in ipairs(deckRefs.surfaces) do
					if inst == p then
						table.insert(out, r.rec)
					end
				end
			end
		end
		return out
	end

	local function spotRecs()
		local out = {}
		for _, rec in ipairs(self.design.items) do
			if rec.t == "spot" then
				table.insert(out, rec)
			end
		end
		return out
	end

	-- the design as it would be with the pending piece (song numbers while placing)
	local function withPending()
		if not pending then
			return self.design
		end
		local items = {}
		for _, it in ipairs(self.design.items) do
			table.insert(items, it)
		end
		table.insert(items, pending.rec)
		return { items = items }
	end
	local function relabelSpots()
		Stage3D.numberSpots(withPending())
		if pending and pending.def.id == "spot" and pending.label then
			pending.label.Text = tostring(GS.songPlan(withPending()).songOf[pending.rec] or "?")
		end
	end

	------------------------------------------------------------ pending piece (put down, not bought yet)
	local function floorY(rec, def)
		if def.mount == "side" then
			-- on a tower: the height is the tower's foot (+ "Lift up")
			local sx, sz, sr, sy = Stage3D.snapToTower(rec.x, rec.z)
			if sx then
				rec.x, rec.z, rec.y = sx, sz, sy
				if rec.r == nil then
					rec.r = sr
				end
			elseif rec.y == nil then
				rec.y = Stage3D.surfaceY(rec.x, rec.z)
			end
		elseif def.mount ~= "rig" then
			rec.y = Stage3D.surfaceY(rec.x, rec.z)
		end
	end

	local function buildPending(rec)
		local def = StageItems.byId[rec.t]
		if pending then
			pending.model:Destroy()
		end
		local o = itemOpts()
		pending = Builder.build(def, { color = o.color, artistName = o.artistName, rec = rec })
		pending.rec = rec
		Builder.place(pending, Stage3D.itemCFrame(def, rec))
		Builder.rest(pending)
		pending.model.Parent = Stage3D.world
		relabelSpots()
		pendingHighlight.Adornee = pending.model
		pendingHighlight.Enabled = true
	end

	local function placePending()
		if pending then
			Builder.place(pending, Stage3D.itemCFrame(pending.def, pending.rec))
		end
	end

	local function setMode(newMode, def)
		clearGhost()
		if newMode ~= "pending" then
			clearPending()
		end
		mode = newMode
		if newMode == "place" then
			placeDef = def
			ghostRec = defaultsFor(def)
			selected = nil
		elseif newMode == "idle" then
			placeDef = nil
			selected = nil
		end
		refreshList()
		refreshInspector()
		refreshToolbar()
	end

	-- marks the screens chosen for "Copy to chosen screens"
	local function drawCopyPick()
		for _, b in ipairs(copyPick and copyPick.boxes or {}) do
			b:Destroy()
		end
		if not copyPick then
			return
		end
		copyPick.boxes = {}
		for _, r in ipairs(Stage3D.items) do
			if copyPick.recs[r.rec] or r.rec == copyPick.src then
				local src = r.rec == copyPick.src
				table.insert(copyPick.boxes, UI.New("SelectionBox", { Adornee = r.model, Color3 = src and T.accent or T.accent2, LineThickness = 0.12, SurfaceColor3 = T.accent2, SurfaceTransparency = src and 1 or 0.75, Parent = Stage3D.world }))
			end
		end
	end
	local function endCopyPick()
		if copyPick then
			for _, b in ipairs(copyPick.boxes) do
				b:Destroy()
			end
			copyPick = nil
		end
	end
	self.endCopyPick = endCopyPick
	self.copyPickToggle = function(hit)
		if copyPick and hit and Builder.SCREEN_KINDS[hit.def.id] and hit.rec ~= copyPick.src then
			copyPick.recs[hit.rec] = (not copyPick.recs[hit.rec]) or nil
			drawCopyPick()
			if refreshInspector then
				refreshInspector()
			end
		end
	end
	local function select(refs)
		endCopyPick()
		drag = nil
		overHandle = false
		clearGhost()
		clearPending()
		if group then
			setGroup({})
		end
		selected = refs
		placeDef = nil
		mode = refs and "selected" or "idle"
		screenSong = 0
		refreshList()
		refreshInspector()
		refreshToolbar()
	end

	------------------------------------------------------------ groups (Shift + click)
	setGroup = function(list)
		for _, b in ipairs(groupBoxes) do
			b:Destroy()
		end
		groupBoxes = {}
		group = (#list >= 2) and list or nil
		for _, r in ipairs(group or {}) do
			table.insert(groupBoxes, UI.New("SelectionBox", { Adornee = r.model, Color3 = T.gold, LineThickness = 0.1, SurfaceColor3 = T.gold, SurfaceTransparency = 0.85, Parent = Stage3D.world }))
		end
	end
	local function toggleInGroup(hit)
		local list = {}
		for _, r in ipairs(group or (selected and { selected } or {})) do
			if r ~= hit then
				table.insert(list, r)
			end
		end
		local was = false
		for _, r in ipairs(group or (selected and { selected } or {})) do
			if r == hit then
				was = true
			end
		end
		if not was then
			table.insert(list, hit)
		end
		if #list == 0 then
			select(nil)
		elseif #list == 1 then
			select(list[1])
		else
			clearPending()
			clearGhost()
			placeDef = nil
			mode = "selected"
			selected = list[#list]
			setGroup(list)
			refreshList()
			refreshInspector()
			refreshToolbar()
		end
	end
	-- the pieces a tool works on: the group, or the one selected piece
	local function chosen()
		if group then
			return group
		end
		return selected and { selected } or {}
	end

	-- buys copies of recs (already moved where they go) and selects them
	local function buyCopies(recs, what)
		local total, made = 0, {}
		for _, rec in ipairs(recs) do
			if #self.design.items >= cls().maxItems then
				app:toast("This " .. self.design.class .. " stage is full (" .. cls().maxItems .. " items).", T.warn)
				break
			end
			local def = StageItems.byId[rec.t]
			local ok, msg = GS.buyItem(state, self.design, rec)
			if not ok then
				app:toast(msg, T.bad)
				break
			end
			total = total + Sim.itemPrice(def, rec)
			made[rec] = true
		end
		if next(made) == nil then
			return
		end
		SoundFX.sfx("place", 0.7)
		selected = nil
		setGroup({})
		render()
		local list = {}
		for _, r in ipairs(Stage3D.items) do
			if made[r.rec] then
				table.insert(list, r)
			end
		end
		if #list == 1 then
			select(list[1])
		else
			mode = "selected"
			selected = list[#list]
			setGroup(list)
		end
		refreshStats()
		refreshInspector()
		refreshToolbar()
		app:toast(what .. ": " .. #list .. (#list == 1 and " item" or " items") .. (total > 0 and (" for " .. Util.money(total)) or "") .. ". Drag the arrows to move them.", T.good)
	end
	local function freshCopy(rec)
		local c = Util.deepCopy(rec)
		c.uid = nil
		return c
	end
	-- copies of the chosen pieces in the same place (pull them out with an arrow: they stay in line)
	local function copyGroup()
		local recs = {}
		for _, r in ipairs(chosen()) do
			table.insert(recs, freshCopy(r.rec))
		end
		buyCopies(recs, "Copied")
	end
	-- copies on the other side of the stage's centre line (x = 0), turned the other way round
	local function mirrorChosen()
		local recs = {}
		for _, r in ipairs(chosen()) do
			if math.abs(r.rec.x) >= 0.5 then
				local c = freshCopy(r.rec)
				c.x = -c.x
				c.r = (360 - (c.r or 0)) % 360
				table.insert(recs, c)
			end
		end
		if #recs == 0 then
			app:toast("These items are on the centre line already: nothing to mirror.", T.warn)
			return
		end
		buyCopies(recs, "Mirrored to the other side")
	end
	local function deleteGroup()
		local list = group
		setGroup({})
		selected = nil
		for _, r in ipairs(list) do
			GS.sellItem(state, self.design, r.rec)
		end
		SoundFX.sfx("delete", 0.6)
		render()
		mode = "idle"
		refreshStats()
		refreshInspector()
		refreshToolbar()
	end

	-- the green tick: buy the pending piece
	local function confirm()
		if not pending then
			return
		end
		local rec = pending.rec
		local def = pending.def
		if #self.design.items >= cls().maxItems then
			app:toast("This " .. self.design.class .. " stage is full (" .. cls().maxItems .. " items).", T.warn)
			return
		end
		if def.id == "spot" and #spotRecs() >= StageItems.MAX_SPOTS then
			app:toast("A setlist has at most " .. StageItems.MAX_SPOTS .. " songs (artist spots).", T.warn)
			return
		end
		if not Stage3D.inBounds(rec.x, rec.z) then
			app:toast("Outside the build area (gold lines).", T.warn)
			return
		end
		clearPending()
		floorY(rec, def)
		local ok, msg = GS.buyItem(state, self.design, rec)
		if not ok then
			app:toast(msg, T.bad)
			buildPending(rec)
			return
		end
		SoundFX.sfx("place", 0.7)
		local keep = Util.deepCopy(rec)
		keep.x, keep.z, keep.y = nil, nil, nil
		lastSettings[def.id] = keep
		if def.deck then
			render()
		else
			Stage3D.addItem(rec, itemOpts())
			Stage3D.numberSpots(self.design)
		end
		refreshStats()
		-- keep building with the same piece
		setMode("place", def)
	end

	local function cancel()
		if pending then
			setMode("place", placeDef or pending.def)
		elseif mode == "place" then
			setMode("idle")
		elseif selected then
			select(nil)
		end
	end

	------------------------------------------------------------ changes (pending: free, bought: pay the difference)
	local function applyChange(changes)
		if pending then
			for k, v in pairs(changes) do
				pending.rec[k] = v
			end
			local geo = false
			for k in pairs(changes) do
				if GEOMETRY_KEYS[k] then
					geo = true
				end
			end
			if geo then
				buildPending(pending.rec)
			else
				placePending()
			end
			relabelSpots()
			refreshStats()
			refreshInspector()
			return
		end
		if mode == "place" and ghostRec then
			for k, v in pairs(changes) do
				ghostRec[k] = v
			end
			lastSettings[placeDef.id] = Util.deepCopy(ghostRec)
			clearGhost()
			refreshInspector()
			return
		end
		if not selected then
			return
		end
		local rec = selected.rec
		local riders = {}
		if changes.h and selected.def.deck then
			riders = itemsOnDeck(selected)
		end
		local oldH = rec.h
		local ok, msg = GS.changeItem(state, rec, changes)
		if not ok then
			app:toast(msg, T.bad)
			return
		end
		if changes.h and oldH then
			for _, rr in ipairs(riders) do
				if rr.y then
					rr.y = rr.y + (changes.h - oldH)
				end
			end
		end
		-- show settings (song of an instrument, effect songs, screen content) change nothing you can see on the
		-- stage: no rebuild of the whole stage, so nothing jumps or flickers
		local onlyShow = true
		for k in pairs(changes) do
			if not SHOW_KEYS[k] and k ~= "scr" then
				onlyShow = false
			end
		end
		if onlyShow then
			if changes.scr or changes.anim then
				Stage3D.removeItem(selected)
				selected = Stage3D.addItem(rec, itemOpts())
			end
			Stage3D.numberSpots(self.design)
		else
			render()
		end
		refreshStats()
		refreshInspector()
		if refreshSetlist then
			refreshSetlist()
		end
	end

	local function rotate(delta)
		if group and not pending then
			-- turn the group around its middle
			local cx, cz, n = 0, 0, #group
			for _, r in ipairs(group) do
				cx, cz = cx + r.rec.x / n, cz + r.rec.z / n
			end
			local turn = CFrame.Angles(0, math.rad(delta), 0)
			for _, r in ipairs(group) do
				local off = turn * Vector3.new(r.rec.x - cx, 0, r.rec.z - cz)
				r.rec.x, r.rec.z = snapG(cx + off.X), snapG(cz + off.Z)
				r.rec.r = ((r.rec.r or 0) + delta) % 360
				if r.def.mount ~= "rig" and r.def.mount ~= "side" then
					r.rec.y = nil
				end
			end
			render()
			for _, r in ipairs(group or {}) do
				if r.def.mount ~= "rig" and r.def.mount ~= "side" then
					r.rec.y = Stage3D.surfaceY(r.rec.x, r.rec.z, r)
				end
			end
			render()
			return
		end
		-- a light / speaker on a truss tower goes round the tower: R = the next side of the tower
		local sideT = pending or selected
		if sideT and sideT.def.mount == "side" then
			local rec = sideT.rec
			local tower = Stage3D.nearestTower(rec.x, rec.z)
			if tower then
				local c = tower.cf.Position
				local off = CFrame.Angles(0, math.rad((delta >= 0) and 90 or -90), 0) * Vector3.new(rec.x - c.X, 0, rec.z - c.Z)
				local nx, nz, nr = Stage3D.snapToTower(c.X + off.X * 3, c.Z + off.Z * 3)
				if nx then
					applyChange({ x = nx, z = nz, r = nr })
				end
				return
			end
		end
		local cur = (pending and pending.rec.r) or (mode == "place" and ghostRec and ghostRec.r) or (selected and selected.rec.r)
		if cur == nil then
			return
		end
		applyChange({ r = (cur + delta) % 360 })
	end

	local function deleteSelected()
		if pending then
			cancel()
			return
		end
		if group then
			deleteGroup()
			return
		end
		if not selected then
			return
		end
		local refs = selected
		local wasDeck = refs.def.deck
		select(nil)
		GS.sellItem(state, self.design, refs.rec)
		SoundFX.sfx("delete", 0.6)
		Stage3D.removeItem(refs)
		Stage3D.numberSpots(self.design)
		if wasDeck then
			render()
		end
		refreshStats()
	end

	-- copy: a new (not yet bought) piece in exactly the same place - pull it out with one arrow and it stays
	-- in line with the original (a group is copied and bought at once)
	local function copySelected()
		if group then
			copyGroup()
			return
		end
		local src = selected or pending
		if not src then
			return
		end
		local rec = Util.deepCopy(src.rec)
		rec.uid = nil
		app:toast("Copy made in the same place: pull it out with an arrow, then press Q.", T.accent2, 4)
		local def = src.def
		selected = nil
		placeDef = def
		mode = "pending"
		floorY(rec, def)
		buildPending(rec)
		refreshList()
		refreshInspector()
		refreshToolbar()
	end

	------------------------------------------------------------ catalog
	local function thumbnail(parent, def)
		local vp = UI.New("ViewportFrame", {
			Parent = parent,
			Position = UI.px(6, 6),
			Size = UI.px(138, 84),
			BackgroundColor3 = Color3.fromRGB(34, 38, 54),
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(170, 170, 185),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -0.6),
			UI.Corner(6),
		})
		local refs = Builder.build(def, { color = itemOpts().color, artistName = "", rec = { t = def.id }, preview = true })
		Builder.rest(refs)
		refs.model.Parent = vp
		local cf, size = refs.model:GetBoundingBox()
		local r = math.max(size.X, size.Y, size.Z)
		local cam = UI.New("Camera", { FieldOfView = 40, Parent = vp })
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.9, 0.7, 1.1).Unit * (r * 1.55 + 2), cf.Position)
		vp.CurrentCamera = cam
	end

	refreshList = function()
		UI.ClearChildren(cardRow)
		local n = 0
		for _, def in ipairs(StageItems.list) do
			if def.cat == currentCat and not def.hidden and def.id ~= "spot" then
				n = n + 1
				local isSel = placeDef == def and (mode == "place" or mode == "pending")
				local b = UI.Button(cardRow, "", nil, UI.px(150, 148), { order = def.order, color = isSel and T.accent or T.panel3 }, function()
					if placeDef == def and mode == "place" then
						setMode("idle")
					else
						setMode("place", def)
					end
				end)
				thumbnail(b, def)
				UI.Label(b, def.name, UI.px(8, 94), UI.px(136, 24), { textSize = 15, font = UI.FontBold })
				local price = (def.cost > 0) and Util.money(Sim.itemPrice(def)) or "Free"
				UI.Label(b, price, UI.px(8, 118), UI.px(136, 22), { textSize = 14, color = isSel and T.text or T.gold, font = UI.FontBold })
			end
		end
		for _, c in ipairs(tabs:GetChildren()) do
			if c:IsA("TextButton") then
				local on = c.Name == currentCat
				c.BackgroundColor3 = on and T.accent2 or T.panel3
				c.TextColor3 = on and BLACK or T.text
			end
		end
		catHint.Text = (mode == "place" and placeDef) and ("Placing: " .. placeDef.name .. " - point at the stage and press Q") or (n .. " items  |  click a card to build")
	end

	for i, cat in ipairs(StageItems.CATEGORIES) do
		local b = UI.Button(tabs, cat.name, nil, UI.px(148, 36), { order = i, textSize = 16 }, function()
			currentCat = cat.id
			refreshList()
		end)
		b.Name = cat.id
	end

	------------------------------------------------------------ tool bar
	local function toolButton(text, w, color, textColor, cb, disabled)
		return UI.Button(toolbar, text, nil, UI.px(w, 44), { color = color or T.panel3, textColor = textColor, textSize = 15, disabled = disabled }, cb)
	end
	refreshToolbar = function()
		UI.ClearChildren(toolbar)
		local tgt = target()
		toolButton("Grid " .. grid(), 86, T.panel2, nil, function()
			gridIndex = gridIndex % #GRIDS + 1
			refreshToolbar()
		end).LayoutOrder = 1
		toolButton("Turn " .. TURNS[turnIndex] .. " deg", 104, T.panel2, nil, function()
			turnIndex = turnIndex % #TURNS + 1
			refreshToolbar()
		end).LayoutOrder = 2
		toolButton("Turn (R)", 100, nil, nil, function()
			rotate(TURNS[turnIndex])
		end, not (tgt or mode == "place")).LayoutOrder = 3
		toolButton("Copy (C)", 100, nil, nil, copySelected, not tgt).LayoutOrder = 4
		toolButton("Mirror (M)", 110, nil, nil, mirrorChosen, not (selected or group) or pending ~= nil).LayoutOrder = 4
		toolButton("Delete (X)", 110, UI.shade(T.bad, 0.7), nil, deleteSelected, not tgt).LayoutOrder = 5
		toolButton("X", 56, T.panel2, T.bad, cancel, not (tgt or mode == "place")).LayoutOrder = 6
		local price = pending and Sim.itemPrice(pending.def, pending.rec) or nil
		local okBtn = toolButton(pending and ("PLACE (Q)  " .. (price > 0 and Util.moneyShort(price) or "")) or "PLACE (Q)", pending and 180 or 120, pending and T.good or T.panel2, pending and BLACK or T.sub, confirm, not pending)
		okBtn.LayoutOrder = 7
		toolbar.Size = UI.px(pending and 990 or 930, 58)
		toolbar.Position = UI.px(960 - (pending and 495 or 465), 800)
		-- the tools only show while you place or change something
		toolbar.Visible = phase == "build" and catalog.Visible and (tgt ~= nil or mode == "place" or group ~= nil)
	end

	------------------------------------------------------------ inspector
	local function section(text)
		return UI.Label(inspScroll, text, nil, UI.px(296, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local function row(h)
		local f = UI.New("Frame", { Parent = inspScroll, Size = UI.px(296, h or 36), BackgroundTransparency = 1 })
		return f
	end
	local order = 0
	local function nextOrder(inst)
		order = order + 1
		inst.LayoutOrder = order
		return inst
	end
	local function stepper(label, value, onMinus, onPlus)
		local f = nextOrder(row(36))
		UI.Label(f, label, UI.px(0, 0), UI.px(110, 36), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Button(f, "-", UI.px(112, 0), UI.px(44, 36), { textSize = 20 }, onMinus)
		UI.Label(f, value, UI.px(158, 0), UI.px(92, 36), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Center })
		UI.Button(f, "+", UI.px(252, 0), UI.px(44, 36), { textSize = 20 }, onPlus)
	end
	local function chips(list, isOn, onPick, perRow, w)
		perRow = perRow or 3
		w = w or math.floor((296 - (perRow - 1) * 6) / perRow)
		local rows = math.ceil(#list / perRow)
		local f = nextOrder(row(rows * 38))
		for i, item in ipairs(list) do
			local col, r = (i - 1) % perRow, math.floor((i - 1) / perRow)
			local on = isOn(item)
			UI.Button(f, item[2], UI.px(col * (w + 6), r * 38), UI.px(w, 32), { textSize = 13, color = on and T.accent or T.panel3 }, function()
				onPick(item)
			end)
		end
	end

	refreshInspector = function()
		if refreshSetlist then
			refreshSetlist()
		end
		UI.ClearChildren(inspScroll)
		order = 0
		local def, rec
		if pending then
			def, rec = pending.def, pending.rec
		elseif mode == "place" and placeDef then
			def, rec = placeDef, ghostRec
		elseif selected then
			def, rec = selected.def, selected.rec
		end
		if group and not pending then
			inspector.Visible = true
			nextOrder(UI.Label(inspScroll, "GROUP", nil, UI.px(296, 18), { textSize = 13, color = T.gold, font = UI.FontBold }))
			nextOrder(UI.Label(inspScroll, #group .. " items selected", nil, UI.px(296, 30), { textSize = 22, font = UI.FontBlack }))
			nextOrder(UI.Label(inspScroll, "The arrows in the middle move them together, the orange ring turns them around the middle. Shift + click adds or removes items.", nil, UI.px(296, 0), { textSize = 13, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
			nextOrder(UI.Button(inspScroll, "Copy in place (C)", nil, UI.px(296, 36), { textSize = 15, color = T.accent2 }, copyGroup))
			nextOrder(UI.Button(inspScroll, "Mirror to the other side (M)", nil, UI.px(296, 36), { textSize = 15 }, mirrorChosen))
			nextOrder(UI.Button(inspScroll, "Delete all (X)", nil, UI.px(296, 36), { textSize = 15, color = UI.shade(T.bad, 0.7) }, deleteGroup))
			nextOrder(UI.Button(inspScroll, "Clear selection", nil, UI.px(296, 32), { textSize = 13 }, function()
				select(nil)
			end))
			return
		end
		inspector.Visible = def ~= nil
		if not def then
			return
		end
		local head = (pending and "NEW - NOT BOUGHT YET") or (mode == "place" and "PLACING") or "SELECTED"
		nextOrder(UI.Label(inspScroll, head, nil, UI.px(296, 18), { textSize = 13, color = pending and T.good or (selected and T.gold or T.accent2), font = UI.FontBold }))
		nextOrder(UI.Label(inspScroll, def.name, nil, UI.px(296, 30), { textSize = 22, font = UI.FontBlack }))
		local price = Sim.itemPrice(def, rec)
		local priceTxt = (def.cost > 0) and Util.money(price) or "Free"
		if selected and not pending then
			priceTxt = priceTxt .. "   (sells for " .. Util.money(math.floor(price * Config.RESALE)) .. ")"
		end
		nextOrder(UI.Label(inspScroll, priceTxt, nil, UI.px(296, 20), { textSize = 14, color = T.gold, font = UI.FontBold }))
		nextOrder(UI.Label(inspScroll, def.desc, nil, UI.px(296, 0), { textSize = 13, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y

		local build = phase == "build"
		if build and (def.size or def.heights) then
			-- the size is changed with the white handles on the piece itself
			local sz = def.size
			local parts = {}
			if sz then
				local wLabel = (def.shape == "round" or def.id == "portal" or def.id == "moon") and "across" or ((def.mount == "rig") and "long" or "wide")
				table.insert(parts, (rec.w or sz.w) .. " " .. wLabel)
				if sz.d then
					table.insert(parts, (rec.d or sz.d) .. ((sz.dLabel == "Height") and " high" or " deep"))
				end
			end
			if def.heights and not (sz and sz.dLabel == "Height") then
				table.insert(parts, (rec.h or def.h) .. " high")
			end
			nextOrder(section("SIZE"))
			nextOrder(UI.Label(inspScroll, table.concat(parts, "  x  ") .. " studs", nil, UI.px(296, 22), { textSize = 16, font = UI.FontBold }))
			nextOrder(UI.Label(inspScroll, "Pull the gold cubes on the piece to resize (the top cube changes the height). Hold Shift: both sides grow.", nil, UI.px(296, 0), { textSize = 13, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
		end
		if build and def.deck then
			nextOrder(section("SURFACE"))
			local list = {}
			for _, sk in ipairs(Builder.SKINS) do
				table.insert(list, { sk, sk == "led" and "LED screen" or (sk:sub(1, 1):upper() .. sk:sub(2)) })
			end
			chips(list, function(it)
				return (rec.skin or "black") == it[1]
			end, function(it)
				applyChange({ skin = it[1] })
			end)
			local f = nextOrder(row(34))
			UI.Button(f, (rec.edge and "[X]" or "[ ]") .. "  Edge lights", UI.px(0, 0), UI.px(140, 32), { textSize = 13 }, function()
				applyChange({ edge = not rec.edge })
			end)
			if selected and not pending then
				UI.Button(f, "Use on all decks", UI.px(148, 0), UI.px(148, 32), { textSize = 13, color = T.accent2 }, function()
					local total = 0
					for _, other in ipairs(self.design.items) do
						local od = StageItems.byId[other.t]
						if od and od.deck and other ~= rec then
							if GS.changeItem(state, other, { skin = rec.skin or "black", edge = rec.edge == true }) then
								total = total + 1
							end
						end
					end
					app:toast("Applied to " .. total .. " other decks.", T.good)
					render()
					refreshStats()
					refreshInspector()
				end)
			end
		end
		local songs = GS.songCount(self.design)
		local showThings = def.id == "spot" or GS.PLAY_ITEMS[def.id] or Builder.SCREEN_KINDS[def.id] or FX_SONG_KINDS[def.id] or def.id == "curtain"
		if build and def.id == "curtain" then
			nextOrder(section("CURTAIN COLOUR"))
			chips(Builder.CURTAIN_COLORS, function(it)
				return (rec.cc or "red") == it[1]
			end, function(it)
				applyChange({ cc = it[1] })
			end, 3)
		end
		if not build and def.id == "curtain" then
			nextOrder(section("HOW THE CURTAIN OPENS"))
			chips(Builder.CURTAIN_ANIMS, function(it)
				return (rec.anim or "drop") == it[1]
			end, function(it)
				applyChange({ anim = it[1] })
			end, 3)
			stepper("Opens", rec.cs and ("Song " .. rec.cs) or "At the start", function()
				if rec.cs then
					applyChange({ cs = (rec.cs > 1) and (rec.cs - 1) or false })
				end
			end, function()
				applyChange({ cs = math.min(songs, (rec.cs or 0) + 1) })
			end)
			nextOrder(UI.Label(inspScroll, "Until then the curtain hides the stage. Watch it in PREVIEW SHOW.", nil, UI.px(296, 0), { textSize = 13, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
		end
		if build and showThings and def.id ~= "spot" then
			nextOrder(UI.Label(inspScroll, "What it does in which song: set it up in step 2: SETLIST & SHOW (tab at the top).", nil, UI.px(296, 0), { textSize = 14, color = T.accent2, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
		end
		if not build and not showThings then
			nextOrder(UI.Label(inspScroll, "Nothing to set up for the show here. Go back to BUILD to move or change it.", nil, UI.px(296, 0), { textSize = 14, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
		end
		if not build and FX_SONG_KINDS[def.id] then
			nextOrder(section("FIRES IN SONGS"))
			nextOrder(UI.Label(inspScroll, "Auto = the show decides (big moments, the finale). Or pick the songs yourself.", nil, UI.px(296, 0), { textSize = 13, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
			local list = { { "auto", "Auto" } }
			for n = 1, songs do
				table.insert(list, { n, tostring(n) })
			end
			local function has(n)
				if type(rec.songs) ~= "table" then
					return false
				end
				for _, v in ipairs(rec.songs) do
					if v == n then
						return true
					end
				end
				return false
			end
			chips(list, function(it)
				if it[1] == "auto" then
					return type(rec.songs) ~= "table" or #rec.songs == 0
				end
				return has(it[1])
			end, function(it)
				if it[1] == "auto" then
					applyChange({ songs = false })
					return
				end
				local new = {}
				for _, v in ipairs(type(rec.songs) == "table" and rec.songs or {}) do
					if v ~= it[1] then
						table.insert(new, v)
					end
				end
				if not has(it[1]) then
					table.insert(new, it[1])
				end
				table.sort(new)
				applyChange({ songs = (#new > 0) and new or false })
			end, 5, 54)
			if selected and not pending then
				nextOrder(UI.Button(inspScroll, "Use these songs for all " .. def.name .. "s", nil, UI.px(296, 32), { textSize = 13, color = T.accent2 }, function()
					for _, other in ipairs(self.design.items) do
						if other.t == rec.t and other ~= rec then
							other.songs = (type(rec.songs) == "table") and Util.deepCopy(rec.songs) or false
						end
					end
					app:toast("Done: every " .. def.name .. " fires in the same songs.", T.good)
				end))
			end
		end
		if not build and def.id == "spot" then
			local list = spotRecs()
			local idx = 0
			for i, r in ipairs(list) do
				if r == rec then
					idx = i
				end
			end
			local plan = GS.songPlan(withPending())
			local song = plan.songOf[rec]
			nextOrder(section("SETLIST"))
			local txt = song and ("Song " .. song .. " of " .. plan.count .. (song == 1 and "  (opener)" or (song == plan.count and "  (big finale)" or ""))) or "Song ?"
			nextOrder(UI.Label(inspScroll, txt, nil, UI.px(296, 24), { textSize = 17, font = UI.FontBold, color = T.gold }))
			nextOrder(UI.Label(inspScroll, "Lifts and instruments keep their song number, spots take the free ones.", nil, UI.px(296, 0), { textSize = 12, color = T.sub, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
			if idx > 0 then
				local f = nextOrder(row(34))
				local function swap(other)
					local a, b
					for i, r in ipairs(self.design.items) do
						if r == rec then
							a = i
						elseif r == other then
							b = i
						end
					end
					if a and b then
						self.design.items[a], self.design.items[b] = self.design.items[b], self.design.items[a]
						Stage3D.numberSpots(self.design)
						refreshInspector()
					end
				end
				UI.Button(f, "< Earlier", UI.px(0, 0), UI.px(145, 32), { textSize = 13, disabled = idx <= 1 }, function()
					swap(list[idx - 1])
				end)
				UI.Button(f, "Later >", UI.px(151, 0), UI.px(145, 32), { textSize = 13, disabled = idx >= #list }, function()
					swap(list[idx + 1])
				end)
			end
		end
		if not build and GS.PLAY_ITEMS[def.id] then
			local isLift = def.id == "lift" or def.id == "poplift"
			local isTower = def.id == "towerlift"
			nextOrder(section(isTower and "LIFTS THE ARTIST UP IN SONG" or (isLift and "ARTIST COMES UP HERE IN SONG" or "ARTIST PLAYS THIS IN SONG")))
			local cur = rec.play
			if isLift then
				cur = cur or 1
			elseif isTower and cur == nil then
				cur = GS.songPlan(withPending()).songOf[rec]
			end
			stepper("Song", cur and tostring(cur) or "Off", function()
				if not cur then
					return
				end
				local n = cur - 1
				if n < 1 then
					applyChange({ play = (isLift or isTower) and 1 or false })
				else
					applyChange({ play = n })
				end
			end, function()
				applyChange({ play = math.min(StageItems.MAX_SPOTS, (cur or 0) + 1) })
			end)
		end
		if not build and Builder.SCREEN_KINDS[def.id] then
			local scr = rec.scr and Util.deepCopy(rec.scr) or { default = Builder.screenConfig({ rec = rec, kind = def.id }, nil) }
			nextOrder(section("SCREEN SHOWS"))
			local slot = (screenSong == 0) and "default" or tostring(screenSong)
			stepper("For", (screenSong == 0) and "Whole show" or ("Song " .. screenSong), function()
				screenSong = math.max(0, screenSong - 1)
				refreshInspector()
			end, function()
				screenSong = math.min(songs, screenSong + 1)
				refreshInspector()
			end)
			local curCfg = scr[slot]
			local modes = { { "song", "Song title" }, { "artist", "Artist name" }, { "visuals", "Tour visuals" }, { "text", "Own text" }, { "image", "Image ID" }, { "liveArtist", "Live: artist" }, { "liveCrowd", "Live: fans" } }
			local function setSlot(cfg)
				local new = Util.deepCopy(scr)
				new[slot] = cfg
				if not new.default then
					new.default = { m = (def.id == "led_side") and "artist" or "song" }
				end
				applyChange({ scr = new })
			end
			chips(modes, function(it)
				return curCfg ~= nil and curCfg.m == it[1]
			end, function(it)
				setSlot({ m = it[1], text = curCfg and curCfg.text, img = curCfg and curCfg.img })
			end, 2)
			if not curCfg and slot ~= "default" then
				nextOrder(UI.Label(inspScroll, "Same as the whole show", nil, UI.px(296, 20), { textSize = 13, color = T.sub }))
			end
			if curCfg and (curCfg.m == "text" or curCfg.m == "image") then
				local isText = curCfg.m == "text"
				local box = nextOrder(UI.New("TextBox", {
					Parent = inspScroll,
					Size = UI.px(296, 34),
					BackgroundColor3 = T.panel2,
					BorderSizePixel = 0,
					Text = isText and (curCfg.text or "") or tostring(curCfg.img or ""),
					PlaceholderText = isText and "Text on the screen" or "Roblox image ID (numbers)",
					ClearTextOnFocus = false,
					TextColor3 = T.text,
					TextSize = 15,
					Font = UI.Font,
					UI.Corner(6),
				}))
				box.FocusLost:Connect(function()
					local cfg = Util.deepCopy(curCfg)
					if isText then
						cfg.text = box.Text:sub(1, 40)
					else
						cfg.img = tonumber((box.Text:gsub("%D", "")))
						if not cfg.img then
							app:toast("Please enter the number of a Roblox image.", T.warn)
							return
						end
					end
					setSlot(cfg)
				end)
			end
			if slot ~= "default" and curCfg then
				nextOrder(UI.Button(inspScroll, "Remove change for song " .. screenSong, nil, UI.px(296, 30), { textSize = 13 }, function()
					local new = Util.deepCopy(scr)
					new[slot] = nil
					applyChange({ scr = new })
				end))
			end
			if selected and not pending and copyPick and copyPick.src == rec then
				-- choosing the screens that get the same settings
				local n = 0
				for _ in pairs(copyPick.recs) do
					n = n + 1
				end
				nextOrder(UI.Label(inspScroll, "Click the screens on the stage that should show the same. Chosen: " .. n, nil, UI.px(296, 0), { textSize = 14, font = UI.FontBold, color = T.accent2, wrap = true })).AutomaticSize = Enum.AutomaticSize.Y
				local f = nextOrder(row(40))
				UI.Button(f, "Cancel", UI.px(0, 2), UI.px(110, 36), { textSize = 14 }, function()
					endCopyPick()
					refreshInspector()
				end)
				UI.Button(f, "Finish (" .. n .. ")", UI.px(116, 2), UI.px(180, 36), { textSize = 15, color = T.good, disabled = n == 0 }, function()
					for other in pairs(copyPick.recs) do
						other.scr = Util.deepCopy(scr)
					end
					endCopyPick()
					app:toast(n + 1 .. " screens now show the same.", T.good)
					render()
					refreshInspector()
				end).Name = "CopyFinish"
			elseif selected and not pending then
				nextOrder(UI.Button(inspScroll, "Copy to chosen screens...", nil, UI.px(296, 32), { textSize = 13 }, function()
					copyPick = { src = rec, recs = {}, boxes = {} }
					drawCopyPick()
					refreshInspector()
				end))
				nextOrder(UI.Button(inspScroll, "Use on all screens", nil, UI.px(296, 32), { textSize = 13, color = T.accent2 }, function()
					local n = 0
					for _, other in ipairs(self.design.items) do
						if Builder.SCREEN_KINDS[other.t] and other ~= rec then
							other.scr = Util.deepCopy(scr)
							n = n + 1
						end
					end
					app:toast("All " .. (n + 1) .. " screens now show the same.", T.good)
					render()
					refreshInspector()
				end))
			end
		end
		if build then
			nextOrder(section("POSITION"))
			stepper("Turn", (rec.r or 0) .. " deg", function()
				rotate(-TURNS[turnIndex])
			end, function()
				rotate(TURNS[turnIndex])
			end)
			stepper("Lift up", (rec.yo or 0) .. " st", function()
				applyChange({ yo = math.max((def.mount == "rig") and -20 or 0, (rec.yo or 0) - 1) })
			end, function()
				applyChange({ yo = math.min(40, (rec.yo or 0) + 1) })
			end)
		elseif def.id == "spot" and selected and not pending then
			nextOrder(UI.Button(inspScroll, "Remove this spot (X)", nil, UI.px(296, 34), { textSize = 14, color = UI.shade(T.bad, 0.7) }, deleteSelected))
		end
		if pending then
			local f = nextOrder(row(48))
			UI.Button(f, "X Cancel", UI.px(0, 4), UI.px(120, 42), { textSize = 15 }, cancel)
			UI.Button(f, "PLACE (Q)", UI.px(126, 4), UI.px(170, 42), { textSize = 17, color = T.good }, confirm)
		end
	end

	------------------------------------------------------------ step 2: setlist & show
	local spotDef = StageItems.byId.spot
	local function refsOf(rec)
		for _, r in ipairs(Stage3D.items) do
			if r.rec == rec then
				return r
			end
		end
		return nil
	end
	refreshSetlist = function()
		UI.ClearChildren(setlistPanel)
		setlistPanel.Visible = phase == "show"
		if phase ~= "show" then
			return
		end
		UI.Label(setlistPanel, "SETLIST & SHOW", UI.px(18, 12), UI.px(394, 32), { textSize = 24, font = UI.FontBlack, color = T.accent2 })
		UI.Label(setlistPanel, "One song per place: artist spots, lifts and instruments. Click a song or an item on the stage to set it up: screens and effects too.", UI.px(18, 46), UI.px(394, 60), { textSize = 15, color = T.sub, wrap = true })
		local plan = GS.songPlan(withPending())
		local list = UI.Scroll(setlistPanel, UI.px(12, 112), UI.px(406, 470))
		UI.List(true, 6).Parent = list
		for n = 1, plan.count do
			local rec = plan.place[n]
			local def = rec and StageItems.byId[rec.t]
			local isSel = selected ~= nil and rec ~= nil and selected.rec == rec
			local what = def and def.name or "free: the artist walks the stage"
			local tag = (n == 1) and "  (opener)" or ((n == plan.count) and "  (finale)" or "")
			local b = UI.Button(list, "", nil, UI.px(384, 54), { order = n, color = isSel and T.accent or T.panel2 }, function()
				local r = rec and refsOf(rec)
				if r then
					select(r)
				end
			end)
			UI.Label(b, "SONG " .. n .. tag, UI.px(14, 4), UI.px(360, 22), { textSize = 15, font = UI.FontBlack, color = isSel and T.text or T.gold })
			UI.Label(b, what, UI.px(14, 26), UI.px(360, 24), { textSize = 16, color = def and T.text or T.sub })
		end
		local spots = #spotRecs()
		UI.Button(setlistPanel, "+ ADD ARTIST SPOT (a new song)", UI.px(18, 594), UI.px(394, 48), { textSize = 16, color = T.good, disabled = spots >= StageItems.MAX_SPOTS }, function()
			setMode("place", spotDef)
		end)
		local fxAuto, fxSet = 0, 0
		for _, it in ipairs(self.design.items) do
			if FX_SONG_KINDS[it.t] then
				if type(it.songs) == "table" and #it.songs > 0 then
					fxSet = fxSet + 1
				else
					fxAuto = fxAuto + 1
				end
			end
		end
		UI.Label(setlistPanel, string.format("Effects: %d automatic, %d set to songs", fxAuto, fxSet), UI.px(18, 650), UI.px(394, 22), { textSize = 15, color = T.sub })
		UI.Label(setlistPanel, "Place a spot: point at the stage and press Q.", UI.px(18, 676), UI.px(394, 22), { textSize = 15, color = T.sub })
	end

	local function setPhase(p)
		if p == phase then
			return
		end
		select(nil)
		setMode("idle")
		phase = p
		catalog.Visible = p == "build"
		statsBar.Visible = true
		refreshTop()
		refreshToolbar()
		refreshInspector()
		refreshSetlist()
		if p == "show" then
			app:toast("Step 2: choose what happens in every song. Back to building: tab 1  BUILD.", T.accent2, 5)
		end
	end
	self.setPhase = setPhase

	------------------------------------------------------------ top bar
	local function switchDesign(d)
		self.design = d
		app.lastDesignId = d.id
		select(nil)
		Stage3D.setDesign(d)
		render()
		resetCamera()
		refreshTop()
		refreshStats()
	end
	self.switchDesign = switchDesign

	refreshTop = function()
		for _, c in ipairs(topInner:GetChildren()) do
			if c.Name == "TopItem" then
				c:Destroy()
			end
		end
		local function tag(inst)
			inst.Name = "TopItem"
			return inst
		end
		tag(UI.Button(topInner, "< MY STAGES", UI.px(16, 10), UI.px(170, 44), { textSize = 16 }, function()
			Designer.close()
			app:enterMode("menu")
			app:go("stages")
		end))
		local nameBox = tag(UI.New("TextBox", {
			Parent = topInner,
			Position = UI.px(200, 10),
			Size = UI.px(300, 44),
			BackgroundColor3 = T.panel2,
			BorderSizePixel = 0,
			Text = self.design.name,
			PlaceholderText = "Stage name",
			ClearTextOnFocus = false,
			TextColor3 = T.text,
			TextSize = 20,
			Font = UI.FontBold,
			UI.Corner(8),
		}))
		nameBox.FocusLost:Connect(function()
			local txt = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
			if #txt > 0 and txt:sub(1, 24) ~= self.design.name then
				self.design.name = txt:sub(1, 24)
				-- saved together with the stage when the builder closes (an action now would reload the unsaved stage)
				app:toast("Stage name: " .. self.design.name, T.good)
			end
			nameBox.Text = self.design.name
		end)
		tag(UI.Label(topInner, "STAGE NAME (click to rename)", UI.px(204, 0), UI.px(300, 12), { textSize = 10, color = T.sub, font = UI.FontBold }))
		local pill = tag(UI.Pill(topInner, string.upper(self.design.class) .. "  |  " .. (self.design.layout == "center" and "CENTER STAGE" or "END STAGE"), UI.px(512, 18), UI.px(220, 28), T.accent2, 14))
		tag(UI.Button(topInner, "?", UI.px(744, 10), UI.px(44, 44), { textSize = 20, color = helpBox.Visible and T.accent or T.panel3 }, function()
			helpBox.Visible = not helpBox.Visible
			refreshTop()
		end))
		-- the two steps as tabs: 1 build the stage, 2 plan the songs
		local b1 = tag(UI.Button(topInner, "1  BUILD", UI.px(804, 10), UI.px(150, 44), { textSize = 16, color = (phase == "build") and T.accent or T.panel3 }, function()
			setPhase("build")
		end))
		b1.Name = "TopItem"
		tag(UI.Button(topInner, "2  SETLIST & SHOW", UI.px(960, 10), UI.px(226, 44), { textSize = 16, color = (phase == "show") and T.accent or T.panel3 }, function()
			setPhase("show")
		end))
		local ad = previewArtist()
		tag(UI.Button(topInner, "Artist: " .. (ad and ad.name or "-"), UI.px(1200, 10), UI.px(180, 44), { textSize = 14 }, function()
			self.previewIndex = self.previewIndex % math.max(1, #signed) + 1
			render()
			refreshTop()
			refreshStats()
		end))
		tag(UI.Button(topInner, "Preview show", UI.px(1390, 10), UI.px(170, 44), { color = T.accent2, textSize = 16 }, function()
			Designer.preview()
		end))
		tag(UI.Button(topInner, "DONE", UI.px(1570, 10), UI.px(110, 44), { color = T.good, textSize = 18 }, function()
			Designer.close()
			app:enterMode("menu")
			app:go(app.returnScreen or "stages")
		end))
	end

	local lastMoney = nil
	refreshStats = function()
		local m = state.money
		moneyLbl.Text = Util.money(m)
		moneyLbl.TextColor3 = (lastMoney and m < lastMoney) and T.bad or (m < 0 and T.bad or T.good)
		if lastMoney and m ~= lastMoney then
			task.delay(0.8, function()
				if moneyLbl.Parent then
					moneyLbl.TextColor3 = state.money < 0 and T.bad or T.good
				end
			end)
		end
		lastMoney = m
		local ad = previewArtist()
		local st = Sim.designStats(self.design, ad and ad.genre)
		local c = cls()
		local fits = {}
		for _, k in ipairs(Config.STAGE_CLASSES) do
			if k.order >= c.order then
				local score = Sim.productionScore(self.design, ad and ad.genre, CLASS_CAP[k.id])
				local col = score >= 80 and "#16a34a" or (score >= 55 and "#b45309" or "#dc2626")
				table.insert(fits, string.format('%s <font color="%s"><b>%d%%</b></font>', k.id, col, math.floor(score + 0.5)))
			end
		end
		statsLbl.Text = string.format(
			"Songs <b>%d</b>      Items <b>%d / %d</b>      Cost <b>%s</b> per show      Quality for %s:  %s",
			GS.songCount(withPending()),
			st.count,
			c.maxItems,
			Util.money(st.cost),
			ad and ad.name or "your artist",
			table.concat(fits, "   ")
		)
	end

	refreshTop()
	refreshList()
	refreshToolbar()
	refreshInspector()
	refreshStats()

	------------------------------------------------------------ ghost / hover
	local function updateGhost()
		if mode ~= "place" or not placeDef or mouseOverUI() or dialog then
			clearGhost()
			return
		end
		local def, rec = placeDef, ghostRec
		local x, z, rr, sy, onTower = mousePoint(nil, def, rec)
		if rr then
			rec.r = rr -- a truss beam turns to line up with its neighbour, a side mount looks away from its tower
		end
		if not x then
			clearGhost()
			return
		end
		local ok = Stage3D.inBounds(x, z) and #self.design.items < cls().maxItems and state.money >= Sim.itemPrice(def, rec) and (def.mount ~= "side" or onTower == true)
		local key = def.id .. tostring(ok) .. tostring(rec.w) .. tostring(rec.d) .. tostring(rec.h) .. tostring(rec.skin)
		if not ghost or ghostKey ~= key then
			clearGhost()
			ghost = Builder.build(def, { color = itemOpts().color, artistName = itemOpts().artistName, rec = rec, preview = true })
			Builder.ghost(ghost, ok)
			ghost.model.Parent = Stage3D.world
			ghostKey = key
		end
		local tmp = { x = x, z = z, r = rec.r, yo = rec.yo, y = sy }
		Builder.place(ghost, Stage3D.itemCFrame(def, tmp))
		ghost.ok, ghost.x, ghost.z, ghost.y = ok, x, z, sy
		ghost.noTower = def.mount == "side" and not onTower
	end

	local function updateHover()
		local hovered = nil
		if (mode == "idle" or mode == "selected") and not mouseOverUI() and not dialog then
			hovered = itemUnderMouse()
		end
		hoverHighlight.Adornee = (hovered and hovered ~= selected) and hovered.model or nil
		hoverHighlight.Enabled = hovered ~= nil and hovered ~= selected
		selHighlight.Adornee = selected and selected.model or nil
		selHighlight.Enabled = selected ~= nil and group == nil
	end

	-- price tag next to the mouse while placing
	local function updatePriceTag()
		local def = (mode == "place" and placeDef) or (pending and pending.def)
		if not def or mouseOverUI() or def.cost <= 0 then
			priceTag.Visible = false
			return
		end
		local rec = pending and pending.rec or ghostRec
		local price = Sim.itemPrice(def, rec)
		local m = UserInputService:GetMouseLocation()
		local a = app.canvas.AbsolutePosition
		local sc = app.uiScale and app.uiScale.Scale or 1
		priceTag.Position = UI.px((m.X - a.X) / sc + 18, (m.Y - a.Y) / sc + 12)
		priceTag.Text = Util.money(price)
		priceTag.TextColor3 = (state.money >= price) and T.good or T.bad
		priceTag.Visible = true
	end

	------------------------------------------------------------ gizmo (Roblox handles, coloured like a 3D editor)
	local moveBox = UI.New("Part", { Name = "GizmoMove", Size = Vector3.new(4, 4, 4), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = Stage3D.world })
	local sizeBox = UI.New("Part", { Name = "GizmoSize", Size = Vector3.new(4, 4, 4), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = Stage3D.world })
	local moveX = UI.New("Handles", { Adornee = moveBox, Style = Enum.HandlesStyle.Movement, Faces = Faces.new(Enum.NormalId.Left, Enum.NormalId.Right), Color3 = AXIS.x, Visible = false, Parent = app.gui })
	local moveY = UI.New("Handles", { Adornee = moveBox, Style = Enum.HandlesStyle.Movement, Faces = Faces.new(Enum.NormalId.Top, Enum.NormalId.Bottom), Color3 = AXIS.y, Visible = false, Parent = app.gui })
	local moveZ = UI.New("Handles", { Adornee = moveBox, Style = Enum.HandlesStyle.Movement, Faces = Faces.new(Enum.NormalId.Front, Enum.NormalId.Back), Color3 = AXIS.z, Visible = false, Parent = app.gui })
	local sizeH = UI.New("Handles", { Adornee = sizeBox, Style = Enum.HandlesStyle.Resize, Faces = Faces.new(Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right), Color3 = AXIS.size, Visible = false, Parent = app.gui })
	local rotH = UI.New("ArcHandles", { Adornee = moveBox, Axes = Axes.new(Enum.Axis.Y), Color3 = AXIS.rot, Visible = false, Parent = app.gui })
	self.handles = { moveX = moveX, moveY = moveY, moveZ = moveZ, size = sizeH, rotate = rotH }

	-- which white resize handles a piece has: width (left/right), depth (front/back), height (top)
	local sizeFacesKey = nil
	local function sizeFaces(def)
		local list = {}
		local sz = def.size
		if sz then
			if def.shape == "round" or def.id == "portal" or def.id == "moon" then
				list = { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }
			else
				list = { Enum.NormalId.Left, Enum.NormalId.Right }
				if sz.d and sz.dLabel == "Height" then
					table.insert(list, Enum.NormalId.Top)
				elseif sz.d then
					table.insert(list, Enum.NormalId.Front)
					table.insert(list, Enum.NormalId.Back)
				end
			end
		end
		if def.heights and not (sz and sz.dLabel == "Height") then
			table.insert(list, Enum.NormalId.Top)
		end
		if #list == 0 then
			return nil
		end
		return list
	end
	self.sizeFaces = sizeFaces

	-- a group: one box around all of its pieces, the arrows sit in its middle
	local function groupBox()
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, r in ipairs(group) do
			local cf, size = r.model:GetBoundingBox()
			local h = size / 2
			lo = Vector3.new(math.min(lo.X, cf.Position.X - h.X), math.min(lo.Y, cf.Position.Y - h.Y), math.min(lo.Z, cf.Position.Z - h.Z))
			hi = Vector3.new(math.max(hi.X, cf.Position.X + h.X), math.max(hi.Y, cf.Position.Y + h.Y), math.max(hi.Z, cf.Position.Z + h.Z))
		end
		return CFrame.new((lo + hi) / 2), hi - lo
	end
	local function updateGizmo()
		local tgt = target()
		local show = tgt ~= nil and dialog == nil and tgt.model.Parent ~= nil and (phase == "build" or tgt == pending)
		if show and not drag then
			local cf, size
			if group then
				cf, size = groupBox()
			else
				cf, size = tgt.model:GetBoundingBox()
			end
			sizeBox.CFrame = cf
			sizeBox.Size = Vector3.new(math.max(2, size.X), math.max(2, size.Y), math.max(2, size.Z))
			moveBox.CFrame = cf
			moveBox.Size = sizeBox.Size + Vector3.new(6, 6, 6)
		end
		moveX.Visible = show
		moveY.Visible = show
		moveZ.Visible = show
		rotH.Visible = show
		local faces = show and sizeFaces(tgt.def) or nil
		if faces and sizeFacesKey ~= tgt.def.id then
			sizeH.Faces = Faces.new((table.unpack or unpack)(faces))
			sizeFacesKey = tgt.def.id
		end
		sizeH.Visible = show and faces ~= nil and group == nil
		if not show then
			-- hidden handles never send MouseLeave: forget the hover, or every click would be ignored
			overHandle = false
			if drag and (not drag.refs or drag.refs.model.Parent == nil) then
				drag = nil
			end
		end
	end

	local function livePlace()
		-- rebuild the target so size changes show while dragging
		if pending then
			buildPending(pending.rec)
		elseif selected then
			local rec = selected.rec
			Stage3D.removeItem(selected)
			selected = Stage3D.addItem(rec, itemOpts())
			Stage3D.numberSpots(self.design)
		end
	end

	local function startDrag(kind)
		local tgt = target()
		if not tgt then
			return
		end
		if group and not pending then
			if kind == "size" then
				return
			end
			local members = {}
			for _, r in ipairs(group) do
				table.insert(members, { refs = r, x = r.rec.x, z = r.rec.z, yo = r.rec.yo or 0, r = r.rec.r or 0 })
			end
			drag = { kind = kind, group = members, refs = tgt, boxCF = moveBox.CFrame, cx = moveBox.CFrame.Position.X, cz = moveBox.CFrame.Position.Z }
			return
		end
		local rec = tgt.rec
		drag = { kind = kind, refs = tgt, rec = rec, x = rec.x, z = rec.z, y = rec.y or tgt.cf.Position.Y, yo = rec.yo or 0, r = rec.r or 0, w = rec.w, d = rec.d, h = rec.h, boxCF = moveBox.CFrame, riders = (tgt == selected and tgt.def.deck) and itemsOnDeck(tgt) or {} }
	end

	local function endDrag()
		if not drag then
			return
		end
		local d = drag
		drag = nil
		if d.group then
			-- decks first, then what stands on them: every floor piece finds its new floor
			table.sort(d.group, function(a, b)
				return (a.refs.def.deck and 0 or 1) < (b.refs.def.deck and 0 or 1)
			end)
			for _, m in ipairs(d.group) do
				local def = m.refs.def
				if def.mount == "side" then
					floorY(m.refs.rec, def)
				elseif def.mount ~= "rig" then
					m.refs.rec.y = Stage3D.surfaceY(m.refs.rec.x, m.refs.rec.z, m.refs)
				end
			end
			render()
			refreshStats()
			refreshInspector()
			return
		end
		local tgt, rec, def = d.refs, d.rec, d.refs.def
		if tgt == pending then
			floorY(rec, def)
			if d.kind == "size" then
				buildPending(rec)
			else
				placePending()
			end
			refreshInspector()
			refreshToolbar()
			return
		end
		if d.kind == "size" then
			local nw, nd, nx, nz, nh = rec.w, rec.d, rec.x, rec.z, rec.h
			rec.w, rec.d, rec.x, rec.z, rec.h = d.w, d.d, d.x, d.z, d.h
			local ok, msg = GS.changeItem(state, rec, { w = nw, d = nd, x = nx, z = nz, h = nh })
			if not ok then
				app:toast(msg, T.bad)
			elseif nh and d.h and nh ~= d.h then
				-- what stands on the deck goes up / down with it
				for _, rr in ipairs(d.riders) do
					if rr.y then
						rr.y = rr.y + (nh - d.h)
					end
				end
			end
		elseif d.kind == "move" and def.mount == "side" then
			floorY(rec, def) -- back onto the closest tower
		elseif d.kind == "move" and def.mount ~= "rig" then
			local newY = Stage3D.surfaceY(rec.x, rec.z, tgt)
			local dy = newY - d.y + ((rec.yo or 0) - d.yo)
			rec.y = newY
			for _, rr in ipairs(d.riders) do
				rr.x, rr.z = rr.x + (rec.x - d.x), rr.z + (rec.z - d.z)
				if rr.y then
					rr.y = rr.y + dy
				end
			end
		end
		render()
		refreshStats()
		refreshInspector()
	end

	local function hookHandle(h, kind)
		h.MouseEnter:Connect(function()
			overHandle = true
		end)
		h.MouseLeave:Connect(function()
			overHandle = false
		end)
		h.MouseButton1Down:Connect(function()
			startDrag(kind)
		end)
		h.MouseButton1Up:Connect(endDrag)
	end
	hookHandle(moveX, "move")
	hookHandle(moveY, "move")
	hookHandle(moveZ, "move")
	hookHandle(sizeH, "size")
	hookHandle(rotH, "rotate")

	local function onMove(face, distance)
		if not drag then
			return
		end
		if drag.group then
			local dx, dz, dy = 0, 0, 0
			if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
				dy = math.floor(((face == Enum.NormalId.Top) and 1 or -1) * distance / grid() + 0.5) * grid()
			else
				local dir = drag.boxCF:VectorToWorldSpace(Vector3.FromNormalId(face))
				dx, dz = snapG(dir.X * distance), snapG(dir.Z * distance)
			end
			for _, m in ipairs(drag.group) do
				if not Stage3D.inBounds(m.x + dx, m.z + dz) then
					return
				end
			end
			for _, m in ipairs(drag.group) do
				local rec, def = m.refs.rec, m.refs.def
				rec.x, rec.z = m.x + dx, m.z + dz
				rec.yo = math.clamp(m.yo + dy, (def.mount == "rig") and -20 or 0, 40)
				Builder.place(m.refs, Stage3D.itemCFrame(def, rec, m.refs))
			end
			return
		end
		local tgt, rec = drag.refs, drag.rec
		if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
			local sign = (face == Enum.NormalId.Top) and 1 or -1
			local minY = (tgt.def.mount == "rig") and -20 or 0
			rec.yo = math.clamp(math.floor((drag.yo + sign * distance) / grid() + 0.5) * grid(), minY, 40)
		else
			local dir = drag.boxCF:VectorToWorldSpace(Vector3.FromNormalId(face))
			local nx = snapG(drag.x + dir.X * distance)
			local nz = snapG(drag.z + dir.Z * distance)
			if Stage3D.inBounds(nx, nz) then
				rec.x, rec.z = nx, nz
			end
		end
		Builder.place(tgt, Stage3D.itemCFrame(tgt.def, rec, tgt))
	end
	moveX.MouseDrag:Connect(onMove)
	moveY.MouseDrag:Connect(onMove)
	moveZ.MouseDrag:Connect(onMove)
	sizeH.MouseDrag:Connect(function(face, distance)
		if not drag or not drag.refs.def.size then
			return
		end
		local def = drag.refs.def
		local sz = def.size
		local n = Vector3.FromNormalId(face)
		local step = math.floor(distance / grid() + 0.5) * grid()
		local rec = drag.rec
		-- the side you pull grows, the other side stays where it is. Hold Shift: both sides grow (centre stays)
		local both = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if face == Enum.NormalId.Top and def.heights and sz.dLabel ~= "Height" then
			-- pull the top up / down: the deck gets higher / lower (in its height steps)
			local want = (drag.h or def.h or 6) + distance
			local best = def.heights[1]
			for _, h in ipairs(def.heights) do
				if math.abs(h - want) < math.abs(best - want) then
					best = h
				end
			end
			if rec.h ~= best then
				rec.h = best
				livePlace()
				drag.refs = target()
			end
			return
		end
		if def.shape == "round" or def.id == "portal" or def.id == "moon" then
			rec.w = math.clamp((drag.w or sz.w) + step * 2, sz.minW, sz.maxW)
		elseif not sz.d or math.abs(n.X) > 0.5 then
			if math.abs(n.X) > 0.5 then
				local w = math.clamp((drag.w or sz.w) + step * (both and 2 or 1), sz.minW, sz.maxW)
				local shift = both and 0 or (w - (drag.w or sz.w)) / 2 * n.X
				local world = drag.boxCF:VectorToWorldSpace(Vector3.new(shift, 0, 0))
				rec.w, rec.x, rec.z = w, drag.x + world.X, drag.z + world.Z
			end
		else
			local dd = math.clamp((drag.d or sz.d) + step * (both and 2 or 1), sz.minD, sz.maxD)
			local shift = both and 0 or (dd - (drag.d or sz.d)) / 2 * n.Z
			local world = drag.boxCF:VectorToWorldSpace(Vector3.new(0, 0, shift))
			rec.d, rec.x, rec.z = dd, drag.x + world.X, drag.z + world.Z
		end
		livePlace()
		drag.refs = target()
	end)
	rotH.MouseDrag:Connect(function(axis, relativeAngle)
		if not drag then
			return
		end
		local step = TURNS[turnIndex]
		if drag.group then
			-- the whole group turns around its middle
			local a = math.floor(math.deg(relativeAngle) / step + 0.5) * step
			local turn = CFrame.Angles(0, math.rad(a), 0)
			for _, m in ipairs(drag.group) do
				local off = turn * Vector3.new(m.x - drag.cx, 0, m.z - drag.cz)
				local rec = m.refs.rec
				rec.x, rec.z = snapG(drag.cx + off.X), snapG(drag.cz + off.Z)
				rec.r = (m.r + a) % 360
				Builder.place(m.refs, Stage3D.itemCFrame(m.refs.def, rec, m.refs))
			end
			return
		end
		local r = math.floor((drag.r + math.deg(relativeAngle)) / step + 0.5) * step
		drag.rec.r = r % 360
		Builder.place(drag.refs, Stage3D.itemCFrame(drag.refs.def, drag.rec, drag.refs))
	end)

	------------------------------------------------------------ input
	-- the piece under the mouse is put down (not bought yet: Q / Enter / the green button buys it)
	putDown = function()
		if not ghost then
			return false
		end
		if not ghost.ok then
			if ghost.noTower then
				app:toast("Point at a Truss Tower (Stage category): side mounts clamp onto a tower.", T.warn)
			elseif #self.design.items >= cls().maxItems then
				app:toast("This " .. self.design.class .. " stage is full (" .. cls().maxItems .. " items).", T.warn)
			elseif state.money < Sim.itemPrice(placeDef, ghostRec) then
				app:toast("Not enough money for " .. placeDef.name .. ".", T.bad)
			else
				app:toast("Outside the build area (gold lines).", T.warn)
			end
			return false
		end
		local rec = Util.deepCopy(ghostRec)
		rec.x, rec.z = ghost.x, ghost.z
		if placeDef.mount == "side" then
			rec.y = ghost.y
		end
		floorY(rec, placeDef)
		clearGhost()
		mode = "pending"
		buildPending(rec)
		refreshList()
		refreshInspector()
		refreshToolbar()
		return true
	end
	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp or app.modalOpen or dialog then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if mouseOverUI() or (overHandle and moveX.Visible) or drag then
				return
			end
			if copyPick then
				-- choosing screens: a click adds / removes a screen
				self.copyPickToggle(itemUnderMouse())
				return
			end
			if mode == "place" and placeDef then
				putDown()
			elseif mode == "pending" and pending then
				-- a click somewhere else does nothing: the new piece only moves with the arrows
				-- (an accidental click must never move it away)
				return
			else
				local hit = itemUnderMouse()
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				if shift and hit and phase == "build" then
					toggleInGroup(hit) -- Shift + click: add to / remove from the group
				elseif not shift then
					select(hit)
				end
			end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local k = input.KeyCode
			local building = phase == "build"
			if k == Enum.KeyCode.R and building then
				rotate(TURNS[turnIndex])
			elseif k == Enum.KeyCode.E and building then
				rotate(-TURNS[turnIndex])
			elseif k == Enum.KeyCode.Q then
				-- Q places: the piece under the mouse is put down and bought in one go
				if pending then
					confirm()
				elseif mode == "place" and placeDef and putDown() then
					confirm()
				end
			elseif k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
				confirm()
			elseif k == Enum.KeyCode.C and building then
				copySelected()
			elseif k == Enum.KeyCode.M and building and (selected or group) and not pending then
				mirrorChosen()
			elseif k == Enum.KeyCode.X or k == Enum.KeyCode.Delete then
				if building or pending or (selected and selected.def.id == "spot") then
					deleteSelected()
				end
			elseif k == Enum.KeyCode.F or k == Enum.KeyCode.Escape then
				cancel()
			elseif k == Enum.KeyCode.T then
				pitch = (pitch > 1.3) and 0.6 or 1.45
			elseif k == Enum.KeyCode.H then
				local show = not catalog.Visible
				catalog.Visible = show and phase == "build"
				toolbar.Visible = show and phase == "build"
				statsBar.Visible = show
				inspector.Visible = show and target() ~= nil
			end
		end
	end))
	table.insert(self.conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))
	table.insert(self.conns, UserInputService.InputChanged:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
			yaw = yaw - input.Delta.X * 0.006
			pitch = math.clamp(pitch + input.Delta.Y * 0.006, 0.15, 1.45)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gp and not mouseOverUI() then
			dist = math.clamp(dist * (1 - input.Position.Z * 0.12), 20, CLASS_MAXDIST[self.design.class] or 240)
		end
	end))

	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		if not app.modalOpen and not UserInputService:GetFocusedTextBox() then
			local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
			local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
			local move = Vector3.new()
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				move = move + fwd
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				move = move - fwd
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				move = move + right
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				move = move - right
			end
			if move.Magnitude > 0 then
				local x0, x1, z0, z1 = Stage3D.bounds()
				focus = focus + move.Unit * dt * (40 + dist * 0.4)
				focus = Vector3.new(math.clamp(focus.X, x0 - 10, x1 + 10), focus.Y, math.clamp(focus.Z, z0 - 10, z1 + 10))
			end
		end
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 60
		local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)) * dist
		cam.CFrame = CFrame.lookAt(focus + offset, focus + Vector3.new(0, 0, -0.01))
		updateGhost()
		updateHover()
		updateGizmo()
		updatePriceTag()
	end))

	function self.cleanup()
		for _, c in ipairs(self.conns) do
			c:Disconnect()
		end
		self.conns = {}
		clearGhost()
		clearPending()
		if venuePreview then
			Venue.destroy(venuePreview)
			venuePreview = nil
		end
		for _, b in ipairs(groupBoxes) do
			b:Destroy()
		end
		endCopyPick()
		for _, inst in ipairs({ selHighlight, hoverHighlight, pendingHighlight, moveX, moveY, moveZ, sizeH, rotH, moveBox, sizeBox }) do
			inst:Destroy()
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		root:Destroy()
		Stage3D.clearDesign()
		Stage3D.showGrid(false)
	end
	self.previewArtist = previewArtist
	self.select = select
	self.toggleInGroup = toggleInGroup
	self.group = function()
		return group
	end
	self.setMode = setMode
	self.confirm = confirm
	self.cancel = cancel
	self.target = target
	self.panels = panels
end

function Designer.close()
	local self = Designer.current
	if not self then
		return
	end
	Designer.current = nil
	self.cleanup()
	self.app:saveDesign(self.design)
end

function Designer.preview()
	local self = Designer.current
	if not self then
		return
	end
	local ad = self.previewArtist()
	if not ad then
		self.app:toast("Sign an artist first.", T.warn)
		return
	end
	-- a show needs a stage: at least one stage deck
	local hasDeck = false
	for _, it in ipairs(self.design.items) do
		local def = StageItems.byId[it.t]
		if def and def.deck then
			hasDeck = true
		end
	end
	if not hasDeck then
		self.app:toast("You need a stage first: place at least one stage deck (STAGE category).", T.warn, 6)
		return
	end
	local app, design = self.app, self.design
	Designer.close()
	local LiveShow = require(Root.Client.LiveShow)
	local cap = CLASS_CAP[design.class] or 15000
	LiveShow.run(app, {
		artistId = ad.id,
		design = design,
		look = CLASS_LOOK[design.class] or "arena",
		cap = cap,
		sold = math.floor(cap * 0.95),
		tourName = design.name,
		preview = true,
		onDone = function()
			Designer.open(app, design.id)
		end,
	})
end

return Designer
