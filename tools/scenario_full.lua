-- Full automated play-through of HEADLINER in the Roblox mock.
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local App = require(root.Client.App)
local GS = require(root.Logic.GameState)
local StageItems = require(root.Data.StageItems)
local app = App.instance
assert(app, "App did not start")
local function log(...) print("[test]", ...) end
local function steps(n, dt) for _ = 1, n do MOCK.step(dt or 1 / 30) end end
local function modalButtons() return #MOCK.buttons("^Continue$") + #MOCK.buttons("^Great!$") end

-- 1) main menu -> new game
assert(app.mode == "title", "should start on the title screen")
MOCK.clickExact("SETTINGS")
MOCK.clickExact("Low")
MOCK.clickExact("< Back")
MOCK.clickExact("STORE")
MOCK.clickExact("< Back")
MOCK.clickExact("CREDITS")
MOCK.clickExact("< Back")
for k = 1, 3 do
	log("menu scene", k, "parts", #workspace.MenuScene:GetDescendants())
	steps(475, 0.1)
end
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
assert(app.state and app.state.artists.lila.signed, "starter not signed")
MOCK.clickExact("Let's go!")
assert(app.current == "office", "not in office")
log("label", app.state.labelName, "money", app.state.money)

-- 2) plan a tour (wizard)
MOCK.clickExact("+ PLAN A TOUR")
local map = app.screens.planner
assert(map.step == 1, "planner should start at step 1")
MOCK.clickExact("SELECT")
assert(map.step == 2 and map.draft.artistId == "lila", "step 2 with lila")
for _, cid in ipairs({ "uk", "fr", "de", "nl" }) do
	map.selected = cid
	map:refresh()
	MOCK.click("^%+ ADD$", 1)
end
map.selected = "uk"
map:refresh()
MOCK.click("^%+ ADD$", 2)
log("draft shows", #map.draft.shows)
MOCK.clickExact("Europe")
steps(5)
local WM3 = require(root.Client.WorldMap3D)
log("3D map active", WM3.active, "country parts", #WM3.queryParts)
MOCK.mouse = Vector2.new(700, 300)
steps(3)
UIS0 = game:GetService("UserInputService")
UIS0.InputChanged:Fire(MOCK.input(Enum.UserInputType.MouseWheel, { Position = Vector3.new(0, 0, 1) }), false)
steps(3)
MOCK.click("^CLUBS")
log("club filter buttons", #MOCK.buttons("^%+ ADD$"))
MOCK.click("^ALL")
map:hoverCountry("ch")
log("hover text", MOCK.texts("Switzerland")[1])
MOCK.click("^v$", 1)
MOCK.click("^%^$", 2)
MOCK.click("^X$", 5)
MOCK.clickExact("NEXT: TICKETS & STAGE >")
assert(map.step == 3)
MOCK.clickExact("+1")
MOCK.clickExact("+10")
MOCK.clickExact("-10")
MOCK.click("Watch the opening night")
MOCK.click("Watch the opening night")
log("price", map.draft.price, "quality texts", #MOCK.texts("%%$"))
MOCK.clickExact("EDIT THIS STAGE")
assert(app.mode == "designer", "designer did not open")
MOCK.clickExact("DONE")
assert(app.current == "planner" and app.mode == "menu", "did not return to planner")
MOCK.clickExact("NEXT: CONFIRM >")
assert(map.step == 4)
log("confirm estimate:", MOCK.texts("Estimated gross")[1])
MOCK.clickExact("ANNOUNCE TOUR")
assert(app.current == "tours", "not on tours screen after announce")
local tour = app.state.tours[1]
log("tour", tour.name, "#shows", #tour.shows, "price", tour.price, tour.shows[2].price, "presale sold", tour.shows[1].sold)
MOCK.click("^Social Ads")
MOCK.clickExact("+")
log("tour price after +", tour.price, tour.shows[3].price)
MOCK.clickExact("OFFICE")
assert(app.current == "office")
log("upcoming:", #MOCK.texts("@"))

-- 3) run time until opening night
MOCK.clickExact(">>>")
local found = false
for _ = 1, 600 do
	MOCK.step(0.25)
	if #MOCK.buttons("WATCH LIVE") > 0 then found = true break end
end
assert(found, "no SHOWTIME modal")
log("showtime on day", app.state.day)
MOCK.clickExact("WATCH LIVE")
assert(app.mode == "live", "live show did not start")
MOCK.click("^Close")
MOCK.click("^Speed")
steps(300)
MOCK.click("^Crowd")
steps(300)
MOCK.click("^Orbit")
local frames = 600
while app.mode == "live" and frames < 8000 do MOCK.step(1 / 30) frames = frames + 1 end
log("live show finished after frames", frames, "mode", app.mode, "bulk moves", MOCK.bulkMoves)
assert(#MOCK.buttons("^Continue$") == 1, "no show report")
log("report:", MOCK.texts("Attendance")[1])
MOCK.clickExact("Continue")

-- 4) run the rest of the tour
local done = false
for _ = 1, 2000 do
	MOCK.step(0.25)
	if #MOCK.buttons("^Great!$") > 0 then done = true break end
	if #MOCK.buttons("^Simulate$") > 0 then MOCK.clickExact("Simulate") end
	if #MOCK.buttons("^Continue$") > 0 then MOCK.clickExact("Continue") end
end
assert(done, "tour never completed")
log("tour complete:", tour.status, "gross", tour.gross, "net", tour.net, "money", app.state.money)
MOCK.clickExact("Charts")
assert(app.current == "charts")

-- 5) artists: Kai is locked until level 2
MOCK.clickExact("OFFICE")
MOCK.clickExact("ARTISTS")
MOCK.clickExact("TALENT SCOUT")
log("locked buttons", #MOCK.buttons("^LOCKED"))
app.state.stats.tickets = 30000
app.state.money = 1000000
MOCK.clickExact("NEXT DAY")
if #MOCK.buttons("^Nice!$") > 0 then log("level-up modal shown") MOCK.clickExact("Nice!") end
for _ = 1, 5 do if app.modalOpen then MOCK.click("^[A-Z]", 1) end end
MOCK.clickExact("OFFICE")
MOCK.clickExact("ARTISTS")
MOCK.clickExact("TALENT SCOUT")
MOCK.click("^SIGN FOR %$250,000")
MOCK.clickExact("Yes")
log("kai signed", app.state.artists.kai.signed, "money", app.state.money)
MOCK.clickExact("YOUR ROSTER")
MOCK.click("^%+ PLAN A TOUR", 2)
assert(app.current == "planner")

-- 6) stage builder: place every item type the new way (card -> click into the world -> tick)
MOCK.clickExact("STAGES")
assert(app.current == "stages", "stages screen")
local Designer = require(root.Client.Designer)
local Stage3D = require(root.Client.Stage3D)
local UIS = game:GetService("UserInputService")
local function click3D() UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.MouseButton1), false) MOCK.runTasks() end
local function key(k) UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.Keyboard, { KeyCode = k }), false) MOCK.runTasks() end
app.state.money = 5000000
MOCK.clickExact("+  NEW STAGE")
MOCK.clickExact("ARENA")
MOCK.clickExact("CENTER STAGE")
MOCK.clickExact("Empty stage")
MOCK.clickExact("CREATE & BUILD")
assert(app.mode == "designer", "designer not open")
local design = Designer.current.design
log("new design", design.name, design.class, design.layout, "items", #design.items)
assert(design.layout == "center" and design.class == "Arena", "dialog settings")
local before = #design.items
local i = 0
for _, cat in ipairs(StageItems.CATEGORIES) do
	MOCK.clickExact(cat.name)
	for _, def in ipairs(StageItems.list) do
		if def.cat == cat.id then
			i = i + 1
			MOCK.clickExact(def.name)
			MOCK.mouse = Vector2.new(700 + (i % 12) * 45, 420 + math.floor(i / 12) * 6)
			if def.size then MOCK.clickExact("+", 1) end -- bigger before placing
			key(Enum.KeyCode.E)
			steps(2)
			click3D()
			assert(Designer.current.target() ~= nil, "nothing pending after the click: " .. def.id)
			steps(1)
			MOCK.click("PLACE", 1)
			steps(1)
		end
	end
end
log("designer items", before, "->", #design.items, "money spent", 5000000 - app.state.money)
assert(#design.items == before + #StageItems.list, "not every item was placed")
-- cancel placing, select a deck and edit it
key(Enum.KeyCode.F)
local deck = nil
for _, r in ipairs(Stage3D.items) do if r.def.deck then deck = r break end end
Designer.current.select(deck)
log("inspector title", MOCK.texts("^SELECTED$")[1] or "none")
MOCK.clickExact("+", 1) -- diameter
MOCK.clickExact("10")
MOCK.clickExact("LED screen")
MOCK.click("Edge lights")
MOCK.clickExact("Use on all decks")
local led = 0
for _, rec in ipairs(design.items) do if rec.skin == "led" then led = led + 1 end end
log("decks with LED surface", led)
-- gizmo: red arrow moves, green arrow lifts, gold cube resizes, orange ring turns
for _, r in ipairs(Stage3D.items) do if r.def.deck then Designer.current.select(r) deck = r break end end
steps(2)
local H = Designer.current.handles
local selRec = deck.rec
local x0 = selRec.x
H.moveX.MouseButton1Down:Fire(Enum.NormalId.Right)
H.moveX.MouseDrag:Fire(Enum.NormalId.Right, 6.4)
H.moveX.MouseButton1Up:Fire(Enum.NormalId.Right)
log("moved deck x", x0, "->", selRec.x)
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
H.moveY.MouseButton1Down:Fire(Enum.NormalId.Top)
H.moveY.MouseDrag:Fire(Enum.NormalId.Top, 4)
H.moveY.MouseButton1Up:Fire(Enum.NormalId.Top)
log("lifted deck yo", selRec.yo)
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
local w0 = selRec.w
H.size.MouseButton1Down:Fire(Enum.NormalId.Right)
H.size.MouseDrag:Fire(Enum.NormalId.Right, 4)
H.size.MouseButton1Up:Fire(Enum.NormalId.Right)
log("resized deck w", w0, "->", selRec.w)
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
H.rotate.MouseButton1Down:Fire(Enum.Axis.Y)
H.rotate.MouseDrag:Fire(Enum.Axis.Y, 0.8, 0)
H.rotate.MouseButton1Up:Fire(Enum.Axis.Y)
log("rotated deck r", selRec.r)
-- copy (new piece next to it, bought with the tick)
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
local n0 = #design.items
MOCK.clickExact("Copy (C)")
MOCK.click("PLACE", 1)
log("copy placed", n0, "->", #design.items)
-- screens: live camera, per-song change; instruments: song number
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then Designer.current.select(r) break end end
MOCK.clickExact("Live: artist")
MOCK.clickExact("+", 3) -- "For": song 1 (after width and height)
MOCK.clickExact("Live: fans")
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then log("screen config", r.rec.scr.default.m, r.rec.scr["1"] and r.rec.scr["1"].m) break end end
for _, r in ipairs(Stage3D.items) do if r.kind == "piano" then Designer.current.select(r) break end end
MOCK.clickExact("+", 1)
local pl = nil
for _, rec in ipairs(design.items) do if rec.t == "piano" then pl = rec.play end end
log("piano plays in song", pl)
for _, r in ipairs(Stage3D.items) do if r.kind == "piano" then Designer.current.select(r) break end end
MOCK.clickExact("Delete (X)")
log("after edit/copy/delete", #design.items, "money", app.state.money)
-- more spots = longer setlist
MOCK.clickExact("Artist")
MOCK.clickExact("Artist Spot")
for k = 1, 5 do
	MOCK.mouse = Vector2.new(900 + k * 10, 500)
	steps(2)
	click3D()
	MOCK.click("PLACE", 1)
end
log("songs in this design", GS.songCount(design))
assert(GS.songCount(design) == 7, "lift = song 1, 6 spots = songs 2-7")
key(Enum.KeyCode.F)
-- camera controls
UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.MouseButton2), false)
UIS.InputChanged:Fire(MOCK.input(Enum.UserInputType.MouseMovement, { Delta = Vector3.new(30, 10, 0) }), false)
UIS.InputEnded:Fire(MOCK.input(Enum.UserInputType.MouseButton2), false)
UIS.InputChanged:Fire(MOCK.input(Enum.UserInputType.MouseWheel, { Position = Vector3.new(0, 0, 1) }), false)
key(Enum.KeyCode.T)
MOCK.keys = { [Enum.KeyCode.W] = true, [Enum.KeyCode.D] = true }
steps(10)
MOCK.keys = {}
MOCK.clickExact("?")
-- preview this design (every item type, 6 songs) at 4x speed
MOCK.click("^Artist:")
MOCK.clickExact("▶  PREVIEW SHOW")
assert(app.mode == "live", "preview did not start")
MOCK.click("^Speed")
MOCK.click("^Speed")
local crowdN = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Fan" then crowdN = crowdN + 1 end end
log("center-stage crowd", crowdN)
local pf, songsSeen, liveParts = 0, {}, 0
while app.mode == "live" and pf < 9000 do
	MOCK.step(1 / 30)
	pf = pf + 1
	for _, t in ipairs(MOCK.texts("^%d+%. ")) do songsSeen[t] = true end
	if pf % 30 == 0 then
		local n = 0
		for _, d in ipairs(workspace:GetDescendants()) do if d:IsA("ViewportFrame") and d.Visible then for _, c in ipairs(d:GetChildren()) do if c:IsA("BasePart") then n = n + 1 end end end end
		liveParts = math.max(liveParts, n)
	end
end
local ns = 0
for _ in pairs(songsSeen) do ns = ns + 1 end
log("preview finished after frames", pf, "mode", app.mode, "songs shown", ns, "parts in live screens", liveParts)
assert(app.mode == "designer", "did not return to designer")
assert(ns == 7, "setlist should have 7 songs")
assert(liveParts > 200, "live screens should show a 3D picture (crowd)")
-- back to the library: copy and delete
MOCK.clickExact("◀  MY STAGES")
assert(app.current == "stages" and app.mode == "menu", "library")
local nd = #app.state.designs
MOCK.clickExact("Copy", nd)
MOCK.clickExact("Yes")
log("designs after copy", nd, "->", #app.state.designs)
MOCK.clickExact("Delete", #app.state.designs)
MOCK.clickExact("Yes")
log("designs after delete", #app.state.designs)
-- buy every tour template and preview it
for _, tpl in ipairs({ { "ARENA", "CENTER STAGE", "The Cube" }, { "ARENA", "END STAGE", "Portal Ring" }, { "STADIUM", "END STAGE", "Runway & Moon" } }) do
	app.state.money = 5000000
	if #app.state.designs >= 8 then GS.deleteDesign(app.state, app.state.designs[#app.state.designs].id) app:refreshCurrent() end
	MOCK.clickExact("+  NEW STAGE")
	MOCK.clickExact(tpl[1])
	MOCK.clickExact(tpl[2])
	MOCK.clickExact("Template: " .. tpl[3])
	MOCK.clickExact("CREATE & BUILD")
	assert(app.mode == "designer" and Designer.current.design.name == tpl[3], "template " .. tpl[3])
	log("template", tpl[3], "items", #Designer.current.design.items, "songs", GS.songCount(Designer.current.design), "cost", 5000000 - app.state.money)
	MOCK.clickExact("▶  PREVIEW SHOW")
	MOCK.click("^Speed")
	MOCK.click("^Speed")
	local f = 0
	while app.mode == "live" and f < 9000 do MOCK.step(1 / 30) f = f + 1 end
	assert(app.mode == "designer", "template preview did not end")
	MOCK.clickExact("DONE")
end
log("designs now", #app.state.designs)

-- 7) other screens
MOCK.clickExact("TOURS")
MOCK.clickExact("OFFICE")
MOCK.clickExact("SOCIAL")
log("social posts", #app.state.social, "first:", app.state.social[1] and app.state.social[1].text)
MOCK.clickExact("CHARTS")
MOCK.clickExact("OFFICE")
MOCK.clickExact("NEXT DAY")

-- 8) superstar stadium tour, watched live with skip
app.state.money = 60000000
app.state.stats.tickets = 2000000
log("sign nova", GS.sign(app.state, "nova"))
app:go("planner", { artistId = "nova" })
map.selected = "uk"
map:refresh()
MOCK.click("^STADIUMS")
MOCK.click("^%+ ADD$", 3) -- Wemblee (biggest UK stadium)
MOCK.click("^CLUBS")
MOCK.click("^%+ ADD$", 1) -- a club show too: needs a second, smaller production
map.selected = "us"
map:refresh()
MOCK.click("^STADIUMS")
MOCK.click("^%+ ADD$", 1)
log("nova draft", #map.draft.shows, map.draft.artistId)
MOCK.clickExact("NEXT: TICKETS & STAGE >")
log("production sections:", table.concat(MOCK.texts("VENUES  %("), " | "))
MOCK.clickExact("NEXT: CONFIRM >")
MOCK.clickExact("ANNOUNCE TOUR")
local nt = app.state.tours[1]
local dn = {}
for cls, id in pairs(nt.designs) do dn[#dn + 1] = cls .. "=" .. GS.getDesign(app.state, id).name end
log("tour productions:", table.concat(dn, ", "))
log("nova tour", nt.name, nt.shows[1].venueId, nt.shows[1].sold)
found = false
for _ = 1, 400 do
	MOCK.step(0.25)
	if #MOCK.buttons("^Nice!$") > 0 then MOCK.clickExact("Nice!") end
	if #MOCK.buttons("WATCH LIVE") > 0 then found = true break end
end
assert(found, "no stadium showtime")
MOCK.clickExact("WATCH LIVE")
steps(120)
local crowd = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Fan" then crowd = crowd + 1 end end
log("stadium crowd figures", crowd)
MOCK.click("^Skip")
steps(2)
assert(app.mode == "menu", "skip did not end the show")
MOCK.clickExact("Continue")
for _ = 1, 400 do
	MOCK.step(0.25)
	if #MOCK.buttons("^Great!$") > 0 then break end
end
MOCK.clickExact("Great!")
log("nova tour", nt.status, nt.gross)
local rows, best = GS.chart(app.state)
log("best chart rank", best)

-- 9) cancel a tour
app:go("planner", { artistId = "kai" })
map.selected = "us"
map:refresh()
MOCK.click("^%+ ADD$", 1)
MOCK.clickExact("NEXT: TICKETS & STAGE >")
MOCK.clickExact("NEXT: CONFIRM >")
MOCK.clickExact("ANNOUNCE TOUR")
MOCK.clickExact("Cancel tour")
MOCK.clickExact("Yes")
log("tours after cancel", #app.state.tours)

-- 10) save / load roundtrip
local json = MOCK.jsonEncode(app.state)
log("save size bytes", #json)
local loaded = GS.sanitize(MOCK.jsonDecode(json))
assert(loaded.money == app.state.money and #loaded.tours == #app.state.tours, "roundtrip mismatch")
-- start a second session from the save
app.speed = 1
app.gui:Destroy()
MOCK.loadData, MOCK.loadStatus = json, "ok"
task.spawn(function() App.start() end)
MOCK.runTasks()
local app2 = App.instance
MOCK.clickExact("CONTINUE")
assert(app2 ~= app, "second session not started")
log("second session money", app2.state.money, "saveAvailable", app2.saveAvailable)
app2:save()
log("saves fired", #MOCK.saves)
steps(30)
log("errors", #MOCK.errors)
