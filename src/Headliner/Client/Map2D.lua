-- The world map of the tour planner: a real top-down map (Natural Earth borders, Data/WorldMap2D.lua,
-- made by tools/gen_map2d.py) on a light sea. Only the continents and the big islands are drawn.
-- The countries you can tour are lighter; under the mouse they light up, a click opens them.
-- Mouse wheel / + - zoom, drag moves the map; it always fills the frame (no empty sky around it).
-- Map2D.new(parent, pos, size, opts) opts = { onClick(cid), onHover(cid), colorFn(cid) -> Color3, countFn(cid) -> n, selected = cid }
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Countries = require(Root.Data.Countries)
local MapData = require(Root.Data.WorldMap2D)
local UI = require(Root.Client.UI)

local T = UI.Theme
local New = UI.New
local Map2D = {}
Map2D.__index = Map2D

local SEA = Color3.fromRGB(198, 222, 242)
local TONES = { Color3.fromRGB(226, 221, 204), Color3.fromRGB(216, 211, 193), Color3.fromRGB(222, 215, 196), Color3.fromRGB(210, 206, 190) }
-- playable countries: light (neighbours a bit different), under the mouse: glowing blue, chosen: blue
local PLAY = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(236, 243, 252), Color3.fromRGB(252, 246, 232) }
local HOVER = Color3.fromRGB(147, 197, 253)
local MAXZOOM = 7

-- grid cell -> playable country (rows -> list of { c0, c1, cid })
local rowIndex = nil
local function buildIndex()
	rowIndex = {}
	for _, layer in ipairs(MapData.layers) do
		if layer.cid then
			local r = layer.r
			for k = 1, #r, 4 do
				local row, col, w, h = r[k], r[k + 1], r[k + 2], r[k + 3]
				for j = row, row + h - 1 do
					local list = rowIndex[j]
					if not list then
						list = {}
						rowIndex[j] = list
					end
					table.insert(list, { col, col + w - 1, layer.cid })
				end
			end
		end
	end
end
function Map2D.countryAt(col, row)
	if not rowIndex then
		buildIndex()
	end
	for _, e in ipairs(rowIndex[row] or {}) do
		if col >= e[1] and col <= e[2] then
			return e[3]
		end
	end
	return nil
end

-- longitude / latitude -> map cell (x, y)
function Map2D.cell(lon, lat)
	if lon < MapData.LON0 then
		lon = lon + 360
	end
	return (lon - MapData.LON0) * MapData.RES, (MapData.LAT_TOP - lat) * MapData.RES
end

function Map2D.new(parent, pos, size, opts)
	local self = setmetatable({ opts = opts or {}, chips = {}, layers = {}, zoom = 1 }, Map2D)
	local fw, fh = size.X.Offset, size.Y.Offset
	self.fw, self.fh = fw, fh
	local frame = New("Frame", { Parent = parent, Position = pos, Size = size, BackgroundColor3 = SEA, BorderSizePixel = 0, ClipsDescendants = true, UI.Corner(14) })
	frame.Name = "WorldMap"
	self.frame = frame
	-- the map itself (1 px = 1 cell, scaled by UIScale)
	local inner = New("Frame", { Parent = frame, Size = UI.px(MapData.W, MapData.H), BackgroundTransparency = 1 })
	self.scale = New("UIScale", { Parent = inner, Scale = 1 })
	self.inner = inner
	for li, layer in ipairs(MapData.layers) do
		local holder = New("Folder", { Parent = inner, Name = layer.cid and ("Land_" .. layer.cid) or ("Land" .. li) })
		local col = layer.cid and PLAY[layer.tone or 1] or TONES[layer.tone or 1]
		local frames = {}
		local r = layer.r
		for k = 1, #r, 4 do
			-- a hair bigger than the cell, so no thin gaps show between the pieces at any zoom
			table.insert(frames, New("Frame", { Parent = holder, Position = UI.px(r[k + 1], r[k]), Size = UI.px(r[k + 2] + 0.5, r[k + 3] + 0.5), BackgroundColor3 = col, BorderSizePixel = 0 }))
		end
		if layer.cid then
			self.layers[layer.cid] = { frames = frames, base = col, lon = layer.lon, lat = layer.lat, cells = 0 }
			for k = 1, #r, 4 do
				self.layers[layer.cid].cells = self.layers[layer.cid].cells + r[k + 2] * r[k + 3]
			end
		end
	end
	-- the mouse: hover, click, drag, wheel (one transparent button over the map)
	local catcher = New("TextButton", { Parent = frame, Name = "MapInput", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 })
	self.catcher = catcher
	-- labels (not scaled: they stay readable at every zoom)
	self.labels = New("Frame", { Parent = frame, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4 })
	for _, c in ipairs(Countries.list) do
		local L = self.layers[c.id]
		if L then
			local w = math.floor(#c.name * 8.8) + 38
			local chip = New("TextButton", { Parent = self.labels, AnchorPoint = Vector2.new(0.5, 0.5), Size = UI.px(w, 26), BackgroundColor3 = T.panel, BackgroundTransparency = 0.08, AutoButtonColor = false, BorderSizePixel = 0, Text = "", ZIndex = 5, UI.Corner(13) })
			chip.Name = "Country_" .. c.id
			local stroke = UI.Stroke(T.stroke, 1, 0)
			stroke.Parent = chip
			local dot = New("Frame", { Parent = chip, Position = UI.px(8, 8), Size = UI.px(10, 10), BackgroundColor3 = T.sub, BorderSizePixel = 0, ZIndex = 6, UI.Corner(5) })
			local label = New("TextLabel", { Parent = chip, Position = UI.px(22, 0), Size = UI.px(w - 26, 26), BackgroundTransparency = 1, Text = c.name, TextColor3 = T.text, TextSize = 13, Font = UI.FontBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 })
			local badge = New("TextLabel", { Parent = chip, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UI.px(22, 22), BackgroundColor3 = T.accent, Text = "", TextColor3 = Color3.new(1, 1, 1), TextSize = 12, Font = UI.FontBlack, Visible = false, ZIndex = 7, UI.Corner(11) })
			chip.MouseEnter:Connect(function()
				self:setHover(c.id)
			end)
			chip.MouseLeave:Connect(function()
				if self.hover == c.id then
					self:setHover(nil)
				end
			end)
			chip.MouseButton1Click:Connect(function()
				if self.opts.onClick then
					self.opts.onClick(c.id)
				end
			end)
			local cx, cy = Map2D.cell(L.lon, L.lat)
			self.chips[c.id] = { chip = chip, stroke = stroke, dot = dot, badge = badge, label = label, cx = cx, cy = cy, w = w }
		end
	end
	-- zoom buttons
	local zb = New("Frame", { Parent = frame, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UI.px(44, 96), BackgroundTransparency = 1, ZIndex = 8 })
	UI.Button(zb, "+", UI.px(0, 0), UI.px(44, 44), { color = T.panel, textSize = 24 }, function()
		self:zoomAt(self.zoom * 1.5, fw / 2, fh / 2)
	end).ZIndex = 8
	UI.Button(zb, "-", UI.px(0, 52), UI.px(44, 44), { color = T.panel, textSize = 24 }, function()
		self:zoomAt(self.zoom / 1.5, fw / 2, fh / 2)
	end).ZIndex = 8
	for _, b in ipairs(zb:GetChildren()) do
		if b:IsA("TextButton") then
			b.Name = (b.Text == "+") and "ZoomIn" or "ZoomOut"
		end
	end
	-- start: the whole height of the map, Europe and the Americas in view
	self.base = math.max(fw / MapData.W, fh / MapData.H)
	local ex = Map2D.cell(-35, 0)
	self.panX = fw / 2 - ex * self.base
	self.panY = 0
	self:layout()

	local function mouseLocal()
		local m = UserInputService:GetMouseLocation()
		local a = frame.AbsolutePosition
		local sc = (frame.AbsoluteSize.X > 0) and (frame.AbsoluteSize.X / fw) or 1
		return (m.X - a.X) / sc, (m.Y - a.Y) / sc
	end
	self.mouseLocal = mouseLocal
	catcher.MouseMoved:Connect(function()
		local x, y = mouseLocal()
		if self.drag then
			local dx, dy = x - self.drag.x, y - self.drag.y
			if math.abs(dx) + math.abs(dy) > 6 then
				self.drag.moved = true
			end
			if self.drag.moved then
				self.panX, self.panY = self.drag.px + dx, self.drag.py + dy
				self:layout()
			end
			return
		end
		self:setHover(self:countryAtPoint(x, y))
	end)
	catcher.MouseLeave:Connect(function()
		self.drag = nil
		self:setHover(nil)
	end)
	catcher.MouseButton1Down:Connect(function()
		local x, y = mouseLocal()
		self.drag = { x = x, y = y, px = self.panX, py = self.panY, moved = false }
	end)
	catcher.MouseButton1Up:Connect(function()
		local d = self.drag
		self.drag = nil
		if d and not d.moved then
			local x, y = mouseLocal()
			local cid = self:countryAtPoint(x, y)
			if cid and self.opts.onClick then
				self.opts.onClick(cid)
			end
		end
	end)
	catcher.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local x, y = mouseLocal()
			self:zoomAt(self.zoom * ((input.Position.Z > 0) and 1.25 or 0.8), x, y)
		end
	end)
	self:refresh()
	return self
end

-- the country under a point of the frame (frame pixels)
function Map2D:countryAt(x, y)
	return self:countryAtPoint(x, y)
end
function Map2D:countryAtPoint(x, y)
	local s = self.base * self.zoom
	local col = math.floor((x - self.panX) / s)
	local row = math.floor((y - self.panY) / s)
	if row < 0 or row >= MapData.H or col < 0 or col >= MapData.W then
		return nil
	end
	return Map2D.countryAt(col, row)
end

-- zoom around a point of the frame, keep the map inside the frame
function Map2D:zoomAt(z, x, y)
	z = math.clamp(z, 1, MAXZOOM)
	local s0 = self.base * self.zoom
	local s1 = self.base * z
	-- the point under the mouse stays where it is
	local mx, my = (x - self.panX) / s0, (y - self.panY) / s0
	self.zoom = z
	self.panX, self.panY = x - mx * s1, y - my * s1
	self:layout()
end

-- centre the map on a country (zoom in a bit)
function Map2D:focus(cid, z)
	local ch = self.chips[cid]
	if not ch then
		return
	end
	self.zoom = math.clamp(z or self.zoom, 1, MAXZOOM)
	local s = self.base * self.zoom
	self.panX, self.panY = self.fw / 2 - ch.cx * s, self.fh / 2 - ch.cy * s
	self:layout()
end

function Map2D:layout()
	local s = self.base * self.zoom
	local mw, mh = MapData.W * s, MapData.H * s
	-- never show anything beyond the map's edges
	self.panX = math.clamp(self.panX, math.min(0, self.fw - mw), 0)
	self.panY = math.clamp(self.panY, math.min(0, self.fh - mh), 0)
	self.scale.Scale = s
	self.inner.Position = UI.px(self.panX, self.panY)
	-- labels: big countries always, small ones once there is room (and always when hovered / chosen / booked)
	for cid, ch in pairs(self.chips) do
		local x, y = self.panX + ch.cx * s, self.panY + ch.cy * s
		ch.chip.Position = UI.px(x, y)
		local L = self.layers[cid]
		local room = L.cells * s * s
		local inside = x > -40 and x < self.fw + 40 and y > -20 and y < self.fh + 20
		local n = self.opts.countFn and self.opts.countFn(cid) or 0
		ch.chip.Visible = inside and (room > 2600 or self.hover == cid or self.opts.selected == cid or n > 0)
	end
end

function Map2D:setHover(cid)
	if self.hover == cid then
		return
	end
	local old = self.hover
	self.hover = cid
	if old then
		self:paint(old)
	end
	if cid then
		self:paint(cid)
	end
	self:layout()
	if self.opts.onHover then
		self.opts.onHover(cid)
	end
end

function Map2D:paint(cid)
	local L = self.layers[cid]
	local ch = self.chips[cid]
	if not L or not ch then
		return
	end
	local sel = self.opts.selected == cid
	local hov = self.hover == cid
	local col = sel and T.accent or (hov and HOVER or L.base)
	if L.painted ~= col then
		L.painted = col
		for _, f in ipairs(L.frames) do
			f.BackgroundColor3 = col
		end
	end
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
		self:paint(cid)
	end
	self:layout()
end

function Map2D:setSelected(cid)
	self.opts.selected = cid
	self:refresh()
end

-- new callbacks / numbers (the map is built once and kept)
function Map2D:setOpts(opts)
	for k, v in pairs(opts) do
		self.opts[k] = v
	end
	self:refresh()
end

return Map2D
