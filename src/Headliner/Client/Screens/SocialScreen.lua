-- SOCIAL: what fans post about your artists. Good shows get love, bad shows and high prices get criticism.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local Social = require(Root.Logic.Social)
local UI = require(Root.Client.UI)

local T = UI.Theme
local BLACK = Color3.new(0, 0, 0)
local SocialScreen = {}
SocialScreen.__index = SocialScreen

local AVATARS = {
	Color3.fromRGB(255, 105, 180), Color3.fromRGB(45, 212, 191), Color3.fromRGB(108, 99, 255), Color3.fromRGB(255, 193, 7),
	Color3.fromRGB(255, 120, 60), Color3.fromRGB(46, 204, 113), Color3.fromRGB(0, 180, 255), Color3.fromRGB(200, 120, 255),
}
local MOOD_COLOR = { [1] = T.good, [0] = T.sub, [-1] = T.bad }

function SocialScreen.new(app)
	local self = setmetatable({ app = app, filter = "all" }, SocialScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Social" })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	return self
end

function SocialScreen:show()
	self:refresh()
end

local function ago(state, day)
	local d = state.day - day
	if d <= 0 then
		return "today"
	elseif d == 1 then
		return "yesterday"
	end
	return d .. "d ago"
end

-- a little "photo": stage, lights and a crowd in the artist's colour
local function photo(parent, color, seed)
	local f = UI.New("Frame", { Parent = parent, Size = UI.px(560, 200), BackgroundColor3 = Color3.fromRGB(10, 10, 20), BorderSizePixel = 0, ClipsDescendants = true, UI.Corner(10) })
	UI.New("UIGradient", { Parent = f, Color = ColorSequence.new(color, Color3.fromRGB(10, 10, 24)), Rotation = 90 })
	for i = 0, 5 do
		local beam = UI.New("Frame", { Parent = f, AnchorPoint = Vector2.new(0.5, 0), Position = UI.px(60 + i * 88, -20), Size = UI.px(14, 260), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, Rotation = ((i + seed) % 2 == 0) and 18 or -18 })
		local _ = beam
	end
	UI.New("Frame", { Parent = f, Position = UI.px(150, 110), Size = UI.px(260, 24), BackgroundColor3 = Color3.fromRGB(30, 30, 40), BorderSizePixel = 0 })
	UI.New("Frame", { Parent = f, Position = UI.px(270, 78), Size = UI.px(16, 34), BackgroundColor3 = BLACK, BorderSizePixel = 0, UI.Corner(6) })
	for i = 0, 34 do
		local x = (i * 37 + seed * 13) % 560
		local h = 20 + (i * 7 + seed) % 16
		UI.New("Frame", { Parent = f, Position = UI.px(x, 200 - h), Size = UI.px(18, h + 4), BackgroundColor3 = BLACK, BorderSizePixel = 0, UI.Corner(9) })
		if i % 4 == 0 then
			UI.New("Frame", { Parent = f, Position = UI.px(x + 6, 200 - h - 16), Size = UI.px(6, 10), BackgroundColor3 = Color3.fromRGB(255, 255, 220), BorderSizePixel = 0 })
		end
	end
	return f
end

function SocialScreen:post(list, p, order)
	local state = self.app.state
	local ad = Artists.byId[p.artistId or ""]
	local card = UI.New("Frame", { Parent = list, Size = UI.px(640, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, UI.Corner(12), UI.Padding(16, 16, 14, 14), UI.List(true, 8) })
	local head = UI.New("Frame", { Parent = card, Size = UI.px(608, 46), BackgroundTransparency = 1, LayoutOrder = 1 })
	local av = UI.New("TextLabel", { Parent = head, Size = UI.px(44, 44), BackgroundColor3 = AVATARS[p.avatar or 1], Text = p.name:sub(1, 1), TextColor3 = BLACK, TextSize = 22, Font = UI.FontBlack, UI.Corner(22) })
	local _ = av
	UI.Label(head, p.name, UI.px(56, 0), UI.px(300, 24), { textSize = 18, font = UI.FontBold })
	UI.Label(head, p.handle .. "  ·  " .. ago(state, p.day), UI.px(56, 24), UI.px(400, 20), { textSize = 14, color = T.sub })
	if ad then
		local tag = UI.Pill(head, ad.name, UI.px(458, 10), UI.px(150, 24), UI.rgb(ad.color), 12)
		tag.TextColor3 = BLACK
	end
	UI.New("TextLabel", {
		Parent = card,
		Size = UI.px(608, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = UI.esc(p.text),
		RichText = true,
		TextWrapped = true,
		TextSize = 19,
		TextColor3 = T.text,
		Font = UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	if p.photo then
		photo(card, ad and UI.rgb(ad.color) or T.accent, (p.likes or 1) % 7).LayoutOrder = 3
	end
	local foot = UI.New("Frame", { Parent = card, Size = UI.px(608, 22), BackgroundTransparency = 1, LayoutOrder = 4 })
	UI.Label(foot, "♥ " .. Util.short(p.likes or 0) .. "      ⟲ " .. Util.short(p.reposts or 0), UI.px(0, 0), UI.px(300, 22), { textSize = 15, color = T.sub })
	local moodTxt = (p.mood > 0) and "positive" or ((p.mood < 0) and "critical" or "neutral")
	UI.Label(foot, moodTxt, UI.px(408, 0), UI.px(200, 22), { textSize = 14, font = UI.FontBold, color = MOOD_COLOR[p.mood] or T.sub, alignX = Enum.TextXAlignment.Right })
end

function SocialScreen:refresh()
	local state = self.app.state
	local body = self.body
	UI.ClearChildren(body)

	-- left: filter + fan mood per artist
	local left = UI.Panel(body, UI.px(40, 20), UI.px(400, 970))
	UI.Label(left, "FAN MOOD", UI.px(20, 16), UI.px(360, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Label(left, "How fans feel about your artists right now.", UI.px(20, 48), UI.px(360, 22), { textSize = 14, color = T.sub })
	local y = 84
	local allBtn = UI.Button(left, "All posts", UI.px(20, y), UI.px(360, 44), { color = self.filter == "all" and T.accent or T.panel3, textSize = 17 }, function()
		self.filter = "all"
		self:refresh()
	end)
	local _ = allBtn
	y = y + 56
	for _, ad in ipairs(GS.signedArtists(state)) do
		local mood, n = Social.mood(state, ad.id)
		local b = UI.Button(left, "", UI.px(20, y), UI.px(360, 76), { color = self.filter == ad.id and UI.shade(T.accent, 0.6) or T.panel2 }, function()
			self.filter = ad.id
			self:refresh()
		end)
		UI.New("Frame", { Parent = b, Position = UI.px(0, 0), Size = UI.px(8, 76), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(b, ad.name, UI.px(20, 6), UI.px(220, 28), { textSize = 19, font = UI.FontBold })
		local label = (n == 0) and "no posts yet" or ((mood >= 40) and "fans love it" or ((mood >= 0) and "mixed feelings" or "fans are upset"))
		local col = (n == 0) and T.sub or ((mood >= 40) and T.good or ((mood >= 0) and T.warn or T.bad))
		UI.Label(b, label, UI.px(20, 40), UI.px(220, 24), { textSize = 15, color = col, font = UI.FontBold })
		UI.Bar(b, UI.px(240, 46), UI.px(100, 10), (mood + 100) / 200, col)
		UI.Label(b, n > 0 and ((mood > 0 and "+" or "") .. mood) or "", UI.px(240, 12), UI.px(100, 26), { textSize = 18, font = UI.FontBlack, color = col, alignX = Enum.TextXAlignment.Right })
		y = y + 86
	end

	-- center: the feed
	local list = UI.Scroll(body, UI.px(470, 20), UI.px(680, 970))
	UI.List(true, 12).Parent = list
	local n = 0
	for _, p in ipairs(state.social or {}) do
		if self.filter == "all" or p.artistId == self.filter then
			n = n + 1
			if n <= 60 then
				self:post(list, p, n)
			end
		end
	end
	if n == 0 then
		UI.Label(list, "Nothing here yet. Announce a tour and fans will start talking!", nil, UI.px(640, 60), { textSize = 18, color = T.sub, wrap = true })
	end

	-- right: trending + tips
	local right = UI.Panel(body, UI.px(1180, 20), UI.px(700, 470))
	UI.Label(right, "TRENDING", UI.px(24, 16), UI.px(400, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	local tr = Social.trending(state)
	if #tr == 0 then
		UI.Label(right, "No hashtags yet.", UI.px(24, 60), UI.px(600, 24), { textSize = 16, color = T.sub })
	end
	for i = 1, math.min(8, #tr) do
		UI.Label(right, i .. ".  " .. tr[i][1], UI.px(24, 30 + i * 46), UI.px(460, 36), { textSize = 22, font = UI.FontBold })
		UI.Label(right, Util.short(tr[i][2]) .. " likes", UI.px(480, 30 + i * 46), UI.px(196, 36), { textSize = 16, color = T.sub, alignX = Enum.TextXAlignment.Right })
	end
	local tips = UI.Panel(body, UI.px(1180, 510), UI.px(700, 480))
	UI.Label(tips, "WHAT FANS TALK ABOUT", UI.px(24, 16), UI.px(600, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Label(tips, table.concat({
		"•  Great shows get photos, love and fan projects.",
		"•  Weak shows and bare stages get criticism.",
		"•  Very high ticket prices make fans angry.",
		"•  Fans notice special stage moments: lifts, pyro, the LED cube, balloons...",
		"•  Empty venues: fans worry when tickets don't sell.",
		"•  Cancelled tours hurt the mood a lot.",
	}, "\n"), UI.px(24, 60), UI.px(650, 400), { textSize = 18, wrap = true, alignY = Enum.TextYAlignment.Top, color = T.text })
	local _c = Config
end

return SocialScreen
