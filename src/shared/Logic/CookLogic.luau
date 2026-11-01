--!strict
--[[
	CookLogic — real-time cook timers with offline progress.
	A cook stores how many "cook-seconds" of progress it has and when it was last advanced.
	Advancing is piecewise: boosted time (until boostUntil) runs at baseRate * boostMult,
	the rest at baseRate. Because boosts are stored as an absolute expiry time, this works
	identically for online ticks and for a single big jump when a player returns after hours.
]]
local CookLogic = {}

export type Cook = {
	meat: string,
	rarity: string,
	progress: number,
	duration: number,
	last: number,
	startedAt: number,
	rateMult: number, -- from sauces applied at start (1 = none)
	peeks: number,
	revealed: boolean,
	doneAt: number?,
	flip: string?, -- nil | "perfect" | "good" | "miss"
	burnt: boolean?,
}

function CookLogic.new(meat: string, rarity: string, duration: number, now: number, rateMult: number?): Cook
	return {
		meat = meat,
		rarity = rarity,
		progress = 0,
		duration = math.max(1, duration),
		last = now,
		startedAt = now,
		rateMult = rateMult or 1,
		peeks = 0,
		revealed = false,
		doneAt = nil,
		flip = nil,
		burnt = nil,
	}
end

-- Effective rate (cook-seconds per real second) without boosts.
function CookLogic.rate(cook: Cook, pitSpeed: number): number
	return pitSpeed * (cook.rateMult or 1)
end

function CookLogic.advance(cook: Cook, now: number, rate: number, boostMult: number, boostUntil: number): Cook
	if now <= cook.last then
		return cook
	end
	local t0 = cook.last
	local boosted = 0
	if boostUntil > t0 and boostMult > 1 then
		boosted = math.min(now, boostUntil) - t0
	end
	local normal = (now - t0) - boosted
	local before = cook.progress
	cook.progress = math.min(cook.duration, cook.progress + boosted * rate * boostMult + normal * rate)
	cook.last = now
	if cook.progress >= cook.duration and before < cook.duration and cook.doneAt == nil then
		-- Find the exact real time it finished (for burn timers), walking the two segments.
		local need = cook.duration - before
		local boostedGain = boosted * rate * boostMult
		local finishAt
		if need <= boostedGain and boosted > 0 then
			finishAt = t0 + need / (rate * boostMult)
		else
			finishAt = t0 + boosted + (need - boostedGain) / rate
		end
		cook.doneAt = finishAt
	end
	return cook
end

function CookLogic.isDone(cook: Cook): boolean
	return cook.progress >= cook.duration - 1e-6
end

function CookLogic.fraction(cook: Cook): number
	return math.clamp(cook.progress / cook.duration, 0, 1)
end

-- Wall-clock seconds until done from `now` (assumes cook already advanced to now).
function CookLogic.remaining(cook: Cook, now: number, rate: number, boostMult: number, boostUntil: number): number
	local left = cook.duration - cook.progress
	if left <= 0 then
		return 0
	end
	if boostUntil > now and boostMult > 1 then
		local boostWindow = boostUntil - now
		local boostedCapacity = boostWindow * rate * boostMult
		if left <= boostedCapacity then
			return left / (rate * boostMult)
		end
		return boostWindow + (left - boostedCapacity) / rate
	end
	return left / rate
end

-- "If you're lookin', you ain't cookin'": peeking reveals the rarity but costs progress.
function CookLogic.peek(cook: Cook, penaltyFraction: number, minPenalty: number): number
	local penalty = math.max(minPenalty, cook.duration * penaltyFraction)
	penalty = math.min(penalty, cook.progress) -- never below zero
	cook.progress -= penalty
	cook.peeks += 1
	cook.revealed = true
	return penalty
end

function CookLogic.finishNow(cook: Cook, now: number)
	if cook.progress < cook.duration then
		cook.progress = cook.duration
		cook.doneAt = now
	end
	cook.last = now
end

-- Burgers burn if left too long after finishing. Only call while the owner is ONLINE,
-- so nobody ever loses food while away.
function CookLogic.shouldBurn(cook: Cook, now: number, grace: number): boolean
	return cook.doneAt ~= nil and not cook.burnt and (now - (cook.doneAt :: number)) > grace
end

-- Spatula flip judged on the server's clock against the cook fraction.
function CookLogic.judgeFlip(fraction: number, target: number, perfectWindow: number, goodWindow: number): string
	local d = math.abs(fraction - target)
	if d <= perfectWindow then
		return "perfect"
	elseif d <= goodWindow then
		return "good"
	end
	return "miss"
end

return CookLogic
