--!strict
-- Ranch Partners. The +10% (up to 3) used to count any friend in the server.
-- It now counts partners who are here, and Cheer is a short boost on one critter.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")

local Partners = {}

function Partners.ensure(data: any): { string }
	if type(data.partners) ~= "table" then
		data.partners = {}
	end
	-- Saved as a list of user-id strings so the datastore stays simple.
	local list = {}
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(data.partners) do
		local key = tostring(id)
		if key ~= "" and not seen[key] and #list < Config.Partners.max then
			seen[key] = true
			table.insert(list, key)
		end
	end
	data.partners = list
	if type(data.family) ~= "table" then
		data.family = { on = false, purse = 0 }
	end
	if type(data.family.purse) ~= "number" then
		data.family.purse = 0
	end
	return list
end

function Partners.bonusCount(partnerIds: { string }, online: { [string]: boolean }, familyOthers: number?): number
	local n = 0
	for _, id in ipairs(partnerIds) do
		if online[id] then
			n += 1
		end
	end
	if type(familyOthers) == "number" and familyOthers > n then
		n = familyOthers
	end
	return math.clamp(n, 0, Config.Partners.max)
end

function Partners.mult(count: number): number
	return 1 + Config.Partners.per * math.clamp(count, 0, Config.Partners.max)
end

-- Friends, or anyone when the server is private. Never yourself, never a 4th partner.
function Partners.canAdd(list: { string }, selfId: string, otherId: string, isFriend: boolean, privateServer: boolean): (boolean, string)
	if otherId == "" or otherId == selfId then
		return false, "Pick someone else in the server."
	end
	if not isFriend and not privateServer then
		return false, "Partners are friends, or anyone in a private server."
	end
	for _, id in ipairs(list) do
		if id == otherId then
			return false, "They're already a ranch partner."
		end
	end
	if #list >= Config.Partners.max then
		return false, "You can have 3 ranch partners."
	end
	return true, ""
end

function Partners.add(data: any, otherId: string)
	local list = Partners.ensure(data)
	table.insert(list, otherId)
	data.partners = list
end

function Partners.remove(data: any, otherId: string): boolean
	local list = Partners.ensure(data)
	local nextList = {}
	local found = false
	for _, id in ipairs(list) do
		if id == otherId then
			found = true
		else
			table.insert(nextList, id)
		end
	end
	data.partners = nextList
	return found
end

export type Cheer = { ok: boolean, reason: string, untilT: number? }

function Partners.tryCheer(now: number, cooldownUntil: number?, activeUntil: number?): Cheer
	if type(cooldownUntil) == "number" and now < cooldownUntil then
		return { ok = false, reason = "You can cheer again in a few minutes." }
	end
	if type(activeUntil) == "number" and now < activeUntil then
		return { ok = false, reason = "That critter is already cheered." }
	end
	return { ok = true, reason = "", untilT = now + Config.Partners.cheerSeconds }
end

function Partners.cheerCooldown(now: number): number
	return now + Config.Partners.cheerCooldown
end

function Partners.cheered(untilT: number?, now: number): boolean
	return type(untilT) == "number" and now < untilT
end

-- Family Ranch is the private-server host sharing one tier purse. Crew stays individual.
function Partners.canHostFamily(isPrivate: boolean, isHost: boolean): boolean
	return isPrivate == true and isHost == true
end

function Partners.chip(coins: number, purse: number, amount: number): (number?, number?)
	if amount ~= amount or amount <= 0 or amount ~= math.floor(amount) then
		return nil, nil
	end
	if coins < amount then
		return nil, nil
	end
	return coins - amount, purse + amount
end

return Partners
