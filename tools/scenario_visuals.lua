-- Renders every screen visual (Client/Visuals.lua) into one picture: VISUALS_T = the moment (seconds)
-- usage: python3 tools/visuals.py <api_classes.lua> <out dir>
dofile(RENDER_LUA)
local RS = game:GetService("ReplicatedStorage")
local root = MOCK.buildTree(RS, TREE)
local Visuals = require(root.Client.Visuals)
local gui = Instance.new("ScreenGui")
gui.Parent = MOCK.playerGui
local list = Visuals.LIST
local cols = 4
for i, kind in ipairs(list) do
	local x, y = ((i - 1) % cols) * 480, math.floor((i - 1) / cols) * 270
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x + 4, y + 4)
	frame.Size = UDim2.fromOffset(472, 262)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.ClipsDescendants = true
	frame.Parent = gui
	local face = { frame = frame }
	for k = 0, 3 do
		Visuals.draw(face, kind, { t = (VISUALS_T or 7.3) + k * 0.05, beat = 0.6, c1 = Color3.fromRGB(255, 70, 160), c2 = Color3.fromRGB(70, 140, 255) })
		face.visNext = 0
	end
	local lbl = Instance.new("TextLabel")
	lbl.Text = kind
	lbl.Size = UDim2.fromOffset(200, 24)
	lbl.Position = UDim2.fromOffset(x + 10, y + 8)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 18
	lbl.ZIndex = 99
	lbl.Parent = gui
end
WRITE(OUT_DIR .. "/visuals.html", MOCK.renderHTML(gui, "visuals"))
print("visuals done")
