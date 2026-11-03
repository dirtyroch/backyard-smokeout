--!strict
--[[
	Storefront.luau — can this player buy this item right now? (pure logic, unit-tested)
	Every "no" comes with a calm, plain reason. No timers, no pressure.
]]
local Storefront = {}

export type Ctx = {
	owned: { [string]: boolean },
	featured: { [string]: boolean },
	eventActive: boolean,
	onceBought: { [string]: boolean },
	cooking: boolean,
	seasonActive: boolean,
	seasonPaid: boolean,
	canSkip: (n: number) -> boolean,
}

function Storefront.ownedCount(owned: { [string]: boolean }, grants: { string }?): number
	local n = 0
	for _, id in ipairs(grants or {}) do
		if owned[id] then
			n += 1
		end
	end
	return n
end

function Storefront.ownsAll(owned: { [string]: boolean }, grants: { string }?): boolean
	return grants ~= nil and #grants > 0 and Storefront.ownedCount(owned, grants) == #grants
end

function Storefront.canBuy(key: string, p: any, c: Ctx): (boolean, string?)
	if p.rotation and not c.featured[key] then
		return false, "That one's not in this week's rotation. It'll be back!"
	end
	if p.event == "turkeyday" and not c.eventActive then
		return false, "The Turkey Day looks are on sale during Thanksgiving week. They come back next year."
	end
	if p.once and c.onceBought[key] then
		return false, "You already picked up this one-time pack. Thanks!"
	end
	if (p.kind == "cosmetic" or p.kind == "bundle") and Storefront.ownsAll(c.owned, p.grants) then
		return false, "You already own everything in this."
	end
	if p.kind == "finish" and not c.cooking then
		return false, "Nothing is cooking right now."
	end
	if p.kind == "season" or p.kind == "tierskip" then
		if not c.seasonActive then
			return false, "The next Smokehouse Pass season is still being smoked up."
		end
		if p.kind == "season" and c.seasonPaid then
			return false, "You already have this season's Smokehouse Pass."
		end
		if p.kind == "tierskip" and not c.canSkip(p.count or 1) then
			return false, "That would go past the top tier."
		end
	end
	return true, nil
end

-- Pit Crew Club monthly look: a fixed cycle by calendar month, so everyone gets the same one.
function Storefront.clubLook(looks: { string }, year: number, month: number): string
	return looks[((year * 12 + month - 1) % #looks) + 1]
end

function Storefront.monthKey(year: number, month: number): number
	return year * 12 + month - 1
end

return Storefront
