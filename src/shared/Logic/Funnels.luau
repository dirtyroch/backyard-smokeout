--!strict
--[[
	Funnels.luau — step lists for Roblox Analytics funnels (pure, unit-tested).
	The server (InsightsService) logs each onboarding step once per account and the Pit Shop
	steps once per shop visit, so the Creator Dashboard shows where new players drop off and
	which shop tabs lead to purchases. No personal data, nothing shown to players.
]]
local Funnels = {}

-- Onboarding: join -> first brisket -> first plate served -> tutorial done -> each Rookie goal.
function Funnels.onboardingSteps(rookieSteps: { any }): { string }
	local out = { "Joined", "Started first brisket", "Served first plate", "Finished tutorial" }
	for _, r in ipairs(rookieSteps) do
		table.insert(out, "Rookie: " .. r.id)
	end
	return out
end

-- How far along onboarding this save is (1-based index into onboardingSteps).
function Funnels.onboardingReached(data: any, rookieSteps: { any }): number
	local n = 1
	if data.tutorial.firstBrisket then
		n = 2
		if (data.stats.served or 0) >= 1 then
			n = 3
			if data.tutorial.done then
				n = 4
				if not data.rookie.skipped then
					n += math.min(data.rookie.claimed or 0, #rookieSteps)
				end
			end
		end
	end
	return n
end

-- Steps to log now: everything after `logged` up to `reached`.
function Funnels.newSteps(logged: number, reached: number): { number }
	local out = {}
	for i = logged + 1, reached do
		table.insert(out, i)
	end
	return out
end

Funnels.SHOP = { "Opened shop", "Opened a tab", "Tapped buy", "Bought" }

-- Coin flows get added up and sent once a minute instead of on every plate.
export type Bucket = { [string]: { flow: string, tx: string, sku: string, amount: number } }

function Funnels.addCoins(bucket: Bucket, amount: number, tx: string, sku: string)
	if amount == 0 then
		return
	end
	local flow = amount > 0 and "Source" or "Sink"
	local k = flow .. "|" .. tx .. "|" .. sku
	local b = bucket[k]
	if not b then
		b = { flow = flow, tx = tx, sku = sku, amount = 0 }
		bucket[k] = b
	end
	b.amount += math.abs(amount)
end

return Funnels
