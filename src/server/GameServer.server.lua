-- HEADLINER server: owns the game state of every player, runs all actions (Logic/Actions.lua),
-- saves to the DataStore (only works in a published place) and builds the label building.
-- The client only shows the state: after every action the server sends the parts that changed.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

local Root = ReplicatedStorage:WaitForChild("Headliner")
local Config = require(Root.Config)
local GS = require(Root.Logic.GameState)
local Actions = require(Root.Logic.Actions)
local Hub = require(Root.World.Hub)
local Remotes = Root:WaitForChild("Remotes")

Hub.build(workspace)

local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("HeadlinerSave_v1")
end)

local sessions = {}
-- for the automated tests (tools/scenario_full.lua): the sessions of the server
shared.HeadlinerServer = { sessions = sessions }

-- save slots: "1" (the old single save), "2", "3" and the developer sandbox
local SLOTS = { "1", "2", "3" }
local function cleanSlot(slot)
	if slot == "sandbox" then
		return "sandbox"
	end
	slot = tostring(slot or "1")
	if slot == "main" then
		slot = "1"
	end
	for _, k in ipairs(SLOTS) do
		if k == slot then
			return slot
		end
	end
	return "1"
end
local function saveKey(player, slot)
	slot = cleanSlot(slot)
	if slot == "sandbox" then
		return "player_" .. player.UserId .. "_sandbox"
	elseif slot == "1" then
		return "player_" .. player.UserId
	end
	return "player_" .. player.UserId .. "_slot" .. slot
end

local function canSandbox(player)
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local function decode(json)
	if type(json) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if ok and type(data) == "table" and data.version == Config.SAVE_VERSION then
		return GS.sanitize(data)
	end
	return nil
end

local function summary(state)
	if not state then
		return nil
	end
	return { labelName = state.labelName, day = state.day, money = state.money }
end

local function loadSlot(player, slot)
	if not store then
		return nil, false
	end
	local ok, data = pcall(function()
		return store:GetAsync(saveKey(player, slot))
	end)
	return ok and decode(data) or nil, ok
end

local function save(player, force)
	local s = sessions[player]
	if not s or not s.state or not store or not s.loaded then
		return
	end
	if not force and not s.dirty then
		return
	end
	local now = os.clock()
	if not force and s.lastSave and now - s.lastSave < 8 then
		return
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(s.state)
	end)
	if not ok or #json > 3500000 then
		return
	end
	s.dirty = false
	s.lastSave = now
	local key = saveKey(player, s.slot)
	task.spawn(function()
		pcall(function()
			store:SetAsync(key, json)
		end)
	end)
end

-- the parts of the state that changed since they were last sent (one JSON string per top-level key)
local function delta(s, full)
	local out = {}
	for k, v in pairs(s.state) do
		local ok, json = pcall(function()
			return HttpService:JSONEncode({ v = v })
		end)
		if ok and (full or s.sent[k] ~= json) then
			out[k] = json
			s.sent[k] = json
		end
	end
	return out
end

local function startSession(s, state, slot)
	s.state = state
	s.slot = slot
	s.sent = {}
	s.dirty = true
end

Players.PlayerAdded:Connect(function(player)
	local s = { loaded = false, sent = {}, saved = {} }
	sessions[player] = s
	-- no automatic respawn: the character comes back a moment after falling or dying
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			task.delay(3, function()
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		end)
	end)
	local okAll = true
	for _, k in ipairs(SLOTS) do
		local data, ok = loadSlot(player, k)
		s.saved[k] = data
		okAll = okAll and ok
	end
	if canSandbox(player) then
		s.saved.sandbox = loadSlot(player, "sandbox")
	end
	s.saveAvailable = store ~= nil and okAll
	s.loaded = true
end)

Players.PlayerRemoving:Connect(function(player)
	save(player, true)
	sessions[player] = nil
end)

game:BindToClose(function()
	for player in pairs(sessions) do
		save(player, true)
	end
	task.wait(2)
end)

-- autosave
task.spawn(function()
	while true do
		task.wait(30)
		for player in pairs(sessions) do
			save(player, false)
		end
	end
end)

local function spawnCharacter(player)
	if player.Character and player.Character.Parent then
		return
	end
	player:LoadCharacter()
end

local SESSION = {}

function SESSION.hello(player, s)
	local slots = {}
	for _, k in ipairs(SLOTS) do
		slots[k] = summary(s.saved[k]) or false
	end
	return {
		ok = true,
		data = {
			saveAvailable = s.saveAvailable == true,
			slots = slots,
			sandbox = summary(s.saved.sandbox),
			canSandbox = canSandbox(player),
		},
	}
end

function SESSION.newGame(player, s, a)
	local sandbox = a.sandbox == true
	if sandbox and not canSandbox(player) then
		return { ok = false, msg = "The sandbox is only for the developer." }
	end
	local label = (type(a.labelName) == "string" and a.labelName:gsub("^%s+", ""):gsub("%s+$", "") ~= "") and a.labelName:sub(1, 28) or Config.DEFAULT_LABEL_NAME
	local slot = sandbox and "sandbox" or cleanSlot(a.slot)
	startSession(s, GS.new(label, a.starterId, { sandbox = sandbox }), slot)
	s.saved[slot] = s.state
	save(player, true)
	return { ok = true, delta = delta(s, true) }
end

function SESSION.continue(player, s, a)
	local slot = cleanSlot(a.slot)
	local state = s.saved[slot]
	if not state then
		return { ok = false, msg = "No saved game." }
	end
	startSession(s, state, slot)
	return { ok = true, delta = delta(s, true) }
end

-- the home menu: save now / leave the game to the main menu (saves first)
function SESSION.save(player, s)
	if not s.state then
		return { ok = false, msg = "No game running." }
	end
	save(player, true)
	return { ok = true, msg = store and "Game saved (slot " .. tostring(s.slot) .. ")." or "Saving only works in a published place." }
end

function SESSION.leave(player, s)
	if s.state then
		save(player, true)
		s.saved[s.slot] = s.state
	end
	s.state = nil
	if player.Character then
		player.Character:Destroy()
		pcall(function()
			player.Character = nil
		end)
	end
	return SESSION.hello(player, s)
end

function SESSION.deleteSlot(player, s, a)
	local slot = cleanSlot(a.slot)
	if slot == "sandbox" or (s.state and s.slot == slot) then
		return { ok = false, msg = "This slot can't be deleted now." }
	end
	s.saved[slot] = nil
	if store then
		local key = saveKey(player, slot)
		task.spawn(function()
			pcall(function()
				store:RemoveAsync(key)
			end)
		end)
	end
	return { ok = true, msg = "Slot " .. slot .. " deleted." }
end

function SESSION.enterWorld(player, s)
	spawnCharacter(player)
	return { ok = true }
end

function SESSION.resync(player, s)
	if not s.state then
		return { ok = false }
	end
	return { ok = true, delta = delta(s, true) }
end

Remotes.Action.OnServerInvoke = function(player, name, args)
	local s = sessions[player]
	local t0 = os.clock()
	while s and not s.loaded and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	if not s then
		return { ok = false, msg = "No session." }
	end
	-- the client sends its arguments as one JSON string (the same format as the save)
	if type(args) == "string" and #args < 2000000 then
		local okDec, decoded = pcall(function()
			return HttpService:JSONDecode(args)
		end)
		args = okDec and decoded or nil
	end
	if type(args) ~= "table" then
		args = {}
	end
	if SESSION[name] then
		local res = SESSION[name](player, s, args)
		if res.data ~= nil then
			res.data = HttpService:JSONEncode(res.data)
		end
		return res
	end
	if not s.state then
		return { ok = false, msg = "No game running." }
	end
	local okRun, ok, msg, data = pcall(Actions.run, s.state, name, args)
	if not okRun then
		warn("HEADLINER action " .. tostring(name) .. " failed: " .. tostring(ok))
		return { ok = false, msg = "Something went wrong.", delta = delta(s, false) }
	end
	s.dirty = true
	if name == "nextDay" or name == "playShow" or name == "createTour" or name == "sign" then
		save(player, false)
	end
	local dataJson = nil
	if data ~= nil then
		local okEnc, json = pcall(function()
			return HttpService:JSONEncode(data)
		end)
		dataJson = okEnc and json or nil
	end
	return { ok = ok, msg = msg, data = dataJson, delta = delta(s, false) }
end
