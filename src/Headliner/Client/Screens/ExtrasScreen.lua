-- EXTRAS (laptop app): things for your tours besides the artist and the stage. For now: background dancers.
-- Sign dancers for your label, see their skill and shows, train them (better, but away for a few days),
-- let them go. On a tour you pick them in the Tour Planner (step Stage).
local Root = script:FindFirstAncestor("Headliner")
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)
local Dancers = require(Root.Data.Dancers)

local T = UI.Theme
local ExtrasScreen = {}
ExtrasScreen.__index = ExtrasScreen

function ExtrasScreen.new(app)
	local self = setmetatable({ app = app, tab = "dancers" }, ExtrasScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundColor3 = T.bg, BorderSizePixel = 0, Visible = false, Name = "Extras" })
	return self
end

function ExtrasScreen:show()
	self:refresh()
end

local STYLE_COLORS = { ["Hip-Hop"] = Color3.fromRGB(234, 88, 12), Contemporary = Color3.fromRGB(14, 165, 233), ["K-Pop"] = Color3.fromRGB(236, 72, 153), Latin = Color3.fromRGB(220, 38, 38), Street = Color3.fromRGB(100, 116, 139), Jazz = Color3.fromRGB(202, 138, 4) }

function ExtrasScreen:card(parent, d, order, mine)
	local app, state = self.app, self.app.state
	local dd = mine and GS.myDancers(state)[d.id]
	local card = UI.New("Frame", { Parent = parent, Name = "Dancer_" .. d.id, LayoutOrder = order, BackgroundColor3 = T.panel, BorderSizePixel = 0, UI.Corner(12), UI.Stroke(T.stroke, 1, 0.3) })
	People.preview(card, d.look, STYLE_COLORS[d.style] or T.accent, UI.px(10, 12), UI.px(120, 180), Color3.fromRGB(30, 34, 50))
	UI.Label(card, d.name, UI.px(142, 12), UI.px(250, 30), { textSize = 22, font = UI.FontBlack })
	UI.Pill(card, d.style, UI.px(142, 46), UI.px(130, 24), STYLE_COLORS[d.style] or T.accent, 13)
	local skill = dd and dd.skill or d.skill
	UI.Label(card, "SKILL", UI.px(142, 82), UI.px(60, 20), { textSize = 13, color = T.sub, font = UI.FontBold })
	UI.Bar(card, UI.px(200, 88), UI.px(150, 8), skill / 100, T.accent2)
	UI.Label(card, tostring(math.floor(skill)), UI.px(354, 80), UI.px(40, 22), { textSize = 16, font = UI.FontBlack })
	UI.Label(card, Util.money(d.perShow) .. " per show", UI.px(142, 108), UI.px(250, 22), { textSize = 15 })
	if mine then
		local busy = GS.dancerBusy(state, d.id)
		UI.Label(card, (dd.shows or 0) .. " shows  |  " .. (busy or "ready"), UI.px(142, 132), UI.px(250, 22), { textSize = 14, color = busy and T.warn or T.good, font = UI.FontBold })
		local cost = Dancers.trainCost(skill)
		UI.Button(card, "TRAIN  " .. Util.moneyShort(cost), UI.px(142, 160), UI.px(150, 40), { color = T.accent, textSize = 14, disabled = busy ~= nil or skill >= 99 }, function()
			app:confirm("Train " .. d.name .. "?", "+" .. Dancers.TRAIN_GAIN .. " skill for " .. Util.money(cost) .. ". " .. d.name .. " can't go on tour for " .. Dancers.TRAIN_DAYS .. " days.", function()
				local ok, msg = app:act("trainDancer", { dancerId = d.id })
				app:toast(msg or "", ok and T.good or T.bad)
				self:refresh()
			end, "Train")
		end).Name = "Train_" .. d.id
		UI.Button(card, "Let go", UI.px(300, 160), UI.px(92, 40), { color = T.panel3, textSize = 13 }, function()
			app:confirm("Let " .. d.name .. " go?", "They leave your label (the signing fee is not paid back).", function()
				local ok, msg = app:act("releaseDancer", { dancerId = d.id })
				app:toast(msg or "", ok and T.warn or T.bad)
				self:refresh()
			end)
		end)
	else
		UI.Button(card, "SIGN  " .. Util.moneyShort(d.fee), UI.px(142, 150), UI.px(250, 48), { color = T.good, textSize = 17, disabled = state.money < d.fee }, function()
			local ok, msg = app:act("signDancer", { dancerId = d.id })
			app:toast(msg or "", ok and T.good or T.bad)
			self:refresh()
		end).Name = "Sign_" .. d.id
	end
end

function ExtrasScreen:refresh()
	local state = self.app.state
	local f = self.frame
	UI.ClearChildren(f)
	UI.Label(f, "Extras", UI.px(40, 24), UI.px(600, 44), { textSize = 34, font = UI.FontBlack })
	UI.Button(f, "DANCERS", UI.px(40, 80), UI.px(180, 44), { color = T.accent, textSize = 16 }, function() end)
	local mine = GS.myDancers(state)
	-- your dancers on the left, the ones you can sign on the right
	local left = UI.Panel(f, UI.px(40, 140), UI.px(900, 850), T.panel2)
	local n = 0
	for _ in pairs(mine) do
		n = n + 1
	end
	UI.Label(left, "YOUR DANCERS  (" .. n .. " / " .. Dancers.MAX_SIGNED .. ")", UI.px(20, 14), UI.px(600, 28), { textSize = 18, font = UI.FontBlack })
	local lg = UI.Scroll(left, UI.px(12, 52), UI.px(876, 786))
	UI.New("UIGridLayout", { CellSize = UI.px(420, 214), CellPadding = UI.px(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = lg })
	local right = UI.Panel(f, UI.px(980, 140), UI.px(900, 850), T.panel2)
	UI.Label(right, "SIGN DANCERS", UI.px(20, 14), UI.px(600, 28), { textSize = 18, font = UI.FontBlack })
	local rg = UI.Scroll(right, UI.px(12, 52), UI.px(876, 786))
	UI.New("UIGridLayout", { CellSize = UI.px(420, 214), CellPadding = UI.px(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rg })
	local li, ri = 0, 0
	for _, d in ipairs(Dancers.list) do
		if mine[d.id] then
			li = li + 1
			self:card(lg, d, li, true)
		else
			ri = ri + 1
			self:card(rg, d, ri, false)
		end
	end
	if li == 0 then
		UI.Label(lg, "No dancers yet.", nil, UI.px(400, 40), { textSize = 18, color = T.sub })
	end
	lg.CanvasSize = UI.px(0, math.ceil(li / 2) * 228 + 10)
	rg.CanvasSize = UI.px(0, math.ceil(ri / 2) * 228 + 10)
end

return ExtrasScreen
