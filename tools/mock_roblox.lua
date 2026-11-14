-- Minimal Roblox runtime mock for automated play-testing (LuaJIT via lupa).
-- Every property write is validated against the official Roblox API dump (existence, read-only, value type).
local API = API_DATA
local CLASSES, ENUMLIST = API.classes, API.enums
MOCK = { time = 0, errors = {}, saves = {}, calls = {}, loadData = nil, loadStatus = "unavailable" }

local function fail(msg)
	table.insert(MOCK.errors, msg)
	print("!! ERROR: " .. tostring(msg))
end
MOCK.fail = fail

-------------------------------------------------------------- typeof
function typeof(v)
	local mt = getmetatable(v)
	if type(v) == "table" and mt and mt.__type then
		return mt.__type
	end
	return type(v)
end

-------------------------------------------------------------- polyfills (Luau std)
math.clamp = function(x, a, b)
	assert(type(x) == "number" and type(a) == "number" and type(b) == "number", "math.clamp expects numbers")
	assert(a <= b, "math.clamp: max < min")
	return math.max(a, math.min(b, x))
end
math.round = function(x) return math.floor(x + 0.5) end
math.sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end
table.find = function(t, v) for i, x in ipairs(t) do if x == v then return i end end return nil end
table.create = function(n, v) local t = {} if v ~= nil then for i = 1, n do t[i] = v end end return t end
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
function warn(...) print("WARN", ...) end
function tick() return MOCK.time end
os.clock = function() return MOCK.time end

-------------------------------------------------------------- Signal
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ conns = {} }, Signal) end
function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect expects a function")
	local c = { fn = fn, on = true }
	table.insert(self.conns, c)
	return { Disconnect = function() c.on = false end, Connected = true }
end
function Signal:Once(fn)
	local c
	c = self:Connect(function(...) c.Disconnect() fn(...) end)
	return c
end
function Signal:Fire(...)
	local list = {}
	for i, c in ipairs(self.conns) do list[i] = c end
	for _, c in ipairs(list) do
		if c.on then
			local ok, err = xpcall(c.fn, debug.traceback, ...)
			if not ok then fail(err) end
		end
	end
end
function Signal:Wait() return coroutine.yield() end
MOCK.Signal = Signal

-------------------------------------------------------------- datatypes
local function dt(name) local mt = { __type = name } return mt end
-- Vector3
local V3 = dt("Vector3")
local function v3(x, y, z)
	x, y, z = x or 0, y or 0, z or 0
	assert(type(x) == "number" and type(y) == "number" and type(z) == "number", "Vector3.new expects numbers")
	return setmetatable({ X = x, Y = y, Z = z }, V3)
end
local function isV3(v) return typeof(v) == "Vector3" end
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then return v3(0 / 0, 0 / 0, 0 / 0) end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Lerp" then return function(a, b, t) assert(isV3(b)) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
	elseif k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif k == "Cross" then return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	error("Vector3 has no member " .. tostring(k), 2)
end
V3.__add = function(a, b) assert(isV3(a) and isV3(b), "Vector3 + non-Vector3") return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) assert(isV3(a) and isV3(b), "Vector3 - non-Vector3") return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	assert(isV3(b), "Vector3 * invalid") return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3.__tostring = function(a) return string.format("%.2f, %.2f, %.2f", a.X, a.Y, a.Z) end
Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1), yAxis = v3(0, 1, 0) }
Vector3.FromNormalId = function(n)
	local map = { Right = v3(1, 0, 0), Left = v3(-1, 0, 0), Top = v3(0, 1, 0), Bottom = v3(0, -1, 0), Back = v3(0, 0, 1), Front = v3(0, 0, -1) }
	return assert(map[n.Name], "bad NormalId")
end
-- Vector2
local V2 = dt("Vector2")
local function v2(x, y)
	x, y = x or 0, y or 0
	assert(type(x) == "number" and type(y) == "number", "Vector2.new expects numbers")
	return setmetatable({ X = x, Y = y }, V2)
end
V2.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y) return v2(v.X / m, v.Y / m) end
	error("Vector2 has no member " .. tostring(k), 2)
end
V2.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2.__sub = function(a, b) assert(typeof(b) == "Vector2") return v2(a.X - b.X, a.Y - b.Y) end
V2.__mul = function(a, b) if type(a) == "number" then a, b = b, a end if type(b) == "number" then return v2(a.X * b, a.Y * b) end return v2(a.X * b.X, a.Y * b.Y) end
V2.__div = function(a, b) if type(b) == "number" then return v2(a.X / b, a.Y / b) end return v2(a.X / b.X, a.Y / b.Y) end
Vector2 = { new = v2, zero = v2(0, 0) }
-- CFrame (row-major 3x3 rotation + position)
local CF = dt("CFrame")
local ID = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function cf(p, r) return setmetatable({ _p = p, _r = r or ID }, CF) end
local function mm(a, b)
	local r = {}
	for i = 0, 2 do for j = 0, 2 do
		r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
	end end
	return r
end
local function mv(r, v) return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z) end
local function isCF(v) return typeof(v) == "CFrame" end
CF.__index = function(c, k)
	if k == "Position" or k == "p" then return c._p
	elseif k == "X" then return c._p.X elseif k == "Y" then return c._p.Y elseif k == "Z" then return c._p.Z
	elseif k == "LookVector" then return v3(-c._r[3], -c._r[6], -c._r[9])
	elseif k == "VectorToWorldSpace" then
		return function(self, v) return mv(self._r, v) end
	elseif k == "PointToObjectSpace" then
		return function(self, v)
			local d, r = v - self._p, self._r
			return v3(r[1] * d.X + r[4] * d.Y + r[7] * d.Z, r[2] * d.X + r[5] * d.Y + r[8] * d.Z, r[3] * d.X + r[6] * d.Y + r[9] * d.Z)
		end
	elseif k == "Lerp" then return function(a, b, t) assert(isCF(b), "CFrame:Lerp expects CFrame") return cf(a._p:Lerp(b._p, t), t < 0.5 and a._r or b._r) end
	end
	error("CFrame has no member " .. tostring(k), 2)
end
CF.__mul = function(a, b)
	assert(isCF(a), "CFrame * : left side must be CFrame")
	if isCF(b) then return cf(a._p + mv(a._r, b._p), mm(a._r, b._r)) end
	if isV3(b) then return a._p + mv(a._r, b) end
	error("CFrame * invalid operand " .. typeof(b), 2)
end
CF.__add = function(a, b) assert(isCF(a) and isV3(b), "CFrame + Vector3 expected") return cf(a._p + b, a._r) end
CF.__sub = function(a, b) assert(isCF(a) and isV3(b), "CFrame - Vector3 expected") return cf(a._p - b, a._r) end
local function angles(rx, ry, rz)
	assert(type(rx) == "number" and type(ry) == "number" and type(rz) == "number", "CFrame.Angles expects numbers")
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), mm(mm(Rx, Ry), Rz))
end
CFrame = {
	new = function(a, b, c, ...)
		if a == nil then return cf(v3(0, 0, 0)) end
		if isV3(a) then
			if b ~= nil then error("CFrame.new(pos, lookAt) not supported in mock") end
			return cf(a)
		end
		assert(type(a) == "number" and type(b) == "number" and type(c) == "number", "CFrame.new expects 3 numbers")
		return cf(v3(a, b, c))
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	lookAt = function(eye, at)
		assert(isV3(eye) and isV3(at), "CFrame.lookAt expects Vector3s")
		local look = (at - eye).Unit
		local right = look:Cross(v3(0, 1, 0))
		if right.Magnitude < 1e-6 then right = v3(1, 0, 0) end
		right = right.Unit
		local up = right:Cross(look)
		return cf(eye, { right.X, up.X, -look.X, right.Y, up.Y, -look.Y, right.Z, up.Z, -look.Z })
	end,
}
-- Color3
local C3 = dt("Color3")
local function c3(r, g, b)
	assert(type(r) == "number" and type(g) == "number" and type(b) == "number", "Color3 expects numbers")
	return setmetatable({ R = r, G = g, B = b }, C3)
end
C3.__index = function(c, k)
	if k == "Lerp" then return function(a, b, t) assert(typeof(b) == "Color3", "Color3:Lerp expects Color3") return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end end
	error("Color3 has no member " .. tostring(k), 2)
end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3 = {
	new = function(r, g, b) return c3(r or 0, g or 0, b or 0) end,
	fromRGB = function(r, g, b)
		assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255, "fromRGB out of range")
		return c3(r / 255, g / 255, b / 255)
	end,
}
-- UDim / UDim2
local UD = dt("UDim")
local function udim(s, o) assert(type(s) == "number" and type(o) == "number", "UDim.new expects numbers") return setmetatable({ Scale = s, Offset = o }, UD) end
UD.__index = function(_, k) error("UDim has no member " .. tostring(k), 2) end
UDim = { new = function(s, o) return udim(s or 0, o or 0) end }
local UD2 = dt("UDim2")
local function udim2(xs, xo, ys, yo) return setmetatable({ X = udim(xs, xo), Y = udim(ys, yo) }, UD2) end
UD2.__index = function(_, k) error("UDim2 has no member " .. tostring(k), 2) end
UDim2 = {
	new = function(xs, xo, ys, yo) return udim2(xs or 0, xo or 0, ys or 0, yo or 0) end,
	fromOffset = function(x, y) return udim2(0, x or 0, 0, y or 0) end,
	fromScale = function(x, y) return udim2(x or 0, 0, y or 0, 0) end,
}
-- sequences & misc
local NS = dt("NumberSequence")
NumberSequence = { new = function(a, b)
	if type(a) == "number" then assert(b == nil or type(b) == "number", "NumberSequence.new(n0, n1) expects numbers")
	else assert(type(a) == "table", "NumberSequence.new invalid") end
	return setmetatable({}, NS)
end }
local NSK = dt("NumberSequenceKeypoint")
NumberSequenceKeypoint = { new = function(a, b) assert(type(a) == "number" and type(b) == "number") return setmetatable({ Time = a, Value = b }, NSK) end }
local CS = dt("ColorSequence")
ColorSequence = { new = function(a, b)
	if typeof(a) == "Color3" then assert(b == nil or typeof(b) == "Color3", "ColorSequence.new(c0, c1) expects Color3s")
	else
		assert(type(a) == "table" and #a >= 2, "ColorSequence keypoints")
		for i, kp in ipairs(a) do assert(typeof(kp) == "ColorSequenceKeypoint", "bad keypoint") end
		assert(a[1].Time == 0 and a[#a].Time == 1, "ColorSequence must start at 0 and end at 1")
	end
	return setmetatable({}, CS)
end }
local CSK = dt("ColorSequenceKeypoint")
ColorSequenceKeypoint = { new = function(t, c) assert(type(t) == "number" and typeof(c) == "Color3") return setmetatable({ Time = t, Value = c }, CSK) end }
local NR = dt("NumberRange")
NumberRange = { new = function(a, b) assert(type(a) == "number" and (b == nil or (type(b) == "number" and b >= a)), "NumberRange invalid") return setmetatable({ Min = a, Max = b or a }, NR) end }
local TI = dt("TweenInfo")
TweenInfo = { new = function(t, style, dir) assert(type(t) == "number") return setmetatable({ Time = t }, TI) end }
local RP = dt("RaycastParams")
RaycastParams = { new = function() return setmetatable({ FilterDescendantsInstances = {}, FilterType = nil }, RP) end }
local RND = dt("Random")
RND.__index = { NextInteger = function(self, a, b) assert(a <= b) return math.random(a, b) end, NextNumber = function(self, a, b) return (a or 0) + math.random() * ((b or 1) - (a or 0)) end }
Random = { new = function(seed) return setmetatable({}, RND) end }
local FACES = dt("Faces")
Faces = { new = function(...) for _, n in ipairs({ ... }) do assert(n.EnumType == "NormalId") end return setmetatable({}, FACES) end }
local AXES = dt("Axes")
Axes = { new = function(...) for _, n in ipairs({ ... }) do assert(n.EnumType == "Axis" or n.EnumType == "NormalId") end return setmetatable({}, AXES) end }
local FONT = dt("Font")
Font = { new = function() return setmetatable({}, FONT) end }

-------------------------------------------------------------- Enum
local ENUMS = {}
local EI = dt("EnumItem")
EI.__tostring = function(e) return "Enum." .. e.EnumType .. "." .. e.Name end
for ename, items in pairs(ENUMLIST) do
	local t = {}
	for i, n in ipairs(items) do t[n] = setmetatable({ Name = n, EnumType = ename, Value = i - 1 }, EI) end
	ENUMS[ename] = setmetatable(t, { __index = function(_, k) error("Enum." .. ename .. "." .. tostring(k) .. " does not exist", 2) end })
end
Enum = setmetatable({}, { __index = function(_, k) return ENUMS[k] or error("Enum." .. tostring(k) .. " does not exist", 2) end })

-------------------------------------------------------------- Instances
local function findMember(cls, kind, name)
	local c = cls
	while c and c ~= "<<<ROOT>>>" do
		local info = CLASSES[c]
		if not info then return nil end
		local m = info[kind][name]
		if m then return m end
		c = info.super
	end
	return nil
end
local function isA(cls, target)
	local c = cls
	while c and c ~= "<<<ROOT>>>" do
		if c == target then return true end
		c = CLASSES[c] and CLASSES[c].super
	end
	return false
end

local SPECIAL_DEFAULT = { Visible = true, Enabled = true, Archivable = true, Transparency = 0, BackgroundTransparency = 0, TextTransparency = 0 }
local ALIGN_DEFAULT = { TextXAlignment = "Center", TextYAlignment = "Center" }
local function defaultFor(cat, tname, inst, k)
	if k == "ViewportSize" then return v2(1920, 1080) end
	if k == "AbsoluteSize" then return v2(100, 100) end
	if SPECIAL_DEFAULT[k] ~= nil then return SPECIAL_DEFAULT[k] end
	if ALIGN_DEFAULT[k] then return ENUMS[k][ALIGN_DEFAULT[k]] end
	if cat == "Primitive" then
		if tname == "bool" then return false elseif tname == "string" then return "" else return 0 end
	elseif cat == "Enum" then
		local first = ENUMLIST[tname] and ENUMLIST[tname][1]
		return first and ENUMS[tname][first] or nil
	elseif cat == "Class" then return nil
	elseif tname == "Vector3" then return v3()
	elseif tname == "Vector2" then return v2()
	elseif tname == "CFrame" then return CFrame.new()
	elseif tname == "Color3" then return c3(0, 0, 0)
	elseif tname == "UDim2" then return UDim2.new()
	elseif tname == "UDim" then return UDim.new()
	elseif tname == "Content" or tname == "ContentId" then return ""
	end
	return setmetatable({}, dt(tname))
end
local NUMS = { float = true, double = true, int = true, int64 = true }
local function typeOk(cat, tname, v)
	if cat == "Primitive" then
		if tname == "bool" then return type(v) == "boolean" end
		if tname == "string" then return type(v) == "string" end
		if NUMS[tname] then return type(v) == "number" and v == v end
		return true
	elseif cat == "Enum" then return typeof(v) == "EnumItem" and v.EnumType == tname
	elseif cat == "Class" then return v == nil or (typeof(v) == "Instance" and isA(v.ClassName, tname))
	elseif tname == "Content" or tname == "ContentId" then return type(v) == "string"
	end
	return typeof(v) == tname
end

local Methods = {}
local InstMT = { __type = "Instance" }
local function newInst(cls)
	return setmetatable({ __class = cls, __props = { Name = cls }, __children = {}, __signals = {}, __attrs = {}, __propSignals = {} }, InstMT)
end
local function setParent(self, p)
	if p ~= nil and typeof(p) ~= "Instance" then error("Parent must be an Instance", 3) end
	if rawget(self, "__destroyed") and p ~= nil then error("The Parent property of " .. self.__props.Name .. " is locked (destroyed)", 3) end
	local old = rawget(self, "__parent")
	if old then
		for i, c in ipairs(old.__children) do if c == self then table.remove(old.__children, i) break end end
	end
	if p then table.insert(p.__children, self) end
	rawset(self, "__parent", p)
end
InstMT.__index = function(self, k)
	local cls = rawget(self, "__class")
	local m = Methods[k]
	if m and findMember(cls, "funcs", k) then return m end
	if k == "Parent" then return rawget(self, "__parent") end
	if k == "ClassName" then return cls end
	local p = findMember(cls, "props", k)
	if p then
		local v = self.__props[k]
		if v ~= nil then return v end
		return defaultFor(p[1], p[2], self, k)
	end
	if findMember(cls, "events", k) then
		local s = self.__signals[k]
		if not s then s = Signal.new() self.__signals[k] = s end
		return s
	end
	if findMember(cls, "funcs", k) then
		return function() MOCK.calls[k] = (MOCK.calls[k] or 0) + 1 end
	end
	for _, c in ipairs(self.__children) do if c.__props.Name == k then return c end end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(k), cls, tostring(self.__props.Name)), 2)
end
InstMT.__newindex = function(self, k, v)
	if k == "Parent" then return setParent(self, v) end
	local cls = rawget(self, "__class")
	local p = findMember(cls, "props", k)
	if not p then error(string.format("%s is not a valid member of %s", tostring(k), cls), 2) end
	if p[3] then error(k .. " is read-only / not scriptable on " .. cls, 2) end
	if not typeOk(p[1], p[2], v) then error(string.format("Unable to assign %s.%s: %s expected, got %s", cls, k, p[2], typeof(v)), 2) end
	self.__props[k] = v
	local s = self.__propSignals[k]
	if s then s:Fire() end
end
InstMT.__tostring = function(self) return self.__props.Name end

Instance = { new = function(cls, parent)
	local info = CLASSES[cls]
	if not info then error("Unable to create an Instance of type \"" .. tostring(cls) .. "\"", 2) end
	if not info.creatable then error(cls .. " is not creatable", 2) end
	local i = newInst(cls)
	if parent then i.Parent = parent end
	return i
end }
MOCK.newRaw = newInst

function Methods.Destroy(self)
	if rawget(self, "__destroyed") then return end
	setParent(self, nil)
	rawset(self, "__destroyed", true)
	local kids = {}
	for i, c in ipairs(self.__children) do kids[i] = c end
	for _, c in ipairs(kids) do Methods.Destroy(c) end
end
function Methods.Clone(self)
	local c = newInst(self.__class)
	for k, v in pairs(self.__props) do c.__props[k] = v end
	return c
end
function Methods.GetChildren(self) local t = {} for i, c in ipairs(self.__children) do t[i] = c end return t end
function Methods.GetDescendants(self)
	local out = {}
	local function walk(i) for _, c in ipairs(i.__children) do table.insert(out, c) walk(c) end end
	walk(self)
	return out
end
function Methods.IsA(self, c) return isA(self.__class, c) end
function Methods.FindFirstChild(self, n) for _, c in ipairs(self.__children) do if c.__props.Name == n then return c end end return nil end
function Methods.WaitForChild(self, n)
	local c = Methods.FindFirstChild(self, n)
	if not c then error("Infinite yield: WaitForChild(\"" .. n .. "\") on " .. self.__props.Name, 2) end
	return c
end
function Methods.FindFirstAncestor(self, n)
	local p = rawget(self, "__parent")
	while p do if p.__props.Name == n then return p end p = rawget(p, "__parent") end
	return nil
end
function Methods.IsDescendantOf(self, other)
	local p = rawget(self, "__parent")
	while p do if p == other then return true end p = rawget(p, "__parent") end
	return false
end
function Methods.GetPropertyChangedSignal(self, prop)
	assert(findMember(self.__class, "props", prop), "GetPropertyChangedSignal: unknown property " .. prop)
	local s = self.__propSignals[prop]
	if not s then s = Signal.new() self.__propSignals[prop] = s end
	return s
end
function Methods.GetBoundingBox(self) return CFrame.new(), v3(4, 4, 4) end
function Methods.PivotTo(self, c) assert(isCF(c), "PivotTo expects CFrame") end
function Methods.Emit(self, n) assert(type(n) == "number", "Emit expects number") end
function Methods.ClearAllChildren(self) for _, c in ipairs(Methods.GetChildren(self)) do Methods.Destroy(c) end end
function Methods.SetCoreGuiEnabled(self, t, on) assert(typeof(t) == "EnumItem") end
function Methods.IsLoaded() return true end
function Methods.GetMouseLocation() return MOCK.mouse or v2(960, 540) end
function Methods.IsKeyDown(self, k) return MOCK.keys and MOCK.keys[k] or false end
function Methods.GetFocusedTextBox() return nil end
function Methods.ViewportPointToRay(self, x, y)
	assert(type(x) == "number" and type(y) == "number")
	local o = v3(0, 120, 140)
	return { Origin = o, Direction = (v3((x - 960) / 10, 6, -10) - o).Unit }
end
function Methods.Raycast(self, origin, dir, params)
	assert(isV3(origin) and isV3(dir), "Raycast expects Vector3s")
	assert(params == nil or typeof(params) == "RaycastParams", "Raycast params")
	return MOCK.raycast(origin, dir, params)
end
function Methods.BulkMoveTo(self, parts, cfs, mode)
	assert(#parts == #cfs, "BulkMoveTo: part and CFrame lists differ in length")
	for i, p in ipairs(parts) do assert(isCF(cfs[i]), "BulkMoveTo: not a CFrame") assert(p:IsA("BasePart")) end
	MOCK.bulkMoves = (MOCK.bulkMoves or 0) + 1
end
function Methods.GetService(self, name)
	if not CLASSES[name] then error("'" .. tostring(name) .. "' is not a valid Service name", 2) end
	MOCK.services = MOCK.services or {}
	local s = MOCK.services[name]
	if not s then
		s = newInst(name)
		s.__props.Name = name
		setParent(s, game)
		MOCK.services[name] = s
	end
	return s
end
function Methods.JSONEncode(self, t) return MOCK.jsonEncode(t) end
function Methods.JSONDecode(self, s) return MOCK.jsonDecode(s) end
function Methods.InvokeServer(self, ...) return MOCK.loadData, MOCK.loadStatus end
function Methods.FireServer(self, data) assert(type(data) == "string") table.insert(MOCK.saves, data) end
function Methods.Create(self, inst, info, props)
	assert(typeof(inst) == "Instance" and typeof(info) == "TweenInfo" and type(props) == "table", "TweenService:Create args")
	local tw = { Completed = Signal.new() }
	function tw.Play()
		for k, v in pairs(props) do inst[k] = v end
		task.defer(function() tw.Completed:Fire(Enum.PlaybackState.Completed) end)
	end
	function tw.Cancel() end
	return tw
end

-------------------------------------------------------------- task scheduler
local sched = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then fail(debug.traceback(co, err)) end
end
task = {}
function task.spawn(fn, ...) local co = coroutine.create(fn) resume(co, ...) return co end
function task.defer(fn, ...) local co = coroutine.create(fn) table.insert(sched, { co = co, wake = MOCK.time, args = { ... } }) return co end
function task.delay(t, fn, ...) local co = coroutine.create(fn) table.insert(sched, { co = co, wake = MOCK.time + (t or 0), args = { ... } }) return co end
function task.wait(t)
	local co = coroutine.running()
	assert(co, "task.wait called outside a coroutine")
	table.insert(sched, { co = co, wake = MOCK.time + (t or 0.03), args = {} })
	return coroutine.yield()
end
function MOCK.runTasks()
	local guard = 0
	while true do
		guard = guard + 1
		if guard > 1000 then fail("task loop") return end
		local idx = nil
		for i, s in ipairs(sched) do if s.wake <= MOCK.time then idx = i break end end
		if not idx then return end
		local s = table.remove(sched, idx)
		resume(s.co, unpack(s.args))
	end
end
function MOCK.step(dt)
	MOCK.time = MOCK.time + dt
	local RS = game:GetService("RunService")
	RS.RenderStepped:Fire(dt)
	RS.Heartbeat:Fire(dt)
	MOCK.runTasks()
end

-------------------------------------------------------------- world setup
game = newInst("DataModel")
game.__props.Name = "Game"
workspace = game:GetService("Workspace")
local cam = newInst("Camera")
cam.__props.Name = "Camera"
setParent(cam, workspace)
workspace.__props.CurrentCamera = cam
local players = game:GetService("Players")
local player = newInst("Player")
player.__props.Name = "Tester"
setParent(player, players)
players.__props.LocalPlayer = player
local pg = newInst("PlayerGui")
pg.__props.Name = "PlayerGui"
setParent(pg, player)
MOCK.playerGui = pg

-- module loading
local moduleCache = {}
function require(mod)
	if typeof(mod) ~= "Instance" or not mod:IsA("ModuleScript") then error("require: expected ModuleScript, got " .. typeof(mod), 2) end
	if moduleCache[mod] ~= nil then return moduleCache[mod] end
	local path = rawget(mod, "__path")
	local chunk, err = loadstring(READFILE(path), "@" .. path)
	if not chunk then error(err) end
	setfenv(chunk, setmetatable({ script = mod }, { __index = _G }))
	local r = chunk()
	if r == nil then error("Module " .. path .. " did not return a value") end
	moduleCache[mod] = r
	return r
end
function MOCK.buildTree(parent, node)
	local inst = newInst(node.class)
	inst.__props.Name = node.name
	if node.path then rawset(inst, "__path", node.path) end
	setParent(inst, parent)
	for _, ch in ipairs(node.children or {}) do MOCK.buildTree(inst, ch) end
	return inst
end
function MOCK.runScript(inst)
	local path = rawget(inst, "__path")
	local chunk = assert(loadstring(READFILE(path), "@" .. path))
	setfenv(chunk, setmetatable({ script = inst }, { __index = _G }))
	local co = coroutine.create(chunk)
	resume(co)
end

-------------------------------------------------------------- GUI helpers
local function visible(inst)
	local p = inst
	while p and p ~= MOCK.playerGui do
		if rawget(p, "__destroyed") then return false end
		if p:IsA("GuiObject") and p.Visible == false then return false end
		if p:IsA("ScreenGui") and p.Enabled == false then return false end
		p = rawget(p, "__parent")
	end
	return p == MOCK.playerGui
end
MOCK.visible = visible
local function buttonLabel(b)
	if b.Text ~= "" then return b.Text end
	for _, c in ipairs(b:GetChildren()) do
		if c:IsA("TextLabel") and c.Text ~= "" then return c.Text end
	end
	return ""
end
function MOCK.buttons(pattern)
	local out = {}
	for _, d in ipairs(MOCK.playerGui:GetDescendants()) do
		if d:IsA("TextButton") and visible(d) then
			local lbl = buttonLabel(d)
			if lbl:find(pattern) then table.insert(out, d) end
		end
	end
	return out
end
function MOCK.click(pattern, idx)
	local list = MOCK.buttons(pattern)
	local b = list[idx or 1]
	if not b then
		fail("button not found: " .. pattern)
		return false
	end
	b.MouseButton1Click:Fire()
	MOCK.runTasks()
	return true
end
function MOCK.texts(pattern)
	local out = {}
	for _, d in ipairs(MOCK.playerGui:GetDescendants()) do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and visible(d) and d.Text:find(pattern) then table.insert(out, d.Text) end
	end
	return out
end
function MOCK.input(kind, extra)
	local UIS = game:GetService("UserInputService")
	local obj = { UserInputType = kind, KeyCode = Enum.KeyCode.Unknown, Delta = v3(0, 0, 0), Position = v3(0, 0, 0) }
	for k, v in pairs(extra or {}) do obj[k] = v end
	return obj, UIS
end

-------------------------------------------------------------- raycast & json
function MOCK.raycast(origin, dir, params)
	local list = (params and params.FilterDescendantsInstances) or {}
	for _, inst in ipairs(list) do
		if inst.Name == "Design" then
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") and d.Name ~= "Pivot" then return { Instance = d, Position = d.CFrame.Position, Normal = v3(0, 1, 0) } end
			end
			return nil
		end
	end
	if dir.Y >= 0 then return nil end
	local t = -origin.Y / dir.Y
	if t < 0 or t > 1 then return nil end
	local hit = origin + dir * t
	local best, bestY = list[1], 0
	for _, p in ipairs(list) do
		if p.Name ~= "Ground" and p:IsA("BasePart") then
			local pos, sz = p.CFrame.Position, p.Size
			local ext = math.max(sz.X, sz.Y, sz.Z) / 2
			local top = pos.Y + math.min(sz.X, sz.Y, sz.Z) / 2
			if math.abs(hit.X - pos.X) <= ext and math.abs(hit.Z - pos.Z) <= ext and top > bestY then
				best, bestY = p, top
			end
		end
	end
	return { Instance = best, Position = v3(hit.X, bestY, hit.Z), Normal = v3(0, 1, 0) }
end

local function esc(s)
	return '"' .. s:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
end
function MOCK.jsonEncode(v)
	local t = type(v)
	if t == "table" then
		if getmetatable(v) then error("JSONEncode: cannot encode " .. typeof(v)) end
		local count = 0
		for _ in pairs(v) do count = count + 1 end
		if count == 0 then return "[]" end
		local isArr = true
		for i = 1, count do if v[i] == nil then isArr = false break end end
		local parts = {}
		if isArr then
			for i = 1, count do parts[i] = MOCK.jsonEncode(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for k, x in pairs(v) do
			if type(k) ~= "string" then error("JSONEncode: table has mixed or non-string keys (" .. tostring(k) .. ")") end
			table.insert(parts, esc(k) .. ":" .. MOCK.jsonEncode(x))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then return esc(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("JSONEncode: NaN/inf") end
		return string.format("%.17g", v)
	elseif t == "boolean" then return tostring(v)
	end
	error("JSONEncode: cannot encode " .. t)
end
function MOCK.clickExact(text, idx)
	local n = 0
	for _, d in ipairs(MOCK.playerGui:GetDescendants()) do
		if d:IsA("TextButton") and visible(d) then
			local lbl = d.Text ~= "" and d.Text or nil
			if not lbl then
				for _, c in ipairs(d:GetChildren()) do if c:IsA("TextLabel") and c.Text ~= "" then lbl = c.Text break end end
			end
			if lbl == text then
				n = n + 1
				if n == (idx or 1) then
					d.MouseButton1Click:Fire()
					MOCK.runTasks()
					return true
				end
			end
		end
	end
	fail("exact button not found: " .. text)
	return false
end
