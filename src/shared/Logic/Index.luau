--!strict
-- Crew Index. A species row is that critter with all 4 traits. A finished row is +2% income, forever.
-- Finishing every species of a rarity grants a free title.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")

local Index = {}

local TRAITS = { "smoky", "glazed", "golden", "meteorite" }

function Index.traits(): { string }
	return TRAITS
end

function Index.ensure(data: any): any
	if type(data.index) ~= "table" then
		data.index = { traits = {} }
	end
	if type(data.index.traits) ~= "table" then
		data.index.traits = {}
	end
	if type(data.titles) ~= "table" then
		data.titles = {}
	end
	return data.index
end

function Index.has(data: any, speciesId: string, traitId: string): boolean
	local index = Index.ensure(data)
	local row = index.traits[speciesId]
	return type(row) == "table" and row[traitId] == true
end

function Index.rowComplete(data: any, speciesId: string): boolean
	for _, traitId in ipairs(TRAITS) do
		if not Index.has(data, speciesId, traitId) then
			return false
		end
	end
	return true
end

function Index.completedRows(data: any, speciesList: { any }?): number
	local list = speciesList or Config.CrewSpecies
	local n = 0
	for _, species in ipairs(list) do
		if species.secret ~= true and Index.rowComplete(data, species.id) then
			n += 1
		end
	end
	return n
end

function Index.incomeMult(data: any): number
	return 1 + Config.IndexBonus * Index.completedRows(data)
end

function Index.rarityComplete(data: any, rarity: string, speciesList: { any }?): boolean
	local list = speciesList or Config.CrewSpecies
	local any = false
	for _, species in ipairs(list) do
		if species.rarity == rarity and species.secret ~= true then
			any = true
			if not Index.rowComplete(data, species.id) then
				return false
			end
		end
	end
	return any
end

export type Note = { newTrait: boolean, rowDone: boolean, title: string? }

-- Records a caught trait. Does not downgrade anything; the caller already upgraded the critter.
function Index.note(data: any, speciesId: string, traitId: string): Note
	local index = Index.ensure(data)
	if traitId == "none" or traitId == "" then
		return { newTrait = false, rowDone = false, title = nil }
	end
	local row = index.traits[speciesId]
	if type(row) ~= "table" then
		row = {}
		index.traits[speciesId] = row
	end
	local wasRow = Index.rowComplete(data, speciesId)
	local fresh = row[traitId] ~= true
	row[traitId] = true
	local rowDone = fresh and not wasRow and Index.rowComplete(data, speciesId)
	local title = nil
	local species = nil
	for _, rowSpecies in ipairs(Config.CrewSpecies) do
		if rowSpecies.id == speciesId then
			species = rowSpecies
			break
		end
	end
	if species and Index.rarityComplete(data, species.rarity) then
		local name = Config.IndexTitles[species.rarity]
		if name and data.titles[name] ~= true then
			data.titles[name] = true
			title = name
		end
	end
	return { newTrait = fresh, rowDone = rowDone, title = title }
end

return Index
