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
	mk(vp, "Floor", Vector3.new(160, 1, 120), CFrame.new(0, -0.5, 30), Color3.fromRGB(16, 16, 22))
	sc.wall = mk(vp, "BackGlow", Vector3.new(200, 60, 1), CFrame.new(0, 20, 70), self.color, Enum.Material.Neon)
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
	-- camera on the stage, panning slowly along the rows
	local a = t * 0.22 + face.seed
	local pos = Vector3.new(math.sin(a) * 22, 9 + math.sin(t * 0.13) * 2, -14)
	face.liveCam.FieldOfView = 46
	face.liveCam.CFrame = CFrame.lookAt(pos, Vector3.new(math.sin(a + 0.5) * 16, 3.5, 14))
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
