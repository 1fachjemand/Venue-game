-- The laptop in the office: a little computer of its own.
-- Power on -> start screen with the label name -> LOG IN -> desktop with apps.
-- Apps open in windows: move them (title bar), resize them (corner), full screen (double click or the
-- square button), minimise, close, several at once. The taskbar shows the open windows, the time and money.
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Util = require(Root.Logic.Util)
local UI = require(Root.Client.UI)
local SoundFX = require(Root.Client.SoundFX)

local T = UI.Theme
local New = UI.New
local Laptop = {}

local DW, DH = 1920, 1080
local BAR = 52 -- taskbar height
local TITLE = 42 -- window title bar
local CW, CH = 1920, 1008 -- design size of the app pages (scaled into the windows)
Laptop.skipBoot = false -- the tests skip the start-up animation

-- the apps on the desktop: screen = the page (app.screens[screen]) shown in the window
Laptop.APPS = {
	{ id = "planner", name = "Tour Planner", color = Color3.fromRGB(37, 99, 235), glyph = "pin", screen = "planner" },
	{ id = "tours", name = "My Tours", color = Color3.fromRGB(13, 148, 136), glyph = "ticket", screen = "tours" },
	{ id = "artists", name = "Our Artists", color = Color3.fromRGB(147, 51, 234), glyph = "person", screen = "artists" },
	{ id = "social", name = "Socials", color = Color3.fromRGB(219, 39, 119), glyph = "bubble", screen = "social" },
	{ id = "stats", name = "Statistics", color = Color3.fromRGB(234, 88, 12), glyph = "bars", screen = "stats" },
	{ id = "settings", name = "Settings", color = Color3.fromRGB(100, 116, 139), glyph = "gear", screen = nil },
}
local APP_BY_ID = {}
for _, a in ipairs(Laptop.APPS) do
	APP_BY_ID[a.id] = a
end

------------------------------------------------------------------ icons (drawn, no images)
local function glyph(parent, kind, size)
	local s = size / 64
	local w = Color3.new(1, 1, 1)
	local function f(x, y, ww, hh, r, rot)
		return New("Frame", { Parent = parent, Position = UI.px(x * s, y * s), Size = UI.px(ww * s, hh * s), BackgroundColor3 = w, BorderSizePixel = 0, Rotation = rot or 0, UI.Corner(math.floor((r or 0) * s)) })
	end
	if kind == "pin" then
		f(20, 12, 24, 24, 12)
		f(25, 24, 14, 14, 2, 45)
		New("Frame", { Parent = parent, Position = UI.px(27 * s, 19 * s), Size = UI.px(10 * s, 10 * s), BackgroundColor3 = parent.BackgroundColor3, BorderSizePixel = 0, UI.Corner(math.floor(5 * s)) })
		f(14, 46, 36, 4, 2)
	elseif kind == "ticket" then
		f(12, 20, 40, 24, 4)
		New("Frame", { Parent = parent, Position = UI.px(34 * s, 22 * s), Size = UI.px(2 * s, 20 * s), BackgroundColor3 = parent.BackgroundColor3, BorderSizePixel = 0 })
	elseif kind == "person" then
		f(24, 12, 16, 16, 8)
		f(16, 32, 32, 20, 10)
	elseif kind == "bubble" then
		f(12, 14, 40, 28, 10)
		f(20, 36, 10, 10, 2, 45)
	elseif kind == "bars" then
		f(14, 34, 8, 16, 2)
		f(28, 24, 8, 26, 2)
		f(42, 14, 8, 36, 2)
	elseif kind == "gear" then
		for k = 0, 3 do
			f(28, 10, 8, 44, 2, k * 45)
		end
		f(18, 18, 28, 28, 14)
		New("Frame", { Parent = parent, Position = UI.px(26 * s, 26 * s), Size = UI.px(12 * s, 12 * s), BackgroundColor3 = parent.BackgroundColor3, BorderSizePixel = 0, UI.Corner(math.floor(6 * s)) })
	end
end
local function appTile(parent, app, size, pos)
	local tile = New("Frame", { Parent = parent, Position = pos or UI.px(0, 0), Size = UI.px(size, size), BackgroundColor3 = app.color, BorderSizePixel = 0, UI.Corner(math.floor(size * 0.22)) })
	glyph(tile, app.glyph, size)
	return tile
end
Laptop.appTile = appTile

------------------------------------------------------------------ helpers
local function L(app)
	app.laptop = app.laptop or { power = "off", windows = {}, icons = {}, z = 0 }
	return app.laptop
end

-- the mouse in desktop pixels
local function mouseDesk(app)
	local m = UserInputService:GetMouseLocation()
	local lt = L(app)
	local a = lt.desk.AbsolutePosition
	local sc = (app.uiScale and app.uiScale.Scale) or 1
	-- the UI ignores the top bar inset, so mouse and AbsolutePosition use the same origin
	return (m.X - a.X) / sc, (m.Y - a.Y) / sc
end

------------------------------------------------------------------ build the computer
local function build(app)
	local lt = L(app)
	if lt.root then
		return lt
	end
	local gap = app.sideGap or 0
	local root = New("Frame", { Parent = app.canvas, Name = "Laptop", Position = UI.px(-gap, 0), Size = UI.px(DW + gap * 2, DH), BackgroundColor3 = Color3.fromRGB(214, 228, 244), BorderSizePixel = 0, Visible = false, ZIndex = 45 })
	New("UIGradient", { Parent = root, Color = ColorSequence.new(Color3.fromRGB(196, 220, 245), Color3.fromRGB(240, 244, 250)), Rotation = 90 })
	lt.root = root
	local desk = New("Frame", { Parent = root, Position = UI.px(gap, 0), Size = UI.px(DW, DH - BAR), BackgroundTransparency = 1 })
	lt.desk = desk
	-- the label's name on the wallpaper
	UI.Label(desk, string.upper(app.state.labelName), UI.px(0, 400), UI.px(DW, 80), { textSize = 64, font = UI.FontBlack, color = Color3.fromRGB(170, 190, 214), alignX = Enum.TextXAlignment.Center })
	UI.Label(desk, "STARLIGHT OS", UI.px(0, 478), UI.px(DW, 30), { textSize = 20, font = UI.FontBold, color = Color3.fromRGB(170, 190, 214), alignX = Enum.TextXAlignment.Center })
	lt.iconLayer = New("Frame", { Parent = desk, Size = UI.px(DW, DH - BAR), BackgroundTransparency = 1 })
	lt.winLayer = New("Frame", { Parent = desk, Size = UI.px(DW, DH - BAR), BackgroundTransparency = 1 })
	-- taskbar
	local bar = New("Frame", { Parent = root, Position = UI.px(0, DH - BAR), Size = UI.px(DW + gap * 2, BAR), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	New("Frame", { Parent = bar, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	local inner = New("Frame", { Parent = bar, Position = UI.px(gap, 0), Size = UI.px(DW, BAR), BackgroundTransparency = 1 })
	lt.bar = inner
	local start = UI.Button(inner, "", UI.px(8, 6), UI.px(124, 40), { color = T.panel, radius = 8 }, function()
		Laptop.toggleStart(app)
	end)
	start.Name = "StartButton"
	local logo = New("Frame", { Parent = start, Position = UI.px(10, 8), Size = UI.px(24, 24), BackgroundColor3 = T.accent, BorderSizePixel = 0, UI.Corner(6) })
	UI.Label(logo, "S", UI.px(0, 0), UI.px(24, 24), { textSize = 16, font = UI.FontBlack, color = Color3.new(1, 1, 1), alignX = Enum.TextXAlignment.Center })
	UI.Label(start, "Start", UI.px(42, 0), UI.px(80, 40), { textSize = 17, font = UI.FontBold })
	lt.tasks = New("Frame", { Parent = inner, Position = UI.px(146, 6), Size = UI.px(1200, 40), BackgroundTransparency = 1 })
	UI.List(false, 6).Parent = lt.tasks
	lt.clock = UI.Label(inner, "", UI.px(1380, 4), UI.px(280, 22), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	lt.money = UI.Label(inner, "", UI.px(1380, 26), UI.px(280, 22), { textSize = 14, color = T.good, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	local closeBtn = UI.Button(inner, "Close laptop", UI.px(1676, 6), UI.px(236, 40), { color = T.panel3, textSize = 16 }, function()
		app:closeLaptop()
	end)
	closeBtn.Name = "CloseLaptop"
	-- start menu
	local menu = New("Frame", { Parent = root, Position = UI.px(gap + 8, DH - BAR - 236), Size = UI.px(300, 228), BackgroundColor3 = T.panel, BorderSizePixel = 0, Visible = false, ZIndex = 10, UI.Corner(12), UI.Stroke(T.stroke, 1, 0) })
	lt.menu = menu
	UI.Label(menu, app.state.labelName, UI.px(18, 12), UI.px(264, 26), { textSize = 18, font = UI.FontBlack }).ZIndex = 11
	local my = 50
	for _, it in ipairs({ { "Settings", function()
		Laptop.openApp(app, "settings")
	end }, { "Close laptop", function()
		app:closeLaptop()
	end }, { "Shut down", function()
		Laptop.shutdown(app)
	end } }) do
		local b = UI.Button(menu, it[1], UI.px(10, my), UI.px(280, 50), { color = T.panel, textSize = 17 }, function()
			menu.Visible = false
			it[2]()
		end)
		b.ZIndex = 11
		b.TextXAlignment = Enum.TextXAlignment.Left
		UI.Padding(16, 8, 0, 0).Parent = b
		my = my + 56
	end
	-- boot / login screen on top of everything
	lt.screen = New("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(16, 18, 24), BorderSizePixel = 0, Visible = false, ZIndex = 20 })
	Laptop.buildIcons(app)
	-- drag icons and windows
	lt.conns = {
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement and lt.drag then
				Laptop.onDrag(app)
			end
		end),
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and lt.drag then
				Laptop.endDrag(app)
			end
		end),
	}
	return lt
end

------------------------------------------------------------------ desktop icons
function Laptop.buildIcons(app)
	local lt = L(app)
	UI.ClearChildren(lt.iconLayer)
	for i, a in ipairs(Laptop.APPS) do
		local pos = lt.icons[a.id] or { 28, 24 + (i - 1) * 132 }
		lt.icons[a.id] = pos
		local b = New("TextButton", { Parent = lt.iconLayer, Name = "Icon_" .. a.id, Position = UI.px(pos[1], pos[2]), Size = UI.px(116, 122), BackgroundColor3 = T.accent, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", UI.Corner(10) })
		appTile(b, a, 68, UI.px(24, 8))
		UI.Label(b, a.name, UI.px(0, 82), UI.px(116, 36), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Center, wrap = true, color = Color3.fromRGB(30, 40, 60) })
		b.MouseEnter:Connect(function()
			b.BackgroundTransparency = 0.8
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 1
		end)
		b.MouseButton1Down:Connect(function()
			local mx, my = mouseDesk(app)
			lt.drag = { kind = "icon", id = a.id, btn = b, mx = mx, my = my, x = lt.icons[a.id][1], y = lt.icons[a.id][2], moved = false }
		end)
		b.MouseButton1Click:Connect(function()
			-- a double click opens the app (a drag does not)
			if lt.wasDrag then
				lt.wasDrag = false
				return
			end
			local now = os.clock()
			if lt.lastClick == a.id and now - (lt.lastClickT or 0) < 0.45 then
				lt.lastClick = nil
				Laptop.openApp(app, a.id)
			else
				lt.lastClick, lt.lastClickT = a.id, now
			end
		end)
	end
end

function Laptop.onDrag(app)
	local lt = L(app)
	local d = lt.drag
	local mx, my = mouseDesk(app)
	local dx, dy = mx - d.mx, my - d.my
	if not d.moved and math.abs(dx) + math.abs(dy) < 6 then
		return
	end
	d.moved = true
	if d.kind == "icon" then
		d.btn.Position = UI.px(d.x + dx, d.y + dy)
	elseif d.kind == "move" then
		local w = d.win
		w.rect.x = math.clamp(d.x + dx, -w.rect.w + 120, DW - 120)
		w.rect.y = math.clamp(d.y + dy, 0, DH - BAR - TITLE)
		Laptop.layout(app, w)
	elseif d.kind == "size" then
		local w = d.win
		w.rect.w = math.clamp(d.w + dx, 640, DW - w.rect.x)
		w.rect.h = math.clamp(d.h + dy, 420, DH - BAR - w.rect.y)
		Laptop.layout(app, w)
	end
end

function Laptop.endDrag(app)
	local lt = L(app)
	local d = lt.drag
	lt.drag = nil
	if d.kind == "icon" and d.moved then
		-- icons snap to a grid
		local p = d.btn.Position
		local gx = math.clamp(math.floor((p.X.Offset - 28) / 130 + 0.5), 0, 13) * 130 + 28
		local gy = math.clamp(math.floor((p.Y.Offset - 24) / 132 + 0.5), 0, 6) * 132 + 24
		lt.icons[d.id] = { gx, gy }
		d.btn.Position = UI.px(gx, gy)
		lt.wasDrag = true
	end
end

------------------------------------------------------------------ windows
function Laptop.layout(app, w)
	local r = w.rect
	local x, y, ww, hh = r.x, r.y, r.w, r.h
	if w.max then
		x, y, ww, hh = 0, 0, DW, DH - BAR
	end
	w.frame.Position = UI.px(x, y)
	w.frame.Size = UI.px(ww, hh)
	local cw, ch = ww - 2, hh - TITLE - 1
	w.content.Size = UI.px(cw, ch)
	local sc = math.min(cw / CW, ch / CH)
	w.scale.Scale = sc
	w.frame.Visible = not w.min
end

function Laptop.focus(app, w)
	local lt = L(app)
	-- the last child is drawn on top
	w.frame.Parent = nil
	w.frame.Parent = lt.winLayer
	lt.active = w
	Laptop.refreshTasks(app)
end

function Laptop.openApp(app, id, args)
	local lt = L(app)
	local def = APP_BY_ID[id]
	if not def then
		return
	end
	if lt.menu then
		lt.menu.Visible = false
	end
	-- already open: bring it to the front
	for _, w in ipairs(lt.windows) do
		if w.id == id then
			w.min = false
			Laptop.layout(app, w)
			Laptop.focus(app, w)
			if w.screen then
				w.screen.frame.Parent = w.holder
				w.screen.frame.Position = UI.px(0, 0)
				w.screen.frame.Visible = true
				w.screen:show(args)
			end
			return w
		end
	end
	local n = #lt.windows
	local w = { id = id, def = def, rect = { x = 80 + n * 40, y = 30 + n * 34, w = 1500, h = 860 }, max = true }
	local f = New("Frame", { Parent = lt.winLayer, Name = "Window_" .. id, BackgroundColor3 = T.panel, BorderSizePixel = 0, UI.Corner(10), UI.Stroke(Color3.fromRGB(160, 170, 186), 1, 0) })
	w.frame = f
	-- title bar: drag to move, double click = full screen
	local title = New("TextButton", { Parent = f, Name = "TitleBar", Size = UDim2.new(1, 0, 0, TITLE), BackgroundColor3 = T.panel2, AutoButtonColor = false, Text = "", BorderSizePixel = 0, UI.Corner(10) })
	New("Frame", { Parent = f, Position = UI.px(0, TITLE - 10), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = T.panel2, BorderSizePixel = 0 })
	appTile(title, def, 26, UI.px(10, 8))
	UI.Label(title, def.name, UI.px(46, 0), UI.px(600, TITLE), { textSize = 17, font = UI.FontBold })
	title.MouseButton1Down:Connect(function()
		Laptop.focus(app, w)
		local now = os.clock()
		if w.lastTitle and now - w.lastTitle < 0.4 then
			w.max = not w.max
			Laptop.layout(app, w)
			w.lastTitle = nil
			return
		end
		w.lastTitle = now
		if not w.max then
			local mx, my = mouseDesk(app)
			lt.drag = { kind = "move", win = w, mx = mx, my = my, x = w.rect.x, y = w.rect.y }
		end
	end)
	local function tb(text, x, color, fn)
		local b = UI.Button(title, text, UDim2.new(1, x, 0, 4), UI.px(46, 34), { color = T.panel2, textSize = 16, radius = 6 }, fn)
		if color then
			b.MouseEnter:Connect(function()
				b.BackgroundColor3 = color
				b.TextColor3 = Color3.new(1, 1, 1)
			end)
			b.MouseLeave:Connect(function()
				b.BackgroundColor3 = T.panel2
				b.TextColor3 = T.text
			end)
		end
		return b
	end
	tb("_", -150, nil, function()
		w.min = true
		Laptop.layout(app, w)
		Laptop.refreshTasks(app)
	end).Name = "Minimize"
	tb("[ ]", -100, nil, function()
		w.max = not w.max
		Laptop.layout(app, w)
	end).Name = "Maximize"
	tb("X", -50, T.bad, function()
		Laptop.closeWindow(app, w)
	end).Name = "CloseWindow"
	-- the page, scaled to the window
	local content = New("Frame", { Parent = f, Position = UI.px(1, TITLE), BackgroundColor3 = T.bg, BorderSizePixel = 0, ClipsDescendants = true })
	w.content = content
	local holder = New("Frame", { Parent = content, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UI.px(CW, CH), BackgroundTransparency = 1 })
	w.scale = New("UIScale", { Parent = holder })
	w.holder = holder
	-- resize corner
	local grip = New("TextButton", { Parent = f, Name = "Resize", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UI.px(22, 22), BackgroundTransparency = 1, Text = "", ZIndex = 5 })
	for k = 0, 2 do
		New("Frame", { Parent = grip, Position = UI.px(6 + k * 5, 16 - k * 5), Size = UI.px(12 - k * 5, 2), BackgroundColor3 = T.sub, BorderSizePixel = 0, ZIndex = 5 })
	end
	grip.MouseButton1Down:Connect(function()
		Laptop.focus(app, w)
		if w.max then
			return
		end
		local mx, my = mouseDesk(app)
		lt.drag = { kind = "size", win = w, mx = mx, my = my, w = w.rect.w, h = w.rect.h }
	end)
	if def.screen then
		local scr = app.screens[def.screen]
		w.screen = scr
		scr.frame.Parent = holder
		scr.frame.Position = UI.px(0, 0)
		scr.frame.Visible = true
		scr:show(args)
	else
		Laptop.buildSettings(app, holder)
	end
	table.insert(lt.windows, w)
	Laptop.layout(app, w)
	Laptop.focus(app, w)
	SoundFX.sfx("click", 0.4)
	return w
end

function Laptop.closeWindow(app, w)
	local lt = L(app)
	for i, o in ipairs(lt.windows) do
		if o == w then
			table.remove(lt.windows, i)
			break
		end
	end
	if w.screen then
		if w.screen.hide then
			w.screen:hide()
		end
		w.screen.frame.Visible = false
		w.screen.frame.Parent = app.content
	end
	w.frame:Destroy()
	if lt.active == w then
		lt.active = lt.windows[#lt.windows]
	end
	Laptop.refreshTasks(app)
end

function Laptop.refreshTasks(app)
	local lt = L(app)
	UI.ClearChildren(lt.tasks)
	for i, w in ipairs(lt.windows) do
		local on = lt.active == w and not w.min
		local b = UI.Button(lt.tasks, "", nil, UI.px(200, 40), { order = i, color = on and Color3.fromRGB(219, 234, 254) or T.panel2, radius = 8 }, function()
			if lt.active == w and not w.min then
				w.min = true
				Laptop.layout(app, w)
				Laptop.refreshTasks(app)
			else
				w.min = false
				Laptop.layout(app, w)
				Laptop.focus(app, w)
			end
		end)
		b.Name = "Task_" .. w.id
		appTile(b, w.def, 24, UI.px(8, 8))
		UI.Label(b, w.def.name, UI.px(40, 0), UI.px(154, 40), { textSize = 15, font = UI.FontBold })
	end
end

function Laptop.toggleStart(app)
	local lt = L(app)
	lt.menu.Visible = not lt.menu.Visible
end

------------------------------------------------------------------ settings app
function Laptop.buildSettings(app, holder)
	UI.ClearChildren(holder)
	local p = New("Frame", { Parent = holder, Size = UI.px(CW, CH), BackgroundColor3 = T.bg, BorderSizePixel = 0 })
	UI.Label(p, "Settings", UI.px(60, 40), UI.px(800, 50), { textSize = 38, font = UI.FontBlack })
	local s = app.settings
	local y = 130
	local function row(label, key)
		UI.Label(p, label, UI.px(60, y), UI.px(300, 50), { textSize = 22, font = UI.FontBold })
		UI.Button(p, "-", UI.px(380, y), UI.px(60, 50), { textSize = 24 }, function()
			s[key] = math.max(0, s[key] - 10)
			SoundFX.setVolumes(s.music, s.effects)
			Laptop.buildSettings(app, holder)
		end)
		UI.Bar(p, UI.px(456, y + 20), UI.px(300, 10), s[key] / 100, T.accent)
		UI.Label(p, tostring(s[key]), UI.px(770, y), UI.px(80, 50), { textSize = 22, font = UI.FontBold })
		UI.Button(p, "+", UI.px(860, y), UI.px(60, 50), { textSize = 24 }, function()
			s[key] = math.min(100, s[key] + 10)
			SoundFX.setVolumes(s.music, s.effects)
			Laptop.buildSettings(app, holder)
		end)
		y = y + 76
	end
	row("Music", "music")
	row("Effects", "effects")
	UI.Label(p, "Crowd detail in shows", UI.px(60, y), UI.px(400, 50), { textSize = 22, font = UI.FontBold })
	for i, lvl in ipairs({ "Low", "Medium", "High" }) do
		UI.Button(p, lvl, UI.px(460 + (i - 1) * 160, y), UI.px(150, 50), { color = (s.crowd == lvl) and T.accent or T.panel3, textSize = 20 }, function()
			s.crowd = lvl
			require(Root.Client.Venue).setDetail(lvl)
			Laptop.buildSettings(app, holder)
		end)
	end
end

------------------------------------------------------------------ power: boot, login, desktop
local function showDesktop(app)
	local lt = L(app)
	lt.power = "on"
	lt.screen.Visible = false
	UI.ClearChildren(lt.screen)
	if lt.afterBoot then
		local fn = lt.afterBoot
		lt.afterBoot = nil
		fn()
	end
end

local function loginScreen(app)
	local lt = L(app)
	local sc = lt.screen
	UI.ClearChildren(sc)
	sc.BackgroundColor3 = Color3.fromRGB(30, 58, 110)
	sc.Visible = true
	local gap = app.sideGap or 0
	local box = New("Frame", { Parent = sc, Position = UI.px(gap, 0), Size = UI.px(DW, DH), BackgroundTransparency = 1, ZIndex = 21 })
	local _, dateShort = Util.date(app.state.day, Config.START_YEAR)
	UI.Label(box, dateShort, UI.px(0, 150), UI.px(DW, 60), { textSize = 50, font = UI.FontBlack, color = Color3.new(1, 1, 1), alignX = Enum.TextXAlignment.Center }).ZIndex = 22
	local avatar = New("Frame", { Parent = box, Position = UI.px(DW / 2 - 70, 380), Size = UI.px(140, 140), BackgroundColor3 = Color3.fromRGB(226, 232, 240), BorderSizePixel = 0, ZIndex = 22, UI.Corner(70) })
	UI.Label(avatar, string.upper(app.state.labelName:sub(1, 1)), UI.px(0, 0), UI.px(140, 140), { textSize = 64, font = UI.FontBlack, color = Color3.fromRGB(30, 58, 110), alignX = Enum.TextXAlignment.Center }).ZIndex = 23
	UI.Label(box, app.state.labelName, UI.px(0, 540), UI.px(DW, 50), { textSize = 34, font = UI.FontBlack, color = Color3.new(1, 1, 1), alignX = Enum.TextXAlignment.Center }).ZIndex = 22
	local b = UI.Button(box, "LOG IN", UI.px(DW / 2 - 140, 620), UI.px(280, 60), { color = Color3.new(1, 1, 1), textSize = 22, radius = 30 }, function()
		SoundFX.sfx("click", 0.5)
		showDesktop(app)
	end)
	b.Name = "LoginButton"
	b.ZIndex = 22
end

local function bootScreen(app)
	local lt = L(app)
	local sc = lt.screen
	UI.ClearChildren(sc)
	sc.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
	sc.Visible = true
	local gap = app.sideGap or 0
	local box = New("Frame", { Parent = sc, Position = UI.px(gap, 0), Size = UI.px(DW, DH), BackgroundTransparency = 1, ZIndex = 21 })
	local logo = New("Frame", { Parent = box, Position = UI.px(DW / 2 - 50, 400), Size = UI.px(100, 100), BackgroundColor3 = T.accent, BorderSizePixel = 0, ZIndex = 22, UI.Corner(24) })
	UI.Label(logo, "S", UI.px(0, 0), UI.px(100, 100), { textSize = 60, font = UI.FontBlack, color = Color3.new(1, 1, 1), alignX = Enum.TextXAlignment.Center }).ZIndex = 23
	UI.Label(box, "STARLIGHT OS", UI.px(0, 520), UI.px(DW, 40), { textSize = 26, font = UI.FontBold, color = Color3.fromRGB(200, 210, 230), alignX = Enum.TextXAlignment.Center }).ZIndex = 22
	local barBg = New("Frame", { Parent = box, Position = UI.px(DW / 2 - 150, 600), Size = UI.px(300, 6), BackgroundColor3 = Color3.fromRGB(50, 56, 70), BorderSizePixel = 0, ZIndex = 22, UI.Corner(3) })
	local fill = New("Frame", { Parent = barBg, Size = UI.px(0, 6), BackgroundColor3 = T.accent, BorderSizePixel = 0, ZIndex = 23, UI.Corner(3) })
	UI.Tween(fill, 1.2, { Size = UI.px(300, 6) })
	task.delay(1.3, function()
		if lt.root and lt.root.Visible and lt.power == "booting" then
			loginScreen(app)
		end
	end)
end

-- open the laptop (switches it on if it is off). then = open this app afterwards
function Laptop.open(app, appId, args)
	local lt = build(app)
	lt.root.Visible = true
	lt.menu.Visible = false
	Laptop.refreshClock(app)
	local function after()
		if appId then
			Laptop.openApp(app, appId, args)
		end
	end
	if lt.power == "on" then
		after()
		return
	end
	lt.afterBoot = after
	if Laptop.skipBoot then
		showDesktop(app)
		return
	end
	lt.power = "booting"
	bootScreen(app)
end

function Laptop.close(app)
	local lt = L(app)
	if lt.root then
		lt.root.Visible = false
		lt.drag = nil
	end
end

function Laptop.isOpen(app)
	local lt = app.laptop
	return lt ~= nil and lt.root ~= nil and lt.root.Visible
end

function Laptop.shutdown(app)
	local lt = L(app)
	for i = #lt.windows, 1, -1 do
		Laptop.closeWindow(app, lt.windows[i])
	end
	lt.power = "off"
	app:closeLaptop()
end

function Laptop.refreshClock(app)
	local lt = app.laptop
	if not lt or not lt.clock or not app.state then
		return
	end
	local _, dateShort = Util.date(app.state.day, Config.START_YEAR)
	lt.clock.Text = dateShort
	lt.money.Text = Util.money(app.state.money)
end

-- the open windows show the current state again
function Laptop.refresh(app)
	local lt = app.laptop
	if not lt or not lt.root or not lt.root.Visible then
		return
	end
	for _, w in ipairs(lt.windows) do
		if w.screen and not w.min then
			w.screen:refresh()
		end
	end
	Laptop.refreshClock(app)
end

-- removes the computer (back to the main menu)
function Laptop.destroy(app)
	local lt = app.laptop
	if not lt then
		return
	end
	for _, c in ipairs(lt.conns or {}) do
		c:Disconnect()
	end
	if lt.root then
		lt.root:Destroy()
	end
	app.laptop = nil
end

return Laptop
