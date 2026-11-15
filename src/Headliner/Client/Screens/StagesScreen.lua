-- MY STAGES: all your stage designs in one place. Edit, copy, delete or start a new one.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local StageItems = require(Root.Data.StageItems)
local Artists = require(Root.Data.Artists)
local Countries = require(Root.Data.Countries)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Builder = require(Root.Client.Builder)

local T = UI.Theme
local BLACK = Color3.new(0, 0, 0)
local StagesScreen = {}
StagesScreen.__index = StagesScreen

-- categories that are shown in the small 3D picture
local THUMB_CATS = { Stage = true, Screens = true, Set = true, Artist = true }

function StagesScreen.new(app)
	local self = setmetatable({ app = app }, StagesScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Stages" })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	return self
end

function StagesScreen:show(args)
	self.back = args and args.back or nil
	self:refresh()
	if args and args.newClass then
		self:newDialog(args.newClass)
	end
end

-- small 3D picture of a design
local function thumbnail(parent, design, pos, size)
	-- the background (a gradient behind the 3D picture; a gradient on the ViewportFrame would tint the picture too)
	local back = UI.New("Frame", { Parent = parent, Position = pos, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, UI.Corner(10) })
	UI.New("UIGradient", { Parent = back, Color = ColorSequence.new(Color3.fromRGB(70, 50, 110), Color3.fromRGB(12, 12, 20)), Rotation = 90 })
	local vp = UI.New("ViewportFrame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = back.ZIndex + 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(165, 165, 185),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		UI.Corner(10),
	})
	-- a small venue around the stage: dark hall, back drape with a light strip, fans in front
	local c = Config.STAGE_CLASS_BY_ID[design.class]
	local reach = (design.layout == "center") and c.center or math.max(c.maxX, (c.maxZ - c.minZ) / 2)
	local cz = (design.layout == "center") and 0 or (c.minZ + (c.maxZ - c.minZ) * 0.3)
	local function block(size, cf, color, mat)
		return UI.New("Part", { Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic, Anchored = true, Parent = vp })
	end
	block(Vector3.new(reach * 6, 1, reach * 6), CFrame.new(0, -0.5, cz), Color3.fromRGB(34, 34, 44))
	if design.layout ~= "center" then
		block(Vector3.new(reach * 4, reach * 1.6, 1), CFrame.new(0, reach * 0.8, c.minZ - 3), Color3.fromRGB(20, 20, 28))
		block(Vector3.new(reach * 4, 0.6, 0.4), CFrame.new(0, reach * 1.1, c.minZ - 2.4), T.accent, Enum.Material.Neon)
	end
	-- fans: a few rows of little figures in front of (or around) the stage
	local rng = Random.new(#design.items + 7)
	local FAN = { Color3.fromRGB(240, 90, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(250, 210, 80), Color3.fromRGB(120, 220, 160), Color3.fromRGB(230, 230, 240), Color3.fromRGB(170, 110, 255) }
	for k = 1, 70 do
		local x, z
		if design.layout == "center" then
			local a = rng:NextNumber() * math.pi * 2
			local rr = reach * (1.05 + rng:NextNumber() * 0.5)
			x, z = math.cos(a) * rr, math.sin(a) * rr
		else
			x = (rng:NextNumber() - 0.5) * reach * 2.4
			z = c.maxZ + 4 + rng:NextNumber() * reach * 0.9
		end
		local sc = math.max(1, reach / 40)
		block(Vector3.new(1.6, 3, 1) * sc, CFrame.new(x, 1.5 * sc, z), FAN[rng:NextInteger(1, #FAN)])
		block(Vector3.new(1, 1, 1) * sc, CFrame.new(x, 3.6 * sc, z), Color3.fromRGB(200, 160, 130))
	end
	local n = 0
	for _, rec in ipairs(design.items) do
		local def = StageItems.byId[rec.t]
		if def and THUMB_CATS[def.cat] and def.id ~= "spot" and n < 60 then
			n = n + 1
			local refs = Builder.build(def, { color = T.accent2, artistName = "", rec = rec, preview = true })
			Builder.rest(refs)
			Builder.hideMarker(refs)
			local y = (rec.y or 0) + (rec.yo or 0)
			if def.mount == "rig" then
				y = c.rigY - 2
			end
			Builder.place(refs, CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, math.rad(rec.r or 0), 0))
			refs.model.Parent = vp
		end
	end
	if n == 0 then
		UI.Label(vp, "EMPTY - OPEN IT TO BUILD", UI.px(0, 0), UDim2.fromScale(1, 0.3), { textSize = 16, font = UI.FontBold, color = Color3.fromRGB(220, 220, 235), alignX = Enum.TextXAlignment.Center })
	end
	local cam = UI.New("Camera", { FieldOfView = 40, Parent = vp })
	cam.CFrame = CFrame.lookAt(Vector3.new(reach * 0.9, reach * 1.1, cz + reach * 1.7), Vector3.new(0, 4, cz))
	vp.CurrentCamera = cam
	return vp
end

StagesScreen.thumbnail = thumbnail

local function usedBy(state, id)
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			for _, did in pairs(t.designs or {}) do
				if did == id then
					return t
				end
			end
		end
	end
	return nil
end

function StagesScreen:refresh()
	local app, state = self.app, self.app.state
	local body = self.body
	UI.ClearChildren(body)
	UI.Label(body, "My Stages", UI.px(40, 20), UI.px(800, 56), { textSize = 44, font = UI.FontBlack })
	UI.Label(body, "Every tour takes one stage per venue size (club, theatre, arena, stadium). Changes save automatically.", UI.px(42, 76), UI.px(1200, 26), { textSize = 18, color = T.sub })
	-- the tour in planning: which stage sizes it needs
	local d = state.draft or {}
	if d.artistId and #(d.shows or {}) > 0 then
		local need, seen = {}, {}
		for _, sh in ipairs(d.shows) do
			local cls = GS.venueClass(Countries.venueById[sh.venueId])
			if not seen[cls] then
				seen[cls] = true
				table.insert(need, cls)
			end
		end
		local banner = UI.New("Frame", { Parent = body, Position = UI.px(760, 16), Size = UI.px(820, 88), BackgroundColor3 = UI.shade(T.accent, 0.35), BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.accent2, 2, 0.2) })
		UI.Label(banner, "TOUR PLAN | " .. string.upper(Artists.byId[d.artistId].name) .. " needs a stage for: " .. table.concat(need, ", "), UI.px(16, 8), UI.px(790, 30), { textSize = 18, font = UI.FontBlack })
		UI.Label(banner, "The best fitting stages are used. Edit or build one here, then pick it and announce on the LAPTOP.", UI.px(16, 42), UI.px(790, 40), { textSize = 15, color = T.text, wrap = true })
	end
	local canAdd = #state.designs < Config.MAX_DESIGNS
	UI.Button(body, "+  NEW STAGE", UI.px(1600, 26), UI.px(280, 60), { color = T.accent, textSize = 22, disabled = not canAdd }, function()
		self:newDialog()
	end)
	UI.Label(body, #state.designs .. " / " .. Config.MAX_DESIGNS .. " stages", UI.px(1600, 88), UI.px(280, 22), { textSize = 15, color = T.sub, alignX = Enum.TextXAlignment.Center })

	local grid = UI.Scroll(body, UI.px(32, 122), UI.px(1864, 876))
	UI.New("UIGridLayout", { Parent = grid, CellSize = UI.px(452, 400), CellPadding = UI.px(12, 14), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, d in ipairs(state.designs) do
		local st = Sim.designStats(d, nil)
		local card = UI.New("Frame", { Parent = grid, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(14), UI.Stroke(T.stroke, 1, 0.3) })
		thumbnail(card, d, UI.px(10, 10), UI.px(432, 200))
		-- the name: click it and type a new one
		local nameBox = UI.New("TextBox", { Parent = card, Position = UI.px(12, 216), Size = UI.px(428, 38), BackgroundColor3 = T.panel2, BorderSizePixel = 0, Text = d.name, PlaceholderText = "Name this stage", ClearTextOnFocus = false, TextColor3 = T.text, TextSize = 24, Font = UI.FontBlack, TextXAlignment = Enum.TextXAlignment.Left, UI.Corner(8), UI.Padding(10, 10, 0, 0) })
		UI.Label(card, "RENAME", UI.px(372, 220), UI.px(60, 14), { textSize = 11, color = T.sub, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
		nameBox.FocusLost:Connect(function()
			local txt = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
			if #txt > 0 and txt ~= d.name then
				local ok, msg = app:act("renameDesign", { designId = d.id, name = txt })
				app:toast(msg or "", ok and T.good or T.bad)
			end
			nameBox.Text = d.name
		end)
		local pill = UI.Pill(card, string.upper(d.class) .. "  |  " .. (d.layout == "center" and "CENTER" or "END STAGE"), UI.px(18, 256), UI.px(190, 26), T.accent2, 13)
		local t = usedBy(state, d.id)
		if t then
			UI.Pill(card, "ON TOUR", UI.px(216, 256), UI.px(100, 26), T.good, 13)
		elseif d.template then
			UI.Pill(card, "STARTER", UI.px(216, 256), UI.px(100, 26), T.panel3, 13)
		end
		UI.Label(card, GS.songCount(d) .. " songs   |   " .. st.count .. " items   |   " .. Util.money(st.cost) .. " per show", UI.px(18, 290), UI.px(416, 24), { textSize = 16, color = T.sub })
		-- a tour in planning: this stage can be selected for it
		local dd = state.draft or {}
		if dd.artistId and #(dd.shows or {}) > 0 then
			local fitsAny, chosen = false, false
			for _, sh in ipairs(dd.shows) do
				local cls = GS.venueClass(Countries.venueById[sh.venueId])
				if Config.STAGE_CLASS_BY_ID[d.class].order <= Config.STAGE_CLASS_BY_ID[cls].order then
					fitsAny = true
					if (dd.designs or {})[cls] == d.id then
						chosen = true
					end
				end
			end
			UI.Button(card, chosen and "SELECTED FOR THE TOUR" or "SELECT FOR TOUR", UI.px(226, 168), UI.px(208, 34), { textSize = 13, color = chosen and T.good or T.accent2, disabled = not fitsAny }, function()
				self:selectForTour(d)
			end)
		end
		UI.Button(card, "EDIT", UI.px(18, 330), UI.px(200, 54), { color = T.accent, textSize = 20 }, function()
			app.returnScreen = self.back or "stages"
			app:openDesigner(d.id)
		end)
		UI.Button(card, "Copy", UI.px(226, 330), UI.px(98, 54), { textSize = 16, disabled = not canAdd }, function()
			local value = GS.designValue(d)
			app:confirm("Copy \"" .. UI.esc(d.name) .. "\"?", "A copy needs its own equipment, worth <b>" .. Util.money(value) .. "</b>.", function()
				local ok, msg = app:act("copyDesign", { designId = d.id })
				if not ok then
					app:toast(msg or "Could not copy.", T.bad)
				end
				app:refreshCurrent()
			end)
		end)
		UI.Button(card, "Delete", UI.px(332, 330), UI.px(102, 54), { textSize = 16, color = T.bad, disabled = t ~= nil or #state.designs <= 1 }, function()
			local body = d.template and "This example stage will be gone. Are you sure?" or ("Are you sure? The equipment is sold for " .. math.floor(Config.RESALE * 100) .. "% of its price (+" .. Util.money(math.floor(GS.designValue(d) * Config.RESALE)) .. ").")
			app:confirm("Delete \"" .. UI.esc(d.name) .. "\"?", body, function()
				local ok, msg = app:act("deleteDesign", { designId = d.id })
				app:toast(ok and "Stage deleted." or msg, ok and T.good or T.bad)
				app:refreshCurrent()
			end, "Yes, I'm sure")
		end)
	end
end

-- use this stage for every venue size of the planned tour it fits
function StagesScreen:selectForTour(d)
	local app, state = self.app, self.app.state
	local dd = state.draft
	dd.designs = dd.designs or {}
	local used = {}
	for _, sh in ipairs(dd.shows) do
		local cls = GS.venueClass(Countries.venueById[sh.venueId])
		if Config.STAGE_CLASS_BY_ID[d.class].order <= Config.STAGE_CLASS_BY_ID[cls].order and not used[cls] then
			used[cls] = true
			dd.designs[cls] = d.id
		end
	end
	dd.stageSet = true
	app:act("setDraft", { draft = dd })
	local list = {}
	for cls in pairs(used) do
		table.insert(list, cls)
	end
	table.sort(list)
	app:toast("<b>" .. UI.esc(d.name) .. "</b> is the stage for the " .. table.concat(list, ", ") .. " shows. Announce the tour on the LAPTOP.", T.good, 7)
	self:refresh()
end

-- "new stage" dialog: size, layout and how to start
function StagesScreen:newDialog(preClass)
	local app, state = self.app, self.app.state
	if self.dialog then
		self.dialog:Destroy()
	end
	local choice = { class = preClass or "Arena", layout = "end", start = "deck" }
	local layer = UI.New("TextButton", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, AutoButtonColor = false, Text = "", ZIndex = 40 })
	self.dialog = layer
	local dlg = UI.Panel(layer, UI.px(460, 40), UI.px(1000, 930), T.panel)
	dlg.ZIndex = 41
	local function close()
		layer:Destroy()
		self.dialog = nil
	end
	local function draw()
		UI.ClearChildren(dlg)
		UI.Label(dlg, "NEW STAGE", UI.px(32, 22), UI.px(600, 44), { textSize = 34, font = UI.FontBlack, color = T.accent })
		UI.Label(dlg, "1   SIZE  -  works in venues of this size or bigger", UI.px(32, 82), UI.px(900, 24), { textSize = 17, font = UI.FontBold, color = T.sub })
		for i, c in ipairs(Config.STAGE_CLASSES) do
			local sel = choice.class == c.id
			local b = UI.Button(dlg, "", UI.px(32 + (i - 1) * 236, 112), UI.px(224, 92), { color = sel and T.accent or T.panel3 }, function()
				choice.class = c.id
				draw()
			end)
			UI.Label(b, string.upper(c.id), UI.px(10, 10), UI.px(204, 32), { textSize = 22, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
			UI.Label(b, c.desc, UI.px(8, 46), UI.px(208, 40), { textSize = 14, wrap = true, alignX = Enum.TextXAlignment.Center })
		end
		UI.Label(dlg, "2   TYPE", UI.px(32, 226), UI.px(900, 24), { textSize = 17, font = UI.FontBold, color = T.sub })
		for i, l in ipairs({ { "end", "END STAGE", "Stage at one end, fans in front." }, { "center", "CENTER STAGE", "In the round: fans on every side." } }) do
			local sel = choice.layout == l[1]
			local b = UI.Button(dlg, "", UI.px(32 + (i - 1) * 472, 256), UI.px(460, 84), { color = sel and T.accent or T.panel3 }, function()
				choice.layout = l[1]
				draw()
			end)
			UI.Label(b, l[2], UI.px(16, 8), UI.px(420, 34), { textSize = 22, font = UI.FontBlack })
			UI.Label(b, l[3], UI.px(16, 44), UI.px(420, 30), { textSize = 15 })
		end
		UI.Label(dlg, "3   START WITH", UI.px(32, 362), UI.px(900, 24), { textSize = 17, font = UI.FontBold, color = T.sub })
		local starts = { { "empty", "Empty stage", "Build everything yourself.", 0 }, { "deck", "Basic deck", "One stage deck to start from.", nil } }
		for _, p in ipairs(StageItems.PRESETS) do
			if p.class == choice.class and p.layout == choice.layout then
				table.insert(starts, { p.name, "Template: " .. p.name, p.desc or "A ready-made production.", GS.designValue({ items = p.items }), p })
			end
		end
		local list = UI.Scroll(dlg, UI.px(24, 392), UI.px(952, 410))
		UI.List(true, 8).Parent = list
		for i, s in ipairs(starts) do
			local sel = choice.start == s[1]
			local b = UI.Button(list, "", nil, UI.px(930, 72), { order = i, color = sel and UI.shade(T.accent, 0.6) or T.panel2 }, function()
				choice.start = s[1]
				choice.preset = s[5]
				draw()
			end)
			UI.Label(b, s[2], UI.px(18, 8), UI.px(640, 30), { textSize = 20, font = UI.FontBold })
			UI.Label(b, s[3], UI.px(18, 40), UI.px(700, 24), { textSize = 15, color = T.sub })
			local price = s[4]
			UI.Label(b, price == nil and "cheap" or (price == 0 and "free" or Util.money(price)), UI.px(700, 0), UI.px(212, 72), { textSize = 20, font = UI.FontBlack, color = T.gold, alignX = Enum.TextXAlignment.Right })
		end
		UI.Button(dlg, "Cancel", UI.px(32, 840), UI.px(200, 64), { textSize = 18 }, close)
		UI.Button(dlg, "CREATE & BUILD", UI.px(668, 840), UI.px(300, 64), { color = T.accent, textSize = 22 }, function()
			local ok, msg, data = app:act("newDesign", { class = choice.class, layout = choice.layout, start = choice.start, preset = choice.preset and choice.preset.name or nil })
			local d = ok and data and GS.getDesign(state, data.designId)
			if not d then
				app:toast(msg or "Could not create the stage.", T.bad)
				return
			end
			if msg then
				app:toast(msg, T.warn)
			end
			close()
			app.returnScreen = self.back or "stages"
			app:openDesigner(d.id)
		end)
	end
	draw()
	local _ = Artists
end

return StagesScreen
