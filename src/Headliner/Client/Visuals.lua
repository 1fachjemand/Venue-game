-- Tour visuals on the screens: every artist has 8 of their own (chosen by genre and name), one for every
-- song of the setlist (song n shows visual n, after 8 it starts again), like the video content of real tours
-- (waveforms and a big face, lightning for metal, hearts for pop ...). Drawn with GUI frames inside a screen.
--   Visuals.forArtist(ad)            -> list of 8 kinds
--   Visuals.draw(face, kind, ctx)    -> shows kind on a screen face (builds it the first time, 30 updates / s)
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)

local New = UI.New
local Visuals = {}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local function box(parent, x, y, w, h, color, z)
	return New("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color or WHITE, BorderSizePixel = 0, ZIndex = z or 3 })
end
local function round(f)
	New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	return f
end
local function ring(parent, x, y, size, color, thick)
	local f = New("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(size, size), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 })
	New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = f })
	round(f)
	local st = New("UIStroke", { Color = color or WHITE, Thickness = thick or 4, Parent = f })
	return f, st
end
local function rnd(i, k)
	-- a fixed "random" number 0..1 for element i (the same every frame)
	local v = math.sin(i * 12.9898 + (k or 0) * 78.233) * 43758.5453
	return v - math.floor(v)
end

-- every visual: build(c) -> state, update(st, t, beat, c1, c2)
local K = {}

K.waveform = {
	build = function(c)
		local st = { bars = {} }
		for i = 1, 40 do
			st.bars[i] = box(c, (i - 0.5) / 40, 0.5, 0.012, 0.1)
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, b in ipairs(st.bars) do
			local a = math.abs(math.sin(t * 3.1 + i * 0.42) * math.sin(t * 1.3 + i * 0.13)) * (0.4 + 0.6 * beat)
			b.Size = UDim2.fromScale(0.012, 0.05 + a * 0.75)
			b.BackgroundColor3 = c1:Lerp(WHITE, 0.3)
		end
	end,
}
K.equalizer = {
	build = function(c)
		local st = { bars = {} }
		for i = 1, 16 do
			local f = New("Frame", { Parent = c, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale((i - 0.5) / 16, 0.95), Size = UDim2.fromScale(0.045, 0.2), BorderSizePixel = 0, ZIndex = 3 })
			st.bars[i] = f
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, b in ipairs(st.bars) do
			local h = 0.1 + (0.5 + 0.5 * math.sin(t * (2 + rnd(i) * 3) + i)) * (0.35 + 0.5 * beat)
			b.Size = UDim2.fromScale(0.045, h)
			b.BackgroundColor3 = c2:Lerp(c1, h)
		end
	end,
}
K.lightning = {
	build = function(c)
		local st = { bolts = {} }
		for b = 1, 3 do
			local segs = {}
			for k = 1, 6 do
				segs[k] = box(c, 0.5, 0.5, 0.012, 0.18, WHITE)
			end
			st.bolts[b] = segs
		end
		return st
	end,
	update = function(st, t, beat, c1)
		local flash = math.floor(t * 4)
		for b, segs in ipairs(st.bolts) do
			local on = rnd(flash, b) > 0.45 and beat > 0.25
			local x, y = 0.15 + 0.35 * (b - 1) + rnd(flash, b + 10) * 0.1, 0.02
			for k, sgm in ipairs(segs) do
				local nx = x + (rnd(flash * 7 + k, b) - 0.5) * 0.16
				local ny = y + 0.16
				sgm.Position = UDim2.fromScale((x + nx) / 2, (y + ny) / 2)
				sgm.Rotation = math.deg(math.atan2(nx - x, ny - y)) * -1
				sgm.Size = UDim2.fromScale(0.01, 0.19)
				sgm.Visible = on
				sgm.BackgroundColor3 = WHITE:Lerp(c1, 0.25)
				x, y = nx, ny
			end
		end
	end,
}
K.rings = {
	build = function(c)
		local st = { rings = {} }
		for i = 1, 6 do
			local f, s = ring(c, 0.5, 0.5, 0.1, WHITE, 5)
			st.rings[i] = { f, s }
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, r in ipairs(st.rings) do
			local p = (t * 0.35 + i / 6) % 1
			r[1].Size = UDim2.fromScale(0.05 + p * 1.6, 0.05 + p * 1.6)
			r[2].Color = (i % 2 == 0) and c1 or c2
			r[2].Transparency = p
			r[2].Thickness = 3 + 6 * beat
		end
	end,
}
K.starfield = {
	build = function(c)
		local st = { dots = {} }
		for i = 1, 46 do
			st.dots[i] = round(box(c, 0.5, 0.5, 0.008, 0.012, WHITE))
		end
		return st
	end,
	update = function(st, t, beat, c1)
		for i, d in ipairs(st.dots) do
			local a = rnd(i) * math.pi * 2
			local p = (t * (0.15 + rnd(i, 2) * 0.25) + rnd(i, 3)) % 1
			d.Position = UDim2.fromScale(0.5 + math.cos(a) * p * 0.7, 0.5 + math.sin(a) * p * 0.9)
			local s = 0.004 + p * 0.014
			d.Size = UDim2.fromScale(s, s * 1.7)
			d.BackgroundColor3 = WHITE:Lerp(c1, rnd(i, 4) * 0.6)
			d.BackgroundTransparency = 1 - p
		end
	end,
}
K.face = {
	-- a huge face (eyes, nose, lips) that appears out of the dark and blinks
	build = function(c)
		local st = {}
		st.head = round(box(c, 0.5, 0.52, 0.42, 0.9))
		st.eyeL = round(box(c, 0.43, 0.42, 0.08, 0.06, BLACK))
		st.eyeR = round(box(c, 0.57, 0.42, 0.08, 0.06, BLACK))
		st.nose = box(c, 0.5, 0.55, 0.012, 0.1, BLACK)
		st.mouth = round(box(c, 0.5, 0.7, 0.14, 0.035, BLACK))
		return st
	end,
	update = function(st, t, beat, c1)
		local vis = 0.5 + 0.5 * math.sin(t * 0.5)
		local col = c1:Lerp(Color3.fromRGB(80, 140, 255), 0.5)
		st.head.BackgroundColor3 = col
		st.head.BackgroundTransparency = 0.25 + 0.6 * (1 - vis)
		local blink = (t % 4.5 < 0.15) and 0.01 or 0.06
		for _, e in ipairs({ st.eyeL, st.eyeR }) do
			e.Size = UDim2.fromScale(0.08, blink)
			e.BackgroundTransparency = 0.2 + 0.7 * (1 - vis)
		end
		st.nose.BackgroundTransparency = 0.5 + 0.5 * (1 - vis)
		st.mouth.Size = UDim2.fromScale(0.14, 0.02 + 0.04 * beat)
		st.mouth.BackgroundTransparency = 0.2 + 0.7 * (1 - vis)
	end,
}
local function heart(c, color)
	local h = New("Frame", { Parent = c, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.1, 0.16), BackgroundTransparency = 1, ZIndex = 3 })
	New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = h })
	local sq = New("Frame", { Parent = h, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.55, 0.55), Rotation = 45, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 })
	local l = round(New("Frame", { Parent = h, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.33, 0.38), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }))
	local r = round(New("Frame", { Parent = h, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.67, 0.38), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }))
	return h, { sq, l, r }
end
K.hearts = {
	build = function(c)
		local st = { hearts = {} }
		for i = 1, 9 do
			local h, parts = heart(c, WHITE)
			st.hearts[i] = { h, parts }
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, h in ipairs(st.hearts) do
			local p = (t * 0.12 + rnd(i)) % 1
			h[1].Position = UDim2.fromScale(0.08 + rnd(i, 2) * 0.84 + math.sin(t + i) * 0.02, 1.1 - p * 1.25)
			local s = 0.08 + 0.05 * beat + rnd(i, 3) * 0.06
			h[1].Size = UDim2.fromScale(s, s * 1.6)
			for _, pp in ipairs(h[2]) do
				pp.BackgroundColor3 = (i % 2 == 0) and c1 or c2:Lerp(WHITE, 0.3)
			end
		end
	end,
}
K.flames = {
	build = function(c)
		local st = { f = {} }
		for i = 1, 14 do
			local f = New("Frame", { Parent = c, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale((i - 0.5) / 14, 1.02), Size = UDim2.fromScale(0.09, 0.4), BorderSizePixel = 0, ZIndex = 3 })
			New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
			New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 60, 0)), Parent = f })
			st.f[i] = f
		end
		return st
	end,
	update = function(st, t, beat)
		for i, f in ipairs(st.f) do
			local h = 0.25 + 0.35 * math.abs(math.sin(t * (4 + rnd(i) * 3) + i)) + 0.25 * beat
			f.Size = UDim2.fromScale(0.08 + rnd(i, 2) * 0.03, h)
		end
	end,
}
K.rain = {
	build = function(c)
		local st = { d = {} }
		for i = 1, 50 do
			st.d[i] = box(c, rnd(i), 0, 0.003, 0.08, WHITE)
		end
		return st
	end,
	update = function(st, t, beat, c1)
		for i, d in ipairs(st.d) do
			local p = (t * (0.8 + rnd(i, 2)) + rnd(i, 3)) % 1.2
			d.Position = UDim2.fromScale(rnd(i), p - 0.1)
			d.BackgroundColor3 = WHITE:Lerp(c1, 0.4)
			d.BackgroundTransparency = 0.3 + rnd(i, 4) * 0.4
		end
	end,
}
K.spiral = {
	build = function(c)
		local st = { d = {} }
		for i = 1, 36 do
			st.d[i] = round(box(c, 0.5, 0.5, 0.02, 0.03))
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, d in ipairs(st.d) do
			local a = i * 0.55 + t * 1.2
			local r = i / 36 * 0.48
			d.Position = UDim2.fromScale(0.5 + math.cos(a) * r * 0.6, 0.5 + math.sin(a) * r)
			local s = 0.01 + i / 36 * 0.03 * (0.7 + 0.5 * beat)
			d.Size = UDim2.fromScale(s, s * 1.6)
			d.BackgroundColor3 = c1:Lerp(c2, i / 36)
		end
	end,
}
K.tunnel = {
	build = function(c)
		local st = { s = {} }
		for i = 1, 8 do
			local f = box(c, 0.5, 0.5, 0.1, 0.1)
			f.BackgroundTransparency = 1
			local stroke = New("UIStroke", { Thickness = 4, Parent = f })
			st.s[i] = { f, stroke }
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, sq in ipairs(st.s) do
			local p = (t * 0.4 + i / 8) % 1
			local z = p * p * 1.4
			sq[1].Size = UDim2.fromScale(z, z)
			sq[1].Rotation = t * 10 + i * 6
			sq[2].Color = (i % 2 == 0) and c1 or c2
			sq[2].Thickness = 2 + 8 * p + 4 * beat
			sq[2].Transparency = 1 - p
		end
	end,
}
K.checker = {
	build = function(c)
		local st = { cells = {} }
		for x = 0, 7 do
			for y = 0, 3 do
				table.insert(st.cells, { box(c, (x + 0.5) / 8, (y + 0.5) / 4, 1 / 8, 1 / 4), x, y })
			end
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		local n = math.floor(t * 2)
		for _, cell in ipairs(st.cells) do
			local on = (cell[2] + cell[3] + n) % 2 == 0
			cell[1].BackgroundColor3 = on and c1 or BLACK
			cell[1].BackgroundTransparency = on and (0.6 - 0.5 * beat) or 0.2
		end
	end,
}
K.sun = {
	build = function(c)
		local st = { rays = {} }
		for i = 1, 12 do
			st.rays[i] = box(c, 0.5, 0.55, 0.012, 0.8)
		end
		st.disc = round(box(c, 0.5, 0.55, 0.22, 0.36))
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = st.disc })
		return st
	end,
	update = function(st, t, beat, c1)
		local warm = Color3.fromRGB(255, 190, 80):Lerp(c1, 0.25)
		st.disc.BackgroundColor3 = warm
		st.disc.Size = UDim2.fromScale(0.24 + 0.04 * beat, 0.36 + 0.06 * beat)
		for i, r in ipairs(st.rays) do
			r.Rotation = i * 15 + t * 8
			r.BackgroundColor3 = warm
			r.BackgroundTransparency = 0.5 + 0.3 * math.sin(t * 2 + i)
		end
	end,
}
K.moon = {
	build = function(c)
		local st = { stars = {} }
		st.moon = round(box(c, 0.6, 0.45, 0.25, 0.4, Color3.fromRGB(240, 236, 220)))
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = st.moon })
		st.shadow = round(box(c, 0.66, 0.4, 0.25, 0.4, BLACK))
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = st.shadow })
		for i = 1, 24 do
			st.stars[i] = round(box(c, rnd(i), rnd(i, 2), 0.006, 0.01))
		end
		return st
	end,
	update = function(st, t, beat, c1)
		st.moon.BackgroundColor3 = Color3.fromRGB(240, 236, 220):Lerp(c1, 0.15)
		st.shadow.Position = UDim2.fromScale(0.66 + math.sin(t * 0.2) * 0.03, 0.4)
		for i, s in ipairs(st.stars) do
			s.BackgroundTransparency = 0.2 + 0.7 * math.abs(math.sin(t * (1 + rnd(i, 3) * 2) + i))
		end
	end,
}
K.glitch = {
	build = function(c)
		local st = { bars = {} }
		for i = 1, 10 do
			st.bars[i] = box(c, 0.5, i / 11, 1, 0.06)
		end
		st.text = New("TextLabel", { Parent = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.4), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, ZIndex = 4, Text = "" })
		return st
	end,
	update = function(st, t, beat, c1, c2, ctx)
		local n = math.floor(t * 12)
		for i, b in ipairs(st.bars) do
			local on = rnd(n, i) > 0.6
			b.Visible = on
			b.Position = UDim2.fromScale(0.5 + (rnd(n, i + 20) - 0.5) * 0.3, rnd(n, i + 40))
			b.Size = UDim2.fromScale(0.6 + rnd(n, i) * 0.6, 0.02 + rnd(n, i + 60) * 0.08)
			b.BackgroundColor3 = (i % 3 == 0) and WHITE or ((i % 2 == 0) and c1 or c2)
		end
		st.text.Text = ctx and ctx.artistName or ""
		st.text.Position = UDim2.fromScale(0.5 + (rnd(n, 99) - 0.5) * 0.04 * (1 + beat * 2), 0.5)
		st.text.TextColor3 = (n % 7 == 0) and c1 or WHITE
	end,
}
K.kaleido = {
	build = function(c)
		local st = { p = {} }
		for i = 1, 12 do
			st.p[i] = box(c, 0.5, 0.5, 0.05, 0.7)
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, p in ipairs(st.p) do
			p.Rotation = i * 15 + t * ((i % 2 == 0) and 20 or -14)
			p.Size = UDim2.fromScale(0.03 + 0.03 * beat, 0.5 + 0.35 * math.abs(math.sin(t + i)))
			p.BackgroundColor3 = (i % 2 == 0) and c1 or c2
			p.BackgroundTransparency = 0.3
		end
	end,
}
K.petals = {
	build = function(c)
		local st = { p = {} }
		for i = 1, 22 do
			local f = box(c, rnd(i), 0, 0.03, 0.04)
			New("UICorner", { CornerRadius = UDim.new(0.6, 0), Parent = f })
			st.p[i] = f
		end
		return st
	end,
	update = function(st, t, beat, c1)
		for i, p in ipairs(st.p) do
			local y = (t * (0.08 + rnd(i, 2) * 0.1) + rnd(i, 3)) % 1.2 - 0.1
			p.Position = UDim2.fromScale(rnd(i) + math.sin(t + i) * 0.04, y)
			p.Rotation = t * 60 + i * 30
			p.BackgroundColor3 = Color3.fromRGB(255, 180, 210):Lerp(c1, 0.3)
		end
	end,
}
K.skyline = {
	build = function(c)
		local st = { b = {}, w = {} }
		for i = 1, 12 do
			local h = 0.2 + rnd(i) * 0.5
			local f = New("Frame", { Parent = c, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale((i - 0.5) / 12, 1), Size = UDim2.fromScale(1 / 12 - 0.008, h), BackgroundColor3 = Color3.fromRGB(12, 12, 18), BorderSizePixel = 0, ZIndex = 3 })
			st.b[i] = f
			for k = 1, 4 do
				local wdw = New("Frame", { Parent = f, Position = UDim2.fromScale(0.15 + (k % 2) * 0.45, 0.1 + math.floor((k - 1) / 2) * 0.3), Size = UDim2.fromScale(0.25, 0.1), BorderSizePixel = 0, ZIndex = 4 })
				table.insert(st.w, { wdw, i * 4 + k })
			end
		end
		return st
	end,
	update = function(st, t, beat, c1)
		local n = math.floor(t * 2)
		for _, w in ipairs(st.w) do
			local on = rnd(w[2], n) > 0.45
			w[1].BackgroundColor3 = on and Color3.fromRGB(255, 220, 140):Lerp(c1, 0.3 * beat) or Color3.fromRGB(30, 30, 40)
		end
	end,
}
K.orbit = {
	build = function(c)
		local st = { p = {} }
		st.core = round(box(c, 0.5, 0.5, 0.1, 0.16))
		for i = 1, 5 do
			st.p[i] = round(box(c, 0.5, 0.5, 0.04, 0.06))
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		st.core.BackgroundColor3 = c1
		st.core.Size = UDim2.fromScale(0.1 + 0.04 * beat, 0.16 + 0.06 * beat)
		for i, p in ipairs(st.p) do
			local a = t * (0.6 + i * 0.25) + i
			local r = 0.1 + i * 0.07
			p.Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r * 1.4)
			p.BackgroundColor3 = (i % 2 == 0) and c2 or WHITE
		end
	end,
}
K.eye = {
	build = function(c)
		local st = {}
		st.white = round(box(c, 0.5, 0.5, 0.5, 0.45, WHITE))
		st.iris = round(box(c, 0.5, 0.5, 0.14, 0.32))
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = st.iris })
		st.pupil = round(box(c, 0.5, 0.5, 0.06, 0.13, BLACK))
		New("UIAspectRatioConstraint", { AspectRatio = 1, Parent = st.pupil })
		return st
	end,
	update = function(st, t, beat, c1)
		local lx = math.sin(t * 0.7) * 0.1
		local open = (t % 5 < 0.2) and 0.05 or 0.45
		st.white.Size = UDim2.fromScale(0.5, open)
		st.iris.Position = UDim2.fromScale(0.5 + lx, 0.5)
		st.iris.BackgroundColor3 = c1
		st.pupil.Position = UDim2.fromScale(0.5 + lx, 0.5)
		st.pupil.Size = UDim2.fromScale(0.05 + 0.03 * beat, 0.12)
		st.iris.Visible = open > 0.1
		st.pupil.Visible = open > 0.1
	end,
}
K.smoke = {
	build = function(c)
		local st = { p = {} }
		for i = 1, 10 do
			st.p[i] = round(box(c, rnd(i), 0.6, 0.3, 0.5))
		end
		return st
	end,
	update = function(st, t, beat, c1, c2)
		for i, p in ipairs(st.p) do
			local y = (t * 0.05 + rnd(i, 2)) % 1.3 - 0.15
			p.Position = UDim2.fromScale(rnd(i) + math.sin(t * 0.3 + i) * 0.08, 1 - y)
			p.Size = UDim2.fromScale(0.25 + y * 0.3, 0.4 + y * 0.4)
			p.BackgroundColor3 = c1:Lerp(c2, rnd(i, 5))
			p.BackgroundTransparency = 0.65 + y * 0.25
		end
	end,
}
-- intro visuals (before the artist comes on)
K.countdown = {
	build = function(c)
		local st = {}
		st.text = New("TextLabel", { Parent = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.9), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, ZIndex = 4, Text = "" })
		st.ring, st.stroke = ring(c, 0.5, 0.5, 0.8, WHITE, 8)
		return st
	end,
	update = function(st, t, beat, c1, c2, ctx)
		local left = ctx and ctx.introLeft or 0
		st.text.Text = (left > 0.5) and tostring(math.ceil(left)) or ""
		st.stroke.Color = c1
		st.stroke.Transparency = left % 1
	end,
}
K.name = {
	build = function(c)
		local st = {}
		st.text = New("TextLabel", { Parent = c, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.4), BackgroundTransparency = 1, TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = WHITE, ZIndex = 4, Text = "" })
		return st
	end,
	update = function(st, t, beat, c1, c2, ctx)
		local name = (ctx and ctx.artistName) or ""
		local f = math.clamp((ctx and ctx.introFrac) or 1, 0, 1)
		st.text.Text = name:sub(1, math.max(1, math.floor(#name * f * 1.3)))
		st.text.TextColor3 = WHITE:Lerp(c1, 0.3 + 0.3 * math.sin(t * 3))
		st.text.TextTransparency = 1 - math.min(1, f * 2)
	end,
}

Visuals.KINDS = K
Visuals.LIST = { "waveform", "equalizer", "lightning", "rings", "starfield", "face", "hearts", "flames", "rain", "spiral", "tunnel", "checker", "sun", "moon", "glitch", "kaleido", "petals", "skyline", "orbit", "eye", "smoke" }
-- what fits a genre (the first ones are picked first; the rest of the 8 come from all visuals)
Visuals.GENRE = {
	Pop = { "hearts", "rings", "starfield", "kaleido", "face", "petals" },
	Rock = { "lightning", "flames", "equalizer", "glitch", "skyline" },
	Metal = { "lightning", "flames", "glitch", "eye", "smoke", "checker" },
	EDM = { "tunnel", "equalizer", "checker", "spiral", "kaleido", "waveform" },
	["Hip-Hop"] = { "skyline", "equalizer", "glitch", "eye", "waveform" },
	Indie = { "rain", "moon", "petals", "sun", "waveform", "starfield" },
	["K-Pop"] = { "hearts", "starfield", "kaleido", "rings", "orbit", "petals" },
	Country = { "sun", "starfield", "moon", "skyline", "rain" },
	Latin = { "sun", "flames", "petals", "kaleido", "hearts" },
	["R&B"] = { "smoke", "moon", "waveform", "face", "rings" },
}
local function seedOf(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end
-- 8 visuals of an artist: the same in every show (by genre and name)
function Visuals.forArtist(ad)
	local out, seen = {}, {}
	local h = seedOf(ad and ad.id or "x")
	local pref = Visuals.GENRE[ad and ad.genre or "Pop"] or Visuals.GENRE.Pop
	-- 4-5 genre visuals in an order of this artist, then others
	local start = h % #pref
	for k = 0, #pref - 1 do
		local kind = pref[(start + k) % #pref + 1]
		if #out < 5 and not seen[kind] then
			table.insert(out, kind)
			seen[kind] = true
		end
	end
	local tries = 0
	while #out < 8 and tries < 100 do
		tries = tries + 1
		h = (h * 1103515245 + 12345) % 2147483648
		local kind = Visuals.LIST[h % #Visuals.LIST + 1]
		if not seen[kind] then
			table.insert(out, kind)
			seen[kind] = true
		end
	end
	return out
end
function Visuals.forSong(ad, n)
	local list = Visuals.forArtist(ad)
	return list[((n or 1) - 1) % #list + 1]
end

-- shows a visual on a screen face (face.frame = the SurfaceGui's frame); nil hides it
function Visuals.draw(face, kind, ctx)
	if face.visKind ~= kind then
		if face.vis then
			face.vis:Destroy()
			face.vis = nil
		end
		face.visKind = kind
		if kind and K[kind] then
			face.vis = New("Frame", { Parent = face.frame, Name = "Visual", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3 })
			face.visState = K[kind].build(face.vis)
			face.visNext = 0
		end
	end
	if not face.vis then
		return
	end
	local t = ctx.t or 0
	if t < (face.visNext or 0) then
		return
	end
	face.visNext = t + 1 / 30
	K[kind].update(face.visState, t, ctx.beat or 0, ctx.c1 or WHITE, ctx.c2 or WHITE, ctx)
end

return Visuals
