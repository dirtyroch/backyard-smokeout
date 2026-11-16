--!strict
-- Jimothy the Raccoon.
-- Old Regulars Index saves stored serves under the id "possum" (Possum Pete). Those counts
-- move onto "jimothy" so nobody loses a regular. The sighting hunt is server-side: each id
-- counts once, attempts are rate-limited, and the title plus free buddy are granted once.
local Jimothy = {}

Jimothy.LEGACY_ID = "possum"
Jimothy.ID = "jimothy"
Jimothy.TITLE = "Jimothy Spotter"
Jimothy.COSMETIC = "buddy_jimothy"
Jimothy.COOLDOWN = 0.75

Jimothy.LINES = {
	"Praise Jimothy!!",
	"No neck, no problem.",
	"Is that brisket?",
	"Built different.",
}

export type Spot = { id: string, place: string }

Jimothy.SIGHTINGS = {
	{ id = "shack", place = "Behind the Sauce Shack, against the back wall" },
	{ id = "roof", place = "On the Sauce Shack roof, beside the Roof Club pad" },
	{ id = "trash", place = "In a trash can on the southeast edge of the town square (King of the trash)" },
	{ id = "board", place = "Beside the Cook-Off leaderboard, on the back side at ground level" },
	{ id = "spawn", place = "Behind the left post of the welcome arch, just past spawn" },
	{ id = "plots", place = "In the grass outside the ranches, in the gap between plot 1 and plot 2" },
	{ id = "creek", place = "In the cattails by the creek, away from the whisper stone" },
	{ id = "oak", place = "Behind the tire-swing oak, on the far side of the trunk" },
	{ id = "hay", place = "Behind the hay bales west of the Cook-Off stage" },
	{ id = "bertha", place = "Behind Big Bertha, by the back wheel" },
} :: { Spot }

export type Record = {
	ok: boolean,
	duplicate: boolean,
	limited: boolean,
	count: number,
	total: number,
	justCompleted: boolean,
	title: string?,
	cosmetic: string?,
}

function Jimothy.total(): number
	return #Jimothy.SIGHTINGS
end

function Jimothy.isSpot(id: string): boolean
	for _, spot in ipairs(Jimothy.SIGHTINGS) do
		if spot.id == id then
			return true
		end
	end
	return false
end

function Jimothy.count(seen: any): number
	if type(seen) ~= "table" then
		return 0
	end
	local n = 0
	for _, spot in ipairs(Jimothy.SIGHTINGS) do
		if seen[spot.id] then
			n += 1
		end
	end
	return n
end

-- Moves legacy Regulars Index data onto Jimothy. Safe to call more than once.
function Jimothy.migrate(data: any): boolean
	if type(data) ~= "table" then
		return false
	end
	local changed = false
	if type(data.critters) == "table" and data.critters[Jimothy.LEGACY_ID] ~= nil then
		local legacy = data.critters[Jimothy.LEGACY_ID]
		local add = if type(legacy) == "number" then legacy else 0
		local cur = data.critters[Jimothy.ID]
		local base = if type(cur) == "number" then cur else 0
		data.critters[Jimothy.ID] = base + add
		data.critters[Jimothy.LEGACY_ID] = nil
		changed = true
	end
	if data.forceCritter == Jimothy.LEGACY_ID then
		data.forceCritter = Jimothy.ID
		changed = true
	end
	return changed
end

local function ensure(data: any): any
	if type(data.jimothy) ~= "table" then
		data.jimothy = { seen = {}, lastAt = 0, rewarded = false }
	end
	if type(data.jimothy.seen) ~= "table" then
		data.jimothy.seen = {}
	end
	if type(data.titles) ~= "table" then
		data.titles = {}
	end
	return data.jimothy
end

-- `now` is seconds (the server passes os.clock()). A repeat of the same id never
-- adds credit. A new id inside the cooldown is refused and not stored.
function Jimothy.record(data: any, id: string, now: number): Record
	local total = Jimothy.total()
	if type(data) ~= "table" or not Jimothy.isSpot(id) or type(now) ~= "number" then
		return { ok = false, duplicate = false, limited = false, count = 0, total = total, justCompleted = false }
	end
	local state = ensure(data)
	local count = Jimothy.count(state.seen)
	if state.seen[id] then
		return { ok = true, duplicate = true, limited = false, count = count, total = total, justCompleted = false }
	end
	-- lastAt stays 0 until the first credit, so a brand-new save isn't cooling down.
	local last = state.lastAt
	if type(last) == "number" and last > 0 and now - last < Jimothy.COOLDOWN then
		return { ok = false, duplicate = false, limited = true, count = count, total = total, justCompleted = false }
	end
	state.seen[id] = true
	state.lastAt = now
	count += 1
	local just = count >= total and state.rewarded ~= true
	if just then
		state.rewarded = true
		data.titles[Jimothy.TITLE] = true
	end
	return {
		ok = true,
		duplicate = false,
		limited = false,
		count = count,
		total = total,
		justCompleted = just,
		title = if just then Jimothy.TITLE else nil,
		cosmetic = if just then Jimothy.COSMETIC else nil,
	}
end

return Jimothy
