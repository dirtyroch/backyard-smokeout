--!strict
-- The shape of a saved player. Add new fields here; old saves get them automatically (Reconcile).
local Config = require(script.Parent.Config)

return {
	schema = 1,
	coins = Config.START_COINS,
	runCoins = 0,
	lifetimeCoins = 0,
	aura = 0,
	rank = 1,
	pitLevel = 1,
	smokerSlotsBought = 0,
	grillSlotsBought = 0,
	stations = {}, -- "s1".."s7", "g1".."g4" -> Cook
	cooler = {}, -- { m = meatId, r = rarityId, f = flip? }
	sauces = {
		luck = { amount = 0, charges = 0 },
		speed = { amount = 0, charges = 0 },
		tip = { amount = 0, charges = 0 },
	},
	boost = { mult = 1, untilT = 0 },
	cuts = { wagyu = 0, tomahawk = 0 },
	unlocks = { tomahawk = false },
	owned = {},
	equipped = {},
	titles = {},
	title = "",
	critters = {},
	cutsIndex = {},
	eggs = {},
	stats = {
		served = 0,
		smoked = 0,
		cooks = 0,
		rares = 0,
		perfectFlips = 0,
		critters = 0,
		cookoffs = 0,
		upgrades = 0,
		mosquitoes = 0,
		sauces = 0,
		burnt = 0,
		snags = 0,
		flips = 0,
		smokerStarts = 0,
		bells = 0,
		giftsSent = 0,
		giftsGot = 0,
	},
	streak = { lastDay = -1, count = 0, best = 0, freeMissWeek = -1 },
	path = { claimed = 0, playDays = 0, lastPlayDay = -1 },
	daily = { jokeDay = -1, creekDay = -1, kingDone = false, bellDay = -1, turkeyDay = -1, holidayDay = -1 },
	restock = { window = -1, bought = {} },
	cookoff = { week = -1, best = 0 },
	settings = { peace = true, sfx = true }, -- snagging is opt-in (Fair Play)
	tutorial = { firstBrisket = false, done = false },
	rookie = { claimed = 0, skipped = false, resumed = false }, -- Unc Hank's Rookie List (Logic/Rookie)
	forceCritter = "",
	combo = 0,
	receipts = {},
	seasonPass = { id = "", base = {}, days = 0, lastDay = -1, skips = 0, paid = false, freeClaimed = 0, paidClaimed = 0 }, -- Logic/SeasonPass
	club = { month = -1, showerDay = -1 }, -- Pit Crew Club monthly look + daily shower
	purchases = { once = {}, count = 0 }, -- one-per-account packs; count of Robux purchases
	analytics = { onboard = 0 }, -- last onboarding funnel step logged (InsightsService)
	giftsHeld = {}, -- paid gifts whose recipient left before the receipt; send later for free (Logic/Gifting)
	lastSeen = 0,
	playSeconds = 0,
}
