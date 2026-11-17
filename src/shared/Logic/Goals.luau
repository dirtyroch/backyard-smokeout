--!strict
-- The one next-step the HUD keeps on screen after the Rookie List is done.
local Numbers = if script ~= nil and script.Parent ~= nil then require(script.Parent.Numbers) else require("./Numbers")

local Goals = {}

export type Input = {
	rookieActive: boolean,
	giftReady: boolean,
	coins: number,
	hireCost: number?,
	hireName: string?,
	pitCost: number?,
	pitName: string?,
	crew: number,
	crewSlots: number,
}

export type Goal = {
	id: string,
	title: string,
	detail: string,
	current: number,
	goal: number,
	action: string,
}

function Goals.next(inp: Input): Goal?
	if inp.giftReady then
		return {
			id = "gift",
			title = "Free gift ready",
			detail = "Tap to claim",
			current = 1,
			goal = 1,
			action = "gift",
		}
	end
	if inp.rookieActive then
		return nil
	end
	if inp.hireCost and inp.hireName and inp.hireCost > 0 then
		local cost = inp.hireCost
		return {
			id = "hire",
			title = "Next: hire " .. inp.hireName,
			detail = Numbers.abbrev(math.max(0, inp.coins)) .. " / " .. Numbers.abbrev(cost),
			current = math.clamp(inp.coins, 0, cost),
			goal = cost,
			action = "crew",
		}
	end
	if inp.pitCost and inp.pitName and inp.pitCost > 0 then
		local cost = inp.pitCost
		return {
			id = "pit",
			title = "Next upgrade: " .. inp.pitName,
			detail = Numbers.abbrev(math.max(0, inp.coins)) .. " / " .. Numbers.abbrev(cost),
			current = math.clamp(inp.coins, 0, cost),
			goal = cost,
			action = "upgrades",
		}
	end
	local slots = math.max(1, inp.crewSlots)
	return {
		id = "crew",
		title = "Crew is on the ranch",
		detail = string.format("%d / %d hands working", math.min(inp.crew, slots), slots),
		current = math.min(inp.crew, slots),
		goal = slots,
		action = "crew",
	}
end

return Goals
