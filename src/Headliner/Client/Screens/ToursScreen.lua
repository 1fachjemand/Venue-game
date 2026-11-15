-- TOURS screen: ticket sales, prices, marketing and results of your tours.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)

local T = UI.Theme
local ToursScreen = {}
ToursScreen.__index = ToursScreen

local STATUS = { announced = "ON SALE", touring = "ON TOUR", done = "COMPLETED" }

function ToursScreen.new(app)
	local self = setmetatable({ app = app }, ToursScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Tours" })
	local left = UI.Panel(self.frame, UI.px(20, 12), UI.px(500, 984))
	UI.Label(left, "YOUR TOURS", UI.px(20, 12), UI.px(300, 34), { textSize = 26, font = UI.FontBlack, color = T.accent })
	self.list = UI.Scroll(left, UI.px(12, 56), UI.px(480, 918))
	UI.List(true, 8).Parent = self.list
	self.detail = UI.Panel(self.frame, UI.px(536, 12), UI.px(1364, 984))
	return self
end

function ToursScreen:show(args)
	if args and args.tourId then
		self.selected = args.tourId
	end
	self:refresh()
end

function ToursScreen:refresh()
	local state = self.app.state
	UI.ClearChildren(self.list)
	if not GS.getTour(state, self.selected or "") then
		self.selected = state.tours[1] and state.tours[1].id
	end
	if #state.tours == 0 then
		UI.Label(self.list, "No tours yet. Go to OFFICE > PLAN A TOUR!", nil, UI.px(460, 60), { textSize = 16, color = T.sub, wrap = true })
	end
	for i, tour in ipairs(state.tours) do
		local ad = Artists.byId[tour.artistId]
		local sel = tour.id == self.selected
		local b = UI.Button(self.list, "", nil, UI.px(464, 92), { order = i, color = sel and T.panel3 or T.panel2 }, function()
			self.selected = tour.id
			self:refresh()
		end)
		UI.New("Frame", { Parent = b, Size = UI.px(6, 92), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(b, tour.name, UI.px(18, 8), UI.px(430, 26), { textSize = 19, font = UI.FontBold })
		UI.Label(b, ad.name .. "  |  " .. #tour.shows .. " shows", UI.px(18, 36), UI.px(430, 20), { textSize = 15, color = T.sub })
		local col = tour.status == "done" and T.sub or (tour.status == "touring" and T.good or T.accent2)
		UI.Label(b, STATUS[tour.status] or tour.status, UI.px(18, 62), UI.px(200, 22), { textSize = 14, font = UI.FontBold, color = col })
		UI.Label(b, Util.money(tour.gross), UI.px(220, 62), UI.px(226, 22), { textSize = 16, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	end
	self:refreshDetail()
end

function ToursScreen:refreshDetail()
	local d = self.detail
	UI.ClearChildren(d)
	local app, state = self.app, self.app.state
	local tour = GS.getTour(state, self.selected or "")
	if not tour then
		UI.Label(d, "Select a tour on the left.", UI.px(24, 20), UI.px(800, 40), { textSize = 20, color = T.sub })
		return
	end
	local ad = Artists.byId[tour.artistId]
	local design = GS.getDesign(state, tour.designId)
	-- click the name to rename the tour
	local nameBox = UI.New("TextBox", {
		Parent = d,
		Position = UI.px(24, 12),
		Size = UI.px(900, 46),
		BackgroundColor3 = T.panel2,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Text = tour.name,
		ClearTextOnFocus = false,
		TextColor3 = T.text,
		TextSize = 34,
		Font = UI.FontBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		UI.Corner(8),
	})
	nameBox.FocusLost:Connect(function()
		local txt = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if #txt > 0 and txt ~= tour.name then
			app:act("renameTour", { tourId = tour.id, name = txt:sub(1, 40) })
		end
		nameBox.Text = tour.name
		app:refreshCurrent()
	end)
	UI.Label(d, "(click to rename)", UI.px(930, 24), UI.px(200, 24), { textSize = 13, color = T.sub })
	UI.Label(d, ad.name .. "   |   Stage: " .. (design and design.name or "-") .. "   |   " .. (STATUS[tour.status] or ""), UI.px(24, 58), UI.px(1000, 24), { textSize = 17, color = T.sub })

	-- summary stats
	local cap, sold = 0, 0
	for _, s in ipairs(tour.shows) do
		cap = cap + s.cap
		sold = sold + math.min(s.sold, s.cap)
	end
	local avg = tour.played > 0 and math.floor(tour.ratingSum / tour.played + 0.5) or nil
	local stats = {
		{ "TICKETS SOLD", Util.number(sold) .. " / " .. Util.number(cap) },
		{ "GROSS (PLAYED)", Util.money(tour.gross) },
		{ "LABEL PROFIT", Util.money(tour.net) },
		{ "SOLD OUT", tour.sellouts .. " / " .. tour.played .. " played" },
		{ "AVG RATING", avg and (avg .. "/100") or "-" },
	}
	for i, st in ipairs(stats) do
		local box = UI.New("Frame", { Parent = d, Position = UI.px(24 + (i - 1) * 264, 94), Size = UI.px(252, 72), BackgroundColor3 = T.panel2, BorderSizePixel = 0, UI.Corner(10) })
		UI.Label(box, st[1], UI.px(14, 8), UI.px(230, 18), { textSize = 13, color = T.sub, font = UI.FontBold })
		UI.Label(box, st[2], UI.px(14, 30), UI.px(230, 32), { textSize = 22, font = UI.FontBlack })
	end

	-- marketing, ticket price & cancel
	if tour.status ~= "done" then
		local price = tour.price or tour.shows[#tour.shows].price
		UI.Label(d, "TICKET PRICE (remaining shows)", UI.px(930, 180), UI.px(260, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
		UI.Button(d, "-", UI.px(930, 204), UI.px(44, 44), { textSize = 20 }, function()
			app:act("setTourPrice", { tourId = tour.id, price = price - (price >= 20 and 5 or 1) })
			app:refreshCurrent()
		end)
		UI.Label(d, Util.money(price), UI.px(978, 204), UI.px(100, 44), { textSize = 22, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center })
		UI.Button(d, "+", UI.px(1082, 204), UI.px(44, 44), { textSize = 20 }, function()
			app:act("setTourPrice", { tourId = tour.id, price = price + (price >= 20 and 5 or 1) })
			app:refreshCurrent()
		end)
		UI.Label(d, "MARKETING (boosts ticket demand for all remaining shows)", UI.px(24, 180), UI.px(700, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
		for i, mk in ipairs(Config.MARKETING) do
			local owned = tour.marketing[mk.id]
			local cost = GS.marketingCost(tour, mk)
			local txt = owned and (mk.name .. " - RUNNING") or (mk.name .. " +" .. math.floor(mk.boost * 100) .. "%  (" .. Util.moneyShort(cost) .. ")")
			UI.Button(d, txt, UI.px(24 + (i - 1) * 300, 204), UI.px(290, 44), { color = owned and T.good or T.panel3, disabled = owned or state.money < cost, textSize = 15 }, function()
				local ok, msg = app:act("buyMarketing", { tourId = tour.id, id = mk.id })
				app:toast(msg or "", ok and T.good or T.bad)
				app:refreshCurrent()
			end)
		end
		if tour.played == 0 then
			UI.Button(d, "Cancel tour", UI.px(1180, 204), UI.px(160, 44), { color = UI.shade(T.bad, 0.7), textSize = 15 }, function()
				app:confirm("Cancel tour?", "All tickets get refunded and " .. ad.name .. " loses hype. Are you sure?", function()
					local ok, msg = app:act("cancelTour", { tourId = tour.id })
					app:toast(msg or "", ok and T.warn or T.bad)
					self.selected = nil
					app:refreshCurrent()
				end)
			end)
		end
	end

	if tour.played > 0 then
		UI.Button(d, "TOUR REPORT", UI.px(1180, tour.status ~= "done" and 150 or 132), UI.px(160, 40), { color = T.accent2, textColor = Color3.new(0, 0, 0), textSize = 15 }, function()
			app:tourReport(tour, false)
		end)
	end

	-- show table
	local y0 = tour.status ~= "done" and 262 or 182
	local headers = { { "DATE", 24 }, { "VENUE", 150 }, { "TICKETS", 600 }, { "PRICE", 900 }, { "RESULT", 1050 }, { "WATCH", 1250 } }
	for _, h in ipairs(headers) do
		UI.Label(d, h[1], UI.px(h[2], y0), UI.px(200, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	end
	local list = UI.Scroll(d, UI.px(12, y0 + 24), UI.px(1340, 984 - y0 - 36))
	UI.List(true, 4).Parent = list
	for i, s in ipairs(tour.shows) do
		local v = Countries.venueById[s.venueId]
		local row = UI.New("Frame", { Parent = list, Size = UI.px(1320, 54), BackgroundColor3 = (i % 2 == 0) and T.panel2 or T.panel3, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(8) })
		local _, dateShort = Util.date(s.day, Config.START_YEAR)
		local daysLeft = s.day - state.day
		UI.Label(row, dateShort, UI.px(12, 6), UI.px(120, 22), { textSize = 16, font = UI.FontBold })
		UI.Label(row, s.done and "played" or (daysLeft == 0 and "TODAY" or ("in " .. daysLeft .. " days")), UI.px(12, 28), UI.px(120, 20), { textSize = 13, color = T.sub })
		UI.Label(row, v.name, UI.px(138, 6), UI.px(440, 22), { textSize = 17, font = UI.FontBold })
		UI.Label(row, v.city .. ", " .. Countries.byId[v.countryId].name, UI.px(138, 28), UI.px(440, 20), { textSize = 13, color = T.sub })
		local f = math.min(1, s.sold / s.cap)
		local col = f >= 1 and T.gold or (f > 0.7 and T.good or (f > 0.4 and T.warn or T.bad))
		UI.Bar(row, UI.px(588, 12), UI.px(220, 10), f, col)
		UI.Label(row, Util.number(math.min(s.sold, s.cap)) .. " / " .. Util.number(s.cap) .. (f >= 1 and "  SOLD OUT" or ""), UI.px(588, 26), UI.px(300, 22), { textSize = 14, color = col, font = UI.FontBold })
		UI.Label(row, Util.money(s.price), UI.px(888, 0), UI.px(140, 54), { textSize = 16, font = UI.FontBold })
		if s.done and s.result then
			local r = s.result
			UI.Label(row, Util.stars(r.stars) .. "  " .. Util.moneyShort(r.gross), UI.px(1040, 4), UI.px(220, 24), { textSize = 16, font = UI.FontBold, color = T.gold })
			UI.Label(row, "profit " .. Util.moneyShort(r.net), UI.px(1040, 28), UI.px(220, 20), { textSize = 13, color = r.net >= 0 and T.good or T.bad })
		else
			UI.Label(row, s.sold >= s.cap and "waiting for show day" or "tickets on sale", UI.px(1040, 0), UI.px(110, 54), { textSize = 13, color = T.sub, wrap = true })
			-- a show that sells badly can be dropped: the venue is paid anyway, fans are disappointed
			if daysLeft > 0 and (tour.played > 0 or #tour.shows > 1) then
				UI.Button(row, "CANCEL", UI.px(1150, 10), UI.px(80, 34), { color = UI.shade(T.bad, 0.6), textSize = 13 }, function()
					local cost, hype = GS.cancelShowCost(state, tour, i)
					app:confirm("Cancel the show in " .. v.city .. "?", string.format("%s tickets sold so far. The venue still has to be paid (%s) and %s loses hype (-%d). The tickets are refunded. Selling few tickets can also cost money: is it worth it?", Util.number(s.sold), Util.money(cost), ad.name, hype), function()
						local ok, msg = app:act("cancelShow", { tourId = tour.id, idx = i })
						app:toast(msg or "", ok and T.warn or T.bad, 6)
						app:refreshCurrent()
					end)
				end)
			end
		end
		if not s.done then
			local live = not s.skipLive
			UI.Button(row, live and "WATCH" or "auto", UI.px(1236, 10), UI.px(76, 34), { color = live and T.accent or T.panel, textSize = 14 }, function()
				app:act("setLive", { tourId = tour.id, idx = i, live = not live })
				app:refreshCurrent()
			end)
		end
	end
end

return ToursScreen
