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
local Laptop
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
-- the tutorial: Sam talks (click to go on), then sends you to the meeting room
steps(40, 0.05)
local bubble = app.canvas:FindFirstChild("TutorialBubble")
assert(bubble and #MOCK.texts("^SAM") == 1, "Sam talks")
local guide = workspace.StarlightRecords:FindFirstChild("Guide")
assert(guide, "Sam stands in the office")
local function talk(n) for _ = 1, n do bubble.MouseButton1Click:Fire() MOCK.runTasks() steps(2) end end
talk(14)
log("tutorial step", app.state.tutorial.step, "hint", MOCK.texts("MEETING ROOM")[1], "arrow", app.world.target)
assert(app.state.tutorial.step == 2 and app.world.target == "meeting", "first task: the meeting room, the arrow shows it")
steps(200, 0.05) -- Sam walks over (no teleport)
local gpos = guide.PrimaryPart.CFrame.Position
log("Sam waits at", gpos)
assert((Vector3.new(gpos.X, 0, gpos.Z) - (require(root.World.Hub).ORIGIN + require(root.World.Hub).GUIDE_SPOTS.meeting)).Magnitude < 1, "Sam waits at the meeting room")
MOCK.sit(workspace.StarlightRecords:FindFirstChild("MeetingSeat2", true))
steps(20)
talk(3)
MOCK.prompt("meeting")
steps(20)
talk(3)
log("tutorial step after the meeting", app.state.tutorial.step, SRV().tutorial.step)
assert(app.state.tutorial.step == 4, "next task: PLAN A TOUR")
MOCK.sit(nil)
steps(2)
MOCK.clickExact("Skip tutorial")
steps(2)
assert(SRV().tutorial.done and app.canvas:FindFirstChild("TutorialBubble") == nil and app.world.target == nil, "skip ends the tutorial, no arrow")
-- after the tutorial Sam walks to his own office and works at his desk
local Sam = require(root.Client.Sam)
local samWalked = false
for _ = 1, 400 do
	steps(1, 0.05)
	if Sam.walk then samWalked = true end
	if Sam.sitting and Sam.sitting.kind == "office" and Sam.sitting.t >= 1 then break end
end
local sp = guide.PrimaryPart.CFrame.Position - require(root.World.Hub).ORIGIN
log("Sam in his office", samWalked, Sam.sitting and Sam.sitting.kind, sp)
assert(samWalked and Sam.sitting and Sam.sitting.kind == "office" and (Vector3.new(sp.X, 0, sp.Z) - Vector3.new(33, 0, -42)).Magnitude < 0.5, "Sam walks to his office and sits at his desk")
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
-- laptop: power on -> login -> desktop with apps in windows
Laptop = require(root.Client.Laptop)
MOCK.prompt("laptop")
assert(app.mode == "laptop" and Laptop.isOpen(app), "the laptop opens")
steps(60, 0.05)
MOCK.clickExact("LOG IN")
assert(app.laptop.power == "on", "logged in")
local function dbl(id)
	local ic = app.laptop.iconLayer:FindFirstChild("Icon_" .. id)
	ic.MouseButton1Click:Fire() ic.MouseButton1Click:Fire() MOCK.runTasks()
end
dbl("tours")
assert(#app.laptop.windows == 1 and app.laptop.windows[1].id == "tours", "double click opens My Tours in a window")
local win = app.laptop.windows[1]
win.frame:FindFirstChild("Maximize", true).MouseButton1Click:Fire() MOCK.runTasks()
assert(win.max == false, "window restored from full screen")
dbl("stats")
assert(#app.laptop.windows == 2 and #MOCK.texts("^Statistics$") >= 1, "a second window: statistics")
app.laptop.windows[2].frame:FindFirstChild("Minimize", true).MouseButton1Click:Fire() MOCK.runTasks()
assert(not app.laptop.windows[2].frame.Visible, "minimised")
app.laptop.tasks:FindFirstChild("Task_stats").MouseButton1Click:Fire() MOCK.runTasks()
assert(app.laptop.windows[2].frame.Visible, "back from the taskbar")
dbl("settings")
for i = #app.laptop.windows, 1, -1 do app.laptop.windows[i].frame:FindFirstChild("CloseWindow", true).MouseButton1Click:Fire() MOCK.runTasks() end
assert(#app.laptop.windows == 0 and app.screens.tours.frame.Parent == app.content, "windows closed, pages back")
MOCK.clickExact("Close laptop")
assert(app.mode == "world", "close returns to walking")
local function openPlanner()
	MOCK.prompt("laptop")
	if app.laptop.power ~= "on" then steps(60, 0.05) MOCK.clickExact("LOG IN") end
	Laptop.openApp(app, "planner")
	assert(app.screens.planner.frame.Visible, "tour planner window")
end
-- the world map table: the shows of the plan
local function openMap()
	MOCK.prompt("maptable")
	local tp = app.screens.planner
	assert(app.current == "planner" and tp:place() == "maptable" and tp.step == 2, "the map table opens the shows step")
end
-- book a show: a country on the map -> SELECT on the n-th open venue -> first free day after the last show
local function book(cid, n)
	local tp = app.screens.planner
	if tp.step ~= 2 then tp:go(2) end
	tp.map.chips[cid].chip.MouseButton1Click:Fire() MOCK.runTasks()
	assert(tp.sub == "country" and tp.selected == cid, "country page after the click")
	local sel = MOCK.buttons("^SELECT$")
	local btn = ((n or 1) < 0) and sel[#sel] or sel[n or 1]
	assert(btn, "no SELECT button")
	btn.MouseButton1Click:Fire() MOCK.runTasks()
	assert(tp.picked and tp.overlay.Visible, "calendar after SELECT")
	local last = tp.draft.shows[#tp.draft.shows]
	local d = last and (last.day + 1) or (app.state.day + 21)
	while tp:dayState(d) ~= "ok" do d = d + 1 end
	local before = #tp.draft.shows
	tp:dayClicked(d)
	assert(#tp.draft.shows == before + 1, "day click did not add a show")
	MOCK.clickExact("Done")
	tp.sub = "map"
	tp:refresh()
end

-- the meeting room board: PLAN A TOUR for an artist (stands up, the laptop is next)
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
	assert(app.world.target == nil, "no arrow after the tutorial")
end
-- tickets -> stage -> announce (in the planner window)
local function pricesAndAnnounce()
	local tp = app.screens.planner
	tp:go(3)
	assert(tp.step == 3, "ticket step")
	MOCK.clickExact("+5", 1)
	MOCK.clickExact("Next: choose the stage  >")
	assert(SRV().draft.pricesSet and tp.step == 4, "prices saved, stage step")
	if #MOCK.buttons("^SELECT$") > 0 then MOCK.clickExact("SELECT", 1) end
	for _, need in ipairs(tp:classesNeeded()) do
		if not tp:chosenDesign(need.class) then tp.draft.designs[need.class] = tp:fittingDesigns(need.class)[1].id end
	end
	tp:saveDraft()
	tp:refresh()
	log("stage step selected", #MOCK.buttons("^SELECTED$"))
	MOCK.clickExact("Next: check & announce  >")
	assert(SRV().draft.stageSet and tp.step == 5, "stage set, announce step")
	MOCK.clickExact("ANNOUNCE TOUR")
end

-- 2) plan a tour: meeting room (PLAN A TOUR) -> laptop: Tour Planner (shows, tickets, stage, announce)
MOCK.prompt("maptable")
local tp = app.screens.planner
assert(app.current == "planner" and #MOCK.buttons("^Go to the MEETING ROOM") == 1, "no artist yet: the map table sends you to the meeting room")
MOCK.clickExact("Go to the MEETING ROOM  >")
assert(app.mode == "world", "back to walking")
-- Sam joins a meeting: he walks to the board in the meeting room
do
	local Sam = require(root.Client.Sam)
	MOCK.sit(workspace.StarlightRecords:FindFirstChild("MeetingSeat3", true))
	steps(2)
	MOCK.prompt("meeting")
	assert(app.mode == "meeting", "meeting")
	for _ = 1, 600 do
		steps(1, 0.05)
		if Sam.at == "board" then break end
	end
	log("Sam in the meeting", Sam.at)
	assert(Sam.at == "board", "Sam stands next to the board in the meeting")
	-- a click on an artist card: Sam says a few words about them
	local ask = app.world.boardGui:FindFirstChild("AskSam", true)
	ask.MouseButton1Click:Fire() MOCK.runTasks()
	log("Sam says", Sam.sayText)
	assert(Sam.bubble and Sam.sayText and #Sam.sayText > 30, "Sam talks about the artist")
	MOCK.sit(nil)
	steps(2)
	assert(app.mode == "world", "meeting over")
	steps(10, 0.05)
	assert(Sam.goal == "office", "Sam goes back to his office")
end
planArtist("lila")
openPlanner()
assert(#MOCK.buttons("^Go to the WORLD MAP table") == 1, "the laptop: book the shows at the map table first")
MOCK.clickExact("Go to the WORLD MAP table  >")
assert(app.mode == "world", "laptop closed")
openMap()
assert(tp.step == 2 and tp.draft.artistId == "lila", "map table: the shows")
assert(tp.map and tp.map.chips.uk and tp.map.chips.br, "the flat map has every country")
tp.map.chips.uk.chip.MouseButton1Click:Fire() MOCK.runTasks()
local locked = #MOCK.buttons("^LOCKED$")
log("uk venues: open", #MOCK.buttons("^SELECT$"), "locked", locked, "sections", #MOCK.texts("^CLUBS$"), #MOCK.texts("^STADIUMS$"))
assert(locked > 0 and #MOCK.buttons("^SELECT$") >= 1, "theatres/arenas locked at level 1")
MOCK.click("STADIUMS")
assert(tp.filter.Stadium == false and #MOCK.texts("^STADIUMS$") == 0, "filter hides the stadiums")
MOCK.clickExact("Show all")
MOCK.clickExact("< World map")
assert(tp.sub == "map", "back to the map")
book("uk", 1)
-- calendar
tp:openCalendar(tp.draft.shows[1].venueId)
local m0 = tp.calMonth[2]
MOCK.clickExact("<")
assert(tp.calMonth[2] ~= m0, "month navigation failed")
log("calendar month", MOCK.texts("^%a+ 20%d%d$")[1], "free days", #MOCK.texts("^free$"), "taken", #MOCK.texts("^taken:"))
local first = tp.draft.shows[1]
local d2 = first.day + 1
while tp:dayState(d2) ~= "ok" do d2 = d2 + 1 end
tp:dayClicked(d2)
assert(#tp.draft.shows == 2, "second night")
tp:dayClicked(d2)
assert(#tp.draft.shows == 1, "click on own show did not remove it")
MOCK.clickExact("Done")
for _, cid in ipairs({ "fr", "de", "nl" }) do book(cid, 1) end
log("draft shows", #tp.draft.shows)
for i = 2, #tp.draft.shows do assert(tp.draft.shows[i].day > tp.draft.shows[i - 1].day, "dates not sorted") end
assert(#SRV().draft.shows == #tp.draft.shows, "dates are on the server")
-- done at the map table: on to the laptop
MOCK.clickExact("Done: on to the LAPTOP  >")
assert(app.mode == "world", "map table closed")
-- the stage hall can select a stage for the plan too
MOCK.prompt("stagehall")
for _, d in ipairs(app.state.designs) do
	if d.class == "Club" then app.screens.stages:selectForTour(d) break end
end
MOCK.clickExact("CLOSE")
openPlanner()
pricesAndAnnounce()
local tour = app.state.tours[1]
assert(tour and app.laptop.windows[#app.laptop.windows].id == "tours", "My Tours opens after the announcement")
log("tour", tour.name, "#shows", #tour.shows, "price", tour.price, tour.shows[2].price, "presale sold", tour.shows[1].sold)
MOCK.click("^Social Ads")
MOCK.clickExact("+")
log("tour price after +", tour.price, tour.shows[3].price)
MOCK.clickExact("Close laptop")
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
-- "Our Artists" is an app on the laptop
app:go("artists")
assert(app.mode == "laptop" and app.screens.artists.frame.Visible, "artists open on the laptop")
MOCK.clickExact("Close laptop")

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
-- building has no side panel: the bar above the catalog shows the piece, "Style" opens its looks
local Designer3 = Designer.current
log("tool bar", MOCK.texts("^Stage Deck$")[1] or "none", "style box before", Designer3.root:FindFirstChild("StyleButton", true) ~= nil, #MOCK.buttons("^LED screen$"))
assert(#MOCK.buttons("^LED screen$") == 0, "the looks only open with Style")
MOCK.clickExact("Style")
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
-- the top handle makes the deck higher (in its height steps)
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
local h0 = selRec.h or 6
H.size.MouseButton1Down:Fire(Enum.NormalId.Top)
H.size.MouseDrag:Fire(Enum.NormalId.Top, 3.6)
H.size.MouseButton1Up:Fire(Enum.NormalId.Top)
log("deck height with the top handle", h0, "->", selRec.h)
assert(selRec.h == 10 and h0 == 6, "top handle sets the height")
-- the green arrow also points down
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
local yo0 = selRec.yo
H.moveY.MouseButton1Down:Fire(Enum.NormalId.Bottom)
H.moveY.MouseDrag:Fire(Enum.NormalId.Bottom, 2)
H.moveY.MouseButton1Up:Fire(Enum.NormalId.Bottom)
log("lowered deck yo", yo0, "->", selRec.yo)
assert(selRec.yo == yo0 - 2, "down arrow")
-- moving with an arrow goes straight along the arrow (no sideways slide), also for a turned piece
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
selRec.r = 30
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
Designer.current.render()
for _, r in ipairs(Stage3D.items) do if r.rec == selRec then Designer.current.select(r) end end
steps(2)
local ax0, az0 = selRec.x, selRec.z
local adir = H.moveX.Adornee.CFrame:VectorToWorldSpace(Vector3.new(1, 0, 0))
H.moveX.MouseButton1Down:Fire(Enum.NormalId.Right)
H.moveX.MouseDrag:Fire(Enum.NormalId.Right, 6.3)
H.moveX.MouseButton1Up:Fire(Enum.NormalId.Right)
local mdx, mdz = selRec.x - ax0, selRec.z - az0
log("turned deck moved", mdx, mdz)
assert(math.abs(mdx - adir.X * 6) < 0.05 and math.abs(mdz - adir.Z * 6) < 0.05, "a deck moves straight along its arrow, exactly in grid steps")
selRec.r = 0
Designer.current.render()
-- decks line up with the edges of decks next to them
do
	local def = StageItems.byId.deck
	local a = { t = "deck", x = 200, z = 300, r = 0, w = 20, d = 10 }
	table.insert(design.items, a)
	local test = { t = "deck", x = 200 + 10 + 5 + 0.9, z = 301, r = 0, w = 10, d = 10 }
	local x0 = test.x
	Designer.current.edgeSnap(test, def)
	table.remove(design.items, #design.items)
	log("edge snap", x0, "->", test.x, test.z)
	assert(math.abs(test.x - (x0 - 0.9)) < 0.01 and math.abs(test.z - 300) < 0.01, "a deck next to another one snaps flush to its edges")
end
-- a truss beam turned on purpose keeps its angle next to another beam
do
	local beam = nil
	for _, r in ipairs(Stage3D.items) do if r.kind == "truss_beam" then beam = r break end end
	local p = beam.cf.Position
	local _, _, rr = Stage3D.alignTruss(p.X + 2, p.Z + 3, ((beam.rec.r or 0) + 15) % 360, 24)
	log("turned beam keeps", rr, "beam", beam.rec.r)
	assert(math.abs(((rr - (beam.rec.r or 0)) % 360) - 15) < 0.01, "R turns a truss beam")
end
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
MOCK.clickExact("2  SETLIST & SHOW")
log("phase show, catalog visible", Designer.current.panels[3].Visible, "artist path pieces", Designer.current.artistPathCount())
assert(Designer.current.artistPathCount() > 0, "step 2 shows the way of the artist")
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then Designer.current.select(r) break end end
MOCK.clickExact("Live: artist")
MOCK.clickExact("+", 1) -- "For": song 1
MOCK.clickExact("Live: fans")
MOCK.clickExact("-", 1) -- back to the whole show
MOCK.clickExact("Tour visuals")
local ledRec, pillar = nil, nil
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then ledRec = r.rec end end
log("tour visuals", ledRec.scr.default.m)
assert(ledRec.scr.default.m == "visuals", "tour visuals mode")
MOCK.clickExact("Copy to chosen screens...")
for _, r in ipairs(Stage3D.items) do if r.kind == "ledpillar" then pillar = r end end
Designer.current.copyPickToggle(pillar)
MOCK.clickExact("Finish (1)")
log("copied to chosen screen", pillar.rec.scr and pillar.rec.scr.default.m)
assert(pillar.rec.scr.default.m == "visuals", "copy to chosen screens")
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then Designer.current.select(r) break end end
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then log("screen config", r.rec.scr.default.m, r.rec.scr["1"] and r.rec.scr["1"].m) break end end
for _, r in ipairs(Stage3D.items) do if r.kind == "piano" then Designer.current.select(r) break end end
-- the instrument is set up in the setlist on the left (no panel on the right)
MOCK.clickExact(">", 1)
local pl = nil
for _, rec in ipairs(design.items) do if rec.t == "piano" then pl = rec.play end end
log("piano plays in song", pl)
assert(pl == 1, "piano song set in the setlist box")
MOCK.clickExact("Crew sets it up")
for _, rec in ipairs(design.items) do if rec.t == "piano" then assert(rec.setup == "crew", "crew setup from the setlist box") rec.setup = nil end end
-- a screen set up for one song: only that song's spots show on the stage
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then Designer.current.select(r) break end end
MOCK.clickExact("+", 1)
local shown, hidden = 0, 0
for _, r in ipairs(Stage3D.items) do if r.kind == "spot" then if r.marker.Transparency < 1 then shown = shown + 1 else hidden = hidden + 1 end end end
log("spots for song 1: shown", shown, "hidden", hidden, "focus", Designer.current.focusSong())
assert(Designer.current.focusSong() == 1 and (hidden > 0 or shown == 0), "only the spots of the chosen song")
Designer.current.select(nil)
for _, r in ipairs(Stage3D.items) do if r.kind == "spot" then assert(r.marker.Transparency == 0, "all spots back") end end
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
MOCK.clickExact("1  BUILD")
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
	-- R takes it round the tower to the next side
	for _, r in ipairs(Stage3D.items) do if r.rec == sw then Designer.current.select(r) end end
	key(Enum.KeyCode.R)
	log("side wash after R", sw.x, sw.z, sw.r)
	assert(sw.r ~= 90 and math.abs(sw.x - 60) < 0.1 and math.abs(math.abs(sw.z + 18) - 1.05) < 0.1, "R moves a side mount round the tower")
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
-- undo: Ctrl + Z takes the last change back
do
	steps(12)
	local nU = #design.items
	MOCK.clickExact("Decor")
	MOCK.clickExact("Hedge")
	MOCK.mouse = Vector2.new(930, 520)
	steps(2)
	key(Enum.KeyCode.Q)
	steps(12)
	log("before undo", nU, "->", #design.items)
	assert(#design.items == nU + 1, "placed for the undo test")
	MOCK.keys = { [Enum.KeyCode.LeftControl] = true }
	key(Enum.KeyCode.Z)
	MOCK.keys = {}
	steps(2)
	log("after undo", #design.items)
	assert(#design.items == nU, "Ctrl + Z takes the piece back")
	key(Enum.KeyCode.F)
	key(Enum.KeyCode.F)
end
-- the LED cube hangs on cables from the roof (longer when it hangs lower)
do
	local Builder = require(root.Client.Builder)
	local hi = Builder.build(StageItems.byId.ledcube, { rec = { t = "ledcube", yo = 0 } })
	local lo = Builder.build(StageItems.byId.ledcube, { rec = { t = "ledcube", yo = -10 } })
	local free = Builder.build(StageItems.byId.ledcube, { rec = { t = "ledcube", yo = -10, roof = false } })
	log("cube cables", #hi.cables, hi.cables[1][1].Size.Y, lo.cables[1][1].Size.Y, #free.cables)
	assert(#hi.cables == 4 and lo.cables[1][1].Size.Y > hi.cables[1][1].Size.Y + 9 and #free.cables == 0, "LED cube: connect to roof")
	hi.model:Destroy() lo.model:Destroy() free.model:Destroy()
end
-- an accidental click never moves a new piece (only the arrows do)
MOCK.clickExact("Decor")
MOCK.clickExact("Planter Box")
MOCK.mouse = Vector2.new(900, 520)
steps(2)
click3D()
local pend = Designer.current.target()
local px, pz = pend.rec.x, pend.rec.z
MOCK.mouse = Vector2.new(1100, 600)
steps(2)
click3D()
log("pending after a second click", px, "->", pend.rec.x, pz, "->", pend.rec.z)
assert(pend.rec.x == px and pend.rec.z == pz, "a click must not move the new piece")
key(Enum.KeyCode.F)
key(Enum.KeyCode.F)
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
MOCK.clickExact("2  SETLIST & SHOW")
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
MOCK.clickExact("1  BUILD")
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
MOCK.clickExact("Preview show")
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
log("band musicians in the preview", LiveShow.lastBand)
assert(LiveShow.lastBand >= 5, "every Band item gets a musician")
local barriers = 0
for _, d in ipairs(workspace:GetDescendants()) do if d.Name == "Barrier" then barriers = barriers + 1 end end
-- a lift in the last song is the exit: the artist goes down with it at the end; curtain opens in song 2
do
	local exitDesign = { id = "exit_test", name = "Exit", class = "Arena", layout = "end", items = {
		{ t = "deck", x = 0, z = -14, r = 0, w = 40, d = 20, h = 6 },
		{ t = "spot", x = -6, z = -10, r = 0 }, { t = "spot", x = 6, z = -10, r = 0 },
		{ t = "lift", x = 0, z = -12, r = 0, play = 3 },
		{ t = "curtain", x = 0, z = -2, r = 0, w = 40, d = 24, anim = "split", cs = 2, cc = "gold" },
	} }
	local doneExit = false
	LiveShow.run(app, { artistId = app.state.tours[1] and app.state.tours[1].artistId or "lila", design = exitDesign, look = "arena", cap = 1000, sold = 900, tourName = "Exit", preview = true, onDone = function() doneExit = true end })
	log("exit lift", LiveShow.lastExitLift and LiveShow.lastExitLift.kind or "none")
	assert(LiveShow.lastExitLift ~= nil, "a lift in the last song is the exit lift")
	MOCK.click("^Speed") MOCK.click("^Speed")
	local f = 0
	while not doneExit and f < 6000 do MOCK.step(1 / 30) f = f + 1 end
	assert(doneExit, "exit-lift preview did not finish")
	for _ = 1, 10 do MOCK.step(1 / 30) end
end
-- the crew sets up the acoustic set before its song and takes it away after it
do
	local crewDesign = { id = "crew_test", name = "Crew", class = "Arena", layout = "end", items = {
		{ t = "deck", x = 0, z = -14, r = 0, w = 60, d = 24, h = 6 },
		{ t = "spot", x = -10, z = -10, r = 0 }, { t = "spot", x = 10, z = -10, r = 0 },
		{ t = "acoustic", x = 0, z = -12, r = 0, play = 2, setup = "crew" },
	} }
	local doneC = false
	LiveShow.run(app, { artistId = "lila", design = crewDesign, look = "arena", cap = 1000, sold = 900, tourName = "Crew", preview = true, onDone = function() doneC = true end })
	local job = LiveShow.lastSetups[1]
	assert(job and #job.parts > 5, "a crew job for the acoustic set")
	-- the guitar itself leaves the stand while the artist strums it, so it does not count
	local inHands = { Body = true, SoundHole = true, Bridge = true, Neck = true, Headstock = true }
	local function shownNow(hands) local n = 0 for _, e in ipairs(job.parts) do if e[1].Transparency < 1 or (hands and inHands[e[1].Name]) then n = n + 1 end end return n end
	MOCK.click("^Speed") MOCK.click("^Speed")
	local seen = { before = nil, during = nil, hands = false, after = nil }
	local f = 0
	local LS = LiveShow
	while not doneC and f < 9000 do
		MOCK.step(1 / 30)
		f = f + 1
		local t = LS.debugT and LS.debugT() or nil
		if t then
			if t < job.tIn - 0.5 and seen.before == nil then seen.before = shownNow() end
			if t > job.tIn + job.total + 0.5 and t < job.tOut - 0.5 then seen.during = shownNow(true) end
			if t > job.tIn + 0.5 and t < job.tIn + job.total - 0.5 then
				for _, h in ipairs(job.hands) do if h.p.visible then seen.hands = true end end
				-- coming in from a side of the stage (not from the back wall), fading in
				local h1 = job.hands[1]
				if t < job.tIn + 0.2 * job.walk then seen.fadeIn = (h1.p.fade or 0) > 0.2 end
			end
			if t > job.tOut + job.total + 0.5 then seen.after = shownNow() end
		end
	end
	log("crew set-up: before", seen.before, "during", seen.during, "of", #job.parts, "crew seen", seen.hands, "after", seen.after, "from x", job.hands[1].way[1].X, job.hands[2].way[1].X, "fade in", seen.fadeIn)
	assert(job.hands[1].way[1].X < -10 and job.hands[2].way[1].X > 10, "the stage hands come from both sides")
	assert(doneC and seen.before == 0 and seen.during == #job.parts and seen.hands and seen.after == 0, "the crew sets the acoustic set up and takes it away")
	for _ = 1, 10 do MOCK.step(1 / 30) end
end
-- a group (STARLYTE, K-Pop): the other members dance on their own on the decks; a "2.5" spot (a moment in song 2)
do
	local grpDesign = { id = "group_test", name = "Group", class = "Arena", layout = "end", items = {
		{ t = "deck", x = 0, z = -14, r = 0, w = 60, d = 24, h = 6 },
		{ t = "spot", x = -10, z = -10, r = 0 }, { t = "spot", x = 10, z = -10, r = 0 }, { t = "spot", x = 0, z = -6, r = 0 },
		{ t = "spot", x = 14, z = -18, r = 0, song = 2, mid = 0.5 },
	} }
	local plan = GS.songPlan(grpDesign)
	log("group design songs", plan.count, "moment", plan.momentOf[grpDesign.items[5]])
	assert(plan.count == 3 and plan.momentOf[grpDesign.items[5]] == 2.5, "a moment spot does not add a song")
	local doneG = false
	LiveShow.run(app, { artistId = "starlyte", design = grpDesign, look = "arena", cap = 1000, sold = 900, tourName = "Group", preview = true, onDone = function() doneG = true end })
	local crew = LiveShow.lastCrew
	assert(#crew == 4, "STARLYTE: the 4 other members dance on their own")
	local moment = false
	for _, w in ipairs(LiveShow.lastWalks) do if w.moment then moment = true end end
	assert(moment, "the artist walks to the 2.5 spot during song 2")
	MOCK.click("^Speed") MOCK.click("^Speed")
	local f, off, movesSeen, walked, apart = 0, 0, {}, false, 0
	while not doneG and f < 8000 do
		MOCK.step(1 / 30)
		f = f + 1
		-- (only while the stage still stands: at the very end the show clears the world)
		if f % 15 == 0 and Stage3D.surfaceY(0, -14) > 0.5 then
			for _, c in ipairs(crew) do
				movesSeen[c.move or "?"] = true
				if c.move == "walk" then walked = true end
				if Stage3D.surfaceY(c.pos.X, c.pos.Z) < 0.5 then off = off + 1 end
			end
			for a = 1, #crew do
				for b = a + 1, #crew do
					if (crew[a].pos - crew[b].pos).Magnitude < 1.5 then apart = apart + 1 end
				end
			end
		end
	end
	local nm = 0
	for _ in pairs(movesSeen) do nm = nm + 1 end
	log("group show: different moves", nm, "walked", walked, "off the decks", off, "too close", apart)
	assert(doneG and walked and nm >= 6 and off == 0, "dancers walk on the decks and dance many different moves")
	for _ = 1, 10 do MOCK.step(1 / 30) end
end
-- back to the library: copy and delete
if app.mode ~= "designer" then app:openDesigner(design.id) end
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
MOCK.clickExact("Yes, I'm sure")
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
	MOCK.clickExact("Preview show")
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


-- 6b) own office: the door plate shows the label name, the laptop of the other offices is off, the LIVE SHOWS board
do
	local Hub = require(root.World.Hub)
	assert(MOCK.player:GetAttribute("Office") == 1 and Hub.myOffice == 1, "the player has office 1")
	local plateText, others = nil, 0
	for _, d in ipairs(workspace.StarlightRecords:GetDescendants()) do
		if d.Name == "OfficeName" and d:GetAttribute("Office") == 1 then
			plateText = d.OfficeNameSign:FindFirstChildOfClass("TextLabel").Text
		end
		if d:IsA("ProximityPrompt") and d:GetAttribute("Office") and d:GetAttribute("Office") ~= 1 and not d.Enabled then
			others = others + 1
		end
	end
	log("office plate", plateText, "other laptops off", others)
	assert(plateText == string.upper(app.state.labelName) and others == 4, "door plate + only your own laptop")
	MOCK.clickExact("CLOSE")
	app.world.trigger("liveboard")
	assert(app.current == "liveshows" and app.screens.liveshows.frame.Visible, "LIVE SHOWS board opens")
	log("live shows of other labels", #(app.screens.liveshows.shows or {}))
	app:closeScreen()
end

-- 7) phone + laptop pages
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
cheat(function(s)
	s.money = 60000000 s.stats.tickets = 4000000
	local GSx = require(root.Logic.GameState)
	local busy, d = GSx.artistBusy(s, "nova")
	if busy then s.day = s.day + d end
end)
log("sign nova", app:act("sign", { artistId = "nova" }))
clearModals()
planArtist("nova")
openMap()
book("uk", -1) -- the last (biggest) venue: the stadium
book("uk", 1) -- and a club: needs a smaller stage too
log("nova draft", #tp.draft.shows, tp.draft.artistId)
MOCK.clickExact("Done: on to the LAPTOP  >")
openPlanner()
assert(tp.step == 3, "laptop: tickets for nova")
pricesAndAnnounce()
local nt = app.state.tours[1]
log("nova tour", nt.name, nt.shows[1].venueId, nt.shows[1].sold)
MOCK.clickExact("Close laptop")
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
openMap()
book("us", 1)
MOCK.clickExact("Done: on to the LAPTOP  >")
openPlanner()
pricesAndAnnounce()
local nTours = #app.state.tours
MOCK.clickExact("Cancel tour")
MOCK.clickExact("Yes")
log("tours after cancel", nTours, "->", #app.state.tours, "server", #SRV().tours)
assert(#SRV().tours == nTours - 1, "cancel did not reach the server")
MOCK.clickExact("Close laptop")

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
MOCK.clickExact("PLAY")
assert(app2.mode == "world", "continue did not enter the building")
log("second session money", app2.state.money, "was", money)
assert(app2.state.money == money and #app2.state.tours == #SRV().tours, "loaded game differs")
-- home menu: save, then back to the main menu, a new label in slot 2, back again, delete slot 2
steps(5)
app2:openHome()
MOCK.clickExact("Save game")
app2:openHome()
MOCK.clickExact("Back to main menu")
MOCK.clickExact("Yes")
steps(3)
assert(app2.mode == "title" and app2.state == nil, "back to the main menu")
log("canvas children after leaving", #app2.canvas:GetChildren())
MOCK.clickExact("NEW GAME", 1) -- the first empty slot (2)
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 1)
steps(40, 0.05)
MOCK.clickExact("Skip tutorial")
assert(app2.state and app2.slot == "2" and app2.mode == "world", "new game in slot 2")
app2:call("save")
assert(MOCK.store.data["player_1_slot2"] ~= nil, "slot 2 saved under its own key")
app2:leaveToMenu()
local labels = MOCK.texts("^PLAY$")
log("slots with a game", #labels)
assert(#labels == 2, "two slots in use")
MOCK.clickExact("Delete", 2)
MOCK.clickExact("Yes")
assert(#MOCK.texts("^PLAY$") == 1 and MOCK.store.data["player_1_slot2"] == nil, "slot 2 deleted")
app2.gui:Destroy()

-- 11) developer sandbox: unlimited money, everything open, own save
task.spawn(function() App.start() end)
MOCK.runTasks()
local app3 = App.instance
MOCK.click("^SANDBOX")
MOCK.click("^NEW SANDBOX", 1)
assert(#MOCK.texts("^SAM") == 0, "no tutorial in the sandbox")
assert(app3.state.sandbox and app3.state.money >= 1000000000, "sandbox money")
assert(GS.level(app3.state) == #require(root.Config).LEVELS, "sandbox: every level")
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
