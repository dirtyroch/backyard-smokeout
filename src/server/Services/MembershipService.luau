--!strict
--[[
	MembershipService — Pit Crew Club (Roblox subscription), Roblox Premium and private servers.
	  * Pit Crew Club: status comes from MarketplaceService:GetUserSubscriptionStatusAsync and
	    Players.UserSubscriptionStatusChanged. Shown only when the ID is set and PolicyService
	    says the player can subscribe. Perks: a monthly look kept forever, a name tag, a daily
	    server-wide Smoke Shower and one free Smokehouse Pass tier a month. Never coins.
	  * Premium: members get a free look (Config.Premium.look). Premium Payouts are automatic.
	  * Private servers: the owner gets a "Ranch Host" tag and a Smoke Shower every 10 minutes.
	In Studio, the Club can be test-toggled for free (saved as owned["sub:PitCrewClub"]).
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetization = require(Shared.Monetization)
local Storefront = require(Shared.Logic.Storefront)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Holiday = require(Shared.Logic.Holiday)

local MembershipService = {}
local ctx: any = nil
local IS_STUDIO = RunService:IsStudio()
local CLUB = Monetization.Subscriptions.PitCrewClub

local members: { [Player]: boolean? } = {}
local hostShowerAt = -1e9

local function today(): number
	return TimeUtil.dayNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

function MembershipService.isMember(player: Player): boolean
	return members[player] == true
end

function MembershipService.isHost(player: Player): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0 and game.PrivateServerOwnerId == player.UserId
end

function MembershipService.isPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Can this player be offered the Club at all? (ID set or Studio, and Roblox policy allows it)
function MembershipService.offerable(player: Player): boolean
	if CLUB.id == "" and not IS_STUDIO then
		return false
	end
	if IS_STUDIO then
		return true
	end
	local policy = ctx.Purchase.policy(player)
	return policy ~= nil and policy.IsEligibleToPurchaseSubscription == true
end

-- Monthly perks: this month's look (kept forever) and one free Smokehouse Pass tier.
local function monthly(player: Player, data: any)
	if not members[player] then
		return
	end
	local y, m = Holiday.civilFromDays(today())
	local key = Storefront.monthKey(y, m)
	if data.club.month == key then
		return
	end
	data.club.month = key
	local look = Storefront.clubLook(Config.Club.looks, y, m)
	ctx.Game.grantCosmetic(player, data, look)
	ctx.Season.grantSkips(player, data, Config.Club.monthlyTierSkips)
	local def = Config.Cosmetics[look]
	ctx.Game.toast(player, string.format("🔧 Pit Crew Club: this month's look is %s. It's yours to keep!", def and def.name or look), "good")
	ctx.Game.markDirty(player)
end

local function refreshClub(player: Player)
	local data = ctx.Game.dataOf(player)
	if not data then
		return
	end
	local on = false
	if CLUB.id ~= "" then
		local ok, status = pcall(function()
			return MarketplaceService:GetUserSubscriptionStatusAsync(player, CLUB.id)
		end)
		on = ok and type(status) == "table" and status.IsSubscribed == true
	end
	if IS_STUDIO and data.owned["sub:PitCrewClub"] then
		on = true
	end
	local was = members[player] == true
	members[player] = on or nil
	if on then
		monthly(player, data)
	end
	if on ~= was then
		ctx.Cosmetics.apply(player)
		ctx.Game.markDirty(player)
	end
end

local function refreshPremium(player: Player)
	local data = ctx.Game.dataOf(player)
	if data and MembershipService.isPremium(player) and not data.owned[Config.Premium.look] then
		ctx.Game.grantCosmetic(player, data, Config.Premium.look)
		ctx.Game.toast(player, "⭐ Thanks for being a Roblox Premium member! The Premium Pitmaster Bandana is in your closet.", "good")
	end
end

function MembershipService.onLoaded(player: Player, data: any)
	if MembershipService.isHost(player) then
		data.titles[Config.PrivateServer.hostTitle] = true
	end
	task.spawn(refreshClub, player)
	refreshPremium(player)
end

function MembershipService.onNewDay(player: Player, data: any)
	monthly(player, data)
end

-- Share a free Smoke Shower with everyone else in the server.
local function shower(from: Player, label: string)
	local now = workspace:GetServerTimeNow()
	for other in pairs(ctx.Game.runtime) do
		local od = other ~= from and ctx.Game.dataOf(other) or nil
		if od and od.boost.untilT <= now then
			ctx.Game.addBoost(od, Config.Club.showerMinutes, Config.FairPlay.showerMult)
			ctx.Game.markDirty(other)
		end
	end
	ctx.Game.announce(string.format("💨 %s %s shared a Smoke Shower! Everyone else gets x%.2g cook speed for %d min.", label, from.DisplayName, Config.FairPlay.showerMult, Config.Club.showerMinutes), "#7CD1C1")
end

function MembershipService.snapshot(player: Player, data: any): any
	return {
		club = members[player] == true,
		clubOffer = MembershipService.offerable(player),
		clubShowerReady = members[player] == true and data.club.showerDay ~= today(),
		premium = MembershipService.isPremium(player),
		host = MembershipService.isHost(player),
		hostShowerReady = MembershipService.isHost(player) and os.clock() - hostShowerAt >= Config.PrivateServer.hostShowerCooldown,
	}
end

function MembershipService.init(c: any)
	ctx = c
	local A: any = c.Game.Actions
	A.Subscribe = function(player, data): (boolean, string?)
		if members[player] then
			return false, "You're already in the Pit Crew Club. Thanks!"
		end
		if not MembershipService.offerable(player) then
			return false, "The Pit Crew Club isn't available here."
		end
		if CLUB.id == "" then
			data.owned["sub:PitCrewClub"] = true
			refreshClub(player)
			return true, "Studio test: Pit Crew Club on (only in Studio)."
		end
		ctx.Insights.shopPrompt(player, "PitCrewClub")
		MarketplaceService:PromptSubscriptionPurchase(player, CLUB.id)
		return true, nil
	end
	A.ClubShower = function(player, data): (boolean, string?)
		if not members[player] then
			return false, "That's a Pit Crew Club perk."
		end
		if data.club.showerDay == today() then
			return false, "You've shared today's Pit Crew Smoke Shower. Thanks! See you tomorrow."
		end
		data.club.showerDay = today()
		shower(player, "🔧 Pit Crew member")
		return true, nil
	end
	A.HostShower = function(player, _data): (boolean, string?)
		if not MembershipService.isHost(player) then
			return false, "Only the host of a private server can do that."
		end
		if os.clock() - hostShowerAt < Config.PrivateServer.hostShowerCooldown then
			return false, "The smoker's still warming up. Try again in a few minutes."
		end
		hostShowerAt = os.clock()
		shower(player, "🏠 Ranch Host")
		return true, nil
	end
	A.PremiumInfo = function(player, _data): (boolean, string?)
		if MembershipService.isPremium(player) then
			return false, "You're already a Premium member. Thanks!"
		end
		pcall(function()
			MarketplaceService:PromptPremiumPurchase(player)
		end)
		return true, nil
	end
end

function MembershipService.start()
	Players.UserSubscriptionStatusChanged:Connect(function(player: Player, subscriptionId: string)
		if subscriptionId == CLUB.id then
			refreshClub(player)
		end
	end)
	Players.PlayerMembershipChanged:Connect(function(player: Player)
		refreshPremium(player)
		ctx.Game.markDirty(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		members[p] = nil
	end)
end

return MembershipService
