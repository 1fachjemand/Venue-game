-- Main client controller: state, time, navigation, popups, saving.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Artists = require(Root.Data.Artists)
local Countries = require(Root.Data.Countries)
local Achievements = require(Root.Data.Achievements)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Stage3D = require(Root.Client.Stage3D)
local SoundFX = require(Root.Client.SoundFX)

local T = UI.Theme
local App = {}
App.__index = App

------------------------------------------------------------------ saving
function App:save()
	if not self.saveAvailable or not self.state then
		return
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(self.state)
	end)
	if ok then
		Root.Remotes.SaveGame:FireServer(json)
	end
end

local function loadState()
	local result, status = nil, "unavailable"
	local finished = false
	task.spawn(function()
		local ok, data, st = pcall(function()
			return Root.Remotes.LoadGame:InvokeServer()
		end)
		if ok then
			result, status = data, st or "unavailable"
		end
		finished = true
	end)
	local t0 = os.clock()
	while not finished and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	local state = nil
	if type(result) == "string" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(result)
		end)
		if ok and type(data) == "table" and data.version == Config.SAVE_VERSION then
			state = GS.sanitize(data)
		end
	end
	return state, status == "ok"
end

------------------------------------------------------------------ setup
function App.start()
	local self = setmetatable({}, App)
	App.instance = self
	self.player = Players.LocalPlayer
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)

	local gui = UI.New("ScreenGui", {
		Name = "HeadlinerUI",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = self.player:WaitForChild("PlayerGui"),
	})
	self.gui = gui
	self.backdrop = UI.New("Frame", {
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		UI.New("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(20, 26, 52), Color3.fromRGB(8, 10, 18)),
			Rotation = 60,
		}),
	})
	self.canvas = UI.New("Frame", {
		Parent = gui,
		Name = "Canvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UI.px(1920, 1080),
		BackgroundTransparency = 1,
	})
	local scale = UI.New("UIScale", { Parent = self.canvas })
	self.uiScale = scale
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(vp.X / 1920, vp.Y / 1080)
		-- on screens wider than 16:9 the canvas is centred: how far (in canvas pixels) its left edge is from the screen edge
		self.sideGap = math.max(0, (vp.X / math.max(scale.Scale, 0.01) - 1920) / 2)
		if self.onRescale then
			self.onRescale()
		end
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- loading text
	local loading = UI.Label(self.canvas, "HEADLINER  -  loading...", UI.px(0, 500), UI.px(1920, 80), { textSize = 48, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center, color = T.accent })

	Stage3D.init()
	local saved
	saved, self.saveAvailable = loadState()
	loading:Destroy()

	self.speed = 2
	self.mode = "title"
	self.modalOpen = false
	self.liveQueue = {}
	self.screens = {}
	local MainMenu = require(Root.Client.MainMenu)
	MainMenu.show(self, saved, function(state, isNew)
		self:beginGame(state, isNew)
	end)

	-- time loop
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local secs = Config.SPEEDS[self.speed].seconds
		if self.mode ~= "menu" or self.modalOpen or secs <= 0 or #self.liveQueue > 0 then
			acc = 0
			return
		end
		acc = acc + dt
		if self.setDayProgress then
			self.setDayProgress(acc / secs)
		end
		if acc >= secs then
			acc = 0
			self:nextDay()
		end
	end)
	-- autosave
	task.spawn(function()
		while true do
			task.wait(45)
			self:save()
		end
	end)
	return self
end

function App:beginGame(state, isNew)
	self.state = state
	self.mode = "menu"
	self.backdrop.Visible = true
	self:buildHud()
	self.content = UI.New("Frame", { Parent = self.canvas, Name = "Content", Position = UI.px(0, 72), Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	local Screens = Root.Client.Screens
	self.screens.office = require(Screens.OfficeScreen).new(self)
	self.screens.planner = require(Screens.PlannerScreen).new(self)
	self.screens.artists = require(Screens.ArtistsScreen).new(self)
	self.screens.tours = require(Screens.ToursScreen).new(self)
	self.screens.charts = require(Screens.ChartsScreen).new(self)
	self.screens.stages = require(Screens.StagesScreen).new(self)
	self.screens.social = require(Screens.SocialScreen).new(self)
	self.toastFrame = UI.New("Frame", { Parent = self.canvas, Name = "Toasts", Position = UI.px(740, 80), Size = UI.px(440, 900), BackgroundTransparency = 1 })
	UI.List(true, 8, Enum.HorizontalAlignment.Center).Parent = self.toastFrame
	self:go("office")
	SoundFX.menu("office")
	if isNew then
		self:save()
		self:showWelcome()
	elseif self.saveAvailable then
		self:toast("Welcome back! Progress saves automatically.", T.good)
	end
end

------------------------------------------------------------------ HUD
function App:buildHud()
	local hud = UI.New("Frame", { Parent = self.canvas, Name = "Hud", Size = UI.px(1920, 64), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	UI.New("Frame", { Parent = hud, Position = UI.px(0, 63), Size = UI.px(1920, 2), BackgroundColor3 = T.accent, BorderSizePixel = 0 })
	self.hud = hud
	UI.Label(hud, "HEADLINER", UI.px(24, 6), UI.px(220, 32), { textSize = 26, font = UI.FontBlack, color = T.accent })
	self.labelLbl = UI.Label(hud, self.state.labelName, UI.px(24, 36), UI.px(250, 22), { textSize = 14, color = T.sub })
	-- main navigation: always visible, the active tab is highlighted
	self.tabs = {}
	local TABS = { { "office", "OFFICE" }, { "artists", "ARTISTS" }, { "tours", "TOURS" }, { "stages", "STAGES" }, { "social", "SOCIAL" }, { "charts", "CHARTS" } }
	for i, tab in ipairs(TABS) do
		self.tabs[tab[1]] = UI.Button(hud, tab[2], UI.px(290 + (i - 1) * 126, 10), UI.px(120, 44), { textSize = 16 }, function()
			self:go(tab[1])
		end)
	end
	self.tabs.planner = UI.Button(hud, "+ PLAN A TOUR", UI.px(1050, 10), UI.px(196, 44), { textSize = 16, color = T.accent2, textColor = Color3.new(0, 0, 0) }, function()
		self:go("planner")
	end)
	self.moneyLbl = UI.Label(hud, "", UI.px(1262, 6), UI.px(210, 30), { textSize = 26, font = UI.FontBlack, alignX = Enum.TextXAlignment.Right, color = T.good })
	self.dateLbl = UI.Label(hud, "", UI.px(1262, 34), UI.px(210, 22), { textSize = 16, alignX = Enum.TextXAlignment.Right, color = T.sub })
	-- how far the current day has run
	local _, setDay = UI.Bar(hud, UI.px(1372, 56), UI.px(100, 4), 0, T.accent2)
	self.setDayProgress = setDay
	self.speedBtns = {}
	for i, sp in ipairs(Config.SPEEDS) do
		self.speedBtns[i] = UI.Button(hud, sp.label, UI.px(1486 + (i - 1) * 58, 10), UI.px(52, 44), { textSize = 18 }, function()
			self.speed = i
			self:refreshHud()
		end)
	end
	UI.Button(hud, "NEXT DAY", UI.px(1724, 10), UI.px(180, 44), { color = T.accent, textSize = 16 }, function()
		if not self.modalOpen and #self.liveQueue == 0 then
			self:nextDay()
		end
	end)
	self:refreshHud()
end

function App:refreshHud()
	local st = self.state
	self.moneyLbl.Text = Util.money(st.money)
	self.moneyLbl.TextColor3 = st.money < 0 and T.bad or T.good
	self.dateLbl.Text = Util.date(st.day, Config.START_YEAR)
	for i, b in ipairs(self.speedBtns) do
		b.BackgroundColor3 = (i == self.speed) and T.accent2 or T.panel3
		b.TextColor3 = (i == self.speed) and Color3.new(0, 0, 0) or T.text
	end
	for key, b in pairs(self.tabs) do
		if key == "planner" then
			b.BackgroundColor3 = (self.current == "planner") and T.accent or T.accent2
			b.TextColor3 = (self.current == "planner") and T.text or Color3.new(0, 0, 0)
		else
			b.BackgroundColor3 = (self.current == key) and T.accent or T.panel3
		end
	end
	local lvl, def = GS.level(st)
	self.labelLbl.Text = st.labelName .. "  |  Level " .. lvl
	local _ = def
end

------------------------------------------------------------------ navigation
function App:go(name, args)
	self.current = name
	for key, scr in pairs(self.screens) do
		if key ~= name and scr.hide and scr.frame.Visible then
			scr:hide()
		end
		scr.frame.Visible = key == name
	end
	local scr = self.screens[name]
	if scr then
		self.returnScreen = name
		scr:show(args)
	end
	self:refreshHud()
end

function App:refreshCurrent()
	local scr = self.screens[self.current]
	if scr and scr.frame.Visible then
		scr:refresh()
	end
	self:refreshHud()
end

function App:enterMode(mode)
	self.mode = mode
	if mode ~= "menu" then
		require(Root.Client.WorldMap3D).deactivate()
	end
	local menu = mode == "menu"
	self.backdrop.Visible = menu
	self.hud.Visible = menu
	self.content.Visible = menu
end

function App:openDesigner(designId)
	if self.modalOpen then
		return
	end
	local Designer = require(Root.Client.Designer)
	self.current = "designer"
	Designer.open(self, designId)
end

------------------------------------------------------------------ toasts & modals
function App:toast(text, color, seconds)
	local f = UI.New("Frame", {
		Parent = self.toastFrame,
		Size = UI.px(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.panel2,
		BorderSizePixel = 0,
		LayoutOrder = -os.clock() * 1000,
		UI.Corner(10),
		UI.Stroke(color or T.accent2, 2, 0),
		UI.Padding(14, 14, 10, 10),
	})
	UI.New("TextLabel", {
		Parent = f,
		Size = UI.px(412, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextWrapped = true,
		TextColor3 = T.text,
		TextSize = 17,
		Font = UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	})
	local kids = self.toastFrame:GetChildren()
	local frames = {}
	for _, k in ipairs(kids) do
		if k:IsA("Frame") then
			table.insert(frames, k)
		end
	end
	if #frames > 7 then
		table.sort(frames, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		frames[1]:Destroy()
	end
	task.delay(seconds or 6, function()
		if f.Parent then
			f:Destroy()
		end
	end)
end

-- buttons = { {text, color, callback}, ... }
function App:modal(title, body, buttons, width)
	self.modalOpen = true
	local w = width or 720
	local layer = UI.New("TextButton", {
		Parent = self.canvas,
		Name = "Modal",
		Size = UI.px(1920, 1080),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 50,
	})
	local box = UI.New("Frame", {
		Parent = layer,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UI.px(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.panel,
		BorderSizePixel = 0,
		ZIndex = 51,
		UI.Corner(16),
		UI.Stroke(T.accent, 2, 0),
		UI.Padding(28, 28, 24, 24),
		UI.List(true, 14),
	})
	UI.New("TextLabel", {
		Parent = box,
		Size = UI.px(w - 56, 40),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = T.accent,
		TextSize = 32,
		Font = UI.FontBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 52,
	})
	UI.New("TextLabel", {
		Parent = box,
		Size = UI.px(w - 56, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = body,
		TextColor3 = T.text,
		TextSize = 19,
		Font = UI.Font,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		ZIndex = 52,
	})
	local row = UI.New("Frame", { Parent = box, Size = UI.px(w - 56, 52), BackgroundTransparency = 1, LayoutOrder = 3, ZIndex = 52 })
	UI.List(false, 12, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center).Parent = row
	local function close()
		layer:Destroy()
		self.modalOpen = false
		task.defer(function()
			self:processLiveQueue()
		end)
	end
	for i, b in ipairs(buttons or { { "OK" } }) do
		local btn = UI.Button(row, b[1], nil, UI.px(math.max(140, #b[1] * 13 + 40), 48), { color = b[2] or T.accent, order = i, textSize = 18 }, function()
			close()
			if b[3] then
				b[3]()
			end
		end)
		btn.ZIndex = 53
	end
	return close
end

function App:confirm(title, body, onYes)
	self:modal(title, body, { { "Cancel", T.panel3 }, { "Yes", T.bad, onYes } }, 560)
end

function App:showWelcome()
	self:modal("Welcome to " .. UI.esc(self.state.labelName) .. "!", table.concat({
		"Your goal: sell out venues and climb the tour charts.",
		"",
		"<b>1.  + PLAN A TOUR</b>   pick venues on the world map and a ticket price.",
		"<b>2.  TOURS</b>   watch ticket sales and the shows.",
		"<b>3.  STAGES</b>   build your own stage show.",
		"",
		"Start small: clubs first!",
	}, "\n"), { { "Let's go!", T.accent } }, 720)
end

------------------------------------------------------------------ time
function App:nextDay()
	local ev = GS.advanceDay(self.state)
	if #ev.soldOut > 0 then
		SoundFX.sfx("soldout", 0.6)
	elseif #ev.achievements > 0 then
		SoundFX.sfx("notify", 0.6)
	end
	for _, so in ipairs(ev.soldOut) do
		local s = so.tour.shows[so.idx]
		local v = Countries.venueById[s.venueId]
		self:toast("<b>SOLD OUT!</b> " .. Artists.byId[so.tour.artistId].name .. " @ " .. v.name .. " (" .. Util.number(v.cap) .. ")", T.gold)
	end
	for _, p in ipairs(ev.played) do
		local r = p.result
		local v = Countries.venueById[p.tour.shows[p.idx].venueId]
		self:toast(
			string.format(
				"%s @ %s<br/>%s/%s sold - %s gross - <font color='%s'>%s net</font>  %s",
				Artists.byId[p.tour.artistId].name,
				v.name,
				Util.number(r.sold),
				Util.number(r.cap),
				Util.moneyShort(r.gross),
				r.net >= 0 and "#2ecc71" or "#ff5252",
				Util.moneyShort(r.net),
				Util.stars(r.stars)
			),
			r.soldOut and T.gold or T.accent2
		)
	end
	for _, id in ipairs(ev.achievements) do
		self:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name .. "<br/>" .. Achievements.byId[id].desc, T.accent, 8)
	end
	for _, l in ipairs(ev.live) do
		table.insert(self.liveQueue, l)
	end
	if ev.levelUp then
		SoundFX.sfx("levelup", 0.8)
		self:modal("LEVEL UP!", "Your label is now a <b>" .. ev.levelUp .. "</b>.\nNew artists are ready to talk to you in ARTISTS > TALENT SCOUT.", { { "Nice!", T.gold } }, 600)
	end
	for _, tour in ipairs(ev.completed) do
		self:tourCompleted(tour)
	end
	self:refreshCurrent()
	self:processLiveQueue()
end

function App:tourCompleted(tour)
	self:tourReport(tour, true)
	self:save()
end

-- Tour report: real numbers per show (not estimates) with charts
function App:tourReport(tour, finished)
	local ad = Artists.byId[tour.artistId]
	local state = self.state
	self.modalOpen = true
	local layer = UI.New("TextButton", { Parent = self.canvas, Name = "TourReport", Size = UI.px(1920, 1080), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AutoButtonColor = false, Text = "", ZIndex = 50 })
	local box = UI.New("Frame", { Parent = layer, Position = UI.px(90, 50), Size = UI.px(1740, 980), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 51, UI.Corner(16), UI.Stroke(T.accent, 2, 0) })
	local function z(inst)
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 52
			end
		end
	end
	local function close()
		layer:Destroy()
		self.modalOpen = false
		task.defer(function()
			self:processLiveQueue()
		end)
	end
	-- collect the played shows
	local rows = {}
	local tot = { gross = 0, rent = 0, production = 0, travel = 0, cut = 0, net = 0, sold = 0, cap = 0, rating = 0, n = 0, sellouts = 0 }
	for i, s in ipairs(tour.shows) do
		if s.done and s.result then
			local r = s.result
			local v = Countries.venueById[s.venueId]
			local costs = (r.rent or 0) + (r.production or 0) + (r.travel or 0) + (r.artistCut or 0)
			if costs == 0 then
				costs = (r.gross or 0) - (r.net or 0)
			end
			local row = { i = i, v = v, day = s.day, gross = r.gross or 0, net = r.net or 0, costs = costs, rent = r.rent or 0, production = r.production or 0, travel = r.travel or 0, cut = r.artistCut or 0, sold = r.sold or 0, cap = r.cap or s.cap, stars = r.stars or 0, rating = r.rating or 0 }
			table.insert(rows, row)
			tot.gross = tot.gross + row.gross
			tot.net = tot.net + row.net
			tot.rent = tot.rent + row.rent
			tot.production = tot.production + row.production
			tot.travel = tot.travel + row.travel
			tot.cut = tot.cut + row.cut
			tot.sold = tot.sold + row.sold
			tot.cap = tot.cap + row.cap
			tot.rating = tot.rating + row.rating
			tot.n = tot.n + 1
			if row.sold >= row.cap then
				tot.sellouts = tot.sellouts + 1
			end
		end
	end
	local costsAll = tot.gross - tot.net
	UI.Label(box, finished and "TOUR COMPLETE - THE REPORT" or "TOUR REPORT", UI.px(32, 20), UI.px(1000, 40), { textSize = 32, font = UI.FontBlack, color = T.accent })
	UI.Label(box, ad.name .. "  -  " .. UI.esc(tour.name) .. "   |   " .. tot.n .. " of " .. #tour.shows .. " shows played", UI.px(32, 62), UI.px(1400, 26), { textSize = 18, color = T.sub })
	-- key numbers
	local kpis = {
		{ "TICKETS SOLD", Util.short(tot.sold) .. " / " .. Util.short(tot.cap), T.text },
		{ "FILL", (tot.cap > 0 and math.floor(tot.sold / tot.cap * 100 + 0.5) or 0) .. "%", T.text },
		{ "GROSS", Util.money(tot.gross), T.text },
		{ "COSTS", Util.money(costsAll), T.bad },
		{ "PROFIT", (tot.net >= 0 and "+" or "") .. Util.money(tot.net), tot.net >= 0 and T.good or T.bad },
		{ "AVG RATING", (tot.n > 0 and math.floor(tot.rating / tot.n + 0.5) or 0) .. "/100", T.gold },
		{ "SOLD OUT", tot.sellouts .. " / " .. tot.n, T.text },
	}
	for i, k in ipairs(kpis) do
		local tile = UI.New("Frame", { Parent = box, Position = UI.px(32 + (i - 1) * 240, 100), Size = UI.px(228, 78), BackgroundColor3 = T.panel2, BorderSizePixel = 0, UI.Corner(10) })
		UI.Label(tile, k[1], UI.px(14, 8), UI.px(210, 18), { textSize = 13, color = T.sub, font = UI.FontBold })
		UI.Label(tile, k[2], UI.px(14, 30), UI.px(210, 38), { textSize = 24, font = UI.FontBlack, color = k[3] })
	end
	-- chart 1: per show, money in (gross) and out (costs stacked), profit as a dot
	local cw, ch = 1100, 330
	local chart = UI.New("Frame", { Parent = box, Position = UI.px(32, 230), Size = UI.px(cw, ch), BackgroundColor3 = Color3.fromRGB(18, 18, 26), BorderSizePixel = 0, UI.Corner(10) })
	UI.Label(box, "MONEY PER SHOW  (green = ticket gross, stacked = costs, dot = profit)", UI.px(32, 198), UI.px(cw, 26), { textSize = 15, font = UI.FontBold, color = T.sub })
	local maxV = 1
	for _, r in ipairs(rows) do
		maxV = math.max(maxV, r.gross, r.costs)
	end
	local minNet = 0
	for _, r in ipairs(rows) do
		minNet = math.min(minNet, r.net)
	end
	local zeroY = ch - 30 - (ch - 50) * (-minNet) / (maxV - minNet)
	local scale = (ch - 50) / (maxV - minNet)
	UI.New("Frame", { Parent = chart, Position = UI.px(10, zeroY), Size = UI.px(cw - 20, 1), BackgroundColor3 = T.sub, BorderSizePixel = 0 })
	UI.Label(chart, Util.moneyShort(maxV), UI.px(10, 6), UI.px(200, 18), { textSize = 12, color = T.sub })
	local n = math.max(1, #rows)
	local slot = (cw - 40) / n
	local bw = math.max(3, math.min(36, slot * 0.38))
	local COSTCOL = { Color3.fromRGB(230, 90, 90), Color3.fromRGB(240, 150, 60), Color3.fromRGB(150, 110, 230), Color3.fromRGB(90, 160, 240) }
	for k, r in ipairs(rows) do
		local x = 20 + (k - 1) * slot + slot / 2
		local gh = r.gross * scale
		UI.New("Frame", { Parent = chart, Position = UI.px(x - bw - 1, zeroY - gh), Size = UI.px(bw, gh), BackgroundColor3 = Color3.fromRGB(60, 200, 120), BorderSizePixel = 0 })
		local y = zeroY
		for c, val in ipairs({ r.rent, r.production, r.travel, r.cut }) do
			local hh = val * scale
			y = y - hh
			UI.New("Frame", { Parent = chart, Position = UI.px(x + 1, y), Size = UI.px(bw, hh), BackgroundColor3 = COSTCOL[c], BorderSizePixel = 0 })
		end
		local ny = zeroY - r.net * scale
		UI.New("Frame", { Parent = chart, Position = UI.px(x - 5, ny - 5), Size = UI.px(10, 10), BackgroundColor3 = (r.net >= 0) and Color3.new(1, 1, 1) or T.bad, BorderSizePixel = 0, UI.Corner(5) })
		if n <= 16 then
			UI.Label(chart, r.v.city, UI.px(x - slot / 2, ch - 26), UI.px(slot, 20), { textSize = 11, color = T.sub, alignX = Enum.TextXAlignment.Center })
		end
	end
	-- chart 2: where the money went
	local px0 = 1160
	UI.Label(box, "WHERE THE MONEY WENT", UI.px(px0, 198), UI.px(540, 26), { textSize = 15, font = UI.FontBold, color = T.sub })
	local parts = {
		{ "Venue rent", tot.rent, COSTCOL[1] },
		{ "Stage production", tot.production, COSTCOL[2] },
		{ "Travel & trucks", tot.travel, COSTCOL[3] },
		{ "Artist's share", tot.cut, COSTCOL[4] },
		{ (tot.net >= 0) and "Label profit" or "Loss", math.abs(tot.net), (tot.net >= 0) and Color3.fromRGB(60, 200, 120) or T.bad },
	}
	local sum = 0
	for _, pp in ipairs(parts) do
		sum = sum + pp[2]
	end
	local bx = 0
	local bar = UI.New("Frame", { Parent = box, Position = UI.px(px0, 236), Size = UI.px(540, 40), BackgroundColor3 = T.panel2, BorderSizePixel = 0, ClipsDescendants = true, UI.Corner(8) })
	for i, pp in ipairs(parts) do
		local w = (sum > 0) and pp[2] / sum * 540 or 0
		UI.New("Frame", { Parent = bar, Position = UI.px(bx, 0), Size = UI.px(w, 40), BackgroundColor3 = pp[3], BorderSizePixel = 0 })
		bx = bx + w
		local ly = 292 + (i - 1) * 46
		UI.New("Frame", { Parent = box, Position = UI.px(px0, ly + 6), Size = UI.px(18, 18), BackgroundColor3 = pp[3], BorderSizePixel = 0, UI.Corner(4) })
		UI.Label(box, pp[1], UI.px(px0 + 30, ly), UI.px(260, 30), { textSize = 17 })
		UI.Label(box, Util.money(pp[2]) .. "  (" .. ((sum > 0) and math.floor(pp[2] / sum * 100 + 0.5) or 0) .. "%)", UI.px(px0 + 280, ly), UI.px(260, 30), { textSize = 17, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	end
	-- chart 3: how full every show was
	UI.Label(box, "HOW FULL EVERY SHOW WAS", UI.px(32, 580), UI.px(cw, 26), { textSize = 15, font = UI.FontBold, color = T.sub })
	local fchart = UI.New("Frame", { Parent = box, Position = UI.px(32, 610), Size = UI.px(cw, 190), BackgroundColor3 = Color3.fromRGB(18, 18, 26), BorderSizePixel = 0, UI.Corner(10) })
	for k, r in ipairs(rows) do
		local x = 20 + (k - 1) * slot + slot / 2
		local f = (r.cap > 0) and r.sold / r.cap or 0
		local hh = 150 * f
		local col = (f >= 0.999) and T.gold or ((f > 0.75) and T.good or ((f > 0.45) and T.warn or T.bad))
		UI.New("Frame", { Parent = fchart, Position = UI.px(x - bw, 170 - hh), Size = UI.px(bw * 2, hh), BackgroundColor3 = col, BorderSizePixel = 0 })
		if n <= 24 then
			UI.Label(fchart, math.floor(f * 100 + 0.5) .. "%", UI.px(x - slot / 2, 150 - hh), UI.px(slot, 18), { textSize = 11, alignX = Enum.TextXAlignment.Center })
		end
	end
	-- best and worst show
	local best, worst
	for _, r in ipairs(rows) do
		if not best or r.net > best.net then
			best = r
		end
		if not worst or r.net < worst.net then
			worst = r
		end
	end
	local lines = {}
	if best then
		table.insert(lines, "Best show: <b>" .. best.v.name .. ", " .. best.v.city .. "</b>  (" .. (best.net >= 0 and "+" or "") .. Util.money(best.net) .. ", " .. best.stars .. " stars)")
		table.insert(lines, "Weakest show: <b>" .. worst.v.name .. ", " .. worst.v.city .. "</b>  (" .. (worst.net >= 0 and "+" or "") .. Util.money(worst.net) .. ", " .. worst.stars .. " stars)")
	end
	table.insert(lines, ad.name .. " now has <b>" .. Util.short(Util.totalFans(state.artists[ad.id].fans)) .. "</b> fans (" .. Util.tier(Util.totalFans(state.artists[ad.id].fans)) .. ").")
	UI.Label(box, table.concat(lines, "\n"), UI.px(px0, 540), UI.px(540, 260), { textSize = 17, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(box, "Charts", UI.px(1280, 900), UI.px(200, 56), { color = T.panel3, textSize = 18 }, function()
		close()
		self:go("charts")
	end)
	UI.Button(box, finished and "Great!" or "Close", UI.px(1500, 900), UI.px(208, 56), { color = T.accent, textSize = 20 }, close)
	z(box)
	return close
end

function App:processLiveQueue()
	if self.modalOpen or self.mode ~= "menu" then
		return
	end
	local item = table.remove(self.liveQueue, 1)
	if not item then
		return
	end
	local tour = GS.getTour(self.state, item.tourId)
	if not tour then
		self:processLiveQueue()
		return
	end
	local s = tour.shows[item.idx]
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	self:modal("SHOWTIME!", string.format("<b>%s</b> plays <b>%s</b> in %s tonight.<br/>%s / %s tickets sold.<br/><br/>Do you want to watch the show live?", ad.name, v.name, v.city, Util.number(s.sold), Util.number(v.cap)), {
		{ "Simulate", T.panel3, function()
			self:resolveShow(tour, item.idx, false)
		end },
		{ "WATCH LIVE", T.accent, function()
			self:resolveShow(tour, item.idx, true)
		end },
	}, 640)
end

function App:resolveShow(tour, idx, watch)
	local result = GS.prepareShow(self.state, tour, idx)
	local function apply()
		local res = GS.applyShow(self.state, tour, idx, result)
		self:showResult(tour, idx, result, function()
			for _, id in ipairs(res.achievements) do
				self:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name, T.accent, 8)
			end
			if res.completed then
				self:tourCompleted(tour)
			end
			self:refreshCurrent()
			self:processLiveQueue()
		end)
	end
	if watch then
		local LiveShow = require(Root.Client.LiveShow)
		local s = tour.shows[idx]
		LiveShow.run(self, {
			artistId = tour.artistId,
			design = GS.showDesign(self.state, tour, idx),
			venueId = s.venueId,
			sold = result.sold,
			tourName = tour.name,
			result = result,
			onDone = function()
				self:enterMode("menu")
				self:go(self.current ~= "designer" and self.current or "tours")
				apply()
			end,
		})
	else
		apply()
	end
end

function App:showResult(tour, idx, r, onClose)
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	local body = table.concat({
		"<b>" .. ad.name .. " @ " .. v.name .. ", " .. v.city .. "</b>",
		"",
		"<font size='28' color='#ffcd3c'>" .. Util.stars(r.stars) .. "</font>   rating " .. math.floor(r.rating + 0.5) .. "/100",
		"<i>" .. r.review .. "</i>",
		"",
		"Attendance: <b>" .. Util.number(r.sold) .. " / " .. Util.number(r.cap) .. "</b>" .. (r.soldOut and "  <font color='#ffcd3c'><b>SOLD OUT!</b></font>" or ""),
		"Ticket gross: <b>" .. Util.money(r.gross) .. "</b>  (" .. Util.money(r.price) .. " per ticket)",
		"Costs: venue " .. Util.money(r.rent) .. ", production " .. Util.money(r.production) .. ", travel " .. Util.money(r.travel) .. ", artist share " .. Util.money(r.artistCut),
		"Label profit: <b><font color='" .. (r.net >= 0 and "#2ecc71" or "#ff5252") .. "'>" .. Util.money(r.net) .. "</font></b>",
		"New fans: <b>+" .. Util.number(r.fansGained) .. "</b>",
	}, "\n")
	SoundFX.sfx(r.net >= 0 and "cash" or "error", 0.7)
	self:modal("SHOW REPORT", body, { { "Continue", T.accent, onClose } }, 760)
end

return App
