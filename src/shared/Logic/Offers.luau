--!strict
-- A quiet card next to the thing it helps. No countdown, no "only a few left."
local Offers = {}

export type Offer = { id: string, title: string, detail: string, kind: string, key: string }

export type Need = {
	playSeconds: number,
	skip: boolean,
	promptAt: number,
	slotsFull: boolean,
	bunkhouse: boolean,
	autoHire: boolean,
	hasCrew: boolean,
}

function Offers.pick(need: Need): Offer?
	if not need.skip and need.playSeconds < need.promptAt then
		return nil
	end
	if need.slotsFull and not need.bunkhouse then
		return {
			id = "bunkhouse",
			title = "Bunkhouse",
			detail = "Adds 4 crew slots, and crew keep earning for 8 hours while you're away.",
			kind = "pass",
			key = "Bunkhouse",
		}
	end
	if need.hasCrew and not need.autoHire then
		return {
			id = "autohire",
			title = "Auto-Hire",
			detail = "While you're here, the best critter you can afford is hired when the line restocks. You can turn it off.",
			kind = "pass",
			key = "AutoHire",
		}
	end
	return nil
end

return Offers
