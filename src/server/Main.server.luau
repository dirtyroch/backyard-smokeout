--!strict
-- Server entry point: builds remotes, wires every service together, starts them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Services = script.Parent:WaitForChild("Services")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local action = Instance.new("RemoteFunction")
action.Name = "Action"
action.Parent = remotes
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = remotes
remotes.Parent = ReplicatedStorage

Players.CharacterAutoLoads = true

local ctx = {
	Data = require(Services.DataService),
	World = require(Services.WorldService),
	Game = require(Services.GameService),
	Social = require(Services.SocialService),
	Event = require(Services.EventService),
	Egg = require(Services.EggService),
	Cosmetics = require(Services.CosmeticService),
	Purchase = require(Services.PurchaseService),
	Remotes = { Action = action, Push = push },
}

-- World first: it builds the map if it wasn't baked into the place file.
local order = { "World", "Game", "Social", "Event", "Egg", "Cosmetics", "Purchase" }
for _, name in ipairs(order) do
	local svc = (ctx :: any)[name]
	if svc.init then
		svc.init(ctx)
	end
end
ctx.Data.start()
for _, name in ipairs({ "World", "Social", "Event", "Egg", "Cosmetics", "Purchase", "Game" }) do
	local svc = (ctx :: any)[name]
	if svc.start then
		svc.start()
	end
end
print("[Backyard Smokeout] server ready")
