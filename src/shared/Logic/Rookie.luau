--!strict
-- Unc Hank's Rookie List: five quick goals that walk a brand-new pitmaster through the first
-- five minutes (after the one-button first brisket). Each goal is a lifetime stat, so it can't be
-- lost, and the client shows an arrow to where the goal happens. Pure logic, no Roblox APIs.
local Rookie = {}

export type State = { claimed: number, skipped: boolean? }

function Rookie.new(): State
	return { claimed = 0 }
end

export type Status = {
	step: number, -- 1-based index of the current goal (total + 1 when finished)
	total: number,
	finished: boolean,
	progress: number,
	amount: number,
	id: string?,
	label: string?,
	target: string?,
	reward: any?,
}

function Rookie.status(s: State, steps: { any }, stats: { [string]: number }): Status
	local step = s.claimed + 1
	local def = steps[step]
	if s.skipped or not def then
		return { step = #steps + 1, total = #steps, finished = true, progress = 0, amount = 0 }
	end
	local progress = math.min(stats[def.stat] or 0, def.amount)
	return {
		step = step,
		total = #steps,
		finished = false,
		progress = progress,
		amount = def.amount,
		id = def.id,
		label = def.label,
		target = def.target,
		reward = def.reward,
	}
end

-- Claims every goal that is already met, in order. Returns the list of goals just claimed.
-- (Usually zero or one, but a fast player can finish two in one action.)
function Rookie.advance(s: State, steps: { any }, stats: { [string]: number }): { any }
	local claimed = {}
	if s.skipped then
		return claimed
	end
	while true do
		local def = steps[s.claimed + 1]
		if not def or (stats[def.stat] or 0) < def.amount then
			break
		end
		s.claimed += 1
		table.insert(claimed, def)
	end
	return claimed
end

-- Veterans from before the list existed skip it quietly (they already know the loop).
function Rookie.shouldSkip(s: State, tutorialDone: boolean, stats: { [string]: number }, veteranServes: number): boolean
	return s.claimed == 0 and not s.skipped and tutorialDone and (stats.served or 0) >= veteranServes
end

return Rookie
