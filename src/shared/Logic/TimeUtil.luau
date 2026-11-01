--!strict
-- Pure time helpers (no Roblox APIs). `now` is unix seconds (os.time()).
local TimeUtil = {}

function TimeUtil.dayNumber(now: number, offsetHours: number): number
	return math.floor((now + offsetHours * 3600) / 86400)
end

-- 1 = Sunday ... 7 = Saturday. Day 0 (1970-01-01) was a Thursday.
function TimeUtil.weekday(now: number, offsetHours: number): number
	local day = TimeUtil.dayNumber(now, offsetHours)
	return ((day + 4) % 7) + 1
end

-- Monday-start week index for a day number.
function TimeUtil.weekOfDay(day: number): number
	return math.floor((day + 3) / 7)
end

function TimeUtil.weekNumber(now: number, offsetHours: number): number
	return TimeUtil.weekOfDay(TimeUtil.dayNumber(now, offsetHours))
end

-- Month 1..12 in the given offset (civil-from-days, Howard Hinnant's algorithm).
function TimeUtil.month(now: number, offsetHours: number): number
	local z = TimeUtil.dayNumber(now, offsetHours) + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local m = mp < 10 and mp + 3 or mp - 9
	return m
end

function TimeUtil.formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

return TimeUtil
