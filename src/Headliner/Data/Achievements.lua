-- Goals. Checked after every show / tour.
local Achievements = {
	list = {
		{ id = "first_show", name = "Opening Night", desc = "Play your first show." },
		{ id = "first_sellout", name = "SOLD OUT!", desc = "Sell out any venue." },
		{ id = "theatre_sellout", name = "Theatre Kid", desc = "Sell out a venue with 2,500+ capacity." },
		{ id = "arena_sellout", name = "Arena Ready", desc = "Sell out a venue with 10,000+ capacity." },
		{ id = "stadium_sellout", name = "Stadium Status", desc = "Sell out a venue with 40,000+ capacity." },
		{ id = "mega_sellout", name = "Wemblee Magic", desc = "Sell out a venue with 80,000+ capacity." },
		{ id = "five_stars", name = "Five Stars", desc = "Get a 5-star review." },
		{ id = "sellouts_10", name = "Hot Ticket", desc = "Sell out 10 shows." },
		{ id = "sellouts_50", name = "Unstoppable", desc = "Sell out 50 shows." },
		{ id = "tour_1m", name = "Millionaire Tour", desc = "Finish a tour grossing $1M+." },
		{ id = "tour_10m", name = "Big Business", desc = "Finish a tour grossing $10M+." },
		{ id = "tour_100m", name = "Mega Tour", desc = "Finish a tour grossing $100M+." },
		{ id = "world_tour", name = "World Tour", desc = "Play 4+ regions in a single tour." },
		{ id = "chart_top10", name = "Top 10", desc = "Get a tour into the Top 10 grossing chart." },
		{ id = "chart_1", name = "Number One", desc = "Have the #1 grossing tour of all time." },
		{ id = "rich", name = "Label Mogul", desc = "Have $10M in the bank." },
		{ id = "superstar", name = "Superstar Signing", desc = "Sign Nova Ray." },
	},
	byId = {},
}
for _, a in ipairs(Achievements.list) do
	Achievements.byId[a.id] = a
end
return Achievements
