--!strict
--[[
	Forgiving daily streak.
	  * Claim once per (Texas) day.
	  * Miss exactly one day? Your one free miss for the week covers it automatically.
	  * Miss more? You drop back to the first day of your current 7-day week, never to zero.
]]
local Streak = {}

export type State = { lastDay: number, count: number, best: number, freeMissWeek: number }

local function weekOf(day: number): number
	return math.floor((day + 3) / 7)
end

function Streak.new(): State
	return { lastDay = -1, count = 0, best = 0, freeMissWeek = -1 }
end

function Streak.canClaim(s: State, today: number): boolean
	return s.lastDay ~= today
end

export type Result = { ok: boolean, count: number, cycleDay: number, week: number, usedFreeMiss: boolean, softReset: boolean }

function Streak.claim(s: State, today: number): Result
	if s.lastDay == today then
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

return Streak
