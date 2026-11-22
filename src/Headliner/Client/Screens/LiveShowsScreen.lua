-- LIVE SHOWS board (in the office wing): the shows of the other players in this server.
-- A show that is on right now: JOIN takes you into it at the same moment as its player (same show, same
-- songs). A show that is still coming: REMIND ME, and you get a message when it starts.
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
	app.reminders = app.reminders or {}
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "LiveShows" })
	local panel = UI.Panel(self.frame, UI.px(360, 40), UI.px(1200, 930))
	UI.Label(panel, "LIVE SHOWS", UI.px(32, 22), UI.px(800, 44), { textSize = 34, font = UI.FontBlack, color = T.bad })
	self.list = UI.Scroll(panel, UI.px(20, 90), UI.px(1160, 820))
	UI.List(true, 12).Parent = self.list
	return self
end

function LiveShowsScreen:show()
	self:refresh()
end

function LiveShowsScreen:refresh()
	UI.ClearChildren(self.list)
	UI.List(true, 12).Parent = self.list
	local res = self.app:call("liveShows", {})
	local shows = (res.ok and type(res.data) == "table" and res.data.shows) or {}
	self.shows = shows
	if #shows == 0 then
		UI.Label(self.list, "No shows right now.", nil, UI.px(1120, 60), { textSize = 22, color = T.sub })
		return
	end
	for i, sh in ipairs(shows) do
		local ad = Artists.byId[sh.artistId or ""]
		local v = Countries.venueById[sh.venueId or ""]
		local row = UI.New("Frame", { Parent = self.list, Name = "Show" .. i, Size = UI.px(1136, 116), BackgroundColor3 = T.panel2, BorderSizePixel = 0, LayoutOrder = i, UI.Corner(14) })
		UI.New("Frame", { Parent = row, Size = UI.px(12, 116), BackgroundColor3 = ad and UI.rgb(ad.color) or T.accent, BorderSizePixel = 0 })
		-- the artist and the venue big, the label and the player small underneath
		UI.Label(row, ad and ad.name or "?", UI.px(34, 12), UI.px(700, 40), { textSize = 30, font = UI.FontBlack })
		UI.Label(row, v and (v.name .. ", " .. v.city) or "", UI.px(34, 52), UI.px(700, 26), { textSize = 20 })
		UI.Label(row, tostring(sh.label or "") .. "  (" .. tostring(sh.player or "") .. ")", UI.px(34, 80), UI.px(700, 24), { textSize = 16, color = T.sub })
		local ok = ad and v and sh.design
		if sh.live then
			UI.Pill(row, "LIVE NOW", UI.px(760, 40), UI.px(130, 36), T.bad, 16)
			UI.Button(row, "JOIN", UI.px(910, 28), UI.px(206, 60), { color = T.bad, textSize = 24, disabled = not ok }, function()
				self:watch(sh)
			end).Name = "Join" .. i
		else
			local d = sh.inDays or 0
			UI.Label(row, (d <= 0) and "today" or ("in " .. d .. " day" .. (d == 1 and "" or "s")), UI.px(740, 0), UI.px(160, 116), { textSize = 20, color = T.sub, alignX = Enum.TextXAlignment.Right })
			local on = self.app.reminders[sh.key] ~= nil
			UI.Button(row, on and "REMINDER ON" or "REMIND ME", UI.px(910, 28), UI.px(206, 60), { color = on and T.good or T.accent, textSize = 20 }, function()
				if self.app.reminders[sh.key] then
					self.app.reminders[sh.key] = nil
				else
					self.app.reminders[sh.key] = { label = sh.label, artistId = sh.artistId }
				end
				self:refresh()
			end).Name = "Remind" .. i
		end
	end
end

-- into another label's show that is on right now, at the same moment as its player (nothing changes in your game)
function LiveShowsScreen.join(app, sh)
	local ad = Artists.byId[sh.artistId or ""]
	local v = Countries.venueById[sh.venueId or ""]
	if not ad or not v or type(sh.design) ~= "table" or type(sh.design.items) ~= "table" then
		return
	end
	if app.inShow then
		return
	end
	app:closeScreen()
	local LiveShow = require(Root.Client.LiveShow)
	local closeLoading = app:showLoading(string.upper(ad.name), v.name .. ", " .. v.city)
	app.inShow = true
	LiveShow.run(app, {
		artistId = ad.id,
		design = sh.design,
		venueId = v.id,
		sold = math.max(sh.sold or 0, math.floor((sh.cap or v.cap) * 0.5)),
		tourName = tostring(sh.tourName or ""),
		tourId = sh.tourId,
		dancers = sh.dancers,
		seed = sh.seed,
		startAt = (sh.elapsed or 0) + 1.2,
		walk = true,
		onDone = function()
			app.inShow = false
			app:closeScreen()
		end,
	})
	task.delay(1.2, closeLoading)
end
function LiveShowsScreen:watch(sh)
	LiveShowsScreen.join(self.app, sh)
end

-- reminders: while you play, the board is checked every few seconds; a show you wanted starts = a message
-- (click it to join)
function LiveShowsScreen.watchReminders(app)
	if app.reminderLoop then
		return
	end
	app.reminderLoop = true
	task.spawn(function()
		while app.reminderLoop do
			task.wait(6)
			if app.state and next(app.reminders or {}) and not app.inShow then
				local ok, res = pcall(function()
					return app:call("liveShows", {})
				end)
				local shows = (ok and res and res.ok and type(res.data) == "table" and res.data.shows) or {}
				for _, sh in ipairs(shows) do
					if sh.live and app.reminders[sh.key] then
						app.reminders[sh.key] = nil
						local ad = Artists.byId[sh.artistId or ""]
						app:toast("<b>LIVE NOW:</b> " .. UI.esc(ad and ad.name or "") .. " (" .. UI.esc(tostring(sh.label or "")) .. ")<br/><font color='#dc2626'><b>Click to join</b></font>", T.bad, 20, function()
							LiveShowsScreen.join(app, sh)
						end)
					end
				end
			end
		end
	end)
end

return LiveShowsScreen
