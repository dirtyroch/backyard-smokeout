--!strict
-- Hired critters: slots, levels, merges, and coins per second.
-- Prices and rates come from Config. A trait multiplies both, and you see it before you pay.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local Economy = if script ~= nil and script.Parent ~= nil then require(script.Parent.Economy) else require("./Economy")

local Crew = {}

export type Member = {
	uid: number,
	species: string,
	name: string,
	level: number,
	trait: string,
	badge: string?,
	role: string,
}

export type Mults = {
	rank: number?,
	friends: number?,
	tipPass: boolean?,
}

local function finite(n: any): number?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

local function rules(): any
	return Config.Hiring
end

function Crew.byId(speciesId: string, list: { any }?): any?
	local rows = list or Config.CrewSpecies
	for _, row in ipairs(rows) do
		if row.id == speciesId then
			return row
		end
	end
	return nil
end

function Crew.traitDef(traitId: string?): any
	local id = if type(traitId) == "string" and traitId ~= "" then traitId else "none"
	for _, row in ipairs(Config.CrewTraits) do
		if row.id == id then
			return row
		end
	end
	return Config.CrewTraits[1]
end

function Crew.rarityDef(rarityId: string): any?
	for _, row in ipairs(Config.CrewRarities) do
		if row.id == rarityId then
			return row
		end
	end
	return nil
end

-- Tier 1 starts at 3. Each tier adds 2. Old smoker and grill purchases add at most one slot each.
-- The cap is 19, which is tier 8 plus those two extras.
function Crew.slotCount(tier: any, extra: any): number
	local hiring = rules()
	local t = math.clamp(math.floor(finite(tier) or 1), 1, #Config.RanchTiers)
	local e = math.clamp(math.floor(finite(extra) or 0), 0, 2)
	local n = hiring.startSlots + (t - 1) * hiring.slotsPerTier + e
	return math.min(hiring.maxSlots, n)
end

function Crew.levelMult(level: any): number
	local hiring = rules()
	local lv = math.clamp(math.floor(finite(level) or 1), 1, hiring.maxLevel)
	return 1 + hiring.levelBonus * (lv - 1)
end

-- Rounded average of the old speed / carry / quality levels, capped at 10.
function Crew.founderLevel(speed: any, carry: any, quality: any): number
	local a = finite(speed) or 1
	local b = finite(carry) or 1
	local c = finite(quality) or 1
	local avg = (a + b + c) / 3
	return math.clamp(math.floor(avg + 0.5), 1, rules().maxLevel)
end

function Crew.tipMult(tipPass: boolean?): number
	if not tipPass then
		return 1
	end
	local asked = Config.FairPlay.passTipMult
	local cap = Config.FairPlay.passTipCap
	return math.min(asked, cap)
end

function Crew.friendMult(friends: any): number
	local n = finite(friends) or 0
	return Economy.crewMult(n, Config.Crew.perFriend, Config.Crew.maxFriends)
end

function Crew.rankMult(rank: any): number
	return Economy.rankMult(finite(rank) or 1, Config.RANK_STEP)
end

-- Coins per second for one critter. `board` skips rank, friends and the tip pass so the
-- Hiring Line shows the same number to everybody.
function Crew.rate(baseRate: number, level: any, traitId: string?, mults: Mults?, board: boolean?): number
	local trait = Crew.traitDef(traitId)
	local per = baseRate * Crew.levelMult(level) * trait.mult
	if board then
		return per
	end
	local m = mults or {}
	per *= Crew.rankMult(m.rank)
	per *= Crew.friendMult(m.friends)
	per *= Crew.tipMult(m.tipPass)
	return per
end

function Crew.memberRate(member: any, mults: Mults?): number
	local species = Crew.byId(member.species)
	if not species then
		return 0
	end
	return Crew.rate(species.baseRate, member.level, member.trait, mults, false)
end

-- The first `slots` owned critters are the ones on station. The rest wait for a ranch tier.
function Crew.working(owned: { any }, slots: number): { any }
	local out = {}
	local n = math.max(0, math.floor(slots))
	for i, member in ipairs(owned) do
		if i > n then
			break
		end
		table.insert(out, member)
	end
	return out
end

function Crew.totalRate(owned: { any }, slots: number, mults: Mults?): number
	local sum = 0
	for _, member in ipairs(Crew.working(owned, slots)) do
		sum += Crew.memberRate(member, mults)
	end
	return sum
end

-- One second of pay. The leftover fraction carries so 1.5/s pays 1, then 2, then 1.
function Crew.tickPay(rate: number, bank: number): (number, number)
	if type(rate) ~= "number" or rate ~= rate or rate <= 0 or rate == math.huge then
		return 0, if type(bank) == "number" and bank == bank then bank else 0
	end
	local held = if type(bank) == "number" and bank == bank and bank > 0 and bank < 1 then bank else 0
	local sum = held + rate
	local coins = math.floor(sum + 1e-9)
	local left = sum - coins
	if left < 1e-9 or left ~= left then
		left = 0
	end
	return coins, left
end

function Crew.levelCost(price: number, level: any): number?
	local hiring = rules()
	local lv = math.floor(finite(level) or 1)
	if lv < 1 or lv >= hiring.maxLevel or price <= 0 then
		return nil
	end
	return math.max(1, math.floor(price * 0.35 * lv))
end

function Crew.greeterCount(owned: { any }, slots: number): number
	local n = 0
	for _, member in ipairs(Crew.working(owned, slots)) do
		if member.role == "greeter" then
			n += 1
		end
	end
	return n
end

-- Each working greeter shortens the wait for the next guest a little. It never goes under 60%.
function Crew.greeterDelay(greeters: number): number
	local n = math.max(0, math.floor(finite(greeters) or 0))
	return math.max(0.6, 1 - 0.08 * n)
end

local function takeCoins(coins: any, cost: number): number?
	local have = finite(coins)
	if not have or cost <= 0 or have < cost then
		return nil
	end
	local left = have - cost
	if left ~= left or left < 0 then
		return nil
	end
	return left
end

function Crew.ensure(data: any): any
	if type(data.crew) ~= "table" then
		data.crew = { owned = {}, slots = 3, nextUid = 1, extra = 0 }
	end
	local crew = data.crew
	if type(crew.owned) ~= "table" then
		crew.owned = {}
	end
	if type(crew.nextUid) ~= "number" or crew.nextUid < 1 then
		crew.nextUid = 1
	end
	if type(crew.extra) ~= "number" then
		crew.extra = 0
	end
	if type(data.ranch) ~= "table" then
		data.ranch = { tier = 1 }
	end
	if type(data.ranch.tier) ~= "number" then
		data.ranch.tier = 1
	end
	crew.slots = Crew.slotCount(data.ranch.tier, crew.extra)
	if type(data.offline) ~= "table" then
		data.offline = { lastTick = 0 }
	end
	return crew
end

function Crew.findSpecies(owned: { any }, speciesId: string): Member?
	for _, member in ipairs(owned) do
		if member.species == speciesId and (member.level or 1) < rules().maxLevel then
			return member
		end
	end
	return nil
end

function Crew.findUid(owned: { any }, uid: number): Member?
	for _, member in ipairs(owned) do
		if member.uid == uid then
			return member
		end
	end
	return nil
end

export type HireOutcome = {
	ok: boolean,
	reason: string,
	cost: number?,
	coins: number,
	mergeUid: number?,
	member: Member?,
}

function Crew.hireMessage(reason: string, cost: number?): string
	if reason == "coins" and cost then
		return string.format("You need %d coins.", cost)
	elseif reason == "slots" then
		return "The ranch is full. A ranch tier adds crew slots."
	elseif reason == "bad" then
		return "That critter isn't on the line."
	end
	return "You can't hire right now."
end

-- Does not mutate the save. The caller writes coins and the roster after this returns ok.
function Crew.tryHire(data: any, applicant: any): HireOutcome
	local crew = Crew.ensure(data)
	local balance = if finite(data.coins) then data.coins else 0
	if type(applicant) ~= "table" or type(applicant.species) ~= "string" then
		return { ok = false, reason = "bad", coins = balance }
	end
	local species = Crew.byId(applicant.species)
	if not species then
		return { ok = false, reason = "bad", coins = balance }
	end
	local trait = Crew.traitDef(applicant.trait)
	local cost = math.max(1, math.floor((species.price * trait.mult) + 0.5))
	if type(applicant.price) == "number" and applicant.price > 0 then
		cost = math.floor(applicant.price)
	end
	local left = takeCoins(data.coins, cost)
	if not left then
		return { ok = false, reason = "coins", cost = cost, coins = balance }
	end
	local merge = Crew.findSpecies(crew.owned, species.id)
	if merge then
		return { ok = true, reason = "ok", cost = cost, coins = left, mergeUid = merge.uid }
	end
	if #crew.owned >= crew.slots then
		return { ok = false, reason = "slots", cost = cost, coins = balance }
	end
	local member: Member = {
		uid = crew.nextUid,
		species = species.id,
		name = species.name,
		level = 1,
		trait = trait.id,
		badge = nil,
		role = species.role,
	}
	return { ok = true, reason = "ok", cost = cost, coins = left, member = member }
end

function Crew.applyHire(data: any, outcome: HireOutcome): Member?
	if not outcome.ok then
		return nil
	end
	local crew = Crew.ensure(data)
	data.coins = outcome.coins
	if outcome.mergeUid then
		local member = Crew.findUid(crew.owned, outcome.mergeUid)
		if member then
			member.level = math.min(rules().maxLevel, (member.level or 1) + 1)
			return member
		end
	end
	local member = outcome.member
	if not member then
		return nil
	end
	table.insert(crew.owned, member)
	crew.nextUid = member.uid + 1
	return member
end

export type LevelOutcome = {
	ok: boolean,
	reason: string,
	cost: number?,
	coins: number,
	uid: number?,
	level: number?,
}

function Crew.tryLevel(data: any, uid: any): LevelOutcome
	local crew = Crew.ensure(data)
	local balance = if finite(data.coins) then data.coins else 0
	local id = finite(uid)
	if not id then
		return { ok = false, reason = "bad", coins = balance }
	end
	local member = Crew.findUid(crew.owned, id)
	if not member then
		return { ok = false, reason = "missing", coins = balance }
	end
	local species = Crew.byId(member.species)
	if not species then
		return { ok = false, reason = "bad", coins = balance }
	end
	local cost = Crew.levelCost(species.price, member.level)
	if not cost then
		return { ok = false, reason = "max", coins = balance }
	end
	local left = takeCoins(data.coins, cost)
	if not left then
		return { ok = false, reason = "coins", cost = cost, coins = balance }
	end
	return { ok = true, reason = "ok", cost = cost, coins = left, uid = member.uid, level = member.level + 1 }
end

function Crew.levelMessage(reason: string, cost: number?): string
	if reason == "coins" and cost then
		return string.format("You need %d coins.", cost)
	elseif reason == "max" then
		return "That's as high as it goes."
	elseif reason == "missing" then
		return "That critter isn't on the ranch."
	end
	return "You can't level them right now."
end

function Crew.applyLevel(data: any, outcome: LevelOutcome): boolean
	if not outcome.ok or not outcome.uid or not outcome.level then
		return false
	end
	local member = Crew.findUid(data.crew.owned, outcome.uid)
	if not member or member.level ~= outcome.level - 1 then
		return false
	end
	data.coins = outcome.coins
	member.level = outcome.level
	return true
end

function Crew.nextTier(tier: number): any?
	for _, row in ipairs(Config.RanchTiers) do
		if row.tier == tier + 1 then
			return row
		end
	end
	return nil
end

export type TierOutcome = {
	ok: boolean,
	reason: string,
	cost: number?,
	coins: number,
	tier: number?,
	name: string?,
}

function Crew.tryTier(data: any): TierOutcome
	Crew.ensure(data)
	local balance = if finite(data.coins) then data.coins else 0
	local nxt = Crew.nextTier(math.floor(data.ranch.tier))
	if not nxt or not nxt.cost or nxt.cost <= 0 then
		return { ok = false, reason = "max", coins = balance }
	end
	local left = takeCoins(data.coins, nxt.cost)
	if not left then
		return { ok = false, reason = "coins", cost = nxt.cost, coins = balance }
	end
	return { ok = true, reason = "ok", cost = nxt.cost, coins = left, tier = nxt.tier, name = nxt.name }
end

function Crew.tierMessage(reason: string, cost: number?): string
	if reason == "coins" and cost then
		return string.format("You need %d coins.", cost)
	elseif reason == "max" then
		return "The ranch is built out."
	end
	return "You can't build that right now."
end

function Crew.applyTier(data: any, outcome: TierOutcome): boolean
	if not outcome.ok or not outcome.tier then
		return false
	end
	local crew = Crew.ensure(data)
	if data.ranch.tier ~= outcome.tier - 1 then
		return false
	end
	data.coins = outcome.coins
	data.ranch.tier = outcome.tier
	crew.slots = Crew.slotCount(data.ranch.tier, crew.extra)
	return true
end

-- What a working critter does on the ranch. Pit and grill hands cook. Servers carry plates.
function Crew.job(role: string): string
	if role == "pit" then
		return "smoke"
	elseif role == "grill" then
		return "grill"
	elseif role == "server" then
		return "serve"
	end
	return "greet"
end

-- A brand-new ranch with nobody hired yet. Veterans (onboarding finished, or they already
-- cooked and served) do not get a second free Pip.
function Crew.needsStarter(data: any): boolean
	local crew = Crew.ensure(data)
	if crew.starterGranted == true or #crew.owned > 0 then
		return false
	end
	if type(data.onboard) == "table" and data.onboard.done == true then
		return false
	end
	if type(data.tutorial) == "table" and data.tutorial.done == true then
		return false
	end
	if type(data.guide) == "table" and (data.guide.done == true or data.guide.skipped == true) then
		return false
	end
	local served = data.stats and data.stats.served or 0
	if type(served) == "number" and served > 0 then
		return false
	end
	local played = data.playSeconds or 0
	if type(played) == "number" and played > 90 then
		return false
	end
	return true
end

-- Free Pip. Does not spend coins and does not take a Hiring Line applicant.
function Crew.grantStarter(data: any): Member?
	if not Crew.needsStarter(data) then
		return nil
	end
	local species = Crew.byId("armadillo")
	if not species then
		return nil
	end
	local crew = data.crew
	local member: Member = {
		uid = crew.nextUid,
		species = species.id,
		name = "Pip",
		level = 1,
		trait = "none",
		badge = nil,
		role = species.role,
	}
	table.insert(crew.owned, member)
	crew.nextUid = member.uid + 1
	crew.starterGranted = true
	return member
end

function Crew.view(data: any, mults: Mults?): any
	local crew = Crew.ensure(data)
	local owned = {}
	for _, member in ipairs(crew.owned) do
		local species = Crew.byId(member.species)
		local rarity = species and Crew.rarityDef(species.rarity) or nil
		local trait = Crew.traitDef(member.trait)
		table.insert(owned, {
			uid = member.uid,
			species = member.species,
			name = member.name,
			level = member.level,
			trait = trait.id,
			traitName = trait.name,
			badge = member.badge,
			role = member.role,
			roleName = (Config.CrewRoles[member.role] and Config.CrewRoles[member.role].name) or member.role,
			rarity = species and species.rarity or "common",
			rarityName = rarity and rarity.name or "Common",
			color = rarity and rarity.color or "#E7E2DA",
			line = species and species.line or "",
			earn = Crew.memberRate(member, mults),
			levelCost = species and Crew.levelCost(species.price, member.level) or nil,
		})
	end
	local nxt = Crew.nextTier(math.floor(data.ranch.tier))
	local tierRow = Config.RanchTiers[math.clamp(math.floor(data.ranch.tier), 1, #Config.RanchTiers)]
	return {
		owned = owned,
		slots = crew.slots,
		extra = crew.extra,
		used = math.min(#crew.owned, crew.slots),
		tier = data.ranch.tier,
		tierName = tierRow and tierRow.name or "Open yard",
		nextCost = nxt and nxt.cost or nil,
		nextName = nxt and nxt.name or nil,
		nextBlurb = nxt and nxt.blurb or nil,
		rate = Crew.totalRate(crew.owned, crew.slots, mults),
	}
end

return Crew
