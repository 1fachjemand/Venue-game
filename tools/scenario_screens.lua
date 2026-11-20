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
for _ = 1, 80 do MOCK.step(0.05) end
for _ = 1, 40 do MOCK.step(0.05) end MOCK.clickExact("Skip tutorial")
dump("04b_world_hud")
App.instance:openHome()
dump("04b2_home_menu")
MOCK.clickExact("Back to main menu")
dump("04b3_home_confirm")
MOCK.clickExact("Cancel")
local Laptop = require(root.Client.Laptop)
MOCK.prompt("laptop")
dump("04c_laptop_boot")
for _ = 1, 40 do MOCK.step(0.05) end
dump("04d_laptop_login")
MOCK.clickExact("LOG IN")
dump("04e_desktop")
Laptop.openApp(app, "stats")
Laptop.openApp(app, "tours")
app.laptop.windows[2].max = false
app.laptop.windows[2].rect = { x = 300, y = 120, w = 1200, h = 720 }
Laptop.layout(app, app.laptop.windows[2])
dump("04f_two_windows")
for i = #app.laptop.windows, 1, -1 do Laptop.closeWindow(app, app.laptop.windows[i]) end
MOCK.clickExact("Close laptop")
MOCK.prompt("maptable")
dump("05a_plan_artist")
MOCK.clickExact("CLOSE")
SRV().money = 5000000 SRV().stats.tickets = 250000 app:applyDelta(app:call("resync").delta)
app:act("setDraft", { draft = { artistId = "juno" } })
MOCK.prompt("maptable")
local tp = app.screens.planner
dump("05_plan_map")
tp.map:setHover("de")
tp.map:zoomAt(2.5, 700, 200)
dump("05b_plan_map_zoom")
local function book(cid, n)
	tp.selected, tp.sub = cid, "country"
	tp:refresh()
	local sel = MOCK.buttons("^SELECT$")
	local b = (n < 0) and sel[#sel] or sel[n]
	b.MouseButton1Click:Fire() MOCK.runTasks()
	local last = tp.draft.shows[#tp.draft.shows]
	local d = last and (last.day + 1) or (app.state.day + 21)
	while tp:dayState(d) ~= "ok" do d = d + 1 end
	tp:dayClicked(d)
end
tp.selected, tp.sub = "uk", "country"
tp:refresh()
dump("06_plan_venues")
book("uk", 1)
dump("06b_calendar")
MOCK.clickExact("Done")
book("fr", 1)
MOCK.clickExact("Done")
book("de", 1)
MOCK.clickExact("Done")
tp.sub = "map" tp:refresh()
dump("06c_plan_map_route")
MOCK.clickExact("Done: on to the LAPTOP  >")
MOCK.prompt("laptop")
Laptop.openApp(app, "planner")
dump("07b_plan_tickets")
MOCK.clickExact("Next: choose the stage  >")
dump("07c_plan_stage")
for _, need in ipairs(tp:classesNeeded()) do tp.draft.designs[need.class] = tp:fittingDesigns(need.class)[1].id end
tp:saveDraft()
tp:refresh()
MOCK.clickExact("Next: check & announce  >")
dump("08_plan_announce")
MOCK.clickExact("ANNOUNCE TOUR")
for _ = 1, 6 do
	app:nextDay()
	if #MOCK.buttons("^Nice!$") > 0 then MOCK.clickExact("Nice!") end
end
dump("09_tours")
MOCK.clickExact("Close laptop")
dump("11b_world_after")
local seat = workspace.StarlightRecords:FindFirstChild("MeetingSeat1", true)
MOCK.sit(seat)
for _ = 1, 3 do MOCK.step(1 / 30) end
MOCK.prompt("meeting")
dump("10_meeting_hud")
WRITE(OUT_DIR .. "/10b_meeting_board.html", MOCK.renderHTML(app.world.boardGui, "board"))
MOCK.sit(nil)
for _ = 1, 3 do MOCK.step(1 / 30) end
app:openPhone()
dump("12_phone_feed")
MOCK.clickExact("FAN MOOD")
dump("12b_phone_mood")
MOCK.clickExact("X")
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
-- a placed deck: the small bar above the catalog, its looks open with "Style"
for _, r in ipairs(Stage3D.items) do if r.def.deck then require(root.Client.Designer).current.select(r) break end end
MOCK.runTasks()
dump("15b_designer_selected")
MOCK.clickExact("Style")
dump("15c_designer_style")
MOCK.clickExact("2  SETLIST & SHOW")
for _, r in ipairs(Stage3D.items) do if r.kind == "led" then require(root.Client.Designer).current.select(r) break end end
dump("16_designer_show")
MOCK.clickExact("DONE")
for _ = 1, 30 do MOCK.step(0.05) end
if app.mode == "menu" then MOCK.clickExact("CLOSE") end
do
	local t = app.state.tours[1]
	SRV().day = t.shows[1].day app:applyDelta(app:call("resync").delta)
	app:showTonight(t, 1)
	dump("17_tonight")
	MOCK.clickExact("Skip show")
	dump("18_show_report")
	MOCK.clickExact("Continue")
end
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
