-- Background dancers you can sign for your label (Laptop: EXTRAS). They dance with solo artists in halls,
-- arenas and stadiums (not in clubs), cost a fee per show and get better with every show (or with training).
-- fee = signing fee, perShow = what one show costs, skill = 0..100 (better = better reviews)
local Dancers = {}

Dancers.list = {
	{ id = "d_mika", name = "Mika Sol", style = "Hip-Hop", skill = 42, fee = 6000, perShow = 900, look = { skin = 2, hair = "messy", hairColor = { 30, 22, 18 }, top = { 240, 240, 245 }, pants = { 30, 30, 36 } } },
	{ id = "d_ines", name = "Ines Vale", style = "Contemporary", skill = 48, fee = 8000, perShow = 1000, look = { skin = 1, hair = "bun", hairColor = { 120, 70, 40 }, top = { 30, 30, 36 }, pants = { 30, 30, 36 } } },
	{ id = "d_theo", name = "Theo Park", style = "K-Pop", skill = 55, fee = 12000, perShow = 1300, look = { skin = 3, hair = "short", hairColor = { 20, 20, 20 }, top = { 250, 250, 255 }, pants = { 230, 230, 236 } } },
	{ id = "d_lux", name = "Lux Romero", style = "Latin", skill = 50, fee = 9000, perShow = 1100, look = { skin = 4, hair = "long", hairColor = { 40, 26, 18 }, top = { 220, 40, 60 }, pants = { 30, 30, 36 } } },
	{ id = "d_juno", name = "Jun Okafor", style = "Street", skill = 38, fee = 5000, perShow = 800, look = { skin = 5, hair = "buzz", hairColor = { 20, 20, 20 }, top = { 255, 200, 40 }, pants = { 40, 50, 90 } } },
	{ id = "d_cleo", name = "Cleo Hart", style = "Jazz", skill = 60, fee = 15000, perShow = 1500, look = { skin = 1, hair = "pony", hairColor = { 230, 200, 120 }, top = { 30, 30, 36 }, pants = { 30, 30, 36 } } },
	{ id = "d_rafa", name = "Rafa Lima", style = "Latin", skill = 64, fee = 18000, perShow = 1700, look = { skin = 3, hair = "short", hairColor = { 30, 22, 18 }, top = { 250, 250, 255 }, pants = { 30, 30, 36 } } },
	{ id = "d_yuna", name = "Yuna Seo", style = "K-Pop", skill = 70, fee = 25000, perShow = 2100, look = { skin = 2, hair = "long", hairColor = { 20, 20, 20 }, top = { 255, 120, 190 }, pants = { 240, 240, 245 } } },
	{ id = "d_omar", name = "Omar Reyes", style = "Hip-Hop", skill = 66, fee = 20000, perShow = 1900, look = { skin = 4, hair = "afro", hairColor = { 30, 22, 18 }, top = { 30, 30, 36 }, pants = { 200, 40, 40 } } },
	{ id = "d_nell", name = "Nell Price", style = "Contemporary", skill = 74, fee = 32000, perShow = 2400, look = { skin = 1, hair = "long", hairColor = { 170, 90, 40 }, top = { 240, 240, 245 }, pants = { 240, 240, 245 } } },
	{ id = "d_kai", name = "Kai Brandt", style = "Street", skill = 58, fee = 14000, perShow = 1400, look = { skin = 2, hair = "mohawk", hairColor = { 230, 40, 60 }, top = { 30, 30, 36 }, pants = { 30, 30, 36 } } },
	{ id = "d_zara", name = "Zara Moon", style = "Jazz", skill = 78, fee = 40000, perShow = 2800, look = { skin = 5, hair = "bun", hairColor = { 30, 22, 18 }, top = { 200, 160, 60 }, pants = { 30, 30, 36 } } },
	{ id = "d_leo", name = "Leo Martin", style = "Contemporary", skill = 45, fee = 7000, perShow = 950, look = { skin = 1, hair = "short", hairColor = { 200, 160, 90 }, top = { 90, 120, 200 }, pants = { 30, 30, 36 } } },
	{ id = "d_ami", name = "Ami Tanaka", style = "K-Pop", skill = 82, fee = 50000, perShow = 3200, look = { skin = 2, hair = "pigtails", hairColor = { 40, 30, 26 }, top = { 250, 250, 255 }, pants = { 30, 30, 36 } } },
	{ id = "d_sky", name = "Sky Bennett", style = "Hip-Hop", skill = 52, fee = 10000, perShow = 1200, look = { skin = 3, hair = "messy", hairColor = { 90, 60, 40 }, top = { 60, 200, 120 }, pants = { 30, 30, 36 } } },
	{ id = "d_vic", name = "Vic Duarte", style = "Latin", skill = 86, fee = 65000, perShow = 3800, look = { skin = 4, hair = "long", hairColor = { 20, 20, 20 }, top = { 30, 30, 36 }, pants = { 30, 30, 36 } } },
}
Dancers.byId = {}
for _, d in ipairs(Dancers.list) do
	Dancers.byId[d.id] = d
end
Dancers.MAX_SIGNED = 12
Dancers.TRAIN_DAYS = 5 -- in training: not on tour for these days
Dancers.TRAIN_GAIN = 6 -- skill per training
Dancers.SHOW_GAIN = 0.5 -- skill per show
-- what a training costs (the better the dancer, the dearer)
function Dancers.trainCost(skill)
	return math.floor((2000 + (skill or 40) * 120) / 100) * 100
end

return Dancers
