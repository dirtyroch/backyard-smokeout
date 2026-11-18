--!strict
--[[
	Ranch crew. Coin-bought hands who cook, carry and serve.
	Jimothy the Waiter (the AutoServe pass) is not one of these slots. He still
	serves on his own timer. Owning the pass also shortens the crew's walk
	between jobs, so the pass stays a boost instead of a second copy of the crew.
	The first grill and the first smoker stay the player's. Crew uses the rest.
]]
local Economy = if script ~= nil and script.Parent ~= nil then require(script.Parent.Economy) else require("./Economy")
local FreeGift = if script ~= nil and script.Parent ~= nil then require(script.Parent.FreeGift) else require("./FreeGift")

local Staff = {}

Staff.MAX = 5

export type Hand = {
	id: string,
	name: string,
	species: string,
	role: string,
	title: string,
	blurb: string,
	lines: { string },
}

export type Employee = {
	id: string,
	name: string,
	species: string,
	role: string,
	speed: number,
	capacity: number,
	quality: number,
}

export type World = {
	coins: number,
	cooler: number,
	coolerMax: number,
	customers: number,
	openGrill: number,
	openSmoker: number,
	done: number,
	burgerCost: number,
	linkCost: number,
}

export type Decision = {
	kind: string,
	meat: string?,
	count: number,
}

Staff.HANDS = {
	{
		id = "pip",
		name = "Pip",
		species = "raccoon",
		role = "grill",
		title = "Grill hand",
		blurb = "Starts burgers on your extra grills, then carries plates and serves when the grill is busy.",
		lines = {
			"Patties are my whole personality.",
			"I can hear that grill from the creek.",
			"You flip. I'll mind the patties.",
		},
	},
	{
		id = "dottie",
		name = "Dottie",
		species = "armadillo",
		role = "pit",
		title = "Pit hand",
		blurb = "Keeps hot links moving on your extra smokers. Low and slow, on purpose.",
		lines = {
			"Low and slow. That's the whole job.",
			"Hot links are in. Don't rush a shell.",
			"The pit's hot. I'm not.",
		},
	},
	{
		id = "mango",
		name = "Mango",
		species = "clapcat",
		role = "floor",
		title = "Floor",
		blurb = "Serves the line and carries finished plates. Doesn't start cooks.",
		lines = {
			"Order up. I clapped for it.",
			"Table's hungry. I'm on it.",
			"I serve faster than I nap. That's new.",
		},
	},
	{
		id = "biscuit",
		name = "Biscuit",
		species = "bellyrubpup",
		role = "grill",
		title = "Grill hand",
		blurb = "Another burger station, plus a very serious tail.",
		lines = {
			"Belly rubs after the lunch rush.",
			"I brought the buns.",
			"Who's a good pitmaster? You are.",
		},
	},
	{
		id = "tumble",
		name = "Tumble",
		species = "hornedtoad",
		role = "pit",
		title = "Pit hand",
		blurb = "Fits under the barrel and keeps another smoker fed.",
		lines = {
			"Spikes out. Smoker loaded.",
			"I fit right under the barrel.",
			"Hot link express, coming through.",
		},
	},
} :: { Hand }

-- First hand is a short goal. Later hands cost more than a casual burger loop.
Staff.COSTS = { 250, 900, 2800, 8000, 22000 }

local UPGRADE_BASE: { [string]: number } = { speed = 180, capacity = 220, quality = 260 }

function Staff.hand(id: string): Hand?
	for _, h in ipairs(Staff.HANDS) do
		if h.id == id then
			return h
		end
	end
	return nil
end

function Staff.slots(pitLevel: number): number
	local level = math.clamp(math.floor(pitLevel), 1, #Staff.HANDS)
	return level
end

function Staff.preview(have: number): Hand?
	return Staff.HANDS[have + 1]
end

-- The next hand who is not already on the roster, in catalog order.
-- Indexing by roster length hired a duplicate when an earlier id had been dropped.
function Staff.nextHand(roster: { any }): Hand?
	local seen: { [string]: boolean } = {}
	for _, e in ipairs(roster) do
		if type(e) == "table" and type(e.id) == "string" then
			seen[e.id] = true
		end
	end
	for _, h in ipairs(Staff.HANDS) do
		if not seen[h.id] then
			return h
		end
	end
	return nil
end

local function finiteNumber(n: any): number?
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return n
end

-- Coins left after paying `cost`, or nil when the spend is not allowed.
-- NaN, infinity, a non-positive cost, and a balance that would go below zero all refuse.
function Staff.takeCoins(coins: any, cost: any): number?
	local have = finiteNumber(coins)
	local price = finiteNumber(cost)
	if not have or not price or price <= 0 or have < price then
		return nil
	end
	local left = have - price
	if left ~= left or left < 0 then
		return nil
	end
	return left
end

export type HireOutcome = {
	ok: boolean,
	reason: string,
	cost: number?,
	coins: number,
	employee: Employee?,
}

function Staff.hireMessage(reason: string, cost: number?): string
	if reason == "coins" and cost then
		return string.format("You need %d coins.", cost)
	elseif reason == "slots" then
		return "Upgrade your pit to hire another hand."
	elseif reason == "full" then
		return "The crew is full."
	end
	return "You can't hire right now."
end

-- Does not mutate `roster`. The caller inserts `employee` only after this returns ok.
function Staff.tryHire(roster: { any }, pitLevel: any, coins: any): HireOutcome
	local level = finiteNumber(pitLevel) or 1
	local slots = Staff.slots(level)
	if slots ~= slots then
		slots = 1
	end
	if #roster >= slots then
		return { ok = false, reason = "slots", coins = if finiteNumber(coins) then coins :: number else 0 }
	end
	local hand = Staff.nextHand(roster)
	local cost = Staff.hireCost(#roster)
	if not hand or not cost or Staff.find(roster :: { Employee }, hand.id) then
		return { ok = false, reason = "full", coins = if finiteNumber(coins) then coins :: number else 0 }
	end
	local left = Staff.takeCoins(coins, cost)
	if not left then
		return { ok = false, reason = "coins", cost = cost, coins = if finiteNumber(coins) then coins :: number else 0 }
	end
	return {
		ok = true,
		reason = "ok",
		cost = cost,
		coins = left,
		employee = {
			id = hand.id,
			name = hand.name,
			species = hand.species,
			role = hand.role,
			speed = 1,
			capacity = 1,
			quality = 1,
		},
	}
end

export type UpgradeOutcome = {
	ok: boolean,
	reason: string,
	cost: number?,
	coins: number,
	stat: string?,
	from: number?,
	level: number?,
}

function Staff.upgradeMessage(reason: string, cost: number?): string
	if reason == "coins" and cost then
		return string.format("You need %d coins.", cost)
	elseif reason == "max" then
		return "That's as high as it goes."
	elseif reason == "missing" then
		return "That hand isn't on the crew."
	end
	return "Bad request."
end

-- Does not mutate the employee. `from` is the level this price was quoted for,
-- so a second in-flight upgrade of the same level can be refused.
function Staff.tryUpgrade(roster: { any }, id: any, stat: any, coins: any): UpgradeOutcome
	local balance = if finiteNumber(coins) then coins :: number else 0
	if type(id) ~= "string" or #id > 32 or (stat ~= "speed" and stat ~= "capacity" and stat ~= "quality") then
		return { ok = false, reason = "bad", coins = balance }
	end
	local e = Staff.find(roster :: { Employee }, id)
	if not e then
		return { ok = false, reason = "missing", coins = balance }
	end
	local from = finiteNumber((e :: any)[stat])
	if not from then
		return { ok = false, reason = "max", coins = balance }
	end
	local cost = Staff.upgradeCost(stat, from)
	if not cost then
		return { ok = false, reason = "max", coins = balance }
	end
	local left = Staff.takeCoins(coins, cost)
	if not left then
		return { ok = false, reason = "coins", cost = cost, coins = balance }
	end
	return { ok = true, reason = "ok", cost = cost, coins = left, stat = stat, from = from, level = from + 1 }
end

function Staff.hireCost(have: number): number?
	return Staff.COSTS[have + 1]
end

function Staff.template(have: number): Employee?
	local h = Staff.preview(have)
	if not h then
		return nil
	end
	return {
		id = h.id,
		name = h.name,
		species = h.species,
		role = h.role,
		speed = 1,
		capacity = 1,
		quality = 1,
	}
end

function Staff.find(roster: { Employee }, id: string): Employee?
	for _, e in ipairs(roster) do
		if e.id == id then
			return e
		end
	end
	return nil
end

function Staff.upgradeCost(stat: string, level: number): number?
	local base = UPGRADE_BASE[stat]
	if not base or level >= Staff.MAX or level < 1 then
		return nil
	end
	return math.floor(base * (level ^ 1.4))
end

-- Seconds between jobs. The waiter pass shortens the walk. It does not cook for them.
function Staff.interval(speedLevel: number, waiterPass: boolean): number
	local level = math.clamp(math.floor(speedLevel), 1, Staff.MAX)
	local seconds = 16 * (0.84 ^ (level - 1))
	if waiterPass then
		seconds *= 0.72
	end
	return seconds
end

function Staff.carry(capacityLevel: number): number
	return math.clamp(math.floor(capacityLevel), 1, Staff.MAX)
end

function Staff.qualityLuck(qualityLevel: number): number
	local level = math.clamp(math.floor(qualityLevel), 1, Staff.MAX)
	return 1 + 0.06 * (level - 1)
end

-- Extra plate value when this hand is the one serving. Caps at +20%.
function Staff.qualityTip(qualityLevel: number): number
	local level = math.clamp(math.floor(qualityLevel), 1, Staff.MAX)
	return 1 + 0.05 * (level - 1)
end

function Staff.line(id: string, index: number): string
	local h = Staff.hand(id)
	local lines = if h then h.lines else { "On it!" }
	local i = ((math.floor(index) - 1) % #lines) + 1
	return lines[i]
end

-- What a hand starts on their own. Grill hands make burgers, pit hands make hot links.
-- Event cuts (turkey leg, holiday ham) stay the player's to smoke and carry to the potluck.
-- A hand never starts one, so they can't auto-share it or cash the daily reward.
function Staff.stationMeat(role: string): string?
	if role == "grill" then
		return "burger"
	elseif role == "pit" then
		return "hotlink"
	end
	return nil
end

-- Cooks fill open extra stations first. Floor serves first. Nobody spends coins they don't have.
function Staff.decide(e: Employee, w: World): Decision?
	local cap = Staff.carry(e.capacity)
	local function serve(): Decision?
		if w.customers > 0 and w.cooler > 0 then
			return { kind = "serve", count = math.min(cap, w.customers, w.cooler) }
		end
		return nil
	end
	local function collect(): Decision?
		if w.done > 0 and w.cooler < w.coolerMax then
			return { kind = "collect", count = math.min(cap, w.done, w.coolerMax - w.cooler) }
		end
		return nil
	end
	if e.role == "floor" then
		return serve() or collect()
	end
	local meat = Staff.stationMeat(e.role)
	if not meat then
		return collect() or serve()
	end
	local open = if meat == "burger" then w.openGrill else w.openSmoker
	local cost = if meat == "burger" then w.burgerCost else w.linkCost
	if open > 0 and cost > 0 and w.coins >= cost then
		local n = math.min(cap, open, math.floor(w.coins / cost))
		if n > 0 then
			return { kind = "cook", meat = meat, count = n }
		end
	end
	return collect() or serve()
end

-- Expected profit per second once a hand is in a steady cook loop.
-- Floor hands don't start cooks, so their cook contribution is 0.
-- The HUD's +/s number is the real trailing earn window, not this estimate.
function Staff.cookProfitPerSecond(e: Employee, meat: any, pitSpeed: number, rarityMult: number, rankMult: number, waiterPass: boolean): number
	if e.role == "floor" then
		return 0
	end
	local speed = math.max(0.05, pitSpeed)
	local cycle = Staff.interval(e.speed, waiterPass) + (meat.cookTime / speed)
	if cycle <= 0 then
		return 0
	end
	local unit = meat.price * rarityMult * rankMult * Staff.qualityTip(e.quality) - Economy.rawCost(meat, rankMult)
	if unit < 0 then
		unit = 0
	end
	return Staff.carry(e.capacity) * unit / cycle
end

function Staff.serveRate(e: Employee, waiterPass: boolean): number
	return Staff.carry(e.capacity) / Staff.interval(e.speed, waiterPass)
end

local function clampLevel(n: any): number
	local v = tonumber(n) or 1
	return math.clamp(math.floor(v), 1, Staff.MAX)
end

-- Drops unknown or duplicate ids and fills missing levels. Old saves load.
function Staff.normalize(data: any)
	if type(data.staff) ~= "table" then
		data.staff = { roster = {} }
	end
	if type(data.staff.roster) ~= "table" then
		data.staff.roster = {}
	end
	local clean: { Employee } = {}
	local seen: { [string]: boolean } = {}
	for _, e in ipairs(data.staff.roster) do
		if type(e) == "table" and type(e.id) == "string" and not seen[e.id] then
			local h = Staff.hand(e.id)
			if h then
				seen[e.id] = true
				table.insert(clean, {
					id = h.id,
					name = h.name,
					species = h.species,
					role = h.role,
					speed = clampLevel(e.speed),
					capacity = clampLevel(e.capacity),
					quality = clampLevel(e.quality),
				})
			end
		end
	end
	data.staff.roster = clean
	data.freeGift = FreeGift.normalize(data.freeGift, nil)
end

function Staff.signature(roster: { any }, slots: number): string
	local parts = {}
	for i, e in ipairs(roster) do
		if i <= slots and type(e) == "table" then
			table.insert(parts, tostring(e.id))
		end
	end
	return table.concat(parts, ",")
end

function Staff.appearance(entry: any, critters: { any }): any?
	for _, c in ipairs(critters) do
		if c.id == entry.species then
			local copy = table.clone(c)
			copy.staff = true
			copy.scale = (c.scale or 1) * 0.92
			return copy
		end
	end
	return nil
end

return Staff
