--!strict
-- Cook-Off judging. Score 0..100 from rarity, cut value and a perfect flip. Paid perks don't count:
-- premium cuts are judged as if they were a regular brisket.
local CookOff = {}

function CookOff.score(rarityIndex: number, price: number, perfectFlip: boolean): number
	local valuePart = math.min(20, math.max(0, (math.log(math.max(price, 1)) / math.log(2)) * 2))
	local s = rarityIndex * 16 + valuePart + (perfectFlip and 5 or 0)
	return math.clamp(math.floor(s + 0.5), 0, 100)
end

function CookOff.rating(ratings: { any }, score: number): any
	local best = ratings[1]
	for _, r in ipairs(ratings) do
		if score >= r.min then
			best = r
		end
	end
	return best
end

function CookOff.isSaturday(weekday: number): boolean
	return weekday == 7
end

function CookOff.isSudsWeekend(weekday: number): boolean
	return weekday == 7 or weekday == 1
end

function CookOff.seasonFor(seasons: { any }, month: number): any
	for _, s in ipairs(seasons) do
		for _, m in ipairs(s.months) do
			if m == month then
				return s
			end
		end
	end
	return seasons[1]
end

-- Weekly limited-time rotation: which product keys are featured this week.
function CookOff.rotation(pool: { string }, featured: number, week: number): { string }
	local out = {}
	local n = #pool
	if n == 0 then
		return out
	end
	for i = 0, math.min(featured, n) - 1 do
		table.insert(out, pool[((week * featured + i) % n) + 1])
	end
	return out
end

-- ===== The weekly board (pure, so the hub leaderboard text is unit-tested) =====
-- Entries come only on Saturdays (Texas time) and weeks start on Monday, so a week's board is
-- final from Sunday on. What the hub board shows: Saturday = today's live standings, Sunday =
-- yesterday's results, Monday-Friday = last Saturday's champs (the previous week's store) plus the
-- next Cook-Off date. It used to say "Opens Saturday" five days out of seven.
function CookOff.boardMode(weekday: number): string
	if weekday == 7 then
		return "live"
	elseif weekday == 1 then
		return "results"
	end
	return "last"
end

-- Week offset of the final (finished) results for `weekday`: 0 = this week (Sunday), -1 = last
-- week (Monday-Friday), nil on Saturday while the Cook-Off is still running.
function CookOff.finalWeekOffset(weekday: number): number?
	local mode = CookOff.boardMode(weekday)
	if mode == "live" then
		return nil
	end
	return mode == "results" and 0 or -1
end

-- Day number of the next Cook-Off Saturday (today if it's Saturday). Day 0 was a Thursday.
function CookOff.nextSaturday(day: number): number
	local wd = ((day + 4) % 7) + 1 -- 1 = Sunday ... 7 = Saturday
	return day + ((7 - wd) % 7)
end

export type Placing = { userId: number, score: number, place: number }

-- Places from sorted board entries ({ key = "userId", value = score }, highest first). Ties share
-- a place (100, 100, 97 -> 1st, 1st, 3rd), so nobody loses a medal to a coin-flip sort order.
function CookOff.placings(entries: { any }): { Placing }
	local out: { Placing } = {}
	local lastScore, lastPlace = nil, 0
	for i, e in ipairs(entries) do
		local uid = tonumber(e.key)
		local score = tonumber(e.value)
		if uid and score then
			local place = (score == lastScore) and lastPlace or i
			table.insert(out, { userId = uid, score = score, place = place })
			lastScore, lastPlace = score, place
		end
	end
	return out
end

-- The place `userId` earned if it's a podium finish (1-3, ties included), else nil.
function CookOff.podiumPlace(placings: { Placing }, userId: number): number?
	for _, p in ipairs(placings) do
		if p.userId == userId and p.place <= 3 then
			return p.place
		end
	end
	return nil
end

local MEDALS = { "🥇", "🥈", "🥉" }
function CookOff.medal(place: number): string
	return MEDALS[place] or (tostring(place) .. ".")
end

-- Board names stay short enough to read from the spawn point.
function CookOff.shortName(name: string, max: number): string
	if utf8.len(name) and (utf8.len(name) :: number) > max then
		local cut = utf8.offset(name, max) :: number
		return string.sub(name, 1, cut - 1) .. "…"
	end
	return name
end

-- The hub board's text. `L` holds the copy (Content.CookOffBoard), `nameOf(userId)` a name and
-- `nextLabel` the next Saturday ("Sat, Nov 21"); dates only, never a countdown.
function CookOff.boardText(mode: string, season: string, placings: { Placing }, nameOf: (number) -> string, nextLabel: string, L: { [string]: any }): string
	local limit = mode == "live" and L.liveRows or L.finalRows
	local lines = { season, mode == "live" and L.liveHead or (mode == "results" and L.resultsHead or L.lastHead), "" }
	for i, p in ipairs(placings) do
		if i > limit then
			break
		end
		table.insert(lines, string.format("%s %s  %d", CookOff.medal(p.place), CookOff.shortName(nameOf(p.userId), L.nameMax), p.score))
	end
	if #placings == 0 then
		table.insert(lines, mode == "live" and L.liveEmpty or L.finalEmpty)
	end
	if mode ~= "live" then
		table.insert(lines, "")
		table.insert(lines, string.format(L.next, nextLabel))
		table.insert(lines, L.practice)
	end
	return table.concat(lines, "\n")
end

return CookOff
