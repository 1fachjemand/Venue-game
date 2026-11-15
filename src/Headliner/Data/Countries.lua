-- Countries and venues.
-- Venue names are parody names inspired by real venues. Capacities follow the real venues'
-- concert capacities (source: Wikipedia infoboxes, checked Nov 2026). Venues marked "fictional" are made up.
--
-- share      = this country's share of its region's music market (fans in region * share)
-- priceLevel = ticket price multiplier
-- genres     = local taste multipliers (1 = neutral)

local Countries = {}

Countries.VENUE_TYPES = {
	Club = { label = "CLUB", color = { 120, 120, 150 }, rentPerSeat = 2.5, look = "club", stage = "Club" },
	Theatre = { label = "THEATRE", color = { 170, 120, 255 }, rentPerSeat = 3.0, look = "theatre", stage = "Theatre" },
	Hall = { label = "HALL", color = { 120, 170, 255 }, rentPerSeat = 3.0, look = "theatre", stage = "Theatre" },
	Arena = { label = "ARENA", color = { 0, 200, 255 }, rentPerSeat = 3.5, look = "arena", stage = "Arena" },
	Amphitheatre = { label = "AMPHI", color = { 80, 220, 140 }, rentPerSeat = 3.0, look = "amphi", stage = "Arena" },
	Stadium = { label = "STADIUM", color = { 255, 90, 140 }, rentPerSeat = 3.0, look = "stadium", stage = "Stadium" },
}

Countries.list = {
	-- ===================== EUROPE =====================
	{
		id = "uk", name = "United Kingdom", region = "EU", lat = 51.5, lon = -0.13,
		share = 0.164, priceLevel = 1.10, genres = { Indie = 1.2, Rock = 1.1 },
		venues = {
			{ id = "uk_fiddle", name = "The Foggy Fiddle", city = "London", type = "Club", cap = 350 },
			{ id = "uk_brixtown", name = "O3 Academy Brixtown", city = "London", type = "Theatre", cap = 4921 }, -- O2 Academy Brixton
			{ id = "uk_alfred", name = "Royal Alfred Hall", city = "London", type = "Hall", cap = 5272 }, -- Royal Albert Hall
			{ id = "uk_o3", name = "The O3 Arena", city = "London", type = "Arena", cap = 20000 }, -- The O2 Arena
			{ id = "uk_coopalive", name = "Co-op Alive", city = "Manchester", type = "Arena", cap = 23500 }, -- Co-op Live
			{ id = "uk_wemblee", name = "Wemblee Stadium", city = "London", type = "Stadium", cap = 90000 }, -- Wembley Stadium
			{ id = "uk_koka", name = "KOKA", city = "London", type = "Club", cap = 1500 }, -- KOKO
			{ id = "uk_roundhaus", name = "The Roundhaus", city = "London", type = "Theatre", cap = 3300 }, -- Roundhouse
			{ id = "uk_hammer", name = "Hammerstone Apollo", city = "London", type = "Theatre", cap = 5039 }, -- Hammersmith Apollo
			{ id = "uk_ova", name = "OVA Arena Wemblee", city = "London", type = "Arena", cap = 12500 }, -- OVO Arena Wembley
			{ id = "uk_hydra", name = "The Hydra", city = "Glasgow", type = "Arena", cap = 14700 }, -- OVO Hydro
			{ id = "uk_aok", name = "AOK Arena", city = "Manchester", type = "Arena", cap = 23000 }, -- Manchester Arena
			{ id = "uk_etihat", name = "Etihat Stadium", city = "Manchester", type = "Stadium", cap = 61038 }, -- Etihad Stadium
			{ id = "uk_murray", name = "Murrayfeld Stadium", city = "Edinburgh", type = "Stadium", cap = 67144 }, -- Murrayfield
		},
	},
	{
		id = "ie", name = "Ireland", region = "EU", lat = 53.35, lon = -6.26,
		share = 0.033, priceLevel = 1.00, genres = { Indie = 1.15, Rock = 1.1 },
		venues = {
			{ id = "ie_clover", name = "The Clover Room", city = "Dublin", type = "Club", cap = 400 },
			{ id = "ie_crook", name = "Crook Park", city = "Dublin", type = "Stadium", cap = 82300 }, -- Croke Park
			{ id = "ie_vicar", name = "Vicar Lane", city = "Dublin", type = "Theatre", cap = 1500 }, -- Vicar Street
			{ id = "ie_olimpia", name = "Olimpia Theatre", city = "Dublin", type = "Theatre", cap = 1621 }, -- Olympia Theatre
			{ id = "ie_liffey", name = "Liffey Arena", city = "Dublin", type = "Arena", cap = 13000 }, -- fictional
			{ id = "ie_avivo", name = "Avivo Stadium", city = "Dublin", type = "Stadium", cap = 65000 }, -- Aviva Stadium (concerts)
		},
	},
	{
		id = "fr", name = "France", region = "EU", lat = 48.86, lon = 2.35,
		share = 0.123, priceLevel = 1.00, genres = { ["Hip-Hop"] = 1.15 },
		venues = {
			{ id = "fr_neon", name = "Le Petit Neon", city = "Paris", type = "Club", cap = 300 },
			{ id = "fr_olympix", name = "L'Olympix", city = "Paris", type = "Theatre", cap = 2824 }, -- L'Olympia
			{ id = "fr_zenit", name = "Le Zenit", city = "Paris", type = "Hall", cap = 6300 }, -- Zenith Paris
			{ id = "fr_accord", name = "Accord Arena", city = "Paris", type = "Arena", cap = 20300 }, -- Accor Arena
			{ id = "fr_defence", name = "La Defence Dome", city = "Paris", type = "Stadium", cap = 45000 }, -- Paris La Defense Arena
			{ id = "fr_stadium", name = "Stadium of France", city = "Saint-Denis", type = "Stadium", cap = 81338 }, -- Stade de France
			{ id = "fr_cigalle", name = "La Cigalle", city = "Paris", type = "Club", cap = 1389 }, -- La Cigale
			{ id = "fr_bataklan", name = "Le Bataklan", city = "Paris", type = "Theatre", cap = 1694 }, -- Bataclan
			{ id = "fr_arkea", name = "Arkea Dome", city = "Bordeaux", type = "Arena", cap = 11300 }, -- Arkea Arena
			{ id = "fr_ldlb", name = "LDLB Arena", city = "Lyon", type = "Arena", cap = 16000 }, -- LDLC Arena
			{ id = "fr_grouparama", name = "Grouparama Stadium", city = "Lyon", type = "Stadium", cap = 59186 }, -- Groupama Stadium
			{ id = "fr_velodrom", name = "Stade Velodrom", city = "Marseille", type = "Stadium", cap = 67394 }, -- Stade Velodrome
		},
	},
	{
		id = "nl", name = "Netherlands", region = "EU", lat = 52.37, lon = 4.9,
		share = 0.057, priceLevel = 1.00, genres = { EDM = 1.3 },
		venues = {
			{ id = "nl_paradisio", name = "Paradisio", city = "Amsterdam", type = "Theatre", cap = 1500 }, -- Paradiso
			{ id = "nl_afos", name = "AFOS Live", city = "Amsterdam", type = "Hall", cap = 6000 }, -- AFAS Live
			{ id = "nl_zigga", name = "Zigga Dome", city = "Amsterdam", type = "Arena", cap = 17000 }, -- Ziggo Dome
			{ id = "nl_kroft", name = "Johan Kroft Arena", city = "Amsterdam", type = "Stadium", cap = 71000 }, -- Johan Cruyff Arena
			{ id = "nl_kroeg", name = "De Kleine Kroeg", city = "Rotterdam", type = "Club", cap = 450 }, -- fictional
			{ id = "nl_vredenberg", name = "Tivoli Vredenberg", city = "Utrecht", type = "Theatre", cap = 2000 }, -- TivoliVredenburg
			{ id = "nl_geldre", name = "Geldre Dome", city = "Arnhem", type = "Stadium", cap = 41000 }, -- GelreDome
			{ id = "nl_kuup", name = "De Kuup", city = "Rotterdam", type = "Stadium", cap = 50000 }, -- De Kuip
		},
	},
	{
		id = "de", name = "Germany", region = "EU", lat = 52.52, lon = 13.4,
		share = 0.164, priceLevel = 1.00, genres = { EDM = 1.2, Metal = 1.25 },
		venues = {
			{ id = "de_keller", name = "Kellerklub 37", city = "Hamburg", type = "Club", cap = 400 },
			{ id = "de_columbus", name = "Columbus Hall", city = "Berlin", type = "Theatre", cap = 3500 }, -- Columbiahalle
			{ id = "de_olyhall", name = "Olympus Hall", city = "Munich", type = "Arena", cap = 15500 }, -- Olympiahalle
			{ id = "de_ubar", name = "Ubar Arena", city = "Berlin", type = "Arena", cap = 17000 }, -- Uber Arena
			{ id = "de_lanxus", name = "Lanxus Arena", city = "Cologne", type = "Arena", cap = 20000 }, -- Lanxess Arena
			{ id = "de_forest", name = "Forest Stage", city = "Berlin", type = "Amphitheatre", cap = 22290 }, -- Waldbuehne
			{ id = "de_olympus", name = "Olympus Stadium", city = "Berlin", type = "Stadium", cap = 74475 }, -- Olympiastadion
			{ id = "de_tempodrome", name = "Tempodrome", city = "Berlin", type = "Theatre", cap = 3500 }, -- Tempodrom
			{ id = "de_palladiom", name = "Palladiom", city = "Cologne", type = "Theatre", cap = 4000 }, -- Palladium
			{ id = "de_festival", name = "Festival Hall", city = "Frankfurt", type = "Arena", cap = 13500 }, -- Festhalle
			{ id = "de_sab", name = "SAB Arena", city = "Mannheim", type = "Arena", cap = 15000 }, -- SAP Arena
			{ id = "de_barclay", name = "Barclay Arena", city = "Hamburg", type = "Arena", cap = 16000 }, -- Barclays Arena
			{ id = "de_veltinz", name = "Veltinz Arena", city = "Gelsenkirchen", type = "Stadium", cap = 62271 }, -- Veltins-Arena
			{ id = "de_allianz", name = "Allianz Arina", city = "Munich", type = "Stadium", cap = 75024 }, -- Allianz Arena
			{ id = "de_idunno", name = "Signal Idunno Park", city = "Dortmund", type = "Stadium", cap = 81365 }, -- Signal Iduna Park
			{ id = "de_bonkpark", name = "Deutsche Bonk Park", city = "Frankfurt", type = "Stadium", cap = 55000 }, -- Deutsche Bank Park (concerts 44,000-60,000)
		},
	},
	{
		id = "ch", name = "Switzerland", region = "EU", lat = 47.37, lon = 8.54,
		share = 0.033, priceLevel = 1.35, genres = { EDM = 1.1 },
		venues = {
			{ id = "ch_alpenglow", name = "Club Alpenglow", city = "Zurich", type = "Club", cap = 450 },
			{ id = "ch_jacob", name = "St. Jacob's Hall", city = "Basel", type = "Arena", cap = 12400 }, -- St. Jakobshalle
			{ id = "ch_hots", name = "Hall of the Stadium", city = "Zurich", type = "Arena", cap = 15000 }, -- Hallenstadion
			{ id = "ch_wankdorf", name = "Wankdorf Park", city = "Bern", type = "Stadium", cap = 45000 }, -- Stadion Wankdorf
			{ id = "ch_lazy", name = "Lazyground Stadium", city = "Zurich", type = "Stadium", cap = 50044 }, -- Letzigrund
			{ id = "ch_volkshalle", name = "Volkshalle", city = "Zurich", type = "Theatre", cap = 1600 }, -- fictional
			{ id = "ch_lakeside", name = "Lakeside Hall", city = "Lausanne", type = "Hall", cap = 3000 }, -- fictional
			{ id = "ch_geneva", name = "Arena of Geneva", city = "Geneva", type = "Arena", cap = 9500 }, -- Arena de Geneve
			{ id = "ch_jacobpark", name = "St. Jacob Park", city = "Basel", type = "Stadium", cap = 40000 }, -- St. Jakob-Park (concerts)
		},
	},
	{
		id = "it", name = "Italy", region = "EU", lat = 41.9, lon = 12.5,
		share = 0.09, priceLevel = 0.90, genres = { Pop = 1.1, Rock = 1.1 },
		venues = {
			{ id = "it_lucciola", name = "Club Lucciola", city = "Milan", type = "Club", cap = 400 },
			{ id = "it_forum", name = "Unipolo Forum", city = "Milan", type = "Arena", cap = 15800 }, -- Unipol Forum
			{ id = "it_verona", name = "Arena of Verona", city = "Verona", type = "Amphitheatre", cap = 22000 }, -- Arena di Verona
			{ id = "it_sansirro", name = "San Sirro Stadium", city = "Milan", type = "Stadium", cap = 80018 }, -- San Siro
			{ id = "it_aurora", name = "Teatro Aurora", city = "Milan", type = "Theatre", cap = 2500 }, -- fictional
			{ id = "it_palalotto", name = "PalaLotto", city = "Rome", type = "Arena", cap = 11200 }, -- PalaLottomatica
			{ id = "it_inalpo", name = "Inalpo Arena", city = "Turin", type = "Arena", cap = 13347 }, -- Inalpi Arena (end stage)
			{ id = "it_olimpo", name = "Stadio Olimpo", city = "Rome", type = "Stadium", cap = 70634 }, -- Stadio Olimpico
		},
	},
	{
		id = "es", name = "Spain", region = "EU", lat = 40.42, lon = -3.7,
		share = 0.09, priceLevel = 0.85, genres = { Latin = 1.25 },
		venues = {
			{ id = "es_cometa", name = "Sala Cometa", city = "Madrid", type = "Club", cap = 500 },
			{ id = "es_movistor", name = "Movistor Arena", city = "Madrid", type = "Arena", cap = 15000 }, -- Movistar Arena Madrid
			{ id = "es_jorge", name = "Palau Saint Jorge", city = "Barcelona", type = "Arena", cap = 17960 }, -- Palau Sant Jordi
			{ id = "es_bernabeo", name = "Bernabeo Stadium", city = "Madrid", type = "Stadium", cap = 83186 }, -- Santiago Bernabeu
			{ id = "es_luna", name = "Sala Luna", city = "Barcelona", type = "Theatre", cap = 1800 }, -- fictional
			{ id = "es_biscaya", name = "Biscaya Arena", city = "Bilbao", type = "Arena", cap = 21500 }, -- Bizkaia Arena (concerts)
			{ id = "es_olimpic", name = "Estadi Olimpico", city = "Barcelona", type = "Stadium", cap = 55926 }, -- Estadi Olimpic Lluis Companys
			{ id = "es_metropolitan", name = "Metropolitan Stadium", city = "Madrid", type = "Stadium", cap = 60000 }, -- Metropolitano (concerts)
		},
	},
	{
		id = "se", name = "Sweden", region = "EU", lat = 59.33, lon = 18.07,
		share = 0.041, priceLevel = 1.05, genres = { Pop = 1.2, Metal = 1.1 },
		venues = {
			{ id = "se_norrsken", name = "Klubb Norrsken", city = "Stockholm", type = "Club", cap = 400 },
			{ id = "se_glob", name = "The Glob Arena", city = "Stockholm", type = "Arena", cap = 16000 }, -- Avicii Arena (Globen)
			{ id = "se_annex", name = "The Annex", city = "Stockholm", type = "Theatre", cap = 3400 }, -- Annexet
			{ id = "se_scandium", name = "Scandium", city = "Gothenburg", type = "Arena", cap = 14000 }, -- Scandinavium
			{ id = "se_malmoe", name = "Malmoe Arena", city = "Malmo", type = "Arena", cap = 15500 }, -- Malmo Arena
			{ id = "se_strawbery", name = "Strawbery Arena", city = "Stockholm", type = "Stadium", cap = 65000 }, -- Strawberry Arena (concerts)
			{ id = "se_ulevi", name = "Ulevi", city = "Gothenburg", type = "Stadium", cap = 75000 }, -- Ullevi (concerts)
		},
	},
	{
		id = "be", name = "Belgium", region = "EU", lat = 50.85, lon = 4.35,
		share = 0.035, priceLevel = 1.0, genres = { EDM = 1.2, Indie = 1.1 },
		venues = {
			{ id = "be_grenier", name = "Le Petit Grenier", city = "Brussels", type = "Club", cap = 400 }, -- fictional
			{ id = "be_oldhall", name = "Old Belgium Hall", city = "Brussels", type = "Theatre", cap = 2000 }, -- Ancienne Belgique
			{ id = "be_forest", name = "Forest Nationaal", city = "Brussels", type = "Hall", cap = 8400 }, -- Forest National
			{ id = "be_sportpalace", name = "Sportpalace Dome", city = "Antwerp", type = "Arena", cap = 23001 }, -- AFAS Dome / Sportpaleis
			{ id = "be_baldwin", name = "King Baldwin Stadium", city = "Brussels", type = "Stadium", cap = 50093 }, -- King Baudouin Stadium
		},
	},
	{
		id = "at", name = "Austria", region = "EU", lat = 48.21, lon = 16.37,
		share = 0.03, priceLevel = 1.05, genres = { Pop = 1.1 },
		venues = {
			{ id = "at_kaffee", name = "Kaffeekeller", city = "Vienna", type = "Club", cap = 350 }, -- fictional
			{ id = "at_gasometre", name = "Gasometre", city = "Vienna", type = "Hall", cap = 4200 }, -- Gasometer Vienna
			{ id = "at_cityhall", name = "Vienna City Arena", city = "Vienna", type = "Arena", cap = 16083 }, -- Wiener Stadthalle
			{ id = "at_hapel", name = "Ernst-Hapel Stadium", city = "Vienna", type = "Stadium", cap = 50865 }, -- Ernst-Happel-Stadion (end stage)
		},
	},
	{
		id = "pl", name = "Poland", region = "EU", lat = 52.23, lon = 21.01,
		share = 0.06, priceLevel = 0.6, genres = { Metal = 1.2, Rock = 1.1 },
		venues = {
			{ id = "pl_wisla", name = "Klub Wisla", city = "Warsaw", type = "Club", cap = 600 }, -- fictional
			{ id = "pl_polonia", name = "Teatr Polonia Live", city = "Warsaw", type = "Theatre", cap = 2500 }, -- fictional
			{ id = "pl_atlas", name = "Atlas Dome", city = "Lodz", type = "Arena", cap = 14728 }, -- Atlas Arena
			{ id = "pl_tauryn", name = "Tauryn Arena", city = "Krakow", type = "Arena", cap = 22000 }, -- Tauron Arena Krakow
			{ id = "pl_narodny", name = "Narodny Stadium", city = "Warsaw", type = "Stadium", cap = 80000 }, -- PGE Narodowy (concerts)
		},
	},
	{
		id = "no", name = "Norway", region = "EU", lat = 59.91, lon = 10.75,
		share = 0.025, priceLevel = 1.3, genres = { Metal = 1.2, Pop = 1.1 },
		venues = {
			{ id = "no_fjord", name = "Fjordkjeller", city = "Oslo", type = "Club", cap = 400 }, -- fictional
			{ id = "no_nordlys", name = "Nordlys Scene", city = "Oslo", type = "Theatre", cap = 1700 }, -- fictional
			{ id = "no_spectrum", name = "Oslo Spectrum", city = "Oslo", type = "Arena", cap = 9700 }, -- Oslo Spektrum (concerts)
			{ id = "no_ullevall", name = "Ullevall Stadium", city = "Oslo", type = "Stadium", cap = 27182 }, -- Ullevaal Stadion
		},
	},
	{
		id = "dk", name = "Denmark", region = "EU", lat = 55.68, lon = 12.57,
		share = 0.025, priceLevel = 1.2, genres = { Indie = 1.1, Pop = 1.1 },
		venues = {
			{ id = "dk_hygge", name = "Hygge Klub", city = "Copenhagen", type = "Club", cap = 450 }, -- fictional
			{ id = "dk_vesterbro", name = "Vesterbro Hall", city = "Copenhagen", type = "Theatre", cap = 1500 }, -- fictional
			{ id = "dk_royal", name = "Royal Dome", city = "Copenhagen", type = "Arena", cap = 17000 }, -- Royal Arena
			{ id = "dk_parkland", name = "Parkland Stadium", city = "Copenhagen", type = "Stadium", cap = 38190 }, -- Parken
		},
	},
	{
		id = "pt", name = "Portugal", region = "EU", lat = 38.72, lon = -9.14,
		share = 0.03, priceLevel = 0.75, genres = { Latin = 1.1 },
		venues = {
			{ id = "pt_fado", name = "Fado Club", city = "Lisbon", type = "Club", cap = 350 }, -- fictional
			{ id = "pt_coliseum", name = "Coliseum Lisboa", city = "Lisbon", type = "Hall", cap = 4300 }, -- Coliseu dos Recreios
			{ id = "pt_meu", name = "MEU Arena", city = "Lisbon", type = "Arena", cap = 20100 }, -- MEO Arena
			{ id = "pt_lux", name = "Estadio da Lux", city = "Lisbon", type = "Stadium", cap = 68100 }, -- Estadio da Luz
		},
	},
	{
		id = "cz", name = "Czech Republic", region = "EU", lat = 50.08, lon = 14.44,
		share = 0.02, priceLevel = 0.7, genres = { Rock = 1.1, Metal = 1.1 },
		venues = {
			{ id = "cz_lucerna", name = "Lucerna Bar", city = "Prague", type = "Club", cap = 800 }, -- Lucerna Music Bar
			{ id = "cz_vltava", name = "Vltava Hall", city = "Prague", type = "Theatre", cap = 2800 }, -- fictional
			{ id = "cz_fortune", name = "Fortune Arena", city = "Prague", type = "Stadium", cap = 19370 }, -- Fortuna Arena
			{ id = "cz_o3", name = "O3 Arena Prague", city = "Prague", type = "Arena", cap = 20000 }, -- O2 Arena Prague
		},
	},
	-- ===================== NORTH AMERICA =====================
	{
		id = "us", name = "USA", region = "NA", lat = 39.5, lon = -98.35,
		share = 0.88, priceLevel = 1.25, genres = { Country = 1.25, ["Hip-Hop"] = 1.2, ["R&B"] = 1.15 },
		venues = {
			{ id = "us_bowery", name = "Bowery Ballhall", city = "New York", type = "Club", cap = 575 }, -- Bowery Ballroom
			{ id = "us_fillmoore", name = "The Fillmoore", city = "San Francisco", type = "Theatre", cap = 1315 }, -- The Fillmore
			{ id = "us_redstones", name = "Red Stones Amphitheatre", city = "Denver", type = "Amphitheatre", cap = 9525 }, -- Red Rocks
			{ id = "us_dish", name = "Hollywood Dish", city = "Los Angeles", type = "Amphitheatre", cap = 17500 }, -- Hollywood Bowl
			{ id = "us_orb", name = "The Orb", city = "Las Vegas", type = "Arena", cap = 17600 }, -- Sphere
			{ id = "us_cryptic", name = "Cryptic.com Arena", city = "Los Angeles", type = "Arena", cap = 20000 }, -- Crypto.com Arena
			{ id = "us_msg", name = "Madison Circle Garden", city = "New York", type = "Arena", cap = 22000 }, -- Madison Square Garden
			{ id = "us_sofa", name = "SoFa Stadium", city = "Los Angeles", type = "Stadium", cap = 70240 }, -- SoFi Stadium
			{ id = "us_metalife", name = "MetaLife Stadium", city = "New Jersey", type = "Stadium", cap = 82500 }, -- MetLife Stadium
			{ id = "us_1030", name = "10:30 Club", city = "Washington", type = "Club", cap = 1200 }, -- 9:30 Club
			{ id = "us_irving", name = "Irving Plazza", city = "New York", type = "Club", cap = 1200 }, -- Irving Plaza
			{ id = "us_brooklynsteal", name = "Brooklyn Steal", city = "New York", type = "Theatre", cap = 1800 }, -- Brooklyn Steel
			{ id = "us_wilturn", name = "The Wilturn", city = "Los Angeles", type = "Theatre", cap = 1850 }, -- The Wiltern
			{ id = "us_rymann", name = "Rymann Auditorium", city = "Nashville", type = "Theatre", cap = 2362 }, -- Ryman Auditorium
			{ id = "us_grecian", name = "Grecian Theatre", city = "Los Angeles", type = "Amphitheatre", cap = 5900 }, -- Greek Theatre
			{ id = "us_radiant", name = "Radiant City Music Hall", city = "New York", type = "Hall", cap = 5960 }, -- Radio City Music Hall
			{ id = "us_gorge", name = "The Gorgeous Amphitheatre", city = "George, WA", type = "Amphitheatre", cap = 27500 }, -- The Gorge
			{ id = "us_chess", name = "Chess Center", city = "San Francisco", type = "Arena", cap = 19500 }, -- Chase Center
			{ id = "us_tbgarden", name = "TB Garden", city = "Boston", type = "Arena", cap = 20000 }, -- TD Garden
			{ id = "us_barclay", name = "Barclay Center", city = "Brooklyn", type = "Arena", cap = 20000 }, -- Barclays Center
			{ id = "us_unity", name = "Unity Center", city = "Chicago", type = "Arena", cap = 23500 }, -- United Center
			{ id = "us_soldier", name = "Soldier Fields", city = "Chicago", type = "Stadium", cap = 62500 }, -- Soldier Field
			{ id = "us_gillett", name = "Gillett Stadium", city = "Foxborough", type = "Stadium", cap = 64628 }, -- Gillette Stadium
			{ id = "us_mercedos", name = "Mercedos Stadium", city = "Atlanta", type = "Stadium", cap = 71000 }, -- Mercedes-Benz Stadium
			{ id = "us_atd", name = "AT&D Stadium", city = "Dallas", type = "Stadium", cap = 80000 }, -- AT&T Stadium
		},
	},
	{
		id = "ca", name = "Canada", region = "NA", lat = 55.0, lon = -105.0,
		share = 0.12, priceLevel = 1.05, genres = { Country = 1.1, Indie = 1.1 },
		venues = {
			{ id = "ca_maple", name = "The Maple Basement", city = "Toronto", type = "Club", cap = 350 },
			{ id = "ca_mossy", name = "Mossy Hall", city = "Toronto", type = "Theatre", cap = 2752 }, -- Massey Hall
			{ id = "ca_scotch", name = "Scotchbank Arena", city = "Toronto", type = "Arena", cap = 19800 }, -- Scotiabank Arena
			{ id = "ca_rodgers", name = "Rodgers Centre", city = "Toronto", type = "Stadium", cap = 55000 }, -- Rogers Centre
			{ id = "ca_commodore", name = "Commodore Hall", city = "Vancouver", type = "Club", cap = 990 }, -- Commodore Ballroom
			{ id = "ca_danforth", name = "Danforth Hall", city = "Toronto", type = "Theatre", cap = 1427 }, -- Danforth Music Hall
			{ id = "ca_rogue", name = "Rogue Arena", city = "Vancouver", type = "Arena", cap = 19000 }, -- Rogers Arena
			{ id = "ca_bell", name = "Bell Center", city = "Montreal", type = "Arena", cap = 19200 }, -- Bell Centre
			{ id = "ca_bcplaza", name = "BC Plaza", city = "Vancouver", type = "Stadium", cap = 54500 }, -- BC Place
			{ id = "ca_olympicdome", name = "Olympic Dome", city = "Montreal", type = "Stadium", cap = 56040 }, -- Olympic Stadium Montreal
		},
	},
	-- ===================== LATIN AMERICA =====================
	{
		id = "mx", name = "Mexico", region = "LATAM", lat = 19.43, lon = -99.13,
		share = 0.292, priceLevel = 0.60, genres = { Latin = 1.35, Rock = 1.1 },
		venues = {
			{ id = "mx_calavera", name = "Club Calavera", city = "Mexico City", type = "Club", cap = 500 },
			{ id = "mx_palace", name = "Palace of Sports", city = "Mexico City", type = "Arena", cap = 20000 }, -- Palacio de los Deportes
			{ id = "mx_arena", name = "Arena MXC", city = "Mexico City", type = "Arena", cap = 22300 }, -- Arena CDMX
			{ id = "mx_gpn", name = "Estadio GPN", city = "Mexico City", type = "Stadium", cap = 65000 }, -- Estadio GNP Seguros
			{ id = "mx_plata", name = "Teatro Plata", city = "Mexico City", type = "Theatre", cap = 3000 }, -- fictional
			{ id = "mx_nacional", name = "National Auditorium", city = "Mexico City", type = "Hall", cap = 9366 }, -- Auditorio Nacional
			{ id = "mx_monterey", name = "Arena Monterey", city = "Monterrey", type = "Arena", cap = 17599 }, -- Arena Monterrey
			{ id = "mx_aztek", name = "Estadio Aztek", city = "Mexico City", type = "Stadium", cap = 87523 }, -- Estadio Azteca
		},
	},
	{
		id = "br", name = "Brazil", region = "LATAM", lat = -23.55, lon = -46.63,
		share = 0.277, priceLevel = 0.55, genres = { Latin = 1.15, Metal = 1.2 },
		venues = {
			{ id = "br_samba", name = "Clube Samba Azul", city = "Sao Paulo", type = "Club", cap = 600 },
			{ id = "br_neobank", name = "Neobank Park", city = "Sao Paulo", type = "Stadium", cap = 55000 }, -- Allianz/Nubank Parque
			{ id = "br_maracanoo", name = "Maracanoo Stadium", city = "Rio de Janeiro", type = "Stadium", cap = 73139 }, -- Maracana
			{ id = "br_unimedi", name = "Espaco Unimedi", city = "Sao Paulo", type = "Hall", cap = 8000 }, -- Espaco Unimed
			{ id = "br_ibira", name = "Ibirapuera Gym", city = "Sao Paulo", type = "Arena", cap = 10200 }, -- Ginasio do Ibirapuera
			{ id = "br_farma", name = "Farma Arena", city = "Rio de Janeiro", type = "Arena", cap = 18768 }, -- Farmasi Arena
			{ id = "br_morumbo", name = "Morumbo Stadium", city = "Sao Paulo", type = "Stadium", cap = 66795 }, -- Morumbi
			{ id = "br_engenhao", name = "Engenhao Park", city = "Rio de Janeiro", type = "Stadium", cap = 70000 }, -- Estadio Nilton Santos (concerts)
		},
	},
	{
		id = "ar", name = "Argentina", region = "LATAM", lat = -34.6, lon = -58.38,
		share = 0.161, priceLevel = 0.45, genres = { Rock = 1.2, Latin = 1.2 },
		venues = {
			{ id = "ar_tango", name = "Club Tango Rojo", city = "Buenos Aires", type = "Club", cap = 450 },
			{ id = "ar_luna", name = "Luna Parque", city = "Buenos Aires", type = "Hall", cap = 8400 }, -- Luna Park
			{ id = "ar_movistor", name = "Movistor Arena BA", city = "Buenos Aires", type = "Arena", cap = 15000 }, -- Movistar Arena
			{ id = "ar_monumental", name = "Monumental River Stadium", city = "Buenos Aires", type = "Stadium", cap = 85018 }, -- Estadio Monumental
			{ id = "ar_obras", name = "Obras Stadium", city = "Buenos Aires", type = "Hall", cap = 4700 }, -- Estadio Obras
			{ id = "ar_velez", name = "Velez Stadium", city = "Buenos Aires", type = "Stadium", cap = 49540 }, -- Jose Amalfitani
			{ id = "ar_unico", name = "Estadio Unico", city = "La Plata", type = "Stadium", cap = 53000 }, -- Estadio Unico
			{ id = "ar_bombonero", name = "La Bombonero", city = "Buenos Aires", type = "Stadium", cap = 58305 }, -- La Bombonera
		},
	},
	{
		id = "cl", name = "Chile", region = "LATAM", lat = -33.45, lon = -70.67,
		share = 0.12, priceLevel = 0.6, genres = { Latin = 1.1, Rock = 1.1 },
		venues = {
			{ id = "cl_andes", name = "Club Andes", city = "Santiago", type = "Club", cap = 500 }, -- fictional
			{ id = "cl_cordillera", name = "Teatro Cordillera", city = "Santiago", type = "Theatre", cap = 4000 }, -- fictional
			{ id = "cl_arena", name = "Arena Santiago", city = "Santiago", type = "Arena", cap = 15000 }, -- fictional
			{ id = "cl_nacional", name = "Estadio Nacional Chile", city = "Santiago", type = "Stadium", cap = 48745 }, -- Estadio Nacional
		},
	},
	{
		id = "co", name = "Colombia", region = "LATAM", lat = 4.71, lon = -74.07,
		share = 0.15, priceLevel = 0.55, genres = { Latin = 1.3 },
		venues = {
			{ id = "co_salsa", name = "Club Salsa Roja", city = "Bogota", type = "Club", cap = 600 }, -- fictional
			{ id = "co_teatro", name = "Teatro Bogota Live", city = "Bogota", type = "Theatre", cap = 3000 }, -- fictional
			{ id = "co_movistor", name = "Movistor Arena Bogota", city = "Bogota", type = "Arena", cap = 14000 }, -- Movistar Arena Bogota
			{ id = "co_campin", name = "Estadio El Campin", city = "Bogota", type = "Stadium", cap = 39512 }, -- Estadio El Campin
		},
	},
	-- ===================== ASIA =====================
	{
		id = "jp", name = "Japan", region = "ASIA", lat = 35.68, lon = 139.69,
		share = 0.286, priceLevel = 1.05, genres = { ["K-Pop"] = 1.2, Rock = 1.15, Metal = 1.1 },
		venues = {
			{ id = "jp_komori", name = "Live House Komori", city = "Tokyo", type = "Club", cap = 300 },
			{ id = "jp_budokon", name = "Nippon Budokon", city = "Tokyo", type = "Arena", cap = 14471 }, -- Nippon Budokan
			{ id = "jp_saitama", name = "Saitama Mega Arena", city = "Saitama", type = "Arena", cap = 36500 }, -- Saitama Super Arena
			{ id = "jp_tokio", name = "Tokio Dome", city = "Tokyo", type = "Stadium", cap = 55000 }, -- Tokyo Dome
			{ id = "jp_starhall", name = "Shibuya Starhall", city = "Tokyo", type = "Theatre", cap = 2500 }, -- fictional
			{ id = "jp_castle", name = "Osaka Castle Hall", city = "Osaka", type = "Arena", cap = 16000 }, -- Osaka-jo Hall
			{ id = "jp_yokohoma", name = "Yokohoma Arena", city = "Yokohama", type = "Arena", cap = 17000 }, -- Yokohama Arena
			{ id = "jp_kyocero", name = "Kyocero Dome", city = "Osaka", type = "Stadium", cap = 55000 }, -- Kyocera Dome
			{ id = "jp_nisson", name = "Nisson Stadium", city = "Yokohama", type = "Stadium", cap = 72327 }, -- Nissan Stadium
		},
	},
	{
		id = "kr", name = "South Korea", region = "ASIA", lat = 37.57, lon = 126.98,
		share = 0.234, priceLevel = 0.95, genres = { ["K-Pop"] = 1.4, ["R&B"] = 1.1 },
		venues = {
			{ id = "kr_byeol", name = "Club Byeol", city = "Seoul", type = "Club", cap = 400 },
			{ id = "kr_kspa", name = "KSPA Dome", city = "Seoul", type = "Arena", cap = 15000 }, -- KSPO Dome
			{ id = "kr_gocheok", name = "Gocheok Cloud Dome", city = "Seoul", type = "Arena", cap = 25000 }, -- Gocheok Sky Dome
			{ id = "kr_olympia", name = "Seoul Olympia Stadium", city = "Seoul", type = "Stadium", cap = 65599 }, -- Seoul Olympic Stadium
			{ id = "kr_hongdae", name = "Hongdae Live Hall", city = "Seoul", type = "Theatre", cap = 2000 }, -- fictional
			{ id = "kr_jamsil", name = "Jamsil Hall", city = "Seoul", type = "Arena", cap = 11069 }, -- Jamsil Arena
			{ id = "kr_inspyre", name = "Inspyre Arena", city = "Incheon", type = "Arena", cap = 15000 }, -- Inspire Arena
			{ id = "kr_busan", name = "Busan Asian Stadium", city = "Busan", type = "Stadium", cap = 53769 }, -- Busan Asiad
			{ id = "kr_worldcup", name = "Seoul Cup Stadium", city = "Seoul", type = "Stadium", cap = 66704 }, -- Seoul World Cup Stadium
		},
	},
	{
		id = "in", name = "India", region = "ASIA", lat = 28.61, lon = 77.21,
		share = 0.25, priceLevel = 0.5, genres = { Pop = 1.1, EDM = 1.1 },
		venues = {
			{ id = "in_bandra", name = "Bandra Base", city = "Mumbai", type = "Club", cap = 500 }, -- fictional
			{ id = "in_patel", name = "Patel Indoor Stadium", city = "Mumbai", type = "Hall", cap = 6000 }, -- NSCI Dome
			{ id = "in_dypatel", name = "DY Patel Stadium", city = "Mumbai", type = "Stadium", cap = 45300 }, -- DY Patil Stadium
			{ id = "in_jln", name = "JLN Stadium Delhi", city = "New Delhi", type = "Stadium", cap = 60254 }, -- Jawaharlal Nehru Stadium
		},
	},
	{
		id = "ph", name = "Philippines", region = "ASIA", lat = 14.6, lon = 120.98,
		share = 0.1, priceLevel = 0.55, genres = { ["K-Pop"] = 1.2, Pop = 1.2 },
		venues = {
			{ id = "ph_groove", name = "Manila Groove", city = "Manila", type = "Club", cap = 500 }, -- fictional
			{ id = "ph_araneto", name = "Araneto Coliseum", city = "Quezon City", type = "Arena", cap = 9679 }, -- Araneta Coliseum (concerts)
			{ id = "ph_moa", name = "Mall of Asia Dome", city = "Pasay", type = "Arena", cap = 20000 }, -- SM Mall of Asia Arena
			{ id = "ph_philippino", name = "Philippino Arena", city = "Bocaue", type = "Stadium", cap = 55000 }, -- Philippine Arena
		},
	},
	{
		id = "sg", name = "Singapore", region = "ASIA", lat = 1.35, lon = 103.82,
		share = 0.05, priceLevel = 1.2, genres = { ["K-Pop"] = 1.1, EDM = 1.1 },
		venues = {
			{ id = "sg_marina", name = "Marina Club", city = "Singapore", type = "Club", cap = 600 }, -- fictional
			{ id = "sg_starlight", name = "Starlight Theatre", city = "Singapore", type = "Theatre", cap = 5000 }, -- The Star Theatre
			{ id = "sg_indoor", name = "Singapore Indoor Arena", city = "Singapore", type = "Arena", cap = 9000 }, -- Singapore Indoor Stadium (concerts)
			{ id = "sg_singapura", name = "Singapura Stadium", city = "Singapore", type = "Stadium", cap = 55000 }, -- National Stadium
		},
	},
	{
		id = "th", name = "Thailand", region = "ASIA", lat = 13.76, lon = 100.5,
		share = 0.08, priceLevel = 0.5, genres = { ["K-Pop"] = 1.2 },
		venues = {
			{ id = "th_neon", name = "Bangkok Neon Club", city = "Bangkok", type = "Club", cap = 500 }, -- fictional
			{ id = "th_siam", name = "Siam Live Hall", city = "Bangkok", type = "Theatre", cap = 3000 }, -- fictional
			{ id = "th_impakt", name = "Impakt Arena", city = "Bangkok", type = "Arena", cap = 12000 }, -- Impact Arena
			{ id = "th_rajamangla", name = "Rajamangla Stadium", city = "Bangkok", type = "Stadium", cap = 51560 }, -- Rajamangala Stadium
		},
	},
	-- ===================== OCEANIA =====================
	{
		id = "au", name = "Australia", region = "OCE", lat = -33.87, lon = 151.21,
		share = 0.85, priceLevel = 1.10, genres = { Rock = 1.15, Country = 1.1, EDM = 1.1 },
		venues = {
			{ id = "au_roo", name = "The Kangaroo Lounge", city = "Sydney", type = "Club", cap = 400 },
			{ id = "au_opra", name = "Sydney Opra House", city = "Sydney", type = "Hall", cap = 2679 }, -- Sydney Opera House (Concert Hall)
			{ id = "au_lever", name = "Rod Lever Arena", city = "Melbourne", type = "Arena", cap = 14820 }, -- Rod Laver Arena
			{ id = "au_austral", name = "Stadium Austral", city = "Sydney", type = "Stadium", cap = 83000 }, -- Stadium Australia
			{ id = "au_mcc", name = "MCC Ground", city = "Melbourne", type = "Stadium", cap = 100024 }, -- Melbourne Cricket Ground
			{ id = "au_enmoore", name = "Enmoore Theatre", city = "Sydney", type = "Theatre", cap = 2500 }, -- Enmore Theatre
			{ id = "au_hordern", name = "Hordern Hall", city = "Sydney", type = "Hall", cap = 5500 }, -- Hordern Pavilion
			{ id = "au_brisbane", name = "Brisbane Show Centre", city = "Brisbane", type = "Arena", cap = 14500 }, -- Brisbane Entertainment Centre
			{ id = "au_kudos", name = "Kudos Bank Arena", city = "Sydney", type = "Arena", cap = 21032 }, -- Qudos Bank Arena
			{ id = "au_langparc", name = "Lang Parc", city = "Brisbane", type = "Stadium", cap = 52500 }, -- Lang Park
			{ id = "au_marble", name = "Marble Stadium", city = "Melbourne", type = "Stadium", cap = 56347 }, -- Marvel Stadium
			{ id = "au_optimus", name = "Optimus Stadium", city = "Perth", type = "Stadium", cap = 75000 }, -- Perth Stadium (concerts)
		},
	},
	{
		id = "nz", name = "New Zealand", region = "OCE", lat = -36.85, lon = 174.76,
		share = 0.15, priceLevel = 1.0, genres = { Indie = 1.1, Rock = 1.1 },
		venues = {
			{ id = "nz_kiwi", name = "Kiwi Basement", city = "Auckland", type = "Club", cap = 400 }, -- fictional
			{ id = "nz_harbour", name = "Harbour Theatre", city = "Auckland", type = "Theatre", cap = 2000 }, -- fictional
			{ id = "nz_sparky", name = "Sparky Arena", city = "Auckland", type = "Arena", cap = 13280 }, -- Spark Arena
			{ id = "nz_edan", name = "Edan Park", city = "Auckland", type = "Stadium", cap = 50000 }, -- Eden Park
		},
	},
	-- ===================== MIDDLE EAST & AFRICA =====================
	{
		id = "ae", name = "UAE", region = "MEA", lat = 25.2, lon = 55.27,
		share = 0.45, priceLevel = 1.15, genres = { Pop = 1.1, EDM = 1.1 },
		venues = {
			{ id = "ae_rose", name = "Desert Rose Club", city = "Dubai", type = "Club", cap = 500 },
			{ id = "ae_cola", name = "Cola-Coca Arena", city = "Dubai", type = "Arena", cap = 17000 }, -- Coca-Cola Arena
			{ id = "ae_opra", name = "Dubai Opra", city = "Dubai", type = "Hall", cap = 2000 }, -- Dubai Opera
			{ id = "ae_etihat", name = "Etihat Arena", city = "Abu Dhabi", type = "Arena", cap = 18000 }, -- Etihad Arena
			{ id = "ae_zayid", name = "Zayid Stadium", city = "Abu Dhabi", type = "Stadium", cap = 44260 }, -- Zayed Sports City Stadium
		},
	},
	{
		id = "za", name = "South Africa", region = "MEA", lat = -26.2, lon = 28.05,
		share = 0.55, priceLevel = 0.50, genres = { ["Hip-Hop"] = 1.2, EDM = 1.1 },
		venues = {
			{ id = "za_jacaranda", name = "The Jacaranda Room", city = "Johannesburg", type = "Club", cap = 450 },
			{ id = "za_fnc", name = "FNC Stadium", city = "Johannesburg", type = "Stadium", cap = 94736 }, -- FNB Stadium
			{ id = "za_soweto", name = "Soweto Hall", city = "Johannesburg", type = "Hall", cap = 3000 }, -- fictional
			{ id = "za_jozi", name = "Jozi Dome", city = "Johannesburg", type = "Arena", cap = 10000 }, -- fictional
			{ id = "za_loftus", name = "Loftus Stadium", city = "Pretoria", type = "Stadium", cap = 51762 }, -- Loftus Versfeld
			{ id = "za_capepoint", name = "Cape Point Stadium", city = "Cape Town", type = "Stadium", cap = 55000 }, -- Cape Town Stadium
			{ id = "za_mabida", name = "Moses Mabida Stadium", city = "Durban", type = "Stadium", cap = 55500 }, -- Moses Mabhida
			{ id = "za_elis", name = "Elis Park", city = "Johannesburg", type = "Stadium", cap = 62567 }, -- Ellis Park
		},
	},
}

Countries.byId = {}
Countries.venueById = {}
for _, c in ipairs(Countries.list) do
	table.sort(c.venues, function(a, b)
		return a.cap < b.cap
	end)
	Countries.byId[c.id] = c
	for _, v in ipairs(c.venues) do
		v.countryId = c.id
		Countries.venueById[v.id] = v
	end
end

-- Travel between shows (GS.travelGap): neighbours share a land border or a fixed link
-- (Channel Tunnel UK-France, Oresund Bridge Denmark-Sweden). Continents for long trips.
Countries.NEIGHBOURS = {
	uk = { "ie", "fr" },
	ie = { "uk" },
	fr = { "uk", "be", "de", "ch", "it", "es" },
	nl = { "be", "de" },
	de = { "nl", "be", "fr", "ch", "at", "cz", "pl", "dk" },
	ch = { "fr", "de", "at", "it" },
	it = { "fr", "ch", "at" },
	es = { "fr", "pt" },
	se = { "no", "dk" },
	be = { "fr", "nl", "de" },
	at = { "de", "ch", "it", "cz" },
	pl = { "de", "cz" },
	no = { "se" },
	dk = { "de", "se" },
	pt = { "es" },
	cz = { "de", "at", "pl" },
	us = { "ca", "mx" },
	ca = { "us" },
	mx = { "us" },
	br = { "ar", "co" },
	ar = { "br", "cl" },
	cl = { "ar" },
	co = { "br" },
}
Countries.CONTINENT = {
	uk = "Europe", ie = "Europe", fr = "Europe", nl = "Europe", de = "Europe", ch = "Europe", it = "Europe", es = "Europe",
	se = "Europe", be = "Europe", at = "Europe", pl = "Europe", no = "Europe", dk = "Europe", pt = "Europe", cz = "Europe",
	us = "North America", ca = "North America", mx = "North America",
	br = "South America", ar = "South America", cl = "South America", co = "South America",
	jp = "Asia", kr = "Asia", ["in"] = "Asia", ph = "Asia", sg = "Asia", th = "Asia", ae = "Asia",
	au = "Oceania", nz = "Oceania",
	za = "Africa",
}
Countries.neighbourSet = {}
for id, list in pairs(Countries.NEIGHBOURS) do
	Countries.neighbourSet[id] = {}
	for _, n in ipairs(list) do
		Countries.neighbourSet[id][n] = true
	end
end

-- travel days between two countries: 0 = same country or a neighbour, 1 = same continent, 2 = another continent
function Countries.travelDays(a, b)
	if a == b or (Countries.neighbourSet[a] and Countries.neighbourSet[a][b]) then
		return 0
	end
	if Countries.CONTINENT[a] and Countries.CONTINENT[a] == Countries.CONTINENT[b] then
		return 1
	end
	return 2
end

return Countries
