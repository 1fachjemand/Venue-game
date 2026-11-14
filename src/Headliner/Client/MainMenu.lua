-- Title screen: menu on the left, a famous venue at night on the right (see MenuScene).
-- New game: name your label, then pick your first artist.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)
local MenuScene = require(Root.Client.MenuScene)
local Venue = require(Root.Client.Venue)

local T = UI.Theme
local MainMenu = {}

local PANEL_W = 600

-- onStart(state, isNew)
function MainMenu.show(app, saved, onStart)
	app.backdrop.Visible = false
	app.settings = app.settings or { music = 80, effects = 80, crowd = "High" }
	local root = UI.New("Frame", { Parent = app.canvas, Name = "MainMenu", Size = UI.px(1920, 1080), BackgroundTransparency = 1 })
	-- left column with a soft fade into the 3D scene
	local column = UI.New("Frame", {
		Parent = root,
		Size = UI.px(PANEL_W + 220, 1080),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
		UI.New("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		}),
	})
	local body = UI.New("Frame", { Parent = root, Size = UI.px(PANEL_W, 1080), BackgroundTransparency = 1 })
	-- caption of the venue on screen
	local caption = UI.New("Frame", { Parent = root, Position = UI.px(1360, 930), Size = UI.px(520, 110), BackgroundColor3 = T.panel, BackgroundTransparency = 0.25, BorderSizePixel = 0, UI.Corner(12) })
	local capName = UI.Label(caption, "", UI.px(20, 10), UI.px(480, 36), { textSize = 28, font = UI.FontBlack })
	local capCity = UI.Label(caption, "", UI.px(20, 46), UI.px(480, 24), { textSize = 17, color = T.sub })
	local capTonight = UI.Label(caption, "", UI.px(20, 74), UI.px(480, 26), { textSize = 17, font = UI.FontBold, color = T.accent2 })
	MenuScene.start(function(scene)
		capName.Text = scene.name
		capCity.Text = scene.city
		capTonight.Text = "Tonight: " .. scene.tonight .. "  -  SOLD OUT"
	end)

	local labelName = Config.DEFAULT_LABEL_NAME
	local function clear()
		UI.ClearChildren(body)
	end
	local function logo()
		UI.Label(body, "HEADLINER", UI.px(64, 96), UI.px(680, 90), { textSize = 72, font = UI.FontBlack, color = T.text })
		UI.New("Frame", { Parent = body, Position = UI.px(68, 186), Size = UI.px(150, 6), BackgroundColor3 = T.accent, BorderSizePixel = 0, UI.Corner(3) })
		UI.Label(body, Config.SUBTITLE, UI.px(68, 200), UI.px(PANEL_W - 68, 30), { textSize = 22, color = T.sub })
	end
	local function menuButton(y, text, sub, primary, onClick, disabled)
		local b = UI.Button(body, "", UI.px(64, y), UI.px(440, sub and 76 or 62), { color = primary and T.accent or T.panel2, disabled = disabled }, onClick)
		UI.Label(b, text, UI.px(24, sub and 8 or 0), UI.px(400, sub and 36 or 62), { textSize = 24, font = UI.FontBlack, color = disabled and T.sub or T.text })
		if sub then
			UI.Label(b, sub, UI.px(24, 44), UI.px(400, 22), { textSize = 15, color = primary and Color3.fromRGB(225, 225, 255) or T.sub })
		end
		return b
	end

	local home, nameStep, pickArtist, settingsPage, storePage, creditsPage

	nameStep = function()
		clear()
		logo()
		UI.Label(body, "NEW GAME  -  1 / 2", UI.px(64, 300), UI.px(440, 26), { textSize = 16, color = T.accent2, font = UI.FontBold })
		UI.Label(body, "Name your label", UI.px(64, 330), UI.px(460, 44), { textSize = 34, font = UI.FontBlack })
		local box = UI.New("TextBox", {
			Parent = body,
			Position = UI.px(64, 392),
			Size = UI.px(440, 70),
			BackgroundColor3 = T.panel2,
			BorderSizePixel = 0,
			Text = labelName,
			PlaceholderText = "Label name",
			ClearTextOnFocus = false,
			TextColor3 = T.text,
			TextSize = 30,
			Font = UI.FontBlack,
			UI.Corner(10),
			UI.Stroke(T.accent, 2, 0),
		})
		UI.Label(body, "This is the name of your office and your record label.", UI.px(64, 470), UI.px(440, 44), { textSize = 16, color = T.sub, wrap = true })
		UI.Button(body, "< Back", UI.px(64, 540), UI.px(150, 60), { textSize = 20 }, function()
			home()
		end)
		UI.Button(body, "NEXT >", UI.px(224, 540), UI.px(280, 60), { color = T.accent, textSize = 22 }, function()
			local txt = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
			labelName = (#txt > 0) and txt:sub(1, 28) or Config.DEFAULT_LABEL_NAME
			pickArtist()
		end)
	end

	pickArtist = function()
		clear()
		logo()
		UI.Label(body, "NEW GAME  -  2 / 2", UI.px(64, 280), UI.px(440, 26), { textSize = 16, color = T.accent2, font = UI.FontBold })
		UI.Label(body, "Sign your first artist", UI.px(64, 306), UI.px(500, 44), { textSize = 32, font = UI.FontBlack })
		UI.Label(body, "Free. Everyone starts small - grow your label to unlock bigger stars.", UI.px(64, 350), UI.px(500, 24), { textSize = 15, color = T.sub })
		local y = 390
		for _, ad in ipairs(Artists.list) do
			if ad.starter then
				local card = UI.Panel(body, UI.px(64, y), UI.px(500, 150), T.panel2)
				UI.New("Frame", { Parent = card, Size = UI.px(8, 150), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0, UI.Corner(4) })
				People.preview(card, ad.look, UI.rgb(ad.color), UI.px(14, 6), UI.px(96, 138))
				UI.Label(card, ad.name, UI.px(118, 10), UI.px(240, 34), { textSize = 26, font = UI.FontBlack })
				UI.Label(card, ad.genre .. (ad.members > 1 and ("  |  " .. ad.members .. "-piece band") or "  |  Solo"), UI.px(118, 44), UI.px(240, 22), { textSize = 15, color = UI.rgb(ad.color), font = UI.FontBold })
				UI.Label(card, ad.bio, UI.px(118, 70), UI.px(230, 40), { textSize = 14, color = T.sub, wrap = true, alignY = Enum.TextYAlignment.Top })
				UI.Label(card, Util.short(Util.totalFans(ad.fans)) .. " fans  |  skill " .. ad.skill, UI.px(118, 116), UI.px(240, 22), { textSize = 14, font = UI.FontBold })
				UI.Button(card, "SIGN", UI.px(366, 50), UI.px(118, 50), { color = T.accent, textSize = 20 }, function()
					MenuScene.stop()
					root:Destroy()
					onStart(GS.new(labelName, ad.id), true)
				end)
				y = y + 162
			end
		end
		UI.Button(body, "< Back", UI.px(64, y + 6), UI.px(150, 52), { textSize = 18 }, function()
			nameStep()
		end)
	end

	settingsPage = function()
		clear()
		logo()
		UI.Label(body, "SETTINGS", UI.px(64, 300), UI.px(440, 40), { textSize = 30, font = UI.FontBlack })
		local s = app.settings
		local function slider(y, label, key)
			UI.Label(body, label, UI.px(64, y), UI.px(240, 30), { textSize = 18, font = UI.FontBold })
			UI.Button(body, "-", UI.px(264, y), UI.px(40, 30), {}, function()
				s[key] = math.max(0, s[key] - 10)
				settingsPage()
			end)
			UI.Bar(body, UI.px(312, y + 11), UI.px(140, 8), s[key] / 100, T.accent2)
			UI.Button(body, "+", UI.px(460, y), UI.px(40, 30), {}, function()
				s[key] = math.min(100, s[key] + 10)
				settingsPage()
			end)
		end
		slider(360, "Music volume", "music")
		slider(406, "Effects volume", "effects")
		UI.Label(body, "Music arrives in a later update.", UI.px(64, 442), UI.px(440, 22), { textSize = 14, color = T.sub })
		UI.Label(body, "Crowd detail in shows", UI.px(64, 486), UI.px(440, 26), { textSize = 18, font = UI.FontBold })
		for i, lvl in ipairs({ "Low", "Medium", "High" }) do
			UI.Button(body, lvl, UI.px(64 + (i - 1) * 148, 518), UI.px(140, 44), { color = (s.crowd == lvl) and T.accent or T.panel3, textSize = 17 }, function()
				s.crowd = lvl
				Venue.setDetail(lvl)
				settingsPage()
			end)
		end
		UI.Button(body, "< Back", UI.px(64, 600), UI.px(200, 56), { textSize = 20 }, function()
			home()
		end)
	end

	storePage = function()
		clear()
		logo()
		UI.Label(body, "STORE", UI.px(64, 300), UI.px(440, 40), { textSize = 30, font = UI.FontBlack })
		local items = { "Stage skins & special effects", "Exclusive artist outfits", "Iconic venue packs" }
		for i, it in ipairs(items) do
			local card = UI.Panel(body, UI.px(64, 350 + (i - 1) * 76), UI.px(440, 66), T.panel2)
			UI.Label(card, it, UI.px(18, 0), UI.px(300, 66), { textSize = 17, font = UI.FontBold })
			UI.Pill(card, "SOON", UI.px(350, 20), UI.px(70, 26), T.accent, 13)
		end
		UI.Label(body, "The store opens in a later update.", UI.px(64, 588), UI.px(440, 24), { textSize = 15, color = T.sub })
		UI.Button(body, "< Back", UI.px(64, 630), UI.px(200, 56), { textSize = 20 }, function()
			home()
		end)
	end

	creditsPage = function()
		clear()
		logo()
		UI.Label(body, "CREDITS", UI.px(64, 300), UI.px(440, 40), { textSize = 30, font = UI.FontBlack })
		UI.Label(body, "Game idea & design: you\nBuilt with Claude\n\nVenues and artists are fictional parodies.\nCountry borders: Natural Earth (public domain).\nVenue capacities: Wikipedia.", UI.px(64, 350), UI.px(470, 200), { textSize = 17, wrap = true, alignY = Enum.TextYAlignment.Top })
		UI.Button(body, "< Back", UI.px(64, 580), UI.px(200, 56), { textSize = 20 }, function()
			home()
		end)
	end

	home = function()
		clear()
		logo()
		local y = 320
		if saved then
			menuButton(y, "CONTINUE", saved.labelName .. "  -  " .. Util.date(saved.day, Config.START_YEAR) .. "  -  " .. Util.money(saved.money), true, function()
				MenuScene.stop()
				root:Destroy()
				onStart(saved, false)
			end)
			y = y + 92
		end
		menuButton(y, "NEW GAME", nil, saved == nil, function()
			if saved then
				app:confirm("Start over?", "A new game replaces your saved label <b>" .. UI.esc(saved.labelName) .. "</b> the next time the game saves.", nameStep)
			else
				nameStep()
			end
		end)
		y = y + 78
		menuButton(y, "STORE", nil, false, storePage)
		y = y + 78
		menuButton(y, "SETTINGS", nil, false, settingsPage)
		y = y + 78
		menuButton(y, "CREDITS", nil, false, creditsPage)
		if not app.saveAvailable then
			UI.Label(body, "Saving only works when the place is published to Roblox. In a local file, progress resets when you stop the game.", UI.px(64, 980), UI.px(470, 50), { textSize = 14, color = T.warn, wrap = true })
		end
	end

	MainMenu.home = home
	home()
end

return MainMenu
