--!strict
-- Family purse chips. The contributor's coins are saved before the host is credited.
-- A nonce on the host means a retry cannot add the same coins twice.
local Purse = {}

export type Entry = { nonce: string, amount: number, hostId: string }

local function outbox(data: any): { Entry }
	if type(data.purseOut) ~= "table" then
		data.purseOut = {}
	end
	return data.purseOut
end

function Purse.propose(data: any, amount: number, hostId: string, now: number): (Entry?, string)
	if amount ~= amount or amount <= 0 or amount ~= math.floor(amount) then
		return nil, "That amount doesn't fit."
	end
	if type(data.coins) ~= "number" or data.coins < amount then
		return nil, "You don't have that many coins."
	end
	local box = outbox(data)
	local nonce = string.format("%s:%d:%d:%d", hostId, now, amount, #box + 1)
	return { nonce = nonce, amount = amount, hostId = hostId }, ""
end

function Purse.commit(data: any, entry: Entry)
	data.coins -= entry.amount
	table.insert(outbox(data), entry)
end

function Purse.rollback(data: any, nonce: string): boolean
	local box = outbox(data)
	for i, entry in ipairs(box) do
		if entry.nonce == nonce then
			data.coins += entry.amount
			table.remove(box, i)
			return true
		end
	end
	return false
end

function Purse.ack(data: any, nonce: string)
	local box = outbox(data)
	local nextBox = {}
	for _, entry in ipairs(box) do
		if entry.nonce ~= nonce then
			table.insert(nextBox, entry)
		end
	end
	data.purseOut = nextBox
end

function Purse.apply(host: any, entry: Entry): boolean
	if type(host.family) ~= "table" then
		host.family = { on = false, purse = 0, seen = {} }
	end
	if type(host.family.seen) ~= "table" then
		host.family.seen = {}
	end
	if host.family.seen[entry.nonce] == true then
		return false
	end
	host.family.seen[entry.nonce] = true
	host.family.purse = (host.family.purse or 0) + entry.amount
	return true
end

-- saveContributor and saveHost return true when that player's coins are durable.
-- If the contributor's save fails, their coins are put back and the host is not touched.
export type Transfer = { ok: boolean, message: string, credited: boolean }

function Purse.transfer(contributor: any, host: any, amount: number, hostId: string, now: number, saveContributor: () -> boolean, saveHost: () -> boolean): Transfer
	local entry, why = Purse.propose(contributor, amount, hostId, now)
	if not entry then
		return { ok = false, message = why, credited = false }
	end
	Purse.commit(contributor, entry)
	if not saveContributor() then
		Purse.rollback(contributor, entry.nonce)
		return { ok = false, message = "Couldn't save that. Your coins stayed with you.", credited = false }
	end
	local fresh = Purse.apply(host, entry)
	if not saveHost() then
		return { ok = true, message = "Added to the family purse. It will finish saving with the host.", credited = fresh }
	end
	Purse.ack(contributor, entry.nonce)
	saveContributor()
	return { ok = true, message = string.format("Added %d coins to the family purse.", amount), credited = fresh }
end

return Purse
