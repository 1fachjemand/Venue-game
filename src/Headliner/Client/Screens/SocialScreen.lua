-- SOCIAL: what fans post about your artists. Good shows get love, bad shows and high prices get criticism.
local Root = script:FindFirstAncestor("Headliner")
local Config = require(Root.Config)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local Social = require(Root.Logic.Social)
local UI = require(Root.Client.UI)
local People = require(Root.Client.People)

local T = UI.Theme
local BLACK = Color3.new(0, 0, 0)
local SocialScreen = {}
SocialScreen.__index = SocialScreen

local AVATARS = {
	Color3.fromRGB(255, 105, 180), Color3.fromRGB(45, 212, 191), Color3.fromRGB(108, 99, 255), Color3.fromRGB(255, 193, 7),
	Color3.fromRGB(255, 120, 60), Color3.fromRGB(46, 204, 113), Color3.fromRGB(0, 180, 255), Color3.fromRGB(200, 120, 255),
}
local SHIRT_COLORS = { Color3.fromRGB(230, 230, 235), Color3.fromRGB(30, 30, 36), Color3.fromRGB(200, 40, 60), Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 200, 50) }
local MOOD_COLOR = { [1] = T.good, [0] = T.sub, [-1] = T.bad }

function SocialScreen.new(app)
	SocialScreen.app = app
	local self = setmetatable({ app = app, filter = "all" }, SocialScreen)
	self.frame = UI.New("Frame", { Parent = app.content, Size = UI.px(1920, 1008), BackgroundTransparency = 1, Visible = false, Name = "Social" })
	self.body = UI.New("Frame", { Parent = self.frame, Size = UI.px(1920, 1008), BackgroundTransparency = 1 })
	return self
end

function SocialScreen:show()
	self:refresh()
end

local function ago(state, day)
	local d = state.day - day
	if d <= 0 then
		return "today"
	elseif d == 1 then
		return "yesterday"
	end
	return d .. "d ago"
end

-- a concert photo as a small 3D scene: "stage" = view from the crowd, "selfie" = fans in front of the stage
local SKY = Color3.fromRGB(8, 8, 18)
local function mk(vp, size, cf, color, material, shape, tr)
	local p = UI.New("Part", { Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic, Transparency = tr or 0, Anchored = true, Parent = vp })
	if shape then
		p.Shape = shape
	end
	return p
end
-- a simple fan in a photo: legs, shirt, round head, hair (kept light: photos can hold hundreds of them)
local function crowdFan(vp, x, z, shirt, rng, arm, phone)
	local pants = Color3.fromRGB(20, 22, 32)
	mk(vp, Vector3.new(1.3, 1.6, 0.8), CFrame.new(x, 0.8, z), pants)
	mk(vp, Vector3.new(1.6, 1.6, 0.95), CFrame.new(x, 2.4, z), shirt)
	local head = mk(vp, Vector3.new(1.1, 1.15, 1.1), CFrame.new(x, 3.75, z), People.SKINS[rng:NextInteger(1, #People.SKINS)])
	UI.New("SpecialMesh", { MeshType = Enum.MeshType.Head, Parent = head })
	mk(vp, Vector3.new(1.18, 0.4, 1.18), CFrame.new(x, 4.25, z + 0.06), Color3.fromRGB(30, 22, 18):Lerp(Color3.fromRGB(220, 190, 120), rng:NextNumber() * 0.6))
	if arm then
		mk(vp, Vector3.new(0.42, 1.8, 0.42), CFrame.new(x + 0.9, 4.1, z) * CFrame.Angles(0, 0, -0.25), shirt)
		if phone then
			mk(vp, Vector3.new(0.5, 0.8, 0.1), CFrame.new(x + 1.15, 5.1, z), Color3.fromRGB(255, 255, 235), Enum.Material.Neon)
		end
	end
end

-- the stage at the back of most photos: deck, LED wall, light beams, haze; returns the artist figure position
local function stageSet(vp, color, rng, opts)
	opts = opts or {}
	mk(vp, Vector3.new(300, 1, 300), CFrame.new(0, -0.5, -20), Color3.fromRGB(12, 12, 18))
	mk(vp, Vector3.new(44, 5, 16), CFrame.new(0, 2.5, -30), Color3.fromRGB(26, 26, 32))
	mk(vp, Vector3.new(46, 22, 1), CFrame.new(0, 16, -38), color, Enum.Material.Neon, nil, 0.25)
	mk(vp, Vector3.new(14, 8, 0.5), CFrame.new(0, 16, -37.3), Color3.new(1, 1, 1), Enum.Material.Neon, nil, 0.6)
	for _, x in ipairs({ -30, 30 }) do
		mk(vp, Vector3.new(10, 6, 0.5), CFrame.new(x, 14, -30) * CFrame.Angles(0, -x / 120, 0), color, Enum.Material.Neon, nil, 0.4)
		for i = 0, 5 do
			mk(vp, Vector3.new(3.4, 1.2, 2), CFrame.new(x * 0.82, 26 - i * 1.3, -26), Color3.fromRGB(16, 16, 20))
		end
	end
	mk(vp, Vector3.new(60, 1.2, 1.2), CFrame.new(0, 30, -30), Color3.fromRGB(70, 70, 80), Enum.Material.Metal)
	for i = 0, 7 do
		local x = -21 + i * 6
		local c = (i % 2 == 0) and color or Color3.fromRGB(255, 240, 220)
		mk(vp, Vector3.new(0.8, 60, 0.8), CFrame.new(x, 30, -32) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.5, 0.5)), c, Enum.Material.Neon, nil, opts.beams or 0.75)
	end
	mk(vp, Vector3.new(80, 6, 30), CFrame.new(0, 3, -20), color, Enum.Material.Neon, nil, 0.93) -- haze
	return Vector3.new(rng:NextNumber(-6, 6), 5, -30)
end

-- the real stage of the tour (the design the show used): decks, screens, set pieces and lights, set up like
-- in the venue, in front of the crowd. Big stages are shown from further back (returns artistPos, zoom).
local function realStage(vp, design, color, artistName)
	local Builder = require(Root.Client.Builder)
	local StageItems = require(Root.Data.StageItems)
	local Config = require(Root.Config)
	if not design or type(design.items) ~= "table" then
		return nil
	end
	local decks, others = {}, {}
	for _, rec in ipairs(design.items) do
		local def = StageItems.byId[rec.t]
		-- (no Kabuki curtain: it is down when the show is on, a photo never shows it closed)
		if def and not def.hidden and rec.t ~= "spot" and rec.t ~= "curtain" then
			if def.deck then
				table.insert(decks, { def = def, rec = rec })
			else
				table.insert(others, { def = def, rec = rec })
			end
		end
	end
	if #decks == 0 then
		return nil
	end
	-- the biggest pieces first, at most 60 (a photo does not need every little light)
	table.sort(others, function(a, b)
		return (a.def.cost or 0) > (b.def.cost or 0)
	end)
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	local function topAt(x, z)
		local top = 0
		for _, d in ipairs(decks) do
			local r, def = d.rec, d.def
			local w, dd = r.w or (def.size and def.size.w) or 10, r.d or (def.size and (def.size.d or def.size.w)) or 10
			if math.abs(((r.r or 0) % 180) - 90) < 1 then
				w, dd = dd, w
			end
			if math.abs(x - r.x) <= w / 2 and math.abs(z - r.z) <= dd / 2 then
				top = math.max(top, (r.y or 0) + (r.yo or 0) + (r.h or def.h or 6))
			end
		end
		return top
	end
	for _, d in ipairs(decks) do
		local r, def = d.rec, d.def
		local w = math.max(r.w or (def.size and def.size.w) or 10, r.d or (def.size and (def.size.d or def.size.w)) or 10)
		x0, x1 = math.min(x0, r.x - w / 2), math.max(x1, r.x + w / 2)
		z0, z1 = math.min(z0, r.z - w / 2), math.max(z1, r.z + w / 2)
	end
	-- the front of the main stage goes to z = -22 in the photo
	local dz = -22 - math.min(z1, z0 + 40)
	local cx = (x0 + x1) / 2
	local cls = Config.STAGE_CLASS_BY_ID[design.class or "Arena"] or Config.STAGE_CLASS_BY_ID.Arena
	local saveRig = Builder.rigTop
	Builder.rigTop = cls.rigY - 1.9
	local placed = {}
	local function put(e)
		local def, rec = e.def, e.rec
		local ok, refs = pcall(Builder.build, def, { color = color, artistName = artistName, rec = rec, preview = true })
		if not ok or not refs then
			return
		end
		refs.rec = rec
		table.insert(placed, refs)
		local y
		if def.mount == "rig" then
			y = cls.rigY - ((def.id == "truss_beam") and 0 or 2)
		elseif def.deck then
			y = rec.y or 0
		elseif def.ground then
			y = 0
		else
			y = rec.y or topAt(rec.x, rec.z)
		end
		y = y + (rec.yo or 0)
		Builder.place(refs, CFrame.new(rec.x - cx, y, rec.z + dz) * CFrame.Angles(0, math.rad(rec.r or 0), 0))
		if Builder.hideMarker then
			Builder.hideMarker(refs)
		end
		refs.model.Parent = vp
	end
	for _, e in ipairs(decks) do
		put(e)
	end
	-- the pieces the artist plays or rides always make it into the photo (a moment of the show)
	local MOMENT = { lift = true, poplift = true, drums = true, piano = true, gownriser = true, floatplat = true, descendcube = true, showerstage = true, harp = true, keys = true }
	local count = 0
	for _, e in ipairs(others) do
		if MOMENT[e.def.id] or count < 30 then
			put(e)
			count = count + (MOMENT[e.def.id] and 0 or 1)
		end
	end
	Builder.rigTop = saveRig
	mk(vp, Vector3.new(400, 1, 400), CFrame.new(0, -0.5, -20), Color3.fromRGB(12, 12, 18))
	mk(vp, Vector3.new(math.max(80, x1 - x0 + 20), 6, 30), CFrame.new(0, 3, -20), color, Enum.Material.Neon, nil, 0.93) -- haze
	local top = topAt(cx, (z0 + z1) / 2)
	local zoom = math.clamp((x1 - x0) / 46, 1, 4)
	-- the artist stands at the front edge of the stage, on top of it (not sunk in)
	return Vector3.new(0, math.max(0, top), -24), zoom, placed
end

-- a moment of the show for the photo: the artist coming up on the lift, at the drums, at the piano, up in
-- the giant dress, lying on the floating platform, in the glass cube, in the rain ... (the piece is shown
-- in that moment). returns { pos, yaw, move } or nil
local function showMoment(placed, rng)
	local Models = require(Root.Client.Models)
	local list = {}
	for _, r in ipairs(placed or {}) do
		local k, cf = r.kind, r.cf
		if k == "lift" or k == "poplift" then
			table.insert(list, { pos = cf.Position + Vector3.new(0, r.topY or 0.4, 0), yaw = 0, move = "pop" })
		elseif k == "drums" then
			table.insert(list, { pos = (cf * CFrame.new(0, 1, -1.8)).Position, yaw = math.rad(r.rec.r or 0), move = "drumsolo" })
		elseif k == "piano" then
			table.insert(list, { pos = (cf * CFrame.new(0, 0, 5.2)).Position, yaw = math.rad(r.rec.r or 0) + math.pi, move = "piano" })
		elseif k == "keys" then
			table.insert(list, { pos = (cf * CFrame.new(0, 0, -2.4)).Position, yaw = math.rad(r.rec.r or 0), move = "keyshype" })
		elseif k == "harp" then
			table.insert(list, { pos = (cf * CFrame.new(0, 0, -2.2)).Position, yaw = math.rad(r.rec.r or 0), move = "harp" })
		elseif k == "gownriser" and Models.layoutGown then
			table.insert(list, { pos = (cf * CFrame.new(0, 19.55, 0)).Position, yaw = 0, move = "gown", item = r, set = function()
				Models.layoutGown(r, cf, 1)
			end })
		elseif k == "floatplat" and Models.layoutFloat then
			table.insert(list, { pos = (cf * CFrame.new(0, 14.65, 0)).Position, yaw = 0, move = (rng:NextNumber() < 0.5) and "lie" or "sitedge", set = function()
				Models.layoutFloat(r, cf, 1)
			end })
		elseif k == "descendcube" and Models.layoutCube then
			table.insert(list, { pos = (cf * CFrame.new(0, 14.8, 0)).Position, yaw = 0, move = "wave", set = function()
				Models.layoutCube(r, cf, 1, 1)
			end })
		elseif k == "showerstage" and Models.animate then
			table.insert(list, { pos = (cf * CFrame.new(0, 1.2, 0)).Position, yaw = 0, move = "rainarms", set = function()
				local n = (type(r.rec.play) == "number") and r.rec.play or 1
				r.rec = { play = n, t = "showerstage" }
				r.readySong, r.readyAt = n, 0
				pcall(Models.animate, r, { t = 8 + rng:NextNumber() * 3, songNum = n, songFrac = 0.5 })
			end })
		end
	end
	if #list == 0 then
		return nil
	end
	local m = list[rng:NextInteger(1, #list)]
	if m.set then
		m.set()
	end
	return m
end

-- a follow spot on the artist: a soft cone from above and a glow behind them, so they stand out in the photo
local function spotOn(vp, pos, color)
	mk(vp, Vector3.new(36, 7, 7), CFrame.new(pos + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 248, 230), Enum.Material.Neon, Enum.PartType.Cylinder, 0.88)
	mk(vp, Vector3.new(0.2, 12, 12), CFrame.new(pos + Vector3.new(0, 5, -2.5)) * CFrame.Angles(0, math.pi / 2, 0), color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon, Enum.PartType.Cylinder, 0.78)
	local disc = mk(vp, Vector3.new(0.2, 9, 9), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 246, 226), Enum.Material.Neon, Enum.PartType.Cylinder, 0.55)
	local _ = disc
end
local function star(vp, ad, color, seed, rng, pos, move, yaw, big)
	if not ad then
		return
	end
	local f = People.new(vp, color, big or 1.4, "lead", seed, ad.look)
	local moves = { "micout", "micout", "jump", "wave", "dance" }
	f:update(pos, yaw or 0, { t = rng:NextNumber() * 10, beat = 0.5, energy = 1, walking = false, armsUp = rng:NextNumber() < 0.4 and 1 or 0, move = move or moves[rng:NextInteger(1, #moves)] })
	return f
end

-- crowd rows between the camera and the stage
local function crowdRows(vp, color, rng, rows, z0, sticks)
	for row = 0, rows - 1 do
		for col = 0, 13 do
			local x = -26 + col * 4 + rng:NextNumber(-1, 1)
			local z = z0 - row * 3.4 + rng:NextNumber(-0.6, 0.6)
			local c = Color3.fromRGB(14, 14, 20):Lerp(color, rng:NextNumber() * 0.3)
			local r = rng:NextNumber()
			crowdFan(vp, x, z, c, rng, r < 0.45, r < 0.25)
			if sticks and r > 0.8 then
				mk(vp, Vector3.new(0.3, 1.6, 0.3), CFrame.new(x - 0.8, 5.0, z) * CFrame.Angles(0, 0, 0.3), color, Enum.Material.Neon)
			end
		end
	end
end

-- 2D photos (ticket, poster): a styled frame instead of a 3D scene
local function flatPhoto(parent, ad, kind, p, rng)
	local color = ad and UI.rgb(ad.color) or T.accent
	local f = UI.New("Frame", { Parent = parent, Size = UI.px(608, 250), BackgroundColor3 = Color3.fromRGB(40, 32, 28), BorderSizePixel = 0, UI.Corner(10) })
	local name = ad and string.upper(ad.name) or "HEADLINER"
	if kind == "ticket" then
		-- a ticket on a wooden table, slightly rotated
		for i = 0, 5 do
			UI.New("Frame", { Parent = f, Position = UI.px(0, i * 42), Size = UI.px(608, 2), BackgroundColor3 = Color3.fromRGB(60, 46, 38), BorderSizePixel = 0 })
		end
		local t = UI.New("Frame", { Parent = f, Position = UI.px(84, 40), Size = UI.px(440, 170), BackgroundColor3 = Color3.fromRGB(245, 240, 230), BorderSizePixel = 0, Rotation = rng:NextNumber(-6, 6), UI.Corner(8) })
		UI.New("Frame", { Parent = t, Size = UI.px(130, 170), BackgroundColor3 = color, BorderSizePixel = 0, UI.Corner(8) })
		UI.Label(t, "ADMIT\nONE", UI.px(10, 40), UI.px(110, 90), { textSize = 26, font = UI.FontBlack, color = BLACK, alignX = Enum.TextXAlignment.Center })
		UI.Label(t, name, UI.px(146, 14), UI.px(280, 34), { textSize = 26, font = UI.FontBlack, color = BLACK })
		UI.Label(t, p.venue or "Live in concert", UI.px(146, 52), UI.px(280, 24), { textSize = 16, color = Color3.fromRGB(60, 60, 70) })
		UI.Label(t, "SEC " .. rng:NextInteger(100, 230) .. "   ROW " .. rng:NextInteger(1, 30) .. "   SEAT " .. rng:NextInteger(1, 40), UI.px(146, 80), UI.px(280, 22), { textSize = 15, font = UI.FontBold, color = Color3.fromRGB(40, 40, 50) })
		for i = 0, 36 do
			local w = (rng:NextNumber() < 0.5) and 2 or 4
			UI.New("Frame", { Parent = t, Position = UI.px(150 + i * 7, 116), Size = UI.px(w, 40), BackgroundColor3 = BLACK, BorderSizePixel = 0 })
		end
	else
		-- tour poster on a street wall
		f.BackgroundColor3 = Color3.fromRGB(70, 70, 76)
		for i = 0, 7 do
			for k = 0, 3 do
				UI.New("Frame", { Parent = f, Position = UI.px(((i + k) % 2) * -30 + i * 80, k * 64), Size = UI.px(78, 62), BackgroundColor3 = Color3.fromRGB(90, 54, 44), BorderSizePixel = 0 })
			end
		end
		local poster = UI.New("Frame", { Parent = f, Position = UI.px(204, 14), Size = UI.px(200, 222), BackgroundColor3 = BLACK, BorderSizePixel = 0 })
		UI.New("UIGradient", { Parent = poster, Rotation = 90, Color = ColorSequence.new(color, BLACK) })
		UI.Label(poster, name, UI.px(10, 120), UI.px(180, 40), { textSize = 26, font = UI.FontBlack, alignX = Enum.TextXAlignment.Center, wrap = true })
		UI.Label(poster, "WORLD TOUR", UI.px(10, 160), UI.px(180, 24), { textSize = 16, font = UI.FontBold, color = T.gold, alignX = Enum.TextXAlignment.Center })
		UI.Label(poster, "TICKETS ON SALE NOW", UI.px(10, 190), UI.px(180, 20), { textSize = 12, color = Color3.fromRGB(220, 220, 230), alignX = Enum.TextXAlignment.Center })
		local circle = UI.New("Frame", { Parent = poster, Position = UI.px(60, 22), Size = UI.px(80, 80), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.2, BorderSizePixel = 0, UI.Corner(40) })
		local _ = circle
	end
	return f
end

-- a concert photo as a small 3D scene. kind: stage, selfie, wide, closeup, confetti, pyro, phones, barricade, queue, sign, merch
local function photo(parent, ad, seed, kind, p)
	local rng = Random.new(seed)
	if kind == "ticket" or kind == "poster" then
		return flatPhoto(parent, ad, kind, p or {}, rng)
	end
	local color = ad and UI.rgb(ad.color) or T.accent
	local vp = UI.New("ViewportFrame", {
		Parent = parent,
		Size = UI.px(608, 250),
		BackgroundColor3 = SKY,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(110, 100, 140),
		LightColor = color:Lerp(Color3.new(1, 1, 1), 0.5),
		LightDirection = Vector3.new(0.2, -0.6, 1),
		UI.Corner(10),
	})
	local cam = UI.New("Camera", { FieldOfView = 42, Parent = vp })
	vp.CurrentCamera = cam
	if kind == "merch" then
		-- flat lay of the tour shirt on a bed, with a tote and the ticket
		vp.BackgroundColor3 = Color3.fromRGB(200, 196, 210)
		vp.Ambient = Color3.fromRGB(200, 196, 200)
		vp.LightDirection = Vector3.new(0.3, -1, 0.2)
		mk(vp, Vector3.new(60, 1, 40), CFrame.new(0, -0.5, 0), Color3.fromRGB(225, 222, 232), Enum.Material.Fabric)
		local shirt = (rng:NextNumber() < 0.5) and BLACK:Lerp(Color3.new(1, 1, 1), 0.08) or Color3.fromRGB(235, 235, 238)
		mk(vp, Vector3.new(8, 0.3, 9), CFrame.new(-3, 0.15, 0), shirt, Enum.Material.Fabric)
		mk(vp, Vector3.new(3.4, 0.3, 3), CFrame.new(-8, 0.15, -2.6) * CFrame.Angles(0, 0.5, 0), shirt, Enum.Material.Fabric)
		mk(vp, Vector3.new(3.4, 0.3, 3), CFrame.new(2, 0.15, -2.6) * CFrame.Angles(0, -0.5, 0), shirt, Enum.Material.Fabric)
		mk(vp, Vector3.new(0.32, 4.5, 4.5), CFrame.new(-3, 0.18, 0.2) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, Enum.PartType.Cylinder)
		mk(vp, Vector3.new(5, 0.2, 6), CFrame.new(7, 0.1, 1) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(230, 214, 180), Enum.Material.Fabric)
		mk(vp, Vector3.new(2.6, 0.24, 2.6), CFrame.new(7, 0.2, 1.4) * CFrame.Angles(0, 0.2, 0), color, Enum.Material.SmoothPlastic)
		mk(vp, Vector3.new(4, 0.1, 1.8), CFrame.new(1, 0.3, 4.5) * CFrame.Angles(0, -0.15, 0), Color3.fromRGB(245, 240, 230))
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 18, 6), Vector3.new(0, 0, 0.5))
		return vp
	end
	if kind == "queue" then
		-- outside the venue at dusk: facade, sign, a long line of fans
		vp.BackgroundColor3 = Color3.fromRGB(70, 60, 110)
		vp.Ambient = Color3.fromRGB(150, 130, 160)
		vp.LightDirection = Vector3.new(-0.5, -0.4, -0.6)
		mk(vp, Vector3.new(200, 1, 200), CFrame.new(0, -0.5, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Concrete)
		mk(vp, Vector3.new(120, 40, 4), CFrame.new(0, 20, -30), Color3.fromRGB(60, 64, 80), Enum.Material.Glass)
		for i = 0, 9 do
			mk(vp, Vector3.new(1, 40, 1), CFrame.new(-54 + i * 12, 20, -27.8), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		end
		mk(vp, Vector3.new(50, 6, 1), CFrame.new(0, 32, -27.5), color, Enum.Material.Neon)
		mk(vp, Vector3.new(40, 4, 0.5), CFrame.new(0, 32, -26.9), Color3.new(1, 1, 1), Enum.Material.Neon, nil, 0.7)
		for i = 0, 30 do
			local z = 4 + math.sin(i * 0.7) * 0.8 - (i % 2) * 1.6
			local x = -34 + i * 2.2
			crowdFan(vp, x, z, (rng:NextNumber() < 0.4) and color or SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)], rng, rng:NextNumber() < 0.15, false)
		end
		for i = 0, 6 do
			mk(vp, Vector3.new(0.3, 3, 0.3), CFrame.new(-14 + i * 6, 1.5, 9), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		end
		mk(vp, Vector3.new(38, 0.3, 0.2), CFrame.new(4, 2.6, 9), Color3.fromRGB(200, 40, 40))
		for i = 0, 3 do
			mk(vp, Vector3.new(6, 9, 0.4), CFrame.new(-18 + i * 12, 4.5, -27.6), Color3.fromRGB(255, 220, 160), Enum.Material.Neon, nil, 0.3)
		end
		cam.FieldOfView = 52
		cam.CFrame = CFrame.lookAt(Vector3.new(10, 7, 30), Vector3.new(-2, 15, -12))
		return vp
	end
	-- a photo from the show: the real stage of the tour (if the post knows it), else a typical stage
	local artistPos, zoom = nil, 1
	local design, placed = nil, nil
	local momentY = nil
	if p and SocialScreen.app then
		local GS = require(Root.Logic.GameState)
		local state = SocialScreen.app.state
		if p.designId then
			design = GS.getDesign(state, p.designId)
		end
		-- older posts (and posts about the announcement, sold-out shows ...): the stage of the artist's
		-- latest tour (the stage of the next show, or the tour's main stage)
		if not design and p.artistId then
			for _, tour in ipairs(state.tours or {}) do
				if tour.artistId == p.artistId then
					local idx = 1
					for i, sh in ipairs(tour.shows) do
						if not sh.done then
							idx = i
							break
						end
					end
					design = (tour.shows[idx] and GS.showDesign(state, tour, idx)) or GS.getDesign(state, tour.designId) or design
				end
			end
		end
	end
	-- (only the newest few photos build the real stage: the feed stays light)
	if design and kind ~= "selfie" and kind ~= "barricade" and (SocialScreen.realBudget or 0) > 0 then
		SocialScreen.realBudget = SocialScreen.realBudget - 1
		local ok, pos, z, pl = pcall(realStage, vp, design, color, ad and string.upper(ad.name) or nil)
		if ok and pos then
			artistPos, zoom, placed = pos, z, pl
		end
	end
	artistPos = artistPos or stageSet(vp, color, rng, { beams = (kind == "phones") and 0.88 or 0.75 })
	if kind == "selfie" then
		star(vp, ad, color, seed, rng, artistPos)
		local n = rng:NextInteger(2, 4)
		for i = 1, n do
			local x = (i - (n + 1) / 2) * 2.6
			local fanColor = (rng:NextNumber() < 0.5) and color or SHIRT_COLORS[rng:NextInteger(1, #SHIRT_COLORS)]
			local f = People.new(vp, fanColor, 1, "crowd", seed * 7 + i)
			f:update(Vector3.new(x, 0, 6 + rng:NextNumber() * 0.6), rng:NextNumber(-0.25, 0.25), { t = 1, beat = 0.2, energy = 0.2, walking = false, armsUp = (i == 1) and 1 or 0, move = (i == 1) and "wave" or "idle" })
		end
		vp.LightDirection = Vector3.new(0.1, -0.4, -1)
		vp.Ambient = Color3.fromRGB(150, 140, 170)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 5.6, 15), Vector3.new(0, 4.6, 0))
	elseif kind == "closeup" then
		-- zoomed in on the artist with a spotlight cone
		local pos = Vector3.new(0, 5, -26)
		star(vp, ad, color, seed, rng, pos, (rng:NextNumber() < 0.5) and "micout" or "point")
		mk(vp, Vector3.new(60, 8, 8), CFrame.new(0, 33, -26) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 245, 230), Enum.Material.Neon, Enum.PartType.Cylinder, 0.9)
		vp.Ambient = Color3.fromRGB(150, 140, 170)
		vp.LightDirection = Vector3.new(0, -0.5, -1)
		cam.FieldOfView = 22
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-4, 4), 8, 4), Vector3.new(0, 10, -26))
	elseif kind == "wide" then
		-- from the upper tier: the whole bowl, thousands of phone lights
		star(vp, ad, color, seed, rng, artistPos)
		for side = -1, 1, 2 do
			for r = 0, 9 do
				mk(vp, Vector3.new(4, 2, 60), CFrame.new(side * (30 + r * 4), 1 + r * 2, 0) * CFrame.Angles(0, side * 0.15, 0), Color3.fromRGB(26, 34, 70))
			end
		end
		for r = 0, 9 do
			mk(vp, Vector3.new(60 + r * 8, 2, 4), CFrame.new(0, 1 + r * 2, 34 + r * 4), Color3.fromRGB(26, 34, 70))
		end
		for i = 1, 260 do
			local x, z = rng:NextNumber(-26, 26), rng:NextNumber(-18, 30)
			mk(vp, Vector3.new(0.35, 0.35, 0.35), CFrame.new(x, 2.5 + rng:NextNumber(), z), (rng:NextNumber() < 0.5) and Color3.fromRGB(255, 255, 230) or color, Enum.Material.Neon)
		end
		for i = 1, 200 do
			local side = (rng:NextNumber() < 0.5) and -1 or 1
			local r = rng:NextNumber() * 9
			mk(vp, Vector3.new(0.35, 0.35, 0.35), CFrame.new(side * (31 + r * 4), 2.6 + r * 2, rng:NextNumber(-28, 28)), Color3.fromRGB(255, 255, 230), Enum.Material.Neon)
		end
		cam.FieldOfView = 55
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-10, 10), 30, 62), Vector3.new(0, 4, -20))
	elseif kind == "barricade" then
		-- front row: the barricade right in front, the artist above
		star(vp, ad, color, seed, rng, Vector3.new(rng:NextNumber(-3, 3), 5, -21))
		mk(vp, Vector3.new(30, 2.8, 0.4), CFrame.new(0, 1.6, -12), Color3.fromRGB(150, 155, 165), Enum.Material.DiamondPlate)
		mk(vp, Vector3.new(30, 0.3, 0.6), CFrame.new(0, 3.1, -12), Color3.fromRGB(200, 205, 215), Enum.Material.Metal)
		for i = 0, 3 do
			crowdFan(vp, -6 + i * 4 + rng:NextNumber(-1, 1), -9.5, Color3.fromRGB(14, 14, 20):Lerp(color, rng:NextNumber() * 0.4), rng, rng:NextNumber() < 0.6, rng:NextNumber() < 0.5)
		end
		crowdFan(vp, 1, -15, Color3.fromRGB(255, 214, 0), rng, false, false)
		cam.FieldOfView = 50
		cam.CFrame = CFrame.lookAt(Vector3.new(0.5, 6.4, -1.5), Vector3.new(0, 5.2, -24))
	elseif kind == "sign" then
		-- a fan holds up a sign in the crowd
		star(vp, ad, color, seed, rng, artistPos)
		crowdRows(vp, color, rng, 3, -2, true)
		local sx = ((rng:NextNumber() < 0.5) and -1 or 1) * rng:NextNumber(6, 11)
		local tilt = CFrame.new(sx, 7.6, 1) * CFrame.Angles(0, 0, rng:NextNumber(-0.08, 0.08))
		mk(vp, Vector3.new(5.2, 3.2, 0.15), tilt, Color3.fromRGB(250, 250, 250), Enum.Material.Neon, nil, 0.15)
		for i = 0, 2 do
			mk(vp, Vector3.new(4.2 - i * 0.9, 0.45, 0.1), tilt * CFrame.new(0, 1 - i * 0.85, -0.15), (i == 1) and color or BLACK, (i == 1) and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		end
		mk(vp, Vector3.new(0.9, 0.9, 0.9), tilt * CFrame.new(1.9, -1.1, -0.2), Color3.fromRGB(255, 60, 120), Enum.Material.Neon, Enum.PartType.Ball)
		for _, ox in ipairs({ -2.2, 2.2 }) do
			mk(vp, Vector3.new(0.4, 2.2, 0.4), CFrame.new(sx + ox, 5.4, 1.3), Color3.fromRGB(240, 200, 170))
		end
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-3, 3), 7, 19), Vector3.new(0, 8, -20))
	elseif kind == "imag" then
		-- the artist big on the video screen next to the stage (IMAG), the real one small on the stage
		star(vp, ad, color, seed, rng, artistPos)
		spotOn(vp, artistPos, color)
		local sx = (rng:NextNumber() < 0.5) and -1 or 1
		-- the screen: a black frame with a window; the close-up is a big copy of the artist (head and chest)
		-- behind the window, the frame and a black panel round it hide the rest
		local wx, wy, ww, wh = sx * 22, 20, 20, 13
		local bez = Color3.fromRGB(12, 12, 16)
		local zf = -33
		mk(vp, Vector3.new(ww + 3, 1.5, 1), CFrame.new(wx, wy + wh / 2 + 0.75, zf), bez)
		mk(vp, Vector3.new(ww + 3, 1.5, 1), CFrame.new(wx, wy - wh / 2 - 0.75, zf), bez)
		mk(vp, Vector3.new(1.5, wh + 3, 1), CFrame.new(wx - ww / 2 - 0.75, wy, zf), bez)
		mk(vp, Vector3.new(1.5, wh + 3, 1), CFrame.new(wx + ww / 2 + 0.75, wy, zf), bez)
		mk(vp, Vector3.new(ww + 3, 18, 1), CFrame.new(wx, wy - wh / 2 - 10.5, zf + 0.2), bez) -- the support under it
		mk(vp, Vector3.new(ww - 0.2, wh - 0.2, 0.2), CFrame.new(wx, wy, zf - 6), color:Lerp(Color3.new(0, 0, 0), 0.6), Enum.Material.Neon) -- the screen's background
		local big = People.new(vp, color, 4, "lead", seed, ad and ad.look)
		big:update(Vector3.new(wx, wy - wh / 2 - 9, zf - 4), 0, { t = 2, beat = 0.5, energy = 1, walking = false, armsUp = 0, move = "micout" })
		for _, d in ipairs(big.model:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name:find("^Leg") or d.Name:find("^Shoe")) then
				d.Transparency = 1
			end
		end
		crowdRows(vp, color, rng, 5, 4, true)
		cam.CFrame = CFrame.lookAt(Vector3.new(sx * 6, 7, 14), Vector3.new(sx * 12, 12, -30))
	elseif kind == "backlit" then
		-- the artist as a silhouette in front of a blinding light, haze, hands in the air
		star(vp, ad, color, seed, rng, artistPos, "pose")
		for _, d in ipairs(vp:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Haze" and d.Position.Z > artistPos.Z - 3 and d.Position.Z < artistPos.Z + 3 and math.abs(d.Position.X - artistPos.X) < 4 then
				d.Color = Color3.fromRGB(8, 8, 12)
			end
		end
		mk(vp, Vector3.new(0.4, 34, 34), CFrame.new(artistPos + Vector3.new(0, 9, -10)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 250, 235), Enum.Material.Neon, Enum.PartType.Cylinder, 0.05)
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			mk(vp, Vector3.new(60, 2.4, 2.4), CFrame.new(artistPos + Vector3.new(0, 9, -10)) * CFrame.Angles(0, 0, a), color:Lerp(Color3.new(1, 1, 1), 0.6), Enum.Material.Neon, Enum.PartType.Cylinder, 0.8)
		end
		crowdRows(vp, Color3.fromRGB(6, 6, 10), rng, 4, 0, false)
		vp.Ambient = Color3.fromRGB(40, 40, 60)
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-2, 2), 6, 10), artistPos + Vector3.new(0, 6, 0))
	elseif kind == "aerial" then
		-- from high up behind the crowd: the whole stage, a sea of phone lights
		star(vp, ad, color, seed, rng, artistPos)
		spotOn(vp, artistPos, color)
		crowdRows(vp, color, rng, 10, 4, true)
		for i = 1, 220 do
			mk(vp, Vector3.new(0.35, 0.45, 0.1), CFrame.new(rng:NextNumber(-34, 34), rng:NextNumber(5, 7), rng:NextNumber(-26, 6)), Color3.fromRGB(255, 255, 235), Enum.Material.Neon)
		end
		cam.FieldOfView = 50
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-12, 12), 42, 40), artistPos + Vector3.new(0, 2, 0))
	elseif kind == "sidestage" then
		-- from the side of the stage: the artist close, the crowd beyond
		star(vp, ad, color, seed, rng, artistPos, "micout", math.rad(-25))
		spotOn(vp, artistPos, color)
		for row = 0, 5 do
			for col = 0, 10 do
				crowdFan(vp, -20 + col * 4 + rng:NextNumber(-1, 1), -10 + row * 3.2, Color3.fromRGB(14, 14, 20):Lerp(color, rng:NextNumber() * 0.3), rng, rng:NextNumber() < 0.5, rng:NextNumber() < 0.4)
			end
		end
		cam.FieldOfView = 46
		cam.CFrame = CFrame.lookAt(artistPos + Vector3.new(-16, 7, -6), artistPos + Vector3.new(4, 4, 10))
	else
		-- most photos of a real stage catch a moment of the show (lift, drums, the giant dress ...)
		local moment = (placed and rng:NextNumber() < 0.7) and showMoment(placed, rng) or nil
		if moment then
			star(vp, ad, color, seed, rng, moment.pos, moment.move, moment.yaw)
			spotOn(vp, moment.pos, color)
		else
			star(vp, ad, color, seed, rng, artistPos)
			spotOn(vp, artistPos, color)
		end
		momentY = moment and moment.pos.Y or nil
		crowdRows(vp, color, rng, (kind == "phones") and 7 or 6, 4, true)
		if kind == "confetti" then
			local cols = { color, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 214, 0), Color3.fromRGB(255, 80, 160), Color3.fromRGB(80, 220, 255) }
			for i = 1, 160 do
				mk(vp, Vector3.new(0.7, 0.05, 0.45), CFrame.new(rng:NextNumber(-26, 26), rng:NextNumber(4, 26), rng:NextNumber(-30, 8)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), cols[rng:NextInteger(1, #cols)], Enum.Material.Neon)
			end
		elseif kind == "pyro" then
			-- flame columns: a hot core inside softer layers, a rolling ball of fire on top, black smoke above
			for _, x in ipairs({ -20, -12, 12, 20 }) do
				local h = rng:NextNumber(10, 14)
				for k, layer in ipairs({ { 4.6, 1, Color3.fromRGB(220, 60, 10), 0.45 }, { 3.2, 0.85, Color3.fromRGB(255, 140, 30), 0.25 }, { 1.8, 0.7, Color3.fromRGB(255, 240, 170), 0 } }) do
					local f = mk(vp, Vector3.new(layer[1], h * layer[2], layer[1]), CFrame.new(x, 5 + h * layer[2] / 2, -24), layer[3], Enum.Material.Neon, nil, layer[4])
					UI.New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = f })
					local _ = k
				end
				local top = mk(vp, Vector3.new(7, 5, 7), CFrame.new(x, 6 + h, -24), Color3.fromRGB(255, 120, 20), Enum.Material.Neon, nil, 0.35)
				UI.New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = top })
				local smoke = mk(vp, Vector3.new(9, 6, 9), CFrame.new(x, 11 + h, -25), Color3.fromRGB(30, 26, 26), Enum.Material.SmoothPlastic, nil, 0.5)
				UI.New("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = smoke })
			end
			vp.Ambient = Color3.fromRGB(200, 130, 80)
		elseif kind == "phones" then
			for i = 1, 160 do
				mk(vp, Vector3.new(0.4, 0.55, 0.1), CFrame.new(rng:NextNumber(-30, 30), rng:NextNumber(4.5, 7), rng:NextNumber(-22, -4)), Color3.fromRGB(255, 255, 235), Enum.Material.Neon)
			end
			vp.Ambient = Color3.fromRGB(60, 60, 90)
		end
		-- a moment high up (dress, platform, cube): the phone points higher
		local lookY = math.max(9, (momentY or 0) + 2)
		cam.CFrame = CFrame.lookAt(Vector3.new(rng:NextNumber(-8, 8), 6.5 + (lookY - 9) * 0.4, 12), Vector3.new(0, lookY, -30))
	end
	if zoom > 1 then
		-- a big stage: step back (and up) so the whole stage is in the photo
		local c = cam.CFrame
		cam.CFrame = c - c.LookVector * (zoom - 1) * 34 + Vector3.new(0, (zoom - 1) * 6, 0)
	end
	return vp
end
SocialScreen.photo = photo

function SocialScreen:post(list, p, order)
	local state = self.app.state
	local ad = Artists.byId[p.artistId or ""]
	local card = UI.New("Frame", { Parent = list, Size = UI.px(640, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, BorderSizePixel = 0, LayoutOrder = order, UI.Corner(12), UI.Padding(16, 16, 14, 14), UI.List(true, 8) })
	local head = UI.New("Frame", { Parent = card, Size = UI.px(608, 46), BackgroundTransparency = 1, LayoutOrder = 1 })
	local av = UI.New("TextLabel", { Parent = head, Size = UI.px(44, 44), BackgroundColor3 = AVATARS[p.avatar or 1], Text = p.name:sub(1, 1), TextColor3 = BLACK, TextSize = 22, Font = UI.FontBlack, UI.Corner(22) })
	local _ = av
	UI.Label(head, p.name, UI.px(56, 0), UI.px(300, 24), { textSize = 18, font = UI.FontBold })
	UI.Label(head, p.handle .. "  |  " .. ago(state, p.day), UI.px(56, 24), UI.px(400, 20), { textSize = 14, color = T.sub })
	if ad then
		local tag = UI.Pill(head, ad.name, UI.px(458, 10), UI.px(150, 24), UI.rgb(ad.color), 12)
		tag.TextColor3 = BLACK
	end
	UI.New("TextLabel", {
		Parent = card,
		Size = UI.px(608, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = UI.esc(p.text),
		RichText = true,
		TextWrapped = true,
		TextSize = 22,
		TextColor3 = T.text,
		Font = UI.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	if p.photo and self.photos < 8 then
		self.photos = self.photos + 1
		local seed = (p.likes or 1) + (p.avatar or 1) * 31
		photo(card, ad, p.seed or seed, p.pkind or ((seed % 2 == 0) and "selfie" or "stage"), p).LayoutOrder = 3
	end
	local foot = UI.New("Frame", { Parent = card, Size = UI.px(608, 22), BackgroundTransparency = 1, LayoutOrder = 4 })
	UI.Label(foot, "Likes: " .. Util.short(p.likes or 0) .. "      Reposts: " .. Util.short(p.reposts or 0), UI.px(0, 0), UI.px(300, 22), { textSize = 15, color = T.sub })
	local moodTxt = (p.mood > 0) and "positive" or ((p.mood < 0) and "critical" or "neutral")
	UI.Label(foot, moodTxt, UI.px(408, 0), UI.px(200, 22), { textSize = 14, font = UI.FontBold, color = MOOD_COLOR[p.mood] or T.sub, alignX = Enum.TextXAlignment.Right })
end

function SocialScreen:refresh()
	SocialScreen.realBudget = 6
	local state = self.app.state
	local body = self.body
	UI.ClearChildren(body)

	-- left: filter + fan mood per artist
	local left = UI.Panel(body, UI.px(40, 20), UI.px(400, 970))
	UI.Label(left, "FAN MOOD", UI.px(20, 16), UI.px(360, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Label(left, "How fans feel about your artists right now.", UI.px(20, 48), UI.px(360, 22), { textSize = 14, color = T.sub })
	local y = 84
	local allBtn = UI.Button(left, "All posts", UI.px(20, y), UI.px(360, 44), { color = self.filter == "all" and T.accent or T.panel3, textSize = 17 }, function()
		self.filter = "all"
		self:refresh()
	end)
	local _ = allBtn
	y = y + 56
	for _, ad in ipairs(GS.signedArtists(state)) do
		local mood, n = Social.mood(state, ad.id)
		local b = UI.Button(left, "", UI.px(20, y), UI.px(360, 76), { color = self.filter == ad.id and UI.shade(T.accent, 0.6) or T.panel2 }, function()
			self.filter = ad.id
			self:refresh()
		end)
		UI.New("Frame", { Parent = b, Position = UI.px(0, 0), Size = UI.px(8, 76), BackgroundColor3 = UI.rgb(ad.color), BorderSizePixel = 0 })
		UI.Label(b, ad.name, UI.px(20, 6), UI.px(220, 28), { textSize = 19, font = UI.FontBold })
		local label = (n == 0) and "no posts yet" or ((mood >= 40) and "fans love it" or ((mood >= 0) and "mixed feelings" or "fans are upset"))
		local col = (n == 0) and T.sub or ((mood >= 40) and T.good or ((mood >= 0) and T.warn or T.bad))
		UI.Label(b, label, UI.px(20, 40), UI.px(220, 24), { textSize = 15, color = col, font = UI.FontBold })
		UI.Bar(b, UI.px(240, 46), UI.px(100, 10), (mood + 100) / 200, col)
		UI.Label(b, n > 0 and ((mood > 0 and "+" or "") .. mood) or "", UI.px(240, 12), UI.px(100, 26), { textSize = 18, font = UI.FontBlack, color = col, alignX = Enum.TextXAlignment.Right })
		y = y + 86
	end

	-- center: the feed
	self.photos = 0
	local list = UI.Scroll(body, UI.px(470, 20), UI.px(680, 970))
	UI.List(true, 12).Parent = list
	local n = 0
	for _, p in ipairs(state.social or {}) do
		if self.filter == "all" or p.artistId == self.filter then
			n = n + 1
			if n <= 60 then
				self:post(list, p, n)
			end
		end
	end
	if n == 0 then
		UI.Label(list, "Nothing here yet. Announce a tour and fans will start talking!", nil, UI.px(640, 60), { textSize = 18, color = T.sub, wrap = true })
	end

	-- right: trending + tips
	local right = UI.Panel(body, UI.px(1180, 20), UI.px(700, 470))
	UI.Label(right, "TRENDING", UI.px(24, 16), UI.px(400, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	local tr = Social.trending(state)
	if #tr == 0 then
		UI.Label(right, "No hashtags yet.", UI.px(24, 60), UI.px(600, 24), { textSize = 16, color = T.sub })
	end
	for i = 1, math.min(8, #tr) do
		UI.Label(right, i .. ".  " .. tr[i][1], UI.px(24, 30 + i * 46), UI.px(460, 36), { textSize = 22, font = UI.FontBold })
		UI.Label(right, Util.short(tr[i][2]) .. " likes", UI.px(480, 30 + i * 46), UI.px(196, 36), { textSize = 16, color = T.sub, alignX = Enum.TextXAlignment.Right })
	end
	local tips = UI.Panel(body, UI.px(1180, 510), UI.px(700, 480))
	UI.Label(tips, "WHAT FANS TALK ABOUT", UI.px(24, 16), UI.px(600, 30), { textSize = 22, font = UI.FontBlack, color = T.accent })
	UI.Label(tips, table.concat({
		"-  Great shows get photos, love and fan projects.",
		"-  Weak shows and bare stages get criticism.",
		"-  Very high ticket prices make fans angry.",
		"-  Fans notice special stage moments: lifts, pyro, the LED cube, balloons...",
		"-  Empty venues: fans worry when tickets don't sell.",
		"-  Cancelled tours hurt the mood a lot.",
	}, "\n"), UI.px(24, 60), UI.px(650, 400), { textSize = 18, wrap = true, alignY = Enum.TextYAlignment.Top, color = T.text })
	local _c = Config
end

return SocialScreen
