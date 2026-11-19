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

-- Clock time in the offset zone, e.g. "3:45 PM". A time of day, not a countdown.
function TimeUtil.clock(now: number, offsetHours: number): string
	local localSec = now + offsetHours * 3600
	local sod = localSec % 86400
	if sod < 0 then
		sod += 86400
	end
	local hour = math.floor(sod / 3600)
	local minute = math.floor((sod % 3600) / 60)
	local am = hour < 12
	local h12 = hour % 12
	if h12 == 0 then
		h12 = 12
	end
	return string.format("%d:%02d %s", h12, minute, if am then "AM" else "PM")
end

-- Year, month, day in a fixed offset. Month is 1..12.
function TimeUtil.civil(now: number, offsetHours: number): (number, number, number)
	local z = TimeUtil.dayNumber(now, offsetHours) + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

-- Unix time for a UTC civil date. Hour is 0..23.
function TimeUtil.unix(year: number, month: number, day: number, hour: number, minute: number): number
	local y = year
	local m = month
	if m <= 2 then
		y -= 1
		m += 9
	else
		m -= 3
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * m + 2) / 5) + day - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + hour * 3600 + minute * 60
end

-- US Central. UTC-6 in winter, UTC-5 from the second Sunday in March 2:00 AM
-- through the first Sunday in November 2:00 AM. The clock change is the real one.
function TimeUtil.centralOffset(now: number): number
	local year = TimeUtil.civil(now, -6)
	local function nthSunday(month: number, n: number): number
		local w = TimeUtil.weekday(TimeUtil.unix(year, month, 1, 0, 0), 0)
		local first = 1 + ((1 - w) % 7)
		return first + (n - 1) * 7
	end
	-- 2:00 AM standard time is 08:00 UTC. 2:00 AM daylight time is 07:00 UTC.
	local startUtc = TimeUtil.unix(year, 3, nthSunday(3, 2), 8, 0)
	local endUtc = TimeUtil.unix(year, 11, nthSunday(11, 1), 7, 0)
	if now >= startUtc and now < endUtc then
		return -5
	end
	return -6
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
