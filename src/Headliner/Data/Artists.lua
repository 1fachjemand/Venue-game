-- Fictional artists. fans = starting fan count per region.
-- skill (0-100) = live performance quality. pricePower = how much fans pay compared to an average act.
-- members: 1 = solo, 2+ = band/group. level = label level needed to sign. starter = can be picked for free at game start.

local Artists = {}

Artists.GENRES = { "Pop", "Rock", "Hip-Hop", "EDM", "Metal", "Indie", "K-Pop", "Country", "Latin", "R&B" }

Artists.GENRE_COLORS = {
	Pop = { 255, 105, 180 },
	Rock = { 230, 70, 60 },
	["Hip-Hop"] = { 255, 190, 40 },
	EDM = { 0, 230, 255 },
	Metal = { 160, 160, 170 },
	Indie = { 140, 220, 120 },
	["K-Pop"] = { 190, 120, 255 },
	Country = { 220, 150, 80 },
	Latin = { 255, 120, 60 },
	["R&B"] = { 150, 90, 230 },
}

Artists.list = {
	{
		id = "lila", name = "Lila Moon", genre = "Indie", members = 1, signCost = 40000, level = 1, starter = true,
		color = { 150, 200, 255 }, skill = 72, hype = 45, pricePower = 1.0,
		fans = { EU = 90000, NA = 40000, LATAM = 5000, ASIA = 8000, OCE = 10000, MEA = 2000 },
		bio = "Dreamy bedroom-pop songwriter with a cult following.",
		setlist = { "Paper Satellites", "Moonrise Avenue", "Static in Your Hair", "Quiet Planets", "Velvet Static", "Lanterns", "Northern Window", "Glow", "Satellite Hearts", "Cardigan Weather", "Small Hours", "Tide Pool", "Paper Boats", "Orbit of Two", "Window Seat", "Hush Comet", "Lavender Radio", "Late Bus Home", "Sleepwalk Signal", "Moth to the Moon" },
		look = { skin = 1, hair = "long", hairColor = { 236, 200, 140 }, top = { 150, 200, 255 }, pants = { 60, 70, 110 }, shoes = { 240, 240, 240 }, acc = "none", jacket = { 230, 230, 236 } },
	},
	{
		id = "juno", name = "Juno Park", genre = "Pop", members = 1, signCost = 40000, level = 1, starter = true,
		color = { 255, 150, 200 }, skill = 70, hype = 50, pricePower = 1.0,
		fans = { EU = 70000, NA = 60000, LATAM = 10000, ASIA = 20000, OCE = 15000, MEA = 3000 },
		bio = "Bubblegum pop newcomer with one viral hit.",
		setlist = { "Sugar Rush Radio", "Polaroid Heart", "Bubblegum Sky", "Rainy Day Diary", "Neon Lemonade", "Heartbeat Hotline", "Glitter Weather", "Confetti Kiss", "Pink Lemon Skies", "Mixtape Summer", "Sparkle Mode", "Stay Cute", "Candy Phone", "Rollerdisco Love", "Strawberry Static", "Best Day Ever", "Glow Stick Summer", "Bubble Letters", "Sweet Sixteen Speed", "Heart Emoji" },
		look = { skin = 2, hair = "pigtails", hairColor = { 255, 140, 200 }, top = { 255, 150, 200 }, pants = { 255, 255, 255 }, shoes = { 255, 120, 180 }, acc = "none" },
	},
	{
		id = "rusty", name = "The Rusty Wires", genre = "Rock", members = 4, signCost = 40000, level = 1, starter = true,
		color = { 230, 90, 60 }, skill = 68, hype = 40, pricePower = 1.0,
		fans = { EU = 220000, NA = 160000, LATAM = 30000, ASIA = 15000, OCE = 40000, MEA = 5000 },
		bio = "Garage rock four-piece. Loud, sweaty, fun.",
		setlist = { "Short Circuit", "Highway Teeth", "Copper Heart", "Last Call Lullaby", "Gasoline Choir", "Rust Belt Romance", "Amplifier Ghosts", "Blow the Fuse", "Tin Can Sunday", "Wired Wrong", "Smoke Alarm", "Rust Never Sleeps", "Gravel Road Gospel", "Broken Jukebox", "Engine Room", "Feedback Valentine", "Iron Horse", "Garage Door Anthem", "Spark Plug Kiss", "Loud Neighbours" },
		look = { skin = 1, hair = "short", hairColor = { 120, 60, 30 }, top = { 30, 30, 34 }, pants = { 50, 70, 120 }, shoes = { 20, 20, 20 }, acc = "bandana", jacket = { 120, 60, 40 } },
	},
	{
		id = "voltage", name = "DJ Voltage", genre = "EDM", members = 1, signCost = 150000, level = 2,
		color = { 0, 230, 255 }, skill = 75, hype = 50, pricePower = 1.05,
		fans = { EU = 600000, NA = 350000, LATAM = 120000, ASIA = 90000, OCE = 80000, MEA = 60000 },
		bio = "Festival-ready producer with massive drops.",
		setlist = { "Overload", "1000 Volts", "Neon Rain", "Afterglow (Slow Mix)", "Surge Protector", "Static Bloom", "Circuit Breaker", "Kilowatt Kiss", "Power Grid", "Ampere", "Voltage Drop", "Live Wire", "Overclock", "Bassline Thunder", "Laser Garden", "Midnight Voltage", "Drop Zone", "Circuit Breaker", "Strobe Heart", "Power Surge" },
		look = { skin = 3, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 20, 20, 24 }, pants = { 20, 20, 24 }, shoes = { 0, 230, 255 }, acc = "headphones" },
	},
	{
		id = "kai", name = "Kai Rivers", genre = "Hip-Hop", members = 1, signCost = 250000, level = 2,
		color = { 255, 190, 40 }, skill = 78, hype = 60, pricePower = 1.1,
		fans = { EU = 500000, NA = 1200000, LATAM = 150000, ASIA = 80000, OCE = 120000, MEA = 90000 },
		bio = "Sharp lyricist on the rise, viral on every platform.",
		setlist = { "Riverside", "Gold Teeth Prayer", "No Cap Kingdom", "Mama's Porch", "Concrete Psalms", "Late Night Ledger", "Undertow", "Flood the City", "Delta Blues 2.0", "Paper Planes", "Crown of Concrete", "Home Team", "River Flow", "Concrete Crown", "Late Night Ledger", "Block Party Prayer", "Gold Chain Thoughts", "Skyline Verses", "No Days Off", "Hometown Hero" },
		look = { skin = 4, hair = "afro", hairColor = { 25, 20, 18 }, top = { 255, 190, 40 }, pants = { 40, 40, 46 }, shoes = { 255, 255, 255 }, acc = "chain" },
	},
	{
		id = "neon", name = "Neon Harbor", genre = "Indie", members = 4, signCost = 350000, level = 2,
		color = { 100, 255, 200 }, skill = 76, hype = 55, pricePower = 1.0,
		fans = { EU = 900000, NA = 700000, LATAM = 100000, ASIA = 150000, OCE = 250000, MEA = 30000 },
		bio = "Indie-rock band with sing-along choruses.",
		setlist = { "Lighthouse", "Saltwater Radio", "Docklands", "Fog Horn Heart", "Tidewater", "Paper Boats", "Harbor Lights", "Sail Away Tonight", "Beacon", "Low Tide Disco", "Anchors", "Northern Lights", "Harbor Lights", "Sea Glass", "Lighthouse Static", "Foghorn Love", "Saltwater Radio", "Night Ferry", "Pier Pressure", "Low Tide Disco" },
		look = { skin = 1, hair = "messy", hairColor = { 60, 40, 30 }, top = { 100, 255, 200 }, pants = { 40, 40, 50 }, shoes = { 200, 200, 200 }, acc = "beanie" },
	},
	{
		id = "ironclad", name = "Ironclad", genre = "Metal", members = 4, signCost = 600000, level = 3,
		color = { 170, 170, 180 }, skill = 82, hype = 50, pricePower = 1.15,
		fans = { EU = 1600000, NA = 900000, LATAM = 700000, ASIA = 300000, OCE = 200000, MEA = 40000 },
		bio = "Thunderous metal veterans. Bring earplugs.",
		setlist = { "Forged in Fire", "Anvil Storm", "Steel Horizon", "Rust and Roses", "Molten Crown", "Warhammer Sky", "Black Furnace", "Iron Will", "Hammerfall Hymn", "Scrap Metal Saints", "Brimstone", "Last Forge Standing", "Anvil Storm", "Forged in Thunder", "Steel Cathedral", "Blackout Siege", "Hammerfall Night", "Molten Crown", "Rivet Heart", "War Drum Weather" },
		look = { skin = 2, hair = "long", hairColor = { 20, 20, 20 }, top = { 24, 24, 26 }, pants = { 24, 24, 26 }, shoes = { 10, 10, 10 }, acc = "sunglasses", jacket = { 50, 50, 54 } },
	},
	{
		id = "velvet", name = "Velvet June", genre = "R&B", members = 1, signCost = 1000000, level = 3,
		color = { 170, 90, 230 }, skill = 84, hype = 60, pricePower = 1.25,
		fans = { EU = 1500000, NA = 2000000, LATAM = 300000, ASIA = 400000, OCE = 300000, MEA = 250000 },
		bio = "Silky voice, sold-out late-night shows.",
		setlist = { "Velvet Hours", "Slow Burn", "Midnight Satin", "June Rain", "Silk Signals", "After Midnight", "Honey Moonlight", "Stay Till Sunrise", "Velour", "Candlelight Code", "Lavender Haze Hotel", "Pillow Talk Radio", "Silk Sheets", "Slow Burn Sunday", "Honey Voicemail", "After Hours", "Velvet Rope", "Candlelight Call", "Golden Hour Lover", "Midnight Satin" },
		look = { skin = 4, hair = "bun", hairColor = { 30, 20, 20 }, top = { 170, 90, 230 }, pants = { 40, 20, 60 }, shoes = { 230, 190, 90 }, acc = "earrings" },
	},
	{
		id = "luna", name = "Luna Sol", genre = "Latin", members = 1, signCost = 1500000, level = 3,
		color = { 255, 120, 60 }, skill = 80, hype = 65, pricePower = 1.2,
		fans = { EU = 1200000, NA = 2500000, LATAM = 6000000, ASIA = 200000, OCE = 150000, MEA = 150000 },
		bio = "Reggaeton queen with stadium-sized hooks.",
		setlist = { "Fuego Lento", "Luna Llena", "Bailame Ya", "Corazon de Sal", "Noche Dorada", "Mar de Estrellas", "Ritmo Prohibido", "Sol de Medianoche", "Caliente", "Perreo Lunar", "Fiesta en la Playa", "Te Quiero Mas", "Sol y Luna", "Calle del Sol", "Baila Conmigo", "Fuego Lento", "Verano Eterno", "Corazon de Oro", "Noche Tropical", "Ritmo del Mar" },
		look = { skin = 3, hair = "long", hairColor = { 40, 25, 20 }, top = { 255, 120, 60 }, pants = { 255, 210, 80 }, shoes = { 255, 255, 255 }, acc = "sunglasses" },
	},
	{
		id = "dusty", name = "Dusty Creek", genre = "Country", members = 1, signCost = 2500000, level = 4,
		color = { 220, 150, 80 }, skill = 79, hype = 55, pricePower = 1.3,
		fans = { EU = 400000, NA = 7000000, LATAM = 100000, ASIA = 50000, OCE = 900000, MEA = 50000 },
		bio = "Cowboy hat, big heart, bigger choruses.",
		setlist = { "Gravel Road Gospel", "Tailgate Summer", "Whiskey Sunset", "Mama's Pickup", "Dust Devil Dance", "Porch Light", "County Fair Kiss", "Long Way Home", "Boots on the Bar", "Barn Dance Saturday", "Heartland Radio", "Dirt Road Diamonds", "Back Porch Hymn", "Two-Lane Heart", "Whiskey River Sky", "Barn Dance Saturday", "Dust on My Boots", "Prairie Radio", "Tailgate Moon", "Hometown Lights" },
		look = { skin = 1, hair = "short", hairColor = { 140, 100, 60 }, top = { 220, 150, 80 }, pants = { 50, 70, 120 }, shoes = { 110, 70, 40 }, acc = "cowboy" },
	},
	{
		id = "starlyte", name = "STARLYTE", genre = "K-Pop", members = 5, signCost = 3500000, level = 4,
		color = { 190, 120, 255 }, skill = 85, hype = 75, pricePower = 1.5,
		fans = { EU = 2000000, NA = 3000000, LATAM = 2000000, ASIA = 8000000, OCE = 600000, MEA = 400000 },
		bio = "Five-member K-Pop group with flawless choreography.",
		setlist = { "Starlight Code", "Hyperdrive", "Butterfly Effect", "Galaxy Letter", "Prism", "Comet Chaser", "Orbit Kiss", "Supernova", "Lightspeed", "Dear Universe", "Neon Seoul", "Stardust Promise", "Starlight Code", "Zero Gravity", "Supernova Kiss", "Firefly Formation", "Neon Promise", "Comet Chase", "Galaxy Party", "Shine Again" },
		look = { skin = 2, hair = "messy", hairColor = { 190, 160, 255 }, top = { 240, 240, 250 }, pants = { 190, 120, 255 }, shoes = { 255, 255, 255 }, acc = "none", jacket = { 190, 120, 255 } },
	},
	{
		id = "nova", name = "Nova Ray", genre = "Pop", members = 1, signCost = 12000000, level = 5,
		color = { 255, 105, 180 }, skill = 92, hype = 80, pricePower = 1.6,
		fans = { EU = 14000000, NA = 22000000, LATAM = 8000000, ASIA = 7000000, OCE = 3000000, MEA = 1500000 },
		bio = "Global pop superstar. Every show is an event.",
		setlist = { "Supernova Heart", "Gravity", "Electric Daydream", "Paper Crown", "Afterlight", "Diamond Static", "Neon Halo", "Shine Forever", "Midnight Encore", "Glass Hearts", "Satellite Love", "Golden Hour Girl", "Supernova", "Gravity Dress", "Diamond Static", "Satellite Crown", "Encore Forever", "Mirrorball Heart", "Infinite Night", "Starstruck" },
		look = { skin = 2, hair = "pony", hairColor = { 250, 230, 200 }, top = { 255, 105, 180 }, pants = { 255, 255, 255 }, shoes = { 255, 255, 255 }, acc = "sparkle", jacket = { 255, 255, 255 } },
	},
}

-- Look of the band members / dancers per genre (the lead artist has an own look)
Artists.BAND_STYLE = {
	Rock = { hair = { "long", "short", "messy" }, tops = { { 30, 30, 34 }, { 120, 30, 30 }, { 60, 60, 66 } }, pants = { { 40, 50, 90 }, { 20, 20, 24 } }, acc = { "none", "bandana", "sunglasses" } },
	Metal = { hair = { "long", "long", "buzz" }, tops = { { 20, 20, 22 }, { 40, 40, 44 } }, pants = { { 20, 20, 22 } }, acc = { "none", "sunglasses" } },
	Indie = { hair = { "messy", "short", "long" }, tops = { { 200, 170, 120 }, { 90, 120, 90 }, { 230, 230, 230 } }, pants = { { 60, 60, 70 }, { 110, 90, 70 } }, acc = { "none", "beanie" } },
	["K-Pop"] = { hair = { "messy", "short", "pony" }, tops = { { 240, 240, 250 } }, pants = { { 30, 30, 36 } }, acc = { "none" }, matchArtist = true },
	default = { hair = { "short", "messy", "bun" }, tops = { { 30, 30, 36 }, { 230, 230, 236 } }, pants = { { 30, 30, 36 } }, acc = { "none" } },
}

Artists.byId = {}
for i, a in ipairs(Artists.list) do
	a.order = i
	Artists.byId[a.id] = a
end

return Artists
