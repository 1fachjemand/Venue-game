-- Tiny UI toolkit. All layouts are designed for a 1920x1080 canvas that gets scaled to the screen.
local TweenService = game:GetService("TweenService")

local UI = {}

-- A plain, bright look: light grey background, white cards, dark text, one blue for "do this".
UI.Theme = {
	bg = Color3.fromRGB(240, 242, 245),
	panel = Color3.fromRGB(255, 255, 255),
	panel2 = Color3.fromRGB(246, 247, 249),
	panel3 = Color3.fromRGB(229, 232, 237),
	stroke = Color3.fromRGB(210, 214, 221),
	text = Color3.fromRGB(30, 33, 40),
	sub = Color3.fromRGB(104, 110, 122),
	accent = Color3.fromRGB(37, 99, 235),
	accent2 = Color3.fromRGB(13, 148, 136),
	good = Color3.fromRGB(22, 163, 74),
	warn = Color3.fromRGB(217, 119, 6),
	bad = Color3.fromRGB(220, 38, 38),
	gold = Color3.fromRGB(202, 138, 4),
	white = Color3.new(1, 1, 1),
}
local T = UI.Theme

UI.Font = Enum.Font.GothamMedium
UI.FontBold = Enum.Font.GothamBold
UI.FontBlack = Enum.Font.GothamBlack

function UI.rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Creates an instance. Number keys in props are children, "Parent" is applied last.
function UI.New(className, props)
	local inst = Instance.new(className)
	local parent = nil
	for k, v in pairs(props or {}) do
		if type(k) == "number" then
			v.Parent = inst
		elseif k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Escapes text for RichText labels
function UI.esc(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function UI.px(x, y)
	return UDim2.fromOffset(x, y)
end

function UI.Corner(r)
	return UI.New("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

function UI.Stroke(color, thickness, transparency)
	return UI.New("UIStroke", {
		Color = color or T.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.Padding(l, r, t, b)
	return UI.New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or l or 0),
		PaddingBottom = UDim.new(0, b or t or l or 0),
	})
end

function UI.List(vertical, padding, hAlign, vAlign)
	return UI.New("UIListLayout", {
		FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, padding or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

function UI.Panel(parent, pos, size, color, radius)
	return UI.New("Frame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = color or T.panel,
		BorderSizePixel = 0,
		Active = true,
		UI.Corner(radius or 12),
		UI.Stroke(T.stroke, 1, 0.3),
	})
end

-- opts: textSize, color, font, alignX, alignY, wrap, order, bg
function UI.Label(parent, text, pos, size, opts)
	opts = opts or {}
	local lbl = UI.New("TextLabel", {
		Parent = parent,
		Position = pos or UI.px(0, 0),
		Size = size or UI.px(200, 24),
		BackgroundTransparency = opts.bg and 0 or 1,
		BackgroundColor3 = opts.bg or T.panel,
		BorderSizePixel = 0,
		Text = text or "",
		TextColor3 = opts.color or T.text,
		TextSize = opts.textSize or 18,
		Font = opts.font or UI.Font,
		TextXAlignment = opts.alignX or Enum.TextXAlignment.Left,
		TextYAlignment = opts.alignY or Enum.TextYAlignment.Center,
		TextWrapped = opts.wrap or false,
		TextTruncate = opts.wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		RichText = opts.rich or false,
		LayoutOrder = opts.order or 0,
	})
	return lbl
end

local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
UI.shade = shade
-- how bright a colour looks (0 dark .. 1 white)
function UI.lum(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end
-- readable text on a background: white on strong colours, dark on light ones
function UI.onColor(bg)
	return (UI.lum(bg) < 0.55) and Color3.new(1, 1, 1) or T.text
end

-- opts: color, textColor, textSize, font, radius, order, disabled
function UI.Button(parent, text, pos, size, opts, onClick)
	opts = opts or {}
	local base = opts.color or T.panel3
	local btn = UI.New("TextButton", {
		Parent = parent,
		Position = pos or UI.px(0, 0),
		Size = size or UI.px(160, 40),
		BackgroundColor3 = base,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = text or "",
		TextColor3 = opts.textColor or UI.onColor(base),
		TextSize = opts.textSize or 18,
		Font = opts.font or UI.FontBold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		LayoutOrder = opts.order or 0,
		UI.Corner(opts.radius or 8),
	})
	if opts.disabled then
		btn.BackgroundColor3 = T.panel3:Lerp(base, 0.25)
		btn.TextColor3 = Color3.fromRGB(160, 165, 175)
		btn.Active = false
		btn.AutoButtonColor = false
	end
	-- light buttons get a bit darker under the mouse, coloured ones a bit lighter
	local hover = (UI.lum(base) > 0.7) and shade(base, 0.93) or base:Lerp(Color3.new(1, 1, 1), 0.15)
	btn.MouseEnter:Connect(function()
		if not opts.disabled then
			btn.BackgroundColor3 = hover
			-- no hover tick right after a click (a screen rebuilt under the mouse would sound twice)
			if UI.onHover and os.clock() - (UI.lastClick or -1) > 0.3 then
				UI.onHover()
			end
		end
	end)
	btn.MouseLeave:Connect(function()
		if not opts.disabled then
			btn.BackgroundColor3 = base
		end
	end)
	btn.MouseButton1Click:Connect(function()
		if opts.disabled or not onClick then
			return
		end
		UI.lastClick = os.clock()
		if UI.onClick then
			UI.onClick()
		end
		onClick(btn)
	end)
	return btn
end

-- Returns (frame, setFraction(f, color?))
function UI.Bar(parent, pos, size, frac, color, bgColor)
	local bg = UI.New("Frame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = bgColor or T.panel3,
		BorderSizePixel = 0,
		UI.Corner(4),
	})
	local fill = UI.New("Frame", {
		Parent = bg,
		Size = UDim2.fromScale(math.clamp(frac or 0, 0, 1), 1),
		BackgroundColor3 = color or T.accent2,
		BorderSizePixel = 0,
		UI.Corner(4),
	})
	local function set(f, c)
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
		if c then
			fill.BackgroundColor3 = c
		end
	end
	return bg, set
end

function UI.Scroll(parent, pos, size)
	return UI.New("ScrollingFrame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(170, 175, 185),
		Active = true,
	})
end

function UI.Pill(parent, text, pos, size, color, textSize)
	return UI.New("TextLabel", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = UI.onColor(color),
		TextSize = textSize or 13,
		Font = UI.FontBold,
		UI.Corner(6),
	})
end

-- Destroys all children except layout helpers
function UI.ClearChildren(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if not (c:IsA("UIListLayout") or c:IsA("UIGridLayout") or c:IsA("UIPadding") or c:IsA("UICorner") or c:IsA("UIStroke")) then
			c:Destroy()
		end
	end
end

function UI.Tween(inst, t, props, style)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

return UI
