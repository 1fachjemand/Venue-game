-- Stage design catalog.
-- cost  = production cost per show (crew, transport, power)
-- pts   = production value points (more points = more impressive show)
-- tags  = used for genre bonuses
-- mount = "floor" (stands on the stage deck / ground) or "rig" (hangs from the lighting rig)
-- deck  = true if performers can walk on it (other items can be placed on top)

local StageItems = {}

StageItems.CATEGORIES = {
	{ id = "Stage", name = "Stage" },
	{ id = "Lights", name = "Lights" },
	{ id = "Screens", name = "Screens" },
	{ id = "Lifts", name = "Lifts" },
	{ id = "FX", name = "Special FX" },
	{ id = "Props", name = "Props" },
}

StageItems.list = {
	-- Stage structure. "size" = resizable (w = width along x, d = depth along z); decks have selectable heights.
	{ id = "deck", name = "Stage Deck", cat = "Stage", cost = 600, pts = 3, tags = {}, mount = "floor", deck = true, shape = "rect", size = { w = 16, d = 12, minW = 4, maxW = 90, minD = 4, maxD = 90 }, h = 6, heights = { 1, 2, 4, 6, 8, 10, 14 }, desc = "Rectangular platform. Resize, rotate and stack it to build any stage shape." },
	{ id = "deck_tri", name = "Triangle Deck", cat = "Stage", cost = 500, pts = 3, tags = { "intimate" }, mount = "floor", deck = true, shape = "tri", size = { w = 16, d = 16, minW = 4, maxW = 80, minD = 4, maxD = 80 }, h = 6, heights = { 1, 2, 4, 6, 8, 10, 14 }, desc = "Triangle platform (tip points forward). Great for triangle catwalks." },
	{ id = "deck_corner", name = "Corner Deck", cat = "Stage", cost = 400, pts = 2, tags = {}, mount = "floor", deck = true, shape = "corner", size = { w = 12, d = 12, minW = 4, maxW = 60, minD = 4, maxD = 60 }, h = 6, heights = { 1, 2, 4, 6, 8, 10, 14 }, desc = "Right-angled triangle. Use it for diagonal corners and angled runways." },
	{ id = "deck_round", name = "Round Deck", cat = "Stage", cost = 700, pts = 4, tags = { "spectacle" }, mount = "floor", deck = true, shape = "round", size = { w = 16, minW = 6, maxW = 70 }, h = 6, heights = { 1, 2, 4, 6, 8, 10, 14 }, desc = "Round platform: a B-stage or the heart of a center stage." },
	{ id = "stairs", name = "Stairs", cat = "Stage", cost = 300, pts = 0, tags = {}, mount = "floor", deck = true, shape = "stairs", size = { w = 6, d = 8, minW = 3, maxW = 30, minD = 3, maxD = 30 }, h = 6, heights = { 2, 4, 6, 8, 10, 14 }, desc = "Steps up to a higher deck. The low end points to the front (rotate with R)." },
	{ id = "spot", name = "Artist Spot", cat = "Stage", cost = 0, pts = 0, tags = {}, mount = "floor", deck = false, desc = "Where the artist performs. Spot 1 = opening, 2 = second song, 3 = ballad, 4 = finale. The artist walks between them." },
	{ id = "pit", name = "Pit Barrier", cat = "Stage", cost = 800, pts = 2, tags = { "intimate" }, mount = "floor", deck = false, size = { w = 20, d = 12, minW = 6, maxW = 80, minD = 6, maxD = 80 }, desc = "Fenced VIP pit on the floor. Fans fill the pit first." },
	{ id = "truss_beam", name = "Truss Beam", cat = "Stage", cost = 300, pts = 1, tags = {}, mount = "rig", deck = false, size = { w = 24, minW = 8, maxW = 140 }, desc = "Horizontal truss in the rig. Hang lights along it." },
	{ id = "truss", name = "Truss Tower", cat = "Stage", cost = 400, pts = 1, tags = {}, mount = "floor", deck = false, desc = "Vertical truss tower." },
	-- Lights
	{ id = "par", name = "PAR Wash", cat = "Lights", cost = 150, pts = 2, tags = { "lights" }, mount = "rig", deck = false, desc = "Coloured wash light." },
	{ id = "moving", name = "Moving Head", cat = "Lights", cost = 900, pts = 4, tags = { "lights" }, mount = "rig", deck = false, desc = "Sweeping beam light." },
	{ id = "beambar", name = "Beam Light", cat = "Lights", cost = 800, pts = 4, tags = { "lights" }, mount = "floor", deck = false, desc = "Floor beam shooting up into the sky." },
	{ id = "strobe", name = "Strobe", cat = "Lights", cost = 450, pts = 3, tags = { "lights", "energy" }, mount = "rig", deck = false, desc = "Flashes on the beat." },
	{ id = "blinder", name = "Audience Blinder", cat = "Lights", cost = 500, pts = 3, tags = { "lights", "energy" }, mount = "rig", deck = false, desc = "Warm flash towards the crowd on big moments." },
	{ id = "followspot", name = "Follow Spot", cat = "Lights", cost = 1100, pts = 3, tags = { "lights", "intimate" }, mount = "floor", deck = false, desc = "Follows the artist everywhere." },
	{ id = "discoball", name = "Disco Ball", cat = "Lights", cost = 700, pts = 3, tags = { "retro" }, mount = "rig", deck = false, desc = "Spinning mirror ball." },
	-- Screens
	{ id = "led", name = "LED Wall", cat = "Screens", cost = 3000, pts = 8, tags = { "screens", "spectacle" }, mount = "floor", deck = false, size = { w = 16, d = 9, minW = 4, maxW = 96, minD = 3, maxD = 40, dLabel = "Height" }, desc = "Video wall. Width and height are adjustable." },
	{ id = "led_side", name = "Side Screen", cat = "Screens", cost = 3500, pts = 8, tags = { "screens" }, mount = "floor", deck = false, desc = "Tall side screen showing the artist." },
	{ id = "led_floor", name = "LED Floor", cat = "Screens", cost = 4500, pts = 9, tags = { "screens" }, mount = "floor", deck = false, size = { w = 16, d = 16, minW = 4, maxW = 64, minD = 4, maxD = 64 }, desc = "Animated light-up floor. Put it on top of a deck." },
	{ id = "neonsign", name = "Neon Logo", cat = "Screens", cost = 1800, pts = 5, tags = { "retro" }, mount = "floor", deck = false, desc = "The artist's name in neon." },
	-- Lifts
	{ id = "lift", name = "Artist Lift", cat = "Lifts", cost = 6000, pts = 12, tags = { "spectacle" }, mount = "floor", deck = false, desc = "The artist rises out of the stage for the big entrance. Place it on the stage." },
	{ id = "scissor", name = "Scissor Lift", cat = "Lifts", cost = 7500, pts = 12, tags = { "spectacle" }, mount = "floor", deck = false, desc = "Platform that rises high during the finale." },
	-- Special effects
	{ id = "pyro", name = "Flame Pyro", cat = "FX", cost = 2000, pts = 8, tags = { "pyro", "energy" }, mount = "floor", deck = false, desc = "Huge flame bursts." },
	{ id = "sparks", name = "Spark Fountain", cat = "FX", cost = 1400, pts = 6, tags = { "pyro" }, mount = "floor", deck = false, desc = "Golden spark fountain." },
	{ id = "confetti", name = "Confetti Cannon", cat = "FX", cost = 1100, pts = 5, tags = { "party" }, mount = "floor", deck = false, desc = "Confetti for the finale." },
	{ id = "co2", name = "CO2 Jet", cat = "FX", cost = 1200, pts = 5, tags = { "energy" }, mount = "floor", deck = false, desc = "Freezing white jets on the drop." },
	{ id = "laser", name = "Laser Array", cat = "FX", cost = 2500, pts = 9, tags = { "lasers" }, mount = "rig", deck = false, desc = "Fan of sweeping lasers." },
	{ id = "haze", name = "Haze Machine", cat = "FX", cost = 300, pts = 3, tags = { "atmosphere" }, mount = "floor", deck = false, desc = "Stage haze for atmosphere." },
	{ id = "fireworks", name = "Fireworks Rack", cat = "FX", cost = 7000, pts = 14, tags = { "pyro", "spectacle" }, mount = "floor", deck = false, desc = "Fireworks for the grand finale." },
	-- Props
	{ id = "speakers", name = "Speaker Stack", cat = "Props", cost = 400, pts = 2, tags = {}, mount = "floor", deck = false, desc = "Big PA speakers." },
	{ id = "drums", name = "Drum Kit", cat = "Props", cost = 900, pts = 3, tags = { "band" }, mount = "floor", deck = false, desc = "Drum riser with kit." },
	{ id = "piano", name = "Grand Piano", cat = "Props", cost = 1500, pts = 4, tags = { "intimate" }, mount = "floor", deck = false, desc = "Black grand piano." },
	{ id = "djbooth", name = "DJ Booth", cat = "Props", cost = 1500, pts = 4, tags = { "dj" }, mount = "floor", deck = false, desc = "DJ table with neon front." },
	{ id = "inflatable", name = "Giant Inflatable", cat = "Props", cost = 5000, pts = 10, tags = { "spectacle", "party" }, mount = "floor", deck = false, desc = "Giant inflatable that blows up during the show." },
	{ id = "palm", name = "Neon Palm", cat = "Props", cost = 800, pts = 3, tags = { "party", "retro" }, mount = "floor", deck = false, desc = "Glowing palm tree." },
}

-- Genre bonus per tag (multiplies the item's points)
StageItems.GENRE_TAGS = {
	Pop = { spectacle = 1.3, screens = 1.2, party = 1.2, lights = 1.1 },
	Rock = { pyro = 1.25, lights = 1.2, band = 1.2 },
	["Hip-Hop"] = { pyro = 1.3, screens = 1.2, energy = 1.2 },
	EDM = { lasers = 1.4, energy = 1.3, lights = 1.2, dj = 1.4 },
	Metal = { pyro = 1.5, energy = 1.2, band = 1.2, party = 0.7 },
	Indie = { intimate = 1.4, retro = 1.2, pyro = 0.8, spectacle = 0.8 },
	["K-Pop"] = { spectacle = 1.3, screens = 1.3, lights = 1.2, party = 1.1 },
	Country = { retro = 1.2, band = 1.2, pyro = 1.1 },
	Latin = { party = 1.3, energy = 1.2, pyro = 1.1 },
	["R&B"] = { intimate = 1.25, lights = 1.2, atmosphere = 1.2 },
}

-- Ready-made designs every new game starts with. Coordinates in studs (stage deck: x -32..32, z -24..8).
-- Ready-made designs every new game starts with (free). Coordinates in studs, audience towards +z.
local function ring(t, n, r, y)
	local out = {}
	for i = 0, n - 1 do
		local a = i * 2 * math.pi / n
		table.insert(out, { t = t, x = math.floor(math.sin(a) * r + 0.5), z = math.floor(math.cos(a) * r + 0.5), r = math.floor(math.deg(a) + 0.5) })
	end
	return out
end
local function join(...)
	local out = {}
	for _, list in ipairs({ ... }) do
		for _, x in ipairs(list) do
			table.insert(out, x)
		end
	end
	return out
end
StageItems.PRESETS = {
	{
		name = "Club Stage", class = "Club", layout = "end",
		items = {
			{ t = "deck", x = 0, z = -12, r = 0, w = 32, d = 16, h = 4 },
			{ t = "spot", x = 0, z = -8, r = 0 },
			{ t = "speakers", x = -19, z = -6, r = 0 },
			{ t = "speakers", x = 19, z = -6, r = 0 },
			{ t = "truss_beam", x = 0, z = -8, r = 0, w = 34 },
			{ t = "par", x = -12, z = -8, r = 0 },
			{ t = "par", x = -4, z = -8, r = 0 },
			{ t = "par", x = 4, z = -8, r = 0 },
			{ t = "par", x = 12, z = -8, r = 0 },
			{ t = "haze", x = 0, z = -18, r = 0 },
		},
	},
	{
		name = "Arena End Stage", class = "Arena", layout = "end",
		items = {
			{ t = "deck", x = 0, z = -8, r = 0, w = 64, d = 32, h = 6 },
			{ t = "deck", x = 0, z = 22, r = 0, w = 8, d = 28, h = 6 },
			{ t = "deck_round", x = 0, z = 42, r = 0, w = 18, h = 6 },
			{ t = "spot", x = 0, z = -4, r = 0 },
			{ t = "spot", x = 0, z = 42, r = 0 },
			{ t = "spot", x = 0, z = 42, r = 0 },
			{ t = "spot", x = 0, z = -2, r = 0 },
			{ t = "lift", x = 0, z = -4, r = 0 },
			{ t = "led", x = 0, z = -21, r = 0, w = 40, d = 18 },
			{ t = "speakers", x = -38, z = 4, r = 0 },
			{ t = "speakers", x = 38, z = 4, r = 0 },
			{ t = "truss_beam", x = 0, z = -10, r = 0, w = 70 },
			{ t = "truss_beam", x = 0, z = 4, r = 0, w = 70 },
			{ t = "moving", x = -25, z = -10, r = 0 },
			{ t = "moving", x = -15, z = -10, r = 0 },
			{ t = "moving", x = -5, z = -10, r = 0 },
			{ t = "moving", x = 5, z = -10, r = 0 },
			{ t = "moving", x = 15, z = -10, r = 0 },
			{ t = "moving", x = 25, z = -10, r = 0 },
			{ t = "par", x = -20, z = 4, r = 0 },
			{ t = "par", x = -7, z = 4, r = 0 },
			{ t = "par", x = 7, z = 4, r = 0 },
			{ t = "par", x = 20, z = 4, r = 0 },
			{ t = "pyro", x = -26, z = 5, r = 0 },
			{ t = "pyro", x = 26, z = 5, r = 0 },
			{ t = "co2", x = -14, z = 6, r = 0 },
			{ t = "co2", x = 14, z = 6, r = 0 },
			{ t = "confetti", x = -30, z = -20, r = 0 },
			{ t = "confetti", x = 30, z = -20, r = 0 },
		},
	},
	{
		name = "Center Stage", class = "Arena", layout = "center",
		items = join(
			{ { t = "deck_round", x = 0, z = 0, r = 0, w = 34, h = 6 } },
			{ { t = "spot", x = 0, z = 6, r = 0 }, { t = "spot", x = 0, z = -6, r = 0 }, { t = "spot", x = 0, z = 0, r = 0 }, { t = "spot", x = 0, z = 0, r = 0 } },
			{ { t = "lift", x = 0, z = 0, r = 0 }, { t = "led_floor", x = 0, z = 0, r = 0, w = 20, d = 20 } },
			ring("moving", 8, 24),
			ring("speakers", 4, 30),
			ring("sparks", 6, 15)
		),
	},
}

StageItems.byId = {}
for i, it in ipairs(StageItems.list) do
	it.order = i
	StageItems.byId[it.id] = it
end

return StageItems
