math.randomseed(42)
local GS = require(ROOT.Logic.GameState)
local Sim = require(ROOT.Logic.Sim)
local Artists = require(ROOT.Data.Artists)
local Util = require(ROOT.Logic.Util)
local Countries = require(ROOT.Data.Countries)
local Config = require(ROOT.Config)
local fails = 0
local function check(cond, msg) if not cond then fails = fails + 1; print("FAIL: " .. msg) end end

-- formatting
check(Util.money(1234567) == "$1,234,567", "money " .. Util.money(1234567))
check(Util.money(-500) == "-$500", "neg money")
check(Util.money(100) == "$100", "money 100 " .. Util.money(100))
check(Util.date(0) == "Jan 1, 2027", "date0 " .. Util.date(0))
check(Util.date(59) == "Mar 1, 2027", "date59 " .. Util.date(59))
check(Util.date(365) == "Jan 1, 2028", "date365")
check(Util.date(365+59) == "Feb 29, 2028", "leap " .. Util.date(365+59))
print("stars", Util.stars(3), Util.short(1234567), Util.moneyShort(45000), Util.short(950))

local state = GS.new("Test Records", "lila")
check(#state.designs == 3, "presets")
check(state.artists.lila.signed and not state.artists.voltage.signed, "only starter signed")
local okSign = GS.sign(state, "voltage")
check(not okSign, "voltage locked at level 1")
state.artists.voltage.signed = true
local club, arena = state.designs[1], state.designs[2]

-- production scores
for _, cap in ipairs({350, 5000, 20000, 80000}) do
  local s1 = Sim.productionScore(club, "Indie", cap)
  local s2 = Sim.productionScore(arena, "Indie", cap)
  print(string.format("cap %6d  club-basic %5.1f  arena-starter %5.1f", cap, s1, s2))
end
print("arena design cost/show", Sim.designStats(arena).cost, "club", Sim.designStats(club).cost)

-- pools & fair prices for starting artists
for _, id in ipairs({"lila","rusty","voltage","nova"}) do
  print(id, "fair UK", Sim.fairPrice(state, id, "uk"), "pool UK", math.floor(Sim.countryPool(state, id, "uk")), "pool US", math.floor(Sim.countryPool(state, id, "us")))
end

-- Lila club tour estimate
local draft = { artistId = "lila", designId = club.id, firstIn = 21, gap = 2, watchFirst = true, price = Sim.fairPrice(state, "lila", "uk"), shows = {} }
for _, vid in ipairs({"uk_fiddle","ie_clover","fr_neon","nl_paradisio","de_keller","ch_alpenglow"}) do
  local v = Countries.venueById[vid]
  table.insert(draft.shows, { venueId = vid, price = Sim.fairPrice(state, "lila", v.countryId) })
end
local est = Sim.estimate(state, draft, club)
for i, r in ipairs(est.rows) do print(draft.shows[i].venueId, math.floor(r.demand), r.sold, Util.percent(r.fill), r.gross, r.net) end
print("est total gross", est.gross, "net", est.net)

-- venues need a label level: level 1 = clubs only
local okLock, msgLock = GS.createTour(state, draft)
check(not okLock and tostring(msgLock):find("level"), "theatres are locked at level 1: " .. tostring(msgLock))
state.stats.tickets = 250000 -- level 4 (no level-up check runs here)
local ok, tour = GS.createTour(state, draft)
check(ok, "create tour: " .. tostring(tour))
check(tour.shows[1].sold > 0, "presale sold")
local ok2, msg2 = GS.createTour(state, draft)
check(not ok2, "double tour blocked")

-- voltage arena tour
local d2 = { artistId = "voltage", designId = club.id, firstIn = 30, gap = 2, price = 55, shows = {} }
for _, vid in ipairs({"nl_afos","de_columbus","uk_brixtown","fr_zenit","ch_jacob"}) do
  local v = Countries.venueById[vid]
  table.insert(d2.shows, { venueId = vid, price = Sim.fairPrice(state, "voltage", v.countryId) })
end
local ok3, t2 = GS.createTour(state, d2)
check(ok3, "voltage tour " .. tostring(t2))
print("marketing", GS.buyMarketing(state, t2.id, "social"))

local live = 0
for day = 1, 60 do
  local ev = GS.advanceDay(state)
  for _, so in ipairs(ev.soldOut) do print("day", state.day, "SOLD OUT", so.tour.shows[so.idx].venueId) end
  for _, p in ipairs(ev.played) do print("day", state.day, "played", p.tour.shows[p.idx].venueId, p.result.sold .. "/" .. p.result.cap, "gross", p.result.gross, "net", p.result.net, "stars", p.result.stars, p.result.review) end
  for _, l in ipairs(ev.live) do
    live = live + 1
    local t = GS.getTour(state, l.tourId)
    local r = GS.prepareShow(state, t, l.idx)
    local res = GS.applyShow(state, t, l.idx, r)
    print("day", state.day, "LIVE", t.shows[l.idx].venueId, r.sold, r.gross, r.stars)
  end
  for _, a in ipairs(ev.achievements) do print("ACH", a) end
  for _, t in ipairs(ev.completed) do print("COMPLETED", t.name, t.gross, t.net) end
end
check(live >= 1, "the opening night is played live")
check(tour.status == "done" and t2.status == "done", "tours done")
print("money", state.money, "lila fans", Util.totalFans(state.artists.lila.fans), "hype", state.artists.lila.hype)
local rows, best = GS.chart(state)
print("best chart rank", best)
-- sanitize roundtrip
local s2 = GS.sanitize(Util.deepCopy(state))
check(s2.money == state.money, "sanitize keeps")
local s3 = GS.sanitize({ version = 999 })
check(s3.money == 150000, "sanitize resets")

-- big artist stadium economics
state.artists.nova.signed = true
local d3 = { artistId = "nova", designId = arena.id, firstIn = 30, gap = 2, price = 150, shows = {} }
for _, vid in ipairs({"uk_wemblee","uk_wemblee","de_olympus","fr_stadium","us_sofa","us_metalife","jp_tokio"}) do
  local v = Countries.venueById[vid]
  table.insert(d3.shows, { venueId = vid, price = Sim.fairPrice(state, "nova", v.countryId) })
end
local e3 = Sim.estimate(state, d3, arena)
for i, r in ipairs(e3.rows) do print("nova", d3.shows[i].venueId, d3.shows[i].price, math.floor(r.demand), Util.percent(r.fill), Util.moneyShort(r.gross), Util.moneyShort(r.net)) end
-- water filling: a small club must not be starved by a big venue in the same country
do
  local st = GS.new()
  local pool = Sim.countryPool(st, "lila", "uk")
  local fair = Sim.fairPrice(st, "lila", "uk")
  local d = Sim.demands(st, "lila", { { venueId = "uk_fiddle", price = fair }, { venueId = "uk_brixtown", price = fair } }, 1)
  print("water-fill UK: pool", math.floor(pool), "club demand", math.floor(d[1]), "theatre demand", math.floor(d[2]))
  check(d[1] >= 350, "club should sell out")
  check(math.abs(350 + d[2] - pool) < 1, "pool conserved")
  local d2 = Sim.demands(st, "lila", { { venueId = "uk_brixtown", price = fair } }, 1)
  check(math.abs(d2[1] - pool) < 1, "single show gets whole pool")
  local d3 = Sim.demands(st, "nova", { { venueId = "uk_wemblee", price = 148 }, { venueId = "uk_wemblee", price = 148 }, { venueId = "uk_fiddle", price = 148 } }, 1)
  check(d3[1] >= 90000 and d3[2] >= 90000 and d3[3] >= 350, "superstar fills all")
end
-- single tour price, equipment economy, levels
do
  local st = GS.new("X", "juno")
  check(st.artists.juno.signed, "juno starter")
  local d = st.designs[1]
  local m0 = st.money
  local ok = GS.buyItem(st, d, { t = "led", x = 0, z = 0, r = 0, w = 32, d = 9 })
  check(ok and st.money == m0 - 18000, "buy led " .. st.money)
  GS.sellItem(st, d, d.items[#d.items])
  check(st.money == m0 - 18000 + 12600, "resale 70%")
  st.stats.tickets = 25000
  check(GS.level(st) == 4 and GS.checkLevelUp(st) == "Rising Label", "level up")
  st.money = 1000000
  local ok2 = GS.sign(st, "voltage")
  check(ok2, "voltage signable at level 4")
  local okT, t = GS.createTour(st, { artistId = "juno", designId = d.id, firstIn = 20, gap = 2, price = 40, shows = { { venueId = "uk_fiddle" }, { venueId = "fr_neon" } } })
  check(okT and t.shows[1].price == 40 and t.shows[2].price == 40, "tour price")
  GS.setTourPrice(st, t.id, 45)
  check(t.price == 45 and t.shows[2].price == 45, "set tour price")
  local est = Sim.estimate(st, { artistId = "juno", shows = { { venueId = "uk_fiddle", price = 40 } } }, d)
  print("estimate range", est.rows[1].fillLow, est.rows[1].fillHigh, Sim.recommendation(st, "juno", "uk"))
end
do
  local st = GS.new("X", "lila")
  local Countries = require(ROOT.Data.Countries)
  local arenaD = st.designs[2]
  check(not Sim.designFits(arenaD, Countries.venueById.uk_fiddle) and Sim.designFits(arenaD, Countries.venueById.uk_o3), "class fit")
  local rec = { t = "deck", x = 0, z = 0, r = 0, w = 16, d = 12, h = 6 }
  local DEF = require(ROOT.Data.StageItems).byId.deck
  check(Sim.itemPrice(DEF, rec) == 1800, "deck price " .. Sim.itemPrice(DEF, rec))
  local m = st.money
  check(GS.changeItem(st, rec, { w = 32 }) and st.money == m - 1800 and rec.w == 32, "resize charge")
  GS.changeItem(st, rec, { w = 16 })
  check(st.money == m - 1800 + 1260, "shrink refund " .. st.money)
end
-- multi-night residencies, templates, setlist length, fan posts
do
  local st = GS.new("Y", "juno")
  local SI = require(ROOT.Data.StageItems)
  check(#st.designs == 3, "only free starter stages")
  local days = GS.scheduleDays(10, { { venueId = "uk_o3" }, { venueId = "uk_o3" }, { venueId = "uk_o3" }, { venueId = "fr_neon" } }, 3)
  check(days[1] == 10 and days[2] == 11 and days[3] == 12 and days[4] == 15, "residency days " .. table.concat(days, ","))
  local v = Countries.venueById.uk_o3
  check(Sim.travelCost(v, v, 30) == 0, "no travel between nights in the same venue")
  check(GS.songCount(st.designs[1]) == 4 and GS.songCount({ items = {} }) == 4, "song count")
  -- keyboard in song 2: spots take songs 1, 3, 4 (the user's example)
  local keys = { t = "keys", play = 2 }
  local s1, s2, s3 = { t = "spot" }, { t = "spot" }, { t = "spot" }
  local plan = GS.songPlan({ items = { s1, keys, s2, s3 } })
  check(plan.songOf[s1] == 1 and plan.songOf[keys] == 2 and plan.songOf[s2] == 3 and plan.songOf[s3] == 4 and plan.count == 4, "spots skip the keyboard song")
  local lift = { t = "lift" }
  plan = GS.songPlan({ items = { lift, s1 } }, s2)
  check(plan.songOf[lift] == 1 and plan.songOf[s1] == 2 and plan.songOf[s2] == 3 and plan.count == 3, "lift is song 1, a new spot gets the next free song")
  local cube
  for _, p in ipairs(SI.PRESETS) do if p.name == "The Cube" then cube = p end end
  st.money = 100
  check(GS.addDesignFromTemplate(st, cube) == nil, "template needs money")
  st.money = 5000000
  local d = GS.addDesignFromTemplate(st, cube)
  check(d and #d.items == #cube.items and st.money < 5000000, "template bought")
  for _, it in ipairs(d.items) do check(SI.byId[it.t] ~= nil, "template item exists: " .. it.t) end
  for _, p in ipairs(SI.PRESETS) do
    local c = require(ROOT.Config).STAGE_CLASS_BY_ID[p.class]
    for _, it in ipairs(p.items) do
      local inside = (p.layout == "center") and (math.abs(it.x) <= c.center and math.abs(it.z) <= c.center) or (it.x >= c.minX and it.x <= c.maxX and it.z >= c.minZ and it.z <= c.maxZ)
      check(inside, p.name .. ": " .. it.t .. " outside the build area")
    end
  end
  st.stats.tickets = 250000 -- arenas need label level 3
  local ok, t = GS.createTour(st, { artistId = "juno", designs = { Arena = d.id, Club = st.designs[1].id, Theatre = st.designs[1].id }, firstIn = 20, gap = 2, price = 300, shows = { { venueId = "uk_o3" }, { venueId = "uk_o3" } } })
  check(ok and t.shows[2].day == t.shows[1].day + 1 and t.shows[2].travel == 0, "two nights at the O3")
  check(#st.social >= 3, "fans post about the announcement")
  local neg = 0
  for _, p in ipairs(st.social) do if p.kind == "price_high" then neg = neg + 1 end end
  check(neg >= 1, "expensive tickets get criticism")
  for _ = 1, 40 do
    local ev = GS.advanceDay(st)
    for _, l in ipairs(ev.live) do
      local tt = GS.getTour(st, l.tourId)
      GS.applyShow(st, tt, l.idx, GS.prepareShow(st, tt, l.idx))
    end
  end
  local kinds = {}
  for _, p in ipairs(st.social) do kinds[p.kind] = true check(not p.text:find("{"), "placeholder left: " .. p.text) end
  local list = {}
  for k in pairs(kinds) do list[#list + 1] = k end
  table.sort(list)
  print("social kinds", table.concat(list, ","), "posts", #st.social)
  check(kinds.show_great or kinds.show_ok or kinds.show_bad, "posts after the shows")
end
-- seat sections: never more than the capacity, a cheap section sells more than an expensive one
do
  local prices = Sim.defaultPrices(40, "arena")
  local by, total, gross = Sim.splitSections("arena", 10000, prices, 50000)
  check(total <= 10000 and total >= 9000, "a hot show sells (almost) all sections: " .. total)
  local p2 = Sim.defaultPrices(40, "arena")
  p2.upper = 200
  local by2 = Sim.splitSections("arena", 10000, p2, 6000)
  local by3 = Sim.splitSections("arena", 10000, prices, 6000)
  check(by2.upper < by3.upper, "an expensive upper tier sells less")
  print("sections", by.golden, by.floor, by.lower, by.upper, "gross", gross)
  -- venue calendar: some days are taken, the same in every game
  local st = GS.new("Cal", "juno")
  local busy, n = 0, 0
  for d = 20, 200 do
    n = n + 1
    if GS.venueBusy(st, "uk_o3", d) then busy = busy + 1 end
  end
  check(busy > 0 and busy < n * 0.4, "arena is sometimes booked: " .. busy .. "/" .. n)
  check(GS.venueBusy(st, "uk_o3", 77) == GS.venueBusy(st, "uk_o3", 77), "calendar is deterministic")
end

-- server actions (Logic/Actions.lua): what the client asks for
do
  local Actions = require(ROOT.Logic.Actions)
  local st = GS.new("Act", "lila")
  local ok, msg, ev = Actions.run(st, "nextDay", {})
  check(ok and st.day == 1 and type(ev.live) == "table", "nextDay action")
  check(not Actions.run(st, "nope", {}), "unknown action refused")
  -- level gate through the action as well
  local okT, msgT = Actions.run(st, "createTour", { draft = { artistId = "lila", designId = st.designs[1].id, shows = { { venueId = "uk_o3", day = 30 } } } })
  check(not okT, "arena locked for a new label: " .. tostring(msgT))
  local okC, _, dataC = Actions.run(st, "createTour", { draft = { artistId = "lila", designId = st.designs[1].id, shows = { { venueId = "uk_fiddle", day = 30 } } } })
  check(okC and dataC.tourId, "club tour via action")
  -- a show waits on its day: next day refused until it is played
  for _ = 1, 40 do
    local okD = Actions.run(st, "nextDay", {})
    if not okD then break end
  end
  check(st.day == 30, "time stops on the show day: " .. st.day)
  local tour = GS.getTour(st, dataC.tourId)
  local okP, _, dataP = Actions.run(st, "playShow", { tourId = tour.id, idx = 1 })
  check(okP and dataP.result and tour.shows[1].done, "playShow")
  check(not Actions.run(st, "playShow", { tourId = tour.id, idx = 1 }), "a show plays only once")
  check(GS.unlocks(st).stagehall, "stage hall is open")
  -- stage builder: the server pays the difference per item uid
  local d = st.designs[1]
  local before = st.money
  local items = Util.deepCopy(d.items)
  table.insert(items, { t = "par", x = 0, z = 0, r = 0 })
  local okS, _, dataS = Actions.run(st, "saveDesign", { designId = d.id, design = { name = d.name, items = items } })
  check(okS and dataS.cost > 0 and st.money == before - dataS.cost, "new item is paid: " .. tostring(dataS and dataS.cost))
  local items2 = Util.deepCopy(d.items)
  table.remove(items2)
  local m2 = st.money
  Actions.run(st, "saveDesign", { designId = d.id, design = { name = d.name, items = items2 } })
  check(st.money > m2 and st.money < before, "removed item sold for less than its price")
  check(not Actions.run(st, "saveDesign", { designId = d.id, design = { items = { { t = "hack" } } } }) or #d.items == 0, "unknown items are dropped")
  -- sandbox
  local sb = GS.new("Sand", "juno", { sandbox = true })
  check(sb.sandbox and sb.money == Config.SANDBOX_MONEY and GS.level(sb) == #Config.LEVELS, "sandbox start")
  local okN = Actions.run(sb, "sign", { artistId = "nova" })
  check(okN and sb.money == Config.SANDBOX_MONEY, "sandbox: money never runs out")
  check(GS.unlocks(sb).charts and GS.venueUnlocked(sb, Countries.venueById.uk_wemblee), "sandbox: everything open")
  check(not Actions.run(st, "devSkip", {}), "dev tools only in the sandbox")
  check(Actions.run(sb, "devSkip", { days = 7 }) and sb.day == 7, "sandbox skip")
  -- objective
  local fresh = GS.new("Obj", "lila")
  check(GS.objective(fresh).target == "meeting", "first goal: pick the artist in the meeting room")
  -- the tour plan, room by room
  check(GS.planStage(fresh) == "artist", "plan starts with the artist")
  check(Actions.run(fresh, "setDraft", { draft = { artistId = "lila" } }) and fresh.draft.artistId == "lila", "artist picked")
  check(GS.objective(fresh).target == "maptable", "then the world map")
  Actions.run(fresh, "setDraft", { draft = { artistId = "lila", shows = { { venueId = "uk_fiddle", day = 30 }, { venueId = "nope", day = 31 } } } })
  check(#fresh.draft.shows == 1 and GS.planStage(fresh) == "tickets", "dates saved (bad venue dropped), then tickets")
  check(GS.objective(fresh).target == "laptop", "tickets on the laptop")
  Actions.run(fresh, "setDraft", { draft = { artistId = "lila", shows = fresh.draft.shows, pricesSet = true } })
  check(GS.objective(fresh).target == "stagehall", "then the stage hall")
  local okKai = Actions.run(fresh, "setDraft", { draft = { artistId = "kai", shows = fresh.draft.shows } })
  check(not okKai and fresh.draft.artistId == "lila", "an unsigned artist can't be planned (the plan stays)")
  -- a finished tour: the artist needs a break, only one tour at a time at level 1
  local rs = GS.new("Rest", "lila")
  rs.artists.juno.signed = true
  local okR, tr = GS.createTour(rs, { artistId = "lila", designId = rs.designs[1].id, shows = { { venueId = "uk_fiddle" } } })
  check(okR, "first tour")
  local okR2 = GS.createTour(rs, { artistId = "juno", designId = rs.designs[1].id, shows = { { venueId = "fr_neon" } } })
  check(not okR2, "level 1: one tour at a time")
  GS.finishTour(rs, tr)
  check(GS.restLeft(rs, "lila") > 0 and not GS.canPlan(rs, "lila"), "lila rests after the tour")
  check(GS.canPlan(rs, "juno"), "juno can tour")
  -- unsigned artists: some are busy sometimes, but there is always someone
  local busyN, freeN = 0, 0
  for _, ad in ipairs(Artists.list) do
    if GS.artistBusy(rs, ad.id) then busyN = busyN + 1 else freeN = freeN + 1 end
  end
  print("busy artists", busyN, "free", freeN)
  check(busyN > 0 and freeN > busyN, "a few artists are busy")
  -- tickets: a cheap golden circle sells out, the rest of the room does not change
  local sp = GS.new("Tix", "lila")
  local fair = Sim.fairPrice(sp, "lila", "uk")
  local pr = Sim.defaultPrices(fair, "arena")
  local _, _, _ = Sim.splitSections("arena", 20000, pr, 6000, fair)
  local byA = Sim.splitSections("arena", 20000, pr, 6000, fair)
  local pr2 = Sim.defaultPrices(fair, "arena")
  pr2.golden = math.floor(pr2.golden / 3)
  local d2 = 6000 * Sim.priceFactor("arena", pr2, fair) / Sim.priceFactor("arena", pr, fair)
  local byB = Sim.splitSections("arena", 20000, pr2, d2, fair)
  check(byB.golden > byA.golden and math.abs(byB.upper - byA.upper) < 5, "cheaper golden circle sells more golden tickets: " .. byA.golden .. " -> " .. byB.golden)
  Actions.run(fresh, "setDraft", { draft = { artistId = "lila", shows = { { venueId = "uk_fiddle", day = 30 } }, pricesSet = true, stageSet = true } })
  check(GS.planStage(fresh) == "announce", "ready to announce")
  local okA, _, dA = Actions.run(fresh, "announceTour", { name = "Moon Tour" })
  check(okA and GS.getTour(fresh, dA.tourId).name == "Moon Tour" and fresh.draft.artistId == nil, "announced from the plan, plan cleared")
  -- travel days: same country / neighbour = next day, same continent = 1 travel day, other continent = 2
  local function gap(a, b) return GS.travelGap({ venueId = a }, { venueId = b }) end
  check(gap("uk_fiddle", "uk_o3") == 1, "same country: no travel day")
  check(gap("uk_fiddle", "fr_neon") == 1 and gap("fr_neon", "de_keller") == 1, "neighbour: no travel day")
  check(gap("uk_fiddle", "de_keller") == 2, "two countries away: one travel day")
  check(gap("uk_fiddle", "us_bowery") == 3, "other continent: two travel days")
  -- cancel one show: the venue is paid, hype drops, the tour goes on
  local cs = GS.new("Cancel", "lila")
  cs.money = 5000000
  local okCT, ct = GS.createTour(cs, { artistId = "lila", designId = cs.designs[1].id, price = 30, shows = { { venueId = "uk_fiddle", day = 30 }, { venueId = "fr_neon", day = 32 }, { venueId = "de_keller", day = 35 } } })
  check(okCT, "tour for cancel test")
  if okCT then
    local m0, h0 = cs.money, cs.artists.lila.hype
    local cost = GS.cancelShowCost(cs, ct, 2)
    local okX = Actions.run(cs, "cancelShow", { tourId = ct.id, idx = 2 })
    check(okX and #ct.shows == 2 and cs.money == m0 - cost and (cs.artists.lila.hype < h0 or h0 == 0), "cancel a show: venue paid, hype down")
    check(ct.shows[2].venueId == "de_keller", "the other shows stay")
    check(not Actions.run(cs, "cancelShow", { tourId = ct.id, idx = 9 }), "no such show")
    cs.day = 30
    check(not Actions.run(cs, "cancelShow", { tourId = ct.id, idx = 1 }), "today's show can't be cancelled")
  end
  -- in-place sync keeps tables
  local dst = { list = { { id = "a", v = 1 }, { id = "b", v = 2 } }, n = 1, gone = true }
  local keepB = dst.list[2]
  Util.syncInto(dst, { list = { { id = "b", v = 3 } }, n = 2 })
  check(dst.list[1] == keepB and keepB.v == 3 and #dst.list == 1 and dst.n == 2 and dst.gone == nil, "syncInto")
end
print("FAILS", fails)
