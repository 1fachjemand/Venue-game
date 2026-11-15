-- STATISTICS (laptop app): the label in numbers, every artist and every tour.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Artists = require(Root.Data.Artists)

local T = UI.Theme
local StatsScreen = {}
StatsScreen.__index = StatsScreen

function StatsScreen.new(app)
	local self = setmetatable({ app = app }, StatsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false, Name = "Stats" })
	return self
end

function StatsScreen:show()
	self:refresh()
end

function StatsScreen:refresh()
	local state = self.app.state
	local f = self.frame
	UI.ClearChildren(f)
	local st = state.stats
	UI.Label(f, "Statistics", UI.px(40, 24), UI.px(800, 44), { textSize = 34, font = UI.FontBlack })
	UI.Label(f, state.labelName .. "  |  level " .. GS.level(state) .. " (" .. Config.LEVELS[GS.level(state)].name .. ")", UI.px(40, 70), UI.px(1000, 24), { textSize = 17, color = T.sub })
	local tiles = {
		{ "SHOWS PLAYED", Util.number(st.shows) },
		{ "TICKETS SOLD", Util.number(st.tickets) },
		{ "TICKET MONEY", Util.money(st.totalGross) },
		{ "SOLD-OUT SHOWS", Util.number(st.sellouts) },
		{ "5-STAR SHOWS", Util.number(st.fiveStars) },
		{ "BEST SHOW", st.bestShowGross > 0 and Util.money(st.bestShowGross) or "-", st.bestShowText },
		{ "BEST TOUR", st.bestTourGross > 0 and Util.money(st.bestTourGross) or "-" },
		{ "BIGGEST SELL-OUT", st.biggestSellout > 0 and (Util.number(st.biggestSellout) .. " seats") or "-" },
	}
	for i, t in ipairs(tiles) do
		local x, y = 40 + ((i - 1) % 4) * 464, 116 + math.floor((i - 1) / 4) * 132
		local box = UI.Panel(f, UI.px(x, y), UI.px(448, 118), T.panel)
		UI.Label(box, t[1], UI.px(20, 14), UI.px(410, 20), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Label(box, t[2], UI.px(20, 40), UI.px(410, 40), { textSize = 30, font = UI.FontBlack })
		if t[3] and t[3] ~= "" then
			UI.Label(box, t[3], UI.px(20, 84), UI.px(410, 20), { textSize = 13, color = T.sub })
		end
	end
	-- artists
	local left = UI.Panel(f, UI.px(40, 392), UI.px(900, 590), T.panel)
	UI.Label(left, "YOUR ARTISTS", UI.px(24, 16), UI.px(500, 26), { textSize = 18, font = UI.FontBlack })
	local la = UI.Scroll(left, UI.px(12, 52), UI.px(876, 526))
	UI.List(true, 6).Parent = la
	for i, ad in ipairs(GS.signedArtists(state)) do
		local a = state.artists[ad.id]
		local row = UI.New("Frame", { Parent = la, Size = UI.px(852, 64), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		UI.New("Frame", { Parent = row, Size = UI.px(8, 64), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(row, ad.name, UI.px(22, 6), UI.px(300, 28), { textSize = 19, font = UI.FontBold })
		UI.Label(row, ad.genre, UI.px(22, 34), UI.px(300, 22), { textSize = 14, color = T.sub })
		UI.Label(row, Util.short(Util.totalFans(a.fans)) .. " fans", UI.px(330, 0), UI.px(160, 64), { textSize = 17, font = UI.FontBold })
		UI.Label(row, (a.shows or 0) .. " shows", UI.px(500, 0), UI.px(120, 64), { textSize = 16 })
		UI.Label(row, Util.money(a.gross or 0), UI.px(630, 0), UI.px(200, 64), { textSize = 16, alignX = Enum.TextXAlignment.Right })
	end
	-- tours
	local right = UI.Panel(f, UI.px(960, 392), UI.px(920, 590), T.panel)
	UI.Label(right, "TOURS", UI.px(24, 16), UI.px(500, 26), { textSize = 18, font = UI.FontBlack })
	local lt = UI.Scroll(right, UI.px(12, 52), UI.px(896, 526))
	UI.List(true, 6).Parent = lt
	if #state.tours == 0 then
		UI.Label(lt, "No tours yet. Plan one in the Tour Planner.", nil, UI.px(860, 40), { textSize = 16, color = T.sub })
	end
	for i, t in ipairs(state.tours) do
		local row = UI.New("Frame", { Parent = lt, Size = UI.px(872, 64), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		UI.Label(row, t.name, UI.px(16, 6), UI.px(460, 28), { textSize = 18, font = UI.FontBold })
		UI.Label(row, Artists.byId[t.artistId].name .. "  |  " .. t.played .. " / " .. #t.shows .. " shows  |  " .. ((t.status == "done") and "finished" or "running"), UI.px(16, 34), UI.px(460, 22), { textSize = 14, color = T.sub })
		UI.Label(row, Util.number(t.attendance or 0) .. " fans", UI.px(480, 0), UI.px(160, 64), { textSize = 16 })
		UI.Label(row, "profit " .. Util.money(t.net or 0), UI.px(640, 0), UI.px(216, 64), { textSize = 16, font = UI.FontBold, color = (t.net or 0) >= 0 and T.good or T.bad, alignX = Enum.TextXAlignment.Right })
	end
end

return StatsScreen
