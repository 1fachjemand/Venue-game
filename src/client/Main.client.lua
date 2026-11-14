-- HEADLINER client entry point
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Root = ReplicatedStorage:WaitForChild("Headliner")
local App = require(Root:WaitForChild("Client"):WaitForChild("App"))
App.start()
