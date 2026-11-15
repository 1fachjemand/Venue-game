-- Live camera pictures for LED screens ("Live: artist" / "Live: crowd").
-- Every screen face gets its own little 3D scene inside its ViewportFrame:
--   artist: copies of the performers (synced every frame) in front of a glowing LED wall, the camera slowly circles them
--   crowd:  a crowd of fans with raised arms, light sticks and phone lights, the camera pans along the rows
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)

local New = UI.New
local LiveFeed = {}
LiveFeed.__index = LiveFeed

local SHIRTS = {
	Color3.fromRGB(20, 20, 24), Color3.fromRGB(230, 230, 235), Color3.fromRGB(200, 40, 60), Color3.fromRGB(40, 90, 200),
	Color3.fromRGB(250, 200, 50), Color3.fromRGB(60, 160, 90), Color3.fromRGB(150, 60, 200), Color3.fromRGB(255, 120, 170),
}

local function mk(parent, name, size, cf, color, material, shape)
	local p = New("Part", {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = parent,
	})
	if shape then
		p.Shape = shape
	end
	return p
end

-- opts: { performers = { People objects }, color = artist colour }
function LiveFeed.new(opts)
	local self = setmetatable({}, LiveFeed)
	self.performers = opts.performers or {}
	self.color = opts.color or Color3.new(1, 1, 1)
	self.sources = {}
	for _, p in ipairs(self.performers) do
		for _, part in ipairs(p.model:GetChildren()) do
			if part:IsA("BasePart") then
				table.insert(self.sources, part)
			end
		end
	end
	return self
end

------------------------------------------------------------------ crowd scene
local function buildCrowd(self, vp)
	local sc = { kind = "liveCrowd", fans = {}, beams = {} }
	vp.Ambient = Color3.fromRGB(120, 120, 150)
	mk(vp, "Floor", Vector3.new(600, 1, 120), CFrame.new(-100, -0.5, 30), Color3.fromRGB(16, 16, 22))
	sc.wall = mk(vp, "BackGlow", Vector3.new(600, 60, 1), CFrame.new(-100, 20, 70), self.color, Enum.Material.Neon)
	sc.wall.Transparency = 0.75
	for i = 0, 7 do
		local x = -42 + i * 12
		local b = mk(vp, "Beam", Vector3.new(1.2, 70, 1.2), CFrame.new(x, 30, 60) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.35 or -0.35), self.color, Enum.Material.Neon)
		b.Transparency = 0.6
		table.insert(sc.beams, b)
	end
	local rng = Random.new(77)
	for row = 0, 7 do
		for col = 0, 17 do
			local base = Vector3.new(-36 + col * 4.2 + rng:NextNumber() * 1.6, 0, row * 4.4 + rng:NextNumber() * 1.4)
			local shirt = (rng:NextNumber() < 0.3) and self.color or SHIRTS[rng:NextInteger(1, #SHIRTS)]
			local f = { base = base, ph = rng:NextNumber() * 6.28, parts = {} }
			f.body = mk(vp, "Fan", Vector3.new(1.6, 2.8, 1), CFrame.new(base + Vector3.new(0, 1.4, 0)), shirt)
			f.head = mk(vp, "Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(base + Vector3.new(0, 3.45, 0)), People.SKINS[rng:NextInteger(1, #People.SKINS)], nil, Enum.PartType.Ball)
			local r = rng:NextNumber()
			if r < 0.35 then
				f.armL = mk(vp, "Arm", Vector3.new(0.5, 2, 0.5), CFrame.new(base), shirt)
				f.armR = mk(vp, "Arm", Vector3.new(0.5, 2, 0.5), CFrame.new(base), shirt)
			end
			if r > 0.7 then
				f.stick = mk(vp, "LightStick", Vector3.new(0.3, 1.6, 0.3), CFrame.new(base), self.color, Enum.Material.Neon)
			elseif r > 0.55 then
				f.stick = mk(vp, "Phone", Vector3.new(0.5, 0.8, 0.12), CFrame.new(base), Color3.fromRGB(255, 255, 230), Enum.Material.Neon)
			end
			table.insert(sc.fans, f)
		end
	end
	-- close-up groups in front of the crowd; the camera cuts between them and the wide pan
	-- { x position, kind }: phones = two fans waving phone lights, dance = two fans dancing, costume = dressed-up fans,
	-- sign = a fan with a big sign, couple = two friends singing along arm in arm
	sc.groups = {}
	local looks = {
		costume = { { acc = "cowboy", hair = "long" }, { acc = "sparkle", hair = "bun" }, { acc = "headphones", hair = "afro" } },
		dance = { { acc = "sunglasses", hair = "pony" }, { acc = "cap", hair = "short" } },
		phones = { { acc = "earrings", hair = "long" }, { acc = "beanie", hair = "messy" } },
		couple = { { acc = "bandana", hair = "pigtails" }, { acc = "chain", hair = "buzz" } },
		sign = { { acc = "cap", hair = "long" } },
	}
	local kinds = { "phones", "dance", "costume", "sign", "couple" }
	for gi, kind in ipairs(kinds) do
		local gx = -260 + gi * 40
		local g = { x = gx, kind = kind, figs = {} }
		-- a few rows of plain fans behind them, so every close-up has a crowd in the background
		for row = 0, 2 do
			for col = 0, 5 do
				local base = Vector3.new(gx - 10 + col * 4 + rng:NextNumber() * 1.4, 0, 6 + row * 4)
				local shirt = (rng:NextNumber() < 0.3) and self.color or SHIRTS[rng:NextInteger(1, #SHIRTS)]
				local f = { base = base, ph = rng:NextNumber() * 6.28 }
				f.body = mk(vp, "Fan", Vector3.new(1.6, 2.8, 1), CFrame.new(base + Vector3.new(0, 1.4, 0)), shirt)
				f.head = mk(vp, "Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(base + Vector3.new(0, 3.45, 0)), People.SKINS[rng:NextInteger(1, #People.SKINS)], nil, Enum.PartType.Ball)
				if rng:NextNumber() < 0.4 then
					f.stick = mk(vp, "Phone", Vector3.new(0.5, 0.8, 0.12), CFrame.new(base), Color3.fromRGB(255, 255, 230), Enum.Material.Neon)
				end
				table.insert(sc.fans, f)
			end
		end
		local lk = looks[kind]
		for i, look in ipairs(lk) do
			local shirt = (i % 2 == 1) and self.color or SHIRTS[rng:NextInteger(1, #SHIRTS)]
			look.top = { math.floor(shirt.R * 255), math.floor(shirt.G * 255), math.floor(shirt.B * 255) }
			local fig = People.new(vp, shirt, 1, "crowd", gi * 10 + i, look)
			local fo = { fig = fig, off = (i - (#lk + 1) / 2) * 2.4, ph = rng:NextNumber() * 6 }
			if kind == "phones" then
				fo.phone = mk(vp, "PhoneLight", Vector3.new(0.45, 0.75, 0.1), CFrame.new(), Color3.fromRGB(255, 255, 235), Enum.Material.Neon)
			end
			if kind == "costume" and i == 2 then
				fo.ears = { mk(vp, "Ear", Vector3.new(0.4, 0.7, 0.2), CFrame.new(), self.color, Enum.Material.Neon), mk(vp, "Ear", Vector3.new(0.4, 0.7, 0.2), CFrame.new(), self.color, Enum.Material.Neon) }
			end
			table.insert(g.figs, fo)
		end
		if kind == "sign" then
			g.sign = mk(vp, "Sign", Vector3.new(4.4, 2.6, 0.12), CFrame.new(), Color3.fromRGB(250, 250, 250))
			g.signText = mk(vp, "SignHeart", Vector3.new(1.4, 1.4, 0.1), CFrame.new(), self.color, Enum.Material.Neon, Enum.PartType.Ball)
		end
		table.insert(sc.groups, g)
	end
	return sc
end

local function updateCrowd(sc, face, ctx)
	local t = ctx.t
	local energy = ctx.crowdEnergy or 1
	local speed = ctx.crowdSpeed or 6
	for _, f in ipairs(sc.fans) do
		local j = math.sin(t * speed + f.ph)
		if j < 0 then
			j = 0
		end
		local up = Vector3.new(0, j * 0.8 * energy, 0)
		local b = f.base + up
		f.body.CFrame = CFrame.new(b + Vector3.new(0, 1.4, 0))
		f.head.CFrame = CFrame.new(b + Vector3.new(0, 3.45, 0))
		local wave = math.sin(t * 2 + f.ph) * 0.35
		if f.armL then
			f.armL.CFrame = CFrame.new(b + Vector3.new(-1.1, 3.6, 0)) * CFrame.Angles(0, 0, -0.3 + wave)
			f.armR.CFrame = CFrame.new(b + Vector3.new(1.1, 3.6, 0)) * CFrame.Angles(0, 0, 0.3 + wave)
		end
		if f.stick then
			f.stick.CFrame = CFrame.new(b + Vector3.new(0.9, 5 + (ctx.phones and 0.6 or 0), 0)) * CFrame.Angles(0, 0, wave)
		end
	end
	for i, bm in ipairs(sc.beams) do
		bm.Color = (i % 2 == 0) and ctx.c1 or ctx.c2
		bm.CFrame = CFrame.new(-42 + (i - 1) * 12, 30, 60) * CFrame.Angles(0, 0, math.sin(t * 0.6 + i) * 0.45)
	end
	sc.wall.Color = ctx.c1:Lerp(ctx.c2, 0.5 + 0.5 * math.sin(t))
	-- the close-up groups (they face the stage, i.e. the camera)
	local beat = ctx.beat or 0
	for _, g in ipairs(sc.groups) do
		for i, fo in ipairs(g.figs) do
			local pos = Vector3.new(g.x + fo.off, 0, 1)
			local opts = { t = t + fo.ph, beat = beat, energy = 1, walking = false, armsUp = 0, move = "idle" }
			local yaw = math.pi
			if g.kind == "phones" then
				opts.armsUp = 1
			elseif g.kind == "dance" then
				opts.move = "dance"
			elseif g.kind == "costume" then
				opts.move = (i % 2 == 0) and "jump" or "wave"
			elseif g.kind == "sign" then
				opts.armsUp = 1
			elseif g.kind == "couple" then
				opts.move = "wave"
				yaw = math.pi + ((i == 1) and 0.25 or -0.25) + math.sin(t * 1.5) * 0.1
			end
			fo.fig:update(pos, yaw, opts)
			if fo.phone then
				fo.phone.CFrame = fo.fig.armR.CFrame * CFrame.new(0, -1.15, 0) * CFrame.Angles(0, 0, math.sin(t * 2.4 + fo.ph) * 0.4)
				fo.phone.Color = ctx.phones and Color3.fromRGB(255, 255, 235) or Color3.fromRGB(180, 200, 255)
			end
			if fo.ears then
				local hc = fo.fig.head.CFrame
				fo.ears[1].CFrame = hc * CFrame.new(-0.4, 0.75, 0) * CFrame.Angles(0, 0, 0.3)
				fo.ears[2].CFrame = hc * CFrame.new(0.4, 0.75, 0) * CFrame.Angles(0, 0, -0.3)
				fo.ears[1].Color, fo.ears[2].Color = ctx.c1, ctx.c1
			end
		end
		if g.sign then
			local f1 = g.figs[1].fig
			local top = (f1.armL.CFrame.Position + f1.armR.CFrame.Position) / 2 + Vector3.new(0, 1.3, 0)
			g.sign.CFrame = CFrame.new(top) * CFrame.Angles(0, math.pi, math.sin(t * 2) * 0.06)
			g.signText.CFrame = g.sign.CFrame * CFrame.new(0, 0, 0.1)
			g.signText.Color = ctx.c1
		end
	end
	-- camera: cuts between a slow pan over the crowd and close-ups of the groups
	local shot = math.floor((t + face.seed * 7) / 6) % (#sc.groups + 2)
	if shot >= 2 then
		local g = sc.groups[shot - 1]
		local sway = math.sin(t * 0.5) * 1.5
		face.liveCam.FieldOfView = 34
		face.liveCam.CFrame = CFrame.lookAt(Vector3.new(g.x + sway, 4.6, -9), Vector3.new(g.x, 3.8, 2))
	else
		local a = t * 0.22 + face.seed
		local pos = Vector3.new(math.sin(a) * 22, 9 + math.sin(t * 0.13) * 2, -14)
		face.liveCam.FieldOfView = 46
		face.liveCam.CFrame = CFrame.lookAt(pos, Vector3.new(math.sin(a + 0.5) * 16, 3.5, 14))
	end
end

------------------------------------------------------------------ artist scene
local function buildArtist(self, vp)
	local sc = { kind = "liveArtist", copies = {} }
	vp.Ambient = Color3.fromRGB(170, 170, 190)
	for _, src in ipairs(self.sources) do
		local c = src:Clone()
		c.Parent = vp
		table.insert(sc.copies, { src = src, copy = c })
	end
	sc.wall = mk(vp, "LEDWall", Vector3.new(70, 34, 1), CFrame.new(), self.color, Enum.Material.Neon)
	sc.wall.Transparency = 0.35
	sc.floor = mk(vp, "Deck", Vector3.new(60, 1, 60), CFrame.new(), Color3.fromRGB(30, 30, 38))
	sc.lights = {}
	for i = 1, 5 do
		table.insert(sc.lights, mk(vp, "Light", Vector3.new(1.6, 1.6, 1.6), CFrame.new(), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball))
	end
	return sc
end

local function updateArtist(sc, face, ctx)
	for _, pair in ipairs(sc.copies) do
		pair.copy.CFrame = pair.src.CFrame
		pair.copy.Transparency = pair.src.Transparency
	end
	local t = ctx.t
	local leadPos = ctx.leadPos or Vector3.new()
	local yaw = ctx.leadYaw or 0
	local head = leadPos + Vector3.new(0, 6.5, 0)
	-- the camera swings around the front of the artist
	local a = yaw + math.sin(t * 0.3 + face.seed) * 0.9
	local dist = 11 + math.sin(t * 0.2 + face.seed) * 3
	local camPos = head + Vector3.new(math.sin(a) * dist, 1.2, math.cos(a) * dist)
	local dir = (head - camPos).Unit
	sc.wall.CFrame = CFrame.lookAt(head + dir * 22, camPos)
	sc.wall.Color = ctx.c1:Lerp(ctx.c2, 0.5 + 0.5 * math.sin(t * 1.3))
	sc.floor.CFrame = CFrame.new(leadPos - Vector3.new(0, 0.55, 0))
	local right = dir:Cross(Vector3.new(0, 1, 0))
	for i, l in ipairs(sc.lights) do
		l.CFrame = CFrame.new(head + dir * 20 + right * ((i - 3) * 9) + Vector3.new(0, 12, 0))
		l.Color = (i % 2 == 0) and ctx.c1 or ctx.c2
	end
	face.liveCam.FieldOfView = 38
	face.liveCam.CFrame = CFrame.lookAt(camPos, head - Vector3.new(0, 1.4, 0))
end

------------------------------------------------------------------ public
-- called by the screen animation: face = { live = ViewportFrame, liveCam = Camera }, mode = "liveArtist" | "liveCrowd"
function LiveFeed:update(face, mode, ctx)
	if not face.scene or face.scene.kind ~= mode then
		for _, c in ipairs(face.live:GetChildren()) do
			if c:IsA("BasePart") then
				c:Destroy()
			end
		end
		face.seed = face.seed or (math.random() * 6)
		face.scene = (mode == "liveCrowd") and buildCrowd(self, face.live) or buildArtist(self, face.live)
		face.nextT = 0
	end
	-- 30 updates per second are enough for a screen
	if ctx.t < (face.nextT or 0) then
		return
	end
	face.nextT = ctx.t + 1 / 30
	if mode == "liveCrowd" then
		updateCrowd(face.scene, face, ctx)
	else
		updateArtist(face.scene, face, ctx)
	end
end

return LiveFeed
