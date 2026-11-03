--!strict
--[[
	SeasonPass.luau — the Smokehouse Pass (pure logic, unit-tested with Lune).

	  * A season lasts cfg.lengthDays. Season n starts at cfg.epochDay + (n-1) * lengthDays.
	  * Season XP comes from stats you already earn (served, cooks, flips...) counted from the
	    moment the season started for you, plus dailyXP for each day you visit, plus bought or
	    member tier skips. Nothing extra to grind and nothing random.
	  * Free track: a reward every few tiers. Paid track: a reward every tier. Both are looks or
	    titles only. Buying the paid track hands over every paid reward you've already reached.
	  * Tiers you reach are yours forever; the save just remembers how far you've claimed.
]]
local SeasonPass = {}

export type State = {
	id: string,
	base: { [string]: number },
	days: number,
	lastDay: number,
	skips: number,
	paid: boolean,
	freeClaimed: number,
	paidClaimed: number,
}

function SeasonPass.new(): State
	return { id = "", base = {}, days = 0, lastDay = -1, skips = 0, paid = false, freeClaimed = 0, paidClaimed = 0 }
end

export type Info = { index: number, def: any?, startDay: number, endDay: number }

-- Which season is it on `day`? def is nil before the first season or after the last one we've made.
function SeasonPass.seasonAt(day: number, cfg: any): Info
	local index = math.floor((day - cfg.epochDay) / cfg.lengthDays) + 1
	local startDay = cfg.epochDay + (index - 1) * cfg.lengthDays
	local def = if index >= 1 then cfg.seasons[index] else nil
	return { index = index, def = def, startDay = startDay, endDay = startDay + cfg.lengthDays - 1 }
end

function SeasonPass.maxTier(def: any): number
	return #def.paid
end

-- Keep the save in step with the current season and count today's visit.
-- Returns true when a new season started for this player (state was reset).
function SeasonPass.sync(s: State, seasonId: string, stats: { [string]: number }, cfg: any, today: number): boolean
	local reset = false
	if s.id ~= seasonId then
		s.id = seasonId
		s.base = {}
		for stat in pairs(cfg.xp) do
			s.base[stat] = stats[stat] or 0
		end
		s.days = 0
		s.lastDay = -1
		s.skips = 0
		s.paid = false
		s.freeClaimed = 0
		s.paidClaimed = 0
		reset = true
	end
	if s.lastDay ~= today then
		s.lastDay = today
		s.days += 1
	end
	return reset
end

function SeasonPass.xp(s: State, stats: { [string]: number }, cfg: any): number
	local total = s.days * cfg.dailyXP + s.skips * cfg.tierXP
	for stat, w in pairs(cfg.xp) do
		total += math.max(0, (stats[stat] or 0) - (s.base[stat] or 0)) * w
	end
	return total
end

function SeasonPass.tier(xp: number, def: any, cfg: any): number
	return math.min(math.floor(xp / cfg.tierXP), SeasonPass.maxTier(def))
end

-- XP into the current tier and XP needed for the next one (0, 0 at the top).
function SeasonPass.progress(xp: number, def: any, cfg: any): (number, number)
	if SeasonPass.tier(xp, def, cfg) >= SeasonPass.maxTier(def) then
		return 0, 0
	end
	return xp % cfg.tierXP, cfg.tierXP
end

-- Can `n` tier skips be used without going past the top tier?
function SeasonPass.canSkip(s: State, stats: { [string]: number }, def: any, cfg: any, n: number): boolean
	local cur = SeasonPass.tier(SeasonPass.xp(s, stats, cfg), def, cfg)
	return cur + n <= SeasonPass.maxTier(def)
end

-- Adds a skip that lands on the start of the next tier (any partial progress is kept on top).
function SeasonPass.addSkips(s: State, n: number)
	s.skips += n
end

export type Reward = { track: string, tier: number, reward: any }

-- Hand out every reward reached but not yet claimed. Mutates the claimed counters.
function SeasonPass.claim(s: State, stats: { [string]: number }, def: any, cfg: any): { Reward }
	local out = {}
	local t = SeasonPass.tier(SeasonPass.xp(s, stats, cfg), def, cfg)
	for i = s.freeClaimed + 1, t do
		local r = def.free[i]
		if r then
			table.insert(out, { track = "free", tier = i, reward = r })
		end
	end
	s.freeClaimed = math.max(s.freeClaimed, t)
	if s.paid then
		for i = s.paidClaimed + 1, t do
			table.insert(out, { track = "paid", tier = i, reward = def.paid[i] })
		end
		s.paidClaimed = math.max(s.paidClaimed, t)
	end
	return out
end

return SeasonPass
