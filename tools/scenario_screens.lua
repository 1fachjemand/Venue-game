math.randomseed(3)
dofile(RENDER_LUA)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local server = MOCK.newRaw("Script")
server.__props.Name = "GameServer"
rawset(server, "__path", SERVER_PATH)
MOCK.runScript(server)
MOCK.runTasks()
game:GetService("Players").PlayerAdded:Fire(MOCK.player)
MOCK.runTasks()
local function SRV() return shared.HeadlinerServer.sessions[MOCK.player].state end
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local App = require(root.Client.App)
local app = App.instance
local function dump(name) WRITE(OUT_DIR .. "/" .. name .. ".html", MOCK.renderHTML(app.gui, name)) end
dump("01_title")
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
dump("03_starter")
MOCK.clickExact("SIGN", 2)
dump("04_welcome")
MOCK.clickExact("Let's go!")
dump("04b_world_hud")
MOCK.prompt("laptop")
dump("04c_laptop")
MOCK.clickExact("✕  CLOSE")
MOCK.prompt("maptable")
dump("05_plan_artist")
MOCK.clickExact("SELECT")
local map = app.screens.planner
local function book(n)
	map.picked = nil map:refresh()
	MOCK.click("^PICK$", n)
	local last = map.draft.shows[#map.draft.shows]
	local d = last and last.day or (app.state.day + 21)
	while map:dayState(d) ~= "ok" do d = d + 1 end
	map:dayClicked(d)
end
dump("06a_plan_empty")
for _, cid in ipairs({ "uk", "fr", "de" }) do map.selected = cid map:refresh() book(1) end
map.selected = "de" map:refresh() book(1)
map.selected = "uk" map:refresh()
MOCK.click("^ARENAS") book(1)
SRV().money = 5000000 SRV().stats.tickets = 250000 app:applyDelta(app:call("resync").delta)
map.picked = nil map:refresh()
dump("06_plan_route")
map.selected = "fr" map:refresh()
MOCK.click("^PICK$", 2)
dump("06b_calendar")
MOCK.clickExact("NEXT: STAGE >")
dump("07_plan_stage")
if #MOCK.buttons("^BUILD ARENA STAGE$") > 0 then
	local GS = require(root.Logic.GameState)
	local SI = require(root.Data.StageItems)
	app:act("newDesign", { preset = "Portal Ring" })
	map:refresh()
end
MOCK.clickExact("STAGE READY - NEXT: TICKETS >")
MOCK.clickExact("ARENAS")
dump("07b_plan_tickets")
MOCK.clickExact("NEXT: CONFIRM >")
dump("08_plan_confirm")
MOCK.clickExact("ANNOUNCE TOUR")
for _ = 1, 6 do
	app:nextDay()
	if #MOCK.buttons("^Nice!$") > 0 then MOCK.clickExact("Nice!") end
end
dump("09_tours")
MOCK.clickExact("OVERVIEW")
dump("11_office_after")
MOCK.clickExact("✕  CLOSE")
dump("11b_world_after")
local seat = workspace.StarlightRecords:FindFirstChild("MeetingSeat1", true)
MOCK.sit(seat)
for _ = 1, 3 do MOCK.step(1 / 30) end
MOCK.prompt("meeting")
MOCK.clickExact("TALENT SCOUT")
dump("10_scout")
MOCK.clickExact("✕  CLOSE")
app:openPhone()
dump("12_social")
MOCK.clickExact("✕  CLOSE")
SRV().stats.shows = 1 app:applyDelta(app:call("resync").delta) app:refreshCurrent()
MOCK.prompt("stagehall")
dump("13_stages")
MOCK.clickExact("+  NEW STAGE")
MOCK.clickExact("CENTER STAGE")
dump("14_new_stage")
MOCK.clickExact("Cancel")
MOCK.clickExact("EDIT", 2)
MOCK.clickExact("Stage Deck")
MOCK.mouse = Vector2.new(900, 500)
for _ = 1, 3 do MOCK.step(1 / 30) end
game:GetService("UserInputService").InputBegan:Fire(MOCK.input(Enum.UserInputType.MouseButton1), false)
MOCK.runTasks()
dump("15_designer_pending")
MOCK.clickExact("Screens")
MOCK.click("PLACE", 1)
local Stage3D = require(root.Client.Stage3D)
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then require(root.Client.Designer).current.select(r) break end end
dump("16_designer_screen")
print("dumped")
-- tour report with made-up results
do
	local t = app.state.tours[1]
	for i, s in ipairs(t.shows) do
		s.done = true
		local sold = math.floor(s.cap * (0.55 + 0.1 * i))
		s.result = { sold = math.min(sold, s.cap), cap = s.cap, gross = math.min(sold, s.cap) * s.price, rent = 2000 + i * 500, production = 3000, travel = 1500 * i, artistCut = math.floor(math.min(sold, s.cap) * s.price * 0.35), stars = 3 + i % 3, rating = 70 + i * 4 }
		s.result.net = s.result.gross - s.result.rent - s.result.production - s.result.travel - s.result.artistCut
		t.played = i
	end
	app:tourReport(t, true)
	dump("20_report")
end
