--!strict
-- Unc Hank's Rookie List: five quick goals that walk a brand-new pitmaster through the first
-- five minutes (after the one-button first brisket). Each goal is a lifetime stat, so it can't be
-- lost, and the client shows an arrow to where the goal happens. Pure logic, no Roblox APIs.
local Rookie = {}

export type State = { claimed: number, skipped: boolean?, resumed: boolean? }

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
	skipped: boolean, -- tucked away (by the player, or quietly for veterans) and not done yet
	done: boolean, -- all goals claimed, finish reward earned
}

function Rookie.status(s: State, steps: { any }, stats: { [string]: number }): Status
	local step = s.claimed + 1
	local def = steps[step]
	local done = s.claimed >= #steps
	if s.skipped or not def then
		return { step = #steps + 1, total = #steps, finished = true, progress = 0, amount = 0, skipped = s.skipped == true and not done, done = done }
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
		skipped = false,
		done = false,
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

-- Veterans from before the list existed skip it quietly (they already know the loop), unless
-- they brought it back themselves.
function Rookie.shouldSkip(s: State, tutorialDone: boolean, stats: { [string]: number }, veteranServes: number): boolean
	return s.claimed == 0 and not s.skipped and not s.resumed and tutorialDone and (stats.served or 0) >= veteranServes
end

-- The player taps Skip (after a confirm). A finished list can't be skipped.
function Rookie.skip(s: State, steps: { any }): boolean
	if s.skipped or s.claimed >= #steps then
		return false
	end
	s.skipped = true
	return true
end

-- Bring a skipped list back (Settings > Game). Progress is lifetime stats, so goals done in the
-- meantime are claimed on the next check, and the finish reward can still be earned.
function Rookie.resume(s: State, steps: { any }): boolean
	if not s.skipped or s.claimed >= #steps then
		return false
	end
	s.skipped = false
	s.resumed = true
	return true
end

-- Short form for the small card: "Rookie of the Ranch Bandana + title + 250 🪙".
function Rookie.rewardShort(r: any, cosmeticName: string?): string
	local parts = {}
	if r.cosmetic then
		table.insert(parts, cosmeticName or r.cosmetic)
	end
	if r.title then
		table.insert(parts, "title")
	end
	if r.coins and r.coins > 0 then
		table.insert(parts, r.coins .. " 🪙")
	end
	return table.concat(parts, " + ")
end

-- Plain words for the finish reward, used in the skip confirm and in Settings.
function Rookie.rewardText(r: any, cosmeticName: string?): string
	local parts = {}
	if r.cosmetic then
		table.insert(parts, cosmeticName or r.cosmetic)
	end
	if r.title then
		table.insert(parts, 'the "' .. r.title .. '" title')
	end
	if r.coins and r.coins > 0 then
		table.insert(parts, "+" .. r.coins .. " 🪙")
	end
	if #parts <= 1 then
		return parts[1] or ""
	end
	return table.concat(parts, ", ", 1, #parts - 1) .. " and " .. parts[#parts]
end

return Rookie
