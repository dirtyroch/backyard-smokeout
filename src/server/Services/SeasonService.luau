--!strict
--[[
	SeasonService — the Smokehouse Pass on the server (rules live in Shared.Logic.SeasonPass).
	Rewards are looks and titles only. Claims happen automatically: reach a tier and it's yours.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SeasonPass = require(Shared.Logic.SeasonPass)
local TimeUtil = require(Shared.Logic.TimeUtil)
local Holiday = require(Shared.Logic.Holiday)

local SeasonService = {}
local ctx: any = nil
local CFG = Config.SeasonPass

local function today(): number
	return TimeUtil.dayNumber(os.time(), Config.TIMEZONE_OFFSET_HOURS)
end

function SeasonService.current(): SeasonPass.Info
	return SeasonPass.seasonAt(today(), CFG)
end

-- Bring the save up to date with the current season (call on join, each tick is cheap).
function SeasonService.sync(player: Player, data: any)
	local info = SeasonService.current()
	if not info.def then
		return
	end
	if SeasonPass.sync(data.seasonPass, info.def.id, data.stats, CFG, today()) then
		ctx.Game.markDirty(player)
	end
end

local function rewardName(r: any): string
	if r.cosmetic then
		local def = Config.Cosmetics[r.cosmetic]
		return def and def.name or r.cosmetic
	end
	return '"' .. tostring(r.title) .. '" title'
end

-- Hand out any tiers reached. Quiet and celebratory, never a nag.
function SeasonService.check(player: Player, data: any)
	local info = SeasonService.current()
	if not info.def or data.seasonPass.id ~= info.def.id then
		return
	end
	local before = SeasonPass.tier(SeasonPass.xp(data.seasonPass, data.stats, CFG), info.def, CFG)
	local got = SeasonPass.claim(data.seasonPass, data.stats, info.def, CFG)
	if #got == 0 then
		return
	end
	local names = {}
	for _, g in ipairs(got) do
		if g.reward.cosmetic then
			ctx.Game.grantCosmetic(player, data, g.reward.cosmetic)
		elseif g.reward.title then
			data.titles[g.reward.title] = true
		end
		table.insert(names, rewardName(g.reward))
	end
	ctx.Game.toast(player, string.format("%s Smokehouse Pass tier %d! You got: %s.", info.def.icon, before, table.concat(names, ", ")), "good")
	ctx.Game.fx(player, "season", { tier = before, icon = info.def.icon })
	if ctx.Insights then
		ctx.Insights.seasonTier(player, info.def.id, before)
	end
	ctx.Cosmetics.apply(player)
	ctx.Game.markDirty(player)
end

-- Can the paid track / n skips be bought right now?
function SeasonService.storeState(data: any): (boolean, boolean, (number) -> boolean)
	local info = SeasonService.current()
	local active = info.def ~= nil and data.seasonPass.id == info.def.id
	return active, active and data.seasonPass.paid, function(n: number): boolean
		return active and SeasonPass.canSkip(data.seasonPass, data.stats, info.def, CFG, n)
	end
end

function SeasonService.grantPaid(player: Player, data: any)
	SeasonService.sync(player, data)
	data.seasonPass.paid = true
	SeasonService.check(player, data)
end

function SeasonService.grantSkips(player: Player, data: any, n: number)
	SeasonService.sync(player, data)
	local info = SeasonService.current()
	if not info.def then
		return
	end
	-- never past the top: extra skips are simply not added (the shop blocks this anyway)
	local cur = SeasonPass.tier(SeasonPass.xp(data.seasonPass, data.stats, CFG), info.def, CFG)
	SeasonPass.addSkips(data.seasonPass, math.max(0, math.min(n, SeasonPass.maxTier(info.def) - cur)))
	SeasonService.check(player, data)
end

-- What the client needs to draw the Smokehouse Pass window.
function SeasonService.snapshot(data: any): any
	local info = SeasonService.current()
	if not info.def or data.seasonPass.id ~= info.def.id then
		local nextStart = info.startDay + (info.index < 1 and 0 or CFG.lengthDays)
		return { active = false, nextLabel = Holiday.label(info.index < 1 and CFG.epochDay or nextStart) }
	end
	local xp = SeasonPass.xp(data.seasonPass, data.stats, CFG)
	local into, need = SeasonPass.progress(xp, info.def, CFG)
	return {
		active = true,
		id = info.def.id,
		name = info.def.name,
		icon = info.def.icon,
		number = info.index,
		starts = Holiday.label(info.startDay),
		ends = Holiday.label(info.endDay),
		tier = SeasonPass.tier(xp, info.def, CFG),
		max = SeasonPass.maxTier(info.def),
		xp = xp,
		into = into,
		need = need,
		paid = data.seasonPass.paid,
	}
end

function SeasonService.init(c: any)
	ctx = c
end

return SeasonService
