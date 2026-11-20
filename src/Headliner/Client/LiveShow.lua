-- Plays a concert in 3D: venue + crowd + your stage design + the artist.
-- Every show gets its own running order: the songs, the ballad position, effects and colours change.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Root = script:FindFirstAncestor("Headliner")
local Artists = require(Root.Data.Artists)
local Countries = require(Root.Data.Countries)
local Util = require(Root.Logic.Util)
local GS = require(Root.Logic.GameState)
local UI = require(Root.Client.UI)
local Builder = require(Root.Client.Builder)
local Stage3D = require(Root.Client.Stage3D)
local StageNav = require(Root.Client.StageNav)
local People = require(Root.Client.People)
local Venue = require(Root.Client.Venue)
local LiveFeed = require(Root.Client.LiveFeed)
local SoundFX = require(Root.Client.SoundFX)
local AudioMap = require(Root.Data.AudioMap)
local ShowTasks = require(Root.Client.ShowTasks)

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
	-- song numbers refer to the artist's setlist (and to the audio file): 1 = opener, 4 = the ballad, 8 = the big hit
	local BALLAD, HIT = AudioMap.BALLAD_INDEX or 4, AudioMap.HIT_INDEX or 8
	local pool = {}
	for i = 2, #ad.setlist do
		if i ~= BALLAD and i ~= HIT then
			table.insert(pool, i)
		end
	end
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local middle = {}
	for i = 1, songCount - 3 do
		table.insert(middle, pool[(i - 1) % #pool + 1])
	end
	table.insert(middle, rng:NextInteger(math.max(1, #middle - 1), #middle + 1), BALLAD)
	local order = { { title = ad.setlist[1], idx = 1, kind = "opener" } }
	for _, n in ipairs(middle) do
		table.insert(order, { title = ad.setlist[n], idx = n, kind = (n == BALLAD) and "ballad" or ((rng:NextNumber() < 0.55) and "banger" or "mid") })
	end
	table.insert(order, { title = ad.setlist[HIT], idx = HIT, kind = "finale" })

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
	add({ kind = "intro", title = "The lights go down...", fog = true, len = 5, bpm = 0, c1 = Color3.fromRGB(40, 60, 255), c2 = Color3.fromRGB(140, 60, 255), intensity = 0.4, sweep = 0.3 })
	local bpm0 = GENRE_BPM[ad.genre] or 120
	for i, song in ipairs(order) do
		if song.kind == "finale" then
			add({ kind = "break", title = "Encore! Encore!", len = 4, bpm = 0, c1 = Color3.fromRGB(20, 20, 60), c2 = base, intensity = 0.15, sweep = 0.2 })
		end
		local kind = song.kind
		local len = (kind == "ballad") and rng:NextInteger(23, 26) or rng:NextInteger(20, 24)
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
			songIndex = song.idx,
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
			seg.fog = true
		elseif kind == "finale" then
			hit(0.2, "pyro")
			hit(0.2, "co2")
			hit(3, "sparks")
			for k = 6, len - 2, 4 do
				hit(k, (k % 8 == 6) and "pyro" or "co2")
			end
			hit(len * 0.45, "confetti")
			hit(len * 0.3, "balls")
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

-- effect items and the hit that fires them (laser / low fog follow ctx.lasers / ctx.fog)
local FX_HIT = { pyro = "pyro", flamebar = "pyro", sparks = "sparks", sparkrain = "sparks", confetti = "confetti", streamers = "streamers", co2 = "co2", fireworks = "fireworks", balls = "balls", laser = "laser", lowfog = "fog" }

-- the moves of the artist at an instrument (they change every 4 seconds)
local PLAY_MOVES = {
	piano = { "piano", "pianosway", "piano" },
	keys = { "keys", "keys", "keyshype" },
	drumsolo = { "drumsolo", "drumfill", "drumsolo", "drumfill" },
	dance = { "djmix", "djknob", "djhype", "djmix" },
	harp = { "harp" },
	strum = { "strum" },
	standmic = { "standmic" },
}

------------------------------------------------------------------ the dancers of a group (K-Pop & co.)
-- formations: places next to the anchor (the artist's place in that song); +Z = towards the fans
local FORMATIONS = {
	line = { { -6, -3 }, { 6, -3 }, { -12, -3 }, { 12, -3 }, { -18, -3 }, { 18, -3 } },
	v = { { -5, -4 }, { 5, -4 }, { -10, -8 }, { 10, -8 }, { -15, -12 }, { 15, -12 } },
	wings = { { -9, 1 }, { 9, 1 }, { -13, -3 }, { 13, -3 }, { -17, 1 }, { 17, 1 } },
	diamond = { { 0, -6 }, { -6, -2 }, { 6, -2 }, { 0, -11 }, { -11, -6 }, { 11, -6 } },
	front = { { -5, 4 }, { 5, 4 }, { -10, 2 }, { 10, 2 }, { -15, 0 }, { 15, 0 } },
	circle = { { -7, 0 }, { 7, 0 }, { 0, -7 }, { -5, -5 }, { 5, -5 }, { 0, 6 } },
	pairs = { { -8, -2 }, { -5, -2 }, { 5, -2 }, { 8, -2 }, { -14, -5 }, { 14, -5 } },
}
local FORMATION_ORDER = { "line", "v", "wings", "diamond", "front", "pairs", "circle" }
local CREW_MOVES = {
	["K-Pop"] = { "groove", "hiphop", "armwave", "shimmy", "kick", "heart", "spin", "clap", "pose", "dance" },
	default = { "dance", "groove", "clap", "swayup", "armwave", "hiphop", "kick" },
}
-- moves everybody does together (one per song)
local SYNC_MOVES = { "clap", "armwave", "hiphop", "kick", "heart", "groove", "spin" }

-- plans every dancer's places and walks for the whole show. env = { findPath, onSurface, walkable, nav, start }
function LiveShow.planCrew(ad, color, segments, walks, env)
	local rng = Random.new(#ad.id * 97 + ad.members)
	local n = math.min(6, ad.members - 1)
	local crew = {}
	for i = 1, n do
		local fig = People.new(Stage3D.peopleFolder, color:Lerp(Color3.new(1, 1, 1), 0.35), 1.45, "dancer", 20 + i, People.bandLook(ad, 10 + i, Artists.BAND_STYLE))
		table.insert(crew, { p = fig, i = i, plan = {}, phase = rng:NextNumber() * 6, yaw = 0 })
	end
	-- where the artist is in each song
	local anchorOf = {}
	local last = env.start
	for _, w in ipairs(walks) do
		if w.spot and w[2] and not w.moment then
			anchorOf[w.spot] = w[2]
			last = w[2]
		end
	end
	-- a free place on a deck near a wanted point
	local function place(want, taken)
		local ok, cell = env.walkable(env.onSurface(want))
		local function free(p)
			for _, q in ipairs(taken) do
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(q.X, 0, q.Z)).Magnitude < 3.2 then
					return false
				end
			end
			return true
		end
		if ok and free(cell) then
			return cell
		end
		-- look around in rings for a deck cell that is free
		for r = 1, 6 do
			for k = 0, 11 do
				local a = k / 12 * math.pi * 2
				local p = want + Vector3.new(math.cos(a) * r * env.nav, 0, math.sin(a) * r * env.nav)
				local ok2, c2 = env.walkable(env.onSurface(p))
				if ok2 and free(c2) then
					return c2
				end
			end
		end
		return nil
	end
	local cur = {}
	local prevAnchor = env.start
	local formN = rng:NextInteger(1, #FORMATION_ORDER)
	for _, seg in ipairs(segments) do
		if seg.song then
			local anchor = anchorOf[seg.song] or prevAnchor or last
			prevAnchor = anchor
			-- one formation at the start of the song, a second one half way through long songs
			local changes = { { seg.t0 + 0.4, FORMATION_ORDER[formN % #FORMATION_ORDER + 1] } }
			formN = formN + 1
			if seg.len >= 16 then
				table.insert(changes, { seg.t0 + seg.len * 0.5, FORMATION_ORDER[formN % #FORMATION_ORDER + 1] })
				formN = formN + 1
			end
			for _, ch in ipairs(changes) do
				local form = FORMATIONS[ch[2]]
				local taken = { anchor }
				for _, c in ipairs(crew) do
					local off = form[c.i] or { (c.i % 2 == 0) and 8 or -8, -4 }
					local target = place(anchor + Vector3.new(off[1], 0, off[2]), taken) or cur[c.i] or anchor
					table.insert(taken, target)
					local from = cur[c.i] or target
					local path = nil
					if (target - from).Magnitude > 0.5 then
						path = env.findPath(from, target)
						if not path then
							path = { from, target }
						end
					end
					local len = 0
					for k = 2, #(path or {}) do
						len = len + (path[k] - path[k - 1]).Magnitude
					end
					-- they set off one after the other, not like a robot army
					table.insert(c.plan, { t = ch[1] + (c.i - 1) * 0.2, to = target, path = path, len = len, dur = math.clamp(len / 9, 0.6, 6), form = ch[2] })
					cur[c.i] = target
				end
			end
		end
	end
	-- before the first song: at their first places
	for _, c in ipairs(crew) do
		c.pos = c.plan[1] and c.plan[1].to or env.start
	end
	return crew
end

local function pathPoint(path, len, f)
	local d = len * f
	for k = 2, #path do
		local sl = (path[k] - path[k - 1]).Magnitude
		if d <= sl or k == #path then
			local u = (sl > 0) and math.clamp(d / sl, 0, 1) or 1
			local dir = path[k] - path[k - 1]
			return path[k - 1]:Lerp(path[k], u), math.atan2(dir.X, dir.Z)
		end
		d = d - sl
	end
	return path[#path], 0
end

-- every frame: walk / dance / move in sync / a moment with a partner
function LiveShow.updateCrew(crew, t, seg, inSeg, beat, energy, leadMove, facing, genre)
	local moves = CREW_MOVES[genre or ""] or CREW_MOVES.default
	for _, c in ipairs(crew) do
		local step = nil
		for _, s2 in ipairs(c.plan) do
			if t >= s2.t then
				step = s2
			end
		end
		local pos, yaw, walking = c.pos, facing, false
		if step then
			if step.path and t < step.t + step.dur then
				local f = (t - step.t) / step.dur
				f = f * f * (3 - 2 * f)
				pos, yaw = pathPoint(step.path, step.len, f)
				walking = true
			else
				pos = step.to
			end
		end
		c.pos = pos
		local move
		if walking then
			move = "walk"
		elseif seg.kind == "intro" then
			move = "pose"
		elseif seg.kind == "ballad" then
			move = (c.i % 2 == 0) and "swayup" or "dance"
		elseif seg.kind == "outro" or seg.kind == "break" then
			move = leadMove -- bow and wave with the artist
		elseif seg.song then
			local songLen = seg.t1 - seg.t0
			local syncA = inSeg >= 6 and inSeg < 12
			local syncB = inSeg >= songLen - 7
			local pairT = inSeg >= songLen * 0.5 + 2 and inSeg < songLen * 0.5 + 6
			if syncA or syncB or seg.kind == "finale" and inSeg > songLen - 12 then
				-- everybody together: the same move, facing the fans
				move = SYNC_MOVES[(seg.song % #SYNC_MOVES) + 1]
				if seg.kind == "finale" and syncB then
					move = "jump"
				end
			elseif pairT and crew[c.i + ((c.i % 2 == 1) and 1 or -1)] then
				-- two dancers turn to each other: clap and point
				local partner = crew[c.i + ((c.i % 2 == 1) and 1 or -1)]
				local d = partner.pos - pos
				if d.Magnitude > 0.1 then
					yaw = math.atan2(d.X, d.Z)
				end
				move = (c.i % 2 == 1) and "clap" or "point"
			else
				-- their own moves, every few seconds a new one
				local k = math.floor((t + c.phase) / 3.2) + c.i * 3
				move = moves[k % #moves + 1]
			end
		else
			move = "idle"
		end
		c.p:update(pos, yaw, { t = t + c.phase, beat = beat, energy = energy, walking = walking, armsUp = 0, move = move })
		c.move = move
	end
end

------------------------------------------------------------------ the crew brings instruments on and off
-- before the song: two stagehands walk on from behind the stage, the instrument appears piece by piece
-- (from the bottom up), they walk off; after the song the same backwards
local crewHidden = setmetatable({}, { __mode = "k" }) -- parts the crew has not built yet / already took away
local function showParts(job, frac)
	-- frac 0 = nothing, 1 = everything (pieces sorted from the bottom up)
	local n = #job.parts
	local k = math.floor(frac * n + 0.5)
	if job.shown == k then
		return
	end
	job.shown = k
	for i, e in ipairs(job.parts) do
		e[1].Transparency = (i <= k) and e[2] or 1
		crewHidden[e[1]] = (i > k) or nil
	end
end
function LiveShow.planSetups(items, segments, navC, navD, onSurface)
	local jobs = {}
	for _, r in ipairs(items) do
		local rec = r.rec
		if rec and rec.setup == "crew" and type(rec.play) == "number" and rec.play > 1 then
			local seg = nil
			for _, s2 in ipairs(segments) do
				if s2.song == rec.play then
					seg = s2
				end
			end
			if seg then
				local parts = {}
				for _, d in ipairs(r.model:GetDescendants()) do
					if d:IsA("BasePart") and d.Transparency < 1 then
						table.insert(parts, { d, d.Transparency, d.CFrame.Position.Y })
					end
				end
				table.sort(parts, function(a, b)
					return a[3] < b[3]
				end)
				local p = r.cf.Position
				local back = navC.Z - navD / 2 - 3
				local hands = {}
				for i = 1, 2 do
					local look = { worker = true, top = { 249, 115, 22 }, pants = { 40, 44, 56 }, shoes = { 30, 30, 30 }, hair = "short" }
					local fig = People.new(Stage3D.peopleFolder, Color3.fromRGB(249, 115, 22), 1.35, "dancer", 300 + #jobs * 2 + i, look)
					fig:setVisible(false)
					local side = (i == 1) and -1 or 1
					table.insert(hands, { p = fig, from = onSurface(Vector3.new(p.X + side * 2.5, 0, back)), to = onSurface(Vector3.new(p.X + side * 2.4, 0, p.Z + 1.5)) })
				end
				local tIn = math.max(segments[1].t0 + 1, seg.t0 - 6.5)
				local job = { item = r, parts = parts, hands = hands, tIn = tIn, tOut = seg.t1 + 0.5 }
				showParts(job, 0)
				table.insert(jobs, job)
			end
		end
	end
	return jobs
end
function LiveShow.updateSetups(jobs, t)
	for _, job in ipairs(jobs) do
		-- 0..2 walk on, 2..4.5 build, 4.5..6.5 walk off (and the same after the song)
		local u, phase = nil, nil
		if t >= job.tIn and t < job.tIn + 6.5 then
			u, phase = t - job.tIn, "on"
		elseif t >= job.tOut and t < job.tOut + 6.5 then
			u, phase = t - job.tOut, "off"
		end
		if phase then
			local frac = math.clamp((u - 2) / 2.5, 0, 1)
			showParts(job, (phase == "on") and frac or (1 - frac))
			for i, h in ipairs(job.hands) do
				local pos, walking, yaw
				if u < 2 then
					local f = u / 2
					pos, walking = h.from:Lerp(h.to, f), true
					local d = h.to - h.from
					yaw = math.atan2(d.X, d.Z)
				elseif u < 4.5 then
					pos, walking = h.to, false
					local d = job.item.cf.Position - h.to
					yaw = math.atan2(d.X, d.Z)
				else
					local f = math.clamp((u - 4.5) / 2, 0, 1)
					pos, walking = h.to:Lerp(h.from, f), true
					local d = h.from - h.to
					yaw = math.atan2(d.X, d.Z)
				end
				h.p:setVisible(true)
				h.p:update(pos, yaw, { t = t + i, beat = 0, energy = 0.4, walking = walking, armsUp = 0, move = walking and "walk" or "carry" })
			end
		else
			for _, h in ipairs(job.hands) do
				h.p:setVisible(false)
			end
			-- before it is built and after it is taken away nothing is there; in between it stays as it is
			if t < job.tIn or t >= job.tOut + 6.5 then
				showParts(job, 0)
			elseif job.shown ~= #job.parts and t >= job.tIn + 6.5 and t < job.tOut then
				showParts(job, 1)
			end
		end
	end
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
	-- one song per performance place (artist spots, lifts, instruments), see GS.songPlan
	local plan = GS.songPlan(opts.design)
	local songCount = plan.count
	local segments, showLength = buildTimeline(ad, rng, songCount, hasRoof)
	local songStart = {} -- when song n starts (curtains that open in a later song)
	for _, sg in ipairs(segments) do
		if sg.song then
			songStart[sg.song] = sg.t0
		end
	end
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
	local riseY
	local pits, spots, liftAt = {}, {}, {}
	for _, r in ipairs(items) do
		Builder.hideMarker(r)
		if GS.LIFT_ITEMS[r.kind] then
			local n = (r.rec and plan.songOf[r.rec]) or 1
			if not liftAt[n] then
				liftAt[n] = r
			end
		elseif r.kind == "djbooth" and not booth then
			booth = r
		elseif r.kind == "drums" and not drums then
			drums = r
		elseif r.kind == "pit" then
			table.insert(pits, { cf = r.cf, w = r.pitW, d = r.pitD })
		elseif r.kind == "delaytower" or r.kind == "towerlift" then
			-- nobody stands inside a tower in the crowd
			table.insert(pits, { cf = r.cf, w = (r.kind == "delaytower") and 10 or 14, d = (r.kind == "delaytower") and 10 or 14, solid = true })
		elseif r.kind == "spot" then
			table.insert(spots, r)
		end
	end
	table.sort(spots, function(a, b)
		return (a.spotIndex or 0) < (b.spotIndex or 0)
	end)
	-- which songs have effects set by hand (see the animation loop)
	local songFx = {}
	for _, r in ipairs(items) do
		local songs = r.rec and r.rec.songs
		if type(songs) == "table" and FX_HIT[r.kind] then
			for _, n in ipairs(songs) do
				songFx[n] = true
			end
		end
	end
	local wristbands = false
	for _, r in ipairs(items) do
		if r.kind == "wristbands" then
			wristbands = true
		end
	end
	local crowd = Venue.build(look, fill, artistColor, { layout = centerStage and "center" or "end", pits = pits, wristbands = wristbands })
	local deckCenter = Stage3D.deckBox()

	local function onSurface(p)
		return Vector3.new(p.X, Stage3D.surfaceY(p.X, p.Z), p.Z)
	end

	-- where the artist performs: spot 1 = opening, 2 = second song, 3 = ballad, 4 = finale
	local leadRole = "lead"
	-- spot that belongs to song i (nil: that song has no artist spot)
	local spotBySong = {}
	for _, r in ipairs(spots) do
		local n = r.rec and plan.songOf[r.rec]
		if n then
			spotBySong[n] = r
		end
	end
	local function spotPos(i)
		return spotBySong[i] and spotBySong[i].cf.Position or nil
	end
	lift = liftAt[1] -- the entrance lift
	local function liftTop(r)
		return r.cf.Position + Vector3.new(0, r.topY or 0.4, 0)
	end
	-- how long a lift needs to bring the artist up (the pop-up lift is a catapult)
	local function liftDur(r)
		return (r and r.kind == "poplift") and 1.1 or 3
	end
	local home = (lift and liftTop(lift)) or spotPos(1) or onSurface(deckCenter)
	if lift and lift.kind == "towerlift" then
		lift = nil -- the show starts on the tower; it rises during song 1
	end
	if ad.genre == "EDM" and ad.members == 1 and booth then
		leadRole = "dj"
		home = (booth.cf * CFrame.new(0, 0, -3.2)).Position
		lift = nil -- a DJ stays at the booth
	end
	local start = lift and (lift.cf.Position + Vector3.new(0, 0.4, 0)) or home
	local upDur = liftDur(lift)
	local liftUp0 = segments[1].t1 - upDur -- the lift rises at the end of the intro
	-- one walk per song: to the spot that belongs to that song
	-- props the artist plays (set in the designer): piano / drums / DJ booth at a spot number
	local playProps = {}
	for _, r in ipairs(items) do
		local n = r.rec and r.rec.play
		if n and (r.kind == "piano" or r.kind == "drums" or r.kind == "djbooth" or r.kind == "keys" or r.kind == "acoustic" or r.kind == "harp" or r.kind == "micstand") then
			local seat, move, yaw
			if r.kind == "piano" then
				seat, move, yaw = (r.cf * CFrame.new(0, 0, 5.2)).Position, "piano", math.rad(r.rec.r or 0) + math.pi
			elseif r.kind == "keys" then
				seat, move, yaw = (r.cf * CFrame.new(0, 0, -2.4)).Position, "keys", math.rad(r.rec.r or 0)
			elseif r.kind == "acoustic" then
				seat, move, yaw = (r.cf * CFrame.new(0, 1.15, 0)).Position, "strum", math.rad(r.rec.r or 0)
			elseif r.kind == "harp" then
				seat, move, yaw = (r.cf * CFrame.new(0, 0, -2.2)).Position, "harp", math.rad(r.rec.r or 0)
			elseif r.kind == "drums" then
				seat, move, yaw = (r.cf * CFrame.new(0, 1, -1.8)).Position, "drumsolo", math.rad(r.rec.r or 0)
			elseif r.kind == "micstand" then
				seat, move, yaw = (r.cf * CFrame.new(0, 0, -2.3)).Position, "standmic", math.rad(r.rec.r or 0)
			else
				seat, move, yaw = (r.cf * CFrame.new(0, 0, -3.2)).Position, "dance", math.rad(r.rec.r or 0)
			end
			playProps[n] = { pos = seat, move = move, yaw = yaw, item = r }
		end
	end
	------------------------------------------------------------ path finding on the stage (Client/StageNav.lua)
	local nav = StageNav.new()
	local findPath = nav.findPath
	local NAV, navC, navD = nav.NAV, nav.navC, nav.navD
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
	-- a lift set to the last song is the exit: the artist walks onto it for the finale, waves at the end
	-- and is lowered down out of sight
	local finaleLift = nil
	local hiddenStand = nil -- acoustic set whose guitar is in the artist's hands
	local outroSeg = segments[#segments]
	local exitT0 = outroSeg.t0 + 2.4
	local EXIT_DUR = 2.4
	for _, seg in ipairs(segments) do
		if seg.song then
			-- the place that belongs to this song (a song without a place: the artist stays where they are)
			local spotIdx = seg.song
			local w = { seg.t0, nil, spot = spotIdx, t1 = seg.t1 }
			local play = playProps[spotIdx]
			local lf = liftAt[spotIdx]
			if play then
				w[2], w.play = play.pos, play
			elseif lf then
				w[2] = liftTop(lf)
			else
				w[2] = spotPos(spotIdx) or cur
			end
			if lf and lf.kind == "towerlift" then
				w.tower = lf
			end
			local isFinale = lf and not play and spotIdx == songCount and songCount > 1 and lf ~= lift and (lf.kind == "lift" or lf.kind == "poplift") and outroSeg.kind == "outro"
			if isFinale then
				finaleLift = lf
			end
			if lf and not play and lf ~= lift and lf.kind ~= "towerlift" and not isFinale then
				w.kind, w.lift, w.dur = "lift", lf, liftDur(lf) -- disappear, come up on this lift
			elseif (w[2] - cur).Magnitude < 1 then
				w.kind, w.dur = "stay", 0
			else
				local path = (leadRole ~= "dj") and findPath(cur, w[2]) or nil
				if not path then
					-- no connected decks: walk straight over (never vanish in front of the fans)
					path = { cur }
					local steps = math.max(1, math.floor((w[2] - cur).Magnitude / 3))
					for k = 1, steps - 1 do
						local p = cur:Lerp(w[2], k / steps)
						table.insert(path, Vector3.new(p.X, math.max(p.Y, (Stage3D.surfaceY(p.X, p.Z))), p.Z))
					end
					table.insert(path, w[2])
				end
				w.kind, w.path = "walk", path
				w.len = pathLength(path)
				w.dur = math.clamp(w.len / 9, 1, 9)
			end
			table.insert(walks, w)
			cur = w[2]
			-- moments inside this song (spots "2.25", "2.5", "2.75"): the artist walks on during the song
			local prevEnd = w[1] + (w.dur or 0)
			for _, m in ipairs((plan.moments or {})[spotIdx] or {}) do
				local spotRef = nil
				for _, r in ipairs(spots) do
					if r.rec == m.rec then
						spotRef = r
					end
				end
				if spotRef and not play then
					local to = spotRef.cf.Position
					local mt = math.max(seg.t0 + (seg.t1 - seg.t0) * m.frac, prevEnd + 0.5)
					local mw = { mt, to, spot = spotIdx, t1 = seg.t1, moment = m.frac }
					if (to - cur).Magnitude < 1 then
						mw.kind, mw.dur = "stay", 0
					else
						local path = findPath(cur, to) or { cur, to }
						mw.kind, mw.path = "walk", path
						mw.len = pathLength(path)
						mw.dur = math.clamp(mw.len / 9, 1, 9)
					end
					if mt + mw.dur < seg.t1 then
						table.insert(walks, mw)
						cur = to
						prevEnd = mt + mw.dur
					end
				end
			end
		end
	end
	local curWalk = nil
	LiveShow.lastWalks = walks -- for the automated tests
	LiveShow.lastExitLift = finaleLift

	local lead = People.new(Stage3D.peopleFolder, artistColor, 1.5, leadRole, 7, ad.look)
	local band = {}
	-- the live band from the stage builder's Band tab: every musician plays the whole show at their place
	local BAND_ITEMS = {
		band_drums = { "drums", Vector3.new(0, 1, -1.8), "drumsolo" },
		band_guitar = { "guitar", Vector3.new(0, 0, 0) },
		band_bass = { "bass", Vector3.new(0, 0, 0) },
		band_keys = { "dancer", Vector3.new(0, 0, -2.4), "keys" },
		band_backing = { "lead", Vector3.new(0, 0.4, 0), "dance" },
	}
	local hasBand = false
	for _, r in ipairs(items) do
		local b = BAND_ITEMS[r.kind]
		if b then
			hasBand = true
			local n = #band + 1
			local fig = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, b[1], 40 + n, People.bandLook(ad, 20 + n, Artists.BAND_STYLE))
			table.insert(band, { p = fig, pos = (r.cf * CFrame.new(b[2])).Position, yaw = math.rad((r.rec and r.rec.r) or 0), move = b[3] })
		end
	end
	if ad.members >= 4 and ad.genre ~= "K-Pop" and not hasBand then
		local drumPos = drums and (drums.cf * CFrame.new(0, 1, -1.6)).Position or onSurface(home + Vector3.new(0, 0, -10))
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "guitar", 11, People.bandLook(ad, 1, Artists.BAND_STYLE)), pos = onSurface(home + Vector3.new(-14, 0, -4)) })
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "bass", 12, People.bandLook(ad, 2, Artists.BAND_STYLE)), pos = onSurface(home + Vector3.new(14, 0, -4)) })
		table.insert(band, { p = People.new(Stage3D.peopleFolder, Color3.fromRGB(30, 30, 36), 1.4, "drums", 13, People.bandLook(ad, 3, Artists.BAND_STYLE)), pos = drumPos })
	end
	-- a group (K-Pop and other groups without a band): the other members dance on their own. They walk to
	-- their places on the decks (path finding, never off the stage), change formations during the songs,
	-- have their own moves and come together for moves in sync and little moments with each other
	local crew = {}
	if ad.members >= 2 and not hasBand and not (ad.members >= 4 and ad.genre ~= "K-Pop") then
		crew = LiveShow.planCrew(ad, artistColor, segments, walks, {
			findPath = findPath,
			onSurface = onSurface,
			walkable = nav.walkable,
			nav = NAV,
			start = home,
		})
	end
	LiveShow.lastCrew = crew -- for the automated tests
	-- instruments the crew sets up for their song (and takes away after it): rec.setup = "crew"
	local setupJobs = LiveShow.planSetups(items, segments, navC, navD, onSurface)
	LiveShow.lastSetups = setupJobs
	LiveShow.lastBand = #band -- for the automated tests
	local performers = { lead }
	for _, b in ipairs(band) do
		table.insert(performers, b.p)
	end
	for _, c in ipairs(crew) do
		table.insert(performers, c.p)
	end

	local function idleYaw(t)
		if centerStage then
			return t * 0.35 -- turn around to face every side of the arena
		end
		return math.sin(t * 0.5) * 0.4
	end
	-- height of the artist below/above the deck while a lift brings them up (t0 = start of the rise)
	function riseY(r, t0, t)
		local d = liftDur(r)
		local u = math.clamp((t - t0) / d, 0, 1)
		if r and r.kind == "poplift" then
			-- shot up: through the hatch in 40 % of the time, then a jump and landing
			if u < 0.4 then
				return -LIFT_DEPTH + (LIFT_DEPTH + 7) * (u / 0.4)
			end
			local v = (u - 0.4) / 0.6
			return 7 * (1 - v * v)
		end
		return (smooth(t0, t0 + d, t) - 1) * LIFT_DEPTH
	end
	-- returns position, yaw, walking, hidden
	local function leadState(t)
		LiveShow.popping = false
		if leadRole == "dj" then
			return home, centerStage and idleYaw(t) or 0, false, false
		end
		if lift and t < liftUp0 + upDur then
			LiveShow.popping = lift.kind == "poplift" and t >= liftUp0
			return start + Vector3.new(0, riseY(lift, liftUp0, t), 0), 0, false, t < liftUp0
		end
		if finaleLift and t >= exitT0 then
			-- going down with the exit lift
			local f = smooth(exitT0, exitT0 + EXIT_DUR, t)
			curWalk = nil
			return liftTop(finaleLift) - Vector3.new(0, f * LIFT_DEPTH, 0), centerStage and idleYaw(t) or 0, false, f >= 0.97
		end
		LiveShow.popping = false
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
					LiveShow.popping = w.lift.kind == "poplift"
					return to + Vector3.new(0, riseY(w.lift, w[1], t), 0), 0, false, false
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
		local d = liftDur(r)
		if r == finaleLift and t >= exitT0 - 0.1 then
			return 1 - smooth(exitT0, exitT0 + EXIT_DUR, t)
		end
		local up = (r.kind == "poplift") and 0.4 or 1 -- a pop-up lift is up after 40 % (then the artist flies)
		if r == lift and t < liftUp0 + d then
			return math.clamp((t - liftUp0) / (d * up), 0, 1)
		end
		for _, w in ipairs(walks) do
			if w.lift == r and t >= w[1] - 1 and t < w[1] + d then
				if r.kind == "poplift" then
					return math.clamp((t - w[1]) / (d * up), 0, 1)
				end
				return smooth(w[1], w[1] + d, t)
			end
		end
		return 1
	end
	-- tower lift height (0..1) during the song it belongs to
	local function towerValue(r, t)
		for _, w in ipairs(walks) do
			if w.tower == r and t >= w[1] and t < (w.t1 or w[1]) then
				local up0 = w[1] + (w.dur or 0) + 1
				return smooth(up0, up0 + 5, t) * (1 - smooth(w.t1 - 5, w.t1 - 1, t))
			end
		end
		return 0
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

	-- opts.walk: the player is in the venue with their character and can walk around (camera "Walk"),
	-- or switch to the show cameras like before
	local walkMode = opts.walk == true and app.world ~= nil
	local camMode = walkMode and 0 or 1
	local camButtons = {}
	local bar = UI.Panel(overlay, UI.px(1920 / 2 - 505, 1012), UI.px(1010, 52), T.panel)
	bar.BackgroundTransparency = 0.35
	UI.List(false, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent = bar
	if walkMode then
		camButtons[0] = UI.Button(bar, "Walk [V]", nil, UI.px(100, 38), { order = 0, textSize = 14 }, function()
			camMode = 0
		end)
		UI.Label(overlay, "WASD = walk around the venue   |   V = walk   |   0 - 5 = show cameras", UI.px(0, 976), UI.px(1920, 30), { textSize = 17, font = UI.FontBold, alignX = Enum.TextXAlignment.Center }).TextStrokeTransparency = 0.5
	end
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
		elseif input.KeyCode == Enum.KeyCode.V and walkMode then
			camMode = 0
		end
	end)

	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 60
	local size = crowd.size
	-- the player stands at the back of the floor, looking at the stage
	local W = app.world
	if walkMode then
		Venue.makeWalkable(crowd, { Stage3D.designFolder })
		local _, char = W.humanoid()
		if char and char.PrimaryPart then
			local spawnZ = size.center and (size.floorEnd - 6) or math.max(deckCenter.Z + 30, size.floorEnd - 8)
			char:PivotTo(CFrame.lookAt(Vector3.new(0, 4, spawnZ), Vector3.new(0, 4, deckCenter.Z)))
		end
		W.freeze(false)
		W.setZoom(40)
		W.resetCamera()
	end
	local taskCtx = { app = app, venue = venue, look = look, crowd = crowd, items = items, overlay = overlay, character = walkMode and select(2, W.humanoid()) or nil, t = 0, timeScale = 1 }
	ShowTasks.start(taskCtx)
	local camCF = nil
	local t = 0
	LiveShow.debugT = function()
		return t -- the show clock (for the automated tests)
	end
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
	local feed = LiveFeed.new({ performers = performers, color = artistColor })
	local leadNow, yawNow = home, 0
	ctx.liveFeed = function(face, mode)
		ctx.leadPos, ctx.leadYaw = leadNow, yawNow
		feed:update(face, mode, ctx)
	end

	-- sound: crowd noise from the start, the music follows the running order
	SoundFX.stopMusic(1.5)
	SoundFX.crowd(0.2 + 0.5 * math.clamp(fill, 0, 1))
	SoundFX.sfx("cheer", 0.3 + 0.5 * math.clamp(fill, 0, 1))
	local soundSeg = 1
	local SFX_HITS = { pyro = { "boom", 0.45 }, co2 = { "whoosh", 0.35 }, fireworks = { "firework", 0.6 }, confetti = { "whoosh", 0.25 } }

	local done = false
	local conn
	local function cleanup()
		SoundFX.crowd(0)
		SoundFX.menu("office")
		keyConn:Disconnect()
		for _, p in ipairs(performers) do
			p:destroy()
		end
		Venue.destroy(crowd)
		Stage3D.clearDesign()
		Stage3D.setLighting("designer")
		overlay:Destroy()
		if walkMode then
			W.setZoom()
			W.toSpawn()
		end
		if opts.onDone then
			opts.onDone()
		end
	end
	local function finish()
		if done then
			return
		end
		done = true
		conn:Disconnect()
		ShowTasks.stop(taskCtx)
		if opts.onFinish then
			-- the result screen comes while you are still in the venue; then back home
			if walkMode then
				W.freeze(true)
			end
			bar.Visible = false
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 40, (size.center and 0 or deckCenter.Z) + 120), deckCenter + Vector3.new(0, 10, 0))
			opts.onFinish(cleanup)
		else
			cleanup()
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
			local fx = SFX_HITS[hits[hitIndex][2]]
			if fx then
				SoundFX.sfx(fx[1], fx[2])
			end
			hitIndex = hitIndex + 1
		end
		-- music: every song starts its part of the artist's audio file
		if soundSeg ~= segIndex then
			soundSeg = segIndex
			if seg.songIndex then
				SoundFX.song(ad.id, seg.songIndex, 1)
				SoundFX.sfx("cheer", 0.25)
			elseif seg.kind == "break" then
				SoundFX.stopMusic(1)
				SoundFX.sfx("scream", 0.6)
			elseif seg.kind == "outro" then
				SoundFX.stopMusic(2)
				SoundFX.sfx("applause", 0.8)
			end
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
		if curWalk and curWalk.tower then
			leadPos = leadPos + Vector3.new(0, Builder.TOWER_HEIGHT * towerValue(curWalk.tower, t), 0)
		end
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
			-- every instrument has a few moves that change every few seconds
			local moves = PLAY_MOVES[curWalk.play.move] or { curWalk.play.move }
			move = moves[math.floor(inSeg / 4) % #moves + 1]
			leadYaw = curWalk.play.yaw
		end
		local armsUp = 0
		if LiveShow.popping then
			move = "pop"
		end
		lead:update(leadPos, leadYaw, { t = t, beat = beat, energy = energy, walking = walking, armsUp = armsUp, move = move })
		-- the guitar of the acoustic set leaves its stand while the artist plays it
		local standItem = curWalk and curWalk.play and curWalk.play.item
		local want = (standItem and standItem.kind == "acoustic" and move == "strum") and standItem or nil
		if want ~= hiddenStand then
			for _, it in ipairs({ hiddenStand or false, want or false }) do
				if it then
					for _, pp in ipairs(it.model:GetChildren()) do
						if pp:IsA("BasePart") and (pp.Name == "Body" or pp.Name == "SoundHole" or pp.Name == "Bridge" or pp.Name == "Neck" or pp.Name == "Headstock") then
							pp.Transparency = ((it == want) or crewHidden[pp]) and 1 or 0
						end
					end
				end
			end
			hiddenStand = want
		end
		LiveShow.updateSetups(setupJobs, t)
		local bandMove = (ad.genre == "K-Pop") and move or (((ad.genre == "Metal" or ad.genre == "Rock") and seg.kind == "banger") and "headbang" or "idle")
		for _, b in ipairs(band) do
			local pos = b.pos
			if b.follow then
				pos = onSurface(leadPos + b.follow)
			end
			local bm = b.move or ((bandMove == "micout") and "point" or bandMove)
			if b.move == "dance" and seg.bpm == 0 then
				bm = "idle"
			end
			b.p:update(pos, b.yaw or 0, { t = t + 0.3, beat = beat, energy = energy, walking = false, armsUp = armsUp, move = bm })
		end
		if #crew > 0 then
			LiveShow.updateCrew(crew, t, seg, inSeg, beat, energy, move, centerStage and idleYaw(t) or 0, ad.genre)
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
			if r.kind == "lift" or r.kind == "poplift" then
				r.liftT = liftValue(r, t)
			elseif r.kind == "towerlift" then
				r.towerT = towerValue(r, t)
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
		ctx.dt = dt
		ctx.fog = seg.fog == true
		ctx.phones = seg.phones == true
		ctx.curtainT = math.max(0, t - segments[1].t1)
		ctx.songStart = songStart
		leadNow, yawNow = leadPos, leadYaw
		-- effects set to fire in chosen songs (stage builder, step 2): they ignore the automatic hits and
		-- fire at the start, in the middle and near the end of their songs
		local mySong = seg.song and songFx[seg.song]
		local customHit = {}
		if mySong then
			local inPrev = inSeg - dt
			for _, at in ipairs({ 0.3, seg.len * 0.5, seg.len - 2 }) do
				if inPrev < at and inSeg >= at then
					customHit.now = true
				end
			end
		end
		for _, r in ipairs(items) do
			local songs = r.rec and r.rec.songs
			if type(songs) == "table" and #songs > 0 and FX_HIT[r.kind] then
				local saved, savedL, savedF = ctx.hit, ctx.lasers, ctx.fog
				local here = false
				for _, n in ipairs(songs) do
					if n == seg.song then
						here = true
					end
				end
				local h = {}
				if here and customHit.now then
					h[FX_HIT[r.kind]] = true
					if not r.soundAt or t - r.soundAt > 0.5 then
						r.soundAt = t
						local fx = SFX_HITS[FX_HIT[r.kind]]
						if fx then
							SoundFX.sfx(fx[1], fx[2])
						end
					end
				end
				ctx.hit = h
				ctx.lasers = here
				ctx.fog = here
				Builder.animate(r, ctx)
				ctx.hit, ctx.lasers, ctx.fog = saved, savedL, savedF
			else
				Builder.animate(r, ctx)
			end
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
		ctx.crowdEnergy = crowdEnergy * segMult
		ctx.crowdSpeed = speed
		Venue.animate(crowd, t, crowdEnergy * segMult, speed, seg.phones == true, seg.c1, seg.c2, beatCount)

		if songLbl.Text ~= seg.title then
			songLbl.Text = seg.title
		end
		setProg(t / showLength)

		taskCtx.t, taskCtx.seg, taskCtx.timeScale = t, seg, timeScale
		ShowTasks.update(dt, taskCtx)
		-- camera
		local mode = camMode
		if mode == 1 then
			mode = autoOrder[(math.floor(t / 7) % #autoOrder) + 1]
		end
		for i, b in pairs(camButtons) do
			b.BackgroundColor3 = (i == camMode) and T.accent or T.panel3
		end
		if mode == 0 then
			-- walking: the normal Roblox camera follows the character
			if cam.CameraType ~= Enum.CameraType.Custom then
				W.resetCamera()
				camCF = nil
			end
			return
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
