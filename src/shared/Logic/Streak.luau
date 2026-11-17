--!strict
--[[
	Forgiving daily streak.
	  * Claim once per (Texas) day.
	  * Miss exactly one day? Your one free miss for the week covers it automatically.
	  * Miss more? You drop back to the first day of your current 7-day week, never to zero.
]]
local Streak = {}

export type State = { lastDay: number, count: number, best: number, freeMissWeek: number }
export type Result = { ok: boolean, count: number, cycleDay: number, week: number, usedFreeMiss: boolean, softReset: boolean }

local function weekOf(day: number): number
	return math.floor((day + 3) / 7)
end

function Streak.new(): State
	return { lastDay = -1, count = 0, best = 0, freeMissWeek = -1 }
end

-- True only when a claim would actually pay. A clock that moved backwards used to
-- light the button, then refuse and rewrite lastDay.
function Streak.canClaim(s: State, today: number): boolean
	return Streak.forecast(s, today).ok
end

-- What claim would do, without changing `s`. The daily cards use this count so a
-- soft reset doesn't show next week's payout.
function Streak.forecast(s: State, today: number): Result
	local copy: State = {
		lastDay = s.lastDay,
		count = s.count,
		best = s.best,
		freeMissWeek = s.freeMissWeek,
	}
	return Streak.claim(copy, today)
end

-- If the saved day is in the future, park it on today without paying again.
-- Called with the server's day number (os.time), never a client clock.
function Streak.healClock(s: State, today: number): boolean
	if type(today) ~= "number" or today ~= today then
		return false
	end
	local day = math.floor(today)
	if type(s.lastDay) ~= "number" or s.lastDay ~= s.lastDay then
		s.lastDay = -1
		return true
	end
	if s.lastDay > day then
		s.lastDay = day
		return true
	end
	return false
end

function Streak.claim(s: State, today: number): Result
	-- A brand-new streak stores lastDay = -1. That is also a real day number, so
	-- "already claimed" is lastDay == today only after the streak has started.
	local neverClaimed = s.lastDay < 0 and s.count <= 0
	if not neverClaimed and s.lastDay == today then
		return { ok = false, count = s.count, cycleDay = ((s.count - 1) % 7) + 1, week = math.ceil(s.count / 7), usedFreeMiss = false, softReset = false }
	end
	local usedFreeMiss, softReset = false, false
	local gap = today - s.lastDay
	if s.lastDay < 0 or s.count <= 0 then
		s.count = 1
	elseif gap == 1 then
		s.count += 1
	elseif gap == 2 and s.freeMissWeek ~= weekOf(today) then
		s.count += 1
		s.freeMissWeek = weekOf(today)
		usedFreeMiss = true
	elseif gap <= 0 then
		-- clock went backwards; treat as same streak, no reward abuse
		s.lastDay = today
		return { ok = false, count = s.count, cycleDay = ((s.count - 1) % 7) + 1, week = math.ceil(s.count / 7), usedFreeMiss = false, softReset = false }
	else
		-- soft reset to the start of the current week of the streak
		s.count = s.count - ((s.count - 1) % 7)
		softReset = true
	end
	s.lastDay = today
	s.best = math.max(s.best, s.count)
	return { ok = true, count = s.count, cycleDay = ((s.count - 1) % 7) + 1, week = math.ceil(s.count / 7), usedFreeMiss = usedFreeMiss, softReset = softReset }
end

-- Coins scale gently with how many weeks you've kept it going (caps at week 4).
function Streak.rewardScale(count: number): number
	local tier = math.clamp(math.ceil(math.max(1, count) / 7), 1, 4)
	return 1 + 0.5 * (tier - 1)
end

-- Matches GameService: streak scale is floored, then the rank multiplier is floored again.
function Streak.payout(base: number, count: number, rankMult: number): number
	local scaled = math.floor((base or 0) * Streak.rewardScale(count))
	return math.floor(scaled * rankMult)
end

return Streak
