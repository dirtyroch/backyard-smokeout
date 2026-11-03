--!strict
--[[
	InsightsService — Roblox Analytics (Creator Dashboard > Analytics).
	  * Onboarding funnel: each step once per account (saved in data.analytics.onboard).
	  * "PitShop" funnel: opened shop -> opened a tab -> tapped buy -> bought, per visit.
	  * Economy: coin sources and sinks, added up and sent once a minute per player.
	  * Smokehouse Pass progression: each tier reached.
	Every call is wrapped in pcall; analytics can never break the game. Nothing is shown to
	players and nothing here changes prices or offers per player.
]]
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Funnels = require(Shared.Logic.Funnels)

local InsightsService = {}
local ctx: any = nil
local STEPS = Funnels.onboardingSteps(Config.RookieSteps)

local shopSession: { [Player]: { id: string, step: number } } = {}
local coinBuckets: { [Player]: Funnels.Bucket } = {}

local function try(fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn("[Insights] " .. tostring(err))
	end
end

-- Log any onboarding steps this save has newly reached.
function InsightsService.onboarding(player: Player, data: any)
	if type(data.analytics) ~= "table" then
		return
	end
	local reached = Funnels.onboardingReached(data, Config.RookieSteps)
	for _, i in ipairs(Funnels.newSteps(data.analytics.onboard or 0, reached)) do
		try(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, i, STEPS[i])
		end)
		data.analytics.onboard = i
	end
end

local function shopStep(player: Player, step: number, extra: { [string]: any }?)
	local s = shopSession[player]
	if step == 1 or not s then
		s = { id = HttpService:GenerateGUID(false), step = 0 }
		shopSession[player] = s
	end
	if step <= s.step and step ~= 3 then
		return -- each step once per visit (taps can repeat)
	end
	s.step = math.max(s.step, step)
	local id = s.id
	try(function()
		AnalyticsService:LogFunnelStepEvent(player, "PitShop", id, step, Funnels.SHOP[step], extra)
	end)
end

function InsightsService.shopOpened(player: Player)
	shopStep(player, 1)
end
function InsightsService.shopTab(player: Player, tab: string)
	shopStep(player, 2, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tab })
end
function InsightsService.shopPrompt(player: Player, sku: string)
	shopStep(player, 3, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sku })
end
function InsightsService.shopBought(player: Player, sku: string)
	shopStep(player, 4, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = sku })
	try(function()
		AnalyticsService:LogCustomEvent(player, "RobuxPurchase:" .. sku, 1)
	end)
end

function InsightsService.coins(player: Player, amount: number, tx: string, sku: string)
	local b = coinBuckets[player]
	if not b then
		b = {}
		coinBuckets[player] = b
	end
	Funnels.addCoins(b, amount, tx, sku)
end

function InsightsService.seasonTier(player: Player, seasonId: string, tier: number)
	try(function()
		AnalyticsService:LogProgressionCompleteEvent(player, "SmokehousePass_" .. seasonId, tier, "Tier " .. tier)
	end)
end

local function flush(player: Player)
	local b = coinBuckets[player]
	local data = ctx.Game.dataOf(player)
	coinBuckets[player] = nil
	if not b or not data then
		return
	end
	for _, e in pairs(b) do
		try(function()
			local flow = e.flow == "Source" and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
			AnalyticsService:LogEconomyEvent(player, flow, "Coins", e.amount, math.max(0, data.coins), e.tx, e.sku)
		end)
	end
end

function InsightsService.init(c: any)
	ctx = c
end

function InsightsService.start()
	task.spawn(function()
		while true do
			task.wait(60)
			for player in pairs(coinBuckets) do
				flush(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		flush(p)
		shopSession[p] = nil
	end)
end

return InsightsService
