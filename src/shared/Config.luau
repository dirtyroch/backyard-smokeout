--!strict
--[[
	Config.luau — every piece of game balance and content lives here as plain data.
	Weekly updates should mostly be "add a row": a new meat, sauce, critter, cosmetic,
	Pitmaster Path step or season theme. No Roblox APIs are used in this file so the
	pure-logic unit tests (Lune) can load it too. Colors are hex strings.
]]

local Config = {}

Config.GAME_NAME = "Backyard Smokeout"
Config.TAGLINE = "Low and slow. Smoke it while you sleep."

-- Daily resets, streaks and the Saturday Cook-Off use Texas time (Central, fixed UTC-6).
Config.TIMEZONE_OFFSET_HOURS = -6

Config.MAX_PLOTS = 8 -- set the server size to 8 in Game Settings > Places
Config.START_COINS = 50
Config.COOLER_MAX = 40
Config.AUTOSAVE_SECONDS = 60
Config.RESTOCK_SECONDS = 300 -- sauce shop restocks every 5 minutes
Config.BURGER_BURN_GRACE = 15 -- seconds a finished burger can sit before it burns (only while you're online)
Config.PEEK_PENALTY_FRACTION = 0.10 -- "If you're lookin', you ain't cookin'"
Config.PEEK_PENALTY_MIN = 10
Config.PLAYTIME_NUDGE_MINUTES = 60
Config.CUSTOMER_SPOTS = 3
Config.CUSTOMER_SPAWN_SECONDS = 9
Config.CUSTOMER_PATIENCE = 120
Config.MATCH_ORDER_BONUS = 1.25
Config.NEW_REGULAR_REWARD = 50
Config.RESTING_IDLE_SECONDS = 120

-- Spatula flip (burgers): flip near the halfway mark. Fractions of total cook time.
Config.Flip = {
	target = 0.5,
	perfectWindow = 0.08, -- +-2.4s on a 30s burger
	goodWindow = 0.2,
	perfectMult = 1.5,
	goodMult = 1.15,
	missMult = 0.9,
	unflippedMult = 0.85,
	perfectAura = 1000, -- "+1000 Aura"
	comboStep = 0.1, -- each perfect in a row adds +10% tip (max +100%)
	comboMax = 10,
	lockedInAt = 3, -- "LOCKED IN" combo status
}

Config.Stations = { "grill", "smoker" }

export type Meat = {
	id: string,
	name: string,
	station: string,
	cookTime: number,
	cost: number,
	price: number,
	unlockPit: number,
	maxRarity: number,
	color: string,
	icon: string,
	premium: boolean?,
	season: string?,
	hidden: boolean?,
	size: { number },
}

Config.Meats = {
	burger = { id = "burger", name = "Backyard Burger", station = "grill", cookTime = 30, cost = 2, price = 12, unlockPit = 1, maxRarity = 3, color = "#8B4A2B", icon = "🍔", size = { 1.6, 0.5, 1.6 } },
	hotlink = { id = "hotlink", name = "Hot Link", station = "smoker", cookTime = 120, cost = 6, price = 30, unlockPit = 1, maxRarity = 5, color = "#9E2A2B", icon = "🌭", size = { 2.2, 0.5, 0.5 } },
	brisket = { id = "brisket", name = "Texas Brisket", station = "smoker", cookTime = 21600, cost = 300, price = 3600, unlockPit = 1, maxRarity = 5, color = "#3E2215", icon = "🥩", size = { 3, 1, 1.8 } },
	yardbird = { id = "yardbird", name = "Smoked Yardbird", station = "smoker", cookTime = 480, cost = 20, price = 110, unlockPit = 2, maxRarity = 5, color = "#C27C3A", icon = "🍗", size = { 1.6, 1, 1.4 } },
	ribs = { id = "ribs", name = "Roch & Roll Ribs", station = "smoker", cookTime = 1800, cost = 60, price = 420, unlockPit = 2, maxRarity = 5, color = "#7A2E1C", icon = "🍖", size = { 2.8, 0.5, 1.2 } },
	porkbutt = { id = "porkbutt", name = "Pork Butt", station = "smoker", cookTime = 7200, cost = 150, price = 1500, unlockPit = 3, maxRarity = 5, color = "#6B3A20", icon = "🐖", size = { 1.8, 1.4, 1.8 } },
	turkeyleg = { id = "turkeyleg", name = "Harvest Turkey Leg", station = "smoker", cookTime = 900, cost = 30, price = 260, unlockPit = 1, maxRarity = 5, color = "#A0522D", icon = "🦃", season = "harvest", size = { 1, 1, 2.2 } },
	wagyu = { id = "wagyu", name = "Wagyu Brisket", station = "smoker", cookTime = 14400, cost = 0, price = 7000, unlockPit = 1, maxRarity = 5, color = "#2B140B", icon = "🥩", premium = true, size = { 3.2, 1.1, 1.9 } },
	tomahawk = { id = "tomahawk", name = "Tomahawk Steak", station = "grill", cookTime = 300, cost = 0, price = 700, unlockPit = 1, maxRarity = 5, color = "#5A1E12", icon = "🪓", premium = true, size = { 3, 0.6, 1.4 } },
	firstbrisket = { id = "firstbrisket", name = "First Brisket", station = "smoker", cookTime = 75, cost = 0, price = 100, unlockPit = 1, maxRarity = 5, color = "#3E2215", icon = "🥩", hidden = true, size = { 3, 1, 1.8 } },
}

Config.MeatOrder = { "burger", "tomahawk", "hotlink", "yardbird", "turkeyleg", "ribs", "porkbutt", "brisket", "wagyu" }

-- Rarity of a finished cut. Rolled on the server when the cook starts. Odds are shown in the Index.
Config.Rarities = {
	{ id = "common", name = "Common", weight = 70, mult = 1, color = "#D6D0C6", flex = false },
	{ id = "juicy", name = "Juicy", weight = 22, mult = 1.5, color = "#5AD2FF", flex = false },
	{ id = "smokering", name = "Smoke Ring Gold", weight = 6, mult = 3, color = "#FFC83C", flex = true },
	{ id = "texas", name = "Texas-Size", weight = 1.8, mult = 6, color = "#FF5A36", flex = true },
	{ id = "meteorite", name = "Meteorite", weight = 0.2, mult = 12, color = "#9B5CFF", flex = true },
}

-- Pit levels upgrade every smoker and grill at once.
Config.PitLevels = {
	{ name = "Rusty Drum", speed = 1.0, luck = 1.0, cost = 0, color = "#6E4B3A" },
	{ name = "Rochin' the Smoker", speed = 1.25, luck = 1.1, cost = 500, color = "#3B3B3B" },
	{ name = "Big Pit", speed = 1.5, luck = 1.25, cost = 3000, color = "#2A2A2A" },
	{ name = "Pitmaster Rig", speed = 1.85, luck = 1.4, cost = 15000, color = "#1C2A3A" },
	{ name = "Golden Smokehouse", speed = 2.25, luck = 1.6, cost = 75000, color = "#D4A017" },
}

Config.Slots = {
	smoker = { base = 2, costs = { 400, 2500, 12000 }, passBonus = 2 },
	grill = { base = 2, costs = { 300, 2000 }, passBonus = 0 },
}
Config.MAX_SMOKERS = 7
Config.MAX_GRILLS = 4

-- Unc Status rebirths. `need` = coins earned this run to rebirth INTO this rank.
Config.Ranks = {
	{ name = "Lil Griller", need = 0 },
	{ name = "Big Bro", need = 100000 },
	{ name = "Unc", need = 400000, unlock = "feet_socksandals" },
	{ name = "Great Unc", need = 1500000 },
	{ name = "OG Pitmaster", need = 5000000 },
}
Config.RANK_STEP = 0.5 -- +50% income per rank, forever

-- Sauces: bought with coins (never Robux), each gives a few charges of an effect.
Config.Sauces = {
	sweetheat = { id = "sweetheat", name = "Sweet Heat", effect = "luck", amount = 0.15, charges = 3, price = 150, weight = 40, maxStock = 3, color = "#D2462E" },
	rochetfuel = { id = "rochetfuel", name = "Rochet Fuel Hot Sauce", effect = "speed", amount = 0.25, charges = 3, price = 200, weight = 30, maxStock = 3, color = "#FF5A00" },
	carolinagold = { id = "carolinagold", name = "Carolina Gold Mustard", effect = "tip", amount = 0.25, charges = 5, price = 120, weight = 30, maxStock = 3, color = "#E8B923" },
	peachfuzz = { id = "peachfuzz", name = "Peach Fuzz Glaze", effect = "tip", amount = 0.5, charges = 5, price = 600, weight = 10, maxStock = 2, color = "#FFA07A" },
	hillcountry = { id = "hillcountry", name = "Hill Country Mop", effect = "luck", amount = 0.35, charges = 3, price = 900, weight = 8, maxStock = 1, color = "#5B3A1E" },
	secretcreek = { id = "secretcreek", name = "Secret Creek Sauce", effect = "luck", amount = 0.5, charges = 5, price = 0, weight = 0, maxStock = 0, color = "#3FA7D6", hidden = true },
	goodboy = { id = "goodboy", name = "Good Boy Glaze", effect = "tip", amount = 0.2, charges = 3, price = 0, weight = 0, maxStock = 0, color = "#E6B25A", hidden = true },
	straitshootin = { id = "straitshootin", name = "Strait-Shootin' Sauce", effect = "speed", amount = 0.3, charges = 3, price = 0, weight = 0, maxStock = 0, color = "#C19A6B", hidden = true },
}
Config.SauceOrder = { "sweetheat", "rochetfuel", "carolinagold", "peachfuzz", "hillcountry" }
Config.RESTOCK_SLOTS = 3

-- Daily login (7-day cycle). One free missed day per week; a longer break only drops you
-- back to the start of your current week, never to zero.
Config.DailyRewards = {
	{ coins = 100 },
	{ coins = 150 },
	{ coins = 200, sauce = "sweetheat" },
	{ coins = 300 },
	{ coins = 400, sauce = "rochetfuel" },
	{ coins = 600 },
	{ coins = 1000, sauce = "hillcountry", boostMinutes = 15 },
}

-- 28-day Pitmaster Path. Step N unlocks on your Nth play day; goals are lifetime stats.
Config.PathSteps = ({
	{ stat = "served", amount = 3, reward = { coins = 200 }, label = "Serve 3 plates" },
	{ stat = "perfectFlips", amount = 3, reward = { sauce = "sweetheat" }, label = "Land 3 perfect spatula flips" },
	{ stat = "smoked", amount = 3, reward = { cosmetic = "hat_straw" }, label = "Smoke 3 meats" },
	{ stat = "critters", amount = 3, reward = { coins = 500 }, label = "Meet 3 different regulars" },
	{ stat = "sauces", amount = 2, reward = { boostMinutes = 15 }, label = "Buy 2 sauces" },
	{ stat = "upgrades", amount = 1, reward = { coins = 800 }, label = "Upgrade your pit once" },
	{ stat = "rares", amount = 2, reward = { wagyu = 1, title = "Week 1 Pitmaster" }, label = "Cook 2 rare cuts" },
	{ stat = "served", amount = 60, reward = { coins = 1200 }, label = "Serve 60 plates" },
	{ stat = "cookoffs", amount = 1, reward = { sauce = "hillcountry" }, label = "Enter a Cook-Off" },
	{ stat = "critters", amount = 5, reward = { rex = true }, label = "Meet 5 regulars (someone special is coming...)" },
	{ stat = "perfectFlips", amount = 25, reward = { cosmetic = "trail_smokepuff" }, label = "Land 25 perfect flips" },
	{ stat = "smoked", amount = 25, reward = { coins = 2000 }, label = "Smoke 25 meats" },
	{ stat = "mosquitoes", amount = 10, reward = { boostMinutes = 30 }, label = "Swat 10 mosquitoes" },
	{ stat = "rares", amount = 6, reward = { cosmetic = "tool_goldtongs", title = "Two-Week Pitmaster" }, label = "Cook 6 rare cuts" },
	{ stat = "served", amount = 150, reward = { coins = 3000 }, label = "Serve 150 plates" },
	{ stat = "sauces", amount = 8, reward = { sauce = "peachfuzz" }, label = "Buy 8 sauces" },
	{ stat = "cookoffs", amount = 3, reward = { coins = 3500 }, label = "Enter 3 Cook-Offs" },
	{ stat = "critters", amount = 7, reward = { cosmetic = "smoke_hickory" }, label = "Meet 7 regulars" },
	{ stat = "upgrades", amount = 3, reward = { wagyu = 2 }, label = "Upgrade 3 times" },
	{ stat = "perfectFlips", amount = 60, reward = { coins = 4000 }, label = "Land 60 perfect flips" },
	{ stat = "rares", amount = 12, reward = { cosmetic = "smoke_sunset", title = "Three-Week Pitmaster" }, label = "Cook 12 rare cuts" },
	{ stat = "served", amount = 300, reward = { coins = 6000 }, label = "Serve 300 plates" },
	{ stat = "smoked", amount = 80, reward = { boostMinutes = 60 }, label = "Smoke 80 meats" },
	{ stat = "mosquitoes", amount = 40, reward = { coins = 7000 }, label = "Swat 40 mosquitoes" },
	{ stat = "cookoffs", amount = 6, reward = { cosmetic = "apron_pathfinder" }, label = "Enter 6 Cook-Offs" },
	{ stat = "critters", amount = 9, reward = { coins = 9000 }, label = "Meet 9 regulars" },
	{ stat = "rares", amount = 20, reward = { wagyu = 3 }, label = "Cook 20 rare cuts" },
	{ stat = "served", amount = 500, reward = { tomahawk = true, cosmetic = "skin_pathgold", title = "Pitmaster" }, label = "Serve 500 plates" },
} :: { any })

-- Critter customers = the Regulars Index. All original characters.
Config.Critters = {
	{ id = "armadillo", name = "Dilly the Armadillo", weight = 20, tip = 1.0, body = "#9C8A7A", head = "#8A7868", scale = 1.0, ears = false },
	{ id = "roadrunner", name = "Zoom the Roadrunner", weight = 18, tip = 1.0, body = "#6B5B4B", head = "#3A6EA5", scale = 0.9, ears = false },
	{ id = "raccoon", name = "Bandit the Raccoon", weight = 16, tip = 1.1, body = "#7D7D7D", head = "#505050", scale = 1.0, ears = true },
	{ id = "possum", name = "Possum Pete", weight = 14, tip = 1.1, body = "#BEBEBE", head = "#F0E6E6", scale = 0.95, ears = true },
	{ id = "hornedtoad", name = "Spike the Horned Lizard", weight = 10, tip = 1.2, body = "#C2A36B", head = "#B08F55", scale = 0.7, ears = false },
	{ id = "longhorn", name = "Lil Longhorn", weight = 8, tip = 1.3, body = "#C46A2F", head = "#E0B080", scale = 1.3, ears = true, horns = true },
	{ id = "hummingbird", name = "Buzz the Hummingbird", weight = 7, tip = 1.3, body = "#2E8B57", head = "#C2185B", scale = 0.6, ears = false },
	{ id = "bellyrubpup", name = "Belly Rub Pup", weight = 6, tip = 1.5, body = "#E8D3B9", head = "#E8D3B9", scale = 0.9, ears = true, bellyRub = true },
	{ id = "clapcat", name = "Clapping Cat", weight = 5, tip = 1.4, body = "#151515", head = "#1E1E1E", scale = 0.85, ears = true },
	{ id = "rex", name = "Rex", weight = 0.8, tip = 3.0, body = "#6CC24A", head = "#7BD35A", scale = 1.2, ears = false, rex = true, ribbon = "RAWR means I love you ♥" },
}

-- Cosmetics. `source`: "robux" (developer product), "path", "egg", "rank", "suds", "pass", "rotation" (limited-time Robux).
Config.Cosmetics = {
	hat_pitmaster = { name = "Pitmaster Cowboy Hat", slot = "hat", source = "robux", color = "#3B2A1A" },
	hat_straw = { name = "Straw Cowboy Hat", slot = "hat", source = "path", color = "#E3C77A" },
	hat_turkey = { name = "Gobble Hat", slot = "hat", source = "rotation", color = "#8B5A2B" },
	apron_grillmaster = { name = "Grill Master Apron", slot = "apron", source = "robux", color = "#B22222", text = "GRILL MASTER" },
	apron_okayestunc = { name = "World's Okayest Unc Apron", slot = "apron", source = "egg", color = "#4A6FA5", text = "WORLD'S OKAYEST UNC" },
	apron_pathfinder = { name = "Pit Path Apron", slot = "apron", source = "path", color = "#2F4F2F", text = "28 DAYS LOW & SLOW" },
	apron_harvest = { name = "Harvest Plaid Apron", slot = "apron", source = "rotation", color = "#A0522D", text = "GIVE THANKS" },
	tool_goldenspatula = { name = "Golden Spatula", slot = "tool", source = "robux", color = "#FFD700" },
	tool_goldtongs = { name = "Golden Tongs", slot = "tool", source = "path", color = "#E6BE8A" },
	skin_candyred = { name = "Candy Apple Smoker", slot = "skin", source = "robux", color = "#C1121F" },
	skin_galaxy = { name = "Galaxy Smoker", slot = "skin", source = "robux", color = "#3A0CA3", neon = true },
	skin_golden = { name = "Solid Gold Smoker", slot = "skin", source = "robux", color = "#FFD700", gold = true },
	skin_pathgold = { name = "Pitmaster Bronze Smoker", slot = "skin", source = "path", color = "#CD7F32" },
	skin_snowy = { name = "Snowy Smoker", slot = "skin", source = "rotation", color = "#E8F4FF" },
	smoke_grape = { name = "Grape Soda Smoke", slot = "smoke", source = "robux", color = "#8E44AD" },
	smoke_bluebonnet = { name = "Bluebonnet Smoke", slot = "smoke", source = "robux", color = "#3B6FD8" },
	smoke_sherbet = { name = "Rainbow Sherbet Smoke", slot = "smoke", source = "robux", color = "#FF8FAB", rainbow = true },
	smoke_hickory = { name = "Hickory Gold Smoke", slot = "smoke", source = "path", color = "#D4A35A" },
	smoke_sunset = { name = "Sunset Smoke", slot = "smoke", source = "path", color = "#FF7F50" },
	smoke_pumpkin = { name = "Pumpkin Patch Smoke", slot = "smoke", source = "rotation", color = "#FF7518" },
	trail_sparkler = { name = "Sparkler Trail", slot = "trail", source = "robux", color = "#FFF3B0" },
	trail_sauce = { name = "BBQ Sauce Drip Trail", slot = "trail", source = "robux", color = "#7B1E10" },
	trail_petals = { name = "Bluebonnet Petal Trail", slot = "trail", source = "robux", color = "#4169E1" },
	trail_smokepuff = { name = "Smoke Puff Trail", slot = "trail", source = "path", color = "#BBBBBB" },
	trail_firework = { name = "Firework Trail", slot = "trail", source = "rotation", color = "#FF2E63" },
	feet_socksandals = { name = "Socks & Sandals", slot = "feet", source = "rank", color = "#FFFFFF" },
	bandana_red = { name = "Red Bandana", slot = "neck", source = "suds", color = "#C0392B" },
	bandana_blue = { name = "Blue Bandana", slot = "neck", source = "suds", color = "#2E86C1" },
	bandana_paws = { name = "Paw Print Bandana", slot = "neck", source = "suds", color = "#F5B7B1" },
	bandana_gold = { name = "Golden Bandana", slot = "neck", source = "suds", color = "#F1C40F" },
	vip_lights = { name = "VIP Patio Lights", slot = "patio", source = "pass", color = "#FFE9A8" },
}
Config.CosmeticSlots = { "hat", "apron", "tool", "neck", "feet", "trail", "skin", "smoke", "patio" }

-- Suds Saturday & Sunday: wash a muddy pup for a free bandana. Odds shown in game.
Config.Bandanas = {
	{ id = "bandana_red", weight = 50 },
	{ id = "bandana_blue", weight = 30 },
	{ id = "bandana_paws", weight = 15 },
	{ id = "bandana_gold", weight = 5 },
}
Config.SUDS_PUP_CHANCE = 0.35

-- Limited-time cosmetics rotate weekly (2 at a time) and always come back in a later rotation.
Config.RotationPool = { "Rot_ApronHarvest", "Rot_SkinSnowy", "Rot_SmokePumpkin", "Rot_TrailFirework", "Rot_HatTurkey" }
Config.ROTATION_FEATURED = 2

-- Saturday Cook-Off. Judges rate W / Mid / L / Cooked (Cooked is the best: it's BBQ).
Config.CookOff = {
	ratings = {
		{ id = "L", min = 0, coins = 50, aura = 0, line = "Bless your heart, sugar." },
		{ id = "Mid", min = 35, coins = 150, aura = 100, line = "It's... food. Mid." },
		{ id = "W", min = 55, coins = 400, aura = 300, line = "Now THAT's a W plate!" },
		{ id = "Cooked", min = 75, coins = 1200, aura = 1000, line = "You COOKED. The cat is clapping." },
	},
	saturdayMult = 3, -- practice rounds on other days pay 1x; Saturdays pay 3x + leaderboard
	cooldown = 60,
}

-- Mosquito swarm at dusk (co-op).
Config.Mosquito = { baseCount = 6, perPlayer = 2, hp = 2, queenHp = 25, duration = 90, rewardPerPit = 120, aura = 250 }
Config.DAY_LENGTH_MINUTES = 20

-- Plate snagging ("you got taxed"). Only from ONLINE players, never rare cuts, with lock timers.
Config.Snag = {
	cooldown = 120, -- per snagger
	victimLock = 180, -- victim's pass window is locked after a snag
	newPlayerShield = 300, -- first 5 minutes of a session are protected
	insurance = 0.25, -- victim gets 25% of the plate value back right away
	catchWindow = 15, -- tag the snagger within 15s to get it back (+ bonus)
	catchDistance = 7,
	catchBonus = 50,
	maxRarityIndex = 2, -- only Common and Juicy plates can be snagged
}

Config.Crew = { perFriend = 0.10, maxFriends = 3 }

-- Fair Play: paid perks are capped so they never wall off free players.
--   * the tip pass is +50% (not x2) and never applies to the Cook-Off or snagging
--   * buying a speed boost gives everyone else in the server a free "Smoke Shower"
--   * snagging is opt-in: new players start in Peace Mode
Config.FairPlay = { passTipMult = 1.5, passTipCap = 1.5, showerMinutes = 5, showerMult = 1.25 }

-- Big Biscuit Zoomies: 3 different players rub his belly within 20 s -> the whole server gets
-- +25% tips for 5 minutes (free). Server-wide cooldown 10 minutes.
Config.Zoomies = { window = 20, need = 3, cooldown = 600, minutes = 5, tipBonus = 0.25 }

-- Lunch Rush: every 150 s window, serve 4 plates for +50% of what those plates earned.
Config.Rush = { period = 150, need = 4, bonusFrac = 0.5 }

-- Season themes: the Cook-Off template reskins by month.
Config.Seasons = {
	{ months = { 10 }, id = "spooky", name = "Spooky Smoke-Off", color = "#FF7518" },
	{ months = { 11 }, id = "harvest", name = "Harvest Smoke-Off", color = "#C46A2F" },
	{ months = { 12, 1 }, id = "holiday", name = "Holiday Ham Jam", color = "#C0392B" },
	{ months = { 2, 3, 4, 5 }, id = "bluebonnet", name = "Bluebonnet Bash", color = "#3B6FD8" },
	{ months = { 6, 7, 8, 9 }, id = "summer", name = "Summer Sizzle", color = "#F4D03F" },
}

return Config
