-- PLAN A TOUR: a 5-step wizard: artist -> dates (map + calendar) -> stage -> tickets (seat map) -> confirm.
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
local People = require(Root.Client.People)

local T = UI.Theme
local MapScreen = {}
MapScreen.__index = MapScreen
local STEPS = { "ARTIST", "DATES", "STAGE", "TICKETS", "CONFIRM" }

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
	-- in step 2 the 3D map shows only through the map window: dark cover around it
	self.mapMask = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "MapMask" })
	for _, r in ipairs({ { -3000, 0, 7920, 72 }, { -3000, 72, 3020, 500 }, { 780, 72, 4140, 500 }, { -3000, 572, 7920, 3000 } }) do
		UI.New("Frame", { Parent = self.mapMask, Position = UI.px(r[1], r[2]), Size = UI.px(r[3], r[4]), BackgroundColor3 = T.bg, BorderSizePixel = 0 })
	end
	self.stepBar = UI.New("Frame", { Parent = self.frame, Position = UI.px(20, 8), Size = UI.px(1880, 52), BackgroundTransparency = 1 })
	self.draft = { artistId = nil, name = "", designs = {}, firstIn = 21, gap = 2, watchFirst = true, price = 30, prices = {}, shows = {} }
	-- step 2 (route) keeps its map alive between visits; the other steps are rebuilt
	self.routeView = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	self:buildMap()
	return self
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

-- section prices of a venue look (club / theatre / arena / amphi / stadium) for this tour
function MapScreen:pricesFor(look)
	local draft = self.draft
	draft.prices = draft.prices or {}
	if not draft.prices[look] then
		draft.prices[look] = Sim.defaultPrices(draft.price, look)
	end
	return draft.prices[look]
end

function MapScreen:syncPrices()
	for _, s in ipairs(self.draft.shows) do
		local v = Countries.venueById[s.venueId]
		local look = Sim.lookOf(v)
		s.prices = self:pricesFor(look)
		s.price = Sim.avgPrice(look, s.prices)
	end
end

-- shows are always in date order
function MapScreen:sortShows()
	table.sort(self.draft.shows, function(a, b)
		return (a.day or 0) < (b.day or 0)
	end)
end

-- days already used by this route (an artist plays one show a day)
function MapScreen:takenDays(except)
	local taken = {}
	for _, s in ipairs(self.draft.shows) do
		if s ~= except and s.day then
			taken[s.day] = true
		end
	end
	return taken
end

-- adds a show at the first free date after the last show (next day for another night in the same venue)
function MapScreen:addShow(venueId)
	local state, draft = self.app.state, self.draft
	local last = draft.shows[#draft.shows]
	local from = state.day + 21
	local new = { venueId = venueId }
	if last then
		from = math.max(state.day + Config.MIN_LEAD_DAYS, last.day + GS.travelGap(last, new))
	end
	new.day = GS.nextFreeDay(state, venueId, from, self:takenDays())
	table.insert(draft.shows, new)
	self:sortShows()
	self:refresh()
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

-- true if every venue size on the route has a stage
function MapScreen:stagesReady()
	for _, need in ipairs(self:classesNeeded()) do
		if not self:designForClass(need.class) then
			return false
		end
	end
	return true
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

------------------------------------------------------------------ step 2: dates
-- Left: the world map (pick a country) and its venues (pick one). Right: the calendar. With a venue picked,
-- every day shows if that venue is free; a click on a free day books the show there. A click on one of your
-- shows removes it. Shows of your other artists are on the calendar too.
local MAP_W, MAP_H = 760, 500
function MapScreen:buildMap()
	local view = UI.New("Frame", { Parent = self.routeView, Position = UI.px(20, 72), Size = UI.px(MAP_W, MAP_H), BackgroundTransparency = 1, Name = "MapView" })
	self.mapView = view
	local bar = UI.Panel(view, UI.px(0, 0), UI.px(MAP_W, 86), T.panel)
	bar.BackgroundTransparency = 0.15
	self.mapBar = bar
	UI.Label(bar, "1. WHERE?", UI.px(14, 6), UI.px(200, 30), { textSize = 20, font = UI.FontBlack, color = T.accent })
	UI.Label(bar, "Click a country. Drag = move, wheel = zoom.", UI.px(170, 6), UI.px(580, 30), { textSize = 14, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local x = 10
	for _, v in ipairs(VIEWS) do
		local w = #v[1] * 8 + 24
		UI.Button(bar, v[1], UI.px(x, 44), UI.px(w, 32), { textSize = 13 }, function()
			WorldMap3D.flyTo(v[2], v[3], v[4] * 1.7)
		end)
		x = x + w + 6
	end
	local legendBox = UI.Panel(view, UI.px(0, MAP_H - 34), UI.px(MAP_W, 34), T.panel)
	legendBox.BackgroundTransparency = 0.15
	self.legendBox = legendBox
	self.legend = UI.Label(legendBox, "", UI.px(10, 0), UI.px(MAP_W - 20, 34), { textSize = 13, color = T.sub, rich = true })
	self.hoverBox = UI.New("TextLabel", {
		Parent = view,
		Position = UI.px(10, 96),
		Size = UI.px(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.panel,
		BackgroundTransparency = 0.1,
		Text = "",
		RichText = true,
		TextWrapped = true,
		TextColor3 = T.text,
		TextSize = 15,
		Font = UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		UI.Corner(8),
		UI.Padding(12, 12, 8, 8),
		UI.Stroke(T.gold, 1, 0.2),
	})
	-- covers the 3D map everywhere except the map window
	self.venuePanel = UI.Panel(self.routeView, UI.px(20, MAP_H + 84), UI.px(MAP_W, 1000 - MAP_H - 84))
	self.calPanel = UI.Panel(self.routeView, UI.px(MAP_W + 40, 72), UI.px(1880 - MAP_W - 20, 928))
end

-- the 3D map only reacts inside its window
function MapScreen:overUI()
	if self.app.modalOpen then
		return true
	end
	local m = UserInputService:GetMouseLocation()
	local a, sz = self.mapView.AbsolutePosition, self.mapView.AbsoluteSize
	if m.X < a.X or m.X > a.X + sz.X or m.Y < a.Y or m.Y > a.Y + sz.Y then
		return true
	end
	for _, p in ipairs({ self.mapBar, self.legendBox, self.hoverBox }) do
		if p and p.Visible then
			local pa, ps = p.AbsolutePosition, p.AbsoluteSize
			if m.X >= pa.X and m.X <= pa.X + ps.X and m.Y >= pa.Y and m.Y <= pa.Y + ps.Y then
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
		maxDist = 1000,
		screenCenter = function()
			local a, sz = self.mapView.AbsolutePosition, self.mapView.AbsoluteSize
			return a.X + sz.X / 2, a.Y + sz.Y / 2 + 20
		end,
	})
	if not self.mapOpened then
		self.mapOpened = true
		WorldMap3D.flyTo(VIEWS[2][2], VIEWS[2][3], VIEWS[2][4] * 1.7)
	end
end

-- venues of the chosen country (left, below the map)
function MapScreen:refreshCountry()
	local p = self.venuePanel
	UI.ClearChildren(p)
	local c = self.selected and Countries.byId[self.selected]
	local state, aid = self.app.state, self.draft.artistId
	if not c then
		UI.Label(p, "2. WHICH VENUE?", UI.px(16, 10), UI.px(500, 30), { textSize = 20, font = UI.FontBlack, color = T.accent })
		UI.Label(p, "Click a country on the map. Colours show how many fans " .. Artists.byId[aid].name .. " has there.", UI.px(16, 46), UI.px(MAP_W - 32, 60), { textSize = 16, color = T.sub, wrap = true })
		return
	end
	local tip, pool = Sim.recommendation(state, aid, c.id)
	UI.Label(p, string.upper(c.name), UI.px(16, 8), UI.px(400, 30), { textSize = 22, font = UI.FontBlack })
	local last = state.artists[aid].lastPlayed[c.id]
	UI.Label(p, "Promoter tip: <b>" .. tip .. "</b>  (~" .. Util.short(pool) .. " fans)" .. ((last and state.day - last < 180) and "  <font color='#ffc107'>played here recently</font>" or ""), UI.px(16, 38), UI.px(MAP_W - 32, 22), { textSize = 14, color = T.sub, rich = true })
	-- filter chips
	local FILTERS = { { "ALL", nil }, { "CLUBS", { Club = true } }, { "THEATRES", { Theatre = true, Hall = true } }, { "ARENAS", { Arena = true, Amphitheatre = true } }, { "STADIUMS", { Stadium = true } } }
	local allowed, x = nil, 16
	for _, f in ipairs(FILTERS) do
		local n = 0
		for _, v in ipairs(c.venues) do
			if not f[2] or f[2][v.type] then
				n = n + 1
			end
		end
		local on = (self.venueFilter or "ALL") == f[1]
		if on then
			allowed = f[2]
		end
		local w = #f[1] * 9 + 46
		UI.Button(p, f[1] .. " " .. n, UI.px(x, 66), UI.px(w, 30), { textSize = 13, color = on and T.accent2 or T.panel3, textColor = on and Color3.new(0, 0, 0) or T.text, disabled = n == 0 }, function()
			self.venueFilter = f[1]
			self:refreshCountry()
		end)
		x = x + w + 6
	end
	local list = UI.Scroll(p, UI.px(10, 104), UI.px(MAP_W - 20, 1000 - MAP_H - 84 - 114))
	UI.List(true, 6).Parent = list
	local shown = 0
	for i, v in ipairs(c.venues) do
		if not allowed or allowed[v.type] then
			shown = shown + 1
			local vt = Countries.VENUE_TYPES[v.type]
			local picked = self.picked == v.id
			local row = UI.New("Frame", { Parent = list, Size = UI.px(MAP_W - 44, 58), BackgroundColor3 = picked and UI.shade(T.accent, 0.5) or T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
			UI.Pill(row, vt.label, UI.px(10, 17), UI.px(84, 24), UI.rgb(vt.color), 12)
			UI.Label(row, v.name, UI.px(104, 6), UI.px(290, 24), { textSize = 17, font = UI.FontBold })
			UI.Label(row, v.city .. "  |  " .. Util.number(v.cap) .. " seats  |  rent " .. Util.moneyShort(Sim.venueRent(v)), UI.px(104, 30), UI.px(330, 20), { textSize = 13, color = T.sub })
			-- promoter estimate (a range, not a promise)
			local shows = {}
			for _, s in ipairs(self.draft.shows) do
				local sv = Countries.venueById[s.venueId]
				if sv.countryId == c.id then
					table.insert(shows, { venueId = s.venueId, price = Sim.avgPrice(Sim.lookOf(sv), self:pricesFor(Sim.lookOf(sv))) })
				end
			end
			table.insert(shows, { venueId = v.id, price = Sim.avgPrice(Sim.lookOf(v), self:pricesFor(Sim.lookOf(v))) })
			local d = Sim.demands(state, aid, shows, 1)[#shows]
			local n = Config.DEMAND_NOISE
			local lo, hi = math.min(1, d * (1 - n) / v.cap), math.min(1, d * (1 + n) / v.cap)
			UI.Label(row, rangeText(lo, hi) .. (lo < 0.999 and " full" or ""), UI.px(440, 6), UI.px(150, 46), { textSize = 14, color = rangeColor(lo, hi), font = UI.FontBold, wrap = true })
			UI.Button(row, picked and "PICKED" or "PICK", UI.px(MAP_W - 150, 10), UI.px(96, 38), { color = picked and T.gold or T.accent, textColor = picked and Color3.new(0, 0, 0) or nil, textSize = 15 }, function()
				self.picked = picked and nil or v.id
				-- jump to the month where the next show would fit
				if self.picked then
					local lastS = self.draft.shows[#self.draft.shows]
					local from = lastS and lastS.day or (state.day + 21)
					local y, m = Util.ymd(from, Config.START_YEAR)
					self.calMonth = { y, m }
				end
				self:refresh()
			end)
		end
	end
	if shown == 0 then
		UI.Label(list, "No venues of this type here.", nil, UI.px(600, 40), { textSize = 16, color = T.sub })
	end
end

-- what a day means for the picked venue: "ok", or the reason why not
function MapScreen:dayState(day)
	local state, draft = self.app.state, self.draft
	if day < state.day + 3 then
		return "past"
	end
	for _, s in ipairs(draft.shows) do
		if s.day == day then
			return "mine"
		end
	end
	if not self.picked then
		return "none"
	end
	local busy = GS.venueBusy(state, self.picked, day)
	if busy then
		return "busy", busy
	end
	-- travel: enough days to and from the neighbouring shows
	local new = { venueId = self.picked }
	for _, s in ipairs(draft.shows) do
		local gap = math.abs(s.day - day)
		if gap < GS.travelGap(s, new) then
			return "travel"
		end
	end
	return "ok"
end

function MapScreen:showDays()
	local out = {}
	for i, s in ipairs(self.draft.shows) do
		out[i] = s.day
	end
	return out
end

-- click on a day: book the picked venue, or remove your show from that day
function MapScreen:dayClicked(day)
	local draft = self.draft
	for i, s in ipairs(draft.shows) do
		if s.day == day then
			table.remove(draft.shows, i)
			self:refresh()
			return
		end
	end
	if self:dayState(day) == "ok" and #draft.shows < Config.MAX_SHOWS_PER_TOUR then
		table.insert(draft.shows, { venueId = self.picked, day = day })
		self:sortShows()
		self:refresh()
	end
end

-- shows of all your tours on a day: { "Juno Park: Paris" }
function MapScreen:otherShows(day)
	local out = {}
	for _, t in ipairs(self.app.state.tours or {}) do
		for _, s in ipairs(t.shows) do
			if s.day == day and not s.done then
				table.insert(out, Artists.byId[t.artistId].name .. ": " .. Countries.venueById[s.venueId].city)
			end
		end
	end
	return out
end

function MapScreen:refreshRoutePanel()
	local p = self.calPanel
	UI.ClearChildren(p)
	local state, draft = self.app.state, self.draft
	local W = 1880 - MAP_W - 20
	if not self.calMonth then
		local first = draft.shows[1]
		local y, m = Util.ymd(first and first.day or (state.day + 21), Config.START_YEAR)
		self.calMonth = { y, m }
	end
	local y, m = self.calMonth[1], self.calMonth[2]
	UI.Label(p, "3. WHEN?", UI.px(20, 12), UI.px(200, 32), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Button(p, "<", UI.px(260, 10), UI.px(48, 40), { textSize = 20 }, function()
		m = m - 1
		if m < 1 then
			m, y = 12, y - 1
		end
		self.calMonth = { y, m }
		self:refreshRoutePanel()
	end)
	UI.Label(p, Util.monthName(m) .. " " .. y, UI.px(314, 10), UI.px(220, 40), { textSize = 24, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
	UI.Button(p, ">", UI.px(540, 10), UI.px(48, 40), { textSize = 20 }, function()
		m = m + 1
		if m > 12 then
			m, y = 1, y + 1
		end
		self.calMonth = { y, m }
		self:refreshRoutePanel()
	end)
	local pv = self.picked and Countries.venueById[self.picked]
	local hint = pv and ("<b>" .. pv.name .. ", " .. pv.city .. "</b>: click a green day to play there (click several days for more nights). Click one of your shows to remove it.")
		or "Pick a venue on the left, then click the days you want to play there."
	UI.Label(p, hint, UI.px(610, 8), UI.px(W - 630, 46), { textSize = 14, color = pv and T.text or T.sub, rich = true, wrap = true })
	-- weekday header and the month grid
	local cw, ch, gap = math.floor((W - 30) / 7) - 6, 104, 6
	for i, nm in ipairs({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }) do
		UI.Label(p, nm, UI.px(15 + (i - 1) * (cw + gap), 60), UI.px(cw, 22), { textSize = 14, color = T.sub, font = UI.FontBold, alignX = Enum.TextXAlignment.Center })
	end
	local d0 = Util.dayOf(y, m, 1, Config.START_YEAR)
	local _, _, _, wd0 = Util.ymd(d0, Config.START_YEAR)
	for dd = 1, Util.monthLength(y, m) do
		local day = d0 + dd - 1
		local cell = wd0 - 1 + dd - 1
		local cx, cy = 15 + (cell % 7) * (cw + gap), 86 + math.floor(cell / 7) * (ch + gap)
		local st, why = self:dayState(day)
		local color = T.panel2
		if st == "past" then
			color = T.panel
		elseif st == "mine" then
			color = UI.shade(T.accent, 0.75)
		elseif st == "ok" then
			color = UI.shade(T.good, 0.42)
		elseif st == "busy" then
			color = UI.shade(T.bad, 0.42)
		elseif st == "travel" then
			color = T.panel3
		end
		local b = UI.Button(p, "", UI.px(cx, cy), UI.px(cw, ch), { color = color, disabled = st == "past" }, function()
			self:dayClicked(day)
		end)
		b.Name = "Day" .. day
		UI.Label(b, tostring(dd), UI.px(8, 4), UI.px(40, 22), { textSize = 17, font = UI.FontBold, color = (st == "past") and T.sub or T.text })
		local lines = {}
		if st == "mine" then
			for i, s in ipairs(draft.shows) do
				if s.day == day then
					local v = Countries.venueById[s.venueId]
					table.insert(lines, "<b>#" .. i .. " " .. v.city .. "</b>")
					table.insert(lines, v.name)
				end
			end
		elseif st == "busy" then
			table.insert(lines, "taken: " .. why)
		elseif st == "travel" then
			table.insert(lines, "travel day")
		elseif st == "ok" then
			table.insert(lines, "free")
		end
		for _, o in ipairs(self:otherShows(day)) do
			table.insert(lines, "<font color='#9696b2'>" .. o .. "</font>")
		end
		if #lines > 0 then
			UI.Label(b, table.concat(lines, "\n"), UI.px(8, 26), UI.px(cw - 12, ch - 30), { textSize = 12, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
		end
	end
	-- the route in date order and the way on
	local strip = UI.Scroll(p, UI.px(15, 750), UI.px(W - 30, 84))
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	UI.List(false, 6).Parent = strip
	if #draft.shows == 0 then
		UI.Label(strip, "No shows yet.", nil, UI.px(400, 70), { textSize = 16, color = T.sub })
	end
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local _, dshort = Util.date(s.day, Config.START_YEAR)
		local chip = UI.Button(strip, "", nil, UI.px(170, 70), { order = i, color = T.panel3 }, function()
			local yy, mm = Util.ymd(s.day, Config.START_YEAR)
			self.calMonth = { yy, mm }
			self:refreshRoutePanel()
		end)
		UI.Label(chip, i .. ". " .. dshort, UI.px(8, 4), UI.px(156, 22), { textSize = 14, font = UI.FontBold })
		UI.Label(chip, v.city, UI.px(8, 26), UI.px(156, 20), { textSize = 13 })
		UI.Label(chip, v.name, UI.px(8, 46), UI.px(156, 18), { textSize = 11, color = T.sub })
	end
	UI.Label(p, #draft.shows .. " show" .. (#draft.shows == 1 and "" or "s"), UI.px(15, 846), UI.px(130, 60), { textSize = 18, font = UI.FontBold })
	-- colour legend
	local lx = 150
	for _, k in ipairs({ { "your show", UI.shade(T.accent, 0.75) }, { "free", UI.shade(T.good, 0.42) }, { "taken", UI.shade(T.bad, 0.42) }, { "travel day", T.panel3 } }) do
		UI.New("Frame", { Parent = p, Position = UI.px(lx, 866), Size = UI.px(20, 20), BackgroundColor3 = k[2], BorderSizePixel = 0, UI.Corner(4) })
		UI.Label(p, k[1], UI.px(lx + 26, 864), UI.px(110, 24), { textSize = 14, color = T.sub })
		lx = lx + 34 + #k[1] * 9
	end
	UI.Button(p, "< Back", UI.px(W - 440, 846), UI.px(130, 60), {}, function()
		self:setStep(1)
	end)
	UI.Button(p, "NEXT: STAGE >", UI.px(W - 300, 846), UI.px(280, 60), { color = T.accent, textSize = 18, disabled = #draft.shows == 0 }, function()
		self:setStep(3)
	end)
end

------------------------------------------------------------------ step bar
function MapScreen:refreshStepBar()
	UI.ClearChildren(self.stepBar)
	for i, name in ipairs(STEPS) do
		local active = i == self.step
		local reachable = i == 1 or (i == 2 and self.draft.artistId ~= nil) or (i == 3 and #self.draft.shows > 0) or (i >= 4 and #self.draft.shows > 0 and self:stagesReady())
		UI.Button(self.stepBar, i .. "  " .. name, UI.px((i - 1) * 376, 0), UI.px(364, 52), {
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
		People.preview(card, ad.look, UI.rgb(ad.color), UI.px(300, 16), UI.px(130, 200))
		UI.Label(card, ad.name, UI.px(20, 22), UI.px(280, 36), { textSize = 28, font = UI.FontBlack })
		UI.Label(card, ad.genre .. "  |  " .. Util.tier(Util.totalFans(a.fans)), UI.px(20, 60), UI.px(280, 22), { textSize = 16, color = T.sub })
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
		UI.Label(card, table.concat(lines, "\n"), UI.px(20, 96), UI.px(280, 130), { textSize = 16, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
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
		self.draft.prices = {}
		self.selected = nil
	end
end

------------------------------------------------------------------ step 3: stage
function MapScreen:buildStageStep(body)
	local draft = self.draft
	local ad = Artists.byId[draft.artistId]
	local panel = UI.Panel(body, UI.px(20, 72), UI.px(1880, 928))
	UI.Label(panel, "STAGE PRODUCTIONS", UI.px(28, 20), UI.px(600, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	UI.Label(panel, "Pick one stage for every venue size on your dates. Build or edit it now - when it is ready, go on to the ticket prices.", UI.px(28, 58), UI.px(1500, 26), { textSize = 16, color = T.sub })
	local list = UI.Scroll(panel, UI.px(20, 100), UI.px(1840, 728))
	UI.List(true, 8).Parent = list
	local order = 0
	local function add(inst)
		order = order + 1
		inst.LayoutOrder = order
		inst.Parent = list
		return inst
	end
	local missing = false
	for _, need in ipairs(self:classesNeeded()) do
		local head = add(UI.New("Frame", { Size = UI.px(1820, 54), BackgroundTransparency = 1 }))
		UI.Label(head, CLASS_LABEL[need.class] .. " VENUES  (" .. need.shows .. " show" .. (need.shows > 1 and "s" or "") .. ")", UI.px(0, 4), UI.px(1200, 26), { textSize = 18, font = UI.FontBlack, color = T.gold })
		UI.Label(head, table.concat(need.names, ", "), UI.px(0, 30), UI.px(1800, 20), { textSize = 13, color = T.sub })
		local chosen = self:designForClass(need.class)
		local fits = self:fittingDesigns(need.class)
		if #fits == 0 then
			missing = true
			local warn = add(UI.New("Frame", { Size = UI.px(1820, 70), BackgroundColor3 = UI.shade(T.bad, 0.35), BorderSizePixel = 0, UI.Corner(8) }))
			UI.Label(warn, "No stage fits these venues yet. Build a " .. need.class .. " stage.", UI.px(16, 0), UI.px(1000, 70), { textSize = 17, wrap = true, font = UI.FontBold })
			UI.Button(warn, "BUILD " .. string.upper(need.class) .. " STAGE", UI.px(1500, 14), UI.px(300, 42), { color = T.accent, textSize = 15 }, function()
				self.app:go("stages", { newClass = need.class, back = "planner" })
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
			local b = add(UI.Button(nil, "", nil, UI.px(1820, 64), { color = sel and UI.shade(T.accent, 0.5) or T.panel2 }, function()
				draft.designs[need.class] = d.id
				self:refresh()
			end))
			UI.Label(b, (sel and "> " or "") .. d.name, UI.px(16, 6), UI.px(900, 28), { textSize = 19, font = UI.FontBold })
			UI.Label(b, d.class .. " " .. (d.layout == "center" and "center stage" or "end stage") .. "  |  " .. GS.songCount(d) .. " songs  |  " .. Util.money(st.cost) .. " per show", UI.px(16, 36), UI.px(900, 20), { textSize = 14, color = T.sub })
			local col = q >= 80 and T.good or (q >= 55 and T.warn or T.bad)
			UI.Label(b, "show quality " .. math.floor(q + 0.5) .. "%", UI.px(1200, 0), UI.px(380, 64), { textSize = 22, font = UI.FontBlack, color = col, alignX = Enum.TextXAlignment.Right })
			UI.Button(b, "EDIT", UI.px(1650, 12), UI.px(150, 40), { color = T.accent2, textColor = Color3.new(0, 0, 0), textSize = 16 }, function()
				draft.designs[need.class] = d.id
				self.app.lastDesignId = d.id
				self.app.returnScreen = "planner"
				self.app:openDesigner(d.id)
			end)
		end
	end
	UI.Button(panel, "< Back to dates", UI.px(28, 846), UI.px(260, 60), {}, function()
		self:setStep(2)
	end)
	UI.Button(panel, "+ NEW STAGE", UI.px(760, 846), UI.px(360, 60), { textSize = 18 }, function()
		local need = self:classesNeeded()[1]
		self.app:go("stages", { newClass = need and need.class or "Club", back = "planner" })
	end)
	UI.Button(panel, "STAGE READY - NEXT: TICKETS >", UI.px(1440, 846), UI.px(412, 60), { color = T.accent, textSize = 18, disabled = missing }, function()
		self:setStep(4)
	end)
end

------------------------------------------------------------------ step 4: tickets (seat map like a ticket shop)
local LOOK_LABEL = { club = "CLUBS", theatre = "THEATRES & HALLS", arena = "ARENAS", amphi = "AMPHITHEATRES", stadium = "STADIUMS" }
local LOOK_ORDER = { "club", "theatre", "amphi", "arena", "stadium" }
-- seat map shapes, in a 760 x 600 box, stage at the top: { section id, x, y, w, h }
local SEATMAP = {
	club = { { "ga", 120, 170, 520, 400 } },
	theatre = {
		{ "stalls", 170, 150, 420, 300 },
		{ "circle", 100, 150, 60, 320 }, { "circle", 600, 150, 60, 320 }, { "circle", 100, 470, 560, 50 },
		{ "upper", 30, 150, 60, 420 }, { "upper", 670, 150, 60, 420 }, { "upper", 30, 530, 700, 50 },
	},
	arena = {
		{ "golden", 250, 140, 260, 70 }, { "floor", 200, 216, 360, 230 },
		{ "lower", 120, 130, 70, 380 }, { "lower", 570, 130, 70, 380 }, { "lower", 120, 455, 520, 55 },
		{ "upper", 40, 110, 70, 470 }, { "upper", 650, 110, 70, 470 }, { "upper", 40, 520, 680, 60 },
	},
	amphi = {
		{ "pit", 230, 140, 300, 120 }, { "bowl", 130, 270, 500, 170 }, { "bowl", 130, 140, 90, 120 }, { "bowl", 540, 140, 90, 120 },
		{ "lawn", 40, 450, 680, 120 },
	},
	stadium = {
		{ "golden", 260, 130, 240, 60 }, { "field", 190, 196, 380, 250 },
		{ "lower", 110, 110, 70, 400 }, { "lower", 580, 110, 70, 400 }, { "lower", 110, 456, 540, 54 },
		{ "upper", 30, 80, 70, 500 }, { "upper", 660, 80, 70, 500 }, { "upper", 30, 520, 700, 60 },
	},
}
local SEC_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(80, 170, 255), Color3.fromRGB(150, 110, 255), Color3.fromRGB(60, 210, 160), Color3.fromRGB(255, 120, 150) }

-- estimated tickets per section for all shows of a look (with the current prices)
function MapScreen:sectionForecast(look)
	local state, draft = self.app.state, self.draft
	self:syncPrices()
	local d = Sim.demands(state, draft.artistId, draft.shows, 1)
	local sold, cap = {}, {}
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		if Sim.lookOf(v) == look then
			local by = Sim.splitSections(look, v.cap, s.prices, d[i])
			for _, sec in ipairs(Sim.SECTIONS[look]) do
				sold[sec.id] = (sold[sec.id] or 0) + (by[sec.id] or 0)
				cap[sec.id] = (cap[sec.id] or 0) + math.floor(v.cap * sec.share)
			end
		end
	end
	return sold, cap
end

function MapScreen:buildTicketStep(body)
	local state, draft = self.app.state, self.draft
	local ad = Artists.byId[draft.artistId]
	local looks = {}
	for _, lk in ipairs(LOOK_ORDER) do
		for _, s in ipairs(draft.shows) do
			if Sim.lookOf(Countries.venueById[s.venueId]) == lk then
				table.insert(looks, lk)
				break
			end
		end
	end
	local known = false
	for _, lk in ipairs(looks) do
		known = known or lk == self.ticketLook
	end
	if not known then
		self.ticketLook = looks[1]
	end
	local look = self.ticketLook
	local prices = self:pricesFor(look)
	local secs = Sim.SECTIONS[look]
	if not self.ticketSec or not prices[self.ticketSec] then
		self.ticketSec = secs[1].id
	end
	local sold, cap = self:sectionForecast(look)

	-- left: venue type tabs and the seat map
	local left = UI.Panel(body, UI.px(20, 72), UI.px(1000, 928))
	UI.Label(left, "TICKET PRICES", UI.px(28, 16), UI.px(500, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	local x = 28
	for _, lk in ipairs(looks) do
		local w = #LOOK_LABEL[lk] * 11 + 40
		UI.Button(left, LOOK_LABEL[lk], UI.px(x, 58), UI.px(w, 36), { textSize = 14, color = (lk == look) and T.accent or T.panel3 }, function()
			self.ticketLook = lk
			self.ticketSec = nil
			self:refresh()
		end)
		x = x + w + 8
	end
	local map = UI.New("Frame", { Parent = left, Position = UI.px(120, 110), Size = UI.px(760, 600), BackgroundColor3 = Color3.fromRGB(18, 18, 24), BorderSizePixel = 0, UI.Corner(12) })
	local stage = UI.New("TextLabel", { Parent = map, Position = UI.px(200, 30), Size = UI.px(360, 80), BackgroundColor3 = Color3.fromRGB(40, 40, 50), Text = "STAGE", TextColor3 = T.sub, TextSize = 22, Font = UI.FontBlack, BorderSizePixel = 0, UI.Corner(8) })
	local _ = stage
	if look ~= "club" then
		UI.New("TextLabel", { Parent = map, Position = UI.px(120, 4), Size = UI.px(520, 22), BackgroundTransparency = 1, Text = (look == "theatre") and "orchestra pit" or "draped off behind the stage", TextColor3 = T.sub, TextSize = 13, Font = UI.Font })
	end
	local labeled = {}
	for _, sh in ipairs(SEATMAP[look]) do
		local id = sh[1]
		local idx = 1
		for i, sec in ipairs(secs) do
			if sec.id == id then
				idx = i
			end
		end
		local sec = secs[idx]
		local fill = (cap[id] or 0) > 0 and (sold[id] or 0) / cap[id] or 0
		local base = SEC_COLORS[idx]
		local selected = id == self.ticketSec
		local col = base:Lerp(Color3.new(0, 0, 0), 0.55 - 0.45 * math.clamp(fill, 0, 1))
		local b = UI.Button(map, "", UI.px(sh[2], sh[3]), UI.px(sh[4], sh[5]), { color = col }, function()
			self.ticketSec = id
			self:refresh()
		end)
		if selected then
			UI.Stroke(Color3.new(1, 1, 1), 3, 0).Parent = b
		end
		if not labeled[id] and sh[4] > 150 then
			labeled[id] = true
			UI.Label(b, string.upper(sec.name) .. "\n" .. Util.money(prices[id]) .. "\n~" .. math.floor(fill * 100 + 0.5) .. "% sold", UI.px(0, 0), UI.px(sh[4], sh[5]), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Center, color = Color3.new(1, 1, 1) })
		end
	end
	UI.Label(left, "Colours get brighter the more tickets are expected to sell. Click a section to set its price.", UI.px(28, 724), UI.px(940, 24), { textSize = 15, color = T.sub })
	UI.Button(left, "< Back to the stage", UI.px(28, 846), UI.px(300, 60), {}, function()
		self:setStep(3)
	end)

	-- right: the sections with prices
	local right = UI.Panel(body, UI.px(1040, 72), UI.px(860, 928))
	UI.Label(right, LOOK_LABEL[look] .. " - PRICE PER SECTION", UI.px(28, 18), UI.px(800, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Label(right, "The same prices go for all " .. string.lower(LOOK_LABEL[look]) .. " on this tour. Fans in expensive countries accept higher prices. Promoter suggests about " .. Util.money(Util.round(Sim.ticketBase(state, ad.id))) .. " as a base price for " .. ad.name .. ".", UI.px(28, 52), UI.px(800, 46), { textSize = 15, color = T.sub, wrap = true })
	local y = 112
	for i, sec in ipairs(secs) do
		local sel = sec.id == self.ticketSec
		local row = UI.New("Frame", { Parent = right, Position = UI.px(20, y), Size = UI.px(820, 92), BackgroundColor3 = sel and UI.shade(T.accent, 0.45) or T.panel2, BorderSizePixel = 0, UI.Corner(10) })
		UI.New("Frame", { Parent = row, Size = UI.px(10, 92), BackgroundColor3 = SEC_COLORS[i], BorderSizePixel = 0 })
		local fill = (cap[sec.id] or 0) > 0 and (sold[sec.id] or 0) / cap[sec.id] or 0
		UI.Label(row, sec.name, UI.px(24, 8), UI.px(330, 28), { textSize = 20, font = UI.FontBold })
		UI.Label(row, (sec.standing and "standing" or "seated") .. "  |  " .. math.floor(sec.share * 100 + 0.5) .. "% of the venue  |  ~" .. Util.number(sold[sec.id] or 0) .. " of " .. Util.number(cap[sec.id] or 0) .. " sold", UI.px(24, 40), UI.px(470, 22), { textSize = 14, color = T.sub })
		local fc = fill > 0.9 and T.good or (fill > 0.6 and T.warn or T.bad)
		UI.Bar(row, UI.px(24, 68), UI.px(440, 10), fill, fc)
		for k, dv in ipairs({ -5, -1, 1, 5 }) do
			local bx = (k <= 2) and (500 + (k - 1) * 52) or (720 + (k - 3) * 52)
			UI.Button(row, (dv > 0 and "+" or "") .. dv, UI.px(bx, 22), UI.px(46, 48), { textSize = 15 }, function()
				prices[sec.id] = math.clamp(prices[sec.id] + dv, 5, 4000)
				self.ticketSec = sec.id
				self:refresh()
			end)
		end
		UI.Label(row, Util.money(prices[sec.id]), UI.px(604, 22), UI.px(110, 48), { textSize = 22, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
		y = y + 100
	end
	local est = self:estimate()
	local lines = {
		string.format("Shows: <b>%d</b>    Seats: <b>%s</b>    Average ticket here: <b>%s</b>", #draft.shows, Util.number(est.capacity), Util.money(Sim.avgPrice(look, prices))),
		"Promoter estimate, gross (whole tour): <b>" .. Util.money(est.grossLow or 0) .. " - " .. Util.money(est.grossHigh or 0) .. "</b>",
		"Costs (venues, production, travel, artist share): about <b>" .. Util.money(est.costs) .. "</b>",
		"<font color='#9696b2'>Estimates can be wrong. You see the real sales once the tour is announced.</font>",
	}
	UI.Label(right, table.concat(lines, "\n"), UI.px(28, y + 10), UI.px(800, 130), { textSize = 16, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(right, "NEXT: CONFIRM >", UI.px(520, 846), UI.px(312, 60), { color = T.accent, textSize = 18 }, function()
		self:setStep(5)
	end)
end

------------------------------------------------------------------ step 5: confirm
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
	self:syncPrices()
	local lo, hi = math.huge, 0
	for _, s in ipairs(draft.shows) do
		for _, p in pairs(s.prices) do
			lo, hi = math.min(lo, p), math.max(hi, p)
		end
	end
	UI.Label(panel, ad.name .. "   |   " .. #draft.shows .. " shows   |   tickets " .. Util.money(lo) .. " - " .. Util.money(hi) .. "   |   Stage: " .. table.concat(prodNames, " / "), UI.px(760, 42), UI.px(1100, 54), { textSize = 19, color = T.sub })
	UI.Button(panel, (draft.watchFirst and "[X]" or "[  ]") .. "  Watch the opening night live in 3D", UI.px(760, 92), UI.px(500, 36), { color = T.panel2, textSize = 15 }, function()
		draft.watchFirst = not draft.watchFirst
		self:refresh()
	end)

	local headers = { { "#", 28 }, { "DATE", 70 }, { "VENUE", 200 }, { "SEATS", 860 }, { "PROMOTER ESTIMATE", 1040 } }
	for _, h in ipairs(headers) do
		UI.Label(panel, h[1], UI.px(h[2], 116), UI.px(300, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local list = UI.Scroll(panel, UI.px(16, 140), UI.px(1848, 560))
	UI.List(true, 4).Parent = list
	local days = self:showDays()
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local r = est.rows[i]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(1828, 44), BackgroundColor3 = (i % 2 == 0) and T.panel2 or T.panel3, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(6) })
		local _, dateShort = Util.date(days[i], Config.START_YEAR)
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
		self:setStep(4)
	end)
	UI.Button(panel, "ANNOUNCE TOUR", UI.px(1452, 846), UI.px(400, 60), { color = T.accent, textSize = 24 }, function()
		self:syncPrices()
		local ok, res = GS.createTour(state, draft)
		if not ok then
			self.app:toast(res, T.bad)
			return
		end
		self.app:toast("<b>" .. UI.esc(res.name) .. "</b> is announced! Tickets are on sale now.", T.good, 8)
		self.draft = { artistId = nil, name = "", designs = draft.designs, firstIn = 21, gap = 2, watchFirst = true, price = 30, prices = {}, shows = {} }
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
	elseif self.step >= 4 and not self:stagesReady() then
		self.step = 3
	end
	self:refreshStepBar()
	UI.ClearChildren(self.body)
	self.routeView.Visible = self.step == 2
	self.mapMask.Visible = self.step == 2
	if self.step ~= 2 then
		self:deactivateMap()
	end
	if self.step == 1 then
		self:buildArtistStep(self.body)
	elseif self.step == 2 then
		self:refreshRoute()
	elseif self.step == 3 then
		self:buildStageStep(self.body)
	elseif self.step == 4 then
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
	self.legend.Text = "Fans of <b>" .. Artists.byId[aid].name .. "</b>:  <font color='#9646af'>very few</font>  <font color='#eb4646'>few</font>  <font color='#ff9628'>some</font>  <font color='#ffe13c'>good</font>  <font color='#a0eb5a'>many</font>  <font color='#28dc78'>huge</font>"
	self:refreshCountry()
	self:refreshRoutePanel()
end

return MapScreen
