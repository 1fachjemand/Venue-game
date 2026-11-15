-- Small helpers (pure Lua, no Roblox APIs)
local Util = {}

function Util.clamp(x, a, b)
	if x < a then
		return a
	end
	if x > b then
		return b
	end
	return x
end

function Util.round(x)
	return math.floor(x + 0.5)
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

local function commas(n)
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

function Util.number(n)
	local s = commas(n)
	if n < 0 then
		return "-" .. s
	end
	return s
end

function Util.money(n)
	if n < 0 then
		return "-$" .. commas(n)
	end
	return "$" .. commas(n)
end

local function short(n)
	local a = math.abs(n)
	if a >= 1e9 then
		return string.format("%.2fB", a / 1e9)
	elseif a >= 1e6 then
		return string.format("%.1fM", a / 1e6)
	elseif a >= 1e4 then
		return string.format("%.0fK", a / 1e3)
	elseif a >= 1e3 then
		return string.format("%.1fK", a / 1e3)
	end
	return tostring(math.floor(a + 0.5))
end

function Util.short(n)
	if n < 0 then
		return "-" .. short(n)
	end
	return short(n)
end

function Util.moneyShort(n)
	if n < 0 then
		return "-$" .. short(n)
	end
	return "$" .. short(n)
end

function Util.percent(f)
	return tostring(math.floor(f * 100 + 0.5)) .. "%"
end

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local MDAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function isLeap(y)
	return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

-- day 0 = Jan 1 of startYear
-- year, month (1-12), day of month (1-31) of a game day; weekday 1 = Monday (day 0 = Fri, Jan 1 2027)
function Util.ymd(day, startYear)
	local y = startYear or 2027
	local d = math.floor(day)
	while d >= (isLeap(y) and 366 or 365) do
		d = d - (isLeap(y) and 366 or 365)
		y = y + 1
	end
	local m = 1
	while true do
		local ml = (m == 2 and isLeap(y)) and 29 or MDAYS[m]
		if d < ml then
			break
		end
		d = d - ml
		m = m + 1
	end
	return y, m, d + 1, (math.floor(day) + 4) % 7 + 1
end
function Util.monthLength(y, m)
	return (m == 2 and isLeap(y)) and 29 or MDAYS[m]
end
function Util.monthName(m)
	return MONTHS[m]
end
-- game day of a date
function Util.dayOf(y, m, dd, startYear)
	local day = 0
	for yy = startYear or 2027, y - 1 do
		day = day + (isLeap(yy) and 366 or 365)
	end
	for mm = 1, m - 1 do
		day = day + Util.monthLength(y, mm)
	end
	return day + dd - 1
end

function Util.date(day, startYear)
	local y = startYear or 2027
	local d = math.floor(day)
	while true do
		local len = isLeap(y) and 366 or 365
		if d < len then
			break
		end
		d = d - len
		y = y + 1
	end
	local m = 1
	while true do
		local ml = MDAYS[m]
		if m == 2 and isLeap(y) then
			ml = 29
		end
		if d < ml then
			break
		end
		d = d - ml
		m = m + 1
	end
	return MONTHS[m] .. " " .. tostring(d + 1) .. ", " .. tostring(y), MONTHS[m] .. " " .. tostring(d + 1)
end

function Util.distanceKm(lat1, lon1, lat2, lon2)
	local r = math.pi / 180
	local dLat = (lat2 - lat1) * r
	local dLon = (lon2 - lon1) * r
	local a = math.sin(dLat / 2) ^ 2 + math.cos(lat1 * r) * math.cos(lat2 * r) * math.sin(dLon / 2) ^ 2
	return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
end

function Util.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = Util.deepCopy(v)
	end
	return c
end

-- Copies `src` into `dst` in place, so tables other code holds on to stay the same tables.
-- Lists of tables with an id (or uid) are matched by that id, other lists by position.
local function syncKey(v)
	return type(v) == "table" and (v.id or v.uid) or nil
end
function Util.syncInto(dst, src)
	if #src > 0 then
		local byKey = {}
		for _, v in ipairs(dst) do
			local k = syncKey(v)
			if k ~= nil then
				byKey[k] = v
			end
		end
		local out = {}
		for i, v in ipairs(src) do
			local k = syncKey(v)
			local old
			if k ~= nil then
				old = byKey[k]
				byKey[k] = nil
			elseif type(dst[i]) == "table" and syncKey(dst[i]) == nil then
				old = dst[i]
			end
			if type(v) == "table" and type(old) == "table" then
				Util.syncInto(old, v)
				out[i] = old
			else
				out[i] = v
			end
		end
		for k in pairs(dst) do
			dst[k] = nil
		end
		for i, v in ipairs(out) do
			dst[i] = v
		end
		return dst
	end
	for k in pairs(dst) do
		if src[k] == nil then
			dst[k] = nil
		end
	end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			Util.syncInto(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

function Util.stars(n)
	-- plain text (Roblox fonts have no star symbols)
	return tostring(n) .. "/5 stars"
end

function Util.totalFans(fans)
	local t = 0
	for _, v in pairs(fans) do
		t = t + v
	end
	return t
end

function Util.tier(totalFans)
	if totalFans < 300000 then
		return "Rising Act"
	elseif totalFans < 1500000 then
		return "Breakthrough"
	elseif totalFans < 5000000 then
		return "Arena Act"
	elseif totalFans < 15000000 then
		return "Stadium Act"
	end
	return "Global Superstar"
end

return Util
