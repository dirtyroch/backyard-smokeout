--!strict
-- A small timed gift while you play. Separate from the daily login streak.
-- The base is tiny on purpose: it is a reason to check back, not a second economy.
local FreeGift = {}

FreeGift.PERIOD = 15 * 60
FreeGift.BASE = 35

export type State = { nextAt: number }

function FreeGift.new(): State
	return { nextAt = 0 }
end

function FreeGift.ready(nextAt: number, now: number): boolean
	return now >= (nextAt or 0)
end

function FreeGift.remaining(nextAt: number, now: number): number
	return math.max(0, (nextAt or 0) - now)
end

-- Moves the timer forward. Returns false when it is not time yet.
function FreeGift.claim(state: State, now: number): boolean
	if not FreeGift.ready(state.nextAt, now) then
		return false
	end
	state.nextAt = now + FreeGift.PERIOD
	return true
end

function FreeGift.payout(rankMult: number): number
	return math.max(1, math.floor(FreeGift.BASE * math.max(0, rankMult) + 0.5))
end

return FreeGift
