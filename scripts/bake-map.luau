--!nocheck
-- Bakes the generated map into the built place file so it's visible in Studio edit mode.
-- Usage: lune run scripts/bake-map BackyardSmokeout.rbxlx
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config")
local Content = require("../src/shared/Content")
local WorldBuilder = require("../src/shared/WorldBuilder")

local path = process.args[1] or "BackyardSmokeout.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))
local workspace = game:GetService("Workspace")

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
for _, c in ipairs(workspace:GetChildren()) do
	if c.Name == "Baseplate" then
		c:Destroy()
	end
end

local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	NumberSequence = roblox.NumberSequence,
	NumberRange = roblox.NumberRange,
	ColorSequence = roblox.ColorSequence,
	Vector2 = roblox.Vector2,
}
local map = WorldBuilder.build(env, workspace, Config, Content)

local count = 0
local function walk(inst)
	count += 1
	for _, c in ipairs(inst:GetChildren()) do
		walk(c)
	end
end
walk(map)

fs.writeFile(path, roblox.serializePlace(game, true))
print(string.format("Baked map into %s (%d instances)", path, count))
