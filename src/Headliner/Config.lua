-- HEADLINER :: global tuning values
local Config = {}

Config.GAME_TITLE = "HEADLINER"
Config.SUBTITLE = "Music Label Tour Manager"
Config.DEFAULT_LABEL_NAME = "Starlight Records"
Config.SAVE_VERSION = 3

Config.START_MONEY = 150000
Config.START_YEAR = 2027

-- Share of an artist's fans in a country that buy a ticket during one tour
Config.ATTEND_RATE = 0.08
-- Days between announcing a tour and its first show (ticket pre-sale window)
Config.MIN_LEAD_DAYS = 14
Config.MAX_LEAD_DAYS = 120
Config.MAX_GAP_DAYS = 7
Config.MAX_SHOWS_PER_TOUR = 60
-- Part of the ticket gross that goes to the artist
Config.ARTIST_SHARE = 0.35

-- Time runs by itself: seconds per in-game day for each speed (II = paused)
Config.SPEEDS = {
	{ label = "II", seconds = 0 },
	{ label = "1x", seconds = 30 },
	{ label = "2x", seconds = 12 },
	{ label = "4x", seconds = 4 },
}

-- Sandbox (developer test mode): money never runs out, every level, artist, venue and station is open
Config.SANDBOX_MONEY = 1000000000

-- Label level needed to book a venue type (level 1 = clubs)
Config.VENUE_LEVEL = { Club = 1, Theatre = 2, Hall = 2, Arena = 3, Amphitheatre = 3, Stadium = 4 }

-- Label levels: unlocked by total tickets sold. Bigger artists need a higher level.
Config.LEVELS = {
	{ name = "Garage Label", tickets = 0 },
	{ name = "Indie Label", tickets = 3000 },
	{ name = "Rising Label", tickets = 25000 },
	{ name = "Major Label", tickets = 200000 },
	{ name = "Global Powerhouse", tickets = 1000000 },
}

-- Stage equipment is bought once (price = catalog cost * ITEM_PRICE_MULT).
-- Every show then costs PRODUCTION_RATE of the equipment value (crew, trucks, power).
-- Removing equipment sells it back for RESALE of its price.
Config.ITEM_PRICE_MULT = 3
Config.PRODUCTION_RATE = 0.08
Config.RESALE = 0.7

-- Promoter estimates are uncertain: real demand per show varies by this much (hidden from the player)
Config.DEMAND_NOISE = 0.25

Config.MAX_DESIGN_ITEMS = 260
Config.MAX_DESIGNS = 8

-- Stage size classes. A design can only be used in venues of its class or bigger.
-- end stage: build area x minX..maxX, z minZ..maxZ (audience towards +z)
-- center stage: square build area -center..center (audience all around)
Config.STAGE_CLASSES = {
	{ id = "Club", order = 1, minX = -24, maxX = 24, minZ = -22, maxZ = 14, center = 22, rigY = 27, maxItems = 40, desc = "Clubs (up to ~600 fans)" },
	{ id = "Theatre", order = 2, minX = -36, maxX = 36, minZ = -28, maxZ = 34, center = 34, rigY = 28, maxItems = 80, desc = "Theatres & halls (up to ~8,000)" },
	{ id = "Arena", order = 3, minX = -60, maxX = 60, minZ = -34, maxZ = 100, center = 62, rigY = 38, maxItems = 170, desc = "Arenas & amphitheatres" },
	{ id = "Stadium", order = 4, minX = -120, maxX = 120, minZ = -70, maxZ = 200, center = 120, rigY = 75, maxItems = 340, desc = "Stadiums only" },
}
Config.STAGE_CLASS_BY_ID = {}
for _, c in ipairs(Config.STAGE_CLASSES) do
	Config.STAGE_CLASS_BY_ID[c.id] = c
end

-- 3D stage layout (studs). The audience is towards +Z.
Config.STAGE = {
	deckWidth = 64,
	deckDepth = 32,
	deckHeight = 6,
	deckCenterZ = -8, -- deck spans z = -24 .. 8
	front = 8,
	back = -24,
	rigY = 38, -- hanging height for rig items
	trussY = 40,
	minX = -60,
	maxX = 60,
	minZ = -26,
	maxZ = 100,
}

-- Marketing campaigns per tour: cost = base + perSeat * total tour capacity
Config.MARKETING = {
	{ id = "social", name = "Social Ads", base = 5000, perSeat = 0.25, boost = 0.10 },
	{ id = "billboards", name = "Billboards", base = 20000, perSeat = 0.75, boost = 0.18 },
	{ id = "tv", name = "TV Spots", base = 75000, perSeat = 2.0, boost = 0.30 },
}

return Config
