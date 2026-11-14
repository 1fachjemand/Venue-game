-- CHARTS screen: Top grossing tours of all time + achievements + records.
local Root = script:FindFirstAncestor("Headliner")
local Achievements = require(Root.Data.Achievements)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)

local T = UI.Theme
local ChartsScreen = {}
ChartsScreen.__index = ChartsScreen

function ChartsScreen.new(app)
	local self = setmetatable({ app = app }, ChartsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Charts" })
	local left = UI.Panel(self.frame, UI.px(20, 12), UI.px(1180, 984))
	UI.Label(left, "TOP GROSSING TOURS OF ALL TIME", UI.px(24, 14), UI.px(900, 36), { textSize = 28, font = UI.FontBlack, color = T.gold })
	local headers = { { "#", 24 }, { "ARTIST / TOUR", 90 }, { "GROSS", 640 }, { "SHOWS", 840 }, { "ATTENDANCE", 960 } }
	for _, h in ipairs(headers) do
		UI.Label(left, h[1], UI.px(h[2], 60), UI.px(200, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	self.chart = UI.Scroll(left, UI.px(12, 84), UI.px(1160, 890))
	UI.List(true, 4).Parent = self.chart
	local right = UI.Panel(self.frame, UI.px(1216, 12), UI.px(684, 984))
	UI.Label(right, "RECORDS", UI.px(24, 14), UI.px(600, 36), { textSize = 26, font = UI.FontBlack, color = T.accent })
	self.records = UI.Label(right, "", UI.px(24, 56), UI.px(636, 170), { textSize = 17, rich = true, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Label(right, "ACHIEVEMENTS", UI.px(24, 236), UI.px(600, 36), { textSize = 26, font = UI.FontBlack, color = T.accent })
	self.ach = UI.Scroll(right, UI.px(12, 280), UI.px(664, 694))
	UI.List(true, 6).Parent = self.ach
	return self
end

function ChartsScreen:show()
	self:refresh()
end

function ChartsScreen:refresh()
	local state = self.app.state
	UI.ClearChildren(self.chart)
	local rows = GS.chart(state)
	for i, r in ipairs(rows) do
		local row = UI.New("Frame", {
			Parent = self.chart,
			Size = UI.px(1140, 58),
			BackgroundColor3 = r.player and UI.shade(T.accent, 0.45) or ((i % 2 == 0) and T.panel2 or T.panel3),
			BorderSizePixel = 0,
			LayoutOrder = i,
			UI.Corner(8),
		})
		if r.player then
			UI.Stroke(T.accent, 2, 0).Parent = row
		end
		local rankCol = i == 1 and T.gold or (i <= 3 and Color3.fromRGB(200, 200, 215) or T.text)
		UI.Label(row, tostring(i), UI.px(12, 0), UI.px(60, 58), { textSize = 26, font = UI.FontBlack, color = rankCol })
		UI.Label(row, r.artist .. (r.player and "  (YOUR LABEL)" or ""), UI.px(78, 6), UI.px(540, 24), { textSize = 18, font = UI.FontBold })
		UI.Label(row, r.tour .. (r.live and "  - still on tour" or ""), UI.px(78, 30), UI.px(540, 20), { textSize = 14, color = T.sub })
		UI.Label(row, Util.money(r.gross), UI.px(628, 0), UI.px(200, 58), { textSize = 20, font = UI.FontBlack, color = T.gold })
		UI.Label(row, tostring(r.shows), UI.px(828, 0), UI.px(100, 58), { textSize = 18 })
		UI.Label(row, Util.number(r.attendance), UI.px(948, 0), UI.px(180, 58), { textSize = 18 })
	end

	local st = state.stats
	self.records.Text = table.concat({
		"Shows played: <b>" .. Util.number(st.shows) .. "</b>     Sold-out shows: <b>" .. Util.number(st.sellouts) .. "</b>",
		"Tickets sold: <b>" .. Util.number(st.tickets) .. "</b>",
		"Total gross: <b>" .. Util.money(st.totalGross) .. "</b>",
		"Best tour: <b>" .. Util.money(st.bestTourGross) .. "</b>",
		"Best single show: <b>" .. Util.money(st.bestShowGross) .. "</b>" .. (st.bestShowText ~= "" and (" (" .. st.bestShowText .. ")") or ""),
		"Biggest sell-out: <b>" .. (st.biggestSellout > 0 and Util.number(st.biggestSellout) or "-") .. "</b>",
	}, "\n")

	UI.ClearChildren(self.ach)
	for i, a in ipairs(Achievements.list) do
		local got = state.achievements[a.id] ~= nil
		local row = UI.New("Frame", { Parent = self.ach, Size = UI.px(644, 56), BackgroundColor3 = got and UI.shade(T.good, 0.35) or T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		UI.Label(row, got and "*" or "-", UI.px(12, 0), UI.px(30, 56), { textSize = 26, font = UI.FontBlack, color = got and T.gold or T.sub })
		UI.Label(row, a.name, UI.px(48, 6), UI.px(580, 24), { textSize = 18, font = UI.FontBold, color = got and T.text or T.sub })
		UI.Label(row, a.desc, UI.px(48, 30), UI.px(580, 20), { textSize = 14, color = T.sub })
	end
end

return ChartsScreen
