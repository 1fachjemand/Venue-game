-- Generates fan posts for the SOCIAL feed. Pure Lua (no Roblox APIs).
local Root = script:FindFirstAncestor("Headliner")
local Data = require(Root.Data.Social)
local Countries = require(Root.Data.Countries)
local Artists = require(Root.Data.Artists)
local Util = require(Root.Logic.Util)

local Social = {}
Social.MAX = 200

local function pick(list, rnd)
	return list[math.floor(rnd() * #list) + 1]
end

local function hashtag(ad)
	return "#" .. ad.name:gsub("[^%w]", "") .. "Live"
end

local function fill(text, c)
	return (text:gsub("{(%w+)}", function(k)
		local v = c[k]
		return v ~= nil and tostring(v) or ""
	end))
end

-- texts that talk about a stage element: only when the stage of that show has one of these items
Social.NEEDS = {
	{ "out of the FLOOR", { "lift", "poplift" } },
	{ "platform went up", { "floatplat" } },
	{ "rain moment", { "showerstage", "raincurtain" } },
	{ "giant dress", { "gownriser" } },
	{ "on the drums", { "drums" } },
	{ "piano moment", { "piano" } },
	{ "fireworks", { "fireworks", "rimfireworks" } },
	{ "lasers", { "laser" } },
	{ "confetti", { "confetti" } },
	{ "The screens", { "led", "led_flat", "led_hang", "led_side", "led_curve", "led_round", "led_kinetic", "ledtower", "ledcube" } },
}

-- adds `n` posts of a kind. c = { artistId, venueId?, tour?, song?, price?, item? }
function Social.add(state, kind, c, n, rnd)
	rnd = rnd or math.random
	state.social = state.social or {}
	local list = Data.POSTS[kind]
	if not list then
		return
	end
	local ad = Artists.byId[c.artistId or ""]
	local v = c.venueId and Countries.venueById[c.venueId]
	local ctx = {
		artist = ad and ad.name or "",
		venue = v and v.name or "",
		city = v and v.city or "",
		country = c.country or (v and Countries.byId[v.countryId].name) or "",
		tour = c.tour and c.tour.name or "",
		song = c.song or (ad and pick(ad.setlist, rnd)) or "",
		price = c.price and Util.money(c.price) or "",
		tag = ad and hashtag(ad) or "",
		item = c.item or "",
		label = state.labelName or "",
	}
	-- only texts that fit: no sections, rows or tiers in a standing club; a post about a lift, the rain,
	-- the giant dress ... only when the stage has it
	local look = v and Countries.VENUE_TYPES[v.type] and Countries.VENUE_TYPES[v.type].look or nil
	local has = nil
	if c.designId then
		for _, d in ipairs(state.designs or {}) do
			if d.id == c.designId then
				has = {}
				for _, it in ipairs(d.items or {}) do
					has[it.t] = true
				end
			end
		end
	end
	local function fits(text)
		if look == "club" then
			local low = text:lower()
			if low:find("section") or low:find("row %d") or low:find("tier") or low:find("seat") or low:find("nosebleed") then
				return false
			end
		end
		for _, need in ipairs(Social.NEEDS) do
			if text:find(need[1]) then
				local ok = false
				for _, k in ipairs(need[2]) do
					if has and has[k] then
						ok = true
					end
				end
				if not ok then
					return false
				end
			end
		end
		return true
	end
	local fitting = {}
	for i, tpl in ipairs(list) do
		if fits(tpl[2]) then
			table.insert(fitting, i)
		end
	end
	if #fitting == 0 then
		for i = 1, #list do
			fitting[i] = i
		end
	end
	-- no text that was in the feed lately (the last 80 posts)
	local used = {}
	for i = 1, math.min(80, #state.social) do
		local key = state.social[i].tpl
		if key then
			used[key] = true
		end
	end
	for _ = 1, n or 1 do
		local idx = fitting[math.floor(rnd() * #fitting) + 1]
		local tries = 0
		while used[kind .. ":" .. idx] and tries < 14 do
			idx = fitting[math.floor(rnd() * #fitting) + 1]
			tries = tries + 1
		end
		local tpl = list[idx]
		used[kind .. ":" .. idx] = true
		local first = pick(Data.FIRST, rnd)
		local handle = "@" .. pick(Data.HANDLE_A, rnd) .. "." .. pick(Data.HANDLE_B, rnd)
		local likes = math.floor((20 + rnd() * 400) * (tpl[1] > 0 and 2.5 or 1) * (1 + (c.reach or 0)))
		-- a photo with the post?
		local ph = Data.PHOTOS[kind]
		local pkind = nil
		if ph and rnd() < ph[1] then
			pkind = ph[2][math.floor(rnd() * #ph[2]) + 1]
		end
		table.insert(state.social, 1, {
			day = state.day,
			name = first,
			handle = handle,
			text = fill(tpl[2], ctx),
			mood = tpl[1],
			kind = kind,
			tpl = kind .. ":" .. idx,
			likes = likes,
			reposts = math.floor(likes * (0.05 + rnd() * 0.2)),
			artistId = c.artistId,
			photo = pkind ~= nil,
			pkind = pkind,
			look = v and Countries.VENUE_TYPES[v.type] and Countries.VENUE_TYPES[v.type].look or nil,
			venue = v and v.name or nil,
			designId = c.designId, -- photos of the show show this stage
			seed = math.floor(rnd() * 100000),
			avatar = math.floor(rnd() * 8) + 1,
		})
	end
	while #state.social > Social.MAX do
		table.remove(state.social)
	end
end

-- reach: bigger artists get more likes
local function reach(state, artistId)
	local a = state.artists[artistId]
	return a and math.log10(1 + Util.totalFans(a.fans) / 100000) or 0
end

function Social.onAnnounce(state, tour, fairPrice, rnd)
	rnd = rnd or math.random
	local s1 = tour.shows[1]
	local c = { artistId = tour.artistId, venueId = s1 and s1.venueId, tour = tour, price = tour.price, reach = reach(state, tour.artistId) }
	Social.add(state, "announce", c, 3, rnd)
	if fairPrice and tour.price > fairPrice * 1.3 then
		Social.add(state, "price_high", c, 2, rnd)
	elseif fairPrice and tour.price < fairPrice * 0.85 then
		Social.add(state, "price_low", c, 1, rnd)
	end
end

function Social.onSoldOut(state, tour, idx, rnd)
	local s = tour.shows[idx]
	Social.add(state, "soldout", { artistId = tour.artistId, venueId = s.venueId, tour = tour, reach = reach(state, tour.artistId) }, 2, rnd)
end

function Social.onLowSales(state, tour, idx, rnd)
	local s = tour.shows[idx]
	Social.add(state, "lowsales", { artistId = tour.artistId, venueId = s.venueId, tour = tour }, 2, rnd)
end

-- after a show: reviews, photos and comments about songs, outfits and the stage
function Social.onShow(state, tour, idx, r, design, rnd)
	rnd = rnd or math.random
	local s = tour.shows[idx]
	local c = { artistId = tour.artistId, venueId = s.venueId, tour = tour, price = s.price, reach = reach(state, tour.artistId), designId = design and design.id }
	local kind = (r.stars >= 4) and "show_great" or ((r.stars == 3) and "show_ok" or "show_bad")
	Social.add(state, kind, c, (r.stars >= 4) and 4 or 3, rnd)
	if r.stars >= 3 then
		Social.add(state, "photo", c, 2 + math.floor(rnd() * 2), rnd)
		Social.add(state, "outfit", c, 1, rnd)
		Social.add(state, "setlist", c, 1, rnd)
		if rnd() < 0.4 then
			Social.add(state, "sign", c, 1, rnd)
		end
	end
	-- a post about a special stage item
	if design and r.stars >= 3 then
		local found = {}
		for _, it in ipairs(design.items or {}) do
			local nm = Data.ITEM_NAMES[it.t]
			if nm and not found[nm] then
				found[nm] = true
				table.insert(found, nm)
			end
		end
		if #found > 0 then
			c.item = found[math.floor(rnd() * #found) + 1]
			Social.add(state, "stage", c, 2, rnd)
		end
	end
	if r.fill < 0.6 then
		Social.add(state, "lowsales", c, 1, rnd)
	end
end

-- small chance every day: fan projects, merch, countdowns for upcoming shows
function Social.daily(state, rnd)
	rnd = rnd or math.random
	for _, tour in ipairs(state.tours) do
		if tour.status ~= "done" and rnd() < 0.45 then
			for _, s in ipairs(tour.shows) do
				if not s.done then
					local kinds = { "fanproject", "merch", "countdown" }
					Social.add(state, kinds[math.floor(rnd() * #kinds) + 1], { artistId = tour.artistId, venueId = s.venueId, tour = tour }, 1, rnd)
					break
				end
			end
		end
	end
end

-- -100..100: how fans feel about an artist (last 25 posts)
function Social.mood(state, artistId)
	local sum, n = 0, 0
	for _, p in ipairs(state.social or {}) do
		if p.artistId == artistId then
			sum = sum + p.mood
			n = n + 1
			if n >= 25 then
				break
			end
		end
	end
	if n == 0 then
		return 0, 0
	end
	return math.floor(sum / n * 100 + 0.5), n
end

-- trending hashtags: { {tag, count} } sorted
function Social.trending(state)
	local counts = {}
	for _, p in ipairs(state.social or {}) do
		for tag in p.text:gmatch("#%w+") do
			counts[tag] = (counts[tag] or 0) + p.likes
		end
	end
	local out = {}
	for tag, n in pairs(counts) do
		table.insert(out, { tag, n })
	end
	table.sort(out, function(a, b)
		return a[2] > b[2]
	end)
	return out
end

return Social
