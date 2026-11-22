-- Goals with a money reward (the harder, the more). Checked after every day, show and tour.
-- stat = what is measured (GS.achievementStats), goal = the value to reach (rank: at most this place).
local Achievements = {
	list = {
		-- first steps
		{ id = "first_show", name = "Opening Night", desc = "Play your first show.", stat = "shows", goal = 1, reward = 5000 },
		{ id = "first_sellout", name = "SOLD OUT!", desc = "Sell out any venue.", stat = "sellouts", goal = 1, reward = 10000 },
		{ id = "first_tour", name = "On the Road", desc = "Finish your first tour.", stat = "toursDone", goal = 1, reward = 15000 },
		{ id = "five_stars", name = "Five Stars", desc = "Get a 5-star review.", stat = "fiveStars", goal = 1, reward = 20000 },
		{ id = "second_artist", name = "Growing Family", desc = "Have 2 artists signed.", stat = "signed", goal = 2, reward = 20000 },
		-- venues
		{ id = "theatre_sellout", name = "Theatre Kid", desc = "Sell out a venue with 2,500+ capacity.", stat = "biggestSellout", goal = 2500, reward = 40000 },
		{ id = "arena_sellout", name = "Arena Ready", desc = "Sell out a venue with 10,000+ capacity.", stat = "biggestSellout", goal = 10000, reward = 150000 },
		{ id = "stadium_sellout", name = "Stadium Status", desc = "Sell out a venue with 40,000+ capacity.", stat = "biggestSellout", goal = 40000, reward = 750000 },
		{ id = "mega_sellout", name = "Wemblee Magic", desc = "Sell out a venue with 80,000+ capacity.", stat = "biggestSellout", goal = 80000, reward = 2500000 },
		-- shows and sell-outs
		{ id = "shows_10", name = "Ten Nights", desc = "Play 10 shows.", stat = "shows", goal = 10, reward = 25000 },
		{ id = "shows_50", name = "Road Warriors", desc = "Play 50 shows.", stat = "shows", goal = 50, reward = 150000 },
		{ id = "shows_200", name = "Never Off Stage", desc = "Play 200 shows.", stat = "shows", goal = 200, reward = 1000000 },
		{ id = "sellouts_10", name = "Hot Ticket", desc = "Sell out 10 shows.", stat = "sellouts", goal = 10, reward = 75000 },
		{ id = "sellouts_50", name = "Unstoppable", desc = "Sell out 50 shows.", stat = "sellouts", goal = 50, reward = 500000 },
		{ id = "sellouts_150", name = "Sold Out Everywhere", desc = "Sell out 150 shows.", stat = "sellouts", goal = 150, reward = 2500000 },
		{ id = "fivestars_10", name = "Critics' Darling", desc = "Get 10 five-star reviews.", stat = "fiveStars", goal = 10, reward = 200000 },
		{ id = "fivestars_50", name = "Legendary Shows", desc = "Get 50 five-star reviews.", stat = "fiveStars", goal = 50, reward = 1500000 },
		-- tickets
		{ id = "tickets_10k", name = "Ten Thousand Fans", desc = "Sell 10,000 tickets.", stat = "tickets", goal = 10000, reward = 30000 },
		{ id = "tickets_100k", name = "A Small City", desc = "Sell 100,000 tickets.", stat = "tickets", goal = 100000, reward = 200000 },
		{ id = "tickets_1m", name = "Million Tickets", desc = "Sell 1,000,000 tickets.", stat = "tickets", goal = 1000000, reward = 2000000 },
		{ id = "tickets_10m", name = "A Whole Country", desc = "Sell 10,000,000 tickets.", stat = "tickets", goal = 10000000, reward = 15000000 },
		-- tours and money
		{ id = "tours_5", name = "Tour Machine", desc = "Finish 5 tours.", stat = "toursDone", goal = 5, reward = 150000 },
		{ id = "tours_20", name = "Tour Empire", desc = "Finish 20 tours.", stat = "toursDone", goal = 20, reward = 1500000 },
		{ id = "tour_1m", name = "Millionaire Tour", desc = "Finish a tour grossing $1M+.", stat = "bestTourGross", goal = 1000000, reward = 100000 },
		{ id = "tour_10m", name = "Big Business", desc = "Finish a tour grossing $10M+.", stat = "bestTourGross", goal = 10000000, reward = 750000 },
		{ id = "tour_100m", name = "Mega Tour", desc = "Finish a tour grossing $100M+.", stat = "bestTourGross", goal = 100000000, reward = 6000000 },
		{ id = "gross_1b", name = "Billion Dollar Label", desc = "Earn $1B from tickets in total.", stat = "totalGross", goal = 1000000000, reward = 25000000 },
		{ id = "rich", name = "Label Mogul", desc = "Have $10M in the bank.", stat = "money", goal = 10000000, reward = 500000 },
		{ id = "rich_100m", name = "Money Vault", desc = "Have $100M in the bank.", stat = "money", goal = 100000000, reward = 5000000 },
		-- the world
		{ id = "world_tour", name = "World Tour", desc = "Play 4+ regions in a single tour.", stat = "maxRegions", goal = 4, reward = 400000 },
		{ id = "countries_5", name = "Passport Stamps", desc = "Play shows in 5 countries.", stat = "countries", goal = 5, reward = 60000 },
		{ id = "countries_15", name = "Frequent Flyers", desc = "Play shows in 15 countries.", stat = "countries", goal = 15, reward = 400000 },
		{ id = "countries_30", name = "Around the World", desc = "Play shows in 30 countries.", stat = "countries", goal = 30, reward = 2000000 },
		-- the label
		{ id = "artists_5", name = "Talent Scout", desc = "Have 5 artists signed.", stat = "signed", goal = 5, reward = 250000 },
		{ id = "artists_10", name = "Star Factory", desc = "Have 10 artists signed.", stat = "signed", goal = 10, reward = 1500000 },
		{ id = "level_5", name = "Big League", desc = "Reach label level 5.", stat = "level", goal = 5, reward = 500000 },
		{ id = "level_10", name = "Global Powerhouse", desc = "Reach label level 10.", stat = "level", goal = 10, reward = 10000000 },
		{ id = "superstar", name = "Superstar Signing", desc = "Sign Nova Ray.", stat = "nova", goal = 1, reward = 1000000 },
		-- the stage builder
		{ id = "stages_3", name = "Set Designer", desc = "Have 3 stages of your own.", stat = "designs", goal = 3, reward = 30000 },
		{ id = "big_stage", name = "Production Value", desc = "Build a stage with 100+ pieces.", stat = "biggestStage", goal = 100, reward = 300000 },
		-- the charts
		{ id = "chart_top10", name = "Top 10", desc = "Get a tour into the Top 10 grossing chart.", stat = "rank", goal = 10, reward = 300000 },
		{ id = "chart_1", name = "Number One", desc = "Have the #1 grossing tour of all time.", stat = "rank", goal = 1, reward = 8000000 },
	},
	byId = {},
}
for _, a in ipairs(Achievements.list) do
	Achievements.byId[a.id] = a
end
return Achievements
