-- TOUR PLANNER (an app on the laptop): one thing after the other.
-- 1 Artist  ->  2 Shows (map -> venues of a country -> date)  ->  3 Tickets  ->  4 Stage  ->  5 Announce
-- The plan lives on the server (state.draft, action setDraft) so it survives closing the laptop.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)
local SoundFX = require(Root.Client.SoundFX)
local Map2D = require(Root.Client.Map2D)
local VenueModels = require(Root.Client.VenueModels)

local T = UI.Theme
local TP = {}
TP.__index = TP

local W, H = 1920, 1008
local STEPS = { "Artist", "Shows", "Tickets", "Stage", "Announce" }
-- a tour is planned in the rooms of the label, one after the other:
-- the artist in the MEETING ROOM, the shows at the WORLD MAP table, tickets / stage / announce on the LAPTOP
local STEP_PLACE = { "meeting", "maptable", "laptop", "laptop", "laptop" }
local PLACE_NAME = { meeting = "Meeting room", maptable = "Map table", laptop = "Laptop" }
local PLACE_LONG = { meeting = "MEETING ROOM", maptable = "WORLD MAP table", laptop = "LAPTOP" }
local CLASS_ORDER = { "Club", "Theatre", "Arena", "Stadium" }
local CLASS_TITLE = { Club = "CLUBS", Theatre = "THEATRES & HALLS", Arena = "ARENAS & AMPHITHEATRES", Stadium = "STADIUMS" }
local LOOK_LABEL = { club = "CLUBS", theatre = "THEATRES & HALLS", arena = "ARENAS", amphi = "AMPHITHEATRES", stadium = "STADIUMS" }
local LOOK_ORDER = { "club", "theatre", "amphi", "arena", "stadium" }

-- fans of the artist in a country (dot on the map)
local function heatColor(pool)
	if pool < 300 then
		return Color3.fromRGB(190, 190, 200)
	elseif pool < 1500 then
		return Color3.fromRGB(239, 68, 68)
	elseif pool < 6000 then
		return Color3.fromRGB(249, 115, 22)
	elseif pool < 20000 then
		return Color3.fromRGB(234, 179, 8)
	elseif pool < 60000 then
		return Color3.fromRGB(132, 204, 22)
	end
	return Color3.fromRGB(22, 163, 74)
end
local function rangeText(lo, hi)
	if lo >= 0.98 then
		return "sells out"
	elseif hi >= 0.98 then
		return Util.percent(lo) .. " full, maybe sold out"
	end
	return Util.percent(lo) .. " - " .. Util.percent(hi) .. " full"
end
local function rangeColor(lo, hi)
	local mid = (lo + hi) / 2
	if lo >= 0.999 or mid > 0.75 then
		return T.good
	elseif mid > 0.45 then
		return T.warn
	end
	return T.bad
end

function TP.new(app, parent)
	local self = setmetatable({ app = app, step = 1, sub = "map", filter = { Club = true, Theatre = true, Arena = true, Stadium = true } }, TP)
	self.frame = UI.New("Frame", { Parent = parent or app.content, Name = "TourPlanner", Size = UI.px(W, H), BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false })
	self.header = UI.New("Frame", { Parent = self.frame, Size = UI.px(W, 92), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	UI.New("Frame", { Parent = self.header, Position = UI.px(0, 91), Size = UI.px(W, 1), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	self.body = UI.New("Frame", { Parent = self.frame, Position = UI.px(0, 92), Size = UI.px(W, H - 92 - 84), BackgroundTransparency = 1 })
	self.footer = UI.New("Frame", { Parent = self.frame, Position = UI.px(0, H - 84), Size = UI.px(W, 84), BackgroundColor3 = T.panel, BorderSizePixel = 0 })
	UI.New("Frame", { Parent = self.footer, Size = UI.px(W, 1), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	self.overlay = UI.New("Frame", { Parent = self.frame, Size = UI.px(W, H), BackgroundTransparency = 1, Visible = false, ZIndex = 20 })
	self.draft = { shows = {}, prices = {}, designs = {} }
	return self
end

------------------------------------------------------------------ the plan in the server state
function TP:syncDraft()
	local state = self.app.state
	state.draft = state.draft or {}
	local d = state.draft
	d.shows = d.shows or {}
	d.prices = d.prices or {}
	d.designs = d.designs or {}
	if d.artistId and not d.price then
		d.price = math.max(5, Util.round(Sim.ticketBase(state, d.artistId)))
	end
	if d.artistId and not d.name then
		d.name = Artists.byId[d.artistId].name .. " Live " .. (Config.START_YEAR + math.floor(state.day / 365))
	end
	self.draft = d
end

function TP:saveDraft()
	self.app:act("setDraft", { draft = self.draft })
	self:syncDraft()
end

function TP:pricesFor(look)
	local draft = self.draft
	draft.prices = draft.prices or {}
	if not draft.prices[look] then
		draft.prices[look] = Sim.defaultPrices(draft.price, look)
	end
	return draft.prices[look]
end

function TP:syncPrices()
	for _, s in ipairs(self.draft.shows) do
		local look = Sim.lookOf(Countries.venueById[s.venueId])
		s.prices = self:pricesFor(look)
		s.price = Sim.avgPrice(look, s.prices)
	end
end

function TP:sortShows()
	table.sort(self.draft.shows, function(a, b)
		return (a.day or 0) < (b.day or 0)
	end)
end

-- venue sizes on the route, small to big: { {class=, shows=n, cities={}} }
function TP:classesNeeded()
	local by = {}
	for _, s in ipairs(self.draft.shows) do
		local v = Countries.venueById[s.venueId]
		local c = GS.venueClass(v)
		by[c] = by[c] or { class = c, shows = 0, cities = {} }
		by[c].shows = by[c].shows + 1
		table.insert(by[c].cities, v.city)
	end
	local out = {}
	for _, c in ipairs(CLASS_ORDER) do
		if by[c] then
			table.insert(out, by[c])
		end
	end
	return out
end

-- stages that fit venues of a class (a smaller stage fits a bigger venue), biggest first
function TP:fittingDesigns(vclass)
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

-- the stage chosen for a venue size (nil if none was selected yet)
function TP:chosenDesign(vclass)
	local id = (self.draft.designs or {})[vclass]
	local d = id and GS.getDesign(self.app.state, id)
	if d then
		for _, f in ipairs(self:fittingDesigns(vclass)) do
			if f == d then
				return d
			end
		end
	end
	return nil
end

function TP:designFor(v)
	local c = GS.venueClass(v)
	return self:chosenDesign(c) or self:fittingDesigns(c)[1]
end

function TP:estimate()
	self:syncPrices()
	return Sim.estimate(self.app.state, self.draft, function(v)
		return self:designFor(v)
	end)
end

-- how far the plan is: 1 artist .. 5 announce (the highest step you may open)
function TP:reachable()
	local d = self.draft
	if not d.artistId then
		return 1
	elseif #d.shows == 0 then
		return 2
	elseif not d.pricesSet then
		return 3
	elseif not d.stageSet then
		return 4
	end
	return 5
end

------------------------------------------------------------------ header and footer
function TP:buildHeader()
	local h = self.header
	UI.ClearChildren(h)
	UI.Label(h, "Tour Planner", UI.px(32, 14), UI.px(400, 36), { textSize = 30, font = UI.FontBlack })
	local ad = self.draft.artistId and Artists.byId[self.draft.artistId]
	UI.Label(h, ad and (ad.name .. "  |  " .. #self.draft.shows .. " show" .. (#self.draft.shows == 1 and "" or "s")) or "Plan a new tour, step by step", UI.px(32, 52), UI.px(500, 24), { textSize = 16, color = T.sub })
	local reach = self:reachable()
	local place = self:place()
	for i, name in ipairs(STEPS) do
		local x = 640 + (i - 1) * 252
		local done = i < reach
		local here = STEP_PLACE[i] == place
		local open = i <= reach and here
		local active = i == self.step and open
		local b = UI.Button(h, "", UI.px(x, 18), UI.px(240, 56), { color = active and T.accent or (done and Color3.fromRGB(220, 242, 228) or T.panel2), radius = 28 }, function()
			if not here then
				self.app:toast(name .. ": at the <b>" .. PLACE_LONG[STEP_PLACE[i]] .. "</b>.", T.accent2)
			elseif open then
				self:go(i)
			end
		end)
		if not open and not done then
			b.BackgroundColor3 = T.panel2
		end
		b.Name = "Step" .. i
		local fg = active and Color3.new(1, 1, 1) or (open and T.text or T.sub)
		UI.Label(b, tostring(i), UI.px(10, 10), UI.px(36, 36), { textSize = 18, font = UI.FontBlack, color = active and T.accent or Color3.new(1, 1, 1), alignX = Enum.TextXAlignment.Center, bg = active and Color3.new(1, 1, 1) or (done and T.good or Color3.fromRGB(180, 186, 196)) }).ZIndex = 2
		for _, c in ipairs(b:GetChildren()) do
			if c:IsA("TextLabel") then
				UI.Corner(18).Parent = c
			end
		end
		UI.Label(b, name, UI.px(56, 6), UI.px(170, 26), { textSize = 19, font = UI.FontBold, color = fg })
		UI.Label(b, PLACE_NAME[STEP_PLACE[i]], UI.px(56, 30), UI.px(170, 18), { textSize = 12, color = active and Color3.fromRGB(220, 230, 255) or T.sub })
	end
end

function TP:buildFooter(backText, onBack, nextText, onNext, nextEnabled, hint)
	local f = self.footer
	UI.ClearChildren(f)
	UI.New("Frame", { Parent = f, Size = UI.px(W, 1), BackgroundColor3 = T.stroke, BorderSizePixel = 0 })
	if onBack then
		UI.Button(f, backText or "< Back", UI.px(32, 16), UI.px(200, 52), { textSize = 18 }, onBack)
	end
	if hint then
		UI.Label(f, hint, UI.px(260, 0), UI.px(1100, 84), { textSize = 17, color = T.sub, rich = true })
	end
	if onNext then
		local b = UI.Button(f, nextText, UI.px(W - 32 - 400, 14), UI.px(400, 56), { color = T.accent, textSize = 20, disabled = not nextEnabled }, onNext)
		b.Name = "NextButton"
	end
end

-- where this planner is open: at the world map table or on the laptop
function TP:place()
	local app = self.app
	if app.station == "maptable" and app.content and self.frame.Parent == app.content then
		return "maptable"
	end
	return "laptop"
end

-- the first / last step that belongs to this place
function TP:stepRange()
	if self:place() == "maptable" then
		return 2, 2
	end
	return 3, 5
end

-- a step of another room: say where to go (with a button that takes you on your way)
function TP:buildElsewhere(target, title, text)
	local body = self.body
	local card = UI.Panel(body, UI.px(460, 150), UI.px(1000, 420), T.panel)
	UI.Label(card, title, UI.px(48, 48), UI.px(904, 44), { textSize = 32, font = UI.FontBlack })
	UI.Label(card, text, UI.px(48, 110), UI.px(904, 120), { textSize = 19, color = T.sub, wrap = true, rich = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(card, "Go to the " .. PLACE_LONG[target] .. "  >", UI.px(48, 300), UI.px(420, 64), { color = T.accent, textSize = 20 }, function()
		self:leaveTo(target)
	end).Name = "GoElsewhere"
	self:buildFooter(nil, nil, nil, nil, false, nil)
end

-- close this screen / the laptop and walk to the next room (the arrow shows the way)
function TP:leaveTo(target, msg)
	local app = self.app
	if app.mode == "laptop" then
		app:closeLaptop()
	elseif app.mode == "menu" then
		app:closeScreen()
	end
	if app.world then
		app.world.guide(target)
	end
	app:toast(msg or ("Go to the <b>" .. PLACE_LONG[target] .. "</b>."), T.accent2, 7)
end

function TP:go(i)
	local lo, hi = self:stepRange()
	i = math.clamp(i, lo, math.min(hi, self:reachable()))
	self.step = i
	if i == 2 then
		self.sub = self.sub or "map"
	end
	self:refresh()
end

------------------------------------------------------------------ step 1: artist
function TP:buildArtist()
	local app, state = self.app, self.app.state
	local body = self.body
	UI.Label(body, "Who goes on tour?", UI.px(40, 24), UI.px(1000, 44), { textSize = 34, font = UI.FontBlack })
	UI.Label(body, "Pick one of your artists. New artists are signed in the MEETING ROOM.", UI.px(40, 70), UI.px(1200, 26), { textSize = 18, color = T.sub })
	local list = UI.Scroll(body, UI.px(28, 112), UI.px(W - 56, 700))
	UI.New("UIGridLayout", { Parent = list, CellSize = UI.px(440, 300), CellPadding = UI.px(18, 18), SortOrder = Enum.SortOrder.LayoutOrder })
	UI.Padding(12, 12, 6, 6).Parent = list
	for i, ad in ipairs(GS.signedArtists(state)) do
		local sel = self.draft.artistId == ad.id
		local touring = GS.activeTour(state, ad.id)
		local card = UI.Button(list, "", nil, nil, { order = i, color = T.panel, radius = 14 }, function()
			self:pickArtist(ad.id)
		end)
		card.Name = "Artist_" .. ad.id
		UI.Stroke(sel and T.accent or T.stroke, sel and 3 or 1, 0).Parent = card
		People.preview(card, ad.look, UI.rgb(ad.color), UI.px(16, 16), UI.px(150, 268), Color3.fromRGB(236, 240, 246))
		UI.Label(card, ad.name, UI.px(184, 22), UI.px(240, 34), { textSize = 26, font = UI.FontBlack })
		UI.Label(card, ad.genre .. ((ad.members > 1) and ("  |  " .. ad.members .. " members") or "  |  solo"), UI.px(184, 60), UI.px(240, 22), { textSize = 16, color = T.sub })
		UI.Label(card, Util.short(Util.totalFans(state.artists[ad.id].fans)) .. " fans", UI.px(184, 100), UI.px(240, 26), { textSize = 19, font = UI.FontBold })
		UI.Label(card, "Hype " .. math.floor(state.artists[ad.id].hype) .. " / 100", UI.px(184, 130), UI.px(240, 22), { textSize = 16, color = T.sub })
		local rest = GS.restLeft(state, ad.id)
		if touring then
			UI.Pill(card, "ON TOUR NOW", UI.px(184, 168), UI.px(140, 28), T.warn, 13)
		elseif rest > 0 then
			UI.Pill(card, "RESTING " .. rest .. " DAYS", UI.px(184, 168), UI.px(170, 28), T.warn, 13)
		end
		if sel then
			UI.Pill(card, "SELECTED", UI.px(184, 244), UI.px(120, 32), T.accent, 14)
		end
	end
	self:buildFooter(nil, nil, "Next: plan the shows  >", function()
		self:go(2)
	end, self.draft.artistId ~= nil, self.draft.artistId and nil or "Click an artist.")
end

function TP:pickArtist(aid)
	local d = self.draft
	local okPlan, why = GS.canPlan(self.app.state, aid)
	if not okPlan and d.artistId ~= aid then
		self.app:toast(why or "Not possible right now.", T.bad, 6)
		return
	end
	local function set()
		d.artistId = aid
		d.shows, d.prices, d.designs, d.name, d.price, d.pricesSet, d.stageSet = {}, {}, {}, nil, nil, nil, nil
		self:saveDraft()
		self.sub, self.selected = "map", nil
		self:go(2)
	end
	if d.artistId == aid then
		self:go(2)
	elseif d.artistId and #d.shows > 0 then
		self.app:confirm("Plan a tour for " .. Artists.byId[aid].name .. "?", "The plan for <b>" .. Artists.byId[d.artistId].name .. "</b> (" .. #d.shows .. " shows) will be dropped.", set)
	else
		set()
	end
end

------------------------------------------------------------------ step 2: shows (map -> venues -> date)
function TP:routePanel(parent, x, y, w, h)
	local p = UI.Panel(parent, UI.px(x, y), UI.px(w, h), T.panel)
	local n = #self.draft.shows
	UI.Label(p, "YOUR SHOWS", UI.px(20, 14), UI.px(w - 40, 26), { textSize = 18, font = UI.FontBlack })
	UI.Label(p, n == 0 and "No shows yet." or (n .. " show" .. (n == 1 and "" or "s") .. " planned"), UI.px(20, 42), UI.px(w - 40, 22), { textSize = 15, color = T.sub })
	local list = UI.Scroll(p, UI.px(10, 74), UI.px(w - 20, h - 84))
	UI.List(true, 6).Parent = list
	for i, s in ipairs(self.draft.shows) do
		local v = Countries.venueById[s.venueId]
		local _, dshort = Util.date(s.day, Config.START_YEAR)
		local row = UI.New("Frame", { Parent = list, Size = UI.px(w - 40, 58), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		UI.Label(row, dshort .. "   " .. v.city, UI.px(12, 6), UI.px(w - 110, 24), { textSize = 16, font = UI.FontBold })
		UI.Label(row, v.name, UI.px(12, 30), UI.px(w - 110, 20), { textSize = 13, color = T.sub })
		UI.Button(row, "Remove", UI.px(w - 124, 13), UI.px(76, 32), { textSize = 13, color = T.panel }, function()
			table.remove(self.draft.shows, i)
			self:saveDraft()
			self:refresh()
		end).TextColor3 = T.bad
	end
	return p
end

function TP:buildShows()
	local state, aid = self.app.state, self.draft.artistId
	local body = self.body
	if self.sub == "country" and Countries.byId[self.selected or ""] then
		self:buildCountry()
		return
	end
	self.sub = "map"
	UI.Label(body, "Where does " .. Artists.byId[aid].name .. " play?", UI.px(40, 20), UI.px(1200, 40), { textSize = 30, font = UI.FontBlack })
	UI.Label(body, "Click a country on the map. The dot shows how many fans live there.", UI.px(40, 62), UI.px(1200, 24), { textSize = 17, color = T.sub })
	local counts = {}
	for _, s in ipairs(self.draft.shows) do
		local cid = Countries.venueById[s.venueId].countryId
		counts[cid] = (counts[cid] or 0) + 1
	end
	local mapOpts = {
		onClick = function(cid)
			self.selected = cid
			self.sub = "country"
			self:refresh()
		end,
		colorFn = function(cid)
			return heatColor(Sim.countryPool(state, aid, cid))
		end,
		countFn = function(cid)
			return counts[cid] or 0
		end,
	}
	-- the map is built once (thousands of little pieces) and kept between visits
	if not self.keptMap then
		self.keptMap = Map2D.new(body, UI.px(28, 100), UI.px(1380, 680), mapOpts)
	else
		self.keptMap.frame.Parent = body
		self.keptMap:setOpts(mapOpts)
	end
	self.map = self.keptMap
	-- fans legend under the map
	local lx = 40
	for _, k in ipairs({ { "very few fans", 100 }, { "few", 1000 }, { "some", 4000 }, { "good", 12000 }, { "many", 40000 }, { "huge", 90000 } }) do
		UI.New("Frame", { Parent = body, Position = UI.px(lx, 798), Size = UI.px(14, 14), BackgroundColor3 = heatColor(k[2]), BorderSizePixel = 0, UI.Corner(7) })
		UI.Label(body, k[1], UI.px(lx + 20, 792), UI.px(130, 26), { textSize = 14, color = T.sub })
		lx = lx + 40 + #k[1] * 8
	end
	self:routePanel(body, 1432, 100, 460, 708)
	self:buildFooter(nil, nil, "Done: on to the LAPTOP  >", function()
		self:leaveTo("laptop", "Shows booked! Now the <b>LAPTOP</b>: Tour Planner for tickets, stage and the announcement.")
	end, #self.draft.shows > 0, (#self.draft.shows == 0) and "Add at least one show." or "Next: tickets, stage and the announcement on the <b>LAPTOP</b>.")
end

-- the venues of a country as cards: picture, info, select. Sections per size, filters on the left.
function TP:buildCountry()
	local state, aid = self.app.state, self.draft.artistId
	local body = self.body
	local c = Countries.byId[self.selected]
	local tip, pool = Sim.recommendation(state, aid, c.id)
	-- left: country, tip, filters
	local left = UI.Panel(body, UI.px(28, 20), UI.px(300, 788), T.panel)
	UI.Button(left, "< World map", UI.px(16, 16), UI.px(268, 44), { textSize = 16 }, function()
		self.sub = "map"
		self:refresh()
	end)
	UI.Label(left, c.name, UI.px(20, 76), UI.px(260, 36), { textSize = 28, font = UI.FontBlack })
	UI.Label(left, "~" .. Util.short(pool) .. " fans of " .. Artists.byId[aid].name .. " here.\nPromoter tip: " .. tip, UI.px(20, 116), UI.px(260, 90), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Label(left, "SHOW ME", UI.px(20, 218), UI.px(260, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
	local y = 246
	for _, cls in ipairs(CLASS_ORDER) do
		local on = self.filter[cls]
		local b = UI.Button(left, (on and "[X]  " or "[  ]  ") .. CLASS_TITLE[cls], UI.px(16, y), UI.px(268, 44), { textSize = 14, color = on and Color3.fromRGB(219, 234, 254) or T.panel2 }, function()
			self.filter[cls] = not self.filter[cls]
			self:refresh()
		end)
		b.TextXAlignment = Enum.TextXAlignment.Left
		UI.Padding(14, 8, 0, 0).Parent = b
		y = y + 52
	end
	UI.Button(left, "Show all", UI.px(16, y + 6), UI.px(268, 40), { textSize = 14 }, function()
		for _, cls in ipairs(CLASS_ORDER) do
			self.filter[cls] = true
		end
		self:refresh()
	end)
	UI.Label(left, "Your label is level " .. GS.level(state) .. ". Bigger venues open at higher levels.", UI.px(20, 700), UI.px(260, 70), { textSize = 14, color = T.sub, wrap = true })
	-- middle: the venue cards, one section per size
	local grid = UI.Scroll(body, UI.px(344, 20), UI.px(1072, 788))
	UI.List(true, 10).Parent = grid
	local venues = {}
	for _, v in ipairs(c.venues) do
		table.insert(venues, v)
	end
	table.sort(venues, function(a, b)
		return a.cap < b.cap
	end)
	local order = 0
	for _, cls in ipairs(CLASS_ORDER) do
		local list = {}
		for _, v in ipairs(venues) do
			if GS.venueClass(v) == cls then
				table.insert(list, v)
			end
		end
		if self.filter[cls] and #list > 0 then
			order = order + 1
			-- section title with a dashed line
			local head = UI.New("Frame", { Parent = grid, Size = UI.px(1040, 44), BackgroundTransparency = 1, LayoutOrder = order })
			UI.Label(head, CLASS_TITLE[cls], UI.px(4, 4), UI.px(400, 30), { textSize = 20, font = UI.FontBlack })
			local tw = #CLASS_TITLE[cls] * 14 + 20
			for dx = tw, 1030, 18 do
				UI.New("Frame", { Parent = head, Position = UI.px(dx, 20), Size = UI.px(10, 2), BackgroundColor3 = Color3.fromRGB(170, 176, 188), BorderSizePixel = 0 })
			end
			order = order + 1
			local rows = math.ceil(#list / 4)
			local holder = UI.New("Frame", { Parent = grid, Size = UI.px(1040, rows * 352), BackgroundTransparency = 1, LayoutOrder = order })
			UI.New("UIGridLayout", { Parent = holder, CellSize = UI.px(248, 340), CellPadding = UI.px(16, 12), SortOrder = Enum.SortOrder.LayoutOrder })
			for i, v in ipairs(list) do
				self:venueCard(holder, v, i)
			end
		end
	end
	if order == 0 then
		UI.Label(grid, "No venues to show. Turn a size on in SHOW ME.", nil, UI.px(1000, 60), { textSize = 18, color = T.sub })
	end
	self:routePanel(body, 1432, 20, 460, 788)
	self:buildFooter("< World map", function()
		self.sub = "map"
		self:refresh()
	end, "Done: on to the LAPTOP  >", function()
		self:leaveTo("laptop", "Shows booked! Now the <b>LAPTOP</b>: Tour Planner for tickets, stage and the announcement.")
	end, #self.draft.shows > 0, "Pick a venue, then a date.")
end

function TP:venueCard(parent, v, i)
	local state, aid = self.app.state, self.draft.artistId
	local vt = Countries.VENUE_TYPES[v.type]
	local open = GS.venueUnlocked(state, v)
	local card = UI.New("Frame", { Parent = parent, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = i, Name = "Venue_" .. v.id, UI.Corner(12), UI.Stroke(T.stroke, 1, 0) })
	-- picture (red box in the sketch)
	local pic = VenueModels.picture(card, v.type, UI.px(8, 8), UI.px(232, 140), UI.rgb(vt.color))
	if not open then
		pic.ImageTransparency = 0.5
	end
	UI.Pill(card, vt.label, UI.px(14, 14), UI.px(84, 22), Color3.fromRGB(255, 255, 255), 11)
	-- info (green)
	UI.Label(card, v.name, UI.px(12, 154), UI.px(224, 26), { textSize = 18, font = UI.FontBold })
	UI.Label(card, v.city .. "   |   " .. Util.number(v.cap) .. " seats", UI.px(12, 182), UI.px(224, 20), { textSize = 14, color = T.sub })
	UI.Label(card, "Rent " .. Util.moneyShort(Sim.venueRent(v)), UI.px(12, 204), UI.px(224, 20), { textSize = 14, color = T.sub })
	if open then
		local lk = Sim.lookOf(v)
		local pr = self:pricesFor(lk)
		local shows = { { venueId = v.id, prices = pr, price = Sim.avgPrice(lk, pr) } }
		local d = Sim.demands(state, aid, shows, 1)[1]
		local n = Config.DEMAND_NOISE
		local fair = Sim.fairPrice(state, aid, v.countryId)
		local _, soldLo = Sim.splitSections(lk, v.cap, pr, d * (1 - n), fair)
		local _, soldHi = Sim.splitSections(lk, v.cap, pr, d * (1 + n), fair)
		local lo, hi = soldLo / v.cap, soldHi / v.cap
		UI.Label(card, "Expected: " .. rangeText(lo, hi), UI.px(12, 230), UI.px(224, 22), { textSize = 15, font = UI.FontBold, color = rangeColor(lo, hi) })
		-- select (blue)
		local b = UI.Button(card, "SELECT", UI.px(12, 276), UI.px(224, 50), { color = T.accent, textSize = 18 }, function()
			self:openCalendar(v.id)
		end)
		b.Name = "Select"
	else
		UI.Label(card, "Opens at label level " .. GS.venueLevel(v) .. " (" .. Config.LEVELS[GS.venueLevel(v)].name .. ")", UI.px(12, 230), UI.px(224, 40), { textSize = 14, color = T.sub, wrap = true })
		UI.Button(card, "LOCKED", UI.px(12, 276), UI.px(224, 50), { textSize = 16, disabled = true })
	end
end

-- the date for a venue: a calendar over the planner
function TP:dayState(day)
	local state, draft = self.app.state, self.draft
	if day < state.day + 3 then
		return "past"
	end
	for _, s in ipairs(draft.shows) do
		if s.day == day then
			return "mine"
		end
	end
	local busy = GS.venueBusy(state, self.picked, day)
	if busy then
		return "busy", busy
	end
	local new = { venueId = self.picked }
	for _, s in ipairs(draft.shows) do
		if math.abs(s.day - day) < GS.travelGap(s, new) then
			return "travel"
		end
	end
	return "ok"
end

function TP:openCalendar(venueId)
	local state = self.app.state
	self.picked = venueId
	local last = self.draft.shows[#self.draft.shows]
	local from = last and (last.day + 1) or (state.day + 21)
	local y, m = Util.ymd(from, Config.START_YEAR)
	self.calMonth = { y, m }
	self:buildCalendar()
end

function TP:buildCalendar()
	local ov = self.overlay
	UI.ClearChildren(ov)
	ov.Visible = true
	local dim = UI.New("TextButton", { Parent = ov, Size = UI.px(W, H), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, AutoButtonColor = false, Text = "", ZIndex = 20 })
	local _ = dim
	local p = UI.New("Frame", { Parent = ov, Position = UI.px(260, 60), Size = UI.px(1400, 880), BackgroundColor3 = T.panel, BorderSizePixel = 0, ZIndex = 21, UI.Corner(16) })
	local v = Countries.venueById[self.picked]
	local function z(inst)
		inst.ZIndex = 22
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = 23
			end
		end
		return inst
	end
	local y, m = self.calMonth[1], self.calMonth[2]
	z(UI.Label(p, "When? " .. v.name .. ", " .. v.city, UI.px(32, 20), UI.px(1000, 36), { textSize = 26, font = UI.FontBlack }))
	z(UI.Label(p, "Click a green day. Click more days for more nights. Click one of your shows to take it away.", UI.px(32, 58), UI.px(1100, 24), { textSize = 16, color = T.sub }))
	z(UI.Button(p, "<", UI.px(940, 100), UI.px(52, 44), { textSize = 20 }, function()
		m = m - 1
		if m < 1 then
			m, y = 12, y - 1
		end
		self.calMonth = { y, m }
		self:buildCalendar()
	end))
	z(UI.Label(p, Util.monthName(m) .. " " .. y, UI.px(1000, 100), UI.px(300, 44), { textSize = 24, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center }))
	z(UI.Button(p, ">", UI.px(1310, 100), UI.px(52, 44), { textSize = 20 }, function()
		m = m + 1
		if m > 12 then
			m, y = 1, y + 1
		end
		self.calMonth = { y, m }
		self:buildCalendar()
	end))
	local cw, ch, gap = 186, 104, 8
	for i, nm in ipairs({ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }) do
		z(UI.Label(p, nm, UI.px(32 + (i - 1) * (cw + gap), 154), UI.px(cw, 22), { textSize = 14, color = T.sub, font = UI.FontBold, alignX = Enum.TextXAlignment.Center }))
	end
	local d0 = Util.dayOf(y, m, 1, Config.START_YEAR)
	local _, _, _, wd0 = Util.ymd(d0, Config.START_YEAR)
	local COL = { past = T.panel2, mine = T.accent, ok = Color3.fromRGB(187, 247, 208), busy = Color3.fromRGB(254, 202, 202), travel = Color3.fromRGB(226, 232, 240) }
	for dd = 1, Util.monthLength(y, m) do
		local day = d0 + dd - 1
		local cell = wd0 - 1 + dd - 1
		local cx, cy = 32 + (cell % 7) * (cw + gap), 180 + math.floor(cell / 7) * (ch + gap)
		local st, why = self:dayState(day)
		local b = z(UI.Button(p, "", UI.px(cx, cy), UI.px(cw, ch), { color = COL[st] or T.panel2, disabled = st == "past" }, function()
			self:dayClicked(day)
		end))
		b.Name = "Day" .. day
		local fg = (st == "mine") and Color3.new(1, 1, 1) or ((st == "past") and T.sub or T.text)
		z(UI.Label(b, tostring(dd), UI.px(10, 6), UI.px(60, 24), { textSize = 18, font = UI.FontBold, color = fg }))
		local txt = (st == "busy") and ("taken: " .. tostring(why)) or ((st == "travel") and "travel day" or ((st == "ok") and "free" or ""))
		if st == "mine" then
			for _, s in ipairs(self.draft.shows) do
				if s.day == day then
					txt = Countries.venueById[s.venueId].city
				end
			end
		end
		z(UI.Label(b, txt, UI.px(10, 34), UI.px(cw - 20, 60), { textSize = 13, color = fg, wrap = true, alignY = Enum.TextYAlignment.Top }))
	end
	z(UI.Button(p, "Done", UI.px(1100, 808), UI.px(268, 52), { color = T.accent, textSize = 20 }, function()
		ov.Visible = false
		UI.ClearChildren(ov)
		self:refresh()
	end)).Name = "CalendarDone"
end

function TP:dayClicked(day)
	local draft = self.draft
	for i, s in ipairs(draft.shows) do
		if s.day == day then
			table.remove(draft.shows, i)
			self:saveDraft()
			self:buildCalendar()
			return
		end
	end
	if self:dayState(day) == "ok" and #draft.shows < Config.MAX_SHOWS_PER_TOUR then
		table.insert(draft.shows, { venueId = self.picked, day = day })
		self:sortShows()
		self:saveDraft()
	end
	self:buildCalendar()
end

------------------------------------------------------------------ step 3: tickets
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
local SEC_COLORS = { Color3.fromRGB(245, 158, 11), Color3.fromRGB(59, 130, 246), Color3.fromRGB(139, 92, 246), Color3.fromRGB(16, 185, 129), Color3.fromRGB(236, 72, 153) }

function TP:sectionForecast(look)
	local state, draft = self.app.state, self.draft
	self:syncPrices()
	local d = Sim.demands(state, draft.artistId, draft.shows, 1)
	local sold, cap = {}, {}
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		if Sim.lookOf(v) == look then
			local by = Sim.splitSections(look, v.cap, s.prices, d[i], Sim.fairPrice(state, draft.artistId, v.countryId))
			for _, sec in ipairs(Sim.SECTIONS[look]) do
				sold[sec.id] = (sold[sec.id] or 0) + (by[sec.id] or 0)
				cap[sec.id] = (cap[sec.id] or 0) + math.floor(v.cap * sec.share)
			end
		end
	end
	return sold, cap
end

function TP:buildTickets()
	local state, draft = self.app.state, self.draft
	local ad = Artists.byId[draft.artistId]
	local body = self.body
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
	local left = UI.Panel(body, UI.px(28, 20), UI.px(960, 788), T.panel)
	UI.Label(left, "Ticket prices", UI.px(28, 16), UI.px(500, 36), { textSize = 28, font = UI.FontBlack })
	local x = 28
	for _, lk in ipairs(looks) do
		local w = #LOOK_LABEL[lk] * 11 + 40
		UI.Button(left, LOOK_LABEL[lk], UI.px(x, 60), UI.px(w, 38), { textSize = 14, color = (lk == look) and T.accent or T.panel3 }, function()
			self.ticketLook = lk
			self.ticketSec = nil
			self:refresh()
		end)
		x = x + w + 8
	end
	local map = UI.New("Frame", { Parent = left, Position = UI.px(100, 116), Size = UI.px(760, 600), BackgroundColor3 = Color3.fromRGB(241, 244, 248), BorderSizePixel = 0, UI.Corner(12) })
	UI.New("TextLabel", { Parent = map, Position = UI.px(200, 30), Size = UI.px(360, 80), BackgroundColor3 = Color3.fromRGB(51, 55, 66), Text = "STAGE", TextColor3 = Color3.new(1, 1, 1), TextSize = 22, Font = UI.FontBlack, BorderSizePixel = 0, UI.Corner(8) })
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
		local col = Color3.new(1, 1, 1):Lerp(SEC_COLORS[idx], 0.35 + 0.65 * math.clamp(fill, 0, 1))
		local b = UI.Button(map, "", UI.px(sh[2], sh[3]), UI.px(sh[4], sh[5]), { color = col }, function()
			self.ticketSec = id
			self:refresh()
		end)
		if id == self.ticketSec then
			UI.Stroke(T.text, 3, 0).Parent = b
		end
		if not labeled[id] and sh[4] > 150 then
			labeled[id] = true
			UI.Label(b, string.upper(sec.name) .. "\n" .. Util.money(prices[id]) .. "\n~" .. math.floor(fill * 100 + 0.5) .. "% sold", UI.px(0, 0), UI.px(sh[4], sh[5]), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Center, color = UI.onColor(col) })
		end
	end
	UI.Label(left, "The stronger the colour, the more tickets are expected to sell. Click a section.", UI.px(28, 736), UI.px(900, 24), { textSize = 15, color = T.sub })
	local right = UI.Panel(body, UI.px(1004, 20), UI.px(888, 788), T.panel)
	UI.Label(right, LOOK_LABEL[look] .. ": PRICE PER SECTION", UI.px(28, 18), UI.px(820, 30), { textSize = 20, font = UI.FontBlack })
	-- what a ticket is worth in the countries of these shows (fair price, average over the shows)
	local fairSum, fairN = 0, 0
	for _, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		if Sim.lookOf(v) == look then
			fairSum = fairSum + Sim.fairPrice(state, ad.id, v.countryId)
			fairN = fairN + 1
		end
	end
	local fairBase = fairN > 0 and fairSum / fairN or Sim.ticketBase(state, ad.id)
	UI.Label(right, "Same prices for all " .. string.lower(LOOK_LABEL[look]) .. " of this tour. Every section sells on its own: below its fair price it sells faster, above it slower. Tickets keep selling until the show day.", UI.px(28, 50), UI.px(830, 48), { textSize = 14, color = T.sub, wrap = true })
	local y = 106
	for i, sec in ipairs(secs) do
		local sel = sec.id == self.ticketSec
		local row = UI.New("Frame", { Parent = right, Position = UI.px(20, y), Size = UI.px(848, 92), BackgroundColor3 = sel and Color3.fromRGB(219, 234, 254) or T.panel2, BorderSizePixel = 0, UI.Corner(10) })
		UI.New("Frame", { Parent = row, Size = UI.px(10, 92), BackgroundColor3 = SEC_COLORS[i], BorderSizePixel = 0 })
		local fill = (cap[sec.id] or 0) > 0 and (sold[sec.id] or 0) / cap[sec.id] or 0
		UI.Label(row, sec.name, UI.px(24, 8), UI.px(330, 28), { textSize = 20, font = UI.FontBold })
		UI.Label(row, (sec.standing and "standing" or "seated") .. "  |  ~" .. Util.number(sold[sec.id] or 0) .. " of " .. Util.number(cap[sec.id] or 0) .. " sold", UI.px(24, 40), UI.px(470, 22), { textSize = 14, color = T.sub })
		UI.Bar(row, UI.px(24, 68), UI.px(440, 10), fill, fill > 0.9 and T.good or (fill > 0.6 and T.warn or T.bad))
		for k, dv in ipairs({ -5, -1, 1, 5 }) do
			local bx = (k <= 2) and (510 + (k - 1) * 52) or (740 + (k - 3) * 52)
			UI.Button(row, (dv > 0 and "+" or "") .. dv, UI.px(bx, 22), UI.px(46, 48), { textSize = 15, color = T.panel }, function()
				prices[sec.id] = math.clamp(prices[sec.id] + dv, 5, 4000)
				self.ticketSec = sec.id
				self:saveDraft()
				self:refresh()
			end)
		end
		UI.Label(row, Util.money(prices[sec.id]), UI.px(614, 14), UI.px(120, 40), { textSize = 22, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
		local worth = math.max(5, Util.round(fairBase * sec.mult))
		local fb = UI.Button(row, "fair " .. Util.money(worth), UI.px(614, 56), UI.px(120, 28), { textSize = 12, color = T.panel }, function()
			prices[sec.id] = worth
			self.ticketSec = sec.id
			self:saveDraft()
			self:refresh()
		end)
		fb.Name = "Fair_" .. sec.id
		y = y + 100
	end
	local est = self:estimate()
	UI.Label(right, "Whole tour, promoter estimate: <b>" .. Util.money(est.grossLow or 0) .. " - " .. Util.money(est.grossHigh or 0) .. "</b> ticket money\nCosts (venues, production, travel, artist share): about <b>" .. Util.money(est.costs) .. "</b>", UI.px(28, math.min(y + 10, 680)), UI.px(830, 80), { textSize = 16, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	self:buildFooter(nil, nil, "Next: choose the stage  >", function()
		self:syncPrices()
		self.draft.pricesSet = true
		self:saveDraft()
		self:go(4)
	end, true)
end

------------------------------------------------------------------ step 4: stage
function TP:buildStage()
	local state = self.app.state
	local body = self.body
	UI.Label(body, "Which stage goes on tour?", UI.px(40, 20), UI.px(1200, 40), { textSize = 30, font = UI.FontBlack })
	UI.Label(body, "Select one stage for each venue size. Build and name your stages in the STAGE HALL.", UI.px(40, 62), UI.px(1100, 24), { textSize = 17, color = T.sub })
	-- background dancers (solo artists, not in clubs): cost per show, better reviews
	local ad = Artists.byId[self.draft.artistId or ""]
	local bigShows = 0
	for _, sh in ipairs(self.draft.shows) do
		if Sim.lookOf(Countries.venueById[sh.venueId]) ~= "club" then
			bigShows = bigShows + 1
		end
	end
	if ad and ad.members == 1 and bigShows > 0 then
		local n = math.clamp(math.floor(tonumber(self.draft.dancers) or 0), 0, Config.MAX_DANCERS)
		local box = UI.New("Frame", { Parent = body, Name = "Dancers", Position = UI.px(1180, 10), Size = UI.px(700, 84), BackgroundColor3 = T.panel, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.stroke, 1, 0) })
		UI.Label(box, "BACKGROUND DANCERS", UI.px(16, 8), UI.px(300, 24), { textSize = 16, font = UI.FontBlack })
		UI.Label(box, n == 0 and "None: the artist is alone on stage." or (n .. " dancer" .. (n == 1 and "" or "s") .. ": +" .. Util.money(n * Config.DANCER_COST) .. " per show, better reviews (not in clubs)"), UI.px(16, 36), UI.px(440, 40), { textSize = 13, color = T.sub, wrap = true })
		local function set(v)
			self.draft.dancers = math.clamp(v, 0, Config.MAX_DANCERS)
			self:saveDraft()
			self:refresh()
		end
		UI.Button(box, "-", UI.px(476, 16), UI.px(52, 52), { textSize = 22 }, function()
			set(n - 1)
		end).Name = "DancersDown"
		UI.Label(box, tostring(n), UI.px(530, 16), UI.px(80, 52), { textSize = 28, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
		UI.Button(box, "+", UI.px(612, 16), UI.px(52, 52), { textSize = 22, color = T.accent }, function()
			set(n + 1)
		end).Name = "DancersUp"
	end
	local list = UI.Scroll(body, UI.px(28, 100), UI.px(W - 56, 712))
	UI.List(true, 14).Parent = list
	local StagesScreen = require(Root.Client.Screens.StagesScreen)
	local allChosen = true
	for k, need in ipairs(self:classesNeeded()) do
		local sec = UI.New("Frame", { Parent = list, Size = UI.px(W - 80, 380), BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = k, UI.Corner(14), UI.Stroke(T.stroke, 1, 0) })
		local chosen = self:chosenDesign(need.class)
		allChosen = allChosen and chosen ~= nil
		UI.Label(sec, string.upper(need.class) .. " SHOWS", UI.px(24, 14), UI.px(600, 30), { textSize = 22, font = UI.FontBlack })
		UI.Label(sec, need.shows .. " show" .. (need.shows == 1 and "" or "s") .. ": " .. table.concat(need.cities, ", "), UI.px(24, 46), UI.px(1500, 22), { textSize = 15, color = T.sub })
		UI.Label(sec, chosen and ("Selected: " .. chosen.name) or "Not selected yet", UI.px(1300, 14), UI.px(480, 30), { textSize = 18, font = UI.FontBold, color = chosen and T.good or T.warn, alignX = Enum.TextXAlignment.Right })
		local strip = UI.Scroll(sec, UI.px(16, 78), UI.px(W - 112, 296))
		strip.AutomaticCanvasSize = Enum.AutomaticSize.X
		strip.ScrollingDirection = Enum.ScrollingDirection.X
		UI.List(false, 14).Parent = strip
		local fits = self:fittingDesigns(need.class)
		if #fits == 0 then
			UI.Label(strip, "No stage fits yet. Build one in the STAGE HALL.", nil, UI.px(800, 60), { textSize = 18, color = T.bad })
		end
		for i, d in ipairs(fits) do
			local on = chosen == d
			local card = UI.New("Frame", { Parent = strip, Size = UI.px(320, 280), BackgroundColor3 = on and Color3.fromRGB(219, 234, 254) or T.panel2, BorderSizePixel = 0, LayoutOrder = i, Name = "Stage_" .. d.id, UI.Corner(12), UI.Stroke(on and T.accent or T.stroke, on and 3 or 1, 0) })
			StagesScreen.thumbnail(card, d, UI.px(8, 8), UI.px(304, 150))
			UI.Label(card, d.name, UI.px(14, 164), UI.px(292, 26), { textSize = 19, font = UI.FontBold })
			local st = Sim.designStats(d, nil)
			UI.Label(card, d.class .. " stage  |  " .. GS.songCount(d) .. " songs  |  " .. Util.moneyShort(st.cost) .. " per show", UI.px(14, 192), UI.px(292, 20), { textSize = 13, color = T.sub })
			UI.Button(card, on and "SELECTED" or "SELECT", UI.px(14, 222), UI.px(292, 46), { color = on and T.good or T.accent, textSize = 18 }, function()
				self.draft.designs = self.draft.designs or {}
				self.draft.designs[need.class] = d.id
				self:saveDraft()
				self:refresh()
			end).Name = "SelectStage"
		end
	end
	self:buildFooter("< Tickets", function()
		self:go(3)
	end, "Next: check & announce  >", function()
		self.draft.stageSet = true
		self:saveDraft()
		self:go(5)
	end, allChosen, (not allChosen) and "Select a stage for every venue size." or nil)
end

------------------------------------------------------------------ step 5: check & announce
function TP:buildAnnounce()
	local app, state, draft = self.app, self.app.state, self.draft
	local body = self.body
	local ad = Artists.byId[draft.artistId]
	local p = UI.Panel(body, UI.px(28, 20), UI.px(W - 56, 788), T.panel)
	UI.Label(p, "Check & announce", UI.px(28, 18), UI.px(800, 40), { textSize = 30, font = UI.FontBlack })
	UI.Label(p, "TOUR NAME", UI.px(28, 70), UI.px(400, 20), { textSize = 14, color = T.sub, font = UI.FontBold })
	local nameBox = UI.New("TextBox", { Parent = p, Position = UI.px(28, 94), Size = UI.px(700, 52), BackgroundColor3 = T.panel2, BorderSizePixel = 0, Text = draft.name or (ad.name .. " Live"), PlaceholderText = "Tour name", ClearTextOnFocus = false, TextColor3 = T.text, TextSize = 24, Font = UI.FontBlack, UI.Corner(8), UI.Stroke(T.stroke, 1, 0) })
	nameBox.FocusLost:Connect(function()
		draft.name = nameBox.Text:sub(1, 40)
		self:saveDraft()
	end)
	local sx = 760
	for _, need in ipairs(self:classesNeeded()) do
		local d = self:chosenDesign(need.class)
		UI.Pill(p, need.class .. " stage: " .. (d and d.name or "-"), UI.px(sx, 104), UI.px(300, 34), T.panel3, 14)
		sx = sx + 312
	end
	local est = self:estimate()
	local headers = { { "#", 28 }, { "DATE", 76 }, { "VENUE", 210 }, { "SEATS", 900 }, { "AVG. TICKET", 1060 }, { "EXPECTED", 1260 } }
	for _, h in ipairs(headers) do
		UI.Label(p, h[1], UI.px(h[2], 166), UI.px(300, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local list = UI.Scroll(p, UI.px(16, 190), UI.px(W - 88, 420))
	UI.List(true, 4).Parent = list
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local r = est.rows[i]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(W - 110, 44), BackgroundColor3 = (i % 2 == 0) and T.panel2 or T.panel, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(6) })
		local _, dateShort = Util.date(s.day, Config.START_YEAR)
		UI.Label(row, tostring(i), UI.px(12, 0), UI.px(40, 44), { textSize = 16, font = UI.FontBold })
		UI.Label(row, dateShort, UI.px(60, 0), UI.px(120, 44), { textSize = 16 })
		UI.Label(row, v.name .. ", " .. v.city, UI.px(194, 0), UI.px(680, 44), { textSize = 16, font = UI.FontBold })
		UI.Label(row, Util.number(v.cap), UI.px(884, 0), UI.px(140, 44), { textSize = 16 })
		UI.Label(row, Util.money(s.price or 0), UI.px(1044, 0), UI.px(160, 44), { textSize = 16 })
		UI.Label(row, rangeText(r.fillLow, r.fillHigh), UI.px(1244, 0), UI.px(400, 44), { textSize = 16, font = UI.FontBold, color = rangeColor(r.fillLow, r.fillHigh) })
	end
	UI.Label(p, "Ticket money: <b>" .. Util.money(est.grossLow or 0) .. " - " .. Util.money(est.grossHigh or 0) .. "</b>\nLabel profit: <b>" .. Util.money(est.netLow or 0) .. " - " .. Util.money(est.netHigh or 0) .. "</b>  (after venues, production, travel and the artist's share)\n<font color='#686e7a'>The promoter can be wrong. Watch the real sales in MY TOURS.</font>", UI.px(28, 630), UI.px(1500, 120), { textSize = 18, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	self:buildFooter("< Stage", function()
		self:go(4)
	end, "ANNOUNCE TOUR", function()
		self:syncPrices()
		self:saveDraft()
		local ok, msg, data = app:act("announceTour", { name = draft.name })
		if not ok then
			app:toast(msg or "Could not announce the tour.", T.bad)
			return
		end
		local res = GS.getTour(state, data.tourId)
		SoundFX.sfx("cash", 0.6)
		app:toast("<b>" .. UI.esc(res.name) .. "</b> is announced! Tickets are on sale now.", T.good, 8)
		self.step, self.sub, self.selected, self.picked = 2, "map", nil, nil
		if self.onAnnounced then
			self.onAnnounced(res)
		end
	end, true)
end

------------------------------------------------------------------ show / refresh
function TP:show(args)
	self:syncDraft()
	if args and args.step then
		self.step = args.step
	end
	if args and args.artistId and args.artistId ~= self.draft.artistId then
		self.frame.Visible = true
		self:pickArtist(args.artistId)
		return
	end
	-- every room starts at its own first open step
	if not (args and args.step) then
		local lo, hi = self:stepRange()
		if (self.step or 1) < lo or (self.step or 1) > hi then
			self.step = lo
		end
		if lo == 3 then
			self.step = math.max(self.step, math.min(hi, self:reachable()))
		end
	end
	self.frame.Visible = true
	self:refresh()
end

function TP:hide()
	self.overlay.Visible = false
end

function TP:refresh()
	self:syncDraft()
	if self.keptMap then
		self.keptMap.frame.Parent = nil -- kept, not destroyed with the page
	end
	UI.ClearChildren(self.body)
	-- what can be done here: the steps of this room; the others say where to go
	local place = self:place()
	local lo, hi = self:stepRange()
	if not self.draft.artistId then
		self.step = lo
		self:buildHeader()
		self:buildElsewhere("meeting", "First: who goes on tour?", "Choose the artist in the <b>MEETING ROOM</b>: sit down, press E and click <b>PLAN A TOUR</b> on an artist's card.")
		return
	end
	if place == "laptop" and #self.draft.shows == 0 then
		self.step = lo
		self:buildHeader()
		self:buildElsewhere("maptable", "First: book the shows", "The shows of <b>" .. UI.esc(Artists.byId[self.draft.artistId].name) .. "</b> are booked at the big <b>WORLD MAP</b> table: country, venue, date. Then come back here for tickets, stage and the announcement.")
		return
	end
	self.step = math.clamp(self.step or lo, lo, math.max(lo, math.min(hi, self:reachable())))
	self:buildHeader()
	self.map = nil
	if self.step == 1 then
		self:buildArtist()
	elseif self.step == 2 then
		self:buildShows()
	elseif self.step == 3 then
		self:buildTickets()
	elseif self.step == 4 then
		self:buildStage()
	else
		self:buildAnnounce()
	end
end

return TP
