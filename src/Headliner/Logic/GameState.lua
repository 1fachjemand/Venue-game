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

function GS.new(labelName, starterId)
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
	return state
end

-- Repairs / upgrades a loaded save so missing fields never crash the game
function GS.sanitize(data)
	if type(data) ~= "table" or data.version ~= Config.SAVE_VERSION then
		return GS.new()
	end
	local fresh = GS.new()
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

function GS.unsignedArtists(state)
	local out = {}
	for _, ad in ipairs(Artists.list) do
		if not state.artists[ad.id].signed then
			table.insert(out, ad)
		end
	end
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

------------------------------------------------------------------ designs
function GS.addDesign(state, name, items, class, layout)
	local d = { id = GS.newId(state, "d"), name = name, items = items or {}, class = class or "Arena", layout = layout or "end" }
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
GS.PLAY_ITEMS = { lift = true, poplift = true, towerlift = true, piano = true, keys = true, drums = true, djbooth = true }
-- lifts: the artist comes up out of the stage (lift, pop-up) or is lifted high into the air (tower)
GS.LIFT_ITEMS = { lift = true, poplift = true, towerlift = true }

-- The setlist of a design. Lifts and instruments keep the song number set in the builder,
-- artist spots take the free song numbers in the order they were placed.
-- returns { count = songs, songOf = { [rec] = n }, place = { [n] = rec } }
function GS.songPlan(design, extraSpot)
	local items = (design and design.items) or {}
	local place, songOf = {}, {}
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
		if it.t == "spot" or (it.t == "towerlift" and it.play == nil) then
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
	return { count = count, songOf = songOf, place = place }
end

-- number of songs a design plays (at least 3, nothing placed = 4)
function GS.songCount(design)
	return GS.songPlan(design).count
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
	local target = GS.getDesign(state, id)
	if target and target.template then
		return false, "Templates can't be deleted. Use CLEAR to remove what you built."
	end
	for i, d in ipairs(state.designs) do
		if d.id == id then
			table.remove(state.designs, i)
			state.money = state.money + Util.round(GS.designValue(d) * Config.RESALE)
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
	local days = GS.scheduleDays(state.day + firstIn, draft.shows, gap)
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		table.insert(tour.shows, {
			venueId = v.id,
			countryId = v.countryId,
			cap = v.cap,
			price = math.max(5, math.floor(draft.price or s.price or 30)),
			day = days[i],
			sold = 0,
			noise = 1 - Config.DEMAND_NOISE + math.random() * 2 * Config.DEMAND_NOISE,
			travel = Sim.travelCost(prev, v, #(GS.getDesign(state, designs[GS.venueClass(v)]) or design).items),
			done = false,
			watch = (i == 1) and (draft.watchFirst == true),
		})
		prev = v
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
	tour.price = Util.clamp(math.floor(price), 5, 2000)
	for _, s in ipairs(tour.shows) do
		if not s.done then
			s.price = tour.price
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
	s.result = { sold = r.sold, gross = r.gross, net = r.net, stars = r.stars, rating = Util.round(r.rating), review = r.review }

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
	return { completed = completed, achievements = GS.checkAchievements(state) }
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
				if s.watch and s.day == state.day then
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
