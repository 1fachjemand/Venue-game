-- PLAN A TOUR (at the world map table): one clean screen per step:
-- 1 artist -> 2 country (world map) -> 3 venue -> 4 date (calendar) -> 5 ticket prices -> 6 confirm.
-- A tour can have many shows: after a date, "+ ADD ANOTHER SHOW" goes back to the map.
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
local STEPS = { "ARTIST", "COUNTRY", "VENUE", "DATE", "TICKETS", "CONFIRM" }
local STEP_TITLE = { "Who goes on tour?", "Where? Pick a country", "Which venue?", "When? Pick a date", "Ticket prices", "Check & announce" }

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
	-- in step 2 the 3D map shows through the map window: dark cover around it
	self.mapMask = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "MapMask" })
	for _, r in ipairs({ { -3000, -200, 7920, 270 }, { -3000, 70, 3020, 930 }, { 1900, 70, 3000, 930 }, { -3000, 1000, 7920, 3000 } }) do
		UI.New("Frame", { Parent = self.mapMask, Position = UI.px(r[1], r[2]), Size = UI.px(r[3], r[4]), BackgroundColor3 = T.bg, BorderSizePixel = 0 })
	end
	self.header = UI.New("Frame", { Parent = self.frame, Position = UI.px(0, 0), Size = UI.px(1920, 66), BackgroundTransparency = 1, ZIndex = 5 })
	self.draft = { artistId = nil, name = "", designs = {}, firstIn = 21, gap = 2, price = 30, prices = {}, shows = {} }
	-- step 2 keeps its map alive between visits; the other steps are rebuilt
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
	local state = self.app.state
	local open, total = 0, #c.venues
	local minC, maxC = math.huge, 0
	for _, v in ipairs(c.venues) do
		minC, maxC = math.min(minC, v.cap), math.max(maxC, v.cap)
		if GS.venueUnlocked(state, v) then
			open = open + 1
		end
	end
	local txt = "<b>" .. c.name .. "</b>   " .. total .. " venues (" .. Util.number(minC) .. " - " .. Util.number(maxC) .. " seats), " .. open .. " open for your level"
	local aid = self.draft.artistId
	if aid then
		local tip, pool = Sim.recommendation(state, aid, cid)
		txt = txt .. "\n~" .. Util.short(pool) .. " fans of " .. Artists.byId[aid].name .. "  ·  Promoter tip: " .. tip
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

------------------------------------------------------------------ step 2: country (the world map, full screen)
local MAP_X, MAP_Y, MAP_W, MAP_H = 20, 70, 1880, 930
function MapScreen:buildMap()
	local view = UI.New("Frame", { Parent = self.routeView, Position = UI.px(MAP_X, MAP_Y), Size = UI.px(MAP_W, MAP_H), BackgroundTransparency = 1, Name = "MapView" })
	self.mapView = view
	local bar = UI.Panel(view, UI.px(0, 0), UI.px(MAP_W, 56), T.panel)
	bar.BackgroundTransparency = 0.15
	self.mapBar = bar
	local x = 14
	for _, v in ipairs(VIEWS) do
		local w = #v[1] * 9 + 30
		UI.Button(bar, v[1], UI.px(x, 10), UI.px(w, 36), { textSize = 14 }, function()
			WorldMap3D.flyTo(v[2], v[3], v[4] * 1.7)
		end)
		x = x + w + 8
	end
	UI.Label(bar, "Click a country.  Drag = move,  wheel = zoom.", UI.px(x + 20, 10), UI.px(MAP_W - x - 40, 36), { textSize = 15, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local legendBox = UI.Panel(view, UI.px(0, MAP_H - 40), UI.px(MAP_W, 40), T.panel)
	legendBox.BackgroundTransparency = 0.15
	self.legendBox = legendBox
	self.legend = UI.Label(legendBox, "", UI.px(14, 0), UI.px(MAP_W - 28, 40), { textSize = 15, color = T.sub, rich = true })
	self.hoverBox = UI.New("TextLabel", {
		Parent = view,
		Position = UI.px(14, 70),
		Size = UI.px(560, 0),
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
	-- the shows booked so far (bottom right), with the way on to the ticket prices
	self.routeBox = UI.Panel(view, UI.px(MAP_W - 470, MAP_H - 300), UI.px(460, 250), T.panel)
	self.routeBox.BackgroundTransparency = 0.08
end

-- the 3D map only reacts inside its window (and not under the panels on it)
function MapScreen:overUI()
	if self.app.modalOpen then
		return true
	end
	local m = UserInputService:GetMouseLocation()
	local a, sz = self.mapView.AbsolutePosition, self.mapView.AbsoluteSize
	if m.X < a.X or m.X > a.X + sz.X or m.Y < a.Y or m.Y > a.Y + sz.Y then
		return true
	end
	for _, p in ipairs({ self.mapBar, self.legendBox, self.hoverBox, self.routeBox }) do
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
			self:pickCountry(cid)
		end,
		onHover = function(cid)
			self:hoverCountry(cid)
		end,
		maxDist = 1000,
		screenCenter = function()
			local a, sz = self.mapView.AbsolutePosition, self.mapView.AbsoluteSize
			return a.X + sz.X / 2, a.Y + sz.Y / 2
		end,
	})
	if not self.mapOpened then
		self.mapOpened = true
		WorldMap3D.flyTo(VIEWS[2][2], VIEWS[2][3], VIEWS[2][4] * 1.7)
	end
end

function MapScreen:pickCountry(cid)
	self.selected = cid
	self.picked = nil
	self:setStep(3)
end

-- list of the booked shows (used on the map and in the calendar step)
function MapScreen:fillRouteList(parent, w, h)
	local draft = self.draft
	local list = UI.Scroll(parent, UI.px(12, 46), UI.px(w - 24, h - 56))
	UI.List(true, 4).Parent = list
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local _, dshort = Util.date(s.day, Config.START_YEAR)
		local row = UI.New("Frame", { Parent = list, Size = UI.px(w - 44, 30), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(6) })
		UI.Label(row, i .. ".  " .. dshort .. "   " .. v.city .. "  ·  " .. v.name, UI.px(10, 0), UI.px(w - 64, 30), { textSize = 14 })
	end
end

function MapScreen:refreshRouteBox()
	local p = self.routeBox
	UI.ClearChildren(p)
	local n = #self.draft.shows
	p.Visible = n > 0
	if n == 0 then
		return
	end
	UI.Label(p, "YOUR TOUR: " .. n .. " SHOW" .. (n == 1 and "" or "S"), UI.px(14, 10), UI.px(300, 28), { textSize = 18, font = UI.FontBlack, color = T.accent2 })
	self:fillRouteList(p, 460, 180)
	UI.Button(p, "DONE: TICKET PRICES >", UI.px(12, 190), UI.px(436, 48), { color = T.accent, textSize = 17 }, function()
		self:setStep(5)
	end)
	-- the route list is shorter here
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("ScrollingFrame") then
			c.Size = UI.px(436, 138)
		end
	end
end

------------------------------------------------------------------ step 3: venue (only the venues your level can book)
function MapScreen:buildVenueStep(body)
	local state, aid = self.app.state, self.draft.artistId
	local c = Countries.byId[self.selected or ""]
	if not c then
		self:setStep(2)
		return
	end
	local tip, pool = Sim.recommendation(state, aid, c.id)
	local panel = UI.Panel(body, UI.px(20, 70), UI.px(1880, 930))
	UI.Label(panel, string.upper(c.name), UI.px(28, 16), UI.px(900, 44), { textSize = 34, font = UI.FontBlack })
	local last = state.artists[aid].lastPlayed[c.id]
	UI.Label(panel, "~" .. Util.short(pool) .. " fans of " .. Artists.byId[aid].name .. " here.   Promoter tip: <b>" .. tip .. "</b>" .. ((last and state.day - last < 180) and "   <font color='#ffc107'>played here recently</font>" or ""), UI.px(28, 62), UI.px(1500, 26), { textSize = 17, color = T.sub, rich = true })
	local lvl = GS.level(state)
	UI.Label(panel, "Your label is level " .. lvl .. ". Grey venues open at a higher level.", UI.px(28, 92), UI.px(1500, 24), { textSize = 15, color = T.sub })
	local list = UI.Scroll(panel, UI.px(16, 128), UI.px(1848, 790))
	UI.List(true, 8).Parent = list
	local venues = {}
	for _, v in ipairs(c.venues) do
		table.insert(venues, v)
	end
	table.sort(venues, function(a, b)
		return a.cap < b.cap
	end)
	for i, v in ipairs(venues) do
		local vt = Countries.VENUE_TYPES[v.type]
		local open = GS.venueUnlocked(state, v)
		local row = UI.New("Frame", { Parent = list, Size = UI.px(1820, 84), BackgroundColor3 = open and T.panel2 or T.panel, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(10) })
		local pill = UI.Pill(row, vt.label, UI.px(16, 28), UI.px(110, 28), open and UI.rgb(vt.color) or T.panel3, 13)
		local _ = pill
		UI.Label(row, (open and "" or "🔒  ") .. v.name, UI.px(146, 10), UI.px(700, 34), { textSize = 24, font = UI.FontBold, color = open and T.text or T.sub })
		UI.Label(row, v.city .. "   ·   " .. Util.number(v.cap) .. " seats   ·   rent " .. Util.moneyShort(Sim.venueRent(v)), UI.px(146, 46), UI.px(700, 26), { textSize = 16, color = T.sub })
		if open then
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
			UI.Label(row, "Expected: " .. rangeText(lo, hi) .. (lo < 0.999 and " full" or ""), UI.px(900, 0), UI.px(560, 84), { textSize = 18, color = rangeColor(lo, hi), font = UI.FontBold })
			UI.Button(row, "PICK  >", UI.px(1600, 16), UI.px(200, 52), { color = T.accent, textSize = 18 }, function()
				self.picked = v.id
				local lastS = self.draft.shows[#self.draft.shows]
				local from = lastS and lastS.day or (state.day + 21)
				local y, m = Util.ymd(from, Config.START_YEAR)
				self.calMonth = { y, m }
				self:setStep(4)
			end)
		else
			UI.Label(row, "Needs label level " .. GS.venueLevel(v) .. " (" .. Config.LEVELS[GS.venueLevel(v)].name .. ")", UI.px(900, 0), UI.px(880, 84), { textSize = 18, color = T.sub, font = UI.FontBold })
		end
	end
end

------------------------------------------------------------------ step 4: date (the calendar on its own)
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

function MapScreen:buildDateStep()
	local p = UI.Panel(self.body, UI.px(20, 70), UI.px(1880, 930))
	local state, draft = self.app.state, self.draft
	local W = 1880
	if not self.calMonth then
		local first = draft.shows[1]
		local y, m = Util.ymd(first and first.day or (state.day + 21), Config.START_YEAR)
		self.calMonth = { y, m }
	end
	local y, m = self.calMonth[1], self.calMonth[2]
	UI.Button(p, "<", UI.px(260, 10), UI.px(48, 40), { textSize = 20 }, function()
		m = m - 1
		if m < 1 then
			m, y = 12, y - 1
		end
		self.calMonth = { y, m }
		self:refresh()
	end)
	UI.Label(p, Util.monthName(m) .. " " .. y, UI.px(314, 10), UI.px(220, 40), { textSize = 24, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
	UI.Button(p, ">", UI.px(540, 10), UI.px(48, 40), { textSize = 20 }, function()
		m = m + 1
		if m > 12 then
			m, y = 1, y + 1
		end
		self.calMonth = { y, m }
		self:refresh()
	end)
	local pv = self.picked and Countries.venueById[self.picked]
	local hint = pv and ("<b>" .. pv.name .. ", " .. pv.city .. "</b> (" .. Util.number(pv.cap) .. " seats): click a green day to play there. Click more days for more nights. Click one of your shows to remove it.")
		or "Pick a venue first."
	UI.Label(p, hint, UI.px(610, 8), UI.px(W - 630, 46), { textSize = 16, color = pv and T.text or T.sub, rich = true, wrap = true })
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
			self:refresh()
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
	UI.Button(p, "+ ADD ANOTHER SHOW", UI.px(W - 700, 846), UI.px(330, 60), { textSize = 18, disabled = #draft.shows == 0 }, function()
		self:setStep(2)
	end)
	UI.Button(p, "NEXT: TICKET PRICES >", UI.px(W - 350, 846), UI.px(330, 60), { color = T.accent, textSize = 18, disabled = #draft.shows == 0 }, function()
		self:setStep(5)
	end)
end

------------------------------------------------------------------ step 1: artist
function MapScreen:buildArtistStep(body)
	local state = self.app.state
	UI.Label(body, "Pick one of your artists. Artists who are already on tour can't start a new one.", UI.px(40, 90), UI.px(1400, 26), { textSize = 18, color = T.sub })
	local grid = UI.Scroll(body, UI.px(40, 170), UI.px(1840, 830))
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

------------------------------------------------------------------ step 5: tickets (seat map like a ticket shop)
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
	local left = UI.Panel(body, UI.px(20, 70), UI.px(1000, 930))
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

	-- right: the sections with prices
	local right = UI.Panel(body, UI.px(1040, 70), UI.px(860, 930))
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
		self:setStep(6)
	end)
end

------------------------------------------------------------------ step 6: confirm (the stage is picked automatically, you can change it)
function MapScreen:buildConfirmStep(body)
	local state, draft = self.app.state, self.draft
	local ad = Artists.byId[draft.artistId]
	local est = self:estimate()
	local prodNames = {}
	for _, need in ipairs(self:classesNeeded()) do
		local d = self:designForClass(need.class)
		table.insert(prodNames, d and d.name or "?")
	end
	local panel = UI.Panel(body, UI.px(20, 70), UI.px(1880, 930))
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
	UI.Label(panel, ad.name .. "   |   " .. #draft.shows .. " shows   |   tickets " .. Util.money(lo) .. " - " .. Util.money(hi), UI.px(760, 42), UI.px(1100, 54), { textSize = 19, color = T.sub })
	-- stage per venue size: picked automatically, a click shows the next one that fits
	local sx = 760
	UI.Label(panel, "STAGE:", UI.px(sx, 96), UI.px(80, 34), { textSize = 15, color = T.sub, font = UI.FontBold })
	sx = sx + 80
	for _, need in ipairs(self:classesNeeded()) do
		local d = self:designForClass(need.class)
		local fits = self:fittingDesigns(need.class)
		local label = need.class .. ": " .. (d and d.name or "none") .. ((#fits > 1) and "  ▸" or "")
		local w = math.min(420, #label * 9 + 30)
		UI.Button(panel, label, UI.px(sx, 94), UI.px(w, 36), { textSize = 14, color = d and T.panel3 or UI.shade(T.bad, 0.5), disabled = #fits < 2 }, function()
			local idx = 1
			for k, f in ipairs(fits) do
				if f == d then
					idx = k
				end
			end
			draft.designs[need.class] = fits[idx % #fits + 1].id
			self:refresh()
		end)
		sx = sx + w + 8
	end

	local headers = { { "#", 28 }, { "DATE", 70 }, { "VENUE", 200 }, { "SEATS", 860 }, { "PROMOTER ESTIMATE", 1040 } }
	for _, h in ipairs(headers) do
		UI.Label(panel, h[1], UI.px(h[2], 156), UI.px(300, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local list = UI.Scroll(panel, UI.px(16, 180), UI.px(1848, 520))
	-- (stages are built in the STAGE HALL; here the best fitting one is used)
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
		"<font color='#9696b2'>The promoter can be wrong. Once announced, watch the real pre-sale on the LAPTOP and react with marketing or price changes.</font>",
	}
	UI.Label(panel, table.concat(lines, "\n"), UI.px(28, 716), UI.px(1820, 100), { textSize = 18, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(panel, "ANNOUNCE TOUR", UI.px(1452, 846), UI.px(400, 60), { color = T.accent, textSize = 24 }, function()
		self:syncPrices()
		local ok, msg, data = self.app:act("createTour", { draft = draft })
		if not ok then
			self.app:toast(msg or "Could not announce the tour.", T.bad)
			return
		end
		local res = GS.getTour(state, data.tourId)
		self.app:toast("<b>" .. UI.esc(res.name) .. "</b> is announced! Tickets are on sale now.", T.good, 8)
		self.draft = { artistId = nil, name = "", designs = draft.designs, firstIn = 21, gap = 2, price = 30, prices = {}, shows = {} }
		self.step = 1
		self.selected, self.picked = nil, nil
		self.app:go("tours", { tourId = res.id })
	end)
end

------------------------------------------------------------------ header: back, step x of 6, progress
function MapScreen:availableArtists()
	local out = {}
	for _, ad in ipairs(GS.signedArtists(self.app.state)) do
		if not GS.activeTour(self.app.state, ad.id) then
			table.insert(out, ad)
		end
	end
	return out
end

function MapScreen:back()
	local s = self.step
	if s == 2 and #self:availableArtists() <= 1 then
		self.app:closeScreen()
		return
	end
	if s == 5 then
		-- back to the calendar of the last venue
		local last = self.draft.shows[#self.draft.shows]
		if last then
			self.picked = last.venueId
			self.selected = Countries.venueById[last.venueId].countryId
		end
		self:setStep(self.picked and 4 or 2)
		return
	end
	if s <= 1 then
		self.app:closeScreen()
		return
	end
	self:setStep(s - 1)
end

function MapScreen:refreshHeader()
	local h = self.header
	UI.ClearChildren(h)
	UI.Button(h, "<  BACK", UI.px(20, 8), UI.px(150, 50), { textSize = 18 }, function()
		self:back()
	end)
	UI.Label(h, "STEP " .. self.step .. " OF 6", UI.px(196, 6), UI.px(220, 24), { textSize = 16, color = T.accent2, font = UI.FontBlack })
	UI.Label(h, STEP_TITLE[self.step], UI.px(196, 28), UI.px(900, 34), { textSize = 28, font = UI.FontBlack })
	for i, name in ipairs(STEPS) do
		local done, active = i < self.step, i == self.step
		local x = 1100 + (i - 1) * 134
		UI.New("Frame", { Parent = h, Position = UI.px(x, 14), Size = UI.px(126, 8), BackgroundColor3 = active and T.accent or (done and T.accent2 or T.panel3), BorderSizePixel = 0, UI.Corner(4) })
		UI.Label(h, name, UI.px(x, 26), UI.px(126, 24), { textSize = 13, font = UI.FontBold, color = active and T.text or (done and T.accent2 or T.sub), alignX = Enum.TextXAlignment.Center })
	end
	local n = #self.draft.shows
	if n > 0 and self.step ~= 2 then
		UI.Label(h, n .. " show" .. (n == 1 and "" or "s") .. " booked", UI.px(900, 28), UI.px(180, 30), { textSize = 15, color = T.sub, alignX = Enum.TextXAlignment.Right })
	end
end

function MapScreen:setStep(i)
	self.step = i
	self:refresh()
end

------------------------------------------------------------------ refresh
function MapScreen:show(args)
	if args and args.artistId then
		self:setArtist(args.artistId)
		self.step = 2
	end
	-- only one artist can tour: skip the artist step
	local avail = self:availableArtists()
	if self.step == 1 and #avail == 1 then
		self:setArtist(avail[1].id)
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
	elseif self.step == 3 and not self.selected then
		self.step = 2
	elseif self.step == 4 and not self.picked then
		self.step = (self.selected and 3) or 2
	elseif self.step >= 5 and #self.draft.shows == 0 then
		self.step = 2
	end
	self:refreshHeader()
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
		self:buildVenueStep(self.body)
	elseif self.step == 4 then
		self:buildDateStep()
	elseif self.step == 5 then
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
	self:refreshRouteBox()
end

return MapScreen
