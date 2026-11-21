-- The phone (SOCIAL): opens from the phone button at any time while walking around.
-- A smartphone on the right side of the screen with the fan feed, the fan mood and trending hashtags.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local Social = require(Root.Logic.Social)
local UI = require(Root.Client.UI)
local SocialScreen = require(Root.Client.Screens.SocialScreen)

local T = UI.Theme
local PhoneScreen = {}
PhoneScreen.__index = PhoneScreen

local W, H = 660, 1010
local SCALE = 0.95 -- the feed cards are made for 640 px

function PhoneScreen.new(app)
	local self = setmetatable({ app = app, tab = "feed" }, PhoneScreen)
	local frame = UI.New("Frame", { Parent = app.canvas, Name = "Phone", Position = UI.px(1230, 36), Size = UI.px(W, H), BackgroundColor3 = Color3.fromRGB(14, 14, 18), BorderSizePixel = 0, Visible = false, ZIndex = 30, UI.Corner(56), UI.Stroke(Color3.fromRGB(70, 70, 82), 4, 0) })
	self.frame = frame
	-- the screen
	local screen = UI.New("Frame", { Parent = frame, Position = UI.px(18, 18), Size = UI.px(W - 36, H - 36), BackgroundColor3 = T.bg, BorderSizePixel = 0, ClipsDescendants = true, UI.Corner(42) })
	self.screen = screen
	UI.New("Frame", { Parent = frame, Position = UI.px(W / 2 - 70, 26), Size = UI.px(140, 30), BackgroundColor3 = Color3.fromRGB(8, 8, 10), BorderSizePixel = 0, ZIndex = 40, UI.Corner(15) })
	self.status = UI.Label(screen, "", UI.px(36, 12), UI.px(200, 24), { textSize = 15, font = UI.FontBold })
	UI.Label(screen, "5G  |||  92%", UI.px(W - 236, 12), UI.px(170, 24), { textSize = 14, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	-- app header
	local head = UI.New("Frame", { Parent = screen, Position = UI.px(0, 50), Size = UI.px(W - 36, 70), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	UI.Label(head, "FanFeed", UI.px(22, 6), UI.px(300, 36), { textSize = 28, font = UI.FontBlack, color = T.accent2 })
	self.sub = UI.Label(head, "", UI.px(22, 40), UI.px(400, 22), { textSize = 14, color = T.sub })
	UI.Button(head, "X", UI.px(W - 36 - 64, 12), UI.px(46, 46), { textSize = 20, color = T.panel3 }, function()
		app:closePhone()
	end)
	-- tabs at the bottom
	self.tabs = {}
	local TABS = { { "feed", "FEED" }, { "mood", "FAN MOOD" }, { "trend", "TRENDING" } }
	local tw = math.floor((W - 36 - 40) / 3)
	for i, t in ipairs(TABS) do
		self.tabs[t[1]] = UI.Button(screen, t[2], UI.px(14 + (i - 1) * (tw + 6), H - 36 - 84), UI.px(tw, 54), { textSize = 15 }, function()
			self.tab = t[1]
			self:refresh()
		end)
	end
	UI.New("Frame", { Parent = screen, Position = UI.px((W - 36) / 2 - 70, H - 36 - 18), Size = UI.px(140, 6), BackgroundColor3 = Color3.fromRGB(120, 120, 130), BorderSizePixel = 0, UI.Corner(3) })
	self.body = UI.New("Frame", { Parent = screen, Position = UI.px(0, 126), Size = UI.px(W - 36, H - 36 - 126 - 96), BackgroundTransparency = 1, ClipsDescendants = true })
	return self
end

function PhoneScreen:show()
	self.frame.Visible = true
	self:refresh()
end

function PhoneScreen:hide()
	self.frame.Visible = false
end

function PhoneScreen:refresh()
	local app, state = self.app, self.app.state
	local _, dateShort = Util.date(state.day, Config.START_YEAR)
	self.status.Text = dateShort
	self.sub.Text = "Fans talk about " .. state.labelName
	for k, b in pairs(self.tabs) do
		b.BackgroundColor3 = (k == self.tab) and T.accent or T.panel3
	end
	local body = self.body
	UI.ClearChildren(body)
	local bw, bh = W - 36, body.Size.Y.Offset
	if self.tab == "feed" then
		-- the feed cards are 640 wide: a scaled holder makes them fit the phone
		local holder = UI.New("Frame", { Parent = body, Position = UI.px(8, 4), Size = UI.px((bw - 16) / SCALE, (bh - 8) / SCALE), BackgroundTransparency = 1 })
		UI.New("UIScale", { Parent = holder, Scale = SCALE })
		local list = UI.Scroll(holder, UI.px(0, 0), UI.px((bw - 16) / SCALE, (bh - 8) / SCALE))
		UI.List(true, 12).Parent = list
		local ctx = { app = app, photos = 6 }
		SocialScreen.realBudget = 6 -- the photos of the newest posts show the real stage of the tour
		local n = 0
		for _, p in ipairs(state.social or {}) do
			n = n + 1
			if n > 40 then
				break
			end
			ctx.photos = (n <= 6) and 0 or 99 -- photos only for the newest posts (they are small 3D scenes)
			SocialScreen.post(ctx, list, p, n)
		end
		if n == 0 then
			UI.Label(list, "Nothing here yet. Announce a tour and fans will start talking!", nil, UI.px(600, 80), { textSize = 22, color = T.sub, wrap = true })
		end
	elseif self.tab == "mood" then
		local list = UI.Scroll(body, UI.px(12, 8), UI.px(bw - 24, bh - 16))
		UI.List(true, 8).Parent = list
		for i, ad in ipairs(GS.signedArtists(state)) do
			local mood, n = Social.mood(state, ad.id)
			local row = UI.New("Frame", { Parent = list, Size = UI.px(bw - 44, 84), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(12) })
			UI.New("Frame", { Parent = row, Size = UI.px(8, 84), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
			UI.Label(row, ad.name, UI.px(22, 8), UI.px(300, 30), { textSize = 21, font = UI.FontBold })
			local label = (n == 0) and "no posts yet" or ((mood >= 40) and "fans love it" or ((mood >= 0) and "mixed feelings" or "fans are upset"))
			local col = (n == 0) and T.sub or ((mood >= 40) and T.good or ((mood >= 0) and T.warn or T.bad))
			UI.Label(row, label, UI.px(22, 44), UI.px(260, 26), { textSize = 16, color = col, font = UI.FontBold })
			UI.Bar(row, UI.px(290, 52), UI.px(180, 10), (mood + 100) / 200, col)
			UI.Label(row, n > 0 and ((mood > 0 and "+" or "") .. mood) or "", UI.px(290, 12), UI.px(180, 30), { textSize = 22, font = UI.FontBlack, color = col, alignX = Enum.TextXAlignment.Right })
		end
	else
		local tr = Social.trending(state)
		UI.Label(body, "TRENDING NOW", UI.px(22, 12), UI.px(400, 30), { textSize = 20, font = UI.FontBlack, color = T.accent })
		if #tr == 0 then
			UI.Label(body, "No hashtags yet.", UI.px(22, 56), UI.px(400, 26), { textSize = 17, color = T.sub })
		end
		for i = 1, math.min(10, #tr) do
			UI.Label(body, i .. ".  " .. tr[i][1], UI.px(22, 14 + i * 56), UI.px(360, 34), { textSize = 21, font = UI.FontBold })
			UI.Label(body, Util.short(tr[i][2]) .. " likes", UI.px(340, 14 + i * 56), UI.px(170, 34), { textSize = 15, color = T.sub, alignX = Enum.TextXAlignment.Right })
		end
	end
end

return PhoneScreen
