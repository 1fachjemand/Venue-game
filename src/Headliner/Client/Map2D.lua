-- A simple flat world map for the tour planner: soft round continents on a light sea and one label
-- ("chip") per country. Not to scale: Europe is bigger so its many countries have room.
-- Map2D.new(parent, pos, size, opts) opts = { onClick(cid), colorFn(cid) -> Color3, countFn(cid) -> n, selected = cid }
local Root = script:FindFirstAncestor("Headliner")
local Countries = require(Root.Data.Countries)
local UI = require(Root.Client.UI)

local T = UI.Theme
local New = UI.New
local Map2D = {}
Map2D.__index = Map2D

Map2D.W, Map2D.H = 1300, 760
local SEA = Color3.fromRGB(200, 224, 244)
local LAND = Color3.fromRGB(240, 236, 222)
local LAND_EDGE = Color3.fromRGB(214, 206, 184)

-- continents: overlapping round shapes { cx, cy, w, h, rotation }
local BLOBS = {
	-- North America
	{ 230, 150, 380, 230, -8 }, { 150, 90, 200, 130, 0 }, { 250, 245, 260, 140, 10 }, { 240, 320, 120, 110, 25 },
	-- South America
	{ 380, 470, 210, 190, 0 }, { 370, 590, 150, 200, 8 }, { 350, 690, 70, 80, 0 },
	-- Europe (big, so the countries fit)
	{ 745, 200, 470, 330, 0 }, { 770, 60, 230, 110, 0 }, { 575, 150, 120, 110, 0 }, { 620, 320, 220, 100, 0 },
	-- Africa
	{ 760, 520, 290, 250, 0 }, { 790, 640, 190, 170, 0 },
	-- Asia
	{ 1080, 220, 420, 280, 0 }, { 1100, 400, 300, 170, 0 }, { 1230, 230, 110, 150, 15 }, { 975, 410, 120, 100, 0 },
	-- Oceania
	{ 1140, 640, 230, 130, 0 }, { 1268, 702, 56, 80, 20 },
}
-- country label positions (centre of the chip)
Map2D.POS = {
	ca = { 220, 95 }, us = { 240, 195 }, mx = { 235, 300 },
	co = { 345, 420 }, br = { 425, 495 }, cl = { 330, 615 }, ar = { 425, 615 },
	no = { 715, 50 }, se = { 830, 50 },
	ie = { 560, 105 }, dk = { 760, 105 }, pl = { 905, 105 },
	uk = { 600, 160 }, nl = { 760, 160 }, de = { 905, 160 },
	be = { 700, 215 }, cz = { 880, 215 },
	fr = { 640, 270 }, ch = { 760, 270 }, at = { 890, 270 },
	pt = { 540, 325 }, es = { 640, 325 }, it = { 830, 325 },
	za = { 790, 640 },
	ae = { 975, 405 }, ["in"] = { 1065, 400 }, th = { 1160, 440 }, sg = { 1170, 505 }, ph = { 1255, 440 },
	kr = { 1185, 255 }, jp = { 1262, 215 },
	au = { 1140, 640 }, nz = { 1268, 705 },
}

function Map2D.new(parent, pos, size, opts)
	local self = setmetatable({ opts = opts or {}, chips = {} }, Map2D)
	-- the map keeps its shape: scaled to fit, centred, sea all around (no sky, no zoom)
	local frame = New("Frame", { Parent = parent, Position = pos, Size = size, BackgroundColor3 = SEA, BorderSizePixel = 0, ClipsDescendants = true, UI.Corner(14) })
	self.frame = frame
	local sc = math.min(size.X.Offset / Map2D.W, size.Y.Offset / Map2D.H)
	local inner = New("Frame", { Parent = frame, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UI.px(Map2D.W, Map2D.H), BackgroundTransparency = 1 })
	New("UIScale", { Parent = inner, Scale = sc })
	self.inner = inner
	-- land: an outline layer (a bit bigger) and the land on top: soft round coasts
	for layer = 1, 2 do
		for _, b in ipairs(BLOBS) do
			local grow = (layer == 1) and 8 or 0
			New("Frame", {
				Parent = inner,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UI.px(b[1], b[2]),
				Size = UI.px(b[3] + grow, b[4] + grow),
				Rotation = b[5],
				BackgroundColor3 = (layer == 1) and LAND_EDGE or LAND,
				BorderSizePixel = 0,
				ZIndex = layer,
				UI.Corner(math.floor(math.min(b[3], b[4]) / 2)),
			})
		end
	end
	for _, c in ipairs(Countries.list) do
		local p = Map2D.POS[c.id]
		if p then
			local w = math.floor(#c.name * 8.6) + 46
			local chip = New("TextButton", {
				Parent = inner,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UI.px(p[1], p[2]),
				Size = UI.px(w, 34),
				BackgroundColor3 = T.panel,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				Text = "",
				ZIndex = 5,
				UI.Corner(17),
			})
			chip.Name = "Country_" .. c.id
			local stroke = UI.Stroke(T.stroke, 2, 0)
			stroke.Parent = chip
			-- dot = fans there (left), the name next to it, badge = shows booked there
			local dot = New("Frame", { Parent = chip, Position = UI.px(10, 11), Size = UI.px(12, 12), BackgroundColor3 = T.sub, BorderSizePixel = 0, ZIndex = 6, UI.Corner(6) })
			local label = New("TextLabel", { Parent = chip, Position = UI.px(28, 0), Size = UI.px(w - 34, 34), BackgroundTransparency = 1, Text = c.name, TextColor3 = T.text, TextSize = 15, Font = UI.FontBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
			local badge = New("TextLabel", { Parent = chip, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UI.px(24, 24), BackgroundColor3 = T.accent, Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = UI.FontBlack, Visible = false, ZIndex = 7, UI.Corner(12) })
			chip.MouseEnter:Connect(function()
				self.hover = c.id
				self:paintChip(c.id)
				if self.opts.onHover then
					self.opts.onHover(c.id)
				end
			end)
			chip.MouseLeave:Connect(function()
				if self.hover == c.id then
					self.hover = nil
				end
				self:paintChip(c.id)
				if self.opts.onHover then
					self.opts.onHover(nil)
				end
			end)
			chip.MouseButton1Click:Connect(function()
				if self.opts.onClick then
					self.opts.onClick(c.id)
				end
			end)
			self.chips[c.id] = { chip = chip, stroke = stroke, dot = dot, badge = badge, label = label }
		end
	end
	self:refresh()
	return self
end

function Map2D:paintChip(cid)
	local ch = self.chips[cid]
	if not ch then
		return
	end
	local sel = self.opts.selected == cid
	local hov = self.hover == cid
	ch.chip.BackgroundColor3 = sel and T.accent or (hov and Color3.fromRGB(232, 240, 255) or T.panel)
	ch.label.TextColor3 = sel and Color3.new(1, 1, 1) or T.text
	ch.stroke.Color = (sel or hov) and T.accent or T.stroke
	ch.dot.BackgroundColor3 = self.opts.colorFn and self.opts.colorFn(cid) or T.sub
	local n = self.opts.countFn and self.opts.countFn(cid) or 0
	ch.badge.Visible = n > 0
	ch.badge.Text = tostring(n)
end

function Map2D:refresh()
	for cid in pairs(self.chips) do
		self:paintChip(cid)
	end
end

function Map2D:setSelected(cid)
	self.opts.selected = cid
	self:refresh()
end

return Map2D
