math.randomseed(3)
dofile(RENDER_LUA)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
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
MOCK.clickExact("Let's go!")
dump("04_office")
MOCK.clickExact("+ PLAN A TOUR")
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
app.state.money = 5000000
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
	for _, p in ipairs(SI.PRESETS) do if p.name == "Portal Ring" then GS.addDesignFromTemplate(app.state, p) end end
	map:refresh()
end
MOCK.clickExact("STAGE READY - NEXT: TICKETS >")
MOCK.clickExact("ARENAS")
dump("07b_plan_tickets")
MOCK.clickExact("NEXT: CONFIRM >")
dump("08_plan_confirm")
MOCK.clickExact("ANNOUNCE TOUR")
for _ = 1, 6 do app:nextDay() end
dump("09_tours")
MOCK.clickExact("ARTISTS")
MOCK.clickExact("TALENT SCOUT")
dump("10_scout")
MOCK.clickExact("OFFICE")
dump("11_office_after")
MOCK.clickExact("SOCIAL")
dump("12_social")
MOCK.clickExact("STAGES")
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
