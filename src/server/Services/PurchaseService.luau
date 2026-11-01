--!strict
--[[
	PurchaseService — Game Passes and Developer Products.
	  * ProcessReceipt is idempotent: each PurchaseId is recorded in the player's save
	    (ReceiptLedger) and the save must succeed before we tell Roblox "PurchaseGranted".
	    If Roblox calls again for the same PurchaseId we just say "granted" without re-granting.
	  * IDs live in ReplicatedStorage.Shared.Monetization. Items with id 0 are hidden in the
	    live game; in Studio they get a free "Studio test" grant so you can try everything.
	  * Nothing sold here is random. Robux never buys coins.
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

local PurchaseService = {}
local ctx: any = nil
local RECEIPT_MEMORY = 50
local IS_STUDIO = RunService:IsStudio()

local productById: { [number]: string } = {}
local passById: { [number]: string } = {}
local policies: { [Player]: any } = {}

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
	elseif p.kind == "cosmetic" or p.kind == "bundle" then
		for _, id in ipairs(p.grants or {}) do
			ctx.Game.grantCosmetic(player, data, id)
		end
		if p.kind == "bundle" and p.minutes then
			ctx.Game.addBoost(data, p.minutes, p.mult or 2)
		end
	end
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
	if p.rotation and not featuredNow()[key] then
		return false, "That one's not in this week's rotation. It'll be back!"
	end
	if (p.kind == "cosmetic" or p.kind == "bundle") and cosmeticsOwned(data, p.grants) then
		return false, "You already own everything in this."
	end
	if p.kind == "finish" then
		local any = false
		for _, cook in pairs(data.stations) do
			if type(cook) == "table" and not CookLogic.isDone(cook) then
				any = true
			end
		end
		if not any then
			return false, "Nothing is cooking right now."
		end
	end
	if p.id == 0 then
		if IS_STUDIO then
			local msg = grantProduct(player, data, key)
			ctx.World.refreshStations(player)
			return true, "Studio test (free): " .. msg
		end
		return false, "Not on sale yet."
	end
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
	Players.PlayerRemoving:Connect(function(p)
		policies[p] = nil
	end)
end

return PurchaseService
