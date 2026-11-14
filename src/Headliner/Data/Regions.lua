-- World regions. Artists have a fan count per region.
local Regions = {
	list = {
		{ id = "EU", name = "Europe" },
		{ id = "NA", name = "North America" },
		{ id = "LATAM", name = "Latin America" },
		{ id = "ASIA", name = "Asia" },
		{ id = "OCE", name = "Oceania" },
		{ id = "MEA", name = "Middle East & Africa" },
	},
	byId = {},
}

for _, r in ipairs(Regions.list) do
	Regions.byId[r.id] = r
end

return Regions
