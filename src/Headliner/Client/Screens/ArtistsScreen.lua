-- ARTISTS screen: your roster and the talent scout.
local Root = script:FindFirstAncestor("Headliner")
local Achievements = require(Root.Data.Achievements)
local Config = require(Root.Config)
local Regions = require(Root.Data.Regions)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)

local T = UI.Theme
local ArtistsScreen = {}
ArtistsScreen.__index = ArtistsScreen

function ArtistsScreen.new(app)
	local self = setmetatable({ app = app, tab = "roster" }, ArtistsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Artists" })
	self.rosterBtn = UI.Button(self.frame, "YOUR ROSTER", UI.px(20, 12), UI.px(220, 44), {}, function()
		self.tab = "roster"
		self:refresh()
	end)
	self.scoutBtn = UI.Button(self.frame, "TALENT SCOUT", UI.px(250, 12), UI.px(220, 44), {}, function()
		self.tab = "scout"
		self:refresh()
	end)
	self.info = UI.Label(self.frame, "", UI.px(490, 12), UI.px(1400, 44), { textSize = 16, color = T.sub })
	self.grid = UI.Scroll(self.frame, UI.px(20, 68), UI.px(1880, 930))
	UI.New("UIGridLayout", { Parent = self.grid, CellSize = UI.px(452, 420), CellPadding = UI.px(12, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	return self
end

function ArtistsScreen:show()
	self:refresh()
end

function ArtistsScreen:card(ad, order)
	local app, state = self.app, self.app.state
	local a = state.artists[ad.id]
	local total = Util.totalFans(a.fans)
	local card = UI.New("Frame", { Parent = self.grid, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, UI.Corner(12), UI.Stroke(T.stroke, 1, 0.3) })
	local head = UI.New("Frame", { Parent = card, Size = UI.px(452, 86), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0, UI.Corner(12) })
	UI.New("UIGradient", { Parent = head, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(70, 70, 90)), Rotation = 0 })
	local lum = 0.299 * ad.color[1] + 0.587 * ad.color[2] + 0.114 * ad.color[3]
	local nameColor = lum > 150 and Color3.fromRGB(16, 16, 26) or Color3.new(1, 1, 1)
	UI.Label(head, ad.name, UI.px(18, 8), UI.px(416, 40), { textSize = 30, font = UI.FontBlack, color = nameColor })
	local members = ad.members > 1 and (ad.members .. "-piece") or "Solo"
	UI.Label(head, ad.genre .. "  |  " .. members .. "  |  " .. Util.tier(total), UI.px(18, 50), UI.px(416, 24), { textSize = 17, font = UI.FontBold, color = Color3.fromRGB(20, 20, 30) })

	UI.Label(card, ad.bio, UI.px(18, 94), UI.px(416, 40), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	local function stat(y, label, frac, txt, col)
		UI.Label(card, label, UI.px(18, y), UI.px(90, 20), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Bar(card, UI.px(110, y + 6), UI.px(220, 8), frac, col)
		UI.Label(card, txt, UI.px(340, y), UI.px(94, 20), { textSize = 14, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	end
	stat(138, "SKILL", ad.skill / 100, tostring(ad.skill), T.accent2)
	stat(162, "HYPE", a.hype / 100, tostring(math.floor(a.hype)), T.accent)
	stat(186, "FANS", math.min(1, math.log10(1 + total / 10000) / 4), Util.short(total), T.good)
	-- regions
	local maxFans = 1
	for _, n in pairs(a.fans) do
		maxFans = math.max(maxFans, n)
	end
	for i, r in ipairs(Regions.list) do
		local y = 214 + (i - 1) * 22
		UI.Label(card, r.name, UI.px(18, y), UI.px(150, 20), { textSize = 13, color = T.sub })
		UI.Bar(card, UI.px(170, y + 7), UI.px(180, 6), (a.fans[r.id] or 0) / maxFans, UI.rgb(ad.color))
		UI.Label(card, Util.short(a.fans[r.id] or 0), UI.px(354, y), UI.px(80, 20), { textSize = 13, alignX = Enum.TextXAlignment.Right })
	end
	local priceTxt = "Fair ticket price ~" .. Util.money(Sim.fairPrice(state, ad.id, "uk")) .. " (UK)"
	UI.Label(card, priceTxt, UI.px(18, 348), UI.px(416, 20), { textSize = 13, color = T.sub })

	if a.signed then
		local tour = GS.activeTour(state, ad.id)
		if tour then
			UI.Button(card, "ON TOUR: " .. tour.name, UI.px(18, 370), UI.px(416, 40), { color = T.panel3, textSize = 15 }, function()
				app:go("tours", { tourId = tour.id })
			end)
		else
			UI.Button(card, "PLAN A TOUR", UI.px(18, 370), UI.px(416, 40), { color = T.accent }, function()
				app:go("planner", { artistId = ad.id })
			end)
		end
	else
		local lvl = GS.level(state)
		local afford = state.money >= ad.signCost and ad.level <= lvl
		local txt = ad.level > lvl and ("LOCKED - needs " .. Config.LEVELS[ad.level].name .. " (Lv " .. ad.level .. ")") or ("SIGN FOR " .. Util.money(ad.signCost))
		UI.Button(card, txt, UI.px(18, 370), UI.px(416, 40), { color = afford and T.good or T.panel3, disabled = not afford, textSize = 15 }, function()
			app:confirm("Sign " .. ad.name .. "?", "Signing costs <b>" .. Util.money(ad.signCost) .. "</b>. Then you can book their tours.", function()
				local ok, msg = GS.sign(state, ad.id)
				app:toast(msg, ok and T.good or T.bad)
				for _, id in ipairs(GS.checkAchievements(state)) do
					app:toast("<b>Achievement unlocked:</b> " .. Achievements.byId[id].name, T.accent, 8)
				end
				app:save()
				app:refreshCurrent()
			end)
		end)
	end
end

function ArtistsScreen:refresh()
	UI.ClearChildren(self.grid)
	local state = self.app.state
	self.rosterBtn.BackgroundColor3 = self.tab == "roster" and T.accent or T.panel3
	self.scoutBtn.BackgroundColor3 = self.tab == "scout" and T.accent or T.panel3
	local list
	if self.tab == "roster" then
		list = GS.signedArtists(state)
		self.info.Text = "Your signed artists. Bigger fanbases sell bigger venues. Good shows win new fans and hype."
	else
		list = GS.unsignedArtists(state)
		self.info.Text = "Unsigned artists you can sign. Bigger stars cost more but can fill arenas and stadiums."
		if #list == 0 then
			self.info.Text = "You signed everyone. What a label!"
		end
	end
	for i, ad in ipairs(list) do
		self:card(ad, i)
	end
end

return ArtistsScreen
