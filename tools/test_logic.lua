math.randomseed(42)
local GS = require(ROOT.Logic.GameState)
local Sim = require(ROOT.Logic.Sim)
local Util = require(ROOT.Logic.Util)
local Countries = require(ROOT.Data.Countries)
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
check(live == 1, "one live show")
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
  st.stats.tickets = 3500
  check(GS.level(st) == 2 and GS.checkLevelUp(st) == "Indie Label", "level up")
  st.money = 1000000
  local ok2 = GS.sign(st, "voltage")
  check(ok2, "voltage signable at level 2")
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
print("FAILS", fails)
