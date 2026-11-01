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

return CookOff
