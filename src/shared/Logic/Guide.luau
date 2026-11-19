--!strict
-- First-visit hints. Shown once, saved on the profile, and skippable.
-- Copy stays on the porch: no shop pressure and no paid randomness.
local Guide = {}

export type State = {
	step: number,
	done: boolean,
	skipped: boolean,
	introduced: boolean,
}

export type Step = {
	id: string,
	target: string,
	title: string,
	body: string,
}

export type Life = {
	served: number?,
	firstBrisket: boolean?,
	tutorialDone: boolean?,
	playSeconds: number?,
	crew: number?,
}

Guide.STEPS = {
	{
		id = "ranch",
		target = "ranch",
		title = "Claim your ranch",
		body = "This yard is yours. Tap the orange button to start your first brisket.",
	},
	{
		id = "serve",
		target = "serve",
		title = "Serve your first critter",
		body = "A hungry critter is waiting. Serve them a plate and they pay you in coins.",
	},
	{
		id = "crew",
		target = "crew",
		title = "Hire Pip",
		body = "Open the Crew tab and hire Pip the raccoon. Pip helps cook burgers. It costs coins you earn in the yard.",
	},
	{
		id = "gift",
		target = "gift",
		title = "Claim your free gift",
		body = "A free gift is ready. Tap Gift to claim it. Another one shows up later, on the house.",
	},
} :: { Step }

function Guide.new(): State
	return { step = 1, done = false, skipped = false, introduced = false }
end

-- Ranchers from before the hints existed skip them quietly. A player we already
-- introduced keeps going, even after they serve someone.
function Guide.prepare(g: State, life: Life): boolean
	if g.done or g.skipped then
		g.introduced = true
		return false
	end
	if type(g.step) ~= "number" or g.step ~= g.step or g.step < 1 then
		g.step = 1
	end
	g.step = math.floor(g.step)
	if not g.introduced then
		g.introduced = true
		local played = (life.served or 0) > 0
			or life.firstBrisket == true
			or life.tutorialDone == true
			or (life.playSeconds or 0) >= 120
			or (life.crew or 0) > 0
		if played then
			g.skipped = true
			g.done = true
			return true
		end
	end
	return false
end

export type Signals = {
	ranch: boolean,
	serve: boolean,
	crew: boolean,
	gift: boolean,
}

function Guide.signals(data: any): Signals
	local ranch = data.tutorial ~= nil and data.tutorial.firstBrisket == true
	if not ranch and type(data.stations) == "table" then
		for _, cook in pairs(data.stations) do
			if type(cook) == "table" and cook.meat == "firstbrisket" then
				ranch = true
				break
			end
		end
	end
	local crew = false
	local roster = data.staff and data.staff.roster
	if type(roster) == "table" then
		for _, e in ipairs(roster) do
			if type(e) == "table" and e.id == "pip" then
				crew = true
				break
			end
		end
	end
	local owned = data.crew and data.crew.owned
	if not crew and type(owned) == "table" and #owned > 0 then
		crew = true
	end
	local nextAt = data.freeGift and data.freeGift.nextAt
	local gift = type(nextAt) == "number" and nextAt == nextAt and nextAt > 0
	local served = data.stats and data.stats.served or 0
	return {
		ranch = ranch,
		serve = type(served) == "number" and served >= 1,
		crew = crew,
		gift = gift,
	}
end

-- Moves past steps the ranch has already finished. Returns true when the saved step changes.
function Guide.sync(g: State, signals: Signals): boolean
	if g.done or g.skipped then
		return false
	end
	local before = g.step
	if type(g.step) ~= "number" or g.step ~= g.step then
		g.step = 1
	end
	g.step = math.max(1, math.floor(g.step))
	while g.step >= 1 and g.step <= #Guide.STEPS do
		local def = Guide.STEPS[g.step]
		if (signals :: any)[def.id] ~= true then
			break
		end
		g.step += 1
	end
	if g.step > #Guide.STEPS then
		g.done = true
	end
	return g.step ~= before or g.done
end

function Guide.skip(g: State): boolean
	if g.done or g.skipped then
		return false
	end
	g.skipped = true
	g.done = true
	return true
end

export type View = {
	active: boolean,
	step: number?,
	total: number?,
	id: string?,
	title: string?,
	body: string?,
	target: string?,
}

function Guide.view(g: State?): View
	if not g or g.done or g.skipped then
		return { active = false }
	end
	local def = Guide.STEPS[g.step]
	if not def then
		return { active = false }
	end
	return {
		active = true,
		step = g.step,
		total = #Guide.STEPS,
		id = def.id,
		title = def.title,
		body = def.body,
		target = def.target,
	}
end

return Guide
