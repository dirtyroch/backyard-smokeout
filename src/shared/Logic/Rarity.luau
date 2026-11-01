--!strict
-- Weighted rarity rolls. `luck` scales every non-common weight. `u` is a uniform [0,1) number
-- supplied by the caller (server uses Random.new(); tests pass fixed values).
local Rarity = {}

export type RarityDef = { id: string, name: string, weight: number, mult: number, color: string, flex: boolean }

function Rarity.weights(rarities: { RarityDef }, luck: number, maxIndex: number?): { number }
	local out = {}
	local cap = maxIndex or #rarities
	for i, r in ipairs(rarities) do
		if i > cap then
			out[i] = 0
		elseif i == 1 then
			out[i] = r.weight
		else
			out[i] = r.weight * math.max(0, luck)
		end
	end
	return out
end

function Rarity.odds(rarities: { RarityDef }, luck: number, maxIndex: number?): { { id: string, name: string, pct: number } }
	local w = Rarity.weights(rarities, luck, maxIndex)
	local total = 0
	for _, x in ipairs(w) do
		total += x
	end
	local out = {}
	for i, r in ipairs(rarities) do
		table.insert(out, { id = r.id, name = r.name, pct = total > 0 and (w[i] / total * 100) or 0 })
	end
	return out
end

function Rarity.roll(rarities: { RarityDef }, luck: number, maxIndex: number?, u: number): string
	local w = Rarity.weights(rarities, luck, maxIndex)
	local total = 0
	for _, x in ipairs(w) do
		total += x
	end
	local pick = math.clamp(u, 0, 0.999999999) * total
	local acc = 0
	for i, r in ipairs(rarities) do
		acc += w[i]
		if pick < acc then
			return r.id
		end
	end
	return rarities[1].id
end

function Rarity.indexOf(rarities: { RarityDef }, id: string): number
	for i, r in ipairs(rarities) do
		if r.id == id then
			return i
		end
	end
	return 1
end

function Rarity.get(rarities: { RarityDef }, id: string): RarityDef
	return rarities[Rarity.indexOf(rarities, id)]
end

-- Generic weighted pick over { {id, weight} } lists (critters, bandanas).
function Rarity.pickWeighted(list: { any }, u: number): any
	local total = 0
	for _, e in ipairs(list) do
		total += e.weight
	end
	local pick = math.clamp(u, 0, 0.999999999) * total
	local acc = 0
	for _, e in ipairs(list) do
		acc += e.weight
		if pick < acc then
			return e
		end
	end
	return list[#list]
end

function Rarity.weightedOdds(list: { any }): { [string]: number }
	local total = 0
	for _, e in ipairs(list) do
		total += e.weight
	end
	local out = {}
	for _, e in ipairs(list) do
		out[e.id] = total > 0 and e.weight / total * 100 or 0
	end
	return out
end

return Rarity
