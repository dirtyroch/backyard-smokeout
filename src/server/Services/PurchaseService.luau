--!strict
--[[
	PurchaseService — Game Passes and Developer Products.
	  * ProcessReceipt is idempotent: each PurchaseId is recorded in the player's save
	    (ReceiptLedger) and the save must succeed before we tell Roblox "PurchaseGranted".
	    If Roblox calls again for the same PurchaseId we just say "granted" without re-granting.
	  * IDs live in ReplicatedStorage.Shared.Monetization. Items with id 0 are hidden in the
	    live game; in Studio they get a free "Studio test" grant so you can try everything.
	  * Nothing sold here is random. Robux never buys coins.
	  * Every "can I buy this?" rule is in Shared.Logic.Storefront (unit-tested): weekly rotation,
	    Turkey Day week only, one-per-account packs, nothing you already own, season limits.
	  * Roblox PolicyService info is fetched per player; MembershipService uses
	    IsEligibleToPurchaseSubscription to decide who sees the Pit Crew Club.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Monetization = require(Shared.Monetization)
local ReceiptLedger = require(Shared.Logic.ReceiptLedger)
local CookLogic = require(Shared.Logic.CookLogic)
local CookOff = require(Shared.Logic.CookOff)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Gifting = require(Shared.Logic.Gifting)
local Storefront = require(Shared.Logic.Storefront)

local PurchaseService = {}
local ctx: any = nil
local RECEIPT_MEMORY = 50
local IS_STUDIO = RunService:IsStudio()

local productById: { [number]: string } = {}
local passById: { [number]: string } = {}
local policies: { [Player]: any } = {}
local pendingGifts: { [Player]: { [string]: Gifting.Pending } } = {}
local deliverGift: (Player, any, Player, any, string) -> ()

for key, p in pairs(Monetization.Products) do
	if p.id ~= 0 then
		productById[p.id] = key
	end
end
for key, p in pairs(Monetization.Passes) do
	if p.id ~= 0 then
		passById[p.id] = key
	end
end

local function featuredNow(): { [string]: boolean }
	local week = TimeUtil.weekNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
	local set = {}
	for _, k in ipairs(CookOff.rotation(Config.RotationPool, Config.ROTATION_FEATURED, week)) do
		set[k] = true
	end
	return set
end

-- Which items can be bought here: real ID, or anything while play-testing in Studio.
function PurchaseService.availability(): any
	local out = { products = {}, passes = {}, studio = IS_STUDIO }
	for key, p in pairs(Monetization.Products) do
		out.products[key] = p.id ~= 0 or IS_STUDIO
	end
	for key, p in pairs(Monetization.Passes) do
		out.passes[key] = p.id ~= 0 or IS_STUDIO
	end
	return out
end

function PurchaseService.loadPasses(player: Player): { [string]: boolean }
	local owned = {}
	for key, p in pairs(Monetization.Passes) do
		if p.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
			if ok and has then
				owned[key] = true
			end
		end
	end
	-- Studio test grants persist in the save under owned["pass:<key>"] (Studio only).
	local data = ctx.Game.dataOf(player)
	if IS_STUDIO and data then
		for key in pairs(Monetization.Passes) do
			if data.owned["pass:" .. key] then
				owned[key] = true
			end
		end
	end
	if owned.VIPPatio and data then
		data.owned.vip_lights = true
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		policies[player] = ok and info or nil
	end)
	return owned
end

-- Roblox policy for this player (paid random items are never sold here regardless).
function PurchaseService.policy(player: Player): any?
	return policies[player]
end

local function storeCtx(_player: Player, data: any): Storefront.Ctx
	local cooking = false
	for _, cook in pairs(data.stations) do
		if type(cook) == "table" and not CookLogic.isDone(cook) then
			cooking = true
		end
	end
	local active, paid, canSkip = ctx.Season.storeState(data)
	return {
		owned = data.owned,
		featured = featuredNow(),
		eventActive = ctx.Game.turkeyWeek().active,
		onceBought = data.purchases.once,
		cooking = cooking,
		seasonActive = active,
		seasonPaid = paid,
		canSkip = canSkip,
	}
end

local function cosmeticsOwned(data: any, grants: { string }?): boolean
	if not grants or #grants == 0 then
		return false
	end
	for _, id in ipairs(grants) do
		if not data.owned[id] then
			return false
		end
	end
	return true
end

-- Apply a developer product to a player's data. Returns a toast message.
local function grantProduct(player: Player, data: any, key: string): string
	local p = Monetization.Products[key]
	if p.kind == "boost" then
		ctx.Game.addBoost(data, p.minutes or 30, p.mult or 2)
		-- Fair Play: everyone else in the server gets a free Smoke Shower.
		local now = workspace:GetServerTimeNow()
		for other in pairs(ctx.Game.runtime) do
			local od = other ~= player and ctx.Game.dataOf(other) or nil
			if od and od.boost.untilT <= now then
				ctx.Game.addBoost(od, Config.FairPlay.showerMinutes, Config.FairPlay.showerMult)
				ctx.Game.markDirty(other)
				ctx.Game.toast(other, string.format("💨 Smoke Shower from %s! Everyone gets x%.2g speed for %d min.", player.DisplayName, Config.FairPlay.showerMult, Config.FairPlay.showerMinutes), "good")
			end
		end
	elseif p.kind == "finish" then
		local t = workspace:GetServerTimeNow()
		ctx.Game.advanceAll(player, data, t, false)
		for _, cook in pairs(data.stations) do
			if type(cook) == "table" and not CookLogic.isDone(cook) then
				CookLogic.finishNow(cook, t)
			end
		end
	elseif p.kind == "cut" and p.cut then
		data.cuts[p.cut] = (data.cuts[p.cut] or 0) + (p.count or 1)
	elseif p.kind == "cosmetic" or p.kind == "bundle" or p.kind == "starter" then
		for _, id in ipairs(p.grants or {}) do
			ctx.Game.grantCosmetic(player, data, id)
		end
		if (p.kind == "bundle" or p.kind == "starter") and p.minutes then
			ctx.Game.addBoost(data, p.minutes, p.mult or 2)
		end
		if p.kind == "starter" and p.cut then
			data.cuts[p.cut] = (data.cuts[p.cut] or 0) + (p.count or 1)
		end
	elseif p.kind == "season" then
		ctx.Season.grantPaid(player, data)
	elseif p.kind == "tierskip" then
		ctx.Season.grantSkips(player, data, p.count or 1)
	end
	if p.once then
		data.purchases.once[key] = true
	end
	data.purchases.count += 1
	ctx.Insights.shopBought(player, key)
	ctx.Game.markDirty(player)
	return "Thanks! " .. p.icon .. " " .. p.name .. " is yours."
end

local function grantPass(player: Player, key: string)
	local r = ctx.Game.runtime[player]
	if not r then
		return
	end
	r.passes[key] = true
	local data = ctx.Game.dataOf(player)
	if key == "VIPPatio" and data then
		data.owned.vip_lights = true
		data.equipped.patio = "vip_lights"
	end
	ctx.Game.toast(player, "Thanks! " .. Monetization.Passes[key].icon .. " " .. Monetization.Passes[key].name .. " is active.", "good")
	ctx.World.refreshStations(player)
	ctx.Cosmetics.apply(player)
	ctx.Game.markDirty(player)
end

function PurchaseService.prompt(player: Player, kind: string, key: string): (boolean, string?)
	local data = ctx.Game.dataOf(player)
	if not data then
		return false, "Still loading..."
	end
	if kind == "pass" then
		local p = Monetization.Passes[key]
		if not p then
			return false, "Not found."
		end
		if ctx.Game.hasPass(player, key) then
			return false, "You already have this."
		end
		if p.id == 0 then
			if IS_STUDIO then
				data.owned["pass:" .. key] = true
				grantPass(player, key)
				return true, "Studio test: pass granted for free (only in Studio)."
			end
			return false, "Not on sale yet."
		end
		MarketplaceService:PromptGamePassPurchase(player, p.id)
		return true, nil
	end
	local p = Monetization.Products[key]
	if not p then
		return false, "Not found."
	end
	local ok, why = Storefront.canBuy(key, p, storeCtx(player, data))
	if not ok then
		return false, why
	end
	ctx.Insights.shopPrompt(player, key)
	if p.id == 0 then
		if IS_STUDIO then
			local msg = grantProduct(player, data, key)
			ctx.World.refreshStations(player)
			return true, "Studio test (free): " .. msg
		end
		return false, "Not on sale yet."
	end
	if pendingGifts[player] then
		pendingGifts[player][key] = nil -- buying for yourself is never redirected to an old gift intent
	end
	MarketplaceService:PromptProductPurchase(player, p.id)
	return true, nil
end

-- Hand a looks-only product to another player and celebrate it.
deliverGift = function(giver: Player, giverData: any, recipient: Player, rdata: any, key: string)
	local p = Monetization.Products[key]
	for _, id in ipairs(p.grants or {}) do
		ctx.Game.grantCosmetic(recipient, rdata, id)
	end
	if p.kind == "bundle" and p.minutes then
		ctx.Game.addBoost(rdata, p.minutes, p.mult or 2)
	end
	rdata.stats.giftsGot = (rdata.stats.giftsGot or 0) + 1
	giverData.stats.giftsSent = (giverData.stats.giftsSent or 0) + 1
	local firstTitle = Config.Gifting.firstGiftTitle
	local newTitle = not giverData.titles[firstTitle]
	giverData.titles[firstTitle] = true
	ctx.Game.markDirty(recipient)
	ctx.Game.markDirty(giver)
	ctx.Game.toast(recipient, string.format("🎁 %s gifted you %s %s! It's in your closet.", giver.DisplayName, p.icon, p.name), "good")
	ctx.Game.toast(giver, string.format("🎁 Gift sent! %s now has %s %s.%s", recipient.DisplayName, p.icon, p.name, newTitle and ' You earned the "' .. firstTitle .. '" title.' or ""), "good")
	ctx.Game.fx(recipient, "gift", { from = giver.DisplayName, item = p.name, icon = p.icon })
	ctx.Game.announce(string.format("🎁 %s gifted %s to %s!", giver.DisplayName, p.name, recipient.DisplayName), "#FF8FAB")
	ctx.Cosmetics.apply(recipient)
	ctx.World.refreshStations(recipient)
end

-- Gift a looks-only product to another player in this server.
function PurchaseService.promptGift(player: Player, key: string, recipientUserId: number): (boolean, string?)
	local data = ctx.Game.dataOf(player)
	if not data then
		return false, "Still loading..."
	end
	local p = Monetization.Products[key]
	if not p then
		return false, "Not found."
	end
	if p.rotation and not featuredNow()[key] then
		return false, "That one's not in this week's rotation. It'll be back!"
	end
	if p.event == "turkeyday" and not ctx.Game.turkeyWeek().active then
		return false, "The Turkey Day looks are on sale during Thanksgiving week. They come back next year."
	end
	local recipient = Players:GetPlayerByUserId(recipientUserId)
	local rdata = recipient and ctx.Game.dataOf(recipient) or nil
	local ok, why = Gifting.check(player.UserId, (recipient and rdata) and recipient.UserId or nil, p, rdata ~= nil and cosmeticsOwned(rdata, p.grants))
	if not ok then
		return false, why
	end
	-- A held gift (recipient left before an earlier gift landed) goes out free.
	if Gifting.takeHeld(data.giftsHeld, key) then
		deliverGift(player, data, recipient :: Player, rdata, key)
		return true, nil
	end
	if p.id == 0 then
		if IS_STUDIO then
			deliverGift(player, data, recipient :: Player, rdata, key)
			return true, "Studio test (free gift)."
		end
		return false, "Not on sale yet."
	end
	pendingGifts[player] = pendingGifts[player] or {}
	Gifting.remember(pendingGifts[player], key, recipientUserId, os.time())
	MarketplaceService:PromptProductPurchase(player, p.id)
	return true, nil
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = ctx.Data.waitFor(player, 10)
	if not profile or not ctx.Game.runtime[player] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = profile.data
	local purchaseId = tostring(info.PurchaseId)
	if ReceiptLedger.has(data.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = productById[info.ProductId]
	if not key then
		warn("[PurchaseService] unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Was this purchase a gift for someone else in the server?
	local giftTo = pendingGifts[player] and Gifting.claim(pendingGifts[player], key, os.time(), Config.Gifting.ttlSeconds) or nil
	if giftTo then
		local recipient = Players:GetPlayerByUserId(giftTo)
		local rprofile = recipient and ctx.Data.get(recipient) or nil
		local gok, gerr = pcall(function()
			if recipient and rprofile and ctx.Game.runtime[recipient] then
				deliverGift(player, data, recipient, rprofile.data, key)
				ctx.Data.save(rprofile, false)
			else
				Gifting.hold(data.giftsHeld, key)
				ctx.Game.toast(player, "They left before the gift landed, so it's saved for you. Open the shop and tap Gift on " .. Monetization.Products[key].name .. " to send it to anyone, free.", "info")
			end
		end)
		if not gok then
			warn("[PurchaseService] gift failed: " .. tostring(gerr))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		ReceiptLedger.add(data.receipts, purchaseId, RECEIPT_MEMORY)
		data.purchases.count += 1
		ctx.Insights.shopBought(player, "Gift:" .. key)
		ctx.Game.markDirty(player)
		if not ctx.Data.save(profile, false) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local ok, msg = pcall(grantProduct, player, data, key)
	if not ok then
		warn("[PurchaseService] grant failed: " .. tostring(msg))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ReceiptLedger.add(data.receipts, purchaseId, RECEIPT_MEMORY)
	-- Only confirm once the grant + receipt id are safely saved.
	if not ctx.Data.save(profile, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ctx.Game.toast(player, msg, "good")
	ctx.World.refreshStations(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService.init(c: any)
	ctx = c
end

function PurchaseService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
		-- A cancelled gift prompt shouldn't leave a stale intent that hijacks a later self-purchase.
		local key = productById[productId]
		local plr = Players:GetPlayerByUserId(userId)
		if not purchased and key and plr and pendingGifts[plr] then
			pendingGifts[plr][key] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		policies[p] = nil
		pendingGifts[p] = nil
	end)
end

return PurchaseService
