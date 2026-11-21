-- Simulation formulas: demand, ticket sales, production value, show results.
-- Pure Lua (no Roblox APIs) so it can be unit tested outside of Roblox.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local StageItems = require(Root.Data.StageItems)
local Reviews = require(Root.Data.Reviews)
local Util = require(Root.Logic.Util)

local Sim = {}

------------------------------------------------------------------ production
-- How many production points a venue of this size "expects"
function Sim.expectedProduction(cap)
	return 6 * math.sqrt(cap / 100)
end

-- Resizable items cost (and impress) more when they are bigger
function Sim.itemScale(def, rec)
	if not def.size or not rec then
		return 1
	end
	local sw = (rec.w or def.size.w) / def.size.w
	if def.shape == "round" or def.shape == "ring" or def.shape == "half" then
		return sw * sw
	end
	local sd = def.size.d and ((rec.d or def.size.d) / def.size.d) or 1
	return sw * sd
end

local function ledMult(rec, m)
	return (rec and rec.skin == "led") and m or 1
end

function Sim.itemPrice(def, rec)
	return Util.round(def.cost * Config.ITEM_PRICE_MULT * Sim.itemScale(def, rec) * ledMult(rec, 1.8))
end

function Sim.itemPts(def, rec)
	return def.pts * Sim.itemScale(def, rec) ^ 0.75 * ledMult(rec, 2)
end

-- Can this design be used in that venue? (stage class must not be bigger than the venue's)
function Sim.designFits(design, venue)
	local dc = Config.STAGE_CLASS_BY_ID[(design and design.class) or "Club"]
	local vc = Config.STAGE_CLASS_BY_ID[Countries.VENUE_TYPES[venue.type].stage]
	return dc.order <= vc.order
end

function Sim.designStats(design, genre)
	local st = { cost = 0, value = 0, raw = 0, eff = 0, count = 0, categories = 0 }
	if not design then
		return st
	end
	local tagMap = (genre and StageItems.GENRE_TAGS[genre]) or {}
	local cats = {}
	for _, it in ipairs(design.items) do
		local def = StageItems.byId[it.t]
		if def then
			st.count = st.count + 1
			local pts = Sim.itemPts(def, it)
			st.value = st.value + Sim.itemPrice(def, it)
			st.raw = st.raw + pts
			local mult = 1
			for _, tag in ipairs(def.tags) do
				local m = tagMap[tag]
				if m then
					mult = mult * m
				end
			end
			mult = Util.clamp(mult, 0.6, 1.7)
			st.eff = st.eff + pts * mult
			if not cats[def.cat] then
				cats[def.cat] = true
				st.categories = st.categories + 1
			end
		end
	end
	st.cost = Util.round(st.value * Config.PRODUCTION_RATE) -- running cost per show
	if st.categories >= 5 then
		st.eff = st.eff * 1.15
	elseif st.categories >= 4 then
		st.eff = st.eff * 1.1
	end
	return st
end

-- 0..100. Extra production beyond 1.7x of what the venue expects adds nothing (size limits: see Sim.designFits).
function Sim.productionScore(design, genre, cap)
	local st = Sim.designStats(design, genre)
	local expected = Sim.expectedProduction(cap)
	local maxFit = expected * 1.7
	local used = math.min(st.eff, maxFit)
	local ratio = used / expected
	local score = 100 * (1 - math.exp(-1.6 * ratio)) / (1 - math.exp(-1.6 * 1.7))
	return Util.clamp(score, 0, 100), st, expected, maxFit
end

------------------------------------------------------------------ seat sections (like a ticket shop seat map)
-- per venue look: share of the capacity, price factor against the base ticket price, standing or seated
Sim.SECTIONS = {
	club = {
		{ id = "ga", name = "Standing", share = 1, mult = 1, standing = true },
	},
	theatre = {
		{ id = "stalls", name = "Stalls (standing)", share = 0.5, mult = 1, standing = true },
		{ id = "circle", name = "Dress Circle", share = 0.3, mult = 1.15 },
		{ id = "upper", name = "Upper Circle", share = 0.2, mult = 0.75 },
	},
	arena = {
		{ id = "golden", name = "Golden Circle", share = 0.08, mult = 1.8, standing = true },
		{ id = "floor", name = "Floor (standing)", share = 0.27, mult = 1, standing = true },
		{ id = "lower", name = "Lower Tier", share = 0.4, mult = 1.15 },
		{ id = "upper", name = "Upper Tier", share = 0.25, mult = 0.75 },
	},
	amphi = {
		{ id = "pit", name = "Pit (standing)", share = 0.3, mult = 1.1, standing = true },
		{ id = "bowl", name = "Seated Bowl", share = 0.45, mult = 1 },
		{ id = "lawn", name = "Lawn", share = 0.25, mult = 0.65, standing = true },
	},
	stadium = {
		{ id = "golden", name = "Golden Circle", share = 0.07, mult = 1.9, standing = true },
		{ id = "field", name = "Field (standing)", share = 0.28, mult = 1, standing = true },
		{ id = "lower", name = "Lower Tier", share = 0.35, mult = 1.1 },
		{ id = "upper", name = "Upper Tier", share = 0.3, mult = 0.7 },
	},
}
function Sim.lookOf(venue)
	return Countries.VENUE_TYPES[venue.type].look
end
function Sim.sections(venue)
	return Sim.SECTIONS[Sim.lookOf(venue)] or Sim.SECTIONS.arena
end
-- default prices of the sections of a look for a base price
function Sim.defaultPrices(base, look)
	local out = {}
	for _, sec in ipairs(Sim.SECTIONS[look] or Sim.SECTIONS.arena) do
		out[sec.id] = math.max(5, Util.round(base * sec.mult))
	end
	return out
end
-- average ticket price (weighted by the size of the sections)
function Sim.avgPrice(look, prices)
	local sum, w = 0, 0
	for _, sec in ipairs(Sim.SECTIONS[look] or Sim.SECTIONS.arena) do
		sum = sum + (prices[sec.id] or 0) * sec.share
		w = w + sec.share
	end
	return math.max(5, Util.round(sum / math.max(0.01, w)))
end
-- Splits ticket buyers over the sections: a section that is cheap for what it offers sells faster,
-- an expensive one slower; fans who find a sold-out section partly move on to the others.
-- returns soldBy = { [id] = n }, total sold, gross
-- How keen fans are on each section: its share of the room times how its price compares with what
-- that section is worth (fair base price * the section's factor). A section at half its worth sells
-- about 3x faster, one at double its worth hardly sells. Without `fair` the average price is the yardstick.
function Sim.sectionWeights(look, prices, fair)
	local secs = Sim.SECTIONS[look] or Sim.SECTIONS.arena
	local avg = Sim.avgPrice(look, prices)
	fair = fair or avg
	local weight, sumW = {}, 0
	for _, sec in ipairs(secs) do
		local p = math.max(1, prices[sec.id] or avg * sec.mult)
		weight[sec.id] = sec.share * Sim.priceMult(fair * sec.mult, p)
		sumW = sumW + weight[sec.id]
	end
	return weight, sumW
end
-- how many fans (of those who would come at a fair price) want a ticket at these prices: 1 = all of them
function Sim.priceFactor(look, prices, fair)
	local _, sumW = Sim.sectionWeights(look, prices, fair)
	local share = 0
	for _, sec in ipairs(Sim.SECTIONS[look] or Sim.SECTIONS.arena) do
		share = share + sec.share
	end
	return sumW / math.max(0.01, share)
end

function Sim.splitSections(look, cap, prices, demand, fair)
	local secs = Sim.SECTIONS[look] or Sim.SECTIONS.arena
	local avg = Sim.avgPrice(look, prices)
	local want, room = {}, {}
	local weight, sumW = Sim.sectionWeights(look, prices, fair)
	local spill = 0
	for _, sec in ipairs(secs) do
		local c = math.floor(cap * sec.share)
		want[sec.id] = demand * weight[sec.id] / math.max(1e-6, sumW)
		room[sec.id] = c
		if want[sec.id] > c then
			spill = spill + (want[sec.id] - c) * 0.6
			want[sec.id] = c
		end
	end
	for _ = 1, 3 do
		if spill < 1 then
			break
		end
		local open = 0
		for _, sec in ipairs(secs) do
			if want[sec.id] < room[sec.id] then
				open = open + weight[sec.id]
			end
		end
		if open <= 0 then
			break
		end
		local s2 = spill
		spill = 0
		for _, sec in ipairs(secs) do
			if want[sec.id] < room[sec.id] then
				local add = s2 * weight[sec.id] / open
				want[sec.id] = want[sec.id] + add
				if want[sec.id] > room[sec.id] then
					spill = spill + (want[sec.id] - room[sec.id])
					want[sec.id] = room[sec.id]
				end
			end
		end
	end
	local soldBy, total, gross = {}, 0, 0
	for _, sec in ipairs(secs) do
		local n = math.floor(want[sec.id])
		soldBy[sec.id] = n
		total = total + n
		gross = gross + n * (prices[sec.id] or avg)
	end
	return soldBy, total, gross
end
-- prices of a show (old saves only have one price)
function Sim.showPrices(s, venue)
	if s.prices then
		return s.prices
	end
	local out = {}
	for _, sec in ipairs(Sim.sections(venue)) do
		out[sec.id] = s.price
	end
	return out
end

------------------------------------------------------------------ prices & demand
function Sim.ticketBase(state, artistId)
	local a = state.artists[artistId]
	local ad = Artists.byId[artistId]
	local total = Util.totalFans(a.fans)
	return (15 + 22 * math.log10(1 + total / 40000)) * ad.pricePower
end

function Sim.fairPrice(state, artistId, countryId)
	local c = Countries.byId[countryId]
	return math.max(5, Util.round(Sim.ticketBase(state, artistId) * c.priceLevel))
end

-- Number of people in a country who want to see this artist on one tour (at a fair price)
function Sim.countryPool(state, artistId, countryId)
	local a = state.artists[artistId]
	local ad = Artists.byId[artistId]
	local c = Countries.byId[countryId]
	local fans = a.fans[c.region] or 0
	local hypeMult = 0.6 + (a.hype / 100) * 0.8
	local genreMult = c.genres[ad.genre] or 1
	local fatigue = 1
	local last = a.lastPlayed[countryId]
	if last then
		fatigue = 0.45 + 0.55 * Util.clamp((state.day - last) / 180, 0, 1)
	end
	return fans * c.share * Config.ATTEND_RATE * hypeMult * genreMult * fatigue
end

function Sim.priceMult(fair, price)
	return Util.clamp((fair / math.max(1, price)) ^ 1.6, 0.05, 3)
end

-- shows: array of { venueId=, price=, noise=? }. Returns an array of demand (tickets wanted) per show.
-- Fans of a country are spread evenly over that country's shows ("water filling"): if a small venue
-- sells out, the fans who could not get a ticket move on to the other shows in the same country.
function Sim.demands(state, artistId, shows, mult)
	local byCountry, order = {}, {}
	for i, s in ipairs(shows) do
		local cid = Countries.venueById[s.venueId].countryId
		if not byCountry[cid] then
			byCountry[cid] = {}
			table.insert(order, cid)
		end
		table.insert(byCountry[cid], i)
	end
	local out = {}
	for _, cid in ipairs(order) do
		local idxs = byCountry[cid]
		local pool = Sim.countryPool(state, artistId, cid) * (mult or 1)
		local fair = Sim.fairPrice(state, artistId, cid)
		local pm, need, alloc, full = {}, {}, {}, {}
		for _, i in ipairs(idxs) do
			local s = shows[i]
			local v = Countries.venueById[s.venueId]
			if s.prices then
				pm[i] = Sim.priceFactor(Sim.lookOf(v), s.prices, fair) * (s.noise or 1)
			else
				pm[i] = Sim.priceMult(fair, s.price or fair) * (s.noise or 1)
			end
			need[i] = Countries.venueById[s.venueId].cap / pm[i] -- fans needed to sell out
			alloc[i] = 0
		end
		local remaining, open = pool, idxs
		for _ = 1, #idxs do
			if remaining <= 0 or #open == 0 then
				break
			end
			local per = remaining / #open
			remaining = 0
			local nextOpen = {}
			for _, i in ipairs(open) do
				local left = need[i] - alloc[i]
				if per >= left then
					alloc[i] = need[i]
					full[i] = true
					remaining = remaining + (per - left)
				else
					alloc[i] = alloc[i] + per
					table.insert(nextOpen, i)
				end
			end
			open = nextOpen
		end
		local even = pool / #idxs
		for _, i in ipairs(idxs) do
			local d = alloc[i] * pm[i]
			if full[i] then
				d = math.max(d, even * pm[i]) -- keeps "how hot" a sold-out show is (sells out earlier)
			end
			out[i] = d
		end
	end
	return out
end

function Sim.marketingMult(tour)
	local m = 1
	for _, mk in ipairs(Config.MARKETING) do
		if tour.marketing and tour.marketing[mk.id] then
			m = m * (1 + mk.boost)
		end
	end
	return m
end

-- Share of the final demand that has bought a ticket after `elapsed` of `total` pre-sale days
function Sim.salesFraction(elapsed, total)
	if total <= 0 then
		return 1
	end
	local tau = Util.clamp(elapsed / total, 0, 1)
	return 0.4 + 0.6 * tau ^ 0.8
end

-- Updates sold tickets of all unplayed shows. Returns list of show indexes that just sold out.
function Sim.updateTourSales(state, tour)
	local newlySoldOut = {}
	local d = Sim.demands(state, tour.artistId, tour.shows, Sim.marketingMult(tour))
	for i, s in ipairs(tour.shows) do
		if not s.done then
			s.demand = d[i]
			local total = s.day - tour.announcedDay
			local elapsed = state.day - tour.announcedDay
			local v = Countries.venueById[s.venueId]
			local soldBy, target = Sim.splitSections(Sim.lookOf(v), s.cap, Sim.showPrices(s, v), d[i] * Sim.salesFraction(elapsed, total), Sim.fairPrice(state, tour.artistId, v.countryId))
			s.secSold = s.secSold or {}
			local sum = 0
			for id, n in pairs(soldBy) do
				s.secSold[id] = math.max(s.secSold[id] or 0, n)
				sum = sum + s.secSold[id]
			end
			target = math.max(target, sum)
			if target > s.sold then
				s.sold = target
			end
			if s.sold >= s.cap and not s.soldOutDay then
				s.soldOutDay = state.day
				table.insert(newlySoldOut, i)
			end
		end
	end
	return newlySoldOut
end

-- Promoter advice: what venue size fits this artist in a country (ticket buyers at a fair price)
function Sim.recommendation(state, artistId, countryId)
	local pool = Sim.countryPool(state, artistId, countryId)
	local label
	if pool < 600 then
		label = "small clubs (under 600)"
	elseif pool < 2500 then
		label = "clubs or a small theatre (up to ~2,500)"
	elseif pool < 8000 then
		label = "theatres and halls (2,500 - 8,000)"
	elseif pool < 30000 then
		label = "an arena (10,000 - 25,000)"
	elseif pool < 90000 then
		label = "arenas, maybe several nights"
	else
		label = "stadiums"
	end
	return label, pool
end

------------------------------------------------------------------ costs
function Sim.venueRent(venue)
	local vt = Countries.VENUE_TYPES[venue.type]
	local c = Countries.byId[venue.countryId]
	return Util.round(500 + venue.cap * vt.rentPerSeat * c.priceLevel)
end

function Sim.travelCost(prevVenue, venue, itemCount)
	if prevVenue and prevVenue.id == venue.id then
		return 0 -- another night in the same venue: the stage stays up
	end
	local km = 0
	if prevVenue then
		if prevVenue.countryId == venue.countryId then
			km = 300
		else
			local a = Countries.byId[prevVenue.countryId]
			local b = Countries.byId[venue.countryId]
			km = Util.distanceKm(a.lat, a.lon, b.lat, b.lon)
		end
	end
	return Util.round((1000 + km * 1.2) * (1 + (itemCount or 0) / 40))
end

------------------------------------------------------------------ planner estimate
-- draft = { artistId=, designId=, shows = { {venueId=, price=}, ... } }
function Sim.estimate(state, draft, design)
	local res = { rows = {}, tickets = 0, capacity = 0, gross = 0, costs = 0, net = 0 }
	if not draft.artistId or #draft.shows == 0 then
		return res
	end
	-- design can be one design or a function(venue) -> design (one production per venue size)
	local function stFor(v)
		local dd = design
		if type(design) == "function" then
			dd = design(v)
		end
		return Sim.designStats(dd, nil)
	end
	local d = Sim.demands(state, draft.artistId, draft.shows, 1)
	local prev = nil
	for i, s in ipairs(draft.shows) do
		local v = Countries.venueById[s.venueId]
		local prices = Sim.showPrices(s, v)
		local fair = Sim.fairPrice(state, draft.artistId, v.countryId)
		local _, sold, gross = Sim.splitSections(Sim.lookOf(v), v.cap, prices, d[i], fair)
		local rent = Sim.venueRent(v)
		local st = stFor(v)
		local travel = Sim.travelCost(prev, v, st.count)
		local cut = Util.round(gross * Config.ARTIST_SHARE)
		local costs = rent + st.cost + travel + cut + Sim.dancersAt(draft, v) * Config.DANCER_COST
		local n = Config.DEMAND_NOISE
		local low = math.min(1, d[i] * (1 - n) / v.cap)
		local high = math.min(1, d[i] * (1 + n) / v.cap)
		local _, soldLo, grossLo = Sim.splitSections(Sim.lookOf(v), v.cap, prices, d[i] * (1 - n), fair)
		local _, soldHi, grossHi = Sim.splitSections(Sim.lookOf(v), v.cap, prices, d[i] * (1 + n), fair)
		low, high = soldLo / v.cap, soldHi / v.cap
		res.rows[i] = { demand = d[i], sold = sold, fill = sold / v.cap, fillLow = low, fillHigh = high, gross = gross, costs = costs, net = gross - costs }
		res.grossLow = (res.grossLow or 0) + grossLo
		res.grossHigh = (res.grossHigh or 0) + grossHi
		res.tickets = res.tickets + sold
		res.capacity = res.capacity + v.cap
		res.gross = res.gross + gross
		res.costs = res.costs + costs
		prev = v
	end
	res.net = res.gross - res.costs
	res.netLow = (res.grossLow or 0) - res.costs + Util.round((res.gross - (res.grossLow or 0)) * Config.ARTIST_SHARE)
	res.netHigh = (res.grossHigh or 0) - res.costs - Util.round(((res.grossHigh or 0) - res.gross) * Config.ARTIST_SHARE)
	return res
end

-- background dancers of a tour at this venue (solo artists only, never in clubs)
function Sim.dancersAt(tour, venue)
	local ad = Artists.byId[tour.artistId or ""]
	if not ad or ad.members ~= 1 or Sim.lookOf(venue) == "club" then
		return 0
	end
	return Util.clamp(math.floor(tonumber(tour.dancers) or 0), 0, Config.MAX_DANCERS)
end

------------------------------------------------------------------ show result
function Sim.showResult(state, tour, idx, design, rnd)
	rnd = rnd or math.random
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local c = Countries.byId[v.countryId]
	local ad = Artists.byId[tour.artistId]

	local sold = math.min(s.sold, v.cap)
	local prices = Sim.showPrices(s, v)
	local gross = 0
	if s.secSold then
		local n = 0
		for id, k in pairs(s.secSold) do
			gross = gross + k * (prices[id] or s.price)
			n = n + k
		end
		gross = gross + math.max(0, sold - n) * s.price
	else
		gross = sold * s.price
	end
	local rent = Sim.venueRent(v)
	local prodScore, st = Sim.productionScore(design, ad.genre, v.cap)
	local travel = s.travel or 0
	local cut = Util.round(gross * Config.ARTIST_SHARE)
	local dancers = Sim.dancersAt(tour, v)
	local dancerCost = dancers * Config.DANCER_COST
	local net = gross - rent - st.cost - travel - cut - dancerCost
	local fill = sold / v.cap

	local rating = 0.45 * ad.skill + 0.45 * prodScore + 10 * fill - 5 + (rnd() * 8 - 4) + dancers * Config.DANCER_RATING
	rating = Util.clamp(rating, 1, 100)
	local stars = 1
	if rating >= 88 then
		stars = 5
	elseif rating >= 75 then
		stars = 4
	elseif rating >= 60 then
		stars = 3
	elseif rating >= 45 then
		stars = 2
	end

	local list = Reviews[stars]
	local review = list[math.floor(rnd() * #list) + 1] or list[1]
	review = review:gsub("{artist}", ad.name):gsub("{venue}", v.name):gsub("{city}", v.city)

	local soldOut = sold >= v.cap
	-- word of mouth: good reviews spread to fans who were not there (diminishing for huge artists)
	local regionFans = state.artists[tour.artistId].fans[c.region] or 0
	local buzz = regionFans * 0.012 * math.max(0, stars - 2) / (1 + regionFans / 2000000)
	return {
		sold = sold,
		cap = v.cap,
		fill = fill,
		price = s.price,
		secSold = s.secSold,
		gross = gross,
		rent = rent,
		production = st.cost + dancerCost,
		dancers = dancers,
		travel = travel,
		artistCut = cut,
		net = net,
		rating = rating,
		stars = stars,
		prodScore = prodScore,
		fansGained = math.floor(sold * (0.5 + 3 * (rating / 100) ^ 2) + buzz),
		hypeDelta = (rating - 60) / 12 + (soldOut and 1 or -0.5),
		review = review,
		soldOut = soldOut,
		region = c.region,
	}
end

return Sim
