--!strict
-- The Hiring Line. One seeded lineup per 5-minute window, shared by the server.
-- You buy the critter you can see. The price is coins, and the same seed always restocks the same six.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local TimeUtil = if script ~= nil and script.Parent ~= nil then require(script.Parent.TimeUtil) else require("./TimeUtil")

local HiringLine = {}

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic" }
-- Higher ranch tiers add weight to rarer applicants. Commons stay put, so a new ranch still sees them.
local RARITY_WEIGHT = {
	common = 62,
	uncommon = 24,
	rare = 9,
	epic = 3.5,
	legendary = 1.2,
	mythic = 0.3,
}
local RARITY_BONUS = {
	common = 0,
	uncommon = 1.5,
	rare = 2.2,
	epic = 1.4,
	legendary = 0.7,
	mythic = 0.35,
}

export type Applicant = {
	index: number,
	species: string,
	name: string,
	rarity: string,
	rarityName: string,
	color: string,
	role: string,
	roleName: string,
	trait: string,
	traitName: string,
	baseRate: number,
	rate: number,
	price: number,
	model: string,
	style: string?,
	body: string,
	head: string,
	scale: number?,
	line: string,
	secret: boolean?,
}

function HiringLine.window(now: number, period: number): number
	if period <= 0 then
		return 0
	end
	return math.floor(now / period)
end

function HiringLine.nextAt(now: number, period: number): number
	return (HiringLine.window(now, period) + 1) * period
end

-- "3:45 PM CT". The board shows when the next lineup walks in, not how many seconds are left.
function HiringLine.clockLabel(now: number, period: number, offsetHours: number): string
	local at = HiringLine.nextAt(now, period)
	return "Next lineup: " .. TimeUtil.clock(at, offsetHours) .. " CT"
end

local function mix(seed: number, window: number): number
	local x = (math.floor(seed) * 1000003 + math.floor(window) * 9176 + 17) % 2147483647
	if x <= 0 then
		x += 2147483646
	end
	return x
end

local function lcg(state: number): () -> number
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function weightOf(rarity: string, tier: number): number
	local base = RARITY_WEIGHT[rarity] or 0
	local bonus = RARITY_BONUS[rarity] or 0
	return base + math.max(0, tier - 1) * bonus
end

local function pickKey(rnd: () -> number, keys: { string }, weightFor: (string) -> number): string
	local total = 0
	for _, key in ipairs(keys) do
		total += weightFor(key)
	end
	if total <= 0 then
		return keys[1]
	end
	local x = rnd() * total
	local acc = 0
	for _, key in ipairs(keys) do
		acc += weightFor(key)
		if x < acc then
			return key
		end
	end
	return keys[#keys]
end

local function groups(list: { any }): { [string]: { any } }
	local out: { [string]: { any } } = {}
	for _, row in ipairs(list) do
		if row.secret ~= true then
			local bucket = out[row.rarity]
			if not bucket then
				bucket = {}
				out[row.rarity] = bucket
			end
			table.insert(bucket, row)
		end
	end
	return out
end

local function rarityName(id: string): (string, string)
	for _, row in ipairs(Config.CrewRarities) do
		if row.id == id then
			return row.name, row.color
		end
	end
	return id, "#E7E2DA"
end

local function traitOf(id: string): any
	for _, row in ipairs(Config.CrewTraits) do
		if row.id == id then
			return row
		end
	end
	return Config.CrewTraits[1]
end

local function roleName(id: string): string
	local row = Config.CrewRoles[id]
	return if row then row.name else id
end

local function toApplicant(index: number, species: any, traitId: string): Applicant
	local trait = traitOf(traitId)
	local name, color = rarityName(species.rarity)
	local rate = species.baseRate * trait.mult
	local price = math.max(1, math.floor(species.price * trait.mult + 0.5))
	return {
		index = index,
		species = species.id,
		name = species.name,
		rarity = species.rarity,
		rarityName = name,
		color = color,
		role = species.role,
		roleName = roleName(species.role),
		trait = trait.id,
		traitName = trait.name,
		baseRate = species.baseRate,
		rate = rate,
		price = price,
		model = species.model,
		style = species.style,
		body = species.body,
		head = species.head,
		scale = species.scale,
		line = species.line,
		secret = species.secret == true,
	}
end

-- `tier` is the ranch tier the lineup was weighted for. The same seed, window and tier
-- always return the same six applicants, in the same order, with the same prices.
function HiringLine.stock(seed: number, window: number, tier: number, list: { any }?): { Applicant }
	local species = list or Config.CrewSpecies
	local byRarity = groups(species)
	local rex = nil
	for _, row in ipairs(species) do
		if row.secret == true then
			rex = row
			break
		end
	end
	local rnd = lcg(mix(seed, window))
	local showRex = rex ~= nil and rnd() < Config.Hiring.rexChance
	local tierN = math.clamp(math.floor(tier), 1, #Config.RanchTiers)
	local traitKeys = {}
	for _, row in ipairs(Config.CrewTraits) do
		table.insert(traitKeys, row.id)
	end
	local function traitWeight(id: string): number
		return traitOf(id).weight or 0
	end
	local out: { Applicant } = {}
	for i = 1, Config.Hiring.count do
		local rarity = pickKey(rnd, RARITY_ORDER, function(id: string): number
			return weightOf(id, tierN)
		end)
		local bucket = byRarity[rarity]
		local picked = species[1]
		if bucket and #bucket > 0 then
			local at = math.floor(rnd() * #bucket) + 1
			if at > #bucket then
				at = #bucket
			end
			picked = bucket[at]
		end
		local traitId = pickKey(rnd, traitKeys, traitWeight)
		table.insert(out, toApplicant(i, picked, traitId))
	end
	if showRex and rex then
		local traitId = pickKey(rnd, traitKeys, traitWeight)
		out[Config.Hiring.count] = toApplicant(Config.Hiring.count, rex, traitId)
	end
	-- A brand-new purse is 50 coins. At least two applicants stay at or under that,
	-- so a lineup is never only critters the new player cannot buy.
	local cheap = {}
	for _, row in ipairs(species) do
		if row.secret ~= true and row.price <= Config.Hiring.cheapPrice then
			table.insert(cheap, row)
		end
	end
	table.sort(cheap, function(p, q)
		if p.price ~= q.price then
			return p.price < q.price
		end
		return p.id < q.id
	end)
	local function affordable(): number
		local n = 0
		for _, applicant in ipairs(out) do
			if applicant.secret ~= true and applicant.price <= Config.Hiring.cheapPrice then
				n += 1
			end
		end
		return n
	end
	local pick = 1
	local guard = 0
	while affordable() < Config.Hiring.cheapCount and #cheap > 0 and guard < 8 do
		guard += 1
		local worst = 1
		local worstPrice = -1
		for i, applicant in ipairs(out) do
			if applicant.secret ~= true and applicant.price > Config.Hiring.cheapPrice and applicant.price > worstPrice then
				worst = i
				worstPrice = applicant.price
			end
		end
		if worstPrice < 0 then
			break
		end
		local speciesPick = cheap[((pick - 1) % #cheap) + 1]
		pick += 1
		out[worst] = toApplicant(worst, speciesPick, "none")
	end
	return out
end

-- First valid claim wins. A failed claim (not enough coins, no slot) must not call this.
function HiringLine.tryTake(taken: { [number]: number }, index: any, userId: number): boolean
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > Config.Hiring.count then
		return false
	end
	if type(userId) ~= "number" then
		return false
	end
	if taken[index] ~= nil then
		return false
	end
	taken[index] = userId
	return true
end

return HiringLine
