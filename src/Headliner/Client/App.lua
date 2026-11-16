-- Main client controller: talks to the server, HUD, the station screens, popups, shows.
-- The game state lives on the server (src/server/GameServer). `app.state` is a copy that the
-- server keeps up to date; every change goes through app:act(name, args).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
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
			Color = ColorSequence.new(Color3.fromRGB(246, 248, 251), Color3.fromRGB(222, 229, 239)),
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
		self.topGap = math.max(0, (vp.Y / math.max(scale.Scale, 0.01) - 1080) / 2)
		self:measureTopbar()
		if self.onRescale then
			self.onRescale()
		end
		if self.placeEdges then
			self.placeEdges()
		end
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(rescale)
	end)

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

-- Roblox draws its own buttons (menu, chat) in the top left corner, over our UI (IgnoreGuiInset):
-- safeX / safeY = the first canvas pixel right of / below them
function App:measureTopbar()
	local left, bottom = 0, 0
	pcall(function()
		local r = GuiService["TopbarInset"]
		left, bottom = r.Min.X, r.Max.Y
	end)
	if bottom <= 0 then
		pcall(function()
			local tl = GuiService:GetGuiInset()
			bottom = tl.Y
		end)
	end
	if bottom <= 0 then
		bottom = 58
	end
	if left <= 0 then
		left = 150
	end
	local sc = math.max(self.uiScale and self.uiScale.Scale or 1, 0.01)
	self.safeX = math.max(16, left / sc - (self.sideGap or 0) + 8)
	self.safeY = math.max(12, bottom / sc - (self.topGap or 0) + 8)
end

-- position and size (canvas pixels) of a layer that covers the whole screen, also outside the 16:9 canvas
function App:fullRect()
	local gx, gy = self.sideGap or 0, self.topGap or 0
	return UI.px(-gx, -gy), UI.px(1920 + gx * 2, 1080 + gy * 2)
end

-- MainMenu: start a new label (or the developer sandbox) / continue a saved one
function App:startNew(labelName, starterId, sandbox, slot)
	local res = self:call("newGame", { labelName = labelName, starterId = starterId, sandbox = sandbox == true, slot = slot })
	if not res.ok then
		self:toast(res.msg or "Could not start.", T.bad)
		return false
	end
	self.state = nil
	self.slot = sandbox and "sandbox" or (slot or "1")
	self:applyDelta(res.delta)
	return true
end

function App:continueGame(slot)
	local res = self:call("continue", { slot = slot })
	if not res.ok then
		self:toast(res.msg or "Could not load.", T.bad)
		return false
	end
	self.slot = slot
	self.state = nil
	self:applyDelta(res.delta)
	return true
end

function App:beginGame(isNew)
	self.backdrop.Visible = false
	-- everything the game adds to the canvas from here on is removed again when you go back to the main menu
	self.baseChildren = {}
	for _, c in ipairs(self.canvas:GetChildren()) do
		self.baseChildren[c] = true
	end
	self:buildHud()
	self:buildHomeButton()
	self.content = UI.New("Frame", { Parent = self.canvas, Name = "Content", Position = UI.px(0, 72), Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false })
	self:buildScreenBar()
	local Screens = Root.Client.Screens
	self.screens.planner = require(Screens.TourPlanner).new(self)
	self.screens.planner.onAnnounced = function(tour)
		local Laptop = require(Root.Client.Laptop)
		if Laptop.isOpen(self) then
			local lt = self.laptop
			for _, w in ipairs(lt.windows) do
				if w.id == "planner" then
					Laptop.closeWindow(self, w)
				end
			end
			Laptop.openApp(self, "tours", { tourId = tour.id })
		else
			self:closeScreen()
			self:toast("Follow the ticket sales on the LAPTOP: My Tours.", T.accent2, 6)
		end
	end
	self.screens.stats = require(Screens.StatsScreen).new(self)
	self.screens.artists = require(Screens.ArtistsScreen).new(self)
	self.screens.tours = require(Screens.ToursScreen).new(self)
	self.screens.charts = require(Screens.ChartsScreen).new(self)
	self.screens.stages = require(Screens.StagesScreen).new(self)
	self.screens.social = require(Screens.SocialScreen).new(self)
	self.phone = require(Screens.PhoneScreen).new(self)
	self.toastFrame = UI.New("Frame", { Parent = self.canvas, Name = "Toasts", Position = UI.px(740, 150), Size = UI.px(440, 900), BackgroundTransparency = 1, ZIndex = 60 })
	UI.List(true, 8, Enum.HorizontalAlignment.Center).Parent = self.toastFrame
	self.mode = "world"
	local closeLoading = self:showLoading("HEADLINER", "Welcome to " .. self.state.labelName)
	local World = require(Root.Client.World)
	self.world = World
	World.start(self)
	SoundFX.menu("office")
	self:startClock()
	self:refreshHud()
	-- the loading picture stays until the character stands in the office
	task.spawn(function()
		local t0 = os.clock()
		while not (self.player.Character and self.player.Character.PrimaryPart) and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		task.wait(0.8)
		closeLoading()
	end)
	local Tutorial = require(Root.Client.Tutorial)
	if Tutorial.active(self) then
		-- Sam explains the game (the tutorial) instead of a welcome window
		task.delay(1.2, function()
			if self.state then
				Tutorial.start(self)
			end
		end)
	elseif self.saveAvailable then
		self:toast("Welcome back! Progress saves automatically.", T.good)
	end
end


------------------------------------------------------------------ loading screen (a faded concert picture)
local TIPS = {
	"Tip: small clubs sell out more easily. Grow step by step.",
	"Tip: press E at a station. Follow the golden arrow.",
	"Tip: a sold-out show brings hype, hype sells the next tour.",
	"Tip: check ticket sales on the LAPTOP and react with marketing.",
	"Tip: sit down in the MEETING ROOM to meet new talent.",
	"Tip: bigger venues need a bigger label level.",
}
function App:showLoading(title, sub)
	local root = UI.New("CanvasGroup", { Parent = self.gui, Name = "Loading", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 48, 90), BorderSizePixel = 0, ZIndex = 200 })
	UI.New("UIGradient", { Parent = root, Color = ColorSequence.new(Color3.fromRGB(96, 120, 210), Color3.fromRGB(36, 40, 78)), Rotation = 90 })
	local function frame(props)
		props.Parent = props.Parent or root
		props.BorderSizePixel = 0
		props.ZIndex = props.ZIndex or 201
		return UI.New("Frame", props)
	end
	-- light beams from the rig
	for i = 0, 7 do
		local beam = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.15 + i * 0.1, 0.06), Size = UDim2.fromScale(0.06, 0.95), Rotation = (i - 3.5) * 9, BackgroundColor3 = (i % 2 == 0) and T.accent2 or T.accent })
		UI.New("UIGradient", { Parent = beam, Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }) })
		frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.15 + i * 0.1, 0.06), Size = UDim2.fromScale(0.02, 0.035), BackgroundColor3 = Color3.new(1, 1, 1), UI.Corner(8) })
	end
	frame({ Position = UDim2.fromScale(0.05, 0.045), Size = UDim2.fromScale(0.9, 0.012), BackgroundColor3 = Color3.fromRGB(70, 70, 84) })
	-- the stage glow
	local glow = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.8, 0.22), BackgroundColor3 = T.accent, UI.Corner(400) })
	UI.New("UIGradient", { Parent = glow, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }) })
	-- the crowd (silhouettes, raised hands, phone lights)
	local rng = Random.new(5)
	for row = 0, 2 do
		for k = 0, 27 do
			local x = (k + (row % 2) * 0.5) / 27
			local y = 0.84 + row * 0.06 + rng:NextNumber(-0.01, 0.01)
			local dark = Color3.fromRGB(8 + row * 4, 6 + row * 3, 16 + row * 5)
			frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(0.045, 0.2), BackgroundColor3 = dark, UI.Corner(30), ZIndex = 202 + row })
			frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x, y + 0.01), Size = UDim2.fromScale(0.022, 0.045), BackgroundColor3 = dark, UI.Corner(30), ZIndex = 202 + row })
			if rng:NextNumber() < 0.3 then
				local arm = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(x + 0.012, y + 0.03), Size = UDim2.fromScale(0.006, 0.09), Rotation = rng:NextNumber(-20, 20), BackgroundColor3 = dark, ZIndex = 202 + row })
				if rng:NextNumber() < 0.5 then
					frame({ Parent = arm, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = Color3.fromRGB(255, 250, 220), UI.Corner(4), ZIndex = 210 })
				end
			end
		end
	end
	-- faded: a soft veil over the picture, and a bright card for the title so it is easy to read
	frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75, ZIndex = 220 })
	local center = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(900, 300), BackgroundTransparency = 1, ZIndex = 221 })
	UI.New("Frame", { Parent = center, Position = UDim2.fromOffset(40, -20), Size = UDim2.fromOffset(820, 290), BackgroundColor3 = T.panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 221, UI.Corner(20) })
	local scale = UI.New("UIScale", { Parent = center, Scale = self.uiScale and self.uiScale.Scale or 1 })
	local _ = scale
	UI.New("TextLabel", { Parent = center, Size = UDim2.fromOffset(900, 110), BackgroundTransparency = 1, Text = title or "HEADLINER", TextColor3 = T.text, TextSize = 96, Font = UI.FontBlack, ZIndex = 222 })
	UI.New("TextLabel", { Parent = center, Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(900, 36), BackgroundTransparency = 1, Text = sub or "", TextColor3 = T.accent, TextSize = 26, Font = UI.FontBold, ZIndex = 222 })
	local barBg = UI.New("Frame", { Parent = center, Position = UDim2.fromOffset(250, 176), Size = UDim2.fromOffset(400, 10), BackgroundColor3 = Color3.fromRGB(222, 228, 236), BorderSizePixel = 0, ZIndex = 222, UI.Corner(5) })
	local bar = UI.New("Frame", { Parent = barBg, Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.accent2, BorderSizePixel = 0, ZIndex = 223, UI.Corner(5) })
	local tip = UI.New("TextLabel", { Parent = center, Position = UDim2.fromOffset(0, 210), Size = UDim2.fromOffset(900, 30), BackgroundTransparency = 1, Text = TIPS[math.random(1, #TIPS)], TextColor3 = T.sub, TextSize = 20, Font = UI.Font, ZIndex = 222 })
	local alive = true
	task.spawn(function()
		local f = 0
		while alive do
			f = math.min(0.95, f + (1 - f) * 0.08)
			bar.Size = UDim2.fromScale(f, 1)
			task.wait(0.1)
		end
	end)
	local closed = false
	return function(fade)
		if closed then
			return
		end
		closed = true
		bar.Size = UDim2.fromScale(1, 1)
		local _t = tip
		task.delay(0.25, function()
			UI.Tween(root, fade or 0.6, { GroupTransparency = 1 })
			task.delay((fade or 0.6) + 0.1, function()
				alive = false
				root:Destroy()
			end)
		end)
	end
end

------------------------------------------------------------------ HUD (walking around): money, date, level, NEXT DAY
function App:buildHud()
	local hud = UI.New("Frame", { Parent = self.canvas, Name = "Hud", Position = UI.px(20, 20), Size = UI.px(676, 118), BackgroundColor3 = T.panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, UI.Corner(14), UI.Stroke(T.accent, 2, 0.3) })
	self.hud = hud
	self.labelLbl = UI.Label(hud, "", UI.px(18, 10), UI.px(330, 26), { textSize = 20, font = UI.FontBlack })
	self.levelPill = UI.Pill(hud, "", UI.px(356, 12), UI.px(226, 24), T.accent, 13)
	local bar, setBar = UI.Bar(hud, UI.px(18, 44), UI.px(330, 8), 0, T.gold)
	self.levelBar, self.setLevelBar = bar, setBar
	self.levelLbl = UI.Label(hud, "", UI.px(356, 38), UI.px(226, 20), { textSize = 13, color = T.sub, alignX = Enum.TextXAlignment.Right })
	self.moneyLbl = UI.Label(hud, "", UI.px(18, 62), UI.px(220, 40), { textSize = 30, font = UI.FontBlack, color = T.good })
	self.dateLbl = UI.Label(hud, "", UI.px(238, 66), UI.px(170, 34), { textSize = 17, font = UI.FontBold, color = T.text })
	-- time runs by itself; pause / speed
	self.speedBtns = {}
	for i, sp in ipairs(Config.SPEEDS) do
		local b = UI.Button(hud, sp.label, UI.px(400 + (i - 1) * 46, 64), UI.px(42, 42), { textSize = 15 }, function()
			self:setSpeed(i)
		end)
		table.insert(self.speedBtns, b)
	end
	local _, setDay = UI.Bar(hud, UI.px(238, 102), UI.px(150, 4), 0, T.accent2)
	self.setDayProgress = setDay
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
		local sb = UI.New("Frame", { Parent = self.canvas, Name = "Sandbox", Position = UI.px(1430, 20), Size = UI.px(400, 112), BackgroundColor3 = Color3.fromRGB(60, 40, 10), BackgroundTransparency = 0.1, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.gold, 2, 0) })
		UI.Label(sb, "SANDBOX  |  developer mode", UI.px(16, 8), UI.px(370, 24), { textSize = 16, font = UI.FontBlack, color = T.gold })
		UI.Button(sb, "SKIP TO NEXT SHOW", UI.px(14, 42), UI.px(230, 56), { color = T.gold, textSize = 15 }, function()
			self:devSkip(true)
		end)
		UI.Button(sb, "+7 DAYS", UI.px(254, 42), UI.px(132, 56), { color = T.panel3, textSize = 15 }, function()
			self:devSkip(false)
		end)
		self.sandboxPanel = sb
	end
	self.placeEdges = function()
		local gap = self.sideGap or 0
		local top = self.safeY or 20
		hud.Position = UI.px(20 - gap, top)
		obj.Position = UI.px(20 - gap, top + 128)
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
	local money = st.sandbox and "UNLIMITED" or Util.money(st.money)
	self.moneyLbl.Text = money
	self.moneyLbl.TextColor3 = (st.money < 0) and T.bad or T.good
	local dateTxt = Util.date(st.day, Config.START_YEAR)
	self.dateLbl.Text = dateTxt
	local lvl, def, nextDef = GS.level(st)
	self.labelLbl.Text = st.labelName
	self.levelPill.Text = "LV " .. lvl .. "  |  " .. string.upper(def.name)
	if nextDef then
		local f = (st.stats.tickets - def.tickets) / math.max(1, nextDef.tickets - def.tickets)
		self.setLevelBar(math.clamp(f, 0, 1))
		self.levelLbl.Text = Util.number(st.stats.tickets) .. " / " .. Util.number(nextDef.tickets) .. " tickets"
	else
		self.setLevelBar(1)
		self.levelLbl.Text = "max level"
	end
	local o = GS.objective(st)
	self.objectiveLbl.Text = "<font color='#2dd4bf'>NEXT  ></font>  " .. o.text
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
	for _, list in ipairs({ self.speedBtns or {}, self.barSpeedBtns or {} }) do
		for i, b in ipairs(list) do
			b.BackgroundColor3 = (i == (self.speed or 2)) and T.accent2 or T.panel3
			b.TextColor3 = (i == (self.speed or 2)) and Color3.new(1, 1, 1) or T.text
		end
	end
	self.hud.Visible = walking or self.mode == "phone"
	if self.homeButton then
		self.homeButton.Visible = walking or self.mode == "phone"
	end
	self.objectiveFrame.Visible = false
	self.phoneButton.Visible = walking
	if not self.meetingHint then
		self.meetingHint = UI.Label(self.canvas, "MEETING  |  click SIGN on the board  |  press SPACE to stand up", UI.px(0, 1020), UI.px(1920, 40), { textSize = 22, font = UI.FontBold, alignX = Enum.TextXAlignment.Center })
		self.meetingHint.TextStrokeTransparency = 0.4
	end
	self.meetingHint.Visible = self.mode == "meeting"
	if self.sandboxPanel then
		self.sandboxPanel.Visible = walking
	end
end

------------------------------------------------------------------ station screens (opened at a place in the building)
local TITLES = {
	office = "LAPTOP",
	tours = "LAPTOP",
	tourplan = "LAPTOP",
	planner = "WORLD MAP  |  PLAN A TOUR",
	artists = "MEETING ROOM",
	stages = "STAGE HALL",
	charts = "CHARTS",
	social = "SOCIAL",
}

function App:buildScreenBar()
	local bar = UI.New("Frame", { Parent = self.canvas, Name = "ScreenBar", Size = UI.px(1920, 64), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false })
	-- the white bar reaches the screen edges; the title starts right of Roblox's own buttons
	local bg = UI.New("Frame", { Parent = bar, Name = "Bg", Size = UI.px(1920, 64), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 0 })
	local line = UI.New("Frame", { Parent = bar, Position = UI.px(0, 63), Size = UI.px(1920, 2), BackgroundColor3 = T.accent, BorderSizePixel = 0, ZIndex = 0 })
	self.screenBar = bar
	self.barTitle = UI.Label(bar, "", UI.px(24, 0), UI.px(520, 64), { textSize = 24, font = UI.FontBlack, color = T.accent })
	local function edges()
		local gap = self.sideGap or 0
		bg.Position = UI.px(-gap, -(self.topGap or 0))
		bg.Size = UI.px(1920 + gap * 2, 64 + (self.topGap or 0))
		line.Position = UI.px(-gap, 63)
		line.Size = UI.px(1920 + gap * 2, 2)
		self.barTitle.Position = UI.px(math.max(24, self.safeX or 24), 0)
	end
	edges()
	local prev = self.placeEdges
	self.placeEdges = function()
		if prev then
			prev()
		end
		edges()
	end
	self.barTabs = {}
	self.barMoney = UI.Label(bar, "", UI.px(1200, 4), UI.px(250, 32), { textSize = 26, font = UI.FontBlack, color = T.good, alignX = Enum.TextXAlignment.Right })
	self.barDate = UI.Label(bar, "", UI.px(1200, 34), UI.px(250, 24), { textSize = 16, color = T.sub, alignX = Enum.TextXAlignment.Right })
	self.barSpeedBtns = {}
	for i, sp in ipairs(Config.SPEEDS) do
		local b = UI.Button(bar, sp.label, UI.px(1460 + (i - 1) * 45, 12), UI.px(41, 40), { textSize = 14 }, function()
			self:setSpeed(i)
		end)
		table.insert(self.barSpeedBtns, b)
	end
	UI.Button(bar, "CLOSE", UI.px(1650, 10), UI.px(250, 44), { color = T.panel3, textSize = 18 }, function()
		self:closeScreen()
	end)
end

-- which pages a station shows; any other page is a different place in the building
local STATION_PAGES = {
	maptable = { planner = true },
	stagehall = { stages = true },
	charts = { charts = true },
}
local PAGE_STATION = { stages = "stagehall", charts = "charts" }
-- pages that are apps on the laptop
local LAPTOP_APP = { office = true, tours = "tours", tourplan = "planner", planner = "planner", artists = "artists", stats = "stats" }
local STATION_NAME = { laptop = "LAPTOP", maptable = "WORLD MAP table", meeting = "MEETING ROOM (sit down)", stagehall = "STAGE HALL", charts = "CHARTS screen" }

function App:openStation(station, page, args)
	self.station = station
	self:showPage(page, args)
end

-- a page of another station: walk there (the arrow shows the way); laptop pages open as apps
function App:go(name, args)
	if name == "social" then
		if self.mode == "laptop" then
			self:openLaptop("social")
			return
		end
		self:closeScreen()
		self:openPhone()
		return
	end
	if LAPTOP_APP[name] and not (name == "planner" and self.station == "maptable") then
		local appId = (LAPTOP_APP[name] == true) and nil or LAPTOP_APP[name]
		if self.mode == "laptop" or self.mode == "menu" or self.mode == "world" then
			if self.mode == "menu" then
				self:closeScreen()
			end
			self:openLaptop(appId, args)
			return
		end
	end
	local here = self.station and STATION_PAGES[self.station]
	if here and here[name] then
		self:showPage(name, args)
		return
	end
	local target = PAGE_STATION[name]
	-- a tour plan starts with the artist in the meeting room
	if name == "planner" and not (self.state.draft or {}).artistId then
		target = "meeting"
	end
	if self.mode == "menu" then
		self:closeScreen()
	end
	if target and self.world then
		self.world.guide(target)
		self:toast("Go to the <b>" .. STATION_NAME[target] .. "</b>.", T.accent2)
	end
end

-- opens a page (full screen, the character waits in the building)
function App:showPage(name, args)
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

	for key, scr in pairs(self.screens) do
		-- pages inside laptop windows stay as they are
		if scr.frame.Parent == self.content or key == name then
			if key ~= name and scr.hide and scr.frame.Visible then
				scr:hide()
			end
			scr.frame.Visible = key == name
		end
	end
	local scr = self.screens[name]
	self.returnScreen = name
	scr.frame.Parent = self.content
	scr.frame.Position = UI.px(0, 0)
	scr:show(args)
	self:refreshHud()
end

------------------------------------------------------------------ the laptop (a little computer, see Laptop.lua)
function App:openLaptop(appId, args)
	local Laptop = require(Root.Client.Laptop)
	if self.mode == "world" and self.world then
		self.world.freeze(true)
	end
	if self.mode == "phone" then
		self.phone:hide()
	end
	self.mode = "laptop"
	self.station = "laptop"
	Laptop.open(self, appId, args)
	self:refreshHud()
end

function App:closeLaptop()
	local Laptop = require(Root.Client.Laptop)
	Laptop.close(self)
	self.station = nil
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

-- back to walking around in the building
function App:closeScreen()
	for _, scr in pairs(self.screens) do
		if scr.frame.Visible and scr.frame.Parent == self.content then
			if scr.hide then
				scr:hide()
			end
			scr.frame.Visible = false
		end
	end
	self.current = nil
	self.station = nil
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

-- the phone: SOCIAL on a smartphone, over the building (the character waits)
function App:openPhone()
	if self.mode ~= "world" or self.modalOpen then
		return
	end
	self.seenPosts = #(self.state.social or {})
	self.mode = "phone"
	if self.world then
		self.world.freeze(true)
	end
	self.phone:show()
	self:refreshHud()
end

function App:closePhone()
	if self.mode ~= "phone" then
		return
	end
	self.phone:hide()
	self.mode = "world"
	if self.world then
		self.world.freeze(false)
		self.world.refresh()
	end
	self:refreshHud()
	self:processLiveQueue()
end

function App:refreshCurrent()
	local scr = self.current and self.screens[self.current]
	if scr and scr.frame.Visible then
		scr:refresh()
	end
	if self.mode == "phone" then
		self.phone:refresh()
	end
	if self.world and self.mode == "world" then
		self.world.refresh()
	end
	if self.mode == "laptop" then
		require(Root.Client.Laptop).refresh(self)
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
		Position = (self:fullRect()),
		Size = select(2, self:fullRect()),
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

function App:confirm(title, body, onYes, yesText)
	self:modal(title, body, { { "Cancel", T.panel3 }, { yesText or "Yes", T.bad, onYes } }, 560)
end

function App:showWelcome()
	self:modal("Welcome to " .. UI.esc(self.state.labelName) .. "!", table.concat({
		"This is your label building. Walk around with <b>W A S D</b>, press <b>E</b> at a station.",
		"",
		"<b>WORLD MAP table</b>   plan a tour: country, venue, date, ticket price.",
		"<b>LAPTOP</b>   your shows, ticket sales and news.",
		"<b>MEETING ROOM</b>   sit down to meet your artists and new talent.",
		"<b>Time</b> runs by itself (II pauses, 1x / 2x / 4x speed). On the opening night you travel to the venue.",
		"",
		"Follow the glowing arrow. Start small: clubs first!",
	}, "\n"), { { "Let's go!", T.accent } }, 760)
end

------------------------------------------------------------------ time: runs by itself (pause / 1x / 2x / 4x)
function App:setSpeed(i)
	self.speed = i
	self:refreshHud()
end

-- time stands still in shows, the stage builder, popups and while a show of today waits
function App:timeRuns()
	local m = self.mode
	return (m == "world" or m == "menu" or m == "phone" or m == "meeting" or m == "laptop") and not self.modalOpen and not self.homeOpen and #self.liveQueue == 0 and not self.dayBusy
end

------------------------------------------------------------------ home button: save, settings, back to the main menu
local function houseIcon(parent, color)
	-- a little house: roof (a turned square), walls, a door
	local icon = UI.New("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UI.px(28, 26), BackgroundTransparency = 1 })
	UI.New("Frame", { Parent = icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UI.px(14, 9), Size = UI.px(19, 19), Rotation = 45, BackgroundColor3 = color, BorderSizePixel = 0, UI.Corner(2) })
	UI.New("Frame", { Parent = icon, Position = UI.px(4, 10), Size = UI.px(20, 15), BackgroundColor3 = color, BorderSizePixel = 0, UI.Corner(2) })
	UI.New("Frame", { Parent = icon, Position = UI.px(11, 16), Size = UI.px(6, 9), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	return icon
end

function App:buildHomeButton()
	-- the house sits at the right end of the HUD (money, date, speed)
	UI.New("Frame", { Parent = self.hud, Position = UI.px(594, 14), Size = UI.px(2, 90), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	local b = UI.Button(self.hud, "", UI.px(606, 24), UI.px(56, 56), { color = T.panel3, radius = 14 }, function()
		self:openHome()
	end)
	b.Name = "HomeButton"
	UI.Stroke(T.stroke, 1, 0).Parent = b
	houseIcon(b, T.text)
	UI.Label(self.hud, "MENU", UI.px(600, 82), UI.px(68, 20), { textSize = 12, font = UI.FontBold, color = T.sub, alignX = Enum.TextXAlignment.Center })
	self.homeButton = b
end

function App:openHome(page)
	if self.homeLayer then
		self.homeLayer:Destroy()
	end
	self.homeOpen = true
	-- one holder: a grey veil over the whole screen (incl. the edges of wide screens), the menu on the
	-- left on top of it, and a click on the veil right of the menu closes it
	local fullPos, fullSize = self:fullRect()
	local gap, vgap = self.sideGap or 0, self.topGap or 0
	local layer = UI.New("Frame", { Parent = self.canvas, Name = "HomeMenu", Size = fullSize, Position = fullPos, BackgroundTransparency = 1, ZIndex = 90 })
	self.homeLayer = layer
	UI.New("Frame", { Parent = layer, Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 90 })
	local catcher = UI.New("TextButton", { Parent = layer, Name = "CloseArea", Position = UI.px(gap + 440, 0), Size = UDim2.new(1, -(gap + 440), 1, 0), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 90 })
	local panel = UI.New("Frame", { Parent = layer, Name = "Panel", Position = UI.px(0, 0), Size = UDim2.new(0, gap + 440, 1, 0), BackgroundColor3 = T.panel, BorderSizePixel = 0, Active = true, ZIndex = 91 })
	-- (the content starts below Roblox's own buttons in the top left corner)
	panel = UI.New("Frame", { Parent = panel, Position = UI.px(gap, vgap + math.max(0, (self.safeY or 20) - 20)), Size = UI.px(440, 1000), BackgroundTransparency = 1, ZIndex = 91 })
	local function close()
		self.homeOpen = false
		if self.homeLayer then
			self.homeLayer:Destroy()
			self.homeLayer = nil
		end
	end
	catcher.MouseButton1Click:Connect(close)
	local function z(inst)
		inst.ZIndex = 92
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 93
			end
		end
		return inst
	end
	z(UI.Label(panel, self.state and self.state.labelName or "HEADLINER", UI.px(36, 40), UI.px(380, 40), { textSize = 30, font = UI.FontBlack }))
	z(UI.Label(panel, "Save slot " .. tostring(self.slot or 1) .. (self.state and self.state.sandbox and "  (sandbox)" or ""), UI.px(36, 82), UI.px(380, 22), { textSize = 16, color = T.sub }))
	local y = 140
	local function item(text, color, fn)
		local b = z(UI.Button(panel, text, UI.px(36, y), UI.px(368, 60), { color = color or T.panel3, textSize = 20 }, fn))
		b.TextXAlignment = Enum.TextXAlignment.Left
		UI.Padding(22, 10, 0, 0).Parent = b
		y = y + 72
		return b
	end
	if page == "settings" then
		z(UI.Label(panel, "SETTINGS", UI.px(36, y), UI.px(368, 30), { textSize = 22, font = UI.FontBlack }))
		y = y + 44
		local st = self.settings
		local function row(label, key)
			z(UI.Label(panel, label, UI.px(36, y), UI.px(200, 40), { textSize = 17, font = UI.FontBold }))
			z(UI.Button(panel, "-", UI.px(236, y), UI.px(44, 40), { textSize = 20 }, function()
				st[key] = math.max(0, st[key] - 10)
				SoundFX.setVolumes(st.music, st.effects)
				self:openHome("settings")
			end))
			z(UI.Label(panel, tostring(st[key]), UI.px(284, y), UI.px(72, 40), { textSize = 18, font = UI.FontBold, alignX = Enum.TextXAlignment.Center }))
			z(UI.Button(panel, "+", UI.px(360, y), UI.px(44, 40), { textSize = 20 }, function()
				st[key] = math.min(100, st[key] + 10)
				SoundFX.setVolumes(st.music, st.effects)
				self:openHome("settings")
			end))
			y = y + 52
		end
		row("Music", "music")
		row("Effects", "effects")
		z(UI.Label(panel, "Crowd detail in shows", UI.px(36, y), UI.px(368, 30), { textSize = 17, font = UI.FontBold }))
		y = y + 34
		for i, lvl in ipairs({ "Low", "Medium", "High" }) do
			z(UI.Button(panel, lvl, UI.px(36 + (i - 1) * 124, y), UI.px(116, 44), { color = (st.crowd == lvl) and T.accent or T.panel3, textSize = 16 }, function()
				st.crowd = lvl
				require(Root.Client.Venue).setDetail(lvl)
				self:openHome("settings")
			end))
		end
		y = y + 70
		item("< Back", nil, function()
			self:openHome()
		end)
		return
	end
	item("Resume", T.accent, close)
	item("Save game", nil, function()
		local res = self:call("save")
		self:toast(res.msg or (res.ok and "Saved." or "Could not save."), res.ok and T.good or T.warn)
		close()
	end)
	item("Settings", nil, function()
		self:openHome("settings")
	end)
	item("Back to main menu", nil, function()
		-- the menu closes first, so the question is on top and nothing grey covers it
		close()
		self:confirm("Back to the main menu?", "Your game is saved first.", function()
			self:leaveToMenu()
		end)
	end)
end

-- saves, removes the world and the game screens and shows the title screen again
function App:leaveToMenu()
	local res = self:call("leave")
	local info = res.data
	if type(info) == "string" then
		local ok, dec = pcall(function()
			return game:GetService("HttpService"):JSONDecode(info)
		end)
		info = ok and dec or {}
	end
	if self.clockConn then
		self.clockConn:Disconnect()
		self.clockConn = nil
	end
	self.clockRunning = false
	if self.world then
		self.world.stop()
	end
	require(Root.Client.Laptop).destroy(self)
	require(Root.Client.Tutorial).stop()
	for _, c in ipairs(self.canvas:GetChildren()) do
		if not (self.baseChildren or {})[c] and not c:IsA("UIScale") then
			c:Destroy()
		end
	end
	self.screens = {}
	self.current = nil
	self.state = nil
	self.liveQueue = {}
	self.mode = "title"
	self.homeOpen = false
	self.modalOpen = false
	local MainMenu = require(Root.Client.MainMenu)
	MainMenu.show(self, info or {}, function(isNew)
		self:beginGame(isNew)
	end)
end

function App:startClock()
	if self.clockRunning then
		return
	end
	self.clockRunning = true
	self.speed = self.speed or 2
	local acc = 0
	self.clockConn = RunService.Heartbeat:Connect(function(dt)
		local secs = Config.SPEEDS[self.speed or 2].seconds
		if secs <= 0 or not self.state or not self:timeRuns() then
			return
		end
		acc = acc + dt
		if self.setDayProgress then
			self.setDayProgress(math.clamp(acc / secs, 0, 1))
		end
		if acc >= secs then
			acc = 0
			self.dayBusy = true
			task.spawn(function()
				self:nextDay()
				self.dayBusy = false
			end)
		end
	end)
end

function App:nextDay()
	if self.modalOpen or #self.liveQueue > 0 or (self.mode ~= "world" and self.mode ~= "menu" and self.mode ~= "phone" and self.mode ~= "meeting") then
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

-- show day: "TODAY: Lila Moon in Paris, Le Petit Neon", then you travel to the venue
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
	if self.mode == "menu" then
		self:closeScreen()
	end
	self:showTonight(tour, item.idx)
end

function App:showTonight(tour, idx)
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	local col = UI.rgb(ad.color)
	self.modalOpen = true
	if self.world then
		self.world.freeze(true)
	end
	SoundFX.sfx("cheer", 0.4)
	local layer = UI.New("TextButton", { Parent = self.canvas, Name = "Tonight", Size = UI.px(1920, 1080), BackgroundColor3 = Color3.fromRGB(10, 8, 20), BackgroundTransparency = 0.15, AutoButtonColor = false, Text = "", ZIndex = 80 })
	local box = UI.New("Frame", { Parent = layer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UI.px(1000, 520), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 81, UI.Corner(24), UI.Stroke(col, 3, 0) })
	UI.New("Frame", { Parent = box, Size = UI.px(1000, 14), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 82, UI.Corner(24) })
	local function z(inst)
		inst.ZIndex = 83
		return inst
	end
	z(UI.Pill(box, "TODAY  |  SHOW DAY", UI.px(380, 44), UI.px(240, 34), T.bad, 16))
	z(UI.Label(box, ad.name, UI.px(0, 92), UI.px(1000, 90), { textSize = 76, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center }))
	z(UI.Label(box, "live in " .. v.city .. ",  " .. v.name, UI.px(0, 184), UI.px(1000, 44), { textSize = 32, font = UI.FontBold, color = col, alignX = Enum.TextXAlignment.Center }))
	local f = math.min(1, s.sold / math.max(1, s.cap))
	z(UI.Label(box, Util.number(math.min(s.sold, s.cap)) .. " / " .. Util.number(s.cap) .. " tickets sold" .. (f >= 1 and "  |  SOLD OUT" or ""), UI.px(0, 240), UI.px(1000, 34), { textSize = 22, color = (f >= 1) and T.gold or T.sub, alignX = Enum.TextXAlignment.Center }))
	local count = z(UI.Label(box, "", UI.px(0, 296), UI.px(1000, 30), { textSize = 18, color = T.sub, alignX = Enum.TextXAlignment.Center }))
	local gone = false
	local function close()
		if gone then
			return false
		end
		gone = true
		layer:Destroy()
		self.modalOpen = false
		return true
	end
	local go = z(UI.Button(box, "GO TO THE SHOW", UI.px(300, 350), UI.px(400, 76), { color = T.accent, textSize = 26 }, function()
		if close() then
			self:resolveShow(tour, idx, true)
		end
	end))
	for _, d in ipairs(go:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 84
		end
	end
	local skip = z(UI.Button(box, "Skip show", UI.px(420, 444), UI.px(160, 40), { color = T.panel3, textSize = 15 }, function()
		if close() then
			self:resolveShow(tour, idx, false)
		end
	end))
	for _, d in ipairs(skip:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 84
		end
	end
	-- the bus leaves by itself after a few seconds
	task.spawn(function()
		for k = 8, 1, -1 do
			if gone then
				return
			end
			count.Text = "The tour bus leaves in " .. k .. "..."
			task.wait(1)
		end
		if close() then
			self:resolveShow(tour, idx, true)
		end
	end)
end

-- the server decides and books the result first; then you watch the show in the venue (or skip it)
function App:resolveShow(tour, idx, watch)
	local ok, msg, data = self:act("playShow", { tourId = tour.id, idx = idx })
	if not ok or not data then
		self:toast(msg or "The show could not start.", T.bad)
		if self.world then
			self.world.freeze(self.mode ~= "world")
		end
		self:processLiveQueue()
		return
	end
	tour = GS.getTour(self.state, tour.id) or tour
	local result = data.result
	local function afterReport()
		for _, id in ipairs(data.achievements or {}) do
			self:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name, T.accent, 8)
		end
		if data.completed then
			self:tourCompleted(tour)
		end
		self:refreshCurrent()
		self:processLiveQueue()
	end
	if not watch then
		self:showResult(tour, idx, result, function()
			if self.world and self.mode == "world" then
				self.world.freeze(false)
			end
			afterReport()
		end)
		return
	end
	local LiveShow = require(Root.Client.LiveShow)
	local s = tour.shows[idx]
	local closeLoading = self:showLoading(string.upper(Artists.byId[tour.artistId].name), "Tonight: " .. Countries.venueById[s.venueId].name .. ", " .. Countries.venueById[s.venueId].city)
	self.inShow = true
	LiveShow.run(self, {
		artistId = tour.artistId,
		design = GS.showDesign(self.state, tour, idx),
		venueId = s.venueId,
		sold = result.sold,
		tourName = tour.name,
		result = result,
		walk = true,
		-- the show is over: the result while you are still in the venue, then back to the office
		onFinish = function(leave)
			self:showResult(tour, idx, result, function()
				local closeBack = self:showLoading("HEADLINER", "Back to the office")
				leave()
				task.delay(1, closeBack)
			end)
		end,
		onDone = function()
			self.inShow = false
			self:closeScreen()
			afterReport()
		end,
	})
	task.delay(1.2, closeLoading)
end

-- the result of a show: tiles with the numbers, the stars and what the press says
function App:showResult(tour, idx, r, onClose)
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	SoundFX.sfx(r.net >= 0 and "cash" or "error", 0.7)
	self.modalOpen = true
	local layer = UI.New("TextButton", { Parent = self.canvas, Name = "ShowReport", Size = UI.px(1920, 1080), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, AutoButtonColor = false, Text = "", ZIndex = 85 })
	local box = UI.New("Frame", { Parent = layer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UI.px(1100, 640), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 86, UI.Corner(20), UI.Stroke(r.soldOut and T.gold or T.accent, 3, 0) })
	local function lbl(text, pos, size, opts)
		local l = UI.Label(box, text, pos, size, opts)
		l.ZIndex = 87
		return l
	end
	lbl("SHOW REPORT", UI.px(40, 26), UI.px(500, 30), { textSize = 18, font = UI.FontBlack, color = T.accent2 })
	lbl(ad.name .. "  @  " .. v.name .. ", " .. v.city, UI.px(40, 56), UI.px(1020, 46), { textSize = 34, font = UI.FontBlack })
	lbl(Util.stars(r.stars) .. "   " .. math.floor(r.rating + 0.5) .. " / 100", UI.px(40, 106), UI.px(600, 44), { textSize = 34, color = T.gold, font = UI.FontBlack })
	lbl(tostring(r.review), UI.px(40, 152), UI.px(1020, 50), { textSize = 19, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	local fill = (r.cap > 0) and r.sold / r.cap or 0
	local tiles = {
		{ "TICKETS SOLD", Util.number(r.sold) .. " / " .. Util.number(r.cap), T.text },
		{ "VENUE FULL", math.floor(fill * 100 + 0.5) .. "%" .. (r.soldOut and "  SOLD OUT" or ""), r.soldOut and T.gold or (fill > 0.7 and T.good or T.warn) },
		{ "TICKET MONEY", Util.money(r.gross), T.text },
		{ "LABEL PROFIT", (r.net >= 0 and "+" or "") .. Util.money(r.net), r.net >= 0 and T.good or T.bad },
		{ "NEW FANS", "+" .. Util.number(r.fansGained), T.accent2 },
		{ "COSTS", Util.money(r.rent + r.production + r.travel + r.artistCut), T.bad },
	}
	for i, tl in ipairs(tiles) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local tile = UI.New("Frame", { Parent = box, Position = UI.px(40 + col * 346, 216 + row * 134), Size = UI.px(330, 120), BackgroundColor3 = T.panel2, BorderSizePixel = 0, ZIndex = 87, UI.Corner(14) })
		local a = UI.Label(tile, tl[1], UI.px(20, 14), UI.px(300, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
		local b = UI.Label(tile, tl[2], UI.px(20, 44), UI.px(300, 56), { textSize = 30, font = UI.FontBlack, color = tl[3] })
		a.ZIndex, b.ZIndex = 88, 88
	end
	lbl("Costs: venue " .. Util.moneyShort(r.rent) .. "  |  production " .. Util.moneyShort(r.production) .. "  |  travel " .. Util.moneyShort(r.travel) .. "  |  artist share " .. Util.moneyShort(r.artistCut), UI.px(40, 494), UI.px(1020, 26), { textSize = 16, color = T.sub })
	local btn = UI.Button(box, "Continue", UI.px(800, 548), UI.px(260, 64), { color = T.accent, textSize = 22 }, function()
		layer:Destroy()
		self.modalOpen = false
		if onClose then
			onClose()
		end
	end)
	btn.ZIndex = 88
	for _, d in ipairs(btn:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 89
		end
	end
end

return App
