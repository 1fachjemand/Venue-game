-- SOCIAL: what fans post about your artists. Good shows get love, bad shows and high prices get criticism.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local Social = require(Root.Logic.Social)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)

local T = UI.Theme
local BLACK = Color3.new(0, 0, 0)
local SocialScreen = {}
SocialScreen.__index = SocialScreen

local AVATARS = {
	Color3.fromRGB(255, 105, 180), Color3.fromRGB(45, 212, 191), Color3.fromRGB(108, 99, 255), Color3.fromRGB(255, 193, 7),
	Color3.fromRGB(255, 120, 60), Color3.fromRGB(46, 204, 113), Color3.fromRGB(0, 180, 255), Color3.fromRGB(200, 120, 255),
}
local SHIRT_COLORS = { Color3.fromRGB(230, 230, 235), Color3.fromRGB(30, 30, 36), Color3.fromRGB(200, 40, 60), Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 200, 50) }
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

-- a concert photo as a small 3D scene: "stage" = view from the crowd, "selfie" = fans in front of the stage
local SKY = Color3.fromRGB(8, 8, 18)
local function mk(vp, size, cf, color, material, shape, tr)
	local p = UI.New("Part", { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = tr or 0, Anchored = true, Parent = vp })
	if shape then
		p.Shape = shape
	end
	return p
end
local function photo(parent, ad, seed, kind)
	local color = ad and UI.rgb(ad.color) or T.accent
	local vp = UI.New("ViewportFrame", {
		Parent = parent,
		Size = UI.px(608, 250),
		BackgroundColor3 = SKY,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(110, 100, 140),
		LightColor = color:Lerp(Color3.new(1, 1, 1), 0.5),
		LightDirection = Vector3.new(0.2, -0.6, 1),
		UI.Corner(10),
	})
	local rng = Random.new(seed)
	-- stage: deck, LED wall in the artist colour, light beams, haze
	mk(vp, Vector3.new(200, 1, 200), CFrame.new(0, -0.5, -20), Color3.fromRGB(12, 12, 18))
	mk(vp, Vector3.new(44, 5, 16), CFrame.new(0, 2.5, -30), Color3.fromRGB(26, 26, 32))
	mk(vp, Vector3.new(46, 22, 1), CFrame.new(0, 16, -38), color, Enum.Material.Neon, nil, 0.25)
	mk(vp, Vector3.new(14, 8, 0.5), CFrame.new(0, 16, -37.3), Color3.new(1, 1, 1), Enum.Material.Neon, nil, 0.6)
	for i = 0, 7 do
		local x = -21 + i * 6
		local c = (i % 2 == 0) and color or Color3.fromRGB(255, 240, 220)
		mk(vp, Vector3.new(0.8, 60, 0.8), CFrame.new(x, 30, -32) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.5, 0.5)), c, Enum.Material.Neon, nil, 0.75)
	end
	mk(vp, Vector3.new(80, 6, 30), CFrame.new(0, 3, -20), color, Enum.Material.Neon, nil, 0.93) -- haze
	if ad then
		local star = People.new(vp, color, 1.4, "lead", seed, ad.look)
		local moves = { "micout", "jump", "point", "wave", "dance" }
		star:update(Vector3.new(rng:NextNumber(-6, 6), 5, -30), 0, { t = rng:NextNumber() * 10, beat = 0.5, energy = 1, walking = false, armsUp = rng:NextNumber() < 0.4 and 1 or 0, move = moves[rng:NextInteger(1, #moves)] })
	end
	local cam = UI.New("Camera", { FieldOfView = 42, Parent = vp })
	vp.CurrentCamera = cam
	if kind == "selfie" then
		-- 2 to 4 fans close to the camera, arms around each other, phone glow
		local n = rng:NextInteger(2, 4)
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 2.6
			local fanColor = (rng:NextNumber() < 0.5) and color or SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
			local f = People.new(vp, fanColor, 1, "crowd", seed * 7 + i)
			f:update(Vector3.new(x, 0, 6 + rng:NextNumber() * 0.6), rng:NextNumber(-0.25, 0.25), { t = 1, beat = 0.2, energy = 0.2, walking = false, armsUp = (i == 1) and 1 or 0, move = (i == 1) and "wave" or "idle" })
		end
		-- the phone flash lights the faces
		vp.LightDirection = Vector3.new(0.1, -0.4, -1)
		vp.Ambient = Color3.fromRGB(150, 140, 170)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 5.6, 15), Vector3.new(0, 4.6, 0))
	else
		-- crowd between the camera and the stage with raised arms and phones
		for row = 0, 5 do
			for col = 0, 13 do
				local x = -26 + col * 4 + rng:NextNumber(-1, 1)
				local z = 4 - row * 3.4 + rng:NextNumber(-0.6, 0.6)
				local c = Color3.fromRGB(14, 14, 20):Lerp(color, rng:NextNumber() * 0.25)
				mk(vp, Vector3.new(1.6, 2.8, 1), CFrame.new(x, 1.4, z), c)
				mk(vp, Vector3.new(1.3, 1.3, 1.3), CFrame.new(x, 3.45, z), c, nil, Enum.PartType.Ball)
				local r = rng:NextNumber()
				if r < 0.3 then
					mk(vp, Vector3.new(0.45, 2.2, 0.45), CFrame.new(x + 0.9, 4.6, z) * CFrame.Angles(0, 0, -0.3), c)
					mk(vp, Vector3.new(0.5, 0.8, 0.12), CFrame.new(x + 1.3, 5.9, z), Color3.fromRGB(255, 255, 235), Enum.Material.Neon)
				elseif r < 0.45 then
					mk(vp, Vector3.new(0.3, 1.6, 0.3), CFrame.new(x - 0.8, 5.2, z) * CFrame.Angles(0, 0, 0.3), color, Enum.Material.Neon)
				end
			end
		end
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-8, 8), 6.5, 12), Vector3.new(0, 9, -30))
	end
	return vp
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
	if p.photo and self.photos < 14 then
		self.photos = self.photos + 1
		local seed = (p.likes or 1) + (p.avatar or 1) * 31
		photo(card, ad, seed, (seed % 2 == 0) and "selfie" or "stage").LayoutOrder = 3
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
	self.photos = 0
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
