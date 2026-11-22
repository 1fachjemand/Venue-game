-- ARTISTS screen: your roster and the talent scout.
local Root = script:FindFirstAncestor("Headliner")
local Achievements = require(Root.Data.Achievements)
local Config = require(Root.Config)
local Regions = require(Root.Data.Regions)
local Util = require(Root.Logic.Util)
local Sim = require(Root.Logic.Sim)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)
local SoundFX = require(Root.Client.SoundFX)

local T = UI.Theme
local ArtistsScreen = {}
ArtistsScreen.__index = ArtistsScreen

function ArtistsScreen.new(app)
	local self = setmetatable({ app = app, tab = "roster" }, ArtistsScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Artists" })
	self.rosterBtn = UI.Button(self.frame, "YOUR ROSTER", UI.px(20, 12), UI.px(220, 44), {}, function()
		self.tab = "roster"
		self:refresh()
	end)
	self.scoutBtn = UI.Button(self.frame, "TALENT SCOUT", UI.px(250, 12), UI.px(220, 44), {}, function()
		self.tab = "scout"
		self:refresh()
	end)
	self.info = UI.Label(self.frame, "", UI.px(490, 12), UI.px(1400, 44), { textSize = 16, color = T.sub })
	self.grid = UI.Scroll(self.frame, UI.px(20, 68), UI.px(1880, 930))
	UI.New("UIGridLayout", { Parent = self.grid, CellSize = UI.px(452, 392), CellPadding = UI.px(12, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	return self
end

function ArtistsScreen:show(args)
	if args and args.tab then
		self.tab = args.tab
	end
	self:refresh()
end

function ArtistsScreen:card(ad, order)
	local app, state = self.app, self.app.state
	local a = state.artists[ad.id]
	local total = Util.totalFans(a.fans)
	local card = UI.New("Frame", { Parent = self.grid, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, UI.Corner(12), UI.Stroke(T.stroke, 1, 0.3) })
	UI.New("Frame", { Parent = card, Size = UI.px(452, 8), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0, UI.Corner(12) })
	-- the artist as a 3D figure
	People.preview(card, ad.look, UI.rgb(ad.color), UI.px(12, 20), UI.px(150, 230), Color3.fromRGB(30, 34, 50))
	UI.Label(card, ad.name, UI.px(176, 18), UI.px(264, 36), { textSize = 28, font = UI.FontBlack })
	local members = ad.members > 1 and (ad.members .. " members") or "Solo"
	UI.Label(card, ad.genre .. "  |  " .. members, UI.px(176, 54), UI.px(264, 22), { textSize = 16, color = UI.rgb(ad.color), font = UI.FontBold })
	UI.Label(card, Util.tier(total), UI.px(176, 78), UI.px(264, 22), { textSize = 15, color = T.sub })
	local function stat(y, label, frac, txt, col)
		UI.Label(card, label, UI.px(176, y), UI.px(70, 22), { textSize = 14, color = T.sub, font = UI.FontBold })
		UI.Bar(card, UI.px(246, y + 7), UI.px(130, 8), frac, col)
		UI.Label(card, txt, UI.px(380, y), UI.px(60, 22), { textSize = 15, font = UI.FontBold, alignX = Enum.TextXAlignment.Right })
	end
	stat(112, "FANS", math.min(1, math.log10(1 + total / 10000) / 4), Util.short(total), T.good)
	stat(140, "SKILL", ad.skill / 100, tostring(ad.skill), T.accent2)
	stat(168, "HYPE", a.hype / 100, tostring(math.floor(a.hype)), T.accent)
	local best, n = "EU", -1
	for rid, f in pairs(a.fans) do
		if f > n then
			best, n = rid, f
		end
	end
	UI.Label(card, "Biggest in " .. Regions.byId[best].name, UI.px(176, 198), UI.px(264, 22), { textSize = 15 })
	UI.Label(card, "Tickets ~" .. Util.money(Sim.fairPrice(state, ad.id, "uk")), UI.px(176, 222), UI.px(264, 22), { textSize = 15, color = T.sub })
	UI.Label(card, ad.bio, UI.px(18, 262), UI.px(330, 44), { textSize = 15, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
	UI.Button(card, "> Listen", UI.px(354, 264), UI.px(80, 36), { textSize = 14 }, function()
		if not SoundFX.preview(ad.id) then
			app:toast("Music is not uploaded yet (see audio/README.md).", T.warn, 4)
		end
	end)

	if a.signed then
		local tour = GS.activeTour(state, ad.id)
		if tour then
			UI.Button(card, "ON TOUR: " .. tour.name, UI.px(18, 326), UI.px(416, 52), { color = T.panel3, textSize = 16 }, function()
				app:go("tours", { tourId = tour.id })
			end)
		else
			UI.Button(card, "+ PLAN A TOUR", UI.px(18, 326), UI.px(416, 52), { color = T.accent, textSize = 18 }, function()
				app:go("planner", { artistId = ad.id })
			end)
		end
	else
		local lvl = GS.level(state)
		local afford = state.money >= ad.signCost and ad.level <= lvl
		local txt = ad.level > lvl and ("LOCKED - needs " .. Config.LEVELS[ad.level].name .. " (Lv " .. ad.level .. ")") or ("SIGN FOR " .. Util.money(ad.signCost))
		UI.Button(card, txt, UI.px(18, 326), UI.px(416, 52), { color = afford and T.good or T.panel3, disabled = not afford, textSize = 16 }, function()
			app:confirm("Sign " .. ad.name .. "?", "Signing costs <b>" .. Util.money(ad.signCost) .. "</b>. Then you can book their tours.", function()
				local ok, msg, data = app:act("sign", { artistId = ad.id })
				app:toast(msg or "", ok and T.good or T.bad)
				for _, id in ipairs((data and data.achievements) or {}) do
					app:achievementToast(id)
				end
				app:refreshCurrent()
			end)
		end)
	end
end

function ArtistsScreen:refresh()
	UI.ClearChildren(self.grid)
	local state = self.app.state
	self.rosterBtn.BackgroundColor3 = self.tab == "roster" and T.accent or T.panel3
	self.scoutBtn.BackgroundColor3 = self.tab == "scout" and T.accent or T.panel3
	local list
	if self.tab == "roster" then
		list = GS.signedArtists(state)
		self.info.Text = "Your signed artists. Bigger fanbases sell bigger venues. Good shows win new fans and hype."
	else
		list = GS.unsignedArtists(state)
		self.info.Text = "Unsigned artists you can sign. Bigger stars cost more but can fill arenas and stadiums."
		if #list == 0 then
			self.info.Text = "You signed everyone. What a label!"
		end
	end
	for i, ad in ipairs(list) do
		self:card(ad, i)
	end
end

return ArtistsScreen
