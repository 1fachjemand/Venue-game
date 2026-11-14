-- HEADLINER server: disables avatars and handles saving (DataStore only works in a published place).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = false

local Remotes = ReplicatedStorage:WaitForChild("Headliner"):WaitForChild("Remotes")
local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("HeadlinerSave_v1")
end)

local lastSave = {}

Remotes.LoadGame.OnServerInvoke = function(player)
	if not store then
		return nil, "unavailable"
	end
	local ok, data = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if ok then
		return data, "ok"
	end
	return nil, "unavailable"
end

Remotes.SaveGame.OnServerEvent:Connect(function(player, json)
	if not store or type(json) ~= "string" or #json > 3500000 then
		return
	end
	local now = os.clock()
	if lastSave[player] and now - lastSave[player] < 6 then
		return
	end
	lastSave[player] = now
	pcall(function()
		store:SetAsync("player_" .. player.UserId, json)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastSave[player] = nil
end)
