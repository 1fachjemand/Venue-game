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
local function nextDay() app:nextDay() MOCK.runTasks() steps(1) end

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
assert(GS.objective(app.state).target == "meeting", "first goal: the meeting room")
local W = app.world
assert(W.prompts.laptop.Enabled and W.prompts.maptable.Enabled, "start stations open")
assert(W.prompts.stagehall.Enabled, "stage hall is open from the start")
app:setSpeed(1) -- pause the clock: the test moves time itself
assert(#MOCK.buttons("^2x$") >= 1, "speed buttons in the HUD")
assert(not W.prompts.meeting.Enabled, "meeting prompt only while sitting")
steps(30)
log("hub parts", #workspace.StarlightRecords:GetDescendants(), "client parts", #workspace.HubClient:GetDescendants())
-- laptop
MOCK.prompt("laptop")
assert(app.current == "office" and app.mode == "menu", "laptop opens the overview")
MOCK.clickExact("TOURS")
assert(app.current == "tours")
MOCK.clickExact("CLOSE")
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

-- the meeting room board: PLAN A TOUR for an artist (stands up, the arrow goes to the world map)
local function planArtist(artistId)
	local seat = workspace.StarlightRecords:FindFirstChild("MeetingSeat3", true)
	MOCK.sit(seat)
	steps(2)
	MOCK.prompt("meeting")
	assert(app.mode == "meeting", "meeting did not start")
	local name = require(root.Data.Artists).byId[artistId].name
	local done = false
	for _, l in ipairs(app.world.boardGui:GetDescendants()) do
		if not done and l:IsA("TextLabel") and l.Text == name then
			for _, b in ipairs(l.Parent:GetDescendants()) do
				if not done and b:IsA("TextButton") and (b.Text == "PLAN A TOUR" or b.Text:find("IN PLANNING")) then
					b.MouseButton1Click:Fire() MOCK.runTasks() done = true
				end
			end
		end
	end
	assert(done, "no PLAN A TOUR button for " .. artistId)
	if #MOCK.buttons("^Yes$") > 0 then MOCK.clickExact("Yes") end
	MOCK.sit(nil)
	steps(2)
	assert(app.state.draft.artistId == artistId and SRV().draft.artistId == artistId, "plan not started for " .. artistId)
	assert(app.world.target == "maptable", "arrow should point to the world map")
end
-- the laptop: ticket prices, (stage hall), announce
local function pricesAndAnnounce(withStageHall)
	MOCK.prompt("laptop")
	MOCK.clickExact("TOUR PLAN")
	assert(app.current == "tourplan", "tour plan page")
	MOCK.clickExact("SET PRICES")
	MOCK.clickExact("+5", 1)
	MOCK.clickExact("SAVE PRICES >")
	assert(SRV().draft.pricesSet, "prices not saved")
	MOCK.clickExact("CLOSE")
	-- the stage: select one in the stage hall
	assert(GS.objective(app.state).target == "stagehall", "next: the stage hall")
	MOCK.prompt("stagehall")
	log("select buttons", #MOCK.buttons("^SELECT FOR TOUR"))
	for _, d in ipairs(app.state.designs) do
		if d.class == "Club" then app.screens.stages:selectForTour(d) break end
	end
	assert(SRV().draft.stageSet, "stage not selected")
	MOCK.clickExact("CLOSE")
	assert(GS.objective(app.state).target == "laptop", "next: announce on the laptop")
	MOCK.prompt("laptop")
	MOCK.clickExact("TOUR PLAN")
	log("plan page:", MOCK.texts("Estimated gross")[1])
	MOCK.clickExact("ANNOUNCE TOUR")
end

-- 2) plan a tour room by room: meeting room (artist) -> world map (dates) -> laptop (prices, announce)
MOCK.prompt("maptable")
local map = app.screens.planner
assert(#MOCK.texts("^Which artist goes on tour") == 1, "map table without an artist asks for the meeting room")
MOCK.clickExact("GO TO THE MEETING ROOM")
assert(app.mode == "world" and app.world.target == "meeting", "guided to the meeting room")
planArtist("lila")
MOCK.prompt("maptable")
assert(map.step == 2 and map.draft.artistId == "lila", "the map shows the countries")
assert(#MOCK.texts("STEP 2 OF 5") == 1, "plan progress shown")
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
local locked = #MOCK.texts("^LOCKED  ")
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
MOCK.clickExact("DONE: PRICES ON THE LAPTOP >")
assert(app.mode == "world" and app.world.target == "laptop", "after the dates: to the laptop")
assert(#SRV().draft.shows == #map.draft.shows, "dates are on the server")
pricesAndAnnounce(false)
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
MOCK.clickExact("CLOSE")
assert(SRV().tours[1] and SRV().tours[1].id == tour.id, "the tour is not on the server")


-- 3) press NEXT DAY until opening night
local found = false
for _ = 1, 200 do
	if #MOCK.buttons("GO TO THE SHOW") > 0 then found = true break end
	nextDay()
end
assert(found, "no SHOWTIME modal")
log("showtime on day", app.state.day)
MOCK.clickExact("GO TO THE SHOW")
assert(app.mode == "live", "live show did not start")
steps(40)
local char = MOCK.player.Character
log("player in the venue at", char.PrimaryPart.CFrame.Position, "camera", workspace.CurrentCamera.CameraType)
assert(char.PrimaryPart.CFrame.Position.X < 1000, "the character was not brought into the venue")
assert(workspace.CurrentCamera.CameraType == Enum.CameraType.Custom, "walk mode: normal camera")
local solidWalls, bounds, solidDecks = 0, 0, 0
for _, d in ipairs(workspace.HeadlinerWorld:GetDescendants()) do
	if d:IsA("BasePart") then
		if (d.Name == "Wall" or d.Name == "BackWall" or d.Name == "StageBackWall") and d.CanCollide then solidWalls = solidWalls + 1 end
		if d.Name == "VenueBoundary" then bounds = bounds + 1 end
		if d:FindFirstAncestor("Design") and d.CanCollide then solidDecks = solidDecks + 1 end
	end
end
log("walk mode: solid walls", solidWalls, "boundaries", bounds, "solid stage parts", solidDecks)
assert(solidWalls > 0 and bounds == 4 and solidDecks > 0, "the venue must be solid when you walk in it")
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
log("report:", MOCK.texts("@")[1], MOCK.texts("^TICKETS SOLD$")[1])
MOCK.clickExact("Continue")
steps(60)
assert(app.mode == "world", "back in the building after the show")
log("player back at", char.PrimaryPart.CFrame.Position)
assert(char.PrimaryPart.CFrame.Position.X > 3000, "back in the office")
assert(app.world.target == nil, "after the first show the arrow only shows when a button sends you")

-- 4) the rest of the tour
local done = false
for _ = 1, 400 do
	if #MOCK.buttons("^Great!$") > 0 then done = true break end
	if #MOCK.buttons("^Skip show$") > 0 then MOCK.clickExact("Skip show")
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
MOCK.clickExact("CLOSE")

-- 5) meeting room: sit down, start the meeting, the board shows roster + talent; Kai is locked until level 2
local seat = workspace.StarlightRecords:FindFirstChild("MeetingSeat1", true)
MOCK.sit(seat)
steps(2)
assert(W.prompts.meeting.Enabled, "meeting prompt while sitting")
MOCK.prompt("meeting")
assert(app.mode == "meeting" and W.boardGui, "meeting started, board shows")
log("board: roster", #MOCK.texts("^YOUR ROSTER"), "locked", #MOCK.buttons("^LOCKED"))
assert(#MOCK.buttons("^LOCKED") > 0, "bigger artists locked at level 1")
MOCK.sit(nil)
steps(2)
assert(app.mode == "world" and not W.boardGui, "standing up ends the meeting")
assert(not W.prompts.meeting.Enabled, "standing up hides the meeting prompt")
cheat(function(s) s.stats.tickets = 30000 s.money = 1000000 end)
nextDay()
clearModals()
MOCK.sit(seat)
steps(2)
MOCK.prompt("meeting")
local kaiBtn = nil
for _, b in ipairs(MOCK.buttons("^SIGN$")) do kaiBtn = kaiBtn or b end
assert(kaiBtn, "a SIGN button on the board")
-- sign the second SIGN card (Kai) by name
local signed = false
for _, card in ipairs(W.boardGui:GetDescendants()) do
	if card:IsA("TextLabel") and card.Text == "Kai Rivers" then
		for _, b in ipairs(card.Parent:GetDescendants()) do
			if b:IsA("TextButton") and b.Text == "SIGN" then b.MouseButton1Click:Fire() MOCK.runTasks() signed = true end
		end
	end
end
assert(signed, "Kai's SIGN button")
MOCK.clickExact("Yes")
log("kai signed", app.state.artists.kai.signed, SRV().artists.kai.signed, "money", app.state.money)
assert(SRV().artists.kai.signed, "signing did not reach the server")
MOCK.sit(nil)
steps(2)
-- a link to another room: the arrow points there
app:go("artists")
log("guide after a link to the meeting room:", W.target)
assert(W.target == "meeting", "a link to another room points the arrow there")

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
		if def.cat == cat.id and not def.hidden and def.id ~= "spot" and def.mount ~= "side" then -- spots: step 2, side mounts: on a tower (tested below)
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
for _, def in ipairs(StageItems.list) do if not def.hidden and def.id ~= "spot" and def.mount ~= "side" then visible = visible + 1 end end
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
local xs0 = selRec.x
H.size.MouseButton1Down:Fire(Enum.NormalId.Right)
H.size.MouseDrag:Fire(Enum.NormalId.Right, 4)
H.size.MouseButton1Up:Fire(Enum.NormalId.Right)
log("resized deck w", w0, "->", selRec.w, "x", xs0, "->", selRec.x)
assert(selRec.w == w0 + 4 and math.abs(math.abs(selRec.x - xs0) - 2) < 0.01, "resize grows one side only")
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
local w1, xs1 = selRec.w, selRec.x
MOCK.keys = { [Enum.KeyCode.LeftShift] = true }
H.size.MouseButton1Down:Fire(Enum.NormalId.Right)
H.size.MouseDrag:Fire(Enum.NormalId.Right, 2)
H.size.MouseButton1Up:Fire(Enum.NormalId.Right)
MOCK.keys = {}
log("shift resize w", w1, "->", selRec.w, "x", xs1, "->", selRec.x)
assert(selRec.w == w1 + 4 and math.abs(selRec.x - xs1) < 0.01, "Shift: both sides grow")
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
-- step 2 (setlist & show): screens: live camera, per-song change; instruments: song number; effects per song
MOCK.clickExact("STEP 2: SETLIST & SHOW >")
log("phase show, catalog visible", Designer.current.panels[3].Visible)
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then Designer.current.select(r) break end end
MOCK.clickExact("Live: artist")
MOCK.clickExact("+", 1) -- "For": song 1
MOCK.clickExact("Live: fans")
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then log("screen config", r.rec.scr.default.m, r.rec.scr["1"] and r.rec.scr["1"].m) break end end
for _, r in ipairs(Stage3D.items) do if r.kind == "piano" then Designer.current.select(r) break end end
MOCK.clickExact("+", 1)
local pl = nil
for _, rec in ipairs(design.items) do if rec.t == "piano" then pl = rec.play end end
log("piano plays in song", pl)
local fxRec = nil
for _, r in ipairs(Stage3D.items) do if r.kind == "pyro" or r.kind == "co2" or r.kind == "sparks" then Designer.current.select(r) fxRec = r.rec break end end
if fxRec then
	MOCK.clickExact("2")
	MOCK.clickExact("3")
	log("effect fires in songs", fxRec.t, table.concat(fxRec.songs or {}, ","))
	assert(type(fxRec.songs) == "table" and #fxRec.songs == 2, "effect songs not set")
else
	log("no effect item in this design")
end
MOCK.clickExact("< STEP 1: BUILD")
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
-- side mounts clamp onto a truss tower
do
	local design0 = Designer.current.design
	local tower = { t = "truss", x = 60, z = -18, r = 0 }
	GS.buyItem(app.state, design0, tower)
	Designer.current.switchDesign(design0)
	MOCK.clickExact("Lights")
	MOCK.clickExact("Side Wash")
	MOCK.mouse = Vector2.new(960 + math.floor(61.6 / 1.0526 * 10), 500)
	steps(2)
	local n1 = #design0.items
	key(Enum.KeyCode.Q)
	local sw = design0.items[#design0.items]
	log("side wash", #design0.items - n1, sw.t, sw.x, sw.z, sw.r, sw.yo)
	assert(#design0.items == n1 + 1 and sw.t == "sidewash" and math.abs(sw.x - 61.05) < 0.1 and sw.r == 90, "side wash clamps onto the tower")
	key(Enum.KeyCode.F)
	key(Enum.KeyCode.F)
	-- groups: Shift + click, copy in place, mirror, move together, delete
	local a, b
	for _, r in ipairs(Stage3D.items) do
		if r.kind == "truss_beam" or r.kind == "speakers" then
			if not a then a = r elseif not b and r.rec.x ~= a.rec.x then b = r end
		end
	end
	Designer.current.select(a)
	Designer.current.toggleInGroup(b)
	assert(#(Designer.current.group() or {}) == 2, "Shift + click makes a group")
	local n2 = #design0.items
	key(Enum.KeyCode.C)
	log("group copied", n2, "->", #design0.items)
	assert(#design0.items == n2 + 2, "group copy")
	local g = Designer.current.group()
	assert(g and #g == 2, "the copies are the new group")
	local gx = { g[1].rec.x, g[2].rec.x }
	steps(2)
	H.moveX.MouseButton1Down:Fire(Enum.NormalId.Right)
	H.moveX.MouseDrag:Fire(Enum.NormalId.Right, 6)
	H.moveX.MouseButton1Up:Fire(Enum.NormalId.Right)
	g = Designer.current.group()
	log("group moved", gx[1], "->", g[1].rec.x, gx[2], "->", g[2].rec.x)
	local n3 = #design0.items
	key(Enum.KeyCode.M)
	log("mirrored", n3, "->", #design0.items)
	assert(#design0.items > n3, "mirror makes copies")
	local n4 = #design0.items
	key(Enum.KeyCode.X)
	log("group deleted", n4, "->", #design0.items)
	assert(#design0.items < n4, "group delete")
end
-- Q places an item in one go (build step)
MOCK.clickExact("Decor")
MOCK.clickExact("Velvet Drapes")
MOCK.mouse = Vector2.new(940, 520)
steps(2)
local nq = #design.items
key(Enum.KeyCode.Q)
log("placed with Q", nq, "->", #design.items)
assert(#design.items == nq + 1, "Q must place the item")
key(Enum.KeyCode.F)
key(Enum.KeyCode.F)
-- more spots = longer setlist (step 2)
MOCK.clickExact("STEP 2: SETLIST & SHOW >")
MOCK.clickExact("+ ADD ARTIST SPOT (a new song)")
for k = 1, 6 do
	MOCK.mouse = Vector2.new(900 + k * 10, 500)
	steps(2)
	key(Enum.KeyCode.Q)
end
log("songs in this design", GS.songCount(design))
assert(GS.songCount(design) == 8, "lift + pop-up = song 1, 6 spots + tower lift = songs 2-8")
key(Enum.KeyCode.F)
log("setlist rows", #MOCK.texts("^SONG %d"))
MOCK.clickExact("< STEP 1: BUILD")
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
MOCK.clickExact("> PREVIEW SHOW")
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
MOCK.clickExact("< MY STAGES")
log("money after the builder: client", app.state.money, "server", SRV().money, "items on server", #GS.getDesign(SRV(), design.id).items)
assert(#GS.getDesign(SRV(), design.id).items == #design.items, "the server did not get the edited stage")
local leftover = 0
for _, d in ipairs(MOCK.playerGui:GetChildren()) do if d:IsA("SurfaceGui") and d.Name ~= "Poster" then leftover = leftover + 1 end end
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
	MOCK.clickExact("> PREVIEW SHOW")
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
MOCK.clickExact("CLOSE")
assert(app.mode == "world")
app:openPhone()
assert(app.mode == "phone" and app.phone.frame.Visible, "phone open")
MOCK.clickExact("FAN MOOD")
MOCK.clickExact("TRENDING")
MOCK.clickExact("FEED")
log("social posts", #app.state.social, "first:", app.state.social[1] and app.state.social[1].text)
MOCK.clickExact("X")
assert(app.mode == "world", "phone closed")

-- 8) superstar stadium tour (needs level 4), watched live with skip
cheat(function(s) s.money = 60000000 s.stats.tickets = 2000000 end)
log("sign nova", app:act("sign", { artistId = "nova" }))
clearModals()
planArtist("nova")
MOCK.prompt("maptable")
assert(map.step == 2, "planner for nova")
book("uk", -1) -- the last (biggest) venue: the stadium
book("uk", 1) -- and a club: needs a smaller stage too
log("nova draft", #map.draft.shows, map.draft.artistId)
MOCK.clickExact("DONE: PRICES ON THE LAPTOP >")
pricesAndAnnounce(true)
log("stages:", table.concat(MOCK.texts("^%a+: .+"), " | "))
local nt = app.state.tours[1]
log("nova tour", nt.name, nt.shows[1].venueId, nt.shows[1].sold)
MOCK.clickExact("CLOSE")
found = false
for _ = 1, 200 do
	clearModals()
	if #MOCK.buttons("GO TO THE SHOW") > 0 then found = true break end
	nextDay()
end
assert(found, "no stadium showtime")
MOCK.clickExact("GO TO THE SHOW")
steps(120)
local crowd = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Fan" then crowd = crowd + 1 end end
log("stadium crowd figures", crowd)
MOCK.click("^Skip")
steps(2)
MOCK.clickExact("Continue")
for _ = 1, 200 do
	if #MOCK.buttons("^Great!$") > 0 then break end
	if #MOCK.buttons("^Skip show$") > 0 then MOCK.clickExact("Skip show")
	elseif #MOCK.buttons("^Continue$") > 0 then MOCK.clickExact("Continue")
	else nextDay() end
end
log("report texts", #MOCK.texts("MONEY PER SHOW"), #MOCK.texts("WHERE THE MONEY WENT"))
MOCK.clickExact("Great!")
local rows, best = GS.chart(app.state)
log("best chart rank", best)

-- 9) cancel a tour (laptop > tours)
planArtist("kai")
MOCK.prompt("maptable")
book("us", 1)
MOCK.clickExact("DONE: PRICES ON THE LAPTOP >")
pricesAndAnnounce(true)
local nTours = #app.state.tours
MOCK.clickExact("Cancel tour")
MOCK.clickExact("Yes")
log("tours after cancel", nTours, "->", #app.state.tours, "server", #SRV().tours)
assert(#SRV().tours == nTours - 1, "cancel did not reach the server")
MOCK.clickExact("CLOSE")

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
