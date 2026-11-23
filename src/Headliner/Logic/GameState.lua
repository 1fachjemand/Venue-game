-- Game state: everything that gets saved. Pure Lua (no Roblox APIs).
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Dancers = require(Root.Data.Dancers)
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
		dancers = {}, -- signed background dancers: [id] = { skill, shows, trainUntil }
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
	state.artists[starter.id].signFans = Util.totalFans(state.artists[starter.id].fans)
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

-- tours that are announced or running (not finished)
function GS.runningTours(state)
	local n = 0
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			n = n + 1
		end
	end
	return n
end
function GS.maxTours(state)
	if state.sandbox then
		return 99
	end
	return Config.MAX_TOURS[GS.level(state)] or 1
end
-- the next level that allows one more tour at the same time (nil = none)
function GS.moreToursAt(state)
	local now = GS.maxTours(state)
	for i = GS.level(state) + 1, #Config.LEVELS do
		if (Config.MAX_TOURS[i] or 1) > now then
			return i
		end
	end
	return nil
end

-- how much rest an artist needs after a tour (some need a long break, some hardly any)
local function seedOf(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end
function GS.restDays(artistId, showsPlayed)
	local f = 0.25 + (seedOf(artistId) % 9) / 8 -- 0.25 .. 1.25
	local d = (Config.REST_BASE + Config.REST_PER_SHOW * (showsPlayed or 0)) * f
	return math.floor(Util.clamp(d, 2, Config.REST_MAX) + 0.5)
end
-- days left of an artist's break after a tour (0 = ready)
function GS.restLeft(state, artistId)
	local a = state.artists[artistId]
	if state.sandbox or not a or not a.restUntil then
		return 0
	end
	return math.max(0, a.restUntil - state.day)
end
-- unsigned artists are sometimes busy (album, another label's tour, holiday). Deterministic per artist
-- and day, starters and roughly half of the artists are never busy, so there is always talent around.
GS.BUSY_REASONS = { "is recording a new album", "is on tour with another label", "is taking a break", "is writing songs in the studio", "is on holiday" }
function GS.artistBusy(state, artistId)
	local ad = Artists.byId[artistId]
	if state.sandbox or not ad or ad.starter or state.artists[artistId].signed then
		return nil
	end
	local h = seedOf(artistId .. "busy")
	if h % 2 == 0 then
		return nil
	end
	local cycle = Config.ARTIST_BUSY_CYCLE
	local phase = (state.day + h) % cycle
	local busyLen = math.floor(cycle * (0.25 + (h % 5) / 20)) -- 25 .. 45 % of the time
	if phase < busyLen then
		return GS.BUSY_REASONS[h % #GS.BUSY_REASONS + 1], busyLen - phase
	end
	return nil
end
-- can a new tour be planned for this artist now? ok, reason
function GS.canPlan(state, artistId)
	local ad = Artists.byId[artistId or ""]
	local a = ad and state.artists[ad.id]
	if not a or not a.signed then
		return false, "Pick an artist first."
	end
	if GS.activeTour(state, ad.id) then
		return false, ad.name .. " is already on tour."
	end
	local rest = GS.restLeft(state, ad.id)
	if rest > 0 then
		return false, ad.name .. " needs a break after the last tour: " .. rest .. " more day" .. (rest == 1 and "" or "s") .. "."
	end
	if (state.draft or {}).artistId ~= ad.id and GS.runningTours(state) >= GS.maxTours(state) then
		local nxt = GS.moreToursAt(state)
		return false, "Your crew can only handle " .. GS.maxTours(state) .. " tour" .. (GS.maxTours(state) == 1 and "" or "s") .. " at a time" .. (nxt and (" (more at level " .. nxt .. ")") or "") .. "."
	end
	return true
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
	-- a level once reached is never lost (also when the level steps were made bigger in an update)
	lvl = math.max(lvl, math.min(#Config.LEVELS, math.floor(tonumber(state.levelSeen) or 1)))
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
	local busy, days = GS.artistBusy(state, ad.id)
	if busy then
		return false, ad.name .. " " .. busy .. ". Ask again in " .. days .. " days."
	end
	if state.money < ad.signCost then
		return false, "Not enough money to sign " .. ad.name .. "."
	end
	state.money = state.money - ad.signCost
	a.signed = true
	a.signFans = Util.totalFans(a.fans) -- growth bonuses count from here (Config.GROWTH)
	GS.log(state, "Signed " .. ad.name .. " for " .. Util.money(ad.signCost) .. "!")
	Social.add(state, "sign", { artistId = ad.id }, 2)
	return true, ad.name .. " joined your label!"
end

------------------------------------------------------------------ background dancers (Data/Dancers.lua)
function GS.myDancers(state)
	state.dancers = state.dancers or {}
	return state.dancers
end
-- why a signed dancer can't go on a tour now (nil = ready): in training, or on another tour that is not done
function GS.dancerBusy(state, id, ignoreTourId)
	local dd = GS.myDancers(state)[id]
	if not dd then
		return "not signed"
	end
	if (dd.trainUntil or 0) > state.day then
		return "in training (" .. (dd.trainUntil - state.day) .. " days)"
	end
	for _, t in ipairs(state.tours or {}) do
		if t.status ~= "done" and t.id ~= ignoreTourId then
			for _, did in ipairs(t.dancerIds or {}) do
				if did == id then
					return "on tour with " .. (Artists.byId[t.artistId] and Artists.byId[t.artistId].name or "an artist")
				end
			end
		end
	end
	return nil
end
function GS.signDancer(state, id)
	local d = Dancers.byId[id or ""]
	local mine = GS.myDancers(state)
	if not d then
		return false, "Unknown dancer."
	end
	if mine[id] then
		return false, "Already signed."
	end
	local n = 0
	for _ in pairs(mine) do
		n = n + 1
	end
	if n >= Dancers.MAX_SIGNED then
		return false, "You have " .. Dancers.MAX_SIGNED .. " dancers already."
	end
	if state.money < d.fee then
		return false, "Not enough money to sign " .. d.name .. "."
	end
	state.money = state.money - d.fee
	mine[id] = { skill = d.skill, shows = 0, trainUntil = 0 }
	GS.log(state, d.name .. " dances for your label now.")
	return true, d.name .. " signed!"
end
function GS.releaseDancer(state, id)
	local mine = GS.myDancers(state)
	if not mine[id] then
		return false, "Not signed."
	end
	if GS.dancerBusy(state, id) and GS.dancerBusy(state, id):find("^on tour") then
		return false, "On tour right now."
	end
	mine[id] = nil
	return true, "Released."
end
function GS.trainDancer(state, id)
	local mine = GS.myDancers(state)
	local dd = mine[id]
	if not dd then
		return false, "Not signed."
	end
	local busy = GS.dancerBusy(state, id)
	if busy then
		return false, "Can't train now: " .. busy .. "."
	end
	if dd.skill >= 99 then
		return false, "Already the best."
	end
	local cost = Dancers.trainCost(dd.skill)
	if state.money < cost then
		return false, "Not enough money for the training (" .. Util.money(cost) .. ")."
	end
	state.money = state.money - cost
	dd.skill = math.min(99, dd.skill + Dancers.TRAIN_GAIN)
	dd.trainUntil = state.day + Dancers.TRAIN_DAYS
	return true, (Dancers.byId[id] and Dancers.byId[id].name or "") .. " is training for " .. Dancers.TRAIN_DAYS .. " days."
end

-- days on the road: from the first to the last show (the artist allows at most ad.maxTourDays)
function GS.tourSpan(shows, extraDay)
	local lo, hi = extraDay, extraDay
	for _, s in ipairs(shows or {}) do
		if s.day then
			lo = lo and math.min(lo, s.day) or s.day
			hi = hi and math.max(hi, s.day) or s.day
		end
	end
	if not lo then
		return 0
	end
	return hi - lo + 1
end
function GS.maxTourDays(artistId)
	local ad = Artists.byId[artistId or ""]
	return (ad and ad.maxTourDays) or 60
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
		if not state.artists[ad.id].signed and ad.level <= GS.level(state) and ad.signCost <= state.money and not GS.artistBusy(state, ad.id) then
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
GS.PLAY_ITEMS = { lift = true, poplift = true, towerlift = true, piano = true, keys = true, drums = true, djbooth = true, acoustic = true, harp = true, micstand = true, showerstage = true, flyharness = true, descendcube = true, gownriser = true, floatplat = true }
-- lifts: the artist comes up out of the stage (lift, pop-up) or is lifted high into the air (tower)
GS.LIFT_ITEMS = { lift = true, poplift = true, towerlift = true }
-- built into the stage for the whole tour (like on real tours): the crew never carries these on and off
GS.FIXED_ITEMS = { lift = true, poplift = true, towerlift = true, showerstage = true, flyharness = true, descendcube = true, gownriser = true, floatplat = true }
-- a lift can be used twice: rec.play2 = a second song (e.g. the entrance in song 1 and the exit in the finale)
GS.TWICE_ITEMS = { lift = true, poplift = true }

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
	local place, songOf, againOf = {}, {}, {}
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
			local n2 = it.play2
			if GS.TWICE_ITEMS[it.t] and type(n2) == "number" and n2 >= 1 and n2 ~= n then
				place[n2] = place[n2] or it
				againOf[it] = n2
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
	return { count = count, songOf = songOf, againOf = againOf, place = place, moments = moments, momentOf = momentOf }
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
	if GS.restLeft(state, ad.id) > 0 then
		return false, ad.name .. " needs a break after the last tour (" .. GS.restLeft(state, ad.id) .. " more days)."
	end
	if GS.runningTours(state) >= GS.maxTours(state) then
		return false, "Your crew can only handle " .. GS.maxTours(state) .. " tour" .. (GS.maxTours(state) == 1 and "" or "s") .. " at a time. Wait until one is finished."
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
		dancers = (ad.members == 1) and Util.clamp(math.floor(tonumber(draft.dancers) or 0), 0, Config.MAX_DANCERS) or 0,
		dancerIds = nil,
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
	-- the signed dancers chosen for this tour (ready ones only); without a choice the old count stays
	if ad.members == 1 and type(draft.dancerIds) == "table" then
		local ids = {}
		for _, id in ipairs(draft.dancerIds) do
			if #ids < Config.MAX_DANCERS and GS.myDancers(state)[id] and not GS.dancerBusy(state, id) then
				table.insert(ids, id)
			end
		end
		tour.dancerIds = ids
		tour.dancers = #ids
	end
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
	-- the dancers of the tour learn with every show (only where they danced: not in clubs)
	if tour.dancerIds and (r.dancers or 0) > 0 then
		for _, id in ipairs(tour.dancerIds) do
			local dd = GS.myDancers(state)[id]
			if dd then
				dd.shows = (dd.shows or 0) + 1
				dd.skill = math.min(99, dd.skill + Dancers.SHOW_GAIN)
			end
		end
	end
	-- word of mouth (social media): the opening night counts most, later 5-star shows add a little
	if tour.played == 1 then
		local b = ({ 0.88, 0.94, 1.0, 1.12, 1.25 })[Util.clamp(r.stars or 3, 1, 5)]
		tour.buzz = b
		if b > 1 then
			Social.add(state, "buzz", { artistId = tour.artistId, venueId = s.venueId, tour = tour }, 2)
		end
	elseif (r.stars or 0) >= 5 then
		tour.buzz = math.min(1.4, (tour.buzz or 1) + 0.03)
	end
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
		local played = 0
		for _, sh in ipairs(tour.shows) do
			if sh.done and not sh.cancelled then
				played = played + 1
			end
		end
		a.restUntil = state.day + GS.restDays(tour.artistId, played)
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

-- the values the achievements measure (Data/Achievements: stat)
function GS.achievementStats(state)
	local st = state.stats
	local _, bestRank = GS.chart(state)
	local signed, toursDone, countries, designs, biggest = 0, 0, {}, 0, 0
	for _, a in pairs(state.artists) do
		if a.signed then
			signed = signed + 1
		end
	end
	for _, t in ipairs(state.tours or {}) do
		if t.status == "done" then
			toursDone = toursDone + 1
		end
		for _, sh in ipairs(t.shows or {}) do
			local v = sh.done and Countries.venueById[sh.venueId]
			if v then
				countries[v.countryId] = true
			end
		end
	end
	local nCountries = 0
	for _ in pairs(countries) do
		nCountries = nCountries + 1
	end
	for _, d in ipairs(state.designs or {}) do
		if not d.template then
			designs = designs + 1
		end
		biggest = math.max(biggest, #(d.items or {}))
	end
	return {
		shows = st.shows,
		sellouts = st.sellouts,
		tickets = st.tickets,
		totalGross = st.totalGross,
		fiveStars = st.fiveStars,
		biggestSellout = st.biggestSellout,
		bestTourGross = st.bestTourGross,
		maxRegions = st.maxRegions,
		money = state.money,
		signed = signed,
		toursDone = toursDone,
		countries = nCountries,
		level = GS.level(state),
		nova = (state.artists.nova ~= nil and state.artists.nova.signed) and 1 or 0,
		designs = designs,
		biggestStage = biggest,
		rank = bestRank,
	}
end

-- how far an achievement is: value, goal, done (rank: lower is better)
function GS.achievementProgress(ach, vals)
	local v = vals[ach.stat]
	if ach.stat == "rank" then
		return v or 0, ach.goal, v ~= nil and v <= ach.goal
	end
	v = v or 0
	return v, ach.goal, v >= ach.goal
end

-- growing a small artist pays: a bonus every time a signed artist's fans reach 2x, 5x, 10x, 25x, 50x of what
-- they had when you signed them (newcomers pay the most). returns ids "grow:<artist>:<x>:<reward>"
function GS.checkGrowth(state)
	local out = {}
	for _, ad in ipairs(Artists.list) do
		local a = state.artists[ad.id]
		if a and a.signed then
			local total = Util.totalFans(a.fans)
			if not a.signFans or a.signFans <= 0 then
				a.signFans = total -- (older saves: counted from now on)
			end
			a.growth = a.growth or {}
			local f = total / a.signFans
			for _, g in ipairs(Config.GROWTH) do
				local key = tostring(g.x)
				if f >= g.x and not a.growth[key] then
					a.growth[key] = state.day
					local reward = Util.round(g.reward * (Config.GROWTH_TIER[ad.tier or 3] or 1) / 1000) * 1000
					if not state.sandbox then
						state.money = state.money + reward
					end
					GS.log(state, ad.name .. " has " .. g.x .. "x the fans since you signed them: bonus " .. Util.money(reward))
					table.insert(out, "grow:" .. ad.id .. ":" .. g.x .. ":" .. reward)
				end
			end
		end
	end
	return out
end

-- unlocks reached achievements and pays their reward (in the sandbox the money stays as it is)
function GS.checkAchievements(state)
	local vals = GS.achievementStats(state)
	local new = {}
	for _, ach in ipairs(Achievements.list) do
		if not state.achievements[ach.id] then
			local _, _, done = GS.achievementProgress(ach, vals)
			if done then
				state.achievements[ach.id] = state.day
				table.insert(new, ach.id)
				if (ach.reward or 0) > 0 and not state.sandbox then
					state.money = state.money + ach.reward
				end
				GS.log(state, "Achievement unlocked: " .. ach.name .. ((ach.reward or 0) > 0 and (" (+" .. Util.money(ach.reward) .. ")") or ""))
			end
		end
	end
	for _, id in ipairs(GS.checkGrowth(state)) do
		table.insert(new, id)
	end
	return new
end

return GS
