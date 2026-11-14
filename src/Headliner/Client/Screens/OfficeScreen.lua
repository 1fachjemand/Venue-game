-- OFFICE: the hub of your label. Every part of the game starts here.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)

local T = UI.Theme
local OfficeScreen = {}
OfficeScreen.__index = OfficeScreen

function OfficeScreen.new(app)
	local self = setmetatable({ app = app }, OfficeScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Office" })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	return self
end

function OfficeScreen:show()
	self:refresh()
end

function OfficeScreen:refresh()
	local app, state = self.app, self.app.state
	local body = self.body
	UI.ClearChildren(body)

	-- header: label + level progress
	UI.Label(body, state.labelName, UI.px(40, 18), UI.px(1100, 60), { textSize = 50, font = UI.FontBlack })
	local lvl, def, nextDef = GS.level(state)
	UI.Pill(body, "LEVEL " .. lvl, UI.px(40, 86), UI.px(100, 30), T.accent, 16)
	UI.Label(body, def.name, UI.px(152, 84), UI.px(400, 34), { textSize = 24, font = UI.FontBold, color = T.gold })
	if nextDef then
		local f = (state.stats.tickets - def.tickets) / (nextDef.tickets - def.tickets)
		UI.Bar(body, UI.px(560, 96), UI.px(520, 12), f, T.gold)
		UI.Label(body, Util.number(state.stats.tickets) .. " / " .. Util.number(nextDef.tickets) .. " tickets sold until " .. nextDef.name, UI.px(1096, 84), UI.px(800, 34), { textSize = 17, color = T.sub })
	else
		UI.Label(body, "Highest level reached!", UI.px(560, 84), UI.px(600, 34), { textSize = 18, color = T.sub })
	end

	-- main tiles
	local active = 0
	for _, t in ipairs(state.tours) do
		if t.status ~= "done" then
			active = active + 1
		end
	end
	local _, rank = GS.chart(state)
	local tiles = {
		{ "ARTISTS", "Your roster and new talent to sign.", #GS.signedArtists(state) .. " signed", function()
			app:go("artists")
		end, T.accent },
		{ "PLAN A TOUR", "Pick an artist, venues, ticket price and stage.", "Book venues", function()
			app:go("planner")
		end, T.accent2 },
		{ "TOURS", "Live ticket sales, marketing and results.", active .. " active", function()
			app:go("tours")
		end, T.good },
		{ "STAGE DESIGNER", "Build and buy your stage productions.", #state.designs .. " designs", function()
			app.returnScreen = "office"
			app:openDesigner(app.lastDesignId)
		end, Color3.fromRGB(190, 120, 255) },
		{ "CHARTS", "Top grossing tours and achievements.", rank and ("best rank #" .. rank) or "not ranked yet", function()
			app:go("charts")
		end, T.gold },
	}
	for i, t in ipairs(tiles) do
		local b = UI.Button(body, "", UI.px(40 + (i - 1) * 372, 140), UI.px(356, 200), { color = T.panel }, t[4])
		UI.Stroke(t[5], 2, 0.2).Parent = b
		UI.New("Frame", { Parent = b, Size = UI.px(356, 8), BackgroundColor3 = t[5], BorderSizePixel = 0, UI.Corner(8) })
		UI.Label(b, t[1], UI.px(22, 30), UI.px(320, 40), { textSize = 28, font = UI.FontBlack, color = t[5] })
		UI.Label(b, t[2], UI.px(22, 76), UI.px(316, 60), { textSize = 17, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
		UI.Label(b, t[3], UI.px(22, 150), UI.px(316, 30), { textSize = 18, font = UI.FontBold })
	end

	-- upcoming shows
	local up = UI.Panel(body, UI.px(40, 364), UI.px(1100, 628))
	UI.Label(up, "UPCOMING SHOWS", UI.px(24, 16), UI.px(600, 32), { textSize = 24, font = UI.FontBlack, color = T.accent })
	local list = UI.Scroll(up, UI.px(16, 60), UI.px(1068, 556))
	UI.List(true, 6).Parent = list
	local shows = {}
	for _, tour in ipairs(state.tours) do
		for _, s in ipairs(tour.shows) do
			if not s.done then
				table.insert(shows, { tour = tour, s = s })
			end
		end
	end
	table.sort(shows, function(a, b)
		return a.s.day < b.s.day
	end)
	if #shows == 0 then
		UI.Label(list, "No shows booked. Go to PLAN A TOUR to book your first tour!", nil, UI.px(1040, 40), { textSize = 17, color = T.sub })
	end
	for i = 1, math.min(12, #shows) do
		local e = shows[i]
		local v = Countries.venueById[e.s.venueId]
		local ad = Artists.byId[e.tour.artistId]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(1048, 50), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		local _, d = Util.date(e.s.day, Config.START_YEAR)
		UI.Label(row, d, UI.px(14, 0), UI.px(90, 50), { textSize = 16, font = UI.FontBold })
		UI.New("Frame", { Parent = row, Position = UI.px(104, 12), Size = UI.px(6, 26), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(row, ad.name .. "  @  " .. v.name .. ", " .. v.city, UI.px(122, 0), UI.px(560, 50), { textSize = 16 })
		local f = math.min(1, e.s.sold / e.s.cap)
		local col = f >= 1 and T.gold or (f > 0.7 and T.good or (f > 0.4 and T.warn or T.bad))
		UI.Bar(row, UI.px(700, 20), UI.px(160, 10), f, col)
		UI.Label(row, f >= 1 and "SOLD OUT" or (Util.number(e.s.sold) .. " / " .. Util.number(e.s.cap)), UI.px(870, 0), UI.px(170, 50), { textSize = 15, font = UI.FontBold, color = col })
	end

	-- news
	local news = UI.Panel(body, UI.px(1160, 364), UI.px(720, 628))
	UI.Label(news, "NEWS", UI.px(24, 16), UI.px(600, 32), { textSize = 24, font = UI.FontBlack, color = T.accent })
	local nl = UI.Scroll(news, UI.px(16, 60), UI.px(688, 556))
	UI.List(true, 8).Parent = nl
	for i = 1, math.min(15, #state.log) do
		local e = state.log[i]
		local _, d = Util.date(e.day, Config.START_YEAR)
		UI.New("TextLabel", {
			Parent = nl,
			Size = UI.px(664, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = "<b>" .. d .. "</b>   " .. UI.esc(e.text),
			RichText = true,
			TextWrapped = true,
			TextSize = 16,
			TextColor3 = T.text,
			Font = UI.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		})
	end
end

return OfficeScreen
