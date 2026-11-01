--!strict
-- Sauce shop restocks every RESTOCK_SECONDS. Stock is a deterministic function of the window,
-- so every server shows the same shelf and it survives server restarts.
local Restock = {}

local M = 2147483647

local function prng(seed: number)
	local x = (seed % (M - 1)) + 1
	return function(): number
		x = (x * 48271) % M
		return x / M
	end
end

function Restock.window(now: number, period: number): number
	return math.floor(now / period)
end

function Restock.nextIn(now: number, period: number): number
	return period - (now % period)
end

export type Shelf = { { id: string, qty: number } }

function Restock.shelf(window: number, sauces: { [string]: any }, order: { string }, slots: number): Shelf
	local rnd = prng(window * 7919 + 17)
	local pool = {}
	for _, id in ipairs(order) do
		local s = sauces[id]
		if s and s.weight > 0 then
			table.insert(pool, { id = id, weight = s.weight, maxStock = s.maxStock })
		end
	end
	local shelf = {}
	for _ = 1, math.min(slots, #pool) do
		local total = 0
		for _, e in ipairs(pool) do
			total += e.weight
		end
		local pick = rnd() * total
		local acc = 0
		for i, e in ipairs(pool) do
			acc += e.weight
			if pick < acc or i == #pool then
				table.insert(shelf, { id = e.id, qty = 1 + math.floor(rnd() * e.maxStock) % e.maxStock })
				table.remove(pool, i)
				break
			end
		end
	end
	return shelf
end

-- Chance a sauce shows up in a given restock (for the "restock odds" panel), measured over
-- `samples` real restock windows (the exact same function the shop uses).
function Restock.appearOdds(sauces: { [string]: any }, order: { string }, slots: number, samples: number?): { [string]: number }
	local n = samples or 2000
	local counts: { [string]: number } = {}
	for w = 1, n do
		for _, e in ipairs(Restock.shelf(w, sauces, order, slots)) do
			counts[e.id] = (counts[e.id] or 0) + 1
		end
	end
	local out = {}
	for _, id in ipairs(order) do
		out[id] = (counts[id] or 0) / n * 100
	end
	return out
end

return Restock
