-- MY STAGES: all your stage designs in one place. Edit, copy, delete or start a new one.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local StageItems = require(Root.Data.StageItems)
local Artists = require(Root.Data.Artists)
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
	local vp = UI.New("ViewportFrame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(30, 34, 50),
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(165, 165, 185),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.5, -1, -0.7),
		UI.Corner(10),
	})
	local floor = UI.New("Part", { Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, -0.5, 0), Color = Color3.fromRGB(44, 48, 60), Anchored = true, Parent = vp })
	local _ = floor
	local c = Config.STAGE_CLASS_BY_ID[design.class]
	local n = 0
	for _, rec in ipairs(design.items) do
		local def = StageItems.byId[rec.t]
		if def and THUMB_CATS[def.cat] and def.id ~= "spot" and n < 60 then
			n = n + 1
			local refs = Builder.build(def, { color = T.accent2, artistName = "", rec = rec })
			Builder.rest(refs)
			local y = (rec.y or 0) + (rec.yo or 0)
			if def.mount == "rig" then
				y = c.rigY - 2
			end
			Builder.place(refs, CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, math.rad(rec.r or 0), 0))
			refs.model.Parent = vp
		end
	end
	local reach = (design.layout == "center") and c.center or math.max(c.maxX, (c.maxZ - c.minZ) / 2)
	local cz = (design.layout == "center") and 0 or (c.minZ + (c.maxZ - c.minZ) * 0.3)
	local cam = UI.New("Camera", { FieldOfView = 40, Parent = vp })
	cam.CFrame = CFrame.lookAt(Vector3.new(reach * 0.9, reach * 1.1, cz + reach * 1.7), Vector3.new(0, 4, cz))
	vp.CurrentCamera = cam
	return vp
end

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
		UI.Label(card, d.name, UI.px(18, 218), UI.px(416, 34), { textSize = 26, font = UI.FontBlack })
		local pill = UI.Pill(card, string.upper(d.class) .. "  ·  " .. (d.layout == "center" and "CENTER" or "END STAGE"), UI.px(18, 256), UI.px(190, 26), T.accent2, 13)
		pill.TextColor3 = BLACK
		local t = usedBy(state, d.id)
		if t then
			UI.Pill(card, "ON TOUR", UI.px(216, 256), UI.px(100, 26), T.good, 13).TextColor3 = BLACK
		elseif d.template then
			UI.Pill(card, "STARTER", UI.px(216, 256), UI.px(100, 26), T.panel3, 13)
		end
		UI.Label(card, GS.songCount(d) .. " songs   ·   " .. st.count .. " items   ·   " .. Util.money(st.cost) .. " per show", UI.px(18, 290), UI.px(416, 24), { textSize = 16, color = T.sub })
		UI.Button(card, "EDIT", UI.px(18, 330), UI.px(200, 54), { color = T.accent, textSize = 20 }, function()
			app.returnScreen = self.back or "stages"
			app:openDesigner(d.id)
		end)
		UI.Button(card, "Copy", UI.px(226, 330), UI.px(98, 54), { textSize = 16, disabled = not canAdd }, function()
			local value = GS.designValue(d)
			app:confirm("Copy \"" .. UI.esc(d.name) .. "\"?", "A copy needs its own equipment, worth <b>" .. Util.money(value) .. "</b>.", function()
				if state.money < value then
					app:toast("Not enough money for the equipment.", T.bad)
					return
				end
				state.money = state.money - value
				GS.addDesign(state, (d.name .. " copy"):sub(1, 24), Util.deepCopy(d.items), d.class, d.layout)
				app:refreshCurrent()
			end)
		end)
		UI.Button(card, "Delete", UI.px(332, 330), UI.px(102, 54), { textSize = 16, color = UI.shade(T.bad, 0.65), disabled = d.template ~= nil or t ~= nil }, function()
			app:confirm("Delete \"" .. UI.esc(d.name) .. "\"?", "The equipment is sold for " .. math.floor(Config.RESALE * 100) .. "% of its price (+" .. Util.money(math.floor(GS.designValue(d) * Config.RESALE)) .. ").", function()
				local ok, msg = GS.deleteDesign(state, d.id)
				app:toast(ok and "Stage deleted." or msg, ok and T.good or T.bad)
				app:refreshCurrent()
			end)
		end)
	end
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
			local d, msg
			local name = choice.class .. " " .. (choice.layout == "center" and "Center" or "Stage") .. " " .. (#state.designs + 1)
			if choice.preset then
				d, msg = GS.addDesignFromTemplate(state, choice.preset)
			elseif #state.designs >= Config.MAX_DESIGNS then
				msg = "You can have up to " .. Config.MAX_DESIGNS .. " stages. Delete one first."
			else
				d = GS.addDesign(state, name, {}, choice.class, choice.layout)
				if choice.start == "deck" then
					local c = Config.STAGE_CLASS_BY_ID[choice.class]
					local rec
					if choice.layout == "center" then
						rec = { t = "deck_round", x = 0, z = 0, r = 0, w = math.min(70, math.floor(c.center * 0.5)), h = 6, y = 0 }
					else
						rec = { t = "deck", x = 0, z = c.minZ + math.floor((c.maxX - c.minX) * 0.12) + 2, r = 0, w = math.floor((c.maxX - c.minX) * 0.6), d = math.floor((c.maxX - c.minX) * 0.25), h = (c.order == 1) and 4 or 6, y = 0 }
					end
					local ok, err = GS.buyItem(state, d, rec)
					if not ok then
						app:toast(err, T.warn)
					end
				end
			end
			if not d then
				app:toast(msg or "Could not create the stage.", T.bad)
				return
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
