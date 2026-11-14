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
		setlist = { "Paper Satellites", "Moonrise Avenue", "Static in Your Hair", "Quiet Planets", "Velvet Static", "Lanterns", "Northern Window", "Glow" },
	},
	{
		id = "juno", name = "Juno Park", genre = "Pop", members = 1, signCost = 40000, level = 1, starter = true,
		color = { 255, 150, 200 }, skill = 70, hype = 50, pricePower = 1.0,
		fans = { EU = 70000, NA = 60000, LATAM = 10000, ASIA = 20000, OCE = 15000, MEA = 3000 },
		bio = "Bubblegum pop newcomer with one viral hit.",
		setlist = { "Sugar Rush Radio", "Polaroid Heart", "Bubblegum Sky", "Rainy Day Diary", "Neon Lemonade", "Heartbeat Hotline", "Glitter Weather", "Confetti Kiss" },
	},
	{
		id = "rusty", name = "The Rusty Wires", genre = "Rock", members = 4, signCost = 40000, level = 1, starter = true,
		color = { 230, 90, 60 }, skill = 68, hype = 40, pricePower = 1.0,
		fans = { EU = 220000, NA = 160000, LATAM = 30000, ASIA = 15000, OCE = 40000, MEA = 5000 },
		bio = "Garage rock four-piece. Loud, sweaty, fun.",
		setlist = { "Short Circuit", "Highway Teeth", "Copper Heart", "Last Call Lullaby", "Gasoline Choir", "Rust Belt Romance", "Amplifier Ghosts", "Blow the Fuse" },
	},
	{
		id = "voltage", name = "DJ Voltage", genre = "EDM", members = 1, signCost = 150000, level = 2,
		color = { 0, 230, 255 }, skill = 75, hype = 50, pricePower = 1.05,
		fans = { EU = 600000, NA = 350000, LATAM = 120000, ASIA = 90000, OCE = 80000, MEA = 60000 },
		bio = "Festival-ready producer with massive drops.",
		setlist = { "Overload", "1000 Volts", "Neon Rain", "Afterglow (Slow Mix)", "Surge Protector", "Static Bloom", "Circuit Breaker", "Kilowatt Kiss" },
	},
	{
		id = "kai", name = "Kai Rivers", genre = "Hip-Hop", members = 1, signCost = 250000, level = 2,
		color = { 255, 190, 40 }, skill = 78, hype = 60, pricePower = 1.1,
		fans = { EU = 500000, NA = 1200000, LATAM = 150000, ASIA = 80000, OCE = 120000, MEA = 90000 },
		bio = "Sharp lyricist on the rise, viral on every platform.",
		setlist = { "Riverside", "Gold Teeth Prayer", "No Cap Kingdom", "Mama's Porch", "Concrete Psalms", "Late Night Ledger", "Undertow", "Flood the City" },
	},
	{
		id = "neon", name = "Neon Harbor", genre = "Indie", members = 4, signCost = 350000, level = 2,
		color = { 100, 255, 200 }, skill = 76, hype = 55, pricePower = 1.0,
		fans = { EU = 900000, NA = 700000, LATAM = 100000, ASIA = 150000, OCE = 250000, MEA = 30000 },
		bio = "Indie-rock band with sing-along choruses.",
		setlist = { "Lighthouse", "Saltwater Radio", "Docklands", "Fog Horn Heart", "Tidewater", "Paper Boats", "Harbor Lights", "Sail Away Tonight" },
	},
	{
		id = "ironclad", name = "Ironclad", genre = "Metal", members = 4, signCost = 600000, level = 3,
		color = { 170, 170, 180 }, skill = 82, hype = 50, pricePower = 1.15,
		fans = { EU = 1600000, NA = 900000, LATAM = 700000, ASIA = 300000, OCE = 200000, MEA = 40000 },
		bio = "Thunderous metal veterans. Bring earplugs.",
		setlist = { "Forged in Fire", "Anvil Storm", "Steel Horizon", "Rust and Roses", "Molten Crown", "Warhammer Sky", "Black Furnace", "Iron Will" },
	},
	{
		id = "velvet", name = "Velvet June", genre = "R&B", members = 1, signCost = 1000000, level = 3,
		color = { 170, 90, 230 }, skill = 84, hype = 60, pricePower = 1.25,
		fans = { EU = 1500000, NA = 2000000, LATAM = 300000, ASIA = 400000, OCE = 300000, MEA = 250000 },
		bio = "Silky voice, sold-out late-night shows.",
		setlist = { "Velvet Hours", "Slow Burn", "Midnight Satin", "June Rain", "Silk Signals", "After Midnight", "Honey Moonlight", "Stay Till Sunrise" },
	},
	{
		id = "luna", name = "Luna Sol", genre = "Latin", members = 1, signCost = 1500000, level = 3,
		color = { 255, 120, 60 }, skill = 80, hype = 65, pricePower = 1.2,
		fans = { EU = 1200000, NA = 2500000, LATAM = 6000000, ASIA = 200000, OCE = 150000, MEA = 150000 },
		bio = "Reggaeton queen with stadium-sized hooks.",
		setlist = { "Fuego Lento", "Luna Llena", "Bailame Ya", "Corazon de Sal", "Noche Dorada", "Mar de Estrellas", "Ritmo Prohibido", "Sol de Medianoche" },
	},
	{
		id = "dusty", name = "Dusty Creek", genre = "Country", members = 1, signCost = 2500000, level = 4,
		color = { 220, 150, 80 }, skill = 79, hype = 55, pricePower = 1.3,
		fans = { EU = 400000, NA = 7000000, LATAM = 100000, ASIA = 50000, OCE = 900000, MEA = 50000 },
		bio = "Cowboy hat, big heart, bigger choruses.",
		setlist = { "Gravel Road Gospel", "Tailgate Summer", "Whiskey Sunset", "Mama's Pickup", "Dust Devil Dance", "Porch Light", "County Fair Kiss", "Long Way Home" },
	},
	{
		id = "starlyte", name = "STARLYTE", genre = "K-Pop", members = 5, signCost = 3500000, level = 4,
		color = { 190, 120, 255 }, skill = 85, hype = 75, pricePower = 1.5,
		fans = { EU = 2000000, NA = 3000000, LATAM = 2000000, ASIA = 8000000, OCE = 600000, MEA = 400000 },
		bio = "Five-member K-Pop group with flawless choreography.",
		setlist = { "Starlight Code", "Hyperdrive", "Butterfly Effect", "Galaxy Letter", "Prism", "Comet Chaser", "Orbit Kiss", "Supernova" },
	},
	{
		id = "nova", name = "Nova Ray", genre = "Pop", members = 1, signCost = 12000000, level = 5,
		color = { 255, 105, 180 }, skill = 92, hype = 80, pricePower = 1.6,
		fans = { EU = 14000000, NA = 22000000, LATAM = 8000000, ASIA = 7000000, OCE = 3000000, MEA = 1500000 },
		bio = "Global pop superstar. Every show is an event.",
		setlist = { "Supernova Heart", "Gravity", "Electric Daydream", "Paper Crown", "Afterlight", "Diamond Static", "Neon Halo", "Shine Forever" },
	},
}

Artists.byId = {}
for i, a in ipairs(Artists.list) do
	a.order = i
	Artists.byId[a.id] = a
end

return Artists
