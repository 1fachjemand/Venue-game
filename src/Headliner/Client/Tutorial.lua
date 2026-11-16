-- The tutorial: Sam, the label manager, walks you through your first tour and your first stage.
-- A speech bubble at the bottom: click to go on. When you have to do something, the bubble gets small,
-- shows what to do, and the golden arrow shows the way. Skip any time; the progress is saved
-- (state.tutorial, action "tutorial").
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Root = script:FindFirstAncestor("Headliner")
local Artists = require(Root.Data.Artists)
local UI = require(Root.Client.UI)
local Hub = require(Root.World.Hub)
local SoundFX = require(Root.Client.SoundFX)

local T = UI.Theme
local New = UI.New
local Tutorial = {}

local O = Hub.ORIGIN

local function laptopWindow(app, id)
	local lt = app.laptop
	for _, w in ipairs((lt and lt.windows) or {}) do
		if w.id == id and not w.min then
			return true
		end
	end
	return false
end
local function itemCount(app)
	local D = require(Root.Client.Designer)
	return (D.current and D.current.design and #D.current.design.items) or 0
end

-- the steps: what Sam says (lines), where Sam waits (at), where the arrow points (target),
-- what you have to do (hint, done = check)
Tutorial.STEPS = {
	{
		at = "start",
		lines = function(app)
			return {
				"Hey, welcome to <b>HEADLINER</b>!",
				"I'm Sam, I run the office here at <b>" .. UI.esc(app.state.labelName) .. "</b>.",
				"You always wanted your own record label. Now it's real: you sign artists, book their tours and build their stages.",
				"Let's plan your first tour together. Follow me!",
			}
		end,
	},
	{
		at = "meeting",
		target = "meeting",
		lines = { "First stop: the <b>meeting room</b>. This is where we meet our artists." },
		hint = "Go to the MEETING ROOM and sit down on a chair.",
		done = function(app)
			return app.world and (app.world.inMeetingSeat() or app.mode == "meeting")
		end,
	},
	{
		at = "meeting",
		lines = { "Press <b>E</b> to start the meeting. The board shows your artists and new talent." },
		hint = "Press E to start the meeting.",
		done = function(app)
			return app.mode == "meeting" or (app.state.draft or {}).artistId ~= nil
		end,
	},
	{
		at = "meeting",
		lines = function(app)
			local ad = nil
			for _, a in ipairs(Artists.list) do
				if app.state.artists[a.id].signed then
					ad = ad or a
				end
			end
			return { "That's <b>" .. (ad and ad.name or "your artist") .. "</b>, your first artist. Press <b>PLAN A TOUR</b> on the card." }
		end,
		hint = "Press PLAN A TOUR on the board.",
		done = function(app)
			return (app.state.draft or {}).artistId ~= nil
		end,
	},
	{
		at = "maptable",
		target = "maptable",
		lines = { "The shows are booked at the big <b>world map</b> table. Follow me!" },
		hint = "Walk to the WORLD MAP table and press E.",
		done = function(app)
			return app.station == "maptable" or #((app.state.draft or {}).shows or {}) > 0
		end,
	},
	{
		at = "maptable",
		lines = { "Click a <b>country</b> on the map, SELECT a <b>club</b> and pick a <b>date</b>. Start small: clubs sell out!" },
		hint = "Click a country, SELECT a club, pick a date, press Done.",
		done = function(app)
			return #((app.state.draft or {}).shows or {}) > 0 and not (app.screens.planner and app.screens.planner.overlay.Visible)
		end,
	},
	{
		at = "laptop",
		target = "laptop",
		lines = { "Booked! Tickets, the stage and the announcement are done on the <b>laptop</b>. Press <b>Done</b> and come to my desk." },
		hint = "Press Done, walk to the LAPTOP and press E.",
		done = function(app)
			return app.mode == "laptop"
		end,
	},
	{
		at = "laptop",
		lines = { "Your own computer. Log in, then <b>double-click the Tour Planner</b>." },
		hint = "Log in, then double-click the Tour Planner.",
		done = function(app)
			return laptopWindow(app, "planner")
		end,
	},
	{
		at = "laptop",
		lines = { "These are the ticket prices. The promoter already set fair ones: press <b>Next</b>." },
		hint = "Press Next: choose the stage.",
		done = function(app)
			return (app.state.draft or {}).pricesSet == true
		end,
	},
	{
		at = "laptop",
		lines = { "Every tour needs a stage. <b>Select</b> the Club Stage and press <b>Next</b>." },
		hint = "Select a stage, then Next.",
		done = function(app)
			return (app.state.draft or {}).stageSet == true
		end,
	},
	{
		at = "laptop",
		lines = { "Last step: check everything and press <b>ANNOUNCE TOUR</b>!" },
		hint = "Press ANNOUNCE TOUR.",
		done = function(app)
			return #app.state.tours > 0
		end,
	},
	{
		at = "stagehall",
		target = "stagehall",
		lines = { "Your first tour is on sale! Now let's build a stage of your own.", "Close the laptop and follow me to the <b>STAGE HALL</b>." },
		hint = "Go to the STAGE HALL, press E, then EDIT a stage.",
		done = function(app)
			return app.mode == "designer"
		end,
	},
	{
		at = "stagehall",
		lines = { "This is the stage builder. Pick an item at the bottom, point at the stage and press <b>Q</b> to place it." },
		hint = "Pick an item and press Q to place it.",
		start = function(app, run)
			run.items0 = itemCount(app)
		end,
		done = function(app, run)
			return app.mode ~= "designer" or itemCount(app) > (run.items0 or 0)
		end,
	},
	{
		at = "stagehall",
		lines = {
			"Click an item to select it. The arrows move it, the gold cubes make it bigger, R turns it.",
			"The tab <b>2  SETLIST & SHOW</b> plans what happens in every song. Press <b>DONE</b> when you're happy.",
		},
		hint = "Press DONE when you are finished.",
		done = function(app)
			return app.mode ~= "designer"
		end,
	},
	{
		at = "start",
		lines = {
			"That's all you need! Time runs by itself: pause it or speed it up at the top.",
			"On show day you can go to the venue and watch it live.",
			"The house button at the top right saves your game. Good luck, boss!",
		},
	},
}

------------------------------------------------------------------ Sam in the office
local function guideModel()
	local root = workspace:FindFirstChild("StarlightRecords")
	return root and root:FindFirstChild("Guide")
end

local function moveGuide(spot)
	local g = guideModel()
	local p = Hub.GUIDE_SPOTS[spot or "start"]
	if not g or not p then
		return
	end
	local h = g:GetAttribute("RootHeight") or 3
	local pos = O + p + Vector3.new(0, h, 0)
	-- look at the player (or towards the room)
	local look = O + Hub.SPAWN
	local char = Players.LocalPlayer.Character
	if char and char.PrimaryPart then
		look = char.PrimaryPart.Position
	end
	local dir = Vector3.new(look.X - pos.X, 0, look.Z - pos.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, 1)
	end
	pcall(function()
		g:PivotTo(CFrame.lookAt(pos, pos + dir))
	end)
end
Tutorial.moveGuide = moveGuide

-- joints of the R15 character: Sam waves and talks with the hands
local function joint(g, partName, jointName)
	local p = g:FindFirstChild(partName)
	return p and p:FindFirstChild(jointName)
end
local function animateGuide(t, talking, wave)
	local g = guideModel()
	if not g then
		return
	end
	local rs = joint(g, "RightUpperArm", "RightShoulder")
	local ls = joint(g, "LeftUpperArm", "LeftShoulder")
	local neck = joint(g, "Head", "Neck")
	local waist = joint(g, "UpperTorso", "Waist")
	if rs and rs:IsA("Motor6D") then
		if wave > 0 then
			rs.Transform = CFrame.Angles(0, 0, math.rad(150 + math.sin(t * 9) * 18) * wave)
		elseif talking then
			rs.Transform = CFrame.Angles(math.rad(35 + math.sin(t * 3.1) * 14), 0, math.rad(8 + math.sin(t * 2.3) * 6))
		else
			rs.Transform = CFrame.Angles(math.rad(math.sin(t * 1.2) * 3), 0, 0)
		end
	end
	if ls and ls:IsA("Motor6D") then
		-- the clipboard arm stays bent in front of the body
		ls.Transform = CFrame.Angles(math.rad(55 + math.sin(t * 1.3) * 2), 0, math.rad(-6))
	end
	if neck and neck:IsA("Motor6D") then
		neck.Transform = talking and CFrame.Angles(math.rad(math.sin(t * 5) * 5), math.rad(math.sin(t * 1.7) * 8), 0) or CFrame.Angles(0, math.rad(math.sin(t * 0.6) * 6), 0)
	end
	if waist and waist:IsA("Motor6D") then
		waist.Transform = CFrame.Angles(math.rad(math.sin(t * 1.6) * 1.2), 0, 0)
	end
end

------------------------------------------------------------------ the speech bubble
local function portrait(parent)
	local vp = New("ViewportFrame", { Parent = parent, Position = UI.px(16, 16), Size = UI.px(120, 120), BackgroundColor3 = Color3.fromRGB(219, 234, 254), BorderSizePixel = 0, Ambient = Color3.fromRGB(200, 200, 210), LightDirection = Vector3.new(-0.4, -0.6, -1), UI.Corner(60) })
	local g = guideModel()
	if g then
		local ok, copy = pcall(function()
			g.Archivable = true
			return g:Clone()
		end)
		if ok and copy then
			copy.Parent = vp
			local head = copy:FindFirstChild("Head")
			if head then
				local cam = New("Camera", { FieldOfView = 30, Parent = vp })
				local hc = head.CFrame
				cam.CFrame = CFrame.lookAt((hc * CFrame.new(0, 0.1, -4.6)).Position, hc.Position + Vector3.new(0, -0.15, 0))
				vp.CurrentCamera = cam
			end
		end
	end
	return vp
end

function Tutorial.active(app)
	local tut = app.state and app.state.tutorial
	return type(tut) == "table" and not tut.done
end

-- where the bubble sits: low in the middle, small and out of the way when you have to do something
local function dock(run)
	local app = run.app
	local f = run.frame
	local mode = app.mode
	local gap = 0
	if run.waiting then
		if mode == "designer" then
			f.Position, f.Size = UI.px(20, 104), UI.px(760, 86)
		elseif mode == "laptop" then
			f.Position, f.Size = UI.px(530 + gap, 918), UI.px(860, 86)
		else
			f.Position, f.Size = UI.px(530 + gap, 960), UI.px(860, 86)
		end
	else
		f.Position, f.Size = UI.px(470 + gap, 852), UI.px(980, 168)
	end
	run.pic.Visible = not run.waiting
	run.text.Position = run.waiting and UI.px(24, 30) or UI.px(156, 50)
	run.text.Size = run.waiting and UI.px(820, 50) or UI.px(800, 80)
	run.name.Position = run.waiting and UI.px(24, 6) or UI.px(156, 16)
	run.more.Visible = not run.waiting
end

local run = nil

local function showLine(r, text)
	r.text.Text = text
	r.text.MaxVisibleGraphemes = 0
	r.typeT = 0
	r.full = false
	SoundFX.sfx("click", 0.25)
end

local function stepDef(i)
	return Tutorial.STEPS[i]
end

local function startStep(r, i)
	r.step = i
	local st = stepDef(i)
	if not st then
		Tutorial.finish(r.app)
		return
	end
	r.app:act("tutorial", { step = i })
	r.waiting = false
	r.lines = type(st.lines) == "function" and st.lines(r.app) or st.lines or {}
	r.lineIdx = 1
	r.wave = (i == 1) and 2.5 or 1.2
	moveGuide(st.at)
	if st.start then
		st.start(r.app, r)
	end
	if r.app.world then
		r.app.world.tutorialTarget = nil
		r.app.world.refresh()
	end
	dock(r)
	if #r.lines > 0 then
		showLine(r, r.lines[1])
	else
		Tutorial.next(r.app)
	end
end

-- click on the bubble: finish typing, next line, or wait for the task of this step
function Tutorial.next(app)
	local r = run
	if not r or r.app ~= app then
		return
	end
	if r.waiting then
		return
	end
	if not r.full and r.lineIdx <= #r.lines then
		r.text.MaxVisibleGraphemes = -1
		r.full = true
		return
	end
	if r.lineIdx < #r.lines then
		r.lineIdx = r.lineIdx + 1
		showLine(r, r.lines[r.lineIdx])
		return
	end
	local st = stepDef(r.step)
	if st and st.done and not st.done(app, r) then
		-- your turn: the bubble shows what to do, the arrow shows where
		r.waiting = true
		r.text.Text = st.hint or ""
		r.text.MaxVisibleGraphemes = -1
		if app.world then
			app.world.tutorialTarget = st.target
			app.world.refresh()
		end
		dock(r)
		return
	end
	startStep(r, r.step + 1)
end

function Tutorial.finish(app, skipped)
	app:act("tutorial", { done = true })
	if run and run.app == app then
		for _, c in ipairs(run.conns) do
			c:Disconnect()
		end
		run.frame:Destroy()
		run = nil
	end
	if app.world then
		app.world.tutorialTarget = nil
		app.world.override = nil
		app.world.refresh()
	end
	moveGuide("start")
	if skipped then
		app:toast("Tutorial skipped. Sam is in the office if you need him.", T.accent2, 5)
	end
end

function Tutorial.start(app)
	if not Tutorial.active(app) or run then
		return
	end
	local r = { app = app, conns = {}, step = 1, t = 0 }
	run = r
	local f = New("TextButton", { Parent = app.canvas, Name = "TutorialBubble", BackgroundColor3 = T.panel, AutoButtonColor = false, Text = "", BorderSizePixel = 0, ZIndex = 85, UI.Corner(18), UI.Stroke(T.accent, 2, 0) })
	r.frame = f
	r.pic = portrait(f)
	r.pic.ZIndex = 86
	r.name = UI.Label(f, "SAM  |  LABEL MANAGER", UI.px(156, 16), UI.px(500, 24), { textSize = 15, font = UI.FontBlack, color = T.accent })
	r.name.ZIndex = 86
	r.text = UI.Label(f, "", UI.px(156, 50), UI.px(800, 80), { textSize = 22, wrap = true, rich = true, alignY = Enum.TextYAlignment.Top })
	r.text.ZIndex = 86
	r.more = UI.Label(f, "Click to continue", UI.px(156, 134), UI.px(400, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
	r.more.ZIndex = 86
	local skip = UI.Button(f, "Skip tutorial", UDim2.new(1, -150, 0, 10), UI.px(136, 30), { textSize = 13, color = T.panel2 }, function()
		Tutorial.finish(app, true)
	end)
	skip.ZIndex = 87
	skip.Name = "SkipTutorial"
	f.MouseButton1Click:Connect(function()
		Tutorial.next(app)
	end)
	table.insert(r.conns, RunService.RenderStepped:Connect(function(dt)
		r.t = r.t + dt
		if not r.full and r.text.MaxVisibleGraphemes >= 0 then
			r.typeT = r.typeT + dt
			local n = math.floor(r.typeT * 70)
			if n >= #r.text.ContentText then
				r.text.MaxVisibleGraphemes = -1
				r.full = true
			else
				r.text.MaxVisibleGraphemes = n
			end
		end
		r.wave = math.max(0, (r.wave or 0) - dt)
		animateGuide(r.t, not r.waiting, math.min(1, r.wave))
		-- the bubble follows the mode (walking, laptop, builder) and hides in shows
		local show = app.mode ~= "live" and app.mode ~= "title"
		f.Visible = show
		if r.lastMode ~= app.mode then
			r.lastMode = app.mode
			dock(r)
		end
	end))
	table.insert(r.conns, RunService.Heartbeat:Connect(function()
		r.check = (r.check or 0) + 1
		if r.check % 10 ~= 0 or not r.waiting then
			return
		end
		local st = stepDef(r.step)
		if st and st.done and st.done(app, r) then
			SoundFX.sfx("cash", 0.3)
			startStep(r, r.step + 1)
		end
	end))
	local step = (app.state.tutorial and app.state.tutorial.step) or 1
	startStep(r, math.clamp(step, 1, #Tutorial.STEPS))
end

function Tutorial.stop()
	if run then
		for _, c in ipairs(run.conns) do
			c:Disconnect()
		end
		run.frame:Destroy()
		run = nil
	end
end

return Tutorial
