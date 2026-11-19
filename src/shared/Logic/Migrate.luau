--!strict
-- One-time save step from schema 1 to schema 2. Safe to call again: a schema 2 save is left alone.
-- Founders keep their names. Their old speed, carry and quality become one level.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")
local Crew = if script ~= nil and script.Parent ~= nil then require(script.Parent.Crew) else require("./Crew")

local Migrate = {}

local function progress(data: any): boolean
	local rookie = data.rookie
	if type(rookie) == "table" and ((rookie.claimed or 0) > 0 or rookie.skipped == true or rookie.resumed == true) then
		return true
	end
	local guide = data.guide
	if type(guide) == "table" and (guide.done == true or guide.skipped == true or guide.introduced == true or (guide.step or 1) > 1) then
		return true
	end
	local tutorial = data.tutorial
	if type(tutorial) == "table" and (tutorial.done == true or tutorial.firstBrisket == true) then
		return true
	end
	return false
end

local function grantRookie(data: any)
	if type(data.onboard) ~= "table" then
		data.onboard = { done = false, rookieReward = false }
	end
	if data.onboard.rookieReward == true then
		return
	end
	local rookie = data.rookie
	if type(rookie) ~= "table" then
		return
	end
	local claimed = rookie.claimed or 0
	local total = #Config.RookieSteps
	if claimed <= 0 or claimed >= total then
		return
	end
	local reward = Config.RookieFinish
	if type(data.titles) == "table" and reward.title and data.titles[reward.title] then
		data.onboard.rookieReward = true
		return
	end
	if type(reward.coins) == "number" and reward.coins > 0 then
		data.coins = (data.coins or 0) + reward.coins
	end
	if reward.cosmetic then
		if type(data.owned) ~= "table" then
			data.owned = {}
		end
		data.owned[reward.cosmetic] = true
	end
	if reward.title then
		if type(data.titles) ~= "table" then
			data.titles = {}
		end
		data.titles[reward.title] = true
	end
	data.onboard.rookieReward = true
end

local function extraSlots(data: any): number
	local n = 0
	if type(data.smokerSlotsBought) == "number" and data.smokerSlotsBought > 0 then
		n += 1
	end
	if type(data.grillSlotsBought) == "number" and data.grillSlotsBought > 0 then
		n += 1
	end
	return n
end

-- Returns true when this call did the schema 2 step.
function Migrate.apply(data: any, now: number?): boolean
	if type(data) ~= "table" then
		return false
	end
	local schema = data.schema
	if type(schema) == "number" and schema >= 2 then
		return false
	end
	Crew.ensure(data)
	if type(data.index) ~= "table" then
		data.index = { traits = {} }
	elseif type(data.index.traits) ~= "table" then
		data.index.traits = {}
	end
	if type(data.codes) ~= "table" then
		data.codes = {}
	end
	if type(data.partners) ~= "table" then
		data.partners = {}
	end
	if type(data.events) ~= "table" then
		data.events = { smokeShowWeek = -1 }
	elseif type(data.events.smokeShowWeek) ~= "number" then
		data.events.smokeShowWeek = -1
	end
	if type(data.onboard) ~= "table" then
		data.onboard = { done = false, rookieReward = false }
	end
	local roster = {}
	if type(data.staff) == "table" and type(data.staff.roster) == "table" then
		roster = data.staff.roster
	end
	local owned = {}
	local uid = 1
	for _, entry in ipairs(roster) do
		if type(entry) == "table" and type(entry.id) == "string" then
			local founder = Config.Founders[entry.id]
			local species = founder and Crew.byId(founder.species) or nil
			if founder and species then
				table.insert(owned, {
					uid = uid,
					species = species.id,
					name = founder.name,
					level = Crew.founderLevel(entry.speed, entry.capacity, entry.quality),
					trait = "none",
					badge = "Founder",
					role = species.role,
				})
				uid += 1
			end
		end
	end
	data.crew.owned = owned
	data.crew.nextUid = uid
	local pit = data.pitLevel
	local tier = 1
	if type(pit) == "number" and pit == pit then
		tier = math.clamp(math.floor(pit), 1, #Config.RanchTiers)
	end
	data.ranch.tier = tier
	data.crew.extra = extraSlots(data)
	data.crew.slots = Crew.slotCount(tier, data.crew.extra, data.crew.bunkhouse == true)
	if progress(data) then
		data.onboard.done = true
	end
	grantRookie(data)
	local tick = if type(now) == "number" and now > 0 then now else 0
	data.offline.lastTick = tick
	data.schema = 2
	return true
end

return Migrate
