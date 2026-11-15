-- Full automated play-through of HEADLINER in the Roblox mock (server + client).
math.randomseed(7)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
-- pretend the audio files are uploaded so every sound path runs
for k in pairs(require(root.Data.Audio).IDS) do require(root.Data.Audio).IDS[k] = 1000 end
-- the server: builds the label building, owns the game state
local server = MOCK.newRaw("Script")
server.__props.Name = "GameServer"
rawset(server, "__path", SERVER_PATH)
MOCK.runScript(server)
MOCK.runTasks()
assert(workspace:FindFirstChild("StarlightRecords"), "the server did not build the label building")
local Players = game:GetService("Players")
Players.PlayerAdded:Fire(MOCK.player)
MOCK.runTasks()
local function SRV() return shared.HeadlinerServer.sessions[MOCK.player].state end
-- the client
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
-- test cheats change the state on the server, then the client gets the new state
local function resync() app:applyDelta(app:call("resync").delta) app:refreshCurrent() end
local function cheat(fn) fn(SRV()) resync() end
local function clearModals()
	for _ = 1, 8 do
		if #MOCK.buttons("^Nice!$") > 0 then MOCK.clickExact("Nice!")
		elseif #MOCK.buttons("^Great!$") > 0 then MOCK.clickExact("Great!")
		elseif #MOCK.buttons("^Continue$") > 0 then MOCK.clickExact("Continue")
		elseif #MOCK.buttons("^Let's go!$") > 0 then MOCK.clickExact("Let's go!") end
	end
end
local function nextDay() MOCK.click("^NEXT DAY", 1) steps(1) end

-- 1) main menu -> new game -> walking in the label building
assert(app.mode == "title", "should start on the title screen")
MOCK.clickExact("SETTINGS")
MOCK.clickExact("Low")
MOCK.clickExact("< Back")
MOCK.clickExact("STORE")
MOCK.clickExact("< Back")
MOCK.clickExact("CREDITS")
MOCK.clickExact("< Back")
assert(#MOCK.buttons("SANDBOX") == 1, "sandbox button missing in studio")
for k = 1, 2 do
	log("menu scene", k, "parts", #workspace.MenuScene:GetDescendants())
	steps(475, 0.1)
end
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
assert(app.state and app.state.artists.lila.signed, "starter not signed")
assert(SRV().artists.lila.signed and SRV().labelName == app.state.labelName, "server state differs")
MOCK.clickExact("Let's go!")
assert(app.mode == "world", "not walking in the building")
assert(MOCK.player.Character and MOCK.player.Character:FindFirstChild("Humanoid"), "no character")
assert(app.hud.Visible and #MOCK.buttons("^OFFICE$") == 0, "old tab bar still there")
assert(#MOCK.buttons("^>>>$") == 0, "speed buttons still there")
log("label", app.state.labelName, "money", app.state.money, "objective", GS.objective(app.state).text)
assert(GS.objective(app.state).target == "maptable", "first goal should be the world map")
local W = app.world
assert(W.prompts.laptop.Enabled and W.prompts.maptable.Enabled, "start stations open")
assert(not W.prompts.stagehall.Enabled, "stage hall should be locked")
assert(not W.prompts.meeting.Enabled, "meeting prompt only while sitting")
steps(30)
log("hub parts", #workspace.StarlightRecords:GetDescendants(), "client parts", #workspace.HubClient:GetDescendants())
-- locked hall: a hint
W.trigger("stagehall")
assert(app.mode == "world")
-- laptop
MOCK.prompt("laptop")
assert(app.current == "office" and app.mode == "menu", "laptop opens the overview")
MOCK.clickExact("TOURS")
assert(app.current == "tours")
MOCK.clickExact("✕  CLOSE")
assert(app.mode == "world", "close returns to walking")
-- book a show: country on the map -> n-th open venue -> first free day after the last show
local function book(cid, n)
	local map = app.screens.planner
	if map.step ~= 2 then map:setStep(2) end
	map:pickCountry(cid)
	assert(map.step == 3, "venue step after picking a country")
	local picks = MOCK.buttons("^PICK")
	local btn = ((n or 1) < 0) and picks[#picks] or picks[n or 1]
	assert(btn, "no PICK button")
	btn.MouseButton1Click:Fire()
	MOCK.runTasks()
	assert(map.step == 4 and map.picked, "date step after picking a venue")
	local last = map.draft.shows[#map.draft.shows]
	local d = last and (last.day + 1) or (app.state.day + 21)
	while map:dayState(d) ~= "ok" do d = d + 1 end
	local before = #map.draft.shows
	map:dayClicked(d)
	assert(#map.draft.shows == before + 1, "day click did not add a show")
end

-- 2) plan a tour: 6 steps, one screen each (only one artist -> the artist step is skipped)
MOCK.prompt("maptable")
local map = app.screens.planner
assert(map.step == 2 and map.draft.artistId == "lila", "one artist: starts on the map (step 2)")
assert(#MOCK.texts("^STEP 2 OF 6$") == 1, "progress shown")
local WM3 = require(root.Client.WorldMap3D)
log("3D map active", WM3.active, "country parts", #WM3.queryParts)
MOCK.clickExact("Europe")
steps(5)
MOCK.mouse = Vector2.new(700, 300)
steps(3)
UIS0 = game:GetService("UserInputService")
UIS0.InputChanged:Fire(MOCK.input(Enum.UserInputType.MouseWheel, { Position = Vector3.new(0, 0, 1) }), false)
steps(3)
map:hoverCountry("ch")
log("hover text", MOCK.texts("Switzerland")[1])
-- venue step: only clubs are open at level 1
map:pickCountry("uk")
local locked = #MOCK.texts("^🔒")
log("uk venues: open", #MOCK.buttons("^PICK"), "locked", locked)
assert(locked > 0 and #MOCK.buttons("^PICK") >= 1, "theatres/arenas locked at level 1")
MOCK.clickExact("<  BACK")
assert(map.step == 2, "back from venues to the map")
book("uk", 1)
-- calendar alone on its screen
local m0 = map.calMonth[2]
MOCK.clickExact("<")
assert(map.calMonth[2] ~= m0, "month navigation failed")
map.calMonth = { 2027, m0 }
map:refresh()
log("calendar month", MOCK.texts("^%a+ 20%d%d$")[1], "free days", #MOCK.texts("^free$"), "taken", #MOCK.texts("^taken:"))
-- a second night in the same club, then remove it again
local first = map.draft.shows[1]
local d2 = first.day + 1
while map:dayState(d2) ~= "ok" do d2 = d2 + 1 end
map:dayClicked(d2)
assert(#map.draft.shows == 2, "second night")
map:dayClicked(d2)
assert(#map.draft.shows == 1, "click on own show did not remove it")
MOCK.clickExact("+ ADD ANOTHER SHOW")
assert(map.step == 2, "add another show -> map")
assert(map.routeBox.Visible, "booked shows listed on the map")
for _, cid in ipairs({ "fr", "de", "nl" }) do book(cid, 1) end
log("draft shows", #map.draft.shows)
for i = 2, #map.draft.shows do assert(map.draft.shows[i].day > map.draft.shows[i - 1].day, "dates not sorted") end
MOCK.clickExact("NEXT: TICKET PRICES >")
assert(map.step == 5, "ticket step")
MOCK.clickExact("+5", 1)
MOCK.clickExact("-1", 1)
log("section prices", MOCK.texts("^%$%d+$")[1], MOCK.texts("% sold")[1])
MOCK.clickExact("<  BACK")
assert(map.step == 4, "back from tickets -> calendar")
MOCK.clickExact("NEXT: TICKET PRICES >")
MOCK.clickExact("NEXT: CONFIRM >")
assert(map.step == 6)
log("confirm estimate:", MOCK.texts("Estimated gross")[1], "stage:", MOCK.texts("^Club: ")[1])
MOCK.clickExact("ANNOUNCE TOUR")
if app.current ~= "tours" then for _, d in ipairs(app.toastFrame:GetDescendants()) do if d:IsA("TextLabel") then log("toast:", d.Text) end end end
assert(app.current == "tours", "not on tours screen after announce")
local tour = app.state.tours[1]
log("tour", tour.name, "#shows", #tour.shows, "price", tour.price, tour.shows[2].price, "presale sold", tour.shows[1].sold)
MOCK.click("^Social Ads")
MOCK.clickExact("+")
log("tour price after +", tour.price, tour.shows[3].price)
MOCK.clickExact("OVERVIEW")
assert(app.current == "office")
log("upcoming:", #MOCK.texts("@"))
MOCK.clickExact("✕  CLOSE")
assert(SRV().tours[1] and SRV().tours[1].id == tour.id, "the tour is not on the server")


-- 3) press NEXT DAY until opening night
local found = false
for _ = 1, 200 do
	if #MOCK.buttons("WATCH LIVE") > 0 then found = true break end
	nextDay()
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
log("live show finished after frames", frames, "mode", app.mode)
assert(#MOCK.buttons("^Continue$") == 1, "no show report")
log("report:", MOCK.texts("Attendance")[1])
MOCK.clickExact("Continue")
assert(app.mode == "world", "back in the building after the show")
assert(W.prompts.stagehall.Enabled, "the stage hall opens after the first show")
assert(GS.objective(app.state).target == "stagehall", "next goal: stage hall")

-- 4) the rest of the tour
local done = false
for _ = 1, 400 do
	if #MOCK.buttons("^Great!$") > 0 then done = true break end
	if #MOCK.buttons("^Skip$") > 0 then MOCK.clickExact("Skip")
	elseif #MOCK.buttons("^Continue$") > 0 then MOCK.clickExact("Continue")
	elseif #MOCK.buttons("^Nice!$") > 0 then MOCK.clickExact("Nice!")
	else nextDay() end
end
assert(done, "tour never completed")
log("tour complete:", tour.status, "gross", tour.gross, "net", tour.net, "money", app.state.money, "server money", SRV().money)
assert(SRV().money == app.state.money, "money differs")
MOCK.clickExact("Great!")
assert(GS.unlocks(app.state).charts, "charts open after the first tour")
MOCK.prompt("charts")
assert(app.current == "charts")
MOCK.clickExact("✕  CLOSE")

-- 5) meeting room: sit down, then the meeting starts; Kai is locked until level 2
local seat = workspace.StarlightRecords:FindFirstChild("MeetingSeat1", true)
MOCK.sit(seat)
steps(2)
assert(W.prompts.meeting.Enabled, "meeting prompt while sitting")
MOCK.prompt("meeting")
assert(app.current == "artists")
MOCK.clickExact("TALENT SCOUT")
log("locked buttons", #MOCK.buttons("^LOCKED"))
MOCK.clickExact("✕  CLOSE")
cheat(function(s) s.stats.tickets = 30000 s.money = 1000000 end)
nextDay()
clearModals()
MOCK.prompt("meeting")
MOCK.clickExact("TALENT SCOUT")
MOCK.click("^SIGN FOR %$250,000")
MOCK.clickExact("Yes")
log("kai signed", app.state.artists.kai.signed, SRV().artists.kai.signed, "money", app.state.money)
assert(SRV().artists.kai.signed, "signing did not reach the server")
MOCK.clickExact("✕  CLOSE")
MOCK.sit(nil)
steps(2)
assert(not W.prompts.meeting.Enabled, "standing up hides the meeting prompt")

-- 6) stage builder: place every item type the new way (card -> click into the world -> tick)
MOCK.prompt("stagehall")
assert(app.current == "stages", "stages screen")
local Designer = require(root.Client.Designer)
local Stage3D = require(root.Client.Stage3D)
local UIS = game:GetService("UserInputService")
local function click3D() UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.MouseButton1), false) MOCK.runTasks() end
local function key(k) UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.Keyboard, { KeyCode = k }), false) MOCK.runTasks() end
cheat(function(s) s.money = 5000000 end)
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
		if def.cat == cat.id and not def.hidden then
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
local visible = 0
for _, def in ipairs(StageItems.list) do if not def.hidden then visible = visible + 1 end end
assert(#design.items == before + visible, "not every item was placed")
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
H.moveX.MouseEnter:Fire() -- the mouse was over an arrow when the item was deleted
MOCK.clickExact("Delete (X)")
log("after edit/copy/delete", #design.items, "money", app.state.money)
-- clicking another item must still select it
MOCK.mouse = Vector2.new(960, 540)
steps(2)
click3D()
assert(Designer.current.target() ~= nil, "after deleting, other items must still be clickable")
key(Enum.KeyCode.X)
log("deleted a second item with X", #design.items)
steps(2)
click3D()
assert(Designer.current.target() ~= nil, "still clickable after the second delete")
key(Enum.KeyCode.F)
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
assert(GS.songCount(design) == 8, "lift + pop-up = song 1, 6 spots + tower lift = songs 2-8")
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
		-- screens live in the PlayerGui (Adornee = screen part), Roblox does not draw ViewportFrames in the Workspace
		for _, d in ipairs(MOCK.playerGui:GetDescendants()) do if d:IsA("ViewportFrame") and d.Visible then for _, c in ipairs(d:GetChildren()) do if c:IsA("BasePart") then n = n + 1 end end end end
		liveParts = math.max(liveParts, n)
	end
end
local ns = 0
for _ in pairs(songsSeen) do ns = ns + 1 end
log("preview finished after frames", pf, "mode", app.mode, "songs shown", ns, "parts in live screens", liveParts)
assert(app.mode == "designer", "did not return to designer")
assert(ns == 8, "setlist should have 8 songs")
assert(liveParts > 200, "live screens should show a 3D picture (crowd)")
local LiveShow = require(root.Client.LiveShow)
local kinds = {}
for _, w in ipairs(LiveShow.lastWalks) do kinds[#kinds + 1] = w.kind assert(w.kind ~= "hidden", "the artist must walk, not vanish") end
log("walks", table.concat(kinds, ","))
local towerWalk = false
for _, w in ipairs(LiveShow.lastWalks) do if w.tower then towerWalk = true end end
assert(towerWalk, "the tower lift must get its own song")
local barriers = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Barrier" then barriers = barriers + 1 end end
-- back to the library: copy and delete
MOCK.clickExact("◀  MY STAGES")
log("money after the builder: client", app.state.money, "server", SRV().money, "items on server", #GS.getDesign(SRV(), design.id).items)
assert(#GS.getDesign(SRV(), design.id).items == #design.items, "the server did not get the edited stage")
local leftover = 0
for _, d in ipairs(MOCK.playerGui:GetChildren()) do if d:IsA("SurfaceGui") then leftover = leftover + 1 end end
log("screen guis left in PlayerGui after closing the builder", leftover)
assert(leftover == 0, "screen guis must be removed with their screens")
assert(app.current == "stages" and app.mode == "menu", "library")
local nd = #app.state.designs
MOCK.clickExact("Copy", nd)
MOCK.clickExact("Yes")
log("designs after copy", nd, "->", #app.state.designs)
MOCK.clickExact("Delete", #app.state.designs)
MOCK.clickExact("Yes")
log("designs after delete", #app.state.designs)
-- buy every tour template and preview it
for _, tpl in ipairs({ { "ARENA", "CENTER STAGE", "The Cube" }, { "ARENA", "END STAGE", "Portal Ring" }, { "STADIUM", "END STAGE", "Runway & Moon" }, { "STADIUM", "END STAGE", "Stadium Tour" } }) do
	cheat(function(s)
		s.money = 5000000
		while #s.designs >= 7 do GS.deleteDesign(s, s.designs[#s.designs].id) end
	end)
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
	if tpl[3] == "Stadium Tour" then
		local tw = false
		for _, w in ipairs(LiveShow.lastWalks) do if w.tower then tw = true end end
		assert(tw, "stadium template: the tower lift gets a song")
	end
	MOCK.clickExact("DONE")
	assert(math.abs(SRV().money - app.state.money) < 1, "server and client money differ after the builder")
end
log("designs now", #app.state.designs)


-- 7) phone + laptop pages
MOCK.clickExact("✕  CLOSE")
assert(app.mode == "world")
app:openPhone()
assert(app.current == "social")
log("social posts", #app.state.social, "first:", app.state.social[1] and app.state.social[1].text)
MOCK.clickExact("✕  CLOSE")

-- 8) superstar stadium tour (needs level 4), watched live with skip
cheat(function(s) s.money = 60000000 s.stats.tickets = 2000000 end)
log("sign nova", app:act("sign", { artistId = "nova" }))
clearModals()
MOCK.prompt("maptable")
map:show({ artistId = "nova" })
assert(map.step == 2, "planner for nova")
book("uk", -1) -- the last (biggest) venue: the stadium
book("uk", 1) -- and a club: needs a smaller stage too
log("nova draft", #map.draft.shows, map.draft.artistId)
MOCK.clickExact("NEXT: TICKET PRICES >")
log("ticket tabs", table.concat(MOCK.texts("^STADIUMS$"), ","), table.concat(MOCK.texts("^CLUBS$"), ","))
MOCK.clickExact("NEXT: CONFIRM >")
log("stages:", table.concat(MOCK.texts("^%a+: .+"), " | "))
MOCK.clickExact("ANNOUNCE TOUR")
local nt = app.state.tours[1]
log("nova tour", nt.name, nt.shows[1].venueId, nt.shows[1].sold)
MOCK.clickExact("✕  CLOSE")
found = false
for _ = 1, 200 do
	clearModals()
	if #MOCK.buttons("WATCH LIVE") > 0 then found = true break end
	nextDay()
end
assert(found, "no stadium showtime")
MOCK.clickExact("WATCH LIVE")
steps(120)
local crowd = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Fan" then crowd = crowd + 1 end end
log("stadium crowd figures", crowd)
MOCK.click("^Skip")
steps(2)
MOCK.clickExact("Continue")
for _ = 1, 200 do
	if #MOCK.buttons("^Great!$") > 0 then break end
	if #MOCK.buttons("^Skip$") > 0 then MOCK.clickExact("Skip")
	elseif #MOCK.buttons("^Continue$") > 0 then MOCK.clickExact("Continue")
	else nextDay() end
end
log("report texts", #MOCK.texts("MONEY PER SHOW"), #MOCK.texts("WHERE THE MONEY WENT"))
MOCK.clickExact("Great!")
local rows, best = GS.chart(app.state)
log("best chart rank", best)

-- 9) cancel a tour (laptop > tours)
MOCK.prompt("maptable")
map:show({ artistId = "kai" })
book("us", 1)
MOCK.clickExact("NEXT: TICKET PRICES >")
MOCK.clickExact("NEXT: CONFIRM >")
MOCK.clickExact("ANNOUNCE TOUR")
local nTours = #app.state.tours
MOCK.clickExact("Cancel tour")
MOCK.clickExact("Yes")
log("tours after cancel", nTours, "->", #app.state.tours, "server", #SRV().tours)
assert(#SRV().tours == nTours - 1, "cancel did not reach the server")
MOCK.clickExact("✕  CLOSE")

-- 10) leave and come back: the server saved, the next session continues
local money = SRV().money
Players.PlayerRemoving:Fire(MOCK.player)
MOCK.runTasks()
log("saves", #MOCK.saves)
Players.PlayerAdded:Fire(MOCK.player)
MOCK.runTasks()
app.gui:Destroy()
task.spawn(function() App.start() end)
MOCK.runTasks()
local app2 = App.instance
assert(app2 ~= app, "second session not started")
MOCK.click("^CONTINUE$")
assert(app2.mode == "world", "continue did not enter the building")
log("second session money", app2.state.money, "was", money)
assert(app2.state.money == money and #app2.state.tours == #SRV().tours, "loaded game differs")
app2.gui:Destroy()

-- 11) developer sandbox: unlimited money, everything open, own save
task.spawn(function() App.start() end)
MOCK.runTasks()
local app3 = App.instance
MOCK.click("^SANDBOX")
MOCK.click("^NEW SANDBOX", 1)
MOCK.clickExact("Let's go!")
assert(app3.state.sandbox and app3.state.money >= 1000000000, "sandbox money")
assert(GS.level(app3.state) == 5, "sandbox: every level")
local un = GS.unlocks(app3.state)
assert(un.stagehall and un.charts, "sandbox: every room open")
assert(app3.world.prompts.stagehall.Enabled, "sandbox: hall prompt")
local ok3 = app3:act("sign", { artistId = "nova" })
assert(ok3 and app3.state.money >= 1000000000, "sandbox: sign the superstar for free")
MOCK.clickExact("+7 DAYS")
log("sandbox day", app3.state.day, "money", app3.state.money)
assert(MOCK.store.data["player_1_sandbox"] ~= nil, "sandbox has its own save")
assert(MOCK.store.data["player_1"] ~= nil, "real save still there")
steps(30)
log("errors", #MOCK.errors)
