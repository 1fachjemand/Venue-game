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
	self.dateLbl = UI.Label(hud, "", UI.px(1262, 36), UI.px(210, 22), { textSize = 16, alignX = Enum.TextXAlignment.Right, color = T.sub })
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
		self:modal("LEVEL UP!", "Your label is now a <b>" .. ev.levelUp .. "</b>.\nNew artists are ready to talk to you in ARTISTS > TALENT SCOUT.", { { "Nice!", T.gold } }, 600)
	end
	for _, tour in ipairs(ev.completed) do
		self:tourCompleted(tour)
	end
	self:refreshCurrent()
	self:processLiveQueue()
end

function App:tourCompleted(tour)
	local ad = Artists.byId[tour.artistId]
	local rows, _ = GS.chart(self.state)
	local rank = "-"
	for _, r in ipairs(rows) do
		if r.tourId == tour.id then
			rank = "#" .. r.rank
		end
	end
	local avg = tour.played > 0 and (tour.ratingSum / tour.played) or 0
	self:modal("TOUR COMPLETE!", table.concat({
		"<b>" .. ad.name .. " - " .. UI.esc(tour.name) .. "</b>",
		"",
		"Shows: <b>" .. tour.played .. "</b>   Sold out: <b>" .. tour.sellouts .. "</b>",
		"Attendance: <b>" .. Util.number(tour.attendance) .. "</b>",
		"Gross: <b>" .. Util.money(tour.gross) .. "</b>",
		"Label profit: <b>" .. Util.money(tour.net) .. "</b>",
		"Average rating: <b>" .. math.floor(avg + 0.5) .. "/100</b>",
		"All-time chart position: <b>" .. rank .. "</b>",
		"",
		ad.name .. " now has <b>" .. Util.short(Util.totalFans(self.state.artists[ad.id].fans)) .. "</b> fans (" .. Util.tier(Util.totalFans(self.state.artists[ad.id].fans)) .. ").",
	}, "\n"), { { "Charts", T.panel3, function()
		self:go("charts")
	end }, { "Great!", T.accent } }, 640)
	self:save()
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
	self:modal("SHOW REPORT", body, { { "Continue", T.accent, onClose } }, 760)
end

return App
