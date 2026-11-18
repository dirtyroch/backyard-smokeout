--!strict
-- Server entry point: builds remotes, wires every service together, starts them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Services = script.Parent:WaitForChild("Services")
local Boot = require(script.Parent:WaitForChild("Boot"))

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
	Season = require(Services.SeasonService),
	Membership = require(Services.MembershipService),
	Insights = require(Services.InsightsService),
	Crew = require(Services.CrewService),
	Remotes = { Action = action, Push = push },
}

-- World first: it builds the map if it wasn't baked into the place file.
-- Every init runs before any start, so actions are registered and the map exists
-- before Game.start connects PlayerAdded. Game.start is first among starts:
-- a throw in chat, analytics, or a shop API must not leave joins unwired.
local initOrder = { "World", "Game", "Social", "Event", "Egg", "Cosmetics", "Purchase", "Season", "Membership", "Insights", "Crew" }
local startOrder = { "World", "Crew", "Social", "Event", "Egg", "Cosmetics", "Purchase", "Season", "Membership", "Insights" }
Boot.run(ctx, initOrder, { "Game" }, startOrder)
print("[Backyard Smokeout] server ready")
