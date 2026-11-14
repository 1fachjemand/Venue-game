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

-- role: "lead" (mic), "guitar", "bass", "drums", "dancer", "dj"
function People.new(parent, outfit, scale, role, seed)
	local self = setmetatable({}, People)
	local s = scale or 1.4
	self.s = s
	self.role = role or "lead"
	local rng = Random.new(seed or 1)
	local skin = SKINS[rng:NextInteger(1, #SKINS)]
	local hair = HAIR[rng:NextInteger(1, #HAIR)]
	local pants = Color3.fromRGB(25, 25, 32)
	local model = New("Model", { Name = "Performer", Parent = parent })
	self.model = model
	self.legL = mk(model, "LegL", Vector3.new(0.9, 2, 0.9) * s, pants)
	self.legR = mk(model, "LegR", Vector3.new(0.9, 2, 0.9) * s, pants)
	self.torso = mk(model, "Torso", Vector3.new(2, 2, 1) * s, outfit)
	self.armL = mk(model, "ArmL", Vector3.new(0.85, 2, 0.85) * s, outfit)
	self.armR = mk(model, "ArmR", Vector3.new(0.85, 2, 0.85) * s, outfit)
	self.head = mk(model, "Head", Vector3.new(1.2, 1.2, 1.2) * s, skin)
	self.hair = mk(model, "Hair", Vector3.new(1.3, 0.45, 1.3) * s, hair)
	self.eyeL = mk(model, "EyeL", Vector3.new(0.18, 0.22, 0.05) * s, Color3.new(0, 0, 0))
	self.eyeR = mk(model, "EyeR", Vector3.new(0.18, 0.22, 0.05) * s, Color3.new(0, 0, 0))
	if self.role == "lead" then
		self.prop = mk(model, "Mic", Vector3.new(0.25, 0.9, 0.25) * s, Color3.fromRGB(20, 20, 20), Enum.Material.Metal)
	elseif self.role == "guitar" or self.role == "bass" then
		local c = self.role == "guitar" and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(240, 240, 240)
		self.prop = mk(model, "Guitar", Vector3.new(2.6, 0.9, 0.25) * s, c)
	end
	self.pos = Vector3.new()
	self.yaw = 0
	return self
end

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
	elseif move == "piano" or move == "drumsolo" then
		drop = 1.4 * s -- sitting
		bob = 0
	end
	local root = CFrame.new(pos) * CFrame.Angles(0, yaw + hipYaw, 0) * CFrame.new(0, bob + lift - drop, 0)
	local swing = (move == "walk") and math.sin(t * 9) * 0.6 or beatWave * 0.12 * e

	-- legs
	local legLA, legRA = swing, -swing
	if move == "kneel" then
		legLA, legRA = 1.45, -0.3
	elseif move == "piano" or move == "drumsolo" then
		legLA, legRA = 1.5, 1.5
	elseif move == "jump" then
		legLA, legRA = 0.35 * math.abs(beatWave), 0.35 * math.abs(beatWave)
	end
	self.legL.CFrame = root * CFrame.new(-0.5 * s, 2 * s, 0) * CFrame.Angles(legLA, 0, 0) * CFrame.new(0, -1 * s, 0)
	self.legR.CFrame = root * CFrame.new(0.5 * s, 2 * s, 0) * CFrame.Angles(legRA, 0, 0) * CFrame.new(0, -1 * s, 0)
	-- upper body bends at the hips
	local hip = root * CFrame.new(0, 2 * s, 0) * CFrame.Angles(lean, 0, sway)
	self.torso.CFrame = hip * CFrame.new(0, 1 * s, 0)
	local headCF = hip * CFrame.new(0, 2.6 * s, 0) * CFrame.Angles(headPitch, 0, 0)
	self.head.CFrame = headCF
	self.hair.CFrame = headCF * CFrame.new(0, 0.7 * s, -0.05 * s)
	self.eyeL.CFrame = headCF * CFrame.new(-0.25 * s, 0.1 * s, 0.61 * s)
	self.eyeR.CFrame = headCF * CFrame.new(0.25 * s, 0.1 * s, 0.61 * s)

	-- arms: rotation forward/back (x) and sideways (z)
	local up = opts.armsUp or 0
	local lx, lz = -swing * 0.8, 0
	local rx, rz = swing * 0.8, 0
	if move == "wave" or up > 0.5 then
		lx, lz = -2.8, -0.25 + math.sin(t * 5) * 0.35
		rx, rz = -2.8, 0.25 - math.sin(t * 5) * 0.35
	elseif move == "point" then
		lx, lz = -1.75, 0.1
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
	elseif move == "piano" then
		lx, lz = -1.35 + math.sin(t * 7) * 0.08, 0.15
		rx, rz = -1.35 + math.sin(t * 7 + 2) * 0.08, -0.15
	elseif move == "drumsolo" then
		lx, lz = -0.9 + math.sin(t * 16 + 1.5) * 0.5, 0
		rx, rz = -0.9 + math.sin(t * 16) * 0.5, 0
	end
	local micAtMouth = false
	if self.role == "lead" and (move == "piano" or move == "drumsolo") then
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
				self.prop.CFrame = headCF * CFrame.new(0.1 * s, -0.35 * s, 0.85 * s) * CFrame.Angles(math.rad(-70), 0, 0)
			else
				self.prop.CFrame = self.armR.CFrame * CFrame.new(0, -1.2 * s, 0)
			end
		else
			self.prop.CFrame = hip * CFrame.new(0.2 * s, 0.6 * s, 0.75 * s) * CFrame.Angles(0, 0, math.rad(25))
		end
	end
	self.pos = pos
	self.yaw = yaw
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
