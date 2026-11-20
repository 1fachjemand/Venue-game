-- LIVE SHOWS board (in the corridor of the offices): the next shows of the other players in this server.
-- WATCH takes you into the venue of that show: their artist on their stage, you walk around in the crowd.
local Root = script:FindFirstAncestor("Headliner")
local Artists = require(Root.Data.Artists)
local Countries = require(Root.Data.Countries)
local Util = require(Root.Logic.Util)
local UI = require(Root.Client.UI)

local T = UI.Theme
local LiveShowsScreen = {}
LiveShowsScreen.__index = LiveShowsScreen

function LiveShowsScreen.new(app)
	local self = setmetatable({ app = app }, LiveShowsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "LiveShows" })
	local panel = UI.Panel(self.frame, UI.px(260, 12), UI.px(1400, 984))
	UI.Label(panel, "LIVE SHOWS OF OTHER LABELS", UI.px(28, 16), UI.px(1000, 40), { textSize = 30, font = UI.FontBlack, color = T.bad })
	UI.Label(panel, "The next show of every tour of the other players in this server. WATCH takes you into the venue: their artist on their stage.", UI.px(28, 60), UI.px(1340, 26), { textSize = 17, color = T.sub })
	self.list = UI.Scroll(panel, UI.px(16, 100), UI.px(1368, 870))
	UI.List(true, 10).Parent = self.list
	return self
end

function LiveShowsScreen:show()
	self:refresh()
end

function LiveShowsScreen:refresh()
	UI.ClearChildren(self.list)
	UI.List(true, 10).Parent = self.list
	local res = self.app:call("liveShows", {})
	local shows = (res.ok and type(res.data) == "table" and res.data.shows) or {}
	self.shows = shows
	if #shows == 0 then
		UI.Label(self.list, "No other label has a tour running right now. Play with friends: up to 5 labels share this building, every player has an own office.", nil, UI.px(1300, 60), { textSize = 19, color = T.sub, wrap = true })
		return
	end
	for i, sh in ipairs(shows) do
		local ad = Artists.byId[sh.artistId or ""]
		local v = Countries.venueById[sh.venueId or ""]
		local row = UI.New("Frame", { Parent = self.list, Size = UI.px(1340, 110), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(12) })
		UI.New("Frame", { Parent = row, Size = UI.px(10, 110), BackgroundColor3 = ad and UI.rgb(ad.color) or T.accent, BorderSizePixel = 0 })
		UI.Label(row, string.upper(tostring(sh.label or "")) .. "   |   " .. tostring(sh.player or ""), UI.px(28, 10), UI.px(800, 24), { textSize = 15, color = T.sub, font = UI.FontBold })
		UI.Label(row, (ad and ad.name or "?") .. "  -  " .. tostring(sh.tourName or ""), UI.px(28, 36), UI.px(900, 34), { textSize = 26, font = UI.FontBlack })
		local when = (sh.inDays or 0) <= 0 and "TONIGHT" or ("in " .. sh.inDays .. " day" .. (sh.inDays == 1 and "" or "s"))
		UI.Label(row, (v and (v.name .. ", " .. v.city) or "") .. "   |   " .. when .. "   |   " .. Util.number(sh.sold or 0) .. " / " .. Util.number(sh.cap or 0) .. " tickets", UI.px(28, 74), UI.px(1000, 24), { textSize = 17, color = T.text })
		local b = UI.Button(row, "WATCH", UI.px(1150, 28), UI.px(170, 56), { color = T.accent, textSize = 20, disabled = not (ad and v and sh.design) }, function()
			self:watch(sh)
		end)
		b.Name = "Watch" .. i
	end
end

-- into the venue of another label's show (nothing changes in your own game)
function LiveShowsScreen:watch(sh)
	local app = self.app
	local ad = Artists.byId[sh.artistId or ""]
	local v = Countries.venueById[sh.venueId or ""]
	if not ad or not v or type(sh.design) ~= "table" or type(sh.design.items) ~= "table" then
		return
	end
	app:closeScreen()
	local LiveShow = require(Root.Client.LiveShow)
	local closeLoading = app:showLoading(string.upper(ad.name), "Visiting " .. tostring(sh.label) .. ": " .. v.name .. ", " .. v.city)
	app.inShow = true
	LiveShow.run(app, {
		artistId = ad.id,
		design = sh.design,
		venueId = v.id,
		sold = math.max(sh.sold or 0, math.floor((sh.cap or v.cap) * 0.5)),
		tourName = tostring(sh.tourName or ""),
		walk = true,
		preview = true,
		onDone = function()
			app.inShow = false
			app:closeScreen()
		end,
	})
	task.delay(1.2, closeLoading)
end

return LiveShowsScreen
