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

local function finite(n: any): number?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

-- A non-finite or negative stamp is treated as ready (0). A stamp more than one
-- period ahead of `now` is pulled back so a bad clock can't lock the gift away.
-- `now` is the server's os.time(). The client never supplies it.
function FreeGift.normalize(state: any, now: number?): { nextAt: number }
	if type(state) ~= "table" then
		state = { nextAt = 0 }
	end
	local at = finite(state.nextAt)
	if not at or at < 0 then
		state.nextAt = 0
	else
		state.nextAt = at
	end
	local clock = finite(now)
	if clock and state.nextAt > clock + FreeGift.PERIOD then
		state.nextAt = clock + FreeGift.PERIOD
	end
	return state
end

function FreeGift.ready(nextAt: number, now: number): boolean
	local clock = finite(now)
	if not clock then
		return false
	end
	local at = finite(nextAt)
	local stamp = if at ~= nil and at >= 0 then at else 0
	return clock >= stamp
end

function FreeGift.remaining(nextAt: number, now: number): number
	return math.max(0, (nextAt or 0) - now)
end

-- Moves the timer forward. Returns false when it is not time yet.
function FreeGift.claim(state: State, now: number): boolean
	local clock = finite(now)
	if not clock or not FreeGift.ready(state.nextAt, clock) then
		return false
	end
	state.nextAt = clock + FreeGift.PERIOD
	return true
end

function FreeGift.payout(rankMult: number): number
	return math.max(1, math.floor(FreeGift.BASE * math.max(0, rankMult) + 0.5))
end

return FreeGift
