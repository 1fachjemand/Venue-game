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
	if def.shape == "round" then
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
			pm[i] = Sim.priceMult(fair, s.price) * (s.noise or 1)
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
			local target = math.floor(math.min(s.cap, d[i] * Sim.salesFraction(elapsed, total)))
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
		local sold = math.floor(math.min(v.cap, d[i]))
		local gross = sold * s.price
		local rent = Sim.venueRent(v)
		local st = stFor(v)
		local travel = Sim.travelCost(prev, v, st.count)
		local cut = Util.round(gross * Config.ARTIST_SHARE)
		local costs = rent + st.cost + travel + cut
		local n = Config.DEMAND_NOISE
		local low = math.min(1, d[i] * (1 - n) / v.cap)
		local high = math.min(1, d[i] * (1 + n) / v.cap)
		res.rows[i] = { demand = d[i], sold = sold, fill = sold / v.cap, fillLow = low, fillHigh = high, gross = gross, costs = costs, net = gross - costs }
		res.grossLow = (res.grossLow or 0) + math.floor(low * v.cap) * s.price
		res.grossHigh = (res.grossHigh or 0) + math.floor(high * v.cap) * s.price
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

------------------------------------------------------------------ show result
function Sim.showResult(state, tour, idx, design, rnd)
	rnd = rnd or math.random
	local s = tour.shows[idx]
	local v = Countries.venueById[s.venueId]
	local c = Countries.byId[v.countryId]
	local ad = Artists.byId[tour.artistId]

	local sold = math.min(s.sold, v.cap)
	local gross = sold * s.price
	local rent = Sim.venueRent(v)
	local prodScore, st = Sim.productionScore(design, ad.genre, v.cap)
	local travel = s.travel or 0
	local cut = Util.round(gross * Config.ARTIST_SHARE)
	local net = gross - rent - st.cost - travel - cut
	local fill = sold / v.cap

	local rating = 0.45 * ad.skill + 0.45 * prodScore + 10 * fill - 5 + (rnd() * 8 - 4)
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
		gross = gross,
		rent = rent,
		production = st.cost,
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
