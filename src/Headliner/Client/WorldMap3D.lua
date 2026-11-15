-- 3D world map table used by the tour planner. Countries light up on hover and can be clicked.
-- Built from Natural Earth borders (see Data/WorldMap.lua). It lives far away from the stage area.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Root = script:FindFirstAncestor("Headliner")
local Countries = require(Root.Data.Countries)
local WorldMap = require(Root.Data.WorldMap)
local UI = require(Root.Client.UI)

local New = UI.New
local WM = {}

local ORIGIN = Vector3.new(0, 0, 8000)
local S = 2 -- studs per degree
local LAND_TOP = 1
local COUNTRY_TOP = 1.8
local LIFT = 1.2 -- hovered / selected countries rise a bit
local OCEAN = Color3.fromRGB(14, 32, 66)
local LAND = Color3.fromRGB(48, 54, 68)
local HOVER = Color3.fromRGB(255, 236, 100)
local SELECTED = Color3.fromRGB(255, 186, 30)

-- map position of a lat/lon (top surface of the land)
function WM.toWorld(lat, lon, y)
	return ORIGIN + Vector3.new(lon * S, y or COUNTRY_TOP, -lat * S)
end

local function rectPart(parent, rect, cellDeg, top, color, name)
	local row, col, w, h = rect[1], rect[2], rect[3], rect[4]
	local lon = -180 + (col + w / 2) * cellDeg
	local lat = WorldMap.LAT_TOP - (row + h / 2) * cellDeg
	local height = top + 1
	return New("Part", {
		Name = name,
		Size = Vector3.new(w * cellDeg * S, height, h * cellDeg * S),
		CFrame = CFrame.new(ORIGIN + Vector3.new(lon * S, top - height / 2, -lat * S)),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = parent,
	})
end

function WM.build()
	if WM.folder then
		return
	end
	local folder = New("Folder", { Name = "WorldMap3D", Parent = workspace })
	WM.folder = folder
	local w, h = 360 * S, (WorldMap.LAT_TOP - WorldMap.LAT_BOTTOM) * S
	local midLat = (WorldMap.LAT_TOP + WorldMap.LAT_BOTTOM) / 2
	New("Part", {
		Name = "Ocean",
		Size = Vector3.new(w + 60, 2, h + 60),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -1, -midLat * S)),
		Color = OCEAN,
		Material = Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})
	New("Part", {
		Name = "Table",
		Size = Vector3.new(w + 90, 6, h + 90),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, -5, -midLat * S)),
		Color = Color3.fromRGB(24, 20, 30),
		Material = Enum.Material.Wood,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = folder,
	})
	-- faint latitude / longitude lines
	for lon = -150, 150, 30 do
		local p = New("Part", { Name = "Meridian", Size = Vector3.new(0.15, 0.05, h), CFrame = CFrame.new(ORIGIN + Vector3.new(lon * S, 0.03, -midLat * S)), Color = Color3.fromRGB(60, 110, 170), Material = Enum.Material.Neon, Transparency = 0.7, Anchored = true, CanCollide = false, CanQuery = false, Parent = folder })
		local _ = p
	end
	for lat = -45, 75, 15 do
		New("Part", { Name = "Parallel", Size = Vector3.new(w, 0.05, 0.15), CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.03, -lat * S)), Color = Color3.fromRGB(60, 110, 170), Material = Enum.Material.Neon, Transparency = 0.7, Anchored = true, CanCollide = false, CanQuery = false, Parent = folder })
	end
	-- land (not playable)
	local landFolder = New("Folder", { Name = "Land", Parent = folder })
	local cell = 360 / WorldMap.W
	for _, r in ipairs(WorldMap.land) do
		local p = rectPart(landFolder, r, cell, LAND_TOP, LAND, "Land")
		p.CanQuery = false
	end
	-- playable countries
	WM.countries = {}
	WM.partOwner = {}
	WM.queryParts = {}
	local ccell = 360 / WorldMap.CW
	for _, c in ipairs(Countries.list) do
		local shape = WorldMap.countries[c.id]
		local cf = New("Folder", { Name = c.id, Parent = folder })
		local parts = {}
		for _, r in ipairs(shape.rects) do
			local p = rectPart(cf, r, ccell, COUNTRY_TOP, Color3.fromRGB(0, 200, 255), "Country")
			table.insert(parts, { part = p, home = p.CFrame })
			WM.partOwner[p] = c.id
			table.insert(WM.queryParts, p)
		end
		local anchor = New("Part", {
			Name = "LabelAnchor",
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(WM.toWorld(shape.lat, shape.lon, COUNTRY_TOP + 2.5)),
			Transparency = 1,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Parent = cf,
		})
		local bb = New("BillboardGui", { Size = UDim2.fromOffset(180, 26), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 300, Parent = anchor })
		local label = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = c.name,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.2,
			TextSize = 17,
			Font = Enum.Font.GothamBlack,
			Parent = bb,
		})
		local badgeGui = New("BillboardGui", { Size = UDim2.fromOffset(26, 26), StudsOffset = Vector3.new(0, -2.2, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Parent = anchor })
		local badge = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = UI.Theme.accent,
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 15,
			Font = Enum.Font.GothamBold,
			Parent = badgeGui,
		})
		New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		local att = New("Attachment", { Position = Vector3.new(0, -1.5, 0), Axis = Vector3.new(0, 1, 0), SecondaryAxis = Vector3.new(1, 0, 0), Parent = anchor })
		WM.countries[c.id] = { parts = parts, label = label, labelGui = bb, badgeGui = badgeGui, badge = badge, attachment = att, anchor = anchor, color = LAND, lifted = false }
	end
	WM.routeFolder = New("Folder", { Name = "Route", Parent = folder })
	WM.focus = WM.toWorld(30, 0, 0)
	WM.dist = 520
end

------------------------------------------------------------------ looks
-- colorFn(cid) -> base colour of a country (e.g. by fan demand)
function WM.setColorFn(fn)
	WM.colorFn = fn
	WM.paint()
end

function WM.paint()
	if not WM.countries then
		return
	end
	for cid, c in pairs(WM.countries) do
		local col
		local lift = false
		if cid == WM.selected then
			col, lift = SELECTED, true
		elseif cid == WM.hovered then
			col, lift = HOVER, true
		else
			col = WM.colorFn and WM.colorFn(cid) or Color3.fromRGB(0, 200, 255)
			-- neighbours with the same colour get a slightly different shade, so borders stay visible
			local h = 0
			for i = 1, #cid do
				h = h + string.byte(cid, i) * i
			end
			local k = (h % 5) / 4
			col = col:Lerp((k > 0.5) and Color3.new(1, 1, 1) or Color3.new(0, 0, 0), math.abs(k - 0.5) * 0.28)
		end
		if c.color ~= col then
			c.color = col
			for _, p in ipairs(c.parts) do
				p.part.Color = col
				p.part.Material = lift and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
		if c.lifted ~= lift then
			c.lifted = lift
			for _, p in ipairs(c.parts) do
				p.part.CFrame = lift and (p.home + Vector3.new(0, LIFT, 0)) or p.home
			end
		end
		local important = lift
		c.labelGui.MaxDistance = important and 100000 or 300
		c.label.TextColor3 = (cid == WM.selected) and SELECTED or Color3.new(1, 1, 1)
		c.label.TextSize = important and 22 or 17
	end
end

function WM.setSelected(cid)
	WM.selected = cid
	WM.paint()
end

-- counts[cid] = number of shows there; route = list of country ids in show order
function WM.setRoute(route, counts)
	if not WM.countries then
		return
	end
	for cid, c in pairs(WM.countries) do
		local n = counts[cid]
		c.badgeGui.Enabled = n ~= nil
		c.badge.Text = n and tostring(n) or ""
	end
	WM.routeFolder:ClearAllChildren()
	for i = 2, #route do
		local a, b = WM.countries[route[i - 1]], WM.countries[route[i]]
		if a and b and a ~= b then
			local len = (a.anchor.Position - b.anchor.Position).Magnitude
			New("Beam", {
				Attachment0 = a.attachment,
				Attachment1 = b.attachment,
				CurveSize0 = len * 0.35,
				CurveSize1 = -len * 0.35,
				Width0 = 0.8,
				Width1 = 0.8,
				Color = ColorSequence.new(UI.Theme.accent),
				LightEmission = 1,
				LightInfluence = 0,
				FaceCamera = true,
				Segments = 24,
				Parent = WM.routeFolder,
			})
		end
	end
end

------------------------------------------------------------------ camera & input
local PITCH = math.rad(58)

-- puts the camera so that the map focus appears at screen point (sx, sy)
local function placeCamera(cam, sx, sy)
	local look = Vector3.new(0, -math.sin(PITCH), -math.cos(PITCH))
	local rot = CFrame.lookAt(Vector3.new(), look)
	local vp = cam.ViewportSize
	local tanY = math.tan(math.rad(cam.FieldOfView) / 2)
	local nx = (sx - vp.X / 2) / (vp.Y / 2)
	local ny = (sy - vp.Y / 2) / (vp.Y / 2)
	local dir = rot:VectorToWorldSpace(Vector3.new(nx * tanY, -ny * tanY, -1).Unit)
	local pos = WM.focus - dir * WM.dist
	cam.CFrame = CFrame.new(pos) * rot
end

-- opts = { isOverUI = fn() -> bool, onClick = fn(cid), onHover = fn(cid), screenCenter = fn() -> x, y }
function WM.activate(opts)
	if WM.folder then
		WM.folder.Parent = workspace
	end
	WM.build()
	WM.opts = opts
	if WM.active then
		return
	end
	WM.active = true
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(110, 110, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 140)
	local conns = {}
	WM.conns = conns
	local dragStart, dragging, lastMouse = nil, false, nil
	local targetFocus, targetDist = WM.focus, WM.dist
	WM.flyTarget = nil

	local function hoverAt()
		if opts.isOverUI and opts.isOverUI() then
			return nil
		end
		local m = UserInputService:GetMouseLocation()
		local ray = workspace.CurrentCamera:ViewportPointToRay(m.X, m.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = WM.queryParts
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		return hit and WM.partOwner[hit.Instance] or nil
	end

	table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not (opts.isOverUI and opts.isOverUI()) then
			dragStart = UserInputService:GetMouseLocation()
			lastMouse = dragStart
			dragging = false
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragStart then
			if not dragging then
				local cid = hoverAt()
				if cid and opts.onClick then
					opts.onClick(cid)
				end
			end
			dragStart, dragging = nil, false
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragStart then
			local m = UserInputService:GetMouseLocation()
			if (m - dragStart).Magnitude > 5 then
				dragging = true
			end
			if dragging then
				local d = m - lastMouse
				local k = WM.dist / 900
				targetFocus = targetFocus + Vector3.new(-d.X * k, 0, -d.Y * k * 1.3)
				WM.flyTarget = nil
			end
			lastMouse = m
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not gp and not (opts.isOverUI and opts.isOverUI()) then
			targetDist = math.clamp(targetDist * (1 - input.Position.Z * 0.15), 45, opts.maxDist or 560)
			WM.flyTarget = nil
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if WM.flyTarget then
			targetFocus, targetDist = WM.flyTarget[1], WM.flyTarget[2]
			WM.flyTarget = nil
		end
		-- keyboard pan
		if not UserInputService:GetFocusedTextBox() then
			local mv = Vector3.new()
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				mv = mv + Vector3.new(0, 0, -1)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				mv = mv + Vector3.new(0, 0, 1)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				mv = mv + Vector3.new(-1, 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				mv = mv + Vector3.new(1, 0, 0)
			end
			if mv.Magnitude > 0 then
				targetFocus = targetFocus + mv.Unit * dt * WM.dist * 0.8
			end
		end
		-- keep the focus on the map
		local rel = targetFocus - ORIGIN
		targetFocus = ORIGIN + Vector3.new(math.clamp(rel.X, -360, 360), 0, math.clamp(rel.Z, -160, 120))
		local a = 1 - math.exp(-dt * 8)
		WM.focus = WM.focus:Lerp(targetFocus, a)
		WM.dist = WM.dist + (targetDist - WM.dist) * a
		local cam = workspace.CurrentCamera
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = 50
		local sx, sy = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
		if opts.screenCenter then
			sx, sy = opts.screenCenter()
		end
		placeCamera(cam, sx, sy)
		-- hover
		local cid = (not dragging) and hoverAt() or nil
		if cid ~= WM.hovered then
			WM.hovered = cid
			WM.paint()
			if opts.onHover then
				opts.onHover(cid)
			end
		end
	end))
end

function WM.deactivate()
	-- the map table is far away, but in concerts the camera could still see it: take it out of the world
	if WM.folder then
		WM.folder.Parent = nil
	end
	if not WM.active then
		return
	end
	WM.active = false
	for _, c in ipairs(WM.conns or {}) do
		c:Disconnect()
	end
	WM.conns = nil
	if WM.hovered then
		WM.hovered = nil
		WM.paint()
	end
end

function WM.flyTo(lat, lon, dist)
	WM.flyTarget = { WM.toWorld(lat, lon, 0), dist }
end

return WM
