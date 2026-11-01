--!strict
-- 28-day Pitmaster Path: step N unlocks on your Nth distinct play day and is completed by a lifetime stat.
local PitmasterPath = {}

export type State = { claimed: number, playDays: number, lastPlayDay: number }

function PitmasterPath.new(): State
	return { claimed = 0, playDays = 0, lastPlayDay = -1 }
end

-- Call on login and on day rollover. Returns true if a new play day was counted.
function PitmasterPath.registerPlayDay(s: State, today: number): boolean
	if s.lastPlayDay == today then
		return false
	end
	s.lastPlayDay = today
	s.playDays += 1
	return true
end

export type Status = { step: number, done: boolean, unlocked: boolean, progress: number, amount: number, complete: boolean, finished: boolean }

function PitmasterPath.status(s: State, steps: { any }, stats: { [string]: number }): Status
	local step = s.claimed + 1
	local def = steps[step]
	if not def then
		return { step = step, done = false, unlocked = false, progress = 0, amount = 0, complete = false, finished = true }
	end
	local unlocked = s.playDays >= step
	local progress = stats[def.stat] or 0
	return {
		step = step,
		done = false,
		unlocked = unlocked,
		progress = math.min(progress, def.amount),
		amount = def.amount,
		complete = unlocked and progress >= def.amount,
		finished = false,
	}
end

function PitmasterPath.claim(s: State, steps: { any }, stats: { [string]: number }): (boolean, any?)
	local st = PitmasterPath.status(s, steps, stats)
	if not st.complete then
		return false, nil
	end
	s.claimed += 1
	return true, steps[st.step].reward
end

return PitmasterPath
