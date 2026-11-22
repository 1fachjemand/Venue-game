-- Renders the mock GUI tree to approximate HTML so the layout can be screenshotted.
local function rgb(c, tr)
	return string.format("rgba(%d,%d,%d,%.3f)", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), 1 - (tr or 0))
end
local function htmlEsc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
local function rich(s)
	s = s:gsub("<font ([^>]*)>", function(attrs)
		local style = ""
		local col = attrs:match("color=['\"]([^'\"]+)['\"]")
		local size = attrs:match("size=['\"]([^'\"]+)['\"]")
		if col then style = style .. "color:" .. col .. ";" end
		if size then style = style .. "font-size:" .. size .. "px;" end
		return '<span style="' .. style .. '">'
	end)
	s = s:gsub("</font>", "</span>")
	return (s:gsub("\n", "<br>"))
end
local WEIGHT = { GothamBlack = 900, GothamBold = 700, GothamMedium = 500, Gotham = 400 }

local function child(inst, cls)
	for _, c in ipairs(inst:GetChildren()) do if c:IsA(cls) then return c end end
end
local function isGui(i) return i:IsA("GuiObject") end

local measure
-- estimated content height of a GuiObject for AutomaticSize
measure = function(inst, w)
	local h = 0
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		local txt = inst.Text:gsub("<[^>]+>", "")
		local perLine = math.max(1, math.floor(w / (inst.TextSize * 0.52)))
		local lines = 0
		for line in (txt .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line / perLine)) end
		h = lines * inst.TextSize * 1.25
	end
	local list = child(inst, "UIListLayout")
	local pad = child(inst, "UIPadding")
	local pt = pad and (pad.PaddingTop.Offset + pad.PaddingBottom.Offset) or 0
	local pl = pad and (pad.PaddingLeft.Offset + pad.PaddingRight.Offset) or 0
	if list and list.FillDirection == Enum.FillDirection.Vertical then
		local sum, n = 0, 0
		for _, c in ipairs(inst:GetChildren()) do
			if isGui(c) and c.Visible then
				local ch = c.Size.Y.Offset
				if c.AutomaticSize == Enum.AutomaticSize.Y then ch = math.max(ch, measure(c, c.Size.X.Offset)) end
				sum = sum + ch
				n = n + 1
			end
		end
		h = math.max(h, sum + math.max(0, n - 1) * list.Padding.Offset)
	elseif list then
		for _, c in ipairs(inst:GetChildren()) do
			if isGui(c) and c.Visible then h = math.max(h, c.Size.Y.Offset) end
		end
	end
	return h + pt, pl
end

local function render(inst, px, py, pw, ph, out, forced, ox, oy)
	ox, oy = ox or px, oy or py
	if not isGui(inst) or not inst.Visible then
		if inst:IsA("Folder") then
			for _, c in ipairs(inst:GetChildren()) do render(c, px, py, pw, ph, out, nil, ox, oy) end
		end
		return
	end
	local w = inst.Size.X.Scale * pw + inst.Size.X.Offset
	local h = inst.Size.Y.Scale * ph + inst.Size.Y.Offset
	if inst.AutomaticSize == Enum.AutomaticSize.Y then h = math.max(h, (measure(inst, w))) end
	local arc = child(inst, "UIAspectRatioConstraint")
	if arc and h > 0 then
		-- fit inside the given size with this width / height ratio (like Roblox's default)
		local ratio = arc.AspectRatio or 1
		if w / h > ratio then w = h * ratio else h = w / ratio end
	end
	local x, y
	if forced then
		x, y = forced[1], forced[2]
		if forced[3] then w, h = forced[3], forced[4] end
	else
		x = px + inst.Position.X.Scale * pw + inst.Position.X.Offset - inst.AnchorPoint.X * w
		y = py + inst.Position.Y.Scale * ph + inst.Position.Y.Offset - inst.AnchorPoint.Y * h
	end
	local st = {}
	table.insert(st, string.format("left:%.1fpx;top:%.1fpx;width:%.1fpx;height:%.1fpx;", x - ox, y - oy, w, h))
	local grad = child(inst, "UIGradient")
	if inst.BackgroundTransparency < 1 and grad and grad.Enabled ~= false and grad.Color and grad.Color.Keypoints then
		-- UIGradient: a CSS linear gradient (colour x transparency at every keypoint time)
		local function at(seq, tt, isColor)
			local k = seq.Keypoints
			for i = 1, #k - 1 do
				if tt >= k[i].Time and tt <= k[i + 1].Time then
					local f = (tt - k[i].Time) / math.max(1e-6, k[i + 1].Time - k[i].Time)
					if isColor then return k[i].Value:Lerp(k[i + 1].Value, f) end
					return k[i].Value + (k[i + 1].Value - k[i].Value) * f
				end
			end
			return k[#k].Value
		end
		local times, seen = {}, {}
		for _, seq in ipairs({ grad.Color, grad.Transparency }) do
			for _, kp in ipairs((type(seq) == "table" and seq.Keypoints) or {}) do
				if not seen[kp.Time] then seen[kp.Time] = true table.insert(times, kp.Time) end
			end
		end
		table.sort(times)
		local stops = {}
		for _, tt in ipairs(times) do
			local c0 = at(grad.Color, tt, true)
			local bgc = inst.BackgroundColor3
			local c = Color3.new(c0.R * bgc.R, c0.G * bgc.G, c0.B * bgc.B) -- (Roblox multiplies them)
			local tr = (type(grad.Transparency) == "table" and grad.Transparency.Keypoints) and at(grad.Transparency, tt, false) or 0
			tr = 1 - (1 - tr) * (1 - inst.BackgroundTransparency)
			table.insert(stops, rgb(c, tr) .. " " .. string.format("%.1f%%", tt * 100))
		end
		table.insert(st, "background:linear-gradient(" .. ((grad.Rotation or 0) + 90) .. "deg," .. table.concat(stops, ",") .. ");")
	elseif inst.BackgroundTransparency < 1 then table.insert(st, "background:" .. rgb(inst.BackgroundColor3, inst.BackgroundTransparency) .. ";") end
	local corner = child(inst, "UICorner")
	if corner then table.insert(st, "border-radius:" .. (corner.CornerRadius.Offset + corner.CornerRadius.Scale * math.min(w, h)) .. "px;") end
	local stroke = child(inst, "UIStroke")
	if stroke then table.insert(st, string.format("box-shadow:0 0 0 %dpx %s;", stroke.Thickness, rgb(stroke.Color, stroke.Transparency))) end
	-- UIScale: scaled around the anchor point (like Roblox)
	local uis = child(inst, "UIScale")
	local tf = ""
	if uis and math.abs(uis.Scale - 1) > 0.001 then
		tf = tf .. string.format("scale(%.4f) ", uis.Scale)
		table.insert(st, string.format("transform-origin:%.0f%% %.0f%%;", inst.AnchorPoint.X * 100, inst.AnchorPoint.Y * 100))
	end
	if inst.Rotation ~= 0 then tf = tf .. "rotate(" .. inst.Rotation .. "deg)" end
	if tf ~= "" then table.insert(st, "transform:" .. tf .. ";") end
	if inst.ClipsDescendants or inst:IsA("ScrollingFrame") then table.insert(st, "overflow:hidden;") end
	local inner = ""
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local t = inst.Text
		if inst:IsA("TextBox") and t == "" then t = inst.PlaceholderText end
		t = inst.RichText and rich(t) or htmlEsc(t):gsub("\n", "<br>")
		local ax = inst.TextXAlignment.Name
		local ay = inst.TextYAlignment.Name
		local just = ax == "Left" and "flex-start" or (ax == "Right" and "flex-end" or "center")
		local align = ay == "Top" and "flex-start" or (ay == "Bottom" and "flex-end" or "center")
		table.insert(st, string.format("color:%s;font-size:%dpx;font-weight:%d;display:flex;justify-content:%s;align-items:%s;text-align:%s;",
			rgb(inst.TextColor3, inst.TextTransparency), inst.TextSize, WEIGHT[inst.Font.Name] or 500, just, align, ax:lower()))
		local ws = inst.TextWrapped and "white-space:normal;" or "white-space:nowrap;overflow:hidden;text-overflow:ellipsis;"
		inner = '<span style="' .. ws .. 'max-width:100%;">' .. t .. "</span>"
	end
	table.insert(out, '<div style="position:absolute;' .. table.concat(st) .. '">' .. inner)
	-- children
	local pad = child(inst, "UIPadding")
	local cx, cy, cw, chh = x, y, w, h
	if pad then
		cx, cy = x + pad.PaddingLeft.Offset, y + pad.PaddingTop.Offset
		cw, chh = w - pad.PaddingLeft.Offset - pad.PaddingRight.Offset, h - pad.PaddingTop.Offset - pad.PaddingBottom.Offset
	end
	local kids = {}
	for _, c in ipairs(inst:GetChildren()) do if (isGui(c) and c.Visible) or c:IsA("Folder") then table.insert(kids, c) end end
	local list, grid = child(inst, "UIListLayout"), child(inst, "UIGridLayout")
	if list or grid then
		local sorted = {}
		for i, c in ipairs(kids) do if isGui(c) then table.insert(sorted, { c = c, i = i }) end end
		table.sort(sorted, function(a, b) if a.c.LayoutOrder ~= b.c.LayoutOrder then return a.c.LayoutOrder < b.c.LayoutOrder end return a.i < b.i end)
		if grid then
			local gx, gy = 0, 0
			local cwid, chei = grid.CellSize.X.Offset, grid.CellSize.Y.Offset
			for _, e in ipairs(sorted) do
				if gx + cwid > cw + 0.5 then gx = 0 gy = gy + chei + grid.CellPadding.Y.Offset end
				render(e.c, x, y, w, h, out, { cx + gx, cy + gy, cwid, chei }, x, y)
				gx = gx + cwid + grid.CellPadding.X.Offset
			end
		else
			local vertical = list.FillDirection == Enum.FillDirection.Vertical
			-- total size for alignment
			local sizes, total = {}, 0
			for k, e in ipairs(sorted) do
				local ew = e.c.Size.X.Scale * cw + e.c.Size.X.Offset
				local eh = e.c.Size.Y.Scale * chh + e.c.Size.Y.Offset
				if e.c.AutomaticSize == Enum.AutomaticSize.Y then eh = math.max(eh, (measure(e.c, ew))) end
				sizes[k] = { ew, eh }
				total = total + (vertical and eh or ew) + (k > 1 and list.Padding.Offset or 0)
			end
			local pos = 0
			if not vertical then
				local ha = list.HorizontalAlignment.Name
				if ha == "Center" then pos = (cw - total) / 2 elseif ha == "Right" then pos = cw - total end
			end
			for k, e in ipairs(sorted) do
				local ew, eh = sizes[k][1], sizes[k][2]
				local ex, ey
				if vertical then
					ey = cy + pos
					local ha = list.HorizontalAlignment.Name
					ex = cx + (ha == "Center" and (cw - ew) / 2 or (ha == "Right" and cw - ew or 0))
					pos = pos + eh + list.Padding.Offset
				else
					ex = cx + pos
					local va = list.VerticalAlignment.Name
					ey = cy + (va == "Center" and (chh - eh) / 2 or (va == "Bottom" and chh - eh or 0))
					pos = pos + ew + list.Padding.Offset
				end
				render(e.c, x, y, w, h, out, { ex, ey, ew, eh }, x, y)
			end
		end
	else
		for _, c in ipairs(kids) do render(c, cx, cy, cw, chh, out, nil, x, y) end
	end
	table.insert(out, "</div>")
	-- fix positions: children are rendered relative to (px,py) of *this* element
end

-- The renderer above computes children relative to the parent's absolute rect,
-- but writes left/top relative to the passed parent origin. Children of this element
-- get origin (x, y) because we pass x,y as px,py.
function MOCK.renderHTML(gui, title)
	local out = { "<!doctype html><html><head><meta charset='utf-8'><title>" .. title .. "</title><style>body{margin:0;background:#000;font-family:'Montserrat','DejaVu Sans',Arial,sans-serif;} div{box-sizing:border-box;}</style></head><body><div style='position:relative;width:1920px;height:1080px;overflow:hidden;background:#000'>" }
	for _, c in ipairs(gui:GetChildren()) do render(c, 0, 0, 1920, 1080, out) end
	table.insert(out, "</div></body></html>")
	return table.concat(out)
end
