--!strict
-- Economy math: plate values, upgrade costs, rebirth (Unc Status) rules. Pure functions.
local Economy = {}

function Economy.rankMult(rank: number, step: number): number
	return 1 + step * (math.max(1, rank) - 1)
end

function Economy.crewMult(friends: number, perFriend: number, maxFriends: number): number
	return 1 + perFriend * math.clamp(friends, 0, maxFriends)
end

export type ValueOpts = {
	rarityMult: number,
	rankMult: number?,
	crewMult: number?,
	tipMult: number?, -- critter tip
	sauceTip: number?, -- e.g. 0.25 for +25%
	flipMult: number?,
	comboMult: number?,
	doubleTips: boolean?,
	passTipMult: number?, -- Fair Play: the tip pass multiplier (default 1.5)
	orderBonus: number?,
}

function Economy.plateValue(price: number, o: ValueOpts): number
	local v = price
		* o.rarityMult
		* (o.rankMult or 1)
		* (o.crewMult or 1)
		* (o.tipMult or 1)
		* (1 + (o.sauceTip or 0))
		* (o.flipMult or 1)
		* (o.comboMult or 1)
		* (o.orderBonus or 1)
		* (o.doubleTips and (o.passTipMult or 1.5) or 1)
	return math.max(1, math.floor(v + 0.5))
end

-- Cost to reach pit level `level + 1`, or nil if maxed.
function Economy.nextPitCost(pitLevels: { any }, level: number): number?
	local nextDef = pitLevels[level + 1]
	return nextDef and nextDef.cost or nil
end

-- Slot purchases: `owned` = slots bought with coins so far (not counting base/pass).
function Economy.nextSlotCost(costs: { number }, owned: number): number?
	return costs[owned + 1]
end

function Economy.totalSlots(base: number, bought: number, passBonus: number, hasPass: boolean, cap: number): number
	return math.min(cap, base + bought + (hasPass and passBonus or 0))
end

function Economy.canRebirth(ranks: { any }, rank: number, runCoins: number): (boolean, number?)
	local nextRank = ranks[rank + 1]
	if not nextRank then
		return false, nil
	end
	return runCoins >= nextRank.need, nextRank.need
end

function Economy.rawCost(meat: any, rankMult: number): number
	-- Raw meat gets a bit pricier as you rank up so rebirths stay meaningful but not grindy.
	return math.floor(meat.cost * (1 + (rankMult - 1) * 0.5) + 0.5)
end

-- Rough coins-per-minute for a steady loop (used by balance tests and the README table).
function Economy.coinsPerMinute(meat: any, slots: number, speed: number, avgRarityMult: number, rankMult: number): number
	local cycleMinutes = (meat.cookTime / speed) / 60
	local profit = meat.price * avgRarityMult * rankMult - Economy.rawCost(meat, rankMult)
	return profit * slots / cycleMinutes
end

function Economy.averageRarityMult(rarities: { any }, luck: number, maxIndex: number?): number
	local total, acc = 0, 0
	for i, r in ipairs(rarities) do
		if maxIndex == nil or i <= maxIndex then
			local w = i == 1 and r.weight or r.weight * luck
			total += w
			acc += w * r.mult
		end
	end
	return acc / total
end

return Economy
