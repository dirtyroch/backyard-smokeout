--!strict
-- Crew keep earning while you're away, up to a cap. The cap is a length of time, not a sale.
local Offline = {}

Offline.CAP = 4 * 3600
Offline.BUNKHOUSE_CAP = 8 * 3600

function Offline.cap(bunkhouse: boolean?): number
	if bunkhouse then
		return Offline.BUNKHOUSE_CAP
	end
	return Offline.CAP
end

-- Seconds of pay owed. lastTick of 0 (or a clock that went backwards) pays nothing.
function Offline.awaySeconds(lastTick: any, now: number, capSeconds: number): number
	if type(lastTick) ~= "number" or type(now) ~= "number" or type(capSeconds) ~= "number" then
		return 0
	end
	if lastTick <= 0 or capSeconds <= 0 or now ~= now or lastTick ~= lastTick then
		return 0
	end
	local dt = now - lastTick
	if dt ~= dt or dt <= 0 or dt == math.huge then
		return 0
	end
	return math.min(dt, capSeconds)
end

-- Whole coins for a stretch at a steady coins/s. The fraction stays in the stretch, not dropped per second.
function Offline.coins(ratePerSecond: number, seconds: number): number
	if type(ratePerSecond) ~= "number" or type(seconds) ~= "number" then
		return 0
	end
	if ratePerSecond <= 0 or seconds <= 0 or ratePerSecond ~= ratePerSecond or seconds ~= seconds then
		return 0
	end
	local total = ratePerSecond * seconds
	if total ~= total or total == math.huge then
		return 0
	end
	return math.floor(total + 1e-9)
end

export type Settle = { seconds: number, coins: number, lastTick: number }

function Offline.settle(lastTick: any, now: number, capSeconds: number, ratePerSecond: number): Settle
	local seconds = Offline.awaySeconds(lastTick, now, capSeconds)
	return {
		seconds = seconds,
		coins = Offline.coins(ratePerSecond, seconds),
		lastTick = if type(now) == "number" then now else 0,
	}
end

return Offline
