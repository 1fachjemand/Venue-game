-- Blocky performer figures (no external assets needed). Figures face +Z (towards the crowd) at yaw 0.
local Root = script:FindFirstAncestor("Headliner")
local UI = require(Root.Client.UI)
local New = UI.New

local People = {}
People.__index = People

local SKINS = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 134, 94),
	Color3.fromRGB(141, 85, 54),
	Color3.fromRGB(90, 56, 37),
}
local HAIR = {
	Color3.fromRGB(30, 24, 20),
	Color3.fromRGB(90, 60, 30),
	Color3.fromRGB(230, 200, 120),
	Color3.fromRGB(200, 60, 60),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(240, 240, 250),
}
People.SKINS = SKINS

local function mk(parent, name, size, color, material, shape)
	local p = New("Part", {
		Name = name,
		Size = size,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
	if shape then
		p.Shape = shape
	end
	return p
end

local function c3(t, fallback)
	if type(t) == "table" then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return fallback
end

-- role: "lead" (mic), "guitar", "bass", "drums", "dancer", "dj", "crowd"
-- look (optional): { skin = 1..5, hair = "short"|"long"|"bun"|"pony"|"pigtails"|"afro"|"buzz"|"messy"|"mohawk",
--   hairColor, top, pants, shoes, jacket = {r,g,b}, acc = "sunglasses"|"cap"|"cowboy"|"headphones"|"bandana"|"beanie"|"chain"|"earrings"|"sparkle" }
function People.new(parent, outfit, scale, role, seed, look)
	local self = setmetatable({}, People)
	local s = scale or 1.4
	self.s = s
	self.role = role or "lead"
	local rng = Random.new(seed or 1)
	look = look or {}
	local skin = (look.skin and SKINS[look.skin]) or SKINS[rng:NextInteger(1, #SKINS)]
	local hair = c3(look.hairColor, HAIR[rng:NextInteger(1, #HAIR)])
	local pants = c3(look.pants, Color3.fromRGB(25, 25, 32))
	local top = c3(look.top, outfit)
	local model = New("Model", { Name = "Performer", Parent = parent })
	self.model = model
	self.legL = mk(model, "LegL", Vector3.new(0.9, 2, 0.9) * s, pants)
	self.legR = mk(model, "LegR", Vector3.new(0.9, 2, 0.9) * s, pants)
	self.torso = mk(model, "Torso", Vector3.new(2, 2, 1) * s, top)
	self.armL = mk(model, "ArmL", Vector3.new(0.85, 2, 0.85) * s, look.jacket and c3(look.jacket) or top)
	self.armR = mk(model, "ArmR", Vector3.new(0.85, 2, 0.85) * s, look.jacket and c3(look.jacket) or top)
	self.head = mk(model, "Head", Vector3.new(1.2, 1.2, 1.2) * s, skin)
	self.eyeL = mk(model, "EyeL", Vector3.new(0.18, 0.22, 0.05) * s, Color3.new(0, 0, 0))
	self.eyeR = mk(model, "EyeR", Vector3.new(0.18, 0.22, 0.05) * s, Color3.new(0, 0, 0))
	-- extras follow the head ("head") or the upper body ("torso"): { part, attach, offset }
	self.extras = {}
	local function extra(name, size, attach, off, color, material, shape)
		local p = mk(model, name, size * s, color, material, shape)
		table.insert(self.extras, { p, attach, CFrame.new(off.Position * s) * (off - off.Position) })
		return p
	end
	local style = look.hair or ((rng:NextNumber() < 0.5) and "short" or "messy")
	local hat = look.acc == "cap" or look.acc == "beanie" or look.acc == "cowboy" or look.worker
	if style ~= "buzz" and style ~= "afro" and style ~= "mohawk" and not hat then
		extra("Hair", Vector3.new(1.3, 0.45, 1.3), "head", CFrame.new(0, 0.7, -0.05), hair)
	end
	if style == "buzz" then
		extra("Hair", Vector3.new(1.24, 0.2, 1.24), "head", CFrame.new(0, 0.55, -0.02), hair)
	elseif style == "long" then
		extra("HairBack", Vector3.new(1.3, 1.7, 0.4), "head", CFrame.new(0, -0.15, -0.55), hair)
	elseif style == "bun" then
		-- a knot on top: two crossed blocks
		extra("HairBun", Vector3.new(0.72, 0.5, 0.72), "head", CFrame.new(0, 1.05, -0.3) * CFrame.Angles(0, math.rad(45), 0), hair)
		extra("HairBun", Vector3.new(0.5, 0.36, 0.5), "head", CFrame.new(0, 1.36, -0.3), hair)
	elseif style == "pony" then
		extra("HairTail", Vector3.new(0.45, 1.5, 0.45), "head", CFrame.new(0, 0.1, -0.8) * CFrame.Angles(0.35, 0, 0), hair)
	elseif style == "pigtails" then
		extra("HairTail", Vector3.new(0.4, 1.2, 0.4), "head", CFrame.new(-0.75, 0, -0.2) * CFrame.Angles(0, 0, -0.3), hair)
		extra("HairTail", Vector3.new(0.4, 1.2, 0.4), "head", CFrame.new(0.75, 0, -0.2) * CFrame.Angles(0, 0, 0.3), hair)
	elseif style == "afro" then
		-- a big blocky afro: crown, both sides and the back
		extra("Afro", Vector3.new(1.7, 0.78, 1.6), "head", CFrame.new(0, 0.74, -0.1), hair)
		extra("Afro", Vector3.new(1.36, 0.36, 1.3), "head", CFrame.new(0, 1.28, -0.12), hair)
		extra("Afro", Vector3.new(0.3, 1.0, 1.4), "head", CFrame.new(-0.76, 0.25, -0.12), hair)
		extra("Afro", Vector3.new(0.3, 1.0, 1.4), "head", CFrame.new(0.76, 0.25, -0.12), hair)
		extra("Afro", Vector3.new(1.6, 1.1, 0.35), "head", CFrame.new(0, 0.2, -0.8), hair)
	elseif style == "messy" then
		extra("HairFringe", Vector3.new(1.32, 0.35, 0.3), "head", CFrame.new(0, 0.42, 0.55) * CFrame.Angles(-0.4, 0, 0), hair)
	elseif style == "mohawk" then
		extra("Mohawk", Vector3.new(0.3, 0.7, 1.3), "head", CFrame.new(0, 0.85, 0), hair)
	end
	local acc = look.acc or "none"
	if acc == "sunglasses" then
		-- real sunglasses: two lenses, a bridge and thin arms to the ears (not one black bar)
		local frame, lens = Color3.fromRGB(20, 20, 24), Color3.fromRGB(40, 50, 70)
		extra("ShadesLens", Vector3.new(0.38, 0.26, 0.05), "head", CFrame.new(-0.25, 0.1, 0.625), lens, Enum.Material.Glass)
		extra("ShadesLens", Vector3.new(0.38, 0.26, 0.05), "head", CFrame.new(0.25, 0.1, 0.625), lens, Enum.Material.Glass)
		extra("ShadesBridge", Vector3.new(0.14, 0.05, 0.04), "head", CFrame.new(0, 0.17, 0.634), frame)
		extra("ShadesTop", Vector3.new(0.9, 0.05, 0.05), "head", CFrame.new(0, 0.235, 0.628), frame)
		extra("ShadesArm", Vector3.new(0.04, 0.05, 0.62), "head", CFrame.new(-0.62, 0.2, 0.32), frame)
		extra("ShadesArm", Vector3.new(0.04, 0.05, 0.62), "head", CFrame.new(0.62, 0.2, 0.32), frame)
	elseif acc == "cap" then
		extra("Cap", Vector3.new(1.32, 0.35, 1.32), "head", CFrame.new(0, 0.72, 0), top)
		extra("CapBrim", Vector3.new(1.2, 0.1, 0.7), "head", CFrame.new(0, 0.58, 0.85), top)
	elseif acc == "cowboy" then
		extra("HatBrim", Vector3.new(2.2, 0.1, 2.2), "head", CFrame.new(0, 0.62, 0), Color3.fromRGB(150, 110, 70), nil)
		extra("HatCrown", Vector3.new(1.25, 0.7, 1.25), "head", CFrame.new(0, 0.98, 0), Color3.fromRGB(150, 110, 70))
	elseif acc == "headphones" then
		extra("Phones", Vector3.new(1.45, 0.18, 0.25), "head", CFrame.new(0, 0.72, 0), Color3.fromRGB(20, 20, 22))
		extra("PhoneL", Vector3.new(0.25, 0.6, 0.6), "head", CFrame.new(-0.68, 0.05, 0), Color3.fromRGB(0, 230, 255), Enum.Material.Neon)
		extra("PhoneR", Vector3.new(0.25, 0.6, 0.6), "head", CFrame.new(0.68, 0.05, 0), Color3.fromRGB(0, 230, 255), Enum.Material.Neon)
	elseif acc == "bandana" then
		extra("Bandana", Vector3.new(1.28, 0.22, 1.28), "head", CFrame.new(0, 0.38, 0), Color3.fromRGB(200, 30, 40), Enum.Material.Fabric)
	elseif acc == "beanie" then
		extra("Beanie", Vector3.new(1.35, 0.6, 1.35), "head", CFrame.new(0, 0.72, 0), Color3.fromRGB(200, 120, 60), Enum.Material.Fabric)
	elseif acc == "chain" then
		extra("Chain", Vector3.new(1.3, 0.12, 0.1), "torso", CFrame.new(0, 0.55, 0.53), Color3.fromRGB(255, 205, 60), Enum.Material.Metal)
		extra("Pendant", Vector3.new(0.35, 0.35, 0.1), "torso", CFrame.new(0, 0.3, 0.55), Color3.fromRGB(255, 205, 60), Enum.Material.Neon)
	elseif acc == "earrings" then
		extra("Earring", Vector3.new(0.18, 0.3, 0.18), "head", CFrame.new(-0.64, -0.25, 0), Color3.fromRGB(255, 215, 90), Enum.Material.Metal)
		extra("Earring", Vector3.new(0.18, 0.3, 0.18), "head", CFrame.new(0.64, -0.25, 0), Color3.fromRGB(255, 215, 90), Enum.Material.Metal)
	elseif acc == "backpack" then
		extra("Backpack", Vector3.new(1.5, 1.6, 0.7), "torso", CFrame.new(0, 0, -0.86), (look.bag and c3(look.bag)) or Color3.fromRGB(60, 70, 90), Enum.Material.Fabric)
	elseif acc == "sparkle" then
		-- a glittering belt: a bit bigger than the torso and the jacket (1.06 deep), so no faces lie on top of each other
		extra("Sparkles", Vector3.new(2.1, 0.6, 1.14), "torso", CFrame.new(0, -0.2, 0), Color3.fromRGB(255, 235, 250), Enum.Material.Neon)
	end
	if look.worker then
		-- stage crew: yellow hard hat, reflective stripes on the vest
		extra("HardHat", Vector3.new(1.4, 0.5, 1.4), "head", CFrame.new(0, 0.78, 0), Color3.fromRGB(250, 204, 21))
		extra("HardHatBrim", Vector3.new(1.6, 0.1, 1.7), "head", CFrame.new(0, 0.55, -0.05), Color3.fromRGB(250, 204, 21))
		extra("VestStripe", Vector3.new(2.04, 0.18, 1.04), "torso", CFrame.new(0, -0.35, 0), Color3.fromRGB(220, 224, 230), Enum.Material.Foil)
		extra("VestStripe", Vector3.new(2.04, 0.18, 1.04), "torso", CFrame.new(0, 0.25, 0), Color3.fromRGB(220, 224, 230), Enum.Material.Foil)
	end
	if look.jacket then
		extra("JacketL", Vector3.new(0.6, 2.02, 1.06), "torso", CFrame.new(-0.72, 0, 0), c3(look.jacket))
		extra("JacketR", Vector3.new(0.6, 2.02, 1.06), "torso", CFrame.new(0.72, 0, 0), c3(look.jacket))
	end
	if look.shoes then
		self.shoeL = mk(model, "ShoeL", Vector3.new(0.95, 0.35, 1.1) * s, c3(look.shoes))
		self.shoeR = mk(model, "ShoeR", Vector3.new(0.95, 0.35, 1.1) * s, c3(look.shoes))
	end
	if self.role == "lead" then
		self.prop = mk(model, "Mic", Vector3.new(0.25, 0.9, 0.25) * s, Color3.fromRGB(20, 20, 20), Enum.Material.Metal)
	elseif self.role == "guitar" or self.role == "bass" then
		-- rounded electric guitar / bass: body bouts (ellipsoids), pickguard, neck, headstock
		local bass = self.role == "bass"
		local c = bass and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(200, 40, 40)
		local function oval(name, size, color, material)
			local p = mk(model, name, size * s, color, material or Enum.Material.Glass)
			New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
			return p
		end
		self.prop = oval("Guitar", Vector3.new(1.25, 1.05, 0.3), c)
		local neckLen = bass and 2.4 or 1.9
		self.propParts = {
			{ oval("GuitarUpper", Vector3.new(0.95, 0.8, 0.3), c), CFrame.new(0, 0.62 * s, 0) },
			{ oval("GuitarHorn", Vector3.new(0.3, 0.6, 0.28), c), CFrame.new(-0.32 * s, 0.95 * s, 0) * CFrame.Angles(0, 0, 0.25) },
			{ oval("Pickguard", Vector3.new(0.6, 0.9, 0.04), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic), CFrame.new(0.15 * s, 0.1 * s, 0.15 * s) },
			{ mk(model, "Neck", Vector3.new(0.2, neckLen, 0.12) * s, Color3.fromRGB(90, 60, 36), Enum.Material.Wood), CFrame.new(0, (1 + neckLen / 2) * s, 0.04 * s) },
			{ mk(model, "Headstock", Vector3.new(0.3, 0.5, 0.08) * s, Color3.fromRGB(30, 30, 32)), CFrame.new(0.04 * s, (1.25 + neckLen) * s, 0.02 * s) * CFrame.Angles(0, 0, -0.12) },
			{ mk(model, "Pickup", Vector3.new(0.45, 0.12, 0.05) * s, Color3.fromRGB(230, 230, 235), Enum.Material.Metal), CFrame.new(0, -0.2 * s, 0.17 * s) },
		}
	end
	self.pos = Vector3.new()
	self.yaw = 0
	return self
end

-- A random look for a band member / dancer of an artist
function People.bandLook(ad, i, styles)
	local st = styles[ad.genre] or styles.default
	local rng = Random.new(i * 31 + #ad.id)
	local function pickT(list)
		return list[rng:NextInteger(1, #list)]
	end
	local top = pickT(st.tops)
	if st.matchArtist and i % 2 == 0 then
		top = ad.color
	end
	return { skin = rng:NextInteger(1, #SKINS), hair = pickT(st.hair), hairColor = pickT({ { 20, 20, 20 }, { 90, 60, 30 }, { 200, 170, 110 }, ad.color }), top = top, pants = pickT(st.pants), acc = pickT(st.acc), shoes = { 20, 20, 22 } }
end

-- Shows a still figure inside a ViewportFrame (artist cards). Returns the ViewportFrame.
function People.preview(parent, look, color, pos, size, bg)
	local vp = New("ViewportFrame", {
		Parent = parent,
		Position = pos,
		Size = size,
		BackgroundColor3 = bg or Color3.fromRGB(26, 30, 44),
		BackgroundTransparency = bg and 0 or 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 205),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
	})
	-- a calm portrait: arms down, no microphone in front of the face
	local fig = People.new(vp, color, 1, "dancer", 3, look)
	fig:update(Vector3.new(0, 0, 0), math.rad(-18), { t = 0, beat = 0, energy = 0, walking = false, move = "idle" })
	local cam = New("Camera", { FieldOfView = 30, Parent = vp })
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, 11.5), Vector3.new(0, 3.1, 0))
	vp.CurrentCamera = cam
	return vp, fig
end

-- moves played on an instrument: sitting ones and those where both hands are busy (mic on a stand)
People.SEATED = { piano = true, pianosway = true, drumsolo = true, drumfill = true, harp = true, strum = true, typing = true, sitrelax = true }
People.BUSY = { piano = true, pianosway = true, drumsolo = true, drumfill = true, harp = true, strum = true, keys = true, keyshype = true, djmix = true, djhype = true, djknob = true }

-- opts: t, beat (0..1), energy (0..1), walking (bool), armsUp (0..1),
--       move = "idle" | "dance" | "jump" | "point" | "wave" | "kneel" | "headbang" | "micout" | "bow"
function People:update(pos, yaw, opts)
	local s = self.s
	local t = opts.t
	local move = opts.walking and "walk" or (opts.move or "idle")
	local e = opts.energy
	local beatWave = math.sin(opts.beat * math.pi * 2)
	local bob = math.abs(math.sin(opts.beat * math.pi)) * 0.35 * s * e
	local lift, drop, hipYaw, sway, lean, headPitch = 0, 0, 0, 0, 0, beatWave * 0.12 * e
	local shiftX = 0
	if move == "groove" then
		-- side steps to the beat
		shiftX = math.sin(t * 3.2) * 0.55 * s
		sway = -math.sin(t * 3.2) * 0.1
	elseif move == "spin" then
		hipYaw = (t * 5) % (math.pi * 2)
	elseif move == "hiphop" then
		bob = math.abs(math.sin(opts.beat * math.pi)) * 0.6 * s * e
		lean = 0.18
		hipYaw = math.sin(t * 1.6) * 0.25
	elseif move == "shimmy" then
		sway = math.sin(t * 16) * 0.09
		bob = bob * 0.5
	elseif move == "pose" then
		hipYaw, lean, bob = 0.45, -0.08, 0
	elseif move == "swayup" or move == "heart" then
		sway = math.sin(t * 2) * 0.08
		bob = bob * 0.4
	elseif move == "kick" or move == "clap" or move == "armwave" then
		hipYaw = math.sin(t * 2.4) * 0.15
	end
	if move == "jump" then
		lift = math.abs(math.sin(opts.beat * math.pi)) * 1.2 * s * e
	elseif move == "dance" then
		hipYaw = math.sin(t * 3.2) * 0.35
		sway = math.sin(t * 6.4) * 0.12
	elseif move == "kneel" then
		drop = 1.1 * s
		bob = 0
	elseif move == "headbang" then
		headPitch = math.sin(t * 11) * 0.55
		lean = 0.25 + math.sin(t * 11) * 0.12
	elseif move == "bow" then
		lean = 0.8
		bob = 0
	elseif People.SEATED[move] then
		drop = 2 * s - 2.25 -- sitting: hips on a seat about 2.25 studs high
		bob = 0
		if move == "pianosway" then
			sway = math.sin(t * 2.2) * 0.12
			lean = 0.12
		elseif move == "harp" then
			lean = 0.08
			sway = math.sin(t * 1.6) * 0.05
		end
	elseif move == "djknob" then
		headPitch = 0.25 + beatWave * 0.15 -- nodding to the beat, eyes on the mixer
	elseif move == "pop" then
		-- shot out of the pop-up lift: tucked legs, arms up
		lean = -0.15
		bob = 0
	end
	local root = CFrame.new(pos) * CFrame.Angles(0, yaw + hipYaw, 0) * CFrame.new(shiftX, bob + lift - drop, 0)
	local swing = (move == "walk") and math.sin(t * 9) * 0.6 or beatWave * 0.12 * e

	-- legs
	local legLA, legRA = swing, -swing
	if move == "kneel" then
		legLA, legRA = 1.45, -0.3
	elseif People.SEATED[move] then
		legLA, legRA = -0.8, -0.72 -- thighs forward and down, feet on the floor (never through the seat)
	elseif move == "pop" then
		legLA, legRA = -0.9, -0.35
	elseif move == "jump" then
		legLA, legRA = 0.35 * math.abs(beatWave), 0.35 * math.abs(beatWave)
	elseif move == "kick" then
		-- one leg kicks forward, then the other
		legLA, legRA = -1.1 * math.max(0, math.sin(t * 6)), -1.1 * math.max(0, -math.sin(t * 6))
	elseif move == "groove" then
		legLA, legRA = math.sin(t * 6.4) * 0.3, -math.sin(t * 6.4) * 0.3
	elseif move == "pose" then
		legLA, legRA = -0.25, 0.15
	end
	self.legL.CFrame = root * CFrame.new(-0.5 * s, 2 * s, 0) * CFrame.Angles(legLA, 0, 0) * CFrame.new(0, -1 * s, 0)
	self.legR.CFrame = root * CFrame.new(0.5 * s, 2 * s, 0) * CFrame.Angles(legRA, 0, 0) * CFrame.new(0, -1 * s, 0)
	if self.shoeL then
		self.shoeL.CFrame = self.legL.CFrame * CFrame.new(0, -0.85 * s, 0.1 * s)
		self.shoeR.CFrame = self.legR.CFrame * CFrame.new(0, -0.85 * s, 0.1 * s)
	end
	-- upper body bends at the hips
	local hip = root * CFrame.new(0, 2 * s, 0) * CFrame.Angles(lean, 0, sway)
	self.torso.CFrame = hip * CFrame.new(0, 1 * s, 0)
	local headCF = hip * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(headPitch, 0, 0)
	self.head.CFrame = headCF
	self.eyeL.CFrame = headCF * CFrame.new(-0.25 * s, 0.1 * s, 0.61 * s)
	self.eyeR.CFrame = headCF * CFrame.new(0.25 * s, 0.1 * s, 0.61 * s)
	local torsoCF = hip * CFrame.new(0, 1 * s, 0)
	for _, e in ipairs(self.extras) do
		e[1].CFrame = ((e[2] == "head") and headCF or torsoCF) * e[3]
	end

	-- arms: rotation forward/back (x) and sideways (z)
	local up = opts.armsUp or 0
	local lx, lz = -swing * 0.8, 0
	local rx, rz = swing * 0.8, 0
	if move == "pop" then
		lx, lz = -2.95, -0.35
		rx, rz = -2.95, 0.35
	elseif move == "wave" or up > 0.5 then
		lx, lz = -2.8, -0.25 + math.sin(t * 5) * 0.35
		rx, rz = -2.8, 0.25 - math.sin(t * 5) * 0.35
	elseif move == "point" then
		lx, lz = -1.75, 0.1
	elseif move == "groove" then
		lx, lz = -0.6 + math.sin(t * 6.4) * 0.5, -0.5
		rx, rz = -0.6 - math.sin(t * 6.4) * 0.5, 0.5
	elseif move == "spin" then
		lx, lz = -1.5, -1.2
		rx, rz = -1.5, 1.2
	elseif move == "hiphop" then
		-- arm pumps on the beat
		local pump = math.abs(math.sin(opts.beat * math.pi))
		lx, lz = -1.4 - pump * 1.2, -0.2
		rx, rz = -0.7, 0.35
	elseif move == "armwave" then
		-- arms out to the sides, a wave runs through them
		lx, lz = -0.2 + math.sin(t * 5) * 0.35, -1.45
		rx, rz = -0.2 + math.sin(t * 5 + 1.2) * 0.35, 1.45
	elseif move == "clap" then
		local c = math.abs(math.sin(opts.beat * math.pi))
		lx, lz = -2.6, -0.05 - c * 0.4
		rx, rz = -2.6, 0.05 + c * 0.4
	elseif move == "kick" then
		lx, lz = -0.9, -0.6
		rx, rz = -0.9, 0.6
	elseif move == "shimmy" then
		lx, lz = -1.2, -0.45 + math.sin(t * 16) * 0.1
		rx, rz = -1.2, 0.45 + math.sin(t * 16) * 0.1
	elseif move == "pose" then
		lx, lz = -2.95, -0.2
		rx, rz = -0.3, 0.7
	elseif move == "swayup" then
		lx, lz = -2.7, -0.3 + math.sin(t * 2) * 0.2
		rx, rz = -2.7, 0.3 + math.sin(t * 2) * 0.2
	elseif move == "heart" then
		-- arms make a heart above the head
		lx, lz = -2.7, 0.35
		rx, rz = -2.7, -0.35
	elseif move == "dance" then
		lx, lz = -1.0 + math.sin(t * 6.4) * 0.6, -0.3
		rx, rz = -1.0 - math.sin(t * 6.4) * 0.6, 0.3
	elseif move == "jump" then
		lx, lz = -2.6, -0.3
		rx, rz = -2.6, 0.3
	elseif move == "kneel" then
		lx, lz = -1.3, 0.2
	elseif move == "bow" then
		lx, lz = 0.3, -0.1
		rx, rz = 0.3, 0.1
	elseif move == "piano" or move == "keys" then
		lx, lz = -1.35 + math.sin(t * 7) * 0.08, 0.15
		rx, rz = -1.35 + math.sin(t * 7 + 2) * 0.08, -0.15
	elseif move == "drumsolo" then
		lx, lz = -0.9 + math.sin(t * 16 + 1.5) * 0.5, 0
		rx, rz = -0.9 + math.sin(t * 16) * 0.5, 0
	elseif move == "drumfill" then
		-- a fill over the toms: both sticks travel left and right
		lx, lz = -1.15 + math.sin(t * 20) * 0.45, 0.1 + math.sin(t * 5) * 0.35
		rx, rz = -1.15 + math.sin(t * 20 + 1.6) * 0.45, -0.1 + math.sin(t * 5) * 0.35
	elseif move == "pianosway" then
		lx, lz = -1.3 + math.sin(t * 5) * 0.14, 0.25 + math.sin(t * 2.2) * 0.15
		rx, rz = -1.3 + math.sin(t * 5 + 2) * 0.14, -0.05 + math.sin(t * 2.2) * 0.15
	elseif move == "keyshype" then
		lx, lz = -2.75 + math.sin(t * 6) * 0.15, -0.2
		rx, rz = -1.35 + math.sin(t * 8) * 0.08, -0.15
	elseif move == "harp" then
		-- both hands reach into the strings in front, plucking
		lx, lz = -1.2 + math.sin(t * 6) * 0.12, 0.35 + math.sin(t * 9) * 0.06
		rx, rz = -1.45 + math.sin(t * 6 + 1.4) * 0.12, -0.35 - math.sin(t * 9 + 1) * 0.06
	elseif move == "strum" then
		lx, lz = -1.1, 0.55
		rx, rz = -0.75 + math.sin(t * 12) * 0.25, -0.25
	elseif move == "typing" then
		-- hands on the keyboard, small quick moves
		lx, lz = -1.25 + math.sin(t * 13) * 0.05, 0.22
		rx, rz = -1.25 + math.sin(t * 11 + 1) * 0.05, -0.22
	elseif move == "sitrelax" then
		lx, lz = -0.5, 0.15
		rx, rz = -0.5, -0.15
	elseif move == "drink" then
		-- a cup: up to the mouth now and then
		local sip = math.max(0, math.sin(t * 0.9))
		rx, rz = -0.9 - sip * 1.2, 0.35 + sip * 0.25
		lx, lz = swing * 0.3, 0
	elseif move == "phone" then
		rx, rz = -2.5, 0.75 -- the phone at the ear
		lx, lz = -0.35 + math.sin(t * 2) * 0.25, -0.1
	elseif move == "stretch" then
		lx, lz = -2.95, -0.2
		rx, rz = -2.95, 0.2
	elseif move == "carry" then
		-- a box in front of the body, both hands under it
		lx, lz = -1.35, 0.32
		rx, rz = -1.35, -0.32
	elseif move == "djmix" then
		lx, lz = -1.15 + math.sin(t * 4) * 0.08, 0.1
		rx, rz = -1.1, -0.1 + math.sin(t * 8) * 0.25 -- scratching
	elseif move == "djhype" then
		lx, lz = -2.8 + math.abs(beatWave) * 0.25, -0.15 -- fist in the air
		rx, rz = -1.1 + math.sin(t * 4) * 0.08, -0.1
	elseif move == "djknob" then
		lx, lz = -1.2 + math.sin(t * 3) * 0.06, 0.2
		rx, rz = -1.2 + math.sin(t * 3 + 1) * 0.06, -0.2
	end
	local micAtMouth = false
	if self.role == "lead" and People.BUSY[move] then
		-- hands are busy: the mic hangs from a stand at the mouth
		micAtMouth = true
	elseif self.role == "lead" then
		if move == "micout" then
			rx, rz = -1.6, 0.15 -- mic held out to the crowd for a sing-along
			lx, lz = -2.6, -0.4
		elseif move ~= "bow" then
			rx, rz = -2.45, 0.9 -- hand at the mouth
			micAtMouth = true
		end
	elseif self.role == "guitar" or self.role == "bass" then
		rx, rz = -0.9 + math.sin(t * 14) * 0.25 * e, 0
		lx, lz = -1.1, 0
	elseif self.role == "drums" then
		rx, rz = -0.9 + math.sin(t * 16) * 0.5, 0
		lx, lz = -0.9 + math.sin(t * 16 + 1.5) * 0.5, 0
	elseif self.role == "dj" then
		rx, rz = -1.0 + math.sin(t * 5) * 0.15, 0
		if up < 0.5 then
			lx, lz = -1.0, 0
		end
	end
	self.armL.CFrame = hip * CFrame.new(-1.45 * s, 2 * s, 0) * CFrame.Angles(0, 0, lz) * CFrame.Angles(lx, 0, 0) * CFrame.new(0, -1 * s, 0)
	self.armR.CFrame = hip * CFrame.new(1.45 * s, 2 * s, 0) * CFrame.Angles(0, 0, rz) * CFrame.Angles(rx, 0, 0) * CFrame.new(0, -1 * s, 0)
	if self.prop then
		if self.role == "lead" then
			if micAtMouth then
				-- the grille end (top) is a hand's width in front of the mouth, never inside the head
				self.prop.CFrame = headCF * CFrame.new(0.1 * s, -0.36 * s, 1.17 * s) * CFrame.Angles(math.rad(-70), 0, 0)
			else
				self.prop.CFrame = self.armR.CFrame * CFrame.new(0, -1.2 * s, 0)
			end
		else
			-- the neck points up to the player's fretting hand
			self.prop.CFrame = hip * CFrame.new(-0.15 * s, 0.55 * s, 0.75 * s) * CFrame.Angles(0, 0, math.rad(25) - math.pi / 2)
		end
		if self.propParts then
			for _, pp in ipairs(self.propParts) do
				pp[1].CFrame = self.prop.CFrame * pp[2]
			end
		end
	end
	-- the lead plays the acoustic guitar of the acoustic set in their hands (made the first time it is needed)
	if self.role == "lead" and (move == "strum" or self.held) then
		self:holdAcoustic(move == "strum" and self.visible ~= false, hip, s)
	end
	self.pos = pos
	self.yaw = yaw
end

function People:holdAcoustic(on, hip, s)
	if not self.held then
		local wood, dark = Color3.fromRGB(210, 160, 100), Color3.fromRGB(60, 40, 26)
		local function oval(name, size, color)
			local p = mk(self.model, name, size * s, color, Enum.Material.Wood)
			New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
			return p
		end
		self.held = {
			{ oval("AcLower", Vector3.new(1.5, 1.25, 0.5), wood), CFrame.new(0, -0.1 * s, 0) },
			{ oval("AcUpper", Vector3.new(1.15, 0.95, 0.5), wood), CFrame.new(0, 0.75 * s, 0) },
			{ mk(self.model, "AcHole", Vector3.new(0.4, 0.4, 0.05) * s, Color3.fromRGB(30, 20, 14)), CFrame.new(0, 0.35 * s, 0.25 * s) },
			{ mk(self.model, "AcBridge", Vector3.new(0.5, 0.1, 0.06) * s, dark, Enum.Material.Wood), CFrame.new(0, -0.3 * s, 0.25 * s) },
			{ mk(self.model, "AcNeck", Vector3.new(0.2, 1.9, 0.12) * s, Color3.fromRGB(110, 70, 40), Enum.Material.Wood), CFrame.new(0, 2.1 * s, 0.05 * s) },
			{ mk(self.model, "AcHead", Vector3.new(0.3, 0.5, 0.08) * s, dark, Enum.Material.Wood), CFrame.new(0, 3.25 * s, 0.03 * s) },
		}
	end
	local base = hip * CFrame.new(-0.1 * s, 0.5 * s, 0.85 * s) * CFrame.Angles(0, 0, math.rad(25) - math.pi / 2)
	for _, h in ipairs(self.held) do
		h[1].CFrame = base * h[2]
		h[1].Transparency = on and 0 or 1
	end
end

function People:setVisible(on)
	if self.visible == on then
		return
	end
	self.visible = on
	for _, p in ipairs(self.model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Transparency = on and 0 or 1
		end
	end
end

function People:headPosition()
	return self.head.Position
end

function People:destroy()
	self.model:Destroy()
end

return People
