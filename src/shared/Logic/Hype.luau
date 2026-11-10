--!strict
--[[
	Hype.luau — pure logic for the social / clip moments (no Roblox APIs, unit-tested in Lune).

	  * pileOn:   Big Bertha's Dinner Bell. When `need` different players ring the bell within
	              `window` seconds, the whole server gets a short free tip bonus.
	  * rushStep: the Lunch Rush. Time is cut into fixed windows; serve `need` plates inside one
	              window for a bonus. Gives a 1-3 minute goal at every stage of the game.
	  * isSixSeven: a plate worth ...67 coins pops a "6-7!" (text only, no audio or likeness).
	  * passTip:  Fair Play cap for the tip pass.
]]
local Hype = {}

-- `rubs` maps userId -> last rub time. Returns how many distinct players rubbed inside the
-- window, and whether that reaches `need` (and the cooldown since `lastT` has passed).
function Hype.pileOn(rubs: { [number]: number }, now: number, window: number, need: number, lastT: number, cooldown: number): (number, boolean)
	local n = 0
	for id, t in pairs(rubs) do
		if now - t <= window then
			n += 1
		else
			rubs[id] = nil
		end
	end
	return n, n >= need and now - lastT >= cooldown
end

-- Does this bell ring count (stats / Season XP / pile-on)? At most one per `cooldown` seconds
-- per player; records the time when it does.
function Hype.ringCounts(last: { [number]: number }, id: number, now: number, cooldown: number): boolean
	local t = last[id]
	if t ~= nil and now - t < cooldown then
		return false
	end
	last[id] = now
	return true
end

export type Rush = { w: number, n: number, sum: number, done: boolean }

function Hype.rushWindow(t: number, period: number): number
	return math.floor(t / period)
end

function Hype.rushEnds(w: number, period: number): number
	return (w + 1) * period
end

-- Record one served plate worth `value` at time `t`. Returns the (possibly new) rush state and
-- the bonus to pay right now (0 unless this plate cleared the rush).
function Hype.rushStep(state: Rush?, t: number, period: number, need: number, bonusFrac: number, value: number): (Rush, number)
	local w = Hype.rushWindow(t, period)
	local s: Rush = (state and state.w == w) and state or { w = w, n = 0, sum = 0, done = false }
	if s.done then
		return s, 0
	end
	s.n += 1
	s.sum += value
	if s.n >= need then
		s.done = true
		return s, math.max(1, math.floor(s.sum * bonusFrac + 0.5))
	end
	return s, 0
end

function Hype.isSixSeven(value: number): boolean
	return value >= 67 and value % 100 == 67
end

-- Fair Play: the tip pass is a flat multiplier, never more than `cap`.
function Hype.passTip(hasPass: boolean, mult: number, cap: number): number
	if not hasPass then
		return 1
	end
	return math.min(mult, cap)
end

return Hype
