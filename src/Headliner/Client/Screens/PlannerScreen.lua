-- PLAN A TOUR: a 4-step wizard (artist -> route -> tickets & stage -> confirm).
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Regions = require(Root.Data.Regions)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)

local T = UI.Theme
local MapScreen = {}
MapScreen.__index = MapScreen
local STEPS = { "ARTIST", "ROUTE", "TICKETS & STAGE", "CONFIRM" }

local WorldMap3D = require(Root.Client.WorldMap3D)

-- name, latitude, longitude, camera distance
local VIEWS = {
	{ "World", 18, 0, 560 },
	{ "Europe", 50, 8, 115 },
	{ "N. America", 42, -95, 250 },
	{ "Latin America", -14, -70, 250 },
	{ "Asia / Pacific", 5, 135, 320 },
	{ "Africa / M. East", 2, 35, 260 },
}

local function heatColor(pool)
	if pool < 300 then
		return Color3.fromRGB(150, 70, 175)
	elseif pool < 1500 then
		return Color3.fromRGB(235, 70, 70)
	elseif pool < 6000 then
		return Color3.fromRGB(255, 150, 40)
	elseif pool < 20000 then
		return Color3.fromRGB(255, 225, 60)
	elseif pool < 60000 then
		return Color3.fromRGB(160, 235, 90)
	end
	return Color3.fromRGB(40, 220, 120)
end

function MapScreen.new(app)
	local self = setmetatable({ app = app, step = 1 }, MapScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Planner" })
	self.stepBar = UI.New("Frame", { Parent = self.frame, Position = UI.px(20, 8), Size = UI.px(1880, 52), BackgroundTransparency = 1 })
	self.draft = { artistId = nil, name = "", designs = {}, firstIn = 21, gap = 2, watchFirst = true, price = 30, shows = {} }
	-- step 2 (route) keeps its map alive between visits; the other steps are rebuilt
	self.routeView = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	self:buildMap()
	self:buildCountryPanel()
	self.routePanel = UI.Panel(self.routeView, UI.px(1468, 72), UI.px(432, 928))
	return self
end

------------------------------------------------------------------ map (3D world map table, see Client/WorldMap3D)
function MapScreen:buildMap()
	local view = UI.New("Frame", { Parent = self.routeView, Position = UI.px(20, 72), Size = UI.px(1432, 600), BackgroundTransparency = 1, Name = "MapView" })
	self.mapView = view
	local bar = UI.Panel(view, UI.px(0, 0), UI.px(1432, 48), T.panel)
	bar.BackgroundTransparency = 0.2
	self.mapBar = bar
	UI.Label(bar, "WORLD MAP", UI.px(16, 8), UI.px(170, 32), { textSize = 22, font = UI.FontBlack })
	local x = 190
	for _, v in ipairs(VIEWS) do
		local w = #v[1] * 10 + 34
		UI.Button(bar, v[1], UI.px(x, 9), UI.px(w, 30), { textSize = 14 }, function()
			WorldMap3D.flyTo(v[2], v[3], v[4])
		end)
		x = x + w + 8
	end
	UI.Label(bar, "Drag = move   Wheel = zoom", UI.px(1190, 8), UI.px(226, 32), { textSize = 13, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local legendBox = UI.Panel(view, UI.px(0, 562), UI.px(1432, 38), T.panel)
	legendBox.BackgroundTransparency = 0.2
	self.legendBox = legendBox
	self.legend = UI.Label(legendBox, "", UI.px(14, 0), UI.px(1404, 38), { textSize = 14, color = T.sub, rich = true })
	self.hoverBox = UI.New("TextLabel", {
		Parent = view,
		Position = UI.px(10, 60),
		Size = UI.px(480, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.panel,
		BackgroundTransparency = 0.1,
		Text = "",
		RichText = true,
		TextWrapped = true,
		TextColor3 = T.text,
		TextSize = 16,
		Font = UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		UI.Corner(8),
		UI.Padding(12, 12, 8, 8),
		UI.Stroke(T.gold, 1, 0.2),
	})
end

-- true if the mouse is over one of the planner's panels (then the 3D map ignores it)
function MapScreen:overUI()
	if self.app.modalOpen then
		return true
	end
	local m = UserInputService:GetMouseLocation()
	for _, p in ipairs({ self.mapBar, self.legendBox, self.routePanel, self.countryPanel, self.stepBar, self.app.hud, self.hoverBox }) do
		if p and p.Visible then
			local a, sz = p.AbsolutePosition, p.AbsoluteSize
			if m.X >= a.X and m.X <= a.X + sz.X and m.Y >= a.Y and m.Y <= a.Y + sz.Y then
				return true
			end
		end
	end
	return false
end

function MapScreen:activateMap()
	if self.app.mode ~= "menu" then
		return
	end
	self.app.backdrop.Visible = false
	WorldMap3D.activate({
		isOverUI = function()
			return self:overUI()
		end,
		onClick = function(cid)
			self.selected = cid
			self:refresh()
		end,
		onHover = function(cid)
			self:hoverCountry(cid)
		end,
		screenCenter = function()
			local a, sz = self.mapView.AbsolutePosition, self.mapView.AbsoluteSize
			return a.X + sz.X / 2, a.Y + sz.Y / 2
		end,
	})
end

function MapScreen:deactivateMap()
	WorldMap3D.deactivate()
	if self.app.mode == "menu" then
		self.app.backdrop.Visible = true
	end
end

function MapScreen:hide()
	self:deactivateMap()
end

function MapScreen:hoverCountry(cid)
	if not cid then
		self.hoverBox.Visible = false
		return
	end
	local c = Countries.byId[cid]
	local minC, maxC = math.huge, 0
	local types = {}
	for _, v in ipairs(c.venues) do
		minC, maxC = math.min(minC, v.cap), math.max(maxC, v.cap)
		types[v.type] = (types[v.type] or 0) + 1
	end
	local parts = {}
	for _, tname in ipairs({ "Club", "Theatre", "Hall", "Arena", "Amphitheatre", "Stadium" }) do
		if types[tname] then
			table.insert(parts, types[tname] .. " " .. string.lower(tname) .. (types[tname] > 1 and "s" or ""))
		end
	end
	local txt = "<b>" .. c.name .. "</b>   " .. #c.venues .. " venues (" .. Util.number(minC) .. " - " .. Util.number(maxC) .. " seats)\n" .. table.concat(parts, ", ")
	local aid = self.draft.artistId
	if aid then
		txt = txt .. "\nPromoter tip: " .. (Sim.recommendation(self.app.state, aid, cid))
	end
	self.hoverBox.Text = txt .. "\n<font color='#9696b2'>Click to see the venues</font>"
	self.hoverBox.Visible = true
end

------------------------------------------------------------------ helpers
local function rangeText(lo, hi)
	if lo >= 0.999 then
		return "very strong demand"
	end
	return Util.percent(lo) .. " - " .. Util.percent(hi)
end
local function rangeColor(lo, hi)
	local mid = (lo + hi) / 2
	if lo >= 0.999 then
		return T.gold
	elseif mid > 0.75 then
		return T.good
	elseif mid > 0.45 then
		return T.warn
	end
	return T.bad
end

function MapScreen:syncPrices()
	for _, s in ipairs(self.draft.shows) do
		s.price = self.draft.price
	end
end

local CLASS_ORDER = { "Club", "Theatre", "Arena", "Stadium" }
local CLASS_LABEL = { Club = "CLUB", Theatre = "THEATRE / HALL", Arena = "ARENA / AMPHITHEATRE", Stadium = "STADIUM" }

-- which venue sizes are on the route: { {class=, shows=n, names={...}} } (small to big)
function MapScreen:classesNeeded()
	local by = {}
	for _, s in ipairs(self.draft.shows) do
		local v = Countries.venueById[s.venueId]
		local c = GS.venueClass(v)
		by[c] = by[c] or { class = c, shows = 0, names = {} }
		by[c].shows = by[c].shows + 1
		table.insert(by[c].names, v.name)
	end
	local out = {}
	for _, c in ipairs(CLASS_ORDER) do
		if by[c] then
			table.insert(out, by[c])
		end
	end
	return out
end

-- designs that fit venues of a class, biggest fitting class first
function MapScreen:fittingDesigns(vclass)
	local vo = Config.STAGE_CLASS_BY_ID[vclass].order
	local out = {}
	for _, d in ipairs(self.app.state.designs) do
		if Config.STAGE_CLASS_BY_ID[d.class].order <= vo then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return Config.STAGE_CLASS_BY_ID[a.class].order > Config.STAGE_CLASS_BY_ID[b.class].order
	end)
	return out
end

-- the production chosen for venues of this class (auto-picks the best fitting one)
function MapScreen:designForClass(vclass)
	local draft = self.draft
	draft.designs = draft.designs or {}
	local fits = self:fittingDesigns(vclass)
	local cur = GS.getDesign(self.app.state, draft.designs[vclass] or "")
	for _, d in ipairs(fits) do
		if d == cur then
			return cur
		end
	end
	draft.designs[vclass] = fits[1] and fits[1].id or nil
	return fits[1]
end

function MapScreen:designFor(v)
	return self:designForClass(GS.venueClass(v))
end

function MapScreen:design()
	local s = self.draft.shows[1]
	return s and self:designFor(Countries.venueById[s.venueId]) or nil
end

function MapScreen:estimate()
	self:syncPrices()
	return Sim.estimate(self.app.state, self.draft, function(v)
		return self:designFor(v)
	end)
end

------------------------------------------------------------------ country panel (step 2)
function MapScreen:buildCountryPanel()
	local panel = UI.Panel(self.routeView, UI.px(20, 684), UI.px(1432, 316))
	self.countryPanel = panel
	self.countryTitle = UI.Label(panel, "", UI.px(20, 8), UI.px(560, 32), { textSize = 26, font = UI.FontBlack })
	self.countryInfo = UI.Label(panel, "", UI.px(20, 40), UI.px(1392, 24), { textSize = 15, color = T.sub, rich = true })
	-- venue type filter
	self.venueFilter = "ALL"
	self.filterBar = UI.New("Frame", { Parent = panel, Position = UI.px(700, 8), Size = UI.px(716, 32), BackgroundTransparency = 1 })
	UI.List(false, 6, Enum.HorizontalAlignment.Right).Parent = self.filterBar
	self.venueList = UI.Scroll(panel, UI.px(12, 70), UI.px(1408, 238))
	UI.List(true, 6).Parent = self.venueList
end

function MapScreen:refreshCountry()
	local c = self.selected and Countries.byId[self.selected]
	UI.ClearChildren(self.venueList)
	if not c then
		self.countryTitle.Text = "Pick a country"
		self.countryInfo.Text = "Click a pin on the map. Pin colours show how many fans " .. (self.draft.artistId and Artists.byId[self.draft.artistId].name or "your artist") .. " has there."
		return
	end
	local state = self.app.state
	local aid = self.draft.artistId
	local tip, pool = Sim.recommendation(state, aid, c.id)
	self.countryTitle.Text = string.upper(c.name)
	local info = Regions.byId[c.region].name .. "   |   Price level x" .. string.format("%.2f", c.priceLevel)
		.. string.format("   |   <b>Promoter tip:</b> %s should play <b>%s</b> here (~%s interested fans)", Artists.byId[aid].name, tip, Util.short(pool))
	local last = state.artists[aid].lastPlayed[c.id]
	if last and state.day - last < 180 then
		info = info .. "  <font color='#ffc107'>(played here recently)</font>"
	end
	self.countryInfo.Text = info

	-- filter chips
	UI.ClearChildren(self.filterBar)
	local FILTERS = { { "ALL", nil }, { "CLUBS", { Club = true } }, { "THEATRES & HALLS", { Theatre = true, Hall = true } }, { "ARENAS", { Arena = true, Amphitheatre = true } }, { "STADIUMS", { Stadium = true } } }
	local allowed = nil
	for i, f in ipairs(FILTERS) do
		local n = 0
		for _, v in ipairs(c.venues) do
			if not f[2] or f[2][v.type] then
				n = n + 1
			end
		end
		local on = self.venueFilter == f[1]
		if on then
			allowed = f[2]
		end
		UI.Button(self.filterBar, f[1] .. " (" .. n .. ")", nil, UI.px(#f[1] * 9 + 58, 32), { order = i, textSize = 13, color = on and T.accent2 or T.panel3, textColor = on and Color3.new(0, 0, 0) or T.text, disabled = n == 0 }, function()
			self.venueFilter = f[1]
			self:refreshCountry()
		end)
	end
	local shown = 0
	for i, v in ipairs(c.venues) do
		if not allowed or allowed[v.type] then
			shown = shown + 1
		local vt = Countries.VENUE_TYPES[v.type]
		local row = UI.New("Frame", { Parent = self.venueList, Size = UI.px(1386, 56), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		UI.Pill(row, vt.label, UI.px(12, 16), UI.px(92, 24), UI.rgb(vt.color), 13)
		UI.Label(row, v.name, UI.px(118, 6), UI.px(420, 26), { textSize = 20, font = UI.FontBold })
		UI.Label(row, v.city, UI.px(118, 30), UI.px(420, 20), { textSize = 15, color = T.sub })
		UI.Label(row, Util.number(v.cap), UI.px(550, 6), UI.px(150, 26), { textSize = 20, font = UI.FontBold })
		UI.Label(row, "capacity", UI.px(550, 30), UI.px(150, 20), { textSize = 14, color = T.sub })
		UI.Label(row, Util.moneyShort(Sim.venueRent(v)), UI.px(710, 6), UI.px(130, 26), { textSize = 20, font = UI.FontBold })
		UI.Label(row, "rent / show", UI.px(710, 30), UI.px(130, 20), { textSize = 14, color = T.sub })
		-- promoter estimate (a range, not a promise)
		local shows = {}
		for _, s in ipairs(self.draft.shows) do
			if Countries.venueById[s.venueId].countryId == c.id then
				table.insert(shows, { venueId = s.venueId, price = self.draft.price })
			end
		end
		table.insert(shows, { venueId = v.id, price = self.draft.price })
		local d = Sim.demands(state, aid, shows, 1)[#shows]
		local n = Config.DEMAND_NOISE
		local lo, hi = math.min(1, d * (1 - n) / v.cap), math.min(1, d * (1 + n) / v.cap)
		local col = rangeColor(lo, hi)
		UI.Label(row, "Promoter estimate", UI.px(860, 6), UI.px(260, 22), { textSize = 13, color = T.sub })
		UI.Label(row, rangeText(lo, hi) .. (lo < 0.999 and " full" or ""), UI.px(860, 26), UI.px(260, 24), { textSize = 17, color = col, font = UI.FontBold })
		UI.Button(row, "+ ADD", UI.px(1260, 8), UI.px(110, 40), { color = T.accent, disabled = #self.draft.shows >= Config.MAX_SHOWS_PER_TOUR }, function()
			table.insert(self.draft.shows, { venueId = v.id, price = self.draft.price })
			self:refresh()
		end)
		end
	end
	if shown == 0 then
		UI.Label(self.venueList, "No venues of this type here.", nil, UI.px(600, 40), { textSize = 16, color = T.sub })
	end
end

function MapScreen:refreshRoutePanel()
	local p = self.routePanel
	UI.ClearChildren(p)
	local state, draft = self.app.state, self.draft
	UI.Label(p, "YOUR ROUTE", UI.px(20, 12), UI.px(300, 32), { textSize = 24, font = UI.FontBlack, color = T.accent })
	UI.Label(p, #draft.shows .. " show" .. (#draft.shows == 1 and "" or "s"), UI.px(250, 12), UI.px(164, 32), { textSize = 16, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local list = UI.Scroll(p, UI.px(10, 52), UI.px(414, 776))
	UI.List(true, 6).Parent = list
	if #draft.shows == 0 then
		UI.Label(list, "Click a country on the map, then press + ADD on a venue. Shows are played in this order.", nil, UI.px(396, 90), { textSize = 15, color = T.sub, wrap = true })
	end
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(396, 58), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		local _, dateShort = Util.date(state.day + draft.firstIn + (i - 1) * draft.gap, Config.START_YEAR)
		UI.Label(row, i .. ".  " .. v.name, UI.px(10, 4), UI.px(278, 24), { textSize = 17, font = UI.FontBold })
		UI.Label(row, dateShort .. "  |  " .. v.city .. "  |  " .. Util.number(v.cap) .. " seats", UI.px(10, 30), UI.px(278, 20), { textSize = 13, color = T.sub })
		UI.Button(row, "^", UI.px(292, 14), UI.px(30, 30), { textSize = 14 }, function()
			if i > 1 then
				draft.shows[i], draft.shows[i - 1] = draft.shows[i - 1], draft.shows[i]
				self:refresh()
			end
		end)
		UI.Button(row, "v", UI.px(326, 14), UI.px(30, 30), { textSize = 14 }, function()
			if i < #draft.shows then
				draft.shows[i], draft.shows[i + 1] = draft.shows[i + 1], draft.shows[i]
				self:refresh()
			end
		end)
		UI.Button(row, "X", UI.px(360, 14), UI.px(30, 30), { textSize = 14, color = UI.shade(T.bad, 0.7) }, function()
			table.remove(draft.shows, i)
			self:refresh()
		end)
	end
	UI.Button(p, "< Back", UI.px(16, 848), UI.px(110, 60), {}, function()
		self:setStep(1)
	end)
	UI.Button(p, "NEXT: TICKETS & STAGE >", UI.px(134, 848), UI.px(282, 60), { color = T.accent, textSize = 16, disabled = #draft.shows == 0 }, function()
		self:setStep(3)
	end)
end

------------------------------------------------------------------ step bar
function MapScreen:refreshStepBar()
	UI.ClearChildren(self.stepBar)
	for i, name in ipairs(STEPS) do
		local active = i == self.step
		local reachable = i == 1 or (i == 2 and self.draft.artistId ~= nil) or (i >= 3 and #self.draft.shows > 0)
		UI.Button(self.stepBar, i .. "  " .. name, UI.px((i - 1) * 470, 0), UI.px(458, 52), {
			color = active and T.accent or (reachable and T.panel3 or T.panel),
			textColor = reachable and T.text or T.sub,
			textSize = 18,
			disabled = not reachable,
		}, function()
			self:setStep(i)
		end)
	end
end

function MapScreen:setStep(i)
	self.step = i
	self:refresh()
end

------------------------------------------------------------------ step 1: artist
function MapScreen:buildArtistStep(body)
	local state = self.app.state
	UI.Label(body, "Who goes on tour?", UI.px(40, 80), UI.px(1000, 44), { textSize = 34, font = UI.FontBlack })
	UI.Label(body, "Pick one of your artists. Artists who are already on tour can't start a new one.", UI.px(40, 126), UI.px(1400, 26), { textSize = 17, color = T.sub })
	local grid = UI.Scroll(body, UI.px(40, 170), UI.px(1840, 820))
	UI.New("UIGridLayout", { Parent = grid, CellSize = UI.px(440, 300), CellPadding = UI.px(16, 16), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, ad in ipairs(GS.signedArtists(state)) do
		local a = state.artists[ad.id]
		local tour = GS.activeTour(state, ad.id)
		local sel = self.draft.artistId == ad.id
		local card = UI.New("Frame", { Parent = grid, BackgroundColor3 = sel and UI.shade(T.accent, 0.45) or T.panel, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(12), UI.Stroke(sel and T.accent or T.stroke, sel and 3 or 1, 0) })
		UI.New("Frame", { Parent = card, Size = UI.px(440, 10), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0, UI.Corner(12) })
		UI.Label(card, ad.name, UI.px(20, 22), UI.px(400, 36), { textSize = 28, font = UI.FontBlack })
		UI.Label(card, ad.genre .. "  |  " .. Util.tier(Util.totalFans(a.fans)), UI.px(20, 60), UI.px(400, 22), { textSize = 16, color = T.sub })
		local lines = {
			"Fans: <b>" .. Util.short(Util.totalFans(a.fans)) .. "</b>   Hype: <b>" .. math.floor(a.hype) .. "</b>   Skill: <b>" .. ad.skill .. "</b>",
			"Strongest in: <b>" .. (function()
				local best, n = "EU", -1
				for rid, f in pairs(a.fans) do
					if f > n then
						best, n = rid, f
					end
				end
				return Regions.byId[best].name
			end)() .. "</b>",
			"Suggested ticket price: <b>~" .. Util.money(Util.round(Sim.ticketBase(state, ad.id))) .. "</b>",
		}
		UI.Label(card, table.concat(lines, "\n"), UI.px(20, 96), UI.px(400, 110), { textSize = 16, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
		if tour then
			UI.Label(card, "On tour: " .. tour.name, UI.px(20, 236), UI.px(400, 44), { textSize = 16, color = T.warn, font = UI.FontBold })
		else
			UI.Button(card, sel and "SELECTED - NEXT >" or "SELECT", UI.px(20, 232), UI.px(400, 50), { color = T.accent, textSize = 18 }, function()
				self:setArtist(ad.id)
				self:setStep(2)
			end)
		end
	end
end

function MapScreen:setArtist(id)
	if self.draft.artistId ~= id then
		self.draft.artistId = id
		self.draft.shows = {}
		local ad = Artists.byId[id]
		self.draft.name = ad.name .. " Live " .. (Config.START_YEAR + math.floor(self.app.state.day / 365))
		self.draft.price = math.max(5, Util.round(Sim.ticketBase(self.app.state, id)))
		self.selected = nil
	end
end

------------------------------------------------------------------ step 3: tickets & stage
function MapScreen:buildTicketStep(body)
	local state, draft = self.app.state, self.draft
	local ad = Artists.byId[draft.artistId]
	local left = UI.Panel(body, UI.px(20, 72), UI.px(900, 928))
	UI.Label(left, "TICKET PRICE", UI.px(28, 20), UI.px(500, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	UI.Label(left, "One price for the whole tour. Fans in expensive countries (e.g. Switzerland, USA) accept higher prices than fans in cheaper ones.", UI.px(28, 58), UI.px(840, 48), { textSize = 16, color = T.sub, wrap = true })
	local steps = { -10, -1, 1, 10 }
	for i, d in ipairs(steps) do
		local x = (i <= 2) and (28 + (i - 1) * 96) or (560 + (i - 3) * 96)
		UI.Button(left, (d > 0 and "+" or "") .. d, UI.px(x, 120), UI.px(86, 70), { textSize = 22 }, function()
			draft.price = math.clamp(draft.price + d, 5, 2000)
			self:refresh()
		end)
	end
	UI.Label(left, Util.money(draft.price), UI.px(220, 116), UI.px(330, 78), { textSize = 56, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
	UI.Label(left, "Promoter suggests about " .. Util.money(Util.round(Sim.ticketBase(state, ad.id))) .. " for " .. ad.name .. ".", UI.px(28, 200), UI.px(840, 24), { textSize = 16, color = T.gold })

	UI.Label(left, "SCHEDULE", UI.px(28, 260), UI.px(500, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	local function stepper(x, y, label, value, minV, maxV, onSet)
		UI.Label(left, label, UI.px(x, y), UI.px(380, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
		UI.Button(left, "-", UI.px(x, y + 26), UI.px(48, 48), { textSize = 22 }, function()
			onSet(math.max(minV, value - 1))
			self:refresh()
		end)
		UI.Label(left, value .. " days", UI.px(x + 54, y + 26), UI.px(130, 48), { textSize = 22, font = UI.FontBold, alignX = Enum.TextXAlignment.Center })
		UI.Button(left, "+", UI.px(x + 190, y + 26), UI.px(48, 48), { textSize = 22 }, function()
			onSet(math.min(maxV, value + 1))
			self:refresh()
		end)
	end
	stepper(28, 304, "FIRST SHOW IN (longer = more pre-sale time)", draft.firstIn, Config.MIN_LEAD_DAYS, Config.MAX_LEAD_DAYS, function(v)
		draft.firstIn = v
	end)
	stepper(470, 304, "DAYS BETWEEN SHOWS", draft.gap, 1, Config.MAX_GAP_DAYS, function(v)
		draft.gap = v
	end)
	UI.Button(left, (draft.watchFirst and "[X]" or "[  ]") .. "  Watch the opening night live in 3D", UI.px(28, 410), UI.px(844, 48), { color = T.panel2, textSize = 17 }, function()
		draft.watchFirst = not draft.watchFirst
		self:refresh()
	end)
	local est = self:estimate()
	local lines = {
		string.format("Shows: <b>%d</b>    Seats: <b>%s</b>", #draft.shows, Util.number(est.capacity)),
		"Promoter estimate, gross: <b>" .. Util.money(est.grossLow or 0) .. " - " .. Util.money(est.grossHigh or 0) .. "</b>",
		"Costs (venues, production, travel, artist share): about <b>" .. Util.money(est.costs) .. "</b>",
		"Estimates can be wrong. Real ticket sales show up once the tour is announced.",
	}
	UI.Label(left, table.concat(lines, "\n"), UI.px(28, 490), UI.px(844, 130), { textSize = 17, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(left, "< Back to route", UI.px(28, 846), UI.px(260, 60), {}, function()
		self:setStep(2)
	end)
	UI.Button(left, "NEXT: CONFIRM >", UI.px(560, 846), UI.px(312, 60), { color = T.accent, textSize = 18 }, function()
		for _, need in ipairs(self:classesNeeded()) do
			if not self:designForClass(need.class) then
				self.app:toast("You have no stage design that fits your " .. string.lower(need.class) .. " venues. Build a " .. need.class .. " design in the Stage Designer.", T.bad, 8)
				return
			end
		end
		self:setStep(4)
	end)

	-- one stage production per venue size
	local right = UI.Panel(body, UI.px(940, 72), UI.px(960, 928))
	UI.Label(right, "STAGE PRODUCTIONS", UI.px(28, 20), UI.px(600, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	UI.Label(right, "Real tours bring a different production for small and big venues. Pick a design for every venue size on your route. A design never fits into a smaller venue class than its own.", UI.px(28, 58), UI.px(900, 48), { textSize = 15, color = T.sub, wrap = true })
	local list = UI.Scroll(right, UI.px(20, 112), UI.px(920, 716))
	UI.List(true, 8).Parent = list
	local order = 0
	local function add(inst)
		order = order + 1
		inst.LayoutOrder = order
		inst.Parent = list
		return inst
	end
	for _, need in ipairs(self:classesNeeded()) do
		local head = add(UI.New("Frame", { Size = UI.px(900, 54), BackgroundTransparency = 1 }))
		UI.Label(head, CLASS_LABEL[need.class] .. " VENUES  (" .. need.shows .. " show" .. (need.shows > 1 and "s" or "") .. ")", UI.px(0, 4), UI.px(900, 26), { textSize = 18, font = UI.FontBlack, color = T.gold })
		UI.Label(head, table.concat(need.names, ", "), UI.px(0, 30), UI.px(900, 20), { textSize = 13, color = T.sub })
		local chosen = self:designForClass(need.class)
		local fits = self:fittingDesigns(need.class)
		if #fits == 0 then
			local warn = add(UI.New("Frame", { Size = UI.px(900, 70), BackgroundColor3 = UI.shade(T.bad, 0.35), BorderSizePixel = 0, UI.Corner(8) }))
			UI.Label(warn, "No design fits these venues! Your designs are too big. Build a " .. need.class .. " stage.", UI.px(16, 0), UI.px(560, 70), { textSize = 16, wrap = true, font = UI.FontBold })
			UI.Button(warn, "BUILD " .. string.upper(need.class) .. " STAGE", UI.px(600, 14), UI.px(284, 42), { color = T.accent, textSize = 15 }, function()
				self.app.returnScreen = "planner"
				self.app.newDesignClass = need.class
				self.app:openDesigner(nil)
			end)
		end
		for _, d in ipairs(fits) do
			local st = Sim.designStats(d, ad.genre)
			local q, n = 0, 0
			for _, s in ipairs(draft.shows) do
				local v = Countries.venueById[s.venueId]
				if GS.venueClass(v) == need.class then
					q = q + Sim.productionScore(d, ad.genre, v.cap)
					n = n + 1
				end
			end
			q = n > 0 and q / n or 0
			local sel = d == chosen
			local b = add(UI.Button(nil, "", nil, UI.px(900, 64), { color = sel and UI.shade(T.accent, 0.5) or T.panel2 }, function()
				draft.designs[need.class] = d.id
				self:refresh()
			end))
			UI.Label(b, (sel and "> " or "") .. d.name, UI.px(16, 6), UI.px(560, 28), { textSize = 19, font = UI.FontBold })
			UI.Label(b, d.class .. " " .. (d.layout == "center" and "center stage" or "end stage") .. "  |  " .. st.count .. " items  |  " .. Util.money(st.cost) .. " per show", UI.px(16, 36), UI.px(600, 20), { textSize = 14, color = T.sub })
			local col = q >= 80 and T.good or (q >= 55 and T.warn or T.bad)
			UI.Label(b, "quality " .. math.floor(q + 0.5) .. "%", UI.px(640, 0), UI.px(244, 64), { textSize = 22, font = UI.FontBlack, color = col, alignX = Enum.TextXAlignment.Right })
		end
	end
	UI.Button(right, "OPEN STAGE DESIGNER", UI.px(28, 846), UI.px(904, 60), { color = T.accent2, textColor = Color3.new(0, 0, 0), textSize = 18 }, function()
		local d = self:design()
		self.app.lastDesignId = d and d.id
		self.app.returnScreen = "planner"
		self.app:openDesigner(d and d.id)
	end)
end

------------------------------------------------------------------ step 4: confirm
function MapScreen:buildConfirmStep(body)
	local state, draft = self.app.state, self.draft
	local ad = Artists.byId[draft.artistId]
	local est = self:estimate()
	local prodNames = {}
	for _, need in ipairs(self:classesNeeded()) do
		local d = self:designForClass(need.class)
		table.insert(prodNames, d and d.name or "?")
	end
	local panel = UI.Panel(body, UI.px(20, 72), UI.px(1880, 928))
	UI.Label(panel, "TOUR NAME", UI.px(28, 18), UI.px(400, 22), { textSize = 15, color = T.sub, font = UI.FontBold })
	local nameBox = UI.New("TextBox", {
		Parent = panel,
		Position = UI.px(28, 42),
		Size = UI.px(700, 54),
		BackgroundColor3 = T.panel2,
		BorderSizePixel = 0,
		Text = draft.name,
		PlaceholderText = "Tour name",
		ClearTextOnFocus = false,
		TextColor3 = T.text,
		TextSize = 26,
		Font = UI.FontBlack,
		UI.Corner(8),
	})
	nameBox.FocusLost:Connect(function()
		draft.name = nameBox.Text:sub(1, 40)
	end)
	UI.Label(panel, ad.name .. "   |   " .. #draft.shows .. " shows   |   " .. Util.money(draft.price) .. " per ticket   |   Stage: " .. table.concat(prodNames, " / "), UI.px(760, 42), UI.px(1100, 54), { textSize = 19, color = T.sub })

	local headers = { { "#", 28 }, { "DATE", 70 }, { "VENUE", 200 }, { "SEATS", 860 }, { "PROMOTER ESTIMATE", 1040 } }
	for _, h in ipairs(headers) do
		UI.Label(panel, h[1], UI.px(h[2], 116), UI.px(300, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local list = UI.Scroll(panel, UI.px(16, 140), UI.px(1848, 560))
	UI.List(true, 4).Parent = list
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local r = est.rows[i]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(1828, 44), BackgroundColor3 = (i % 2 == 0) and T.panel2 or T.panel3, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(6) })
		local _, dateShort = Util.date(state.day + draft.firstIn + (i - 1) * draft.gap, Config.START_YEAR)
		UI.Label(row, tostring(i), UI.px(12, 0), UI.px(40, 44), { textSize = 16, font = UI.FontBold })
		UI.Label(row, dateShort, UI.px(54, 0), UI.px(120, 44), { textSize = 16 })
		UI.Label(row, v.name .. ", " .. v.city, UI.px(184, 0), UI.px(640, 44), { textSize = 16, font = UI.FontBold })
		UI.Label(row, Util.number(v.cap), UI.px(844, 0), UI.px(160, 44), { textSize = 16 })
		UI.Label(row, rangeText(r.fillLow, r.fillHigh), UI.px(1024, 0), UI.px(400, 44), { textSize = 16, font = UI.FontBold, color = rangeColor(r.fillLow, r.fillHigh) })
	end
	local lines = {
		"Estimated gross: <b>" .. Util.money(est.grossLow or 0) .. " - " .. Util.money(est.grossHigh or 0) .. "</b>",
		"Estimated label profit: <b>" .. Util.money(est.netLow or 0) .. " - " .. Util.money(est.netHigh or 0) .. "</b>   (after venues, production, travel and the artist's 35%)",
		"<font color='#9696b2'>The promoter can be wrong. Once announced, watch the real pre-sale on the TOURS screen and react with marketing or price changes.</font>",
	}
	UI.Label(panel, table.concat(lines, "\n"), UI.px(28, 716), UI.px(1820, 100), { textSize = 18, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(panel, "< Back", UI.px(28, 846), UI.px(200, 60), {}, function()
		self:setStep(3)
	end)
	UI.Button(panel, "ANNOUNCE TOUR", UI.px(1452, 846), UI.px(400, 60), { color = T.accent, textSize = 24 }, function()
		self:syncPrices()
		local ok, res = GS.createTour(state, draft)
		if not ok then
			self.app:toast(res, T.bad)
			return
		end
		self.app:toast("<b>" .. UI.esc(res.name) .. "</b> is announced! Tickets are on sale now.", T.good, 8)
		self.draft = { artistId = nil, name = "", designs = draft.designs, firstIn = 21, gap = 2, watchFirst = true, price = 30, shows = {} }
		self.step = 1
		self.app:save()
		self.app:go("tours", { tourId = res.id })
	end)
end

------------------------------------------------------------------ refresh
function MapScreen:show(args)
	if args and args.artistId then
		self:setArtist(args.artistId)
		self.step = 2
	end
	self:refresh()
end

function MapScreen:refresh()
	local state = self.app.state
	-- make sure the drafted artist is still available
	local aid = self.draft.artistId
	if aid and (not state.artists[aid].signed or GS.activeTour(state, aid)) then
		self.draft.artistId = nil
		self.draft.shows = {}
	end
	if not self.draft.artistId then
		self.step = 1
	elseif self.step >= 3 and #self.draft.shows == 0 then
		self.step = 2
	end
	self:refreshStepBar()
	UI.ClearChildren(self.body)
	self.routeView.Visible = self.step == 2
	if self.step ~= 2 then
		self:deactivateMap()
	end
	if self.step == 1 then
		self:buildArtistStep(self.body)
	elseif self.step == 2 then
		self:refreshRoute()
	elseif self.step == 3 then
		self:buildTicketStep(self.body)
	else
		self:buildConfirmStep(self.body)
	end
end

function MapScreen:refreshRoute()
	local state, aid = self.app.state, self.draft.artistId
	local counts = {}
	for _, s in ipairs(self.draft.shows) do
		local cid = Countries.venueById[s.venueId].countryId
		counts[cid] = (counts[cid] or 0) + 1
	end
	local route = {}
	for _, sh in ipairs(self.draft.shows) do
		table.insert(route, Countries.venueById[sh.venueId].countryId)
	end
	WorldMap3D.build()
	WorldMap3D.setColorFn(function(cid)
		return heatColor(Sim.countryPool(state, aid, cid))
	end)
	WorldMap3D.setSelected(self.selected)
	WorldMap3D.setRoute(route, counts)
	self:activateMap()
	self.legend.Text = "Hover a country to highlight it, click it to see its venues.   Colour = fans of <b>" .. Artists.byId[aid].name .. "</b> who want tickets:  <font color='#9646af'>very few</font>  <font color='#eb4646'>few</font>  <font color='#ff9628'>some</font>  <font color='#ffe13c'>good</font>  <font color='#a0eb5a'>many</font>  <font color='#28dc78'>huge</font>"
	self:refreshCountry()
	self:refreshRoutePanel()
end

return MapScreen
