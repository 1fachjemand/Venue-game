-- Builder: new decks land on the stage they are completely on, stairs turn to the deck next to them and
-- take its height, small pieces at a deck edge stand on the deck, a lift can be used twice.
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local server = MOCK.newRaw("Script")
server.__props.Name = "GameServer"
rawset(server, "__path", SERVER_PATH)
MOCK.runScript(server)
MOCK.runTasks()
game:GetService("Players").PlayerAdded:Fire(MOCK.player)
MOCK.runTasks()
local main = MOCK.newRaw("LocalScript")
main.__props.Name = "Main"
rawset(main, "__path", MAIN_PATH)
MOCK.runScript(main)
MOCK.runTasks()
local App = require(root.Client.App)
local GS = require(root.Logic.GameState)
local Designer = require(root.Client.Designer)
local app = App.instance
local UIS = game:GetService("UserInputService")
MOCK.clickExact("NEW GAME")
MOCK.clickExact("NEXT >")
MOCK.clickExact("SIGN", 3)
for _ = 1, 40 do MOCK.step(0.05) end
MOCK.clickExact("Skip tutorial")
local function steps(n) for _ = 1, n do MOCK.step(1 / 30) end end
local function key(k) UIS.InputBegan:Fire(MOCK.input(Enum.UserInputType.Keyboard, { KeyCode = k }), false) MOCK.runTasks() end
local function log(...) print("[fit]", ...) end
local oldToast = app.toast
app.toast = function(self, msg, ...) print("[fit] toast:", msg) return oldToast(self, msg, ...) end
app.state.money = 90000000
-- the mock camera ray always crosses (x, 6, -10): it hits the ground at z = -17.9 and a 6 high deck at z = -10
local d = GS.addDesign(app.state, "Fit", {
	{ t = "deck", x = 0, z = -10, w = 60, d = 30, h = 6, y = 0 },
	{ t = "deck", x = 60, z = -33, w = 30, d = 20, h = 6, y = 0 },
	{ t = "lift", x = -20, z = -10, play = 1, play2 = 6, y = 6 },
}, "Arena", "end")
app:openDesigner(d.id)
steps(3)
local function place(cat, name, mx)
	MOCK.clickExact(cat)
	MOCK.clickExact(name)
	MOCK.mouse = Vector2.new(mx, 520)
	steps(2)
	local n = #d.items
	key(Enum.KeyCode.Q) -- put down
	key(Enum.KeyCode.Q) -- buy
	steps(2)
	assert(#d.items == n + 1, "placed " .. name)
	return d.items[#d.items]
end
-- a small deck on the big one goes on top of it
local small = place("Stage", "Stage Deck", 960)
log("small deck on the stage", small.x, small.z, small.y)
assert(math.abs((small.y or 0) - 6) < 0.01, "a deck completely on a stage stands on top of it")
-- stairs in front of the other deck (ground at z -17.9, the deck ends at z -23): they turn to it and grow to 6
local st = place("Stage", "Stairs", 960 + 560)
log("stairs", st.x, st.z, st.r, st.h, st.y)
assert(math.abs((st.h or 0) - 6) < 0.05 and (st.r or 0) % 360 == 0 and math.abs(st.y or 0) < 0.01, "stairs fit the deck behind them")
-- a light on the big deck stands on the deck
local p = place("Lights", "Beam Light", 960 + 250)
log("beam light on the deck", p.x, p.y)
assert((p.y or 0) > 5.9, "a light on a deck stands on the deck")
-- the lift used twice
local plan = GS.songPlan(d)
local lift = d.items[3]
log("lift songs", plan.songOf[lift], plan.againOf[lift], plan.place[6] == lift)
assert(plan.songOf[lift] == 1 and plan.againOf[lift] == 6 and plan.place[6] == lift, "a lift has a second song")
MOCK.clickExact("DONE")
print("[fit] OK")
