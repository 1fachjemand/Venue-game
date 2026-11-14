-- Stage Designer: build your own stage in 3D from decks, triangles, rounds, lights, screens and effects.
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

local T = UI.Theme
local Designer = {}

-- a typical venue size per stage class (for the quality preview)
local CLASS_CAP = { Club = 400, Theatre = 3000, Arena = 18000, Stadium = 70000 }
local CLASS_LOOK = { Club = "club", Theatre = "theatre", Arena = "arena", Stadium = "stadium" }
local CLASS_DIST = { Club = 75, Theatre = 105, Arena = 160, Stadium = 250 }
local CLASS_MAXDIST = { Club = 110, Theatre = 150, Arena = 240, Stadium = 360 }

local KEY_HELP = "H: hide menus  |  Left-click: place / select   |   R / Q / E: rotate 15 deg   |   G: move   |   C: copy   |   X: delete   |   F: cancel   |   Right-drag: turn camera   |   Wheel: zoom   |   WASD: move camera   |   T: top view"

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

	-- tool state
	local tool = "select" -- "select" | "place" | "move"
	local placeDef = nil
	local ghostRec = nil -- settings of the next piece to place: { t, r, w, d, h }
	local lastSettings = {}
	local selected = nil -- refs of the selected item
	local moving = nil -- { rec = rec, attached = { {rec, dx, dz} }, startX, startZ, startY }
	local ghost, ghostKey = nil, nil
	local hovered = nil
	local focus = Vector3.new(0, 6, 0)
	local yaw, pitch, dist = 0, 0.6, 150
	local rotating = false

	local selHighlight = UI.New("Highlight", { FillColor = T.gold, FillTransparency = 0.6, OutlineColor = T.gold, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = Stage3D.world })
	local gizmoMode = "move" -- drag arrows: "move" | "size" | "rotate"
	local gridSize = 1
	local screenSlot = "default" -- which spot's screen content is being edited
	local function snapG(v)
		return math.floor(v / gridSize + 0.5) * gridSize
	end
	local overHandle = false
	local hoverHighlight = UI.New("Highlight", { FillColor = Color3.new(1, 1, 1), FillTransparency = 0.85, OutlineColor = Color3.new(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = Stage3D.world })

	local function resetCamera()
		local x0, x1, z0, z1 = Stage3D.bounds()
		focus = Vector3.new((x0 + x1) / 2, 6, design.layout == "center" and 0 or (z0 + (z1 - z0) * 0.3))
		dist = CLASS_DIST[design.class] or 150
		yaw, pitch = 0, 0.6
	end

	local Venue = require(Root.Client.Venue)
	local venuePreview = nil
	local function render()
		local keepRec = selected and selected.rec
		Stage3D.renderDesign(self.design, itemOpts())
		Stage3D.showGrid(true)
		selected = nil
		if keepRec then
			for _, r in ipairs(Stage3D.items) do
				if r.rec == keepRec then
					selected = r
				end
			end
		end
		-- a simple venue of this size around the stage, so you can see where the fans stand
		-- (only rebuilt when the decks change, because the crowd stands around them)
		local sig = self.design.class .. self.design.layout
		for _, rec in ipairs(self.design.items) do
			local def = StageItems.byId[rec.t]
			if def and def.deck then
				sig = sig .. "|" .. rec.t .. rec.x .. "," .. rec.z .. "," .. tostring(rec.r) .. tostring(rec.w) .. tostring(rec.d) .. tostring(rec.h) .. tostring(rec.y)
			end
		end
		if venuePreview and sig == self.venueSig then
			return
		end
		self.venueSig = sig
		if venuePreview then
			Venue.destroy(venuePreview)
		end
		venuePreview = Venue.build(CLASS_LOOK[self.design.class] or "arena", 0, nil, {
			empty = true,
			layout = self.design.layout,
			noRoof = true,
			standingColor = Color3.fromRGB(70, 96, 120),
		})
		selected = nil
		if keepRec then
			for _, r in ipairs(Stage3D.items) do
				if r.rec == keepRec then
					selected = r
				end
			end
		end
	end
	design = self.design
	Stage3D.setDesign(design)
	render()
	resetCamera()

	------------------------------------------------------------ UI layout
	local root = UI.New("Frame", { Parent = app.canvas, Size = UI.px(1920, 1080), BackgroundTransparency = 1, Name = "Designer" })
	self.root = root
	local left = UI.Panel(root, UI.px(16, 64), UI.px(320, 1000), T.panel)
	left.BackgroundTransparency = 0.05
	UI.Label(left, "BUILD", UI.px(18, 12), UI.px(290, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	local catFrame = UI.New("Frame", { Parent = left, Position = UI.px(12, 54), Size = UI.px(296, 80), BackgroundTransparency = 1 })
	UI.New("UIGridLayout", { Parent = catFrame, CellSize = UI.px(94, 34), CellPadding = UI.px(7, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local list = UI.Scroll(left, UI.px(10, 142), UI.px(306, 726))
	UI.New("UIGridLayout", { Parent = list, CellSize = UI.px(142, 150), CellPadding = UI.px(8, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local descBox = UI.Panel(left, UI.px(12, 876), UI.px(296, 112), T.panel2)
	local descTitle = UI.Label(descBox, "Pick an item", UI.px(10, 6), UI.px(276, 24), { textSize = 17, font = UI.FontBold })
	local descText = UI.Label(descBox, "Start with STAGE: decks, triangles and round pieces. Resize and rotate them to build any shape.", UI.px(10, 32), UI.px(276, 76), { textSize = 14, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })

	local top = UI.Panel(root, UI.px(352, 16), UI.px(1552, 116), T.panel)
	top.BackgroundTransparency = 0.05
	local moneyBox = UI.Panel(root, UI.px(1584, 148), UI.px(320, 72), T.panel)
	UI.Label(moneyBox, "YOUR MONEY", UI.px(18, 6), UI.px(200, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	local moneyLbl = UI.Label(moneyBox, "", UI.px(18, 26), UI.px(290, 40), { textSize = 30, font = UI.FontBlack, color = T.good })
	local lastMoney = nil
	local function refreshMoney()
		local m = state.money
		moneyLbl.Text = Util.money(m)
		if lastMoney and m ~= lastMoney then
			moneyLbl.TextColor3 = (m < lastMoney) and T.bad or T.gold
			local delta = m - lastMoney
			local fl = UI.Label(moneyBox, (delta > 0 and "+" or "-") .. Util.money(math.abs(delta)), UI.px(150, 6), UI.px(156, 20), { textSize = 15, font = UI.FontBold, color = (delta > 0) and T.good or T.bad, alignX = Enum.TextXAlignment.Right })
			task.delay(1.2, function()
				fl:Destroy()
				moneyLbl.TextColor3 = state.money < 0 and T.bad or T.good
			end)
		end
		lastMoney = m
	end
	local props = UI.Panel(root, UI.px(1584, 232), UI.px(320, 772), T.panel)
	props.BackgroundTransparency = 0.05
	local hint = UI.Panel(root, UI.px(352, 1016), UI.px(1552, 48), T.panel)
	hint.BackgroundTransparency = 0.1
	local hintLbl = UI.Label(hint, KEY_HELP, UI.px(150, 0), UI.px(1390, 48), { textSize = 14, color = T.sub })
	local gridBtn
	gridBtn = UI.Button(hint, "Grid: 1", UI.px(8, 6), UI.px(130, 36), { textSize = 15, color = T.accent2, textColor = Color3.new(0, 0, 0) }, function()
		gridSize = (gridSize == 1) and 2 or ((gridSize == 2) and 4 or ((gridSize == 4) and 8 or 1))
		gridBtn.Text = "Grid: " .. gridSize
	end)
	local panels = { left, top, props, hint, moneyBox }
	local dialog = nil

	local currentCat = "Stage"
	local refreshStats, refreshList, refreshTop, refreshProps

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
		return rec
	end

	local function clearGhost()
		if ghost then
			ghost.model:Destroy()
			ghost = nil
			ghostKey = nil
		end
	end

	local function setTool(newTool, def)
		clearGhost()
		tool = newTool
		placeDef = def
		if newTool == "place" then
			ghostRec = defaultsFor(def)
			selected = nil
			descTitle.Text = def.name .. "  -  " .. Util.money(Sim.itemPrice(def, ghostRec))
			descText.Text = def.desc .. ((def.mount == "rig") and " (Hangs from the rig.)" or "")
		end
		refreshList()
		refreshProps()
	end

	local function select(refs)
		selected = refs
		if refs then
			tool = "select"
			placeDef = nil
			clearGhost()
		end
		refreshList()
		refreshProps()
	end

	local function mouseOverUI()
		if app.modalOpen then
			return true
		end
		local m = UserInputService:GetMouseLocation()
		local all = { left, top, props, hint, moneyBox }
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

	-- floor/deck point under the mouse (snapped to whole studs)
	local function mousePoint(except, def)
		local ray = mouseRay()
		local hit = Stage3D.raycast(ray.Origin, ray.Direction * 3000, except)
		if not hit then
			return nil
		end
		local x, z = snapG(hit.Position.X), snapG(hit.Position.Z)
		if def and def.mount == "rig" and def.id ~= "truss_beam" then
			x, z = Stage3D.snapToTruss(x, z) -- lights click onto truss beams
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

	------------------------------------------------------------ catalog
	-- small 3D picture of an item (ViewportFrame)
	local function thumbnail(parent, def)
		local vp = UI.New("ViewportFrame", {
			Parent = parent,
			Position = UI.px(6, 6),
			Size = UI.px(130, 82),
			BackgroundColor3 = Color3.fromRGB(34, 36, 50),
			BorderSizePixel = 0,
			Ambient = Color3.fromRGB(170, 170, 185),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -0.6),
			UI.Corner(6),
		})
		local refs = Builder.build(def, { color = itemOpts().color, artistName = "", rec = { t = def.id } })
		Builder.rest(refs)
		refs.model.Parent = vp
		local cf, size = refs.model:GetBoundingBox()
		local r = math.max(size.X, size.Y, size.Z)
		local cam = UI.New("Camera", { FieldOfView = 40, Parent = vp })
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.9, 0.7, 1.1).Unit * (r * 1.55 + 2), cf.Position)
		vp.CurrentCamera = cam
	end

	refreshList = function()
		UI.ClearChildren(list)
		for _, def in ipairs(StageItems.list) do
			if def.cat == currentCat then
				local isSel = placeDef == def
				local b = UI.Button(list, "", nil, nil, { order = def.order, color = isSel and T.accent or T.panel3 }, function()
					if placeDef == def then
						setTool("select")
					else
						setTool("place", def)
					end
				end)
				thumbnail(b, def)
				UI.Label(b, def.name, UI.px(8, 92), UI.px(128, 22), { textSize = 14, font = UI.FontBold })
				local price = (def.cost > 0) and Util.money(Sim.itemPrice(def)) or "Free"
				UI.Label(b, price .. (def.size and "  |  size" or ""), UI.px(8, 116), UI.px(128, 20), { textSize = 12, color = isSel and T.text or T.sub })
			end
		end
	end

	for i, cat in ipairs(StageItems.CATEGORIES) do
		local b
		b = UI.Button(catFrame, cat.name, nil, nil, { order = i, textSize = 15, color = (cat.id == currentCat) and T.accent2 or T.panel3, textColor = (cat.id == currentCat) and Color3.new(0, 0, 0) or T.text }, function()
			currentCat = cat.id
			for _, other in ipairs(catFrame:GetChildren()) do
				if other:IsA("TextButton") then
					other.BackgroundColor3 = T.panel3
					other.TextColor3 = T.text
				end
			end
			b.BackgroundColor3 = T.accent2
			b.TextColor3 = Color3.new(0, 0, 0)
			refreshList()
		end)
	end

	------------------------------------------------------------ properties panel
	-- applies a change to the ghost (placing) or to the selected item (paying the price difference)
	local function applyChange(changes)
		if tool == "place" and ghostRec then
			for k, v in pairs(changes) do
				ghostRec[k] = v
			end
			lastSettings[placeDef.id] = Util.deepCopy(ghostRec)
			clearGhost()
			descTitle.Text = placeDef.name .. "  -  " .. Util.money(Sim.itemPrice(placeDef, ghostRec))
			refreshProps()
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
		render()
		refreshStats()
		refreshProps()
	end

	local function rotate(delta)
		if tool == "place" and ghostRec then
			applyChange({ r = ((ghostRec.r or 0) + delta) % 360 })
		elseif selected then
			applyChange({ r = ((selected.rec.r or 0) + delta) % 360 })
		end
	end

	local function deleteSelected()
		if not selected then
			return
		end
		local refs = selected
		local wasDeck = refs.def.deck
		selected = nil
		GS.sellItem(state, self.design, refs.rec)
		Stage3D.removeItem(refs)
		if wasDeck then
			render()
		end
		refreshStats()
		refreshProps()
	end

	local function startMove()
		if not selected then
			return
		end
		local rec = selected.rec
		local attached = {}
		if selected.def.deck then
			for _, r in ipairs(itemsOnDeck(selected)) do
				table.insert(attached, r)
			end
		end
		moving = { rec = rec, attached = attached, x = rec.x, z = rec.z, y = rec.y or selected.cf.Position.Y }
		tool = "move"
		-- hide the original while moving
		selected.model.Parent = nil
		for _, ar in ipairs(attached) do
			for _, r in ipairs(Stage3D.items) do
				if r.rec == ar then
					r.model.Parent = nil
				end
			end
		end
		refreshProps()
	end

	local function copySelected()
		if not selected then
			return
		end
		-- the copy is placed parallel next to the original (along its own depth axis)
		local rec = Util.deepCopy(selected.rec)
		local d = selected.def
		local off = ((d.size and d.size.d) and (rec.d or d.size.d) or 6) + 2
		local o = CFrame.Angles(0, math.rad(rec.r or 0), 0) * Vector3.new(0, 0, off)
		rec.x, rec.z = snapG(rec.x + o.X), snapG(rec.z + o.Z)
		if not Stage3D.inBounds(rec.x, rec.z) then
			rec.x, rec.z = snapG(selected.rec.x - o.X), snapG(selected.rec.z - o.Z)
		end
		local ok, msg = GS.buyItem(state, self.design, rec)
		if not ok then
			app:toast(msg, T.bad)
			return
		end
		render()
		local refs = nil
		for _, r in ipairs(Stage3D.items) do
			if r.rec == rec then
				refs = r
			end
		end
		gizmoMode = "move"
		select(refs)
		refreshStats()
		app:toast("Copied. Use the arrows to line it up.", T.good, 3)
	end

	refreshProps = function()
		UI.ClearChildren(props)
		local def, rec
		if tool == "place" and placeDef then
			def, rec = placeDef, ghostRec
			UI.Label(props, "PLACING", UI.px(16, 12), UI.px(288, 22), { textSize = 14, color = T.accent2, font = UI.FontBold })
		elseif tool == "move" and moving then
			UI.Label(props, "MOVING", UI.px(16, 12), UI.px(288, 22), { textSize = 14, color = T.accent2, font = UI.FontBold })
			UI.Label(props, "Click where the item should go. Press F to cancel.", UI.px(16, 40), UI.px(288, 60), { textSize = 17, wrap = true })
			return
		elseif selected then
			def, rec = selected.def, selected.rec
			UI.Label(props, "SELECTED", UI.px(16, 12), UI.px(288, 22), { textSize = 14, color = T.gold, font = UI.FontBold })
		else
			UI.Label(props, "PROPERTIES", UI.px(16, 12), UI.px(288, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			UI.Label(props, "Click an item on the left to place it, or click a placed item on the stage to select and edit it.", UI.px(16, 40), UI.px(288, 120), { textSize = 16, wrap = true, color = T.sub, alignY = Enum.TextYAlignment.Top })
			return
		end
		UI.Label(props, def.name, UI.px(16, 34), UI.px(288, 32), { textSize = 22, font = UI.FontBlack })
		UI.Label(props, (def.cost > 0 and Util.money(Sim.itemPrice(def, rec)) or "Free") .. (selected and tool ~= "place" and "  (sells for " .. math.floor(Config.RESALE * 100) .. "%)" or ""), UI.px(16, 66), UI.px(288, 22), { textSize = 14, color = T.sub })
		local y = 100
		local function row(label, value, onMinus, onPlus)
			UI.Label(props, label, UI.px(16, y), UI.px(96, 40), { textSize = 14, color = T.sub, font = UI.FontBold })
			UI.Button(props, "-", UI.px(112, y), UI.px(44, 40), { textSize = 20 }, onMinus)
			UI.Label(props, value, UI.px(158, y), UI.px(100, 40), { textSize = 18, font = UI.FontBold, alignX = Enum.TextXAlignment.Center })
			UI.Button(props, "+", UI.px(260, y), UI.px(44, 40), { textSize = 20 }, onPlus)
			y = y + 48
		end
		row("Rotation", (rec.r or 0) .. " deg", function()
			rotate(-15)
		end, function()
			rotate(15)
		end)
		if def.size then
			local sz = def.size
			local wLabel = (def.shape == "round") and "Diameter" or ((def.mount == "rig") and "Length" or "Width")
			row(wLabel, (rec.w or sz.w) .. " st", function()
				applyChange({ w = math.max(sz.minW, (rec.w or sz.w) - 2) })
			end, function()
				applyChange({ w = math.min(sz.maxW, (rec.w or sz.w) + 2) })
			end)
			if sz.d then
				row(sz.dLabel or "Depth", (rec.d or sz.d) .. " st", function()
					applyChange({ d = math.max(sz.minD, (rec.d or sz.d) - 2) })
				end, function()
					applyChange({ d = math.min(sz.maxD, (rec.d or sz.d) + 2) })
				end)
			end
		end
		if def.heights then
			UI.Label(props, "Height", UI.px(16, y), UI.px(120, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
			y = y + 24
			for i, h in ipairs(def.heights) do
				local cur = (rec.h or def.h) == h
				UI.Button(props, tostring(h), UI.px(16 + (i - 1) * 41, y), UI.px(38, 36), { textSize = 16, color = cur and T.accent or T.panel3 }, function()
					applyChange({ h = h })
				end)
			end
			y = y + 50
		end
		if def.deck then
			-- surface look + edge lights, optionally for every deck at once
			UI.Label(props, "Surface", UI.px(16, y), UI.px(120, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			y = y + 24
			for i, sk in ipairs(Builder.SKINS) do
				local cur = (rec.skin or "black") == sk
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				UI.Button(props, sk == "led" and "LED screen" or (sk:sub(1, 1):upper() .. sk:sub(2)), UI.px(16 + col * 97, y + row * 40), UI.px(92, 34), { textSize = 13, color = cur and T.accent or T.panel3 }, function()
					applyChange({ skin = sk })
				end)
			end
			y = y + 84
			UI.Button(props, (rec.edge and "[X]" or "[  ]") .. " Edge lights", UI.px(16, y), UI.px(140, 34), { textSize = 13 }, function()
				applyChange({ edge = not rec.edge })
			end)
			if tool ~= "place" and selected then
				UI.Button(props, "SET ALL DECKS", UI.px(164, y), UI.px(140, 34), { textSize = 13, color = T.accent2, textColor = Color3.new(0, 0, 0) }, function()
					local total = 0
					for _, other in ipairs(self.design.items) do
						local od = StageItems.byId[other.t]
						if od and od.deck and other ~= rec then
							local ok = GS.changeItem(state, other, { skin = rec.skin or "black", edge = rec.edge == true })
							if ok then
								total = total + 1
							end
						end
					end
					app:toast("Applied to " .. total .. " other decks.", T.good)
					render()
					refreshStats()
					refreshProps()
				end)
			end
			y = y + 44
		end
		if def.id == "led" or def.id == "led_side" then
			-- screen editor: one setting for the whole show (DEFAULT) + optional changes per artist spot
			local scr = rec.scr and Util.deepCopy(rec.scr) or { default = Builder.screenConfig({ rec = rec, kind = def.id }, nil) }
			UI.Label(props, "Screen shows", UI.px(16, y), UI.px(200, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			y = y + 24
			local slots = { "default", "1", "2", "3", "4" }
			for i, sl in ipairs(slots) do
				local on = screenSlot == sl
				local has = scr[sl] ~= nil
				UI.Button(props, (sl == "default") and "Always" or ("Spot " .. sl), UI.px(16 + (i - 1) * 58, y), UI.px(54, 30), { textSize = 11, color = on and T.accent2 or (has and T.panel2 or T.panel3), textColor = on and Color3.new(0, 0, 0) or (has and T.gold or T.text) }, function()
					screenSlot = sl
					refreshProps()
				end)
			end
			y = y + 36
			local curCfg = scr[screenSlot]
			local summary = curCfg and (Builder.SCREEN_NAMES[curCfg.m] or curCfg.m) or "same as Always"
			UI.Label(props, ((screenSlot == "default") and "Whole show: " or ("At spot " .. screenSlot .. ": ")) .. summary, UI.px(16, y), UI.px(288, 20), { textSize = 13, color = T.gold })
			y = y + 22
			local modes = { { "song", "Song title" }, { "artist", "Artist name" }, { "text", "Own text" }, { "image", "Image ID" }, { "liveArtist", "Live: artist" }, { "liveCrowd", "Live: crowd" } }
			local function setSlot(cfg)
				local new = Util.deepCopy(scr)
				new[screenSlot] = cfg
				if not new.default then
					new.default = { m = (def.id == "led_side") and "artist" or "song" }
				end
				applyChange({ scr = new })
			end
			for i, md in ipairs(modes) do
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				UI.Button(props, md[2], UI.px(16 + col * 97, y + row * 36), UI.px(92, 32), { textSize = 12, color = (curCfg and curCfg.m == md[1]) and T.accent or T.panel3 }, function()
					local cfg = { m = md[1], text = curCfg and curCfg.text, img = curCfg and curCfg.img }
					setSlot(cfg)
				end)
			end
			y = y + 76
			if curCfg and (curCfg.m == "text" or curCfg.m == "image") then
				local isText = curCfg.m == "text"
				local box = UI.New("TextBox", {
					Parent = props,
					Position = UI.px(16, y),
					Size = UI.px(288, 34),
					BackgroundColor3 = T.panel2,
					BorderSizePixel = 0,
					Text = isText and (curCfg.text or "") or tostring(curCfg.img or ""),
					PlaceholderText = isText and "Text on the screen" or "Roblox image ID (numbers)",
					ClearTextOnFocus = false,
					TextColor3 = T.text,
					TextSize = 15,
					Font = UI.Font,
					UI.Corner(6),
				})
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
					app:toast("Screen saved.", T.good, 2)
				end)
				y = y + 42
			end
			if screenSlot ~= "default" and curCfg then
				UI.Button(props, "Remove spot " .. screenSlot .. " change", UI.px(16, y), UI.px(288, 30), { textSize = 12 }, function()
					local new = Util.deepCopy(scr)
					new[screenSlot] = nil
					applyChange({ scr = new })
				end)
				y = y + 36
			end
			if tool ~= "place" and selected then
				UI.Button(props, "SET ALL SCREENS", UI.px(16, y), UI.px(288, 32), { textSize = 13, color = T.accent2, textColor = Color3.new(0, 0, 0) }, function()
					local n = 0
					for _, other in ipairs(self.design.items) do
						if (other.t == "led" or other.t == "led_side") and other ~= rec then
							other.scr = Util.deepCopy(scr)
							n = n + 1
						end
					end
					app:toast("All " .. (n + 1) .. " screens now show the same.", T.good)
					render()
					refreshProps()
				end)
				y = y + 40
			end
		end
		if def.id == "lift" then
			UI.Label(props, "Artist comes up here at spot", UI.px(16, y), UI.px(288, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			y = y + 24
			for i, n in ipairs({ 1, 2, 3, 4 }) do
				local on = (rec.play or 1) == n
				UI.Button(props, tostring(n), UI.px(16 + (i - 1) * 72, y), UI.px(66, 30), { textSize = 13, color = on and T.accent2 or T.panel3, textColor = on and Color3.new(0, 0, 0) or T.text }, function()
					applyChange({ play = n })
				end)
			end
			y = y + 36
			UI.Label(props, "No Artist Spot needed: the lift is that spot. 1 = big entrance at the start.", UI.px(16, y), UI.px(288, 40), { textSize = 12, color = T.sub, wrap = true })
			y = y + 44
		end
		if def.id == "piano" or def.id == "drums" or def.id == "djbooth" then
			UI.Label(props, "Artist plays this at spot", UI.px(16, y), UI.px(288, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			y = y + 24
			for i, n in ipairs({ false, 1, 2, 3, 4 }) do
				local on = (rec.play or false) == n
				UI.Button(props, n and tostring(n) or "Off", UI.px(16 + (i - 1) * 58, y), UI.px(54, 30), { textSize = 13, color = on and T.accent2 or T.panel3, textColor = on and Color3.new(0, 0, 0) or T.text }, function()
					applyChange({ play = n })
				end)
			end
			y = y + 40
		end
		if tool ~= "place" and selected then
			UI.Label(props, "Drag arrows", UI.px(16, y), UI.px(120, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
			y = y + 24
			local modes = { { "move", "MOVE" }, { "size", "SIZE" }, { "rotate", "ROTATE" } }
			for i, mm in ipairs(modes) do
				local can = mm[1] ~= "size" or def.size ~= nil
				UI.Button(props, mm[2], UI.px(16 + (i - 1) * 97, y), UI.px(92, 34), { textSize = 13, color = (gizmoMode == mm[1]) and T.accent or T.panel3, disabled = not can }, function()
					gizmoMode = mm[1]
					refreshProps()
				end)
			end
			y = y + 44
			UI.Button(props, "MOVE (G)", UI.px(16, y), UI.px(92, 44), { textSize = 15, color = T.accent2, textColor = Color3.new(0, 0, 0) }, startMove)
			UI.Button(props, "COPY (C)", UI.px(114, y), UI.px(92, 44), { textSize = 15 }, copySelected)
			UI.Button(props, "DELETE (X)", UI.px(212, y), UI.px(92, 44), { textSize = 13, color = UI.shade(T.bad, 0.7) }, deleteSelected)
			y = y + 56
		end
		local tip = def.desc
		if def.id == "spot" then
			tip = "Spot numbers follow the order you place them. 1 = opening, 2 = second song, 3 = ballad, 4 = finale."
		elseif def.deck then
			tip = "Stack decks to build levels. Items placed on a deck move with it."
		end
		UI.Label(props, tip, UI.px(16, y), UI.px(288, math.max(30, 772 - y - 10)), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	end

	------------------------------------------------------------ top bar
	local statsLbl
	local function switchDesign(d)
		self.design = d
		design = d
		app.lastDesignId = d.id
		selected = nil
		setTool("select")
		Stage3D.setDesign(d)
		render()
		resetCamera()
		refreshTop()
	end

	local function newDesignDialog(preClass)
		if dialog then
			dialog:Destroy()
		end
		local choice = { class = (type(preClass) == "string") and preClass or "Arena", layout = "end", template = true }
		dialog = UI.Panel(root, UI.px(560, 200), UI.px(800, 620), T.panel)
		UI.Stroke(T.accent, 2, 0).Parent = dialog
		local function draw()
			UI.ClearChildren(dialog)
			UI.Label(dialog, "NEW STAGE DESIGN", UI.px(28, 20), UI.px(700, 40), { textSize = 30, font = UI.FontBlack, color = T.accent })
			UI.Label(dialog, "SIZE CLASS - the design can be used in venues of this size or bigger", UI.px(28, 76), UI.px(740, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
			for i, c in ipairs(Config.STAGE_CLASSES) do
				local sel = choice.class == c.id
				local b = UI.Button(dialog, "", UI.px(28 + (i - 1) * 186, 104), UI.px(176, 96), { color = sel and T.accent or T.panel3 }, function()
					choice.class = c.id
					draw()
				end)
				UI.Label(b, string.upper(c.id), UI.px(10, 8), UI.px(156, 30), { textSize = 21, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
				UI.Label(b, c.desc, UI.px(8, 42), UI.px(160, 46), { textSize = 13, wrap = true, alignX = Enum.TextXAlignment.Center })
			end
			UI.Label(dialog, "STAGE TYPE", UI.px(28, 222), UI.px(740, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
			local layouts = { { "end", "END STAGE", "Classic: the stage at one end, fans in front." }, { "center", "CENTER STAGE", "In the round: fans on every side." } }
			for i, l in ipairs(layouts) do
				local sel = choice.layout == l[1]
				local b = UI.Button(dialog, "", UI.px(28 + (i - 1) * 376, 250), UI.px(366, 90), { color = sel and T.accent or T.panel3 }, function()
					choice.layout = l[1]
					draw()
				end)
				UI.Label(b, l[2], UI.px(14, 8), UI.px(340, 34), { textSize = 22, font = UI.FontBlack })
				UI.Label(b, l[3], UI.px(14, 46), UI.px(340, 36), { textSize = 15, wrap = true })
			end
			UI.Button(dialog, (choice.template and "[X]" or "[  ]") .. "  Start with a basic deck (you pay for it)", UI.px(28, 362), UI.px(744, 48), { color = T.panel2, textSize = 16 }, function()
				choice.template = not choice.template
				draw()
			end)
			UI.Button(dialog, "Cancel", UI.px(28, 540), UI.px(200, 56), {}, function()
				dialog:Destroy()
				dialog = nil
			end)
			UI.Button(dialog, "CREATE", UI.px(532, 540), UI.px(240, 56), { color = T.accent, textSize = 22 }, function()
				local d = GS.addDesign(state, choice.class .. " " .. (choice.layout == "center" and "Center" or "Stage") .. " " .. (#state.designs + 1), {}, choice.class, choice.layout)
				if choice.template then
					local c = Config.STAGE_CLASS_BY_ID[choice.class]
					local rec
					if choice.layout == "center" then
						rec = { t = "deck_round", x = 0, z = 0, r = 0, w = math.min(70, math.floor(c.center * 0.5)), h = 6, y = 0 }
					else
						rec = { t = "deck", x = 0, z = c.minZ + math.floor((c.maxX - c.minX) * 0.12) + 2, r = 0, w = math.floor((c.maxX - c.minX) * 0.6), d = math.floor((c.maxX - c.minX) * 0.25), h = (c.order == 1) and 4 or 6, y = 0 }
					end
					local ok, msg = GS.buyItem(state, d, rec)
					if not ok then
						app:toast(msg, T.warn)
					end
				end
				dialog:Destroy()
				dialog = nil
				switchDesign(d)
			end)
		end
		draw()
	end

	refreshTop = function()
		UI.ClearChildren(top)
		UI.Button(top, "<", UI.px(16, 14), UI.px(40, 40), {}, function()
			local idx = table.find(state.designs, self.design) or 1
			idx = idx - 1
			if idx < 1 then
				idx = #state.designs
			end
			switchDesign(state.designs[idx])
		end)
		local nameBox = UI.New("TextBox", {
			Parent = top,
			Position = UI.px(62, 14),
			Size = UI.px(260, 40),
			BackgroundColor3 = T.panel2,
			BorderSizePixel = 0,
			Text = self.design.name,
			PlaceholderText = "Design name",
			ClearTextOnFocus = false,
			TextColor3 = T.text,
			TextSize = 19,
			Font = UI.FontBold,
			UI.Corner(8),
		})
		nameBox.FocusLost:Connect(function()
			local txt = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
			if #txt > 0 then
				self.design.name = txt:sub(1, 24)
			end
			nameBox.Text = self.design.name
		end)
		UI.Button(top, ">", UI.px(328, 14), UI.px(40, 40), {}, function()
			local idx = table.find(state.designs, self.design) or 1
			idx = idx + 1
			if idx > #state.designs then
				idx = 1
			end
			switchDesign(state.designs[idx])
		end)
		UI.Pill(top, string.upper(self.design.class) .. "  |  " .. (self.design.layout == "center" and "CENTER" or "END STAGE"), UI.px(378, 20), UI.px(200, 28), T.accent2, 14).TextColor3 = Color3.new(0, 0, 0)
		local canAdd = #state.designs < Config.MAX_DESIGNS
		UI.Button(top, "+ New", UI.px(590, 14), UI.px(90, 40), { disabled = not canAdd }, newDesignDialog)
		UI.Button(top, "Copy", UI.px(686, 14), UI.px(80, 40), { disabled = not canAdd }, function()
			local value = GS.designValue(self.design)
			if state.money < value then
				app:toast("A copy needs new equipment worth " .. Util.money(value) .. ". Not enough money.", T.bad)
				return
			end
			state.money = state.money - value
			switchDesign(GS.addDesign(state, (self.design.name .. " copy"):sub(1, 24), Util.deepCopy(self.design.items), self.design.class, self.design.layout))
		end)
		-- CLEAR only removes what you built; templates can be restored, own designs deleted
		UI.Button(top, "Clear", UI.px(772, 14), UI.px(90, 40), {}, function()
			app:confirm("Clear the stage?", "Remove everything built on \"" .. UI.esc(self.design.name) .. "\"? The equipment is sold for " .. math.floor(Config.RESALE * 100) .. "% of its price. The design itself stays.", function()
				state.money = state.money + math.floor(GS.designValue(self.design) * Config.RESALE + 0.5)
				self.design.items = {}
				selected = nil
				render()
				refreshStats()
				refreshProps()
			end)
		end)
		if self.design.template then
			UI.Button(top, "Restore", UI.px(868, 14), UI.px(90, 40), {}, function()
				local preset
				for _, p in ipairs(StageItems.PRESETS) do
					if p.name == self.design.template then
						preset = p
					end
				end
				if not preset then
					return
				end
				local tmp = { items = preset.items }
				local cost = GS.designValue(tmp)
				local refund = math.floor(GS.designValue(self.design) * Config.RESALE + 0.5)
				app:confirm("Restore template?", "Rebuild the original \"" .. preset.name .. "\" stage. Your current equipment is sold (+" .. Util.money(refund) .. "), the template equipment costs " .. Util.money(cost) .. ".", function()
					if state.money + refund < cost then
						app:toast("Not enough money to restore the template.", T.bad)
						return
					end
					state.money = state.money + refund - cost
					self.design.items = Util.deepCopy(preset.items)
					selected = nil
					render()
					refreshStats()
					refreshProps()
				end)
			end)
		else
			UI.Button(top, "Delete", UI.px(868, 14), UI.px(90, 40), { color = UI.shade(T.bad, 0.7) }, function()
				app:confirm("Delete this design?", "Delete the whole design \"" .. UI.esc(self.design.name) .. "\"? The equipment is sold for " .. math.floor(Config.RESALE * 100) .. "% of its price.", function()
					local ok, msg = GS.deleteDesign(state, self.design.id)
					if ok then
						switchDesign(state.designs[1])
					else
						app:toast(msg, T.bad)
					end
				end)
			end)
		end
		local ad = previewArtist()
		UI.Button(top, "As: " .. (ad and ad.name or "-"), UI.px(968, 14), UI.px(200, 40), { textSize = 15 }, function()
			self.previewIndex = self.previewIndex % math.max(1, #signed) + 1
			render()
			refreshTop()
		end)
		UI.Button(top, "PREVIEW SHOW", UI.px(1176, 14), UI.px(170, 40), { color = T.accent2, textColor = Color3.new(0, 0, 0) }, function()
			Designer.preview()
		end)
		UI.Button(top, "DONE", UI.px(1354, 14), UI.px(118, 40), { color = T.accent }, function()
			Designer.close()
			app:enterMode("menu")
			app:go(app.returnScreen or "office")
		end)
		statsLbl = UI.Label(top, "", UI.px(16, 66), UI.px(1460, 40), { textSize = 17, rich = true })
		refreshStats()
	end

	refreshStats = function()
		refreshMoney()
		if not statsLbl then
			return
		end
		local ad = previewArtist()
		local st = Sim.designStats(self.design, ad and ad.genre)
		local c = cls()
		local fits = {}
		for _, k in ipairs(Config.STAGE_CLASSES) do
			if k.order >= c.order then
				local score = Sim.productionScore(self.design, ad and ad.genre, CLASS_CAP[k.id])
				local col = score >= 80 and "#2ecc71" or (score >= 55 and "#ffc107" or "#ff5252")
				table.insert(fits, string.format('%s <font color="%s">%d%%</font>', k.id, col, math.floor(score + 0.5)))
			end
		end
		statsLbl.Text = string.format(
			"Items <b>%d/%d</b>   Production <b>%d pts</b>   Equipment value <b>%s</b>   Running cost <b>%s</b> per show   |   Quality:  %s",
			st.count,
			c.maxItems,
			math.floor(st.eff + 0.5),
			Util.money(st.value),
			Util.money(st.cost),
			table.concat(fits, "   ")
		)
	end

	refreshList()
	refreshTop()
	refreshProps()
	if app.newDesignClass then
		local c = app.newDesignClass
		app.newDesignClass = nil
		newDesignDialog(c)
	end

	------------------------------------------------------------ ghost / hover
	local function updateGhost()
		if mouseOverUI() or dialog then
			clearGhost()
			return
		end
		local def, rec, except
		if tool == "place" and placeDef then
			def, rec = placeDef, ghostRec
		elseif tool == "move" and moving then
			rec = moving.rec
			def = StageItems.byId[rec.t]
			for _, r in ipairs(Stage3D.items) do
				if r.rec == rec then
					except = r
				end
			end
		else
			clearGhost()
			return
		end
		local x, z = mousePoint(except, def)
		if not x then
			clearGhost()
			return
		end
		local ok = Stage3D.inBounds(x, z)
		if tool == "place" then
			ok = ok and #self.design.items < cls().maxItems and state.money >= Sim.itemPrice(def, rec)
		end
		local key = def.id .. tostring(ok) .. tostring(rec.w) .. tostring(rec.d) .. tostring(rec.h)
		if not ghost or ghostKey ~= key then
			clearGhost()
			ghost = Builder.build(def, { color = itemOpts().color, artistName = itemOpts().artistName, rec = rec })
			Builder.ghost(ghost, ok)
			ghost.model.Parent = Stage3D.world
			ghostKey = key
		end
		local tmp = { x = x, z = z, r = rec.r }
		Builder.place(ghost, Stage3D.itemCFrame(def, tmp, except))
		ghost.ok, ghost.x, ghost.z = ok, x, z
	end

	local function updateHover()
		hovered = nil
		if tool == "select" and not mouseOverUI() and not dialog then
			hovered = itemUnderMouse()
		end
		hoverHighlight.Adornee = (hovered and hovered ~= selected) and hovered.model or nil
		hoverHighlight.Enabled = hovered ~= nil and hovered ~= selected
		selHighlight.Adornee = selected and selected.model or nil
		selHighlight.Enabled = selected ~= nil and tool ~= "move"
	end

	------------------------------------------------------------ drag arrows (Roblox Handles)
	local gizmoBox = UI.New("Part", { Name = "GizmoBox", Size = Vector3.new(4, 4, 4), Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Parent = Stage3D.world })
	local flat = Faces.new(Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right)
	local moveH = UI.New("Handles", { Adornee = gizmoBox, Style = Enum.HandlesStyle.Movement, Faces = flat, Color3 = T.accent2, Visible = false, Parent = app.gui })
	local sizeH = UI.New("Handles", { Adornee = gizmoBox, Style = Enum.HandlesStyle.Resize, Faces = flat, Color3 = T.gold, Visible = false, Parent = app.gui })
	local rotH = UI.New("ArcHandles", { Adornee = gizmoBox, Axes = Axes.new(Enum.Axis.Y), Color3 = T.accent, Visible = false, Parent = app.gui })
	local drag = nil

	local function updateGizmo()
		local show = selected ~= nil and tool == "select" and dialog == nil and selected.model.Parent ~= nil
		if show and not drag then
			local cf, size = selected.model:GetBoundingBox()
			gizmoBox.CFrame = cf
			gizmoBox.Size = Vector3.new(math.max(2, size.X), math.max(2, size.Y), math.max(2, size.Z))
		end
		moveH.Visible = show and gizmoMode == "move"
		sizeH.Visible = show and gizmoMode == "size" and selected.def.size ~= nil
		rotH.Visible = show and gizmoMode == "rotate"
	end

	local function livePlace()
		-- rebuild the selected item so size changes show while dragging
		local rec = selected.rec
		Stage3D.removeItem(selected)
		selected = Stage3D.addItem(rec, itemOpts())
	end

	local function startDrag()
		local rec = selected.rec
		drag = { rec = rec, x = rec.x, z = rec.z, y = rec.y or selected.cf.Position.Y, r = rec.r or 0, w = rec.w, d = rec.d, boxCF = gizmoBox.CFrame, riders = selected.def.deck and itemsOnDeck(selected) or {} }
	end

	local function endDrag()
		if not drag or not selected then
			drag = nil
			return
		end
		local d, rec, def = drag, drag.rec, selected.def
		drag = nil
		if gizmoMode == "size" then
			local nw, nd, nx, nz = rec.w, rec.d, rec.x, rec.z
			rec.w, rec.d, rec.x, rec.z = d.w, d.d, d.x, d.z
			local ok, msg = GS.changeItem(state, rec, { w = nw, d = nd, x = nx, z = nz })
			if not ok then
				app:toast(msg, T.bad)
			end
		elseif gizmoMode == "move" then
			if def.mount ~= "rig" then
				local newY = Stage3D.surfaceY(rec.x, rec.z, selected)
				local dy = newY - d.y
				rec.y = newY
				for _, rr in ipairs(d.riders) do
					rr.x, rr.z = rr.x + (rec.x - d.x), rr.z + (rec.z - d.z)
					if rr.y then
						rr.y = rr.y + dy
					end
				end
			end
		end
		render()
		refreshStats()
		refreshProps()
	end

	for _, h in ipairs({ moveH, sizeH }) do
		h.MouseEnter:Connect(function()
			overHandle = true
		end)
		h.MouseLeave:Connect(function()
			overHandle = false
		end)
		h.MouseButton1Down:Connect(startDrag)
		h.MouseButton1Up:Connect(endDrag)
	end
	rotH.MouseEnter:Connect(function()
		overHandle = true
	end)
	rotH.MouseLeave:Connect(function()
		overHandle = false
	end)
	rotH.MouseButton1Down:Connect(startDrag)
	rotH.MouseButton1Up:Connect(endDrag)

	moveH.MouseDrag:Connect(function(face, distance)
		if not drag or not selected then
			return
		end
		local dir = drag.boxCF:VectorToWorldSpace(Vector3.FromNormalId(face))
		local nx = snapG(drag.x + dir.X * distance)
		local nz = snapG(drag.z + dir.Z * distance)
		if Stage3D.inBounds(nx, nz) then
			drag.rec.x, drag.rec.z = nx, nz
			Builder.place(selected, Stage3D.itemCFrame(selected.def, drag.rec))
		end
	end)
	sizeH.MouseDrag:Connect(function(face, distance)
		if not drag or not selected or not selected.def.size then
			return
		end
		local sz = selected.def.size
		local n = Vector3.FromNormalId(face)
		local step = math.floor(distance / gridSize + 0.5) * gridSize
		local rec = drag.rec
		if selected.def.shape == "round" then
			rec.w = math.clamp((drag.w or sz.w) + step * 2, sz.minW, sz.maxW)
		elseif math.abs(n.X) > 0.5 then
			local w = math.clamp((drag.w or sz.w) + step, sz.minW, sz.maxW)
			local shift = (w - (drag.w or sz.w)) / 2 * n.X
			local world = drag.boxCF:VectorToWorldSpace(Vector3.new(shift, 0, 0))
			rec.w, rec.x, rec.z = w, drag.x + world.X, drag.z + world.Z
		elseif sz.d then
			local dd = math.clamp((drag.d or sz.d) + step, sz.minD, sz.maxD)
			local shift = (dd - (drag.d or sz.d)) / 2 * n.Z
			local world = drag.boxCF:VectorToWorldSpace(Vector3.new(0, 0, shift))
			rec.d, rec.x, rec.z = dd, drag.x + world.X, drag.z + world.Z
		end
		livePlace()
	end)
	rotH.MouseDrag:Connect(function(axis, relativeAngle)
		if not drag or not selected then
			return
		end
		local r = math.floor((drag.r + math.deg(relativeAngle)) / 15 + 0.5) * 15
		drag.rec.r = r % 360
		Builder.place(selected, Stage3D.itemCFrame(selected.def, drag.rec))
	end)

	local function finishMove(cancel)
		if not moving then
			return
		end
		local m = moving
		moving = nil
		tool = "select"
		if not cancel and ghost and ghost.ok then
			local def = StageItems.byId[m.rec.t]
			local except
			for _, r in ipairs(Stage3D.items) do
				if r.rec == m.rec then
					except = r
				end
			end
			local dx, dz = ghost.x - m.x, ghost.z - m.z
			m.rec.x, m.rec.z = ghost.x, ghost.z
			local dy = 0
			if def.mount ~= "rig" then
				local newY = Stage3D.surfaceY(m.rec.x, m.rec.z, except)
				dy = newY - (m.y or 0)
				m.rec.y = newY
			end
			for _, ar in ipairs(m.attached) do
				ar.x, ar.z = ar.x + dx, ar.z + dz
				if ar.y then
					ar.y = ar.y + dy
				end
			end
		end
		clearGhost()
		render()
		refreshProps()
	end

	------------------------------------------------------------ input
	table.insert(self.conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp or app.modalOpen or dialog then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			if mouseOverUI() or overHandle or drag then
				return
			end
			if tool == "move" then
				finishMove(false)
			elseif tool == "place" and placeDef then
				if not ghost then
					return
				end
				if not ghost.ok then
					if #self.design.items >= cls().maxItems then
						app:toast("This " .. self.design.class .. " design is full (" .. cls().maxItems .. " items).", T.warn)
					elseif state.money < Sim.itemPrice(placeDef, ghostRec) then
						app:toast("Not enough money for " .. placeDef.name .. ".", T.bad)
					else
						app:toast("Outside the build area of a " .. self.design.class .. " stage (gold lines).", T.warn)
					end
					return
				end
				local rec = Util.deepCopy(ghostRec)
				rec.x, rec.z = ghost.x, ghost.z
				if placeDef.mount ~= "rig" then
					rec.y = Stage3D.surfaceY(rec.x, rec.z)
				end
				local ok, msg = GS.buyItem(state, self.design, rec)
				if not ok then
					app:toast(msg, T.bad)
					return
				end
				Stage3D.addItem(rec, itemOpts())
				refreshStats()
			else
				select(itemUnderMouse())
			end
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			local k = input.KeyCode
			if k == Enum.KeyCode.R then
				rotate(15)
			elseif k == Enum.KeyCode.Q then
				rotate(-15)
			elseif k == Enum.KeyCode.E then
				rotate(15)
			elseif k == Enum.KeyCode.G then
				startMove()
			elseif k == Enum.KeyCode.C then
				copySelected()
			elseif k == Enum.KeyCode.X or k == Enum.KeyCode.Delete then
				deleteSelected()
			elseif k == Enum.KeyCode.F then
				if tool == "move" then
					finishMove(true)
				else
					setTool("select")
					select(nil)
				end
			elseif k == Enum.KeyCode.T then
				pitch = (pitch > 1.3) and 0.6 or 1.45
			elseif k == Enum.KeyCode.H then
				local show = not left.Visible
				left.Visible = show
				props.Visible = show
				moneyBox.Visible = show
				hint.Visible = show
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
			dist = math.clamp(dist * (1 - input.Position.Z * 0.12), 20, CLASS_MAXDIST[design.class] or 240)
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
	end))

	function self.cleanup()
		for _, c in ipairs(self.conns) do
			c:Disconnect()
		end
		self.conns = {}
		clearGhost()
		if venuePreview then
			Venue.destroy(venuePreview)
			venuePreview = nil
		end
		selHighlight:Destroy()
		moveH:Destroy()
		sizeH:Destroy()
		rotH:Destroy()
		gizmoBox:Destroy()
		hoverHighlight:Destroy()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		root:Destroy()
		Stage3D.clearDesign()
		Stage3D.showGrid(false)
	end
	self.previewArtist = previewArtist
	self.select = select
	self.setTool = setTool
	self.startMove = startMove
	local _ = hintLbl
	local __ = panels
end

function Designer.close()
	local self = Designer.current
	if not self then
		return
	end
	Designer.current = nil
	self.cleanup()
	self.app:save()
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
