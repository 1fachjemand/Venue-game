-- Game state: everything that gets saved. Pure Lua (no Roblox APIs).
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local StageItems = require(Root.Data.StageItems)
local Achievements = require(Root.Data.Achievements)
local Rivals = require(Root.Data.Rivals)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local Social = require(Root.Logic.Social)

local GS = {}

------------------------------------------------------------------ creation
function GS.freshArtist(ad)
	return {
		id = ad.id,
		signed = false,
		fans = Util.deepCopy(ad.fans),
		hype = ad.hype,
		lastPlayed = {},
		shows = 0,
		gross = 0,
	}
end

function GS.newId(state, prefix)
	local id = prefix .. tostring(state.nextId)
	state.nextId = state.nextId + 1
	return id
end

function GS.log(state, text)
	table.insert(state.log, 1, { day = state.day, text = text })
	while #state.log > 40 do
		table.remove(state.log)
	end
end

-- a random id for a placed stage item (made on the client and the server, so it is not a counter)
local uidCount = 0
function GS.uid()
	uidCount = uidCount + 1
	return "u" .. tostring(math.random(1, 999999999)) .. "_" .. tostring(uidCount)
end

-- every item of a design gets a uid (the server pays the difference of a changed design by uid)
function GS.ensureUids(design)
	local seen = {}
	for _, it in ipairs(design.items or {}) do
		if type(it.uid) ~= "string" or seen[it.uid] then
			it.uid = GS.uid()
		end
		seen[it.uid] = true
	end
end

-- opts = { sandbox = true } for the developer test mode
function GS.new(labelName, starterId, opts)
	opts = opts or {}
	local state = {
		version = Config.SAVE_VERSION,
		labelName = labelName or Config.DEFAULT_LABEL_NAME,
		money = Config.START_MONEY,
		day = 0,
		artists = {},
		designs = {},
		tours = {},
		nextId = 1,
		achievements = {},
		log = {},
		social = {},
		levelSeen = 1,
		sandbox = opts.sandbox == true,
		visited = {},
		tutorial = (opts.sandbox == true) and { done = true } or { step = 1 }, -- the guide (Client/Tutorial.lua): step reached, done = true when finished or skipped
		-- the tour being planned, step by step in different rooms (see GS.planStage)
		draft = {},
		stats = {
			shows = 0,
			sellouts = 0,
			tickets = 0,
			totalGross = 0,
			bestShowGross = 0,
			bestShowText = "",
			biggestSellout = 0,
			fiveStars = 0,
			bestTourGross = 0,
			maxRegions = 0,
		},
	}
	for _, ad in ipairs(Artists.list) do
		state.artists[ad.id] = GS.freshArtist(ad)
	end
	local starter = Artists.byId[starterId or ""] or Artists.byId.lila
	state.artists[starter.id].signed = true
	for _, p in ipairs(StageItems.PRESETS) do
		if not p.shop then
			GS.addDesign(state, p.name, Util.deepCopy(p.items), p.class, p.layout).template = p.name
		end
	end
	GS.log(state, state.labelName .. " opens its doors with " .. starter.name .. " on the roster.")
	if state.sandbox then
		state.money = Config.SANDBOX_MONEY
		state.levelSeen = #Config.LEVELS
		GS.log(state, "SANDBOX: unlimited money, every level, artist, venue and room is open.")
	end
	return state
end

-- Repairs / upgrades a loaded save so missing fields never crash the game
function GS.sanitize(data)
	if type(data) ~= "table" or data.version ~= Config.SAVE_VERSION then
		return GS.new()
	end
	local fresh = GS.new()
	-- saves from before the tutorial existed: no tutorial for a label that already played
	if type(data.tutorial) ~= "table" then
		data.tutorial = ((type(data.stats) == "table" and (data.stats.shows or 0) > 0) or (type(data.tours) == "table" and #data.tours > 0)) and { done = true } or { step = 1 }
	end
	for k, v in pairs(fresh) do
		if type(data[k]) ~= type(v) then
			data[k] = v
		end
	end
	for k, v in pairs(fresh.stats) do
		if type(data.stats[k]) ~= type(v) then
			data.stats[k] = v
		end
	end
	for _, ad in ipairs(Artists.list) do
		local a = data.artists[ad.id]
		if type(a) ~= "table" then
			data.artists[ad.id] = GS.freshArtist(ad)
		else
			a.fans = type(a.fans) == "table" and a.fans or Util.deepCopy(ad.fans)
			for rid, n in pairs(ad.fans) do
				if type(a.fans[rid]) ~= "number" then
					a.fans[rid] = n
				end
			end
			a.lastPlayed = type(a.lastPlayed) == "table" and a.lastPlayed or {}
			a.hype = type(a.hype) == "number" and a.hype or ad.hype
			a.shows = a.shows or 0
			a.gross = a.gross or 0
		end
	end
	for _, d in ipairs(data.designs) do
		if type(d.items) ~= "table" then
			d.items = {}
		end
		GS.ensureUids(d)
	end
	if #data.designs == 0 then
		GS.addDesign(data, "My Design", {}, "Club", "end")
	end
	return data
end

------------------------------------------------------------------ artists
function GS.signedArtists(state)
	local out = {}
	for _, ad in ipairs(Artists.list) do
		if state.artists[ad.id].signed then
			table.insert(out, ad)
		end
	end
	return out
end

-- not signed yet, the ones you can afford first (small to big)
function GS.unsignedArtists(state)
	local out = {}
	for _, ad in ipairs(Artists.list) do
		if not state.artists[ad.id].signed then
			table.insert(out, ad)
		end
	end
	table.sort(out, function(a, b)
		if a.signCost ~= b.signCost then
			return a.signCost < b.signCost
		end
		return a.order < b.order
	end)
	return out
end

function GS.activeTour(state, artistId)
	for _, t in ipairs(state.tours) do
		if t.artistId == artistId and t.status ~= "done" then
			return t
		end
	end
	return nil
end

function GS.level(state)
	if state.sandbox then
		local n = #Config.LEVELS
		return n, Config.LEVELS[n], nil
	end
	local lvl = 1
	for i, l in ipairs(Config.LEVELS) do
		if state.stats.tickets >= l.tickets then
			lvl = i
		end
	end
	return lvl, Config.LEVELS[lvl], Config.LEVELS[lvl + 1]
end

function GS.sign(state, artistId)
	local ad = Artists.byId[artistId]
	local a = state.artists[artistId]
	if not ad or a.signed then
		return false, "Already signed."
	end
	if ad.level > GS.level(state) then
		return false, ad.name .. " only talks to a " .. Config.LEVELS[ad.level].name .. " (level " .. ad.level .. ")."
	end
	if state.money < ad.signCost then
		return false, "Not enough money to sign " .. ad.name .. "."
	end
	state.money = state.money - ad.signCost
	a.signed = true
	GS.log(state, "Signed " .. ad.name .. " for " .. Util.money(ad.signCost) .. "!")
	Social.add(state, "sign", { artistId = ad.id }, 2)
	return true, ad.name .. " joined your label!"
end

-- can the label book this venue yet? (level 1 = clubs, see Config.VENUE_LEVEL)
function GS.venueLevel(venue)
	return Config.VENUE_LEVEL[venue.type] or 1
end
function GS.venueUnlocked(state, venue)
	return GS.level(state) >= GS.venueLevel(venue)
end

------------------------------------------------------------------ the label building: rooms open one after another
GS.STATIONS = { "laptop", "maptable", "meeting", "stagehall", "charts" }
function GS.unlocks(state)
	local st = state.stats
	local anyDone = false
	for _, t in ipairs(state.tours) do
		if t.status == "done" then
			anyDone = true
		end
	end
	local all = state.sandbox == true
	return {
		laptop = true,
		maptable = true,
		meeting = true,
		phone = true,
		stagehall = true, -- build a stage right from the first tour
		charts = all or anyDone or st.shows >= 5,
	}
end
GS.UNLOCK_HINT = {
	stagehall = "Opens after your first show",
	charts = "Opens after your first finished tour",
}

-- how far the tour plan is: "artist" (meeting room) -> "dates" (world map) -> "tickets" (laptop)
-- -> "stage" (stage hall) -> "announce" (laptop); nil = nothing planned
GS.PLAN_STEPS = {
	{ id = "artist", name = "ARTIST", where = "Meeting room", station = "meeting" },
	{ id = "dates", name = "DATES", where = "World map", station = "maptable" },
	{ id = "tickets", name = "TICKETS", where = "Laptop", station = "laptop" },
	{ id = "stage", name = "STAGE", where = "Stage hall", station = "stagehall" },
	{ id = "announce", name = "ANNOUNCE", where = "Laptop", station = "laptop" },
}
function GS.planStage(state)
	local d = state.draft or {}
	if not d.artistId then
		return "artist"
	elseif #(d.shows or {}) == 0 then
		return "dates"
	elseif not d.pricesSet then
		return "tickets"
	elseif not d.stageSet then
		return "stage"
	end
	return "announce"
end

-- what the player should do next: { text, target = station id or nil }
function GS.objective(state)
	local un = GS.unlocks(state)
	local visited = state.visited or {}
	local active = nil
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			active = t
		end
	end
	local d = state.draft or {}
	if d.artistId then
		local name = Artists.byId[d.artistId].name
		local stage = GS.planStage(state)
		if stage == "dates" then
			return { text = "Plan the dates of " .. name .. "'s tour at the WORLD MAP table.", target = "maptable" }
		elseif stage == "tickets" then
			return { text = "Set the ticket prices on the LAPTOP (TOUR PLAN).", target = "laptop" }
		elseif stage == "stage" then
			return { text = "Pick or build the stage in the STAGE HALL.", target = "stagehall" }
		end
		return { text = "Check the plan on the LAPTOP and announce the tour!", target = "laptop" }
	end
	if #state.tours == 0 then
		return { text = "Sit down in the MEETING ROOM and pick the artist for your first tour.", target = "meeting" }
	end
	if un.charts and not visited.charts then
		return { text = "The CHARTS screen is on! See where your tours rank.", target = "charts" }
	end
	local talent = false
	for _, ad in ipairs(Artists.list) do
		if not state.artists[ad.id].signed and ad.level <= GS.level(state) and ad.signCost <= state.money then
			talent = true
		end
	end
	if talent and not visited.meeting and state.stats.shows >= 1 then
		return { text = "New talent wants to meet you. Sit down in the MEETING ROOM.", target = "meeting" }
	end
	if active then
		local nextDay = nil
		for _, s in ipairs(active.shows) do
			if not s.done and (not nextDay or s.day < nextDay) then
				nextDay = s.day
			end
		end
		if nextDay then
			local d = nextDay - state.day
			return { text = "Next show in " .. d .. " day" .. (d == 1 and "" or "s") .. ". Ticket sales are on the LAPTOP.", target = nil }
		end
	end
	return { text = "No tour on sale. Pick the next artist in the MEETING ROOM.", target = "meeting" }
end

------------------------------------------------------------------ designs
function GS.addDesign(state, name, items, class, layout)
	local d = { id = GS.newId(state, "d"), name = name, items = items or {}, class = class or "Arena", layout = layout or "end" }
	GS.ensureUids(d)
	table.insert(state.designs, d)
	return d
end

-- A new design built from a template (pays for the equipment). Returns design or nil, message
function GS.addDesignFromTemplate(state, preset, name)
	local cost = GS.designValue({ items = preset.items })
	if state.money < cost then
		return nil, "This template needs equipment worth " .. Util.money(cost) .. "."
	end
	if #state.designs >= Config.MAX_DESIGNS then
		return nil, "You can have up to " .. Config.MAX_DESIGNS .. " stages. Delete one first."
	end
	state.money = state.money - cost
	return GS.addDesign(state, name or preset.name, Util.deepCopy(preset.items), preset.class, preset.layout)
end

-- Places where the artist performs a song: artist spots, lifts and instruments the artist plays.
GS.PLAY_ITEMS = { lift = true, poplift = true, towerlift = true, piano = true, keys = true, drums = true, djbooth = true, acoustic = true, harp = true }
-- lifts: the artist comes up out of the stage (lift, pop-up) or is lifted high into the air (tower)
GS.LIFT_ITEMS = { lift = true, poplift = true, towerlift = true }

-- The setlist of a design. Lifts and instruments keep the song number set in the builder,
-- artist spots take the free song numbers in the order they were placed.
-- returns { count = songs, songOf = { [rec] = n }, place = { [n] = rec } }
-- A spot can also be a moment inside a song (rec.song = n, rec.mid = 0.25 / 0.5 / 0.75): the artist walks
-- there during song n ("2.5" = half way through song 2). It does not add a song.
function GS.isMoment(it)
	return it.t == "spot" and type(it.song) == "number" and type(it.mid) == "number" and it.mid > 0 and it.mid < 1
end
function GS.songPlan(design, extraSpot)
	local items = (design and design.items) or {}
	local place, songOf = {}, {}
	local moments, momentOf = {}, {}
	for _, it in ipairs(items) do
		if GS.isMoment(it) then
			moments[it.song] = moments[it.song] or {}
			table.insert(moments[it.song], { frac = it.mid, rec = it })
			momentOf[it] = it.song + it.mid
		end
	end
	for _, list in pairs(moments) do
		table.sort(list, function(a, b)
			return a.frac < b.frac
		end)
	end
	for _, it in ipairs(items) do
		if GS.PLAY_ITEMS[it.t] then
			local n = it.play
			if (it.t == "lift" or it.t == "poplift") and n == nil then
				n = 1
			end
			if type(n) == "number" and n >= 1 then
				songOf[it] = n
				place[n] = place[n] or it
			end
		end
	end
	local n = 1
	local function addSpot(it)
		while place[n] do
			n = n + 1
		end
		place[n] = it
		songOf[it] = n
	end
	for _, it in ipairs(items) do
		-- a tower lift without a fixed song takes the next free song like a spot
		if (it.t == "spot" and not momentOf[it]) or (it.t == "towerlift" and it.play == nil) then
			addSpot(it)
		end
	end
	if extraSpot then
		addSpot(extraSpot)
	end
	local top = 0
	for k in pairs(place) do
		if k > top then
			top = k
		end
	end
	local count = (top == 0) and 4 or Util.clamp(top, 3, StageItems.MAX_SPOTS)
	return { count = count, songOf = songOf, place = place, moments = moments, momentOf = momentOf }
end

-- number of songs a design plays (at least 3, nothing placed = 4)
function GS.songCount(design)
	return GS.songPlan(design).count
end

------------------------------------------------------------------ calendar: when is a venue free?
-- Venues host other events too (other bands, sport, fairs). This is the same in every game: a few days a month
-- are taken, stadiums more often (match days). Your own shows (any artist) also block the venue.
local BUSY_SHARE = { club = 0.12, theatre = 0.18, arena = 0.22, amphi = 0.2, stadium = 0.3 }
local function venueHash(id)
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 100003
	end
	return h
end
-- returns nil if free, otherwise a short reason
function GS.venueBusy(state, venueId, day, ignore)
	for _, t in ipairs(state.tours or {}) do
		if t ~= ignore then
			for _, s in ipairs(t.shows) do
				if s.venueId == venueId and s.day == day and not s.done then
					return Artists.byId[t.artistId].name
				end
			end
		end
	end
	local v = Countries.venueById[venueId]
	local look = Countries.VENUE_TYPES[v.type].look
	-- other events come in short runs: decide per 2-day block, then per day
	local h = venueHash(venueId)
	local block = math.floor(day / 2)
	local x = math.sin(block * 12.9898 + h * 0.78233) * 43758.5453
	x = x - math.floor(x)
	if x < (BUSY_SHARE[look] or 0.18) then
		local y = math.sin(day * 4.1414 + h * 1.337) * 9631.17
		y = y - math.floor(y)
		if y < 0.75 then
			return (look == "stadium") and "football" or "other event"
		end
	end
	return nil
end

-- the earliest free day for a show at a venue, not before `from` and not on a day of `taken` (set of days)
function GS.nextFreeDay(state, venueId, from, taken)
	for d = from, from + 120 do
		if not GS.venueBusy(state, venueId, d) and not (taken and taken[d]) then
			return d
		end
	end
	return from
end

-- days needed between two shows: the next day in the same country or a neighbour country,
-- one travel day in between on the same continent, two travel days to another continent
function GS.travelGap(a, b)
	if not a or not b then
		return 0
	end
	if a.venueId == b.venueId then
		return 1
	end
	return 1 + Countries.travelDays(Countries.venueById[a.venueId].countryId, Countries.venueById[b.venueId].countryId)
end

-- Show days of a route: another night in the same venue is the next day, a new venue `gap` days later
function GS.scheduleDays(startDay, shows, gap)
	local days = {}
	for i, s in ipairs(shows) do
		if i == 1 then
			days[i] = startDay
		elseif shows[i - 1].venueId == s.venueId then
			days[i] = days[i - 1] + 1
		else
			days[i] = days[i - 1] + gap
		end
	end
	return days
end

-- Buying / selling stage equipment
function GS.buyItem(state, design, rec)
	local def = StageItems.byId[rec.t]
	local price = Sim.itemPrice(def, rec)
	if state.money < price then
		return false, "Not enough money for " .. def.name .. " (" .. Util.money(price) .. ")."
	end
	state.money = state.money - price
	if type(rec.uid) ~= "string" then
		rec.uid = GS.uid()
	end
	table.insert(design.items, rec)
	return true
end

function GS.sellItem(state, design, rec)
	for i, r in ipairs(design.items) do
		if r == rec then
			table.remove(design.items, i)
			state.money = state.money + Util.round(Sim.itemPrice(StageItems.byId[rec.t], rec) * Config.RESALE)
			return true
		end
	end
	return false
end

-- Changes size/height of a placed item and pays (or refunds) the price difference
function GS.changeItem(state, rec, changes)
	local def = StageItems.byId[rec.t]
	local old = Sim.itemPrice(def, rec)
	local test = Util.deepCopy(rec)
	for k, v in pairs(changes) do
		test[k] = v
	end
	local diff = Sim.itemPrice(def, test) - old
	if diff > 0 and state.money < diff then
		return false, "Not enough money (" .. Util.money(diff) .. " needed)."
	end
	state.money = state.money - (diff > 0 and diff or Util.round(diff * Config.RESALE))
	for k, v in pairs(changes) do
		rec[k] = v
	end
	return true
end

function GS.designValue(design)
	return Sim.designStats(design, nil).value
end

-- stage size class of a venue: "Club" | "Theatre" | "Arena" | "Stadium"
function GS.venueClass(venue)
	return Countries.VENUE_TYPES[venue.type].stage
end

-- the production used for one show of a tour
function GS.showDesign(state, tour, idx)
	local v = Countries.venueById[tour.shows[idx].venueId]
	local id = tour.designs and tour.designs[GS.venueClass(v)] or tour.designId
	return GS.getDesign(state, id) or GS.getDesign(state, tour.designId)
end

function GS.getDesign(state, id)
	for _, d in ipairs(state.designs) do
		if d.id == id then
			return d
		end
	end
	return nil
end

function GS.designInUse(state, id)
	for _, t in ipairs(state.tours) do
		local used = t.designId == id
		for _, did in pairs(t.designs or {}) do
			if did == id then
				used = true
			end
		end
		if used and t.status ~= "done" then
			return true
		end
	end
	return false
end

function GS.deleteDesign(state, id)
	if GS.designInUse(state, id) then
		return false, "This design is used by an active tour."
	end
	if #state.designs <= 1 then
		return false, "You need at least one design."
	end
	for i, d in ipairs(state.designs) do
		if d.id == id then
			table.remove(state.designs, i)
			-- the example stages were free: deleting them gives no money back
			if not d.template then
				state.money = state.money + Util.round(GS.designValue(d) * Config.RESALE)
			end
			if state.draft and state.draft.designs then
				for cls, did in pairs(state.draft.designs) do
					if did == id then
						state.draft.designs[cls] = nil
					end
				end
			end
			return true
		end
	end
	return false, "Design not found."
end

------------------------------------------------------------------ tours
function GS.getTour(state, id)
	for _, t in ipairs(state.tours) do
		if t.id == id then
			return t
		end
	end
	return nil
end

function GS.tourCapacity(tour)
	local c = 0
	for _, s in ipairs(tour.shows) do
		c = c + s.cap
	end
	return c
end

function GS.marketingCost(tour, mk)
	return Util.round(mk.base + mk.perSeat * GS.tourCapacity(tour))
end

-- draft = { artistId, name, designId, firstIn, gap, watchFirst, shows = { {venueId, price} } }
function GS.createTour(state, draft)
	local ad = Artists.byId[draft.artistId or ""]
	if not ad or not state.artists[ad.id].signed then
		return false, "Pick an artist first."
	end
	if GS.activeTour(state, ad.id) then
		return false, ad.name .. " is already on tour."
	end
	if #draft.shows == 0 then
		return false, "Add at least one show (click a country, then + Add)."
	end
	if #draft.shows > Config.MAX_SHOWS_PER_TOUR then
		return false, "Too many shows (max " .. Config.MAX_SHOWS_PER_TOUR .. ")."
	end
	if state.money <= 0 then
		return false, "You are in debt! Earn money before announcing a new tour."
	end
	-- one stage production per venue size (club / theatre / arena / stadium)
	local designs = {}
	for _, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		if not v then
			return false, "Unknown venue."
		end
		if not GS.venueUnlocked(state, v) then
			return false, v.name .. " needs label level " .. GS.venueLevel(v) .. "."
		end
		local vc = GS.venueClass(v)
		local d = GS.getDesign(state, (draft.designs and draft.designs[vc]) or draft.designId or "")
		if not d then
			return false, "Pick a stage design for your " .. vc .. " venues."
		end
		if not Sim.designFits(d, v) then
			return false, "\"" .. d.name .. "\" (" .. d.class .. " stage) is too big for " .. v.name .. "."
		end
		designs[vc] = d.id
	end
	local design = GS.getDesign(state, designs[GS.venueClass(Countries.venueById[draft.shows[1].venueId])])
	local firstIn = Util.clamp(math.floor(draft.firstIn or Config.MIN_LEAD_DAYS), Config.MIN_LEAD_DAYS, Config.MAX_LEAD_DAYS)
	local gap = Util.clamp(math.floor(draft.gap or 2), 1, Config.MAX_GAP_DAYS)
	local name = draft.name
	if type(name) ~= "string" or name:gsub("%s", "") == "" then
		name = ad.name .. " World Tour"
	end

	local tour = {
		id = GS.newId(state, "t"),
		artistId = ad.id,
		name = name:sub(1, 40),
		price = math.max(5, math.floor(draft.price or 30)),
		designId = design.id,
		designs = designs,
		status = "announced",
		announcedDay = state.day,
		marketing = {},
		shows = {},
		gross = 0,
		net = 0,
		attendance = 0,
		sellouts = 0,
		played = 0,
		ratingSum = 0,
	}
	local prev = nil
	local dated = true
	for _, s in ipairs(draft.shows) do
		dated = dated and s.day ~= nil
	end
	if dated then
		table.sort(draft.shows, function(a, b)
			return a.day < b.day
		end)
		for i = 2, #draft.shows do
			if draft.shows[i].day == draft.shows[i - 1].day then
				return false, "Two shows on the same day. Move one of them in the calendar."
			end
		end
	end
	local days = GS.scheduleDays(state.day + firstIn, draft.shows, gap)
	for i, s in ipairs(draft.shows) do
		if s.day then
			days[i] = s.day
			if s.day <= state.day + 2 then
				return false, "A show date is too soon (the first show needs a few days of ticket sales)."
			end
			local busy = GS.venueBusy(state, s.venueId, s.day)
			if busy then
				return false, Countries.venueById[s.venueId].name .. " is not free on that day (" .. busy .. ")."
			end
		end
	end
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local look = Countries.VENUE_TYPES[v.type].look
		local prices = (draft.prices and draft.prices[look]) and Util.deepCopy(draft.prices[look]) or Sim.defaultPrices(draft.price or s.price or 30, look)
		table.insert(tour.shows, {
			venueId = v.id,
			countryId = v.countryId,
			cap = v.cap,
			prices = prices,
			price = Sim.avgPrice(look, prices),
			day = days[i],
			sold = 0,
			noise = 1 - Config.DEMAND_NOISE + math.random() * 2 * Config.DEMAND_NOISE,
			travel = Sim.travelCost(prev, v, #(GS.getDesign(state, designs[GS.venueClass(v)]) or design).items),
			done = false,
			-- you are asked to go to the opening night; the other shows run by themselves
			-- (pick them on the laptop: TOURS > WATCH)
			skipLive = (i > 1) or nil,
		})
		prev = v
	end
	tour.price = tour.shows[1].price
	table.insert(state.tours, 1, tour)
	Sim.updateTourSales(state, tour)
	GS.log(state, ad.name .. " announced \"" .. tour.name .. "\" (" .. #tour.shows .. " shows).")
	Social.onAnnounce(state, tour, Sim.ticketBase(state, ad.id))
	return true, tour
end

function GS.buyMarketing(state, tourId, mid)
	local tour = GS.getTour(state, tourId)
	if not tour or tour.status == "done" then
		return false, "Tour not active."
	end
	for _, mk in ipairs(Config.MARKETING) do
		if mk.id == mid then
			if tour.marketing[mid] then
				return false, "Already running."
			end
			local cost = GS.marketingCost(tour, mk)
			if state.money < cost then
				return false, "Not enough money."
			end
			state.money = state.money - cost
			tour.marketing[mid] = true
			Sim.updateTourSales(state, tour)
			return true, mk.name .. " campaign started (" .. Util.money(cost) .. ")."
		end
	end
	return false, "Unknown campaign."
end

function GS.setPrice(state, tourId, idx, price)
	local tour = GS.getTour(state, tourId)
	local s = tour and tour.shows[idx]
	if not s or s.done then
		return
	end
	s.price = Util.clamp(math.floor(price), 5, 2000)
	Sim.updateTourSales(state, tour)
end

-- One ticket price for the whole tour (only unplayed shows change)
function GS.setTourPrice(state, tourId, price)
	local tour = GS.getTour(state, tourId)
	if not tour or tour.status == "done" then
		return
	end
	local old = math.max(1, tour.price or price)
	tour.price = Util.clamp(math.floor(price), 5, 2000)
	local f = tour.price / old
	for _, s in ipairs(tour.shows) do
		if not s.done then
			local v = Countries.venueById[s.venueId]
			if s.prices then
				for id, p in pairs(s.prices) do
					s.prices[id] = Util.clamp(Util.round(p * f), 5, 4000)
				end
				s.price = Sim.avgPrice(Countries.VENUE_TYPES[v.type].look, s.prices)
			else
				s.price = tour.price
			end
		end
	end
	Sim.updateTourSales(state, tour)
end

function GS.cancelTour(state, tourId)
	local tour = GS.getTour(state, tourId)
	if not tour then
		return false, "Tour not found."
	end
	if tour.played > 0 then
		return false, "Shows were already played. You can't cancel anymore."
	end
	for i, t in ipairs(state.tours) do
		if t == tour then
			table.remove(state.tours, i)
			break
		end
	end
	local a = state.artists[tour.artistId]
	a.hype = Util.clamp(a.hype - 8, 0, 100)
	GS.log(state, "Cancelled \"" .. tour.name .. "\". Fans are disappointed (hype -8).")
	Social.add(state, "cancel", { artistId = tour.artistId, tour = tour }, 3)
	return true, "Tour cancelled. Tickets refunded."
end

------------------------------------------------------------------ shows
function GS.prepareShow(state, tour, idx, rnd)
	return Sim.showResult(state, tour, idx, GS.showDesign(state, tour, idx), rnd)
end

-- Applies a show result. Returns { completed = bool, achievements = {ids} }
function GS.applyShow(state, tour, idx, r)
	local s = tour.shows[idx]
	if s.done then
		return { completed = false, achievements = {} }
	end
	local v = Countries.venueById[s.venueId]
	local ad = Artists.byId[tour.artistId]
	local a = state.artists[tour.artistId]
	s.done = true
	s.sold = r.sold
	s.result = {
		sold = r.sold, gross = r.gross, net = r.net, stars = r.stars, rating = Util.round(r.rating), review = r.review,
		rent = r.rent, production = r.production, travel = r.travel, artistCut = r.artistCut, cap = r.cap, fansGained = r.fansGained,
	}

	state.money = state.money + r.net
	tour.gross = tour.gross + r.gross
	tour.net = tour.net + r.net
	tour.attendance = tour.attendance + r.sold
	tour.played = tour.played + 1
	tour.ratingSum = tour.ratingSum + r.rating
	tour.status = "touring"
	if r.soldOut then
		tour.sellouts = tour.sellouts + 1
	end

	-- fans: most of the new fans are local, some spread worldwide
	local gained = r.fansGained
	a.fans[r.region] = (a.fans[r.region] or 0) + math.floor(gained * 0.85)
	for rid, _ in pairs(a.fans) do
		if rid ~= r.region then
			a.fans[rid] = a.fans[rid] + math.floor(gained * 0.03)
		end
	end
	a.hype = Util.clamp(a.hype + r.hypeDelta, 0, 100)
	a.shows = a.shows + 1
	a.gross = a.gross + r.gross

	local st = state.stats
	st.shows = st.shows + 1
	st.tickets = st.tickets + r.sold
	st.totalGross = st.totalGross + r.gross
	if r.soldOut then
		st.sellouts = st.sellouts + 1
		if v.cap > st.biggestSellout then
			st.biggestSellout = v.cap
		end
	end
	if r.stars >= 5 then
		st.fiveStars = st.fiveStars + 1
	end
	if r.gross > st.bestShowGross then
		st.bestShowGross = r.gross
		st.bestShowText = ad.name .. " @ " .. v.name
	end

	Social.onShow(state, tour, idx, r, GS.showDesign(state, tour, idx))
	local completed = tour.played >= #tour.shows
	if completed then
		GS.finishTour(state, tour)
	end
	return { completed = completed, achievements = GS.checkAchievements(state) }
end

-- the last show of a tour is over (or the remaining ones were cancelled)
function GS.finishTour(state, tour)
	local a = state.artists[tour.artistId]
	local st = state.stats
	do
		tour.status = "done"
		tour.endDay = state.day
		local regions, nreg = {}, 0
		for _, sh in ipairs(tour.shows) do
			a.lastPlayed[sh.countryId] = state.day
			local reg = Countries.byId[sh.countryId].region
			if not regions[reg] then
				regions[reg] = true
				nreg = nreg + 1
			end
		end
		if nreg > st.maxRegions then
			st.maxRegions = nreg
		end
		if tour.gross > st.bestTourGross then
			st.bestTourGross = tour.gross
		end
		GS.log(state, "\"" .. tour.name .. "\" finished: " .. Util.money(tour.gross) .. " gross, " .. Util.number(tour.attendance) .. " fans.")
	end
end

-- what cancelling one show costs: the venue is paid anyway, fans who bought tickets are disappointed
function GS.cancelShowCost(state, tour, idx)
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local share = math.min(1, (s.sold or 0) / math.max(1, s.cap))
	return Sim.venueRent(v), math.floor(2 + share * 6 + 0.5)
end

function GS.cancelShow(state, tourId, idx)
	local tour = GS.getTour(state, tourId)
	local s = tour and type(idx) == "number" and tour.shows[idx]
	if not tour or not s or tour.status == "done" then
		return false, "Show not found."
	end
	if s.done then
		return false, "This show was already played."
	end
	if s.day <= state.day then
		return false, "The show is today. Too late to cancel."
	end
	if tour.played == 0 and #tour.shows <= 1 then
		return false, "This is the only show. Cancel the whole tour instead."
	end
	local cost, hype = GS.cancelShowCost(state, tour, idx)
	if state.money < cost and not state.sandbox then
		return false, "Not enough money to pay the venue (" .. Util.money(cost) .. ")."
	end
	local v = Countries.venueById[s.venueId]
	state.money = state.money - cost
	tour.net = tour.net - cost
	tour.cancelledShows = (tour.cancelledShows or 0) + 1
	local a = state.artists[tour.artistId]
	a.hype = Util.clamp(a.hype - hype, 0, 100)
	table.remove(tour.shows, idx)
	GS.log(state, "Cancelled " .. Artists.byId[tour.artistId].name .. " @ " .. v.name .. ": venue paid " .. Util.money(cost) .. ", hype -" .. hype .. ".")
	Social.add(state, "cancelshow", { artistId = tour.artistId, tour = tour, venueId = v.id }, 2)
	if tour.played >= #tour.shows then
		GS.finishTour(state, tour)
	else
		Sim.updateTourSales(state, tour)
	end
	return true, "Show in " .. v.city .. " cancelled. Venue paid (" .. Util.money(cost) .. "), fans are disappointed (hype -" .. hype .. ")."
end

-- Advances one day. Returns events for the UI.
function GS.advanceDay(state, rnd)
	state.day = state.day + 1
	local ev = { soldOut = {}, played = {}, live = {}, completed = {}, achievements = {} }

	for _, a in pairs(state.artists) do
		a.hype = a.hype + (40 - a.hype) * 0.004
	end

	-- iterate over a copy because tours can finish during the loop
	local active = {}
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			table.insert(active, t)
		end
	end
	for _, tour in ipairs(active) do
		for _, idx in ipairs(Sim.updateTourSales(state, tour)) do
			table.insert(ev.soldOut, { tour = tour, idx = idx })
			Social.onSoldOut(state, tour, idx)
		end
		-- a week before a show with weak sales the fans start to talk about it
		for idx, s in ipairs(tour.shows) do
			if not s.done and not s.lowPosted and s.day - state.day <= 7 and s.sold < s.cap * 0.5 then
				s.lowPosted = true
				Social.onLowSales(state, tour, idx)
			end
		end
		for idx, s in ipairs(tour.shows) do
			if not s.done and s.day <= state.day then
				-- every show of today is played live (the player goes there), unless it was set to "auto"
				if s.day == state.day and not s.skipLive then
					table.insert(ev.live, { tourId = tour.id, idx = idx })
				else
					local r = GS.prepareShow(state, tour, idx, rnd)
					local res = GS.applyShow(state, tour, idx, r)
					table.insert(ev.played, { tour = tour, idx = idx, result = r })
					if res.completed then
						table.insert(ev.completed, tour)
					end
					for _, id in ipairs(res.achievements) do
						table.insert(ev.achievements, id)
					end
				end
			end
		end
	end
	for _, id in ipairs(GS.checkAchievements(state)) do
		table.insert(ev.achievements, id)
	end
	Social.daily(state)
	ev.levelUp = GS.checkLevelUp(state)
	return ev
end

------------------------------------------------------------------ charts & goals
function GS.chart(state)
	local rows = {}
	for _, r in ipairs(Rivals) do
		table.insert(rows, { artist = r.artist, tour = r.tour, gross = r.gross, shows = r.shows, attendance = r.attendance, player = false })
	end
	for _, t in ipairs(state.tours) do
		if t.gross > 0 then
			table.insert(rows, {
				artist = Artists.byId[t.artistId].name,
				tour = t.name,
				gross = t.gross,
				shows = t.played,
				attendance = t.attendance,
				player = true,
				tourId = t.id,
				live = t.status ~= "done",
			})
		end
	end
	table.sort(rows, function(x, y)
		return x.gross > y.gross
	end)
	local best = nil
	for i, r in ipairs(rows) do
		r.rank = i
		if r.player and not best then
			best = i
		end
	end
	return rows, best
end

-- Returns the new level name if the label just levelled up
function GS.checkLevelUp(state)
	local lvl, def = GS.level(state)
	if lvl > (state.levelSeen or 1) then
		state.levelSeen = lvl
		if state.visited then
			state.visited.meeting = nil -- new talent wants to meet
		end
		GS.log(state, "Your label is now a " .. def.name .. "! New artists can be signed.")
		return def.name
	end
	return nil
end

function GS.checkAchievements(state)
	local st = state.stats
	local _, bestRank = GS.chart(state)
	local cond = {
		first_show = st.shows >= 1,
		first_sellout = st.sellouts >= 1,
		theatre_sellout = st.biggestSellout >= 2500,
		arena_sellout = st.biggestSellout >= 10000,
		stadium_sellout = st.biggestSellout >= 40000,
		mega_sellout = st.biggestSellout >= 80000,
		five_stars = st.fiveStars >= 1,
		sellouts_10 = st.sellouts >= 10,
		sellouts_50 = st.sellouts >= 50,
		tour_1m = st.bestTourGross >= 1000000,
		tour_10m = st.bestTourGross >= 10000000,
		tour_100m = st.bestTourGross >= 100000000,
		world_tour = st.maxRegions >= 4,
		chart_top10 = bestRank ~= nil and bestRank <= 10,
		chart_1 = bestRank == 1,
		rich = state.money >= 10000000,
		superstar = state.artists.nova ~= nil and state.artists.nova.signed,
	}
	local new = {}
	for _, ach in ipairs(Achievements.list) do
		if cond[ach.id] and not state.achievements[ach.id] then
			state.achievements[ach.id] = state.day
			table.insert(new, ach.id)
			GS.log(state, "Achievement unlocked: " .. ach.name)
		end
	end
	return new
end

return GS
