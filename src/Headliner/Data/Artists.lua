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
		bio = "Dreamy bedroom-pop songwriter with a cult following.", pitch = "Lila is perfect for a first tour: small clubs in Europe, quiet songs, fans who sing every word.",
		setlist = { "Paper Satellites", "Moonrise Avenue", "Static in Your Hair", "Quiet Planets", "Velvet Static", "Lanterns", "Northern Window", "Glow", "Satellite Hearts", "Cardigan Weather", "Small Hours", "Tide Pool", "Paper Boats", "Orbit of Two", "Window Seat", "Hush Comet", "Lavender Radio", "Late Bus Home", "Sleepwalk Signal", "Moth to the Moon" },
		look = { skin = 1, hair = "long", hairColor = { 236, 200, 140 }, top = { 150, 200, 255 }, pants = { 60, 70, 110 }, shoes = { 240, 240, 240 }, acc = "none", jacket = { 230, 230, 236 } },
	},
	{
		id = "juno", name = "Juno Park", genre = "Pop", members = 1, signCost = 40000, level = 1, starter = true,
		color = { 255, 150, 200 }, skill = 70, hype = 50, pricePower = 1.0,
		fans = { EU = 70000, NA = 60000, LATAM = 10000, ASIA = 20000, OCE = 15000, MEA = 3000 },
		bio = "Bubblegum pop newcomer with one viral hit.", pitch = "Juno has one viral hit and loads of young fans. Pink lights and a catwalk make her happy.",
		setlist = { "Sugar Rush Radio", "Polaroid Heart", "Bubblegum Sky", "Rainy Day Diary", "Neon Lemonade", "Heartbeat Hotline", "Glitter Weather", "Confetti Kiss", "Pink Lemon Skies", "Mixtape Summer", "Sparkle Mode", "Stay Cute", "Candy Phone", "Rollerdisco Love", "Strawberry Static", "Best Day Ever", "Glow Stick Summer", "Bubble Letters", "Sweet Sixteen Speed", "Heart Emoji" },
		look = { skin = 2, hair = "pigtails", hairColor = { 255, 140, 200 }, top = { 255, 150, 200 }, pants = { 255, 255, 255 }, shoes = { 255, 120, 180 }, acc = "none" },
	},
	{
		id = "rusty", name = "The Rusty Wires", genre = "Rock", members = 4, signCost = 40000, level = 1, starter = true,
		color = { 230, 90, 60 }, skill = 68, hype = 40, pricePower = 1.0,
		fans = { EU = 220000, NA = 160000, LATAM = 30000, ASIA = 15000, OCE = 40000, MEA = 5000 },
		bio = "Garage rock four-piece. Loud, sweaty, fun.", pitch = "Four guys, loud guitars, cheap to start with. Clubs and pubs first, then the halls.",
		setlist = { "Short Circuit", "Highway Teeth", "Copper Heart", "Last Call Lullaby", "Gasoline Choir", "Rust Belt Romance", "Amplifier Ghosts", "Blow the Fuse", "Tin Can Sunday", "Wired Wrong", "Smoke Alarm", "Rust Never Sleeps", "Gravel Road Gospel", "Broken Jukebox", "Engine Room", "Feedback Valentine", "Iron Horse", "Garage Door Anthem", "Spark Plug Kiss", "Loud Neighbours" },
		look = { skin = 1, hair = "short", hairColor = { 120, 60, 30 }, top = { 30, 30, 34 }, pants = { 50, 70, 120 }, shoes = { 20, 20, 20 }, acc = "bandana", jacket = { 120, 60, 40 } },
	},
	{
		id = "voltage", name = "DJ Voltage", genre = "EDM", members = 1, signCost = 150000, level = 2,
		color = { 0, 230, 255 }, skill = 75, hype = 50, pricePower = 1.05,
		fans = { EU = 600000, NA = 350000, LATAM = 120000, ASIA = 90000, OCE = 80000, MEA = 60000 },
		bio = "Festival-ready producer with massive drops.", pitch = "DJ Voltage needs a DJ booth, lasers and strobes. Clubs and halls in Europe love him.",
		setlist = { "Overload", "1000 Volts", "Neon Rain", "Afterglow (Slow Mix)", "Surge Protector", "Static Bloom", "Circuit Breaker", "Kilowatt Kiss", "Power Grid", "Ampere", "Voltage Drop", "Live Wire", "Overclock", "Bassline Thunder", "Laser Garden", "Midnight Voltage", "Drop Zone", "Circuit Breaker", "Strobe Heart", "Power Surge" },
		look = { skin = 3, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 20, 20, 24 }, pants = { 20, 20, 24 }, shoes = { 0, 230, 255 }, acc = "headphones" },
	},
	{
		id = "kai", name = "Kai Rivers", genre = "Hip-Hop", members = 1, signCost = 250000, level = 2,
		color = { 255, 190, 40 }, skill = 78, hype = 60, pricePower = 1.1,
		fans = { EU = 500000, NA = 1200000, LATAM = 150000, ASIA = 80000, OCE = 120000, MEA = 90000 },
		bio = "Sharp lyricist on the rise, viral on every platform.", pitch = "Kai is big in North America and growing fast. A runway into the crowd works great for him.",
		setlist = { "Riverside", "Gold Teeth Prayer", "No Cap Kingdom", "Mama's Porch", "Concrete Psalms", "Late Night Ledger", "Undertow", "Flood the City", "Delta Blues 2.0", "Paper Planes", "Crown of Concrete", "Home Team", "River Flow", "Concrete Crown", "Late Night Ledger", "Block Party Prayer", "Gold Chain Thoughts", "Skyline Verses", "No Days Off", "Hometown Hero" },
		look = { skin = 4, hair = "afro", hairColor = { 25, 20, 18 }, top = { 255, 190, 40 }, pants = { 40, 40, 46 }, shoes = { 255, 255, 255 }, acc = "chain" },
	},
	{
		id = "neon", name = "Neon Harbor", genre = "Indie", members = 4, signCost = 350000, level = 2,
		color = { 100, 255, 200 }, skill = 76, hype = 55, pricePower = 1.0,
		fans = { EU = 900000, NA = 700000, LATAM = 100000, ASIA = 150000, OCE = 250000, MEA = 30000 },
		bio = "Indie-rock band with sing-along choruses.", pitch = "Neon Harbor already fill theatres. A real band with a loyal crowd in Europe.",
		setlist = { "Lighthouse", "Saltwater Radio", "Docklands", "Fog Horn Heart", "Tidewater", "Paper Boats", "Harbor Lights", "Sail Away Tonight", "Beacon", "Low Tide Disco", "Anchors", "Northern Lights", "Harbor Lights", "Sea Glass", "Lighthouse Static", "Foghorn Love", "Saltwater Radio", "Night Ferry", "Pier Pressure", "Low Tide Disco" },
		look = { skin = 1, hair = "messy", hairColor = { 60, 40, 30 }, top = { 100, 255, 200 }, pants = { 40, 40, 50 }, shoes = { 200, 200, 200 }, acc = "beanie" },
	},
	{
		id = "ironclad", name = "Ironclad", genre = "Metal", members = 4, signCost = 600000, level = 3,
		color = { 170, 170, 180 }, skill = 82, hype = 50, pricePower = 1.15,
		fans = { EU = 1600000, NA = 900000, LATAM = 700000, ASIA = 300000, OCE = 200000, MEA = 40000 },
		bio = "Thunderous metal veterans. Bring earplugs.", pitch = "Ironclad want fire and loud speakers. Their fans travel far for every show.",
		setlist = { "Forged in Fire", "Anvil Storm", "Steel Horizon", "Rust and Roses", "Molten Crown", "Warhammer Sky", "Black Furnace", "Iron Will", "Hammerfall Hymn", "Scrap Metal Saints", "Brimstone", "Last Forge Standing", "Anvil Storm", "Forged in Thunder", "Steel Cathedral", "Blackout Siege", "Hammerfall Night", "Molten Crown", "Rivet Heart", "War Drum Weather" },
		look = { skin = 2, hair = "long", hairColor = { 20, 20, 20 }, top = { 24, 24, 26 }, pants = { 24, 24, 26 }, shoes = { 10, 10, 10 }, acc = "sunglasses", jacket = { 50, 50, 54 } },
	},
	{
		id = "velvet", name = "Velvet June", genre = "R&B", members = 1, signCost = 1000000, level = 3,
		color = { 170, 90, 230 }, skill = 84, hype = 60, pricePower = 1.25,
		fans = { EU = 1500000, NA = 2000000, LATAM = 300000, ASIA = 400000, OCE = 300000, MEA = 250000 },
		bio = "Silky voice, sold-out late-night shows.", pitch = "Velvet June sings slow and smooth. Theatres and arenas, candles and soft light.",
		setlist = { "Velvet Hours", "Slow Burn", "Midnight Satin", "June Rain", "Silk Signals", "After Midnight", "Honey Moonlight", "Stay Till Sunrise", "Velour", "Candlelight Code", "Lavender Haze Hotel", "Pillow Talk Radio", "Silk Sheets", "Slow Burn Sunday", "Honey Voicemail", "After Hours", "Velvet Rope", "Candlelight Call", "Golden Hour Lover", "Midnight Satin" },
		look = { skin = 4, hair = "bun", hairColor = { 30, 20, 20 }, top = { 170, 90, 230 }, pants = { 40, 20, 60 }, shoes = { 230, 190, 90 }, acc = "earrings" },
	},
	{
		id = "luna", name = "Luna Sol", genre = "Latin", members = 1, signCost = 1500000, level = 3,
		color = { 255, 120, 60 }, skill = 80, hype = 65, pricePower = 1.2,
		fans = { EU = 1200000, NA = 2500000, LATAM = 6000000, ASIA = 200000, OCE = 150000, MEA = 150000 },
		bio = "Reggaeton queen with stadium-sized hooks.", pitch = "Luna Sol is huge in Latin America. Big halls and arenas, dancers and colour.",
		setlist = { "Fuego Lento", "Luna Llena", "Bailame Ya", "Corazon de Sal", "Noche Dorada", "Mar de Estrellas", "Ritmo Prohibido", "Sol de Medianoche", "Caliente", "Perreo Lunar", "Fiesta en la Playa", "Te Quiero Mas", "Sol y Luna", "Calle del Sol", "Baila Conmigo", "Fuego Lento", "Verano Eterno", "Corazon de Oro", "Noche Tropical", "Ritmo del Mar" },
		look = { skin = 3, hair = "long", hairColor = { 40, 25, 20 }, top = { 255, 120, 60 }, pants = { 255, 210, 80 }, shoes = { 255, 255, 255 }, acc = "sunglasses" },
	},
	{
		id = "dusty", name = "Dusty Creek", genre = "Country", members = 1, signCost = 2500000, level = 4,
		color = { 220, 150, 80 }, skill = 79, hype = 55, pricePower = 1.3,
		fans = { EU = 400000, NA = 7000000, LATAM = 100000, ASIA = 50000, OCE = 900000, MEA = 50000 },
		bio = "Cowboy hat, big heart, bigger choruses.", pitch = "Dusty is a country star in the US: arenas full of cowboy hats, every night a singalong.",
		setlist = { "Gravel Road Gospel", "Tailgate Summer", "Whiskey Sunset", "Mama's Pickup", "Dust Devil Dance", "Porch Light", "County Fair Kiss", "Long Way Home", "Boots on the Bar", "Barn Dance Saturday", "Heartland Radio", "Dirt Road Diamonds", "Back Porch Hymn", "Two-Lane Heart", "Whiskey River Sky", "Grain Silo Serenade", "Dust on My Boots", "Prairie Radio", "Tailgate Moon", "Hometown Lights" },
		look = { skin = 1, hair = "short", hairColor = { 140, 100, 60 }, top = { 220, 150, 80 }, pants = { 50, 70, 120 }, shoes = { 110, 70, 40 }, acc = "cowboy" },
	},
	{
		id = "starlyte", name = "STARLYTE", genre = "K-Pop", members = 5, signCost = 3500000, level = 4,
		color = { 190, 120, 255 }, skill = 85, hype = 75, pricePower = 1.5,
		fans = { EU = 2000000, NA = 3000000, LATAM = 2000000, ASIA = 8000000, OCE = 600000, MEA = 400000 },
		bio = "Five-member K-Pop group with flawless choreography.", pitch = "STARLYTE are five members with perfect choreography. Give them a wide stage and screens.",
		setlist = { "Starlight Code", "Hyperdrive", "Butterfly Effect", "Galaxy Letter", "Prism", "Comet Chaser", "Orbit Kiss", "Supernova", "Lightspeed", "Dear Universe", "Neon Seoul", "Stardust Promise", "Starlight Overdrive", "Zero Gravity", "Supernova Kiss", "Firefly Formation", "Neon Promise", "Comet Chase", "Galaxy Party", "Shine Again" },
		look = { skin = 2, hair = "messy", hairColor = { 190, 160, 255 }, top = { 240, 240, 250 }, pants = { 190, 120, 255 }, shoes = { 255, 255, 255 }, acc = "none", jacket = { 190, 120, 255 } },
	},
	{
		id = "nova", name = "Nova Ray", genre = "Pop", members = 1, signCost = 12000000, level = 5,
		color = { 255, 105, 180 }, skill = 92, hype = 80, pricePower = 1.6,
		fans = { EU = 14000000, NA = 22000000, LATAM = 8000000, ASIA = 7000000, OCE = 3000000, MEA = 1500000 },
		bio = "Global pop superstar. Every show is an event.", pitch = "Nova Ray is the biggest pop star there is. Only stadiums, and every effect you can buy.",
		setlist = { "Supernova Heart", "Gravity", "Electric Daydream", "Paper Crown", "Afterlight", "Diamond Static", "Neon Halo", "Shine Forever", "Midnight Encore", "Glass Hearts", "Satellite Love", "Golden Hour Girl", "Supernova Sunrise", "Gravity Dress", "Diamond Rain", "Satellite Crown", "Encore Forever", "Mirrorball Heart", "Infinite Night", "Starstruck" },
		look = { skin = 2, hair = "pony", hairColor = { 250, 230, 200 }, top = { 255, 105, 180 }, pants = { 255, 255, 255 }, shoes = { 255, 255, 255 }, acc = "sparkle", jacket = { 255, 255, 255 } },
	},
}

------------------------------------------------------------------ more artists, from newcomers to superstars in every genre
-- tier 1 = newcomer (level 1) .. 5 = superstar (level 5). fans = total; split over the regions by genre.
local REGION_SHARE = {
	Pop = { EU = 0.3, NA = 0.35, LATAM = 0.1, ASIA = 0.12, OCE = 0.08, MEA = 0.05 },
	Rock = { EU = 0.4, NA = 0.35, LATAM = 0.08, ASIA = 0.07, OCE = 0.07, MEA = 0.03 },
	Indie = { EU = 0.5, NA = 0.3, LATAM = 0.04, ASIA = 0.06, OCE = 0.08, MEA = 0.02 },
	EDM = { EU = 0.45, NA = 0.25, LATAM = 0.08, ASIA = 0.12, OCE = 0.06, MEA = 0.04 },
	["Hip-Hop"] = { EU = 0.25, NA = 0.5, LATAM = 0.08, ASIA = 0.07, OCE = 0.05, MEA = 0.05 },
	Metal = { EU = 0.5, NA = 0.25, LATAM = 0.12, ASIA = 0.07, OCE = 0.04, MEA = 0.02 },
	["R&B"] = { EU = 0.25, NA = 0.5, LATAM = 0.06, ASIA = 0.08, OCE = 0.05, MEA = 0.06 },
	Latin = { EU = 0.15, NA = 0.25, LATAM = 0.5, ASIA = 0.03, OCE = 0.02, MEA = 0.05 },
	Country = { EU = 0.1, NA = 0.75, LATAM = 0.03, ASIA = 0.02, OCE = 0.08, MEA = 0.02 },
	["K-Pop"] = { EU = 0.12, NA = 0.18, LATAM = 0.12, ASIA = 0.5, OCE = 0.04, MEA = 0.04 },
}
-- level, sign cost, ticket price power, skill, hype per tier
local TIER = {
	{ level = 1, cost = 45000, pp = 0.95, skill = 66, hype = 42 },
	{ level = 2, cost = 200000, pp = 1.05, skill = 74, hype = 50 },
	{ level = 3, cost = 800000, pp = 1.18, skill = 80, hype = 58 },
	{ level = 4, cost = 2800000, pp = 1.32, skill = 85, hype = 66 },
	{ level = 5, cost = 9000000, pp = 1.52, skill = 90, hype = 76 },
}
-- the audio file of a similar artist (new artists have no own recording yet)
local AUDIO = { Pop = "juno", Rock = "rusty", Indie = "lila", EDM = "voltage", ["Hip-Hop"] = "kai", Metal = "ironclad", ["R&B"] = "velvet", Latin = "luna", Country = "dusty", ["K-Pop"] = "starlyte" }
-- words for more song titles (every artist gets Artists.SONGS songs: their own first, then from these)
Artists.SONGS = 32
local WORDS = {
	Pop = { { "Sugar", "Golden", "Electric", "Pink", "Midnight", "Glitter", "Candy", "Starlight", "Summer", "Cherry", "Velvet", "Disco" }, { "Heart", "Kiss", "Daydream", "Radio", "Party", "Crush", "Sky", "Lights", "Diary", "Fever", "Sparks", "Weekend" } },
	Rock = { { "Highway", "Broken", "Thunder", "Gasoline", "Wild", "Electric", "Rusty", "Midnight", "Iron", "Neon", "Burning", "Loud" }, { "Road", "Heart", "Engine", "Riders", "Anthem", "Nights", "Blues", "Fire", "Rebels", "Garage", "Saints", "Radio" } },
	Indie = { { "Paper", "Quiet", "Velvet", "Northern", "Small", "Pale", "Faded", "Little", "Lantern", "Window", "Autumn", "Sleepy" }, { "Satellites", "Rooms", "Rivers", "Postcards", "Hours", "Gardens", "Echoes", "Letters", "Weather", "Lights", "Trains", "Waves" } },
	EDM = { { "Hyper", "Laser", "Neon", "Pulse", "Digital", "Infinite", "Quantum", "Strobe", "Night", "Bass", "Solar", "Zero" }, { "Drive", "Drop", "Signal", "Rush", "Horizon", "Machine", "Voltage", "Echo", "Wave", "Circuit", "Storm", "Gravity" } },
	["Hip-Hop"] = { { "Gold", "Concrete", "Midnight", "Paper", "Crown", "Block", "City", "Cold", "Diamond", "Late", "Street", "Big" }, { "Dreams", "Kings", "Hustle", "Chains", "Verses", "Skyline", "Moves", "Talk", "Season", "Legacy", "Flow", "Money" } },
	Metal = { { "Iron", "Black", "Steel", "Blood", "Storm", "Grave", "Thunder", "Molten", "Shadow", "Raven", "Burning", "Frozen" }, { "Throne", "Hammer", "Crown", "Siege", "Abyss", "Fury", "Legion", "Inferno", "Requiem", "Wolves", "Anvil", "Eclipse" } },
	["R&B"] = { { "Silk", "Velvet", "Honey", "Slow", "Midnight", "Golden", "Candle", "Late", "Satin", "Smooth", "Sweet", "After" }, { "Love", "Hours", "Touch", "Groove", "Whisper", "Lights", "Fever", "Talk", "Dreams", "Rain", "Kisses", "Sunday" } },
	Latin = { { "Fuego", "Noche", "Sol", "Corazon", "Baila", "Verano", "Luna", "Ritmo", "Calle", "Fiesta", "Mar", "Amor" }, { "Caliente", "Eterna", "Dorado", "Conmigo", "Tropical", "Salvaje", "Lento", "Bonita", "del Sur", "Total", "Brillante", "Loco" } },
	Country = { { "Dirt Road", "Whiskey", "Front Porch", "Hometown", "Pickup", "Prairie", "Small Town", "Tailgate", "County", "Sunday", "Dusty", "Rodeo" }, { "Heart", "Hymn", "Summer", "Sunset", "Diamonds", "Prayer", "Radio", "Lights", "Boots", "Moon", "Fair", "Road" } },
	["K-Pop"] = { { "Starlight", "Neon", "Crystal", "Hyper", "Galaxy", "Blooming", "Electric", "Dream", "Butterfly", "Prism", "Cosmic", "Sparkle" }, { "Code", "Heart", "Signal", "Promise", "Dance", "Wings", "Party", "Universe", "Formation", "Love", "Shine", "Rush" } },
}
local function seedOf(s)
	local h = 7
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 1000003
	end
	return h
end
local function makeSetlist(id, genre, own)
	local out, seen = {}, {}
	for _, t in ipairs(own or {}) do
		if not seen[t] then
			table.insert(out, t)
			seen[t] = true
		end
	end
	local w = WORDS[genre] or WORDS.Pop
	local h = seedOf(id)
	local tries = 0
	while #out < Artists.SONGS and tries < 900 do
		tries = tries + 1
		h = (h * 1103515245 + 12345) % 2147483648
		local a = w[1][h % #w[1] + 1]
		local b = w[2][math.floor(h / 97) % #w[2] + 1]
		local t = a .. " " .. b
		if not seen[t] then
			table.insert(out, t)
			seen[t] = true
		end
	end
	return out
end
Artists.makeSetlist = makeSetlist

-- { id, name, genre, members, tier, fans, color, look, bio, pitch, songs }
local MORE = {
	-- Pop
	{ "mira", "Mira Vale", "Pop", 1, 2, 900000, { 255, 170, 120 }, { skin = 3, hair = "long", hairColor = { 120, 60, 30 }, top = { 255, 170, 120 }, pants = { 240, 240, 245 }, shoes = { 255, 255, 255 }, acc = "earrings" }, "Sunny pop with a big voice and a growing fan club.", "Mira is the next step up from the newcomers: her shows sell well in mid-sized clubs and theatres.", { "Sunflower Phone", "Golden Hour Bike", "Lemon Tree Love", "Summer in Stereo", "Paper Planes Home" } },
	{ "kitty", "Kitty Glow", "Pop", 1, 3, 3500000, { 255, 120, 220 }, { skin = 1, hair = "bun", hairColor = { 255, 200, 230 }, top = { 255, 120, 220 }, pants = { 30, 30, 40 }, shoes = { 255, 120, 220 }, acc = "sparkle", jacket = { 255, 255, 255 } }, "Glitter-pop icon of the internet, every song a trend.", "Kitty's fans film everything. Pink lights and confetti and the internet does the rest.", { "Glow Up Girl", "Pixel Heart", "Bubble Pop Club", "Neon Kitty", "Princess Mode" } },
	{ "aurora", "Aurora Blaze", "Pop", 1, 4, 12000000, { 255, 80, 120 }, { skin = 2, hair = "long", hairColor = { 40, 30, 30 }, top = { 255, 80, 120 }, pants = { 255, 255, 255 }, shoes = { 255, 255, 255 }, acc = "sunglasses", jacket = { 20, 20, 26 } }, "Arena pop queen with dance-floor anthems.", "Aurora fills arenas. She is one step below Nova Ray and wants a show to match.", { "Firestarter Heart", "Diamond Dance", "Red Lights", "Queen of the Night", "Wildfire" } },
	-- Rock
	{ "fusebox", "The Fuse Box", "Rock", 4, 2, 1100000, { 240, 120, 40 }, { skin = 1, hair = "messy", hairColor = { 60, 40, 30 }, top = { 30, 30, 34 }, pants = { 40, 50, 90 }, shoes = { 20, 20, 22 }, acc = "none", jacket = { 120, 60, 30 } }, "Loud garage rock four-piece from the suburbs.", "The Fuse Box play like every show is their last. Clubs and small halls love them.", { "Blown Fuse", "Basement Riot", "Feedback Summer", "Amp Up", "Shortwave" } },
	{ "copper", "Copper Saints", "Rock", 4, 3, 4200000, { 200, 120, 70 }, { skin = 4, hair = "long", hairColor = { 30, 24, 20 }, top = { 200, 120, 70 }, pants = { 30, 30, 34 }, shoes = { 80, 50, 30 }, acc = "bandana" }, "Blues rock band with endless guitar solos.", "Copper Saints are a proper rock band: big riffs, long solos, fans who travel.", { "Copper Rain", "Saints and Sinners", "Southern Thunder", "Slide Guitar Prayer", "Rusted Halo" } },
	{ "outlaws", "Neon Outlaws", "Rock", 5, 4, 10000000, { 255, 60, 90 }, { skin = 1, hair = "short", hairColor = { 200, 40, 60 }, top = { 20, 20, 22 }, pants = { 20, 20, 22 }, shoes = { 255, 60, 90 }, acc = "sunglasses", jacket = { 255, 60, 90 } }, "Stadium rock with neon and fireworks.", "Neon Outlaws need pyro and a long runway. Big arenas, big money.", { "Outlaw Nation", "Neon Rebels", "Gunpowder Sky", "Last Gang Standing", "Run the Night" } },
	{ "atlas", "Thunder Atlas", "Rock", 4, 5, 32000000, { 255, 200, 60 }, { skin = 2, hair = "long", hairColor = { 230, 200, 120 }, top = { 255, 255, 255 }, pants = { 30, 30, 34 }, shoes = { 20, 20, 22 }, acc = "chain", jacket = { 20, 20, 22 } }, "Legendary rock giants, forty years of hits.", "Thunder Atlas are legends. Only a global label gets them, and only for stadiums.", { "Atlas Shrugged Me", "Thunder Road Home", "Hold the Sky", "Rock Eternal", "World on Fire" } },
	-- Indie
	{ "lantern", "Paper Lantern Club", "Indie", 2, 1, 120000, { 240, 220, 150 }, { skin = 1, hair = "messy", hairColor = { 140, 90, 50 }, top = { 240, 220, 150 }, pants = { 90, 80, 70 }, shoes = { 240, 240, 240 }, acc = "beanie" }, "Lo-fi indie duo with handmade songs.", "Two friends with a cassette recorder. Tiny clubs, warm crowds, cheap to sign.", { "Lantern Light", "Bicycle Summer", "Cassette Heart", "Rooftop Garden", "Little Club Song" } },
	{ "willow", "Willow & Wren", "Indie", 2, 3, 3000000, { 130, 190, 140 }, { skin = 1, hair = "long", hairColor = { 200, 140, 80 }, top = { 130, 190, 140 }, pants = { 230, 220, 200 }, shoes = { 120, 90, 60 }, acc = "none" }, "Folk-indie duo, harmonies and lanterns.", "Willow & Wren sell out theatres. Quiet songs, very loyal fans.", { "Willow Tree", "Wren Song", "Two Birds", "Forest Radio", "Hollow Hill" } },
	-- EDM
	{ "pulse", "Pulse Theory", "EDM", 1, 1, 200000, { 60, 255, 200 }, { skin = 3, hair = "short", hairColor = { 20, 20, 20 }, top = { 20, 20, 26 }, pants = { 20, 20, 26 }, shoes = { 60, 255, 200 }, acc = "headphones" }, "Bedroom producer with club bangers.", "A young DJ with good tracks. A DJ booth and some lasers are all he needs.", { "Theory of Pulse", "Night Bus Bass", "First Drop", "Club Bedroom", "Afterhours 101" } },
	{ "kairo", "KAIRO", "EDM", 1, 3, 4500000, { 120, 90, 255 }, { skin = 4, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 255, 255, 255 }, pants = { 20, 20, 26 }, shoes = { 255, 255, 255 }, acc = "sunglasses" }, "Festival DJ with huge drops.", "KAIRO plays festivals all summer. Give him screens and strobes.", { "Desert Laser", "KAIRO Anthem", "Pyramids at Night", "Heatwave Drop", "Sandstorm Signal" } },
	{ "zenith", "ZENITH9", "EDM", 1, 5, 28000000, { 0, 200, 255 }, { skin = 1, hair = "mohawk", hairColor = { 0, 200, 255 }, top = { 20, 20, 26 }, pants = { 20, 20, 26 }, shoes = { 0, 200, 255 }, acc = "headphones", jacket = { 0, 200, 255 } }, "The biggest DJ on the planet, stadium raves.", "ZENITH9 turns stadiums into clubs. Lasers, LED walls, the full program.", { "Zenith Point", "Nine Lives", "Orbit Rave", "Stadium Pulse", "Gravity Zero" } },
	-- Hip-Hop
	{ "breeze", "Lil Breeze", "Hip-Hop", 1, 1, 150000, { 120, 200, 255 }, { skin = 4, hair = "afro", hairColor = { 20, 20, 20 }, top = { 120, 200, 255 }, pants = { 230, 230, 236 }, shoes = { 255, 255, 255 }, acc = "cap" }, "Young rapper with a viral freestyle.", "Lil Breeze is raw but fun. Small clubs first, the hype will come.", { "Breezy Flow", "Corner Store", "First Mixtape", "Skate Park Verse", "Mama Said" } },
	{ "marcus", "Marcus Gold", "Hip-Hop", 1, 3, 5000000, { 230, 190, 60 }, { skin = 5, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 20, 20, 22 }, pants = { 20, 20, 22 }, shoes = { 230, 190, 60 }, acc = "chain", jacket = { 230, 190, 60 } }, "Lyrical rapper with gold records.", "Marcus Gold fills arenas in North America. He loves a big LED wall.", { "Gold Standard", "Marcus Avenue", "Twenty-Four Karat", "Late Night Ledger Two", "Golden Era" } },
	{ "solace", "King Solace", "Hip-Hop", 1, 5, 35000000, { 160, 60, 255 }, { skin = 5, hair = "short", hairColor = { 20, 20, 20 }, top = { 255, 255, 255 }, pants = { 20, 20, 22 }, shoes = { 255, 255, 255 }, acc = "sunglasses", jacket = { 160, 60, 255 } }, "Hip-hop royalty, every album a world record.", "King Solace only plays stadiums. A throne and fireworks are a must.", { "Long Live Solace", "Crown Heavy", "Royal Flow", "Kingdom Come", "Throne Talk" } },
	-- Metal
	{ "coffin", "Coffin Spark", "Metal", 4, 1, 90000, { 180, 60, 60 }, { skin = 1, hair = "long", hairColor = { 20, 20, 20 }, top = { 20, 20, 22 }, pants = { 20, 20, 22 }, shoes = { 20, 20, 22 }, acc = "none" }, "Young thrash band from a basement.", "Coffin Spark are loud and cheap. A small club and a smoke machine, done.", { "Spark the Coffin", "Basement Thrash", "Skull Radio", "Lightning Teeth", "Grave Disco" } },
	{ "thornwall", "Thornwall", "Metal", 5, 2, 1000000, { 120, 140, 120 }, { skin = 1, hair = "long", hairColor = { 60, 40, 30 }, top = { 40, 40, 44 }, pants = { 20, 20, 22 }, shoes = { 20, 20, 22 }, acc = "none" }, "Folk metal with horns and big choruses.", "Thornwall bring drinking songs and drums. Halls in Europe love them.", { "Wall of Thorns", "Mead Hall", "Northern Shields", "Raven Banner", "Forest Oath" } },
	{ "abyss", "Abyss Engine", "Metal", 4, 4, 7000000, { 255, 90, 30 }, { skin = 1, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 20, 20, 22 }, pants = { 20, 20, 22 }, shoes = { 20, 20, 22 }, acc = "none", jacket = { 60, 60, 66 } }, "Industrial metal with flames everywhere.", "Abyss Engine need fire. Lots of fire. Arena crowds go wild for it.", { "Engine of the Abyss", "Furnace Heart", "Machine Gods", "Iron Lung", "Burn Protocol" } },
	-- R&B
	{ "jade", "Jade Monroe", "R&B", 1, 1, 120000, { 80, 200, 160 }, { skin = 4, hair = "bun", hairColor = { 20, 20, 20 }, top = { 80, 200, 160 }, pants = { 240, 240, 245 }, shoes = { 255, 255, 255 }, acc = "earrings" }, "Soulful newcomer with a smoky voice.", "Jade sings like a star already. Small rooms with candles suit her.", { "Jade Hour", "Monroe Street", "Smoke and Honey", "Tea for Two", "Blue Velvet Room" } },
	{ "silk", "Silk Avenue", "R&B", 2, 2, 900000, { 200, 120, 200 }, { skin = 5, hair = "short", hairColor = { 20, 20, 20 }, top = { 200, 120, 200 }, pants = { 20, 20, 26 }, shoes = { 255, 255, 255 }, acc = "chain" }, "R&B duo with slow jams and smooth moves.", "Silk Avenue are a step up from Jade: theatres, slow songs, good ticket prices.", { "Avenue Lights", "Silk Road Love", "Slow Motion", "Two Hearts One Mic", "Late Checkout" } },
	-- Latin
	{ "rio", "Rio Calma", "Latin", 1, 1, 180000, { 255, 170, 60 }, { skin = 3, hair = "messy", hairColor = { 30, 24, 20 }, top = { 255, 170, 60 }, pants = { 240, 240, 245 }, shoes = { 255, 255, 255 }, acc = "none" }, "Reggaeton newcomer with summer hits.", "Rio Calma makes people dance. Latin America first, the rest will follow.", { "Calma Calma", "Playa Bonita", "Verano Conmigo", "Rio de Noche", "Mueve" } },
	{ "soles", "Los Soles Rojos", "Latin", 5, 2, 1400000, { 230, 60, 50 }, { skin = 3, hair = "short", hairColor = { 20, 20, 20 }, top = { 230, 60, 50 }, pants = { 20, 20, 26 }, shoes = { 120, 70, 40 }, acc = "cowboy" }, "Five-piece cumbia band, a party on stage.", "Los Soles Rojos are a whole party with horns. Mid-sized halls in Latin America.", { "Sol Rojo", "Cumbia del Barrio", "Trompeta Loca", "Fiesta Grande", "Baile Total" } },
	{ "maya", "Maya Fuego", "Latin", 1, 5, 40000000, { 255, 100, 40 }, { skin = 3, hair = "long", hairColor = { 30, 20, 16 }, top = { 255, 100, 40 }, pants = { 255, 255, 255 }, shoes = { 255, 255, 255 }, acc = "sparkle", jacket = { 255, 220, 120 } }, "Latin superstar, record-breaking world tours.", "Maya Fuego is huge everywhere. Stadiums, fireworks, a catwalk into the crowd.", { "Fuego Eterno", "Reina del Sol", "Mi Corazon", "Bailando Contigo", "Noche de Oro" } },
	-- Country
	{ "harper", "Harper Lane", "Country", 1, 1, 100000, { 230, 170, 110 }, { skin = 1, hair = "pony", hairColor = { 200, 150, 90 }, top = { 230, 170, 110 }, pants = { 60, 80, 130 }, shoes = { 120, 80, 50 }, acc = "cowboy" }, "Young country singer with a guitar and a pickup.", "Harper plays bars and small clubs in the US. A cosy set and an acoustic moment.", { "Harper's Highway", "Lane to You", "Kitchen Dance", "Pickup Truck Prayer", "Firefly Field" } },
	{ "brody", "Brody Banks", "Country", 1, 2, 800000, { 160, 110, 70 }, { skin = 1, hair = "short", hairColor = { 140, 100, 60 }, top = { 255, 255, 255 }, pants = { 50, 70, 120 }, shoes = { 110, 70, 40 }, acc = "cowboy", jacket = { 160, 110, 70 } }, "Party country with tailgate anthems.", "Brody Banks brings the beer-tent energy. US halls sell out fast.", { "Banks of the River", "Tailgate King", "Cold One Summer", "Saturday Night Truck", "Muddy Boots" } },
	{ "cassidy", "Cassidy Rose", "Country", 1, 3, 3000000, { 230, 110, 140 }, { skin = 1, hair = "long", hairColor = { 230, 200, 140 }, top = { 230, 110, 140 }, pants = { 240, 240, 245 }, shoes = { 255, 255, 255 }, acc = "earrings" }, "Country-pop star with heartbreak hits.", "Cassidy Rose is between Harper and Dusty: arenas in the US, big singalongs.", { "Rose Colored", "Cassidy's Song", "Heartbreak Rodeo", "Wildflower", "Back Road Kiss" } },
	-- K-Pop
	{ "nextwave", "NEXT WAVE", "K-Pop", 4, 2, 1500000, { 80, 200, 255 }, { skin = 2, hair = "messy", hairColor = { 80, 200, 255 }, top = { 255, 255, 255 }, pants = { 30, 30, 36 }, shoes = { 255, 255, 255 }, acc = "none", jacket = { 80, 200, 255 } }, "Rookie K-Pop group, four members, fresh debut.", "NEXT WAVE just debuted. Their fans are loud, the choreography needs room.", { "Next Wave", "Tidal Heart", "Ocean Signal", "Rookie Season", "Splash" } },
	{ "lumina", "LUMINA", "K-Pop", 6, 3, 5000000, { 255, 220, 120 }, { skin = 2, hair = "pony", hairColor = { 255, 220, 150 }, top = { 255, 220, 120 }, pants = { 255, 255, 255 }, shoes = { 255, 255, 255 }, acc = "none", jacket = { 255, 255, 255 } }, "Six-member girl group with bright pop songs.", "LUMINA are big in Asia and growing everywhere. Six dancers need a wide stage.", { "Lumina", "Golden Petals", "Bright Side", "Lemonade Love", "Sunbeam" } },
	{ "eclipse", "ECLIPSE7", "K-Pop", 7, 5, 45000000, { 120, 80, 255 }, { skin = 2, hair = "short", hairColor = { 40, 30, 60 }, top = { 20, 20, 26 }, pants = { 20, 20, 26 }, shoes = { 255, 255, 255 }, acc = "none", jacket = { 120, 80, 255 } }, "Seven-member global K-Pop phenomenon.", "ECLIPSE7 sell out stadiums in minutes. Seven members, a huge stage, every effect.", { "Total Eclipse", "Seven Moons", "Shadow Dance", "Black Sun", "Lunar Code" } },
}
for _, m in ipairs(MORE) do
	local id, name, genre, members, tier, fans, color, look, bio, pitch, own = m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11]
	local tr = TIER[tier]
	local share = REGION_SHARE[genre] or REGION_SHARE.Pop
	local f = {}
	for reg, sh in pairs(share) do
		f[reg] = math.floor(fans * sh / 1000 + 0.5) * 1000
	end
	local h = seedOf(id)
	table.insert(Artists.list, {
		id = id, name = name, genre = genre, members = members, tier = tier,
		signCost = math.floor(tr.cost * (0.8 + (h % 40) / 100) / 5000 + 0.5) * 5000, level = tr.level,
		color = color, skill = tr.skill + (h % 7) - 3, hype = tr.hype + (h % 9) - 4, pricePower = tr.pp,
		fans = f, bio = bio, pitch = pitch, audio = AUDIO[genre],
		setlist = makeSetlist(id, genre, own), look = look,
	})
end

-- Look of the band members / dancers per genre (the lead artist has an own look)
Artists.BAND_STYLE = {
	Rock = { hair = { "long", "short", "messy" }, tops = { { 30, 30, 34 }, { 120, 30, 30 }, { 60, 60, 66 } }, pants = { { 40, 50, 90 }, { 20, 20, 24 } }, acc = { "none", "bandana", "sunglasses" } },
	Metal = { hair = { "long", "long", "buzz" }, tops = { { 20, 20, 22 }, { 40, 40, 44 } }, pants = { { 20, 20, 22 } }, acc = { "none", "sunglasses" } },
	Indie = { hair = { "messy", "short", "long" }, tops = { { 200, 170, 120 }, { 90, 120, 90 }, { 230, 230, 230 } }, pants = { { 60, 60, 70 }, { 110, 90, 70 } }, acc = { "none", "beanie" } },
	["K-Pop"] = { hair = { "messy", "short", "pony" }, tops = { { 240, 240, 250 } }, pants = { { 30, 30, 36 } }, acc = { "none" }, matchArtist = true },
	default = { hair = { "short", "messy", "bun" }, tops = { { 30, 30, 36 }, { 230, 230, 236 } }, pants = { { 30, 30, 36 } }, acc = { "none" } },
}

-- 10 label levels: every artist tier spans two levels (the bigger half of a tier needs the higher one)
do
	local BASE = { 1, 3, 5, 7, 9 }
	local byOld = {}
	for _, a in ipairs(Artists.list) do
		byOld[a.level] = byOld[a.level] or {}
		table.insert(byOld[a.level], a)
	end
	for old, list in pairs(byOld) do
		local function total(a)
			local n = 0
			for _, f in pairs(a.fans) do
				n = n + f
			end
			return n
		end
		table.sort(list, function(x, y)
			return total(x) < total(y)
		end)
		local half = math.floor(#list / 2)
		for i, a in ipairs(list) do
			a.level = BASE[old] + ((i > half and not a.starter) and 1 or 0)
		end
	end
end

-- every setlist: no title twice, and Artists.SONGS songs (long shows never repeat a song)
for _, a in ipairs(Artists.list) do
	a.setlist = makeSetlist(a.id, a.genre, a.setlist)
end

Artists.byId = {}
for i, a in ipairs(Artists.list) do
	a.order = i
	Artists.byId[a.id] = a
end

return Artists
