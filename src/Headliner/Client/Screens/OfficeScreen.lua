-- OFFICE: the home screen. Shows what happens next, upcoming shows, what fans post and the news.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)

local T = UI.Theme
local BLACK = Color3.new(0, 0, 0)
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

local function upcoming(state)
	local shows = {}
	for _, tour in ipairs(state.tours) do
		for i, s in ipairs(tour.shows) do
			if not s.done then
				table.insert(shows, { tour = tour, s = s, idx = i })
			end
		end
	end
	table.sort(shows, function(a, b)
		return a.s.day < b.s.day
	end)
	return shows
end

function OfficeScreen:refresh()
	local app, state = self.app, self.app.state
	local body = self.body
	UI.ClearChildren(body)

	-- header: label name + level progress in one line
	UI.Label(body, state.labelName, UI.px(40, 16), UI.px(900, 56), { textSize = 44, font = UI.FontBlack })
	local lvl, def, nextDef = GS.level(state)
	UI.Pill(body, "LEVEL " .. lvl .. "  ·  " .. string.upper(def.name), UI.px(40, 76), UI.px(250, 28), T.accent, 14)
	if nextDef then
		local f = (state.stats.tickets - def.tickets) / (nextDef.tickets - def.tickets)
		UI.Bar(body, UI.px(306, 86), UI.px(360, 10), f, T.gold)
		UI.Label(body, Util.number(nextDef.tickets - state.stats.tickets) .. " tickets to " .. nextDef.name, UI.px(680, 76), UI.px(500, 28), { textSize = 16, color = T.sub })
	end

	local shows = upcoming(state)
	-- NEXT UP: the next show or what to do now
	local hero = UI.Panel(body, UI.px(40, 124), UI.px(1100, 300))
	local nextShow = shows[1]
	if nextShow then
		local ad = Artists.byId[nextShow.tour.artistId]
		local v = Countries.venueById[nextShow.s.venueId]
		People.preview(hero, ad.look, UI.rgb(ad.color), UI.px(20, 20), UI.px(200, 260), Color3.fromRGB(30, 34, 50))
		UI.Label(hero, "NEXT SHOW", UI.px(250, 22), UI.px(400, 22), { textSize = 15, color = T.accent2, font = UI.FontBold })
		UI.Label(hero, ad.name, UI.px(250, 46), UI.px(820, 48), { textSize = 40, font = UI.FontBlack })
		UI.Label(hero, v.name .. ", " .. v.city, UI.px(250, 96), UI.px(820, 30), { textSize = 22 })
		local days = nextShow.s.day - state.day
		UI.Label(hero, (days <= 0 and "Tonight" or ("In " .. days .. " day" .. (days == 1 and "" or "s"))) .. "   ·   " .. Util.date(nextShow.s.day, Config.START_YEAR), UI.px(250, 130), UI.px(820, 26), { textSize = 18, color = T.sub })
		local f = math.min(1, nextShow.s.sold / nextShow.s.cap)
		local col = f >= 1 and T.gold or (f > 0.7 and T.good or (f > 0.4 and T.warn or T.bad))
		UI.Bar(hero, UI.px(250, 178), UI.px(520, 18), f, col)
		UI.Label(hero, f >= 1 and "SOLD OUT" or (Util.number(nextShow.s.sold) .. " / " .. Util.number(nextShow.s.cap) .. " sold"), UI.px(784, 170), UI.px(300, 34), { textSize = 20, font = UI.FontBold, color = col })
		UI.Button(hero, "OPEN TOUR", UI.px(250, 222), UI.px(220, 56), { color = T.accent, textSize = 18 }, function()
			app:go("tours", { tourId = nextShow.tour.id })
		end)
		UI.Button(hero, "+ PLAN ANOTHER TOUR", UI.px(484, 222), UI.px(280, 56), { textSize = 16 }, function()
			app:go("planner")
		end)
	else
		UI.Label(hero, "WHAT NOW?", UI.px(30, 22), UI.px(600, 22), { textSize = 15, color = T.accent2, font = UI.FontBold })
		UI.Label(hero, "No shows booked yet", UI.px(30, 46), UI.px(1000, 48), { textSize = 38, font = UI.FontBlack })
		UI.Label(hero, "Book a tour for one of your artists. Start with small clubs, they sell out more easily.", UI.px(30, 98), UI.px(1040, 28), { textSize = 18, color = T.sub })
		local actions = {
			{ "+ PLAN A TOUR", "Pick venues and a price", T.accent2, function()
				app:go("planner")
			end },
			{ "BUILD A STAGE", "Design your show", T.accent, function()
				app:go("stages")
			end },
			{ "FIND TALENT", "Sign new artists", T.panel3, function()
				app:go("artists", { tab = "scout" })
			end },
		}
		for i, a in ipairs(actions) do
			local b = UI.Button(body, "", UI.px(70 + (i - 1) * 350, 284), UI.px(330, 110), { color = a[3] }, a[4])
			UI.Label(b, a[1], UI.px(20, 18), UI.px(300, 34), { textSize = 24, font = UI.FontBlack, color = (a[3] == T.accent2) and BLACK or T.text })
			UI.Label(b, a[2], UI.px(20, 60), UI.px(300, 26), { textSize = 16, color = (a[3] == T.accent2) and BLACK or T.sub })
		end
	end

	-- upcoming shows
	local up = UI.Panel(body, UI.px(40, 444), UI.px(1100, 548))
	UI.Label(up, "UPCOMING SHOWS", UI.px(24, 16), UI.px(600, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	local list = UI.Scroll(up, UI.px(16, 58), UI.px(1068, 480))
	UI.List(true, 6).Parent = list
	if #shows == 0 then
		UI.Label(list, "Nothing booked.", nil, UI.px(1040, 40), { textSize = 17, color = T.sub })
	end
	for i = 1, math.min(10, #shows) do
		local e = shows[i]
		local v = Countries.venueById[e.s.venueId]
		local ad = Artists.byId[e.tour.artistId]
		local row = UI.Button(list, "", nil, UI.px(1048, 46), { order = i, color = T.panel2 }, function()
			app:go("tours", { tourId = e.tour.id })
		end)
		local _, d = Util.date(e.s.day, Config.START_YEAR)
		UI.Label(row, d, UI.px(14, 0), UI.px(90, 46), { textSize = 16, font = UI.FontBold })
		UI.New("Frame", { Parent = row, Position = UI.px(104, 10), Size = UI.px(6, 26), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(row, ad.name .. "  @  " .. v.name .. ", " .. v.city, UI.px(122, 0), UI.px(560, 46), { textSize = 16 })
		local f = math.min(1, e.s.sold / e.s.cap)
		local col = f >= 1 and T.gold or (f > 0.7 and T.good or (f > 0.4 and T.warn or T.bad))
		UI.Bar(row, UI.px(700, 18), UI.px(160, 10), f, col)
		UI.Label(row, f >= 1 and "SOLD OUT" or (Util.number(e.s.sold) .. " / " .. Util.number(e.s.cap)), UI.px(870, 0), UI.px(170, 46), { textSize = 15, font = UI.FontBold, color = col })
	end

	-- right: latest fan posts + news
	local soc = UI.Panel(body, UI.px(1160, 124), UI.px(720, 470))
	UI.Label(soc, "FANS ARE SAYING", UI.px(24, 16), UI.px(500, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Button(soc, "Open SOCIAL", UI.px(536, 16), UI.px(160, 34), { textSize = 14 }, function()
		app:go("social")
	end)
	local posts = state.social or {}
	if #posts == 0 then
		UI.Label(soc, "Nobody is talking about your label yet. Announce a tour!", UI.px(24, 64), UI.px(670, 50), { textSize = 17, color = T.sub, wrap = true })
	end
	for i = 1, math.min(4, #posts) do
		local p = posts[i]
		local y = 60 + (i - 1) * 100
		local card = UI.New("Frame", { Parent = soc, Position = UI.px(16, y), Size = UI.px(688, 92), BackgroundColor3 = T.panel2, BorderSizePixel = 0, UI.Corner(10) })
		local col = (p.mood > 0) and T.good or ((p.mood < 0) and T.bad or T.sub)
		UI.New("Frame", { Parent = card, Size = UI.px(6, 92), BackgroundColor3 = col, BorderSizePixel = 0 })
		UI.Label(card, p.name .. "  " .. p.handle, UI.px(18, 6), UI.px(660, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Label(card, p.text, UI.px(18, 30), UI.px(660, 56), { textSize = 17, wrap = true, alignY = Enum.TextYAlignment.Top })
	end
	local news = UI.Panel(body, UI.px(1160, 614), UI.px(720, 378))
	UI.Label(news, "NEWS", UI.px(24, 16), UI.px(600, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	local nl = UI.Scroll(news, UI.px(16, 56), UI.px(688, 312))
	UI.List(true, 8).Parent = nl
	for i = 1, math.min(10, #state.log) do
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
