--!strict
-- The first minute, as one tracker. Guide, the brisket prompt, and the Rookie List
-- stay quiet until this is done. Existing ranchers (guide or tutorial already finished) skip it.
local Config = if script ~= nil and script.Parent ~= nil and script.Parent.Parent ~= nil then require(script.Parent.Parent.Config) else require("../Config")

local Onboard = {}

Onboard.STEPS = {
	"Spawned",
	"Claimed",
	"First crew",
	"First hire",
	"Tier 2",
	"First trait",
	"Shop seen",
}

function Onboard.skip(data: any): boolean
	local ob = if type(data.onboard) == "table" then data.onboard else {}
	if ob.done == true then
		return true
	end
	if ob.started == true then
		return false
	end
	local guide = data.guide
	if type(guide) == "table" and (guide.done == true or guide.skipped == true) then
		return true
	end
	local tutorial = data.tutorial
	if type(tutorial) == "table" and tutorial.done == true then
		return true
	end
	return false
end

function Onboard.allowPurchase(playSeconds: number, skip: boolean): boolean
	return skip or playSeconds >= Config.Onboarding.promptAt
end

function Onboard.buttonOn(id: string, playSeconds: number, skip: boolean): boolean
	if skip then
		return true
	end
	local at = Config.Onboarding.unlock[id]
	if type(at) ~= "number" then
		return false
	end
	return playSeconds >= at
end

function Onboard.visibleCount(playSeconds: number, skip: boolean): number
	local n = 0
	for id in pairs(Config.Onboarding.unlock) do
		if Onboard.buttonOn(id, playSeconds, skip) then
			n += 1
		end
	end
	return n
end

-- The first shed is priced for the opening minute. After that, the ranch price stands.
function Onboard.tierPrice(listed: number, tier: number, playSeconds: number, skip: boolean): number
	if tier ~= 1 or skip or playSeconds >= Config.Onboarding.shopAt then
		return listed
	end
	return Config.Onboarding.tier2Cost
end

export type Flags = {
	claimed: boolean,
	crew: number,
	tier: number,
	trait: boolean,
	playSeconds: number,
	shopSeen: boolean,
}

function Onboard.reached(flags: Flags): number
	local n = 1
	if flags.claimed then
		n = 2
	end
	if flags.crew >= 1 then
		n = 3
	end
	if flags.crew >= 2 then
		n = 4
	end
	if flags.tier >= 2 then
		n = 5
	end
	if flags.trait then
		n = 6
	end
	if flags.shopSeen or flags.playSeconds >= Config.Onboarding.shopAt then
		n = 7
	end
	return n
end

export type Card = { step: number, total: number, title: string, body: string, target: string }

function Onboard.card(step: number, playSeconds: number): Card?
	if step >= 7 or playSeconds >= Config.Onboarding.shopAt then
		return nil
	end
	if step < 3 then
		return { step = step, total = 7, title = "Pip is on the way", body = "First hire's on the house. He'll mop the pit, and coins start ticking.", target = "hire" }
	elseif step < 4 then
		return { step = step, total = 7, title = "Hire your 2nd critter", body = "Pick one on the Hiring Line. The cheapest ones cost what you already have.", target = "hire" }
	elseif step < 5 then
		return { step = step, total = 7, title = "Build Ranch Tier 2", body = "The fence and shed add 2 crew slots.", target = "ranchbuild" }
	end
	return { step = step, total = 7, title = "A little smoke", body = "Watch the crew. A trait can catch, and you'll see it happen.", target = "crew" }
end

export type Beat = { t: number, coins: number, note: string }

-- What a brand-new purse does if the player follows the tracker.
-- Pip earns from pipAt. The 25 coin hire happens at the first second they are asked and can pay.
-- The second critter earns secondDelay seconds after that. The first shed costs tier2Cost.
function Onboard.opening(pipRate: number, secondRate: number): { hireAt: number, tierAt: number, beats: { Beat } }
	local coins = Config.START_COINS
	local hired = false
	local hireAt = -1
	local secondAt = -1
	local tierAt = -1
	local beats = {}
	local function snap(t: number, note: string)
		table.insert(beats, { t = t, coins = coins, note = note })
	end
	snap(0, "Spawned on your ranch with " .. tostring(coins) .. " coins. Four buttons: Crew, Hire, Ranch, Settings.")
	for t = 1, 90 do
		local rate = 0
		if t >= Config.Onboarding.pipAt then
			rate += pipRate
		end
		if secondAt >= 0 and t >= secondAt then
			rate += secondRate
		end
		coins += rate
		if t == Config.Onboarding.pipAt then
			snap(t, "Pip is on the pit. +" .. tostring(pipRate) .. "/s.")
		end
		if not hired and t >= Config.Onboarding.askAt and coins >= Config.Onboarding.hireCost then
			coins -= Config.Onboarding.hireCost
			hired = true
			hireAt = t
			secondAt = t + Config.Onboarding.secondDelay
			snap(t, "Hired a " .. tostring(Config.Onboarding.hireCost) .. " coin critter. They start earning in " .. tostring(Config.Onboarding.secondDelay) .. " seconds.")
		end
		if tierAt < 0 and hired and coins >= Config.Onboarding.tier2Cost then
			coins -= Config.Onboarding.tier2Cost
			tierAt = t
			snap(t, "Ranch Tier 2. The shed and two more slots.")
			break
		end
	end
	return { hireAt = hireAt, tierAt = tierAt, beats = beats }
end

return Onboard
