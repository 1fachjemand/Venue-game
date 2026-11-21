-- Everything that changes the game state, by name. The server runs these on the real game state
-- (the client only asks for them). Pure Lua (no Roblox APIs), so the logic tests can run it too.
-- Actions.run(state, name, args) -> ok, message, data
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local StageItems = require(Root.Data.StageItems)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)

local Actions = {}
local A = {}
Actions.handlers = A

local function str(x, maxLen)
	if type(x) ~= "string" then
		return nil
	end
	x = x:gsub("^%s+", ""):gsub("%s+$", "")
	if #x == 0 then
		return nil
	end
	return x:sub(1, maxLen or 40)
end

local function num(x)
	if type(x) ~= "number" or x ~= x or x == math.huge or x == -math.huge then
		return nil
	end
	return x
end

local function tourShow(state, tourId, idx)
	local tour = GS.getTour(state, tourId)
	local s = tour and type(idx) == "number" and tour.shows[idx]
	return tour, s
end

-- day events with ids instead of table references (they go over the network)
local function serializeDay(ev)
	local out = { soldOut = {}, played = {}, live = {}, completed = {}, achievements = ev.achievements or {}, levelUp = ev.levelUp }
	for _, so in ipairs(ev.soldOut or {}) do
		table.insert(out.soldOut, { tourId = so.tour.id, idx = so.idx })
	end
	for _, p in ipairs(ev.played or {}) do
		table.insert(out.played, { tourId = p.tour.id, idx = p.idx, result = p.result })
	end
	for _, l in ipairs(ev.live or {}) do
		table.insert(out.live, { tourId = l.tourId, idx = l.idx })
	end
	for _, t in ipairs(ev.completed or {}) do
		table.insert(out.completed, t.id)
	end
	return out
end
Actions.serializeDay = serializeDay

local function merge(into, ev)
	for _, k in ipairs({ "soldOut", "played", "live", "completed", "achievements" }) do
		for _, x in ipairs(ev[k]) do
			table.insert(into[k], x)
		end
	end
	into.levelUp = ev.levelUp or into.levelUp
end

------------------------------------------------------------------ time & shows
function A.nextDay(state)
	-- shows of today must be played (or skipped) before the next day starts
	for _, t in ipairs(state.tours) do
		for _, s in ipairs(t.shows) do
			if not s.done and s.day <= state.day then
				return false, "A show is waiting for you today."
			end
		end
	end
	return true, nil, serializeDay(GS.advanceDay(state))
end

-- plays one show of today (live or skipped): the result is decided and applied right away
function A.playShow(state, a)
	local tour, s = tourShow(state, a.tourId, a.idx)
	if not s or s.done then
		return false, "This show was already played."
	end
	if s.day > state.day then
		return false, "This show is not today."
	end
	local r = GS.prepareShow(state, tour, a.idx)
	local res = GS.applyShow(state, tour, a.idx, r)
	return true, nil, { result = r, achievements = res.achievements, completed = res.completed }
end

------------------------------------------------------------------ artists
function A.sign(state, a)
	local ok, msg = GS.sign(state, a.artistId)
	local ach = ok and GS.checkAchievements(state) or {}
	return ok, msg, { achievements = ach }
end

------------------------------------------------------------------ tours
function A.createTour(state, a)
	local d = a.draft
	if type(d) ~= "table" or type(d.shows) ~= "table" then
		return false, "Nothing to book."
	end
	local shows = {}
	for _, s in ipairs(d.shows) do
		if type(s) == "table" and Countries.venueById[s.venueId or ""] then
			table.insert(shows, { venueId = s.venueId, day = num(s.day) and math.floor(s.day) or nil, price = num(s.price) })
		end
	end
	local prices = {}
	if type(d.prices) == "table" then
		for look, list in pairs(d.prices) do
			if type(list) == "table" then
				prices[look] = {}
				for sec, p in pairs(list) do
					if type(sec) == "string" and num(p) then
						prices[look][sec] = Util.clamp(math.floor(p), 5, 4000)
					end
				end
			end
		end
	end
	local designs = {}
	if type(d.designs) == "table" then
		for cls, id in pairs(d.designs) do
			if type(cls) == "string" and type(id) == "string" then
				designs[cls] = id
			end
		end
	end
	local ok, res = GS.createTour(state, {
		artistId = d.artistId,
		name = str(d.name, 40),
		designId = d.designId,
		designs = designs,
		price = num(d.price),
		prices = prices,
		firstIn = num(d.firstIn),
		gap = num(d.gap),
		shows = shows,
		dancers = num(d.dancers) and Util.clamp(math.floor(d.dancers), 0, Config.MAX_DANCERS) or nil,
	})
	if not ok then
		return false, res
	end
	return true, nil, { tourId = res.id }
end

-- the tour plan (built step by step in different rooms) is stored on the server
local function cleanDraft(state, d)
	local out = { shows = {}, prices = {}, designs = {} }
	local ad = Artists.byId[(type(d.artistId) == "string") and d.artistId or ""]
	if ad and GS.canPlan(state, ad.id) then
		out.artistId = ad.id
	end
	if not out.artistId then
		return out
	end
	out.name = str(d.name, 40)
	out.price = num(d.price)
	out.pricesSet = d.pricesSet == true
	out.dancers = num(d.dancers) and Util.clamp(math.floor(d.dancers), 0, Config.MAX_DANCERS) or nil
	out.stageSet = d.stageSet == true
	if type(d.shows) == "table" then
		for _, s in ipairs(d.shows) do
			if #out.shows >= Config.MAX_SHOWS_PER_TOUR then
				break
			end
			if type(s) == "table" and Countries.venueById[s.venueId or ""] and num(s.day) then
				table.insert(out.shows, { venueId = s.venueId, day = math.floor(s.day) })
			end
		end
	end
	if type(d.prices) == "table" then
		for look, list in pairs(d.prices) do
			if type(look) == "string" and type(list) == "table" then
				out.prices[look] = {}
				for sec, p in pairs(list) do
					if type(sec) == "string" and num(p) then
						out.prices[look][sec] = Util.clamp(math.floor(p), 5, 4000)
					end
				end
			end
		end
	end
	if type(d.designs) == "table" then
		for cls, id in pairs(d.designs) do
			if type(cls) == "string" and type(id) == "string" and GS.getDesign(state, id) then
				out.designs[cls] = id
			end
		end
	end
	return out
end

function A.setDraft(state, a)
	if type(a.draft) ~= "table" then
		return false, "Bad plan."
	end
	local want = a.draft.artistId
	if type(want) == "string" and want ~= (state.draft or {}).artistId then
		local ok, why = GS.canPlan(state, want)
		if not ok then
			return false, why
		end
	end
	state.draft = cleanDraft(state, a.draft)
	return true
end

-- the plan becomes a real tour: tickets go on sale
function A.announceTour(state, a)
	local d = cleanDraft(state, state.draft or {})
	if not d.artistId then
		return false, "Pick an artist in the MEETING ROOM first."
	end
	if #d.shows == 0 then
		return false, "Plan the dates at the WORLD MAP table first."
	end
	-- venue sizes without a chosen stage get the biggest stage that fits
	for _, s in ipairs(d.shows) do
		local vc = GS.venueClass(Countries.venueById[s.venueId])
		if not d.designs[vc] then
			local vo, best, bestO = Config.STAGE_CLASS_BY_ID[vc].order, nil, 0
			for _, des in ipairs(state.designs) do
				local o = Config.STAGE_CLASS_BY_ID[des.class].order
				if o <= vo and o > bestO then
					best, bestO = des, o
				end
			end
			d.designs[vc] = best and best.id or nil
		end
	end
	local ok, msg, data = A.createTour(state, { draft = { artistId = d.artistId, name = str(a.name, 40) or d.name, designs = d.designs, prices = d.prices, price = d.price, shows = d.shows, dancers = d.dancers } })
	if ok then
		state.draft = {}
	end
	return ok, msg, data
end

function A.buyMarketing(state, a)
	return GS.buyMarketing(state, a.tourId, a.id)
end

function A.setTourPrice(state, a)
	local p = num(a.price)
	if not p then
		return false, "Bad price."
	end
	GS.setTourPrice(state, a.tourId, p)
	return true
end

function A.cancelTour(state, a)
	return GS.cancelTour(state, a.tourId)
end

function A.cancelShow(state, a)
	return GS.cancelShow(state, a.tourId, num(a.idx))
end

function A.renameTour(state, a)
	local tour = GS.getTour(state, a.tourId)
	local name = str(a.name, 40)
	if not tour or not name then
		return false, "Could not rename."
	end
	tour.name = name
	return true
end

-- live = false: the show is simulated (the player does not go there)
function A.setLive(state, a)
	local _, s = tourShow(state, a.tourId, a.idx)
	if not s or s.done then
		return false
	end
	s.skipLive = (a.live == false) or nil
	return true
end

------------------------------------------------------------------ stages
function A.newDesign(state, a)
	local cls = Config.STAGE_CLASS_BY_ID[a.class or ""] and a.class or "Arena"
	local layout = (a.layout == "center") and "center" or "end"
	if #state.designs >= Config.MAX_DESIGNS then
		return false, "You can have up to " .. Config.MAX_DESIGNS .. " stages. Delete one first."
	end
	if a.preset then
		for _, p in ipairs(StageItems.PRESETS) do
			if p.name == a.preset then
				local d, msg = GS.addDesignFromTemplate(state, p)
				if not d then
					return false, msg
				end
				return true, nil, { designId = d.id }
			end
		end
		return false, "Unknown template."
	end
	local name = str(a.name, 24) or (cls .. " " .. (layout == "center" and "Center" or "Stage") .. " " .. (#state.designs + 1))
	local d = GS.addDesign(state, name, {}, cls, layout)
	local msg = nil
	if a.start == "deck" then
		local c = Config.STAGE_CLASS_BY_ID[cls]
		local rec
		if layout == "center" then
			rec = { t = "deck_round", x = 0, z = 0, r = 0, w = math.min(70, math.floor(c.center * 0.5)), h = 6, y = 0 }
		else
			rec = { t = "deck", x = 0, z = c.minZ + math.floor((c.maxX - c.minX) * 0.12) + 2, r = 0, w = math.floor((c.maxX - c.minX) * 0.6), d = math.floor((c.maxX - c.minX) * 0.25), h = (c.order == 1) and 4 or 6, y = 0 }
		end
		local ok, err = GS.buyItem(state, d, rec)
		if not ok then
			msg = err
		end
	end
	return true, msg, { designId = d.id }
end

function A.copyDesign(state, a)
	local d = GS.getDesign(state, a.designId)
	if not d then
		return false, "Stage not found."
	end
	if #state.designs >= Config.MAX_DESIGNS then
		return false, "You can have up to " .. Config.MAX_DESIGNS .. " stages. Delete one first."
	end
	local value = GS.designValue(d)
	if state.money < value then
		return false, "Not enough money for the equipment."
	end
	state.money = state.money - value
	local items = Util.deepCopy(d.items)
	for _, it in ipairs(items) do
		it.uid = nil
	end
	local c = GS.addDesign(state, (d.name .. " copy"):sub(1, 24), items, d.class, d.layout)
	return true, nil, { designId = c.id }
end

-- the tutorial: the step the player reached, or done (finished / skipped)
function A.tutorial(state, a)
	state.tutorial = type(state.tutorial) == "table" and state.tutorial or {}
	if a.done == true then
		state.tutorial = { done = true }
	elseif num(a.step) then
		state.tutorial.step = Util.clamp(math.floor(a.step), 1, 99)
	end
	return true
end

function A.renameDesign(state, a)
	local d = GS.getDesign(state, a.designId)
	local name = str(a.name, 24)
	if not d or not name then
		return false, "Please type a name."
	end
	d.name = name
	return true, "Stage renamed: " .. name
end

function A.deleteDesign(state, a)
	return GS.deleteDesign(state, a.designId)
end

-- The stage builder edits a design on the client and sends the whole design back when it closes.
-- The server pays the difference item by item (uid): new items cost their price, removed items are
-- sold for RESALE, changed items pay or refund the price difference.
local ITEM_FIELDS = { t = "string", x = "number", y = "number", z = "number", r = "number", w = "number", d = "number", h = "number", yo = "number", uid = "string" }
local function cleanItem(it)
	if type(it) ~= "table" or type(it.t) ~= "string" or not StageItems.byId[it.t] then
		return nil
	end
	local out = {}
	for k, v in pairs(it) do
		if type(k) == "string" and #k <= 24 then
			local want = ITEM_FIELDS[k]
			if want then
				if type(v) == want and (want ~= "number" or num(v)) then
					out[k] = v
				end
			elseif type(v) == "string" then
				out[k] = v:sub(1, 200)
			elseif type(v) == "boolean" or num(v) then
				out[k] = v
			elseif type(v) == "table" then
				-- small nested settings (screen content per song etc.)
				local ok, copy = pcall(Util.deepCopy, v)
				if ok then
					out[k] = copy
				end
			end
		end
	end
	return out
end

function Actions.designCost(old, newItems)
	local byUid = {}
	for _, it in ipairs(old.items) do
		if it.uid then
			byUid[it.uid] = it
		end
	end
	local cost, seen = 0, {}
	for _, it in ipairs(newItems) do
		local def = StageItems.byId[it.t]
		local o = it.uid and byUid[it.uid]
		if o and not seen[it.uid] and o.t == it.t then
			seen[it.uid] = true
			local diff = Sim.itemPrice(def, it) - Sim.itemPrice(def, o)
			cost = cost + (diff > 0 and diff or Util.round(diff * Config.RESALE))
		else
			cost = cost + Sim.itemPrice(def, it)
		end
	end
	for uid, o in pairs(byUid) do
		if not seen[uid] then
			cost = cost - Util.round(Sim.itemPrice(StageItems.byId[o.t], o) * Config.RESALE)
		end
	end
	return cost
end

function A.saveDesign(state, a)
	local d = GS.getDesign(state, a.designId)
	local nd = a.design
	if not d or type(nd) ~= "table" or type(nd.items) ~= "table" then
		return false, "Stage not found."
	end
	local items = {}
	for _, it in ipairs(nd.items) do
		local c = cleanItem(it)
		if c then
			table.insert(items, c)
		end
	end
	local cls = Config.STAGE_CLASS_BY_ID[d.class] or Config.STAGE_CLASSES[1]
	if #items > math.max(cls.maxItems, #d.items) then
		return false, "Too many items for this stage size."
	end
	GS.ensureUids({ items = items })
	local cost = Actions.designCost(d, items)
	if cost > 0 and state.money < cost and not state.sandbox then
		return false, "Not enough money for the new equipment (" .. Util.money(cost) .. ")."
	end
	state.money = state.money - cost
	d.items = items
	d.name = str(nd.name, 24) or d.name
	return true, nil, { cost = cost }
end

------------------------------------------------------------------ the building
function A.visit(state, a)
	if type(a.station) == "string" and #a.station < 20 then
		state.visited = state.visited or {}
		state.visited[a.station] = true
	end
	return true
end

------------------------------------------------------------------ sandbox tools (developer test mode only)
-- jumps ahead day by day until a show is due (or `days` days passed)
function A.devSkip(state, a)
	if not state.sandbox then
		return false, "Only in the sandbox."
	end
	local all = serializeDay({})
	local maxDays = Util.clamp(math.floor(num(a.days) or 60), 1, 365)
	for _ = 1, maxDays do
		local ok, _, ev = A.nextDay(state)
		if not ok then
			break
		end
		merge(all, ev)
		if a.untilShow and #ev.live > 0 then
			break
		end
	end
	return true, nil, all
end

function A.devTickets(state, a)
	if not state.sandbox then
		return false, "Only in the sandbox."
	end
	state.stats.tickets = state.stats.tickets + math.floor(num(a.n) or 10000)
	return true
end

------------------------------------------------------------------ entry point
function Actions.run(state, name, args)
	local fn = A[name]
	if type(name) ~= "string" or not fn then
		return false, "Unknown action."
	end
	if type(args) ~= "table" then
		args = {}
	end
	local ok, msg, data = fn(state, args)
	if state.sandbox and state.money < Config.SANDBOX_MONEY then
		state.money = Config.SANDBOX_MONEY
	end
	return ok == true, msg, data
end

local _ = Artists
return Actions
