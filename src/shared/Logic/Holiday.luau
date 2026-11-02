--!strict
--[[
	Holiday.luau — pure date logic for date-gated events (no Roblox APIs, unit-tested in Lune).

	Days are "day numbers" (days since 1970-01-01 in the game's timezone), the same numbers
	TimeUtil.dayNumber returns. Weekdays use TimeUtil's convention: 1 = Sunday ... 7 = Saturday.

	  * daysFromCivil / civilFromDays: calendar date <-> day number (Howard Hinnant's algorithms)
	  * nthWeekday: e.g. the 4th Thursday of November
	  * thanksgiving: US Thanksgiving (4th Thursday of November) for a year
	  * turkeyWeek: is `day` inside the Turkey Day Smokeout window around Thanksgiving?
]]
local Holiday = {}

function Holiday.daysFromCivil(y: number, m: number, d: number): number
	if m <= 2 then
		y -= 1
	end
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = m > 2 and m - 3 or m + 9
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end

function Holiday.civilFromDays(day: number): (number, number, number)
	local z = day + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local d = doy - math.floor((153 * mp + 2) / 5) + 1
	local m = mp < 10 and mp + 3 or mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

-- 1 = Sunday ... 7 = Saturday (day 0, 1970-01-01, was a Thursday).
function Holiday.weekdayOf(day: number): number
	return ((day + 4) % 7) + 1
end

-- Day number of the `n`th `weekday` (1 = Sunday ... 7 = Saturday) of a month.
function Holiday.nthWeekday(year: number, month: number, weekday: number, n: number): number
	local first = Holiday.daysFromCivil(year, month, 1)
	local offset = (weekday - Holiday.weekdayOf(first)) % 7
	return first + offset + (n - 1) * 7
end

function Holiday.thanksgiving(year: number): number
	return Holiday.nthWeekday(year, 11, 5, 4)
end

export type Week = { active: boolean, isDay: boolean, day: number, startDay: number, endDay: number }

-- The Turkey Day Smokeout runs from `before` days before Thanksgiving through `after` days after.
function Holiday.turkeyWeek(day: number, before: number, after: number): Week
	local year = Holiday.civilFromDays(day)
	local t = Holiday.thanksgiving(year)
	local startDay, endDay = t - before, t + after
	return { active = day >= startDay and day <= endDay, isDay = day == t, day = t, startDay = startDay, endDay = endDay }
end

-- Seasonal cuts cook only in their season, except the event's own cut stays open for the whole
-- event window (so Thanksgiving weeks that run into December still have turkey legs).
function Holiday.meatInSeason(meat: any, seasonId: string, eventActive: boolean, eventMeatId: string): boolean
	if not meat.season or meat.season == seasonId then
		return true
	end
	return eventActive and meat.id == eventMeatId
end

-- Which cooler plate to share at the potluck: the plainest one of `meatId` (lowest rarity index,
-- earliest on ties), so nobody hands over a rare cut by accident. nil if there isn't one.
function Holiday.pickPlate(cooler: { any }, meatId: string, rarityIndex: (string) -> number): number?
	local bestI, bestR = nil, math.huge
	for i, plate in ipairs(cooler) do
		if plate.m == meatId then
			local ri = rarityIndex(plate.r)
			if ri < bestR then
				bestI, bestR = i, ri
			end
		end
	end
	return bestI
end

-- "Nov 23" style label for a day number.
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function Holiday.label(day: number): string
	local _, m, d = Holiday.civilFromDays(day)
	return MONTHS[m] .. " " .. d
end

return Holiday
