-- Main client controller: talks to the server, HUD, the station screens, popups, shows.
-- The game state lives on the server (src/server/GameServer). `app.state` is a copy that the
-- server keeps up to date; every change goes through app:act(name, args).
local Players = game:GetService("Players")
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
local BLACK = Color3.new(0, 0, 0)
local App = {}
App.__index = App

------------------------------------------------------------------ server
-- raw call: returns the server's answer table { ok, msg, data, delta } (args and data travel as JSON)
function App:call(name, args)
	local okEnc, json = pcall(function()
		return HttpService:JSONEncode(args or {})
	end)
	if not okEnc then
		return { ok = false, msg = "Could not send that." }
	end
	local ok, res = pcall(function()
		return Root.Remotes.Action:InvokeServer(name, json)
	end)
	if not ok or type(res) ~= "table" then
		return { ok = false, msg = "No connection to the server." }
	end
	if type(res.data) == "string" then
		local okDec, data = pcall(function()
			return HttpService:JSONDecode(res.data)
		end)
		res.data = okDec and data or nil
	end
	return res
end

-- the server sends the parts of the state that changed; they are copied into app.state in place
function App:applyDelta(delta)
	if type(delta) ~= "table" then
		return
	end
	self.state = self.state or {}
	for k, json in pairs(delta) do
		local ok, wrap = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(wrap) == "table" then
			local v = wrap.v
			if type(v) == "table" and type(self.state[k]) == "table" then
				Util.syncInto(self.state[k], v)
			else
				self.state[k] = v
			end
		end
	end
end

-- runs a game action on the server: returns ok, message, data
function App:act(name, args)
	local res = self:call(name, args)
	self:applyDelta(res.delta)
	return res.ok == true, res.msg, res.data
end

-- the server saves by itself; kept for older calls
function App:save() end

-- the stage builder edits a design here and sends it when it closes (the server pays the difference)
function App:saveDesign(design)
	if not design then
		return
	end
	GS.ensureUids(design)
	local ok, msg = self:act("saveDesign", { designId = design.id, design = { name = design.name, items = design.items } })
	if not ok then
		self:toast(msg or "Could not save the stage.", T.bad)
		self:applyDelta(self:call("resync").delta)
	end
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
		if self.placeEdges then
			self.placeEdges()
		end
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	local loading = UI.Label(self.canvas, "HEADLINER  -  loading...", UI.px(0, 500), UI.px(1920, 80), { textSize = 48, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center, color = T.accent })

	Stage3D.init()
	local hello = self:call("hello")
	local info = hello.data or {}
	self.saveAvailable = info.saveAvailable == true
	self.canSandbox = info.canSandbox == true
	loading:Destroy()

	self.mode = "title"
	self.modalOpen = false
	self.liveQueue = {}
	self.screens = {}
	local MainMenu = require(Root.Client.MainMenu)
	MainMenu.show(self, info, function(isNew)
		self:beginGame(isNew)
	end)
	return self
end

-- MainMenu: start a new label (or the developer sandbox) / continue a saved one
function App:startNew(labelName, starterId, sandbox)
	local res = self:call("newGame", { labelName = labelName, starterId = starterId, sandbox = sandbox == true })
	if not res.ok then
		self:toast(res.msg or "Could not start.", T.bad)
		return false
	end
	self.state = nil
	self:applyDelta(res.delta)
	return true
end

function App:continueGame(slot)
	local res = self:call("continue", { slot = slot })
	if not res.ok then
		self:toast(res.msg or "Could not load.", T.bad)
		return false
	end
	self.state = nil
	self:applyDelta(res.delta)
	return true
end

function App:beginGame(isNew)
	self.backdrop.Visible = false
	self:buildHud()
	self.content = UI.New("Frame", { Parent = self.canvas, Name = "Content", Position = UI.px(0, 72), Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false })
	self:buildScreenBar()
	local Screens = Root.Client.Screens
	self.screens.office = require(Screens.OfficeScreen).new(self)
	self.screens.planner = require(Screens.PlannerScreen).new(self)
	self.screens.artists = require(Screens.ArtistsScreen).new(self)
	self.screens.tours = require(Screens.ToursScreen).new(self)
	self.screens.charts = require(Screens.ChartsScreen).new(self)
	self.screens.stages = require(Screens.StagesScreen).new(self)
	self.screens.social = require(Screens.SocialScreen).new(self)
	self.toastFrame = UI.New("Frame", { Parent = self.canvas, Name = "Toasts", Position = UI.px(740, 80), Size = UI.px(440, 900), BackgroundTransparency = 1, ZIndex = 60 })
	UI.List(true, 8, Enum.HorizontalAlignment.Center).Parent = self.toastFrame
	self.mode = "world"
	local World = require(Root.Client.World)
	self.world = World
	World.start(self)
	SoundFX.menu("office")
	self:refreshHud()
	if isNew then
		self:showWelcome()
	elseif self.saveAvailable then
		self:toast("Welcome back! Progress saves automatically.", T.good)
	end
end

------------------------------------------------------------------ HUD (walking around): money, date, level, NEXT DAY
function App:buildHud()
	local hud = UI.New("Frame", { Parent = self.canvas, Name = "Hud", Position = UI.px(20, 20), Size = UI.px(600, 118), BackgroundColor3 = T.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, UI.Corner(14), UI.Stroke(T.accent, 2, 0.3) })
	self.hud = hud
	self.labelLbl = UI.Label(hud, "", UI.px(18, 10), UI.px(330, 26), { textSize = 20, font = UI.FontBlack })
	self.levelPill = UI.Pill(hud, "", UI.px(356, 12), UI.px(226, 24), T.accent, 13)
	local bar, setBar = UI.Bar(hud, UI.px(18, 44), UI.px(330, 8), 0, T.gold)
	self.levelBar, self.setLevelBar = bar, setBar
	self.levelLbl = UI.Label(hud, "", UI.px(356, 38), UI.px(226, 20), { textSize = 13, color = T.sub, alignX = Enum.TextXAlignment.Right })
	self.moneyLbl = UI.Label(hud, "", UI.px(18, 62), UI.px(220, 40), { textSize = 30, font = UI.FontBlack, color = T.good })
	self.dateLbl = UI.Label(hud, "", UI.px(238, 66), UI.px(170, 34), { textSize = 17, font = UI.FontBold, color = T.text })
	UI.Button(hud, "NEXT DAY  ▶", UI.px(414, 64), UI.px(168, 42), { color = T.accent, textSize = 16 }, function()
		self:nextDay()
	end)
	-- what to do next (follow the arrow)
	local obj = UI.New("Frame", { Parent = self.canvas, Name = "Objective", Position = UI.px(20, 148), Size = UI.px(600, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, BackgroundTransparency = 0.2, BorderSizePixel = 0, UI.Corner(12), UI.Padding(16, 16, 10, 10) })
	self.objectiveFrame = obj
	self.objectiveLbl = UI.New("TextLabel", { Parent = obj, Size = UI.px(568, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "", RichText = true, TextWrapped = true, TextColor3 = T.text, TextSize = 17, Font = UI.FontBold, TextXAlignment = Enum.TextXAlignment.Left })
	-- the phone (SOCIAL) is always at hand
	local phone = UI.Button(self.canvas, "", UI.px(1790, 870), UI.px(104, 180), { color = Color3.fromRGB(16, 16, 22) }, function()
		self:openPhone()
	end)
	phone.Name = "PhoneButton"
	UI.Stroke(T.accent2, 3, 0).Parent = phone
	UI.New("Frame", { Parent = phone, Position = UI.px(8, 18), Size = UI.px(88, 140), BackgroundColor3 = Color3.fromRGB(32, 30, 60), BorderSizePixel = 0, UI.Corner(8), UI.New("UIGradient", { Color = ColorSequence.new(T.accent, T.accent2), Rotation = 90 }) })
	UI.Label(phone, "SOCIAL", UI.px(0, 70), UI.px(104, 30), { textSize = 18, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
	UI.New("Frame", { Parent = phone, Position = UI.px(40, 6), Size = UI.px(24, 5), BackgroundColor3 = Color3.fromRGB(60, 60, 70), BorderSizePixel = 0, UI.Corner(3) })
	self.phoneBadge = UI.Pill(phone, "", UI.px(64, -10), UI.px(50, 28), T.bad, 15)
	self.phoneButton = phone
	-- sandbox tools (developer test mode only)
	if self.state.sandbox then
		local sb = UI.New("Frame", { Parent = self.canvas, Name = "Sandbox", Position = UI.px(1500, 20), Size = UI.px(400, 112), BackgroundColor3 = Color3.fromRGB(60, 40, 10), BackgroundTransparency = 0.1, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.gold, 2, 0) })
		UI.Label(sb, "SANDBOX  ·  developer mode", UI.px(16, 8), UI.px(370, 24), { textSize = 16, font = UI.FontBlack, color = T.gold })
		UI.Button(sb, "SKIP TO NEXT SHOW", UI.px(14, 42), UI.px(230, 56), { color = T.gold, textColor = BLACK, textSize = 15 }, function()
			self:devSkip(true)
		end)
		UI.Button(sb, "+7 DAYS", UI.px(254, 42), UI.px(132, 56), { color = T.panel3, textSize = 15 }, function()
			self:devSkip(false)
		end)
		self.sandboxPanel = sb
	end
	self.placeEdges = function()
		local gap = self.sideGap or 0
		hud.Position = UI.px(20 - gap, 20)
		obj.Position = UI.px(20 - gap, 148)
		phone.Position = UI.px(1790 + gap, 870)
		if self.sandboxPanel then
			self.sandboxPanel.Position = UI.px(1500 + gap, 20)
		end
	end
	self.placeEdges()
end

function App:refreshHud()
	local st = self.state
	if not st or not self.hud then
		return
	end
	local money = st.sandbox and "∞ SANDBOX" or Util.money(st.money)
	self.moneyLbl.Text = money
	self.moneyLbl.TextColor3 = (st.money < 0) and T.bad or T.good
	local dateTxt = Util.date(st.day, Config.START_YEAR)
	self.dateLbl.Text = dateTxt
	local lvl, def, nextDef = GS.level(st)
	self.labelLbl.Text = st.labelName
	self.levelPill.Text = "LV " .. lvl .. "  ·  " .. string.upper(def.name)
	if nextDef then
		local f = (st.stats.tickets - def.tickets) / math.max(1, nextDef.tickets - def.tickets)
		self.setLevelBar(math.clamp(f, 0, 1))
		self.levelLbl.Text = Util.number(st.stats.tickets) .. " / " .. Util.number(nextDef.tickets) .. " tickets"
	else
		self.setLevelBar(1)
		self.levelLbl.Text = "max level"
	end
	local o = GS.objective(st)
	self.objectiveLbl.Text = "<font color='#2dd4bf'>NEXT  ▸</font>  " .. o.text
	-- unread fan posts since the phone was last opened
	local unread = math.max(0, #(st.social or {}) - (self.seenPosts or 0))
	self.phoneBadge.Visible = unread > 0
	self.phoneBadge.Text = unread > 99 and "99+" or tostring(unread)
	if self.barMoney then
		self.barMoney.Text = money
		self.barMoney.TextColor3 = self.moneyLbl.TextColor3
		self.barDate.Text = dateTxt
	end
	local walking = self.mode == "world"
	self.hud.Visible = walking
	self.objectiveFrame.Visible = walking
	self.phoneButton.Visible = walking
	if self.sandboxPanel then
		self.sandboxPanel.Visible = walking
	end
end

------------------------------------------------------------------ station screens (opened at a place in the building)
local TITLES = {
	office = "LAPTOP",
	tours = "LAPTOP",
	planner = "WORLD MAP  ·  PLAN A TOUR",
	artists = "MEETING ROOM",
	stages = "STAGE HALL",
	charts = "CHARTS",
	social = "SOCIAL",
}

function App:buildScreenBar()
	local bar = UI.New("Frame", { Parent = self.canvas, Name = "ScreenBar", Size = UI.px(1920, 64), BackgroundColor3 = T.panel, BorderSizePixel = 0, Visible = false })
	UI.New("Frame", { Parent = bar, Position = UI.px(0, 63), Size = UI.px(1920, 2), BackgroundColor3 = T.accent, BorderSizePixel = 0 })
	self.screenBar = bar
	self.barTitle = UI.Label(bar, "", UI.px(24, 0), UI.px(520, 64), { textSize = 24, font = UI.FontBlack, color = T.accent })
	-- laptop: two pages
	self.barTabs = {}
	for i, tab in ipairs({ { "office", "OVERVIEW" }, { "tours", "TOURS" } }) do
		self.barTabs[tab[1]] = UI.Button(bar, tab[2], UI.px(300 + (i - 1) * 156, 10), UI.px(146, 44), { textSize = 16 }, function()
			self:go(tab[1])
		end)
	end
	self.barMoney = UI.Label(bar, "", UI.px(1200, 4), UI.px(250, 32), { textSize = 26, font = UI.FontBlack, color = T.good, alignX = Enum.TextXAlignment.Right })
	self.barDate = UI.Label(bar, "", UI.px(1200, 34), UI.px(250, 24), { textSize = 16, color = T.sub, alignX = Enum.TextXAlignment.Right })
	UI.Button(bar, "NEXT DAY", UI.px(1470, 10), UI.px(160, 44), { color = T.accent, textSize = 16 }, function()
		self:nextDay()
	end)
	UI.Button(bar, "✕  CLOSE", UI.px(1650, 10), UI.px(250, 44), { color = T.panel3, textSize = 18 }, function()
		self:closeScreen()
	end)
end

-- opens a screen (as a full-screen page, the character waits in the building)
function App:go(name, args)
	if not self.screens[name] then
		return
	end
	if self.mode == "world" and self.world then
		self.world.freeze(true)
	end
	self.mode = "menu"
	self.current = name
	self.backdrop.Visible = true
	self.content.Visible = true
	self.screenBar.Visible = true
	self.barTitle.Text = TITLES[name] or string.upper(name)
	for key, b in pairs(self.barTabs) do
		b.Visible = (name == "office" or name == "tours")
		b.BackgroundColor3 = (key == name) and T.accent or T.panel3
	end
	for key, scr in pairs(self.screens) do
		if key ~= name and scr.hide and scr.frame.Visible then
			scr:hide()
		end
		scr.frame.Visible = key == name
	end
	local scr = self.screens[name]
	self.returnScreen = name
	scr:show(args)
	self:refreshHud()
end

-- back to walking around in the building
function App:closeScreen()
	for _, scr in pairs(self.screens) do
		if scr.frame.Visible then
			if scr.hide then
				scr:hide()
			end
			scr.frame.Visible = false
		end
	end
	require(Root.Client.WorldMap3D).deactivate()
	self.current = nil
	self.backdrop.Visible = false
	self.content.Visible = false
	self.screenBar.Visible = false
	self.mode = "world"
	Stage3D.setLighting("hub")
	if self.world then
		self.world.freeze(false)
		self.world.resetCamera()
		self.world.refresh()
	end
	self:refreshHud()
	self:processLiveQueue()
end

function App:openPhone()
	self.seenPosts = #(self.state.social or {})
	self:go("social")
end

function App:refreshCurrent()
	local scr = self.current and self.screens[self.current]
	if scr and scr.frame.Visible then
		scr:refresh()
	end
	if self.world and self.mode == "world" then
		self.world.refresh()
	end
	self:refreshHud()
end

-- "designer" and "live" hide everything of the building UI; "menu" = a station screen is open
function App:enterMode(mode)
	if mode == "menu" then
		self.mode = "menu"
		self.backdrop.Visible = true
		self.content.Visible = true
		self.screenBar.Visible = true
		self:refreshHud()
		return
	end
	self.mode = mode
	require(Root.Client.WorldMap3D).deactivate()
	self.backdrop.Visible = false
	self.content.Visible = false
	self.screenBar.Visible = false
	if self.world then
		self.world.freeze(true)
	end
	self:refreshHud()
end

function App:openDesigner(designId)
	if self.modalOpen then
		return
	end
	local Designer = require(Root.Client.Designer)
	self.current = "designer"
	Designer.open(self, designId)
end

-- sandbox: jump ahead (until the next show, or one week)
function App:devSkip(untilShow)
	if self.modalOpen or #self.liveQueue > 0 then
		return
	end
	local ok, msg, ev = self:act("devSkip", { untilShow = untilShow, days = untilShow and 120 or 7 })
	if not ok then
		self:toast(msg or "Not possible.", T.bad)
		return
	end
	self:handleDay(ev)
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
		"This is your label building. Walk around with <b>W A S D</b>, press <b>E</b> at a station.",
		"",
		"<b>WORLD MAP table</b>   plan a tour: country, venue, date, ticket price.",
		"<b>LAPTOP</b>   your shows, ticket sales and news.",
		"<b>MEETING ROOM</b>   sit down to meet your artists and new talent.",
		"<b>NEXT DAY</b>   moves time forward. On a show day you travel to the venue.",
		"",
		"Follow the glowing arrow. Start small: clubs first!",
	}, "\n"), { { "Let's go!", T.accent } }, 760)
end

------------------------------------------------------------------ time
function App:nextDay()
	if self.modalOpen or #self.liveQueue > 0 or (self.mode ~= "world" and self.mode ~= "menu") then
		return
	end
	local ok, msg, ev = self:act("nextDay")
	if not ok then
		-- a show of today still waits: go to it
		self:queueTodaysShows()
		if #self.liveQueue == 0 then
			self:toast(msg or "Not possible.", T.bad)
		end
		self:processLiveQueue()
		return
	end
	self:handleDay(ev)
end

-- shows of today that are not played yet (e.g. after loading a save on a show day)
function App:queueTodaysShows()
	for _, tour in ipairs(self.state.tours) do
		for idx, s in ipairs(tour.shows) do
			if not s.done and s.day <= self.state.day then
				local queued = false
				for _, q in ipairs(self.liveQueue) do
					if q.tourId == tour.id and q.idx == idx then
						queued = true
					end
				end
				if not queued then
					table.insert(self.liveQueue, { tourId = tour.id, idx = idx })
				end
			end
		end
	end
end

-- what happened during the day(s): sold out shows, shows played without the player, achievements, today's shows
function App:handleDay(ev)
	ev = ev or {}
	local state = self.state
	if #(ev.soldOut or {}) > 0 then
		SoundFX.sfx("soldout", 0.6)
	elseif #(ev.achievements or {}) > 0 then
		SoundFX.sfx("notify", 0.6)
	end
	for _, so in ipairs(ev.soldOut or {}) do
		local tour = GS.getTour(state, so.tourId)
		local s = tour and tour.shows[so.idx]
		if s then
			local v = Countries.venueById[s.venueId]
			self:toast("<b>SOLD OUT!</b> " .. Artists.byId[tour.artistId].name .. " @ " .. v.name .. " (" .. Util.number(v.cap) .. ")", T.gold)
		end
	end
	for _, p in ipairs(ev.played or {}) do
		local tour = GS.getTour(state, p.tourId)
		local r = p.result
		if tour and r then
			local v = Countries.venueById[tour.shows[p.idx].venueId]
			self:toast(
				string.format(
					"%s @ %s<br/>%s/%s sold - %s gross - <font color='%s'>%s net</font>  %s",
					Artists.byId[tour.artistId].name,
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
	end
	for _, id in ipairs(ev.achievements or {}) do
		self:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name .. "<br/>" .. Achievements.byId[id].desc, T.accent, 8)
	end
	for _, l in ipairs(ev.live or {}) do
		table.insert(self.liveQueue, l)
	end
	if ev.levelUp then
		SoundFX.sfx("levelup", 0.8)
		local lvl = GS.level(state)
		local open = {}
		for vtype, need in pairs(Config.VENUE_LEVEL) do
			if need == lvl then
				table.insert(open, Countries.VENUE_TYPES[vtype].label)
			end
		end
		table.sort(open)
		local extra = (#open > 0) and ("\nYou can now book <b>" .. table.concat(open, " / ") .. "</b> venues.") or ""
		self:modal("LEVEL UP!", "Your label is now a <b>" .. ev.levelUp .. "</b>." .. extra .. "\nNew artists want to meet you in the MEETING ROOM.", { { "Nice!", T.gold } }, 640)
	end
	for _, tourId in ipairs(ev.completed or {}) do
		local tour = GS.getTour(state, tourId)
		if tour then
			self:tourCompleted(tour)
		end
	end
	self:refreshCurrent()
	self:processLiveQueue()
end

function App:tourCompleted(tour)
	self:tourReport(tour, true)
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
	if self.modalOpen or (self.mode ~= "world" and self.mode ~= "menu") then
		return
	end
	local item = table.remove(self.liveQueue, 1)
	if not item then
		return
	end
	local tour = GS.getTour(self.state, item.tourId)
	local s = tour and tour.shows[item.idx]
	if not s or s.done then
		self:processLiveQueue()
		return
	end
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	self:modal("SHOWTIME!", string.format("<b>%s</b> plays <b>%s</b> in %s tonight.<br/>%s / %s tickets sold.<br/><br/>Do you want to watch the show live?", ad.name, v.name, v.city, Util.number(s.sold), Util.number(v.cap)), {
		{ "Skip", T.panel3, function()
			self:resolveShow(tour, item.idx, false)
		end },
		{ "WATCH LIVE", T.accent, function()
			self:resolveShow(tour, item.idx, true)
		end },
	}, 640)
end

-- the server decides and books the result first, the show (if watched) then plays it out
function App:resolveShow(tour, idx, watch)
	local ok, msg, data = self:act("playShow", { tourId = tour.id, idx = idx })
	if not ok or not data then
		self:toast(msg or "The show could not start.", T.bad)
		self:processLiveQueue()
		return
	end
	tour = GS.getTour(self.state, tour.id) or tour
	local result = data.result
	local function report()
		self:showResult(tour, idx, result, function()
			for _, id in ipairs(data.achievements or {}) do
				self:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name, T.accent, 8)
			end
			if data.completed then
				self:tourCompleted(tour)
			end
			self:refreshCurrent()
			self:processLiveQueue()
		end)
	end
	if watch then
		local LiveShow = require(Root.Client.LiveShow)
		local s = tour.shows[idx]
		local back = self.current
		LiveShow.run(self, {
			artistId = tour.artistId,
			design = GS.showDesign(self.state, tour, idx),
			venueId = s.venueId,
			sold = result.sold,
			tourName = tour.name,
			result = result,
			onDone = function()
				if back and self.screens[back] then
					self:go(back)
				else
					self:closeScreen()
				end
				report()
			end,
		})
	else
		report()
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
