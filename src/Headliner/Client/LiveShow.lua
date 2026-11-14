-- Plays a concert in 3D: venue + crowd + your stage design + the artist.
-- Every show gets its own running order: the songs, the ballad position, effects and colours change.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Artists = require(Root.Data.Artists)
local Countries = require(Root.Data.Countries)
local Util = require(Root.Logic.Util)
local UI = require(Root.Client.UI)
local Builder = require(Root.Client.Builder)
local Stage3D = require(Root.Client.Stage3D)
local People = require(Root.Client.People)
local Venue = require(Root.Client.Venue)

local T = UI.Theme
local LiveShow = {}

local CAMERA_NAMES = { "Auto", "Wide", "Close", "Side", "Crowd", "Orbit" }
local GENRE_BPM = { Pop = 118, Rock = 134, ["Hip-Hop"] = 94, EDM = 128, Metal = 152, Indie = 112, ["K-Pop"] = 124, Country = 106, Latin = 98, ["R&B"] = 88 }
local LIFT_DEPTH = 10

local function smooth(a, b, t)
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

-- Builds the running order of one show.
-- returns segments = { {kind, title, t0, t1, bpm, c1, c2, intensity, sweep, spot, lasers, phones, hits = { {time, name} }} }
local function buildTimeline(ad, rng, songCount, hasRoof)
	local songs = {}
	for i, s in ipairs(ad.setlist) do
		songs[i] = s
	end
	local opener = table.remove(songs, 1)
	local closer = table.remove(songs, #songs) -- the big hit is always last
	for i = #songs, 2, -1 do
		local j = rng:NextInteger(1, i)
		songs[i], songs[j] = songs[j], songs[i]
	end
	local middle = {}
	for i = 1, math.max(1, songCount - 2) do
		table.insert(middle, songs[i])
	end
	local balladAt = rng:NextInteger(2, #middle + 1) -- position in the full set (2..n-1)
	local order = { { title = opener, kind = "opener" } }
	for _, title in ipairs(middle) do
		table.insert(order, { title = title, kind = (rng:NextNumber() < 0.55) and "banger" or "mid" })
	end
	if order[balladAt] then
		order[balladAt].kind = "ballad"
	end
	table.insert(order, { title = closer, kind = "finale" })

	local base = Color3.fromRGB(ad.color[1], ad.color[2], ad.color[3])
	local palette = {
		Color3.fromRGB(255, 40, 160), Color3.fromRGB(0, 200, 255), Color3.fromRGB(140, 60, 255),
		Color3.fromRGB(255, 120, 30), Color3.fromRGB(60, 255, 120), Color3.fromRGB(255, 230, 80),
	}
	local segments = {}
	local t = 0
	local function add(seg)
		seg.t0 = t
		seg.t1 = t + seg.len
		t = seg.t1
		seg.hits = seg.hits or {}
		table.insert(segments, seg)
		return seg
	end
	add({ kind = "intro", title = "The lights go down...", len = 5, bpm = 0, c1 = Color3.fromRGB(40, 60, 255), c2 = Color3.fromRGB(140, 60, 255), intensity = 0.4, sweep = 0.3 })
	local bpm0 = GENRE_BPM[ad.genre] or 120
	for i, song in ipairs(order) do
		if song.kind == "finale" then
			add({ kind = "break", title = "Encore! Encore!", len = 4, bpm = 0, c1 = Color3.fromRGB(20, 20, 60), c2 = base, intensity = 0.15, sweep = 0.2 })
		end
		local kind = song.kind
		local len = (kind == "ballad") and rng:NextInteger(17, 20) or rng:NextInteger(14, 18)
		local seg = {
			kind = kind,
			title = i .. ". " .. song.title,
			screen = string.upper(song.title),
			len = len,
			bpm = (kind == "ballad") and 72 or math.floor(bpm0 * (0.9 + rng:NextNumber() * 0.2)),
			c1 = (kind == "ballad") and Color3.fromRGB(255, 160, 60) or ((i % 2 == 1) and base or palette[rng:NextInteger(1, #palette)]),
			c2 = (kind == "ballad") and Color3.fromRGB(255, 230, 190) or palette[rng:NextInteger(1, #palette)],
			intensity = (kind == "ballad") and 0.55 or ((kind == "mid") and 0.8 or 1),
			sweep = (kind == "ballad") and 0.35 or ((kind == "finale") and 1.6 or 1 + rng:NextNumber() * 0.4),
			lasers = (kind == "banger" or kind == "finale") and rng:NextNumber() < 0.8,
			phones = kind == "ballad",
			song = i,
			hits = {},
		}
		local s0 = t
		local function hit(at, name)
			table.insert(seg.hits, { s0 + at, name })
		end
		if kind == "opener" then
			hit(0.2, "pyro")
			hit(0.2, "co2")
			hit(len * 0.5, "sparks")
		elseif kind == "banger" then
			local drop = len * (0.3 + rng:NextNumber() * 0.25)
			hit(drop, rng:NextNumber() < 0.6 and "pyro" or "co2")
			hit(drop + 4, "co2")
			if rng:NextNumber() < 0.5 then
				hit(len - 2, "sparks")
			end
			seg.strobeFrom = len - 4
		elseif kind == "mid" then
			if rng:NextNumber() < 0.4 then
				hit(len * 0.6, "confetti")
			end
		elseif kind == "ballad" then
			hit(len - 1, "sparks")
		elseif kind == "finale" then
			hit(0.2, "pyro")
			hit(0.2, "co2")
			hit(3, "sparks")
			for k = 6, len - 2, 4 do
				hit(k, (k % 8 == 6) and "pyro" or "co2")
			end
			hit(len * 0.45, "confetti")
			hit(len - 1.5, "confetti")
			if not hasRoof then
				hit(len * 0.6, "fireworks")
				hit(len - 1, "fireworks")
			end
			seg.strobeFrom = len - 8
		end
		add(seg)
	end
	add({ kind = "outro", title = "Thank you!", len = 5, bpm = 0, c1 = Color3.new(1, 1, 1), c2 = base, intensity = 0.8, sweep = 0.4 })
	return segments, t
end

-- opts = { artistId, design, venueId?, look?, cap, sold, tourName, result?, preview?, onDone }
function LiveShow.run(app, opts)
	local ad = Artists.byId[opts.artistId]
	local venue = opts.venueId and Countries.venueById[opts.venueId]
	local look = opts.look or (venue and Countries.VENUE_TYPES[venue.type].look) or "arena"
	local cap = opts.cap or (venue and venue.cap) or 15000
	local sold = opts.sold or cap
	local fill = sold / math.max(1, cap)
	local rating = (opts.result and opts.result.rating) or 80
	local artistColor = UI.rgb(ad.color)
	local cityName = venue and venue.city or "Rehearsal"
	local rng = Random.new(math.floor(os.clock() * 1000) % 100000)
	local hasRoof = Venue.LOOKS[look] and Venue.LOOKS[look].roof ~= nil
	local segments, showLength = buildTimeline(ad, rng, opts.preview and 3 or 4, hasRoof)
	local hits = {}
	for _, seg in ipairs(segments) do
		for _, h in ipairs(seg.hits) do
			table.insert(hits, h)
		end
	end
	table.sort(hits, function(a, b)
		return a[1] < b[1]
	end)

	Stage3D.setLighting("show")
	Stage3D.showGrid(false)
	local design = opts.design
	local items = Stage3D.renderDesign(design, { color = artistColor, artistName = string.upper(ad.name) })
	local centerStage = design ~= nil and design.layout == "center"

	-- find special items
	local lift, booth, drums
	local pits, spots, liftAt = {}, {}, {}
	for _, r in ipairs(items) do
		Builder.hideMarker(r)
		if r.kind == "lift" then
			local n = (r.rec and r.rec.play) or 1
			if not liftAt[n] then
				liftAt[n] = r
			end
		elseif r.kind == "djbooth" and not booth then
			booth = r
		elseif r.kind == "drums" and not drums then
			drums = r
		elseif r.kind == "pit" then
			table.insert(pits, { cf = r.cf, w = r.pitW, d = r.pitD })
		elseif r.kind == "spot" then
			table.insert(spots, r)
		end
	end
	table.sort(spots, function(a, b)
		return (a.spotIndex or 0) < (b.spotIndex or 0)
	end)
	local crowd = Venue.build(look, fill, artistColor, { layout = centerStage and "center" or "end", pits = pits })
	local deckCenter = Stage3D.deckBox()

	local function onSurface(p)
		return Vector3.new(p.X, Stage3D.surfaceY(p.X, p.Z), p.Z)
	end

	-- where the artist performs: spot 1 = opening, 2 = second song, 3 = ballad, 4 = finale
	local leadRole = "lead"
	local function spotPos(i)
		return spots[i] and spots[i].cf.Position or nil
	end
	lift = liftAt[1] -- the entrance lift
	local function liftTop(r)
		return r.cf.Position + Vector3.new(0, 0.4, 0)
	end
	local home = (lift and liftTop(lift)) or spotPos(1) or onSurface(deckCenter)
	if ad.genre == "EDM" and ad.members == 1 and booth then
		leadRole = "dj"
		home = (booth.cf * CFrame.new(0, 0, -3.2)).Position
		lift = nil -- a DJ stays at the booth
	end
	local start = lift and (lift.cf.Position + Vector3.new(0, 0.4, 0)) or home
	local liftUp0 = segments[1].t1 - 3 -- the lift rises at the end of the intro
	-- one walk per song: to the spot that belongs to that song
	-- props the artist plays (set in the designer): piano / drums / DJ booth at a spot number
	local playProps = {}
	for _, r in ipairs(items) do
		local n = r.rec and r.rec.play
		if n and (r.kind == "piano" or r.kind == "drums" or r.kind == "djbooth") then
			local seat, move, yaw
			if r.kind == "piano" then
				seat, move, yaw = (r.cf * CFrame.new(0, 0, 5.2)).Position, "piano", math.rad(r.rec.r or 0) + math.pi
			elseif r.kind == "drums" then
				seat, move, yaw = (r.cf * CFrame.new(0, 1, -1.8)).Position, "drumsolo", math.rad(r.rec.r or 0)
			else
				seat, move, yaw = (r.cf * CFrame.new(0, 0, -3.2)).Position, "dance", math.rad(r.rec.r or 0)
			end
			playProps[n] = { pos = seat, move = move, yaw = yaw }
		end
	end
	------------------------------------------------------------ path finding on the stage
	-- grid over all decks (2 studs per cell); the artist only walks where there is a deck
	-- and can only step up/down small heights (stairs). Unreachable spots are reached "backstage".
	local NAV = 2
	local navC, navW, navD = Stage3D.deckBox()
	local nx0, nz0 = navC.X - navW / 2 - 2, navC.Z - navD / 2 - 2
	local ncols, nrows = math.max(1, math.ceil((navW + 4) / NAV)), math.max(1, math.ceil((navD + 4) / NAV))
	local navH = {}
	local function cellH(i, j)
		local key = i * 10000 + j
		local h = navH[key]
		if h == nil then
			h = Stage3D.surfaceY(nx0 + (i + 0.5) * NAV, nz0 + (j + 0.5) * NAV)
			navH[key] = h
		end
		return h
	end
	local function cellOf(p)
		return math.clamp(math.floor((p.X - nx0) / NAV), 0, ncols - 1), math.clamp(math.floor((p.Z - nz0) / NAV), 0, nrows - 1)
	end
	local function findPath(from, to)
		local si, sj = cellOf(from)
		local ti, tj = cellOf(to)
		if si == ti and sj == tj then
			return { from, to }
		end
		if ncols * nrows > 20000 then
			return nil
		end
		local prev, queue, head = {}, { si * 10000 + sj }, 1
		prev[si * 10000 + sj] = -1
		local goal = ti * 10000 + tj
		while queue[head] do
			local key = queue[head]
			head = head + 1
			if key == goal then
				break
			end
			local i, j = math.floor(key / 10000), key % 10000
			local h = cellH(i, j)
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
				local ni, nj = i + d[1], j + d[2]
				local nk = ni * 10000 + nj
				if ni >= 0 and nj >= 0 and ni < ncols and nj < nrows and not prev[nk] then
					local nh = cellH(ni, nj)
					local ok = nh > 0.5 and math.abs(nh - h) <= 2.6
					if ok and d[1] ~= 0 and d[2] ~= 0 then
						-- no cutting corners over gaps
						ok = cellH(i + d[1], j) > 0.5 and cellH(i, j + d[2]) > 0.5
					end
					if ok then
						prev[nk] = key
						table.insert(queue, nk)
					end
				end
			end
		end
		if not prev[goal] then
			return nil
		end
		local cells = {}
		local k = goal
		while k ~= -1 do
			table.insert(cells, 1, k)
			k = prev[k]
		end
		local pts = { from }
		for n = 2, #cells - 1 do
			local i, j = math.floor(cells[n] / 10000), cells[n] % 10000
			table.insert(pts, Vector3.new(nx0 + (i + 0.5) * NAV, cellH(i, j), nz0 + (j + 0.5) * NAV))
		end
		table.insert(pts, to)
		return pts
	end
	local function pathLength(pts)
		local len = 0
		for n = 2, #pts do
			len = len + (pts[n] - pts[n - 1]).Magnitude
		end
		return len
	end
	local function pointOnPath(pts, dist)
		for n = 2, #pts do
			local seg = (pts[n] - pts[n - 1]).Magnitude
			if dist <= seg or n == #pts then
				local k = (seg > 0) and math.clamp(dist / seg, 0, 1) or 1
				local d = pts[n] - pts[n - 1]
				return pts[n - 1]:Lerp(pts[n], k), math.atan2(d.X, d.Z)
			end
			dist = dist - seg
		end
		return pts[#pts], 0
	end

	local walks = {}
	local cur = start
	for _, seg in ipairs(segments) do
		if seg.song then
			local spotIdx = 1
			if seg.kind == "ballad" then
				spotIdx = 3
			elseif seg.kind == "finale" then
				spotIdx = 4
			elseif seg.song == 2 then
				spotIdx = 2
			elseif seg.song > 2 then
				spotIdx = ((seg.song - 1) % 2) + 1
			end
			local w = { seg.t0, nil, spot = spotIdx }
			local play = playProps[spotIdx]
			local lf = liftAt[spotIdx]
			if play then
				w[2], w.play = play.pos, play
			elseif lf then
				w[2] = liftTop(lf)
			else
				w[2] = spotPos(spotIdx) or (spotIdx == 3 and spotPos(2)) or home
			end
			if lf and not play and lf ~= lift then
				w.kind, w.lift, w.dur = "lift", lf, 3 -- disappear, come up on this lift
			elseif (w[2] - cur).Magnitude < 1 then
				w.kind, w.dur = "stay", 0
			else
				local path = (leadRole ~= "dj") and findPath(cur, w[2]) or nil
				if path then
					w.kind, w.path = "walk", path
					w.len = pathLength(path)
					w.dur = math.clamp(w.len / 9, 1, 8)
				else
					w.kind, w.dur = "hidden", 2.5 -- goes backstage and reappears
				end
			end
			table.insert(walks, w)
			cur = w[2]
		end
	end
	local curWalk = nil

	local lead = People.new(Stage3D.peopleFolder, artistColor, 1.5, leadRole, 7)
	local band = {}
	if ad.members >= 4 and ad.genre ~= "K-Pop" then
		local drumPos = drums and (drums.cf * CFrame.new(0, 1, -1.6)).Position or onSurface(home + Vector3.new(0, 0, -10))
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "guitar", 11), pos = onSurface(home + Vector3.new(-14, 0, -4)) })
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "bass", 12), pos = onSurface(home + Vector3.new(14, 0, -4)) })
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "drums", 13), pos = drumPos })
	elseif ad.members >= 2 then
		local offs = { Vector3.new(-7, 0, -3), Vector3.new(7, 0, -3), Vector3.new(-14, 0, -5), Vector3.new(14, 0, -5) }
		for i = 1, math.min(4, ad.members - 1) do
			table.insert(band, { p = People.new(Stage3D.peopleFolder, artistColor:Lerp(Color3.new(1, 1, 1), 0.35), 1.45, "dancer", 20 + i), follow = offs[i] })
		end
	end
	local performers = { lead }
	for _, b in ipairs(band) do
		table.insert(performers, b.p)
	end

	local function idleYaw(t)
		if centerStage then
			return t * 0.35 -- turn around to face every side of the arena
		end
		return math.sin(t * 0.5) * 0.4
	end
	-- returns position, yaw, walking, hidden
	local function leadState(t)
		if leadRole == "dj" then
			return home, centerStage and idleYaw(t) or 0, false, false
		end
		if lift and t < liftUp0 + 3 then
			local k = smooth(liftUp0, liftUp0 + 3, t)
			return start + Vector3.new(0, (k - 1) * LIFT_DEPTH, 0), 0, false, t < liftUp0
		end
		local pos = start
		curWalk = nil
		for _, w in ipairs(walks) do
			local lead0 = (w.kind == "lift") and 1 or 0
			if t < w[1] - lead0 then
				return pos, idleYaw(t), false, false
			end
			curWalk = w
			local to = w[2]
			if t < w[1] + w.dur then
				if w.kind == "lift" then
					if t < w[1] then
						return pos, idleYaw(t), false, true
					end
					local k = smooth(w[1], w[1] + 3, t)
					return to + Vector3.new(0, (k - 1) * LIFT_DEPTH, 0), 0, false, false
				elseif w.kind == "hidden" then
					return to, 0, false, true
				elseif w.kind == "walk" then
					local p, yaw = pointOnPath(w.path, w.len * smooth(w[1], w[1] + w.dur, t))
					return p, yaw, true, false
				end
			end
			pos = to
		end
		return pos, idleYaw(t), false, false
	end

	-- lift platform height (0 = down, 1 = up) for each lift
	local function liftValue(r, t)
		if r == lift and t < liftUp0 + 3 then
			return smooth(liftUp0, liftUp0 + 3, t)
		end
		for _, w in ipairs(walks) do
			if w.lift == r and t >= w[1] - 1 and t < w[1] + 3 then
				return smooth(w[1], w[1] + 3, t)
			end
		end
		return 1
	end

	-- UI overlay (compact, so you can see the show)
	app:enterMode("live")
	local overlay = UI.New("Frame", { Parent = app.canvas, Size = UI.px(1920, 1080), BackgroundTransparency = 1, Name = "LiveOverlay" })
	local info = UI.Panel(overlay, UI.px(24, 72), UI.px(560, 108), T.panel)
	info.BackgroundTransparency = 0.35
	UI.Pill(info, opts.preview and "PREVIEW" or "LIVE", UI.px(14, 12), UI.px(76, 24), opts.preview and T.accent2 or T.bad, 13)
	UI.Label(info, ad.name .. "  -  " .. (opts.tourName or "Rehearsal"), UI.px(100, 10), UI.px(450, 28), { textSize = 19, font = UI.FontBold })
	UI.Label(info, venue and (venue.name .. ", " .. venue.city) or "Stage design preview", UI.px(14, 42), UI.px(400, 22), { textSize = 15, color = T.sub })
	UI.Label(info, Util.number(sold) .. " / " .. Util.number(cap), UI.px(400, 42), UI.px(146, 22), { textSize = 15, color = T.sub, alignX = Enum.TextXAlignment.Right })
	local songLbl = UI.Label(info, "", UI.px(14, 70), UI.px(530, 28), { textSize = 19, color = T.gold, font = UI.FontBold })
	local _, setProg = UI.Bar(overlay, UI.px(24, 186), UI.px(560, 5), 0, T.accent)

	local camMode = 1
	local camButtons = {}
	local bar = UI.Panel(overlay, UI.px(1920 / 2 - 450, 1012), UI.px(900, 52), T.panel)
	bar.BackgroundTransparency = 0.35
	UI.List(false, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = bar
	for i, name in ipairs(CAMERA_NAMES) do
		camButtons[i] = UI.Button(bar, name .. " [" .. (i - 1) .. "]", nil, UI.px(104, 38), { order = i, textSize = 14 }, function()
			camMode = i
		end)
	end
	local finished = false
	local timeScale = 1
	local speedBtn
	speedBtn = UI.Button(bar, "Speed 1x", nil, UI.px(104, 38), { order = 19, textSize = 14 }, function()
		timeScale = (timeScale == 1) and 2 or ((timeScale == 2) and 4 or 1)
		speedBtn.Text = "Speed " .. timeScale .. "x"
	end)
	UI.Button(bar, "Skip >>", nil, UI.px(100, 38), { order = 20, color = T.accent, textSize = 14 }, function()
		finished = true
	end)

	local keyConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		local map = {
			[Enum.KeyCode.Zero] = 1, [Enum.KeyCode.One] = 2, [Enum.KeyCode.Two] = 3,
			[Enum.KeyCode.Three] = 4, [Enum.KeyCode.Four] = 5, [Enum.KeyCode.Five] = 6,
		}
		if map[input.KeyCode] then
			camMode = map[input.KeyCode]
		end
	end)

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 60
	local size = crowd.size
	local camCF = nil
	local t = 0
	local hitIndex = 1
	local beatCount = 0
	local lastBeatT = 0
	local segIndex = 1
	local ctx = { hit = {}, artistName = string.upper(ad.name) }
	if lift then
		lead:setVisible(false)
	end

	local function shot(mode, tt, leadPos, leadYaw)
		local headP = leadPos + Vector3.new(0, 7, 0)
		local C = deckCenter + Vector3.new(0, 8, 0)
		local reach = math.max(30, size.halfW - 6)
		if mode == 2 then
			if centerStage then
				return Vector3.new(0, 55, math.min(reach, 110)), C
			end
			return Vector3.new(0, 28, math.min(size.floorEnd * 0.8, C.Z + 130)), C
		elseif mode == 3 then
			return headP + Vector3.new(math.sin(leadYaw) * 26, 3, math.cos(leadYaw) * 26), headP
		elseif mode == 4 then
			return Vector3.new(-math.min(52, reach), 22, C.Z + 14), C
		elseif mode == 5 then
			if centerStage then
				local a = tt * 0.1
				return C + Vector3.new(0, 30, 0), Vector3.new(math.sin(a) * reach, 0, math.cos(a) * reach)
			end
			return C + Vector3.new(6, 26, -16), Vector3.new(0, 0, size.floorEnd * 0.45)
		else
			local a = tt * 0.12
			local r = math.min(95, reach)
			return C + Vector3.new(math.sin(a) * r, 22, math.cos(a) * r), C
		end
	end
	local autoOrder = { 2, 3, 5, 4, 6, 3, 2, 5 }
	local livePerformerParts = {}
	for _, p in ipairs(lead.model:GetChildren()) do
		if p:IsA("BasePart") then
			table.insert(livePerformerParts, p)
		end
	end
	local liveCrowdParts = {}
	local crowdCenter = Vector3.new(0, 0, size.floorEnd * 0.4)
	for i = 1, math.min(80, #crowd.parts) do
		table.insert(liveCrowdParts, crowd.parts[i])
	end
	if #liveCrowdParts > 0 then
		local sum = Vector3.new()
		for _, p in ipairs(liveCrowdParts) do
			sum = sum + p.Position
		end
		crowdCenter = sum / #liveCrowdParts
	end

	local done = false
	local conn
	local function finish()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		keyConn:Disconnect()
		for _, p in ipairs(performers) do
			p:destroy()
		end
		Venue.destroy(crowd)
		Stage3D.clearDesign()
		Stage3D.setLighting("designer")
		overlay:Destroy()
		if opts.onDone then
			opts.onDone()
		end
	end

	conn = RunService.RenderStepped:Connect(function(dt)
		if finished then
			finish()
			return
		end
		dt = dt * timeScale
		t = t + dt
		if t >= showLength then
			finish()
			return
		end
		while segments[segIndex + 1] and t >= segments[segIndex].t1 do
			segIndex = segIndex + 1
		end
		local seg = segments[segIndex]
		-- beat clock
		local beat = 0
		if seg.bpm > 0 then
			local spb = 60 / seg.bpm
			if t - lastBeatT >= spb then
				lastBeatT = t
				beatCount = beatCount + 1
			end
			beat = math.clamp((t - lastBeatT) / spb, 0, 1)
		end
		-- hits
		local hit = ctx.hit
		for k in pairs(hit) do
			hit[k] = nil
		end
		while hits[hitIndex] and hits[hitIndex][1] <= t do
			hit[hits[hitIndex][2]] = true
			hitIndex = hitIndex + 1
		end
		local inSeg = t - seg.t0
		local strobe = seg.strobeFrom ~= nil and inSeg >= seg.strobeFrom
		local blind = math.max(0, 1 - math.abs(inSeg - 0.3) * 2.5) * ((seg.song and seg.kind ~= "ballad") and 1 or 0)
		if seg.kind == "outro" then
			blind = math.max(blind, math.max(0, 1 - math.abs(inSeg - 0.5)))
		end
		local screenText = seg.screen or ctx.artistName
		if seg.kind == "intro" then
			local left = seg.t1 - t
			screenText = (left < 4) and tostring(math.max(1, math.ceil(left - 0.5))) or string.upper(opts.tourName or ad.name)
		elseif seg.kind == "break" then
			screenText = string.upper(cityName) .. " MAKE SOME NOISE!"
		elseif seg.kind == "outro" then
			screenText = "THANK YOU " .. string.upper(cityName) .. "!"
		end

		local leadPos, leadYaw, walking, hidden = leadState(t)
		lead:setVisible(not hidden)
		local energy = (seg.bpm > 0) and 1 or 0.4
		-- what the artist does: changes every few seconds and depends on the song and genre
		local move = "idle"
		if seg.kind == "ballad" then
			move = (inSeg > seg.len * 0.55) and "kneel" or "dance"
		elseif seg.kind == "break" then
			move = "wave"
		elseif seg.kind == "outro" then
			move = (inSeg < 2.5) and "bow" or "wave"
		elseif seg.song then
			local cycle = (ad.genre == "Metal" or ad.genre == "Rock") and { "headbang", "jump", "point", "micout" } or { "dance", "point", "jump", "wave" }
			if seg.kind == "finale" then
				cycle = { "jump", "micout", "jump", "wave" }
			elseif seg.kind == "mid" then
				cycle = { "dance", "point", "micout", "dance" }
			end
			move = cycle[(math.floor(inSeg / 4) + seg.song) % #cycle + 1]
		end
		if curWalk and curWalk.play and t >= curWalk[1] + 5 and not walking then
			move = curWalk.play.move
			leadYaw = curWalk.play.yaw
		end
		local armsUp = 0
		lead:update(leadPos, leadYaw, { t = t, beat = beat, energy = energy, walking = walking, armsUp = armsUp, move = move })
		local bandMove = (ad.genre == "K-Pop") and move or (((ad.genre == "Metal" or ad.genre == "Rock") and seg.kind == "banger") and "headbang" or "idle")
		for _, b in ipairs(band) do
			local pos = b.pos
			if b.follow then
				pos = onSurface(leadPos + b.follow)
			end
			b.p:update(pos, 0, { t = t + 0.3, beat = beat, energy = energy, walking = false, armsUp = armsUp, move = (bandMove == "micout") and "point" or bandMove })
		end

		ctx.t = t
		ctx.beat = beat
		ctx.beatCount = beatCount
		ctx.seg = (seg.kind == "ballad") and 3 or ((seg.kind == "finale") and 4 or 1)
		ctx.c1 = seg.c1
		ctx.c2 = seg.c2
		ctx.intensity = seg.intensity
		ctx.sweep = seg.sweep
		ctx.strobe = strobe
		ctx.blind = math.clamp(blind, 0, 1)
		ctx.lasers = seg.lasers == true
		ctx.artistPos = lead:headPosition()
		ctx.liftT = 1
		for _, r in ipairs(items) do
			if r.kind == "lift" then
				r.liftT = liftValue(r, t)
			end
		end
		local fin = (seg.kind == "finale") and seg or nil
		ctx.scissorT = fin and (smooth(fin.t0 + 2, fin.t0 + 6, t) * (1 - smooth(fin.t1 - 3, fin.t1, t))) or 0
		ctx.inflate = 0
		for _, s2 in ipairs(segments) do
			if s2.kind == "ballad" then
				ctx.inflate = smooth(s2.t0, s2.t0 + 4, t)
			end
		end
		ctx.screenText = screenText
		ctx.spotIndex = curWalk and curWalk.spot or 1
		-- live camera feeds for screens set to "Live: artist" / "Live: crowd"
		local head = lead:headPosition()
		local fwd = Vector3.new(math.sin(leadYaw), 0, math.cos(leadYaw))
		ctx.livePerformer = { parts = livePerformerParts, cam = CFrame.lookAt(head + fwd * 9 + Vector3.new(0, 0.5, 0), head - Vector3.new(0, 1.2, 0)) }
		ctx.liveCrowd = { parts = liveCrowdParts, cam = CFrame.lookAt(deckCenter + Vector3.new(0, 14, 0), crowdCenter) }
		for _, r in ipairs(items) do
			Builder.animate(r, ctx)
		end

		-- crowd
		local crowdEnergy = 0.4 + 1.4 * (rating / 100)
		local speed = seg.bpm > 0 and (seg.bpm / 60 * math.pi) or 5
		local segMult = 0.6
		if seg.kind == "ballad" then
			segMult = 0.12
		elseif seg.kind == "finale" then
			segMult = 1.3
		elseif seg.kind == "break" then
			segMult = 0.9
		elseif seg.kind == "mid" then
			segMult = 0.75
		elseif seg.bpm > 0 then
			segMult = 1
		end
		Venue.animate(crowd, t, crowdEnergy * segMult, speed, seg.phones == true)

		if songLbl.Text ~= seg.title then
			songLbl.Text = seg.title
		end
		setProg(t / showLength)

		-- camera
		local mode = camMode
		if mode == 1 then
			mode = autoOrder[(math.floor(t / 7) % #autoOrder) + 1]
		end
		for i, b in ipairs(camButtons) do
			b.BackgroundColor3 = (i == camMode) and T.accent or T.panel3
		end
		local pos, at = shot(mode, t, leadPos, leadYaw)
		local target = CFrame.lookAt(pos, at)
		if not camCF then
			camCF = target
		else
			camCF = camCF:Lerp(target, 1 - math.exp(-dt * 2.5))
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = camCF
	end)
end

return LiveShow
