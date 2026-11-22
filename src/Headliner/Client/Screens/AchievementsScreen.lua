-- ACHIEVEMENTS (laptop app): every goal with its reward and how far you are. Unlocked ones are gold and
-- show the day you got them; the harder a goal, the bigger the reward (paid out when it unlocks).
local Root = script:FindFirstAncestor("Headliner")
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Achievements = require(Root.Data.Achievements)

local T = UI.Theme
local AchievementsScreen = {}
AchievementsScreen.__index = AchievementsScreen

function AchievementsScreen.new(app)
	local self = setmetatable({ app = app }, AchievementsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false, Name = "Achievements" })
	return self
end

function AchievementsScreen:show()
	self:refresh()
end

-- short numbers so "value / goal" always fits ($150K / $10M, 30K / 1M)
local function fmt(stat, v)
	if stat == "money" or stat == "bestTourGross" or stat == "totalGross" then
		return "$" .. Util.short(v)
	end
	if v >= 10000 then
		return Util.short(v)
	end
	return Util.number(math.floor(v))
end

function AchievementsScreen:refresh()
	local state = self.app.state
	local f = self.frame
	UI.ClearChildren(f)
	local vals = GS.achievementStats(state)
	local got, earned = 0, 0
	for _, a in ipairs(Achievements.list) do
		if state.achievements[a.id] then
			got = got + 1
			earned = earned + (a.reward or 0)
		end
	end
	UI.Label(f, "Achievements", UI.px(40, 24), UI.px(800, 44), { textSize = 34, font = UI.FontBlack })
	UI.Label(f, got .. " of " .. #Achievements.list .. " unlocked  |  rewards earned " .. Util.money(earned) .. (state.sandbox and "  (no rewards in the sandbox)" or ""), UI.px(40, 70), UI.px(1400, 24), { textSize = 17, color = T.sub })
	local _, setAll = UI.Bar(f, UI.px(40, 102), UI.px(1840, 10), got / math.max(1, #Achievements.list), T.gold)
	local _ = setAll
	-- the open ones first (closest to done on top), then the unlocked ones
	local order = {}
	for i, a in ipairs(Achievements.list) do
		local v, goal, done = GS.achievementProgress(a, vals)
		local frac
		if a.stat == "rank" then
			frac = (v and v > 0) and math.clamp(goal / v, 0, 1) or 0
		else
			frac = math.clamp(v / math.max(1, goal), 0, 1)
		end
		table.insert(order, { a = a, i = i, v = v, goal = goal, done = state.achievements[a.id] ~= nil or done, frac = frac })
	end
	table.sort(order, function(p, q)
		if p.done ~= q.done then
			return not p.done
		end
		if not p.done and math.abs(p.frac - q.frac) > 0.001 then
			return p.frac > q.frac
		end
		return p.i < q.i
	end)
	local list = UI.Scroll(f, UI.px(40, 128), UI.px(1840, 860))
	local grid = UI.New("UIGridLayout", { CellSize = UI.px(600, 128), CellPadding = UI.px(18, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local _ = grid
	for n, e in ipairs(order) do
		local a = e.a
		local done = e.done
		local card = UI.New("Frame", { Parent = list, Name = "Ach_" .. a.id, LayoutOrder = n, BackgroundColor3 = done and Color3.fromRGB(254, 243, 199) or T.panel, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(done and T.gold or T.line or Color3.fromRGB(210, 214, 222), done and 2 or 1, 0) })
		-- a round medal on the left
		local medal = UI.New("Frame", { Parent = card, Position = UI.px(18, 22), Size = UI.px(64, 64), BackgroundColor3 = done and T.gold or Color3.fromRGB(203, 213, 225), BorderSizePixel = 0, UI.Corner(32) })
		UI.Label(medal, done and "DONE" or tostring(math.floor(e.frac * 100)) .. "%", UI.px(0, 0), UI.px(64, 64), { textSize = done and 20 or 17, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center, color = done and Color3.new(1, 1, 1) or T.text })
		UI.Label(card, a.name, UI.px(100, 12), UI.px(330, 28), { textSize = 21, font = UI.FontBlack })
		UI.Label(card, a.desc, UI.px(100, 42), UI.px(480, 22), { textSize = 15, color = T.sub })
		UI.Pill(card, "+" .. Util.money(a.reward or 0), UI.px(440, 14), UI.px(140, 26), done and T.good or T.accent, 14)
		if done then
			local day = state.achievements[a.id]
			UI.Label(card, "Unlocked" .. (type(day) == "number" and (" on day " .. day) or ""), UI.px(100, 80), UI.px(480, 24), { textSize = 15, font = UI.FontBold, color = T.good })
		else
			UI.Bar(card, UI.px(100, 82), UI.px(330, 12), e.frac, T.accent)
			local txt
			if a.stat == "rank" then
				txt = (e.v and e.v > 0) and ("best place #" .. e.v .. " (goal #" .. a.goal .. ")") or "no tour in the chart yet"
			else
				txt = fmt(a.stat, e.v) .. " / " .. fmt(a.stat, a.goal)
			end
			UI.Label(card, txt, UI.px(440, 74), UI.px(140, 28), { textSize = 14, color = T.sub, alignX = Enum.TextXAlignment.Right })
		end
	end
	list.CanvasSize = UI.px(0, math.ceil(#order / 3) * 142 + 20)
end

return AchievementsScreen
